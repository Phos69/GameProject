extends SceneTree

var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var biome_manager := BiomeManager.new()
	root.add_child(biome_manager)
	await process_frame
	biome_manager.start_run({
		"world_seed": 616161,
		"biome_map_width": 5,
		"biome_map_height": 5,
		"extra_edge_chance": 0.35
	})
	var cells := biome_manager.get_generated_biome_map()
	var cells_by_grid := {}
	for cell in cells:
		cells_by_grid[cell.grid] = cell
	for cell in cells:
		for side in BiomeCell.SIDES:
			var adjacent_exists := cells_by_grid.has(cell.grid + BorderGenerator.get_side_offset(side))
			var border_type := cell.get_border(side)
			var layout := cell.generated_layout
			if not adjacent_exists:
				_expect(border_type == BiomeCell.BorderType.FALL, "%s %s without region is fall boundary" % [String(cell.id), String(side)])
				_expect(_has_fall_rect_for_side(layout, side), "%s %s has fall visual/collision rect" % [String(cell.id), String(side)])
			elif border_type == BiomeCell.BorderType.CONNECTED:
				_expect(not _has_fall_rect_for_side(layout, side), "%s connected %s has no fall rect" % [String(cell.id), String(side)])
				_expect(not cell.get_passages_for_side(side).is_empty(), "%s connected %s has physical passage" % [String(cell.id), String(side)])
			else:
				_expect(border_type == BiomeCell.BorderType.BLOCKED, "%s adjacent non-edge %s is blocked" % [String(cell.id), String(side)])
				_expect(not _has_fall_rect_for_side(layout, side), "%s blocked %s is not fall" % [String(cell.id), String(side)])
	var graph := biome_manager.get_world_graph()
	_expect(graph != null and graph.validate_physical_passages().get("is_valid", false), "fall boundary logic keeps physical passages coherent")

	biome_manager.queue_free()
	_finish()

func _has_fall_rect_for_side(layout: BiomeEnvironmentLayout, side: StringName) -> bool:
	if layout == null:
		return false
	for rect in layout.fall_zone_rects:
		match side:
			&"north":
				if rect.position.y <= 0 and rect.size.y <= 8:
					return true
			&"south":
				if (
					rect.position.y + rect.size.y >= layout.zone_size.y
					and rect.size.y <= 8
				):
					return true
			&"west":
				if rect.position.x <= 0 and rect.size.x <= 8:
					return true
			_:
				if (
					rect.position.x + rect.size.x >= layout.zone_size.x
					and rect.size.x <= 8
				):
					return true
	return false

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("FALL_BOUNDARY_VISUAL_LOGIC_SMOKE_TEST: PASS")
		quit(0)
		return
	print("FALL_BOUNDARY_VISUAL_LOGIC_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
