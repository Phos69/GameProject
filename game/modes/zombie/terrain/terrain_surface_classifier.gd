extends RefCounted
class_name TerrainSurfaceClassifier

## Classificazione esclusivamente visuale usata dalla maschera del terreno.
## Non sostituisce BiomeEnvironmentLayout.TERRAIN_* e non possiede regole di
## collisione, spawn, danno o pathfinding.

const SURFACE_VOID: int = 0
const SURFACE_GRASS: int = 1
const SURFACE_PATH: int = 2
const SURFACE_ASPHALT: int = 3

const SURFACE_KIND_NAMES: Dictionary = {
	SURFACE_VOID: &"void",
	SURFACE_GRASS: &"grass",
	SURFACE_PATH: &"path",
	SURFACE_ASPHALT: &"asphalt",
}


static func classify_cell(
	layout: BiomeEnvironmentLayout,
	resolver: BiomeTileResolver,
	cell: Vector2i
) -> int:
	if layout == null or not _cell_inside_layout(layout, cell):
		return SURFACE_VOID
	var terrain_class := layout.get_terrain_class_at_cell(cell)
	if (
		terrain_class == BiomeEnvironmentLayout.TERRAIN_VOID
		or terrain_class == BiomeEnvironmentLayout.TERRAIN_FALL_ZONE
	):
		return SURFACE_VOID
	if resolver != null and resolver.is_route_surface_cell(layout, cell):
		return (
			SURFACE_PATH
			if resolver.route_cell_uses_lane_surface(layout, cell)
			else SURFACE_ASPHALT
		)
	return SURFACE_GRASS


static func kind_name(surface_kind: int) -> StringName:
	return StringName(SURFACE_KIND_NAMES.get(surface_kind, &"void"))


static func encoded_weights(surface_kind: int) -> Color:
	match surface_kind:
		SURFACE_GRASS:
			return Color(1.0, 0.0, 0.0, 0.0)
		SURFACE_PATH:
			return Color(0.0, 1.0, 0.0, 0.0)
		SURFACE_ASPHALT:
			return Color(0.0, 0.0, 1.0, 0.0)
		_:
			return Color(0.0, 0.0, 0.0, 0.0)


static func _cell_inside_layout(
	layout: BiomeEnvironmentLayout,
	cell: Vector2i
) -> bool:
	return (
		cell.x >= 0
		and cell.y >= 0
		and cell.x < layout.zone_size.x
		and cell.y < layout.zone_size.y
	)
