extends SceneTree

var failures: PackedStringArray = []

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
	var biome_manager := get_first_node_in_group(
		"biome_manager"
	) as BiomeManager
	var transition_system := get_first_node_in_group(
		"biome_transition_system"
	) as BiomeTransitionSystem
	var zombie_spawner := get_first_node_in_group(
		"zombie_spawner"
	) as ZombieSpawner
	_expect(game_mode_manager != null, "game mode manager is available")
	_expect(survival_mode != null, "survival mode is available")
	_expect(wave_manager != null, "wave manager is available")
	_expect(health_system != null, "health system is available")
	_expect(biome_manager != null, "biome manager is available")
	_expect(transition_system != null, "transition system is available")
	_expect(zombie_spawner != null, "zombie spawner is available")
	if (
		game_mode_manager == null
		or survival_mode == null
		or wave_manager == null
		or health_system == null
		or biome_manager == null
		or transition_system == null
		or zombie_spawner == null
	):
		_finish()
		return

	wave_manager.initial_delay = 0.0
	wave_manager.intermission_duration = 0.01
	wave_manager.spawn_interval = 0.001
	wave_manager.base_enemy_count = 2
	wave_manager.enemy_count_growth = 1
	wave_manager.boss_wave_interval = 99
	survival_mode.boss_wave_interval = 99
	transition_system.transition_cooldown = 0.01
	_expect(
		game_mode_manager.set_mode(GameConstants.MODE_SURVIVAL),
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
			transition_system.transition_to(
				biome_path[target_index],
				&"east"
			)
			await process_frame
		_expect(
			await _wait_for_wave_combat(wave_manager, wave_index),
			"wave %d reaches combat" % wave_index
		)
		seen_biomes[wave_manager.current_wave_biome_id] = true
		var edge_spawn_ok := zombie_spawner.get_last_spawn_edge() in [
			&"north",
			&"south",
			&"east",
			&"west"
		]
		var edge_spawn_message := "wave %d uses a camera-edge spawn" % wave_index
		if not edge_spawn_ok:
			edge_spawn_message += " (%s)" % _spawn_debug_summary(zombie_spawner)
		_expect(edge_spawn_ok, edge_spawn_message)
		for enemy in wave_manager.get_active_wave_enemies():
			health_system.apply_damage(enemy, 99999)
		_expect(
			await _wait_for_wave_completed(wave_manager, wave_index),
			"wave %d completes cleanly" % wave_index
		)
	_expect(
		seen_biomes.size() >= 5,
		"ten-wave run exercises all five biomes"
	)
	_expect(
		wave_manager.current_wave == 10,
		"survival remains active through ten waves"
	)

	survival_mode.stop_mode()
	_finish()

func _wait_for_wave_combat(
	wave_manager: WaveManager,
	wave_index: int
) -> bool:
	for _frame in range(900):
		if (
			wave_manager.current_wave == wave_index
			and wave_manager.state == WaveManager.State.COMBAT
		):
			return true
		await physics_frame
	return false

func _wait_for_wave_completed(
	wave_manager: WaveManager,
	wave_index: int
) -> bool:
	for _frame in range(240):
		if (
			wave_manager.current_wave == wave_index
			and not wave_manager.wave_running
		):
			return true
		await physics_frame
	return false

func _spawn_debug_summary(zombie_spawner: ZombieSpawner) -> String:
	var edge := zombie_spawner.get_last_spawn_edge()
	var reason := zombie_spawner.get_last_spawn_rejection_reason()
	var report := zombie_spawner.get_last_spawn_attempt_report()
	var recent: Array[String] = []
	var start := maxi(report.size() - 4, 0)
	for index in range(start, report.size()):
		var entry := report[index] as Dictionary
		recent.append("%s:%s" % [
			String(entry.get("edge", &"")),
			String(entry.get("reason", &""))
		])
	return "edge=%s reason=%s recent=[%s]" % [
		String(edge),
		String(reason),
		", ".join(recent)
	]

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("ZOMBIE_REVAMP_TEN_WAVE_SMOKE_TEST: PASS")
		quit(0)
		return
	print(
		"ZOMBIE_REVAMP_TEN_WAVE_SMOKE_TEST: FAIL (%d)"
		% failures.size()
	)
	quit(1)
