extends RefCounted
class_name MapValidationSystem

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
	var classification_report := layout.get_classification_report()
	var is_valid := (
		not visited.is_empty()
		and passage_failures.is_empty()
		and obstructed_passages.is_empty()
		and crate_failures.is_empty()
		and placement_failures.is_empty()
		and fall_failures.is_empty()
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
		"terrain_classification": classification_report
	}

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
		var target := _passage_probe_cell(passage, layout.zone_size)
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
			_rect_intersects_any(passage_rect, layout.obstacle_rects)
			or _rect_intersects_any(passage_rect, layout.fall_zone_rects)
			or _rect_intersects_blocking_hazard(passage_rect, layout)
		):
			failures.append(passage.side)
	return failures

func _find_invalid_placements(
	cell: BiomeCell,
	layout: BiomeEnvironmentLayout
) -> PackedStringArray:
	var failures := PackedStringArray()
	var spawn := _clamp_cell(layout.player_spawn_cell, layout.zone_size)
	if layout.get_terrain_class_at_cell(spawn, cell) != BiomeEnvironmentLayout.TERRAIN_WALKABLE:
		failures.append("player_spawn_not_walkable")
	if _cell_inside_any_rect(spawn, layout.obstacle_rects):
		failures.append("player_spawn_inside_obstacle")
	if _cell_inside_any_rect(spawn, layout.fall_zone_rects):
		failures.append("player_spawn_inside_fall_zone")
	if _cell_inside_any_rect(spawn, layout.hazard_rects):
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
		if _cell_inside_any_rect(clamped_crate, layout.hazard_rects):
			failures.append("crate_inside_hazard:%s" % str(crate_cell))
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

func _passage_probe_cell(
	passage: BiomePassage,
	zone_size: Vector2i
) -> Vector2i:
	match passage.side:
		&"north":
			return Vector2i(passage.position, 3)
		&"south":
			return Vector2i(passage.position, zone_size.y - 4)
		&"west":
			return Vector2i(3, passage.position)
		_:
			return Vector2i(zone_size.x - 4, passage.position)

func _rect_touches_side(
	rect: Rect2i,
	side: StringName,
	zone_size: Vector2i
) -> bool:
	match side:
		&"north":
			return rect.position.y <= 0 and rect.size.y <= 8
		&"south":
			return (
				rect.position.y + rect.size.y >= zone_size.y
				and rect.size.y <= 8
			)
		&"west":
			return rect.position.x <= 0 and rect.size.x <= 8
		_:
			return (
				rect.position.x + rect.size.x >= zone_size.x
				and rect.size.x <= 8
			)

func _clip_rect(rect: Rect2i, zone_size: Vector2i) -> Rect2i:
	var x := clampi(rect.position.x, 0, zone_size.x)
	var y := clampi(rect.position.y, 0, zone_size.y)
	var end_x := clampi(rect.position.x + rect.size.x, 0, zone_size.x)
	var end_y := clampi(rect.position.y + rect.size.y, 0, zone_size.y)
	return Rect2i(Vector2i(x, y), Vector2i(maxi(end_x - x, 0), maxi(end_y - y, 0)))

func _cell_inside_any_rect(cell: Vector2i, rects: Array[Rect2i]) -> bool:
	for rect in rects:
		if rect.has_point(cell):
			return true
	return false

func _rect_intersects_any(rect: Rect2i, rects: Array[Rect2i]) -> bool:
	for other in rects:
		if rect.intersects(other):
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
