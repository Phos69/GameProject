extends SceneTree

var failures: PackedStringArray = []
var temporary_save_path: String = "user://milestone_9_smoke_test.json"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_remove_temporary_save()
	var main_scene := load("res://game/main/main.tscn") as PackedScene
	_expect(main_scene != null, "main scene can be loaded")
	if main_scene == null:
		_finish()
		return

	var main := main_scene.instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	await process_frame

	var game_mode_manager := get_first_node_in_group(
		"game_mode_manager"
	) as GameModeManager
	var main_menu := get_first_node_in_group("main_menu") as MainMenu
	var save_manager := get_first_node_in_group("save_manager") as SaveManager
	var progression := get_first_node_in_group(
		"progression_manager"
	) as ProgressionManager
	var survival_mode := get_first_node_in_group("survival_mode") as SurvivalMode
	var dungeon_mode := get_first_node_in_group("dungeon_mode") as DungeonMode
	var hud := get_first_node_in_group("hud_manager") as HUDManager
	var audio_manager := get_first_node_in_group("audio_manager") as AudioManager

	_expect(game_mode_manager != null, "game mode manager is available")
	_expect(main_menu != null, "main menu is available")
	_expect(save_manager != null, "save manager is available")
	_expect(progression != null, "progression manager is available")
	_expect(survival_mode != null, "survival mode is available")
	_expect(dungeon_mode != null, "dungeon mode is available")
	_expect(hud != null, "HUD manager is available")
	_expect(audio_manager != null, "audio manager is available")
	if (
		game_mode_manager == null
		or main_menu == null
		or save_manager == null
		or progression == null
		or survival_mode == null
		or dungeon_mode == null
		or hud == null
		or audio_manager == null
	):
		_finish()
		return

	_expect(
		game_mode_manager.active_mode_id == GameConstants.MODE_MENU,
		"the project starts in menu state"
	)
	_expect(main_menu.is_open(), "the main menu is visible at startup")
	_expect(not hud.visible, "the gameplay HUD is hidden in the menu")
	_expect(not survival_mode.is_running, "survival does not auto-start behind the menu")
	_expect(
		audio_manager.ui_player != null,
		"procedural UI audio feedback is initialized"
	)

	save_manager.save_path = temporary_save_path
	save_manager.auto_persist_in_headless = true
	progression.add_money(5)
	await process_frame
	await process_frame
	_expect(
		FileAccess.file_exists(temporary_save_path),
		"progression changes trigger autosave"
	)
	save_manager.autosave_progression = false
	save_manager.autosave_mode_selection = false
	progression.restore_save_data({
		"level": 3,
		"experience": 45,
		"money": 70
	})
	save_manager.set_last_mode(GameConstants.MODE_DUNGEON)
	_expect(save_manager.save_game(), "progression save is written")

	progression.restore_save_data({
		"level": 1,
		"experience": 0,
		"money": 0
	})
	save_manager.set_last_mode(GameConstants.MODE_SURVIVAL)
	_expect(save_manager.load_game(), "progression save is loaded")
	_expect(progression.level == 3, "save restores party level")
	_expect(progression.experience == 45, "save restores party experience")
	_expect(progression.money == 70, "save restores party money")
	_expect(
		save_manager.get_last_mode() == GameConstants.MODE_DUNGEON,
		"save restores the last selected mode"
	)

	var invalid_file := FileAccess.open(temporary_save_path, FileAccess.WRITE)
	invalid_file.store_string('{"version":999,"party":{}}')
	invalid_file.close()
	_expect(not save_manager.load_game(), "unsupported save versions are rejected")
	_expect(
		progression.level == 3 and progression.money == 70,
		"rejected saves leave runtime progression unchanged"
	)
	_expect(save_manager.save_game(), "valid save can replace rejected data")

	_expect(
		main_menu.start_selected_mode(save_manager.get_last_mode()),
		"menu starts the saved mode"
	)
	await process_frame
	await physics_frame
	_expect(
		game_mode_manager.active_mode_id == GameConstants.MODE_DUNGEON,
		"mode selection updates the active mode"
	)
	_expect(dungeon_mode.is_running, "dungeon starts from the main menu")
	_expect(not main_menu.is_open(), "menu hides after mode selection")
	_expect(hud.visible, "gameplay HUD becomes visible after mode selection")

	main_menu.open_menu()
	await process_frame
	_expect(main_menu.is_open(), "Escape flow can return to the main menu")
	_expect(not dungeon_mode.is_running, "returning to menu stops the active mode")
	_expect(
		game_mode_manager.active_mode_id == GameConstants.MODE_MENU,
		"returning to menu restores menu state"
	)
	_expect(
		FileAccess.file_exists("res://export_presets.cfg"),
		"desktop export preset is present"
	)

	_finish()

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _remove_temporary_save() -> void:
	if FileAccess.file_exists(temporary_save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary_save_path))
	var temporary_path := temporary_save_path + ".tmp"
	if FileAccess.file_exists(temporary_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary_path))
	var backup_path := temporary_save_path + ".bak"
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(backup_path))

func _finish() -> void:
	_remove_temporary_save()
	if failures.is_empty():
		print("MILESTONE_9_SMOKE_TEST: PASS")
		quit(0)
		return
	print("MILESTONE_9_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
