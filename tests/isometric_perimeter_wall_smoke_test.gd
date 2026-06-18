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
			segments.size() >= 2,
			"%s %s wall is tiled into multiple segments" % [String(cell.id), String(side)]
		)
		var covered := _covered_axis_length(segments, vertical)
		var passages := cell.get_passages_for_side(side)
		if passages.is_empty():
			_expect(
				covered >= axis_limit - 1,
				"%s %s wall spans the full side (%d/%d)" % [
					String(cell.id), String(side), covered, axis_limit
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
