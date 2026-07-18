extends GutTest
## Soak/Stress — Soak accelerato di dieci minuti simulati di zombie survival.
##
## Migra:
##   tests/zombie_revamp_ten_minute_soak_test.gd  (boot main.tscn, 600s simulati)
##
## NB: suite di stress, esclusa dal run rapido (.gutconfig.json). Avanza
## artificialmente wave_director.run_elapsed e tiene puliti i nemici per coprire
## dieci minuti simulati attraversando tutti e quattro i biomi.

func test_accelerated_ten_minute_soak() -> void:
	var scene = _new_main_scene_fixture()
	assert_true(scene.boot(self), "main scene can be loaded")
	await wait_physics_frames(2)

	var game_mode_manager: GameModeManager = scene.node(&"game_mode_manager") as GameModeManager
	var survival_mode: SurvivalMode = scene.node(&"survival_mode") as SurvivalMode
	var wave_manager: WaveManager = scene.node(&"wave_manager") as WaveManager
	var health_system: HealthSystem = scene.node(&"health_system") as HealthSystem
	var wave_director: WaveDirector = scene.node(&"wave_director") as WaveDirector
	var biome_manager: BiomeManager = scene.node(&"biome_manager") as BiomeManager
	var transition_system: BiomeTransitionSystem = scene.node(&"biome_transition_system") as BiomeTransitionSystem
	assert_not_null(game_mode_manager, "game mode manager is available")
	assert_not_null(survival_mode, "survival mode is available")
	assert_not_null(wave_manager, "wave manager is available")
	assert_not_null(health_system, "health system is available")
	assert_not_null(wave_director, "wave director is available")
	assert_not_null(biome_manager, "biome manager is available")
	assert_not_null(transition_system, "transition system is available")
	if (
		game_mode_manager == null or survival_mode == null or wave_manager == null
		or health_system == null or wave_director == null or biome_manager == null
		or transition_system == null
	):
		scene.teardown()
		scene = null
		return

	wave_manager.initial_delay = 0.05
	wave_manager.intermission_duration = 0.05
	wave_manager.spawn_interval = 0.0
	wave_manager.base_enemy_count = 3
	wave_manager.enemy_count_growth = 0
	wave_manager.boss_wave_interval = 99
	survival_mode.boss_wave_interval = 99
	transition_system.transition_cooldown = 0.01
	assert_true(
		game_mode_manager.set_mode(
			GameConstants.MODE_SURVIVAL,
			{"world_seed": 20260622, "disable_region_streaming": true}
		),
		"accelerated survival soak starts"
	)

	var transition_targets: Array[StringName] = [
		&"burning_plains",
		&"frozen_tundra",
		&"swamp"
	]
	var next_transition_index := 0
	var seen_biomes: Dictionary = {&"plains": true}
	var simulated_elapsed := 0.0
	var safety_frames := 0
	while wave_director.run_elapsed < 600.0 and safety_frames < 2400:
		safety_frames += 1
		simulated_elapsed += 1.0
		wave_director.run_elapsed = maxf(wave_director.run_elapsed, simulated_elapsed)
		for enemy in wave_manager.get_active_wave_enemies():
			health_system.apply_damage(enemy, 99999)
		var transition_threshold := float(next_transition_index + 1) * 120.0
		if next_transition_index < transition_targets.size() and wave_director.run_elapsed >= transition_threshold:
			transition_system.cooldown_timer = 0.0
			transition_system.transition_to(transition_targets[next_transition_index], &"east")
			seen_biomes[biome_manager.get_current_biome_id()] = true
			next_transition_index += 1
		await get_tree().physics_frame

	assert_gte(wave_director.run_elapsed, 600.0, "survival remains active for ten simulated minutes")
	assert_eq(seen_biomes.size(), 4, "ten-minute soak crosses all four biomes")
	assert_true(survival_mode.is_running and wave_manager.run_active, "survival systems remain active after the soak")
	assert_gte(wave_manager.current_wave, 5, "multiple wave cycles complete during the soak")

	Engine.time_scale = 1.0
	survival_mode.stop_mode()
	scene.teardown()
	scene = null
	await wait_physics_frames(1)
func _new_main_scene_fixture():
	var script := ResourceLoader.load(
		"res://tests/support/main_scene_fixture.gd",
		"",
		ResourceLoader.CACHE_MODE_IGNORE
	) as Script
	assert_true(script != null, "main scene fixture script loads")
	return script.new() if script != null else null
