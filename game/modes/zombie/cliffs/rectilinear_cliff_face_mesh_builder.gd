extends RefCounted
class_name RectilinearCliffFaceMeshBuilder

## Builds continuous cliff faces aligned to rectangular fall-zone boundaries.
## This replaces per-cell transition faces for the forest renderer only.
## Internal pits use clipped orthogonal side strips so the top/bottom faces own
## the corners. Perimeter east/west strips still use an oblique drop because they
## do not meet an internal lower face.

const TEXTURE_REPEAT_WORLD_SIZE := 128.0
const PERIMETER_FACE_DEPTH_TILES := 1.15
const PERIMETER_MIN_FACE_DEPTH := 42.0
const INTERNAL_LATERAL_WALL_WIDTH_TILES := 0.65
# Horizontal lean of the lateral walls as a fraction of their drop depth. 0.0 is a
# flat vertical strip; ~0.5 ≈ 27° from vertical, matching TopDownCliffMeshBuilder.
const LATERAL_VOID_SLOPE := 0.5
const FALL_ZONE_BOUNDARY_RUNS = preload(
	"res://game/modes/zombie/cliffs/fall_zone_boundary_runs.gd"
)

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
	var zone_offset := Vector2(zone_size) * 0.5
	var boundary_runs: Array[Dictionary] = FALL_ZONE_BOUNDARY_RUNS.build(
		fall_zone_rects,
		fall_zone_sides,
		zone_size
	)
	for run in boundary_runs:
		_append_boundary_run(buffers, run, zone_offset, logical_scale)
	face_mesh = _build_mesh(buffers)

func _append_boundary_run(
	buffers: Dictionary,
	run: Dictionary,
	zone_offset: Vector2,
	logical_scale: float
) -> void:
	var orientation := StringName(run.get("orientation", &""))
	var perimeter_side := StringName(run.get("perimeter_side", &"internal"))
	var boundary := float(int(run.get("boundary", 0)))
	var start := float(int(run.get("start", 0)))
	var end := float(int(run.get("end", 0)))
	var depth_cells := float(int(run.get("depth_cells", 1)))
	if orientation == FALL_ZONE_BOUNDARY_RUNS.TOP or orientation == FALL_ZONE_BOUNDARY_RUNS.BOTTOM:
		var left := (start - zone_offset.x) * logical_scale
		var right := (end - zone_offset.x) * logical_scale
		var boundary_y := (boundary - zone_offset.y) * logical_scale
		var depth_rect := Rect2(
			Vector2(left, boundary_y),
			Vector2(right - left, depth_cells * logical_scale)
		)
		if orientation == FALL_ZONE_BOUNDARY_RUNS.TOP:
			_append_horizontal_face(
				buffers,
				left,
				right,
				boundary_y,
				_far_face_depth(depth_rect, perimeter_side, logical_scale),
				1.0
			)
		else:
			_append_horizontal_face(
				buffers,
				left,
				right,
				boundary_y,
				_near_face_depth(depth_rect, perimeter_side, logical_scale),
				-1.0
			)
		return
	var top := (start - zone_offset.y) * logical_scale
	var bottom := (end - zone_offset.y) * logical_scale
	var boundary_x := (boundary - zone_offset.x) * logical_scale
	var inward_width := depth_cells * logical_scale
	if _is_perimeter_side(perimeter_side):
		var depth_rect := Rect2(
			Vector2(boundary_x, top),
			Vector2(inward_width, bottom - top)
		)
		var drop_depth := _far_face_depth(depth_rect, perimeter_side, logical_scale)
		var slant := minf(
			drop_depth * LATERAL_VOID_SLOPE,
			inward_width * 0.42
		)
		_append_lateral_wall(
			buffers,
			top,
			bottom - minf(drop_depth, (bottom - top) * 0.5),
			boundary_x,
			drop_depth,
			-slant if orientation == FALL_ZONE_BOUNDARY_RUNS.RIGHT else slant
		)
		return
	var lateral_width := minf(
		maxf(logical_scale * INTERNAL_LATERAL_WALL_WIDTH_TILES, 8.0),
		inward_width * 0.18
	)
	_append_lateral_strip(
		buffers,
		top,
		bottom,
		boundary_x,
		lateral_width,
		1.0 if orientation == FALL_ZONE_BOUNDARY_RUNS.LEFT else -1.0
	)

func _append_faces(
	buffers: Dictionary,
	rect: Rect2,
	side: StringName,
	logical_scale: float
) -> void:
	var far_depth := _far_face_depth(rect, side, logical_scale)
	var near_depth := _near_face_depth(rect, side, logical_scale)
	# Perimeter side walls keep the old oblique drop. Internal pits use a clipped
	# orthogonal strip below, so the horizontal faces can own both corner bands.
	var lateral_drop := minf(far_depth, rect.size.y * 0.5)
	if _is_perimeter_side(side):
		lateral_drop = far_depth
	var lateral_slant := minf(lateral_drop * LATERAL_VOID_SLOPE, rect.size.x * 0.42)
	var lateral_width := minf(
		maxf(logical_scale * INTERNAL_LATERAL_WALL_WIDTH_TILES, 8.0),
		rect.size.x * 0.18
	)
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
			var side_top := rect.position.y + far_depth
			var side_bottom := rect.end.y - near_depth
			if side_bottom > side_top:
				_append_lateral_strip(
					buffers,
					side_top,
					side_bottom,
					rect.position.x,
					lateral_width,
					1.0
				)
				_append_lateral_strip(
					buffers,
					side_top,
					side_bottom,
					rect.end.x,
					lateral_width,
					-1.0
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

func _far_face_depth(rect: Rect2, side: StringName, logical_scale: float) -> float:
	if _is_perimeter_side(side):
		return maxf(logical_scale * PERIMETER_FACE_DEPTH_TILES, PERIMETER_MIN_FACE_DEPTH)
	return minf(
		maxf(logical_scale * 5.0, 24.0),
		rect.size.y * 0.55
	)

func _near_face_depth(rect: Rect2, side: StringName, logical_scale: float) -> float:
	if _is_perimeter_side(side):
		return maxf(logical_scale * PERIMETER_FACE_DEPTH_TILES, PERIMETER_MIN_FACE_DEPTH)
	return minf(
		maxf(logical_scale * 0.8, 5.0),
		rect.size.y * 0.20
	)

func _is_perimeter_side(side: StringName) -> bool:
	return side == &"north" or side == &"south" or side == &"east" or side == &"west"

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

func _append_lateral_strip(
	buffers: Dictionary,
	top: float,
	bottom: float,
	boundary_x: float,
	width: float,
	inward_sign: float
) -> void:
	if bottom <= top or width <= 0.0 or is_zero_approx(inward_sign):
		return
	var inner_x := boundary_x + inward_sign * width
	var outer_top := Vector2(boundary_x, top)
	var inner_top := Vector2(inner_x, top)
	var inner_bottom := Vector2(inner_x, bottom)
	var outer_bottom := Vector2(boundary_x, bottom)
	var along_top := top / TEXTURE_REPEAT_WORLD_SIZE
	var along_bottom := bottom / TEXTURE_REPEAT_WORLD_SIZE
	var boundary_color := _boundary_color()
	var inside_color := _inside_color()
	_append_quad(
		buffers,
		PackedVector2Array([outer_top, inner_top, inner_bottom, outer_bottom]),
		PackedVector2Array([
			Vector2(along_top, 0.0),
			Vector2(along_top, 1.0),
			Vector2(along_bottom, 1.0),
			Vector2(along_bottom, 0.0)
		]),
		PackedColorArray([boundary_color, inside_color, inside_color, boundary_color])
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
