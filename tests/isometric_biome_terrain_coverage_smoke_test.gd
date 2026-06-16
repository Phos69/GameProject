extends SceneTree

var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var biome_manager := BiomeManager.new()
	root.add_child(biome_manager)
	await process_frame
	biome_manager.start_run({
		"world_seed": 515151,
		"biome_map_width": 5,
		"biome_map_height": 5,
		"preserve_biome_sequence": false
	})
	var cells := biome_manager.get_generated_biome_map()
	_expect(cells.size() == 25, "megamap generates 25 regions")
	for cell in cells:
		var layout := cell.generated_layout
		_expect(layout != null, "%s has layout" % String(cell.id))
		if layout == null:
			continue
		var report := layout.get_classification_report()
		_expect(bool(report.get("is_complete", false)), "%s classifies every tile" % String(cell.id))
		_expect(int(report.get("total", 0)) == 40000, "%s classification covers 200x200" % String(cell.id))
		var counts := report.get("counts", {}) as Dictionary
		var sum := 0
		for value in counts.values():
			sum += int(value)
		_expect(sum == 40000, "%s classification counts sum to 40000" % String(cell.id))
		_expect(int(counts.get(BiomeEnvironmentLayout.TERRAIN_WALKABLE, 0)) > 0, "%s has walkable terrain" % String(cell.id))
		for passage in cell.passages:
			var probe := _passage_probe_cell(passage, layout.zone_size)
			_expect(
				layout.get_terrain_class_at_cell(probe, cell) == BiomeEnvironmentLayout.TERRAIN_WALKABLE,
				"%s passage %s is classified walkable" % [String(cell.id), String(passage.side)]
			)

	biome_manager.queue_free()
	_finish()

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
		print("ISOMETRIC_BIOME_TERRAIN_COVERAGE_SMOKE_TEST: PASS")
		quit(0)
		return
	print("ISOMETRIC_BIOME_TERRAIN_COVERAGE_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
