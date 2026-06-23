extends GutTest
## Environment A2 — Cluster di integrazione con boot condiviso di main.tscn.
##
## Questi test bootavano ognuno `main.tscn` da solo (10 file legacy, 10 cold-start).
## Qui la scena principale viene istanziata UNA volta in before_all e riusata: ogni
## test riavvia survival (`set_mode`) per isolare il mondo. È il punto in cui il
## taglio dei boot rende il massimo.
##
## Migra e accorpa (batch corrente — streaming regioni):
##   tests/milestone_10_full_region_streaming_smoke_test.gd
##   tests/milestone_10_isometric_performance_smoke_test.gd
##   tests/milestone_10_legacy_cleanup_smoke_test.gd

const MainSceneFixture = preload("res://tests/support/main_scene_fixture.gd")

const PERFORMANCE_ENEMY_IDS: Array[StringName] = [
	&"survival_zombie", &"survival_runner", &"survival_tank", &"survival_shooter"
]

var _scene: MainSceneFixture
var _default_spawn_interval: float = 0.0

func before_all() -> void:
	_scene = MainSceneFixture.new()
	assert_true(_scene.boot(self), "main scene can be loaded")
	await wait_frames(3)
	var wave_manager := _scene.node(&"wave_manager") as WaveManager
	if wave_manager != null:
		_default_spawn_interval = wave_manager.spawn_interval

func before_each() -> void:
	# Ripristina i tunable che i singoli test mutano, così l'ordine non conta.
	var wave_manager := _scene.node(&"wave_manager") as WaveManager
	if wave_manager != null:
		wave_manager.spawn_interval = _default_spawn_interval
	var local_multiplayer := _scene.node(&"local_multiplayer_manager") as LocalMultiplayerManager
	if local_multiplayer != null:
		for slot in [4, 3, 2]:
			local_multiplayer.deactivate_slot(slot)

func after_each() -> void:
	# Indispensabile: senza stop, il prossimo set_mode(SURVIVAL) non ricostruisce.
	_scene.stop_survival()
	await wait_frames(1)

func after_all() -> void:
	_scene.teardown()
	_scene = null

# --- streaming completo della regione corrente e dei vicini -----------------
# (milestone_10_full_region_streaming)

func test_full_region_streaming() -> void:
	var streamer = _scene.node(&"world_region_streamer")
	var biome_manager := _scene.node(&"biome_manager") as BiomeManager
	var world_runtime := _scene.node(&"world_runtime") as WorldRuntime
	var terrain_generator := _scene.node(&"terrain_generator") as TerrainGenerator
	var obstacle_system := _scene.node(&"obstacle_system") as ObstacleSystem
	var hazard_system := _scene.node(&"hazard_system") as HazardSystem
	var crate_system := _scene.node(&"resource_crate_system") as ResourceCrateSystem
	assert_not_null(streamer, "world region streamer is available")
	assert_not_null(terrain_generator, "terrain generator is available")
	assert_not_null(world_runtime, "world runtime is available")
	if streamer == null or biome_manager == null or world_runtime == null:
		return

	assert_true(_scene.start_survival({
		"world_seed": 81818, "biome_map_width": 3, "biome_map_height": 3, "extra_edge_chance": 0.5
	}), "survival starts with full region streaming")
	await wait_frames(1)
	await wait_physics_frames(1)

	var graph := biome_manager.get_world_graph()
	var current_cell := biome_manager.get_current_biome_cell()
	assert_not_null(graph, "world graph exists")
	assert_not_null(current_cell, "current region exists")
	if graph == null or current_cell == null:
		return

	var expected_active := _expected_active_ids(graph, current_cell.id)
	var streamed: Array[StringName] = streamer.get_streamed_region_ids()
	assert_true(_same_ids(streamed, expected_active), "streamer contains current region plus connected neighbors")
	for region_id in expected_active:
		assert_eq(int(streamer.get_content_level(region_id)), 2, "%s is streamed as FULL gameplay content" % String(region_id))
	var distant_id := _find_distant_region(graph, current_cell.id)
	if not distant_id.is_empty():
		assert_eq(int(streamer.get_content_level(distant_id)), 0, "distant regions remain uninstantiated data")

	var current_counts: Dictionary = streamer.get_region_content_counts(current_cell.id)
	var current_layout := current_cell.generated_layout
	assert_eq(int(current_counts.get("tiles", 0)), current_layout.zone_size.x * current_layout.zone_size.y, "current region has a full tile layer")
	assert_eq(int(current_counts.get("obstacles", 0)), current_layout.obstacle_positions.size(), "current region streams all obstacles")
	assert_eq(int(current_counts.get("hazards", 0)), current_layout.hazard_positions.size(), "current region streams all hazards")

	var neighbor_id := _first_neighbor_with_content(graph, biome_manager, current_cell.id)
	assert_false(neighbor_id.is_empty(), "at least one connected neighbor has generated content")
	if not neighbor_id.is_empty():
		_assert_neighbor_gameplay_queries(streamer, biome_manager, obstacle_system, hazard_system, neighbor_id)
		await _assert_neighbor_crate_persistence(streamer, graph, biome_manager, world_runtime,
			terrain_generator, obstacle_system, hazard_system, crate_system, current_cell.id, neighbor_id)

	assert_true(_obstacle_keys_unique(obstacle_system), "streamed obstacle keys are unique")
	assert_true(_crate_keys_unique(crate_system), "streamed crate keys are unique")

# --- profilo prestazioni dello streaming bilanciato -------------------------
# (milestone_10_isometric_performance)

func test_isometric_streaming_performance() -> void:
	var local_multiplayer := _scene.node(&"local_multiplayer_manager") as LocalMultiplayerManager
	var player_manager := _scene.node(&"player_manager") as PlayerManager
	var wave_manager := _scene.node(&"wave_manager") as WaveManager
	var biome_manager := _scene.node(&"biome_manager") as BiomeManager
	var enemy_system := _scene.node(&"enemy_system") as EnemySystem
	var streamer = _scene.node(&"world_region_streamer")
	assert_not_null(local_multiplayer, "local multiplayer manager is available")
	assert_not_null(enemy_system, "enemy system is available")
	assert_not_null(streamer, "world region streamer is available")
	if local_multiplayer == null or player_manager == null or enemy_system == null or streamer == null:
		return

	for slot in range(2, 5):
		local_multiplayer.activate_slot(slot)
	wave_manager.spawn_interval = 0.08
	assert_true(_scene.start_survival({
		"world_seed": 641004, "biome_map_width": 3, "biome_map_height": 3, "extra_edge_chance": 0.5
	}), "survival starts with a 3x3 isometric world")
	await wait_frames(1)
	await wait_physics_frames(1)
	await wait_frames(1)

	assert_eq(biome_manager.get_generated_biome_map().size(), 9, "3x3 biome map is generated")
	var streamed_ids: Array[StringName] = streamer.get_streamed_region_ids()
	assert_gte(streamed_ids.size(), 2, "streamer loads current region and connected neighbors")
	for region_id in streamed_ids:
		assert_eq(int(streamer.get_content_level(region_id)), 2, "%s is streamed as FULL gameplay content" % String(region_id))
		var counts: Dictionary = streamer.get_region_content_counts(region_id)
		var region := biome_manager.get_world_graph().get_region(region_id)
		var expected_tiles := (region.size_tiles.x * region.size_tiles.y if region != null
			else BiomeEnvironmentLayout.DEFAULT_ZONE_SIZE.x * BiomeEnvironmentLayout.DEFAULT_ZONE_SIZE.y)
		assert_eq(int(counts.get("tiles", 0)), expected_tiles, "%s has the full 500x500 tile layer" % String(region_id))

	var tile_layers := _scene.nodes(&"biome_tile_layers")
	assert_gte(tile_layers.size(), streamed_ids.size(), "streamed regions expose chunked tile layers")
	for layer_node in tile_layers:
		var tile_layer := layer_node as BiomeTileLayer
		if tile_layer == null:
			continue
		assert_eq(tile_layer.get_quality_preset(), &"balanced", "tile layer uses the balanced preset")
		assert_eq(tile_layer.get_visual_tile_count(), tile_layer.layout.zone_size.x * tile_layer.layout.zone_size.y,
			"tile layer caches every cell without per-tile nodes")
		assert_false(tile_layer.uses_procedural_fallback(), "tile layer resolves asset-backed tiles without missing assets")
	assert_true(_scene.nodes(&"biome_transition_gates").is_empty(), "survival path has no transition gates")
	assert_true(_scene.nodes(&"multi_region_renderer").is_empty(), "legacy multi-region renderer is not used in the standard path")

	var player_one := player_manager.players.get(1) as PlayerController
	assert_not_null(player_one, "player one is available for profiling")
	if player_one == null:
		return

	var spawned_enemies: Array[Node] = []
	for index in range(28):
		var angle := TAU * float(index) / 28.0
		var radius := 190.0 + float(index % 4) * 28.0
		var enemy := enemy_system.spawn_enemy(
			PERFORMANCE_ENEMY_IDS[index % PERFORMANCE_ENEMY_IDS.size()],
			player_one.global_position + Vector2.RIGHT.rotated(angle) * radius,
			null,
			{"wave_index": 4}
		)
		if enemy != null:
			spawned_enemies.append(enemy)
	assert_eq(spawned_enemies.size(), 28, "profiling scenario includes 28 mixed enemies")

	var profile_start := Time.get_ticks_usec()
	for _frame in range(120):
		await wait_physics_frames(1)
	var profile_elapsed_usec := Time.get_ticks_usec() - profile_start
	var average_frame_msec := float(profile_elapsed_usec) / 1000.0 / 120.0
	gut.p("ISOMETRIC_PROFILE: %d streamed regions, %d enemies, avg %.2f ms"
		% [streamed_ids.size(), spawned_enemies.size(), average_frame_msec])
	# Tetto sul tempo per frame: il preset "balanced" evita i nodi per-tile, quindi
	# una regressione vera (streaming a contenuto pieno di tutte le 9 regioni, o
	# nodi per cella) spingerebbe il frame a centinaia di ms. Il vecchio test usava
	# 35 ms in un processo dedicato; qui il boot condiviso GUT ha un baseline più
	# alto, quindi il tetto è 45 ms (mantiene il segnale anti-regressione senza
	# essere flaky sul margine di 1 ms).
	assert_lt(average_frame_msec, 45.0, "balanced isometric streaming stays within the frame budget")

	for enemy in spawned_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()

# --- assenza di renderer/gate legacy nel percorso standard ------------------
# (milestone_10_legacy_cleanup)

func test_no_legacy_renderer_or_gates() -> void:
	_assert_source_audit()

	var biome_manager := _scene.node(&"biome_manager") as BiomeManager
	var terrain_generator := _scene.node(&"terrain_generator") as TerrainGenerator
	var transition_system := _scene.node(&"biome_transition_system") as BiomeTransitionSystem
	var streamer = _scene.node(&"world_region_streamer")
	assert_not_null(terrain_generator, "terrain generator is available")
	assert_not_null(transition_system, "legacy transition command API is available")
	assert_not_null(streamer, "world region streamer is available")
	if biome_manager == null or terrain_generator == null or streamer == null:
		return

	assert_true(_scene.start_survival({
		"world_seed": 101010, "biome_map_width": 3, "biome_map_height": 3, "extra_edge_chance": 0.5
	}), "survival starts with the asset-driven region streamer")
	await wait_frames(1)
	await wait_physics_frames(1)
	await wait_frames(1)

	var current_region_id := biome_manager.get_current_region_id()
	var streamed_ids: Array[StringName] = streamer.get_streamed_region_ids()
	assert_false(current_region_id.is_empty(), "current region is resolved")
	assert_gt(streamed_ids.size(), 1, "standard survival streams current plus neighbors")
	assert_eq(int(streamer.get_content_level(current_region_id)), 2, "current region is streamed as FULL gameplay content")
	var current_counts: Dictionary = streamer.get_region_content_counts(current_region_id)
	assert_gt(int(current_counts.get("tiles", 0)), 0, "current streamed region owns an asset tile layer")
	assert_not_null(terrain_generator.get_active_tile_layer(), "terrain generator tracks the current streamed tile layer")
	assert_eq(_count_named_prefix(_scene.main, "NeighborGround_"), 0, "standard survival does not instantiate legacy neighbor ground placeholders")
	assert_true(_scene.nodes(&"multi_region_renderer").is_empty(), "legacy multi-region renderer is not instantiated during standard streaming")
	assert_true(_scene.nodes(&"biome_transition_gates").is_empty(), "standard survival does not instantiate biome transition gate nodes")

# --- helper di asserzione (porting dei test legacy) -------------------------

func _assert_neighbor_gameplay_queries(streamer, biome_manager: BiomeManager,
		obstacle_system: ObstacleSystem, hazard_system: HazardSystem, neighbor_id: StringName) -> void:
	var cell := biome_manager.get_cell_by_region_id(neighbor_id)
	if cell == null or cell.generated_layout == null:
		assert_true(false, "%s has generated layout" % String(neighbor_id))
		return
	var layout := cell.generated_layout
	var offset: Vector2 = streamer.get_region_offset(neighbor_id)
	if not layout.obstacle_positions.is_empty():
		var obstacle_position: Vector2 = offset + layout.obstacle_positions.front()
		assert_true(obstacle_system.is_position_blocked(obstacle_position), "neighbor obstacle blocks movement before crossing")
	if not layout.hazard_positions.is_empty():
		var hazard_position: Vector2 = offset + layout.hazard_positions.front()
		assert_true(hazard_system.is_position_hazardous(hazard_position), "neighbor hazard is queryable before crossing")

func _assert_neighbor_crate_persistence(streamer, graph: WorldGraph, biome_manager: BiomeManager,
		world_runtime: WorldRuntime, terrain_generator: TerrainGenerator, obstacle_system: ObstacleSystem,
		hazard_system: HazardSystem, crate_system: ResourceCrateSystem,
		current_region_id: StringName, neighbor_id: StringName) -> void:
	var crate := _find_crate_for_region(crate_system, neighbor_id)
	assert_not_null(crate, "neighbor region streams a layout crate")
	if crate == null:
		return
	var crate_key := StringName(crate.get_meta("region_crate_key", &""))
	crate.opened.emit(crate, null)
	assert_true(world_runtime.is_region_item_consumed(neighbor_id, PersistentWorldState.CATEGORY_OPENED_CRATES, crate_key),
		"opening a neighbor crate records it in the neighbor ledger")
	var environment_container := _scene.main.get_node_or_null("World/EnvironmentProps")
	var pickup_container := _scene.main.get_node_or_null("World/Pickups")
	streamer.stream_world(graph, current_region_id, biome_manager, world_runtime,
		environment_container, pickup_container, terrain_generator, obstacle_system, hazard_system, crate_system)
	await wait_frames(1)
	assert_null(_find_crate_by_region_key(crate_system, neighbor_id, crate_key), "re-streaming skips the opened neighbor crate")

func _assert_source_audit() -> void:
	var controller_source := _read_text("res://game/modes/zombie/zombie_mode_controller.gd")
	var resolve_body := _extract_between(controller_source,
		"func _resolve_components() -> void:", "func _connect_wave_manager() -> void:")
	assert_false(resolve_body.contains("MultiRegionRenderer.new()"), "component resolution does not create the legacy renderer")
	assert_false(controller_source.contains("BiomeTransitionGate"), "zombie mode controller has no transition gate dependency")
	var transition_source := _read_text("res://game/modes/zombie/biome_transition_system.gd")
	var configure_body := _extract_between(transition_source,
		"func configure_biome(biome: BiomeDefinition) -> void:", "func stop_run() -> void:")
	assert_false(configure_body.contains("_spawn_gate"), "transition configuration does not spawn legacy gates")
	assert_false(configure_body.contains("_spawn_generated_map_gates"), "transition configuration does not spawn generated map gates")

# --- helper puri (porting dei test legacy) ----------------------------------

func _expected_active_ids(graph: WorldGraph, current_region_id: StringName) -> Array[StringName]:
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

func _find_distant_region(graph: WorldGraph, current_region_id: StringName) -> StringName:
	var active := {current_region_id: true}
	for neighbor_id in graph.get_connected_region_ids(current_region_id):
		active[neighbor_id] = true
	for region_id in graph.regions.keys():
		if not active.has(region_id):
			return StringName(region_id)
	return &""

func _first_neighbor_with_content(graph: WorldGraph, biome_manager: BiomeManager, current_region_id: StringName) -> StringName:
	for neighbor_id in graph.get_connected_region_ids(current_region_id):
		var cell := biome_manager.get_cell_by_region_id(neighbor_id)
		if cell != null and cell.generated_layout != null:
			return neighbor_id
	return &""

func _find_crate_for_region(crate_system: ResourceCrateSystem, region_id: StringName) -> SupplyCrate:
	for crate in crate_system.get_active_crates():
		if StringName(crate.get_meta("region_id", &"")) == region_id:
			return crate
	return null

func _find_crate_by_region_key(crate_system: ResourceCrateSystem, region_id: StringName, crate_key: StringName) -> SupplyCrate:
	for crate in crate_system.get_active_crates():
		if (StringName(crate.get_meta("region_id", &"")) == region_id
				and StringName(crate.get_meta("region_crate_key", &"")) == crate_key):
			return crate
	return null

func _obstacle_keys_unique(obstacle_system: ObstacleSystem) -> bool:
	var seen := {}
	for obstacle in obstacle_system.get_active_obstacles():
		var key := StringName(obstacle.get("obstacle_key"))
		if key.is_empty() or seen.has(key):
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

func _count_named_prefix(node: Node, prefix: String) -> int:
	var count := 1 if node.name.begins_with(prefix) else 0
	for child in node.get_children():
		count += _count_named_prefix(child, prefix)
	return count

func _extract_between(text: String, start_marker: String, end_marker: String) -> String:
	var start_index := text.find(start_marker)
	if start_index < 0:
		return ""
	start_index += start_marker.length()
	var end_index := text.find(end_marker, start_index)
	if end_index < 0:
		return text.substr(start_index)
	return text.substr(start_index, end_index - start_index)

func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text
