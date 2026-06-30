extends GutTest
## Environment A2 — Tile layer asset-driven, props interni dei blocchi e muri
## perimetrali isometrici.
##
## Migra e accorpa:
##   tests/milestone_10_tile_layer_smoke_test.gd
##   tests/isometric_block_props_smoke_test.gd
##   tests/isometric_perimeter_wall_smoke_test.gd
##
## Ottimizzazione: una sola mappa 3x3 condivisa in before_all per gli invarianti
## per-cella; i casi standalone (void-edge gap, factory wall, integrazione
## TerrainGenerator) costruiscono scene/layout dedicati.

const WorldGen = preload("res://tests/support/world_gen_helpers.gd")

const MAP_SEED := 515151

const PROP_IDS_BY_BIOME: Dictionary = {
	&"toxic_wastes": [&"small_rock", &"toxic_barrel", &"industrial_fence"],
	&"burning_fields": [&"small_rock", &"ash_barrier", &"broken_fence"],
	&"frozen_outskirts": [&"ice_rock", &"fallen_log", &"small_rock"],
	&"drowned_marsh": [&"marsh_log", &"small_rock", &"reed_wall"]
}
const DEFAULT_PROP_IDS: Array = [&"small_rock", &"broken_fence", &"fallen_log"]

var _manager: BiomeManager
var _manifest: IsometricEnvironmentManifest
var _resolver: IsometricTileResolver
var _cells: Array[BiomeCell] = []
var _sample_cells: Array[BiomeCell] = []

func before_all() -> void:
	_manifest = IsometricEnvironmentManifest.reload_shared()
	_resolver = IsometricTileResolver.new(_manifest)
	_manager = WorldGen.start_biome_manager(self, {
		"world_seed": MAP_SEED, "biome_map_width": 3, "biome_map_height": 3,
		"preserve_biome_sequence": false, "extra_edge_chance": 0.5
	}, "TileLayoutManager")
	await wait_physics_frames(1)
	_cells = _manager.get_generated_biome_map()
	_sample_cells = WorldGen.first_cell_per_biome(_cells)

func after_all() -> void:
	WorldGen.free_biome_manager(_manager)
	_manager = null
	_cells = []
	_sample_cells = []

# --- manifest / contratti tile (tile_layer) -------------------------------

func test_manifest_and_required_contracts() -> void:
	assert_true(_manifest.load_error.is_empty(), "il manifest del tile layer carica")
	assert_gte(_manifest.version, 8, "il tile layer usa manifest v8")
	assert_true(bool(_manifest.validate().get("is_valid", false)), "il manifest del tile layer valida")
	for tile_id in _resolver.get_required_tile_ids():
		var section := _resolver.resolve_tile_section(tile_id)
		var contract := _manifest.get_asset_contract(section, tile_id)
		assert_false(contract.is_empty(), "%s ha un contratto asset" % String(tile_id))
		assert_true(_asset_exists(String(contract.get("asset_path", ""))), "%s file asset esiste" % String(tile_id))

func test_resolver_coverage() -> void:
	assert_gte(_sample_cells.size(), 5, "il tile layer campiona tutte le 5 palette biome")
	var saw_tile_ids: Dictionary = {}
	var saw_biome_ids: Dictionary = {}
	var saw_route_tile := false
	var saw_passage_endpoint := false
	var saw_void_edge := false
	var saw_void_depth := false
	var saw_hazard_floor := false
	var asset_exists_by_tile_id: Dictionary = {}
	var road_tile_errors: PackedStringArray = []
	for cell in _sample_cells:
		var layout := cell.generated_layout
		assert_not_null(layout, "%s ha layout generato" % String(cell.id))
		if layout == null:
			continue
		var biome_id := cell.biome_id
		saw_biome_ids[biome_id] = true
		var stable_probe := _find_first_floor_cell(layout, cell)
		var first_tile := _resolver.resolve_tile_id(layout, stable_probe, biome_id, &"balanced", cell)
		var second_tile := _resolver.resolve_tile_id(layout, stable_probe, biome_id, &"balanced", cell)
		assert_eq(first_tile, second_tile, "%s risolve la stessa cella allo stesso tile" % String(cell.id))
		var walkable_count := 0
		var missing_walkable := 0
		var missing_any := 0
		for y in range(layout.zone_size.y):
			for x in range(layout.zone_size.x):
				var probe := Vector2i(x, y)
				var terrain_class := layout.get_terrain_class_at_cell(probe, cell)
				var tile_id := _resolver.resolve_tile_id(layout, probe, biome_id, &"balanced", cell)
				if not asset_exists_by_tile_id.has(tile_id):
					asset_exists_by_tile_id[tile_id] = _asset_exists(String(_resolver.resolve_tile_contract(tile_id).get("asset_path", "")))
				saw_tile_ids[tile_id] = true
				if _resolver.is_route_tile_id(tile_id):
					saw_route_tile = true
				if String(tile_id).ends_with("_entry") or String(tile_id).ends_with("_exit"):
					saw_passage_endpoint = true
				elif _resolver.is_void_transition_tile_id(tile_id):
					saw_void_edge = true
				elif tile_id == IsometricTileResolver.TILE_VOID_DEPTH:
					saw_void_depth = true
				elif tile_id == IsometricTileResolver.TILE_HAZARD_FLOOR:
					saw_hazard_floor = true
				if tile_id.is_empty() or not bool(asset_exists_by_tile_id[tile_id]):
					missing_any += 1
				if terrain_class == BiomeEnvironmentLayout.TERRAIN_WALKABLE:
					walkable_count += 1
					if tile_id.is_empty() or not bool(asset_exists_by_tile_id[tile_id]):
						missing_walkable += 1
				if (
					terrain_class == BiomeEnvironmentLayout.TERRAIN_WALKABLE
					and (_cell_inside_any_rect(probe, layout.road_rects) or _cell_inside_any_rect(probe, layout.passage_rects) or layout.has_road_cell(probe))
					and not _resolver.is_route_tile_id(tile_id)
				):
					road_tile_errors.append("%s road cell %s -> %s" % [String(cell.id), str(probe), String(tile_id)])
		assert_gt(walkable_count, 0, "%s ha celle walkable" % String(cell.id))
		assert_eq(missing_walkable, 0, "%s nessuna cella walkable senza tile visivo" % String(cell.id))
		assert_eq(missing_any, 0, "%s risolve ogni cella a un tile con asset" % String(cell.id))
		assert_true(_manifest.get_biome_asset_set_contract(biome_id).has("asset_path"), "%s ha un asset set contract" % String(biome_id))
	assert_true(road_tile_errors.is_empty(), "ogni cella strada risolve a un route tile (%s)" % ", ".join(road_tile_errors))
	var void_depth_probe := _resolver.resolve_tile_id(_cells[0].generated_layout, Vector2i(-1, -1), _cells[0].biome_id, &"balanced", _cells[0])
	assert_eq(void_depth_probe, IsometricTileResolver.TILE_VOID_DEPTH, "celle fuori bound risolvono a void_depth")
	assert_gte(saw_biome_ids.size(), 5, "la coverage del resolver include 5 biome id")
	assert_true(saw_tile_ids.has(IsometricTileResolver.TILE_FLOOR_BASE), "resolver emette floor_base")
	assert_true(saw_tile_ids.has(IsometricTileResolver.TILE_FLOOR_VARIANT_01), "resolver emette floor_variant_01")
	assert_true(saw_tile_ids.has(IsometricTileResolver.TILE_FLOOR_VARIANT_02), "resolver emette floor_variant_02")
	assert_true(saw_route_tile, "resolver emette route tile per road e passage rects")
	assert_true(saw_passage_endpoint, "resolver emette tile endpoint per le aperture di bordo")
	assert_true(saw_void_edge, "resolver emette tile di transizione cliff neighbor-aware")
	assert_true(saw_void_depth or void_depth_probe == IsometricTileResolver.TILE_VOID_DEPTH, "resolver emette void_depth")
	assert_true(saw_hazard_floor, "resolver emette hazard_floor per le celle hazard")

func test_layer_chunking() -> void:
	var cell := _cells[0]
	var palette := _palette_for_biome(cell.biome_id)
	var layer := BiomeTileLayer.new()
	layer.configure(cell.generated_layout, palette, cell.biome_id, &"balanced", 20, _resolver, _manifest)
	var expected_tile_count := cell.generated_layout.zone_size.x * cell.generated_layout.zone_size.y
	var expected_chunk_count := int(ceil(float(cell.generated_layout.zone_size.x) / 20.0)) * int(ceil(float(cell.generated_layout.zone_size.y) / 20.0))
	assert_eq(layer.get_chunk_size(), 20, "il tile layer balanced usa chunk 20x20")
	assert_eq(layer.get_chunk_count(), expected_chunk_count, "il tile layer chunka l'intera regione 500x500")
	assert_eq(layer.get_visual_tile_count(), expected_tile_count, "il tile layer cachea tutte le celle visive")
	assert_eq(layer.get_missing_asset_count(), 0, "la cache del tile layer non ha celle senza asset")
	assert_false(layer.uses_procedural_fallback(), "il tile layer non usa il fallback procedurale")
	assert_gt(layer.get_suppressed_void_texture_count(), 0, "il tile layer omette le celle void pure dal mesh testurizzato")
	assert_gt(layer.get_cliff_transition_count(), 0, "il tile layer pre-bake le facce cliff per le transizioni fall-zone")
	var probe := _find_first_floor_cell(cell.generated_layout, cell)
	assert_eq(layer.get_resolved_tile_id(probe), _resolver.resolve_tile_id(cell.generated_layout, probe, cell.biome_id, &"balanced", cell),
		"la cache del tile layer combacia col resolver su una cella floor stabile")
	assert_true(layer.has_visual_tile_for_cell(probe), "il tile layer restituisce un asset visivo per la cella floor stabile")
	layer.free()

	var performance_layer := BiomeTileLayer.new()
	performance_layer.configure(cell.generated_layout, palette, cell.biome_id, &"performance", 0, _resolver, _manifest)
	assert_eq(performance_layer.get_chunk_size(), 25, "il preset performance usa chunk piu grandi")
	assert_lt(_resolver.get_floor_variants_for_preset(&"performance").size(), _resolver.get_floor_variants_for_preset(&"quality").size(),
		"il preset performance riduce le varianti floor rispetto a quality")
	performance_layer.free()

func test_terrain_generator_integration() -> void:
	var scene := Node2D.new()
	scene.name = "TileLayerIntegrationScene"
	var container := Node2D.new()
	container.name = "EnvironmentProps"
	scene.add_child(container)
	add_child(scene)

	var terrain_generator := TerrainGenerator.new()
	terrain_generator.environment_container_path = NodePath("../EnvironmentProps")
	terrain_generator.region_ground_quality_preset = "balanced"
	scene.add_child(terrain_generator)
	await wait_physics_frames(1)

	var biome := _manager.get_current_biome() as BiomeDefinition
	terrain_generator.start_run(biome)
	var layer := terrain_generator.get_active_tile_layer()
	assert_not_null(layer, "TerrainGenerator crea BiomeTileLayer come ground primario")
	assert_not_null(container.get_node_or_null("BiomeTileLayer"), "BiomeTileLayer e aggiunto al container environment")
	if layer != null:
		var expected_tile_count := biome.environment_layout.zone_size.x * biome.environment_layout.zone_size.y
		assert_eq(layer.get_visual_tile_count(), expected_tile_count, "il tile layer di TerrainGenerator copre l'intera regione")
		assert_eq(layer.get_missing_asset_count(), 0, "il tile layer di TerrainGenerator non ha asset mancanti")
	terrain_generator.stop_run()
	await wait_physics_frames(1)
	var leftover := container.get_node_or_null("BiomeTileLayer")
	assert_true(leftover == null or (leftover as Node).is_queued_for_deletion(), "TerrainGenerator rimuove il tile layer allo stop")
	scene.free()

# --- props interni dei blocchi (block_props) ------------------------------

func test_block_props() -> void:
	for cell in _sample_cells:
		var layout := cell.generated_layout
		if layout == null:
			assert_not_null(layout, "%s ha layout generato" % String(cell.id))
			continue
		if layout.block_rects.is_empty():
			assert_true(bool(layout.validation_report.get("is_valid", false)),
				"%s senza block props resta valido" % String(cell.id))
			continue
		var prop_pool: Array = PROP_IDS_BY_BIOME.get(cell.biome_id, DEFAULT_PROP_IDS)
		var prop_count := 0
		for index in range(layout.obstacle_rects.size()):
			var obstacle_id := layout.obstacle_ids[index] if index < layout.obstacle_ids.size() else &""
			if not prop_pool.has(obstacle_id):
				continue
			var rect: Rect2i = layout.obstacle_rects[index]
			if not _rect_inside_any(rect, layout.block_rects):
				continue
			prop_count += 1
			assert_false(_any_intersects_rects(rect, layout.road_rects), "%s prop %s fuori dalla rete stradale" % [String(cell.id), String(obstacle_id)])
			assert_false(_any_intersects_rects(rect, layout.fall_zone_rects), "%s prop %s fuori dalle fall zone" % [String(cell.id), String(obstacle_id)])
		assert_gte(prop_count, 3, "%s sparge props tematici nei blocchi (trovati %d)" % [String(cell.id), prop_count])
		assert_true(bool(layout.validation_report.get("is_valid", false)), "%s resta valido con i block props" % String(cell.id))

# --- muri perimetrali (perimeter_wall) ------------------------------------

func test_perimeter_walls() -> void:
	# Build dedicata al seed nativo del test legacy: la copertura dei muri
	# dipende dall'esatta disposizione di passaggi/void, quindi e seed-sensitive.
	var manager := WorldGen.start_biome_manager(self, {
		"world_seed": 906500, "biome_map_width": 3, "biome_map_height": 3,
		"preserve_biome_sequence": false, "extra_edge_chance": 0.5
	}, "PerimeterWallManager")
	await wait_physics_frames(1)
	var sample_cells := WorldGen.first_cell_per_biome(manager.get_generated_biome_map())
	for cell in sample_cells:
		var layout := cell.generated_layout
		assert_not_null(layout, "%s ha layout generato" % String(cell.id))
		if layout == null:
			continue
		assert_false(layout.wall_segment_rects.is_empty(), "%s registra segmenti di muro perimetrale espliciti" % String(cell.id))
		assert_gte(layout.wall_height_cells, 4, "%s muri perimetrali con contratto verticale alto" % String(cell.id))
		for side in BiomeCell.SIDES:
			var segments := layout.get_wall_segments_for_side(side)
			var border_type := cell.get_border(side)
			var vertical := side == &"west" or side == &"east"
			var axis_limit := layout.zone_size.y if vertical else layout.zone_size.x
			if border_type == BiomeCell.BorderType.FALL:
				assert_true(segments.is_empty(), "%s lato %s fall espone il void, niente muro" % [String(cell.id), String(side)])
				continue
			assert_false(segments.is_empty(), "%s lato %s mantiene segmenti di muro fuori dalle aperture" % [String(cell.id), String(side)])
			var covered := _covered_axis_length(segments, vertical)
			var expected_span := _expected_wall_axis_span(cell, side, axis_limit)
			assert_true(_segments_stay_inside_axis_span(segments, vertical, expected_span),
				"%s lato %s muro non renderizza sopra gli angoli fall adiacenti" % [String(cell.id), String(side)])
			var passages := cell.get_passages_for_side(side)
			var edge_void_rects := _fall_rects_touching_side(layout, side)
			for void_rect in edge_void_rects:
				assert_false(_any_intersects(segments, void_rect), "%s lato %s apertura void libera da muro" % [String(cell.id), String(side)])
			if passages.is_empty() and edge_void_rects.is_empty():
				assert_gte(covered, expected_span.y - expected_span.x - 1, "%s lato %s muro copre tutto il lato" % [String(cell.id), String(side)])
			elif passages.is_empty():
				assert_lt(covered, expected_span.y - expected_span.x, "%s lato %s muro si ferma dove il void raggiunge il bordo mondo" % [String(cell.id), String(side)])
			else:
				assert_true(covered > 0 and covered < axis_limit, "%s lato %s muro lascia un varco di passaggio" % [String(cell.id), String(side)])
				for passage in passages:
					var passage_rect: Rect2i = passage.get_local_rect(layout.zone_size)
					assert_false(_any_intersects(segments, passage_rect), "%s lato %s apertura passaggio libera da collisioni muro" % [String(cell.id), String(side)])
	WorldGen.free_biome_manager(manager)

func test_perimeter_void_world_edge_gap() -> void:
	var layout := BiomeEnvironmentLayout.new()
	layout.zone_size = Vector2i(80, 80)
	var cell := BiomeCell.new()
	cell.configure(&"void_edge_gap", &"infected_plains", Vector2i.ZERO, layout.zone_size, 17)
	for side in BiomeCell.SIDES:
		cell.set_border(side, BiomeCell.BorderType.BLOCKED)
	var generator := ObstacleLayoutGenerator.new()
	generator._apply_block_surface(layout, Rect2i(Vector2i(18, ObstacleLayoutGenerator.BORDER_THICKNESS), Vector2i(30, 24)), &"full_void", &"infected_plains")
	var void_rect: Rect2i = layout.fall_zone_rects.front()
	assert_eq(void_rect.position.y, 0, "il full void e esteso attraverso il bordo esterno")
	generator._add_connected_border_walls(layout, cell, null)
	layout.rebuild_terrain_classification(cell)
	assert_false(_any_intersects(layout.get_wall_segments_for_side(&"north"), void_rect),
		"il muro perimetrale e omesso dove il full void raggiunge il bordo mondo nord")
	assert_eq(layout.get_terrain_class_at_cell(Vector2i(24, 0), cell), BiomeEnvironmentLayout.TERRAIN_FALL_ZONE,
		"le celle al bordo mondo dentro l'apertura restano void puro")

func test_perimeter_wall_factory_render() -> void:
	var factory = load("res://game/modes/zombie/isometric_environment_object_factory.gd").new()
	var wall = factory.create_obstacle(&"boundary_fence", Vector2(96.0, 32.0), &"rectangle", 0.0, Color(0.4, 0.4, 0.4, 1.0), Color(0.8, 0.7, 0.4, 1.0))
	assert_not_null(wall, "la factory costruisce un ostacolo muro perimetrale")
	if wall == null:
		return
	assert_true(wall.is_perimeter_wall(), "l'ostacolo di bordo e flaggato come muro perimetrale")
	assert_gt(wall.get_wall_height(), 32.0, "il muro perimetrale renderizza piu alto del suo spessore")
	assert_eq(
		wall.get_perimeter_visual_style(),
		BiomeEnvironmentLayout.PERIMETER_VISUAL_WALL,
		"il factory wall generico mantiene il renderer procedurale di default"
	)
	assert_false(wall.has_raised_cliff_art(), "il factory wall generico non carica cliff art fuori dal profilo arena")
	if wall.has_method("uses_procedural_fallback"):
		assert_true(bool(wall.call("uses_procedural_fallback")), "il muro perimetrale usa il volume iso procedurale tileabile")
	wall.free()

# --- helper ---------------------------------------------------------------

func _palette_for_biome(biome_id: StringName) -> BiomePalette:
	match biome_id:
		&"toxic_wastes":
			return load("res://game/modes/zombie/biomes/toxic_wastes_palette.tres") as BiomePalette
		&"burning_fields":
			return load("res://game/modes/zombie/biomes/burning_fields_palette.tres") as BiomePalette
		&"frozen_outskirts":
			return load("res://game/modes/zombie/biomes/frozen_outskirts_palette.tres") as BiomePalette
		&"drowned_marsh":
			return load("res://game/modes/zombie/biomes/drowned_marsh_palette.tres") as BiomePalette
		_:
			return load("res://game/modes/zombie/biomes/infected_plains_palette.tres") as BiomePalette

func _find_first_floor_cell(layout: BiomeEnvironmentLayout, cell: BiomeCell) -> Vector2i:
	for y in range(layout.zone_size.y):
		for x in range(layout.zone_size.x):
			var probe := Vector2i(x, y)
			var tile_id := _resolver.resolve_tile_id(layout, probe, cell.biome_id, &"balanced", cell)
			if tile_id == IsometricTileResolver.TILE_FLOOR_BASE or tile_id == IsometricTileResolver.TILE_FLOOR_VARIANT_01 or tile_id == IsometricTileResolver.TILE_FLOOR_VARIANT_02:
				return probe
	return Vector2i(layout.zone_size.x / 2, layout.zone_size.y / 2)

func _cell_inside_any_rect(cell: Vector2i, rects: Array[Rect2i]) -> bool:
	for rect in rects:
		if rect.has_point(cell):
			return true
	return false

func _rect_inside_any(rect: Rect2i, rects: Array[Rect2i]) -> bool:
	var center := rect.position + rect.size / 2
	for other in rects:
		if other.has_point(center):
			return true
	return false

func _any_intersects_rects(rect: Rect2i, rects: Array[Rect2i]) -> bool:
	for other in rects:
		if rect.intersects(other):
			return true
	return false

func _asset_exists(asset_path: String) -> bool:
	if asset_path.is_empty():
		return false
	return ResourceLoader.exists(asset_path) or FileAccess.file_exists(asset_path)

func _fall_rects_touching_side(layout: BiomeEnvironmentLayout, side: StringName) -> Array[Rect2i]:
	var result: Array[Rect2i] = []
	for rect in layout.fall_zone_rects:
		var touches := false
		match side:
			&"north":
				touches = rect.position.y <= 0
			&"south":
				touches = rect.end.y >= layout.zone_size.y
			&"west":
				touches = rect.position.x <= 0
			_:
				touches = rect.end.x >= layout.zone_size.x
		if touches:
			result.append(rect)
	return result

func _covered_axis_length(segments: Array[Rect2i], vertical: bool) -> int:
	var intervals: Array[Vector2i] = []
	for rect in segments:
		if vertical:
			intervals.append(Vector2i(rect.position.y, rect.position.y + rect.size.y))
		else:
			intervals.append(Vector2i(rect.position.x, rect.position.x + rect.size.x))
	intervals.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x)
	var covered := 0
	var cursor := -1
	for interval in intervals:
		var start := maxi(interval.x, cursor)
		if interval.y > start:
			covered += interval.y - start
			cursor = interval.y
		elif interval.y > cursor:
			cursor = interval.y
	return covered

func _expected_wall_axis_span(cell: BiomeCell, side: StringName, axis_limit: int) -> Vector2i:
	var vertical := side == &"west" or side == &"east"
	var start_side := &"north" if vertical else &"west"
	var end_side := &"south" if vertical else &"east"
	var start := 0
	var finish := axis_limit
	if cell.get_border(start_side) == BiomeCell.BorderType.FALL:
		start += FallBoundaryGenerator.FALL_THICKNESS
	if cell.get_border(end_side) == BiomeCell.BorderType.FALL:
		finish -= FallBoundaryGenerator.FALL_THICKNESS
	return Vector2i(start, finish)

func _segments_stay_inside_axis_span(segments: Array[Rect2i], vertical: bool, span: Vector2i) -> bool:
	for rect in segments:
		var start := rect.position.y if vertical else rect.position.x
		var finish := start + (rect.size.y if vertical else rect.size.x)
		if start < span.x or finish > span.y:
			return false
	return true

func _any_intersects(segments: Array[Rect2i], other: Rect2i) -> bool:
	for rect in segments:
		if rect.intersects(other):
			return true
	return false
