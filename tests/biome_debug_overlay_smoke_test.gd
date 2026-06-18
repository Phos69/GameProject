extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene_root := Node.new()
	root.add_child(scene_root)
	current_scene = scene_root
	var overlay := BiomeMapDebugOverlay.new()
	scene_root.add_child(overlay)
	var encounter := RandomEncounterSystem.new()
	scene_root.add_child(encounter)
	await process_frame
	encounter.configure_seed(99)
	var biome := load("res://game/modes/zombie/biomes/toxic_wastes.tres") as BiomeDefinition
	var cell := BiomeCell.new()
	cell.id = &"debug_cell"
	cell.biome_id = &"toxic_wastes"
	cell.seed = 99
	cell.validation_report = {"is_valid": true}
	var layout := BiomeEnvironmentLayout.new()
	layout.obstacle_rects.append(Rect2i(Vector2i(10, 10), Vector2i(4, 4)))
	layout.hazard_rects.append(Rect2i(Vector2i(30, 30), Vector2i(5, 5)))
	layout.crate_cells.append(Vector2i(50, 50))
	layout.rebuild_terrain_classification(cell)
	cell.generated_layout = layout
	var cells: Array[BiomeCell] = [cell]
	overlay.configure(99, cells)
	var result := encounter.force_encounter(biome, &"survivor_cache", 2)
	var summary := overlay.get_debug_summary()
	_assert(summary.get("seed") == 99, "overlay reports seed")
	_assert(summary.get("cell_count") == 1, "overlay counts cells")
	_assert(summary.get("obstacle_count") == 1, "overlay counts obstacles")
	_assert(summary.get("hazard_count") == 1, "overlay counts hazards")
	_assert(summary.get("crate_count") == 1, "overlay counts crates")
	_assert(
		int(summary.get("terrain_classification_total", 0))
		== layout.zone_size.x * layout.zone_size.y,
		"overlay reports terrain classification total"
	)
	_assert(
		int(summary.get("terrain_classification_complete", 0)) == 1,
		"overlay reports complete terrain classification"
	)
	var terrain_counts := summary.get("terrain_class_counts") as Dictionary
	_assert(
		int(terrain_counts.get(BiomeEnvironmentLayout.TERRAIN_OBSTACLE, 0)) > 0,
		"overlay reports obstacle terrain class"
	)
	_assert(
		int(terrain_counts.get(BiomeEnvironmentLayout.TERRAIN_HAZARD, 0)) > 0,
		"overlay reports hazard terrain class"
	)
	var encounter_summary := summary.get("encounter") as Dictionary
	_assert(
		encounter_summary.get("last_encounter_id") == &"survivor_cache",
		"overlay exposes last encounter"
	)
	_assert(
		int(encounter_summary.get("last_threat_score", 0))
		== int(result.get("threat_score", 0)),
		"overlay exposes threat score"
	)
	print("biome_debug_overlay_smoke_test passed")
	quit(0)

func _assert(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		quit(1)
