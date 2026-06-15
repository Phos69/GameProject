extends Node
class_name ObstacleLayoutGenerator

const ROAD_WIDTH := 10
const SECONDARY_ROAD_WIDTH := 5
const BORDER_THICKNESS := 4

func populate_layout(
	layout: BiomeEnvironmentLayout,
	cell: BiomeCell,
	biome: BiomeDefinition
) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = maxi(cell.seed, 1)
	_add_roads(layout, cell)
	_add_large_obstacles(layout, biome, rng)
	_add_secondary_obstacles(layout, biome, rng)
	_add_connected_border_walls(layout, cell)
	_add_crates(layout, biome)
	_add_theme_hazards(layout, biome)

func repair_layout(layout: BiomeEnvironmentLayout) -> void:
	for index in range(layout.obstacle_rects.size() - 1, -1, -1):
		var obstacle_rect := layout.obstacle_rects[index]
		if _intersects_any(obstacle_rect, layout.road_rects):
			layout.obstacle_rects.remove_at(index)
			layout.obstacle_ids.remove_at(index)
			layout.obstacle_positions.remove_at(index)
			layout.obstacle_sizes.remove_at(index)
			layout.obstacle_rotations.remove_at(index)
			layout.obstacle_shape_ids.remove_at(index)

func _add_roads(layout: BiomeEnvironmentLayout, cell: BiomeCell) -> void:
	var zone_size := layout.zone_size
	var center := zone_size / 2
	var horizontal := Rect2i(
		Vector2i(0, center.y - ROAD_WIDTH / 2),
		Vector2i(zone_size.x, ROAD_WIDTH)
	)
	var vertical := Rect2i(
		Vector2i(center.x - ROAD_WIDTH / 2, 0),
		Vector2i(ROAD_WIDTH, zone_size.y)
	)
	_add_road_rect(layout, horizontal, &"main_road")
	_add_road_rect(layout, vertical, &"main_road")

	for passage in cell.passages:
		var passage_rect := passage.get_local_rect(zone_size)
		layout.passage_rects.append(passage_rect)
		_add_road_rect(layout, passage_rect, passage.passage_type)
		_add_road_rect(
			layout,
			_connector_rect_for_passage(passage, zone_size),
			passage.passage_type
		)

func _add_road_rect(
	layout: BiomeEnvironmentLayout,
	rect: Rect2i,
	tag: StringName
) -> void:
	layout.road_rects.append(rect)
	layout.terrain_patch_tags.append(tag)
	layout.terrain_patch_positions.append(layout.rect_center_to_world(rect))
	layout.terrain_patch_radii.append(
		maxf(float(maxi(rect.size.x, rect.size.y)) * layout.logical_tile_scale * 0.18, 28.0)
	)

func _connector_rect_for_passage(
	passage: BiomePassage,
	zone_size: Vector2i
) -> Rect2i:
	var center := zone_size / 2
	var half_width := maxi(passage.width / 2, 2)
	match passage.side:
		&"north":
			return Rect2i(
				Vector2i(passage.position - half_width, 0),
				Vector2i(passage.width, center.y)
			)
		&"south":
			return Rect2i(
				Vector2i(passage.position - half_width, center.y),
				Vector2i(passage.width, zone_size.y - center.y)
			)
		&"west":
			return Rect2i(
				Vector2i(0, passage.position - half_width),
				Vector2i(center.x, passage.width)
			)
		_:
			return Rect2i(
				Vector2i(center.x, passage.position - half_width),
				Vector2i(zone_size.x - center.x, passage.width)
			)

func _add_large_obstacles(
	layout: BiomeEnvironmentLayout,
	biome: BiomeDefinition,
	rng: RandomNumberGenerator
) -> void:
	var obstacle_id := _large_obstacle_id(biome.biome_id)
	var candidates: Array[Vector2i] = [
		Vector2i(32, 32),
		Vector2i(142, 32),
		Vector2i(32, 142),
		Vector2i(142, 142)
	]
	for candidate in candidates:
		var size := Vector2i(
			rng.randi_range(14, 28),
			rng.randi_range(12, 24)
		)
		var rect := Rect2i(candidate, size)
		if _intersects_any(rect, layout.road_rects):
			continue
		_add_obstacle(layout, obstacle_id, rect, &"rectangle", 0.0)

func _add_secondary_obstacles(
	layout: BiomeEnvironmentLayout,
	biome: BiomeDefinition,
	_rng: RandomNumberGenerator
) -> void:
	var ids := _secondary_obstacle_ids(biome.biome_id)
	var rects: Array[Rect2i] = [
		Rect2i(Vector2i(72, 62), Vector2i(12, 4)),
		Rect2i(Vector2i(122, 134), Vector2i(16, 5)),
		Rect2i(Vector2i(62, 122), Vector2i(5, 16)),
		Rect2i(Vector2i(134, 72), Vector2i(5, 14))
	]
	for index in range(rects.size()):
		var rect := rects[index]
		if _intersects_any(rect, layout.road_rects):
			continue
		_add_obstacle(layout, ids[index % ids.size()], rect, &"rectangle", 0.0)

func _add_connected_border_walls(
	layout: BiomeEnvironmentLayout,
	cell: BiomeCell
) -> void:
	for side in BiomeCell.SIDES:
		if cell.get_border(side) != BiomeCell.BorderType.CONNECTED:
			continue
		var passages := cell.get_passages_for_side(side)
		if passages.is_empty():
			_add_border_segment(layout, side, 0, layout.zone_size.y)
			continue
		var passage: BiomePassage = passages.front()
		var start := clampi(passage.position - passage.width / 2 - 2, 0, layout.zone_size.y)
		var finish := clampi(passage.position + passage.width / 2 + 2, 0, layout.zone_size.y)
		_add_border_segment(layout, side, 0, start)
		_add_border_segment(layout, side, finish, layout.zone_size.y)

func _add_border_segment(
	layout: BiomeEnvironmentLayout,
	side: StringName,
	start: int,
	finish: int
) -> void:
	if finish - start < 10:
		return
	var zone_size := layout.zone_size
	var rect := Rect2i()
	match side:
		&"north":
			rect = Rect2i(Vector2i(start, 0), Vector2i(finish - start, BORDER_THICKNESS))
		&"south":
			rect = Rect2i(
				Vector2i(start, zone_size.y - BORDER_THICKNESS),
				Vector2i(finish - start, BORDER_THICKNESS)
			)
		&"west":
			rect = Rect2i(Vector2i(0, start), Vector2i(BORDER_THICKNESS, finish - start))
		_:
			rect = Rect2i(
				Vector2i(zone_size.x - BORDER_THICKNESS, start),
				Vector2i(BORDER_THICKNESS, finish - start)
			)
	_add_obstacle(layout, &"boundary_fence", rect, &"rectangle", 0.0)

func _add_crates(
	layout: BiomeEnvironmentLayout,
	biome: BiomeDefinition
) -> void:
	var crate_ids := _crate_ids(biome.biome_id)
	var cells: Array[Vector2i] = [
		Vector2i(82, 92),
		Vector2i(118, 108),
		Vector2i(100, 72),
		Vector2i(100, 128)
	]
	for index in range(cells.size()):
		_add_crate(layout, crate_ids[index % crate_ids.size()], cells[index])

func _add_theme_hazards(
	layout: BiomeEnvironmentLayout,
	biome: BiomeDefinition
) -> void:
	match biome.biome_id:
		&"toxic_wastes":
			_add_hazard(layout, &"toxic_puddle", Rect2i(Vector2i(70, 38), Vector2i(18, 10)))
			_add_hazard(layout, &"gas_cloud", Rect2i(Vector2i(124, 154), Vector2i(20, 12)))
		&"burning_fields":
			_add_hazard(layout, &"lava_crack", Rect2i(Vector2i(68, 148), Vector2i(24, 8)))
			_add_hazard(layout, &"fire_zone", Rect2i(Vector2i(134, 42), Vector2i(14, 14)))
		&"frozen_outskirts":
			_add_hazard(layout, &"slippery_ice", Rect2i(Vector2i(64, 144), Vector2i(24, 14)))
			_add_hazard(layout, &"deep_snow_slow", Rect2i(Vector2i(132, 40), Vector2i(20, 18)))
		&"drowned_marsh":
			_add_hazard(layout, &"deep_water", Rect2i(Vector2i(58, 142), Vector2i(28, 16)))
			_add_hazard(layout, &"mud_slow", Rect2i(Vector2i(132, 44), Vector2i(20, 16)))
		_:
			pass

func _add_obstacle(
	layout: BiomeEnvironmentLayout,
	obstacle_id: StringName,
	rect: Rect2i,
	shape_id: StringName,
	rotation_radians: float
) -> void:
	layout.obstacle_rects.append(rect)
	layout.obstacle_ids.append(obstacle_id)
	layout.obstacle_positions.append(layout.rect_center_to_world(rect))
	layout.obstacle_sizes.append(layout.rect_size_to_world(rect))
	layout.obstacle_rotations.append(rotation_radians)
	layout.obstacle_shape_ids.append(shape_id)

func _add_crate(
	layout: BiomeEnvironmentLayout,
	crate_id: StringName,
	cell: Vector2i
) -> void:
	if _cell_inside_any_rect(cell, layout.obstacle_rects):
		return
	layout.crate_cells.append(cell)
	layout.crate_ids.append(crate_id)
	layout.crate_positions.append(layout.logical_to_world(cell))

func _add_hazard(
	layout: BiomeEnvironmentLayout,
	hazard_id: StringName,
	rect: Rect2i
) -> void:
	layout.hazard_rects.append(rect)
	layout.hazard_ids.append(hazard_id)
	layout.hazard_positions.append(layout.rect_center_to_world(rect))
	layout.hazard_sizes.append(layout.rect_size_to_world(rect))
	layout.hazard_rotations.append(0.0)

func _large_obstacle_id(biome_id: StringName) -> StringName:
	match biome_id:
		&"toxic_wastes":
			return &"lab_block"
		&"burning_fields":
			return &"burned_house"
		&"frozen_outskirts":
			return &"snow_cabin"
		&"drowned_marsh":
			return &"sunken_house"
		_:
			return &"ruined_house"

func _secondary_obstacle_ids(biome_id: StringName) -> Array[StringName]:
	match biome_id:
		&"toxic_wastes":
			return [&"industrial_fence", &"toxic_barrel", &"lab_wall"]
		&"burning_fields":
			return [&"charred_wall", &"ash_barrier", &"burned_car"]
		&"frozen_outskirts":
			return [&"snow_wall", &"ice_rock", &"fallen_log"]
		&"drowned_marsh":
			return [&"reed_wall", &"marsh_log", &"broken_walkway"]
		_:
			return [&"small_rock", &"broken_fence", &"wood_barrier"]

func _crate_ids(biome_id: StringName) -> Array[StringName]:
	match biome_id:
		&"toxic_wastes":
			return [&"biome_toxic", &"medical", &"common"]
		&"burning_fields":
			return [&"biome_fire", &"military", &"common"]
		&"frozen_outskirts":
			return [&"biome_frost", &"medical", &"common"]
		&"drowned_marsh":
			return [&"biome_marsh", &"common", &"medical"]
		_:
			return [&"common", &"medical", &"common"]

func _intersects_any(rect: Rect2i, others: Array[Rect2i]) -> bool:
	for other in others:
		if rect.intersects(other):
			return true
	return false

func _cell_inside_any_rect(cell: Vector2i, rects: Array[Rect2i]) -> bool:
	for rect in rects:
		if rect.has_point(cell):
			return true
	return false
