extends RefCounted
class_name TerrainRoutePass
## TERRAIN-PARCELS-001 route authority.
##
## Carves official passages and a seven-tile hub-and-spokes network before any
## parcel or content exists. Only official passages touch a seam.

const WorldGridConfig = preload("res://game/core/world_grid_config.gd")

const ROAD_WIDTH := WorldGridConfig.ROAD_WIDTH_TILES
const BORDER_THICKNESS := WorldGridConfig.BORDER_THICKNESS_TILES

func generate(
	layout: BiomeEnvironmentLayout,
	cell: BiomeCell,
	context: Dictionary,
	road_tag: StringName,
	spoke_tag: StringName
) -> Dictionary:
	_carve_passages(layout, cell)
	var spokes := _collect_spokes(layout, cell, context, road_tag, spoke_tag)
	var has_passage := false
	for spoke in spokes:
		if bool(spoke.get("is_passage", false)):
			has_passage = true
			break
	if has_passage:
		_carve_hub(layout, road_tag)
	var center := layout.zone_size / 2
	for spoke in spokes:
		_carve_cardinal_route(
			layout,
			spoke.get("anchor", center) as Vector2i,
			center,
			spoke.get("tag", spoke_tag) as StringName
		)
	_choose_spawn(layout)
	return {
		"spoke_count": spokes.size(),
		"official_passage_count": cell.passages.size(),
		"has_hub": has_passage,
		"road_width": ROAD_WIDTH,
	}

func _carve_passages(layout: BiomeEnvironmentLayout, cell: BiomeCell) -> void:
	for passage in cell.passages:
		var passage_rect := passage.get_local_rect(layout.zone_size)
		var connector_rect := passage.get_connector_rect(layout.zone_size)
		layout.passage_rects.append(passage_rect)
		layout.passage_connector_rects.append(connector_rect)
		_add_road_rect(layout, passage_rect, passage.passage_type)
		_add_road_rect(layout, connector_rect, passage.passage_type)

func _collect_spokes(
	layout: BiomeEnvironmentLayout,
	cell: BiomeCell,
	context: Dictionary,
	road_tag: StringName,
	spoke_tag: StringName
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var covered_sides: Dictionary = {}
	for passage in cell.passages:
		result.append({
			"anchor": passage.edge_anchor_cell(layout.zone_size),
			"tag": spoke_tag,
			"is_passage": true,
		})
		covered_sides[passage.side] = true
	var boundary_mode := String(context.get("arena_boundary_mode", ""))
	if boundary_mode == "walled" or boundary_mode == "blocked":
		result.append_array(_wall_spokes(layout, covered_sides, road_tag))
	if result.is_empty():
		result = _wall_spokes(layout, covered_sides, road_tag)
	return result

func _wall_spokes(
	layout: BiomeEnvironmentLayout,
	covered_sides: Dictionary,
	road_tag: StringName
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for side in BiomeCell.SIDES:
		if covered_sides.has(side):
			continue
		result.append({
			"anchor": _wall_anchor(layout, side),
			"tag": road_tag,
			"is_passage": false,
		})
	return result

func _wall_anchor(layout: BiomeEnvironmentLayout, side: StringName) -> Vector2i:
	var mid := layout.zone_size / 2
	match side:
		&"north":
			return Vector2i(mid.x, BORDER_THICKNESS)
		&"south":
			return Vector2i(mid.x, layout.zone_size.y - BORDER_THICKNESS - 1)
		&"west":
			return Vector2i(BORDER_THICKNESS, mid.y)
		_:
			return Vector2i(layout.zone_size.x - BORDER_THICKNESS - 1, mid.y)

func _carve_hub(layout: BiomeEnvironmentLayout, road_tag: StringName) -> void:
	var half := WorldGridConfig.CENTER_RESERVED_HALF_TILES
	var center := layout.zone_size / 2
	var hub := Rect2i(center - Vector2i(half, half), Vector2i(half * 2, half * 2))
	_add_road_rect(layout, hub, road_tag)
	for y in range(hub.position.y, hub.end.y):
		for x in range(hub.position.x, hub.end.x):
			layout.add_road_cell(Vector2i(x, y), road_tag)

func _carve_cardinal_route(
	layout: BiomeEnvironmentLayout,
	start: Vector2i,
	finish: Vector2i,
	tag: StringName
) -> void:
	var elbow := Vector2i(finish.x, start.y)
	_carve_segment(layout, start, elbow, tag)
	_carve_segment(layout, elbow, finish, tag)
	var midpoint := Vector2i(
		roundi((float(start.x) + float(finish.x)) * 0.5),
		roundi((float(start.y) + float(finish.y)) * 0.5)
	)
	_add_route_metadata(
		layout,
		layout.logical_to_world(midpoint),
		maxf(
			float(absi(finish.x - start.x) + absi(finish.y - start.y))
				* layout.logical_tile_scale * 0.10,
			34.0
		),
		tag
	)

func _carve_segment(
	layout: BiomeEnvironmentLayout,
	start: Vector2i,
	finish: Vector2i,
	tag: StringName
) -> void:
	var before := ROAD_WIDTH / 2
	var after := ROAD_WIDTH - before
	for center_y in range(mini(start.y, finish.y), maxi(start.y, finish.y) + 1):
		for center_x in range(mini(start.x, finish.x), maxi(start.x, finish.x) + 1):
			for y in range(center_y - before, center_y + after):
				for x in range(center_x - before, center_x + after):
					var route_cell := Vector2i(x, y)
					if _inside(layout, route_cell):
						layout.add_road_cell(route_cell, tag)

func _add_road_rect(
	layout: BiomeEnvironmentLayout,
	rect: Rect2i,
	tag: StringName
) -> void:
	var clipped := rect.intersection(Rect2i(Vector2i.ZERO, layout.zone_size))
	if clipped.size.x <= 0 or clipped.size.y <= 0:
		return
	layout.road_rects.append(clipped)
	layout.road_rect_tags.append(tag)
	if tag == &"bridge":
		layout.add_bridge_rect(clipped)
	_add_route_metadata(
		layout,
		layout.rect_center_to_world(clipped),
		maxf(
			float(maxi(clipped.size.x, clipped.size.y))
				* layout.logical_tile_scale * 0.18,
			28.0
		),
		tag
	)

func _add_route_metadata(
	layout: BiomeEnvironmentLayout,
	position: Vector2,
	radius: float,
	tag: StringName
) -> void:
	layout.terrain_patch_tags.append(tag)
	layout.terrain_patch_positions.append(position)
	layout.terrain_patch_radii.append(radius)

func _choose_spawn(layout: BiomeEnvironmentLayout) -> void:
	var center := layout.zone_size / 2
	if layout.has_road_cell(center):
		layout.player_spawn_cell = center
		return
	for radius in range(1, maxi(layout.zone_size.x, layout.zone_size.y)):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if absi(dx) != radius and absi(dy) != radius:
					continue
				var candidate := center + Vector2i(dx, dy)
				if _inside(layout, candidate) and layout.has_road_cell(candidate):
					layout.player_spawn_cell = candidate
					return

func _inside(layout: BiomeEnvironmentLayout, cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < layout.zone_size.x and cell.y < layout.zone_size.y
