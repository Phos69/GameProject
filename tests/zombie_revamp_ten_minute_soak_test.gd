extends SceneTree

const TEST_SCENE_LIFECYCLE := preload("res://tests/test_scene_lifecycle.gd")

var failures: PackedStringArray = []
var finish_requested: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
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

	var game_mode_manager := get_first_node_in_group(
		"game_mode_manager"
	) as GameModeManager
	var survival_mode := get_first_node_in_group(
		"survival_mode"
	) as SurvivalMode
	var wave_manager := get_first_node_in_group(
		"wave_manager"
	) as WaveManager
	var health_system := get_first_node_in_group(
		"health_system"
	) as HealthSystem
	var wave_director := get_first_node_in_group(
		"wave_director"
	) as WaveDirector
	var biome_manager := get_first_node_in_group(
		"biome_manager"
	) as BiomeManager
	var transition_system := get_first_node_in_group(
		"biome_transition_system"
	) as BiomeTransitionSystem
	_expect(game_mode_manager != null, "game mode manager is available")
	_expect(survival_mode != null, "survival mode is available")
	_expect(wave_manager != null, "wave manager is available")
	_expect(health_system != null, "health system is available")
	_expect(wave_director != null, "wave director is available")
	_expect(biome_manager != null, "biome manager is available")
	_expect(transition_system != null, "transition system is available")
	if (
		game_mode_manager == null
		or survival_mode == null
		or wave_manager == null
		or health_system == null
		or wave_director == null
		or biome_manager == null
		or transition_system == null
	):
		_finish()
		return

	wave_manager.initial_delay = 0.05
	wave_manager.intermission_duration = 0.05
	wave_manager.spawn_interval = 0.0
	wave_manager.base_enemy_count = 3
	wave_manager.enemy_count_growth = 0
	wave_manager.boss_wave_interval = 99
	survival_mode.boss_wave_interval = 99
	transition_system.transition_cooldown = 0.01
	_expect(
		game_mode_manager.set_mode(GameConstants.MODE_SURVIVAL),
		"accelerated survival soak starts"
	)

	var transition_targets: Array[StringName] = [
		&"toxic_wastes",
		&"burning_fields",
		&"frozen_outskirts",
		&"drowned_marsh"
	]
	var next_transition_index := 0
	var seen_biomes: Dictionary = {&"infected_plains": true}
	var simulated_elapsed := 0.0
	var safety_frames := 0
	while wave_director.run_elapsed < 600.0 and safety_frames < 2400:
		safety_frames += 1
		simulated_elapsed += 1.0
		wave_director.run_elapsed = maxf(
			wave_director.run_elapsed,
			simulated_elapsed
		)
		for enemy in wave_manager.get_active_wave_enemies():
			health_system.apply_damage(enemy, 99999)
		var transition_threshold := float(next_transition_index + 1) * 120.0
		if (
			next_transition_index < transition_targets.size()
			and wave_director.run_elapsed >= transition_threshold
		):
			transition_system.cooldown_timer = 0.0
			transition_system.transition_to(
				transition_targets[next_transition_index],
				&"east"
			)
			seen_biomes[biome_manager.get_current_biome_id()] = true
			next_transition_index += 1
		await physics_frame

	_expect(
		wave_director.run_elapsed >= 600.0,
		"survival remains active for ten simulated minutes"
	)
	_expect(
		seen_biomes.size() == 5,
		"ten-minute soak crosses all five biomes"
	)
	_expect(
		survival_mode.is_running and wave_manager.run_active,
		"survival systems remain active after the soak"
	)
	_expect(
		wave_manager.current_wave >= 5,
		"multiple wave cycles complete during the soak"
	)

	Engine.time_scale = 1.0
	survival_mode.stop_mode()
	_finish()

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if finish_requested:
		return
	finish_requested = true
	call_deferred("_finish_after_teardown")

func _finish_after_teardown() -> void:
	Engine.time_scale = 1.0
	await TEST_SCENE_LIFECYCLE.teardown_current_scene(self, 3)
	if failures.is_empty():
		print("ZOMBIE_REVAMP_TEN_MINUTE_SOAK_TEST: PASS")
		quit(0)
		return
	print(
		"ZOMBIE_REVAMP_TEN_MINUTE_SOAK_TEST: FAIL (%d)"
		% failures.size()
	)
	quit(1)
