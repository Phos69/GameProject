extends RefCounted
class_name ObstacleLayoutGenerator

const ROAD_WIDTH := 10
const SECONDARY_ROAD_WIDTH := 4
const BORDER_THICKNESS := 4
# Perimeter walls are tiled as a contiguous run of segments so the whole side
# reads as a continuous isometric wall instead of a single centred sprite.
const WALL_SEGMENT_LENGTH := 12
const WALL_MIN_SEGMENT := 5
# Small thematic props scattered inside internal blocks for ambient detail.
const MAX_BLOCK_PROPS := 64
const PROP_BLOCK_MARGIN := 4
const MIN_RECT_GAP := 2
const BLOCK_INSET := 0
const MIN_BLOCK_SIZE := 32

const GENERATED_OBSTACLE_CATEGORIES: Dictionary = {
	&"ash_barrier": &"barrier",
	&"boundary_fence": &"border",
	&"broken_fence": &"barrier",
	&"broken_walkway": &"bridge",
	&"burned_car": &"wreck",
	&"burned_house": &"building",
	&"charred_wall": &"barrier",
	&"dead_tree": &"tree",
	&"deep_water_boundary": &"border",
	&"fallen_log": &"log",
	&"ice_boundary": &"border",
	&"ice_block": &"rock",
	&"ice_rock": &"rock",
	&"industrial_fence": &"barrier",
	&"lab_block": &"building",
	&"lab_wall": &"barrier",
	&"lava_boundary": &"border",
	&"marsh_log": &"log",
	&"pipe_stack": &"barrier",
	&"reed_wall": &"barrier",
	&"ruined_house": &"building",
	&"small_rock": &"rock",
	&"snow_cabin": &"building",
	&"snow_wall": &"barrier",
	&"sunken_house": &"building",
	&"toxic_barrel": &"barrel",
	&"toxic_boundary_wall": &"border",
	&"wood_barrier": &"barrier"
}
const GENERATED_TERRAIN_TAG_CATEGORIES: Dictionary = {
	&"ash_lane": &"road",
	&"broken_street": &"road",
	&"main_road": &"road",
	&"packed_snow_path": &"road",
	&"service_lane": &"road",
	&"wooden_walkway": &"road"
}

static func get_generated_obstacle_categories() -> Dictionary:
	return GENERATED_OBSTACLE_CATEGORIES.duplicate()

static func get_generated_terrain_tag_categories() -> Dictionary:
	return GENERATED_TERRAIN_TAG_CATEGORIES.duplicate()

func populate_layout(
	layout: BiomeEnvironmentLayout,
	cell: BiomeCell,
	biome: BiomeDefinition
) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = maxi(cell.seed, 1)
	_add_roads(layout, cell)
	_add_biome_navigation_features(layout, biome, rng)
	_add_internal_blocks(layout, biome, rng)
	_add_large_obstacles(layout, biome, rng)
	_add_secondary_obstacles(layout, biome, rng)
	_add_connected_border_walls(layout, cell, biome)
	_add_crates(layout, biome)
	_add_theme_hazards(layout, biome)
	_add_block_props(layout, biome, rng)

func repair_layout(layout: BiomeEnvironmentLayout) -> void:
	for index in range(layout.obstacle_rects.size() - 1, -1, -1):
		var obstacle_rect := layout.obstacle_rects[index]
		if _intersects_route(layout, obstacle_rect):
			layout.obstacle_rects.remove_at(index)
			layout.obstacle_ids.remove_at(index)
			layout.obstacle_positions.remove_at(index)
			layout.obstacle_sizes.remove_at(index)
			layout.obstacle_rotations.remove_at(index)
			layout.obstacle_shape_ids.remove_at(index)

func _add_roads(layout: BiomeEnvironmentLayout, cell: BiomeCell) -> void:
	var zone_size := layout.zone_size
	var center := zone_size / 2
	var half_main := ROAD_WIDTH / 2
	_add_road_rect(
		layout,
		Rect2i(
			Vector2i(0, center.y - half_main),
			Vector2i(zone_size.x, ROAD_WIDTH)
		),
		&"main_road"
	)
	_add_road_rect(
		layout,
		Rect2i(
			Vector2i(center.x - half_main, 0),
			Vector2i(ROAD_WIDTH, zone_size.y)
		),
		&"main_road"
	)

	for passage in cell.passages:
		var passage_rect := passage.get_local_rect(zone_size)
		layout.passage_rects.append(passage_rect)
		var connector_rect := passage.get_connector_rect(zone_size)
		layout.passage_connector_rects.append(connector_rect)
		_add_road_rect(layout, passage_rect, passage.passage_type)
		_add_road_rect(layout, connector_rect, passage.passage_type)

func _add_biome_navigation_features(
	layout: BiomeEnvironmentLayout,
	biome: BiomeDefinition,
	rng: RandomNumberGenerator
) -> void:
	var path_tag := _secondary_path_tag(biome.biome_id)
	var vertical_ratio := 0.32
	var horizontal_ratio := 0.68
	match biome.biome_id:
		&"infected_plains":
			vertical_ratio = 0.34
			horizontal_ratio = 0.66
		&"toxic_wastes":
			vertical_ratio = 0.38
			horizontal_ratio = 0.62
		&"burning_fields":
			vertical_ratio = 0.30
			horizontal_ratio = 0.70
		&"frozen_outskirts":
			vertical_ratio = 0.36
			horizontal_ratio = 0.64
		&"drowned_marsh":
			vertical_ratio = 0.28 + rng.randf_range(-0.015, 0.015)
			horizontal_ratio = 0.72 + rng.randf_range(-0.015, 0.015)
		_:
			pass
	_add_secondary_grid_paths(layout, path_tag, vertical_ratio, horizontal_ratio)

func _add_cover_cluster(
	layout: BiomeEnvironmentLayout,
	obstacle_id: StringName,
	anchor: Vector2i,
	horizontal: bool
) -> void:
	var first := Rect2i(anchor, Vector2i(13, 6) if horizontal else Vector2i(6, 13))
	var second := Rect2i(
		anchor + (Vector2i(18, 8) if horizontal else Vector2i(8, 18)),
		Vector2i(10, 5) if horizontal else Vector2i(5, 10)
	)
	_add_obstacle_if_clear(layout, obstacle_id, first, &"rectangle", 0.0)
	_add_obstacle_if_clear(layout, obstacle_id, second, &"rectangle", 0.0)

func _add_secondary_grid_paths(
	layout: BiomeEnvironmentLayout,
	path_tag: StringName,
	vertical_ratio: float,
	horizontal_ratio: float
) -> void:
	var zone_size := layout.zone_size
	var half_path := SECONDARY_ROAD_WIDTH / 2
	var vertical_x := clampi(
		roundi(float(zone_size.x) * vertical_ratio),
		BORDER_THICKNESS + half_path,
		zone_size.x - BORDER_THICKNESS - half_path
	)
	var horizontal_y := clampi(
		roundi(float(zone_size.y) * horizontal_ratio),
		BORDER_THICKNESS + half_path,
		zone_size.y - BORDER_THICKNESS - half_path
	)
	_add_road_rect(
		layout,
		Rect2i(
			Vector2i(vertical_x - half_path, BORDER_THICKNESS),
			Vector2i(SECONDARY_ROAD_WIDTH, zone_size.y - BORDER_THICKNESS * 2)
		),
		path_tag
	)
	_add_road_rect(
		layout,
		Rect2i(
			Vector2i(BORDER_THICKNESS, horizontal_y - half_path),
			Vector2i(zone_size.x - BORDER_THICKNESS * 2, SECONDARY_ROAD_WIDTH)
		),
		path_tag
	)

func _secondary_path_tag(biome_id: StringName) -> StringName:
	match biome_id:
		&"toxic_wastes":
			return &"service_lane"
		&"burning_fields":
			return &"ash_lane"
		&"frozen_outskirts":
			return &"packed_snow_path"
		&"drowned_marsh":
			return &"wooden_walkway"
		_:
			return &"broken_street"

func _add_choke_pair(
	layout: BiomeEnvironmentLayout,
	obstacle_id: StringName,
	anchor: Vector2i,
	rotation_radians: float
) -> void:
	_add_obstacle_if_clear(
		layout,
		obstacle_id,
		Rect2i(anchor, Vector2i(8, 18)),
		&"rectangle",
		rotation_radians
	)
	_add_obstacle_if_clear(
		layout,
		obstacle_id,
		Rect2i(anchor + Vector2i(28, -6), Vector2i(8, 18)),
		&"rectangle",
		-rotation_radians
	)

func _add_internal_blocks(
	layout: BiomeEnvironmentLayout,
	biome: BiomeDefinition,
	rng: RandomNumberGenerator
) -> void:
	var vertical_bands := _collect_axis_bands(layout, true)
	var horizontal_bands := _collect_axis_bands(layout, false)
	var x_intervals := _intervals_between_bands(vertical_bands, layout.zone_size.x)
	var y_intervals := _intervals_between_bands(horizontal_bands, layout.zone_size.y)
	var block_index := 0
	for y_interval in y_intervals:
		for x_interval in x_intervals:
			var raw_rect := Rect2i(
				Vector2i(int(x_interval.x), int(y_interval.x)),
				Vector2i(
					int(x_interval.y - x_interval.x),
					int(y_interval.y - y_interval.x)
				)
			)
			var block_rect := _inset_rect(raw_rect, BLOCK_INSET)
			if (
				block_rect.size.x < MIN_BLOCK_SIZE
				or block_rect.size.y < MIN_BLOCK_SIZE
			):
				continue
			var block_kind := _resolve_block_kind(biome.biome_id, block_index, rng)
			# Never drop a void/fall block onto a passage corridor: the connector
			# road must stay walkable and free of fall hazards so cross-biome
			# passages remain reachable.
			if (
				(block_kind == &"full_void" or block_kind == &"partial_void")
				and _rect_overlaps_passage_corridor(layout, block_rect)
			):
				block_kind = &"open"
			layout.add_block_rect(block_rect, block_kind)
			_apply_block_surface(layout, block_rect, block_kind, biome.biome_id)
			block_index += 1

func _rect_overlaps_passage_corridor(
	layout: BiomeEnvironmentLayout,
	rect: Rect2i
) -> bool:
	return (
		_intersects_any(rect, layout.passage_connector_rects)
		or _intersects_any(rect, layout.passage_rects)
	)

func _apply_block_surface(
	layout: BiomeEnvironmentLayout,
	block_rect: Rect2i,
	block_kind: StringName,
	biome_id: StringName = &""
) -> void:
	match block_kind:
		&"full_void":
			layout.add_fall_zone_rect(block_rect, &"internal")
		&"partial_void":
			layout.add_floor_rect(block_rect, &"open_block")
			var pocket := _inset_rect(
				block_rect,
				maxi(mini(block_rect.size.x, block_rect.size.y) / 4, 10)
			)
			layout.add_fall_zone_rect(pocket, &"internal")
		_:
			var floor_tag := &"open_block"
			if biome_id == &"infected_plains" and block_kind == &"forest":
				floor_tag = &"forest_tall_grass"
			layout.add_floor_rect(block_rect, floor_tag)

func _resolve_block_kind(
	biome_id: StringName,
	block_index: int,
	rng: RandomNumberGenerator
) -> StringName:
	var pattern: Array[StringName] = [
		&"building",
		&"open",
		&"forest",
		&"partial_void",
		&"ruins",
		&"open",
		&"large_obstacle",
		&"full_void"
	]
	match biome_id:
		&"toxic_wastes":
			pattern = [&"building", &"ruins", &"partial_void", &"open", &"large_obstacle", &"open", &"building", &"full_void"]
		&"burning_fields":
			pattern = [&"ruins", &"partial_void", &"building", &"full_void", &"large_obstacle", &"open", &"ruins", &"open"]
		&"frozen_outskirts":
			pattern = [&"building", &"open", &"large_obstacle", &"partial_void", &"forest", &"open", &"full_void", &"ruins"]
		&"drowned_marsh":
			pattern = [&"partial_void", &"forest", &"open", &"full_void", &"building", &"open", &"large_obstacle", &"forest"]
		_:
			pass
	var offset := rng.randi_range(0, pattern.size() - 1)
	return pattern[(block_index + offset) % pattern.size()]

func _collect_axis_bands(
	layout: BiomeEnvironmentLayout,
	vertical: bool
) -> Array[Vector2i]:
	var bands: Array[Vector2i] = []
	for rect in layout.road_rects:
		var is_vertical := (
			rect.size.y >= layout.zone_size.y - BORDER_THICKNESS * 2
			and rect.size.x <= ROAD_WIDTH + SECONDARY_ROAD_WIDTH
		)
		var is_horizontal := (
			rect.size.x >= layout.zone_size.x - BORDER_THICKNESS * 2
			and rect.size.y <= ROAD_WIDTH + SECONDARY_ROAD_WIDTH
		)
		if vertical and is_vertical:
			bands.append(Vector2i(rect.position.x, rect.position.x + rect.size.x))
		elif not vertical and is_horizontal:
			bands.append(Vector2i(rect.position.y, rect.position.y + rect.size.y))
	bands.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x)
	return _merge_bands(bands)

func _merge_bands(bands: Array[Vector2i]) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for band in bands:
		if result.is_empty() or band.x > result.back().y:
			result.append(band)
			continue
		var last: Vector2i = result.pop_back()
		result.append(Vector2i(last.x, maxi(last.y, band.y)))
	return result

func _intervals_between_bands(
	bands: Array[Vector2i],
	limit: int
) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var cursor := BORDER_THICKNESS
	for band in bands:
		var start := clampi(band.x, BORDER_THICKNESS, limit - BORDER_THICKNESS)
		var finish := clampi(band.y, BORDER_THICKNESS, limit - BORDER_THICKNESS)
		if start - cursor >= MIN_BLOCK_SIZE:
			result.append(Vector2i(cursor, start))
		cursor = maxi(cursor, finish)
	if limit - BORDER_THICKNESS - cursor >= MIN_BLOCK_SIZE:
		result.append(Vector2i(cursor, limit - BORDER_THICKNESS))
	return result

func _add_road_rect(
	layout: BiomeEnvironmentLayout,
	rect: Rect2i,
	tag: StringName
) -> void:
	rect = _clip_rect(rect, layout.zone_size)
	if rect.size.x <= 0 or rect.size.y <= 0:
		return
	layout.road_rects.append(rect)
	layout.road_rect_tags.append(tag)
	_add_route_metadata(layout, layout.rect_center_to_world(rect), maxf(float(maxi(rect.size.x, rect.size.y)) * layout.logical_tile_scale * 0.18, 28.0), tag)

func _add_diagonal_road(
	layout: BiomeEnvironmentLayout,
	start: Vector2i,
	end: Vector2i,
	width: int,
	tag: StringName
) -> void:
	var radius := maxi(width / 2, 1)
	var delta := end - start
	var steps := maxi(maxi(absi(delta.x), absi(delta.y)), 1)
	var touched: Dictionary = {}
	for step in range(steps + 1):
		var t := float(step) / float(steps)
		var center := Vector2i(
			roundi(lerpf(float(start.x), float(end.x), t)),
			roundi(lerpf(float(start.y), float(end.y), t))
		)
		for y in range(center.y - radius, center.y + radius + 1):
			for x in range(center.x - radius, center.x + radius + 1):
				var cell := Vector2i(x, y)
				if (
					cell.x < 0
					or cell.y < 0
					or cell.x >= layout.zone_size.x
					or cell.y >= layout.zone_size.y
				):
					continue
				var cell_delta := cell - center
				if Vector2(float(cell_delta.x), float(cell_delta.y)).length() > float(radius) + 0.35:
					continue
				layout.add_road_cell(cell, tag)
				touched[_route_cell_key(layout, cell)] = true
	if touched.is_empty():
		return
	var midpoint := Vector2(
		(float(start.x) + float(end.x)) * 0.5,
		(float(start.y) + float(end.y)) * 0.5
	)
	var world_midpoint := layout.logical_to_world(Vector2i(roundi(midpoint.x), roundi(midpoint.y)))
	var world_radius := maxf(
		Vector2(float(delta.x), float(delta.y)).length() * layout.logical_tile_scale * 0.10,
		34.0
	)
	_add_route_metadata(layout, world_midpoint, world_radius, tag)

func _add_route_metadata(
	layout: BiomeEnvironmentLayout,
	position: Vector2,
	radius: float,
	tag: StringName
) -> void:
	layout.terrain_patch_tags.append(tag)
	layout.terrain_patch_positions.append(position)
	layout.terrain_patch_radii.append(radius)

func _add_large_obstacles(
	layout: BiomeEnvironmentLayout,
	biome: BiomeDefinition,
	rng: RandomNumberGenerator
) -> void:
	for index in range(layout.block_rects.size()):
		var block_kind := (
			layout.block_kinds[index]
			if index < layout.block_kinds.size()
			else &"open"
		)
		if not [&"building", &"forest", &"ruins", &"large_obstacle"].has(block_kind):
			continue
		var block_rect := layout.block_rects[index]
		var size := Vector2i(
			clampi(rng.randi_range(18, 34), 12, maxi(block_rect.size.x - 10, 12)),
			clampi(rng.randi_range(14, 28), 10, maxi(block_rect.size.y - 10, 10))
		)
		var obstacle_rect := _centered_rect(block_rect, size)
		_add_obstacle_if_clear(
			layout,
			_block_obstacle_id(biome.biome_id, block_kind, index),
			obstacle_rect,
			&"rectangle",
			rng.randf_range(-0.18, 0.18)
		)

func _add_secondary_obstacles(
	layout: BiomeEnvironmentLayout,
	biome: BiomeDefinition,
	rng: RandomNumberGenerator
) -> void:
	var ids := _secondary_obstacle_ids(biome.biome_id)
	var placed := 0
	for index in range(layout.block_rects.size()):
		if placed >= 8:
			return
		var block_kind := (
			layout.block_kinds[index]
			if index < layout.block_kinds.size()
			else &"open"
		)
		if block_kind == &"full_void" or block_kind == &"partial_void":
			continue
		var block_rect := layout.block_rects[index]
		var horizontal := rng.randi_range(0, 1) == 0
		var size := (
			Vector2i(rng.randi_range(10, 18), 4)
			if horizontal
			else Vector2i(4, rng.randi_range(10, 18))
		)
		var offset := Vector2i(
			rng.randi_range(6, maxi(block_rect.size.x - size.x - 6, 6)),
			rng.randi_range(6, maxi(block_rect.size.y - size.y - 6, 6))
		)
		var rect := Rect2i(block_rect.position + offset, size)
		_add_obstacle_if_clear(
			layout,
			ids[(index + placed) % ids.size()],
			rect,
			&"rectangle",
			rng.randf_range(-0.3, 0.3)
		)
		placed += 1

func _add_block_props(
	layout: BiomeEnvironmentLayout,
	biome: BiomeDefinition,
	rng: RandomNumberGenerator
) -> void:
	# Enrich each non-void block with small thematic props so open areas read as
	# finished spaces, not empty rectangles. Props are placed only on clear
	# interior cells (never on routes, obstacles, fall zones or hazards), so they
	# add detail without breaking pathfinding.
	var prop_ids := _small_prop_ids(biome.biome_id if biome != null else &"")
	if prop_ids.is_empty():
		return
	var placed := 0
	for index in range(layout.block_rects.size()):
		if placed >= MAX_BLOCK_PROPS:
			return
		var kind := (
			layout.block_kinds[index]
			if index < layout.block_kinds.size()
			else &"open"
		)
		if kind == &"full_void":
			continue
		var block_rect := layout.block_rects[index]
		var attempts := _prop_attempts_for_kind(kind, block_rect)
		for _attempt in range(attempts):
			if placed >= MAX_BLOCK_PROPS:
				break
			var prop_id := prop_ids[rng.randi_range(0, prop_ids.size() - 1)]
			var size := _prop_size(prop_id, rng)
			var max_x := maxi(block_rect.size.x - size.x - PROP_BLOCK_MARGIN, PROP_BLOCK_MARGIN)
			var max_y := maxi(block_rect.size.y - size.y - PROP_BLOCK_MARGIN, PROP_BLOCK_MARGIN)
			var pos := block_rect.position + Vector2i(
				rng.randi_range(PROP_BLOCK_MARGIN, max_x),
				rng.randi_range(PROP_BLOCK_MARGIN, max_y)
			)
			if _add_prop_if_clear(layout, prop_id, Rect2i(pos, size), rng):
				placed += 1

func _prop_attempts_for_kind(kind: StringName, block_rect: Rect2i) -> int:
	var area_budget := int(float(block_rect.size.x * block_rect.size.y) / 1100.0)
	var density := 2
	match kind:
		&"forest":
			density = 6
		&"ruins":
			density = 5
		&"open":
			density = 3
		&"large_obstacle", &"building", &"partial_void":
			density = 2
		_:
			density = 2
	return clampi(area_budget, 1, density)

func _add_prop_if_clear(
	layout: BiomeEnvironmentLayout,
	prop_id: StringName,
	rect: Rect2i,
	rng: RandomNumberGenerator
) -> bool:
	var padded := _inflate_rect(rect, MIN_RECT_GAP)
	if _intersects_route(layout, padded):
		return false
	if _intersects_any(padded, layout.obstacle_rects):
		return false
	if _intersects_any(rect, layout.fall_zone_rects):
		return false
	if _intersects_any(rect, layout.hazard_rects):
		return false
	_add_obstacle(layout, prop_id, rect, &"rectangle", rng.randf_range(-0.4, 0.4))
	return true

func _prop_size(prop_id: StringName, rng: RandomNumberGenerator) -> Vector2i:
	match prop_id:
		&"fallen_log", &"marsh_log":
			return Vector2i(rng.randi_range(5, 8), rng.randi_range(3, 4))
		&"toxic_barrel":
			return Vector2i(rng.randi_range(3, 4), rng.randi_range(3, 4))
		_:
			return Vector2i(rng.randi_range(3, 5), rng.randi_range(3, 5))

func _small_prop_ids(biome_id: StringName) -> Array[StringName]:
	# Only contract-complete, biome-whitelisted ids so props always render with a
	# finished look (no placeholders). Bespoke bush/lamp art is a later R3 step.
	match biome_id:
		&"toxic_wastes":
			return [&"small_rock", &"toxic_barrel", &"industrial_fence"]
		&"burning_fields":
			return [&"small_rock", &"ash_barrier", &"broken_fence"]
		&"frozen_outskirts":
			return [&"ice_rock", &"fallen_log", &"small_rock"]
		&"drowned_marsh":
			return [&"marsh_log", &"small_rock", &"reed_wall"]
		_:
			return [&"small_rock", &"broken_fence", &"fallen_log"]

func _add_connected_border_walls(
	layout: BiomeEnvironmentLayout,
	cell: BiomeCell,
	biome: BiomeDefinition
) -> void:
	var border_obstacle_id := _border_obstacle_id(biome.biome_id if biome != null else &"")
	for side in BiomeCell.SIDES:
		var border_type := cell.get_border(side)
		if border_type == BiomeCell.BorderType.FALL:
			continue
		var axis_limit := _side_axis_limit(layout, side)
		var gaps := _passage_gaps_for_side(cell, side, axis_limit)
		# Wall the side, leaving a clean physical opening for every passage so
		# additional (extra-edge) connections are never sealed shut.
		var cursor := 0
		for gap in gaps:
			_add_border_segment(layout, side, cursor, gap.x, border_obstacle_id)
			cursor = maxi(cursor, gap.y)
		_add_border_segment(layout, side, cursor, axis_limit, border_obstacle_id)

func _side_axis_limit(layout: BiomeEnvironmentLayout, side: StringName) -> int:
	if side == &"west" or side == &"east":
		return layout.zone_size.y
	return layout.zone_size.x

func _passage_gaps_for_side(
	cell: BiomeCell,
	side: StringName,
	axis_limit: int
) -> Array[Vector2i]:
	var gaps: Array[Vector2i] = []
	if cell.get_border(side) != BiomeCell.BorderType.CONNECTED:
		return gaps
	for passage in cell.get_passages_for_side(side):
		var start := clampi(passage.position - passage.width / 2 - 2, 0, axis_limit)
		var finish := clampi(passage.position + passage.width / 2 + 2, 0, axis_limit)
		if finish > start:
			gaps.append(Vector2i(start, finish))
	gaps.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x)
	return gaps

func _add_border_segment(
	layout: BiomeEnvironmentLayout,
	side: StringName,
	start: int,
	finish: int,
	obstacle_id: StringName
) -> void:
	# Tile the [start, finish) span into contiguous wall-tile segments so the
	# entire perimeter is a continuous isometric wall, recording the explicit
	# wall contract on the layout for validation and rendering.
	var cursor := start
	while cursor < finish:
		var remaining := finish - cursor
		if remaining < WALL_MIN_SEGMENT:
			break
		var segment_length := mini(WALL_SEGMENT_LENGTH, remaining)
		# Absorb a tiny trailing remainder into the current segment so we never
		# leave a sub-minimum sliver behind.
		if remaining - segment_length > 0 and remaining - segment_length < WALL_MIN_SEGMENT:
			segment_length = remaining
		var rect := _wall_segment_rect(layout, side, cursor, segment_length)
		_add_obstacle(layout, obstacle_id, rect, &"rectangle", 0.0)
		layout.add_wall_segment(rect, side)
		cursor += segment_length

func _wall_segment_rect(
	layout: BiomeEnvironmentLayout,
	side: StringName,
	axis_start: int,
	axis_length: int
) -> Rect2i:
	var zone_size := layout.zone_size
	match side:
		&"north":
			return Rect2i(Vector2i(axis_start, 0), Vector2i(axis_length, BORDER_THICKNESS))
		&"south":
			return Rect2i(
				Vector2i(axis_start, zone_size.y - BORDER_THICKNESS),
				Vector2i(axis_length, BORDER_THICKNESS)
			)
		&"west":
			return Rect2i(Vector2i(0, axis_start), Vector2i(BORDER_THICKNESS, axis_length))
		_:
			return Rect2i(
				Vector2i(zone_size.x - BORDER_THICKNESS, axis_start),
				Vector2i(BORDER_THICKNESS, axis_length)
			)

func _add_obstacle_if_clear(
	layout: BiomeEnvironmentLayout,
	obstacle_id: StringName,
	rect: Rect2i,
	shape_id: StringName,
	rotation_radians: float
) -> void:
	if _intersects_route(layout, _inflate_rect(rect, MIN_RECT_GAP)):
		return
	if _intersects_any(_inflate_rect(rect, MIN_RECT_GAP), layout.obstacle_rects):
		return
	_add_obstacle(layout, obstacle_id, rect, shape_id, rotation_radians)

func _add_crates(
	layout: BiomeEnvironmentLayout,
	biome: BiomeDefinition
) -> void:
	var crate_ids := _crate_ids(biome.biome_id)
	var center := layout.zone_size / 2
	var cells: Array[Vector2i] = [
		center + Vector2i(-42, 0),
		center + Vector2i(42, 0),
		center + Vector2i(0, -42),
		center + Vector2i(0, 42)
	]
	for index in range(cells.size()):
		_add_crate(layout, crate_ids[index % crate_ids.size()], cells[index])

func _add_theme_hazards(
	layout: BiomeEnvironmentLayout,
	biome: BiomeDefinition
) -> void:
	match biome.biome_id:
		&"toxic_wastes":
			_add_hazard_at_ratio(layout, &"toxic_puddle", Vector2(0.42, 0.22), Vector2i(26, 14))
			_add_hazard_at_ratio(layout, &"gas_cloud", Vector2(0.74, 0.78), Vector2i(30, 18))
		&"burning_fields":
			_add_hazard_at_ratio(layout, &"lava_crack", Vector2(0.36, 0.76), Vector2i(34, 10))
			_add_hazard_at_ratio(layout, &"fire_zone", Vector2(0.72, 0.24), Vector2i(20, 20))
		&"frozen_outskirts":
			_add_hazard_at_ratio(layout, &"slippery_ice", Vector2(0.34, 0.74), Vector2i(34, 20))
			_add_hazard_at_ratio(layout, &"deep_snow_slow", Vector2(0.74, 0.22), Vector2i(28, 24))
		&"drowned_marsh":
			_add_hazard_at_ratio(layout, &"deep_water", Vector2(0.30, 0.74), Vector2i(38, 22))
			_add_hazard_at_ratio(layout, &"mud_slow", Vector2(0.74, 0.26), Vector2i(28, 22))
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
	if (
		layout.get_terrain_class_at_cell(cell)
		!= BiomeEnvironmentLayout.TERRAIN_WALKABLE
	):
		return
	layout.crate_cells.append(cell)
	layout.crate_ids.append(crate_id)
	layout.crate_positions.append(layout.logical_to_world(cell))

func _add_hazard(
	layout: BiomeEnvironmentLayout,
	hazard_id: StringName,
	rect: Rect2i
) -> void:
	rect = _clip_rect(rect, layout.zone_size)
	if rect.size.x <= 0 or rect.size.y <= 0:
		return
	layout.hazard_rects.append(rect)
	layout.hazard_ids.append(hazard_id)
	layout.hazard_positions.append(layout.rect_center_to_world(rect))
	layout.hazard_sizes.append(layout.rect_size_to_world(rect))
	layout.hazard_rotations.append(0.0)
	layout.hazard_sides.append(&"")

func _add_hazard_at_ratio(
	layout: BiomeEnvironmentLayout,
	hazard_id: StringName,
	ratio: Vector2,
	size: Vector2i
) -> void:
	var center := Vector2i(
		roundi(float(layout.zone_size.x) * ratio.x),
		roundi(float(layout.zone_size.y) * ratio.y)
	)
	_add_hazard(
		layout,
		hazard_id,
		Rect2i(center - size / 2, size)
	)

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

func _block_obstacle_id(
	biome_id: StringName,
	block_kind: StringName,
	index: int
) -> StringName:
	match block_kind:
		&"forest":
			match biome_id:
				&"drowned_marsh":
					return &"dead_tree"
				&"frozen_outskirts":
					return &"ice_block"
				&"burning_fields":
					return &"burned_car"
				&"toxic_wastes":
					return &"pipe_stack"
				_:
					return &"fallen_log" if index % 2 == 0 else &"small_rock"
		&"ruins":
			match biome_id:
				&"toxic_wastes":
					return &"lab_wall"
				&"burning_fields":
					return &"charred_wall"
				&"frozen_outskirts":
					return &"snow_wall"
				&"drowned_marsh":
					return &"reed_wall"
				_:
					return &"wood_barrier"
		&"large_obstacle":
			var ids := _secondary_obstacle_ids(biome_id)
			return ids[index % ids.size()]
		_:
			return _large_obstacle_id(biome_id)

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

func _border_obstacle_id(biome_id: StringName) -> StringName:
	match biome_id:
		&"toxic_wastes":
			return &"toxic_boundary_wall"
		&"burning_fields":
			return &"lava_boundary"
		&"frozen_outskirts":
			return &"ice_boundary"
		&"drowned_marsh":
			return &"deep_water_boundary"
		_:
			return &"boundary_fence"

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

func _inflate_rect(rect: Rect2i, amount: int) -> Rect2i:
	return Rect2i(
		rect.position - Vector2i(amount, amount),
		rect.size + Vector2i(amount * 2, amount * 2)
	)

func _inset_rect(rect: Rect2i, amount: int) -> Rect2i:
	var inset := mini(amount, mini(rect.size.x, rect.size.y) / 2)
	return Rect2i(
		rect.position + Vector2i(inset, inset),
		rect.size - Vector2i(inset * 2, inset * 2)
	)

func _centered_rect(container: Rect2i, size: Vector2i) -> Rect2i:
	var clamped_size := Vector2i(
		mini(size.x, container.size.x),
		mini(size.y, container.size.y)
	)
	return Rect2i(
		container.position + (container.size - clamped_size) / 2,
		clamped_size
	)

func _passage_inner_anchor(
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

func _intersects_route(layout: BiomeEnvironmentLayout, rect: Rect2i) -> bool:
	if _intersects_any(rect, layout.road_rects):
		return true
	if _intersects_any(rect, layout.passage_connector_rects):
		return true
	return _rect_overlaps_road_cells(layout, rect)

func _rect_overlaps_road_cells(
	layout: BiomeEnvironmentLayout,
	rect: Rect2i
) -> bool:
	var clipped := _clip_rect(rect, layout.zone_size)
	for y in range(clipped.position.y, clipped.position.y + clipped.size.y):
		for x in range(clipped.position.x, clipped.position.x + clipped.size.x):
			if layout.has_road_cell(Vector2i(x, y)):
				return true
	return false

func _clip_rect(rect: Rect2i, zone_size: Vector2i) -> Rect2i:
	var x := clampi(rect.position.x, 0, zone_size.x)
	var y := clampi(rect.position.y, 0, zone_size.y)
	var end_x := clampi(rect.position.x + rect.size.x, 0, zone_size.x)
	var end_y := clampi(rect.position.y + rect.size.y, 0, zone_size.y)
	return Rect2i(Vector2i(x, y), Vector2i(maxi(end_x - x, 0), maxi(end_y - y, 0)))

func _route_cell_key(layout: BiomeEnvironmentLayout, cell: Vector2i) -> int:
	return cell.y * layout.zone_size.x + cell.x
