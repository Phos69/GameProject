extends RefCounted
class_name IsoGridConfig

## Central contract for the isometric logical grid.
##
## Manifest/object assets keep their legacy footprint cells and native 8 px tile
## scale. Runtime world generation converts those legacy cells to the new logical
## grid, where one generated tile represents a 6x6 legacy tile area.

const LEGACY_TILE_SCALE: float = 8.0
const NEW_TILE_SCALE: int = 6
const LOGICAL_TILE_SCALE: float = LEGACY_TILE_SCALE * float(NEW_TILE_SCALE)

const LEGACY_BIOME_SIZE_TILES: int = 500
const BIOME_SIZE_TILES: int = 75
const BIOME_SIZE: Vector2i = Vector2i(BIOME_SIZE_TILES, BIOME_SIZE_TILES)
const LEGACY_EQUIVALENT_SIZE_TILES: int = BIOME_SIZE_TILES * NEW_TILE_SCALE

const LEGACY_BIOME_TILE_COUNT: int = LEGACY_BIOME_SIZE_TILES * LEGACY_BIOME_SIZE_TILES
const GENERATED_TILE_COUNT: int = BIOME_SIZE_TILES * BIOME_SIZE_TILES
const LEGACY_EQUIVALENT_TILE_COUNT: int = (
	LEGACY_EQUIVALENT_SIZE_TILES * LEGACY_EQUIVALENT_SIZE_TILES
)

const ROAD_WIDTH_TILES: int = 7
const SECONDARY_ROAD_WIDTH_TILES: int = 4
const PASSAGE_WIDTH_TILES: int = 7
const PASSAGE_MIN_WIDTH_TILES: int = 1
const PASSAGE_EDGE_DEPTH_TILES: int = 1
const PASSAGE_SAFE_MARGIN_TILES: int = 21

const BORDER_THICKNESS_TILES: int = 1
const FALL_BOUNDARY_THICKNESS_TILES: int = 1
const RAISED_CLIFF_HEIGHT_TILES: int = 2
const PERIMETER_WALL_HEIGHT_TILES: int = 1
const WALL_SEGMENT_LENGTH_TILES: int = 2
const WALL_MIN_SEGMENT_TILES: int = 1
const WALL_GAP_PADDING_TILES: int = 1
const CROSSING_MARGIN_TILES: int = 1
const SIDE_EDGE_MAX_THICKNESS_TILES: int = 2

const MIN_RECT_GAP_TILES: int = 1
const PROP_BLOCK_MARGIN_TILES: int = 1
const MIN_BLOCK_SIZE_TILES: int = 6
const STARTER_RIVER_WIDTH_TILES: int = 4
const STARTER_RIVER_PADDING_TILES: int = 2
const STARTER_BRIDGE_EXTRA_WIDTH_TILES: int = 3
const STARTER_BRIDGE_PADDING_TILES: int = 1

const VOIDFIRST_ROCK_MIN_SIZE_TILES: int = 3
const VOIDFIRST_ROCK_MAX_SIZE_TILES: int = 5
const VOIDFIRST_ROCK_GAP_TILES: int = 1
const VOIDFIRST_ROCK_MARGIN_TILES: int = 1
const VOIDFIRST_FOREST_MIN_SIZE_TILES: int = 2
const VOIDFIRST_FOREST_MAX_SIZE_TILES: int = 10
const VOIDFIRST_FOREST_EDGE_MARGIN_TILES: int = 1
const VOIDFIRST_TREE_SPACING_TILES: int = 3
const VOIDFIRST_TREE_JITTER_TILES: int = 1
const VOIDFIRST_ROUTE_STEP_TILES: int = 1
const VOIDFIRST_ROAD_ROCK_CLEARANCE_TILES: int = 5
const VOIDFIRST_PATH_WIDTH_TILES: int = 2
const VOIDFIRST_PATH_MAX_LEN_TILES: int = 40
const VOIDFIRST_ROAD_LINE_SPACING_TILES: int = 2
const VOIDFIRST_ROAD_LINE_NEAR_TILES: int = 1
const VOIDFIRST_ROAD_LINE_CONFINE_TILES: int = 1
const VOIDFIRST_VOID_PATCH_TILES: int = 3
const VOIDFIRST_CRATE_OFFSET_TILES: int = 5
const LEGACY_CRATE_OFFSET_TILES: int = 7
const CENTER_RESERVED_HALF_TILES: int = 7

const DEFAULT_CENTRAL_CORRIDOR_WORLD_WIDTH: float = 220.0


static func legacy_cells_to_new_tiles(legacy_cells: int, minimum: int = 1) -> int:
	if legacy_cells <= 0:
		return maxi(minimum, 0)
	return maxi(ceili(float(legacy_cells) / float(NEW_TILE_SCALE)), minimum)


static func legacy_size_to_new_tiles(size: Vector2i, minimum: int = 1) -> Vector2i:
	return Vector2i(
		legacy_cells_to_new_tiles(size.x, minimum),
		legacy_cells_to_new_tiles(size.y, minimum)
	)


static func generated_cell_reduction_report() -> Dictionary:
	return {
		"legacy_biome_size_tiles": LEGACY_BIOME_SIZE_TILES,
		"new_biome_size_tiles": BIOME_SIZE_TILES,
		"legacy_equivalent_size_tiles": LEGACY_EQUIVALENT_SIZE_TILES,
		"legacy_biome_tile_count": LEGACY_BIOME_TILE_COUNT,
		"new_generated_tile_count": GENERATED_TILE_COUNT,
		"legacy_equivalent_tile_count": LEGACY_EQUIVALENT_TILE_COUNT,
		"new_tile_scale": NEW_TILE_SCALE,
		"legacy_tile_scale": LEGACY_TILE_SCALE,
		"logical_tile_scale": LOGICAL_TILE_SCALE
	}
