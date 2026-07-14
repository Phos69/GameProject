extends GutTest
## Modes A8 — Modalità zombie: revamp foundation, market, contratto mondo,
## infinite arena di default.
##
## Migra e accorpa:
##   tests/zombie_revamp_foundation_smoke_test.gd        (main.tscn)
##   tests/zombie_market_smoke_test.gd                   (main.tscn)
##   tests/zombie_survival_world_contract_smoke_test.gd  (sintetico)
##   tests/infinite_arena_default_mode_smoke_test.gd     (main.tscn, async)

const IsoGridConfig = preload("res://game/core/iso_grid_config.gd")

var _async_world_ready: bool = false

# --- foundation: biome/wave/spawner + wave loop (zombie_revamp_foundation) ---

func test_zombie_revamp_foundation() -> void:
	var scene = _new_main_scene_fixture()
	assert_true(scene.boot(self), "main scene can be loaded")
	await wait_physics_frames(2)
	var game_mode_manager: GameModeManager = scene.node(&"game_mode_manager") as GameModeManager
	var survival_mode: SurvivalMode = scene.node(&"survival_mode") as SurvivalMode
	var wave_manager: WaveManager = scene.node(&"wave_manager") as WaveManager
	var health_system: HealthSystem = scene.node(&"health_system") as HealthSystem
	var biome_manager = scene.node(&"biome_manager")
	var wave_director = scene.node(&"wave_director")
	var zombie_spawner = scene.node(&"zombie_spawner")
	var zombie_controller = scene.node(&"zombie_mode_controller")
	var streamer: WorldRegionStreamer = scene.node(&"world_region_streamer") as WorldRegionStreamer
	if game_mode_manager == null or survival_mode == null or wave_manager == null or health_system == null or biome_manager == null or wave_director == null or zombie_spawner == null or zombie_controller == null or streamer == null:
		assert_true(false, "revamp foundation systems are available")
		scene.teardown()
		scene = null
		return

	assert_gte(biome_manager.get_available_biome_ids().size(), 5, "biome manager registers the planned biome set")
	assert_eq(biome_manager.get_current_biome_id(), &"infected_plains", "initial biome defaults to Pianura Infetta")
	assert_eq(wave_director.get_enemy_id_for_spawn(1, 0, 3), &"survival_zombie", "first wave resolves to base zombies")

	var visible_rect: Rect2 = zombie_spawner.get_visible_world_rect()
	assert_gt(visible_rect.size.x, 0.0, "spawner can read the camera visible rect")
	assert_false(visible_rect.has_point(zombie_spawner.get_spawn_position(0)), "spawner previews positions outside the current camera view")

	survival_mode.stop_mode()
	await wait_physics_frames(1)
	wave_manager.initial_delay = 0.0
	wave_manager.intermission_duration = 100.0
	wave_manager.spawn_interval = 0.01
	wave_manager.base_enemy_count = 2
	wave_manager.enemy_count_growth = 0
	wave_manager.boss_wave_interval = 99
	survival_mode.boss_wave_interval = 99

	assert_true(game_mode_manager.set_mode(
		GameConstants.MODE_SURVIVAL,
		{"async_world_build": true}
	), "survival mode starts through the game mode manager")
	assert_true(await _await_world_ready(zombie_controller),
		"standard survival waits for camera and prefetch chunks before readiness")
	assert_true(streamer.is_area_ready(),
		"the loading screen closes only after the active camera area is ready")
	assert_true(await _wait_for_wave_combat(wave_manager, 1), "first wave reaches combat")
	assert_eq(biome_manager.get_current_biome_id(), &"infected_plains", "survival run starts from the starting biome")
	assert_eq(wave_manager.current_wave_biome_id, &"infected_plains", "wave manager records the biome used for the wave")
	var wave_enemies := wave_manager.get_active_wave_enemies()
	assert_eq(wave_enemies.size(), 2, "wave one spawns through the delegated systems")
	for enemy in wave_enemies:
		if enemy is Node2D:
			assert_false(visible_rect.has_point((enemy as Node2D).global_position), "spawned zombie enters from outside the initial camera view")
		health_system.apply_damage(enemy, 9999)
	assert_true(await _wait_for_wave_completed(wave_manager, 1), "delegated wave completes")

	survival_mode.stop_mode()
	scene.teardown()
	scene = null
	await wait_physics_frames(1)

# --- market post-boss (zombie_market) ---------------------------------------

func test_zombie_market() -> void:
	var scene = _new_main_scene_fixture()
	assert_true(scene.boot(self), "main scene loads with the survival market")
	await wait_physics_frames(2)
	var game_mode_manager: GameModeManager = scene.node(&"game_mode_manager") as GameModeManager
	var survival_mode: SurvivalMode = scene.node(&"survival_mode") as SurvivalMode
	var wave_manager: WaveManager = scene.node(&"wave_manager") as WaveManager
	var market: SurvivalMarketController = scene.node(&"survival_market_controller") as SurvivalMarketController
	var market_ui: SurvivalMarketUI = scene.node(&"survival_market_ui") as SurvivalMarketUI
	var progression: ProgressionManager = scene.node(&"progression_manager") as ProgressionManager
	var player_manager: PlayerManager = scene.node(&"player_manager") as PlayerManager
	var multiplayer: LocalMultiplayerManager = scene.node(&"local_multiplayer_manager") as LocalMultiplayerManager
	var health_system: HealthSystem = scene.node(&"health_system") as HealthSystem
	if game_mode_manager == null or survival_mode == null or wave_manager == null or market == null or market_ui == null or progression == null or player_manager == null or multiplayer == null or health_system == null:
		assert_true(false, "market systems are available")
		scene.teardown()
		scene = null
		return

	survival_mode.stop_mode()
	multiplayer.activate_slot(2)
	await wait_physics_frames(1)
	var player_one := player_manager.players.get(1) as PlayerController
	var player_two := player_manager.players.get(2) as PlayerController
	if player_one == null or player_two == null:
		_teardown_market(scene, multiplayer)
		return

	wave_manager.initial_delay = 0.0
	wave_manager.intermission_duration = 0.01
	wave_manager.spawn_interval = 0.001
	wave_manager.base_enemy_count = 1
	wave_manager.enemy_count_growth = 0
	wave_manager.boss_wave_interval = 5
	survival_mode.boss_wave_interval = 5
	market.set_random_seed(20260620)
	progression.add_money(220)
	assert_true(game_mode_manager.set_mode(GameConstants.MODE_SURVIVAL), "survival run starts")
	var player_one_health := player_one.get_node("HealthComponent") as HealthComponent
	health_system.apply_damage(player_one, 90)

	assert_true(await _advance_until_market(wave_manager, market, health_system), "waves 1-4 complete and the market opens only after boss wave 5")
	assert_eq(wave_manager.current_wave, 5, "market belongs to wave 5")
	assert_true(market.is_market_open, "market phase is active")
	assert_true(wave_manager.state == WaveManager.State.REWARD and wave_manager.is_next_wave_blocked(), "wave progression remains blocked in reward state during the market")
	assert_eq(wave_manager.get_enemies_remaining(), 0, "no zombie or boss remains and no new spawn starts during the market")
	assert_true(not player_one.gameplay_input_enabled and not player_two.gameplay_input_enabled, "combat input is disabled for every active player")
	assert_true(player_one_health.has_invulnerability_source(SurvivalMarketController.MARKET_INVULNERABILITY), "players cannot take combat damage during the market phase")
	assert_true(market_ui.visible, "market UI is visible")
	assert_true(market_ui.wallet_label.text.contains(str(progression.money)), "market UI always exposes the shared wallet total")

	var offers := market.get_weapon_offers()
	var unique_ids: Dictionary = {}
	for offer in offers:
		var weapon_id := StringName(offer.get("weapon_id", &""))
		unique_ids[weapon_id] = true
		assert_not_null(WeaponCatalog.get_definition(weapon_id), "weapon offer comes from the existing catalog")
		assert_true(not str(offer.get("display_name", "")).is_empty() and not StringName(offer.get("category", &"")).is_empty() and not StringName(offer.get("rarity", &"")).is_empty() and int(offer.get("cost", 0)) > 0 and str(offer.get("stats_text", "")).contains("DMG"), "offer exposes name, category, rarity, price and readable stats")
	assert_true(offers.size() == 4 and unique_ids.size() == 4, "market rolls four unique weapons")

	var wallet_before_heal := progression.money
	var health_before := player_one_health.current_health
	assert_true(market.try_purchase(1, SurvivalMarketController.ITEM_HEAL_SMALL), "P1 buys health for itself")
	assert_true(player_one_health.current_health > health_before and player_one_health.current_health <= player_one_health.max_health, "health purchase heals without exceeding max HP")
	assert_eq(progression.money, wallet_before_heal - market.heal_small_cost, "health purchase deducts the shared wallet exactly once")

	if not offers.is_empty():
		var weapon_offer := offers[0]
		var weapon_id := StringName(weapon_offer.get("weapon_id", &""))
		var wallet_before_weapon := progression.money
		assert_true(market.try_purchase(1, weapon_id), "P1 buys a catalog weapon")
		var weapon_one := player_one.get_node("WeaponSystem") as WeaponSystem
		var weapon_two := player_two.get_node("WeaponSystem") as WeaponSystem
		assert_true(weapon_one.has_weapon(weapon_id) and not weapon_two.has_weapon(weapon_id), "purchased weapon is assigned only to the buying player")
		assert_eq(progression.money, wallet_before_weapon - int(weapon_offer.get("cost", 0)), "weapon purchase uses the shared wallet")
		var refill_weapon := weapon_offer.get("weapon_data") as WeaponData
		if refill_weapon == null or refill_weapon.infinite_reserve_ammo:
			refill_weapon = WeaponCatalog.get_definition(&"tactical_carbine")
			weapon_one.add_weapon(refill_weapon, true)
		else:
			weapon_one.select_weapon(refill_weapon.weapon_id)
		weapon_one.current_ammo = 0
		weapon_one.reserve_ammo = 0
		var wallet_before_ammo := progression.money
		assert_true(market.try_purchase(1, SurvivalMarketController.ITEM_AMMO_ACTIVE), "P1 refills only its equipped weapon")
		assert_true(weapon_one.current_ammo == refill_weapon.magazine_size and weapon_one.reserve_ammo == refill_weapon.starting_reserve_ammo, "equipped ammo purchase restores magazine and reserve")
		assert_eq(progression.money, wallet_before_ammo - market.ammo_active_cost, "ammo purchase deducts its configured price")

	progression.try_spend_money(progression.money)
	var denied_id := StringName((offers[1] if offers.size() > 1 else {}).get("weapon_id", &""))
	var player_two_weapons := player_two.get_node("WeaponSystem") as WeaponSystem
	assert_true(not market.try_purchase(2, denied_id) and not player_two_weapons.has_weapon(denied_id) and progression.money == 0, "insufficient shared funds deny the purchase without assigning the weapon")
	progression.add_money(100)
	player_one_health.current_health = player_one_health.max_health
	var wallet_at_full_health := progression.money
	assert_true(not market.try_purchase(1, SurvivalMarketController.ITEM_HEAL_SMALL) and progression.money == wallet_at_full_health, "full HP denies healing without wasting money")

	assert_true(market.set_player_ready(1, true), "P1 marks itself ready")
	assert_true(market.is_market_open, "one player cannot close the market for everyone")
	assert_true(market.set_player_ready(2, true), "P2 marks itself ready")
	assert_false(market.is_market_open, "all living players ready close the market")
	assert_true(await _wait_for_wave_running(wave_manager, 6), "closing the market resumes the run at wave 6")
	assert_true(player_one.gameplay_input_enabled and player_two.gameplay_input_enabled and not player_one_health.has_invulnerability_source(SurvivalMarketController.MARKET_INVULNERABILITY), "closing the market restores combat state")
	assert_true(market.should_open_after_wave(10) and market.should_open_after_wave(15) and not market.should_open_after_wave(6), "the recurring schedule targets waves 10, 15 and later multiples of five")
	wave_manager.wave_completed.emit(5)
	await wait_physics_frames(1)
	assert_false(market.is_market_open, "processed boss wave cannot reopen its market")

	survival_mode.stop_mode()
	assert_true(not market.is_run_active and not market.is_market_open and market.get_weapon_offers().is_empty(), "new-run cleanup resets market state and offers")
	_teardown_market(scene, multiplayer)

func _teardown_market(scene, multiplayer: LocalMultiplayerManager) -> void:
	if multiplayer != null:
		multiplayer.deactivate_slot(2)
	scene.teardown()
	scene = null
	await wait_physics_frames(1)

# --- contratto del mondo survival (zombie_survival_world_contract) ----------

func test_world_contract() -> void:
	var harness := Node.new()
	add_child(harness)
	var biome_manager := BiomeManager.new()
	biome_manager.name = "BiomeManager"
	harness.add_child(biome_manager)
	var controller := ZombieModeController.new()
	controller.name = "ZombieModeController"
	controller.biome_manager_path = NodePath("../BiomeManager")
	controller.enable_multi_region_render = false
	harness.add_child(controller)
	await wait_physics_frames(1)

	controller.start_run({})
	_assert_default_survival_world(biome_manager)
	controller.stop_run()

	controller.start_run({"single_biome_arena": true})
	_assert_single_biome_quick_arena(biome_manager)
	controller.stop_run()

	controller.start_run({"single_biome_arena": true, "arena_boundary_mode": "walled"})
	_assert_walled_infinite_arena_profile(biome_manager)
	controller.stop_run()

	controller.start_run({"single_biome_arena": true, "biome_map_width": 2, "biome_map_height": 2})
	assert_eq(biome_manager.get_generated_biome_map().size(), 4, "explicit map dimensions override single-biome arena profile")
	controller.stop_run()

	harness.queue_free()
	await wait_physics_frames(1)

func _assert_default_survival_world(biome_manager: BiomeManager) -> void:
	assert_eq(biome_manager.get_generation_seed(), GameConstants.GOLDEN_WORLD_SEED, "default survival run uses the golden world seed")
	var cells := biome_manager.get_generated_biome_map()
	assert_eq(cells.size(), 9, "default survival generates a 3x3 biome map")
	var graph := biome_manager.get_world_graph()
	assert_true(graph != null and graph.is_graph_connected(), "default survival graph is connected")
	var graph_biomes: Dictionary = {}
	if graph != null:
		for region in graph.get_regions_sorted():
			graph_biomes[region.biome_id] = true
	for required_biome in [&"infected_plains", &"toxic_wastes", &"burning_fields", &"frozen_outskirts", &"drowned_marsh"]:
		assert_true(graph_biomes.has(required_biome), "default survival graph contains %s" % String(required_biome))
	var start_cell := biome_manager.get_current_biome_cell()
	assert_true(start_cell != null and start_cell.biome_id == &"infected_plains", "default survival starts from infected_plains")
	var connected_border_count := 0
	var outer_fall_count := 0
	for cell in cells:
		for side in BiomeCell.SIDES:
			if cell.has_neighbor(side):
				connected_border_count += 1
			elif cell.get_border(side) == BiomeCell.BorderType.FALL:
				outer_fall_count += 1
	assert_gt(connected_border_count, 0, "default survival contains connected biome passages")
	assert_gt(outer_fall_count, 0, "default survival keeps fall boundary on the outer world edge")
	if start_cell != null and start_cell.generated_layout != null:
		assert_eq(
			start_cell.generated_layout.perimeter_visual_style,
			BiomeEnvironmentLayout.PERIMETER_VISUAL_RAISED_CLIFF,
			"default survival renders biome-divider walls as raised cliffs"
		)

func _assert_single_biome_quick_arena(biome_manager: BiomeManager) -> void:
	assert_eq(biome_manager.get_generated_biome_map().size(), 1, "quick arena profile generates one cell")
	var start_cell := biome_manager.get_current_biome_cell()
	assert_true(start_cell != null and start_cell.biome_id == &"infected_plains", "quick arena starts from infected_plains")
	if start_cell == null:
		return
	assert_true(start_cell.passages.is_empty(), "quick arena has no inter-region passages")
	for side in BiomeCell.SIDES:
		assert_eq(start_cell.get_border(side), BiomeCell.BorderType.FALL, "quick arena %s border falls to void" % String(side))

func _assert_walled_infinite_arena_profile(biome_manager: BiomeManager) -> void:
	assert_eq(biome_manager.get_generated_biome_map().size(), 1, "walled arena profile generates one cell")
	var start_cell := biome_manager.get_current_biome_cell()
	assert_true(start_cell != null and start_cell.biome_id == &"infected_plains", "walled arena starts from infected_plains")
	if start_cell == null:
		return
	assert_true(start_cell.passages.is_empty(), "walled arena has no inter-region passages")
	for side in BiomeCell.SIDES:
		assert_eq(start_cell.get_border(side), BiomeCell.BorderType.BLOCKED, "walled arena %s border is blocked by walls" % String(side))
	var layout := start_cell.generated_layout
	assert_not_null(layout, "walled arena generates terrain layout")
	if layout == null:
		return
	assert_gt(layout.wall_segment_rects.size(), 0, "walled arena emits perimeter wall segments")
	_assert_no_perimeter_fall_zones(layout, "walled arena")
	_assert_raised_cliff_layout(layout)

# --- infinite arena come modalità di default (infinite_arena_default_mode) ---

func test_infinite_arena_default() -> void:
	var scene = _new_main_scene_fixture()
	assert_true(scene.boot(self), "main scene can be loaded")
	await wait_physics_frames(2)
	await wait_physics_frames(1)
	var game_mode_manager: GameModeManager = scene.node(&"game_mode_manager") as GameModeManager
	var main_menu: MainMenu = scene.node(&"main_menu") as MainMenu
	var save_manager: SaveManager = scene.node(&"save_manager") as SaveManager
	var infinite_arena_mode = scene.node(&"infinite_arena_mode")
	var survival_mode: SurvivalMode = scene.node(&"survival_mode") as SurvivalMode
	var biome_manager: BiomeManager = scene.node(&"biome_manager") as BiomeManager
	var world_runtime: WorldRuntime = scene.node(&"world_runtime") as WorldRuntime
	var streamer: WorldRegionStreamer = scene.node(&"world_region_streamer") as WorldRegionStreamer
	var hud: HUDManager = scene.node(&"hud_manager") as HUDManager
	if game_mode_manager == null or main_menu == null or save_manager == null or infinite_arena_mode == null or survival_mode == null or biome_manager == null or world_runtime == null or streamer == null:
		assert_true(false, "infinite arena systems are available")
		scene.teardown()
		scene = null
		return

	assert_true(game_mode_manager.has_mode(GameConstants.MODE_INFINITE_ARENA), "game mode manager exposes infinite arena")
	assert_true(game_mode_manager.has_mode(GameConstants.MODE_SURVIVAL), "game mode manager keeps zombie survival available")
	assert_true(main_menu.first_mode_button != null and main_menu.first_mode_button.text == "Infinite Arena", "main menu first mode is Infinite Arena")
	assert_not_null(_find_menu_button(main_menu, "Zombie Survival"), "main menu exposes Zombie Survival as a separate mode")
	assert_eq(String((save_manager.create_empty_save()["settings"] as Dictionary).get("last_mode", "")), String(GameConstants.MODE_INFINITE_ARENA), "new saves default Continue to Infinite Arena")

	var zombie_controller = scene.node(&"zombie_mode_controller")
	assert_not_null(zombie_controller, "zombie mode controller is available")
	assert_true(main_menu.start_selected_mode(GameConstants.MODE_INFINITE_ARENA), "main menu starts Infinite Arena")
	await wait_physics_frames(2)
	await wait_physics_frames(1)
	assert_true(await _await_world_ready(zombie_controller), "Infinite Arena finishes its async world build")

	assert_eq(game_mode_manager.active_mode_id, GameConstants.MODE_INFINITE_ARENA, "Infinite Arena becomes the active mode")
	assert_true(bool(infinite_arena_mode.get("is_running")), "infinite arena adapter is running")
	assert_true(survival_mode.is_running, "shared survival runtime is running")
	assert_false(main_menu.is_open(), "menu hides after Infinite Arena starts")
	assert_true(main_menu.character_select_panel == null or not main_menu.character_select_panel.visible, "Infinite Arena does not open Character Select")
	assert_true(not world_runtime.is_active and world_runtime.graph == null and world_runtime.get_active_region_ids().is_empty(), "Infinite Arena does not start WorldRuntime exploration")
	assert_true(streamer.get_streamed_region_ids().is_empty(), "Infinite Arena does not stream connected regions")
	assert_true(scene.nodes(&"biome_transition_gates").is_empty(), "Infinite Arena creates no biome transition gates")
	if hud != null:
		assert_true(hud.exploration_map_panel == null or not hud.exploration_map_panel.visible, "Infinite Arena leaves exploration map hidden")

	_assert_infinite_arena_world(biome_manager)
	_assert_arena_terrain_is_solid(scene)
	_assert_runtime_raised_cliffs(scene, biome_manager)

	main_menu.open_menu()
	await wait_physics_frames(1)
	assert_eq(game_mode_manager.active_mode_id, GameConstants.MODE_MENU, "returning to menu restores menu mode")
	assert_false(bool(infinite_arena_mode.get("is_running")), "Infinite Arena stops on menu return")
	assert_false(survival_mode.is_running, "shared survival runtime stops on menu return")

	scene.teardown()
	scene = null
	await wait_physics_frames(1)

func _assert_infinite_arena_world(biome_manager: BiomeManager) -> void:
	var cells := biome_manager.get_generated_biome_map()
	assert_eq(cells.size(), 1, "Infinite Arena generates one biome cell")
	var start_cell := biome_manager.get_current_biome_cell()
	assert_not_null(start_cell, "Infinite Arena has an active arena cell")
	if start_cell == null:
		return
	assert_eq(
		Vector2i(start_cell.width, start_cell.height),
		BiomeEnvironmentLayout.DEFAULT_ZONE_SIZE,
		"Infinite Arena cell uses the shared iso grid size"
	)
	assert_true(start_cell.passages.is_empty(), "Infinite Arena has no inter-biome passages")
	for side in BiomeCell.SIDES:
		assert_eq(start_cell.get_border(side), BiomeCell.BorderType.BLOCKED, "Infinite Arena %s border is a wall" % String(side))
	var layout := start_cell.generated_layout
	assert_not_null(layout, "Infinite Arena has generated terrain")
	if layout == null:
		return
	assert_gt(layout.wall_segment_rects.size(), 0, "Infinite Arena layout emits perimeter wall segments")
	_assert_no_perimeter_fall_zones(layout, "Infinite Arena layout")
	assert_gt(layout.mesa_rects.size(), 0,
		"Infinite Arena conserva le mesa del generatore condiviso")
	assert_between(
		layout.random_prop_rects.size(),
		ObstacleLayoutGenerator.VOIDFIRST_PROP_MIN_COUNT,
		ObstacleLayoutGenerator.VOIDFIRST_PROP_MAX_COUNT,
		"Infinite Arena conserva i prop casuali del generatore condiviso"
	)
	assert_true(bool(layout.validation_report.get("is_valid", false)), "Infinite Arena layout passes validation")
	_assert_raised_cliff_layout(layout)

func _assert_arena_terrain_is_solid(scene) -> void:
	var hazard_system: HazardSystem = scene.node(&"hazard_system") as HazardSystem
	assert_not_null(hazard_system, "hazard system is available in Infinite Arena")
	if hazard_system == null:
		return
	assert_false(hazard_system.is_void_at_world_position(Vector2.ZERO), "Infinite Arena spawn center is solid ground, not void")
	var player: Node2D = scene.node(&"players") as Node2D
	if player != null:
		assert_false(hazard_system.is_void_at_world_position(player.global_position), "Infinite Arena player spawn is not classified as void")

# The walled arena keeps a walled perimeter (no fall edge to the void), but
# internal chasms are now a shared terrain feature and may appear, so assert only
# that every emitted fall zone is an internal chasm and none is a perimeter
# (side-tagged) fall boundary.
func _assert_no_perimeter_fall_zones(layout: BiomeEnvironmentLayout, label: String) -> void:
	var internal_chasm_count := 0
	for index in range(layout.hazard_ids.size()):
		if layout.hazard_ids[index] != &"fall_zone":
			continue
		var side: StringName = layout.hazard_sides[index]
		assert_eq(
			side,
			&"internal",
			"%s keeps a walled perimeter: fall zones are internal chasms only (got side '%s')" % [label, String(side)]
		)
		if side == &"internal":
			internal_chasm_count += 1
	assert_gt(internal_chasm_count, 0,
		"%s garantisce almeno un chasm interno" % label)

func _assert_raised_cliff_layout(layout: BiomeEnvironmentLayout) -> void:
	assert_eq(
		layout.perimeter_visual_style,
		BiomeEnvironmentLayout.PERIMETER_VISUAL_RAISED_CLIFF,
		"walled arena selects raised cliff perimeter art"
	)
	assert_eq(
		layout.wall_height_cells,
		BiomeEnvironmentLayout.RAISED_CLIFF_HEIGHT_CELLS,
		"raised arena cliff uses the shared height"
	)
	for side in BiomeCell.SIDES:
		var segments := layout.get_wall_segments_for_side(side)
		assert_false(segments.is_empty(), "raised cliff covers %s side" % String(side))
		var vertical := side == &"west" or side == &"east"
		var covered := 0
		for rect in segments:
			covered += rect.size.y if vertical else rect.size.x
		var expected := (
			layout.zone_size.y - ObstacleLayoutGenerator.BORDER_THICKNESS * 2
			if vertical
			else layout.zone_size.x
		)
		assert_eq(covered, expected, "raised cliff %s side has no decorative-road gap" % String(side))
		for rect in segments:
			assert_true(
				layout.obstacle_rects.has(rect),
				"raised cliff %s segment keeps its runtime collision obstacle" % String(side)
			)
	var midpoint := layout.zone_size / 2
	assert_true(layout.is_wall_segment_cell(Vector2i(midpoint.x, 0)), "north road terminates at the raised cliff")
	assert_true(layout.is_wall_segment_cell(Vector2i(midpoint.x, layout.zone_size.y - 1)), "south road terminates at the raised cliff")
	assert_true(layout.is_wall_segment_cell(Vector2i(0, midpoint.y)), "west road terminates at the raised cliff")
	assert_true(layout.is_wall_segment_cell(Vector2i(layout.zone_size.x - 1, midpoint.y)), "east road terminates at the raised cliff")

func _assert_runtime_raised_cliffs(
	scene,
	biome_manager: BiomeManager
) -> void:
	var perimeter_count := 0
	for node in scene.nodes(&"environment_obstacles"):
		var obstacle := node as BiomeObstacle
		if obstacle == null or not obstacle.is_perimeter_wall():
			continue
		perimeter_count += 1
		assert_eq(
			obstacle.get_perimeter_visual_style(),
			BiomeEnvironmentLayout.PERIMETER_VISUAL_RAISED_CLIFF,
			"runtime arena perimeter obstacle uses raised cliff art"
		)
		assert_true(obstacle.has_raised_cliff_art(), "runtime raised cliff loads face and crown textures")
		assert_false(obstacle.uses_perimeter_visual_fallback(), "runtime raised cliff avoids procedural wall fallback")
		assert_eq(
			obstacle.get_wall_height(),
			float(IsoGridConfig.RAISED_CLIFF_HEIGHT_TILES) * IsoGridConfig.LOGICAL_TILE_SCALE,
			"runtime raised cliff uses the configured logical height"
		)
		assert_true(
			(obstacle.collision_layer & BiomeObstacle.MOVEMENT_BLOCK_LAYER_BIT) != 0,
			"runtime raised cliff still blocks movement"
		)
		assert_true(
			(obstacle.collision_layer & BiomeObstacle.PROJECTILE_BLOCK_LAYER_BIT) != 0,
			"runtime raised cliff still blocks projectiles"
		)
		var record := obstacle.get_meta("obstacle_record", {}) as Dictionary
		var occupied_cells := record.get("occupied_cells", Rect2i()) as Rect2i
		assert_eq(
			obstacle.get_perimeter_uv_origin(),
			Vector2(occupied_cells.position) * IsoGridConfig.LOGICAL_TILE_SCALE,
			"runtime raised cliff UV origin follows its generated wall segment"
		)
	var cell := biome_manager.get_current_biome_cell()
	var expected_count := (
		cell.generated_layout.wall_segment_rects.size()
		if cell != null and cell.generated_layout != null
		else 0
	)
	assert_eq(
		perimeter_count,
		expected_count,
		"Infinite Arena instantiates every generated raised cliff segment"
	)

# --- helper -----------------------------------------------------------------

func _wait_for_wave_combat(wave_manager: WaveManager, wave_index: int) -> bool:
	for _frame in range(240):
		if wave_manager.current_wave == wave_index and wave_manager.state == WaveManager.State.COMBAT:
			return true
		await wait_physics_frames(1)
	return false

func _wait_for_wave_completed(wave_manager: WaveManager, wave_index: int) -> bool:
	for _frame in range(180):
		if wave_manager.current_wave == wave_index and not wave_manager.wave_running:
			return true
		await wait_physics_frames(1)
	return false

func _wait_for_wave_running(wave_manager: WaveManager, wave_index: int) -> bool:
	for _frame in range(300):
		if wave_manager.current_wave == wave_index and wave_manager.wave_running:
			return true
		await wait_physics_frames(1)
	return false

func _advance_until_market(wave_manager: WaveManager, market: SurvivalMarketController, health_system: HealthSystem) -> bool:
	for _frame in range(2400):
		for enemy in wave_manager.get_active_wave_enemies():
			enemy.set_physics_process(false)
			health_system.apply_damage(enemy, 999999)
		var boss := wave_manager.get_active_boss()
		if boss != null:
			boss.set_physics_process(false)
			health_system.apply_damage(boss, 999999)
		if market.is_market_open:
			return true
		await wait_physics_frames(1)
	return false

func _await_world_ready(zombie_controller: Node) -> bool:
	if zombie_controller == null:
		return false
	_async_world_ready = false
	zombie_controller.world_ready.connect(_on_async_world_ready, CONNECT_ONE_SHOT)
	var deadline := Time.get_ticks_msec() + 150000
	while not _async_world_ready and Time.get_ticks_msec() < deadline:
		await wait_physics_frames(1)
	return _async_world_ready

func _on_async_world_ready(_biome_id: StringName) -> void:
	_async_world_ready = true

func _find_menu_button(main_menu: MainMenu, label_text: String) -> Button:
	for button in main_menu.menu_buttons:
		if button != null and button.text == label_text:
			return button
	return null
func _new_main_scene_fixture():
	var script := ResourceLoader.load(
		"res://tests/support/main_scene_fixture.gd",
		"",
		ResourceLoader.CACHE_MODE_IGNORE
	) as Script
	assert_true(script != null, "main scene fixture script loads")
	return script.new() if script != null else null
