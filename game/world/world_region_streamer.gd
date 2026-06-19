extends Node
class_name WorldRegionStreamer

enum ContentLevel { NONE = 0, DATA_ONLY = 1, FULL = 2 }

const BIOME_TILE_LAYER_SCRIPT = preload(
	"res://game/modes/zombie/biome_tile_layer.gd"
)

@export_range(0, 3, 1) var active_radius: int = 1
@export_enum("performance", "balanced", "quality") var quality_preset: String = "balanced"

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

# String(region_id) -> { "level": int, "offset": Vector2, "env_root": Node2D,
# "pickup_root": Node2D, "tiles": int, "obstacles": int, "hazards": int,
# "crates": int }
var _entries: Dictionary = {}

func _ready() -> void:
	add_to_group("world_region_streamer")
	manifest = IsometricEnvironmentManifest.get_shared()

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
	_prepare_systems(center.biome_id)
	for region_id in _collect_active_region_ids(center_region_id):
		var region := graph.get_region(region_id)
		if region == null:
			continue
		_stream_region(region, region_id == center_region_id)
	if hazard_system != null and hazard_system.has_method("finalize_streamed_hazards"):
		hazard_system.finalize_streamed_hazards()
	return true

func clear() -> void:
	for key in _entries.keys():
		var entry := _entries[key] as Dictionary
		var env_root := entry.get("env_root") as Node
		var pickup_root := entry.get("pickup_root") as Node
		if env_root != null and is_instance_valid(env_root):
			env_root.queue_free()
		if pickup_root != null and is_instance_valid(pickup_root):
			pickup_root.queue_free()
	_entries.clear()
	graph = null
	biome_manager = null
	world_runtime = null
	environment_container = null
	pickup_container = null
	current_region_id = &""
	anchor_region_id = &""

func get_streamed_region_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for key in _entries.keys():
		ids.append(StringName(key))
	ids.sort()
	return ids

func is_region_streamed(region_id: StringName) -> bool:
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

func _stream_region(region: WorldRegion, is_current: bool) -> void:
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
	var tile_count := _stream_tile_layer(env_root, layout, biome, is_current)
	var obstacle_count := _stream_obstacles(env_root, layout, biome, region.region_id)
	var hazard_count := _stream_hazards(env_root, layout, biome, region.region_id)
	var crate_count := _stream_crates(pickup_root, layout, biome, region.region_id, offset)
	_entries[String(region.region_id)] = {
		"level": ContentLevel.FULL,
		"offset": offset,
		"env_root": env_root,
		"pickup_root": pickup_root,
		"tiles": tile_count,
		"obstacles": obstacle_count,
		"hazards": hazard_count,
		"crates": crate_count
	}

func _stream_tile_layer(
	parent: Node,
	layout: BiomeEnvironmentLayout,
	biome: BiomeDefinition,
	is_current: bool
) -> int:
	var tile_layer := BIOME_TILE_LAYER_SCRIPT.new() as BiomeTileLayer
	if tile_layer == null:
		return 0
	tile_layer.name = "TileLayer_%s" % String(biome.biome_id)
	parent.add_child(tile_layer)
	tile_layer.configure(
		layout,
		biome.palette,
		biome.biome_id,
		StringName(quality_preset)
	)
	if terrain_generator != null and terrain_generator.has_method("register_streamed_tile_layer"):
		terrain_generator.register_streamed_tile_layer(tile_layer, is_current)
	return tile_layer.get_visual_tile_count()

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
