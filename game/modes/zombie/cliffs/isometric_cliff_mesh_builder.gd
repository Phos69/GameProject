extends RefCounted
class_name IsometricCliffMeshBuilder

# Horizontal lean of the east/west walls as a fraction of the drop DEPTH, so the
# side of the cliff is clearly oblique (the wall and its fall stripes slant toward
# the void interior). 0.0 = pure-vertical, ~0.5 ≈ 27° from vertical. Tune to taste.
const LATERAL_VOID_SLOPE := 0.5
# Number of oblique "fall" stripes drawn per path segment on the lateral (east/west)
# walls, so the side of the drop reads as a slanted cliff instead of a flat panel.
const LATERAL_FALL_STRIPES := 3
# The south wall faces the camera's near side. Gameplay fall remains immediate,
# but textured art needs a minimum visible face instead of collapsing to a line.
const SOUTH_INSTANT_DEPTH := 5.0
const SOUTH_TEXTURED_DEPTH := 14.0

var palette: BiomePalette
var generation_seed: int = 0
var textured_art_enabled: bool = false

var face_mesh: ArrayMesh
var lip_mesh: ArrayMesh
var lip_lines: PackedVector2Array = PackedVector2Array()
var fissure_lines: PackedVector2Array = PackedVector2Array()
var transition_count: int = 0

var _face_vertices: PackedVector2Array = PackedVector2Array()
var _face_colors: PackedColorArray = PackedColorArray()
var _face_uvs: PackedVector2Array = PackedVector2Array()
var _face_indices: PackedInt32Array = PackedInt32Array()
var _lip_vertices: PackedVector2Array = PackedVector2Array()
var _lip_colors: PackedColorArray = PackedColorArray()
var _lip_uvs: PackedVector2Array = PackedVector2Array()
var _lip_indices: PackedInt32Array = PackedInt32Array()

func configure(
	next_palette: BiomePalette,
	next_generation_seed: int,
	enable_textured_art: bool = false
) -> void:
	palette = next_palette
	generation_seed = next_generation_seed
	textured_art_enabled = enable_textured_art
	reset()

func reset() -> void:
	face_mesh = null
	lip_mesh = null
	lip_lines = PackedVector2Array()
	fissure_lines = PackedVector2Array()
	transition_count = 0
	_face_vertices = PackedVector2Array()
	_face_colors = PackedColorArray()
	_face_uvs = PackedVector2Array()
	_face_indices = PackedInt32Array()
	_lip_vertices = PackedVector2Array()
	_lip_colors = PackedColorArray()
	_lip_uvs = PackedVector2Array()
	_lip_indices = PackedInt32Array()

func append_transition(
	tile_id: StringName,
	center: Vector2,
	half_w: float,
	half_h: float,
	southern_tile_ids: Array[StringName] = [],
	tile_step_y: float = 0.0
) -> void:
	if palette == null:
		return
	var depth := maxf(half_h * 8.0, 28.0)
	var south_join_y := _find_south_join_y(
		tile_id,
		center.y,
		southern_tile_ids,
		tile_step_y
	)
	var faces := _cliff_faces(
		tile_id,
		center,
		half_w,
		half_h,
		depth,
		south_join_y
	)
	if faces.is_empty():
		return
	transition_count += 1
	var base_top := palette.prop_color.lightened(0.12)
	var void_color := palette.background_color.darkened(0.68)
	for face in faces:
		var path: PackedVector2Array = face.path
		var drop: Vector2 = face.drop
		var drops: PackedVector2Array = face.get("drops", PackedVector2Array())
		var brightness: float = face.brightness
		var face_top := Color(
			base_top.r * brightness, base_top.g * brightness, base_top.b * brightness, 1.0
		)
		# The face itself reaches the exact void colour. A separate shadow pass
		# produced overlapping per-tile bands that looked like a reflection below
		# the real cliff ending.
		var face_bottom := Color(void_color, 1.0)
		if textured_art_enabled:
			var texture_brightness := clampf(brightness * 1.55, 0.90, 1.35)
			face_top = Color(
				texture_brightness,
				texture_brightness,
				texture_brightness,
				1.0
			)
			# Reveal the painted rock near the ledge, then dissolve it into the
			# uniform void instead of ending on an opaque rectangular band.
			face_bottom = Color(0.45, 0.45, 0.45, 0.12)
		for point_index in range(path.size() - 1):
			var start := path[point_index]
			var end := path[point_index + 1]
			var start_drop := drops[point_index] if drops.size() == path.size() else drop
			var end_drop := drops[point_index + 1] if drops.size() == path.size() else drop
			_append_gradient_quad(
				_face_vertices, _face_colors, _face_uvs, _face_indices,
				start, end, start_drop, end_drop, face_top, face_bottom
			)
			_append_lip_quad(start, end, brightness)
			_append_line(lip_lines, start, end)
			var stripes := int(face.get("fall_stripes", 0))
			if stripes > 0:
				# Evenly spaced lines parallel to the (slanted) drop: the oblique
				# hatching that marks the lateral side of the cliff as a fall.
				for stripe_index in range(1, stripes + 1):
					var stripe_weight := float(stripe_index) / float(stripes + 1)
					var anchor := start.lerp(end, stripe_weight)
					var stripe_drop := start_drop.lerp(end_drop, stripe_weight)
					_append_line(
						fissure_lines,
						anchor + stripe_drop * 0.08,
						anchor + stripe_drop * 0.9
					)
			else:
				var midpoint := (start + end) * 0.5
				var midpoint_drop := start_drop.lerp(end_drop, 0.5)
				var fissure_jitter := float((_detail_hash(Vector2i(midpoint)) % 5) - 2)
				_append_line(
					fissure_lines,
					midpoint + Vector2(
						midpoint_drop.x * 0.16 + fissure_jitter,
						midpoint_drop.y * 0.16
					),
					midpoint + Vector2(
						midpoint_drop.x * 0.78 - fissure_jitter * 0.5,
						midpoint_drop.y * 0.78
					)
				)
func build_meshes() -> void:
	face_mesh = _build_textured_mesh(
		_face_vertices,
		_face_colors,
		_face_uvs,
		_face_indices
	)
	lip_mesh = _build_textured_mesh(
		_lip_vertices,
		_lip_colors,
		_lip_uvs,
		_lip_indices
	)

func _build_textured_mesh(
	vertices: PackedVector2Array,
	colors: PackedColorArray,
	uvs: PackedVector2Array,
	indices: PackedInt32Array
) -> ArrayMesh:
	if vertices.is_empty() or indices.is_empty():
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _append_gradient_quad(
	vertices: PackedVector2Array,
	colors: PackedColorArray,
	uvs: PackedVector2Array,
	indices: PackedInt32Array,
	start: Vector2,
	end: Vector2,
	start_drop: Vector2,
	end_drop: Vector2,
	top_color: Color,
	bottom_color: Color
) -> void:
	var base := vertices.size()
	vertices.append(start)
	vertices.append(end)
	vertices.append(end + end_drop)
	vertices.append(start + start_drop)
	colors.append(top_color)
	colors.append(top_color)
	colors.append(bottom_color)
	colors.append(bottom_color)
	var start_u := _world_texture_u(start)
	var end_u := _world_texture_u(end)
	uvs.append(Vector2(start_u, 0.0))
	uvs.append(Vector2(end_u, 0.0))
	uvs.append(Vector2(end_u, 1.0))
	uvs.append(Vector2(start_u, 1.0))
	indices.append(base)
	indices.append(base + 1)
	indices.append(base + 2)
	indices.append(base)
	indices.append(base + 2)
	indices.append(base + 3)

func _append_lip_quad(start: Vector2, end: Vector2, brightness: float) -> void:
	var segment := end - start
	if segment.length_squared() <= 0.001:
		return
	var normal := Vector2(-segment.y, segment.x).normalized() * 4.8
	var base := _lip_vertices.size()
	_lip_vertices.append(start - normal)
	_lip_vertices.append(end - normal)
	_lip_vertices.append(end + normal)
	_lip_vertices.append(start + normal)
	var tint := Color(brightness, brightness, brightness, 1.0)
	for _index in range(4):
		_lip_colors.append(tint)
	var start_u := _world_texture_u(start)
	var end_u := _world_texture_u(end)
	_lip_uvs.append(Vector2(start_u, 0.0))
	_lip_uvs.append(Vector2(end_u, 0.0))
	_lip_uvs.append(Vector2(end_u, 1.0))
	_lip_uvs.append(Vector2(start_u, 1.0))
	_lip_indices.append(base)
	_lip_indices.append(base + 1)
	_lip_indices.append(base + 2)
	_lip_indices.append(base)
	_lip_indices.append(base + 2)
	_lip_indices.append(base + 3)

func _world_texture_u(point: Vector2) -> float:
	# World-space UVs keep adjacent cliff cells on the same seamless material
	# instead of squeezing the complete source image into every five-pixel face.
	return (point.x * 0.72 + point.y * 0.28) / 64.0

# Returns Array of {path, drop, brightness, fall_stripes?}. Each void boundary
# reads differently depending on where it sits relative to the camera:
#   north — far interior wall: a tall wall descending straight into the void.
#   east/west — lateral sides: walls that slope toward the void interior and carry
#               oblique "fall" stripes (fall_stripes) down their slanted face.
#   south — camera-facing near edge: immediate gameplay drop, with a minimum
#           visible textured face when raster art is active.
# Brightness differentiates the faces by light: south brightest, then east, north,
# west (shadow side, darkest).
func _cliff_faces(
	tile_id: StringName,
	center: Vector2,
	half_w: float,
	half_h: float,
	depth: float,
	lateral_max_y: float = INF
) -> Array:
	var top := center + Vector2(0.0, -half_h)
	var right := center + Vector2(half_w, 0.0)
	var bottom := center + Vector2(0.0, half_h)
	var left := center + Vector2(-half_w, 0.0)
	var result: Array = []
	var sides := _cliff_sides_for_tile_id(tile_id)
	var north_drop := Vector2(0.0, depth)
	var south_drop := Vector2(
		0.0,
		SOUTH_TEXTURED_DEPTH if textured_art_enabled else SOUTH_INSTANT_DEPTH
	)
	for side in sides:
		match side:
			&"north":
				# Ground is to the north, so the void drops away to the south (down on
				# screen). This is the far interior wall of the drop and is very much
				# visible — it descends straight into the void below the lip.
				result.append({
					"path": PackedVector2Array([left, top, right]),
					"drop": north_drop,
					"brightness": 0.62
				})
			&"east":
				# Right diamond edge: top→right→bottom. Ground is to the east, so the
				# wall slopes west (toward the void interior) and shows oblique fall
				# stripes down its slanted side.
				var east_drop := Vector2(-depth * LATERAL_VOID_SLOPE, depth)
				var east_path := PackedVector2Array([top, right, bottom])
				var east_drops := PackedVector2Array()
				if sides.has(&"south"):
					# The south face owns right->bottom. End the lateral face at the
					# shared right vertex and taper it to the shallow near-side drop.
					east_path = PackedVector2Array([top, right])
					east_drops = PackedVector2Array([east_drop, south_drop])
				elif sides.has(&"north"):
					# The north face owns top->right. Start the remaining lateral
					# segment at the north depth so the two faces meet without overlap.
					east_path = PackedVector2Array([right, bottom])
					east_drops = PackedVector2Array([north_drop, east_drop])
				if east_drops.is_empty():
					east_drops = _uniform_drops(east_path, east_drop)
				east_drops = _clip_drops_to_max_y(
					east_path,
					east_drops,
					lateral_max_y
				)
				result.append({
					"path": east_path,
					"drop": east_drop,
					"drops": east_drops,
					"brightness": 0.72,
					"fall_stripes": LATERAL_FALL_STRIPES
				})
			&"south":
				# Camera-facing near edge: an instant drop, not a tall wall. Razor-thin
				# depth leaves just the bright lip and a sliver of shadow.
				result.append({
					"path": PackedVector2Array([left, bottom, right]),
					"drop": south_drop,
					"brightness": 1.0
				})
			&"west":
				# Left diamond edge: shadow side, noticeably darker than east. Ground
				# is to the west, so the wall slopes east (toward the void interior) and
				# shows the same oblique fall stripes as the east wall.
				var west_drop := Vector2(depth * LATERAL_VOID_SLOPE, depth)
				var west_path := PackedVector2Array([top, left, bottom])
				var west_drops := PackedVector2Array()
				if sides.has(&"south"):
					west_path = PackedVector2Array([top, left])
					west_drops = PackedVector2Array([west_drop, south_drop])
				elif sides.has(&"north"):
					west_path = PackedVector2Array([left, bottom])
					west_drops = PackedVector2Array([north_drop, west_drop])
				if west_drops.is_empty():
					west_drops = _uniform_drops(west_path, west_drop)
				west_drops = _clip_drops_to_max_y(
					west_path,
					west_drops,
					lateral_max_y
				)
				result.append({
					"path": west_path,
					"drop": west_drop,
					"drops": west_drops,
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

func _find_south_join_y(
	tile_id: StringName,
	center_y: float,
	southern_tile_ids: Array[StringName],
	tile_step_y: float
) -> float:
	var sides := _cliff_sides_for_tile_id(tile_id)
	var lateral_side := &""
	if sides.has(&"east"):
		lateral_side = &"east"
	elif sides.has(&"west"):
		lateral_side = &"west"
	if lateral_side.is_empty():
		return INF
	if sides.has(&"south"):
		return center_y + (
			SOUTH_TEXTURED_DEPTH
			if textured_art_enabled
			else SOUTH_INSTANT_DEPTH
		)
	if tile_step_y <= 0.0:
		return INF
	for index in range(southern_tile_ids.size()):
		var neighbor_sides := _cliff_sides_for_tile_id(southern_tile_ids[index])
		if neighbor_sides.has(lateral_side) and neighbor_sides.has(&"south"):
			return (
				center_y
				+ float(index + 1) * tile_step_y
				+ (
					SOUTH_TEXTURED_DEPTH
					if textured_art_enabled
					else SOUTH_INSTANT_DEPTH
				)
			)
		if not neighbor_sides.has(lateral_side):
			break
	return INF

func _uniform_drops(path: PackedVector2Array, drop: Vector2) -> PackedVector2Array:
	var drops := PackedVector2Array()
	for _point in path:
		drops.append(drop)
	return drops

func _clip_drops_to_max_y(
	path: PackedVector2Array,
	drops: PackedVector2Array,
	max_y: float
) -> PackedVector2Array:
	if is_inf(max_y) or path.size() != drops.size():
		return drops
	var clipped := PackedVector2Array()
	for index in range(path.size()):
		var drop := drops[index]
		if drop.y <= 0.0:
			clipped.append(drop)
			continue
		var allowed_depth := maxf(max_y - path[index].y, 0.0)
		if allowed_depth >= drop.y:
			clipped.append(drop)
			continue
		clipped.append(drop * (allowed_depth / drop.y))
	return clipped

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
