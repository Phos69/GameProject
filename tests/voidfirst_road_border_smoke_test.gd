extends SceneTree

# M4 — Tree lining along roads. Roads crossing open void get a layer of trees
# where they are not already bounded by a rock or forest. Trees sit beside the
# road, never on it, and never on a rock.

const SEED := 515253
const TREE_FOOTPRINT := Vector2i(12, 12)

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
	var layout := _build_layout(biome, SEED)
	_validate_lining_present(layout)
	_validate_no_tree_on_road(layout)
	_validate_no_tree_on_rock(layout)
	_validate_open_road_is_lined()
	_validate_forest_road_not_lined()
	_finish()

func _build_layout(biome: BiomeDefinition, seed_value: int) -> BiomeEnvironmentLayout:
	var cell := BiomeCell.new()
	cell.configure(
		&"voidfirst_road_border_cell",
		biome.biome_id,
		Vector2i.ZERO,
		BiomeEnvironmentLayout.DEFAULT_ZONE_SIZE,
		seed_value
	)
	var layout := BiomeEnvironmentLayout.new()
	layout.zone_size = BiomeEnvironmentLayout.DEFAULT_ZONE_SIZE
	layout.generation_seed = seed_value
	ObstacleLayoutGenerator.new().populate_layout_voidfirst(layout, cell, biome)
	return layout

func _rect_in_any(rect: Rect2i, rects: Array[Rect2i]) -> bool:
	for other in rects:
		if rect.intersects(other):
			return true
	return false

func _rect_near_road(layout: BiomeEnvironmentLayout, rect: Rect2i) -> bool:
	var band := Rect2i(rect.position - Vector2i(3, 3), rect.size + Vector2i(6, 6))
	for y in range(band.position.y, band.end.y):
		for x in range(band.position.x, band.end.x):
			if layout.has_road_cell(Vector2i(x, y)):
				return true
	return false

func _validate_lining_present(layout: BiomeEnvironmentLayout) -> void:
	# A lining tree is one that sits beside a road but is not inside any forest
	# (forest-fill trees always live inside a forest rect).
	var lining := 0
	for index in range(layout.obstacle_ids.size()):
		if layout.obstacle_ids[index] != &"forest_tree":
			continue
		var rect := layout.obstacle_rects[index]
		if _rect_in_any(rect, layout.forest_rects):
			continue
		if _rect_near_road(layout, rect):
			lining += 1
	_expect(lining > 0, "roads in open void are lined with trees (got %d)" % lining)

func _validate_no_tree_on_road(layout: BiomeEnvironmentLayout) -> void:
	var on_road := false
	for index in range(layout.obstacle_ids.size()):
		if layout.obstacle_ids[index] != &"forest_tree":
			continue
		var rect := layout.obstacle_rects[index]
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				if layout.has_road_cell(Vector2i(x, y)):
					on_road = true
					break
			if on_road:
				break
		if on_road:
			break
	_expect(not on_road, "lining trees sit beside the road, never on it")

func _validate_no_tree_on_rock(layout: BiomeEnvironmentLayout) -> void:
	var on_rock := false
	for index in range(layout.obstacle_ids.size()):
		if layout.obstacle_ids[index] != &"forest_tree":
			continue
		if _rect_in_any(layout.obstacle_rects[index], layout.rock_rects):
			on_rock = true
			break
	_expect(not on_rock, "lining never places a tree on a rock")

func _carve_straight_road(layout: BiomeEnvironmentLayout) -> void:
	for x in range(50, 451):
		for y in range(247, 254):
			layout.add_road_cell(Vector2i(x, y), &"main_road")

func _count_trees(layout: BiomeEnvironmentLayout) -> int:
	var count := 0
	for obstacle_id in layout.obstacle_ids:
		if obstacle_id == &"forest_tree":
			count += 1
	return count

func _validate_open_road_is_lined() -> void:
	var layout := BiomeEnvironmentLayout.new()
	layout.zone_size = BiomeEnvironmentLayout.DEFAULT_ZONE_SIZE
	layout.generation_seed = 1
	_carve_straight_road(layout)
	ObstacleLayoutGenerator.new()._line_roads_with_trees(layout)
	_expect(_count_trees(layout) > 0, "open-void road gets a tree lining")

func _validate_forest_road_not_lined() -> void:
	var layout := BiomeEnvironmentLayout.new()
	layout.zone_size = BiomeEnvironmentLayout.DEFAULT_ZONE_SIZE
	layout.generation_seed = 2
	_carve_straight_road(layout)
	# A forest already bounds the road, so no extra lining should be added.
	layout.forest_rects.append(Rect2i(Vector2i(0, 200), Vector2i(500, 110)))
	ObstacleLayoutGenerator.new()._line_roads_with_trees(layout)
	_expect(
		_count_trees(layout) == 0,
		"road already bounded by a forest is not lined again"
	)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("VOIDFIRST_ROAD_BORDER_SMOKE_TEST: PASS")
		quit(0)
		return
	print("VOIDFIRST_ROAD_BORDER_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
