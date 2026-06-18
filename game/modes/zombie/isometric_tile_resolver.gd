extends RefCounted
class_name IsometricTileResolver

const TILE_FLOOR_BASE: StringName = &"floor_base"
const TILE_FLOOR_VARIANT_01: StringName = &"floor_variant_01"
const TILE_FLOOR_VARIANT_02: StringName = &"floor_variant_02"
const TILE_FLOOR_VARIANT_03: StringName = &"floor_variant_03"
const TILE_ROAD: StringName = &"road"
const TILE_HAZARD_FLOOR: StringName = &"hazard_floor"
const TILE_BORDER_FLOOR: StringName = &"border_floor"
const TILE_VOID_EDGE_NEAR: StringName = &"void_edge_near"
const TILE_VOID_DEPTH: StringName = &"void_depth"

const TILE_SECTION_VARIANTS: StringName = &"tile_variants"
const TILE_SECTION_TERRAIN: StringName = &"terrain_tiles"
const TILE_SECTION_VOID: StringName = &"void_tiles"

const FLOOR_VARIANTS: Array[StringName] = [
	TILE_FLOOR_BASE,
	TILE_FLOOR_VARIANT_01,
	TILE_FLOOR_VARIANT_02,
	TILE_FLOOR_VARIANT_03
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
	TILE_VOID_DEPTH
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
	if layout == null:
		return &""
	var terrain_class := layout.get_terrain_class_at_cell(cell, biome_cell)
	match terrain_class:
		BiomeEnvironmentLayout.TERRAIN_VOID:
			return TILE_VOID_DEPTH
		BiomeEnvironmentLayout.TERRAIN_FALL_ZONE:
			return (
				TILE_VOID_EDGE_NEAR
				if _fall_zone_cell_touches_floor(layout, cell, biome_cell)
				else TILE_VOID_DEPTH
			)
		BiomeEnvironmentLayout.TERRAIN_HAZARD:
			return TILE_HAZARD_FLOOR
		BiomeEnvironmentLayout.TERRAIN_BORDER:
			return TILE_BORDER_FLOOR
		_:
			if _cell_inside_any_rect(cell, layout.road_rects) or _cell_inside_any_rect(cell, layout.passage_rects):
				return TILE_ROAD
			return _resolve_floor_variant(layout, cell, biome_id, quality_preset)

func resolve_tile_section(tile_id: StringName) -> StringName:
	match tile_id:
		TILE_ROAD:
			return TILE_SECTION_TERRAIN
		TILE_VOID_EDGE_NEAR, TILE_VOID_DEPTH:
			return TILE_SECTION_VOID
		_:
			return TILE_SECTION_VARIANTS

func resolve_tile_contract(tile_id: StringName) -> Dictionary:
	if manifest == null or tile_id.is_empty():
		return {}
	return manifest.get_asset_contract(resolve_tile_section(tile_id), tile_id)

func resolve_asset_path(
	layout: BiomeEnvironmentLayout,
	cell: Vector2i,
	biome_id: StringName = &"",
	quality_preset: StringName = &"balanced",
	biome_cell: BiomeCell = null
) -> String:
	var tile_id := resolve_tile_id(layout, cell, biome_id, quality_preset, biome_cell)
	return String(resolve_tile_contract(tile_id).get("asset_path", ""))

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
	for offset in [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1)
	]:
		var neighbor_class := layout.get_terrain_class_at_cell(cell + offset, biome_cell)
		if (
			neighbor_class != BiomeEnvironmentLayout.TERRAIN_VOID
			and neighbor_class != BiomeEnvironmentLayout.TERRAIN_FALL_ZONE
		):
			return true
	return false

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
