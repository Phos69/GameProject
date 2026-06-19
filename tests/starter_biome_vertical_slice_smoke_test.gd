extends SceneTree

var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var generator := BiomeTerrainGenerator.new()
	root.add_child(generator)
	var biome := load("res://game/modes/zombie/biomes/infected_plains.tres") as BiomeDefinition
	_expect(biome != null, "infected plains biome loads")
	if biome == null:
		_finish()
		return

	var cell := _make_starter_cell(771337)
	var layout := generator.generate_layout_for_cell(cell, biome)
	_validate_starter_layout(cell, layout)

	var repeated_cell := _make_starter_cell(771337)
	var repeated_layout := generator.generate_layout_for_cell(repeated_cell, biome)
	_expect(
		_starter_signature(layout) == _starter_signature(repeated_layout),
		"same seed regenerates identical starter vertical slice"
	)
	generator.queue_free()
	_finish()

func _make_starter_cell(seed: int) -> BiomeCell:
	var cell := BiomeCell.new()
	cell.configure(
		&"starter_vertical_slice",
		&"infected_plains",
		Vector2i.ZERO,
		BiomeEnvironmentLayout.DEFAULT_ZONE_SIZE,
		seed
	)
	return cell

func _validate_starter_layout(
	cell: BiomeCell,
	layout: BiomeEnvironmentLayout
) -> void:
	_expect(layout != null, "starter layout is generated")
	if layout == null:
		return
	_expect(bool(layout.validation_report.get("is_valid", false)), "starter layout validates")
	var main_road_report := layout.validation_report.get("main_road_report", {}) as Dictionary
	_expect(bool(main_road_report.get("has_horizontal", false)), "starter has horizontal edge-to-edge main road")
	_expect(bool(main_road_report.get("has_vertical", false)), "starter has vertical edge-to-edge main road")
	_expect(bool(main_road_report.get("passes_center", false)), "main road crosses centered spawn")
	_expect(_has_axis_road(layout, &"broken_street", ObstacleLayoutGenerator.SECONDARY_ROAD_WIDTH, true), "starter has vertical secondary path")
	_expect(_has_axis_road(layout, &"broken_street", ObstacleLayoutGenerator.SECONDARY_ROAD_WIDTH, false), "starter has horizontal secondary path")

	var summary := layout.generation_summary
	_expect(int(summary.get("seed", 0)) == cell.seed, "starter summary records generation seed")
	_expect(int(summary.get("main_road_count", 0)) >= 2, "starter summary counts main roads")
	_expect(int(summary.get("path_count", 0)) >= 2, "starter summary counts paths")
	_expect(int(summary.get("house_count", 0)) >= 1, "starter summary counts at least one house")
	_expect(int(summary.get("dense_vegetation_count", 0)) >= 1, "starter summary counts dense vegetation")
	_expect(int(summary.get("river_count", 0)) == 1, "starter summary records one river")
	_expect(int(summary.get("bridge_count", 0)) >= 1, "starter summary counts bridge crossings")

	_expect(_has_any_obstacle(layout, [&"ruined_house", &"abandoned_house"]), "starter has an isometric house obstacle")
	_expect(_has_any_obstacle(layout, [&"dense_vegetation"]), "starter has impassable dense vegetation")
	_expect(_has_any_obstacle(layout, [&"abandoned_car"]), "starter has road-side abandoned car detail")
	_expect(_dense_vegetation_blocks(layout, cell), "dense vegetation is classified as obstacle terrain")

	_expect(layout.water_rects.size() >= 1, "starter river emits deep water segments")
	_expect(layout.bridge_rects.size() >= 1, "starter river emits bridge rects")
	_expect(
		(layout.validation_report.get("water_crossing_errors", PackedStringArray()) as PackedStringArray).is_empty(),
		"starter water crossings are bridged"
	)
	_expect(_bridge_over_water_is_walkable(layout, cell), "bridge over river is walkable")
	_expect(_river_water_blocks_without_bridge(layout, cell), "non-bridge river water remains hazardous")

	var manifest := IsometricEnvironmentManifest.reload_shared()
	for obstacle_id in [&"ruined_house", &"abandoned_house", &"dense_vegetation", &"abandoned_car"]:
		_expect(manifest.has_object(obstacle_id), "%s has manifest object contract" % String(obstacle_id))
		_expect(manifest.object_has_dedicated_draw(obstacle_id), "%s has dedicated draw contract" % String(obstacle_id))
		_expect(manifest.get_object_draw_mode(obstacle_id) != &"generic_barrier", "%s avoids generic fallback" % String(obstacle_id))

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
		if vertical and rect.size.x == width and rect.size.y >= layout.zone_size.y - ObstacleLayoutGenerator.BORDER_THICKNESS * 2:
			return true
		if not vertical and rect.size.y == width and rect.size.x >= layout.zone_size.x - ObstacleLayoutGenerator.BORDER_THICKNESS * 2:
			return true
	return false

func _has_any_obstacle(
	layout: BiomeEnvironmentLayout,
	obstacle_ids: Array[StringName]
) -> bool:
	for obstacle_id in obstacle_ids:
		if layout.obstacle_ids.has(obstacle_id):
			return true
	return false

func _dense_vegetation_blocks(
	layout: BiomeEnvironmentLayout,
	cell: BiomeCell
) -> bool:
	for index in range(layout.obstacle_ids.size()):
		if layout.obstacle_ids[index] != &"dense_vegetation":
			continue
		var rect := layout.obstacle_rects[index]
		var probe := rect.position + rect.size / 2
		return (
			layout.get_terrain_class_at_cell(probe, cell)
			== BiomeEnvironmentLayout.TERRAIN_OBSTACLE
		)
	return false

func _bridge_over_water_is_walkable(
	layout: BiomeEnvironmentLayout,
	cell: BiomeCell
) -> bool:
	for bridge_rect in layout.bridge_rects:
		for water_rect in layout.water_rects:
			if not bridge_rect.intersects(water_rect):
				continue
			var start := Vector2i(
				maxi(bridge_rect.position.x, water_rect.position.x),
				maxi(bridge_rect.position.y, water_rect.position.y)
			)
			var finish := Vector2i(
				mini(bridge_rect.end.x, water_rect.end.x),
				mini(bridge_rect.end.y, water_rect.end.y)
			)
			if finish.x <= start.x or finish.y <= start.y:
				continue
			var probe := start + (finish - start) / 2
			return (
				layout.is_bridge_cell(probe)
				and layout.get_terrain_class_at_cell(probe, cell)
				== BiomeEnvironmentLayout.TERRAIN_WALKABLE
			)
	return false

func _river_water_blocks_without_bridge(
	layout: BiomeEnvironmentLayout,
	cell: BiomeCell
) -> bool:
	for water_rect in layout.water_rects:
		for y in range(water_rect.position.y, water_rect.end.y, 3):
			for x in range(water_rect.position.x, water_rect.end.x, 3):
				var probe := Vector2i(x, y)
				if layout.is_bridge_cell(probe):
					continue
				var terrain_class := layout.get_terrain_class_at_cell(probe, cell)
				if terrain_class == BiomeEnvironmentLayout.TERRAIN_HAZARD:
					return true
	return false

func _starter_signature(layout: BiomeEnvironmentLayout) -> String:
	if layout == null:
		return ""
	return "%s|%s|%s|%s|%s|%s|%s" % [
		str(layout.generation_summary),
		str(layout.road_rects),
		str(layout.bridge_rects),
		str(layout.water_rects),
		str(layout.obstacle_ids),
		str(layout.obstacle_rects),
		str(layout.block_kinds)
	]

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("STARTER_BIOME_VERTICAL_SLICE_SMOKE_TEST: PASS")
		quit(0)
		return
	print("STARTER_BIOME_VERTICAL_SLICE_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
