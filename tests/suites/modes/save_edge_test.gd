extends GutTest
## Modes A8 — Edge di persistenza del SaveManager (QA-001).
##
## Copre i rami non toccati dal flusso principale (encounters_test):
## fallback sul file .bak quando il salvataggio principale manca, rifiuto di
## JSON corrotti/root non-dizionario/party non valido senza toccare lo stato
## runtime, pulizia dei file temporanei del write atomico, sanitizzazione del
## last_mode sconosciuto e roundtrip dei binding join/leave del multiplayer.

const TEMP_SAVE_PATH := "user://qa_save_edge_test.json"

var _load_failures: Array[String] = []

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

func _on_load_failed(_path: String, reason: String) -> void:
	_load_failures.append(reason)

func _write_raw_save(content: String) -> void:
	var file := FileAccess.open(TEMP_SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(content)
		file.close()

func _remove_save_files() -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		var path := TEMP_SAVE_PATH + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _new_main_scene_fixture():
	var script := ResourceLoader.load(
		"res://tests/support/main_scene_fixture.gd",
		"",
		ResourceLoader.CACHE_MODE_IGNORE
	) as Script
	assert_true(script != null, "main scene fixture script loads")
	return script.new() if script != null else null
