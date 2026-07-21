extends RefCounted
class_name BiomeBoundaryWallSystem

const BIOME_BOUNDARY_WALL_VISUAL_SCRIPT = preload(
	"res://game/modes/zombie/cliffs/biome_boundary_wall_visual.gd"
)
const BORDER_GENERATOR = preload(
	"res://game/procedural/world_generation/border_generator.gd"
)

var graph: WorldGraph
var biome_manager: BiomeManager
var environment_container: Node
var anchor_region_id: StringName = &""
var roots: Dictionary = {}

func configure(
	next_graph: WorldGraph,
	next_biome_manager: BiomeManager,
	next_environment_container: Node,
	next_anchor_region_id: StringName
) -> void:
	graph = next_graph
	biome_manager = next_biome_manager
	environment_container = next_environment_container
	anchor_region_id = next_anchor_region_id

func clear() -> void:
	for root_value in roots.values():
		var root := root_value as Node
		if root != null and is_instance_valid(root):
			root.queue_free()
	roots.clear()
	graph = null
	biome_manager = null
	environment_container = null
	anchor_region_id = &""

func get_roots() -> Dictionary:
	return roots.duplicate()

func region_has_neighbor_on_side(
	region_id: StringName,
	side: StringName
) -> bool:
	if graph == null or side.is_empty():
		return false
	var region := graph.get_region(region_id)
	return region != null and not region.get_neighbor_region_id(side).is_empty()

func refresh_for_region(
	region_id: StringName,
	resident_regions: Dictionary
) -> void:
	if graph == null:
		return
	var region := graph.get_region(region_id)
	if region == null:
		return
	for side in BiomeCell.SIDES:
		var descriptor := _wall_descriptor(region, side)
		if descriptor.is_empty():
			continue
		_refresh_wall(descriptor, resident_regions)

func _wall_descriptor(region: WorldRegion, side: StringName) -> Dictionary:
	if region == null or graph == null:
		return {}
	var neighbor_id := region.get_neighbor_region_id(side)
	if neighbor_id.is_empty():
		return {}
	var neighbor := graph.get_region(neighbor_id)
	if neighbor == null:
		return {}
	var source := region
	var target := neighbor
	var source_side := side
	if (
		neighbor.grid_position.x < region.grid_position.x
		or neighbor.grid_position.y < region.grid_position.y
	):
		source = neighbor
		target = region
		source_side = BORDER_GENERATOR.get_opposite_side(side)
	if source_side != &"east" and source_side != &"south":
		return {}
	return {
		"key": "%s|%s|%s" % [
			String(source.region_id),
			String(source_side),
			String(target.region_id),
		],
		"source": source,
		"target": target,
		"side": source_side,
	}

func _refresh_wall(
	descriptor: Dictionary,
	resident_regions: Dictionary
) -> void:
	var key := String(descriptor.get("key", ""))
	var source := descriptor.get("source") as WorldRegion
	var target := descriptor.get("target") as WorldRegion
	if key.is_empty() or source == null or target == null:
		return
	var should_exist := (
		resident_regions.has(String(source.region_id))
		or resident_regions.has(String(target.region_id))
	)
	var existing := roots.get(key) as Node
	if not should_exist:
		if existing != null and is_instance_valid(existing):
			existing.queue_free()
		roots.erase(key)
		return
	if existing != null and is_instance_valid(existing):
		return
	var root := _build_wall_root(
		source,
		target,
		StringName(descriptor.get("side", &""))
	)
	if root != null:
		roots[key] = root

func _build_wall_root(
	source: WorldRegion,
	target: WorldRegion,
	side: StringName
) -> Node2D:
	if environment_container == null or biome_manager == null:
		return null
	var layout := biome_manager.get_layout_for_region(source)
	var target_layout := biome_manager.get_layout_for_region(target)
	var primary_biome := (
		biome_manager.get_biome_definition(source.biome_id) as BiomeDefinition
	)
	var secondary_biome := (
		biome_manager.get_biome_definition(target.biome_id) as BiomeDefinition
	)
	if (
		layout == null
		or target_layout == null
		or primary_biome == null
		or secondary_biome == null
		or primary_biome.palette == null
		or secondary_biome.palette == null
	):
		return null
	var segments := _wall_segment_rects(layout, target_layout, side)
	if segments.is_empty():
		return null
	var root := Node2D.new()
	root.name = "UnifiedBiomeWall_%s_%s" % [String(source.region_id), String(side)]
	root.y_sort_enabled = true
	root.set_meta("unified_biome_wall_root", true)
	root.set_meta("source_region_id", source.region_id)
	root.set_meta("target_region_id", target.region_id)
	environment_container.add_child(root)
	var scale := layout.logical_tile_scale
	var region_offset := _offset_for_region(source, scale)
	for index in range(segments.size()):
		var rect: Rect2i = segments[index]
		var visual := (
			BIOME_BOUNDARY_WALL_VISUAL_SCRIPT.new() as BiomeBoundaryWallVisual
		)
		if visual == null:
			continue
		visual.name = "TransitionSegment_%d" % (index + 1)
		var visual_size := layout.rect_size_to_world(rect)
		var center_offset := Vector2.ZERO
		if side == &"east":
			visual_size.x += scale
			center_offset.x = scale * 0.5
		else:
			visual_size.y += scale
			center_offset.y = scale * 0.5
		visual.position = (
			region_offset
			+ layout.rect_center_to_world(rect)
			+ center_offset
		)
		root.add_child(visual)
		var uv_origin := Vector2(source.world_origin + rect.position) * scale
		visual.configure(
			visual_size,
			side,
			uv_origin,
			layout.wall_height_cells,
			scale,
			primary_biome.biome_id,
			primary_biome.palette,
			secondary_biome.biome_id,
			secondary_biome.palette
		)
	return root

func _wall_segment_rects(
	primary_layout: BiomeEnvironmentLayout,
	secondary_layout: BiomeEnvironmentLayout,
	side: StringName
) -> Array[Rect2i]:
	var result: Array[Rect2i] = []
	if primary_layout == null or secondary_layout == null:
		return result
	var axis_limit := (
		primary_layout.zone_size.y if side == &"east" else primary_layout.zone_size.x
	)
	if axis_limit <= 0:
		return result
	var occupied := PackedByteArray()
	occupied.resize(axis_limit)
	occupied.fill(0)
	_mark_wall_axis(
		occupied,
		primary_layout.get_wall_segments_for_side(side),
		side
	)
	var opposite_side := BORDER_GENERATOR.get_opposite_side(side)
	_mark_wall_axis(
		occupied,
		secondary_layout.get_wall_segments_for_side(opposite_side),
		opposite_side
	)
	var cursor := 0
	while cursor < axis_limit:
		if occupied[cursor] == 0:
			cursor += 1
			continue
		var run_end := cursor + 1
		while run_end < axis_limit and occupied[run_end] != 0:
			run_end += 1
		while cursor < run_end:
			var segment_length := mini(
				WorldGridConfig.WALL_SEGMENT_LENGTH_TILES,
				run_end - cursor
			)
			result.append(
				_wall_segment_rect(primary_layout, side, cursor, segment_length)
			)
			cursor += segment_length
	return result

func _wall_segment_rect(
	layout: BiomeEnvironmentLayout,
	side: StringName,
	axis_start: int,
	axis_length: int
) -> Rect2i:
	if side == &"east":
		return Rect2i(
			Vector2i(
				layout.zone_size.x - WorldGridConfig.BORDER_THICKNESS_TILES,
				axis_start
			),
			Vector2i(WorldGridConfig.BORDER_THICKNESS_TILES, axis_length)
		)
	return Rect2i(
		Vector2i(
			axis_start,
			layout.zone_size.y - WorldGridConfig.BORDER_THICKNESS_TILES
		),
		Vector2i(axis_length, WorldGridConfig.BORDER_THICKNESS_TILES)
	)

func _mark_wall_axis(
	occupied: PackedByteArray,
	segments: Array[Rect2i],
	side: StringName
) -> void:
	var vertical := side == &"west" or side == &"east"
	for rect in segments:
		var start := rect.position.y if vertical else rect.position.x
		var finish := rect.end.y if vertical else rect.end.x
		for axis in range(
			clampi(start, 0, occupied.size()),
			clampi(finish, 0, occupied.size())
		):
			occupied[axis] = 1

func _offset_for_region(region: WorldRegion, tile_scale: float) -> Vector2:
	var anchor := graph.get_region(anchor_region_id) if graph != null else null
	if anchor == null:
		return Vector2.ZERO
	return Vector2(region.world_origin - anchor.world_origin) * tile_scale
