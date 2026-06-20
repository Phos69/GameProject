extends SceneTree

# M6 — Void-first integration. Generate the starter biome through the live
# BiomeTerrainGenerator (populate -> fall boundaries -> validation -> spawn) and
# confirm the chunk is valid, playable and within the instance budget.

const TREE_BUDGET := 500
const FALL_ZONE_BUDGET := 220
const OBSTACLE_BUDGET := 900

var failures := PackedStringArray()

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	IsometricEnvironmentManifest.reload_shared()
	var biome := load("res://game/modes/zombie/biomes/infected_plains.tres") as BiomeDefinition
	_expect(biome != null, "infected plains loads")
	if biome == null:
		_finish()
		return
	var generator := BiomeTerrainGenerator.new()
	root.add_child(generator)
	var cell := BiomeCell.new()
	cell.configure(
		&"voidfirst_integration_cell",
		biome.biome_id,
		Vector2i.ZERO,
		biome.get_biome_size(),
		135790
	)
	var layout := generator.generate_layout_for_cell(cell, biome)
	_expect(layout != null, "layout is generated")
	if layout == null:
		generator.queue_free()
		_finish()
		return

	_validate_report(layout)
	_validate_playable(layout, cell)
	_validate_budget(layout)
	generator.queue_free()
	await process_frame
	_finish()

func _validate_report(layout: BiomeEnvironmentLayout) -> void:
	var report := layout.validation_report
	_expect(bool(report.get("is_valid", false)), "void-first layout passes validation")
	if not bool(report.get("is_valid", false)):
		push_error("validation report: " + str(report))
	var placement_errors := report.get("placement_errors", PackedStringArray()) as PackedStringArray
	_expect(placement_errors.is_empty(), "no spawn/crate placement errors")
	for err in placement_errors:
		push_error("placement: " + String(err))

func _validate_playable(layout: BiomeEnvironmentLayout, cell: BiomeCell) -> void:
	_expect(
		layout.get_terrain_class_at_cell(layout.player_spawn_cell, cell)
		== BiomeEnvironmentLayout.TERRAIN_WALKABLE,
		"player spawn is walkable"
	)
	_expect(layout.crate_cells.size() > 0, "at least one crate is placed")
	var all_walkable := true
	for crate_cell in layout.crate_cells:
		if (
			layout.get_terrain_class_at_cell(crate_cell, cell)
			!= BiomeEnvironmentLayout.TERRAIN_WALKABLE
		):
			all_walkable = false
	_expect(all_walkable, "every crate sits on walkable terrain")
	var report := layout.get_classification_report()
	_expect(bool(report.get("is_complete", false)), "classification covers the whole chunk")

func _validate_budget(layout: BiomeEnvironmentLayout) -> void:
	var trees := 0
	var rocks := 0
	for obstacle_id in layout.obstacle_ids:
		if obstacle_id == &"forest_tree":
			trees += 1
		elif obstacle_id == &"large_rock":
			rocks += 1
	print("INTEGRATION COUNTS trees=%d rocks=%d obstacles=%d fall_zones=%d crates=%d" % [
		trees, rocks, layout.obstacle_ids.size(), layout.fall_zone_rects.size(), layout.crate_cells.size()
	])
	_expect(trees <= TREE_BUDGET, "tree count within budget (%d <= %d)" % [trees, TREE_BUDGET])
	_expect(
		layout.fall_zone_rects.size() <= FALL_ZONE_BUDGET,
		"fall-zone count within budget (%d <= %d)" % [layout.fall_zone_rects.size(), FALL_ZONE_BUDGET]
	)
	_expect(
		layout.obstacle_ids.size() <= OBSTACLE_BUDGET,
		"obstacle count within budget (%d <= %d)" % [layout.obstacle_ids.size(), OBSTACLE_BUDGET]
	)
	_expect(rocks >= 10, "at least 10 rocks in the live layout (%d)" % rocks)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("VOIDFIRST_INTEGRATION_SMOKE_TEST: PASS")
		quit(0)
		return
	print("VOIDFIRST_INTEGRATION_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
