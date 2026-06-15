extends SceneTree

var failures: PackedStringArray = []
var temporary_save_path: String = "user://milestone_17_results_test.json"

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
	var result_screen := get_first_node_in_group(
		"run_results_screen"
	) as RunResultsScreen
	var run_tracker: Node = get_first_node_in_group("run_session_tracker")
	var progression := get_first_node_in_group(
		"progression_manager"
	) as ProgressionManager
	var save_manager := get_first_node_in_group("save_manager") as SaveManager
	var player_manager := get_first_node_in_group(
		"player_manager"
	) as PlayerManager
	var survival_mode := get_first_node_in_group(
		"survival_mode"
	) as SurvivalMode
	var dungeon_mode := get_first_node_in_group("dungeon_mode") as DungeonMode
	var tower_mode := get_first_node_in_group(
		"tower_defense_mode"
	) as TowerDefenseMode
	var wave_manager := get_first_node_in_group("wave_manager") as WaveManager
	_expect(game_mode_manager != null, "game mode manager is available")
	_expect(result_screen != null, "run results screen is available")
	_expect(run_tracker != null, "run session tracker is available")
	_expect(progression != null, "progression manager is available")
	_expect(save_manager != null, "save manager is available")
	_expect(player_manager != null, "player manager is available")
	_expect(survival_mode != null, "survival mode is available")
	_expect(dungeon_mode != null, "dungeon mode is available")
	_expect(tower_mode != null, "tower defense mode is available")
	_expect(wave_manager != null, "wave manager is available")
	if (
		game_mode_manager == null
		or result_screen == null
		or run_tracker == null
		or progression == null
		or save_manager == null
		or player_manager == null
		or survival_mode == null
		or dungeon_mode == null
		or tower_mode == null
		or wave_manager == null
	):
		_finish()
		return

	save_manager.save_path = temporary_save_path
	save_manager.auto_persist_in_headless = true
	save_manager.autosave_progression = false
	save_manager.autosave_mode_selection = false
	wave_manager.initial_delay = 100.0
	game_mode_manager.set_mode(GameConstants.MODE_SURVIVAL)
	await process_frame
	progression.add_experience(100)
	progression.add_money(7)
	var player := player_manager.players.get(1) as PlayerController
	_expect(player != null, "player one is available")
	if player == null:
		_finish()
		return
	player.health_component.apply_damage(9999)
	await process_frame
	await process_frame

	_expect(result_screen.is_open(), "survival defeat opens the results screen")
	_expect(
		result_screen.title_label.text == "RUN OVER",
		"survival uses its explicit end title"
	)
	_expect(
		int(result_screen.current_result.get("experience_gained", 0)) == 100,
		"results use real session XP delta"
	)
	_expect(
		int(result_screen.current_result.get("money_gained", 0)) == 7,
		"results use real session money delta"
	)
	_expect(
		(result_screen.current_result.get("unlocks", []) as Array).has(
			ProgressionManager.FIELD_KIT_UNLOCK
		),
		"results include unlocks earned during the run"
	)
	_expect(
		not game_mode_manager.is_gameplay_active(),
		"gameplay input is disabled behind the results overlay"
	)
	_expect(
		result_screen.retry_button.has_focus(),
		"results give joypad focus to retry"
	)

	var survival_node_id := survival_mode.get_instance_id()
	result_screen._on_retry_pressed()
	await process_frame
	await process_frame
	_expect(not result_screen.is_open(), "retry hides the results screen")
	_expect(survival_mode.is_running, "retry restarts survival")
	_expect(
		survival_mode.get_instance_id() == survival_node_id,
		"retry reuses the registered mode node"
	)
	_expect(
		player.health_component.max_health == 120
		and player.health_component.current_health == 120,
		"retry resets health without stacking Field Kit"
	)

	player.health_component.apply_damage(9999)
	await process_frame
	await process_frame
	result_screen._on_change_mode_pressed()
	await process_frame
	await process_frame
	_expect(
		game_mode_manager.active_mode_id == GameConstants.MODE_DUNGEON
		and dungeon_mode.is_running,
		"change mode starts the next registered mode"
	)

	dungeon_mode.dungeon_completed.emit(dungeon_mode.run_seed, dungeon_mode.layout.size())
	await process_frame
	_expect(result_screen.is_open(), "dungeon completion opens results")
	_expect(
		result_screen.title_label.text == "DUNGEON COMPLETE",
		"dungeon victory uses its explicit title"
	)
	result_screen._on_change_mode_pressed()
	await process_frame
	await process_frame
	_expect(
		game_mode_manager.active_mode_id == GameConstants.MODE_TOWER_DEFENSE
		and tower_mode.is_running,
		"change mode advances from dungeon to defense"
	)

	tower_mode.wave_controller.defeat_run()
	await process_frame
	_expect(result_screen.is_open(), "defense failure opens results")
	_expect(
		result_screen.title_label.text == "DEFENSE FAILED",
		"tower defense uses its explicit failure title"
	)
	result_screen._on_menu_pressed()
	await process_frame
	_expect(
		FileAccess.file_exists(temporary_save_path),
		"results save synchronously before returning to menu"
	)
	_expect(
		game_mode_manager.active_mode_id == GameConstants.MODE_MENU,
		"main menu action returns to menu state"
	)
	_expect(not result_screen.is_open(), "menu action hides results")

	_finish()

func _remove_temporary_save() -> void:
	var absolute_path := ProjectSettings.globalize_path(temporary_save_path)
	if FileAccess.file_exists(temporary_save_path):
		DirAccess.remove_absolute(absolute_path)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	_remove_temporary_save()
	if failures.is_empty():
		print("MILESTONE_17_RUN_RESULTS_SMOKE_TEST: PASS")
		quit(0)
		return
	print(
		"MILESTONE_17_RUN_RESULTS_SMOKE_TEST: FAIL (%d)"
		% failures.size()
	)
	quit(1)
