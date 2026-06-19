extends SceneTree

# Milestone R2 - perimeter walls are tiled into a contiguous run of isometric
# wall segments around the whole chunk (not a single centred sprite), passages
# cut clean gaps, and fall sides expose the void instead of a wall.

var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var biome_manager := BiomeManager.new()
	root.add_child(biome_manager)
	await process_frame

	biome_manager.start_run({
		"world_seed": 906500,
		"biome_map_width": 3,
		"biome_map_height": 3,
		"preserve_biome_sequence": false,
		"extra_edge_chance": 0.5
	})
	var cells := biome_manager.get_generated_biome_map()
	_expect(cells.size() == 9, "perimeter wall smoke generates a 3x3 biome map")

	for cell in _first_cell_per_biome(cells):
		_validate_cell_walls(cell)

	_validate_void_world_edge_gap()
	_validate_wall_obstacle_render()

	biome_manager.queue_free()
	_finish()

func _validate_cell_walls(cell: BiomeCell) -> void:
	var layout := cell.generated_layout
	_expect(layout != null, "%s has generated layout" % String(cell.id))
	if layout == null:
		return
	_expect(
		not layout.wall_segment_rects.is_empty(),
		"%s records explicit perimeter wall segments" % String(cell.id)
	)
	_expect(
		layout.wall_height_cells >= 4,
		"%s perimeter walls carry a tall vertical contract" % String(cell.id)
	)

	for side in BiomeCell.SIDES:
		var segments := layout.get_wall_segments_for_side(side)
		var border_type := cell.get_border(side)
		var vertical := side == &"west" or side == &"east"
		var axis_limit := layout.zone_size.y if vertical else layout.zone_size.x

		if border_type == BiomeCell.BorderType.FALL:
			_expect(
				segments.is_empty(),
				"%s %s fall side exposes void, no wall" % [String(cell.id), String(side)]
			)
			continue

		_expect(
			not segments.is_empty(),
			"%s %s keeps wall segments outside its openings" % [String(cell.id), String(side)]
		)
		var covered := _covered_axis_length(segments, vertical)
		var expected_span := _expected_wall_axis_span(cell, side, axis_limit)
		_expect(
			_segments_stay_inside_axis_span(segments, vertical, expected_span),
			"%s %s wall does not render over adjacent fall corners"
			% [String(cell.id), String(side)]
		)
		var passages := cell.get_passages_for_side(side)
		var edge_void_rects := _fall_rects_touching_side(layout, side)
		for void_rect in edge_void_rects:
			_expect(
				not _any_intersects(segments, void_rect),
				"%s %s void opening is free of perimeter wall rendering" % [
					String(cell.id), String(side)
				]
			)
		if passages.is_empty() and edge_void_rects.is_empty():
			_expect(
				covered >= expected_span.y - expected_span.x - 1,
				"%s %s wall spans the full side (%d/%d)" % [
					String(cell.id),
					String(side),
					covered,
					expected_span.y - expected_span.x
				]
			)
		elif passages.is_empty():
			_expect(
				covered < expected_span.y - expected_span.x,
				"%s %s wall stops where void reaches the world edge" % [
					String(cell.id), String(side)
				]
			)
		else:
			_expect(
				covered > 0 and covered < axis_limit,
				"%s %s wall leaves a physical passage gap" % [String(cell.id), String(side)]
			)
			for passage in passages:
				var passage_rect: Rect2i = passage.get_local_rect(layout.zone_size)
				_expect(
					not _any_intersects(segments, passage_rect),
					"%s %s passage opening is free of wall collisions" % [
						String(cell.id), String(side)
					]
				)

func _validate_void_world_edge_gap() -> void:
	var layout := BiomeEnvironmentLayout.new()
	layout.zone_size = Vector2i(80, 80)
	var cell := BiomeCell.new()
	cell.configure(&"void_edge_gap", &"infected_plains", Vector2i.ZERO, layout.zone_size, 17)
	for side in BiomeCell.SIDES:
		cell.set_border(side, BiomeCell.BorderType.BLOCKED)
	var generator := ObstacleLayoutGenerator.new()
	generator._apply_block_surface(
		layout,
		Rect2i(Vector2i(18, ObstacleLayoutGenerator.BORDER_THICKNESS), Vector2i(30, 24)),
		&"full_void",
		&"infected_plains"
	)
	var void_rect: Rect2i = layout.fall_zone_rects.front()
	_expect(void_rect.position.y == 0, "full void is extended through the outer border")
	generator._add_connected_border_walls(layout, cell, null)
	layout.rebuild_terrain_classification(cell)
	_expect(
		not _any_intersects(layout.get_wall_segments_for_side(&"north"), void_rect),
		"perimeter wall is omitted where full void reaches the north world edge"
	)
	_expect(
		layout.get_terrain_class_at_cell(Vector2i(24, 0), cell)
			== BiomeEnvironmentLayout.TERRAIN_FALL_ZONE,
		"world-edge cells inside the opening remain pure void"
	)

func _fall_rects_touching_side(
	layout: BiomeEnvironmentLayout,
	side: StringName
) -> Array[Rect2i]:
	var result: Array[Rect2i] = []
	for rect in layout.fall_zone_rects:
		var touches := false
		match side:
			&"north":
				touches = rect.position.y <= 0
			&"south":
				touches = rect.end.y >= layout.zone_size.y
			&"west":
				touches = rect.position.x <= 0
			_:
				touches = rect.end.x >= layout.zone_size.x
		if touches:
			result.append(rect)
	return result

func _validate_wall_obstacle_render() -> void:
	var factory_script := load(
		"res://game/modes/zombie/isometric_environment_object_factory.gd"
	)
	var factory = factory_script.new()
	var wall = factory.create_obstacle(
		&"boundary_fence",
		Vector2(96.0, 32.0),
		&"rectangle",
		0.0,
		Color(0.4, 0.4, 0.4, 1.0),
		Color(0.8, 0.7, 0.4, 1.0)
	)
	_expect(wall != null, "factory builds a perimeter wall obstacle")
	if wall == null:
		return
	_expect(wall.is_perimeter_wall(), "border obstacle is flagged as a perimeter wall")
	_expect(
		wall.get_wall_height() > 32.0,
		"perimeter wall renders taller than its footprint thickness"
	)
	if wall.has_method("uses_procedural_fallback"):
		_expect(
			bool(wall.call("uses_procedural_fallback")),
			"perimeter wall uses the tileable procedural iso volume"
		)
	wall.queue_free()

func _covered_axis_length(segments: Array[Rect2i], vertical: bool) -> int:
	var intervals: Array[Vector2i] = []
	for rect in segments:
		if vertical:
			intervals.append(Vector2i(rect.position.y, rect.position.y + rect.size.y))
		else:
			intervals.append(Vector2i(rect.position.x, rect.position.x + rect.size.x))
	intervals.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x)
	var covered := 0
	var cursor := -1
	for interval in intervals:
		var start := maxi(interval.x, cursor)
		if interval.y > start:
			covered += interval.y - start
			cursor = interval.y
		elif interval.y > cursor:
			cursor = interval.y
	return covered

func _expected_wall_axis_span(
	cell: BiomeCell,
	side: StringName,
	axis_limit: int
) -> Vector2i:
	var vertical := side == &"west" or side == &"east"
	var start_side := &"north" if vertical else &"west"
	var end_side := &"south" if vertical else &"east"
	var start := 0
	var finish := axis_limit
	if cell.get_border(start_side) == BiomeCell.BorderType.FALL:
		start += FallBoundaryGenerator.FALL_THICKNESS
	if cell.get_border(end_side) == BiomeCell.BorderType.FALL:
		finish -= FallBoundaryGenerator.FALL_THICKNESS
	return Vector2i(start, finish)

func _segments_stay_inside_axis_span(
	segments: Array[Rect2i],
	vertical: bool,
	span: Vector2i
) -> bool:
	for rect in segments:
		var start := rect.position.y if vertical else rect.position.x
		var finish := start + (rect.size.y if vertical else rect.size.x)
		if start < span.x or finish > span.y:
			return false
	return true

func _any_intersects(segments: Array[Rect2i], other: Rect2i) -> bool:
	for rect in segments:
		if rect.intersects(other):
			return true
	return false

func _first_cell_per_biome(cells: Array[BiomeCell]) -> Array[BiomeCell]:
	var by_biome: Dictionary = {}
	var result: Array[BiomeCell] = []
	for cell in cells:
		if by_biome.has(cell.biome_id):
			continue
		by_biome[cell.biome_id] = true
		result.append(cell)
	return result

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("ISOMETRIC_PERIMETER_WALL_SMOKE_TEST: PASS")
		quit(0)
		return
	print("ISOMETRIC_PERIMETER_WALL_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
