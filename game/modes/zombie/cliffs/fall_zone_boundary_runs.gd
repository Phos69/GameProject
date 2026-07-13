extends RefCounted
class_name FallZoneBoundaryRuns

## Extracts the exposed outline of the union of all fall-zone rectangles.
## Boundaries between touching or overlapping rectangles are deliberately absent,
## so renderers cannot draw a cliff lip or face through one continuous void.

const TOP := &"top"
const BOTTOM := &"bottom"
const LEFT := &"left"
const RIGHT := &"right"
const INTERNAL := &"internal"

static func build(
	fall_zone_rects: Array[Rect2i],
	fall_zone_sides: Array[StringName],
	zone_size: Vector2i
) -> Array[Dictionary]:
	var runs: Array[Dictionary] = []
	if fall_zone_rects.is_empty() or zone_size.x <= 0 or zone_size.y <= 0:
		return runs
	var occupied := _build_occupancy(fall_zone_rects, zone_size)
	for boundary_y in range(1, zone_size.y):
		_append_horizontal_runs(
			runs,
			occupied,
			zone_size,
			boundary_y,
			TOP,
			fall_zone_rects,
			fall_zone_sides
		)
		_append_horizontal_runs(
			runs,
			occupied,
			zone_size,
			boundary_y,
			BOTTOM,
			fall_zone_rects,
			fall_zone_sides
		)
	for boundary_x in range(1, zone_size.x):
		_append_vertical_runs(
			runs,
			occupied,
			zone_size,
			boundary_x,
			LEFT,
			fall_zone_rects,
			fall_zone_sides
		)
		_append_vertical_runs(
			runs,
			occupied,
			zone_size,
			boundary_x,
			RIGHT,
			fall_zone_rects,
			fall_zone_sides
		)
	return runs

static func _build_occupancy(
	fall_zone_rects: Array[Rect2i],
	zone_size: Vector2i
) -> PackedByteArray:
	var occupied := PackedByteArray()
	occupied.resize(zone_size.x * zone_size.y)
	var zone_bounds := Rect2i(Vector2i.ZERO, zone_size)
	for source_rect in fall_zone_rects:
		var rect := source_rect.intersection(zone_bounds)
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				occupied[y * zone_size.x + x] = 1
	return occupied

static func _append_horizontal_runs(
	runs: Array[Dictionary],
	occupied: PackedByteArray,
	zone_size: Vector2i,
	boundary_y: int,
	orientation: StringName,
	fall_zone_rects: Array[Rect2i],
	fall_zone_sides: Array[StringName]
) -> void:
	var run_start := -1
	for x in range(zone_size.x + 1):
		var exposed := false
		if x < zone_size.x:
			var above := _is_occupied(occupied, zone_size, x, boundary_y - 1)
			var below := _is_occupied(occupied, zone_size, x, boundary_y)
			exposed = below and not above if orientation == TOP else above and not below
		if exposed and run_start < 0:
			run_start = x
		elif not exposed and run_start >= 0:
			var run_end := x
			runs.append({
				"orientation": orientation,
				"boundary": boundary_y,
				"start": run_start,
				"end": run_end,
				"depth_cells": _horizontal_depth(
					occupied,
					zone_size,
					run_start,
					run_end,
					boundary_y,
					orientation
				),
				"perimeter_side": _perimeter_side_for_run(
					orientation,
					boundary_y,
					run_start,
					run_end,
					fall_zone_rects,
					fall_zone_sides
				)
			})
			run_start = -1

static func _append_vertical_runs(
	runs: Array[Dictionary],
	occupied: PackedByteArray,
	zone_size: Vector2i,
	boundary_x: int,
	orientation: StringName,
	fall_zone_rects: Array[Rect2i],
	fall_zone_sides: Array[StringName]
) -> void:
	var run_start := -1
	for y in range(zone_size.y + 1):
		var exposed := false
		if y < zone_size.y:
			var left := _is_occupied(occupied, zone_size, boundary_x - 1, y)
			var right := _is_occupied(occupied, zone_size, boundary_x, y)
			exposed = right and not left if orientation == LEFT else left and not right
		if exposed and run_start < 0:
			run_start = y
		elif not exposed and run_start >= 0:
			var run_end := y
			runs.append({
				"orientation": orientation,
				"boundary": boundary_x,
				"start": run_start,
				"end": run_end,
				"depth_cells": _vertical_depth(
					occupied,
					zone_size,
					run_start,
					run_end,
					boundary_x,
					orientation
				),
				"perimeter_side": _perimeter_side_for_run(
					orientation,
					boundary_x,
					run_start,
					run_end,
					fall_zone_rects,
					fall_zone_sides
				)
			})
			run_start = -1

static func _horizontal_depth(
	occupied: PackedByteArray,
	zone_size: Vector2i,
	start_x: int,
	end_x: int,
	boundary_y: int,
	orientation: StringName
) -> int:
	var minimum_depth := zone_size.y
	var direction := 1 if orientation == TOP else -1
	var first_y := boundary_y if orientation == TOP else boundary_y - 1
	for x in range(start_x, end_x):
		var depth := 0
		var y := first_y
		while _is_occupied(occupied, zone_size, x, y):
			depth += 1
			y += direction
		minimum_depth = mini(minimum_depth, depth)
	return maxi(minimum_depth, 1)

static func _vertical_depth(
	occupied: PackedByteArray,
	zone_size: Vector2i,
	start_y: int,
	end_y: int,
	boundary_x: int,
	orientation: StringName
) -> int:
	var minimum_depth := zone_size.x
	var direction := 1 if orientation == LEFT else -1
	var first_x := boundary_x if orientation == LEFT else boundary_x - 1
	for y in range(start_y, end_y):
		var depth := 0
		var x := first_x
		while _is_occupied(occupied, zone_size, x, y):
			depth += 1
			x += direction
		minimum_depth = mini(minimum_depth, depth)
	return maxi(minimum_depth, 1)

static func _perimeter_side_for_run(
	orientation: StringName,
	boundary: int,
	start: int,
	end: int,
	fall_zone_rects: Array[Rect2i],
	fall_zone_sides: Array[StringName]
) -> StringName:
	var expected_side := INTERNAL
	match orientation:
		TOP:
			expected_side = &"south"
		BOTTOM:
			expected_side = &"north"
		LEFT:
			expected_side = &"east"
		RIGHT:
			expected_side = &"west"
	for index in range(fall_zone_rects.size()):
		if index >= fall_zone_sides.size() or fall_zone_sides[index] != expected_side:
			continue
		var rect := fall_zone_rects[index]
		var matches_boundary := (
			boundary == rect.position.y
			if orientation == TOP
			else boundary == rect.end.y
			if orientation == BOTTOM
			else boundary == rect.position.x
			if orientation == LEFT
			else boundary == rect.end.x
		)
		var matches_span := (
			start >= rect.position.x and end <= rect.end.x
			if orientation == TOP or orientation == BOTTOM
			else start >= rect.position.y and end <= rect.end.y
		)
		if matches_boundary and matches_span:
			return expected_side
	return INTERNAL

static func _is_occupied(
	occupied: PackedByteArray,
	zone_size: Vector2i,
	x: int,
	y: int
) -> bool:
	if x < 0 or y < 0 or x >= zone_size.x or y >= zone_size.y:
		return false
	return occupied[y * zone_size.x + x] != 0
