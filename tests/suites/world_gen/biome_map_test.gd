extends GutTest
## World Generation A1 — Mappa biome, layout di cella, copertura terreno,
## persistenza del grafo e roster tematici.
##
## Migra e accorpa:
##   tests/isometric_biome_generation_rewrite_smoke_test.gd
##   tests/isometric_biome_terrain_coverage_smoke_test.gd
##   tests/persistent_world_generation_smoke_test.gd
##   tests/biome_roster_smoke_test.gd
##
## Ottimizzazione: l'intera mappa 3x3 (9 chunk 500x500) viene costruita UNA volta
## in before_all e riusata da tutti i test della suite.

const WorldGen = preload("res://tests/support/world_gen_helpers.gd")

const MAP_SEED := 515151
const BIOME_IDS := ["infected_plains", "toxic_wastes", "burning_fields", "frozen_outskirts", "drowned_marsh"]

var _manager: BiomeManager
var _manifest: IsometricEnvironmentManifest
var _cells: Array[BiomeCell] = []
var _sample_cells: Array[BiomeCell] = []

func before_all() -> void:
	_manifest = IsometricEnvironmentManifest.reload_shared()
	_manager = WorldGen.start_biome_manager(self, {
		"world_seed": MAP_SEED,
		"biome_map_width": 3,
		"biome_map_height": 3,
		"preserve_biome_sequence": false,
		"extra_edge_chance": 0.5
	}, "BiomeMapSharedManager")
	await wait_physics_frames(1)
	_cells = _manager.get_generated_biome_map()
	_sample_cells = WorldGen.first_cell_per_biome(_cells)

func after_all() -> void:
	WorldGen.free_biome_manager(_manager)
	_manager = null
	_cells = []
	_sample_cells = []

# --- struttura della mappa ------------------------------------------------

func test_map_generates_nine_cells() -> void:
	assert_eq(_cells.size(), 9, "la megamappa genera 9 regioni 3x3")
	assert_gte(_sample_cells.size(), 5, "la mappa campiona ogni biome esistente")

func test_generation_constants() -> void:
	assert_eq(ObstacleLayoutGenerator.ROAD_WIDTH, 40, "strada principale larga 40 celle")
	assert_eq(ObstacleLayoutGenerator.SECONDARY_ROAD_WIDTH, 20, "percorso secondario largo 20 celle")
	assert_eq(BiomePassageGenerator.PASSAGE_WIDTH, 40, "passaggio fisico largo 40 celle")

# --- invarianti di layout per cella campione ------------------------------

func test_sample_cells_layout_invariants() -> void:
	for cell in _sample_cells:
		var layout := cell.generated_layout
		assert_not_null(layout, "%s ha un layout generato" % String(cell.id))
		if layout == null:
			continue
		assert_eq(layout.zone_size, BiomeEnvironmentLayout.DEFAULT_ZONE_SIZE,
			"%s usa il chunk 500x500" % String(cell.id))
		if cell.biome_id != &"infected_plains":
			assert_eq(layout.player_spawn_cell, layout.zone_size / 2,
				"%s spawn player centrato sulla rete stradale" % String(cell.id))
		assert_eq(layout.get_terrain_class_at_cell(layout.player_spawn_cell, cell),
			BiomeEnvironmentLayout.TERRAIN_WALKABLE,
			"%s spawn player walkable" % String(cell.id))
		assert_false(layout.floor_rects.is_empty(),
			"%s ha blocchi di pavimento walkable carved" % String(cell.id))
		if cell.biome_id == &"infected_plains":
			assert_false(layout.rock_rects.is_empty(), "%s ha rocce void-first" % String(cell.id))
			assert_false(layout.forest_rects.is_empty(), "%s ha foreste void-first" % String(cell.id))
		else:
			assert_false(layout.block_rects.is_empty(), "%s ha blocchi interni procedurali" % String(cell.id))
			assert_true(layout.block_kinds.has(&"full_void") or layout.block_kinds.has(&"partial_void"),
				"%s mantiene blocchi void/fall nel chunk" % String(cell.id))
		assert_false(layout.fall_zone_rects.is_empty(), "%s ha zone di caduta/void" % String(cell.id))
		assert_false(layout.obstacle_rects.is_empty(), "%s ha oggetti isometrici bloccanti" % String(cell.id))
		assert_true(bool(layout.validation_report.get("is_valid", false)),
			"%s passa la validazione connettivita/placement" % String(cell.id))

func test_sample_cells_roads() -> void:
	for cell in _sample_cells:
		var layout := cell.generated_layout
		if layout == null:
			continue
		if cell.biome_id == &"infected_plains":
			# Connected void-first regions route roads as a central hub the passage
			# corridors converge on (no edge-to-edge cross). Regions with no passages
			# keep the cross for interior structure.
			if cell.passages.is_empty():
				assert_true(_has_main_road_cells(layout, true),
					"%s (senza passaggi) ha una strada principale verticale ai bordi" % String(cell.id))
				assert_true(_has_main_road_cells(layout, false),
					"%s (senza passaggi) ha una strada principale orizzontale ai bordi" % String(cell.id))
			else:
				assert_true(layout.get_road_tags_at_cell(layout.zone_size / 2).has(&"main_road"),
					"%s ha un hub stradale principale al centro" % String(cell.id))
		else:
			assert_true(_has_axis_road(layout, &"main_road", ObstacleLayoutGenerator.ROAD_WIDTH, true),
				"%s ha una main road verticale da %d celle" % [String(cell.id), ObstacleLayoutGenerator.ROAD_WIDTH])
			assert_true(_has_axis_road(layout, &"main_road", ObstacleLayoutGenerator.ROAD_WIDTH, false),
				"%s ha una main road orizzontale da %d celle" % [String(cell.id), ObstacleLayoutGenerator.ROAD_WIDTH])
			var path_tag := _expected_path_tag(cell.biome_id)
			assert_true(_has_axis_road(layout, path_tag, ObstacleLayoutGenerator.SECONDARY_ROAD_WIDTH, true),
				"%s ha un biome path verticale da %d celle" % [String(cell.id), ObstacleLayoutGenerator.SECONDARY_ROAD_WIDTH])
			assert_true(_has_axis_road(layout, path_tag, ObstacleLayoutGenerator.SECONDARY_ROAD_WIDTH, false),
				"%s ha un biome path orizzontale da %d celle" % [String(cell.id), ObstacleLayoutGenerator.SECONDARY_ROAD_WIDTH])

func test_sample_cells_passages_and_crates_walkable() -> void:
	for cell in _sample_cells:
		var layout := cell.generated_layout
		if layout == null:
			continue
		for passage in cell.passages:
			assert_eq(passage.width, BiomePassageGenerator.PASSAGE_WIDTH,
				"%s passaggio usa l'apertura fisica da %d celle" % [String(cell.id), BiomePassageGenerator.PASSAGE_WIDTH])
			var probe := WorldGen.passage_probe_cell(passage, layout.zone_size)
			assert_eq(layout.get_terrain_class_at_cell(probe, cell), BiomeEnvironmentLayout.TERRAIN_WALKABLE,
				"%s passaggio %s e walkable" % [String(cell.id), String(passage.side)])
		for crate_cell in layout.crate_cells:
			assert_eq(layout.get_terrain_class_at_cell(crate_cell, cell), BiomeEnvironmentLayout.TERRAIN_WALKABLE,
				"%s crate su terreno walkable" % String(cell.id))

# --- copertura/classificazione del terreno (tutte le 9 celle) -------------

func test_terrain_classification_complete() -> void:
	for cell in _cells:
		var layout := cell.generated_layout
		assert_not_null(layout, "%s ha layout" % String(cell.id))
		if layout == null:
			continue
		var report := layout.get_classification_report()
		var expected_total := layout.zone_size.x * layout.zone_size.y
		assert_true(bool(report.get("is_complete", false)), "%s classifica ogni tile" % String(cell.id))
		assert_eq(int(report.get("total", 0)), expected_total,
			"%s classificazione copre il chunk 500x500" % String(cell.id))
		var counts := report.get("counts", {}) as Dictionary
		var sum := 0
		for value in counts.values():
			sum += int(value)
		assert_eq(sum, expected_total, "%s i conteggi sommano alla dimensione del chunk" % String(cell.id))
		assert_gt(int(counts.get(BiomeEnvironmentLayout.TERRAIN_WALKABLE, 0)), 0,
			"%s ha terreno walkable" % String(cell.id))
		assert_gt(int(counts.get(BiomeEnvironmentLayout.TERRAIN_FALL_ZONE, 0)), 0,
			"%s ha celle void di fall-zone" % String(cell.id))
		assert_gt(int(counts.get(BiomeEnvironmentLayout.TERRAIN_OBSTACLE, 0)), 0,
			"%s ha celle obstacle" % String(cell.id))

# --- copertura terreno vs manifest ----------------------------------------

func test_manifest_terrain_inventory() -> void:
	assert_true(_manifest.load_error.is_empty(), "il manifest del terreno carica")
	assert_gte(_manifest.version, 4, "versione manifest terreno corrente")
	var manifest_report := _manifest.validate()
	assert_true(bool(manifest_report.get("is_valid", false)), "il manifest del terreno valida")

	var expected := {}
	_merge_tags(expected, ObstacleLayoutGenerator.get_generated_terrain_tag_categories())
	_merge_tags(expected, BiomePassageGenerator.get_generated_passage_terrain_tag_categories())
	for tag_key in expected.keys():
		var terrain_tag := StringName(tag_key)
		assert_true(_manifest.has_terrain_tag(terrain_tag),
			"tag terreno generato %s descritto nel manifest" % String(terrain_tag))
		if _manifest.has_terrain_tag(terrain_tag):
			assert_true(_manifest.terrain_tag_has_dedicated_draw(terrain_tag),
				"tag terreno %s ha draw dedicato" % String(terrain_tag))
			var style := _manifest.get_terrain_style(terrain_tag)
			assert_eq(StringName(style.get("category", &"")), StringName(expected[terrain_tag]),
				"categoria del tag terreno %s combacia col manifest" % String(terrain_tag))
	assert_eq(_manifest.get_terrain_sample_step(&"performance"), 12, "preset performance = 12")
	assert_eq(_manifest.get_terrain_sample_step(&"balanced"), 8, "preset balanced = 8")
	assert_eq(_manifest.get_terrain_sample_step(&"quality"), 4, "preset quality = 4")

func test_generated_tags_are_in_manifest() -> void:
	var generated_tags: Array[StringName] = []
	for cell in _cells:
		var layout := cell.generated_layout
		if layout == null:
			continue
		for terrain_tag in layout.terrain_patch_tags:
			if not generated_tags.has(terrain_tag):
				generated_tags.append(terrain_tag)
		for passage in cell.passages:
			if not generated_tags.has(passage.passage_type):
				generated_tags.append(passage.passage_type)
	assert_false(generated_tags.is_empty(), "i layout generati emettono tag terreno")
	for terrain_tag in generated_tags:
		assert_true(_manifest.has_terrain_tag(terrain_tag),
			"tag layout generato %s nel manifest" % String(terrain_tag))
		if _manifest.has_terrain_tag(terrain_tag):
			assert_true(_manifest.terrain_tag_has_dedicated_draw(terrain_tag),
				"tag strada/passaggio %s evita il fallback dirt" % String(terrain_tag))

# --- persistenza del grafo del mondo --------------------------------------

func test_world_graph_persistence() -> void:
	var graph := _manager.get_world_graph()
	assert_not_null(graph, "il grafo del mondo esiste")
	if graph == null:
		return
	assert_true(graph.is_graph_connected(), "il grafo del mondo persistente e connesso")

	var state := PersistentWorldState.new()
	state.configure(MAP_SEED, graph)
	state.set_current_region(&"biome_1_0", graph)
	state.mark_region_cleared(&"biome_0_0")
	state.set_region_runtime_value(&"biome_0_0", &"opened_crates", ["crate_a"])
	state.set_party_position(Vector2(128.0, -32.0))
	var saved := state.to_save_data()

	var restored := PersistentWorldState.new()
	restored.restore_save_data(saved)
	assert_eq(restored.seed_value, MAP_SEED, "il seed persiste")
	assert_eq(restored.graph_signature, graph.get_signature(), "la firma del grafo persiste")
	assert_eq(restored.current_region_id, &"biome_1_0", "la regione corrente persiste")
	assert_eq(restored.exploration_state.get_state(&"biome_0_0"),
		WorldExplorationState.STATE_CLEARED, "lo stato regione cleared persiste")
	assert_true((restored.get_region_runtime_state(&"biome_0_0").get("opened_crates", []) as Array).has("crate_a"),
		"lo stato runtime di regione persiste")
	assert_true(restored.party_position.is_equal_approx(Vector2(128.0, -32.0)),
		"la posizione della party persiste")

# --- roster tematico dei nemici per biome ---------------------------------

func test_biome_thematic_roster() -> void:
	var thematic := {
		&"toxic_wastes": [&"toxic_zombie", &"toxic_exploder"],
		&"burning_fields": [&"burned_zombie", &"fire_runner", &"fire_exploder"],
		&"frozen_outskirts": [&"frozen_zombie", &"ice_armored_zombie", &"heavy_slow_zombie"],
		&"drowned_marsh": [&"drowned_zombie", &"marsh_zombie", &"water_emerging_zombie"]
	}
	for id in BIOME_IDS:
		var biome := WorldGen.load_biome(id)
		assert_not_null(biome, "carica %s" % id)
		if biome == null:
			continue
		var found := false
		for i in range(16):
			var roster: Array = thematic.get(biome.biome_id, [biome.base_enemy_id]) as Array
			if roster.has(biome.resolve_enemy_id(4, i, 16)):
				found = true
		assert_true(found, "roster tematico per %s" % id)

# --- helper (porting dei test legacy) -------------------------------------

func _has_axis_road(layout: BiomeEnvironmentLayout, tag: StringName, width: int, vertical: bool) -> bool:
	for index in range(layout.road_rects.size()):
		if index >= layout.road_rect_tags.size() or layout.road_rect_tags[index] != tag:
			continue
		var rect := layout.road_rects[index]
		if vertical and rect.size.x == width and rect.size.y >= layout.zone_size.y - 8:
			return true
		if not vertical and rect.size.y == width and rect.size.x >= layout.zone_size.x - 8:
			return true
	return false

func _has_main_road_cells(layout: BiomeEnvironmentLayout, vertical: bool) -> bool:
	var z := layout.zone_size
	var low := false
	var high := false
	for key_value in layout.road_cell_tags.keys():
		var key := int(key_value)
		var cell := Vector2i(key % z.x, int(key / z.x))
		var raw_tags: Array = layout.road_cell_tags[key] as Array
		if not (raw_tags.has(&"main_road") or raw_tags.has("main_road")):
			continue
		if vertical:
			if cell.y <= 2:
				low = true
			if cell.y >= z.y - 3:
				high = true
		else:
			if cell.x <= 2:
				low = true
			if cell.x >= z.x - 3:
				high = true
	return low and high

func _expected_path_tag(biome_id: StringName) -> StringName:
	match biome_id:
		&"toxic_wastes":
			return &"service_lane"
		&"burning_fields":
			return &"ash_lane"
		&"frozen_outskirts":
			return &"packed_snow_path"
		&"drowned_marsh":
			return &"wooden_walkway"
		_:
			return &"broken_street"

func _merge_tags(target: Dictionary, source: Dictionary) -> void:
	for key in source.keys():
		target[StringName(key)] = StringName(source[key])
