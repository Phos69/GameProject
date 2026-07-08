extends GutTest
## Modes A8 — Lifecycle menu -> run -> menu su piu' modalita' (QA-001).
##
## Copre il churn di modalita' nella STESSA scena (complementare al soak che
## ricrea main.tscn da zero): ogni ritorno al menu deve fermare la modalita'
## attiva e pulire i suoi contenuti (nemici della wave, nemici di stanza,
## torri e arena TD), il roster player resta stabile su [1] e ogni nuova run
## riparte con la vita piena.

func test_mode_cycling_cleans_up() -> void:
	var scene = _new_main_scene_fixture()
	assert_true(scene.boot(self), "main scene can be loaded")
	await wait_physics_frames(3)

	var game_mode_manager: GameModeManager = scene.node(&"game_mode_manager") as GameModeManager
	var main_menu: MainMenu = scene.node(&"main_menu") as MainMenu
	var player_manager: PlayerManager = scene.node(&"player_manager") as PlayerManager
	var wave_manager: WaveManager = scene.node(&"wave_manager") as WaveManager
	var survival_mode: SurvivalMode = scene.node(&"survival_mode") as SurvivalMode
	var dungeon_mode: DungeonMode = scene.node(&"dungeon_mode") as DungeonMode
	var tower_mode: TowerDefenseMode = scene.node(&"tower_defense_mode") as TowerDefenseMode
	var hud: HUDManager = scene.node(&"hud_manager") as HUDManager
	if game_mode_manager == null or main_menu == null or player_manager == null or wave_manager == null or survival_mode == null or dungeon_mode == null or tower_mode == null or hud == null:
		assert_true(false, "lifecycle systems are available")
		scene.teardown()
		scene = null
		return

	# --- ciclo 1: survival con una wave reale, poi menu -----------------------
	assert_true(scene.start_survival(), "cycle 1 starts survival")
	await _wait_for_hud(hud, true)
	_assert_gameplay_state(game_mode_manager, main_menu, hud, player_manager, "cycle 1 survival")
	wave_manager.spawn_interval = 0.05
	wave_manager.base_enemy_count = 2
	wave_manager.boss_wave_interval = 50
	wave_manager.start_next_wave()
	var spawn_frames := 0
	while wave_manager.get_active_wave_enemies().size() < 2 and spawn_frames < 300:
		await wait_physics_frames(1)
		spawn_frames += 1
	assert_gt(wave_manager.get_active_wave_enemies().size(), 0, "cycle 1 spawns live wave enemies")
	var player_one := player_manager.players.get(1) as PlayerController
	if player_one != null:
		player_one.health_component.apply_damage(15)
	main_menu.open_menu()
	await _wait_for_hud(hud, false)
	_assert_menu_state(game_mode_manager, main_menu, hud, player_manager, survival_mode, dungeon_mode, tower_mode, "cycle 1")
	assert_false(wave_manager.run_active, "cycle 1: the wave run stops with the mode")
	assert_eq(wave_manager.get_enemies_remaining(), 0, "cycle 1: no wave enemies are tracked in the menu")
	assert_eq(scene.nodes(&"enemies").size(), 0, "cycle 1: no enemy nodes survive the return to menu")

	# --- ciclo 2: dungeon (stanze con nemici propri), poi menu -----------------
	assert_true(game_mode_manager.set_mode(GameConstants.MODE_DUNGEON), "cycle 2 starts the dungeon")
	await _wait_for_hud(hud, true)
	_assert_gameplay_state(game_mode_manager, main_menu, hud, player_manager, "cycle 2 dungeon")
	assert_true(dungeon_mode.is_running, "cycle 2: dungeon is running")
	main_menu.open_menu()
	await _wait_for_hud(hud, false)
	_assert_menu_state(game_mode_manager, main_menu, hud, player_manager, survival_mode, dungeon_mode, tower_mode, "cycle 2")
	assert_eq(scene.nodes(&"enemies").size(), 0, "cycle 2: dungeon room enemies are cleared in the menu")

	# --- ciclo 3: tower defense con una torre costruita, poi menu --------------
	assert_true(
		game_mode_manager.set_mode(
			GameConstants.MODE_TOWER_DEFENSE,
			{"initial_delay": 100.0, "starting_credits": 75}
		),
		"cycle 3 starts tower defense"
	)
	await _wait_for_hud(hud, true)
	_assert_gameplay_state(game_mode_manager, main_menu, hud, player_manager, "cycle 3 tower defense")
	var tower := tower_mode.try_build_at_slot(&"slot_b")
	assert_not_null(tower, "cycle 3: a tower can be built before leaving")
	main_menu.open_menu()
	await _wait_for_hud(hud, false)
	_assert_menu_state(game_mode_manager, main_menu, hud, player_manager, survival_mode, dungeon_mode, tower_mode, "cycle 3")
	assert_eq(scene.nodes(&"defense_towers").size(), 0, "cycle 3: towers are cleared in the menu")
	assert_eq(scene.nodes(&"enemies").size(), 0, "cycle 3: no TD enemies survive the menu")

	# --- ciclo 4: nuova run survival, la vita riparte piena --------------------
	assert_true(scene.start_survival(), "cycle 4 restarts survival")
	await _wait_for_hud(hud, true)
	_assert_gameplay_state(game_mode_manager, main_menu, hud, player_manager, "cycle 4 survival")
	var player_one_restarted := player_manager.players.get(1) as PlayerController
	assert_not_null(player_one_restarted, "cycle 4: player one is available")
	if player_one_restarted != null:
		assert_eq(
			player_one_restarted.health_component.current_health,
			player_one_restarted.health_component.max_health,
			"cycle 4: a new run refills player health"
		)
	main_menu.open_menu()
	await _wait_for_hud(hud, false)
	_assert_menu_state(game_mode_manager, main_menu, hud, player_manager, survival_mode, dungeon_mode, tower_mode, "cycle 4")

	scene.teardown()
	scene = null
	await wait_physics_frames(1)

# La visibilita' dell'HUD viene aggiornata in _process (e il mondo builda in
# modo asincrono), quindi lo stato atteso va atteso con un polling invece che
# con un numero fisso di frame.
func _wait_for_hud(hud: HUDManager, expected: bool, max_frames: int = 180) -> void:
	var frames := 0
	while hud.visible != expected and frames < max_frames:
		await wait_physics_frames(1)
		frames += 1
	await wait_physics_frames(1)

func _assert_gameplay_state(
	game_mode_manager: GameModeManager,
	main_menu: MainMenu,
	hud: HUDManager,
	player_manager: PlayerManager,
	label: String
) -> void:
	assert_ne(game_mode_manager.active_mode_id, GameConstants.MODE_MENU, "%s: a gameplay mode is active" % label)
	assert_false(main_menu.is_open(), "%s: the menu is hidden during gameplay" % label)
	assert_true(hud.visible, "%s: the HUD is visible during gameplay" % label)
	assert_true(player_manager.players.has(1), "%s: player one is spawned" % label)

func _assert_menu_state(
	game_mode_manager: GameModeManager,
	main_menu: MainMenu,
	hud: HUDManager,
	player_manager: PlayerManager,
	survival_mode: SurvivalMode,
	dungeon_mode: DungeonMode,
	tower_mode: TowerDefenseMode,
	label: String
) -> void:
	assert_eq(game_mode_manager.active_mode_id, GameConstants.MODE_MENU, "%s: returning to menu restores menu state" % label)
	assert_true(main_menu.is_open(), "%s: the menu is open" % label)
	assert_false(hud.visible, "%s: the HUD hides in the menu" % label)
	assert_false(survival_mode.is_running, "%s: survival is stopped in the menu" % label)
	assert_false(dungeon_mode.is_running, "%s: dungeon is stopped in the menu" % label)
	assert_false(tower_mode.is_running, "%s: tower defense is stopped in the menu" % label)
	assert_eq(player_manager.players.size(), 1, "%s: the player roster stays stable" % label)

func _new_main_scene_fixture():
	var script := ResourceLoader.load(
		"res://tests/support/main_scene_fixture.gd",
		"",
		ResourceLoader.CACHE_MODE_IGNORE
	) as Script
	assert_true(script != null, "main scene fixture script loads")
	return script.new() if script != null else null
