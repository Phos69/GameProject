extends RefCounted
class_name IsometricCliffMeshBuilder

var palette: BiomePalette
var generation_seed: int = 0

var shadow_mesh: ArrayMesh
var face_mesh: ArrayMesh
var lip_lines: PackedVector2Array = PackedVector2Array()
var fissure_lines: PackedVector2Array = PackedVector2Array()
var mist_lines: PackedVector2Array = PackedVector2Array()
var transition_count: int = 0

var _face_vertices: PackedVector2Array = PackedVector2Array()
var _face_colors: PackedColorArray = PackedColorArray()
var _face_indices: PackedInt32Array = PackedInt32Array()
var _shadow_vertices: PackedVector2Array = PackedVector2Array()
var _shadow_colors: PackedColorArray = PackedColorArray()
var _shadow_indices: PackedInt32Array = PackedInt32Array()

func configure(next_palette: BiomePalette, next_generation_seed: int) -> void:
	palette = next_palette
	generation_seed = next_generation_seed
	reset()

func reset() -> void:
	shadow_mesh = null
	face_mesh = null
	lip_lines = PackedVector2Array()
	fissure_lines = PackedVector2Array()
	mist_lines = PackedVector2Array()
	transition_count = 0
	_face_vertices = PackedVector2Array()
	_face_colors = PackedColorArray()
	_face_indices = PackedInt32Array()
	_shadow_vertices = PackedVector2Array()
	_shadow_colors = PackedColorArray()
	_shadow_indices = PackedInt32Array()

func append_transition(
	tile_id: StringName,
	center: Vector2,
	half_w: float,
	half_h: float
) -> void:
	if palette == null:
		return
	var paths := _cliff_lip_paths(tile_id, center, half_w, half_h)
	if paths.is_empty():
		return
	transition_count += 1
	var depth := maxf(half_h * 6.2, 18.0)
	var face_top := palette.prop_color.lightened(0.12)
	var face_bottom := palette.prop_color.darkened(0.68)
	var shadow_top := Color(palette.background_color.darkened(0.62), 0.84)
	var shadow_bottom := Color(palette.background_color.darkened(0.78), 0.16)
	for raw_path in paths:
		var path := raw_path as PackedVector2Array
		for point_index in range(path.size() - 1):
			var start := path[point_index]
			var end := path[point_index + 1]
			_append_gradient_quad(
				_face_vertices,
				_face_colors,
				_face_indices,
				start,
				end,
				Vector2(0.0, depth),
				face_top,
				face_bottom
			)
			_append_gradient_quad(
				_shadow_vertices,
				_shadow_colors,
				_shadow_indices,
				start + Vector2(0.0, depth * 0.72),
				end + Vector2(0.0, depth * 0.72),
				Vector2(0.0, depth * 0.72),
				shadow_top,
				shadow_bottom
			)
			_append_line(lip_lines, start, end)
			var midpoint := (start + end) * 0.5
			var fissure_jitter := float((_detail_hash(Vector2i(midpoint)) % 5) - 2)
			_append_line(
				fissure_lines,
				midpoint + Vector2(fissure_jitter, depth * 0.16),
				midpoint + Vector2(-fissure_jitter * 0.5, depth * 0.78)
			)
			_append_line(
				mist_lines,
				start + Vector2(0.0, depth * 1.18),
				end + Vector2(0.0, depth * 1.18)
			)

func build_meshes() -> void:
	face_mesh = _build_colored_mesh(_face_vertices, _face_colors, _face_indices)
	shadow_mesh = _build_colored_mesh(
		_shadow_vertices,
		_shadow_colors,
		_shadow_indices
	)

func _build_colored_mesh(
	vertices: PackedVector2Array,
	colors: PackedColorArray,
	indices: PackedInt32Array
) -> ArrayMesh:
	if vertices.is_empty() or indices.is_empty():
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _append_gradient_quad(
	vertices: PackedVector2Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	start: Vector2,
	end: Vector2,
	drop: Vector2,
	top_color: Color,
	bottom_color: Color
) -> void:
	var base := vertices.size()
	vertices.append(start)
	vertices.append(end)
	vertices.append(end + drop)
	vertices.append(start + drop)
	colors.append(top_color)
	colors.append(top_color)
	colors.append(bottom_color)
	colors.append(bottom_color)
	indices.append(base)
	indices.append(base + 1)
	indices.append(base + 2)
	indices.append(base)
	indices.append(base + 2)
	indices.append(base + 3)

func _cliff_lip_paths(
	tile_id: StringName,
	center: Vector2,
	half_w: float,
	half_h: float
) -> Array[PackedVector2Array]:
	var top := center + Vector2(0.0, -half_h)
	var right := center + Vector2(half_w, 0.0)
	var bottom := center + Vector2(0.0, half_h)
	var left := center + Vector2(-half_w, 0.0)
	var result: Array[PackedVector2Array] = []
	for side in _cliff_sides_for_tile_id(tile_id):
		match side:
			&"north":
				result.append(PackedVector2Array([left, top, right]))
			&"east":
				result.append(PackedVector2Array([top, right, bottom]))
			&"south":
				result.append(PackedVector2Array([left, bottom, right]))
			&"west":
				result.append(PackedVector2Array([top, left, bottom]))
			&"diagonal_ne_sw":
				result.append(PackedVector2Array([left, right]))
			&"diagonal_nw_se":
				result.append(PackedVector2Array([top, bottom]))
	return result

func _cliff_sides_for_tile_id(tile_id: StringName) -> Array[StringName]:
	match tile_id:
		IsometricTileResolver.TILE_VOID_EDGE_NORTH:
			return [&"north"]
		IsometricTileResolver.TILE_VOID_EDGE_EAST:
			return [&"east"]
		IsometricTileResolver.TILE_VOID_EDGE_SOUTH:
			return [&"south"]
		IsometricTileResolver.TILE_VOID_EDGE_WEST:
			return [&"west"]
		IsometricTileResolver.TILE_VOID_CORNER_INNER_NORTH_EAST, IsometricTileResolver.TILE_VOID_CORNER_OUTER_NORTH_EAST:
			return [&"north", &"east"]
		IsometricTileResolver.TILE_VOID_CORNER_INNER_SOUTH_EAST, IsometricTileResolver.TILE_VOID_CORNER_OUTER_SOUTH_EAST:
			return [&"south", &"east"]
		IsometricTileResolver.TILE_VOID_CORNER_INNER_SOUTH_WEST, IsometricTileResolver.TILE_VOID_CORNER_OUTER_SOUTH_WEST:
			return [&"south", &"west"]
		IsometricTileResolver.TILE_VOID_CORNER_INNER_NORTH_WEST, IsometricTileResolver.TILE_VOID_CORNER_OUTER_NORTH_WEST:
			return [&"north", &"west"]
		IsometricTileResolver.TILE_VOID_DIAGONAL_NORTH_EAST_SOUTH_WEST:
			return [&"diagonal_ne_sw"]
		IsometricTileResolver.TILE_VOID_DIAGONAL_NORTH_WEST_SOUTH_EAST:
			return [&"diagonal_nw_se"]
	return []

func _append_line(
	target: PackedVector2Array,
	start: Vector2,
	end: Vector2
) -> void:
	target.append(start)
	target.append(end)

func _detail_hash(cell: Vector2i) -> int:
	var value := generation_seed * 1664525
	value += cell.x * 73856093
	value += cell.y * 19349663
	return posmod(value, 2147483647)
