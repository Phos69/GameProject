extends GutTest
## World Generation A1 — Generazione void-first dello starter biome.
##
## Migra e accorpa:
##   tests/voidfirst_rocks_smoke_test.gd
##   tests/voidfirst_forests_smoke_test.gd
##   tests/voidfirst_roads_smoke_test.gd
##   tests/voidfirst_road_border_smoke_test.gd
##   tests/voidfirst_void_lottery_smoke_test.gd
##   tests/voidfirst_integration_smoke_test.gd
##
## Ottimizzazione: un layout void-first condiviso (SHARED_SEED) viene costruito
## UNA volta in before_all e riusato dalle verifiche di invarianti (rocce,
## foreste, strade, bordi, no-chasm-su-strada). Determinismo e casi forzati
## costruiscono layout dedicati.

const WorldGen = preload("res://tests/support/world_gen_helpers.gd")
const WorldGridConfig = preload("res://game/core/world_grid_config.gd")

# Seed con la tolleranza piu stretta (budget alberi forest-fill 240): se passa
# qui passa anche per le altre invarianti, che sono strutturali.
const SHARED_SEED := 246810
const TREE_FOOTPRINT := Vector2i(2, 2)
# infected_plains slice of the void-first palette, used to exercise the road
# tree-lining pass directly (the generator resolves the full palette per biome).
const _PLAINS_LINE_PALETTE := {"line_vegetation": true, "cluster_id": &"forest_tree"}

var _manifest: EnvironmentAssetManifest
var _biome: BiomeDefinition
var _layout: BiomeEnvironmentLayout

func before_all() -> void:
	_manifest = EnvironmentAssetManifest.reload_shared()
	_biome = WorldGen.load_starter_biome()
	assert_not_null(_biome, "infected plains carica")
	if _biome != null:
		_layout = WorldGen.voidfirst_layout(_biome, SHARED_SEED)

func test_biome_divider_uses_upward_cliff_contract() -> void:
	assert_eq(
		_layout.perimeter_visual_style,
		BiomeEnvironmentLayout.PERIMETER_VISUAL_RAISED_CLIFF,
		"physical biome-divider walls use the upward-cliff renderer"
	)
	assert_eq(
		_layout.wall_height_cells,
		BiomeEnvironmentLayout.RAISED_CLIFF_HEIGHT_CELLS,
		"divider cliffs keep the shared Infinite Arena height"
	)

# --- rocce (M1) -----------------------------------------------------------

func test_rocks_placement() -> void:
	assert_eq(_layout.mesa_rects.size(), 1, "una sola montagna mesa piazzata")
	assert_eq(_layout.parcel_types.count(BiomeEnvironmentLayout.PARCEL_MESA), 1,
		"la montagna appartiene all'unico lotto mesa")
	var rock_obstacles := 0
	for obstacle_id in _layout.obstacle_ids:
		if obstacle_id == &"large_rock":
			rock_obstacles += 1
	assert_eq(rock_obstacles, 1, "la montagna e registrata come large_rock")

func test_rocks_classification_and_records() -> void:
	var all_obstacle := true
	for rect in _layout.rock_rects:
		var center := rect.position + _center_offset(rect.size)
		if _layout.get_terrain_class_at_cell(center) != BiomeEnvironmentLayout.TERRAIN_OBSTACLE:
			all_obstacle = false
	assert_true(all_obstacle, "i centri delle rocce classificano come obstacle")
	assert_true(_layout.validate_obstacle_records(_manifest).is_empty(), "i record obstacle delle rocce sono validi")

# --- foreste (M2) ---------------------------------------------------------

func test_forests_placement() -> void:
	var forest_parcels := _layout.parcel_types.count(BiomeEnvironmentLayout.PARCEL_FOREST)
	assert_eq(_layout.forest_rects.size(), forest_parcels,
		"ogni lotto forest ha un bounds visuale")
	var forest_floor := 0
	for tag in _layout.floor_rect_tags:
		if tag == &"forest_tall_grass":
			forest_floor += 1
	assert_gte(forest_floor, _layout.forest_rects.size(), "ogni foresta aggiunge un pavimento walkable")

func test_forest_trees() -> void:
	var trees := 0
	var all_natural := true
	for index in range(_layout.obstacle_ids.size()):
		if _layout.obstacle_ids[index] != &"forest_tree":
			continue
		trees += 1
		if _layout.obstacle_rects[index].size != TREE_FOOTPRINT:
			all_natural = false
	assert_gt(trees, 0, "le foreste sono riempite di alberi")
	assert_lte(trees, 240, "il numero di alberi resta nel budget forest-fill")
	assert_true(all_natural, "ogni albero usa il footprint logico convertito 2x2")

func test_tree_rock_priority() -> void:
	var violation := false
	for index in range(_layout.obstacle_ids.size()):
		if _layout.obstacle_ids[index] != &"forest_tree":
			continue
		var tree_rect := _layout.obstacle_rects[index]
		for rock_rect in _layout.rock_rects:
			if tree_rect.intersects(rock_rect):
				violation = true
	assert_false(violation, "nessun albero si sovrappone a una roccia (la roccia vince)")

func test_forest_walkable_interior() -> void:
	var largest := Rect2i()
	var largest_area := 0
	for rect in _layout.forest_rects:
		var area := rect.size.x * rect.size.y
		if area > largest_area:
			largest_area = area
			largest = rect
	assert_gt(largest_area, 0, "esiste una foresta da testare")
	var walkable := 0
	for y in range(largest.position.y, largest.end.y):
		for x in range(largest.position.x, largest.end.x):
			if _layout.get_terrain_class_at_cell(Vector2i(x, y)) == BiomeEnvironmentLayout.TERRAIN_WALKABLE:
				walkable += 1
	assert_gt(walkable, 0, "la foresta piu grande mantiene celle interne walkable")

func test_forced_forest_over_rock_keeps_rock_clear() -> void:
	var layout := BiomeEnvironmentLayout.new()
	layout.zone_size = BiomeEnvironmentLayout.DEFAULT_ZONE_SIZE
	layout.generation_seed = 13
	var rock := Rect2i(
		layout.zone_size / 2 - Vector2i(4, 4),
		Vector2i(8, 8)
	)
	layout.rock_rects.append(rock)
	layout.obstacle_rects.append(rock)
	layout.obstacle_ids.append(&"large_rock")
	layout.obstacle_positions.append(
		layout.obstacle_rect_center_to_world(rock, &"large_rock")
	)
	layout.obstacle_sizes.append(layout.rect_size_to_world(rock))
	layout.obstacle_rotations.append(0.0)
	layout.obstacle_shape_ids.append(&"rectangle")
	var forest := Rect2i(
		layout.zone_size / 2 - Vector2i(20, 20),
		Vector2i(40, 40)
	)
	layout.forest_rects.append(forest)
	layout.add_floor_rect(forest, &"forest_tall_grass")
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	ObstacleLayoutGenerator.new()._fill_forests_with_trees(layout, rng, &"forest_tree")
	var trees := 0
	var on_rock := false
	for index in range(layout.obstacle_ids.size()):
		if layout.obstacle_ids[index] != &"forest_tree":
			continue
		trees += 1
		if layout.obstacle_rects[index].intersects(rock):
			on_rock = true
	assert_false(on_rock, "overlap forzato: nessun albero sulla roccia coperta")
	assert_gt(trees, 0, "overlap forzato: gli alberi riempiono comunque la foresta")

# --- strade e sentieri (M3) -----------------------------------------------

func test_roads_reach_edges() -> void:
	var z := _layout.zone_size
	var thickness := WorldGridConfig.SIDE_EDGE_MAX_THICKNESS_TILES
	assert_true(_band_has_road(_layout, Rect2i(0, 0, thickness, z.y)), "strada raggiunge il bordo ovest")
	assert_true(_band_has_road(_layout, Rect2i(z.x - thickness, 0, thickness, z.y)), "strada raggiunge il bordo est")
	assert_true(_band_has_road(_layout, Rect2i(0, 0, z.x, thickness)), "strada raggiunge il bordo nord")
	assert_true(_band_has_road(_layout, Rect2i(0, z.y - thickness, z.x, thickness)), "strada raggiunge il bordo sud")

func test_roads_go_around_rocks() -> void:
	var on_rock := false
	for rock_rect in _layout.rock_rects:
		for y in range(rock_rect.position.y, rock_rect.end.y):
			for x in range(rock_rect.position.x, rock_rect.end.x):
				if _layout.has_road_cell(Vector2i(x, y)):
					on_rock = true
					break
			if on_rock:
				break
		if on_rock:
			break
	assert_false(on_rock, "nessuna cella strada attraversa una roccia")

func test_roads_cross_forests_and_clear_trees() -> void:
	var crosses := false
	for forest_rect in _layout.forest_rects:
		if _band_has_road(_layout, forest_rect):
			crosses = true
			break
	assert_false(crosses, "strade e sentieri delimitano le foreste senza attraversarle")
	var tree_on_road := false
	for index in range(_layout.obstacle_ids.size()):
		if _layout.obstacle_ids[index] != &"forest_tree":
			continue
		if _band_has_road(_layout, _layout.obstacle_rects[index]):
			tree_on_road = true
			break
	assert_false(tree_on_road, "nessun albero resta su una corsia carved")

func test_trail_stops_at_rock() -> void:
	var layout := BiomeEnvironmentLayout.new()
	layout.zone_size = BiomeEnvironmentLayout.DEFAULT_ZONE_SIZE
	layout.generation_seed = 7
	var rock := Rect2i(
		Vector2i(layout.zone_size.x * 3 / 5, layout.zone_size.y / 2),
		Vector2i(8, 8)
	)
	layout.rock_rects.append(rock)
	var carved := ObstacleLayoutGenerator.new()._carve_trail(
		layout,
		Vector2i(layout.zone_size.x / 3, rock.position.y + rock.size.y / 2),
		Vector2i(1, 0),
		WorldGridConfig.VOIDFIRST_PATH_WIDTH_TILES,
		WorldGridConfig.VOIDFIRST_PATH_MAX_LEN_TILES,
		&"broken_street"
	)
	assert_gt(carved, 0, "il sentiero scava verso la roccia")
	assert_true(
		layout.has_road_cell(Vector2i(rock.position.x - 1, rock.position.y + rock.size.y / 2)),
		"il sentiero raggiunge le celle prima della roccia"
	)
	var beyond := false
	for x in range(rock.position.x, mini(rock.position.x + 30, layout.zone_size.x)):
		if layout.has_road_cell(Vector2i(x, rock.position.y + rock.size.y / 2)):
			beyond = true
			break
	assert_false(beyond, "il sentiero si ferma alla roccia e non la attraversa")

# --- bordi alberati delle strade (M4) -------------------------------------

func test_road_lining_present_and_clean() -> void:
	var lining := 0
	for index in range(_layout.obstacle_ids.size()):
		if _layout.obstacle_ids[index] != &"forest_tree":
			continue
		var rect := _layout.obstacle_rects[index]
		if _rect_in_any(rect, _layout.forest_rects):
			continue
		if _rect_near_road(_layout, rect):
			lining += 1
	assert_gt(lining, 0, "le strade nel void aperto sono alberate ai bordi")

func test_open_road_is_lined() -> void:
	var layout := BiomeEnvironmentLayout.new()
	layout.zone_size = BiomeEnvironmentLayout.DEFAULT_ZONE_SIZE
	layout.generation_seed = 1
	_carve_straight_road(layout)
	ObstacleLayoutGenerator.new()._line_roads_with_trees(layout, _PLAINS_LINE_PALETTE)
	assert_gt(_count_trees(layout), 0, "la strada nel void aperto riceve un bordo alberato")

func test_forest_bounded_road_not_lined() -> void:
	var layout := BiomeEnvironmentLayout.new()
	layout.zone_size = BiomeEnvironmentLayout.DEFAULT_ZONE_SIZE
	layout.generation_seed = 2
	_carve_straight_road(layout)
	layout.forest_rects.append(Rect2i(
		Vector2i(0, layout.zone_size.y / 2 - 12),
		Vector2i(layout.zone_size.x, 24)
	))
	ObstacleLayoutGenerator.new()._line_roads_with_trees(layout, _PLAINS_LINE_PALETTE)
	assert_eq(_count_trees(layout), 0, "una strada gia delimitata da foresta non viene rialberata")

# --- void lottery (M5) ----------------------------------------------------

func test_void_lottery_ratio() -> void:
	var layout := BiomeEnvironmentLayout.new()
	layout.zone_size = BiomeEnvironmentLayout.DEFAULT_ZONE_SIZE
	layout.generation_seed = 99
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	ObstacleLayoutGenerator.new()._resolve_void_lottery(layout, rng)
	var chasm := _area(layout.fall_zone_rects)
	var floor := _area(layout.floor_rects)
	var total := chasm + floor
	assert_gt(total, 0, "la lottery risolve il void in pavimento e chasm")
	if total > 0:
		var ratio := float(chasm) / float(total)
		assert_between(ratio, 0.18, 0.30, "frazione chasm ~1:3 (got %0.3f)" % ratio)

func test_void_lottery_explicit_opt_out() -> void:
	var layout := BiomeEnvironmentLayout.new()
	layout.zone_size = BiomeEnvironmentLayout.DEFAULT_ZONE_SIZE
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	ObstacleLayoutGenerator.new()._resolve_void_lottery(layout, rng, false)
	assert_true(layout.fall_zone_rects.is_empty(),
		"disable_internal_void sopprime esplicitamente tutti i chasm interni")
	assert_false(layout.floor_rects.is_empty(),
		"l'opt-out converte il void interno in pavimento walkable")

func test_void_lottery_keeps_cliff_lip_clear_of_roads() -> void:
	var too_close_to_road := false
	for chasm_rect in _layout.fall_zone_rects:
		var padded := chasm_rect.grow(
			ObstacleLayoutGenerator.VOIDFIRST_CHASM_ROUTE_CLEARANCE
		)
		for y in range(padded.position.y, padded.end.y):
			for x in range(padded.position.x, padded.end.x):
				if _layout.has_road_cell(Vector2i(x, y)):
					too_close_to_road = true
					break
			if too_close_to_road:
				break
		if too_close_to_road:
			break
	assert_false(
		too_close_to_road,
		"il lip di ogni chasm mantiene una tile libera dalle celle strada"
	)

func test_void_lottery_converts_route_near_patch_to_floor() -> void:
	var layout := BiomeEnvironmentLayout.new()
	layout.zone_size = Vector2i(9, 9)
	for y in range(layout.zone_size.y):
		layout.add_road_cell(Vector2i(6, y), &"main_road")
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	ObstacleLayoutGenerator.new()._resolve_void_lottery(layout, rng)
	assert_false(layout.fall_zone_rects.is_empty(), "il fallback conserva il chasm obbligatorio")
	assert_true(
		layout.floor_rects.has(Rect2i(3, 3, 3, 3)),
		"la patch adiacente alla strada viene convertita in terreno"
	)
	for chasm_rect in layout.fall_zone_rects:
		assert_false(
			chasm_rect.grow(ObstacleLayoutGenerator.VOIDFIRST_CHASM_ROUTE_CLEARANCE)
				.has_point(Vector2i(6, chasm_rect.get_center().y)),
			"il fallback non riporta il cliff lip accanto alla strada"
		)

func test_void_lottery_coverage() -> void:
	# Layout dedicato: rebuild_terrain_classification muta lo stato, non tocco il condiviso.
	var layout := WorldGen.voidfirst_layout(_biome, 424344)
	layout.rebuild_terrain_classification(null)
	var report := layout.get_classification_report()
	var counts := report.get("counts", {}) as Dictionary
	var total := int(report.get("expected_total", 1))
	var void_cells := int(counts.get(BiomeEnvironmentLayout.TERRAIN_VOID, 0))
	var fraction := float(void_cells) / float(maxi(total, 1))
	assert_lt(fraction, 0.10, "quasi nessun void grezzo resta dopo la lottery (%0.3f)" % fraction)

# --- determinismo (accorpato) ---------------------------------------------

func test_voidfirst_is_deterministic() -> void:
	var a := WorldGen.voidfirst_layout(_biome, 565656)
	var b := WorldGen.voidfirst_layout(_biome, 565656)
	assert_eq(a.mesa_rects, b.mesa_rects, "le mesa sono deterministiche per seed fisso")
	assert_eq(a.mesa_profile_ids, b.mesa_profile_ids, "i profili mesa sono deterministici")
	assert_eq(a.rock_rects, b.rock_rects, "le rocce sono deterministiche per seed fisso")
	assert_eq(a.forest_rects, b.forest_rects, "le foreste sono deterministiche per seed fisso")
	assert_eq(a.obstacle_rects.size(), b.obstacle_rects.size(), "il numero di ostacoli e deterministico")
	assert_eq(a.fall_zone_rects, b.fall_zone_rects, "la void lottery e deterministica per seed fisso")
	assert_eq(a.random_prop_rects, b.random_prop_rects, "le posizioni prop sono deterministiche")
	assert_eq(a.random_prop_ids, b.random_prop_ids, "gli id prop sono deterministici")
	assert_eq(a.road_cell_tags.size(), b.road_cell_tags.size(), "il carving delle strade e deterministico")

# --- integrazione live (M6) -----------------------------------------------

func test_live_terrain_generator_integration() -> void:
	var generator := BiomeTerrainGenerator.new()
	add_child(generator)
	var cell := BiomeCell.new()
	cell.configure(&"voidfirst_integration_cell", _biome.biome_id, Vector2i.ZERO, _biome.get_biome_size(), 135790)
	var layout := generator.generate_layout_for_cell(cell, _biome)
	assert_not_null(layout, "il layout viene generato")
	if layout == null:
		generator.free()
		return

	var report := layout.validation_report
	assert_true(bool(report.get("is_valid", false)), "il layout void-first passa la validazione")
	assert_true((report.get("placement_errors", PackedStringArray()) as PackedStringArray).is_empty(),
		"nessun errore di placement spawn/crate")

	assert_eq(layout.get_terrain_class_at_cell(layout.player_spawn_cell, cell),
		BiomeEnvironmentLayout.TERRAIN_WALKABLE, "lo spawn player e walkable")
	assert_gt(layout.crate_cells.size(), 0, "almeno un crate e piazzato")
	var all_walkable := true
	for crate_cell in layout.crate_cells:
		if layout.get_terrain_class_at_cell(crate_cell, cell) != BiomeEnvironmentLayout.TERRAIN_WALKABLE:
			all_walkable = false
	assert_true(all_walkable, "ogni crate e su terreno walkable")
	assert_true(bool(layout.get_classification_report().get("is_complete", false)),
		"la classificazione copre tutto il chunk")

	var trees := 0
	var rocks := 0
	for obstacle_id in layout.obstacle_ids:
		if obstacle_id == &"forest_tree":
			trees += 1
		elif obstacle_id == &"large_rock":
			rocks += 1
	assert_lte(trees, 500, "numero alberi nel budget")
	assert_lte(layout.fall_zone_rects.size(), 220, "numero fall-zone nel budget")
	assert_lte(layout.obstacle_ids.size(), 900, "numero ostacoli nel budget")
	assert_eq(rocks, 1, "una sola montagna nel layout live")

	generator.free()

# --- helper ---------------------------------------------------------------

func _band_has_road(layout: BiomeEnvironmentLayout, rect: Rect2i) -> bool:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if layout.has_road_cell(Vector2i(x, y)):
				return true
	return false

func _rect_in_any(rect: Rect2i, rects: Array[Rect2i]) -> bool:
	for other in rects:
		if rect.intersects(other):
			return true
	return false

func _rect_near_road(layout: BiomeEnvironmentLayout, rect: Rect2i) -> bool:
	var near := WorldGridConfig.VOIDFIRST_ROAD_LINE_NEAR_TILES
	var band := Rect2i(rect.position - Vector2i(near, near), rect.size + Vector2i(near * 2, near * 2))
	for y in range(band.position.y, band.end.y):
		for x in range(band.position.x, band.end.x):
			if layout.has_road_cell(Vector2i(x, y)):
				return true
	return false

func _carve_straight_road(layout: BiomeEnvironmentLayout) -> void:
	var span_before := _span_before_center(WorldGridConfig.ROAD_WIDTH_TILES)
	var span_after := _span_after_center(WorldGridConfig.ROAD_WIDTH_TILES)
	var center_y := layout.zone_size.y / 2
	for x in range(WorldGridConfig.BORDER_THICKNESS_TILES, layout.zone_size.x - WorldGridConfig.BORDER_THICKNESS_TILES):
		for y in range(center_y - span_before, center_y + span_after):
			layout.add_road_cell(Vector2i(x, y), &"main_road")

func _span_before_center(span: int) -> int:
	return maxi(floori(float(span) * 0.5), 0)

func _span_after_center(span: int) -> int:
	return maxi(span - _span_before_center(span), 0)

func _center_offset(size: Vector2i) -> Vector2i:
	return Vector2i(_span_before_center(size.x), _span_before_center(size.y))

func _count_trees(layout: BiomeEnvironmentLayout) -> int:
	var count := 0
	for obstacle_id in layout.obstacle_ids:
		if obstacle_id == &"forest_tree":
			count += 1
	return count

func _area(rects: Array[Rect2i]) -> int:
	var total := 0
	for rect in rects:
		total += rect.size.x * rect.size.y
	return total
