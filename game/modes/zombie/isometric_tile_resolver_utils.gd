extends RefCounted
class_name IsometricTileResolverUtils

static func cell_inside_any_rect(cell: Vector2i, rects: Array[Rect2i]) -> bool:
	for rect in rects:
		if rect.has_point(cell):
			return true
	return false

static func stable_cell_hash(seed: int, biome_id: StringName, cell: Vector2i) -> int:
	var biome_hash := _stable_string_hash(String(biome_id))
	var value := seed * 1103515245
	value += cell.x * 73856093
	value += cell.y * 19349663
	value += biome_hash * 83492791
	return posmod(value, 2147483647)

static func asset_path_exists(asset_path: String) -> bool:
	if asset_path.is_empty():
		return false
	if ResourceLoader.exists(asset_path):
		return true
	return FileAccess.file_exists(asset_path)

static func _stable_string_hash(text: String) -> int:
	var value := 17
	for index in range(text.length()):
		value = posmod(value * 31 + text.unicode_at(index), 2147483647)
	return value
