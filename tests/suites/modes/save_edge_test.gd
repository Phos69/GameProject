extends GutTest
## Modes A8 — Edge di persistenza del SaveManager (QA-001).
##
## Copre i rami non toccati dal flusso principale (encounters_test):
## fallback sul file .bak quando il salvataggio principale manca, rifiuto di
## JSON corrotti/root non-dizionario/party non valido senza toccare lo stato
## runtime, pulizia dei file temporanei del write atomico, sanitizzazione del
## last_mode sconosciuto e roundtrip dei binding join/leave del multiplayer.

const TEMP_SAVE_PATH := "user://qa_save_edge_test.json"
const TEMP_AUTOSAVE_PATH := "user://qa_async_autosave_test.json"
const MIGRATION_ROOT := "user://qa_save_migration_test"
const MIGRATION_LEGACY_DIR := MIGRATION_ROOT + "/legacy"
const MIGRATION_CURRENT_DIR := MIGRATION_ROOT + "/current"

var _load_failures: Array[String] = []

func test_autosave_is_coalesced_and_written_by_worker() -> void:
	_remove_autosave_files()
	var save_manager := SaveManager.new()
	save_manager.save_path = TEMP_AUTOSAVE_PATH
	save_manager.auto_load = false
	save_manager.autosave_debounce_seconds = 1.0
	add_child_autofree(save_manager)

	save_manager.request_save()
	var first_deadline := save_manager._autosave_due_msec
	await wait_process_frames(1)
	save_manager.request_save()
	assert_true(save_manager.save_pending, "le richieste ravvicinate restano coalescenti")
	assert_gte(save_manager._autosave_due_msec, first_deadline, "la seconda mutazione non anticipa la deadline")
	assert_eq(save_manager._autosave_task_id, -1, "il debounce evita I/O nel frame della richiesta")

	# Il flush forza solo l'avvio: stringify e rotazione file restano nel worker.
	save_manager._flush_pending_save()
	assert_false(save_manager.save_pending, "lo snapshot pending viene consegnato al worker")
	assert_gte(save_manager._autosave_task_id, 0, "l'autosave usa WorkerThreadPool")
	for _frame in range(120):
		if save_manager._autosave_task_id < 0:
			break
		await wait_process_frames(1)
	assert_eq(save_manager._autosave_task_id, -1, "il worker autosave termina")
	assert_true(FileAccess.file_exists(TEMP_AUTOSAVE_PATH), "il payload asincrono viene promosso a save valido")
	assert_false(FileAccess.file_exists(TEMP_AUTOSAVE_PATH + ".tmp"), "il worker non lascia file temporanei")
	assert_false(FileAccess.file_exists(TEMP_AUTOSAVE_PATH + ".bak"), "il worker pulisce il backup dopo la promozione")
	_remove_autosave_files()

func test_save_edge_cases() -> void:
	_load_failures = []
	_remove_save_files()
	var scene = _new_main_scene_fixture()
	assert_true(scene.boot(self), "main scene can be loaded")
	await wait_physics_frames(3)

	var save_manager: SaveManager = scene.node(&"save_manager") as SaveManager
	var local_multiplayer: LocalMultiplayerManager = scene.node(&"local_multiplayer_manager") as LocalMultiplayerManager
	if save_manager == null or local_multiplayer == null:
		assert_true(false, "save systems are available")
		scene.teardown()
		scene = null
		return
	save_manager.save_path = TEMP_SAVE_PATH
	save_manager.autosave_progression = false
	save_manager.autosave_mode_selection = false
	save_manager.load_failed.connect(_on_load_failed)

	# Roundtrip binding multiplayer + last_mode, con write atomico pulito.
	local_multiplayer.join_button = JOY_BUTTON_Y
	local_multiplayer.leave_button = JOY_BUTTON_X
	save_manager.set_last_mode(GameConstants.MODE_DUNGEON)
	assert_true(save_manager.save_game(), "save with custom bindings is written")
	assert_true(FileAccess.file_exists(TEMP_SAVE_PATH), "save file exists after save_game")
	assert_false(FileAccess.file_exists(TEMP_SAVE_PATH + ".tmp"), "atomic write leaves no .tmp behind")
	assert_false(FileAccess.file_exists(TEMP_SAVE_PATH + ".bak"), "atomic write leaves no .bak behind")

	local_multiplayer.reset_joystick_buttons()
	save_manager.set_last_mode(GameConstants.MODE_SURVIVAL)
	assert_true(save_manager.load_game(), "save reloads after runtime changes")
	assert_eq(local_multiplayer.join_button, JOY_BUTTON_Y, "join binding roundtrips through the save")
	assert_eq(local_multiplayer.leave_button, JOY_BUTTON_X, "leave binding roundtrips through the save")
	assert_eq(save_manager.get_last_mode(), GameConstants.MODE_DUNGEON, "last mode roundtrips through the save")

	# Sovrascrivere un salvataggio esistente resta atomico e pulisce il backup.
	assert_true(save_manager.save_game(), "overwriting an existing save succeeds")
	assert_false(FileAccess.file_exists(TEMP_SAVE_PATH + ".bak"), "backup is cleaned after a successful overwrite")

	# Fallback sul backup: senza il file principale si carica il .bak.
	var absolute_save := ProjectSettings.globalize_path(TEMP_SAVE_PATH)
	var absolute_backup := ProjectSettings.globalize_path(TEMP_SAVE_PATH + ".bak")
	assert_eq(
		DirAccess.rename_absolute(absolute_save, absolute_backup),
		OK,
		"save file can be staged as backup"
	)
	local_multiplayer.reset_joystick_buttons()
	assert_true(save_manager.load_game(), "load falls back to the .bak file")
	assert_eq(local_multiplayer.join_button, JOY_BUTTON_Y, "backup restores the join binding")
	DirAccess.remove_absolute(absolute_backup)

	# Salvataggi corrotti: rifiutati con load_failed e stato runtime intatto.
	_write_raw_save("this is not json {{{")
	assert_false(save_manager.load_game(), "malformed JSON is rejected")
	assert_engine_error(
		"Parse JSON failed",
		"the JSON parse error is the expected rejection path"
	)
	_write_raw_save("[1, 2, 3]")
	assert_false(save_manager.load_game(), "a non-dictionary save root is rejected")
	_write_raw_save(JSON.stringify({
		"version": SaveManager.SAVE_VERSION,
		"party": "not-a-dict"
	}))
	assert_false(save_manager.load_game(), "a save without a party dictionary is rejected")
	assert_eq(local_multiplayer.join_button, JOY_BUTTON_Y, "rejected saves leave runtime bindings unchanged")
	assert_gte(_load_failures.size(), 3, "every rejected save emits load_failed with a reason")

	# last_mode sconosciuto viene sanitizzato al default.
	_write_raw_save(JSON.stringify({
		"version": SaveManager.SAVE_VERSION,
		"party": {"level": 1, "experience": 0, "money": 0, "unlocks": []},
		"settings": {"last_mode": "banana_mode"}
	}))
	assert_true(save_manager.load_game(), "a save with an unknown mode still loads")
	assert_eq(
		save_manager.get_last_mode(),
		GameConstants.MODE_INFINITE_ARENA,
		"an unknown last_mode falls back to Infinite Arena"
	)

	local_multiplayer.reset_joystick_buttons()
	save_manager.load_failed.disconnect(_on_load_failed)
	scene.teardown()
	scene = null
	await wait_physics_frames(1)
	_remove_save_files()

func test_legacy_project_save_migration_is_safe_and_one_shot() -> void:
	_remove_migration_fixture()
	assert_eq(
		SaveManager._legacy_user_data_dir_for("/data/Local Action Sandbox"),
		"/data/Iso Local Sandbox",
		"legacy user data is resolved as a sibling of the current directory"
	)
	assert_eq(
		DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path(MIGRATION_LEGACY_DIR + "/world_cache")
		),
		OK,
		"legacy migration fixture is created"
	)
	_write_absolute_file(
		MIGRATION_LEGACY_DIR + "/savegame.json",
		"legacy-primary"
	)
	_write_absolute_file(
		MIGRATION_LEGACY_DIR + "/savegame.json.bak",
		"legacy-backup"
	)
	_write_absolute_file(
		MIGRATION_LEGACY_DIR + "/world_cache/ignored.cache",
		"must-not-migrate"
	)

	var save_manager := SaveManager.new()
	var migration_error := save_manager._migrate_legacy_save_files_once(
		ProjectSettings.globalize_path(MIGRATION_LEGACY_DIR),
		ProjectSettings.globalize_path(MIGRATION_CURRENT_DIR)
	)
	assert_eq(migration_error, OK, "legacy saves migrate without an I/O error")
	assert_eq(
		_read_absolute_file(MIGRATION_CURRENT_DIR + "/savegame.json"),
		"legacy-primary",
		"the primary save is copied unchanged"
	)
	assert_eq(
		_read_absolute_file(MIGRATION_CURRENT_DIR + "/savegame.json.bak"),
		"legacy-backup",
		"the backup save is copied unchanged"
	)
	assert_true(
		FileAccess.file_exists(MIGRATION_LEGACY_DIR + "/savegame.json"),
		"migration preserves the legacy source save"
	)
	assert_false(
		DirAccess.dir_exists_absolute(
			ProjectSettings.globalize_path(MIGRATION_CURRENT_DIR + "/world_cache")
		),
		"world_cache is deliberately not migrated"
	)
	assert_true(
		FileAccess.file_exists(
			MIGRATION_CURRENT_DIR + "/" + SaveManager.LEGACY_SAVE_MIGRATION_MARKER
		),
		"a completion marker makes the migration genuinely one-shot"
	)

	_write_absolute_file(
		MIGRATION_LEGACY_DIR + "/savegame.json",
		"changed-legacy-primary"
	)
	_write_absolute_file(
		MIGRATION_LEGACY_DIR + "/savegame.json.bak",
		"changed-legacy-backup"
	)
	migration_error = save_manager._migrate_legacy_save_files_once(
		ProjectSettings.globalize_path(MIGRATION_LEGACY_DIR),
		ProjectSettings.globalize_path(MIGRATION_CURRENT_DIR)
	)
	assert_eq(migration_error, OK, "repeated migration remains a no-op")
	assert_eq(
		_read_absolute_file(MIGRATION_CURRENT_DIR + "/savegame.json"),
		"legacy-primary",
		"an existing primary destination is never overwritten"
	)
	assert_eq(
		_read_absolute_file(MIGRATION_CURRENT_DIR + "/savegame.json.bak"),
		"legacy-backup",
		"an existing backup destination is never overwritten"
	)
	DirAccess.remove_absolute(
		ProjectSettings.globalize_path(MIGRATION_CURRENT_DIR + "/savegame.json")
	)
	DirAccess.remove_absolute(
		ProjectSettings.globalize_path(MIGRATION_CURRENT_DIR + "/savegame.json.bak")
	)
	migration_error = save_manager._migrate_legacy_save_files_once(
		ProjectSettings.globalize_path(MIGRATION_LEGACY_DIR),
		ProjectSettings.globalize_path(MIGRATION_CURRENT_DIR)
	)
	assert_eq(migration_error, OK, "completed migration remains a no-op")
	assert_false(
		FileAccess.file_exists(MIGRATION_CURRENT_DIR + "/savegame.json"),
		"a later deletion does not resurrect the legacy primary save"
	)
	assert_false(
		FileAccess.file_exists(MIGRATION_CURRENT_DIR + "/savegame.json.bak"),
		"a later deletion does not resurrect the legacy backup save"
	)

	save_manager.free()
	_remove_migration_fixture()

func _on_load_failed(_path: String, reason: String) -> void:
	_load_failures.append(reason)

func _write_raw_save(content: String) -> void:
	var file := FileAccess.open(TEMP_SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(content)
		file.close()

func _write_absolute_file(path: String, content: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	var file := FileAccess.open(absolute_path, FileAccess.WRITE)
	assert_true(file != null, "%s can be written" % path)
	if file != null:
		file.store_string(content)
		file.close()

func _read_absolute_file(path: String) -> String:
	var absolute_path := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(absolute_path):
		return ""
	return FileAccess.get_file_as_string(absolute_path)

func _remove_save_files() -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		var path := TEMP_SAVE_PATH + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _remove_autosave_files() -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		var path := TEMP_AUTOSAVE_PATH + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _remove_migration_fixture() -> void:
	var files: Array[String] = [
		MIGRATION_CURRENT_DIR + "/savegame.json",
		MIGRATION_CURRENT_DIR + "/savegame.json.bak",
		MIGRATION_CURRENT_DIR + "/savegame.json.migration.tmp",
		MIGRATION_CURRENT_DIR + "/savegame.json.bak.migration.tmp",
		MIGRATION_CURRENT_DIR + "/" + SaveManager.LEGACY_SAVE_MIGRATION_MARKER,
		MIGRATION_CURRENT_DIR + "/" + SaveManager.LEGACY_SAVE_MIGRATION_MARKER + ".tmp",
		MIGRATION_LEGACY_DIR + "/savegame.json",
		MIGRATION_LEGACY_DIR + "/savegame.json.bak",
		MIGRATION_LEGACY_DIR + "/world_cache/ignored.cache"
	]
	for path: String in files:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var directories: Array[String] = [
		MIGRATION_LEGACY_DIR + "/world_cache",
		MIGRATION_CURRENT_DIR,
		MIGRATION_LEGACY_DIR,
		MIGRATION_ROOT
	]
	for path: String in directories:
		if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _new_main_scene_fixture():
	var script := ResourceLoader.load(
		"res://tests/support/main_scene_fixture.gd",
		"",
		ResourceLoader.CACHE_MODE_IGNORE
	) as Script
	assert_true(script != null, "main scene fixture script loads")
	return script.new() if script != null else null
