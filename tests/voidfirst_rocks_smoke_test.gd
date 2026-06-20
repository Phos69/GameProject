extends SceneTree

# M1 — Void-first rock pass. The chunk starts as void; at least 10 square rocks
# (side 15..30) are placed, non-overlapping, clear of passage corridors and
# deterministic from the cell seed.

const MIN_ROCKS := 10
const MIN_SIDE := 15
const MAX_SIDE := 30
const SEED := 987654

var failures := PackedStringArray()

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var manifest := IsometricEnvironmentManifest.reload_shared()
	var biome := load("res://game/modes/zombie/biomes/infected_plains.tres") as BiomeDefinition
	_expect(biome != null, "infected plains loads")
	if biome == null:
		_finish()
		return
	var layout := _build_layout(biome, SEED)
	_validate_rocks(layout)
	_validate_classification(layout)
	_validate_records(layout, manifest)
	_validate_determinism(biome)
	_finish()

func _build_layout(biome: BiomeDefinition, seed_value: int) -> BiomeEnvironmentLayout:
	var cell := BiomeCell.new()
	cell.configure(
		&"voidfirst_rock_cell",
		biome.biome_id,
		Vector2i.ZERO,
		BiomeEnvironmentLayout.DEFAULT_ZONE_SIZE,
		seed_value
	)
	var layout := BiomeEnvironmentLayout.new()
	layout.zone_size = BiomeEnvironmentLayout.DEFAULT_ZONE_SIZE
	layout.generation_seed = seed_value
	var generator := ObstacleLayoutGenerator.new()
	generator.populate_layout_voidfirst(layout, cell, biome)
	return layout

func _validate_rocks(layout: BiomeEnvironmentLayout) -> void:
	_expect(
		layout.rock_rects.size() >= MIN_ROCKS,
		"at least %d rocks are placed (got %d)" % [MIN_ROCKS, layout.rock_rects.size()]
	)
	var all_square := true
	var all_in_range := true
	for rect in layout.rock_rects:
		if rect.size.x != rect.size.y:
			all_square = false
		if rect.size.x < MIN_SIDE or rect.size.x > MAX_SIDE:
			all_in_range = false
	_expect(all_square, "every rock is square")
	_expect(all_in_range, "every rock side is within %d..%d" % [MIN_SIDE, MAX_SIDE])

	var overlaps := false
	for i in range(layout.rock_rects.size()):
		for j in range(i + 1, layout.rock_rects.size()):
			if layout.rock_rects[i].intersects(layout.rock_rects[j]):
				overlaps = true
	_expect(not overlaps, "no two rocks overlap")

	# In M1 the only obstacles are rocks.
	var rock_obstacles := 0
	for obstacle_id in layout.obstacle_ids:
		if obstacle_id == &"large_rock":
			rock_obstacles += 1
	_expect(
		rock_obstacles == layout.rock_rects.size(),
		"each rock is registered as a large_rock obstacle"
	)

func _validate_classification(layout: BiomeEnvironmentLayout) -> void:
	var all_obstacle := true
	for rect in layout.rock_rects:
		var center := rect.position + rect.size / 2
		if (
			layout.get_terrain_class_at_cell(center)
			!= BiomeEnvironmentLayout.TERRAIN_OBSTACLE
		):
			all_obstacle = false
	_expect(all_obstacle, "rock centers classify as obstacle")

func _validate_records(
	layout: BiomeEnvironmentLayout,
	manifest: IsometricEnvironmentManifest
) -> void:
	var record_failures := layout.validate_obstacle_records(manifest)
	_expect(record_failures.is_empty(), "rock obstacle records are valid")
	for failure in record_failures:
		push_error("record: " + String(failure))

func _validate_determinism(biome: BiomeDefinition) -> void:
	var a := _build_layout(biome, 555111)
	var b := _build_layout(biome, 555111)
	var identical := a.rock_rects.size() == b.rock_rects.size()
	if identical:
		for i in range(a.rock_rects.size()):
			if a.rock_rects[i] != b.rock_rects[i]:
				identical = false
				break
	_expect(identical, "rock placement is deterministic for a fixed seed")

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("VOIDFIRST_ROCKS_SMOKE_TEST: PASS")
		quit(0)
		return
	print("VOIDFIRST_ROCKS_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
