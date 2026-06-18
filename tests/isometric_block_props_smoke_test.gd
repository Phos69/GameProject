extends SceneTree

# Milestone R3 - internal blocks are enriched with small thematic props so open
# areas read as finished spaces. Props must stay clear of routes, fall zones and
# hazards so they add detail without breaking pathfinding.

var failures: PackedStringArray = []

const PROP_IDS_BY_BIOME: Dictionary = {
	&"toxic_wastes": [&"small_rock", &"toxic_barrel", &"industrial_fence"],
	&"burning_fields": [&"small_rock", &"ash_barrier", &"broken_fence"],
	&"frozen_outskirts": [&"ice_rock", &"fallen_log", &"small_rock"],
	&"drowned_marsh": [&"marsh_log", &"small_rock", &"reed_wall"]
}
const DEFAULT_PROP_IDS: Array = [&"small_rock", &"broken_fence", &"fallen_log"]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var biome_manager := BiomeManager.new()
	root.add_child(biome_manager)
	await process_frame

	biome_manager.start_run({
		"world_seed": 515151,
		"biome_map_width": 3,
		"biome_map_height": 3,
		"preserve_biome_sequence": false,
		"extra_edge_chance": 0.5
	})
	var cells := biome_manager.get_generated_biome_map()
	_expect(cells.size() == 9, "block props smoke generates a 3x3 biome map")

	for cell in _first_cell_per_biome(cells):
		_validate_cell_props(cell)

	biome_manager.queue_free()
	_finish()

func _validate_cell_props(cell: BiomeCell) -> void:
	var layout := cell.generated_layout
	if layout == null:
		_expect(false, "%s has generated layout" % String(cell.id))
		return
	var prop_pool := _prop_pool(cell.biome_id)

	var prop_count := 0
	for index in range(layout.obstacle_rects.size()):
		var obstacle_id := (
			layout.obstacle_ids[index]
			if index < layout.obstacle_ids.size()
			else &""
		)
		if not prop_pool.has(obstacle_id):
			continue
		var rect: Rect2i = layout.obstacle_rects[index]
		if not _rect_inside_any(rect, layout.block_rects):
			continue
		prop_count += 1
		# Props must never sit on a road, fall zone or hazard.
		_expect(
			not _any_intersects(rect, layout.road_rects),
			"%s prop %s stays off the road network" % [String(cell.id), String(obstacle_id)]
		)
		_expect(
			not _any_intersects(rect, layout.fall_zone_rects),
			"%s prop %s stays off fall zones" % [String(cell.id), String(obstacle_id)]
		)

	_expect(
		prop_count >= 3,
		"%s scatters thematic props inside its blocks (found %d)" % [String(cell.id), prop_count]
	)
	_expect(
		bool(layout.validation_report.get("is_valid", false)),
		"%s stays valid with block props" % String(cell.id)
	)

func _prop_pool(biome_id: StringName) -> Array:
	return PROP_IDS_BY_BIOME.get(biome_id, DEFAULT_PROP_IDS)

func _rect_inside_any(rect: Rect2i, rects: Array[Rect2i]) -> bool:
	var center := rect.position + rect.size / 2
	for other in rects:
		if other.has_point(center):
			return true
	return false

func _any_intersects(rect: Rect2i, rects: Array[Rect2i]) -> bool:
	for other in rects:
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
		print("ISOMETRIC_BLOCK_PROPS_SMOKE_TEST: PASS")
		quit(0)
		return
	print("ISOMETRIC_BLOCK_PROPS_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
