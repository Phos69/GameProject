extends SceneTree

# M5 — Void lottery. Leftover void is split into floor / chasm patches at a ratio
# of 1 chasm : 3 walkable. Chasms never land on roads, and almost no raw void
# remains after the pass.

const SEED := 424344

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
	_validate_ratio()
	var layout := _build_layout(biome, SEED)
	_validate_no_chasm_on_road(layout)
	_validate_void_coverage(layout)
	_validate_determinism(biome)
	_finish()

func _build_layout(biome: BiomeDefinition, seed_value: int) -> BiomeEnvironmentLayout:
	var cell := BiomeCell.new()
	cell.configure(
		&"voidfirst_lottery_cell",
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

func _area(rects: Array[Rect2i]) -> int:
	var total := 0
	for rect in rects:
		total += rect.size.x * rect.size.y
	return total

func _validate_ratio() -> void:
	# A pure-void canvas: the whole interior goes through the lottery, so the
	# chasm fraction must sit close to 1/4.
	var layout := BiomeEnvironmentLayout.new()
	layout.zone_size = BiomeEnvironmentLayout.DEFAULT_ZONE_SIZE
	layout.generation_seed = 99
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	ObstacleLayoutGenerator.new()._resolve_void_lottery(layout, rng)
	var chasm := _area(layout.fall_zone_rects)
	var floor := _area(layout.floor_rects)
	var total := chasm + floor
	_expect(total > 0, "lottery resolves the void into floor and chasm")
	if total > 0:
		var ratio := float(chasm) / float(total)
		_expect(
			ratio >= 0.18 and ratio <= 0.30,
			"chasm fraction is ~1:3 (got %0.3f)" % ratio
		)

func _validate_no_chasm_on_road(layout: BiomeEnvironmentLayout) -> void:
	var on_road := false
	for chasm_rect in layout.fall_zone_rects:
		for y in range(chasm_rect.position.y, chasm_rect.end.y):
			for x in range(chasm_rect.position.x, chasm_rect.end.x):
				if layout.has_road_cell(Vector2i(x, y)):
					on_road = true
					break
			if on_road:
				break
		if on_road:
			break
	_expect(not on_road, "no chasm overlaps a road cell")

func _validate_void_coverage(layout: BiomeEnvironmentLayout) -> void:
	layout.rebuild_terrain_classification(null)
	var report := layout.get_classification_report()
	var counts := report.get("counts", {}) as Dictionary
	var total := int(report.get("expected_total", 1))
	var void_cells := int(counts.get(BiomeEnvironmentLayout.TERRAIN_VOID, 0))
	var fraction := float(void_cells) / float(maxi(total, 1))
	_expect(
		fraction < 0.10,
		"almost no raw void remains after the lottery (%0.3f)" % fraction
	)

func _validate_determinism(biome: BiomeDefinition) -> void:
	var a := _build_layout(biome, 565656)
	var b := _build_layout(biome, 565656)
	var identical := a.fall_zone_rects.size() == b.fall_zone_rects.size()
	if identical:
		for i in range(a.fall_zone_rects.size()):
			if a.fall_zone_rects[i] != b.fall_zone_rects[i]:
				identical = false
				break
	_expect(identical, "void lottery is deterministic for a fixed seed")

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("VOIDFIRST_VOID_LOTTERY_SMOKE_TEST: PASS")
		quit(0)
		return
	print("VOIDFIRST_VOID_LOTTERY_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
