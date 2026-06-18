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
	var wave_manager := get_first_node_in_group("wave_manager") as WaveManager
	var biome_manager := get_first_node_in_group("biome_manager") as BiomeManager
	var player_manager := get_first_node_in_group("player_manager") as PlayerManager
	var enemy_system := get_first_node_in_group("enemy_system") as EnemySystem
	var seam_system = get_first_node_in_group("region_seam_system")
	var zombie_spawner := get_first_node_in_group("zombie_spawner") as ZombieSpawner
	_expect(game_mode_manager != null, "game mode manager is available")
	_expect(wave_manager != null, "wave manager is available")
	_expect(biome_manager != null, "biome manager is available")
	_expect(player_manager != null, "player manager is available")
	_expect(enemy_system != null, "enemy system is available")
	_expect(seam_system != null, "region seam system is available")
	_expect(zombie_spawner != null, "zombie spawner is available")
	if (
		game_mode_manager == null
		or wave_manager == null
		or biome_manager == null
		or player_manager == null
		or enemy_system == null
		or seam_system == null
		or zombie_spawner == null
	):
		_finish()
		return

	wave_manager.initial_delay = 100.0
	_expect(
		game_mode_manager.set_mode(GameConstants.MODE_SURVIVAL, {
			"world_seed": 91919,
			"biome_map_width": 3,
			"biome_map_height": 3,
			"extra_edge_chance": 0.5
		}),
		"survival starts for cross-biome chase"
	)
	await process_frame
	await physics_frame

	var graph := biome_manager.get_world_graph()
	var start_cell := biome_manager.get_current_biome_cell()
	_expect(graph != null, "world graph exists")
	_expect(start_cell != null, "current region exists")
	if graph == null or start_cell == null:
		_finish()
		return
	var connection := _first_connection_for_cell(graph, start_cell)
	_expect(connection != null, "start region has an open connection")
	if connection == null:
		_finish()
		return

	var player := player_manager.players.get(1) as Node2D
	_expect(player != null, "player one exists")
	if player == null:
		_finish()
		return
	var direction := _direction_for_side(connection.side)
	var crossing_position: Vector2 = seam_system.get_crossing_position_for_connection(
		connection,
		graph.start_region_id
	)
	player.global_position = crossing_position
	seam_system.cooldown_timer = 0.0
	_expect(
		seam_system.try_update_region_for_position(crossing_position),
		"player crossing updates the current region before chase"
	)
	await process_frame
	player.global_position = crossing_position + direction * 220.0

	var enemy_position := crossing_position - direction * 180.0
	var spawn_region_id := StringName(
		seam_system.get_region_id_for_world_position(enemy_position)
	)
	_expect(spawn_region_id == start_cell.id, "enemy spawn remains in source region")
	var enemy := enemy_system.spawn_enemy(
		&"survival_zombie",
		enemy_position,
		null,
		{"wave_index": 1}
	) as BasicEnemy
	_expect(enemy != null, "enemy spawns on source side of seam")
	if enemy == null:
		_finish()
		return
	enemy.detection_range = 4000.0
	enemy.move_speed = 180.0
	enemy.target_refresh_interval = 0.01
	var health_before := enemy.health_component.current_health

	for _frame in range(180):
		await physics_frame
		if enemy == null or not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			break
		if enemy.current_region_id == connection.to_region_id:
			break

	_expect(is_instance_valid(enemy) and not enemy.is_queued_for_deletion(), "enemy is not despawned by region crossing")
	_expect(enemy_system.get_active_enemies().has(enemy), "enemy remains registered while chasing across biome")
	_expect(enemy.spawn_region_id == start_cell.id, "enemy keeps its spawn region metadata")
	_expect(enemy.current_region_id == connection.to_region_id, "enemy updates current region after crossing the seam")
	_expect(enemy.last_seen_player_region_id == connection.to_region_id, "enemy tracks target region across the seam")
	_expect(enemy.get_state_name() == &"chase" or enemy.get_state_name() == &"attack", "enemy keeps chase/attack state across biome")
	_expect(enemy.target == player, "enemy keeps the same player target")
	_expect(enemy.health_component.current_health == health_before, "region change does not reset enemy health")
	_expect(
		zombie_spawner.is_spawn_position_valid(
			player.global_position + direction * zombie_spawner.spawn_margin,
			biome_manager.get_current_biome()
		)
		or not seam_system.get_region_id_for_world_position(player.global_position).is_empty(),
		"spawner can reason about positions in streamed world-space"
	)

	if is_instance_valid(enemy):
		enemy.queue_free()
	var survival_mode := get_first_node_in_group("survival_mode") as SurvivalMode
	if survival_mode != null:
		survival_mode.stop_mode()
	_finish()

func _first_connection_for_cell(
	graph: WorldGraph,
	cell: BiomeCell
) -> WorldRegionConnection:
	var region := graph.get_region(cell.id)
	if region == null:
		return null
	for connection in region.connection_edges:
		if connection.is_open and connection.physical_passage:
			return connection
	return null

func _direction_for_side(side: StringName) -> Vector2:
	match side:
		&"west":
			return Vector2.LEFT
		&"north":
			return Vector2.UP
		&"south":
			return Vector2.DOWN
		_:
			return Vector2.RIGHT

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("MILESTONE_10_CROSS_BIOME_CHASE_SMOKE_TEST: PASS")
		quit(0)
		return
	print(
		"MILESTONE_10_CROSS_BIOME_CHASE_SMOKE_TEST: FAIL (%d)"
		% failures.size()
	)
	quit(1)
