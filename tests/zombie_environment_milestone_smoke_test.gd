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

	var main := main_scene.instantiate() as Node2D
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	await physics_frame

	var game_mode_manager := get_first_node_in_group(
		"game_mode_manager"
	) as GameModeManager
	var survival_mode := get_first_node_in_group(
		"survival_mode"
	) as SurvivalMode
	var wave_manager := get_first_node_in_group(
		"wave_manager"
	) as WaveManager
	var biome_manager := get_first_node_in_group(
		"biome_manager"
	) as BiomeManager
	var terrain_generator := get_first_node_in_group(
		"terrain_generator"
	) as TerrainGenerator
	var obstacle_system := get_first_node_in_group(
		"obstacle_system"
	) as ObstacleSystem
	var resource_crate_system := get_first_node_in_group(
		"resource_crate_system"
	) as ResourceCrateSystem
	var hazard_system := get_first_node_in_group(
		"hazard_system"
	) as HazardSystem
	var enemy_system := get_first_node_in_group(
		"enemy_system"
	) as EnemySystem
	var playground := main.get_node_or_null(
		"World/Playground"
	) as IsometricPlayground
	_expect(game_mode_manager != null, "game mode manager is available")
	_expect(survival_mode != null, "survival mode is available")
	_expect(wave_manager != null, "wave manager is available")
	_expect(biome_manager != null, "biome manager is available")
	_expect(terrain_generator != null, "terrain generator is available")
	_expect(obstacle_system != null, "obstacle system is available")
	_expect(resource_crate_system != null, "resource crate system is available")
	_expect(hazard_system != null, "hazard system is available")
	_expect(enemy_system != null, "enemy system is available")
	_expect(playground != null, "shared playground is available")
	if (
		game_mode_manager == null
		or survival_mode == null
		or wave_manager == null
		or biome_manager == null
		or terrain_generator == null
		or obstacle_system == null
		or resource_crate_system == null
		or hazard_system == null
		or enemy_system == null
		or playground == null
	):
		_finish()
		return

	wave_manager.initial_delay = 100.0
	_expect(
		game_mode_manager.set_mode(GameConstants.MODE_SURVIVAL),
		"survival starts with the environment milestone enabled"
	)
	await process_frame
	await process_frame
	await physics_frame

	var biome := biome_manager.get_current_biome() as BiomeDefinition
	var layout := biome.environment_layout
	var palette := biome.palette
	_expect(
		biome_manager.get_current_biome_id() == &"infected_plains",
		"environment generation starts from Pianura Infetta"
	)
	_expect(layout != null, "starting biome exposes an environment layout")
	if layout == null or palette == null:
		_finish()
		return

	var tile_layer := terrain_generator.get_active_tile_layer()
	_expect(tile_layer != null, "terrain generator creates the asset tile layer")
	if tile_layer != null:
		_expect(
			tile_layer.get_visual_tile_count() == layout.zone_size.x * layout.zone_size.y,
			"asset tile layer covers the full generated layout"
		)
		_expect(tile_layer.get_missing_asset_count() == 0, "asset tile layer has no missing visual cells")
	_expect(
		playground.floor_color.is_equal_approx(palette.background_color)
		and playground.concrete_color.is_equal_approx(palette.floor_color),
		"starting biome palette is applied to the shared playground"
	)

	var player := get_first_node_in_group("players") as Node2D
	if player != null:
		player.global_position = Vector2.ZERO

	var obstacles: Array = obstacle_system.get_active_obstacles()
	_expect(
		obstacles.size() >= layout.obstacle_positions.size(),
		"obstacle system creates at least the deterministic starting layout"
	)
	var spawned_obstacle_ids: Array[StringName] = []
	var current_region_obstacles: Array = []
	for obstacle in obstacles:
		if obstacle == null:
			continue
		if (
			obstacle is Node2D
			and _position_matches_any(
				(obstacle as Node2D).global_position,
				layout.obstacle_positions
			)
		):
			current_region_obstacles.append(obstacle)
		spawned_obstacle_ids.append(
			StringName(obstacle.get("obstacle_id"))
		)
		_expect(
			obstacle is StaticBody2D
			and int(obstacle.get("collision_layer")) & BiomeObstacle.MOVEMENT_BLOCK_LAYER_BIT != 0,
			"environment obstacle is a physical body on the shared movement layer"
		)
		_expect(
			obstacle.is_in_group("environment_obstacles")
			and obstacle.is_in_group("spawn_blockers"),
			"environment obstacle participates in spawn validation"
		)
	_expect(
		current_region_obstacles.size() == layout.obstacle_positions.size(),
		"obstacle system creates every current-region configured obstacle"
	)
	for required_id in [
		&"large_rock",
		&"forest_tree"
	]:
		_expect(
			spawned_obstacle_ids.has(required_id),
			"%s is present in the starting biome (%s)"
			% [String(required_id), str(spawned_obstacle_ids)]
		)
	if layout.obstacle_ids.has(&"boundary_fence"):
		_expect(
			spawned_obstacle_ids.has(&"boundary_fence"),
			"generated solid boundary is represented at runtime"
		)
	else:
		_expect(
			not layout.fall_zone_rects.is_empty(),
			"fall/cliff boundary replaces a solid fence when the generated edge is void"
		)

	for safe_point in [
		Vector2.ZERO,
		Vector2(0.0, -180.0),
		Vector2(0.0, 180.0),
		Vector2(-120.0, 0.0),
		Vector2(120.0, 0.0)
	]:
		_expect(
			not obstacle_system.is_position_blocked(safe_point),
			"central combat corridor remains open at %s" % safe_point
		)

	if not current_region_obstacles.is_empty():
		var first_obstacle := current_region_obstacles[0] as Node2D
		_expect(
			obstacle_system.is_position_blocked(
				first_obstacle.global_position
			),
			"obstacle center is rejected by placement validation"
		)
		_expect(
			_physics_query_finds_obstacle(main, first_obstacle),
			"physics space contains the generated obstacle collision"
		)

	var crates: Array = resource_crate_system.get_active_crates()
	var crate_ids: Array[StringName] = resource_crate_system.get_active_crate_ids()
	var active_crate_positions: Array[Vector2] = []
	var current_region_crates: Array = []
	for active_crate in crates:
		if active_crate is Node2D:
			var active_position := (active_crate as Node2D).global_position
			active_crate_positions.append(active_position)
			if _position_matches_any(active_position, layout.crate_positions):
				current_region_crates.append(active_crate)
	var configured_crate_blockers: Array[String] = []
	for configured_position in layout.crate_positions:
		configured_crate_blockers.append(
			"%s:obstacle=%s,hazard=%s" % [
				str(configured_position),
				str(obstacle_system.is_position_blocked(configured_position)),
				str(hazard_system.is_position_hazardous(configured_position))
			]
		)
	_expect(
		crates.size() >= layout.crate_positions.size()
		and current_region_crates.size() == layout.crate_positions.size(),
		"resource crate system creates every current-region configured crate (%d current/%d configured, %d active total configured=%s active=%s)"
		% [
			current_region_crates.size(),
			layout.crate_positions.size(),
			crates.size(),
			str(layout.crate_positions),
			str(active_crate_positions)
		]
	)
	if current_region_crates.size() != layout.crate_positions.size():
		push_error("crate blockers: " + str(configured_crate_blockers))
	_expect(
		crate_ids.has(&"common") and crate_ids.has(&"medical"),
		"starting biome provides common and medical resources"
	)
	for crate in current_region_crates:
		var crate_node := crate as SupplyCrate
		if crate_node == null:
			continue
		_expect(
			not obstacle_system.is_position_blocked(
				crate_node.global_position
			),
			"resource crate does not overlap a physical obstacle"
		)
		_expect(
			not hazard_system.is_position_hazardous(
				crate_node.global_position
			),
			"resource crate does not overlap an environment hazard"
		)
		_expect(
			_distance_to_nearest_player(crate_node.global_position)
			<= layout.logical_tile_scale * 30.0,
			"resource crate is reachable from the party start"
		)
	_expect(
		_crate_loot_contains(current_region_crates, &"common", GameConstants.DROP_MONEY)
		and _crate_loot_contains(
			current_region_crates,
			&"medical",
			GameConstants.DROP_HEALTH
		),
		"crate loot changes between common and medical containers"
	)

	if player != null:
		player.global_position = Vector2.ZERO
	var lane_enemy := enemy_system.spawn_enemy(
		&"survival_zombie",
		Vector2(0.0, -430.0)
	) as BasicEnemy
	_expect(lane_enemy != null, "a zombie can spawn in the open north lane")
	if lane_enemy != null and player != null:
		var initial_distance := lane_enemy.global_position.distance_to(
			player.global_position
		)
		for _frame in range(90):
			await physics_frame
		var final_distance := lane_enemy.global_position.distance_to(
			player.global_position
		)
		_expect(
			final_distance < initial_distance - 80.0,
			"zombie advances through the preserved central corridor"
		)
		lane_enemy.queue_free()

	survival_mode.stop_mode()
	await process_frame
	await process_frame
	_expect(
		obstacle_system.get_active_obstacles().is_empty(),
		"physical obstacles are removed when survival stops"
	)
	_expect(
		resource_crate_system.get_active_crates().is_empty(),
		"environment resource crates are removed when survival stops"
	)
	_finish()

func _physics_query_finds_obstacle(
	main: Node2D,
	obstacle: Node2D
) -> bool:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = obstacle.global_position
	query.collision_mask = 1
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var results := main.get_world_2d().direct_space_state.intersect_point(
		query,
		16
	)
	for result in results:
		if result.get("collider") == obstacle:
			return true
	return false

func _distance_to_nearest_player(position: Vector2) -> float:
	var nearest := INF
	for player in get_nodes_in_group("players"):
		if player is Node2D:
			nearest = minf(
				nearest,
				position.distance_to((player as Node2D).global_position)
			)
	return nearest

func _position_matches_any(position: Vector2, expected_positions: Array[Vector2]) -> bool:
	for expected in expected_positions:
		if position.distance_to(expected) <= 0.5:
			return true
	return false

func _crate_loot_contains(
	crates: Array,
	crate_id: StringName,
	drop_type: StringName
) -> bool:
	for crate in crates:
		var crate_node := crate as SupplyCrate
		if (
			crate_node == null
			or StringName(
				crate_node.get_meta("biome_crate_id", &"")
			) != crate_id
			or crate_node.loot_table == null
		):
			continue
		for entry in crate_node.loot_table.entries:
			if entry != null and entry.drop_type == drop_type:
				return true
	return false

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("ZOMBIE_ENVIRONMENT_MILESTONE_SMOKE_TEST: PASS")
		quit(0)
		return
	print(
		"ZOMBIE_ENVIRONMENT_MILESTONE_SMOKE_TEST: FAIL (%d)"
		% failures.size()
	)
	quit(1)
