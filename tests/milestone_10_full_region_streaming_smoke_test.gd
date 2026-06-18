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
	var world_runtime := get_first_node_in_group("world_runtime") as WorldRuntime
	var streamer = get_first_node_in_group("world_region_streamer")
	var terrain_generator := get_first_node_in_group("terrain_generator") as TerrainGenerator
	var obstacle_system := get_first_node_in_group("obstacle_system") as ObstacleSystem
	var hazard_system := get_first_node_in_group("hazard_system") as HazardSystem
	var crate_system := get_first_node_in_group("resource_crate_system") as ResourceCrateSystem
	_expect(game_mode_manager != null, "game mode manager is available")
	_expect(wave_manager != null, "wave manager is available")
	_expect(biome_manager != null, "biome manager is available")
	_expect(world_runtime != null, "world runtime is available")
	_expect(streamer != null, "world region streamer is available")
	_expect(terrain_generator != null, "terrain generator is available")
	_expect(obstacle_system != null, "obstacle system is available")
	_expect(hazard_system != null, "hazard system is available")
	_expect(crate_system != null, "resource crate system is available")
	if (
		game_mode_manager == null
		or wave_manager == null
		or biome_manager == null
		or world_runtime == null
		or streamer == null
		or terrain_generator == null
		or obstacle_system == null
		or hazard_system == null
		or crate_system == null
	):
		_finish()
		return

	wave_manager.initial_delay = 100.0
	_expect(
		game_mode_manager.set_mode(GameConstants.MODE_SURVIVAL, {
			"world_seed": 81818,
			"biome_map_width": 5,
			"biome_map_height": 5,
			"extra_edge_chance": 0.5
		}),
		"survival starts with full region streaming"
	)
	await process_frame
	await physics_frame

	var graph := biome_manager.get_world_graph()
	var current_cell := biome_manager.get_current_biome_cell()
	_expect(graph != null, "world graph exists")
	_expect(current_cell != null, "current region exists")
	if graph == null or current_cell == null:
		_finish()
		return

	var expected_active := _expected_active_ids(graph, current_cell.id)
	var streamed: Array[StringName] = streamer.get_streamed_region_ids()
	_expect(
		_same_ids(streamed, expected_active),
		"streamer contains current region plus connected neighbors"
	)
	for region_id in expected_active:
		_expect(
			streamer.get_content_level(region_id) == 2,
			"%s is streamed as FULL gameplay content" % String(region_id)
		)
	var distant_id := _find_distant_region(graph, current_cell.id)
	if not distant_id.is_empty():
		_expect(
			streamer.get_content_level(distant_id) == 0,
			"distant regions remain uninstantiated data"
		)

	var current_counts: Dictionary = streamer.get_region_content_counts(current_cell.id)
	var current_layout := current_cell.generated_layout
	_expect(
		int(current_counts.get("tiles", 0)) == current_layout.zone_size.x * current_layout.zone_size.y,
		"current region has a full tile layer"
	)
	_expect(
		int(current_counts.get("obstacles", 0)) == current_layout.obstacle_positions.size(),
		"current region streams all obstacles"
	)
	_expect(
		int(current_counts.get("hazards", 0)) == current_layout.hazard_positions.size(),
		"current region streams all hazards"
	)

	var neighbor_id := _first_neighbor_with_content(graph, biome_manager, current_cell.id)
	_expect(not neighbor_id.is_empty(), "at least one connected neighbor has generated content")
	if not neighbor_id.is_empty():
		_assert_neighbor_gameplay_queries(streamer, biome_manager, obstacle_system, hazard_system, neighbor_id)
		await _assert_neighbor_crate_persistence(
			main,
			streamer,
			graph,
			biome_manager,
			world_runtime,
			terrain_generator,
			obstacle_system,
			hazard_system,
			crate_system,
			current_cell.id,
			neighbor_id
		)

	_expect(_obstacle_keys_unique(obstacle_system), "streamed obstacle keys are unique")
	_expect(_crate_keys_unique(crate_system), "streamed crate keys are unique")

	var survival_mode := get_first_node_in_group("survival_mode") as SurvivalMode
	if survival_mode != null:
		survival_mode.stop_mode()
	_finish()

func _assert_neighbor_gameplay_queries(
	streamer,
	biome_manager: BiomeManager,
	obstacle_system: ObstacleSystem,
	hazard_system: HazardSystem,
	neighbor_id: StringName
) -> void:
	var cell := biome_manager.get_cell_by_region_id(neighbor_id)
	if cell == null or cell.generated_layout == null:
		_expect(false, "%s has generated layout" % String(neighbor_id))
		return
	var layout := cell.generated_layout
	var offset: Vector2 = streamer.get_region_offset(neighbor_id)
	if not layout.obstacle_positions.is_empty():
		var obstacle_position: Vector2 = offset + layout.obstacle_positions.front()
		_expect(
			obstacle_system.is_position_blocked(obstacle_position),
			"neighbor obstacle blocks movement before crossing"
		)
	if not layout.hazard_positions.is_empty():
		var hazard_position: Vector2 = offset + layout.hazard_positions.front()
		_expect(
			hazard_system.is_position_hazardous(hazard_position),
			"neighbor hazard is queryable before crossing"
		)

func _assert_neighbor_crate_persistence(
	main: Node,
	streamer,
	graph: WorldGraph,
	biome_manager: BiomeManager,
	world_runtime: WorldRuntime,
	terrain_generator: TerrainGenerator,
	obstacle_system: ObstacleSystem,
	hazard_system: HazardSystem,
	crate_system: ResourceCrateSystem,
	current_region_id: StringName,
	neighbor_id: StringName
) -> void:
	var crate := _find_crate_for_region(crate_system, neighbor_id)
	_expect(crate != null, "neighbor region streams a layout crate")
	if crate == null:
		return
	var crate_key := StringName(crate.get_meta("region_crate_key", &""))
	crate.opened.emit(crate, null)
	_expect(
		world_runtime.is_region_item_consumed(
			neighbor_id,
			PersistentWorldState.CATEGORY_OPENED_CRATES,
			crate_key
		),
		"opening a neighbor crate records it in the neighbor ledger"
	)
	var environment_container := main.get_node_or_null("World/EnvironmentProps")
	var pickup_container := main.get_node_or_null("World/Pickups")
	streamer.stream_world(
		graph,
		current_region_id,
		biome_manager,
		world_runtime,
		environment_container,
		pickup_container,
		terrain_generator,
		obstacle_system,
		hazard_system,
		crate_system
	)
	await process_frame
	_expect(
		_find_crate_by_region_key(crate_system, neighbor_id, crate_key) == null,
		"re-streaming skips the opened neighbor crate"
	)

func _expected_active_ids(
	graph: WorldGraph,
	current_region_id: StringName
) -> Array[StringName]:
	var ids: Array[StringName] = [current_region_id]
	for neighbor_id in graph.get_connected_region_ids(current_region_id):
		ids.append(neighbor_id)
	ids.sort()
	return ids

func _same_ids(first: Array[StringName], second: Array[StringName]) -> bool:
	if first.size() != second.size():
		return false
	var a := first.duplicate()
	var b := second.duplicate()
	a.sort()
	b.sort()
	return a == b

func _find_distant_region(
	graph: WorldGraph,
	current_region_id: StringName
) -> StringName:
	var active := {current_region_id: true}
	for neighbor_id in graph.get_connected_region_ids(current_region_id):
		active[neighbor_id] = true
	for region_id in graph.regions.keys():
		if not active.has(region_id):
			return StringName(region_id)
	return &""

func _first_neighbor_with_content(
	graph: WorldGraph,
	biome_manager: BiomeManager,
	current_region_id: StringName
) -> StringName:
	for neighbor_id in graph.get_connected_region_ids(current_region_id):
		var cell := biome_manager.get_cell_by_region_id(neighbor_id)
		if cell != null and cell.generated_layout != null:
			return neighbor_id
	return &""

func _find_crate_for_region(
	crate_system: ResourceCrateSystem,
	region_id: StringName
) -> SupplyCrate:
	for crate in crate_system.get_active_crates():
		if StringName(crate.get_meta("region_id", &"")) == region_id:
			return crate
	return null

func _find_crate_by_region_key(
	crate_system: ResourceCrateSystem,
	region_id: StringName,
	crate_key: StringName
) -> SupplyCrate:
	for crate in crate_system.get_active_crates():
		if (
			StringName(crate.get_meta("region_id", &"")) == region_id
			and StringName(crate.get_meta("region_crate_key", &"")) == crate_key
		):
			return crate
	return null

func _obstacle_keys_unique(obstacle_system: ObstacleSystem) -> bool:
	var seen := {}
	for obstacle in obstacle_system.get_active_obstacles():
		var key := StringName(obstacle.get("obstacle_key"))
		if key.is_empty():
			return false
		if seen.has(key):
			return false
		seen[key] = true
	return true

func _crate_keys_unique(crate_system: ResourceCrateSystem) -> bool:
	var seen := {}
	for crate in crate_system.get_active_crates():
		var region_id := StringName(crate.get_meta("region_id", &""))
		var crate_key := StringName(crate.get_meta("region_crate_key", &""))
		if region_id.is_empty() or crate_key.is_empty():
			continue
		var key := "%s:%s" % [String(region_id), String(crate_key)]
		if seen.has(key):
			return false
		seen[key] = true
	return true

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("MILESTONE_10_FULL_REGION_STREAMING_SMOKE_TEST: PASS")
		quit(0)
		return
	print(
		"MILESTONE_10_FULL_REGION_STREAMING_SMOKE_TEST: FAIL (%d)"
		% failures.size()
	)
	quit(1)
