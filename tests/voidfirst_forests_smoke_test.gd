extends SceneTree

# M2 — Void-first forest pass. Square forests (side 9..60) are walkable floor
# patches filled with natural-size trees. Trees never land on a rock (rock wins)
# and the interior stays walkable between trunks.

const MIN_FORESTS := 4
const MIN_SIDE := 9
const MAX_SIDE := 60
const TREE_FOOTPRINT := Vector2i(12, 12)
const MAX_TREES := 240
const SEED := 246810

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
	_validate_forests(layout)
	_validate_trees(layout)
	_validate_rock_priority(layout)
	_validate_walkable_interior(layout)
	_validate_targeted_rock_priority(biome)
	_validate_determinism(biome)
	_finish()

func _build_layout(biome: BiomeDefinition, seed_value: int) -> BiomeEnvironmentLayout:
	var cell := BiomeCell.new()
	cell.configure(
		&"voidfirst_forest_cell",
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

func _validate_forests(layout: BiomeEnvironmentLayout) -> void:
	_expect(
		layout.forest_rects.size() >= MIN_FORESTS,
		"at least %d forests placed (got %d)" % [MIN_FORESTS, layout.forest_rects.size()]
	)
	var all_square := true
	var all_in_range := true
	for rect in layout.forest_rects:
		if rect.size.x != rect.size.y:
			all_square = false
		if rect.size.x < MIN_SIDE or rect.size.x > MAX_SIDE:
			all_in_range = false
	_expect(all_square, "every forest is square")
	_expect(all_in_range, "every forest side is within %d..%d" % [MIN_SIDE, MAX_SIDE])

	var forest_floor := 0
	for tag in layout.floor_rect_tags:
		if tag == &"forest_tall_grass":
			forest_floor += 1
	_expect(
		forest_floor >= layout.forest_rects.size(),
		"every forest adds a walkable forest floor patch"
	)

func _validate_trees(layout: BiomeEnvironmentLayout) -> void:
	var trees := 0
	var all_natural := true
	for index in range(layout.obstacle_ids.size()):
		if layout.obstacle_ids[index] != &"forest_tree":
			continue
		trees += 1
		if layout.obstacle_rects[index].size != TREE_FOOTPRINT:
			all_natural = false
	_expect(trees > 0, "forests are filled with trees (got %d)" % trees)
	_expect(trees <= MAX_TREES, "tree count stays within the budget (%d)" % trees)
	_expect(all_natural, "every tree uses the natural 12x12 footprint")

func _validate_rock_priority(layout: BiomeEnvironmentLayout) -> void:
	var violation := false
	for index in range(layout.obstacle_ids.size()):
		if layout.obstacle_ids[index] != &"forest_tree":
			continue
		var tree_rect := layout.obstacle_rects[index]
		for rock_rect in layout.rock_rects:
			if tree_rect.intersects(rock_rect):
				violation = true
	_expect(not violation, "no tree overlaps a rock (rock wins)")

func _validate_walkable_interior(layout: BiomeEnvironmentLayout) -> void:
	var largest := Rect2i()
	var largest_area := 0
	for rect in layout.forest_rects:
		var area := rect.size.x * rect.size.y
		if area > largest_area:
			largest_area = area
			largest = rect
	if largest_area <= 0:
		_expect(false, "a forest exists to test walkable interior")
		return
	var walkable := 0
	for y in range(largest.position.y, largest.end.y):
		for x in range(largest.position.x, largest.end.x):
			if (
				layout.get_terrain_class_at_cell(Vector2i(x, y))
				== BiomeEnvironmentLayout.TERRAIN_WALKABLE
			):
				walkable += 1
	_expect(walkable > 0, "largest forest keeps walkable interior cells (%d)" % walkable)

func _validate_targeted_rock_priority(biome: BiomeDefinition) -> void:
	# Force a forest to fully cover a rock and confirm no tree lands on the rock
	# while trees still fill the surrounding forest.
	var layout := BiomeEnvironmentLayout.new()
	layout.zone_size = BiomeEnvironmentLayout.DEFAULT_ZONE_SIZE
	layout.generation_seed = 13
	var rock := Rect2i(Vector2i(120, 120), Vector2i(24, 24))
	layout.rock_rects.append(rock)
	layout.obstacle_rects.append(rock)
	layout.obstacle_ids.append(&"large_rock")
	layout.obstacle_positions.append(layout.rect_center_to_world(rock))
	layout.obstacle_sizes.append(layout.rect_size_to_world(rock))
	layout.obstacle_rotations.append(0.0)
	layout.obstacle_shape_ids.append(&"rectangle")
	var forest := Rect2i(Vector2i(90, 90), Vector2i(90, 90))
	layout.forest_rects.append(forest)
	layout.add_floor_rect(forest, &"forest_tall_grass")
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	ObstacleLayoutGenerator.new()._fill_forests_with_trees(layout, rng)
	var trees := 0
	var on_rock := false
	for index in range(layout.obstacle_ids.size()):
		if layout.obstacle_ids[index] != &"forest_tree":
			continue
		trees += 1
		if layout.obstacle_rects[index].intersects(rock):
			on_rock = true
	_expect(not on_rock, "forced overlap: no tree placed on the covered rock")
	_expect(trees > 0, "forced overlap: trees still fill the forest around the rock")

func _validate_determinism(biome: BiomeDefinition) -> void:
	var a := _build_layout(biome, 777222)
	var b := _build_layout(biome, 777222)
	var identical := (
		a.forest_rects == b.forest_rects
		and a.obstacle_rects.size() == b.obstacle_rects.size()
	)
	if identical:
		for i in range(a.obstacle_rects.size()):
			if a.obstacle_rects[i] != b.obstacle_rects[i]:
				identical = false
				break
	_expect(identical, "forest + tree placement is deterministic for a fixed seed")

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("VOIDFIRST_FORESTS_SMOKE_TEST: PASS")
		quit(0)
		return
	print("VOIDFIRST_FORESTS_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
