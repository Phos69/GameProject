extends GutTest
## World Generation A1 — Mappa biome, layout di cella, copertura terreno,
## persistenza del grafo e roster tematici.
##
## Migra e accorpa:
##   tests/top_down_biome_generation_rewrite_smoke_test.gd
##   tests/top_down_biome_terrain_coverage_smoke_test.gd
##   tests/persistent_world_generation_smoke_test.gd
##   tests/biome_roster_smoke_test.gd
##
## Ottimizzazione: l'intera mappa 3x3 viene costruita UNA volta
## in before_all e riusata da tutti i test della suite.

const WorldGen = preload("res://tests/support/world_gen_helpers.gd")
const WorldGridConfig = preload("res://game/core/world_grid_config.gd")

const MAP_SEED := 515151
const BIOME_IDS := ["plains", "burning_plains", "frozen_tundra", "swamp"]

var _manager: BiomeManager
var _manifest: EnvironmentAssetManifest
var _cells: Array[BiomeCell] = []
var _sample_cells: Array[BiomeCell] = []

func before_all() -> void:
	_manifest = EnvironmentAssetManifest.reload_shared()
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
	assert_gte(_sample_cells.size(), 4, "la mappa campiona i quattro biomi attivi")

func test_generation_constants() -> void:
	assert_eq(BiomeEnvironmentLayout.DEFAULT_ZONE_SIZE, WorldGridConfig.BIOME_SIZE, "regioni logiche 75x75")
	assert_eq(WorldGridConfig.LEGACY_EQUIVALENT_SIZE_TILES, 450, "75 tile nuovi equivalgono a 450 tile legacy")
	assert_eq(ObstacleLayoutGenerator.ROAD_WIDTH, WorldGridConfig.ROAD_WIDTH_TILES, "strada principale larga 7 tile nuovi")
	assert_eq(ObstacleLayoutGenerator.SECONDARY_ROAD_WIDTH, WorldGridConfig.SECONDARY_ROAD_WIDTH_TILES, "percorso secondario largo 4 tile nuovi")
	assert_eq(BiomePassageGenerator.PASSAGE_WIDTH, WorldGridConfig.PASSAGE_WIDTH_TILES, "passaggio fisico largo 7 tile nuovi")

# --- invarianti di layout per cella campione ------------------------------

func test_sample_cells_layout_invariants() -> void:
	for cell in _sample_cells:
		var layout := cell.generated_layout
		assert_not_null(layout, "%s ha un layout generato" % String(cell.id))
		if layout == null:
			continue
		assert_eq(layout.zone_size, BiomeEnvironmentLayout.DEFAULT_ZONE_SIZE,
			"%s usa la regione 75x75" % String(cell.id))
		assert_eq(layout.get_terrain_class_at_cell(layout.player_spawn_cell, cell),
			BiomeEnvironmentLayout.TERRAIN_WALKABLE,
			"%s spawn player walkable" % String(cell.id))
		assert_false(layout.floor_rects.is_empty(),
			"%s ha blocchi di pavimento walkable carved" % String(cell.id))
		var parcel_report := layout.get_parcel_report()
		var parcel_counts := parcel_report.get("type_counts", {}) as Dictionary
		assert_between(layout.parcel_types.size(), 7, 10,
			"%s ha 7..10 lotti logici: %s" % [
				String(cell.id), str(layout.generation_summary.get("parcel_report", {}))
			])
		assert_eq(int(parcel_counts.get(BiomeEnvironmentLayout.PARCEL_MESA, 0)), 1,
			"%s ha esattamente una mesa" % String(cell.id))
		assert_eq(int(parcel_counts.get(BiomeEnvironmentLayout.PARCEL_TOWN, 0)), 1,
			"%s ha esattamente una town" % String(cell.id))
		assert_eq(layout.mesa_rects.size(), 1, "%s costruisce una montagna" % String(cell.id))
		assert_eq(layout.mesa_profile_ids.size(), layout.mesa_rects.size(),
			"%s ha un profilo per ogni mesa" % String(cell.id))
		for profile_id in layout.mesa_profile_ids:
			assert_eq(profile_id, _expected_mesa_profile(cell.biome_id),
				"%s usa il profilo mesa del bioma" % String(cell.id))
		assert_eq(layout.obstacle_ids.count(&"large_rock"), layout.mesa_rects.size(),
			"%s ha un blocker tecnico per ogni mesa" % String(cell.id))
		assert_true(layout.random_prop_rects.is_empty(),
			"%s disattiva lo scatter globale" % String(cell.id))
		var content := layout.generation_summary.get("parcel_content", {}) as Dictionary
		assert_between(int(content.get("town_building_count", 0)), 2, 4,
			"%s town con 2..4 edifici" % String(cell.id))
		assert_between(int(content.get("town_vehicle_count", 0)), 1, 3,
			"%s town con 1..3 veicoli" % String(cell.id))
		assert_false(layout.obstacle_rects.is_empty(), "%s ha oggetti top-down bloccanti" % String(cell.id))
		assert_true(bool(layout.validation_report.get("is_valid", false)),
			"%s passa la validazione: %s" % [String(cell.id), str(layout.validation_report)])

func test_town_content_uses_thematic_pools() -> void:
	for cell in _sample_cells:
		var layout := cell.generated_layout
		if layout == null:
			continue
		var expected_ids: Array[StringName] = _expected_town_ids(cell.biome_id)
		var found := 0
		for obstacle_id in layout.obstacle_ids:
			if expected_ids.has(obstacle_id):
				found += 1
		assert_gte(found, 3, "%s usa edifici e veicoli town tematizzati" % String(cell.id))

func test_sample_cells_roads() -> void:
	for cell in _sample_cells:
		var layout := cell.generated_layout
		if layout == null:
			continue
		# Every biome shares the void-first hub+spokes road model: connected regions
		# route roads as a central main-road hub the passage corridors converge on;
		# regions with no passages keep the edge-to-edge main-road cross. The thematic
		# lane (spoke_tag) skins the passage spokes, while main_road stays universal.
		if cell.passages.is_empty():
			assert_true(_has_main_road_cells(layout, true),
				"%s (senza passaggi) ha una strada principale verticale ai bordi" % String(cell.id))
			assert_true(_has_main_road_cells(layout, false),
				"%s (senza passaggi) ha una strada principale orizzontale ai bordi" % String(cell.id))
		else:
			assert_true(layout.get_road_tags_at_cell(layout.zone_size / 2).has(&"main_road"),
				"%s ha un hub stradale principale al centro" % String(cell.id))

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
			"%s classificazione copre tutta la regione" % String(cell.id))
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
	assert_eq(restored.terrain_generation_revision,
		PersistentWorldState.TERRAIN_GENERATION_REVISION,
		"il save registra la revisione terrain")

func test_legacy_terrain_save_preserves_progress_and_resets_layout_ledgers() -> void:
	var graph := _manager.get_world_graph()
	var current_cell := _cells[4]
	var anchor_cell := _cells[0]
	var state := PersistentWorldState.new()
	state.configure(MAP_SEED, graph)
	state.set_current_region(current_cell.id, graph)
	state.mark_region_cleared(anchor_cell.id)
	state.mark_region_item_consumed(
		current_cell.id, PersistentWorldState.CATEGORY_OPENED_CRATES, &"legacy_crate"
	)
	var legacy_save := state.to_save_data()
	legacy_save.erase("terrain_generation_revision")
	var restored := PersistentWorldState.new()
	restored.restore_save_data(legacy_save)
	assert_true(restored.migrate_terrain_if_needed(current_cell, anchor_cell),
		"un save senza revisione esegue la migrazione terrain")
	assert_eq(restored.seed_value, MAP_SEED, "la migrazione conserva il seed")
	assert_eq(restored.current_region_id, current_cell.id,
		"la migrazione conserva la regione corrente")
	assert_eq(restored.exploration_state.get_state(anchor_cell.id),
		WorldExplorationState.STATE_CLEARED,
		"la migrazione conserva esplorazione e progressione")
	assert_true(restored.get_region_runtime_state(current_cell.id).is_empty(),
		"la migrazione azzera i ledger dipendenti dal vecchio layout")
	var expected_offset := Vector2(current_cell.world_origin - anchor_cell.world_origin) \
		* current_cell.generated_layout.logical_tile_scale
	var expected_position := expected_offset + current_cell.generated_layout.logical_to_world(
		current_cell.generated_layout.player_spawn_cell
	)
	assert_true(restored.party_position.is_equal_approx(expected_position),
		"la migrazione sposta la party sullo spawn route-safe rigenerato")
	assert_false(restored.migrate_terrain_if_needed(current_cell, anchor_cell),
		"la migrazione terrain e one-shot")

# --- roster tematico dei nemici per biome ---------------------------------

func test_biome_thematic_roster() -> void:
	var thematic := {
		&"toxic_wastes": [&"toxic_zombie", &"toxic_exploder"],
		&"burning_plains": [&"burned_zombie", &"fire_runner", &"fire_exploder"],
		&"frozen_tundra": [&"frozen_zombie", &"ice_armored_zombie", &"heavy_slow_zombie"],
		&"swamp": [&"drowned_zombie", &"marsh_zombie", &"water_emerging_zombie"]
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
		if vertical and rect.size.x == width and rect.size.y >= layout.zone_size.y - WorldGridConfig.SIDE_EDGE_MAX_THICKNESS_TILES:
			return true
		if not vertical and rect.size.y == width and rect.size.x >= layout.zone_size.x - WorldGridConfig.SIDE_EDGE_MAX_THICKNESS_TILES:
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
			if cell.y <= WorldGridConfig.SIDE_EDGE_MAX_THICKNESS_TILES:
				low = true
			if cell.y >= z.y - WorldGridConfig.SIDE_EDGE_MAX_THICKNESS_TILES:
				high = true
		else:
			if cell.x <= WorldGridConfig.SIDE_EDGE_MAX_THICKNESS_TILES:
				low = true
			if cell.x >= z.x - WorldGridConfig.SIDE_EDGE_MAX_THICKNESS_TILES:
				high = true
	return low and high

func _expected_path_tag(biome_id: StringName) -> StringName:
	match biome_id:
		&"toxic_wastes":
			return &"service_lane"
		&"burning_plains":
			return &"ash_lane"
		&"frozen_tundra":
			return &"packed_snow_path"
		&"swamp":
			return &"wooden_walkway"
		_:
			return &"broken_street"

func _merge_tags(target: Dictionary, source: Dictionary) -> void:
	for key in source.keys():
		target[StringName(key)] = StringName(source[key])

func _has_internal_chasm(layout: BiomeEnvironmentLayout) -> bool:
	for index in range(layout.hazard_ids.size()):
		if layout.hazard_ids[index] != &"fall_zone":
			continue
		if index < layout.hazard_sides.size() and layout.hazard_sides[index] == &"internal":
			return true
	return false

func _prop_is_clear(layout: BiomeEnvironmentLayout, prop_index: int) -> bool:
	var rect := layout.random_prop_rects[prop_index]
	var prop_id := layout.random_prop_ids[prop_index]
	if rect.has_point(layout.player_spawn_cell):
		return false
	for crate_cell in layout.crate_cells:
		if rect.has_point(crate_cell):
			return false
	for mesa_rect in layout.mesa_rects:
		if rect.intersects(mesa_rect):
			return false
	for hazard_rect in layout.hazard_rects:
		if rect.intersects(hazard_rect):
			return false
	for passage_rect in layout.passage_rects + layout.passage_connector_rects:
		if rect.intersects(passage_rect):
			return false
	for road_rect in layout.road_rects:
		if rect.intersects(road_rect):
			return false
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var cell := Vector2i(x, y)
			if layout.has_road_cell(cell) or layout.get_floor_tag_at_cell(cell).is_empty():
				return false
	for index in range(layout.random_prop_rects.size()):
		if index != prop_index and rect.intersects(layout.random_prop_rects[index]):
			return false
	var skipped_self := false
	for index in range(layout.obstacle_rects.size()):
		if (
			not skipped_self
			and layout.obstacle_rects[index] == rect
			and index < layout.obstacle_ids.size()
			and layout.obstacle_ids[index] == prop_id
		):
			skipped_self = true
			continue
		if rect.intersects(layout.obstacle_rects[index]):
			return false
	return skipped_self

func _expected_random_prop_ids(biome_id: StringName) -> Array[StringName]:
	match biome_id:
		&"toxic_wastes":
			return [&"lab_ruin", &"chemical_barrel", &"toxic_barrel", &"pipe_stack", &"industrial_fence", &"lab_wall", &"corroded_barrier"]
		&"burning_plains":
			return [&"burned_house", &"burned_car", &"metal_wreck", &"charred_wall", &"ash_barrier", &"scorched_barricade"]
		&"frozen_tundra":
			return [&"snow_cabin", &"ice_rock", &"ice_block", &"snow_wall", &"fallen_log"]
		&"swamp":
			return [&"sunken_house", &"sunken_wreck", &"dead_tree", &"marsh_log", &"reed_wall", &"broken_walkway"]
		_:
			return [&"ruined_house", &"abandoned_house", &"abandoned_car", &"broken_fence", &"wood_barrier", &"small_rock", &"fallen_log"]

func _expected_town_ids(biome_id: StringName) -> Array[StringName]:
	match biome_id:
		&"toxic_wastes":
			return [&"lab_ruin", &"lab_block", &"abandoned_car"]
		&"burning_plains":
			return [&"burned_house", &"burned_car", &"metal_wreck"]
		&"frozen_tundra":
			return [&"snow_cabin", &"abandoned_car"]
		&"swamp":
			return [&"sunken_house", &"sunken_wreck"]
		_:
			return [&"ruined_house", &"abandoned_house", &"abandoned_car"]

func _expected_mesa_profile(biome_id: StringName) -> StringName:
	match biome_id:
		&"toxic_wastes":
			return &"urban_ruins"
		&"burning_plains":
			return &"burning_plains"
		&"frozen_tundra":
			return &"frozen_tundra"
		&"swamp":
			return &"swamp"
		_:
			return &"forest"
