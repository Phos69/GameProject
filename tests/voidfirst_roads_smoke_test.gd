extends SceneTree

# M3 — Void-first roads and trails. Main roads connect opposite edges, route
# around rocks and cross forests; the carved lane clears trees. Trails (sentieri)
# cross forests but stop at the first rock.

const SEED := 369121

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
	_validate_edges(layout)
	_validate_around_rocks(layout)
	_validate_through_forests(layout)
	_validate_trees_cleared(layout)
	_validate_trail_stops_at_rock(biome)
	_validate_determinism(biome)
	_finish()

func _build_layout(biome: BiomeDefinition, seed_value: int) -> BiomeEnvironmentLayout:
	var cell := BiomeCell.new()
	cell.configure(
		&"voidfirst_road_cell",
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

func _band_has_road(layout: BiomeEnvironmentLayout, rect: Rect2i) -> bool:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if layout.has_road_cell(Vector2i(x, y)):
				return true
	return false

func _validate_edges(layout: BiomeEnvironmentLayout) -> void:
	var z := layout.zone_size
	var thickness := 3
	_expect(_band_has_road(layout, Rect2i(0, 0, thickness, z.y)), "road reaches the west edge")
	_expect(_band_has_road(layout, Rect2i(z.x - thickness, 0, thickness, z.y)), "road reaches the east edge")
	_expect(_band_has_road(layout, Rect2i(0, 0, z.x, thickness)), "road reaches the north edge")
	_expect(_band_has_road(layout, Rect2i(0, z.y - thickness, z.x, thickness)), "road reaches the south edge")

func _validate_around_rocks(layout: BiomeEnvironmentLayout) -> void:
	var on_rock := false
	for rock_rect in layout.rock_rects:
		for y in range(rock_rect.position.y, rock_rect.end.y):
			for x in range(rock_rect.position.x, rock_rect.end.x):
				if layout.has_road_cell(Vector2i(x, y)):
					on_rock = true
					break
			if on_rock:
				break
		if on_rock:
			break
	_expect(not on_rock, "no road cell runs through a rock (roads go around)")

func _validate_through_forests(layout: BiomeEnvironmentLayout) -> void:
	var crosses := false
	for forest_rect in layout.forest_rects:
		if _band_has_road(layout, forest_rect):
			crosses = true
			break
	_expect(crosses, "at least one road/trail crosses a forest")

func _validate_trees_cleared(layout: BiomeEnvironmentLayout) -> void:
	var tree_on_road := false
	for index in range(layout.obstacle_ids.size()):
		if layout.obstacle_ids[index] != &"forest_tree":
			continue
		var rect := layout.obstacle_rects[index]
		if _band_has_road(layout, rect):
			tree_on_road = true
			break
	_expect(not tree_on_road, "no tree remains on a carved route lane")

func _validate_trail_stops_at_rock(biome: BiomeDefinition) -> void:
	var layout := BiomeEnvironmentLayout.new()
	layout.zone_size = BiomeEnvironmentLayout.DEFAULT_ZONE_SIZE
	layout.generation_seed = 7
	var rock := Rect2i(Vector2i(160, 240), Vector2i(24, 24))
	layout.rock_rects.append(rock)
	var carved := ObstacleLayoutGenerator.new()._carve_trail(
		layout, Vector2i(100, 250), Vector2i(1, 0), 7, 240, &"broken_street"
	)
	_expect(carved > 0, "trail carves through the forest toward the rock")
	_expect(layout.has_road_cell(Vector2i(155, 250)), "trail reaches the cells before the rock")
	var beyond := false
	for x in range(160, 210):
		if layout.has_road_cell(Vector2i(x, 250)):
			beyond = true
			break
	_expect(not beyond, "trail stops at the rock and does not cross it")

func _validate_determinism(biome: BiomeDefinition) -> void:
	var a := _build_layout(biome, 808080)
	var b := _build_layout(biome, 808080)
	var identical := a.road_cell_tags.size() == b.road_cell_tags.size()
	_expect(identical, "route carving is deterministic for a fixed seed")

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("VOIDFIRST_ROADS_SMOKE_TEST: PASS")
		quit(0)
		return
	print("VOIDFIRST_ROADS_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
