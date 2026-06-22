extends RefCounted
class_name RectilinearCliffFaceMeshBuilder

## Builds continuous cliff faces aligned to rectangular fall-zone boundaries.
## This replaces the per-cell diamond faces for the forest renderer only.
## The far (north) wall descends straight; the lateral (east/west) walls are
## sheared so the side of the drop reads as an oblique ravine in fake
## perspective, the same trick the legacy diamond EDGE E/W faces used.

const TEXTURE_REPEAT_WORLD_SIZE := 128.0
# Horizontal lean of the lateral walls as a fraction of their drop depth. 0.0 is a
# flat vertical strip; ~0.5 ≈ 27° from vertical, matching IsometricCliffMeshBuilder.
const LATERAL_VOID_SLOPE := 0.5

var face_mesh: ArrayMesh
var face_count: int = 0

func reset() -> void:
	face_mesh = null
	face_count = 0

func build(
	fall_zone_rects: Array[Rect2i],
	fall_zone_sides: Array[StringName],
	zone_size: Vector2i,
	logical_scale: float
) -> void:
	reset()
	if fall_zone_rects.is_empty() or logical_scale <= 0.0:
		return
	var buffers := _mesh_buffers()
	var zone_bounds := Rect2i(Vector2i.ZERO, zone_size)
	var zone_offset := Vector2(zone_size) * 0.5
	for rect_index in range(fall_zone_rects.size()):
		var source_rect := fall_zone_rects[rect_index]
		var rect := source_rect.intersection(zone_bounds)
		if rect.size.x <= 0 or rect.size.y <= 0:
			continue
		var world_rect := Rect2(
			(Vector2(rect.position) - zone_offset) * logical_scale,
			Vector2(rect.size) * logical_scale
		)
		var side := (
			fall_zone_sides[rect_index]
			if rect_index < fall_zone_sides.size()
			else &"internal"
		)
		_append_faces(buffers, world_rect, side, logical_scale)
	face_mesh = _build_mesh(buffers)

func _append_faces(
	buffers: Dictionary,
	rect: Rect2,
	side: StringName,
	logical_scale: float
) -> void:
	var far_depth := minf(
		maxf(logical_scale * 5.0, 24.0),
		rect.size.y * 0.55
	)
	var near_depth := minf(
		maxf(logical_scale * 0.8, 5.0),
		rect.size.y * 0.20
	)
	# Lateral walls descend roughly as deep as the far wall so the ravine reads at the
	# same scale on every side; the lean is capped so a narrow pit cannot fold over.
	var lateral_drop := minf(far_depth, rect.size.y * 0.5)
	var lateral_slant := minf(lateral_drop * LATERAL_VOID_SLOPE, rect.size.x * 0.42)
	match side:
		&"north":
			_append_horizontal_face(
				buffers,
				rect.position.x,
				rect.end.x,
				rect.end.y,
				near_depth,
				-1.0
			)
		&"south":
			_append_horizontal_face(
				buffers,
				rect.position.x,
				rect.end.x,
				rect.position.y,
				far_depth,
				1.0
			)
		&"west":
			_append_lateral_wall(
				buffers,
				rect.position.y,
				rect.end.y - lateral_drop,
				rect.end.x,
				lateral_drop,
				-lateral_slant
			)
		&"east":
			_append_lateral_wall(
				buffers,
				rect.position.y,
				rect.end.y - lateral_drop,
				rect.position.x,
				lateral_drop,
				lateral_slant
			)
		_:
			var side_top := rect.position.y
			var side_bottom := rect.end.y - lateral_drop
			if side_bottom > side_top:
				_append_lateral_wall(
					buffers,
					side_top,
					side_bottom,
					rect.position.x,
					lateral_drop,
					lateral_slant
				)
				_append_lateral_wall(
					buffers,
					side_top,
					side_bottom,
					rect.end.x,
					lateral_drop,
					-lateral_slant
				)
			_append_horizontal_face(
				buffers,
				rect.position.x,
				rect.end.x,
				rect.position.y,
				far_depth,
				1.0
			)
			_append_horizontal_face(
				buffers,
				rect.position.x,
				rect.end.x,
				rect.end.y,
				near_depth,
				-1.0
			)

func _append_horizontal_face(
	buffers: Dictionary,
	left: float,
	right: float,
	boundary_y: float,
	depth: float,
	void_direction_y: float
) -> void:
	if right <= left or depth <= 0.0:
		return
	var inside_y := boundary_y + void_direction_y * depth
	var top := minf(boundary_y, inside_y)
	var bottom := maxf(boundary_y, inside_y)
	var boundary_v := 0.0
	var inside_v := 1.0
	var top_v := boundary_v if boundary_y <= inside_y else inside_v
	var bottom_v := inside_v if boundary_y <= inside_y else boundary_v
	var u_left := left / TEXTURE_REPEAT_WORLD_SIZE
	var u_right := right / TEXTURE_REPEAT_WORLD_SIZE
	var top_color := _boundary_color() if boundary_y <= inside_y else _inside_color()
	var bottom_color := _inside_color() if boundary_y <= inside_y else _boundary_color()
	_append_quad(
		buffers,
		PackedVector2Array([
			Vector2(left, top),
			Vector2(right, top),
			Vector2(right, bottom),
			Vector2(left, bottom)
		]),
		PackedVector2Array([
			Vector2(u_left, top_v),
			Vector2(u_right, top_v),
			Vector2(u_right, bottom_v),
			Vector2(u_left, bottom_v)
		]),
		PackedColorArray([top_color, top_color, bottom_color, bottom_color])
	)
	face_count += 1

func _append_lateral_wall(
	buffers: Dictionary,
	top: float,
	bottom: float,
	boundary_x: float,
	drop_depth: float,
	slant: float
) -> void:
	# The rim follows the pit's vertical edge; extruding it toward the interior
	# (slant) and downward (drop_depth) turns the side wall into an oblique ravine
	# face instead of a flat vertical strip. The rim keeps the crisp boundary colour
	# and the interior dissolves into the void, matching the far-wall gradient.
	if bottom <= top or drop_depth <= 0.0:
		return
	var rim_top := Vector2(boundary_x, top)
	var rim_bottom := Vector2(boundary_x, bottom)
	var far_top := Vector2(boundary_x + slant, top + drop_depth)
	var far_bottom := Vector2(boundary_x + slant, bottom + drop_depth)
	var along_top := top / TEXTURE_REPEAT_WORLD_SIZE
	var along_bottom := bottom / TEXTURE_REPEAT_WORLD_SIZE
	var boundary_color := _boundary_color()
	var inside_color := _inside_color()
	_append_quad(
		buffers,
		PackedVector2Array([rim_top, far_top, far_bottom, rim_bottom]),
		PackedVector2Array([
			Vector2(along_top, 0.0),
			Vector2(along_top, 1.0),
			Vector2(along_bottom, 1.0),
			Vector2(along_bottom, 0.0)
		]),
		PackedColorArray([boundary_color, inside_color, inside_color, boundary_color])
	)
	face_count += 1

func _boundary_color() -> Color:
	return Color(1.0, 1.0, 1.0, 0.96)

func _inside_color() -> Color:
	return Color(0.52, 0.52, 0.52, 0.16)

func _mesh_buffers() -> Dictionary:
	return {
		"vertices": PackedVector2Array(),
		"colors": PackedColorArray(),
		"uvs": PackedVector2Array(),
		"indices": PackedInt32Array()
	}

func _append_quad(
	buffers: Dictionary,
	quad_vertices: PackedVector2Array,
	quad_uvs: PackedVector2Array,
	quad_colors: PackedColorArray
) -> void:
	var vertices := buffers["vertices"] as PackedVector2Array
	var colors := buffers["colors"] as PackedColorArray
	var uvs := buffers["uvs"] as PackedVector2Array
	var indices := buffers["indices"] as PackedInt32Array
	var base := vertices.size()
	for index in range(4):
		vertices.append(quad_vertices[index])
		colors.append(quad_colors[index])
		uvs.append(quad_uvs[index])
	indices.append(base)
	indices.append(base + 1)
	indices.append(base + 2)
	indices.append(base)
	indices.append(base + 2)
	indices.append(base + 3)
	buffers["vertices"] = vertices
	buffers["colors"] = colors
	buffers["uvs"] = uvs
	buffers["indices"] = indices

func _build_mesh(buffers: Dictionary) -> ArrayMesh:
	var vertices := buffers["vertices"] as PackedVector2Array
	var indices := buffers["indices"] as PackedInt32Array
	if vertices.is_empty() or indices.is_empty():
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = buffers["colors"]
	arrays[Mesh.ARRAY_TEX_UV] = buffers["uvs"]
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
