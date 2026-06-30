extends GutTest
## Soak/Stress — Regressione zombie survival su dieci ondate con transizioni bioma.
##
## Migra:
##   tests/zombie_revamp_ten_wave_smoke_test.gd  (boot main.tscn, 10 wave, 5 biomi)
##
## NB: suite di stress, esclusa dal run rapido (.gutconfig.json).

const MainSceneFixture = preload("res://tests/support/main_scene_fixture.gd")

func test_ten_wave_run_crosses_biomes() -> void:
	var scene := MainSceneFixture.new()
	assert_true(scene.boot(self), "main scene can be loaded")
	await wait_physics_frames(2)

	var game_mode_manager := scene.node(&"game_mode_manager") as GameModeManager
	var survival_mode := scene.node(&"survival_mode") as SurvivalMode
	var wave_manager := scene.node(&"wave_manager") as WaveManager
	var health_system := scene.node(&"health_system") as HealthSystem
	var biome_manager := scene.node(&"biome_manager") as BiomeManager
	var transition_system := scene.node(&"biome_transition_system") as BiomeTransitionSystem
	var zombie_spawner := scene.node(&"zombie_spawner") as ZombieSpawner
	assert_not_null(game_mode_manager, "game mode manager is available")
	assert_not_null(survival_mode, "survival mode is available")
	assert_not_null(wave_manager, "wave manager is available")
	assert_not_null(health_system, "health system is available")
	assert_not_null(biome_manager, "biome manager is available")
	assert_not_null(transition_system, "transition system is available")
	assert_not_null(zombie_spawner, "zombie spawner is available")
	if (
		game_mode_manager == null or survival_mode == null or wave_manager == null
		or health_system == null or biome_manager == null or transition_system == null
		or zombie_spawner == null
	):
		scene.teardown()
		return

	wave_manager.initial_delay = 0.0
	wave_manager.intermission_duration = 0.01
	wave_manager.spawn_interval = 0.001
	wave_manager.base_enemy_count = 2
	wave_manager.enemy_count_growth = 1
	wave_manager.boss_wave_interval = 99
	survival_mode.boss_wave_interval = 99
	transition_system.transition_cooldown = 0.01
	assert_true(
		game_mode_manager.set_mode(
			GameConstants.MODE_SURVIVAL,
			{"world_seed": 20260622, "disable_region_streaming": true}
		),
		"survival starts for ten-wave regression"
	)

	var biome_path: Array[StringName] = [
		&"infected_plains",
		&"toxic_wastes",
		&"burning_fields",
		&"frozen_outskirts",
		&"drowned_marsh"
	]
	var seen_biomes: Dictionary = {}
	for wave_index in range(1, 11):
		if wave_index in [3, 5, 7, 9]:
			var target_index := mini(floori(float(wave_index - 1) / 2.0), 4)
			transition_system.cooldown_timer = 0.0
			transition_system.transition_to(biome_path[target_index], &"east")
			await wait_physics_frames(1)
		assert_true(await _wait_for_wave_combat(wave_manager, wave_index), "wave %d reaches combat" % wave_index)
		seen_biomes[wave_manager.current_wave_biome_id] = true
		for enemy in wave_manager.get_active_wave_enemies():
			health_system.apply_damage(enemy, 99999)
		assert_true(await _wait_for_wave_completed(wave_manager, wave_index), "wave %d completes cleanly" % wave_index)
	assert_gte(seen_biomes.size(), 5, "ten-wave run exercises all five biomes")
	assert_eq(wave_manager.current_wave, 10, "survival remains active through ten waves")

	survival_mode.stop_mode()
	scene.teardown()
	await wait_physics_frames(1)

func _wait_for_wave_combat(wave_manager: WaveManager, wave_index: int) -> bool:
	for _frame in range(900):
		if wave_manager.current_wave == wave_index and wave_manager.state == WaveManager.State.COMBAT:
			return true
		await get_tree().physics_frame
	return false

func _wait_for_wave_completed(wave_manager: WaveManager, wave_index: int) -> bool:
	for _frame in range(240):
		if wave_manager.current_wave == wave_index and not wave_manager.wave_running:
			return true
		await get_tree().physics_frame
	return false
