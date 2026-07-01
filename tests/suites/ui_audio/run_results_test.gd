extends GutTest
## UI/Audio A9 — Schermata dei risultati di fine run su tutte le modalita.
##
## Migra:
##   tests/milestone_17_run_results_smoke_test.gd  (boot main.tscn, survival/dungeon/tower)

const TEMP_SAVE_PATH := "user://ui_audio_run_results_test.json"

func test_run_results_across_modes() -> void:
	_remove_temporary_save()
	var scene = _new_main_scene_fixture()
	assert_true(scene.boot(self), "main scene can be loaded")
	await wait_physics_frames(3)

	var game_mode_manager: GameModeManager = scene.node(&"game_mode_manager") as GameModeManager
	var result_screen: RunResultsScreen = scene.node(&"run_results_screen") as RunResultsScreen
	var run_tracker = scene.node(&"run_session_tracker")
	var progression: ProgressionManager = scene.node(&"progression_manager") as ProgressionManager
	var save_manager: SaveManager = scene.node(&"save_manager") as SaveManager
	var player_manager: PlayerManager = scene.node(&"player_manager") as PlayerManager
	var survival_mode: SurvivalMode = scene.node(&"survival_mode") as SurvivalMode
	var dungeon_mode: DungeonMode = scene.node(&"dungeon_mode") as DungeonMode
	var tower_mode: TowerDefenseMode = scene.node(&"tower_defense_mode") as TowerDefenseMode
	var wave_manager: WaveManager = scene.node(&"wave_manager") as WaveManager
	assert_not_null(game_mode_manager, "game mode manager is available")
	assert_not_null(result_screen, "run results screen is available")
	assert_not_null(run_tracker, "run session tracker is available")
	assert_not_null(progression, "progression manager is available")
	assert_not_null(save_manager, "save manager is available")
	assert_not_null(player_manager, "player manager is available")
	assert_not_null(survival_mode, "survival mode is available")
	assert_not_null(dungeon_mode, "dungeon mode is available")
	assert_not_null(tower_mode, "tower defense mode is available")
	assert_not_null(wave_manager, "wave manager is available")
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
		scene.teardown()
		scene = null
		return

	save_manager.save_path = TEMP_SAVE_PATH
	save_manager.auto_persist_in_headless = true
	save_manager.autosave_progression = false
	save_manager.autosave_mode_selection = false
	wave_manager.initial_delay = 100.0
	game_mode_manager.set_mode(GameConstants.MODE_SURVIVAL)
	await wait_physics_frames(1)
	progression.add_experience(100)
	progression.add_money(7)
	var player := player_manager.players.get(1) as PlayerController
	assert_not_null(player, "player one is available")
	if player == null:
		scene.teardown()
		scene = null
		_remove_temporary_save()
		return
	player.health_component.apply_damage(9999)
	await _poll_idle(func() -> bool: return result_screen.is_open(), 240)

	assert_true(result_screen.is_open(), "survival defeat opens the results screen")
	assert_eq(result_screen.title_label.text, "RUN OVER", "survival uses its explicit end title")
	assert_eq(
		int(result_screen.current_result.get("experience_gained", 0)), 100,
		"results use real session XP delta"
	)
	assert_eq(
		int(result_screen.current_result.get("money_gained", 0)), 7,
		"results use real session money delta"
	)
	assert_true(
		(result_screen.current_result.get("unlocks", []) as Array).has(
			ProgressionManager.FIELD_KIT_UNLOCK
		),
		"results include unlocks earned during the run"
	)
	assert_false(
		game_mode_manager.is_gameplay_active(),
		"gameplay input is disabled behind the results overlay"
	)
	assert_true(result_screen.retry_button.has_focus(), "results give joypad focus to retry")

	var survival_node_id := survival_mode.get_instance_id()
	result_screen._on_retry_pressed()
	await wait_physics_frames(2)
	assert_false(result_screen.is_open(), "retry hides the results screen")
	assert_true(survival_mode.is_running, "retry restarts survival")
	assert_eq(
		survival_mode.get_instance_id(), survival_node_id,
		"retry reuses the registered mode node"
	)
	assert_true(
		player.health_component.max_health == 120
		and player.health_component.current_health == 120,
		"retry resets health without stacking Field Kit"
	)

	player.health_component.apply_damage(9999)
	await _poll_idle(func() -> bool: return result_screen.is_open(), 240)
	result_screen._on_change_mode_pressed()
	await wait_physics_frames(2)
	assert_true(
		game_mode_manager.active_mode_id == GameConstants.MODE_DUNGEON
		and dungeon_mode.is_running,
		"change mode starts the next registered mode"
	)

	dungeon_mode.dungeon_completed.emit(dungeon_mode.run_seed, dungeon_mode.layout.size())
	await wait_physics_frames(1)
	assert_true(result_screen.is_open(), "dungeon completion opens results")
	assert_eq(
		result_screen.title_label.text, "DUNGEON COMPLETE",
		"dungeon victory uses its explicit title"
	)
	result_screen._on_change_mode_pressed()
	await wait_physics_frames(2)
	assert_true(
		game_mode_manager.active_mode_id == GameConstants.MODE_TOWER_DEFENSE
		and tower_mode.is_running,
		"change mode advances from dungeon to defense"
	)

	tower_mode.wave_controller.defeat_run()
	await wait_physics_frames(1)
	assert_true(result_screen.is_open(), "defense failure opens results")
	assert_eq(
		result_screen.title_label.text, "DEFENSE FAILED",
		"tower defense uses its explicit failure title"
	)
	result_screen._on_menu_pressed()
	await wait_physics_frames(1)
	assert_true(
		FileAccess.file_exists(TEMP_SAVE_PATH),
		"results save synchronously before returning to menu"
	)
	assert_eq(
		game_mode_manager.active_mode_id, GameConstants.MODE_MENU,
		"main menu action returns to menu state"
	)
	assert_false(result_screen.is_open(), "menu action hides results")

	scene.teardown()
	scene = null
	await wait_physics_frames(1)
	_remove_temporary_save()

func _remove_temporary_save() -> void:
	for suffix in ["", ".tmp", ".bak"]:
		var path: String = TEMP_SAVE_PATH + str(suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

# La sconfitta survival e l'apertura dei risultati sono guidate da _process (frame
# idle): nel processo GUT condiviso servono piu frame idle del vecchio processo
# dedicato, quindi si attende la condizione invece di un numero fisso di frame.
func _poll_idle(cond: Callable, max_frames: int) -> void:
	for _i in range(max_frames):
		if bool(cond.call()):
			return
		await get_tree().process_frame
func _new_main_scene_fixture():
	var script := ResourceLoader.load(
		"res://tests/support/main_scene_fixture.gd",
		"",
		ResourceLoader.CACHE_MODE_IGNORE
	) as Script
	assert_true(script != null, "main scene fixture script loads")
	return script.new() if script != null else null
