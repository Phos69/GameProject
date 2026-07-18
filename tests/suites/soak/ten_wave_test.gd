extends GutTest
## Soak/Stress — Regressione zombie survival su dieci ondate con transizioni bioma.
##
## Migra:
##   tests/zombie_revamp_ten_wave_smoke_test.gd  (boot main.tscn, 10 wave, 4 biomi)
##
## NB: suite di stress, esclusa dal run rapido (.gutconfig.json).

const MODE_SURVIVAL := &"survival"
const WAVE_STATE_COMBAT := 3

func test_ten_wave_run_crosses_biomes() -> void:
	var scene = _new_main_scene_fixture()
	if scene == null:
		return
	assert_true(scene.boot(self), "main scene can be loaded")
	await wait_physics_frames(2)

	var game_mode_manager = scene.node(&"game_mode_manager")
	var survival_mode = scene.node(&"survival_mode")
	var wave_manager = scene.node(&"wave_manager")
	var health_system = scene.node(&"health_system")
	var biome_manager = scene.node(&"biome_manager")
	var transition_system = scene.node(&"biome_transition_system")
	var zombie_spawner = scene.node(&"zombie_spawner")
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
		await _cleanup_scene(scene)
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
			MODE_SURVIVAL,
			{"world_seed": 20260622, "disable_region_streaming": true}
		),
		"survival starts for ten-wave regression"
	)

	var biome_path: Array[StringName] = [
		&"plains",
		&"burning_plains",
		&"frozen_tundra",
		&"swamp"
	]
	var seen_biomes: Dictionary = {}
	for wave_index in range(1, 11):
		if wave_index in [3, 5, 7, 9]:
			var target_index := mini(floori(float(wave_index - 1) / 2.0), 3)
			transition_system.cooldown_timer = 0.0
			transition_system.transition_to(biome_path[target_index], &"east")
			await wait_physics_frames(1)
		assert_true(await _wait_for_wave_combat(wave_manager, wave_index), "wave %d reaches combat" % wave_index)
		seen_biomes[wave_manager.current_wave_biome_id] = true
		for enemy in wave_manager.get_active_wave_enemies():
			health_system.apply_damage(enemy, 99999)
		assert_true(await _wait_for_wave_completed(wave_manager, wave_index), "wave %d completes cleanly" % wave_index)
	assert_gte(seen_biomes.size(), 4, "ten-wave run exercises all four biomes")
	assert_eq(wave_manager.current_wave, 10, "survival remains active through ten waves")

	game_mode_manager = null
	survival_mode = null
	wave_manager = null
	health_system = null
	biome_manager = null
	transition_system = null
	zombie_spawner = null
	await _cleanup_scene(scene)

func _new_main_scene_fixture():
	var script := ResourceLoader.load(
		"res://tests/support/main_scene_fixture.gd",
		"",
		ResourceLoader.CACHE_MODE_IGNORE
	) as Script
	assert_true(script != null, "main scene fixture script loads")
	return script.new() if script != null else null

func _cleanup_scene(scene) -> void:
	if scene == null:
		return
	scene.stop_survival()
	await wait_physics_frames(1)
	scene.teardown()
	scene = null
	await wait_physics_frames(3)
	WorldDataCache.clear()
	EnvironmentAssetManifest.clear_shared()
	EnvironmentObject.clear_content_metrics_cache()
	await wait_physics_frames(1)

func _wait_for_wave_combat(wave_manager, wave_index: int) -> bool:
	for _frame in range(900):
		if wave_manager.current_wave == wave_index and int(wave_manager.state) == WAVE_STATE_COMBAT:
			return true
		await get_tree().physics_frame
	return false

func _wait_for_wave_completed(wave_manager, wave_index: int) -> bool:
	for _frame in range(240):
		if wave_manager.current_wave == wave_index and not wave_manager.wave_running:
			return true
		await get_tree().physics_frame
	return false
