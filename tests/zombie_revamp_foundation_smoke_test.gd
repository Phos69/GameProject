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

	var game_mode_manager := get_first_node_in_group("game_mode_manager") as GameModeManager
	var survival_mode := get_first_node_in_group("survival_mode") as SurvivalMode
	var wave_manager := get_first_node_in_group("wave_manager") as WaveManager
	var health_system := get_first_node_in_group("health_system") as HealthSystem
	var biome_manager := get_first_node_in_group("biome_manager")
	var wave_director := get_first_node_in_group("wave_director")
	var zombie_spawner := get_first_node_in_group("zombie_spawner")
	var zombie_controller := get_first_node_in_group("zombie_mode_controller")
	_expect(game_mode_manager != null, "game mode manager is available")
	_expect(survival_mode != null, "survival mode is available")
	_expect(wave_manager != null, "wave manager is available")
	_expect(health_system != null, "health system is available")
	_expect(biome_manager != null, "biome manager is available")
	_expect(wave_director != null, "wave director is available")
	_expect(zombie_spawner != null, "zombie spawner is available")
	_expect(zombie_controller != null, "zombie mode controller is available")
	if (
		game_mode_manager == null
		or survival_mode == null
		or wave_manager == null
		or health_system == null
		or biome_manager == null
		or wave_director == null
		or zombie_spawner == null
		or zombie_controller == null
	):
		_finish()
		return

	var biome_ids: Array = biome_manager.get_available_biome_ids()
	_expect(biome_ids.size() >= 5, "biome manager registers the planned biome set")
	_expect(
		biome_manager.get_current_biome_id() == &"infected_plains",
		"initial biome defaults to Pianura Infetta"
	)
	_expect(
		wave_director.get_enemy_id_for_spawn(1, 0, 3) == &"survival_zombie",
		"first wave resolves to base zombies"
	)

	var visible_rect: Rect2 = zombie_spawner.get_visible_world_rect()
	var preview_spawn: Vector2 = zombie_spawner.get_spawn_position(0)
	_expect(visible_rect.size.x > 0.0, "spawner can read the camera visible rect")
	_expect(
		not visible_rect.has_point(preview_spawn),
		"spawner previews positions outside the current camera view"
	)

	survival_mode.stop_mode()
	await process_frame
	wave_manager.initial_delay = 0.0
	wave_manager.intermission_duration = 100.0
	wave_manager.spawn_interval = 0.01
	wave_manager.base_enemy_count = 2
	wave_manager.enemy_count_growth = 0
	wave_manager.boss_wave_interval = 99
	survival_mode.boss_wave_interval = 99

	_expect(
		game_mode_manager.set_mode(GameConstants.MODE_SURVIVAL),
		"survival mode starts through the game mode manager"
	)
	_expect(await _wait_for_wave_combat(wave_manager, 1), "first wave reaches combat")
	_expect(
		biome_manager.get_current_biome_id() == &"infected_plains",
		"survival run starts from the starting biome"
	)
	_expect(
		wave_manager.current_wave_biome_id == &"infected_plains",
		"wave manager records the biome used for the wave"
	)
	var wave_enemies := wave_manager.get_active_wave_enemies()
	_expect(wave_enemies.size() == 2, "wave one spawns through the delegated systems")
	for enemy in wave_enemies:
		if enemy is Node2D:
			_expect(
				not visible_rect.has_point((enemy as Node2D).global_position),
				"spawned zombie enters from outside the initial camera view"
			)
		health_system.apply_damage(enemy, 9999)
	_expect(await _wait_for_wave_completed(wave_manager, 1), "delegated wave completes")

	survival_mode.stop_mode()
	_finish()

func _wait_for_wave_combat(wave_manager: WaveManager, wave_index: int) -> bool:
	for _frame in range(240):
		if wave_manager.current_wave == wave_index and wave_manager.state == WaveManager.State.COMBAT:
			return true
		await physics_frame
	return false

func _wait_for_wave_completed(wave_manager: WaveManager, wave_index: int) -> bool:
	for _frame in range(180):
		if wave_manager.current_wave == wave_index and not wave_manager.wave_running:
			return true
		await physics_frame
	return false

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("ZOMBIE_REVAMP_FOUNDATION_SMOKE_TEST: PASS")
		quit(0)
		return

	print("ZOMBIE_REVAMP_FOUNDATION_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
