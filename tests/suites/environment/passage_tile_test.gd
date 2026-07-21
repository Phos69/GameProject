extends GutTest
## Environment A2 — Tile dei passaggi, dati di connessione del grafo e layout
## delle aperture.
##
## Migra: tests/milestone_10_passage_tile_smoke_test.gd
## Build 3x3 condivisa in before_all (seed 641004).

const WorldGen = preload("res://tests/support/world_gen_helpers.gd")
const WorldGridConfig = preload("res://game/core/world_grid_config.gd")

const WORLD_CONTEXT := {
	"world_seed": 641004, "biome_map_width": 3, "biome_map_height": 3,
	"preserve_biome_sequence": false, "extra_edge_chance": 0.42
}
const REQUIRED_TERRAIN_TILES: Array[StringName] = [
	&"main_road", &"road", &"service_lane", &"ash_lane", &"packed_snow_path", &"wooden_walkway",
	&"bridge", &"snow_pass", &"broken_gate", &"burned_road", &"road_intersection", &"road_edge",
	&"road_curve_north", &"road_curve_east", &"road_curve_south", &"road_curve_west"
]
const REQUIRED_PASSAGE_TILES: Array[StringName] = [
	&"road", &"bridge", &"snow_pass", &"broken_gate", &"burned_road", &"road_entry", &"road_exit",
	&"bridge_entry", &"bridge_exit", &"snow_pass_entry", &"snow_pass_exit", &"broken_gate_entry",
	&"broken_gate_exit", &"burned_road_entry", &"burned_road_exit", &"bridge_broken", &"cliff_ramp"
]

var _manager: BiomeManager
var _manifest: EnvironmentAssetManifest
var _resolver: BiomeTileResolver
var _cells: Array[BiomeCell] = []
var _graph: WorldGraph

func before_all() -> void:
	_manifest = EnvironmentAssetManifest.reload_shared()
	_resolver = BiomeTileResolver.new(_manifest)
	_manager = WorldGen.start_biome_manager(self, WORLD_CONTEXT, "PassageTileManager")
	await wait_physics_frames(1)
	_cells = _manager.get_generated_biome_map()
	_graph = _manager.get_world_graph()

func after_all() -> void:
	WorldGen.free_biome_manager(_manager)
	_manager = null
	_cells = []
	_graph = null

func test_manifest_passage_contracts() -> void:
	assert_true(_manifest.load_error.is_empty(), "il manifest dei passage tile carica")
	assert_gte(_manifest.version, 7, "usa manifest v7")
	assert_true(bool(_manifest.validate().get("is_valid", false)), "il manifest valida")
	for tile_id in REQUIRED_TERRAIN_TILES:
		_assert_asset_contract(&"terrain_tiles", tile_id)
	for tile_id in REQUIRED_PASSAGE_TILES:
		_assert_asset_contract(&"passage_tiles", tile_id)

func test_map_and_graph() -> void:
	assert_eq(_cells.size(), 9, "genera una mappa 3x3")
	assert_not_null(_graph, "genera un world graph")
	if _graph != null:
		assert_true(_graph.is_graph_connected(), "il world graph resta connesso")

func test_connection_data() -> void:
	if _graph == null:
		return
	for connection in _graph.connections:
		var source := _graph.get_region(connection.from_region_id)
		var target := _graph.get_region(connection.to_region_id)
		assert_true(source != null and target != null, "%s connette regioni esistenti" % String(connection.connection_id))
		if source == null or target == null:
			continue
		assert_eq(connection.entry_tile_id, _entry_id_for_type(connection.passage_type), "%s memorizza entry tile id" % String(connection.connection_id))
		assert_eq(connection.exit_tile_id, _exit_id_for_type(connection.passage_type), "%s memorizza exit tile id" % String(connection.connection_id))
		assert_eq(connection.world_rect, Rect2i(source.world_origin + connection.local_rect.position, connection.local_rect.size),
			"%s apertura sorgente usa l'origine globale sorgente" % String(connection.connection_id))
		assert_eq(connection.target_world_rect, Rect2i(target.world_origin + connection.target_local_rect.position, connection.target_local_rect.size),
			"%s apertura target usa l'origine globale target" % String(connection.connection_id))
		assert_eq(connection.world_connector_rect, Rect2i(source.world_origin + connection.connector_local_rect.position, connection.connector_local_rect.size),
			"%s connector sorgente usa l'origine globale sorgente" % String(connection.connection_id))
		assert_eq(connection.target_world_connector_rect, Rect2i(target.world_origin + connection.target_connector_local_rect.position, connection.target_connector_local_rect.size),
			"%s connector target usa l'origine globale target" % String(connection.connection_id))
		assert_true(_world_openings_touch(connection), "%s aperture sorgente e target si toccano in world coords" % String(connection.connection_id))
		assert_true(_world_connectors_touch(connection), "%s connector sorgente e target si toccano in world coords" % String(connection.connection_id))
		assert_true(_opening_span_is_coherent(connection), "%s lo span dell'apertura combacia sui due lati" % String(connection.connection_id))

func test_saved_connection_round_trip() -> void:
	if _graph == null:
		return
	var restored := WorldGraph.from_save_data(_graph.to_save_data())
	assert_eq(restored.connections.size(), _graph.connections.size(), "il grafo salvato preserva le connessioni direzionali")
	for index in range(mini(restored.connections.size(), _graph.connections.size())):
		var before := _graph.connections[index]
		var after := restored.connections[index]
		assert_eq(after.entry_tile_id, before.entry_tile_id, "%s save mantiene entry tile" % String(before.connection_id))
		assert_eq(after.exit_tile_id, before.exit_tile_id, "%s save mantiene exit tile" % String(before.connection_id))
		assert_eq(after.world_connector_rect, before.world_connector_rect, "%s save mantiene il connector rect sorgente" % String(before.connection_id))
		assert_eq(after.target_world_connector_rect, before.target_world_connector_rect, "%s save mantiene il connector rect target" % String(before.connection_id))

func test_passage_layout() -> void:
	var side_counts: Dictionary = {}
	var passage_types: Dictionary = {}
	var saw_entry := false
	var saw_exit := false
	var saw_connector := false
	var saw_curve_or_edge := false
	for cell in _cells:
		var layout := cell.generated_layout
		assert_not_null(layout, "%s ha layout generato" % String(cell.id))
		if layout == null:
			continue
		for passage in cell.passages:
			side_counts[passage.side] = int(side_counts.get(passage.side, 0)) + 1
			passage_types[passage.passage_type] = true
			_assert_passage_rects(cell, layout, passage)
			_assert_passage_endpoint_tiles(cell, layout, passage)
			_assert_passage_connector_tiles(cell, layout, passage)
			saw_entry = saw_entry or _passage_inner_probe_emits_entry(cell, layout, passage)
			saw_exit = saw_exit or _passage_outer_probe_emits_exit(cell, layout, passage)
			saw_connector = saw_connector or _passage_connector_probe_emits_type(cell, layout, passage)
		saw_curve_or_edge = saw_curve_or_edge or _layout_emits_road_connector(cell, layout)
	for side in [&"north", &"south", &"east", &"west"]:
		assert_gt(int(side_counts.get(side, 0)), 0, "copre i passaggi %s" % String(side))
	for passage_type_key in passage_types.keys():
		assert_true(REQUIRED_PASSAGE_TILES.has(StringName(passage_type_key)), "tipo passaggio %s supportato" % String(passage_type_key))
	assert_gte(passage_types.size(), 2, "genera piu tipi di passaggio")
	assert_true(saw_entry, "il resolver emette tile entry dei passaggi")
	assert_true(saw_exit, "il resolver emette tile exit dei passaggi")
	assert_true(saw_connector, "il resolver emette tile connector dedicati")
	assert_true(saw_curve_or_edge, "il resolver emette tile connector stradali")

# --- helper (porting dal test legacy) -------------------------------------

func _assert_passage_rects(cell: BiomeCell, layout: BiomeEnvironmentLayout, passage: BiomePassage) -> void:
	var zone_size := cell.get_zone_size()
	var local_rect := passage.get_local_rect(zone_size)
	var connector_rect := passage.get_connector_rect(zone_size)
	var expected_span := passage.width
	var expected_edge_depth := WorldGridConfig.PASSAGE_EDGE_DEPTH_TILES
	if passage.side == &"north" or passage.side == &"south":
		assert_eq(local_rect.size.x, expected_span, "%s %s larghezza apertura == span passaggio" % [String(cell.id), String(passage.side)])
		assert_eq(local_rect.size.y, expected_edge_depth, "%s %s apertura mantiene la profondita di bordo" % [String(cell.id), String(passage.side)])
	else:
		assert_eq(local_rect.size.y, expected_span, "%s %s altezza apertura == span passaggio" % [String(cell.id), String(passage.side)])
		assert_eq(local_rect.size.x, expected_edge_depth, "%s %s apertura mantiene la profondita di bordo" % [String(cell.id), String(passage.side)])
	assert_true(_rect_inside_any(local_rect, layout.passage_rects), "%s %s passage rect registrato" % [String(cell.id), String(passage.side)])
	assert_eq(passage.get_global_local_rect(zone_size), Rect2i(cell.world_origin + local_rect.position, local_rect.size),
		"%s %s apertura locale ha coordinate globali" % [String(cell.id), String(passage.side)])
	assert_eq(passage.get_global_connector_rect(zone_size), Rect2i(cell.world_origin + connector_rect.position, connector_rect.size),
		"%s %s connector ha coordinate globali" % [String(cell.id), String(passage.side)])
	assert_eq(_passage_cells_overlap(cell, layout, local_rect), "", "%s apertura senza overlap con terreno bloccato" % String(cell.id))
	assert_eq(_passage_cells_overlap(cell, layout, connector_rect), "", "%s connector senza overlap con terreno bloccato" % String(cell.id))

func _passage_cells_overlap(cell: BiomeCell, layout: BiomeEnvironmentLayout, rect: Rect2i) -> String:
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			var probe := Vector2i(x, y)
			var terrain_class := layout.get_terrain_class_at_cell(probe, cell)
			if terrain_class == BiomeEnvironmentLayout.TERRAIN_FALL_ZONE or terrain_class == BiomeEnvironmentLayout.TERRAIN_OBSTACLE or terrain_class == BiomeEnvironmentLayout.TERRAIN_BORDER or terrain_class == BiomeEnvironmentLayout.TERRAIN_VOID:
				return "%s cell %s overlaps %s" % [String(cell.id), str(probe), String(terrain_class)]
	return ""

func _assert_passage_endpoint_tiles(cell: BiomeCell, layout: BiomeEnvironmentLayout, passage: BiomePassage) -> void:
	var outer_probe := _outer_probe(passage.get_local_rect(cell.get_zone_size()), passage.side)
	var inner_probe := _inner_probe(passage.get_local_rect(cell.get_zone_size()), passage.side)
	var outer_data := _resolver.resolve_tile_data(layout, outer_probe, cell.biome_id, &"balanced", cell)
	var inner_data := _resolver.resolve_tile_data(layout, inner_probe, cell.biome_id, &"balanced", cell)
	assert_eq(StringName(outer_data.get("tile_id", &"")), passage.get_exit_tile_id(), "%s %s apertura esterna usa exit tile" % [String(cell.id), String(passage.side)])
	assert_eq(StringName(inner_data.get("tile_id", &"")), passage.get_entry_tile_id(), "%s %s apertura interna usa entry tile" % [String(cell.id), String(passage.side)])
	assert_eq(StringName(outer_data.get("section", &"")), BiomeTileResolver.TILE_SECTION_PASSAGE, "%s %s exit tile e un asset passaggio" % [String(cell.id), String(passage.side)])
	assert_eq(StringName(inner_data.get("section", &"")), BiomeTileResolver.TILE_SECTION_PASSAGE, "%s %s entry tile e un asset passaggio" % [String(cell.id), String(passage.side)])

func _assert_passage_connector_tiles(cell: BiomeCell, layout: BiomeEnvironmentLayout, passage: BiomePassage) -> void:
	var connector_rect := passage.get_connector_rect(cell.get_zone_size())
	var probe := _connector_probe_away_from_opening(connector_rect, passage.side)
	var tile_data := _resolver.resolve_tile_data(layout, probe, cell.biome_id, &"balanced", cell)
	assert_eq(StringName(tile_data.get("tile_id", &"")), passage.passage_type, "%s %s connector usa tile del tipo passaggio" % [String(cell.id), String(passage.side)])
	assert_eq(StringName(tile_data.get("section", &"")), BiomeTileResolver.TILE_SECTION_PASSAGE, "%s %s connector e un asset passaggio" % [String(cell.id), String(passage.side)])

func _passage_inner_probe_emits_entry(cell: BiomeCell, layout: BiomeEnvironmentLayout, passage: BiomePassage) -> bool:
	var probe := _inner_probe(passage.get_local_rect(cell.get_zone_size()), passage.side)
	return _resolver.resolve_tile_id(layout, probe, cell.biome_id, &"balanced", cell) == passage.get_entry_tile_id()

func _passage_outer_probe_emits_exit(cell: BiomeCell, layout: BiomeEnvironmentLayout, passage: BiomePassage) -> bool:
	var probe := _outer_probe(passage.get_local_rect(cell.get_zone_size()), passage.side)
	return _resolver.resolve_tile_id(layout, probe, cell.biome_id, &"balanced", cell) == passage.get_exit_tile_id()

func _passage_connector_probe_emits_type(cell: BiomeCell, layout: BiomeEnvironmentLayout, passage: BiomePassage) -> bool:
	var connector_rect := passage.get_connector_rect(cell.get_zone_size())
	var probe := _connector_probe_away_from_opening(connector_rect, passage.side)
	return _resolver.resolve_tile_id(layout, probe, cell.biome_id, &"balanced", cell) == passage.passage_type

func _layout_emits_road_connector(cell: BiomeCell, layout: BiomeEnvironmentLayout) -> bool:
	for road_cell in layout.get_road_cells():
		if _is_road_connector_tile(_resolver.resolve_tile_id(layout, road_cell, cell.biome_id, &"balanced", cell)):
			return true
	for index in range(layout.road_rects.size()):
		if index >= layout.road_rect_tags.size():
			continue
		if _is_passage_tag(layout.road_rect_tags[index]):
			continue
		var rect := layout.road_rects[index]
		for probe in [
			rect.position,
			rect.position + Vector2i(
				_span_before_center(rect.size.x),
				_span_before_center(rect.size.y)
			),
			rect.position + rect.size - Vector2i.ONE
		]:
			if _is_road_connector_tile(_resolver.resolve_tile_id(layout, probe, cell.biome_id, &"balanced", cell)):
				return true
	return false

func _is_road_connector_tile(tile_id: StringName) -> bool:
	return (
		tile_id == BiomeTileResolver.TILE_ROAD_EDGE
		or tile_id == BiomeTileResolver.TILE_ROAD_INTERSECTION
		or tile_id == BiomeTileResolver.TILE_ROAD_CURVE_NORTH
		or tile_id == BiomeTileResolver.TILE_ROAD_CURVE_EAST
		or tile_id == BiomeTileResolver.TILE_ROAD_CURVE_SOUTH
		or tile_id == BiomeTileResolver.TILE_ROAD_CURVE_WEST
		or tile_id == BiomeTileResolver.TILE_GRASS_TO_PATH
		or tile_id == BiomeTileResolver.TILE_GRASS_TO_ROAD
		or tile_id == BiomeTileResolver.TILE_PATH_TO_ROAD
	)

func _is_passage_tag(tag: StringName) -> bool:
	return tag == &"road" or tag == &"bridge" or tag == &"snow_pass" or tag == &"broken_gate" or tag == &"burned_road"

func _world_openings_touch(connection: WorldRegionConnection) -> bool:
	match connection.side:
		&"east":
			return connection.world_rect.position.x + connection.world_rect.size.x == connection.target_world_rect.position.x
		&"west":
			return connection.target_world_rect.position.x + connection.target_world_rect.size.x == connection.world_rect.position.x
		&"south":
			return connection.world_rect.position.y + connection.world_rect.size.y == connection.target_world_rect.position.y
		&"north":
			return connection.target_world_rect.position.y + connection.target_world_rect.size.y == connection.world_rect.position.y
		_:
			return false

func _world_connectors_touch(connection: WorldRegionConnection) -> bool:
	match connection.side:
		&"east":
			return connection.world_connector_rect.position.x + connection.world_connector_rect.size.x == connection.target_world_connector_rect.position.x
		&"west":
			return connection.target_world_connector_rect.position.x + connection.target_world_connector_rect.size.x == connection.world_connector_rect.position.x
		&"south":
			return connection.world_connector_rect.position.y + connection.world_connector_rect.size.y == connection.target_world_connector_rect.position.y
		&"north":
			return connection.target_world_connector_rect.position.y + connection.target_world_connector_rect.size.y == connection.world_connector_rect.position.y
		_:
			return false

func _opening_span_is_coherent(connection: WorldRegionConnection) -> bool:
	if connection.side == &"north" or connection.side == &"south":
		return connection.world_rect.position.x == connection.target_world_rect.position.x and connection.world_rect.size.x == connection.target_world_rect.size.x and connection.world_rect.size.x == connection.passage_width
	return connection.world_rect.position.y == connection.target_world_rect.position.y and connection.world_rect.size.y == connection.target_world_rect.size.y and connection.world_rect.size.y == connection.passage_width

func _outer_probe(rect: Rect2i, side: StringName) -> Vector2i:
	match side:
		&"north":
			return Vector2i(rect.position.x + _span_before_center(rect.size.x), rect.position.y)
		&"south":
			return Vector2i(rect.position.x + _span_before_center(rect.size.x), rect.position.y + rect.size.y - 1)
		&"west":
			return Vector2i(rect.position.x, rect.position.y + _span_before_center(rect.size.y))
		_:
			return Vector2i(rect.position.x + rect.size.x - 1, rect.position.y + _span_before_center(rect.size.y))

func _inner_probe(rect: Rect2i, side: StringName) -> Vector2i:
	match side:
		&"north":
			return Vector2i(rect.position.x + _span_before_center(rect.size.x), rect.position.y + 1)
		&"south":
			return Vector2i(rect.position.x + _span_before_center(rect.size.x), rect.position.y + rect.size.y - 2)
		&"west":
			return Vector2i(rect.position.x + 1, rect.position.y + _span_before_center(rect.size.y))
		_:
			return Vector2i(rect.position.x + rect.size.x - 2, rect.position.y + _span_before_center(rect.size.y))

func _connector_probe_away_from_opening(rect: Rect2i, side: StringName) -> Vector2i:
	match side:
		&"north":
			return Vector2i(rect.position.x + _span_before_center(rect.size.x), rect.position.y + 4)
		&"south":
			return Vector2i(rect.position.x + _span_before_center(rect.size.x), rect.position.y + rect.size.y - 5)
		&"west":
			return Vector2i(rect.position.x + 4, rect.position.y + _span_before_center(rect.size.y))
		_:
			return Vector2i(rect.position.x + rect.size.x - 5, rect.position.y + _span_before_center(rect.size.y))

func _span_before_center(span: int) -> int:
	return maxi(floori(float(span) * 0.5), 0)

func _entry_id_for_type(passage_type: StringName) -> StringName:
	match passage_type:
		&"bridge":
			return &"bridge_entry"
		&"snow_pass":
			return &"snow_pass_entry"
		&"broken_gate":
			return &"broken_gate_entry"
		&"burned_road":
			return &"burned_road_entry"
		_:
			return &"road_entry"

func _exit_id_for_type(passage_type: StringName) -> StringName:
	match passage_type:
		&"bridge":
			return &"bridge_exit"
		&"snow_pass":
			return &"snow_pass_exit"
		&"broken_gate":
			return &"broken_gate_exit"
		&"burned_road":
			return &"burned_road_exit"
		_:
			return &"road_exit"

func _assert_asset_contract(section: StringName, tile_id: StringName) -> void:
	var contract := _manifest.get_asset_contract(section, tile_id)
	assert_false(contract.is_empty(), "%s/%s contratto esiste" % [String(section), String(tile_id)])
	assert_true(_asset_exists(String(contract.get("asset_path", ""))), "%s/%s asset esiste" % [String(section), String(tile_id)])

func _rect_inside_any(rect: Rect2i, rects: Array[Rect2i]) -> bool:
	for candidate in rects:
		if candidate == rect:
			return true
	return false

func _asset_exists(asset_path: String) -> bool:
	if asset_path.is_empty():
		return false
	return ResourceLoader.exists(asset_path) or FileAccess.file_exists(asset_path)
