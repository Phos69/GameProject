extends RefCounted
class_name BiomeTileResolver

const TILE_CATALOG := preload("res://game/modes/zombie/biome_tile_catalog.gd")
const RESOLVER_UTILS := preload("res://game/modes/zombie/biome_tile_resolver_utils.gd")
const GENERATED_ART_CATALOG := preload(
	"res://game/modes/zombie/biome_generated_art_catalog.gd"
)

const TILE_FLOOR_BASE := TILE_CATALOG.TILE_FLOOR_BASE
const TILE_FLOOR_VARIANT_01 := TILE_CATALOG.TILE_FLOOR_VARIANT_01
const TILE_FLOOR_VARIANT_02 := TILE_CATALOG.TILE_FLOOR_VARIANT_02
const TILE_FLOOR_VARIANT_03 := TILE_CATALOG.TILE_FLOOR_VARIANT_03
const FOREST_BIOME_ID := TILE_CATALOG.FOREST_BIOME_ID
const TILE_FOREST_GRASS := TILE_CATALOG.TILE_FOREST_GRASS
const TILE_FOREST_GRASS_VARIANT_01 := TILE_CATALOG.TILE_FOREST_GRASS_VARIANT_01
const TILE_FOREST_GRASS_VARIANT_02 := TILE_CATALOG.TILE_FOREST_GRASS_VARIANT_02
const TILE_FOREST_TALL_GRASS := TILE_CATALOG.TILE_FOREST_TALL_GRASS
const TILE_FOREST_PATH := TILE_CATALOG.TILE_FOREST_PATH
const TILE_FOREST_ROAD := TILE_CATALOG.TILE_FOREST_ROAD
const TILE_FOREST_VOID := TILE_CATALOG.TILE_FOREST_VOID
const TILE_FOREST_CLIFF_EDGE := TILE_CATALOG.TILE_FOREST_CLIFF_EDGE
const TILE_FOREST_MOUNTAIN_WALL := TILE_CATALOG.TILE_FOREST_MOUNTAIN_WALL
const TILE_GRASS_TO_PATH := TILE_CATALOG.TILE_GRASS_TO_PATH
const TILE_GRASS_TO_ROAD := TILE_CATALOG.TILE_GRASS_TO_ROAD
const TILE_GRASS_TO_TALL_GRASS := TILE_CATALOG.TILE_GRASS_TO_TALL_GRASS
const TILE_PATH_TO_ROAD := TILE_CATALOG.TILE_PATH_TO_ROAD
const TILE_GROUND_TO_VOID_CLIFF := TILE_CATALOG.TILE_GROUND_TO_VOID_CLIFF
const TILE_GROUND_TO_MOUNTAIN_WALL := TILE_CATALOG.TILE_GROUND_TO_MOUNTAIN_WALL
const TILE_ROAD := TILE_CATALOG.TILE_ROAD
const TILE_MAIN_ROAD := TILE_CATALOG.TILE_MAIN_ROAD
const TILE_BROKEN_STREET := TILE_CATALOG.TILE_BROKEN_STREET
const TILE_SERVICE_LANE := TILE_CATALOG.TILE_SERVICE_LANE
const TILE_ASH_LANE := TILE_CATALOG.TILE_ASH_LANE
const TILE_PACKED_SNOW_PATH := TILE_CATALOG.TILE_PACKED_SNOW_PATH
const TILE_WOODEN_WALKWAY := TILE_CATALOG.TILE_WOODEN_WALKWAY
const TILE_BRIDGE := TILE_CATALOG.TILE_BRIDGE
const TILE_SNOW_PASS := TILE_CATALOG.TILE_SNOW_PASS
const TILE_BROKEN_GATE := TILE_CATALOG.TILE_BROKEN_GATE
const TILE_BURNED_ROAD := TILE_CATALOG.TILE_BURNED_ROAD
const TILE_ROAD_INTERSECTION := TILE_CATALOG.TILE_ROAD_INTERSECTION
const TILE_ROAD_EDGE := TILE_CATALOG.TILE_ROAD_EDGE
const TILE_ROAD_CURVE_NORTH := TILE_CATALOG.TILE_ROAD_CURVE_NORTH
const TILE_ROAD_CURVE_EAST := TILE_CATALOG.TILE_ROAD_CURVE_EAST
const TILE_ROAD_CURVE_SOUTH := TILE_CATALOG.TILE_ROAD_CURVE_SOUTH
const TILE_ROAD_CURVE_WEST := TILE_CATALOG.TILE_ROAD_CURVE_WEST
const TILE_ROAD_ENTRY := TILE_CATALOG.TILE_ROAD_ENTRY
const TILE_ROAD_EXIT := TILE_CATALOG.TILE_ROAD_EXIT
const TILE_BRIDGE_ENTRY := TILE_CATALOG.TILE_BRIDGE_ENTRY
const TILE_BRIDGE_EXIT := TILE_CATALOG.TILE_BRIDGE_EXIT
const TILE_SNOW_PASS_ENTRY := TILE_CATALOG.TILE_SNOW_PASS_ENTRY
const TILE_SNOW_PASS_EXIT := TILE_CATALOG.TILE_SNOW_PASS_EXIT
const TILE_BROKEN_GATE_ENTRY := TILE_CATALOG.TILE_BROKEN_GATE_ENTRY
const TILE_BROKEN_GATE_EXIT := TILE_CATALOG.TILE_BROKEN_GATE_EXIT
const TILE_BURNED_ROAD_ENTRY := TILE_CATALOG.TILE_BURNED_ROAD_ENTRY
const TILE_BURNED_ROAD_EXIT := TILE_CATALOG.TILE_BURNED_ROAD_EXIT
const TILE_BRIDGE_BROKEN := TILE_CATALOG.TILE_BRIDGE_BROKEN
const TILE_CLIFF_RAMP := TILE_CATALOG.TILE_CLIFF_RAMP
const TILE_HAZARD_FLOOR := TILE_CATALOG.TILE_HAZARD_FLOOR
const TILE_BORDER_FLOOR := TILE_CATALOG.TILE_BORDER_FLOOR
const TILE_VOID_EDGE_NEAR := TILE_CATALOG.TILE_VOID_EDGE_NEAR
const TILE_VOID_DEPTH := TILE_CATALOG.TILE_VOID_DEPTH
const TILE_VOID_EDGE_NORTH := TILE_CATALOG.TILE_VOID_EDGE_NORTH
const TILE_VOID_EDGE_SOUTH := TILE_CATALOG.TILE_VOID_EDGE_SOUTH
const TILE_VOID_EDGE_EAST := TILE_CATALOG.TILE_VOID_EDGE_EAST
const TILE_VOID_EDGE_WEST := TILE_CATALOG.TILE_VOID_EDGE_WEST
const TILE_VOID_CORNER_INNER_NORTH_EAST := TILE_CATALOG.TILE_VOID_CORNER_INNER_NORTH_EAST
const TILE_VOID_CORNER_INNER_SOUTH_EAST := TILE_CATALOG.TILE_VOID_CORNER_INNER_SOUTH_EAST
const TILE_VOID_CORNER_INNER_SOUTH_WEST := TILE_CATALOG.TILE_VOID_CORNER_INNER_SOUTH_WEST
const TILE_VOID_CORNER_INNER_NORTH_WEST := TILE_CATALOG.TILE_VOID_CORNER_INNER_NORTH_WEST
const TILE_VOID_CORNER_OUTER_NORTH_EAST := TILE_CATALOG.TILE_VOID_CORNER_OUTER_NORTH_EAST
const TILE_VOID_CORNER_OUTER_SOUTH_EAST := TILE_CATALOG.TILE_VOID_CORNER_OUTER_SOUTH_EAST
const TILE_VOID_CORNER_OUTER_SOUTH_WEST := TILE_CATALOG.TILE_VOID_CORNER_OUTER_SOUTH_WEST
const TILE_VOID_CORNER_OUTER_NORTH_WEST := TILE_CATALOG.TILE_VOID_CORNER_OUTER_NORTH_WEST
const TILE_VOID_DIAGONAL_NORTH_EAST_SOUTH_WEST := TILE_CATALOG.TILE_VOID_DIAGONAL_NORTH_EAST_SOUTH_WEST
const TILE_VOID_DIAGONAL_NORTH_WEST_SOUTH_EAST := TILE_CATALOG.TILE_VOID_DIAGONAL_NORTH_WEST_SOUTH_EAST
const VOID_TRANSITION_TILE_IDS := TILE_CATALOG.VOID_TRANSITION_TILE_IDS
const TILE_SECTION_VARIANTS := TILE_CATALOG.TILE_SECTION_VARIANTS
const TILE_SECTION_TERRAIN := TILE_CATALOG.TILE_SECTION_TERRAIN
const TILE_SECTION_PASSAGE := TILE_CATALOG.TILE_SECTION_PASSAGE
const TILE_SECTION_VOID := TILE_CATALOG.TILE_SECTION_VOID
const FLOOR_VARIANTS := TILE_CATALOG.FLOOR_VARIANTS
const FOREST_GRASS_VARIANTS := TILE_CATALOG.FOREST_GRASS_VARIANTS
const CARDINAL_OFFSETS := TILE_CATALOG.CARDINAL_OFFSETS
const NEIGHBOR_OFFSETS := TILE_CATALOG.NEIGHBOR_OFFSETS
const PASSAGE_TYPES := TILE_CATALOG.PASSAGE_TYPES
const TERRAIN_ROUTE_TILE_IDS := TILE_CATALOG.TERRAIN_ROUTE_TILE_IDS
const FOREST_TERRAIN_TILE_IDS := TILE_CATALOG.FOREST_TERRAIN_TILE_IDS
const PASSAGE_ROUTE_TILE_IDS := TILE_CATALOG.PASSAGE_ROUTE_TILE_IDS
const REQUIRED_TILE_IDS := TILE_CATALOG.REQUIRED_TILE_IDS
const GENERATED_THEME_MANIFEST_SURFACE_TILE_IDS: Array[StringName] = [
	TILE_MAIN_ROAD,
	TILE_ROAD,
	TILE_BROKEN_STREET,
	TILE_SERVICE_LANE,
	TILE_ASH_LANE,
	TILE_PACKED_SNOW_PATH,
	TILE_WOODEN_WALKWAY,
	TILE_BRIDGE,
	TILE_SNOW_PASS,
	TILE_BROKEN_GATE,
	TILE_BURNED_ROAD,
	TILE_ROAD_INTERSECTION,
	TILE_ROAD_EDGE,
	TILE_ROAD_CURVE_NORTH,
	TILE_ROAD_CURVE_EAST,
	TILE_ROAD_CURVE_SOUTH,
	TILE_ROAD_CURVE_WEST,
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
# Route del bioma forestale classificate come path oppure asphalt dalla
# TerrainSurfaceClassifier. Gli ID semantici restano pubblici e invariati.
const FOREST_ROUTE_SURFACE_TILE_IDS: Array[StringName] = [
	TILE_FOREST_PATH,
	TILE_FOREST_ROAD,
	TILE_GRASS_TO_PATH,
	TILE_GRASS_TO_ROAD,
	TILE_PATH_TO_ROAD,
	TILE_MAIN_ROAD,
	TILE_ROAD,
	TILE_ROAD_ENTRY,
	TILE_ROAD_EXIT,
	TILE_BROKEN_STREET,
	TILE_SERVICE_LANE,
	TILE_ASH_LANE,
	TILE_PACKED_SNOW_PATH,
	TILE_WOODEN_WALKWAY,
	TILE_ROAD_INTERSECTION,
	TILE_ROAD_EDGE,
	TILE_ROAD_CURVE_NORTH,
	TILE_ROAD_CURVE_EAST,
	TILE_ROAD_CURVE_SOUTH,
	TILE_ROAD_CURVE_WEST,
	TILE_BROKEN_GATE,
	TILE_BROKEN_GATE_ENTRY,
	TILE_BROKEN_GATE_EXIT,
	TILE_BURNED_ROAD,
	TILE_BURNED_ROAD_ENTRY,
	TILE_BURNED_ROAD_EXIT,
	TILE_BRIDGE,
	TILE_BRIDGE_ENTRY,
	TILE_BRIDGE_EXIT,
	TILE_SNOW_PASS,
	TILE_SNOW_PASS_ENTRY,
	TILE_SNOW_PASS_EXIT,
	TILE_BRIDGE_BROKEN,
	TILE_CLIFF_RAMP,
]
const FOREST_PATH_TERRAIN_ASSET_ID: StringName = &"forest_path"
const FOREST_ROAD_TERRAIN_ASSET_ID: StringName = &"forest_road"
const GENERATED_THEME_GENERATED_ROUTE_TILE_IDS: Array[StringName] = [
	TILE_MAIN_ROAD,
	TILE_ROAD,
	TILE_BROKEN_STREET,
	TILE_SERVICE_LANE,
	TILE_ASH_LANE,
	TILE_PACKED_SNOW_PATH,
	TILE_WOODEN_WALKWAY,
	TILE_ROAD_INTERSECTION,
	TILE_ROAD_EDGE,
	TILE_ROAD_CURVE_NORTH,
	TILE_ROAD_CURVE_EAST,
	TILE_ROAD_CURVE_SOUTH,
	TILE_ROAD_CURVE_WEST,
]
const GENERATED_THEME_GENERATED_PASSAGE_SURFACE_TILE_IDS: Array[StringName] = [
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
]

var manifest: EnvironmentAssetManifest
var _forest_route_asset_paths: Dictionary = {}

func _init(next_manifest: EnvironmentAssetManifest = null) -> void:
	manifest = next_manifest if next_manifest != null else EnvironmentAssetManifest.get_shared()

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
	var resolved := _resolve_tile_data_unskinned(
		layout,
		cell,
		biome_id,
		quality_preset,
		biome_cell
	)
	return _apply_generated_material(resolved, layout, cell, biome_id)

func _resolve_tile_data_unskinned(
	layout: BiomeEnvironmentLayout,
	cell: Vector2i,
	biome_id: StringName,
	quality_preset: StringName,
	biome_cell: BiomeCell
) -> Dictionary:
	if layout == null:
		return _tile_data(&"", &"", &"missing")
	var terrain_class := layout.get_terrain_class_at_cell(cell, biome_cell)
	if _uses_themed_surface(biome_id):
		var forest_data := _resolve_forest_tile_data(
			layout,
			cell,
			terrain_class,
			quality_preset,
			biome_cell,
			biome_id
		)
		if not forest_data.is_empty():
			return forest_data
	match terrain_class:
		BiomeEnvironmentLayout.TERRAIN_VOID:
			var void_cliff := _resolve_void_tile_data(layout, cell, biome_cell, TILE_VOID_DEPTH)
			if StringName(void_cliff.get("tile_id", &"")) != TILE_VOID_DEPTH:
				return void_cliff
			return _tile_data(TILE_VOID_DEPTH, TILE_SECTION_VOID, &"void_depth")
		BiomeEnvironmentLayout.TERRAIN_FALL_ZONE:
			return _resolve_void_tile_data(layout, cell, biome_cell, TILE_VOID_DEPTH)
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
		is_void_transition_tile_id(tile_id)
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
	return RESOLVER_UTILS.asset_path_exists(asset_path)

func get_required_tile_ids() -> Array[StringName]:
	return REQUIRED_TILE_IDS.duplicate()

func is_void_transition_tile_id(tile_id: StringName) -> bool:
	return VOID_TRANSITION_TILE_IDS.has(tile_id)

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
	biome_cell: BiomeCell,
	biome_id: StringName
) -> Dictionary:
	match terrain_class:
		BiomeEnvironmentLayout.TERRAIN_VOID:
			if not _cell_inside_layout(layout, cell):
				return _tile_data(TILE_VOID_DEPTH, TILE_SECTION_VOID, &"void_depth")
			var void_cliff := _resolve_void_tile_data(layout, cell, biome_cell, TILE_FOREST_VOID)
			if StringName(void_cliff.get("tile_id", &"")) != TILE_FOREST_VOID:
				return void_cliff
			return _tile_data(TILE_FOREST_VOID, TILE_SECTION_VOID, &"forest_void")
		BiomeEnvironmentLayout.TERRAIN_FALL_ZONE:
			return _resolve_void_tile_data(layout, cell, biome_cell, TILE_FOREST_VOID)
		BiomeEnvironmentLayout.TERRAIN_BORDER:
			return _tile_data(TILE_FOREST_MOUNTAIN_WALL, &"edge_tiles", &"forest_mountain_wall")
		BiomeEnvironmentLayout.TERRAIN_OBSTACLE:
			if _cell_inside_wall_segments(layout, cell):
				return _tile_data(TILE_FOREST_MOUNTAIN_WALL, &"edge_tiles", &"forest_mountain_wall")
		BiomeEnvironmentLayout.TERRAIN_HAZARD:
			if not _is_forest_biome(biome_id):
				return _resolve_forest_floor_tile_data(
					layout,
					cell,
					quality_preset,
					biome_cell,
					biome_id
				)
			return {}

	var route_data := _resolve_route_tile_data(layout, cell, biome_id, biome_cell)
	if not route_data.is_empty():
		return route_data
	# Obstacle-occupied cells render with the exact same floor logic as the
	# walkable ground around them (block floor tag, tall-grass transitions, …) so
	# the footprint never reads as a distinct "hitbox" patch. The solid asset on
	# top is what marks the obstacle; the ground beneath it stays uniform.
	if (
		terrain_class == BiomeEnvironmentLayout.TERRAIN_WALKABLE
		or terrain_class == BiomeEnvironmentLayout.TERRAIN_OBSTACLE
	):
		return _resolve_forest_floor_tile_data(
			layout,
			cell,
			quality_preset,
			biome_cell,
			biome_id
		)
	return {}

func _resolve_forest_floor_tile_data(
	layout: BiomeEnvironmentLayout,
	cell: Vector2i,
	quality_preset: StringName,
	biome_cell: BiomeCell,
	biome_id: StringName
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
		_resolve_forest_grass_variant(layout, cell, quality_preset, biome_id),
		TILE_SECTION_TERRAIN,
		&"forest_grass"
	)

func _resolve_route_tile_data(
	layout: BiomeEnvironmentLayout,
	cell: Vector2i,
	biome_id: StringName = &"",
	biome_cell: BiomeCell = null
) -> Dictionary:
	var passage_rect_data := _resolve_passage_rect_route_tile_data(layout, cell)
	if not passage_rect_data.is_empty():
		return passage_rect_data
	var cell_route_tags := layout.get_road_tags_at_cell(cell)
	if not cell_route_tags.is_empty():
		return _resolve_cell_route_tile_data(
			layout,
			cell,
			cell_route_tags,
			biome_id,
			biome_cell
		)
	var matching_indices: Array[int] = []
	for index in range(layout.road_rects.size()):
		if layout.road_rects[index].has_point(cell):
			matching_indices.append(index)
	if matching_indices.is_empty():
		return {}
	return _resolve_rect_route_tile_data(
		layout,
		cell,
		matching_indices,
		biome_id,
		biome_cell
	)

func _resolve_rect_route_tile_data(
	layout: BiomeEnvironmentLayout,
	cell: Vector2i,
	matching_indices: Array[int],
	biome_id: StringName,
	biome_cell: BiomeCell
) -> Dictionary:
	var has_main := false
	var has_path := false
	var selected_passage_index := -1
	for index in matching_indices:
		var route_tag := _road_tag_for_index(layout, index)
		has_main = has_main or _is_forest_main_tag(route_tag)
		has_path = has_path or _is_forest_path_tag(route_tag)
		if not _is_passage_type(route_tag):
			continue
		if RESOLVER_UTILS.cell_inside_any_rect(cell, layout.passage_rects):
			return _resolve_passage_endpoint_tile_data(layout, cell, route_tag)
		selected_passage_index = index
	if selected_passage_index >= 0:
		return _resolve_passage_connector_tile_data(
			layout,
			cell,
			_road_tag_for_index(layout, selected_passage_index)
		)
	var is_forest := _is_forest_biome(biome_id)
	if is_forest:
		var transition_data := _resolve_forest_route_transition_tile_data(
			layout,
			cell,
			biome_cell
		)
		if not transition_data.is_empty():
			return transition_data
		if has_main and has_path:
			return (
				_tile_data(TILE_GRASS_TO_ROAD, TILE_SECTION_TERRAIN, &"grass_to_road")
				if _route_cell_touches_non_route(layout, cell)
				else _tile_data(TILE_PATH_TO_ROAD, TILE_SECTION_TERRAIN, &"path_to_road")
			)
	var selected_index := matching_indices[matching_indices.size() - 1]
	var selected_tag := _road_tag_for_index(layout, selected_index)
	if is_forest:
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

# Nei route forestali il raccordo cliff/parete ha priorita' sulla superficie
# strada; negli altri biomi i cliff sono gestiti dal renderer dedicato.
func _resolve_forest_route_transition_tile_data(
	layout: BiomeEnvironmentLayout,
	cell: Vector2i,
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
	return {}

func _resolve_passage_rect_route_tile_data(
	layout: BiomeEnvironmentLayout,
	cell: Vector2i
) -> Dictionary:
	for index in range(layout.road_rects.size() - 1, -1, -1):
		if not layout.road_rects[index].has_point(cell):
			continue
		var passage_tag := _road_tag_for_index(layout, index)
		if not _is_passage_type(passage_tag):
			continue
		if RESOLVER_UTILS.cell_inside_any_rect(cell, layout.passage_rects):
			return _resolve_passage_endpoint_tile_data(layout, cell, passage_tag)
		if RESOLVER_UTILS.cell_inside_any_rect(cell, layout.passage_connector_rects):
			return _resolve_passage_connector_tile_data(layout, cell, passage_tag)
	return {}

func _resolve_passage_tile_data(
	layout: BiomeEnvironmentLayout,
	cell: Vector2i,
	passage_tag: StringName
) -> Dictionary:
	if RESOLVER_UTILS.cell_inside_any_rect(cell, layout.passage_rects):
		return _resolve_passage_endpoint_tile_data(layout, cell, passage_tag)
	return _resolve_passage_connector_tile_data(layout, cell, passage_tag)

func _resolve_passage_endpoint_tile_data(
	layout: BiomeEnvironmentLayout,
	cell: Vector2i,
	passage_tag: StringName
) -> Dictionary:
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

func _resolve_passage_connector_tile_data(
	layout: BiomeEnvironmentLayout,
	cell: Vector2i,
	passage_tag: StringName
) -> Dictionary:
	if _cell_on_inner_passage_entry(layout, cell):
		return _tile_data(
			get_passage_entry_tile_id(passage_tag),
			TILE_SECTION_PASSAGE,
			&"passage_entry"
		)
	return _tile_data(passage_tag, TILE_SECTION_PASSAGE, &"passage_connector")

func _road_tag_for_index(layout: BiomeEnvironmentLayout, index: int) -> StringName:
	if index >= 0 and index < layout.road_rect_tags.size():
		return layout.road_rect_tags[index]
	return TILE_ROAD

func _resolve_cell_route_tile_data(
	layout: BiomeEnvironmentLayout,
	cell: Vector2i,
	route_tags: Array[StringName],
	biome_id: StringName,
	biome_cell: BiomeCell
) -> Dictionary:
	var passage_tag := _find_passage_tag(route_tags)
	if not passage_tag.is_empty():
		return _resolve_passage_tile_data(layout, cell, passage_tag)
	if _is_forest_biome(biome_id):
		var transition_data := _resolve_forest_route_transition_tile_data(
			layout,
			cell,
			biome_cell
		)
		if not transition_data.is_empty():
			return transition_data
		if _array_has_forest_main_and_path(route_tags):
			return (
				_tile_data(TILE_GRASS_TO_ROAD, TILE_SECTION_TERRAIN, &"grass_to_road")
				if _route_cell_touches_non_route(layout, cell)
				else _tile_data(TILE_PATH_TO_ROAD, TILE_SECTION_TERRAIN, &"path_to_road")
			)
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
		return (
			TILE_ROAD_EDGE
			if _route_cell_touches_non_route(layout, cell)
			else TILE_ROAD_INTERSECTION
		)
	if road_index < 0 or road_index >= layout.road_rects.size():
		return tag
	var touches_non_route := _route_cell_touches_non_route(layout, cell)
	if not touches_non_route:
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
	quality_preset: StringName,
	biome_id: StringName = FOREST_BIOME_ID
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
		RESOLVER_UTILS.stable_cell_hash(
			layout.generation_seed,
			FOREST_BIOME_ID if _is_forest_biome(biome_id) else biome_id,
			cell
		),
		variants.size()
	)
	return variants[index]

func _is_forest_biome(biome_id: StringName) -> bool:
	return biome_id == FOREST_BIOME_ID

func _uses_themed_surface(biome_id: StringName) -> bool:
	return (
		_is_forest_biome(biome_id)
		or GENERATED_ART_CATALOG.has_generated_theme(biome_id)
	)

func _is_forest_main_tag(tag: StringName) -> bool:
	return tag == TILE_MAIN_ROAD or tag == TILE_FOREST_ROAD

func _is_forest_path_tag(tag: StringName) -> bool:
	return (
		tag == TILE_BROKEN_STREET
		or tag == TILE_FOREST_PATH
		or tag == TILE_SERVICE_LANE
		or tag == TILE_ASH_LANE
		or tag == TILE_PACKED_SNOW_PATH
		or tag == TILE_WOODEN_WALKWAY
	)

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
		if not _cell_is_route_surface(layout, cell + offset):
			return true
	return false

func _route_rect_edge_touches_non_route(
	layout: BiomeEnvironmentLayout,
	cell: Vector2i,
	road_index: int
) -> bool:
	if road_index < 0 or road_index >= layout.road_rects.size():
		return _route_cell_touches_non_route(layout, cell)
	return _route_cell_touches_non_route(layout, cell)

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
	return layout.is_wall_segment_cell(cell)

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
	var index := posmod(RESOLVER_UTILS.stable_cell_hash(seed, biome_id, cell), variants.size())
	return variants[index]

func _resolve_void_tile_data(
	layout: BiomeEnvironmentLayout,
	cell: Vector2i,
	biome_cell: BiomeCell,
	depth_tile_id: StringName
) -> Dictionary:
	var north := _void_neighbor_is_ground(layout, cell + Vector2i.UP, biome_cell)
	var east := _void_neighbor_is_ground(layout, cell + Vector2i.RIGHT, biome_cell)
	var south := _void_neighbor_is_ground(layout, cell + Vector2i.DOWN, biome_cell)
	var west := _void_neighbor_is_ground(layout, cell + Vector2i.LEFT, biome_cell)
	var cardinal_count := int(north) + int(east) + int(south) + int(west)

	if cardinal_count == 1:
		if north:
			return _void_transition_data(TILE_VOID_EDGE_NORTH, &"void_edge_north")
		if east:
			return _void_transition_data(TILE_VOID_EDGE_EAST, &"void_edge_east")
		if south:
			return _void_transition_data(TILE_VOID_EDGE_SOUTH, &"void_edge_south")
		return _void_transition_data(TILE_VOID_EDGE_WEST, &"void_edge_west")

	if cardinal_count == 2:
		if north and east:
			return _void_transition_data(
				TILE_VOID_CORNER_INNER_NORTH_EAST,
				&"void_corner_inner"
			)
		if east and south:
			return _void_transition_data(
				TILE_VOID_CORNER_INNER_SOUTH_EAST,
				&"void_corner_inner"
			)
		if south and west:
			return _void_transition_data(
				TILE_VOID_CORNER_INNER_SOUTH_WEST,
				&"void_corner_inner"
			)
		if west and north:
			return _void_transition_data(
				TILE_VOID_CORNER_INNER_NORTH_WEST,
				&"void_corner_inner"
			)
		if north and south:
			return _void_transition_data(
				TILE_VOID_DIAGONAL_NORTH_EAST_SOUTH_WEST,
				&"void_diagonal"
			)
		return _void_transition_data(
			TILE_VOID_DIAGONAL_NORTH_WEST_SOUTH_EAST,
			&"void_diagonal"
		)

	if cardinal_count >= 3:
		# A one-cell notch is surrounded by playable terrain. Use a closed outer
		# corner so no side of the hole can be mistaken for floor.
		if not north:
			return _void_transition_data(
				TILE_VOID_CORNER_OUTER_NORTH_EAST,
				&"void_corner_outer"
			)
		if not east:
			return _void_transition_data(
				TILE_VOID_CORNER_OUTER_SOUTH_EAST,
				&"void_corner_outer"
			)
		if not south:
			return _void_transition_data(
				TILE_VOID_CORNER_OUTER_SOUTH_WEST,
				&"void_corner_outer"
			)
		return _void_transition_data(
			TILE_VOID_CORNER_OUTER_NORTH_WEST,
			&"void_corner_outer"
		)

	var north_east := _void_neighbor_is_ground(
		layout,
		cell + Vector2i(1, -1),
		biome_cell
	)
	var south_east := _void_neighbor_is_ground(
		layout,
		cell + Vector2i(1, 1),
		biome_cell
	)
	var south_west := _void_neighbor_is_ground(
		layout,
		cell + Vector2i(-1, 1),
		biome_cell
	)
	var north_west := _void_neighbor_is_ground(
		layout,
		cell + Vector2i(-1, -1),
		biome_cell
	)
	var diagonal_count := (
		int(north_east)
		+ int(south_east)
		+ int(south_west)
		+ int(north_west)
	)
	if diagonal_count == 1:
		if north_east:
			return _void_transition_data(
				TILE_VOID_CORNER_OUTER_NORTH_EAST,
				&"void_corner_outer"
			)
		if south_east:
			return _void_transition_data(
				TILE_VOID_CORNER_OUTER_SOUTH_EAST,
				&"void_corner_outer"
			)
		if south_west:
			return _void_transition_data(
				TILE_VOID_CORNER_OUTER_SOUTH_WEST,
				&"void_corner_outer"
			)
		return _void_transition_data(
			TILE_VOID_CORNER_OUTER_NORTH_WEST,
			&"void_corner_outer"
		)
	if north_east and south_west and diagonal_count == 2:
		return _void_transition_data(
			TILE_VOID_DIAGONAL_NORTH_EAST_SOUTH_WEST,
			&"void_diagonal"
		)
	if north_west and south_east and diagonal_count == 2:
		return _void_transition_data(
			TILE_VOID_DIAGONAL_NORTH_WEST_SOUTH_EAST,
			&"void_diagonal"
		)
	return _tile_data(depth_tile_id, TILE_SECTION_VOID, &"void_depth")

func _void_transition_data(tile_id: StringName, role: StringName) -> Dictionary:
	return _tile_data(tile_id, TILE_SECTION_VOID, role)

func _void_neighbor_is_ground(
	layout: BiomeEnvironmentLayout,
	cell: Vector2i,
	biome_cell: BiomeCell
) -> bool:
	var terrain_class := layout.get_terrain_class_at_cell(cell, biome_cell)
	# TERRAIN_BORDER (perimeter wall) counts as solid ground so that fall_zone
	# cells adjacent to a mountain-wall perimeter still resolve to an oriented
	# cliff tile instead of falling back to the untextured void depth tile.
	return (
		terrain_class != BiomeEnvironmentLayout.TERRAIN_VOID
		and terrain_class != BiomeEnvironmentLayout.TERRAIN_FALL_ZONE
	)

func _apply_generated_material(
	tile_data: Dictionary,
	layout: BiomeEnvironmentLayout,
	cell: Vector2i,
	biome_id: StringName
) -> Dictionary:
	if tile_data.is_empty():
		return tile_data
	if not GENERATED_ART_CATALOG.has_generated_theme(biome_id):
		return _apply_forest_route_material(tile_data, layout, cell, biome_id)
	var tile_id := StringName(tile_data.get("tile_id", &""))
	if _uses_manifest_surface_tile(tile_id):
		return tile_data
	var material_role := _generated_surface_role(tile_id)
	if material_role.is_empty():
		return tile_data
	if is_route_surface_cell(layout, cell) and route_cell_uses_lane_surface(layout, cell):
		# Le lane mantengono il proprio riempimento path anche quando il tile ID
		# semantico descrive edge, curva o incrocio.
		material_role = GENERATED_ART_CATALOG.ROLE_PATH
	material_role = GENERATED_ART_CATALOG.resolve_runtime_surface_role(
		biome_id,
		material_role
	)
	var generation_seed := layout.generation_seed if layout != null else 0
	var asset_path := GENERATED_ART_CATALOG.select_surface_asset_path(
		biome_id,
		material_role,
		generation_seed,
		cell
	)
	if asset_path.is_empty():
		return tile_data
	var result := tile_data.duplicate(true)
	result["material_asset_id"] = GENERATED_ART_CATALOG.material_id_from_path(
		asset_path
	)
	result["material_asset_path"] = asset_path
	result["asset_path"] = asset_path
	return result

## La Pianura Infetta conserva gli ID semantici legacy, ma le route tornano a
## usare le texture full-bleed dedicate: dirt path per le lane e asphalt per
## main road/passaggi. Il divisore e' composto separatamente dalla maschera.
func _apply_forest_route_material(
	tile_data: Dictionary,
	layout: BiomeEnvironmentLayout,
	cell: Vector2i,
	biome_id: StringName
) -> Dictionary:
	if not _is_forest_biome(biome_id) or layout == null:
		return tile_data
	var tile_id := StringName(tile_data.get("tile_id", &""))
	if not FOREST_ROUTE_SURFACE_TILE_IDS.has(tile_id):
		return tile_data
	var material_id := (
		FOREST_PATH_TERRAIN_ASSET_ID
		if route_cell_uses_lane_surface(layout, cell)
		else FOREST_ROAD_TERRAIN_ASSET_ID
	)
	var asset_path := _forest_route_asset_path(material_id)
	if asset_path.is_empty():
		return tile_data
	var result := tile_data.duplicate(true)
	result["material_asset_id"] = material_id
	result["material_asset_path"] = asset_path
	result["asset_path"] = asset_path
	return result

func _forest_route_asset_path(asset_id: StringName) -> String:
	if _forest_route_asset_paths.has(asset_id):
		return String(_forest_route_asset_paths[asset_id])
	var asset_path := ""
	if manifest != null:
		asset_path = String(
			manifest.get_terrain_asset_contract(asset_id).get("asset_path", "")
		)
	_forest_route_asset_paths[asset_id] = asset_path
	return asset_path

## True se la cella route appartiene solo a lane tematiche (nessuna strada
## principale la attraversa): la maschera la classifica come path. I passage
## road-like prevalgono sulle lane:
## il generatore carva spoke di lane sotto i corridoi tra biomi, ma quelle
## celle renderizzano asfalto e devono ricevere il bordo strada.
func route_cell_uses_lane_surface(
	layout: BiomeEnvironmentLayout,
	cell: Vector2i
) -> bool:
	if layout == null:
		return false
	if RESOLVER_UTILS.cell_inside_any_rect(cell, layout.passage_rects):
		return false
	if RESOLVER_UTILS.cell_inside_any_rect(cell, layout.passage_connector_rects):
		return false
	var found_lane := false
	for tag in layout.get_road_tags_at_cell(cell):
		if _is_primary_road_tag(tag) or _is_passage_type(tag):
			return false
		if _is_forest_path_tag(tag):
			found_lane = true
	for index in range(layout.road_rects.size()):
		if not layout.road_rects[index].has_point(cell):
			continue
		var tag := _road_tag_for_index(layout, index)
		if _is_primary_road_tag(tag) or _is_passage_type(tag):
			return false
		if _is_forest_path_tag(tag):
			found_lane = true
	return found_lane


## Query visuale pubblica per il classificatore della maschera. Passage e
## connector sono inclusi; la classificazione gameplay resta nel layout.
func is_route_surface_cell(
	layout: BiomeEnvironmentLayout,
	cell: Vector2i
) -> bool:
	return _cell_is_route_surface(layout, cell)


func _is_primary_road_tag(tag: StringName) -> bool:
	return tag == TILE_MAIN_ROAD or tag == TILE_ROAD or tag == TILE_FOREST_ROAD

func _cell_is_route_surface(
	layout: BiomeEnvironmentLayout,
	cell: Vector2i
) -> bool:
	if not _cell_inside_layout(layout, cell):
		return false
	if layout.has_road_cell(cell):
		return true
	for rect in layout.road_rects:
		if rect.has_point(cell):
			return true
	for rect in layout.passage_rects:
		if rect.has_point(cell):
			return true
	for rect in layout.passage_connector_rects:
		if rect.has_point(cell):
			return true
	return false

func _uses_manifest_surface_tile(tile_id: StringName) -> bool:
	if (
		GENERATED_THEME_GENERATED_ROUTE_TILE_IDS.has(tile_id)
		or GENERATED_THEME_GENERATED_PASSAGE_SURFACE_TILE_IDS.has(tile_id)
	):
		return false
	return GENERATED_THEME_MANIFEST_SURFACE_TILE_IDS.has(tile_id)

func _generated_surface_role(tile_id: StringName) -> StringName:
	if is_void_transition_tile_id(tile_id):
		return &""
	match tile_id:
		TILE_MAIN_ROAD, TILE_ROAD, TILE_ROAD_INTERSECTION:
			return GENERATED_ART_CATALOG.ROLE_ROAD
		TILE_BROKEN_STREET, TILE_SERVICE_LANE, TILE_ASH_LANE, TILE_PACKED_SNOW_PATH, TILE_WOODEN_WALKWAY:
			return GENERATED_ART_CATALOG.ROLE_PATH
		TILE_FOREST_GRASS, TILE_FOREST_GRASS_VARIANT_01, TILE_FOREST_GRASS_VARIANT_02, TILE_FOREST_TALL_GRASS, TILE_GRASS_TO_TALL_GRASS, TILE_FOREST_CLIFF_EDGE, TILE_FOREST_MOUNTAIN_WALL, TILE_GROUND_TO_VOID_CLIFF, TILE_GROUND_TO_MOUNTAIN_WALL:
			return GENERATED_ART_CATALOG.ROLE_GROUND
		TILE_FOREST_PATH:
			return GENERATED_ART_CATALOG.ROLE_PATH
		TILE_FOREST_ROAD:
			return GENERATED_ART_CATALOG.ROLE_ROAD
		TILE_GRASS_TO_PATH:
			return GENERATED_ART_CATALOG.ROLE_PATH
		TILE_GRASS_TO_ROAD, TILE_PATH_TO_ROAD:
			return GENERATED_ART_CATALOG.ROLE_ROAD
		TILE_ROAD_EDGE, TILE_ROAD_CURVE_NORTH, TILE_ROAD_CURVE_EAST, TILE_ROAD_CURVE_SOUTH, TILE_ROAD_CURVE_WEST:
			return GENERATED_ART_CATALOG.ROLE_ROAD
	if GENERATED_THEME_GENERATED_PASSAGE_SURFACE_TILE_IDS.has(tile_id):
		return GENERATED_ART_CATALOG.ROLE_ROAD
	if _is_passage_endpoint_tile(tile_id) or PASSAGE_ROUTE_TILE_IDS.has(tile_id):
		return GENERATED_ART_CATALOG.ROLE_PATH
	return &""

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
		"asset_path": asset_path,
		"material_asset_id": &"",
		"material_asset_path": "",
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

func _cell_on_inner_passage_entry(
	layout: BiomeEnvironmentLayout,
	cell: Vector2i
) -> bool:
	if not RESOLVER_UTILS.cell_inside_any_rect(cell, layout.passage_connector_rects):
		return false
	for rect in layout.passage_rects:
		if rect.position.x <= 0 and rect.size.x <= 1:
			if cell.x == rect.position.x + rect.size.x and cell.y >= rect.position.y and cell.y < rect.end.y:
				return true
		elif rect.position.x + rect.size.x >= layout.zone_size.x and rect.size.x <= 1:
			if cell.x == rect.position.x - 1 and cell.y >= rect.position.y and cell.y < rect.end.y:
				return true
		elif rect.position.y <= 0 and rect.size.y <= 1:
			if cell.y == rect.position.y + rect.size.y and cell.x >= rect.position.x and cell.x < rect.end.x:
				return true
		elif rect.position.y + rect.size.y >= layout.zone_size.y and rect.size.y <= 1:
			if cell.y == rect.position.y - 1 and cell.x >= rect.position.x and cell.x < rect.end.x:
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
