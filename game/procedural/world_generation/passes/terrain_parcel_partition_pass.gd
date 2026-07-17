extends RefCounted
class_name TerrainParcelPartitionPass

const WorldGridConfig = preload("res://game/core/world_grid_config.gd")

const TRAIL_TAG: StringName = &"parcel_trail"
const TRAIL_WIDTH := WorldGridConfig.VOIDFIRST_PATH_WIDTH_TILES
const MIN_PARCEL_AREA := 180
const MIN_PARCEL_SPAN := 8
const TOWN_MIN_AREA := 260
const MESA_MIN_AREA := 300
const RANDOM_ATTEMPTS := 96

const DIRECTIONS: Array[Vector2i] = [
	Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP,
]


func generate(
	layout: BiomeEnvironmentLayout,
	biome: BiomeDefinition,
	rng: RandomNumberGenerator,
	trail_surface_tag: StringName
) -> Dictionary:
	var minimum := 7
	var maximum := 10
	if biome != null and biome.generation_profile != null:
		minimum = biome.generation_profile.parcel_min_count
		maximum = biome.generation_profile.parcel_max_count
	maximum = maxi(maximum, minimum)
	var target := rng.randi_range(minimum, maximum)
	var route_mask := _build_route_mask(layout)
	var components := _collect_components(layout, route_mask)
	# Passage spokes can leave tiny enclosed islands at route bends. They cannot
	# become legal parcels, so fold them into the adjacent route before splitting.
	for component in components:
		var bounds := component["bounds"] as Rect2i
		if (
			int(component["area"]) >= MIN_PARCEL_AREA
			and bounds.size.x >= MIN_PARCEL_SPAN
			and bounds.size.y >= MIN_PARCEL_SPAN
		):
			continue
		var island_cells: Array[Vector2i] = []
		island_cells.assign(component["cells"] as Array)
		_mark_cells(route_mask, layout.zone_size, island_cells)
		_register_trail(layout, island_cells, trail_surface_tag)
	components = _collect_components(layout, route_mask)
	var attempts := 0
	while components.size() < target and attempts < RANDOM_ATTEMPTS:
		attempts += 1
		var side := BiomeCell.SIDES[rng.randi_range(0, BiomeCell.SIDES.size() - 1)]
		var trail := _random_trail_candidate(layout, route_mask, side, rng)
		if trail.is_empty():
			continue
		var trial_mask := route_mask.duplicate()
		_mark_cells(trial_mask, layout.zone_size, trail)
		var trial_components := _collect_components(layout, trial_mask)
		if trial_components.size() <= components.size() or trial_components.size() > target:
			continue
		if not _components_are_usable(trial_components):
			continue
		route_mask = trial_mask
		components = trial_components
		_register_trail(layout, trail, trail_surface_tag)

	if components.size() < target:
		for side in BiomeCell.SIDES:
			if components.size() >= target:
				break
			for axis in _scan_axes(layout, side):
				var trail := _trail_candidate(layout, route_mask, side, axis)
				if trail.is_empty():
					continue
				var trial_mask := route_mask.duplicate()
				_mark_cells(trial_mask, layout.zone_size, trail)
				var trial_components := _collect_components(layout, trial_mask)
				if (
					trial_components.size() <= components.size()
					or trial_components.size() > target
					or not _components_are_usable(trial_components)
				):
					continue
				route_mask = trial_mask
				components = trial_components
				_register_trail(layout, trail, trail_surface_tag)
				if components.size() >= target:
					break

	components.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["area"]) > int(b["area"])
	)
	_assign_and_register(layout, biome, components, rng)
	var component_areas: Array[int] = []
	var component_bounds: Array[Rect2i] = []
	for component in components:
		component_areas.append(int(component["area"]))
		component_bounds.append(component["bounds"] as Rect2i)
	return {
		"target": target,
		"count": components.size(),
		"random_attempts": attempts,
		"complete": components.size() >= minimum,
		"component_areas": component_areas,
		"component_bounds": component_bounds,
	}


func _assign_and_register(
	layout: BiomeEnvironmentLayout,
	biome: BiomeDefinition,
	components: Array[Dictionary],
	rng: RandomNumberGenerator
) -> void:
	layout.initialize_parcel_map()
	if components.is_empty():
		return
	var town_index := -1
	for index in range(components.size()):
		var component := components[index]
		var bounds := component["bounds"] as Rect2i
		var component_cells: Array[Vector2i] = []
		component_cells.assign(component["cells"] as Array)
		if (
			int(component["area"]) >= TOWN_MIN_AREA
			and bounds.size.x >= MIN_PARCEL_SPAN
			and bounds.size.y >= MIN_PARCEL_SPAN
			and _component_touches_main_route(layout, component_cells)
		):
			town_index = index
			break
	if town_index < 0:
		town_index = 0

	var mesa_index := -1
	for index in range(components.size()):
		if index == town_index:
			continue
		if int(components[index]["area"]) >= MESA_MIN_AREA:
			mesa_index = index
			break
	if mesa_index < 0:
		mesa_index = 1 if components.size() > 1 else 0

	var clearing_weight := 0.45
	var forest_weight := 0.35
	if biome != null and biome.generation_profile != null:
		clearing_weight = biome.generation_profile.clearing_weight
		forest_weight = biome.generation_profile.forest_weight

	for index in range(components.size()):
		var parcel_type := BiomeEnvironmentLayout.PARCEL_CLEARING
		if index == town_index:
			parcel_type = BiomeEnvironmentLayout.PARCEL_TOWN
		elif index == mesa_index:
			parcel_type = BiomeEnvironmentLayout.PARCEL_MESA
		else:
			var roll := rng.randf()
			if roll < clearing_weight:
				parcel_type = BiomeEnvironmentLayout.PARCEL_CLEARING
			elif roll < clearing_weight + forest_weight:
				parcel_type = BiomeEnvironmentLayout.PARCEL_FOREST
			else:
				parcel_type = BiomeEnvironmentLayout.PARCEL_FALL_ZONE
		var cells: Array[Vector2i] = []
		cells.assign(components[index]["cells"] as Array)
		layout.register_parcel(parcel_type, cells, components[index]["bounds"] as Rect2i)
		_add_floor_runs(layout, cells, parcel_type)


func _add_floor_runs(
	layout: BiomeEnvironmentLayout,
	cells: Array[Vector2i],
	parcel_type: StringName
) -> void:
	var by_row: Dictionary = {}
	for cell in cells:
		if not by_row.has(cell.y):
			by_row[cell.y] = []
		(by_row[cell.y] as Array).append(cell.x)
	var floor_tag: StringName = (
		&"forest_tall_grass"
		if parcel_type == BiomeEnvironmentLayout.PARCEL_FOREST
		else &"open_block"
	)
	var rows: Array = by_row.keys()
	rows.sort()
	for row_value in rows:
		var xs: Array = by_row[row_value] as Array
		xs.sort()
		var run_start := int(xs[0])
		var previous := run_start
		for offset in range(1, xs.size() + 1):
			var at_end := offset == xs.size()
			var next_x := previous + 2 if at_end else int(xs[offset])
			if next_x != previous + 1:
				layout.add_floor_rect(
					Rect2i(run_start, int(row_value), previous - run_start + 1, 1),
					floor_tag
				)
				run_start = next_x
			previous = next_x


func _random_trail_candidate(
	layout: BiomeEnvironmentLayout,
	route_mask: PackedByteArray,
	side: StringName,
	rng: RandomNumberGenerator
) -> Array[Vector2i]:
	var lo := WorldGridConfig.BORDER_THICKNESS_TILES
	var axis_limit := layout.zone_size.x if side == &"north" or side == &"south" else layout.zone_size.y
	var axis := rng.randi_range(lo + TRAIL_WIDTH, axis_limit - lo - TRAIL_WIDTH - 1)
	return _trail_candidate(layout, route_mask, side, axis)


func _trail_candidate(
	layout: BiomeEnvironmentLayout,
	route_mask: PackedByteArray,
	side: StringName,
	axis: int
) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var lo := WorldGridConfig.BORDER_THICKNESS_TILES
	var hi_x := layout.zone_size.x - lo - 1
	var hi_y := layout.zone_size.y - lo - 1
	var anchor := Vector2i(-1, -1)
	var needs_hub_tail := false
	match side:
		&"north":
			for y in range(lo, hi_y + 1):
				if _is_main_route_cell(layout, Vector2i(axis, y)):
					anchor = Vector2i(axis, y)
					break
		&"south":
			for y in range(hi_y, lo - 1, -1):
				if _is_main_route_cell(layout, Vector2i(axis, y)):
					anchor = Vector2i(axis, y)
					break
		&"west":
			for x in range(lo, hi_x + 1):
				if _is_main_route_cell(layout, Vector2i(x, axis)):
					anchor = Vector2i(x, axis)
					break
		_:
			for x in range(hi_x, lo - 1, -1):
				if _is_main_route_cell(layout, Vector2i(x, axis)):
					anchor = Vector2i(x, axis)
					break
	if anchor.x < 0:
		# Curved passage spokes do not necessarily cross every scan axis. Complete
		# the candidate with an L-shaped tail to the central hub in that case.
		var center := layout.zone_size / 2
		anchor = (
			Vector2i(axis, center.y)
			if side == &"north" or side == &"south"
			else Vector2i(center.x, axis)
		)
		needs_hub_tail = true
	var before := TRAIL_WIDTH / 2
	match side:
		&"north", &"south":
			var start_y := lo if side == &"north" else anchor.y
			var end_y := anchor.y if side == &"north" else hi_y
			if end_y - start_y < MIN_PARCEL_SPAN:
				return result
			for y in range(start_y, end_y + 1):
				for x in range(axis - before, axis - before + TRAIL_WIDTH):
					result.append(Vector2i(x, y))
		_:
			var start_x := lo if side == &"west" else anchor.x
			var end_x := anchor.x if side == &"west" else hi_x
			if end_x - start_x < MIN_PARCEL_SPAN:
				return result
			for x in range(start_x, end_x + 1):
				for y in range(axis - before, axis - before + TRAIL_WIDTH):
					result.append(Vector2i(x, y))
	if needs_hub_tail:
		var center := layout.zone_size / 2
		if side == &"north" or side == &"south":
			for x in range(mini(axis, center.x), maxi(axis, center.x) + 1):
				for y in range(center.y - before, center.y - before + TRAIL_WIDTH):
					result.append(Vector2i(x, y))
		else:
			for y in range(mini(axis, center.y), maxi(axis, center.y) + 1):
				for x in range(center.x - before, center.x - before + TRAIL_WIDTH):
					result.append(Vector2i(x, y))
	# Reject candidates that merely repaint an existing route.
	var new_cells := 0
	for cell in result:
		if not _mask_has(route_mask, layout.zone_size, cell):
			new_cells += 1
	if new_cells < MIN_PARCEL_SPAN * TRAIL_WIDTH:
		result.clear()
	return result


func _scan_axes(layout: BiomeEnvironmentLayout, side: StringName) -> Array[int]:
	var result: Array[int] = []
	var lo := WorldGridConfig.BORDER_THICKNESS_TILES + TRAIL_WIDTH
	var limit := layout.zone_size.x if side == &"north" or side == &"south" else layout.zone_size.y
	for axis in range(lo, limit - lo, TRAIL_WIDTH + 1):
		result.append(axis)
	return result


func _register_trail(
	layout: BiomeEnvironmentLayout,
	cells: Array[Vector2i],
	surface_tag: StringName
) -> void:
	for cell in cells:
		layout.add_road_cell(cell, TRAIL_TAG)
		layout.add_road_cell(cell, surface_tag)


func _build_route_mask(layout: BiomeEnvironmentLayout) -> PackedByteArray:
	var result := PackedByteArray()
	result.resize(layout.zone_size.x * layout.zone_size.y)
	result.fill(0)
	for rect in layout.road_rects:
		_mark_rect(result, layout.zone_size, rect)
	for rect in layout.passage_rects:
		_mark_rect(result, layout.zone_size, rect)
	for rect in layout.passage_connector_rects:
		_mark_rect(result, layout.zone_size, rect)
	for cell in layout.get_road_cells():
		_set_mask(result, layout.zone_size, cell)
	return result


func _collect_components(
	layout: BiomeEnvironmentLayout,
	route_mask: PackedByteArray
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var visited := PackedByteArray()
	visited.resize(route_mask.size())
	visited.fill(0)
	var lo := WorldGridConfig.BORDER_THICKNESS_TILES
	for y in range(lo, layout.zone_size.y - lo):
		for x in range(lo, layout.zone_size.x - lo):
			var start := Vector2i(x, y)
			var key := y * layout.zone_size.x + x
			if route_mask[key] != 0 or visited[key] != 0:
				continue
			var cells: Array[Vector2i] = []
			var queue: Array[Vector2i] = [start]
			visited[key] = 1
			var min_cell: Vector2i = start
			var max_cell: Vector2i = start
			while not queue.is_empty():
				var current: Vector2i = queue.pop_back()
				cells.append(current)
				min_cell.x = mini(min_cell.x, current.x)
				min_cell.y = mini(min_cell.y, current.y)
				max_cell.x = maxi(max_cell.x, current.x)
				max_cell.y = maxi(max_cell.y, current.y)
				for direction: Vector2i in DIRECTIONS:
					var next: Vector2i = current + direction
					if (
						next.x < lo or next.y < lo
						or next.x >= layout.zone_size.x - lo
						or next.y >= layout.zone_size.y - lo
					):
						continue
					var next_key: int = next.y * layout.zone_size.x + next.x
					if route_mask[next_key] != 0 or visited[next_key] != 0:
						continue
					visited[next_key] = 1
					queue.append(next)
			result.append({
				"cells": cells,
				"area": cells.size(),
				"bounds": Rect2i(min_cell, max_cell - min_cell + Vector2i.ONE),
			})
	return result


func _components_are_usable(components: Array[Dictionary]) -> bool:
	for component in components:
		var bounds := component["bounds"] as Rect2i
		if (
			int(component["area"]) < MIN_PARCEL_AREA
			or bounds.size.x < MIN_PARCEL_SPAN
			or bounds.size.y < MIN_PARCEL_SPAN
		):
			return false
	return true


func _component_touches_main_route(
	layout: BiomeEnvironmentLayout,
	cells: Array[Vector2i]
) -> bool:
	for cell in cells:
		for direction in DIRECTIONS:
			if _is_main_route_cell(layout, cell + direction):
				return true
	return false


func _is_main_route_cell(layout: BiomeEnvironmentLayout, cell: Vector2i) -> bool:
	var tags := layout.get_road_tags_at_cell(cell)
	if tags.has(TRAIL_TAG):
		for rect in layout.road_rects:
			if rect.has_point(cell):
				return true
		return false
	for tag in tags:
		if tag != TRAIL_TAG:
			return true
	for index in range(layout.road_rects.size()):
		if layout.road_rects[index].has_point(cell):
			return true
	return false


func _mark_cells(mask: PackedByteArray, size: Vector2i, cells: Array[Vector2i]) -> void:
	for cell in cells:
		_set_mask(mask, size, cell)


func _mark_rect(mask: PackedByteArray, size: Vector2i, rect: Rect2i) -> void:
	var clipped := rect.intersection(Rect2i(Vector2i.ZERO, size))
	for y in range(clipped.position.y, clipped.end.y):
		for x in range(clipped.position.x, clipped.end.x):
			mask[y * size.x + x] = 1


func _set_mask(mask: PackedByteArray, size: Vector2i, cell: Vector2i) -> void:
	if cell.x < 0 or cell.y < 0 or cell.x >= size.x or cell.y >= size.y:
		return
	mask[cell.y * size.x + cell.x] = 1


func _mask_has(mask: PackedByteArray, size: Vector2i, cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= size.x or cell.y >= size.y:
		return true
	return mask[cell.y * size.x + cell.x] != 0
