extends Node
class_name WorldRegionStreamer

enum ContentLevel { NONE = 0, DATA_ONLY = 1, FULL = 2 }
enum RegionState { ACTIVE = 0, UNLOADING = 1 }

signal streamed_regions_changed(region_ids: Array[StringName])
signal visual_chunks_changed(loaded_count: int, pending_count: int)

const BIOME_TILE_LAYER_SCRIPT = preload(
	"res://game/modes/zombie/biome_tile_layer.gd"
)
const WORLD_CHUNK_VISIBILITY_CONTROLLER_SCRIPT = preload(
	"res://game/world/streaming/world_chunk_visibility_controller.gd"
)
const WORLD_REGION_RETIREMENT_QUEUE_SCRIPT = preload(
	"res://game/world/streaming/world_region_retirement_queue.gd"
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
@export_range(0.1, 4.0, 0.1) var chunk_eviction_budget_msec: float = 0.5
@export_range(1, 4, 1) var max_chunk_evictions_per_frame: int = 1
@export_range(0.1, 8.0, 0.1) var content_commit_budget_msec: float = 1.5
@export_range(1, 8, 1) var max_content_commits_per_frame: int = 2
@export_range(0.1, 4.0, 0.1) var retirement_budget_msec: float = 0.8
@export_range(1, 16, 1) var max_retired_nodes_per_frame: int = 4

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
var manifest: EnvironmentAssetManifest
var _is_streaming: bool = false
var _pending_region_ids: Array[StringName] = []
# {"region_id": StringName, "kind": &"obstacle"|&"hazard"|&"crate", "index": int,
# "phase": int, "distance": float} — vedi _queue_region_content.
var _pending_content: Array[Dictionary] = []
var _unload_deadlines: Dictionary = {}
var _chunk_visibility: WorldChunkVisibilityController
var _retirement_queue: WorldRegionRetirementQueue
var _seam_system: Node

# String(region_id) -> { "state": int, "level": int, "offset": Vector2,
# "env_root": Node2D, "pickup_root": Node2D, "owned_obstacles": Array,
# "owned_hazards": Array, "owned_crates": Array, "tiles": int,
# "obstacles": int, "hazards": int, "crates": int }
var _entries: Dictionary = {}
var _last_content_commit_count: int = 0
var _last_region_build_count: int = 0
var _last_content_commit_msec: float = 0.0
var _max_content_commit_msec: float = 0.0
var _last_unload_msec: float = 0.0
var _max_unload_msec: float = 0.0
var _pin_collection_count: int = 0

func _ready() -> void:
	add_to_group("world_region_streamer")
	manifest = EnvironmentAssetManifest.get_shared()
	_chunk_visibility = (
		WORLD_CHUNK_VISIBILITY_CONTROLLER_SCRIPT.new()
		as WorldChunkVisibilityController
	)
	_chunk_visibility.visual_chunks_changed.connect(
		_on_visual_chunks_changed
	)
	_ensure_retirement_queue()
	set_process(true)

func _process(_delta: float) -> void:
	if not _is_streaming:
		return
	_last_content_commit_count = 0
	_last_content_commit_msec = 0.0
	_last_region_build_count = 0
	_ensure_retirement_queue()
	_retirement_queue.begin_frame()
	_process_pending_regions()
	_process_pending_content()
	_process_scheduled_unloads()
	_configure_chunk_visibility()
	_chunk_visibility.process(_entries, get_viewport())
	var chunk_stats := _chunk_visibility.get_streaming_stats()
	if (
		_last_region_build_count == 0
		and _last_content_commit_count == 0
		and int(chunk_stats.get("last_frame_chunk_commits", 0)) == 0
	):
		_retirement_queue.process(
			retirement_budget_msec,
			max_retired_nodes_per_frame
		)

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

func set_current_region(region_id: StringName) -> bool:
	if not _is_streaming or graph == null:
		return false
	var center := graph.get_region(region_id)
	if center == null:
		return false
	if region_id == current_region_id:
		return true
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
	# Il controller chiamante invoca prepare_area(); i caller diretti vengono
	# comunque serviti dal normale process al frame successivo. Forzare qui un
	# refresh e subito dopo prepare_area duplicava scansioni/sort dei chunk.
	_chunk_visibility.mark_dirty()
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
	var active_build_phase := -1
	var max_geometry_phase_msec := 0.0
	for entry_value in _entries.values():
		var entry := entry_value as Dictionary
		var tile_layer := entry.get("tile_layer") as BiomeTileLayer
		if tile_layer == null:
			continue
		var build_stats := tile_layer.get_async_build_stats()
		active_build_phase = maxi(
			active_build_phase,
			int(build_stats.get("phase", -1))
		)
		max_geometry_phase_msec = maxf(
			max_geometry_phase_msec,
			float(build_stats.get("max_geometry_phase_msec", 0.0))
		)
	var stats := {
		"gameplay_regions": get_streamed_region_ids().size(),
		"pending_regions": _pending_region_ids.size(),
		"pending_content": _pending_content.size(),
		"scheduled_unloads": _unload_deadlines.size(),
		"last_frame_region_builds": _last_region_build_count,
		"last_frame_content_commits": _last_content_commit_count,
		"last_frame_content_commit_msec": _last_content_commit_msec,
		"max_content_commit_msec": _max_content_commit_msec,
		"content_commit_budget_msec": content_commit_budget_msec,
		"max_content_commits_per_frame": max_content_commits_per_frame,
		"active_tile_build_phase": active_build_phase,
		"max_tile_geometry_phase_msec": max_geometry_phase_msec,
		"last_region_unload_msec": _last_unload_msec,
		"max_region_unload_msec": _max_unload_msec,
		"pin_collection_count": _pin_collection_count
	}
	_ensure_retirement_queue()
	stats.merge(_retirement_queue.get_stats(), true)
	stats.merge(_chunk_visibility.get_streaming_stats(), true)
	return stats

func is_streaming_graph(candidate: WorldGraph) -> bool:
	return _is_streaming and graph == candidate

func clear() -> void:
	_ensure_retirement_queue()
	for key in _entries.keys().duplicate():
		_unstream_region(StringName(key))
	# clear() appartiene al teardown/reset completo, non alla transizione tra
	# regioni: qui e' corretto chiudere gli eventuali retirement ancora pendenti.
	_retirement_queue.flush()
	_entries.clear()
	_pending_region_ids.clear()
	_pending_content.clear()
	_unload_deadlines.clear()
	_seam_system = null
	if _chunk_visibility != null:
		_chunk_visibility.clear()
	graph = null
	biome_manager = null
	world_runtime = null
	environment_container = null
	pickup_container = null
	current_region_id = &""
	anchor_region_id = &""
	_last_content_commit_count = 0
	_last_region_build_count = 0
	_last_content_commit_msec = 0.0
	_max_content_commit_msec = 0.0
	_last_unload_msec = 0.0
	_max_unload_msec = 0.0
	_pin_collection_count = 0
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
		for obstacle_id in biome.obstacle_ids:
			var variant_ids := manifest.get_object_random_variant_ids(
				obstacle_id,
				biome.biome_id
			)
			if variant_ids.is_empty():
				variant_ids.append(biome.biome_id)
			for variant_id in variant_ids:
				EnvironmentObject.prewarm_asset_variant(
					obstacle_id,
					variant_id,
					biome.palette.prop_color,
					biome.palette.hazard_color
				)
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
		async_tiles,
		offset
	)
	var entry := {
		"region_id": region.region_id,
		"state": RegionState.ACTIVE,
		"level": ContentLevel.DATA_ONLY if async_tiles else ContentLevel.FULL,
		"offset": offset,
		"env_root": env_root,
		"pickup_root": pickup_root,
		"tile_layer": tile_layer,
		"tiles": layout.zone_size.x * layout.zone_size.y,
		"obstacles": 0,
		"hazards": 0,
		"crates": 0,
		"tiles_built": not async_tiles,
		"content_remaining": 0,
		"hazards_dirty": false,
		"owned_obstacles": [],
		"owned_hazards": [],
		"owned_crates": []
	}
	_entries[String(region.region_id)] = entry
	# Percorso sincrono (avvio run): tutto il contenuto e' pronto nello stesso
	# frame. Percorso asincrono (regione entrata nel raggio durante il gameplay):
	# ostacoli/hazard/casse vengono accodati e committati con un budget per frame
	# da _process_pending_content, per non concentrare decine di istanziazioni
	# con collider nel frame del cambio zona.
	var obstacle_count := 0
	var hazard_count := 0
	var crate_count := 0
	if not async_tiles:
		obstacle_count = _stream_obstacles(env_root, layout, biome, region.region_id)
		hazard_count = _stream_hazards(env_root, layout, biome, region.region_id)
		crate_count = _stream_crates(pickup_root, layout, biome, region.region_id, offset)
	entry["obstacles"] = obstacle_count
	entry["hazards"] = hazard_count
	entry["crates"] = crate_count
	if async_tiles:
		entry["content_remaining"] = _queue_region_content(
			region.region_id,
			layout,
			biome,
			offset
		)
		if tile_layer != null:
			tile_layer.build_completed.connect(
				_on_region_tile_build_completed.bind(region.region_id),
				CONNECT_ONE_SHOT
			)

func _stream_tile_layer(
	parent: Node,
	layout: BiomeEnvironmentLayout,
	biome: BiomeDefinition,
	is_current: bool,
	async_build: bool,
	terrain_texture_world_origin: Vector2
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
		false,
		terrain_texture_world_origin
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
	for index in range(
		mini(layout.obstacle_positions.size(), layout.obstacle_ids.size())
	):
		if _commit_obstacle(parent, layout, biome, region_id, index):
			count += 1
	return count

func _commit_obstacle(
	parent: Node,
	layout: BiomeEnvironmentLayout,
	biome: BiomeDefinition,
	region_id: StringName,
	index: int
) -> bool:
	if obstacle_system == null or parent == null or not is_instance_valid(parent):
		return false
	var obstacle_id := layout.obstacle_ids[index]
	if not biome.obstacle_ids.has(obstacle_id):
		return false
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
	var world_position := layout.obstacle_positions[index]
	if parent is Node2D:
		world_position = (parent as Node2D).to_global(world_position)
	var asset_variant_id := EnvironmentObject.resolve_random_asset_variant(
		obstacle_id,
		biome.biome_id,
		world_position
	)
	var obstacle := obstacle_system.create_obstacle_instance(
		obstacle_id,
		size,
		shape_id,
		rotation_radians,
		biome.palette.prop_color,
		biome.palette.hazard_color,
		asset_variant_id
	)
	if obstacle == null:
		return false
	obstacle.name = "%s%d" % [
		BiomeHazardCatalog.pascal_case(String(obstacle_id)),
		index + 1
	]
	obstacle.obstacle_key = _region_obstacle_key(region_id, index, obstacle_id)
	ObstacleSystem.attach_obstacle_at_layout_center(
		parent,
		obstacle,
		layout.obstacle_positions[index]
	)
	ObstacleSystem.configure_random_obstacle_asset_variant(
		obstacle,
		biome.biome_id,
		obstacle.global_position
	)
	if manifest != null and not manifest.blocks_movement(obstacle_id):
		obstacle.remove_from_group("spawn_blockers")
		obstacle.remove_from_group("environment_obstacles")
	ObstacleSystem.configure_perimeter_obstacle_visual(
		obstacle,
		layout,
		index,
		biome.biome_id
	)
	ObstacleSystem.configure_mesa_obstacle_visual(
		obstacle,
		layout,
		index,
		biome.biome_id,
		biome.palette
	)
	obstacle.set_meta("region_id", region_id)
	if index < layout.obstacle_rects.size():
		var record_variant_id := biome.biome_id
		if obstacle is EnvironmentObject:
			record_variant_id = (obstacle as EnvironmentObject).get_asset_variant_id()
		obstacle.set_meta(
			"obstacle_record",
			layout.get_obstacle_record(index, manifest, record_variant_id)
		)
	obstacle_system.register_streamed_obstacle(obstacle, obstacle_id)
	_register_region_owned_node(region_id, "owned_obstacles", obstacle)
	return true

func _stream_hazards(
	parent: Node,
	layout: BiomeEnvironmentLayout,
	biome: BiomeDefinition,
	region_id: StringName
) -> int:
	if hazard_system == null:
		return 0
	var count := 0
	for index in range(
		mini(layout.hazard_positions.size(), layout.hazard_ids.size())
	):
		if _commit_hazard(parent, layout, biome, region_id, index):
			count += 1
	return count

func _commit_hazard(
	parent: Node,
	layout: BiomeEnvironmentLayout,
	biome: BiomeDefinition,
	region_id: StringName,
	index: int
) -> bool:
	if hazard_system == null or parent == null or not is_instance_valid(parent):
		return false
	var hazard_id := layout.hazard_ids[index]
	if not biome.hazard_ids.has(hazard_id):
		return false
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
	var hazard_position := layout.get_hazard_position(index)
	var hazard := hazard_system.create_hazard_instance(
		hazard_id,
		size,
		rotation_radians,
		biome,
		layout,
		index,
		hazard_position
	)
	if hazard == null:
		return false
	hazard.name = "%s%d" % [
		BiomeHazardCatalog.pascal_case(String(hazard_id)),
		index + 1
	]
	parent.add_child(hazard)
	hazard.position = hazard_position
	hazard.set_meta("region_id", region_id)
	hazard_system.register_streamed_hazard(hazard, hazard_id)
	_register_region_owned_node(region_id, "owned_hazards", hazard)
	return true

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
	for index in range(
		mini(layout.crate_positions.size(), layout.crate_ids.size())
	):
		if _commit_crate(parent, layout, biome, region_id, offset, index):
			count += 1
	return count

func _commit_crate(
	parent: Node,
	layout: BiomeEnvironmentLayout,
	biome: BiomeDefinition,
	region_id: StringName,
	offset: Vector2,
	index: int
) -> bool:
	if (
		resource_crate_system == null
		or parent == null
		or not is_instance_valid(parent)
	):
		return false
	var crate_id := layout.crate_ids[index]
	if not biome.crate_ids.has(crate_id):
		return false
	var crate_key := StringName("layout_%d" % index)
	if resource_crate_system.is_layout_crate_consumed_for_region(region_id, crate_key):
		return false
	var global_position := offset + layout.crate_positions[index]
	if not resource_crate_system.is_crate_position_valid(global_position):
		return false
	var crate := resource_crate_system.create_layout_crate(crate_id, index, region_id)
	if crate == null:
		return false
	parent.add_child(crate)
	crate.position = layout.crate_positions[index]
	resource_crate_system.register_streamed_crate(crate, crate_id)
	_register_region_owned_node(region_id, "owned_crates", crate)
	return true

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
	_last_region_build_count = built
	if built > 0:
		_emit_streamed_regions_changed()

func _has_running_tile_worker() -> bool:
	for entry_value in _entries.values():
		var entry := entry_value as Dictionary
		var tile_layer := entry.get("tile_layer") as BiomeTileLayer
		if tile_layer != null and tile_layer.is_building():
			return true
	return false

func _queue_region_content(
	region_id: StringName,
	layout: BiomeEnvironmentLayout,
	biome: BiomeDefinition,
	offset: Vector2
) -> int:
	# Le fasi replicano l'ordine del percorso sincrono (ostacoli -> hazard ->
	# casse: la validita' di una cassa puo' dipendere dagli hazard gia' piazzati);
	# dentro ogni fase si parte dagli oggetti piu' vicini alla camera, cosi' i
	# collider attorno al varco appena attraversato diventano solidi per primi.
	var reference := WorldChunkVisibilityController.get_visible_world_rect(
		get_viewport()
	).get_center()
	var items: Array[Dictionary] = []
	if obstacle_system != null:
		for index in range(
			mini(layout.obstacle_positions.size(), layout.obstacle_ids.size())
		):
			if not biome.obstacle_ids.has(layout.obstacle_ids[index]):
				continue
			items.append(_content_item(
				region_id,
				&"obstacle",
				index,
				0,
				reference.distance_squared_to(offset + layout.obstacle_positions[index])
			))
	if hazard_system != null:
		for index in range(
			mini(layout.hazard_positions.size(), layout.hazard_ids.size())
		):
			if not biome.hazard_ids.has(layout.hazard_ids[index]):
				continue
			items.append(_content_item(
				region_id,
				&"hazard",
				index,
				1,
				reference.distance_squared_to(
					offset + layout.get_hazard_position(index)
				)
			))
	if resource_crate_system != null:
		for index in range(
			mini(layout.crate_positions.size(), layout.crate_ids.size())
		):
			if not biome.crate_ids.has(layout.crate_ids[index]):
				continue
			items.append(_content_item(
				region_id,
				&"crate",
				index,
				2,
				reference.distance_squared_to(offset + layout.crate_positions[index])
			))
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["phase"]) != int(b["phase"]):
			return int(a["phase"]) < int(b["phase"])
		return float(a["distance"]) < float(b["distance"])
	)
	_pending_content.append_array(items)
	return items.size()

func _content_item(
	region_id: StringName,
	kind: StringName,
	index: int,
	phase: int,
	distance: float
) -> Dictionary:
	return {
		"region_id": region_id,
		"kind": kind,
		"index": index,
		"phase": phase,
		"distance": distance
	}

func _process_pending_content() -> void:
	if _pending_content.is_empty():
		return
	var started_usec := Time.get_ticks_usec()
	var committed := 0
	var drained_region_ids: Array[StringName] = []
	while not _pending_content.is_empty():
		if (
			committed > 0
			and (
				committed >= max_content_commits_per_frame
				or float(Time.get_ticks_usec() - started_usec) / 1000.0
				>= content_commit_budget_msec
			)
		):
			break
		var item := _pending_content.pop_front() as Dictionary
		var region_id := StringName(item.get("region_id", &""))
		var entry := _entries.get(String(region_id), {}) as Dictionary
		if entry.is_empty():
			continue
		committed += 1
		entry["content_remaining"] = maxi(
			int(entry.get("content_remaining", 0)) - 1,
			0
		)
		var region := graph.get_region(region_id) if graph != null else null
		var layout: BiomeEnvironmentLayout = null
		var biome: BiomeDefinition = null
		if region != null and biome_manager != null:
			layout = _layout_for_region(region)
			biome = biome_manager.get_biome_definition(region.biome_id) as BiomeDefinition
		if layout != null and biome != null:
			var index := int(item.get("index", -1))
			match StringName(item.get("kind", &"")):
				&"obstacle":
					if _commit_obstacle(
						entry.get("env_root") as Node,
						layout,
						biome,
						region_id,
						index
					):
						entry["obstacles"] = int(entry.get("obstacles", 0)) + 1
				&"hazard":
					if _commit_hazard(
						entry.get("env_root") as Node,
						layout,
						biome,
						region_id,
						index
					):
						entry["hazards"] = int(entry.get("hazards", 0)) + 1
						entry["hazards_dirty"] = true
				&"crate":
					if _commit_crate(
						entry.get("pickup_root") as Node,
						layout,
						biome,
						region_id,
						entry.get("offset", Vector2.ZERO) as Vector2,
						index
					):
						entry["crates"] = int(entry.get("crates", 0)) + 1
		if int(entry.get("content_remaining", 0)) <= 0:
			drained_region_ids.append(region_id)
	_last_content_commit_count = committed
	_last_content_commit_msec = (
		float(Time.get_ticks_usec() - started_usec) / 1000.0
	)
	_max_content_commit_msec = maxf(
		_max_content_commit_msec,
		_last_content_commit_msec
	)
	if drained_region_ids.is_empty():
		return
	var hazards_dirty := false
	for region_id in drained_region_ids:
		var drained_entry := _entries.get(String(region_id), {}) as Dictionary
		if bool(drained_entry.get("hazards_dirty", false)):
			hazards_dirty = true
			drained_entry["hazards_dirty"] = false
	if hazards_dirty:
		_finalize_hazards()
	for region_id in drained_region_ids:
		if _try_promote_region_full(region_id):
			_emit_streamed_regions_changed()

# FULL richiede sia il tile layer costruito sia la coda contenuti drenata: i
# consumer (spawner, test) leggono FULL come "gameplay completo nella regione".
func _try_promote_region_full(region_id: StringName) -> bool:
	var entry := _entries.get(String(region_id), {}) as Dictionary
	if entry.is_empty():
		return false
	if not bool(entry.get("tiles_built", false)):
		return false
	if int(entry.get("content_remaining", 0)) > 0:
		return false
	if int(entry.get("level", ContentLevel.NONE)) == ContentLevel.FULL:
		return false
	entry["level"] = ContentLevel.FULL
	return true

func _on_region_tile_build_completed(region_id: StringName) -> void:
	var entry := _entries.get(String(region_id), {}) as Dictionary
	if entry.is_empty():
		return
	entry["tiles_built"] = true
	_try_promote_region_full(region_id)
	if region_id == current_region_id:
		_mark_current_tile_layer(region_id)
	_configure_chunk_visibility()
	_chunk_visibility.refresh(_entries, get_viewport(), true)
	_emit_streamed_regions_changed()

func _process_scheduled_unloads() -> void:
	if _unload_deadlines.is_empty():
		return
	var now := Time.get_ticks_msec()
	var matured_keys: Array = []
	for key in _unload_deadlines.keys():
		if now >= int(_unload_deadlines[key]):
			matured_keys.append(key)
	if matured_keys.is_empty():
		return
	# Una sola passata sui nodi che pinnano invece di una per deadline: con il
	# chase persistente il costo era O(deadline x nemici). La passata parte solo
	# quando almeno una deadline e' matura, non per ogni frame del grace period.
	var pinned_region_ids := _collect_pinned_region_ids()
	for key in matured_keys:
		var region_id := StringName(key)
		if pinned_region_ids.has(region_id):
			_unload_deadlines[key] = (
				now + int(unload_grace_seconds * 1000.0)
			)
			continue
		if _is_region_tile_building(region_id):
			_unload_deadlines[key] = (
				now + int(unload_grace_seconds * 1000.0)
			)
			continue
		_unload_deadlines.erase(key)
		_unstream_region(region_id)
		_emit_streamed_regions_changed()
		break

func _is_region_tile_building(region_id: StringName) -> bool:
	var entry := _entries.get(String(region_id), {}) as Dictionary
	var tile_layer := entry.get("tile_layer") as BiomeTileLayer
	return tile_layer != null and tile_layer.is_building()

# region_id -> true per ogni regione occupata da un nodo che blocca l'unload.
func _collect_pinned_region_ids() -> Dictionary:
	_pin_collection_count += 1
	var pinned := {}
	var seam_system := _resolve_seam_system()
	if seam_system == null or not seam_system.has_method("get_region_id_for_world_position"):
		return pinned
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
			if not node_region_id.is_empty():
				pinned[node_region_id] = true
	return pinned

func _resolve_seam_system() -> Node:
	if _seam_system == null or not is_instance_valid(_seam_system):
		_seam_system = get_tree().get_first_node_in_group("region_seam_system")
	return _seam_system

func _unstream_region(region_id: StringName) -> void:
	var key := String(region_id)
	if not _entries.has(key):
		return
	var entry := _entries[key] as Dictionary
	if int(entry.get("state", RegionState.ACTIVE)) == RegionState.UNLOADING:
		return
	entry["state"] = RegionState.UNLOADING
	var started_usec := Time.get_ticks_usec()
	var env_root := entry.get("env_root") as Node
	var pickup_root := entry.get("pickup_root") as Node
	var tile_layer := entry.get("tile_layer") as BiomeTileLayer
	if (
		terrain_generator != null
		and tile_layer != null
		and terrain_generator.has_method("unregister_streamed_tile_layer")
	):
		terrain_generator.unregister_streamed_tile_layer(tile_layer)
	# Ownership esplicita: nessuna scansione globale e nessuna chiamata nativa
	# is_ancestor_of su nodi che possono essere entrati in queue_free nello stesso
	# frame. Questo e' anche il fix del crash signal 11 osservato nell'unload.
	_unregister_region_owned_nodes(entry)
	_ensure_retirement_queue()
	_retirement_queue.enqueue(env_root)
	_retirement_queue.enqueue(pickup_root)
	_entries.erase(key)
	_pending_region_ids.erase(region_id)
	if not _pending_content.is_empty():
		var retained_items: Array[Dictionary] = []
		for item in _pending_content:
			if StringName(item.get("region_id", &"")) != region_id:
				retained_items.append(item)
		_pending_content = retained_items
	# Il controller di visibilita' salta i refresh quando la firma camera/chunk
	# non cambia: una regione rimossa deve forzarne uno al prossimo process.
	if _chunk_visibility != null:
		_chunk_visibility.mark_dirty()
	_last_unload_msec = float(Time.get_ticks_usec() - started_usec) / 1000.0
	_max_unload_msec = maxf(_max_unload_msec, _last_unload_msec)


func _ensure_retirement_queue() -> void:
	if _retirement_queue == null:
		_retirement_queue = (
			WORLD_REGION_RETIREMENT_QUEUE_SCRIPT.new()
			as WorldRegionRetirementQueue
		)

func _register_region_owned_node(
	region_id: StringName,
	ownership_key: String,
	node: Node
) -> void:
	if node == null:
		return
	var entry := _entries.get(String(region_id), {}) as Dictionary
	if entry.is_empty() or int(entry.get("state", -1)) != RegionState.ACTIVE:
		return
	var owned_nodes := entry.get(ownership_key, []) as Array
	owned_nodes.append(node.get_instance_id())

func _unregister_region_owned_nodes(entry: Dictionary) -> void:
	var region_id := StringName(entry.get("region_id", &""))
	if obstacle_system != null:
		obstacle_system.unregister_streamed_obstacles_by_instance_ids(
			entry.get("owned_obstacles", []) as Array,
			region_id
		)
	if hazard_system != null:
		hazard_system.unregister_streamed_hazards_by_instance_ids(
			entry.get("owned_hazards", []) as Array,
			region_id
		)
	if resource_crate_system != null:
		resource_crate_system.unregister_streamed_crates_by_instance_ids(
			entry.get("owned_crates", []) as Array,
			region_id
		)
	entry["owned_obstacles"] = []
	entry["owned_hazards"] = []
	entry["owned_crates"] = []

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
		max_chunk_commits_per_frame,
		chunk_eviction_budget_msec,
		max_chunk_evictions_per_frame
	)

func _on_visual_chunks_changed(
	loaded_count: int,
	pending_count: int
) -> void:
	visual_chunks_changed.emit(loaded_count, pending_count)

func _layout_for_region(region: WorldRegion) -> BiomeEnvironmentLayout:
	return biome_manager.get_layout_for_region(region)

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
