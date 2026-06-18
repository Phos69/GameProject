extends Node2D
class_name BiomeTileLayer

const DEFAULT_CHUNK_SIZE := 20
const PERFORMANCE_CHUNK_SIZE := 25
const QUALITY_CHUNK_SIZE := 16

var layout: BiomeEnvironmentLayout
var palette: BiomePalette
var biome_id: StringName = &""
var quality_preset: StringName = &"balanced"
var chunk_size: int = DEFAULT_CHUNK_SIZE
var manifest: IsometricEnvironmentManifest
var resolver: IsometricTileResolver

var _chunks: Array[Rect2i] = []
var _tile_id_cache: Dictionary = {}
var _asset_path_cache: Dictionary = {}
var _missing_asset_count: int = 0

func configure(
	next_layout: BiomeEnvironmentLayout,
	next_palette: BiomePalette,
	next_biome_id: StringName,
	next_quality_preset: StringName = &"balanced",
	next_chunk_size: int = 0,
	next_resolver: IsometricTileResolver = null,
	next_manifest: IsometricEnvironmentManifest = null
) -> void:
	layout = next_layout
	palette = next_palette
	biome_id = next_biome_id
	quality_preset = next_quality_preset
	manifest = next_manifest if next_manifest != null else IsometricEnvironmentManifest.get_shared()
	resolver = next_resolver if next_resolver != null else IsometricTileResolver.new(manifest)
	chunk_size = _resolve_chunk_size(next_chunk_size, quality_preset)
	z_index = -9
	add_to_group("biome_tile_layers")
	_rebuild_chunks()
	_rebuild_tile_cache()
	queue_redraw()

func get_chunk_count() -> int:
	return _chunks.size()

func get_chunk_size() -> int:
	return chunk_size

func get_quality_preset() -> StringName:
	return quality_preset

func get_visual_tile_count() -> int:
	return _tile_id_cache.size()

func get_missing_asset_count() -> int:
	return _missing_asset_count

func uses_procedural_fallback() -> bool:
	return _missing_asset_count > 0

func get_chunk_rects() -> Array[Rect2i]:
	return _chunks.duplicate()

func get_resolved_tile_id(cell: Vector2i) -> StringName:
	var key := _cell_key(cell)
	if _tile_id_cache.has(key):
		return StringName(_tile_id_cache[key])
	if resolver == null:
		return &""
	return resolver.resolve_tile_id(layout, cell, biome_id, quality_preset)

func get_resolved_asset_path(cell: Vector2i) -> String:
	var key := _cell_key(cell)
	if _asset_path_cache.has(key):
		return String(_asset_path_cache[key])
	if resolver == null:
		return ""
	return resolver.resolve_asset_path(layout, cell, biome_id, quality_preset)

func has_visual_tile_for_cell(cell: Vector2i) -> bool:
	return _asset_path_exists(get_resolved_asset_path(cell))

func _draw() -> void:
	if layout == null or palette == null:
		return
	for chunk in _chunks:
		for y in range(chunk.position.y, chunk.position.y + chunk.size.y):
			for x in range(chunk.position.x, chunk.position.x + chunk.size.x):
				_draw_tile(Vector2i(x, y))

func _draw_tile(cell: Vector2i) -> void:
	var tile_id := get_resolved_tile_id(cell)
	if tile_id.is_empty():
		return
	var center := _cell_center_to_world(cell)
	var scale := layout.logical_tile_scale
	var half_w := scale * 0.62
	var half_h := scale * 0.34
	var points := PackedVector2Array([
		center + Vector2(0.0, -half_h),
		center + Vector2(half_w, 0.0),
		center + Vector2(0.0, half_h),
		center + Vector2(-half_w, 0.0)
	])
	draw_colored_polygon(points, _tile_color(tile_id))
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, Color(palette.grid_color, 0.12), 1.0, true)

func _rebuild_chunks() -> void:
	_chunks.clear()
	if layout == null or chunk_size <= 0:
		return
	for y in range(0, layout.zone_size.y, chunk_size):
		for x in range(0, layout.zone_size.x, chunk_size):
			var size := Vector2i(
				mini(chunk_size, layout.zone_size.x - x),
				mini(chunk_size, layout.zone_size.y - y)
			)
			_chunks.append(Rect2i(Vector2i(x, y), size))

func _rebuild_tile_cache() -> void:
	_tile_id_cache.clear()
	_asset_path_cache.clear()
	_missing_asset_count = 0
	if layout == null or resolver == null:
		return
	var asset_path_by_tile_id: Dictionary = {}
	var asset_exists_by_tile_id: Dictionary = {}
	for y in range(layout.zone_size.y):
		for x in range(layout.zone_size.x):
			var cell := Vector2i(x, y)
			var tile_id := resolver.resolve_tile_id(layout, cell, biome_id, quality_preset)
			if not asset_path_by_tile_id.has(tile_id):
				var resolved_asset_path := String(resolver.resolve_tile_contract(tile_id).get("asset_path", ""))
				asset_path_by_tile_id[tile_id] = resolved_asset_path
				asset_exists_by_tile_id[tile_id] = _asset_path_exists(resolved_asset_path)
			var cached_asset_path := String(asset_path_by_tile_id[tile_id])
			var key := _cell_key(cell)
			_tile_id_cache[key] = tile_id
			_asset_path_cache[key] = cached_asset_path
			if not bool(asset_exists_by_tile_id[tile_id]):
				_missing_asset_count += 1

func _resolve_chunk_size(next_chunk_size: int, preset: StringName) -> int:
	if next_chunk_size > 0:
		return next_chunk_size
	match preset:
		&"performance":
			return PERFORMANCE_CHUNK_SIZE
		&"quality":
			return QUALITY_CHUNK_SIZE
		_:
			return DEFAULT_CHUNK_SIZE

func _cell_center_to_world(cell: Vector2i) -> Vector2:
	return (
		Vector2(
			float(cell.x) + 0.5 - float(layout.zone_size.x) * 0.5,
			float(cell.y) + 0.5 - float(layout.zone_size.y) * 0.5
		)
		* layout.logical_tile_scale
	)

func _tile_color(tile_id: StringName) -> Color:
	match tile_id:
		IsometricTileResolver.TILE_ROAD:
			return Color(palette.lane_color, maxf(palette.lane_color.a, 0.46))
		IsometricTileResolver.TILE_HAZARD_FLOOR:
			return Color(palette.hazard_color, 0.60)
		IsometricTileResolver.TILE_BORDER_FLOOR:
			return palette.floor_color.darkened(0.24)
		IsometricTileResolver.TILE_VOID_EDGE_NEAR:
			return palette.background_color.darkened(0.38)
		IsometricTileResolver.TILE_VOID_DEPTH:
			return palette.background_color.darkened(0.68)
		IsometricTileResolver.TILE_FLOOR_VARIANT_01:
			return palette.alternate_floor_color
		IsometricTileResolver.TILE_FLOOR_VARIANT_02:
			return palette.floor_color.lightened(0.035)
		IsometricTileResolver.TILE_FLOOR_VARIANT_03:
			return palette.alternate_floor_color.darkened(0.045)
		_:
			return palette.floor_color

func _cell_key(cell: Vector2i) -> int:
	if layout == null:
		return cell.y * 100000 + cell.x
	return cell.y * layout.zone_size.x + cell.x

func _asset_path_exists(asset_path: String) -> bool:
	if asset_path.is_empty():
		return false
	if ResourceLoader.exists(asset_path):
		return true
	return FileAccess.file_exists(asset_path)
