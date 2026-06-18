extends SceneTree

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
	_expect(cells.size() == 9, "rewrite smoke generates a compact 3x3 biome map")
	var sample_cells := _first_cell_per_biome(cells)
	_expect(sample_cells.size() >= 5, "rewrite smoke samples every existing biome")

	for cell in sample_cells:
		_validate_rewritten_cell(cell)

	biome_manager.queue_free()
	_finish()

func _validate_rewritten_cell(cell: BiomeCell) -> void:
	var layout := cell.generated_layout
	_expect(layout != null, "%s has generated layout" % String(cell.id))
	if layout == null:
		return
	var expected_total := layout.zone_size.x * layout.zone_size.y
	_expect(
		layout.zone_size == BiomeEnvironmentLayout.DEFAULT_ZONE_SIZE,
		"%s uses the 500x500 rewrite chunk" % String(cell.id)
	)
	_expect(
		layout.player_spawn_cell == layout.zone_size / 2,
		"%s player spawn is centered on the carved road network" % String(cell.id)
	)
	_expect(
		layout.get_terrain_class_at_cell(layout.player_spawn_cell, cell)
		== BiomeEnvironmentLayout.TERRAIN_WALKABLE,
		"%s player spawn is walkable" % String(cell.id)
	)
	_expect(not layout.floor_rects.is_empty(), "%s has carved walkable floor blocks" % String(cell.id))
	_expect(not layout.block_rects.is_empty(), "%s has procedural internal blocks" % String(cell.id))
	_expect(layout.block_kinds.has(&"full_void") or layout.block_kinds.has(&"partial_void"), "%s keeps void/fall blocks inside the chunk" % String(cell.id))
	_expect(
		ObstacleLayoutGenerator.ROAD_WIDTH == 40,
		"large road width is 40 cells"
	)
	_expect(
		ObstacleLayoutGenerator.SECONDARY_ROAD_WIDTH == 20,
		"medium path width is 20 cells"
	)
	_expect(
		BiomePassageGenerator.PASSAGE_WIDTH == 40,
		"physical passage width is 40 cells"
	)
	_expect(
		_has_axis_road(
			layout,
			&"main_road",
			ObstacleLayoutGenerator.ROAD_WIDTH,
			true
		),
		"%s has a vertical %d-cell main road"
		% [String(cell.id), ObstacleLayoutGenerator.ROAD_WIDTH]
	)
	_expect(
		_has_axis_road(
			layout,
			&"main_road",
			ObstacleLayoutGenerator.ROAD_WIDTH,
			false
		),
		"%s has a horizontal %d-cell main road"
		% [String(cell.id), ObstacleLayoutGenerator.ROAD_WIDTH]
	)
	var path_tag := _expected_path_tag(cell.biome_id)
	_expect(
		_has_axis_road(
			layout,
			path_tag,
			ObstacleLayoutGenerator.SECONDARY_ROAD_WIDTH,
			true
		),
		"%s has a vertical %d-cell biome path"
		% [String(cell.id), ObstacleLayoutGenerator.SECONDARY_ROAD_WIDTH]
	)
	_expect(
		_has_axis_road(
			layout,
			path_tag,
			ObstacleLayoutGenerator.SECONDARY_ROAD_WIDTH,
			false
		),
		"%s has a horizontal %d-cell biome path"
		% [String(cell.id), ObstacleLayoutGenerator.SECONDARY_ROAD_WIDTH]
	)
	for passage in cell.passages:
		_expect(
			passage.width == BiomePassageGenerator.PASSAGE_WIDTH,
			"%s passage uses the %d-cell physical opening"
			% [String(cell.id), BiomePassageGenerator.PASSAGE_WIDTH]
		)
		var probe := _passage_probe_cell(passage, layout.zone_size)
		_expect(
			layout.get_terrain_class_at_cell(probe, cell)
			== BiomeEnvironmentLayout.TERRAIN_WALKABLE,
			"%s passage %s is walkable" % [String(cell.id), String(passage.side)]
		)
	for crate_cell in layout.crate_cells:
		_expect(
			layout.get_terrain_class_at_cell(crate_cell, cell)
			== BiomeEnvironmentLayout.TERRAIN_WALKABLE,
			"%s crate is placed on walkable terrain" % String(cell.id)
		)
	_expect(not layout.fall_zone_rects.is_empty(), "%s has fall/void damage zones" % String(cell.id))
	_expect(not layout.obstacle_rects.is_empty(), "%s has blocking isometric objects" % String(cell.id))
	var report := layout.get_classification_report()
	_expect(bool(report.get("is_complete", false)), "%s classifies the full chunk" % String(cell.id))
	_expect(int(report.get("total", 0)) == expected_total, "%s classification covers 250000 cells" % String(cell.id))
	var counts := report.get("counts", {}) as Dictionary
	_expect(int(counts.get(BiomeEnvironmentLayout.TERRAIN_WALKABLE, 0)) > 0, "%s has walkable carved cells" % String(cell.id))
	_expect(int(counts.get(BiomeEnvironmentLayout.TERRAIN_FALL_ZONE, 0)) > 0, "%s has fall-zone void cells" % String(cell.id))
	_expect(int(counts.get(BiomeEnvironmentLayout.TERRAIN_OBSTACLE, 0)) > 0, "%s has obstacle cells" % String(cell.id))
	_expect(
		bool(layout.validation_report.get("is_valid", false)),
		"%s passes road connectivity and placement validation" % String(cell.id)
	)

func _has_axis_road(
	layout: BiomeEnvironmentLayout,
	tag: StringName,
	width: int,
	vertical: bool
) -> bool:
	for index in range(layout.road_rects.size()):
		if index >= layout.road_rect_tags.size() or layout.road_rect_tags[index] != tag:
			continue
		var rect := layout.road_rects[index]
		if vertical and rect.size.x == width and rect.size.y >= layout.zone_size.y - 8:
			return true
		if not vertical and rect.size.y == width and rect.size.x >= layout.zone_size.x - 8:
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

func _expected_path_tag(biome_id: StringName) -> StringName:
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

func _passage_probe_cell(passage: BiomePassage, zone_size: Vector2i) -> Vector2i:
	match passage.side:
		&"north":
			return Vector2i(passage.position, 3)
		&"south":
			return Vector2i(passage.position, zone_size.y - 4)
		&"west":
			return Vector2i(3, passage.position)
		_:
			return Vector2i(zone_size.x - 4, passage.position)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("ISOMETRIC_BIOME_GENERATION_REWRITE_SMOKE_TEST: PASS")
		quit(0)
		return
	print("ISOMETRIC_BIOME_GENERATION_REWRITE_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
