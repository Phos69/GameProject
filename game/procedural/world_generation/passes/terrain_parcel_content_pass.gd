extends RefCounted
class_name TerrainParcelContentPass

const WorldGridConfig = preload("res://game/core/world_grid_config.gd")

const FALL_ZONE_RIM := 1
const PLAINS_MOUNTAIN_VOID_DEPTH := 2
const FOREST_CORRIDOR_WIDTH := 2
const CLEARING_TREE_MIN_DISTANCE := 5
const MAX_FOREST_TREES := 420
const TOWN_MIN_BUILDINGS := 2
const TOWN_MAX_BUILDINGS := 4
const TOWN_MAX_VEHICLES := 3
const CARDINAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP,
]


func populate(
	layout: BiomeEnvironmentLayout,
	biome: BiomeDefinition,
	rng: RandomNumberGenerator,
	path_tag: StringName,
	allow_internal_void: bool = true
) -> Dictionary:
	var summary := {
		"mesa_count": 0,
		"mountain_void_contact_count": 0,
		"forest_tree_count": 0,
		"clearing_tree_count": 0,
		"fall_zone_parcel_count": 0,
		"town_count": 0,
		"town_building_count": 0,
		"town_vehicle_count": 0,
		"town_driveway_count": 0,
	}
	for parcel_index in range(layout.parcel_types.size()):
		match layout.parcel_types[parcel_index]:
			BiomeEnvironmentLayout.PARCEL_MESA:
				var mesa_result := _populate_mesa(
					layout, biome, parcel_index, allow_internal_void
				)
				summary["mesa_count"] = int(summary["mesa_count"]) + int(
					mesa_result.get("mesa_count", 0)
				)
				summary["mountain_void_contact_count"] = int(
					summary["mountain_void_contact_count"]
				) + int(mesa_result.get("contact_count", 0))
			BiomeEnvironmentLayout.PARCEL_FOREST:
				summary["forest_tree_count"] = int(summary["forest_tree_count"]) + _populate_forest(
					layout, biome, parcel_index, rng
				)
			BiomeEnvironmentLayout.PARCEL_CLEARING:
				summary["clearing_tree_count"] = int(summary["clearing_tree_count"]) + _populate_clearing(
					layout, biome, parcel_index, rng
				)
			BiomeEnvironmentLayout.PARCEL_FALL_ZONE:
				if allow_internal_void and _populate_fall_zone(layout, parcel_index):
					summary["fall_zone_parcel_count"] = int(summary["fall_zone_parcel_count"]) + 1
				else:
					layout.set_parcel_type(parcel_index, BiomeEnvironmentLayout.PARCEL_CLEARING)
					summary["clearing_tree_count"] = int(summary["clearing_tree_count"]) + _populate_clearing(
						layout, biome, parcel_index, rng
					)
			BiomeEnvironmentLayout.PARCEL_TOWN:
				var town := _populate_town(layout, biome, parcel_index, rng, path_tag)
				summary["town_count"] = int(summary["town_count"]) + 1
				summary["town_building_count"] = int(summary["town_building_count"]) + int(town["buildings"])
				summary["town_vehicle_count"] = int(summary["town_vehicle_count"]) + int(town["vehicles"])
				summary["town_driveway_count"] = int(summary["town_driveway_count"]) + int(town["driveways"])
	return summary


func _populate_mesa(
	layout: BiomeEnvironmentLayout,
	biome: BiomeDefinition,
	parcel_index: int,
	allow_internal_void: bool
) -> Dictionary:
	var rect := _largest_inner_rect(layout, parcel_index, 1)
	if rect.size.x < 5 or rect.size.y < 5:
		return {"mesa_count": 0, "contact_count": 0}
	var contact_count := 0
	if (
		allow_internal_void
		and biome != null
		and biome.biome_id == &"plains"
	):
		var chasm_rect := Rect2i(
			Vector2i(rect.position.x, rect.end.y - PLAINS_MOUNTAIN_VOID_DEPTH),
			Vector2i(rect.size.x, PLAINS_MOUNTAIN_VOID_DEPTH)
		)
		rect.size.y -= PLAINS_MOUNTAIN_VOID_DEPTH
		layout.add_fall_zone_rect(chasm_rect, &"internal")
		contact_count = 1
	layout.mesa_rects.append(rect)
	layout.mesa_profile_ids.append(_mesa_profile_id(biome))
	layout.obstacle_rects.append(rect)
	layout.obstacle_ids.append(&"large_rock")
	layout.obstacle_positions.append(layout.obstacle_rect_center_to_world(rect, &"large_rock"))
	layout.obstacle_sizes.append(layout.rect_size_to_world(rect))
	layout.obstacle_rotations.append(0.0)
	layout.obstacle_shape_ids.append(&"rectangle")
	return {"mesa_count": 1, "contact_count": contact_count}


func _populate_forest(
	layout: BiomeEnvironmentLayout,
	biome: BiomeDefinition,
	parcel_index: int,
	rng: RandomNumberGenerator
) -> int:
	var tree_id := &"forest_tree"
	var corridor_count := 1
	if biome != null and biome.generation_profile != null:
		tree_id = biome.generation_profile.forest_tree_id
		corridor_count = rng.randi_range(
			biome.generation_profile.forest_corridor_min_count,
			biome.generation_profile.forest_corridor_max_count
		)
	var footprint := _logical_footprint(tree_id)
	var bounds := layout.parcel_bounds[parcel_index]
	layout.forest_rects.append(bounds)
	var corridor_cells: Dictionary = {}
	var center := bounds.position + bounds.size / 2
	_mark_corridor(corridor_cells, bounds, true, center.y)
	layout.forest_corridor_rects.append(Rect2i(
		Vector2i(bounds.position.x, center.y - FOREST_CORRIDOR_WIDTH / 2),
		Vector2i(bounds.size.x, FOREST_CORRIDOR_WIDTH)
	))
	layout.forest_corridor_parcel_indices.append(parcel_index)
	if corridor_count > 1:
		_mark_corridor(corridor_cells, bounds, false, center.x)
		layout.forest_corridor_rects.append(Rect2i(
			Vector2i(center.x - FOREST_CORRIDOR_WIDTH / 2, bounds.position.y),
			Vector2i(FOREST_CORRIDOR_WIDTH, bounds.size.y)
		))
		layout.forest_corridor_parcel_indices.append(parcel_index)
	var placed := 0
	for y in range(bounds.position.y, bounds.end.y - footprint.y + 1, maxi(footprint.y, 1)):
		for x in range(bounds.position.x, bounds.end.x - footprint.x + 1, maxi(footprint.x, 1)):
			if placed >= MAX_FOREST_TREES:
				return placed
			var rect := Rect2i(Vector2i(x, y), footprint)
			if not _rect_belongs_to_parcel(layout, rect, parcel_index):
				continue
			if _rect_hits_lookup(rect, corridor_cells):
				continue
			if layout.rect_intersects_route(rect) or GeometryUtils.intersects_any(rect, layout.obstacle_rects):
				continue
			_add_obstacle(layout, tree_id, rect)
			placed += 1
	return placed


func _populate_clearing(
	layout: BiomeEnvironmentLayout,
	biome: BiomeDefinition,
	parcel_index: int,
	rng: RandomNumberGenerator
) -> int:
	var tree_id := &"forest_tree"
	var line_chance := 0.50
	if biome != null and biome.generation_profile != null:
		tree_id = biome.generation_profile.forest_tree_id
		line_chance = biome.generation_profile.clearing_tree_line_chance
	var footprint := _logical_footprint(tree_id)
	var cells := layout.get_parcel_cells(parcel_index)
	var target := clampi(cells.size() / 90, 2, 8)
	var candidates := cells.duplicate()
	_shuffle(candidates, rng)
	var placed_rects: Array[Rect2i] = []
	for cell in candidates:
		if placed_rects.size() >= target:
			break
		var rect := Rect2i(cell, footprint)
		if not _can_place_tree(layout, rect, parcel_index, placed_rects):
			continue
		_add_obstacle(layout, tree_id, rect)
		placed_rects.append(rect)

	# Roll once for every continuous route-facing boundary segment, rather than
	# once per cell or parcel. This keeps rows coherent while letting separate
	# road/path edges vary independently for the same seed.
	for segment in _route_boundary_segments(layout, parcel_index):
		if rng.randf() > line_chance:
			continue
		for cell_index in range(0, segment.size(), CLEARING_TREE_MIN_DISTANCE):
			var anchor := segment[cell_index] as Vector2i
			if _near_route_junction(layout, anchor):
				continue
			var rect := Rect2i(anchor, footprint)
			if not _rect_belongs_to_parcel(layout, rect, parcel_index):
				continue
			if not _can_place_tree(layout, rect, parcel_index, placed_rects):
				continue
			_add_obstacle(layout, tree_id, rect)
			placed_rects.append(rect)
	return placed_rects.size()


func _route_boundary_segments(
	layout: BiomeEnvironmentLayout,
	parcel_index: int
) -> Array[Array]:
	var result: Array[Array] = []
	var parcel_cells := layout.get_parcel_cells(parcel_index)
	for direction: Vector2i in CARDINAL_DIRECTIONS:
		var boundary: Dictionary = {}
		for cell in parcel_cells:
			if layout.has_road_cell(cell + direction):
				boundary[cell] = true
		var tangent := Vector2i(-direction.y, direction.x)
		while not boundary.is_empty():
			var seed := boundary.keys()[0] as Vector2i
			var start := seed
			while boundary.has(start - tangent):
				start -= tangent
			var segment: Array[Vector2i] = []
			var cursor := start
			while boundary.has(cursor):
				segment.append(cursor)
				boundary.erase(cursor)
				cursor += tangent
			result.append(segment)
	return result


func _near_route_junction(layout: BiomeEnvironmentLayout, anchor: Vector2i) -> bool:
	var route_neighbors := 0
	for direction: Vector2i in CARDINAL_DIRECTIONS:
		if layout.has_road_cell(anchor + direction):
			route_neighbors += 1
	return route_neighbors > 1


func _populate_fall_zone(layout: BiomeEnvironmentLayout, parcel_index: int) -> bool:
	var interior: Array[Vector2i] = []
	for cell in layout.get_parcel_cells(parcel_index):
		var is_interior := true
		for direction: Vector2i in CARDINAL_DIRECTIONS:
			var neighbor: Vector2i = cell + direction * FALL_ZONE_RIM
			if layout.get_parcel_index_at_cell(neighbor) != parcel_index:
				is_interior = false
				break
		if is_interior:
			interior.append(cell)
	if interior.size() < 16:
		return false
	for rect in _cells_to_row_rects(interior):
		layout.add_fall_zone_rect(rect, &"internal")
	return true


func _populate_town(
	layout: BiomeEnvironmentLayout,
	biome: BiomeDefinition,
	parcel_index: int,
	rng: RandomNumberGenerator,
	path_tag: StringName
) -> Dictionary:
	var pools := _town_pools(biome)
	var buildings := pools["buildings"] as Array[StringName]
	var vehicles := pools["vehicles"] as Array[StringName]
	var desired_buildings := clampi(layout.parcel_areas[parcel_index] / 220, TOWN_MIN_BUILDINGS, TOWN_MAX_BUILDINGS)
	var building_rects: Array[Rect2i] = []
	var driveways := 0
	for index in range(desired_buildings):
		var building_id := buildings[index % buildings.size()]
		var rect := _find_object_rect(layout, parcel_index, building_id, rng, 160, true)
		if rect.size.x <= 0:
			continue
		var entrance := _building_entrance(building_id, rect)
		if not _carve_driveway(layout, parcel_index, entrance, path_tag, rect):
			continue
		_add_obstacle(layout, building_id, rect)
		layout.mass_rects.append(rect)
		building_rects.append(rect)
		layout.town_entrance_cells.append(entrance)
		driveways += 1

	var desired_vehicles := clampi(ceili(float(building_rects.size()) / 2.0), 1, TOWN_MAX_VEHICLES)
	var placed_vehicles := 0
	for index in range(desired_vehicles):
		var vehicle_id := vehicles[index % vehicles.size()]
		var rect := _find_object_rect(layout, parcel_index, vehicle_id, rng, 120)
		if rect.size.x <= 0:
			continue
		_add_obstacle(layout, vehicle_id, rect)
		placed_vehicles += 1
	return {
		"buildings": building_rects.size(),
		"vehicles": placed_vehicles,
		"driveways": driveways,
	}


func _carve_driveway(
	layout: BiomeEnvironmentLayout,
	parcel_index: int,
	start: Vector2i,
	path_tag: StringName,
	planned_building_rect: Rect2i = Rect2i()
) -> bool:
	var target := _nearest_main_route_cell(layout, start)
	if target.x < 0:
		return false
	var astar := AStarGrid2D.new()
	astar.region = Rect2i(Vector2i.ZERO, layout.zone_size)
	astar.cell_size = Vector2.ONE
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()
	for y in range(layout.zone_size.y):
		for x in range(layout.zone_size.x):
			var cell := Vector2i(x, y)
			if (
				layout.get_parcel_index_at_cell(cell) != parcel_index
				and not _is_main_route_cell(layout, cell)
			):
				astar.set_point_solid(cell, true)
	for rect in layout.obstacle_rects:
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				var cell := Vector2i(x, y)
				if astar.region.has_point(cell):
					astar.set_point_solid(cell, true)
	for y in range(planned_building_rect.position.y, planned_building_rect.end.y):
		for x in range(planned_building_rect.position.x, planned_building_rect.end.x):
			var cell := Vector2i(x, y)
			if astar.region.has_point(cell):
				astar.set_point_solid(cell, true)
	start = _nearest_open_cell(astar, start)
	if start.x < 0 or astar.is_point_solid(target):
		return false
	var path := astar.get_id_path(start, target)
	if path.is_empty():
		return false
	var before := WorldGridConfig.VOIDFIRST_PATH_WIDTH_TILES / 2
	for point_value in path:
		var point := point_value as Vector2i
		for y in range(point.y - before, point.y - before + WorldGridConfig.VOIDFIRST_PATH_WIDTH_TILES):
			for x in range(point.x - before, point.x - before + WorldGridConfig.VOIDFIRST_PATH_WIDTH_TILES):
				var cell := Vector2i(x, y)
				if planned_building_rect.has_point(cell):
					continue
				if _cell_inside_obstacle(layout, cell):
					continue
				if layout.get_parcel_index_at_cell(cell) == parcel_index or _is_main_route_cell(layout, cell):
					layout.add_road_cell(cell, &"parcel_driveway")
					layout.add_road_cell(cell, path_tag)
	return true


func _cell_inside_obstacle(layout: BiomeEnvironmentLayout, cell: Vector2i) -> bool:
	for rect in layout.obstacle_rects:
		if rect.has_point(cell):
			return true
	return false


func _find_object_rect(
	layout: BiomeEnvironmentLayout,
	parcel_index: int,
	object_id: StringName,
	rng: RandomNumberGenerator,
	attempts: int,
	requires_entrance: bool = false
) -> Rect2i:
	var size := _logical_footprint(object_id)
	var bounds := layout.parcel_bounds[parcel_index]
	var max_x := bounds.end.x - size.x
	var max_y := bounds.end.y - size.y
	if max_x < bounds.position.x or max_y < bounds.position.y:
		return Rect2i()
	for _attempt in range(attempts):
		var rect := Rect2i(
			Vector2i(
				rng.randi_range(bounds.position.x, max_x),
				rng.randi_range(bounds.position.y, max_y)
			),
			size
		)
		if not _rect_belongs_to_parcel(layout, rect, parcel_index):
			continue
		if layout.rect_intersects_route(GeometryUtils.inflate_rect(rect, 1)):
			continue
		if GeometryUtils.intersects_any(GeometryUtils.inflate_rect(rect, 1), layout.obstacle_rects):
			continue
		if (
			requires_entrance
			and layout.get_parcel_index_at_cell(_building_entrance(object_id, rect)) != parcel_index
		):
			continue
		return rect
	return Rect2i()


func _largest_inner_rect(layout: BiomeEnvironmentLayout, parcel_index: int, inset: int) -> Rect2i:
	var bounds := layout.parcel_bounds[parcel_index].grow(-inset)
	if bounds.size.x <= 0 or bounds.size.y <= 0:
		return Rect2i()
	var heights := PackedInt32Array()
	heights.resize(bounds.size.x)
	var best := Rect2i()
	var best_area := 0
	for y in range(bounds.position.y, bounds.end.y):
		for local_x in range(bounds.size.x):
			var cell := Vector2i(bounds.position.x + local_x, y)
			heights[local_x] = heights[local_x] + 1 if layout.get_parcel_index_at_cell(cell) == parcel_index else 0
		for left in range(bounds.size.x):
			var min_height := 1 << 20
			for right in range(left, bounds.size.x):
				min_height = mini(min_height, heights[right])
				if min_height <= 0:
					break
				var area := min_height * (right - left + 1)
				if area <= best_area:
					continue
				best_area = area
				best = Rect2i(
					Vector2i(bounds.position.x + left, y - min_height + 1),
					Vector2i(right - left + 1, min_height)
				)
	return best


func _can_place_tree(
	layout: BiomeEnvironmentLayout,
	rect: Rect2i,
	parcel_index: int,
	placed: Array[Rect2i]
) -> bool:
	if not _rect_belongs_to_parcel(layout, rect, parcel_index):
		return false
	if layout.rect_intersects_route(rect) or GeometryUtils.intersects_any(rect, layout.obstacle_rects):
		return false
	for other in placed:
		if GeometryUtils.inflate_rect(other, CLEARING_TREE_MIN_DISTANCE).intersects(rect):
			return false
	return true


func _rect_belongs_to_parcel(layout: BiomeEnvironmentLayout, rect: Rect2i, parcel_index: int) -> bool:
	if rect.position.x < 0 or rect.position.y < 0 or rect.end.x > layout.zone_size.x or rect.end.y > layout.zone_size.y:
		return false
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if layout.get_parcel_index_at_cell(Vector2i(x, y)) != parcel_index:
				return false
	return true


func _rect_is_route_adjacent(layout: BiomeEnvironmentLayout, rect: Rect2i) -> bool:
	return layout.rect_intersects_route(GeometryUtils.inflate_rect(rect, 1))


func _mark_corridor(lookup: Dictionary, bounds: Rect2i, horizontal: bool, axis: int) -> void:
	var before := FOREST_CORRIDOR_WIDTH / 2
	if horizontal:
		for y in range(axis - before, axis - before + FOREST_CORRIDOR_WIDTH):
			for x in range(bounds.position.x, bounds.end.x):
				lookup[Vector2i(x, y)] = true
	else:
		for x in range(axis - before, axis - before + FOREST_CORRIDOR_WIDTH):
			for y in range(bounds.position.y, bounds.end.y):
				lookup[Vector2i(x, y)] = true


func _rect_hits_lookup(rect: Rect2i, lookup: Dictionary) -> bool:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if lookup.has(Vector2i(x, y)):
				return true
	return false


func _cells_to_row_rects(cells: Array[Vector2i]) -> Array[Rect2i]:
	var by_row: Dictionary = {}
	for cell in cells:
		if not by_row.has(cell.y):
			by_row[cell.y] = []
		(by_row[cell.y] as Array).append(cell.x)
	var result: Array[Rect2i] = []
	var rows: Array = by_row.keys()
	rows.sort()
	for row_value in rows:
		var xs: Array = by_row[row_value] as Array
		xs.sort()
		var start := int(xs[0])
		var previous := start
		for offset in range(1, xs.size() + 1):
			var at_end := offset == xs.size()
			var next_x := previous + 2 if at_end else int(xs[offset])
			if next_x != previous + 1:
				result.append(Rect2i(start, int(row_value), previous - start + 1, 1))
				start = next_x
			previous = next_x
	return result


func _nearest_main_route_cell(layout: BiomeEnvironmentLayout, origin: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_distance := 1 << 20
	for y in range(layout.zone_size.y):
		for x in range(layout.zone_size.x):
			var cell := Vector2i(x, y)
			if not _is_main_route_cell(layout, cell):
				continue
			var distance := absi(cell.x - origin.x) + absi(cell.y - origin.y)
			if distance < best_distance:
				best = cell
				best_distance = distance
	return best


func _is_main_route_cell(layout: BiomeEnvironmentLayout, cell: Vector2i) -> bool:
	var tags := layout.get_road_tags_at_cell(cell)
	if tags.has(TerrainParcelPartitionPass.TRAIL_TAG) or tags.has(&"parcel_driveway"):
		for rect in layout.road_rects:
			if rect.has_point(cell):
				return true
		return false
	if not tags.is_empty():
		return true
	for rect in layout.road_rects:
		if rect.has_point(cell):
			return true
	return false


func _nearest_open_cell(astar: AStarGrid2D, origin: Vector2i) -> Vector2i:
	if astar.region.has_point(origin) and not astar.is_point_solid(origin):
		return origin
	for radius in range(1, 12):
		for y in range(origin.y - radius, origin.y + radius + 1):
			for x in range(origin.x - radius, origin.x + radius + 1):
				var cell := Vector2i(x, y)
				if astar.region.has_point(cell) and not astar.is_point_solid(cell):
					return cell
	return Vector2i(-1, -1)


func _town_pools(biome: BiomeDefinition) -> Dictionary:
	if biome != null and biome.generation_profile != null:
		if not biome.generation_profile.town_building_ids.is_empty() and not biome.generation_profile.town_vehicle_ids.is_empty():
			return {
				"buildings": biome.generation_profile.town_building_ids,
				"vehicles": biome.generation_profile.town_vehicle_ids,
			}
	var biome_id := biome.biome_id if biome != null else &"plains"
	match biome_id:
		&"toxic_wastes":
			return {"buildings": [&"lab_ruin", &"lab_block"], "vehicles": [&"abandoned_car"]}
		&"burning_plains":
			return {"buildings": [&"burned_house"], "vehicles": [&"burned_car", &"metal_wreck"]}
		&"frozen_tundra":
			return {"buildings": [&"snow_cabin"], "vehicles": [&"abandoned_car"]}
		&"swamp":
			return {"buildings": [&"sunken_house"], "vehicles": [&"sunken_wreck"]}
		_:
			return {"buildings": [&"ruined_house", &"abandoned_house"], "vehicles": [&"abandoned_car"]}


func _building_entrance(building_id: StringName, rect: Rect2i) -> Vector2i:
	var manifest := EnvironmentAssetManifest.get_shared()
	var side := manifest.get_entrance_side(building_id)
	var offset := manifest.get_entrance_offset_tiles(building_id)
	var center := rect.position + rect.size / 2 + offset
	match side:
		&"north":
			return Vector2i(center.x, rect.position.y - 1)
		&"west":
			return Vector2i(rect.position.x - 1, center.y)
		&"east":
			return Vector2i(rect.end.x, center.y)
		_:
			return Vector2i(center.x, rect.end.y)


func _mesa_profile_id(biome: BiomeDefinition) -> StringName:
	if biome != null and biome.generation_profile != null:
		return biome.generation_profile.mesa_profile_id
	return &"forest"


func _logical_footprint(object_id: StringName) -> Vector2i:
	return WorldGridConfig.legacy_size_to_new_tiles(
		EnvironmentAssetManifest.get_shared().get_footprint_tiles(object_id)
	)


func _add_obstacle(layout: BiomeEnvironmentLayout, object_id: StringName, rect: Rect2i) -> void:
	layout.obstacle_rects.append(rect)
	layout.obstacle_ids.append(object_id)
	layout.obstacle_positions.append(layout.obstacle_rect_center_to_world(rect, object_id))
	layout.obstacle_sizes.append(layout.rect_size_to_world(rect))
	layout.obstacle_rotations.append(0.0)
	layout.obstacle_shape_ids.append(
		EnvironmentAssetManifest.get_shared().get_collision_shape(object_id)
	)


func _shuffle(values: Array[Vector2i], rng: RandomNumberGenerator) -> void:
	for index in range(values.size() - 1, 0, -1):
		var other := rng.randi_range(0, index)
		var value := values[index]
		values[index] = values[other]
		values[other] = value
