extends RefCounted
class_name IsometricCliffBorderMeshBuilder

## Builds a continuous orthogonal rim around rectangular fall zones. The
## rectilinear face builder owns the descending rock faces; this builder
## owns the clearly readable grass-to-rock crest and its geometric joins.

const HORIZONTAL_GRASS_RATIO := 0.65
const VERTICAL_GRASS_RATIO := 0.56
const RIM_WIDTH_TILES := 0.75
# The rock strip geometry is anchored by the *_GRASS_RATIO constants above, but the
# UV sampling starts deeper into the texture: the grass->rock transition of both
# source materials keeps green moss right around the geometric ratio, which read as
# a green seam tracing every cliff. Sampling from the pure-rock band removes it.
# Measured green-dominance vanishes past v=0.72 (horizontal v2) and u=0.60 (vertical).
const HORIZONTAL_ROCK_UV_START := 0.76
const VERTICAL_ROCK_UV_START := 0.64
const TEXTURE_REPEAT_WORLD_SIZE := 128.0
const FALL_ZONE_BOUNDARY_RUNS = preload(
	"res://game/modes/zombie/cliffs/fall_zone_boundary_runs.gd"
)

var horizontal_mesh: ArrayMesh
var vertical_mesh: ArrayMesh
var horizontal_segment_count: int = 0
var vertical_segment_count: int = 0
var corner_count: int = 0
var sample_full_texture: bool = false

func reset() -> void:
	horizontal_mesh = null
	vertical_mesh = null
	horizontal_segment_count = 0
	vertical_segment_count = 0
	corner_count = 0

func build(
	fall_zone_rects: Array[Rect2i],
	fall_zone_sides: Array[StringName],
	zone_size: Vector2i,
	logical_scale: float,
	next_sample_full_texture: bool = false
) -> void:
	reset()
	sample_full_texture = next_sample_full_texture
	if fall_zone_rects.is_empty() or logical_scale <= 0.0:
		return
	var horizontal := _mesh_buffers()
	var vertical := _mesh_buffers()
	var zone_offset := Vector2(zone_size) * 0.5
	var border_width := maxf(logical_scale * RIM_WIDTH_TILES, 12.0)
	var boundary_runs: Array[Dictionary] = FALL_ZONE_BOUNDARY_RUNS.build(
		fall_zone_rects,
		fall_zone_sides,
		zone_size
	)
	for run in boundary_runs:
		_append_boundary_run(
			horizontal,
			vertical,
			run,
			zone_offset,
			zone_size,
			logical_scale,
			border_width
		)
	horizontal_mesh = _build_mesh(horizontal)
	vertical_mesh = _build_mesh(vertical)

func get_total_segment_count() -> int:
	return horizontal_segment_count + vertical_segment_count + corner_count

func _append_boundary_run(
	horizontal: Dictionary,
	vertical: Dictionary,
	run: Dictionary,
	zone_offset: Vector2,
	zone_size: Vector2i,
	logical_scale: float,
	border_width: float
) -> void:
	var orientation := StringName(run.get("orientation", &""))
	var boundary := float(int(run.get("boundary", 0)))
	var start := float(int(run.get("start", 0)))
	var end := float(int(run.get("end", 0)))
	var joint_depth := border_width * (1.0 - HORIZONTAL_GRASS_RATIO)
	match orientation:
		FALL_ZONE_BOUNDARY_RUNS.TOP:
			_append_horizontal(
				horizontal,
				(start - zone_offset.x) * logical_scale,
				(end - zone_offset.x) * logical_scale,
				(boundary - zone_offset.y) * logical_scale,
				border_width,
				false
			)
			horizontal_segment_count += 1
			corner_count += 2
		FALL_ZONE_BOUNDARY_RUNS.BOTTOM:
			_append_horizontal(
				horizontal,
				(start - zone_offset.x) * logical_scale,
				(end - zone_offset.x) * logical_scale,
				(boundary - zone_offset.y) * logical_scale,
				border_width,
				true
			)
			horizontal_segment_count += 1
			corner_count += 2
		FALL_ZONE_BOUNDARY_RUNS.LEFT, FALL_ZONE_BOUNDARY_RUNS.RIGHT:
			var top := (start - zone_offset.y) * logical_scale
			var bottom := (end - zone_offset.y) * logical_scale
			# Horizontal strips own geometric joins. Do not trim an endpoint that
			# reaches the map boundary, because there is no rendered outer rim there.
			if int(start) > 0:
				top += joint_depth
			if int(end) < zone_size.y:
				bottom -= joint_depth
			_append_vertical(
				vertical,
				top,
				bottom,
				(boundary - zone_offset.x) * logical_scale,
				border_width,
				orientation == FALL_ZONE_BOUNDARY_RUNS.RIGHT
			)
			vertical_segment_count += 1
			if StringName(run.get("perimeter_side", &"internal")) != &"internal":
				corner_count += 2

func _append_horizontal(
	buffers: Dictionary,
	left: float,
	right: float,
	boundary_y: float,
	width: float,
	flip_vertical: bool
) -> void:
	# As with vertical edges, grass is already rendered by the base ground. Map
	# only the rock interval inside the fall rectangle so the strip cannot leave
	# a rectangular grass cap at either endpoint.
	var rock_depth := width * (1.0 - HORIZONTAL_GRASS_RATIO)
	var top: float
	var bottom: float
	var top_v: float
	var bottom_v: float
	if flip_vertical:
		top = boundary_y - rock_depth
		bottom = boundary_y
		top_v = 1.0
		bottom_v = 0.0 if sample_full_texture else HORIZONTAL_ROCK_UV_START
	else:
		top = boundary_y
		bottom = boundary_y + rock_depth
		top_v = 0.0 if sample_full_texture else HORIZONTAL_ROCK_UV_START
		bottom_v = 1.0
	var u_left := left / TEXTURE_REPEAT_WORLD_SIZE
	var u_right := right / TEXTURE_REPEAT_WORLD_SIZE
	_append_quad(
		buffers,
		Rect2(Vector2(left, top), Vector2(right - left, bottom - top)),
		PackedVector2Array([
			Vector2(u_left, top_v),
			Vector2(u_right, top_v),
			Vector2(u_right, bottom_v),
			Vector2(u_left, bottom_v)
		])
	)

func _append_vertical(
	buffers: Dictionary,
	top: float,
	bottom: float,
	boundary_x: float,
	width: float,
	flip_horizontal: bool
) -> void:
	# The base grass mesh already owns the walkable side. Drawing the grass half
	# of this directional texture created a dark square cap at both endpoints, so
	# only the rock interval is mapped inside the fall rectangle.
	var rock_width := width * (1.0 - VERTICAL_GRASS_RATIO)
	var left: float
	var right: float
	var left_u: float
	var right_u: float
	if flip_horizontal:
		left = boundary_x - rock_width
		right = boundary_x
		left_u = 1.0
		right_u = 0.0 if sample_full_texture else VERTICAL_ROCK_UV_START
	else:
		left = boundary_x
		right = boundary_x + rock_width
		left_u = 0.0 if sample_full_texture else VERTICAL_ROCK_UV_START
		right_u = 1.0
	var v_top := top / TEXTURE_REPEAT_WORLD_SIZE
	var v_bottom := bottom / TEXTURE_REPEAT_WORLD_SIZE
	_append_quad(
		buffers,
		Rect2(Vector2(left, top), Vector2(right - left, bottom - top)),
		PackedVector2Array([
			Vector2(left_u, v_top),
			Vector2(right_u, v_top),
			Vector2(right_u, v_bottom),
			Vector2(left_u, v_bottom)
		])
	)

func _mesh_buffers() -> Dictionary:
	return {
		"vertices": PackedVector2Array(),
		"colors": PackedColorArray(),
		"uvs": PackedVector2Array(),
		"indices": PackedInt32Array()
	}

func _append_quad(
	buffers: Dictionary,
	rect: Rect2,
	quad_uvs: PackedVector2Array
) -> void:
	var vertices := buffers["vertices"] as PackedVector2Array
	var colors := buffers["colors"] as PackedColorArray
	var uvs := buffers["uvs"] as PackedVector2Array
	var indices := buffers["indices"] as PackedInt32Array
	var base := vertices.size()
	vertices.append(rect.position)
	vertices.append(Vector2(rect.end.x, rect.position.y))
	vertices.append(rect.end)
	vertices.append(Vector2(rect.position.x, rect.end.y))
	for index in range(4):
		colors.append(Color.WHITE)
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
