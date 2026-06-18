extends SceneTree

const WORLD_CONTEXT := {
	"world_seed": 641004,
	"biome_map_width": 3,
	"biome_map_height": 3,
	"preserve_biome_sequence": false,
	"extra_edge_chance": 0.42
}
const REQUIRED_TERRAIN_TILES: Array[StringName] = [
	&"main_road",
	&"road",
	&"service_lane",
	&"ash_lane",
	&"packed_snow_path",
	&"wooden_walkway",
	&"bridge",
	&"snow_pass",
	&"broken_gate",
	&"burned_road",
	&"road_intersection",
	&"road_edge",
	&"road_curve_north",
	&"road_curve_east",
	&"road_curve_south",
	&"road_curve_west"
]
const REQUIRED_PASSAGE_TILES: Array[StringName] = [
	&"road",
	&"bridge",
	&"snow_pass",
	&"broken_gate",
	&"burned_road",
	&"road_entry",
	&"road_exit",
	&"bridge_entry",
	&"bridge_exit",
	&"snow_pass_entry",
	&"snow_pass_exit",
	&"broken_gate_entry",
	&"broken_gate_exit",
	&"burned_road_entry",
	&"burned_road_exit",
	&"bridge_broken",
	&"cliff_ramp"
]

var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var manifest := IsometricEnvironmentManifest.reload_shared()
	_expect(manifest.load_error.is_empty(), "passage tile manifest loads")
	_expect(manifest.version >= 7, "passage tile smoke uses manifest v7")
	var manifest_report := manifest.validate()
	_expect(bool(manifest_report.get("is_valid", false)), "passage tile manifest validates")
	if not bool(manifest_report.get("is_valid", false)):
		for failure in manifest_report.get("failures", PackedStringArray()):
			push_error("manifest failure: " + String(failure))

	var resolver := IsometricTileResolver.new(manifest)
	_run_manifest_contract_smoke(manifest)

	var biome_manager := BiomeManager.new()
	root.add_child(biome_manager)
	await process_frame
	biome_manager.start_run(WORLD_CONTEXT)

	var cells := biome_manager.get_generated_biome_map()
	_expect(cells.size() == 9, "passage tile smoke generates a 3x3 biome map")
	var graph := biome_manager.get_world_graph()
	_expect(graph != null, "passage tile smoke generates a world graph")
	if graph != null:
		_expect(graph.is_graph_connected(), "world graph remains connected")
		_run_connection_data_smoke(graph)
		_run_saved_connection_smoke(graph)
	_run_passage_layout_smoke(cells, resolver)
	_run_transition_gate_visual_smoke()

	biome_manager.queue_free()
	_finish()

func _run_manifest_contract_smoke(manifest: IsometricEnvironmentManifest) -> void:
	for tile_id in REQUIRED_TERRAIN_TILES:
		_assert_asset_contract(manifest, &"terrain_tiles", tile_id)
	for tile_id in REQUIRED_PASSAGE_TILES:
		_assert_asset_contract(manifest, &"passage_tiles", tile_id)

func _run_passage_layout_smoke(
	cells: Array[BiomeCell],
	resolver: IsometricTileResolver
) -> void:
	var side_counts: Dictionary = {}
	var passage_types: Dictionary = {}
	var saw_entry := false
	var saw_exit := false
	var saw_connector := false
	var saw_curve_or_edge := false
	for cell in cells:
		var layout := cell.generated_layout
		_expect(layout != null, "%s has generated layout" % String(cell.id))
		if layout == null:
			continue
		for passage in cell.passages:
			side_counts[passage.side] = int(side_counts.get(passage.side, 0)) + 1
			passage_types[passage.passage_type] = true
			_assert_passage_rects(cell, layout, passage)
			_assert_passage_endpoint_tiles(cell, layout, passage, resolver)
			_assert_passage_connector_tiles(cell, layout, passage, resolver)
			saw_entry = saw_entry or _passage_inner_probe_emits_entry(cell, layout, passage, resolver)
			saw_exit = saw_exit or _passage_outer_probe_emits_exit(cell, layout, passage, resolver)
			saw_connector = saw_connector or _passage_connector_probe_emits_type(cell, layout, passage, resolver)
		saw_curve_or_edge = saw_curve_or_edge or _layout_emits_road_connector(cell, layout, resolver)
	for side in [&"north", &"south", &"east", &"west"]:
		_expect(int(side_counts.get(side, 0)) > 0, "passage smoke covers %s passages" % String(side))
	for passage_type_key in passage_types.keys():
		var passage_type := StringName(passage_type_key)
		_expect(
			REQUIRED_PASSAGE_TILES.has(passage_type),
			"%s generated passage type is supported" % String(passage_type)
		)
	_expect(passage_types.size() >= 3, "passage smoke generates multiple passage types")
	_expect(saw_entry, "resolver emits passage entry tiles")
	_expect(saw_exit, "resolver emits passage exit tiles")
	_expect(saw_connector, "resolver emits dedicated passage connector tiles")
	_expect(saw_curve_or_edge, "resolver emits road connector tiles")

func _assert_passage_rects(
	cell: BiomeCell,
	layout: BiomeEnvironmentLayout,
	passage: BiomePassage
) -> void:
	var zone_size := cell.get_zone_size()
	var local_rect := passage.get_local_rect(zone_size)
	var connector_rect := passage.get_connector_rect(zone_size)
	var expected_span := passage.width
	if passage.side == &"north" or passage.side == &"south":
		_expect(local_rect.size.x == expected_span, "%s %s opening width matches passage span" % [String(cell.id), String(passage.side)])
		_expect(local_rect.size.y == 3, "%s %s opening keeps border depth" % [String(cell.id), String(passage.side)])
	else:
		_expect(local_rect.size.y == expected_span, "%s %s opening height matches passage span" % [String(cell.id), String(passage.side)])
		_expect(local_rect.size.x == 3, "%s %s opening keeps border depth" % [String(cell.id), String(passage.side)])
	_expect(_rect_inside_any(local_rect, layout.passage_rects), "%s %s passage rect is registered" % [String(cell.id), String(passage.side)])
	_expect(
		passage.get_global_local_rect(zone_size) == Rect2i(cell.world_origin + local_rect.position, local_rect.size),
		"%s %s local opening has global coordinates" % [String(cell.id), String(passage.side)]
	)
	_expect(
		passage.get_global_connector_rect(zone_size) == Rect2i(cell.world_origin + connector_rect.position, connector_rect.size),
		"%s %s connector has global coordinates" % [String(cell.id), String(passage.side)]
	)
	_assert_passage_cells_are_clear(cell, layout, local_rect, "opening")
	_assert_passage_cells_are_clear(cell, layout, connector_rect, "connector")

func _assert_passage_endpoint_tiles(
	cell: BiomeCell,
	layout: BiomeEnvironmentLayout,
	passage: BiomePassage,
	resolver: IsometricTileResolver
) -> void:
	var outer_probe := _outer_probe(passage.get_local_rect(cell.get_zone_size()), passage.side)
	var inner_probe := _inner_probe(passage.get_local_rect(cell.get_zone_size()), passage.side)
	var outer_data := resolver.resolve_tile_data(layout, outer_probe, cell.biome_id, &"balanced", cell)
	var inner_data := resolver.resolve_tile_data(layout, inner_probe, cell.biome_id, &"balanced", cell)
	_expect(
		StringName(outer_data.get("tile_id", &"")) == passage.get_exit_tile_id(),
		"%s %s outer opening uses exit tile" % [String(cell.id), String(passage.side)]
	)
	_expect(
		StringName(inner_data.get("tile_id", &"")) == passage.get_entry_tile_id(),
		"%s %s inner opening uses entry tile" % [String(cell.id), String(passage.side)]
	)
	_expect(
		StringName(outer_data.get("section", &"")) == IsometricTileResolver.TILE_SECTION_PASSAGE,
		"%s %s exit tile is a passage asset" % [String(cell.id), String(passage.side)]
	)
	_expect(
		StringName(inner_data.get("section", &"")) == IsometricTileResolver.TILE_SECTION_PASSAGE,
		"%s %s entry tile is a passage asset" % [String(cell.id), String(passage.side)]
	)

func _assert_passage_connector_tiles(
	cell: BiomeCell,
	layout: BiomeEnvironmentLayout,
	passage: BiomePassage,
	resolver: IsometricTileResolver
) -> void:
	var connector_rect := passage.get_connector_rect(cell.get_zone_size())
	var probe := _connector_probe_away_from_opening(connector_rect, passage.side)
	var tile_data := resolver.resolve_tile_data(layout, probe, cell.biome_id, &"balanced", cell)
	_expect(
		StringName(tile_data.get("tile_id", &"")) == passage.passage_type,
		"%s %s connector uses passage type tile" % [String(cell.id), String(passage.side)]
	)
	_expect(
		StringName(tile_data.get("section", &"")) == IsometricTileResolver.TILE_SECTION_PASSAGE,
		"%s %s connector is a passage asset" % [String(cell.id), String(passage.side)]
	)

func _assert_passage_cells_are_clear(
	cell: BiomeCell,
	layout: BiomeEnvironmentLayout,
	rect: Rect2i,
	label: String
) -> void:
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			var probe := Vector2i(x, y)
			var terrain_class := layout.get_terrain_class_at_cell(probe, cell)
			if (
				terrain_class == BiomeEnvironmentLayout.TERRAIN_FALL_ZONE
				or terrain_class == BiomeEnvironmentLayout.TERRAIN_OBSTACLE
				or terrain_class == BiomeEnvironmentLayout.TERRAIN_BORDER
				or terrain_class == BiomeEnvironmentLayout.TERRAIN_VOID
			):
				failures.append(
					"%s %s passage %s cell %s overlaps %s"
					% [String(cell.id), label, str(probe), str(rect), String(terrain_class)]
				)
				return

func _run_connection_data_smoke(graph: WorldGraph) -> void:
	for connection in graph.connections:
		var source := graph.get_region(connection.from_region_id)
		var target := graph.get_region(connection.to_region_id)
		_expect(source != null and target != null, "%s connects existing regions" % String(connection.connection_id))
		if source == null or target == null:
			continue
		_expect(connection.entry_tile_id == _entry_id_for_type(connection.passage_type), "%s stores entry tile id" % String(connection.connection_id))
		_expect(connection.exit_tile_id == _exit_id_for_type(connection.passage_type), "%s stores exit tile id" % String(connection.connection_id))
		_expect(
			connection.world_rect == Rect2i(source.world_origin + connection.local_rect.position, connection.local_rect.size),
			"%s source opening uses source global origin" % String(connection.connection_id)
		)
		_expect(
			connection.target_world_rect == Rect2i(target.world_origin + connection.target_local_rect.position, connection.target_local_rect.size),
			"%s target opening uses target global origin" % String(connection.connection_id)
		)
		_expect(
			connection.world_connector_rect == Rect2i(source.world_origin + connection.connector_local_rect.position, connection.connector_local_rect.size),
			"%s source connector uses source global origin" % String(connection.connection_id)
		)
		_expect(
			connection.target_world_connector_rect == Rect2i(target.world_origin + connection.target_connector_local_rect.position, connection.target_connector_local_rect.size),
			"%s target connector uses target global origin" % String(connection.connection_id)
		)
		_expect(_world_openings_touch(connection), "%s source and target openings touch in world coordinates" % String(connection.connection_id))
		_expect(_world_connectors_touch(connection), "%s source and target connectors touch in world coordinates" % String(connection.connection_id))
		_expect(_opening_span_is_coherent(connection), "%s opening span matches on both sides" % String(connection.connection_id))

func _run_saved_connection_smoke(graph: WorldGraph) -> void:
	var restored := WorldGraph.from_save_data(graph.to_save_data())
	_expect(restored.connections.size() == graph.connections.size(), "saved graph preserves directed connections")
	for index in range(mini(restored.connections.size(), graph.connections.size())):
		var before := graph.connections[index]
		var after := restored.connections[index]
		_expect(after.entry_tile_id == before.entry_tile_id, "%s save keeps entry tile" % String(before.connection_id))
		_expect(after.exit_tile_id == before.exit_tile_id, "%s save keeps exit tile" % String(before.connection_id))
		_expect(after.world_connector_rect == before.world_connector_rect, "%s save keeps source connector rect" % String(before.connection_id))
		_expect(after.target_world_connector_rect == before.target_world_connector_rect, "%s save keeps target connector rect" % String(before.connection_id))

func _run_transition_gate_visual_smoke() -> void:
	var gate := BiomeTransitionGate.new()
	_expect(not gate.show_debug_visual, "transition gates hide debug draw by default")
	gate.free()
	var source := _read_text("res://game/modes/zombie/biome_transition_gate.gd")
	_expect(not source.contains("_draw_direction_arrow"), "transition gate no longer draws direction arrows")
	_expect(not source.contains("_draw_passage_marks"), "transition gate no longer draws passage marks")

func _passage_inner_probe_emits_entry(
	cell: BiomeCell,
	layout: BiomeEnvironmentLayout,
	passage: BiomePassage,
	resolver: IsometricTileResolver
) -> bool:
	var probe := _inner_probe(passage.get_local_rect(cell.get_zone_size()), passage.side)
	return resolver.resolve_tile_id(layout, probe, cell.biome_id, &"balanced", cell) == passage.get_entry_tile_id()

func _passage_outer_probe_emits_exit(
	cell: BiomeCell,
	layout: BiomeEnvironmentLayout,
	passage: BiomePassage,
	resolver: IsometricTileResolver
) -> bool:
	var probe := _outer_probe(passage.get_local_rect(cell.get_zone_size()), passage.side)
	return resolver.resolve_tile_id(layout, probe, cell.biome_id, &"balanced", cell) == passage.get_exit_tile_id()

func _passage_connector_probe_emits_type(
	cell: BiomeCell,
	layout: BiomeEnvironmentLayout,
	passage: BiomePassage,
	resolver: IsometricTileResolver
) -> bool:
	var connector_rect := passage.get_connector_rect(cell.get_zone_size())
	var probe := _connector_probe_away_from_opening(connector_rect, passage.side)
	return resolver.resolve_tile_id(layout, probe, cell.biome_id, &"balanced", cell) == passage.passage_type

func _layout_emits_road_connector(
	cell: BiomeCell,
	layout: BiomeEnvironmentLayout,
	resolver: IsometricTileResolver
) -> bool:
	for road_cell in layout.get_road_cells():
		var tile_id := resolver.resolve_tile_id(layout, road_cell, cell.biome_id, &"balanced", cell)
		if (
			tile_id == IsometricTileResolver.TILE_ROAD_EDGE
			or tile_id == IsometricTileResolver.TILE_ROAD_INTERSECTION
			or tile_id == IsometricTileResolver.TILE_ROAD_CURVE_NORTH
			or tile_id == IsometricTileResolver.TILE_ROAD_CURVE_EAST
			or tile_id == IsometricTileResolver.TILE_ROAD_CURVE_SOUTH
			or tile_id == IsometricTileResolver.TILE_ROAD_CURVE_WEST
		):
			return true
	for index in range(layout.road_rects.size()):
		if index >= layout.road_rect_tags.size():
			continue
		if _is_passage_tag(layout.road_rect_tags[index]):
			continue
		var rect := layout.road_rects[index]
		var probes := [
			rect.position,
			rect.position + rect.size / 2,
			rect.position + rect.size - Vector2i.ONE
		]
		for probe in probes:
			var tile_id := resolver.resolve_tile_id(layout, probe, cell.biome_id, &"balanced", cell)
			if (
				tile_id == IsometricTileResolver.TILE_ROAD_EDGE
				or tile_id == IsometricTileResolver.TILE_ROAD_INTERSECTION
				or tile_id == IsometricTileResolver.TILE_ROAD_CURVE_NORTH
				or tile_id == IsometricTileResolver.TILE_ROAD_CURVE_EAST
				or tile_id == IsometricTileResolver.TILE_ROAD_CURVE_SOUTH
				or tile_id == IsometricTileResolver.TILE_ROAD_CURVE_WEST
			):
				return true
	return false

func _is_passage_tag(tag: StringName) -> bool:
	return (
		tag == &"road"
		or tag == &"bridge"
		or tag == &"snow_pass"
		or tag == &"broken_gate"
		or tag == &"burned_road"
	)

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
		return (
			connection.world_rect.position.x == connection.target_world_rect.position.x
			and connection.world_rect.size.x == connection.target_world_rect.size.x
			and connection.world_rect.size.x == connection.passage_width
		)
	return (
		connection.world_rect.position.y == connection.target_world_rect.position.y
		and connection.world_rect.size.y == connection.target_world_rect.size.y
		and connection.world_rect.size.y == connection.passage_width
	)

func _outer_probe(rect: Rect2i, side: StringName) -> Vector2i:
	match side:
		&"north":
			return Vector2i(rect.position.x + rect.size.x / 2, rect.position.y)
		&"south":
			return Vector2i(rect.position.x + rect.size.x / 2, rect.position.y + rect.size.y - 1)
		&"west":
			return Vector2i(rect.position.x, rect.position.y + rect.size.y / 2)
		_:
			return Vector2i(rect.position.x + rect.size.x - 1, rect.position.y + rect.size.y / 2)

func _inner_probe(rect: Rect2i, side: StringName) -> Vector2i:
	match side:
		&"north":
			return Vector2i(rect.position.x + rect.size.x / 2, rect.position.y + 1)
		&"south":
			return Vector2i(rect.position.x + rect.size.x / 2, rect.position.y + rect.size.y - 2)
		&"west":
			return Vector2i(rect.position.x + 1, rect.position.y + rect.size.y / 2)
		_:
			return Vector2i(rect.position.x + rect.size.x - 2, rect.position.y + rect.size.y / 2)

func _connector_probe_away_from_opening(rect: Rect2i, side: StringName) -> Vector2i:
	match side:
		&"north":
			return Vector2i(rect.position.x + rect.size.x / 2, rect.position.y + 4)
		&"south":
			return Vector2i(rect.position.x + rect.size.x / 2, rect.position.y + rect.size.y - 5)
		&"west":
			return Vector2i(rect.position.x + 4, rect.position.y + rect.size.y / 2)
		_:
			return Vector2i(rect.position.x + rect.size.x - 5, rect.position.y + rect.size.y / 2)

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

func _assert_asset_contract(
	manifest: IsometricEnvironmentManifest,
	section: StringName,
	tile_id: StringName
) -> void:
	var contract := manifest.get_asset_contract(section, tile_id)
	var asset_path := String(contract.get("asset_path", ""))
	_expect(not contract.is_empty(), "%s/%s contract exists" % [String(section), String(tile_id)])
	_expect(_asset_exists(asset_path), "%s/%s asset exists" % [String(section), String(tile_id)])

func _rect_inside_any(rect: Rect2i, rects: Array[Rect2i]) -> bool:
	for candidate in rects:
		if candidate == rect:
			return true
	return false

func _asset_exists(asset_path: String) -> bool:
	if asset_path.is_empty():
		return false
	if ResourceLoader.exists(asset_path):
		return true
	return FileAccess.file_exists(asset_path)

func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("MILESTONE_10_PASSAGE_TILE_SMOKE_TEST: PASS")
		quit(0)
		return
	print("MILESTONE_10_PASSAGE_TILE_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
