extends RefCounted
class_name IsometricCliffMeshBuilder

# Horizontal lean of the east/west walls as a fraction of the drop DEPTH, so the
# side of the cliff is clearly oblique (the wall and its fall stripes slant toward
# the void interior). 0.0 = pure-vertical, ~0.5 ≈ 27° from vertical. Tune to taste.
const LATERAL_VOID_SLOPE := 0.5
# Number of oblique "fall" stripes drawn per path segment on the lateral (east/west)
# walls, so the side of the drop reads as a slanted cliff instead of a flat panel.
const LATERAL_FALL_STRIPES := 3
# The south wall faces the camera's near side: the player should fall the instant
# they step off, so it gets a razor-thin drop (just a lip + shadow, no tall wall).
const SOUTH_INSTANT_DEPTH := 5.0

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
	var depth := maxf(half_h * 8.0, 28.0)
	var faces := _cliff_faces(tile_id, center, half_w, half_h, depth)
	if faces.is_empty():
		return
	transition_count += 1
	var base_top := palette.prop_color.lightened(0.12)
	var base_bottom := palette.prop_color.darkened(0.68)
	for face in faces:
		var path: PackedVector2Array = face.path
		var drop: Vector2 = face.drop
		var brightness: float = face.brightness
		var face_top := Color(
			base_top.r * brightness, base_top.g * brightness, base_top.b * brightness, 1.0
		)
		var face_bottom := Color(
			base_bottom.r * brightness, base_bottom.g * brightness, base_bottom.b * brightness, 1.0
		)
		var shadow_top := Color(palette.background_color.darkened(0.62), 0.84 * brightness)
		var shadow_bottom := Color(palette.background_color.darkened(0.78), 0.16 * brightness)
		for point_index in range(path.size() - 1):
			var start := path[point_index]
			var end := path[point_index + 1]
			_append_gradient_quad(
				_face_vertices, _face_colors, _face_indices,
				start, end, drop, face_top, face_bottom
			)
			_append_gradient_quad(
				_shadow_vertices, _shadow_colors, _shadow_indices,
				start + drop * 0.72, end + drop * 0.72, drop * 0.72,
				shadow_top, shadow_bottom
			)
			_append_line(lip_lines, start, end)
			var stripes := int(face.get("fall_stripes", 0))
			if stripes > 0:
				# Evenly spaced lines parallel to the (slanted) drop: the oblique
				# hatching that marks the lateral side of the cliff as a fall.
				for stripe_index in range(1, stripes + 1):
					var anchor := start.lerp(end, float(stripe_index) / float(stripes + 1))
					_append_line(fissure_lines, anchor + drop * 0.08, anchor + drop * 0.9)
			else:
				var midpoint := (start + end) * 0.5
				var fissure_jitter := float((_detail_hash(Vector2i(midpoint)) % 5) - 2)
				_append_line(
					fissure_lines,
					midpoint + Vector2(drop.x * 0.16 + fissure_jitter, drop.y * 0.16),
					midpoint + Vector2(drop.x * 0.78 - fissure_jitter * 0.5, drop.y * 0.78)
				)
			_append_line(
				mist_lines,
				start + drop * 1.18,
				end + drop * 1.18
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

# Returns Array of {path, drop, brightness, fall_stripes?}. Each void boundary
# reads differently depending on where it sits relative to the camera:
#   north — far interior wall: a tall wall descending straight into the void.
#   east/west — lateral sides: walls that slope toward the void interior and carry
#               oblique "fall" stripes (fall_stripes) down their slanted face.
#   south — camera-facing near edge: an INSTANT drop (SOUTH_INSTANT_DEPTH), just a
#           lip and a sliver of shadow, since the player falls the moment they step off.
# Brightness differentiates the faces by light: south brightest, then east, north,
# west (shadow side, darkest).
func _cliff_faces(
	tile_id: StringName,
	center: Vector2,
	half_w: float,
	half_h: float,
	depth: float
) -> Array:
	var top := center + Vector2(0.0, -half_h)
	var right := center + Vector2(half_w, 0.0)
	var bottom := center + Vector2(0.0, half_h)
	var left := center + Vector2(-half_w, 0.0)
	var result: Array = []
	for side in _cliff_sides_for_tile_id(tile_id):
		match side:
			&"north":
				# Ground is to the north, so the void drops away to the south (down on
				# screen). This is the far interior wall of the drop and is very much
				# visible — it descends straight into the void below the lip.
				result.append({
					"path": PackedVector2Array([left, top, right]),
					"drop": Vector2(0.0, depth),
					"brightness": 0.62
				})
			&"east":
				# Right diamond edge: top→right→bottom. Ground is to the east, so the
				# wall slopes west (toward the void interior) and shows oblique fall
				# stripes down its slanted side.
				result.append({
					"path": PackedVector2Array([top, right, bottom]),
					"drop": Vector2(-depth * LATERAL_VOID_SLOPE, depth),
					"brightness": 0.72,
					"fall_stripes": LATERAL_FALL_STRIPES
				})
			&"south":
				# Camera-facing near edge: an instant drop, not a tall wall. Razor-thin
				# depth leaves just the bright lip and a sliver of shadow.
				result.append({
					"path": PackedVector2Array([left, bottom, right]),
					"drop": Vector2(0.0, SOUTH_INSTANT_DEPTH),
					"brightness": 1.0
				})
			&"west":
				# Left diamond edge: shadow side, noticeably darker than east. Ground
				# is to the west, so the wall slopes east (toward the void interior) and
				# shows the same oblique fall stripes as the east wall.
				result.append({
					"path": PackedVector2Array([top, left, bottom]),
					"drop": Vector2(depth * LATERAL_VOID_SLOPE, depth),
					"brightness": 0.52,
					"fall_stripes": LATERAL_FALL_STRIPES
				})
			&"diagonal_ne_sw":
				result.append({
					"path": PackedVector2Array([left, right]),
					"drop": Vector2(0.0, depth * 0.55),
					"brightness": 0.88
				})
			&"diagonal_nw_se":
				result.append({
					"path": PackedVector2Array([top, bottom]),
					"drop": Vector2(0.0, depth * 0.55),
					"brightness": 0.88
				})
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
