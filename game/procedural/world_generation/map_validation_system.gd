extends RefCounted
class_name MapValidationSystem

const WorldGridConfig = preload("res://game/core/world_grid_config.gd")

const SIDES: Array[StringName] = [&"north", &"south", &"east", &"west"]

func validate_layout(
	cell: BiomeCell,
	layout: BiomeEnvironmentLayout
) -> Dictionary:
	if cell == null or layout == null:
		return {"is_valid": false, "reason": "missing input"}

	var zone_size := layout.zone_size
	var blocked := _build_blocked_lookup(zone_size, layout)
	var spawn := _clamp_cell(layout.player_spawn_cell, zone_size)
	var visited := _flood_fill(spawn, zone_size, blocked)
	var passage_failures := _find_unreachable_passages(
		cell,
		layout,
		visited
	)
	var obstructed_passages := _find_obstructed_passages(cell, layout)
	var crate_failures := _find_unreachable_crates(layout, visited)
	var placement_failures := _find_invalid_placements(cell, layout)
	var fall_failures := _find_invalid_fall_boundaries(cell, layout)
	var main_road_report := _validate_main_roads(cell, layout)
	var water_crossing_failures := _find_unbridged_water_crossings(layout)
	var route_obstacle_failures := _find_route_obstacle_overlaps(layout)
	var rotation_failures := _find_non_cardinal_environment_rotations(layout)
	var classification_report := layout.get_classification_report()
	var is_valid := (
		not visited.is_empty()
		and passage_failures.is_empty()
		and obstructed_passages.is_empty()
		and crate_failures.is_empty()
		and placement_failures.is_empty()
		and fall_failures.is_empty()
		and bool(main_road_report.get("is_valid", false))
		and water_crossing_failures.is_empty()
		and route_obstacle_failures.is_empty()
		and rotation_failures.is_empty()
		and bool(classification_report.get("is_complete", false))
	)
	return {
		"is_valid": is_valid,
		"reachable_cells": visited.size(),
		"unreachable_passages": passage_failures,
		"obstructed_passages": obstructed_passages,
		"unreachable_crates": crate_failures,
		"placement_errors": placement_failures,
		"fall_boundary_errors": fall_failures,
		"main_road_report": main_road_report,
		"water_crossing_errors": water_crossing_failures,
		"route_obstacle_errors": route_obstacle_failures,
		"environment_rotation_errors": rotation_failures,
		"terrain_classification": classification_report
	}

func _find_non_cardinal_environment_rotations(
	layout: BiomeEnvironmentLayout
) -> PackedStringArray:
	var failures := PackedStringArray()
	for index in range(layout.obstacle_rotations.size()):
		if not is_zero_approx(layout.obstacle_rotations[index]):
			failures.append("obstacle_rotation:%d" % index)
	for index in range(layout.hazard_rotations.size()):
		if not is_zero_approx(layout.hazard_rotations[index]):
			failures.append("hazard_rotation:%d" % index)
	return failures

func validate_world_graph(graph: WorldGraph) -> Dictionary:
	if graph == null:
		return {"is_valid": false, "reason": "missing graph"}
	var passage_report := graph.validate_physical_passages()
	var is_valid := (
		graph.is_graph_connected()
		and bool(passage_report.get("is_valid", false))
	)
	return {
		"is_valid": is_valid,
		"is_connected": graph.is_graph_connected(),
		"unreachable_regions": graph.get_unreachable_region_ids(),
		"passages": passage_report
	}

func _build_blocked_lookup(
	zone_size: Vector2i,
	layout: BiomeEnvironmentLayout
) -> Dictionary:
	var blocked := {}
	for y in range(zone_size.y):
		for x in range(zone_size.x):
			var cell := Vector2i(x, y)
			var terrain_class := layout.get_terrain_class_at_cell(cell)
			if (
				terrain_class == BiomeEnvironmentLayout.TERRAIN_VOID
				or terrain_class == BiomeEnvironmentLayout.TERRAIN_FALL_ZONE
				or terrain_class == BiomeEnvironmentLayout.TERRAIN_OBSTACLE
				or (
					_cell_inside_blocking_water(cell, layout)
					and not layout.is_bridge_cell(cell)
				)
			):
				blocked[cell] = true
	return blocked

func _mark_rect(blocked: Dictionary, rect: Rect2i) -> void:
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			blocked[Vector2i(x, y)] = true

func _flood_fill(
	spawn: Vector2i,
	zone_size: Vector2i,
	blocked: Dictionary
) -> Dictionary:
	var visited := {}
	if blocked.has(spawn):
		return visited
	var queue: Array[Vector2i] = [spawn]
	visited[spawn] = true
	var directions: Array[Vector2i] = [
		Vector2i.RIGHT,
		Vector2i.LEFT,
		Vector2i.DOWN,
		Vector2i.UP
	]
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		for direction in directions:
			var next: Vector2i = current + direction
			if (
				next.x < 0
				or next.y < 0
				or next.x >= zone_size.x
				or next.y >= zone_size.y
				or visited.has(next)
				or blocked.has(next)
			):
				continue
			visited[next] = true
			queue.append(next)
	return visited

func _find_unreachable_passages(
	cell: BiomeCell,
	layout: BiomeEnvironmentLayout,
	visited: Dictionary
) -> Array[StringName]:
	var failures: Array[StringName] = []
	for passage in cell.passages:
		var target := passage.edge_anchor_cell(layout.zone_size)
		if not visited.has(target):
			failures.append(passage.side)
	return failures

func _find_unreachable_crates(
	layout: BiomeEnvironmentLayout,
	visited: Dictionary
) -> Array[Vector2i]:
	var failures: Array[Vector2i] = []
	for crate_cell in layout.crate_cells:
		if not visited.has(_clamp_cell(crate_cell, layout.zone_size)):
			failures.append(crate_cell)
	return failures

func _find_obstructed_passages(
	cell: BiomeCell,
	layout: BiomeEnvironmentLayout
) -> Array[StringName]:
	var failures: Array[StringName] = []
	for passage in cell.passages:
		var passage_rect := passage.get_local_rect(layout.zone_size)
		if (
			GeometryUtils.intersects_any(passage_rect, layout.obstacle_rects)
			or GeometryUtils.intersects_any(passage_rect, layout.fall_zone_rects)
			or _rect_intersects_blocking_hazard(passage_rect, layout)
		):
			failures.append(passage.side)
	return failures

func _find_invalid_placements(
	cell: BiomeCell,
	layout: BiomeEnvironmentLayout
) -> PackedStringArray:
	var failures := PackedStringArray()
	var zone_rect := Rect2i(Vector2i.ZERO, layout.zone_size)
	var spawn := _clamp_cell(layout.player_spawn_cell, layout.zone_size)
	if layout.get_terrain_class_at_cell(spawn, cell) != BiomeEnvironmentLayout.TERRAIN_WALKABLE:
		failures.append("player_spawn_not_walkable")
	if _cell_inside_any_rect(spawn, layout.obstacle_rects):
		failures.append("player_spawn_inside_obstacle")
	if _cell_inside_any_rect(spawn, layout.fall_zone_rects):
		failures.append("player_spawn_inside_fall_zone")
	if _cell_inside_non_bridge_hazard(spawn, layout):
		failures.append("player_spawn_inside_hazard")
	for crate_cell in layout.crate_cells:
		var clamped_crate := _clamp_cell(crate_cell, layout.zone_size)
		if (
			layout.get_terrain_class_at_cell(clamped_crate, cell)
			!= BiomeEnvironmentLayout.TERRAIN_WALKABLE
		):
			failures.append("crate_not_walkable:%s" % str(crate_cell))
		if _cell_inside_any_rect(clamped_crate, layout.obstacle_rects):
			failures.append("crate_inside_obstacle:%s" % str(crate_cell))
		if _cell_inside_any_rect(clamped_crate, layout.fall_zone_rects):
			failures.append("crate_inside_fall_zone:%s" % str(crate_cell))
		if _cell_inside_non_bridge_hazard(clamped_crate, layout):
			failures.append("crate_inside_hazard:%s" % str(crate_cell))
	for obstacle_index in range(layout.obstacle_rects.size()):
		var obstacle_rect := layout.obstacle_rects[obstacle_index]
		var obstacle_id := (
			layout.obstacle_ids[obstacle_index]
			if obstacle_index < layout.obstacle_ids.size()
			else &"unknown"
		)
		var obstacle_label := "%s:%d" % [
			String(obstacle_id),
			obstacle_index
		]
		if not zone_rect.encloses(obstacle_rect):
			failures.append(
				"obstacle_outside_zone:%s" % obstacle_label
			)
		if GeometryUtils.intersects_any(obstacle_rect, layout.fall_zone_rects):
			failures.append(
				"obstacle_inside_fall_zone:%s" % obstacle_label
			)
	return failures

func _find_invalid_fall_boundaries(
	cell: BiomeCell,
	layout: BiomeEnvironmentLayout
) -> Array[StringName]:
	var failures: Array[StringName] = []
	for side in SIDES:
		var has_fall_rect := false
		for rect in layout.fall_zone_rects:
			if _rect_touches_side(rect, side, layout.zone_size):
				has_fall_rect = true
				break
		if cell.get_border(side) == BiomeCell.BorderType.FALL and not has_fall_rect:
			failures.append(side)
		if cell.get_border(side) == BiomeCell.BorderType.CONNECTED and has_fall_rect:
			failures.append(side)
	return failures

func _validate_main_roads(cell: BiomeCell, layout: BiomeEnvironmentLayout) -> Dictionary:
	var has_horizontal := false
	var has_vertical := false
	var passes_center := false
	var edge_to_edge_count := 0
	var center := layout.zone_size / 2
	for index in range(layout.road_rects.size()):
		if index >= layout.road_rect_tags.size() or layout.road_rect_tags[index] != &"main_road":
			continue
		var rect := layout.road_rects[index]
		if rect.has_point(center):
			passes_center = true
		if (
			rect.position.x <= 0
			and rect.end.x >= layout.zone_size.x
			and rect.size.y >= ObstacleLayoutGenerator.ROAD_WIDTH
		):
			has_horizontal = true
			edge_to_edge_count += 1
		if (
			rect.position.y <= 0
			and rect.end.y >= layout.zone_size.y
			and rect.size.x >= ObstacleLayoutGenerator.ROAD_WIDTH
		):
			has_vertical = true
			edge_to_edge_count += 1
	# Void-first roads are carved as road cells (A* around rocks), not full-width
	# rects. Fall back to a cell-based edge-to-edge check when no rect qualifies.
	if not (has_horizontal and has_vertical and passes_center):
		var cell_report := _validate_main_road_cells(layout)
		has_horizontal = has_horizontal or bool(cell_report.get("horizontal", false))
		has_vertical = has_vertical or bool(cell_report.get("vertical", false))
		passes_center = passes_center or bool(cell_report.get("center", false))
	# Regions that connect to neighbours carry their roads as a central hub the
	# passage corridors converge on; passage reachability from spawn is validated
	# separately (_find_unreachable_passages), so they only need a road hub at the
	# centre, not an edge-to-edge cross. Regions without passages (e.g. the walled
	# arena) keep the edge-to-edge cross for interior structure.
	var requires_edge_to_edge := cell == null or cell.passages.is_empty()
	var failures := PackedStringArray()
	if requires_edge_to_edge:
		if not has_horizontal:
			failures.append("missing_edge_to_edge_horizontal_main_road")
		if not has_vertical:
			failures.append("missing_edge_to_edge_vertical_main_road")
	if not passes_center:
		failures.append("main_road_does_not_pass_center")
	var is_valid := passes_center and (
		not requires_edge_to_edge or (has_horizontal and has_vertical)
	)
	return {
		"is_valid": is_valid,
		"edge_to_edge_count": edge_to_edge_count,
		"has_horizontal": has_horizontal,
		"has_vertical": has_vertical,
		"passes_center": passes_center,
		"requires_edge_to_edge": requires_edge_to_edge,
		"failures": failures
	}

func _validate_main_road_cells(layout: BiomeEnvironmentLayout) -> Dictionary:
	var z := layout.zone_size
	var west := false
	var east := false
	var north := false
	var south := false
	var center_road := false
	var center := z / 2
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var probe := center + Vector2i(dx, dy)
			if layout.get_road_tags_at_cell(probe).has(&"main_road"):
				center_road = true
	for key_value in layout.road_cell_tags.keys():
		var key := int(key_value)
		var cell := Vector2i(key % z.x, int(key / z.x))
		var raw_tags: Array = layout.road_cell_tags[key] as Array
		if not (raw_tags.has(&"main_road") or raw_tags.has("main_road")):
			continue
		if cell.x <= 2:
			west = true
		if cell.x >= z.x - 3:
			east = true
		if cell.y <= 2:
			north = true
		if cell.y >= z.y - 3:
			south = true
	return {
		"horizontal": west and east,
		"vertical": north and south,
		"center": center_road
	}

func _find_unbridged_water_crossings(
	layout: BiomeEnvironmentLayout
) -> PackedStringArray:
	var failures := PackedStringArray()
	if int(layout.generation_summary.get("river_count", 0)) <= 0:
		return failures
	for water_index in range(layout.water_rects.size()):
		var water_rect := layout.water_rects[water_index]
		for road_index in range(layout.road_rects.size()):
			var road_rect := layout.road_rects[road_index]
			if not road_rect.intersects(water_rect):
				continue
			var road_tag := (
				layout.road_rect_tags[road_index]
				if road_index < layout.road_rect_tags.size()
				else &""
			)
			if road_tag == &"bridge":
				continue
			if not _water_road_intersection_has_bridge(water_rect, road_rect, layout.bridge_rects):
				failures.append(
					"water_crossing_unbridged:%d:%d" % [water_index, road_index]
				)
	return failures

func _water_road_intersection_has_bridge(
	water_rect: Rect2i,
	road_rect: Rect2i,
	bridge_rects: Array[Rect2i]
) -> bool:
	for bridge_rect in bridge_rects:
		if bridge_rect.intersects(water_rect) and bridge_rect.intersects(road_rect):
			return true
	return false

func _find_route_obstacle_overlaps(
	layout: BiomeEnvironmentLayout
) -> PackedStringArray:
	var failures := PackedStringArray()
	for obstacle_index in range(layout.obstacle_rects.size()):
		var obstacle_rect := layout.obstacle_rects[obstacle_index]
		# A walled perimeter is the endpoint of an arena road, not an obstacle
		# accidentally placed on a traversable route. Passage walls are already
		# split by the generator before validation.
		if (
			layout.uses_raised_perimeter_cliffs()
			and not layout.get_wall_segment_side(obstacle_rect).is_empty()
		):
			continue
		if GeometryUtils.intersects_any(obstacle_rect, layout.road_rects):
			failures.append("obstacle_on_route:%d" % obstacle_index)
			continue
		if layout.rect_overlaps_road_cells(obstacle_rect):
			failures.append("obstacle_on_route_cell:%d" % obstacle_index)
	return failures

func _rect_touches_side(
	rect: Rect2i,
	side: StringName,
	zone_size: Vector2i
) -> bool:
	match side:
		&"north":
			return (
				rect.position.y <= 0
				and rect.size.y <= WorldGridConfig.SIDE_EDGE_MAX_THICKNESS_TILES
			)
		&"south":
			return (
				rect.position.y + rect.size.y >= zone_size.y
				and rect.size.y <= WorldGridConfig.SIDE_EDGE_MAX_THICKNESS_TILES
			)
		&"west":
			return (
				rect.position.x <= 0
				and rect.size.x <= WorldGridConfig.SIDE_EDGE_MAX_THICKNESS_TILES
			)
		_:
			return (
				rect.position.x + rect.size.x >= zone_size.x
				and rect.size.x <= WorldGridConfig.SIDE_EDGE_MAX_THICKNESS_TILES
			)

func _cell_inside_any_rect(cell: Vector2i, rects: Array[Rect2i]) -> bool:
	for rect in rects:
		if rect.has_point(cell):
			return true
	return false

func _cell_inside_blocking_water(
	cell: Vector2i,
	layout: BiomeEnvironmentLayout
) -> bool:
	for index in range(layout.hazard_rects.size()):
		if not layout.hazard_rects[index].has_point(cell):
			continue
		var hazard_id := (
			layout.hazard_ids[index]
			if index < layout.hazard_ids.size()
			else &""
		)
		if hazard_id == &"deep_water":
			return true
	return false

func _cell_inside_non_bridge_hazard(
	cell: Vector2i,
	layout: BiomeEnvironmentLayout
) -> bool:
	for index in range(layout.hazard_rects.size()):
		if not layout.hazard_rects[index].has_point(cell):
			continue
		var hazard_id := (
			layout.hazard_ids[index]
			if index < layout.hazard_ids.size()
			else &""
		)
		if hazard_id == &"deep_water" and layout.is_bridge_cell(cell):
			continue
		return true
	return false

func _rect_intersects_blocking_hazard(
	rect: Rect2i,
	layout: BiomeEnvironmentLayout
) -> bool:
	for index in range(layout.hazard_rects.size()):
		if not rect.intersects(layout.hazard_rects[index]):
			continue
		var hazard_id := (
			layout.hazard_ids[index]
			if index < layout.hazard_ids.size()
			else &""
		)
		if hazard_id == &"fall_zone" or hazard_id == &"deep_water":
			return true
	return false

func _clamp_cell(cell: Vector2i, zone_size: Vector2i) -> Vector2i:
	return Vector2i(
		clampi(cell.x, 0, zone_size.x - 1),
		clampi(cell.y, 0, zone_size.y - 1)
	)
