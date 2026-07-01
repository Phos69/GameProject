extends Node
class_name WorldRegionStreamer

enum ContentLevel { NONE = 0, DATA_ONLY = 1, FULL = 2 }

signal streamed_regions_changed(region_ids: Array[StringName])
signal visual_chunks_changed(loaded_count: int, pending_count: int)

const BIOME_TILE_LAYER_SCRIPT = preload(
	"res://game/modes/zombie/biome_tile_layer.gd"
)
const WORLD_CHUNK_VISIBILITY_CONTROLLER_SCRIPT = preload(
	"res://game/world/streaming/world_chunk_visibility_controller.gd"
)

@export_range(0, 3, 1) var active_radius: int = 1
@export_enum("performance", "balanced", "quality") var quality_preset: String = "balanced"
@export_range(0.0, 10.0, 0.1) var unload_grace_seconds: float = 2.0
@export_range(1, 4, 1) var max_region_builds_per_frame: int = 1
@export_range(0, 4, 1) var render_margin_chunks: int = 1
@export_range(0, 6, 1) var prefetch_margin_chunks: int = 2
@export_range(0, 8, 1) var retain_margin_chunks: int = 3
@export_range(0.1, 8.0, 0.1) var chunk_commit_budget_msec: float = 2.0
@export_range(1, 8, 1) var max_chunk_commits_per_frame: int = 2

var graph: WorldGraph
var biome_manager: BiomeManager
var world_runtime: WorldRuntime
var terrain_generator: TerrainGenerator
var obstacle_system: ObstacleSystem
var hazard_system: HazardSystem
var resource_crate_system: ResourceCrateSystem
var environment_container: Node
var pickup_container: Node
var current_region_id: StringName = &""
var anchor_region_id: StringName = &""
var manifest: IsometricEnvironmentManifest
var _is_streaming: bool = false
var _pending_region_ids: Array[StringName] = []
var _unload_deadlines: Dictionary = {}
var _chunk_visibility: WorldChunkVisibilityController

# String(region_id) -> { "level": int, "offset": Vector2, "env_root": Node2D,
# "pickup_root": Node2D, "tiles": int, "obstacles": int, "hazards": int,
# "crates": int }
var _entries: Dictionary = {}

func _ready() -> void:
	add_to_group("world_region_streamer")
	manifest = IsometricEnvironmentManifest.get_shared()
	_chunk_visibility = (
		WORLD_CHUNK_VISIBILITY_CONTROLLER_SCRIPT.new()
		as WorldChunkVisibilityController
	)
	_chunk_visibility.visual_chunks_changed.connect(
		_on_visual_chunks_changed
	)
	set_process(true)

func _process(_delta: float) -> void:
	if not _is_streaming:
		return
	_process_pending_regions()
	_process_scheduled_unloads()
	_configure_chunk_visibility()
	_chunk_visibility.process(_entries, get_viewport())

func start_world(
	next_graph: WorldGraph,
	center_region_id: StringName,
	next_biome_manager: BiomeManager,
	next_world_runtime: WorldRuntime,
	next_environment_container: Node,
	next_pickup_container: Node,
	next_terrain_generator: TerrainGenerator,
	next_obstacle_system: ObstacleSystem,
	next_hazard_system: HazardSystem,
	next_resource_crate_system: ResourceCrateSystem
) -> bool:
	var must_reset := (
		not _is_streaming
		or graph != next_graph
		or biome_manager != next_biome_manager
		or environment_container != next_environment_container
	)
	if must_reset:
		clear()
		graph = next_graph
		biome_manager = next_biome_manager
		world_runtime = next_world_runtime
		environment_container = next_environment_container
		pickup_container = next_pickup_container
		terrain_generator = next_terrain_generator
		obstacle_system = next_obstacle_system
		hazard_system = next_hazard_system
		resource_crate_system = next_resource_crate_system
		if graph == null or biome_manager == null or environment_container == null:
			return false
		var center := graph.get_region(center_region_id)
		if center == null:
			return false
		current_region_id = center_region_id
		anchor_region_id = (
			graph.start_region_id
			if not graph.start_region_id.is_empty()
			else center_region_id
		)
		_prewarm_world_assets()
		_configure_chunk_visibility()
		_prepare_systems(center.biome_id)
		_is_streaming = true
		for region_id in _collect_runtime_region_ids(center_region_id):
			var region := graph.get_region(region_id)
			if region != null:
				_stream_region(region, region_id == center_region_id, false)
		_finalize_hazards()
		if terrain_generator != null and terrain_generator.async_tile_build:
			_chunk_visibility.refresh(_entries, get_viewport(), true)
		else:
			# Sync/debug starts have no loading coroutine to consume the regular
			# two-chunk frame budget, so make the initial camera area ready here.
			_chunk_visibility.prepare_area_immediate(_entries, get_viewport())
		_emit_streamed_regions_changed()
		return true
	_update_dependencies(
		next_world_runtime,
		next_pickup_container,
		next_terrain_generator,
		next_obstacle_system,
		next_hazard_system,
		next_resource_crate_system
	)
	return set_current_region(center_region_id)

func stream_world(
	next_graph: WorldGraph,
	center_region_id: StringName,
	next_biome_manager: BiomeManager,
	next_world_runtime: WorldRuntime,
	next_environment_container: Node,
	next_pickup_container: Node,
	next_terrain_generator: TerrainGenerator,
	next_obstacle_system: ObstacleSystem,
	next_hazard_system: HazardSystem,
	next_resource_crate_system: ResourceCrateSystem
) -> bool:
	return start_world(
		next_graph,
		center_region_id,
		next_biome_manager,
		next_world_runtime,
		next_environment_container,
		next_pickup_container,
		next_terrain_generator,
		next_obstacle_system,
		next_hazard_system,
		next_resource_crate_system
	)

func set_current_region(region_id: StringName) -> bool:
	if not _is_streaming or graph == null:
		return false
	var center := graph.get_region(region_id)
	if center == null:
		return false
	current_region_id = region_id
	_configure_active_biome(center.biome_id)
	var desired_ids := _collect_runtime_region_ids(region_id)
	var desired_lookup := {}
	for desired_id in desired_ids:
		desired_lookup[String(desired_id)] = true
		_unload_deadlines.erase(String(desired_id))
		if not _has_region_entry(desired_id) and not _pending_region_ids.has(desired_id):
			if desired_id == region_id:
				_pending_region_ids.push_front(desired_id)
			else:
				_pending_region_ids.append(desired_id)
	for pending_id in _pending_region_ids.duplicate():
		if not desired_lookup.has(String(pending_id)):
			_pending_region_ids.erase(pending_id)
	for key in _entries.keys():
		var existing_id := StringName(key)
		if desired_lookup.has(String(existing_id)):
			continue
		_unload_deadlines[String(existing_id)] = (
			Time.get_ticks_msec() + int(unload_grace_seconds * 1000.0)
		)
	_mark_current_tile_layer(region_id)
	_configure_chunk_visibility()
	_chunk_visibility.refresh(_entries, get_viewport(), true)
	_emit_streamed_regions_changed()
	return true

func prepare_area(_world_rect: Rect2 = Rect2()) -> bool:
	_configure_chunk_visibility()
	return _chunk_visibility.prepare_area(
		_entries,
		get_viewport(),
		_world_rect
	)

func is_area_ready(world_rect: Rect2 = Rect2()) -> bool:
	return (
		_is_streaming
		and _chunk_visibility.is_area_ready(
			_entries,
			get_viewport(),
			world_rect
		)
	)

func get_loaded_visual_chunk_keys() -> Array[StringName]:
	return _chunk_visibility.loaded_chunk_keys.duplicate()

func get_pending_visual_chunk_keys() -> Array[StringName]:
	return _chunk_visibility.get_pending_chunk_keys()

func get_streaming_stats() -> Dictionary:
	var stats := {
		"gameplay_regions": get_streamed_region_ids().size(),
		"pending_regions": _pending_region_ids.size(),
		"scheduled_unloads": _unload_deadlines.size()
	}
	stats.merge(_chunk_visibility.get_streaming_stats(), true)
	return stats

func is_streaming_graph(candidate: WorldGraph) -> bool:
	return _is_streaming and graph == candidate

func clear() -> void:
	for key in _entries.keys().duplicate():
		_unstream_region(StringName(key))
	_entries.clear()
	_pending_region_ids.clear()
	_unload_deadlines.clear()
	if _chunk_visibility != null:
		_chunk_visibility.clear()
	graph = null
	biome_manager = null
	world_runtime = null
	environment_container = null
	pickup_container = null
	current_region_id = &""
	anchor_region_id = &""
	_is_streaming = false

func get_streamed_region_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for key in _entries.keys():
		var entry := _entries[key] as Dictionary
		if int(entry.get("level", ContentLevel.NONE)) == ContentLevel.FULL:
			ids.append(StringName(key))
	ids.sort()
	return ids

func is_region_streamed(region_id: StringName) -> bool:
	return get_content_level(region_id) == ContentLevel.FULL

func _has_region_entry(region_id: StringName) -> bool:
	return _entries.has(String(region_id))

func get_content_level(region_id: StringName) -> int:
	return int(
		(_entries.get(String(region_id), {}) as Dictionary).get(
			"level",
			ContentLevel.NONE
		)
	)

func get_region_offset(region_id: StringName) -> Vector2:
	return (
		_entries.get(String(region_id), {}) as Dictionary
	).get("offset", Vector2.ZERO)

func get_region_content_counts(region_id: StringName) -> Dictionary:
	var entry := _entries.get(String(region_id), {}) as Dictionary
	return {
		"tiles": int(entry.get("tiles", 0)),
		"obstacles": int(entry.get("obstacles", 0)),
		"hazards": int(entry.get("hazards", 0)),
		"crates": int(entry.get("crates", 0))
	}

func get_region_environment_root_instance_id(region_id: StringName) -> int:
	var entry := _entries.get(String(region_id), {}) as Dictionary
	var env_root := entry.get("env_root") as Node
	return (
		env_root.get_instance_id()
		if env_root != null and is_instance_valid(env_root)
		else 0
	)

func get_chunk_coords_for_world_rect(
	region_id: StringName,
	world_rect: Rect2,
	margin_chunks: int = 0
) -> Array[Vector2i]:
	return _chunk_visibility.get_chunk_coords_for_world_rect(
		_entries,
		region_id,
		world_rect,
		maxi(margin_chunks, 0)
	)

func _prepare_systems(center_biome_id: StringName) -> void:
	var center_biome := biome_manager.get_biome_definition(center_biome_id) as BiomeDefinition
	if terrain_generator != null and terrain_generator.has_method("begin_streaming_run"):
		terrain_generator.begin_streaming_run(center_biome)
	if obstacle_system != null and obstacle_system.has_method("begin_streaming_run"):
		obstacle_system.begin_streaming_run(center_biome)
	if hazard_system != null and hazard_system.has_method("begin_streaming_run"):
		hazard_system.begin_streaming_run(center_biome)
	if (
		resource_crate_system != null
		and resource_crate_system.has_method("begin_streaming_run")
	):
		resource_crate_system.begin_streaming_run(center_biome)

func _prewarm_world_assets() -> void:
	if graph == null or biome_manager == null:
		return
	var warmed_biomes := {}
	for region in graph.get_regions_sorted():
		if warmed_biomes.has(region.biome_id):
			continue
		var layout := _layout_for_region(region)
		var biome := biome_manager.get_biome_definition(
			region.biome_id
		) as BiomeDefinition
		if layout == null or biome == null or biome.palette == null:
			continue
		var prewarmer := BIOME_TILE_LAYER_SCRIPT.new() as BiomeTileLayer
		if prewarmer == null:
			continue
		prewarmer.prewarm_assets(
			layout,
			biome.palette,
			biome.biome_id,
			manifest
		)
		prewarmer.free()
		warmed_biomes[region.biome_id] = true

func _configure_active_biome(biome_id: StringName) -> void:
	var biome := biome_manager.get_biome_definition(biome_id) as BiomeDefinition
	for system in [
		terrain_generator,
		obstacle_system,
		hazard_system,
		resource_crate_system
	]:
		if system != null and system.has_method("set_active_biome"):
			system.call("set_active_biome", biome)

func _update_dependencies(
	next_world_runtime: WorldRuntime,
	next_pickup_container: Node,
	next_terrain_generator: TerrainGenerator,
	next_obstacle_system: ObstacleSystem,
	next_hazard_system: HazardSystem,
	next_resource_crate_system: ResourceCrateSystem
) -> void:
	world_runtime = next_world_runtime
	pickup_container = next_pickup_container
	terrain_generator = next_terrain_generator
	obstacle_system = next_obstacle_system
	hazard_system = next_hazard_system
	resource_crate_system = next_resource_crate_system

func _stream_region(
	region: WorldRegion,
	is_current: bool,
	async_tiles: bool = false
) -> void:
	if region == null or _has_region_entry(region.region_id):
		return
	var layout := _layout_for_region(region)
	var biome := biome_manager.get_biome_definition(region.biome_id) as BiomeDefinition
	if layout == null or biome == null or biome.palette == null:
		return
	var offset := _offset_for_region(region, layout.logical_tile_scale)
	var env_root := Node2D.new()
	env_root.name = "StreamedRegion_%s" % String(region.region_id)
	env_root.position = offset
	env_root.y_sort_enabled = true
	environment_container.add_child(env_root)
	var pickup_root: Node2D = null
	if pickup_container != null:
		pickup_root = Node2D.new()
		pickup_root.name = "StreamedPickups_%s" % String(region.region_id)
		pickup_root.position = offset
		pickup_root.y_sort_enabled = true
		pickup_container.add_child(pickup_root)
	var tile_layer := _stream_tile_layer(
		env_root,
		layout,
		biome,
		is_current,
		async_tiles
	)
	var obstacle_count := _stream_obstacles(env_root, layout, biome, region.region_id)
	var hazard_count := _stream_hazards(env_root, layout, biome, region.region_id)
	var crate_count := _stream_crates(pickup_root, layout, biome, region.region_id, offset)
	_entries[String(region.region_id)] = {
		"level": ContentLevel.DATA_ONLY if async_tiles else ContentLevel.FULL,
		"offset": offset,
		"env_root": env_root,
		"pickup_root": pickup_root,
		"tile_layer": tile_layer,
		"tiles": layout.zone_size.x * layout.zone_size.y,
		"obstacles": obstacle_count,
		"hazards": hazard_count,
		"crates": crate_count
	}
	if async_tiles and tile_layer != null:
		tile_layer.build_completed.connect(
			_on_region_tile_build_completed.bind(region.region_id),
			CONNECT_ONE_SHOT
		)

func _stream_tile_layer(
	parent: Node,
	layout: BiomeEnvironmentLayout,
	biome: BiomeDefinition,
	is_current: bool,
	async_build: bool
) -> BiomeTileLayer:
	var tile_layer := BIOME_TILE_LAYER_SCRIPT.new() as BiomeTileLayer
	if tile_layer == null:
		return null
	tile_layer.name = "TileLayer_%s" % String(biome.biome_id)
	parent.add_child(tile_layer)
	tile_layer.configure(
		layout,
		biome.palette,
		biome.biome_id,
		StringName(quality_preset),
		0,
		null,
		null,
		async_build,
		false
	)
	if terrain_generator != null and terrain_generator.has_method("register_streamed_tile_layer"):
		terrain_generator.register_streamed_tile_layer(tile_layer, is_current)
	return tile_layer

func _stream_obstacles(
	parent: Node,
	layout: BiomeEnvironmentLayout,
	biome: BiomeDefinition,
	region_id: StringName
) -> int:
	if obstacle_system == null:
		return 0
	var count := 0
	for index in range(layout.obstacle_positions.size()):
		if index >= layout.obstacle_ids.size():
			break
		var obstacle_id := layout.obstacle_ids[index]
		if not biome.obstacle_ids.has(obstacle_id):
			continue
		var size := (
			layout.obstacle_sizes[index]
			if index < layout.obstacle_sizes.size()
			else Vector2(48.0, 32.0)
		)
		var rotation_radians := (
			layout.obstacle_rotations[index]
			if index < layout.obstacle_rotations.size()
			else 0.0
		)
		var shape_id := (
			layout.obstacle_shape_ids[index]
			if index < layout.obstacle_shape_ids.size()
			else &"rectangle"
		)
		var obstacle := obstacle_system.create_obstacle_instance(
			obstacle_id,
			size,
			shape_id,
			rotation_radians,
			biome.palette.prop_color,
			biome.palette.hazard_color
		)
		if obstacle == null:
			continue
		obstacle.name = "%s%d" % [_pascal_case(String(obstacle_id)), index + 1]
		obstacle.obstacle_key = _region_obstacle_key(region_id, index, obstacle_id)
		parent.add_child(obstacle)
		if manifest != null and not manifest.blocks_movement(obstacle_id):
			obstacle.remove_from_group("spawn_blockers")
			obstacle.remove_from_group("environment_obstacles")
		obstacle.position = layout.obstacle_positions[index]
		ObstacleSystem.configure_perimeter_obstacle_visual(
			obstacle,
			layout,
			index,
			biome.biome_id
		)
		obstacle.set_meta("region_id", region_id)
		if index < layout.obstacle_rects.size():
			obstacle.set_meta("obstacle_record", layout.get_obstacle_record(index, manifest))
		obstacle_system.register_streamed_obstacle(obstacle, obstacle_id)
		count += 1
	return count

func _stream_hazards(
	parent: Node,
	layout: BiomeEnvironmentLayout,
	biome: BiomeDefinition,
	region_id: StringName
) -> int:
	if hazard_system == null:
		return 0
	var count := 0
	for index in range(layout.hazard_positions.size()):
		if index >= layout.hazard_ids.size():
			break
		var hazard_id := layout.hazard_ids[index]
		if not biome.hazard_ids.has(hazard_id):
			continue
		var size := (
			layout.hazard_sizes[index]
			if index < layout.hazard_sizes.size()
			else Vector2(150.0, 72.0)
		)
		var rotation_radians := (
			layout.hazard_rotations[index]
			if index < layout.hazard_rotations.size()
			else 0.0
		)
		var hazard := hazard_system.create_hazard_instance(
			hazard_id,
			size,
			rotation_radians,
			biome,
			layout,
			index,
			layout.hazard_positions[index]
		)
		if hazard == null:
			continue
		hazard.name = "%s%d" % [
			BiomeHazardCatalog.pascal_case(String(hazard_id)),
			index + 1
		]
		parent.add_child(hazard)
		hazard.position = layout.hazard_positions[index]
		hazard.set_meta("region_id", region_id)
		hazard_system.register_streamed_hazard(hazard, hazard_id)
		count += 1
	return count

func _stream_crates(
	parent: Node,
	layout: BiomeEnvironmentLayout,
	biome: BiomeDefinition,
	region_id: StringName,
	offset: Vector2
) -> int:
	if parent == null or resource_crate_system == null:
		return 0
	var count := 0
	for index in range(layout.crate_positions.size()):
		if index >= layout.crate_ids.size():
			break
		var crate_id := layout.crate_ids[index]
		if not biome.crate_ids.has(crate_id):
			continue
		var crate_key := StringName("layout_%d" % index)
		if resource_crate_system.is_layout_crate_consumed_for_region(region_id, crate_key):
			continue
		var global_position := offset + layout.crate_positions[index]
		if not resource_crate_system.is_crate_position_valid(global_position):
			continue
		var crate := resource_crate_system.create_layout_crate(crate_id, index, region_id)
		if crate == null:
			continue
		parent.add_child(crate)
		crate.position = layout.crate_positions[index]
		resource_crate_system.register_streamed_crate(crate, crate_id)
		count += 1
	return count

func _collect_active_region_ids(center_region_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = [center_region_id]
	var depth := {center_region_id: 0}
	var frontier: Array[StringName] = [center_region_id]
	while not frontier.is_empty():
		var current: StringName = frontier.pop_front()
		var current_depth := int(depth[current])
		if current_depth >= active_radius:
			continue
		for neighbor_id in graph.get_connected_region_ids(current):
			if depth.has(neighbor_id):
				continue
			depth[neighbor_id] = current_depth + 1
			result.append(neighbor_id)
			frontier.append(neighbor_id)
	return result

func _collect_runtime_region_ids(
	center_region_id: StringName
) -> Array[StringName]:
	var result: Array[StringName] = []
	if (
		world_runtime != null
		and world_runtime.graph == graph
		and world_runtime.get_current_region_id() == center_region_id
	):
		result = world_runtime.get_active_region_ids()
	if result.is_empty():
		result = _collect_active_region_ids(center_region_id)
	result.sort()
	result.erase(center_region_id)
	result.push_front(center_region_id)
	return result

func _process_pending_regions() -> void:
	if _has_running_tile_worker():
		return
	var built := 0
	while not _pending_region_ids.is_empty() and built < max_region_builds_per_frame:
		var region_id: StringName = _pending_region_ids.pop_front()
		if _has_region_entry(region_id):
			continue
		var region := graph.get_region(region_id) if graph != null else null
		if region == null:
			continue
		_stream_region(region, region_id == current_region_id, true)
		built += 1
	if built > 0:
		_finalize_hazards()
		_emit_streamed_regions_changed()

func _has_running_tile_worker() -> bool:
	for entry_value in _entries.values():
		var entry := entry_value as Dictionary
		var tile_layer := entry.get("tile_layer") as BiomeTileLayer
		if tile_layer != null and tile_layer.is_building():
			return true
	return false

func _on_region_tile_build_completed(region_id: StringName) -> void:
	var entry := _entries.get(String(region_id), {}) as Dictionary
	if entry.is_empty():
		return
	entry["level"] = ContentLevel.FULL
	_entries[String(region_id)] = entry
	if region_id == current_region_id:
		_mark_current_tile_layer(region_id)
	_finalize_hazards()
	_configure_chunk_visibility()
	_chunk_visibility.refresh(_entries, get_viewport(), true)
	_emit_streamed_regions_changed()

func _process_scheduled_unloads() -> void:
	if _unload_deadlines.is_empty():
		return
	var now := Time.get_ticks_msec()
	for key in _unload_deadlines.keys().duplicate():
		var region_id := StringName(key)
		if _is_region_pinned(region_id):
			_unload_deadlines[key] = (
				now + int(unload_grace_seconds * 1000.0)
			)
			continue
		if _is_region_tile_building(region_id):
			_unload_deadlines[key] = (
				Time.get_ticks_msec() + int(unload_grace_seconds * 1000.0)
			)
			continue
		if now < int(_unload_deadlines[key]):
			continue
		_unload_deadlines.erase(key)
		_unstream_region(region_id)
		_emit_streamed_regions_changed()
		break

func _is_region_tile_building(region_id: StringName) -> bool:
	var entry := _entries.get(String(region_id), {}) as Dictionary
	var tile_layer := entry.get("tile_layer") as BiomeTileLayer
	return tile_layer != null and tile_layer.is_building()

func _is_region_pinned(region_id: StringName) -> bool:
	var seam_system := get_tree().get_first_node_in_group("region_seam_system")
	if seam_system == null or not seam_system.has_method("get_region_id_for_world_position"):
		return false
	for group_name in [
		&"players",
		&"enemies",
		&"bosses",
		&"world_streaming_pins"
	]:
		for node in get_tree().get_nodes_in_group(group_name):
			if not node is Node2D or node.is_queued_for_deletion():
				continue
			var node_region_id := StringName(
				seam_system.call(
					"get_region_id_for_world_position",
					(node as Node2D).global_position
				)
			)
			if node_region_id == region_id:
				return true
	return false

func _unstream_region(region_id: StringName) -> void:
	var key := String(region_id)
	if not _entries.has(key):
		return
	var entry := _entries[key] as Dictionary
	var env_root := entry.get("env_root") as Node
	var pickup_root := entry.get("pickup_root") as Node
	var tile_layer := entry.get("tile_layer") as BiomeTileLayer
	if (
		terrain_generator != null
		and tile_layer != null
		and terrain_generator.has_method("unregister_streamed_tile_layer")
	):
		terrain_generator.unregister_streamed_tile_layer(tile_layer)
	if obstacle_system != null:
		for obstacle in obstacle_system.get_active_obstacles():
			if env_root != null and env_root.is_ancestor_of(obstacle):
				obstacle_system.unregister_streamed_obstacle(obstacle)
	if hazard_system != null:
		for hazard in hazard_system.get_active_hazards():
			if env_root != null and env_root.is_ancestor_of(hazard):
				hazard_system.unregister_streamed_hazard(hazard)
	if resource_crate_system != null:
		for crate in resource_crate_system.get_active_crates():
			if pickup_root != null and pickup_root.is_ancestor_of(crate):
				resource_crate_system.unregister_streamed_crate(crate)
	if env_root != null and is_instance_valid(env_root):
		env_root.queue_free()
	if pickup_root != null and is_instance_valid(pickup_root):
		pickup_root.queue_free()
	_entries.erase(key)
	_pending_region_ids.erase(region_id)

func _mark_current_tile_layer(region_id: StringName) -> void:
	if terrain_generator == null:
		return
	var entry := _entries.get(String(region_id), {}) as Dictionary
	var tile_layer := entry.get("tile_layer") as BiomeTileLayer
	if tile_layer != null:
		terrain_generator.register_streamed_tile_layer(tile_layer, true)

func _finalize_hazards() -> void:
	if hazard_system != null and hazard_system.has_method("finalize_streamed_hazards"):
		hazard_system.finalize_streamed_hazards()

func _emit_streamed_regions_changed() -> void:
	streamed_regions_changed.emit(get_streamed_region_ids())

func _configure_chunk_visibility() -> void:
	if _chunk_visibility == null:
		return
	_chunk_visibility.configure(
		graph,
		biome_manager,
		current_region_id,
		StringName(quality_preset),
		render_margin_chunks,
		prefetch_margin_chunks,
		retain_margin_chunks,
		unload_grace_seconds,
		chunk_commit_budget_msec,
		max_chunk_commits_per_frame
	)

func _on_visual_chunks_changed(
	loaded_count: int,
	pending_count: int
) -> void:
	visual_chunks_changed.emit(loaded_count, pending_count)

func _layout_for_region(region: WorldRegion) -> BiomeEnvironmentLayout:
	if region.generated_layout != null:
		return region.generated_layout
	var cell := biome_manager.get_cell_by_region_id(region.region_id) as BiomeCell
	return cell.generated_layout if cell != null else null

func _offset_for_region(region: WorldRegion, tile_scale: float) -> Vector2:
	var anchor := graph.get_region(anchor_region_id)
	if anchor == null:
		return Vector2.ZERO
	return Vector2(region.world_origin - anchor.world_origin) * tile_scale

func _region_obstacle_key(
	region_id: StringName,
	index: int,
	obstacle_id: StringName
) -> StringName:
	return StringName(
		"%s:%s" % [
			String(region_id),
			String(ObstacleSystem.make_obstacle_key(&"streamed", index, obstacle_id))
		]
	)

func _pascal_case(value: String) -> String:
	var result := ""
	for part in value.split("_", false):
		result += part.capitalize()
	return result
