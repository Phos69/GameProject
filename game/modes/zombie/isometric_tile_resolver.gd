extends RefCounted
class_name IsometricTileResolver

const TILE_FLOOR_BASE: StringName = &"floor_base"
const TILE_FLOOR_VARIANT_01: StringName = &"floor_variant_01"
const TILE_FLOOR_VARIANT_02: StringName = &"floor_variant_02"
const TILE_FLOOR_VARIANT_03: StringName = &"floor_variant_03"
const FOREST_BIOME_ID: StringName = &"infected_plains"
const TILE_FOREST_GRASS: StringName = &"forest_grass"
const TILE_FOREST_GRASS_VARIANT_01: StringName = &"forest_grass_variant_01"
const TILE_FOREST_GRASS_VARIANT_02: StringName = &"forest_grass_variant_02"
const TILE_FOREST_TALL_GRASS: StringName = &"forest_tall_grass"
const TILE_FOREST_PATH: StringName = &"forest_path"
const TILE_FOREST_ROAD: StringName = &"forest_road"
const TILE_FOREST_VOID: StringName = &"forest_void"
const TILE_FOREST_CLIFF_EDGE: StringName = &"forest_cliff_edge"
const TILE_FOREST_MOUNTAIN_WALL: StringName = &"forest_mountain_wall"
const TILE_GRASS_TO_PATH: StringName = &"grass_to_path"
const TILE_GRASS_TO_ROAD: StringName = &"grass_to_road"
const TILE_GRASS_TO_TALL_GRASS: StringName = &"grass_to_tall_grass"
const TILE_PATH_TO_ROAD: StringName = &"path_to_road"
const TILE_GROUND_TO_VOID_CLIFF: StringName = &"ground_to_void_cliff"
const TILE_GROUND_TO_MOUNTAIN_WALL: StringName = &"ground_to_mountain_wall"
const TILE_ROAD: StringName = &"road"
const TILE_MAIN_ROAD: StringName = &"main_road"
const TILE_BROKEN_STREET: StringName = &"broken_street"
const TILE_SERVICE_LANE: StringName = &"service_lane"
const TILE_ASH_LANE: StringName = &"ash_lane"
const TILE_PACKED_SNOW_PATH: StringName = &"packed_snow_path"
const TILE_WOODEN_WALKWAY: StringName = &"wooden_walkway"
const TILE_BRIDGE: StringName = &"bridge"
const TILE_SNOW_PASS: StringName = &"snow_pass"
const TILE_BROKEN_GATE: StringName = &"broken_gate"
const TILE_BURNED_ROAD: StringName = &"burned_road"
const TILE_ROAD_INTERSECTION: StringName = &"road_intersection"
const TILE_ROAD_EDGE: StringName = &"road_edge"
const TILE_ROAD_CURVE_NORTH: StringName = &"road_curve_north"
const TILE_ROAD_CURVE_EAST: StringName = &"road_curve_east"
const TILE_ROAD_CURVE_SOUTH: StringName = &"road_curve_south"
const TILE_ROAD_CURVE_WEST: StringName = &"road_curve_west"
const TILE_ROAD_ENTRY: StringName = &"road_entry"
const TILE_ROAD_EXIT: StringName = &"road_exit"
const TILE_BRIDGE_ENTRY: StringName = &"bridge_entry"
const TILE_BRIDGE_EXIT: StringName = &"bridge_exit"
const TILE_SNOW_PASS_ENTRY: StringName = &"snow_pass_entry"
const TILE_SNOW_PASS_EXIT: StringName = &"snow_pass_exit"
const TILE_BROKEN_GATE_ENTRY: StringName = &"broken_gate_entry"
const TILE_BROKEN_GATE_EXIT: StringName = &"broken_gate_exit"
const TILE_BURNED_ROAD_ENTRY: StringName = &"burned_road_entry"
const TILE_BURNED_ROAD_EXIT: StringName = &"burned_road_exit"
const TILE_BRIDGE_BROKEN: StringName = &"bridge_broken"
const TILE_CLIFF_RAMP: StringName = &"cliff_ramp"
const TILE_HAZARD_FLOOR: StringName = &"hazard_floor"
const TILE_BORDER_FLOOR: StringName = &"border_floor"
const TILE_VOID_EDGE_NEAR: StringName = &"void_edge_near"
const TILE_VOID_DEPTH: StringName = &"void_depth"

const TILE_SECTION_VARIANTS: StringName = &"tile_variants"
const TILE_SECTION_TERRAIN: StringName = &"terrain_tiles"
const TILE_SECTION_PASSAGE: StringName = &"passage_tiles"
const TILE_SECTION_VOID: StringName = &"void_tiles"

const FLOOR_VARIANTS: Array[StringName] = [
	TILE_FLOOR_BASE,
	TILE_FLOOR_VARIANT_01,
	TILE_FLOOR_VARIANT_02,
	TILE_FLOOR_VARIANT_03
]
const FOREST_GRASS_VARIANTS: Array[StringName] = [
	TILE_FOREST_GRASS,
	TILE_FOREST_GRASS_VARIANT_01,
	TILE_FOREST_GRASS_VARIANT_02
]
const CARDINAL_OFFSETS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1)
]
const NEIGHBOR_OFFSETS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
	Vector2i(1, 1),
	Vector2i(-1, 1),
	Vector2i(1, -1),
	Vector2i(-1, -1)
]
const PASSAGE_TYPES: Array[StringName] = [
	TILE_ROAD,
	TILE_BRIDGE,
	TILE_SNOW_PASS,
	TILE_BROKEN_GATE,
	TILE_BURNED_ROAD
]
const TERRAIN_ROUTE_TILE_IDS: Array[StringName] = [
	TILE_MAIN_ROAD,
	TILE_ROAD,
	TILE_BROKEN_STREET,
	TILE_SERVICE_LANE,
	TILE_ASH_LANE,
	TILE_PACKED_SNOW_PATH,
	TILE_WOODEN_WALKWAY,
	TILE_FOREST_PATH,
	TILE_FOREST_ROAD,
	TILE_GRASS_TO_PATH,
	TILE_GRASS_TO_ROAD,
	TILE_PATH_TO_ROAD,
	TILE_GROUND_TO_VOID_CLIFF,
	TILE_GROUND_TO_MOUNTAIN_WALL,
	TILE_BRIDGE,
	TILE_SNOW_PASS,
	TILE_BROKEN_GATE,
	TILE_BURNED_ROAD,
	TILE_ROAD_INTERSECTION,
	TILE_ROAD_EDGE,
	TILE_ROAD_CURVE_NORTH,
	TILE_ROAD_CURVE_EAST,
	TILE_ROAD_CURVE_SOUTH,
	TILE_ROAD_CURVE_WEST
]
const FOREST_TERRAIN_TILE_IDS: Array[StringName] = [
	TILE_FOREST_GRASS,
	TILE_FOREST_GRASS_VARIANT_01,
	TILE_FOREST_GRASS_VARIANT_02,
	TILE_FOREST_TALL_GRASS,
	TILE_FOREST_PATH,
	TILE_FOREST_ROAD,
	TILE_GRASS_TO_PATH,
	TILE_GRASS_TO_ROAD,
	TILE_GRASS_TO_TALL_GRASS,
	TILE_PATH_TO_ROAD,
	TILE_GROUND_TO_VOID_CLIFF,
	TILE_GROUND_TO_MOUNTAIN_WALL
]
const PASSAGE_ROUTE_TILE_IDS: Array[StringName] = [
	TILE_ROAD,
	TILE_BRIDGE,
	TILE_SNOW_PASS,
	TILE_BROKEN_GATE,
	TILE_BURNED_ROAD,
	TILE_ROAD_ENTRY,
	TILE_ROAD_EXIT,
	TILE_BRIDGE_ENTRY,
	TILE_BRIDGE_EXIT,
	TILE_SNOW_PASS_ENTRY,
	TILE_SNOW_PASS_EXIT,
	TILE_BROKEN_GATE_ENTRY,
	TILE_BROKEN_GATE_EXIT,
	TILE_BURNED_ROAD_ENTRY,
	TILE_BURNED_ROAD_EXIT,
	TILE_BRIDGE_BROKEN,
	TILE_CLIFF_RAMP
]
const REQUIRED_TILE_IDS: Array[StringName] = [
	TILE_FLOOR_BASE,
	TILE_FLOOR_VARIANT_01,
	TILE_FLOOR_VARIANT_02,
	TILE_FLOOR_VARIANT_03,
	TILE_ROAD,
	TILE_HAZARD_FLOOR,
	TILE_BORDER_FLOOR,
	TILE_VOID_EDGE_NEAR,
	TILE_VOID_DEPTH,
	TILE_FOREST_GRASS,
	TILE_FOREST_GRASS_VARIANT_01,
	TILE_FOREST_GRASS_VARIANT_02,
	TILE_FOREST_TALL_GRASS,
	TILE_FOREST_PATH,
	TILE_FOREST_ROAD,
	TILE_FOREST_VOID,
	TILE_FOREST_CLIFF_EDGE,
	TILE_FOREST_MOUNTAIN_WALL,
	TILE_GRASS_TO_PATH,
	TILE_GRASS_TO_ROAD,
	TILE_GRASS_TO_TALL_GRASS,
	TILE_PATH_TO_ROAD,
	TILE_GROUND_TO_VOID_CLIFF,
	TILE_GROUND_TO_MOUNTAIN_WALL
]

var manifest: IsometricEnvironmentManifest

func _init(next_manifest: IsometricEnvironmentManifest = null) -> void:
	manifest = next_manifest if next_manifest != null else IsometricEnvironmentManifest.get_shared()

func resolve_tile_id(
	layout: BiomeEnvironmentLayout,
	cell: Vector2i,
	biome_id: StringName = &"",
	quality_preset: StringName = &"balanced",
	biome_cell: BiomeCell = null
) -> StringName:
	return StringName(resolve_tile_data(
		layout,
		cell,
		biome_id,
		quality_preset,
		biome_cell
	).get("tile_id", &""))

func resolve_tile_data(
	layout: BiomeEnvironmentLayout,
	cell: Vector2i,
	biome_id: StringName = &"",
	quality_preset: StringName = &"balanced",
	biome_cell: BiomeCell = null
) -> Dictionary:
	if layout == null:
		return _tile_data(&"", &"", &"missing")
	var terrain_class := layout.get_terrain_class_at_cell(cell, biome_cell)
	if _is_forest_biome(biome_id):
		var forest_data := _resolve_forest_tile_data(
			layout,
			cell,
			terrain_class,
			quality_preset,
			biome_cell
		)
		if not forest_data.is_empty():
			return forest_data
	match terrain_class:
		BiomeEnvironmentLayout.TERRAIN_VOID:
			return _tile_data(TILE_VOID_DEPTH, TILE_SECTION_VOID, &"void_depth")
		BiomeEnvironmentLayout.TERRAIN_FALL_ZONE:
			return (
				_tile_data(TILE_VOID_EDGE_NEAR, TILE_SECTION_VOID, &"void_edge")
				if _fall_zone_cell_touches_floor(layout, cell, biome_cell)
				else _tile_data(TILE_VOID_DEPTH, TILE_SECTION_VOID, &"void_depth")
			)
		BiomeEnvironmentLayout.TERRAIN_HAZARD:
			return _tile_data(TILE_HAZARD_FLOOR, TILE_SECTION_VARIANTS, &"hazard")
		BiomeEnvironmentLayout.TERRAIN_BORDER:
			return _tile_data(TILE_BORDER_FLOOR, TILE_SECTION_VARIANTS, &"border")
		_:
			var route_data := _resolve_route_tile_data(layout, cell, biome_id, biome_cell)
			if not route_data.is_empty():
				return route_data
			return _tile_data(
				_resolve_floor_variant(layout, cell, biome_id, quality_preset),
				TILE_SECTION_VARIANTS,
				&"floor"
			)

func resolve_tile_section(tile_id: StringName) -> StringName:
	if (
		tile_id == TILE_VOID_EDGE_NEAR
		or tile_id == TILE_VOID_DEPTH
		or tile_id == TILE_FOREST_VOID
		or tile_id == TILE_FOREST_CLIFF_EDGE
	):
		return TILE_SECTION_VOID
	if tile_id == TILE_FOREST_MOUNTAIN_WALL:
		return &"edge_tiles"
	if (
		tile_id == TILE_FLOOR_BASE
		or tile_id == TILE_FLOOR_VARIANT_01
		or tile_id == TILE_FLOOR_VARIANT_02
		or tile_id == TILE_FLOOR_VARIANT_03
		or tile_id == TILE_HAZARD_FLOOR
		or tile_id == TILE_BORDER_FLOOR
	):
		return TILE_SECTION_VARIANTS
	if _is_passage_endpoint_tile(tile_id) or tile_id == TILE_BRIDGE_BROKEN or tile_id == TILE_CLIFF_RAMP:
		return TILE_SECTION_PASSAGE
	if FOREST_TERRAIN_TILE_IDS.has(tile_id):
		return TILE_SECTION_TERRAIN
	if TERRAIN_ROUTE_TILE_IDS.has(tile_id):
		return TILE_SECTION_TERRAIN
	if PASSAGE_ROUTE_TILE_IDS.has(tile_id):
		return TILE_SECTION_PASSAGE
	return TILE_SECTION_VARIANTS

func resolve_tile_contract(tile_id: StringName) -> Dictionary:
	if manifest == null or tile_id.is_empty():
		return {}
	return manifest.get_asset_contract(resolve_tile_section(tile_id), tile_id)

func resolve_tile_contract_for_cell(
	layout: BiomeEnvironmentLayout,
	cell: Vector2i,
	biome_id: StringName = &"",
	quality_preset: StringName = &"balanced",
	biome_cell: BiomeCell = null
) -> Dictionary:
	var data := resolve_tile_data(layout, cell, biome_id, quality_preset, biome_cell)
	if manifest == null:
		return {}
	return manifest.get_asset_contract(
		StringName(data.get("section", &"")),
		StringName(data.get("tile_id", &""))
	)

func resolve_asset_path(
	layout: BiomeEnvironmentLayout,
	cell: Vector2i,
	biome_id: StringName = &"",
	quality_preset: StringName = &"balanced",
	biome_cell: BiomeCell = null
) -> String:
	var data := resolve_tile_data(layout, cell, biome_id, quality_preset, biome_cell)
	return String(data.get("asset_path", ""))

func has_visual_tile(
	layout: BiomeEnvironmentLayout,
	cell: Vector2i,
	biome_id: StringName = &"",
	quality_preset: StringName = &"balanced",
	biome_cell: BiomeCell = null
) -> bool:
	var asset_path := resolve_asset_path(layout, cell, biome_id, quality_preset, biome_cell)
	return _asset_path_exists(asset_path)

func get_required_tile_ids() -> Array[StringName]:
	return REQUIRED_TILE_IDS.duplicate()

func get_route_tile_ids() -> Array[StringName]:
	var ids := TERRAIN_ROUTE_TILE_IDS.duplicate()
	for tile_id in PASSAGE_ROUTE_TILE_IDS:
		if not ids.has(tile_id):
			ids.append(tile_id)
	return ids

func is_route_tile_id(tile_id: StringName) -> bool:
	return TERRAIN_ROUTE_TILE_IDS.has(tile_id) or PASSAGE_ROUTE_TILE_IDS.has(tile_id)

func get_passage_entry_tile_id(passage_type: StringName) -> StringName:
	match passage_type:
		TILE_BRIDGE:
			return TILE_BRIDGE_ENTRY
		TILE_SNOW_PASS:
			return TILE_SNOW_PASS_ENTRY
		TILE_BROKEN_GATE:
			return TILE_BROKEN_GATE_ENTRY
		TILE_BURNED_ROAD:
			return TILE_BURNED_ROAD_ENTRY
		_:
			return TILE_ROAD_ENTRY

func get_passage_exit_tile_id(passage_type: StringName) -> StringName:
	match passage_type:
		TILE_BRIDGE:
			return TILE_BRIDGE_EXIT
		TILE_SNOW_PASS:
			return TILE_SNOW_PASS_EXIT
		TILE_BROKEN_GATE:
			return TILE_BROKEN_GATE_EXIT
		TILE_BURNED_ROAD:
			return TILE_BURNED_ROAD_EXIT
		_:
			return TILE_ROAD_EXIT

func get_floor_variants_for_preset(
	quality_preset: StringName = &"balanced"
) -> Array[StringName]:
	match quality_preset:
		&"performance":
			return [TILE_FLOOR_BASE, TILE_FLOOR_VARIANT_01]
		&"quality":
			return FLOOR_VARIANTS.duplicate()
		_:
			return [TILE_FLOOR_BASE, TILE_FLOOR_VARIANT_01, TILE_FLOOR_VARIANT_02]

func _resolve_forest_tile_data(
	layout: BiomeEnvironmentLayout,
	cell: Vector2i,
	terrain_class: StringName,
	quality_preset: StringName,
	biome_cell: BiomeCell
) -> Dictionary:
	match terrain_class:
		BiomeEnvironmentLayout.TERRAIN_VOID:
			if not _cell_inside_layout(layout, cell):
				return _tile_data(TILE_VOID_DEPTH, TILE_SECTION_VOID, &"void_depth")
			return _tile_data(TILE_FOREST_VOID, TILE_SECTION_VOID, &"forest_void")
		BiomeEnvironmentLayout.TERRAIN_FALL_ZONE:
			return (
				_tile_data(TILE_FOREST_CLIFF_EDGE, TILE_SECTION_VOID, &"forest_cliff_edge")
				if _fall_zone_cell_touches_floor(layout, cell, biome_cell)
				else _tile_data(TILE_FOREST_VOID, TILE_SECTION_VOID, &"forest_void")
			)
		BiomeEnvironmentLayout.TERRAIN_BORDER:
			return _tile_data(TILE_FOREST_MOUNTAIN_WALL, &"edge_tiles", &"forest_mountain_wall")
		BiomeEnvironmentLayout.TERRAIN_OBSTACLE:
			if _cell_inside_wall_segments(layout, cell):
				return _tile_data(TILE_FOREST_MOUNTAIN_WALL, &"edge_tiles", &"forest_mountain_wall")
		BiomeEnvironmentLayout.TERRAIN_HAZARD:
			return {}

	var route_data := _resolve_route_tile_data(layout, cell, FOREST_BIOME_ID, biome_cell)
	if not route_data.is_empty():
		return route_data
	if terrain_class == BiomeEnvironmentLayout.TERRAIN_WALKABLE:
		return _resolve_forest_floor_tile_data(layout, cell, quality_preset, biome_cell)
	if terrain_class == BiomeEnvironmentLayout.TERRAIN_OBSTACLE:
		return _tile_data(
			_resolve_forest_grass_variant(layout, cell, quality_preset),
			TILE_SECTION_TERRAIN,
			&"forest_grass"
		)
	return {}

func _resolve_forest_floor_tile_data(
	layout: BiomeEnvironmentLayout,
	cell: Vector2i,
	quality_preset: StringName,
	biome_cell: BiomeCell
) -> Dictionary:
	if _cell_touches_void_or_fall(layout, cell, biome_cell):
		return _tile_data(
			TILE_GROUND_TO_VOID_CLIFF,
			TILE_SECTION_TERRAIN,
			&"ground_to_void_cliff"
		)
	if _cell_touches_wall_or_border(layout, cell, biome_cell):
		return _tile_data(
			TILE_GROUND_TO_MOUNTAIN_WALL,
			TILE_SECTION_TERRAIN,
			&"ground_to_mountain_wall"
		)
	var floor_tag := layout.get_floor_tag_at_cell(cell)
	if floor_tag == TILE_FOREST_TALL_GRASS:
		if _cell_touches_non_tall_walkable(layout, cell, biome_cell):
			return _tile_data(
				TILE_GRASS_TO_TALL_GRASS,
				TILE_SECTION_TERRAIN,
				&"grass_to_tall_grass"
			)
		return _tile_data(
			TILE_FOREST_TALL_GRASS,
			TILE_SECTION_TERRAIN,
			&"forest_tall_grass"
		)
	if _cell_touches_floor_tag(layout, cell, TILE_FOREST_TALL_GRASS):
		return _tile_data(
			TILE_GRASS_TO_TALL_GRASS,
			TILE_SECTION_TERRAIN,
			&"grass_to_tall_grass"
		)
	return _tile_data(
		_resolve_forest_grass_variant(layout, cell, quality_preset),
		TILE_SECTION_TERRAIN,
		&"forest_grass"
	)

func _resolve_forest_cell_route_tile_data(
	layout: BiomeEnvironmentLayout,
	cell: Vector2i,
	route_tags: Array[StringName],
	biome_cell: BiomeCell
) -> Dictionary:
	var passage_tag := _find_passage_tag(route_tags)
	if not passage_tag.is_empty():
		if _cell_inside_any_rect(cell, layout.passage_rects):
			var endpoint_tile := (
				get_passage_exit_tile_id(passage_tag)
				if _cell_on_outer_passage_edge(layout, cell)
				else get_passage_entry_tile_id(passage_tag)
			)
			return _tile_data(
				endpoint_tile,
				TILE_SECTION_PASSAGE,
				&"passage_exit" if String(endpoint_tile).ends_with("_exit") else &"passage_entry"
			)
		return _tile_data(passage_tag, TILE_SECTION_PASSAGE, &"passage_connector")
	if _cell_touches_void_or_fall(layout, cell, biome_cell):
		return _tile_data(
			TILE_GROUND_TO_VOID_CLIFF,
			TILE_SECTION_TERRAIN,
			&"ground_to_void_cliff"
		)
	if _cell_touches_wall_or_border(layout, cell, biome_cell):
		return _tile_data(
			TILE_GROUND_TO_MOUNTAIN_WALL,
			TILE_SECTION_TERRAIN,
			&"ground_to_mountain_wall"
		)
	if _array_has_forest_main_and_path(route_tags):
		return _tile_data(TILE_PATH_TO_ROAD, TILE_SECTION_TERRAIN, &"path_to_road")
	if _array_has_forest_main(route_tags):
		return (
			_tile_data(TILE_GRASS_TO_ROAD, TILE_SECTION_TERRAIN, &"grass_to_road")
			if _route_cell_touches_non_route(layout, cell)
			else _tile_data(TILE_FOREST_ROAD, TILE_SECTION_TERRAIN, &"forest_road")
		)
	if _array_has_forest_path(route_tags):
		return (
			_tile_data(TILE_GRASS_TO_PATH, TILE_SECTION_TERRAIN, &"grass_to_path")
			if _route_cell_touches_non_route(layout, cell)
			else _tile_data(TILE_FOREST_PATH, TILE_SECTION_TERRAIN, &"forest_path")
		)
	return _tile_data(TILE_FOREST_PATH, TILE_SECTION_TERRAIN, &"forest_path")

func _resolve_forest_rect_route_tile_data(
	layout: BiomeEnvironmentLayout,
	cell: Vector2i,
	matching_indices: Array[int],
	biome_cell: BiomeCell
) -> Dictionary:
	var selected_passage_index := -1
	var has_main := false
	var has_path := false
	for index in matching_indices:
		var route_tag := _road_tag_for_index(layout, index)
		has_main = has_main or _is_forest_main_tag(route_tag)
		has_path = has_path or _is_forest_path_tag(route_tag)
		if not _is_passage_type(route_tag):
			continue
		if _cell_inside_any_rect(cell, layout.passage_rects):
			var endpoint_tile := (
				get_passage_exit_tile_id(route_tag)
				if _cell_on_outer_passage_edge(layout, cell)
				else get_passage_entry_tile_id(route_tag)
			)
			return _tile_data(
				endpoint_tile,
				TILE_SECTION_PASSAGE,
				&"passage_exit" if String(endpoint_tile).ends_with("_exit") else &"passage_entry"
			)
		selected_passage_index = index
	if selected_passage_index >= 0:
		return _tile_data(
			_road_tag_for_index(layout, selected_passage_index),
			TILE_SECTION_PASSAGE,
			&"passage_connector"
		)
	if _cell_touches_void_or_fall(layout, cell, biome_cell):
		return _tile_data(
			TILE_GROUND_TO_VOID_CLIFF,
			TILE_SECTION_TERRAIN,
			&"ground_to_void_cliff"
		)
	if _cell_touches_wall_or_border(layout, cell, biome_cell):
		return _tile_data(
			TILE_GROUND_TO_MOUNTAIN_WALL,
			TILE_SECTION_TERRAIN,
			&"ground_to_mountain_wall"
		)
	if has_main and has_path:
		return _tile_data(TILE_PATH_TO_ROAD, TILE_SECTION_TERRAIN, &"path_to_road")
	var selected_index := matching_indices[matching_indices.size() - 1]
	var selected_tag := _road_tag_for_index(layout, selected_index)
	if _is_forest_main_tag(selected_tag):
		return (
			_tile_data(TILE_GRASS_TO_ROAD, TILE_SECTION_TERRAIN, &"grass_to_road")
			if _route_rect_edge_touches_non_route(layout, cell, selected_index)
			else _tile_data(TILE_FOREST_ROAD, TILE_SECTION_TERRAIN, &"forest_road")
		)
	if _is_forest_path_tag(selected_tag):
		return (
			_tile_data(TILE_GRASS_TO_PATH, TILE_SECTION_TERRAIN, &"grass_to_path")
			if _route_rect_edge_touches_non_route(layout, cell, selected_index)
			else _tile_data(TILE_FOREST_PATH, TILE_SECTION_TERRAIN, &"forest_path")
		)
	var terrain_tile_id := _resolve_terrain_route_tile_id(
		layout,
		cell,
		selected_index,
		selected_tag,
		matching_indices.size()
	)
	return _tile_data(
		terrain_tile_id,
		TILE_SECTION_TERRAIN,
		_resolve_terrain_route_role(terrain_tile_id)
	)

func _resolve_route_tile_data(
	layout: BiomeEnvironmentLayout,
	cell: Vector2i,
	biome_id: StringName = &"",
	biome_cell: BiomeCell = null
) -> Dictionary:
	var cell_route_tags := layout.get_road_tags_at_cell(cell)
	if not cell_route_tags.is_empty():
		if _is_forest_biome(biome_id):
			return _resolve_forest_cell_route_tile_data(layout, cell, cell_route_tags, biome_cell)
		return _resolve_cell_route_tile_data(layout, cell, cell_route_tags)
	var matching_indices: Array[int] = []
	for index in range(layout.road_rects.size()):
		if layout.road_rects[index].has_point(cell):
			matching_indices.append(index)
	if matching_indices.is_empty():
		return {}
	if _is_forest_biome(biome_id):
		return _resolve_forest_rect_route_tile_data(
			layout,
			cell,
			matching_indices,
			biome_cell
		)
	var selected_passage_index := -1
	for index in matching_indices:
		var passage_tag := _road_tag_for_index(layout, index)
		if not _is_passage_type(passage_tag):
			continue
		if _cell_inside_any_rect(cell, layout.passage_rects):
			var endpoint_tile := (
				get_passage_exit_tile_id(passage_tag)
				if _cell_on_outer_passage_edge(layout, cell)
				else get_passage_entry_tile_id(passage_tag)
			)
			return _tile_data(
				endpoint_tile,
				TILE_SECTION_PASSAGE,
				&"passage_exit" if String(endpoint_tile).ends_with("_exit") else &"passage_entry"
			)
		selected_passage_index = index
	if selected_passage_index >= 0:
		return _tile_data(
			_road_tag_for_index(layout, selected_passage_index),
			TILE_SECTION_PASSAGE,
			&"passage_connector"
		)
	var selected_index := matching_indices[matching_indices.size() - 1]
	var selected_tag := _road_tag_for_index(layout, selected_index)
	var terrain_tile_id := _resolve_terrain_route_tile_id(
		layout,
		cell,
		selected_index,
		selected_tag,
		matching_indices.size()
	)
	return _tile_data(
		terrain_tile_id,
		TILE_SECTION_TERRAIN,
		_resolve_terrain_route_role(terrain_tile_id)
	)

func _road_tag_for_index(layout: BiomeEnvironmentLayout, index: int) -> StringName:
	if index >= 0 and index < layout.road_rect_tags.size():
		return layout.road_rect_tags[index]
	return TILE_ROAD

func _resolve_cell_route_tile_data(
	layout: BiomeEnvironmentLayout,
	cell: Vector2i,
	route_tags: Array[StringName]
) -> Dictionary:
	var passage_tag := _find_passage_tag(route_tags)
	if not passage_tag.is_empty():
		if _cell_inside_any_rect(cell, layout.passage_rects):
			var endpoint_tile := (
				get_passage_exit_tile_id(passage_tag)
				if _cell_on_outer_passage_edge(layout, cell)
				else get_passage_entry_tile_id(passage_tag)
			)
			return _tile_data(
				endpoint_tile,
				TILE_SECTION_PASSAGE,
				&"passage_exit" if String(endpoint_tile).ends_with("_exit") else &"passage_entry"
			)
		return _tile_data(passage_tag, TILE_SECTION_PASSAGE, &"passage_connector")
	if route_tags.size() > 1:
		return _tile_data(
			TILE_ROAD_INTERSECTION,
			TILE_SECTION_TERRAIN,
			&"road_intersection"
		)
	var selected_tag: StringName = route_tags[route_tags.size() - 1]
	if _route_cell_touches_non_route(layout, cell):
		return _tile_data(TILE_ROAD_EDGE, TILE_SECTION_TERRAIN, &"road_edge")
	if _count_route_neighbors(layout, cell) <= 1:
		return _tile_data(TILE_ROAD_EDGE, TILE_SECTION_TERRAIN, &"road_edge")
	return _tile_data(selected_tag, TILE_SECTION_TERRAIN, &"road")

func _find_passage_tag(route_tags: Array[StringName]) -> StringName:
	for tag in route_tags:
		if _is_passage_type(tag):
			return tag
	return &""

func _count_route_neighbors(layout: BiomeEnvironmentLayout, cell: Vector2i) -> int:
	var count := 0
	for offset in NEIGHBOR_OFFSETS:
		if layout.has_road_cell(cell + offset):
			count += 1
	return count

func _resolve_terrain_route_tile_id(
	layout: BiomeEnvironmentLayout,
	cell: Vector2i,
	road_index: int,
	tag: StringName,
	match_count: int
) -> StringName:
	if match_count > 1:
		return TILE_ROAD_INTERSECTION
	if road_index < 0 or road_index >= layout.road_rects.size():
		return tag
	var rect := layout.road_rects[road_index]
	if _cell_on_zone_touching_endpoint(layout.zone_size, rect, cell):
		return TILE_ROAD_EDGE
	var rect_end := rect.position + rect.size - Vector2i.ONE
	if rect.size.x >= rect.size.y:
		if cell.x == rect.position.x:
			return TILE_ROAD_CURVE_WEST
		if cell.x == rect_end.x:
			return TILE_ROAD_CURVE_EAST
		if cell.y == rect.position.y or cell.y == rect_end.y:
			return TILE_ROAD_EDGE
	else:
		if cell.y == rect.position.y:
			return TILE_ROAD_CURVE_NORTH
		if cell.y == rect_end.y:
			return TILE_ROAD_CURVE_SOUTH
		if cell.x == rect.position.x or cell.x == rect_end.x:
			return TILE_ROAD_EDGE
	return tag

func _resolve_terrain_route_role(tile_id: StringName) -> StringName:
	match tile_id:
		TILE_ROAD_INTERSECTION:
			return &"road_intersection"
		TILE_ROAD_EDGE:
			return &"road_edge"
		TILE_ROAD_CURVE_NORTH, TILE_ROAD_CURVE_EAST, TILE_ROAD_CURVE_SOUTH, TILE_ROAD_CURVE_WEST:
			return &"road_curve"
		_:
			return &"road"

func _resolve_forest_grass_variant(
	layout: BiomeEnvironmentLayout,
	cell: Vector2i,
	quality_preset: StringName
) -> StringName:
	var variants: Array[StringName] = []
	match quality_preset:
		&"performance":
			variants = [TILE_FOREST_GRASS, TILE_FOREST_GRASS_VARIANT_01]
		&"quality":
			variants = FOREST_GRASS_VARIANTS.duplicate()
		_:
			variants = [TILE_FOREST_GRASS, TILE_FOREST_GRASS_VARIANT_01, TILE_FOREST_GRASS_VARIANT_02]
	var index := posmod(
		_stable_cell_hash(layout.generation_seed, FOREST_BIOME_ID, cell),
		variants.size()
	)
	return variants[index]

func _is_forest_biome(biome_id: StringName) -> bool:
	return biome_id == FOREST_BIOME_ID

func _is_forest_main_tag(tag: StringName) -> bool:
	return tag == TILE_MAIN_ROAD or tag == TILE_FOREST_ROAD

func _is_forest_path_tag(tag: StringName) -> bool:
	return tag == TILE_BROKEN_STREET or tag == TILE_FOREST_PATH

func _array_has_forest_main(tags: Array[StringName]) -> bool:
	for tag in tags:
		if _is_forest_main_tag(tag):
			return true
	return false

func _array_has_forest_path(tags: Array[StringName]) -> bool:
	for tag in tags:
		if _is_forest_path_tag(tag):
			return true
	return false

func _array_has_forest_main_and_path(tags: Array[StringName]) -> bool:
	return _array_has_forest_main(tags) and _array_has_forest_path(tags)

func _route_cell_touches_non_route(
	layout: BiomeEnvironmentLayout,
	cell: Vector2i
) -> bool:
	for offset in CARDINAL_OFFSETS:
		var neighbor := cell + offset
		if not _cell_inside_layout(layout, neighbor):
			return true
		if not layout.has_road_cell(neighbor) and not _cell_inside_any_rect(neighbor, layout.road_rects):
			return true
	return false

func _route_rect_edge_touches_non_route(
	layout: BiomeEnvironmentLayout,
	cell: Vector2i,
	road_index: int
) -> bool:
	if road_index < 0 or road_index >= layout.road_rects.size():
		return _route_cell_touches_non_route(layout, cell)
	var rect := layout.road_rects[road_index]
	var rect_end := rect.position + rect.size - Vector2i.ONE
	return (
		cell.x == rect.position.x
		or cell.y == rect.position.y
		or cell.x == rect_end.x
		or cell.y == rect_end.y
	)

func _cell_touches_void_or_fall(
	layout: BiomeEnvironmentLayout,
	cell: Vector2i,
	biome_cell: BiomeCell
) -> bool:
	for offset in NEIGHBOR_OFFSETS:
		var terrain_class := layout.get_terrain_class_at_cell(cell + offset, biome_cell)
		if (
			terrain_class == BiomeEnvironmentLayout.TERRAIN_VOID
			or terrain_class == BiomeEnvironmentLayout.TERRAIN_FALL_ZONE
		):
			return true
	return false

func _cell_touches_wall_or_border(
	layout: BiomeEnvironmentLayout,
	cell: Vector2i,
	biome_cell: BiomeCell
) -> bool:
	for offset in NEIGHBOR_OFFSETS:
		var neighbor := cell + offset
		var terrain_class := layout.get_terrain_class_at_cell(neighbor, biome_cell)
		if terrain_class == BiomeEnvironmentLayout.TERRAIN_BORDER:
			return true
		if _cell_inside_wall_segments(layout, neighbor):
			return true
	return false

func _cell_touches_floor_tag(
	layout: BiomeEnvironmentLayout,
	cell: Vector2i,
	floor_tag: StringName
) -> bool:
	for offset in NEIGHBOR_OFFSETS:
		if layout.get_floor_tag_at_cell(cell + offset) == floor_tag:
			return true
	return false

func _cell_touches_non_tall_walkable(
	layout: BiomeEnvironmentLayout,
	cell: Vector2i,
	biome_cell: BiomeCell
) -> bool:
	for offset in NEIGHBOR_OFFSETS:
		var neighbor := cell + offset
		if layout.get_terrain_class_at_cell(neighbor, biome_cell) != BiomeEnvironmentLayout.TERRAIN_WALKABLE:
			continue
		if layout.get_floor_tag_at_cell(neighbor) != TILE_FOREST_TALL_GRASS:
			return true
	return false

func _cell_inside_wall_segments(
	layout: BiomeEnvironmentLayout,
	cell: Vector2i
) -> bool:
	return _cell_inside_any_rect(cell, layout.wall_segment_rects)

func _cell_inside_layout(layout: BiomeEnvironmentLayout, cell: Vector2i) -> bool:
	return (
		cell.x >= 0
		and cell.y >= 0
		and cell.x < layout.zone_size.x
		and cell.y < layout.zone_size.y
	)

func _resolve_floor_variant(
	layout: BiomeEnvironmentLayout,
	cell: Vector2i,
	biome_id: StringName,
	quality_preset: StringName
) -> StringName:
	var variants := get_floor_variants_for_preset(quality_preset)
	if variants.is_empty():
		return TILE_FLOOR_BASE
	var seed := layout.generation_seed if layout != null else 0
	var index := posmod(_stable_cell_hash(seed, biome_id, cell), variants.size())
	return variants[index]

func _fall_zone_cell_touches_floor(
	layout: BiomeEnvironmentLayout,
	cell: Vector2i,
	biome_cell: BiomeCell
) -> bool:
	for offset in CARDINAL_OFFSETS:
		var neighbor_class := layout.get_terrain_class_at_cell(cell + offset, biome_cell)
		if (
			neighbor_class != BiomeEnvironmentLayout.TERRAIN_VOID
			and neighbor_class != BiomeEnvironmentLayout.TERRAIN_FALL_ZONE
		):
			return true
	return false

func _tile_data(tile_id: StringName, section: StringName, role: StringName) -> Dictionary:
	var asset_path := ""
	if manifest != null and not tile_id.is_empty() and not section.is_empty():
		asset_path = String(
			manifest.get_asset_contract(section, tile_id).get("asset_path", "")
		)
	return {
		"tile_id": tile_id,
		"section": section,
		"role": role,
		"asset_path": asset_path
	}

func _is_passage_type(tile_id: StringName) -> bool:
	return PASSAGE_TYPES.has(tile_id)

func _is_passage_endpoint_tile(tile_id: StringName) -> bool:
	return (
		tile_id == TILE_ROAD_ENTRY
		or tile_id == TILE_ROAD_EXIT
		or tile_id == TILE_BRIDGE_ENTRY
		or tile_id == TILE_BRIDGE_EXIT
		or tile_id == TILE_SNOW_PASS_ENTRY
		or tile_id == TILE_SNOW_PASS_EXIT
		or tile_id == TILE_BROKEN_GATE_ENTRY
		or tile_id == TILE_BROKEN_GATE_EXIT
		or tile_id == TILE_BURNED_ROAD_ENTRY
		or tile_id == TILE_BURNED_ROAD_EXIT
	)

func _cell_on_outer_passage_edge(
	layout: BiomeEnvironmentLayout,
	cell: Vector2i
) -> bool:
	for rect in layout.passage_rects:
		if not rect.has_point(cell):
			continue
		if rect.position.x <= 0 and cell.x == rect.position.x:
			return true
		if rect.position.y <= 0 and cell.y == rect.position.y:
			return true
		if rect.position.x + rect.size.x >= layout.zone_size.x and cell.x == rect.position.x + rect.size.x - 1:
			return true
		if rect.position.y + rect.size.y >= layout.zone_size.y and cell.y == rect.position.y + rect.size.y - 1:
			return true
	return false

func _cell_on_zone_touching_endpoint(
	zone_size: Vector2i,
	rect: Rect2i,
	cell: Vector2i
) -> bool:
	var rect_end := rect.position + rect.size - Vector2i.ONE
	return (
		(rect.position.x <= 0 and cell.x == rect.position.x)
		or (rect.position.y <= 0 and cell.y == rect.position.y)
		or (rect_end.x >= zone_size.x - 1 and cell.x == rect_end.x)
		or (rect_end.y >= zone_size.y - 1 and cell.y == rect_end.y)
	)

func _cell_inside_any_rect(cell: Vector2i, rects: Array[Rect2i]) -> bool:
	for rect in rects:
		if rect.has_point(cell):
			return true
	return false

func _stable_cell_hash(seed: int, biome_id: StringName, cell: Vector2i) -> int:
	var biome_hash := _stable_string_hash(String(biome_id))
	var value := seed * 1103515245
	value += cell.x * 73856093
	value += cell.y * 19349663
	value += biome_hash * 83492791
	return posmod(value, 2147483647)

func _stable_string_hash(text: String) -> int:
	var value := 17
	for index in range(text.length()):
		value = posmod(value * 31 + text.unicode_at(index), 2147483647)
	return value

func _asset_path_exists(asset_path: String) -> bool:
	if asset_path.is_empty():
		return false
	if ResourceLoader.exists(asset_path):
		return true
	return FileAccess.file_exists(asset_path)
