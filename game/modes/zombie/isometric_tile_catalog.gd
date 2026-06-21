extends RefCounted
class_name IsometricTileCatalog

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
const TILE_VOID_EDGE_NORTH: StringName = &"void_edge_north"
const TILE_VOID_EDGE_SOUTH: StringName = &"void_edge_south"
const TILE_VOID_EDGE_EAST: StringName = &"void_edge_east"
const TILE_VOID_EDGE_WEST: StringName = &"void_edge_west"
const TILE_VOID_CORNER_INNER_NORTH_EAST: StringName = &"void_corner_inner_north_east"
const TILE_VOID_CORNER_INNER_SOUTH_EAST: StringName = &"void_corner_inner_south_east"
const TILE_VOID_CORNER_INNER_SOUTH_WEST: StringName = &"void_corner_inner_south_west"
const TILE_VOID_CORNER_INNER_NORTH_WEST: StringName = &"void_corner_inner_north_west"
const TILE_VOID_CORNER_OUTER_NORTH_EAST: StringName = &"void_corner_outer_north_east"
const TILE_VOID_CORNER_OUTER_SOUTH_EAST: StringName = &"void_corner_outer_south_east"
const TILE_VOID_CORNER_OUTER_SOUTH_WEST: StringName = &"void_corner_outer_south_west"
const TILE_VOID_CORNER_OUTER_NORTH_WEST: StringName = &"void_corner_outer_north_west"
const TILE_VOID_DIAGONAL_NORTH_EAST_SOUTH_WEST: StringName = &"void_diagonal_north_east_south_west"
const TILE_VOID_DIAGONAL_NORTH_WEST_SOUTH_EAST: StringName = &"void_diagonal_north_west_south_east"
const VOID_TRANSITION_TILE_IDS: Array[StringName] = [
	TILE_VOID_EDGE_NEAR,
	TILE_VOID_EDGE_NORTH,
	TILE_VOID_EDGE_SOUTH,
	TILE_VOID_EDGE_EAST,
	TILE_VOID_EDGE_WEST,
	TILE_VOID_CORNER_INNER_NORTH_EAST,
	TILE_VOID_CORNER_INNER_SOUTH_EAST,
	TILE_VOID_CORNER_INNER_SOUTH_WEST,
	TILE_VOID_CORNER_INNER_NORTH_WEST,
	TILE_VOID_CORNER_OUTER_NORTH_EAST,
	TILE_VOID_CORNER_OUTER_SOUTH_EAST,
	TILE_VOID_CORNER_OUTER_SOUTH_WEST,
	TILE_VOID_CORNER_OUTER_NORTH_WEST,
	TILE_VOID_DIAGONAL_NORTH_EAST_SOUTH_WEST,
	TILE_VOID_DIAGONAL_NORTH_WEST_SOUTH_EAST
]

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
	TILE_VOID_EDGE_NORTH,
	TILE_VOID_EDGE_SOUTH,
	TILE_VOID_EDGE_EAST,
	TILE_VOID_EDGE_WEST,
	TILE_VOID_CORNER_INNER_NORTH_EAST,
	TILE_VOID_CORNER_INNER_SOUTH_EAST,
	TILE_VOID_CORNER_INNER_SOUTH_WEST,
	TILE_VOID_CORNER_INNER_NORTH_WEST,
	TILE_VOID_CORNER_OUTER_NORTH_EAST,
	TILE_VOID_CORNER_OUTER_SOUTH_EAST,
	TILE_VOID_CORNER_OUTER_SOUTH_WEST,
	TILE_VOID_CORNER_OUTER_NORTH_WEST,
	TILE_VOID_DIAGONAL_NORTH_EAST_SOUTH_WEST,
	TILE_VOID_DIAGONAL_NORTH_WEST_SOUTH_EAST,
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
