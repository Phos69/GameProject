extends RefCounted
class_name RectilinearCliffFaceMeshBuilder

## Builds continuous projected cliff faces from the unified fall-zone outline.
## Every orthogonal corner is resolved before triangulation: its two incident
## runs share one combined deep vertex, so there are no patch triangles, shelves
## or uncovered quadrants. Perimeter east/west faces keep their oblique drop.

const TEXTURE_REPEAT_WORLD_SIZE := 128.0
const PERIMETER_FACE_DEPTH_TILES := 1.15
const PERIMETER_MIN_FACE_DEPTH := 42.0
const INTERNAL_LATERAL_WALL_WIDTH_TILES := 0.65
const INTERNAL_FAR_FACE_DEPTH_TILES := 1.75
# Horizontal lean of the lateral walls as a fraction of their drop depth. 0.0 is a
# flat vertical strip; ~0.5 ≈ 27° from vertical, matching TopDownCliffMeshBuilder.
const LATERAL_VOID_SLOPE := 0.5
const FALL_ZONE_BOUNDARY_RUNS = preload(
	"res://game/modes/zombie/cliffs/fall_zone_boundary_runs.gd"
)

var face_mesh: ArrayMesh
var face_count: int = 0
var concave_join_count: int = 0
var corner_drop_by_vertex: Dictionary = {}

func reset() -> void:
	face_mesh = null
	face_count = 0
	concave_join_count = 0
	corner_drop_by_vertex.clear()

func build(
	fall_zone_rects: Array[Rect2i],
	fall_zone_sides: Array[StringName],
	zone_size: Vector2i,
	logical_scale: float
) -> void:
	reset()
	if fall_zone_rects.is_empty() or logical_scale <= 0.0:
		return
	var zone_offset := Vector2(zone_size) * 0.5
	var boundary_runs: Array[Dictionary] = FALL_ZONE_BOUNDARY_RUNS.build(
		fall_zone_rects,
		fall_zone_sides,
		zone_size
	)
	var face_runs: Array[Dictionary] = []
	for run in boundary_runs:
		var face_run := _describe_boundary_run(run, zone_offset, logical_scale)
		if not face_run.is_empty():
			face_runs.append(face_run)
	corner_drop_by_vertex = _build_corner_drops(face_runs)
	var buffers := QuadMeshBuffers.create()
	for face_run in face_runs:
		_append_face_run(buffers, face_run, corner_drop_by_vertex)
	face_mesh = QuadMeshBuffers.build_mesh(buffers)

func _describe_boundary_run(
	run: Dictionary,
	zone_offset: Vector2,
	logical_scale: float
) -> Dictionary:
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
		var void_direction_y := 1.0 if orientation == FALL_ZONE_BOUNDARY_RUNS.TOP else -1.0
		var face_depth := (
			_far_face_depth(depth_rect, perimeter_side, logical_scale)
			if orientation == FALL_ZONE_BOUNDARY_RUNS.TOP
			else _near_face_depth(depth_rect, perimeter_side, logical_scale)
		)
		return _face_run_data(
			Vector2(left, boundary_y),
			Vector2(right, boundary_y),
			Vector2(0.0, void_direction_y * face_depth),
			Vector2i(int(start), int(boundary)),
			Vector2i(int(end), int(boundary)),
			run,
			perimeter_side == FALL_ZONE_BOUNDARY_RUNS.INTERNAL
		)
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
		return _face_run_data(
			Vector2(boundary_x, top),
			Vector2(
				boundary_x,
				bottom - minf(drop_depth, (bottom - top) * 0.5)
			),
			Vector2(
				-slant if orientation == FALL_ZONE_BOUNDARY_RUNS.RIGHT else slant,
				drop_depth
			),
			Vector2i(int(boundary), int(start)),
			Vector2i(int(boundary), int(end)),
			run,
			false
		)
	var lateral_width := minf(
		maxf(logical_scale * INTERNAL_LATERAL_WALL_WIDTH_TILES, 8.0),
		inward_width * 0.18
	)
	return _face_run_data(
		Vector2(boundary_x, top),
		Vector2(boundary_x, bottom),
		Vector2(
			lateral_width if orientation == FALL_ZONE_BOUNDARY_RUNS.LEFT else -lateral_width,
			0.0
		),
		Vector2i(int(boundary), int(start)),
		Vector2i(int(boundary), int(end)),
		run,
		true
	)

func _face_run_data(
	start_point: Vector2,
	end_point: Vector2,
	default_drop: Vector2,
	start_vertex: Vector2i,
	end_vertex: Vector2i,
	source_run: Dictionary,
	joinable: bool
) -> Dictionary:
	return {
		"start_point": start_point,
		"end_point": end_point,
		"default_drop": default_drop,
		"start_vertex": start_vertex,
		"end_vertex": end_vertex,
		"start_corner": StringName(source_run.get("start_corner", &"")),
		"end_corner": StringName(source_run.get("end_corner", &"")),
		"joinable": joinable,
	}

func _build_corner_drops(face_runs: Array[Dictionary]) -> Dictionary:
	var corner_parts := {}
	for face_run in face_runs:
		if not bool(face_run.get("joinable", false)):
			continue
		_append_corner_part(corner_parts, face_run, true)
		_append_corner_part(corner_parts, face_run, false)
	var corner_drops := {}
	for vertex in corner_parts:
		var part := corner_parts[vertex] as Dictionary
		if not bool(part.get("has_horizontal", false)):
			continue
		if not bool(part.get("has_vertical", false)):
			continue
		corner_drops[vertex] = part.get("drop", Vector2.ZERO)
		if StringName(part.get("kind", &"")) == FALL_ZONE_BOUNDARY_RUNS.CORNER_CONCAVE:
			concave_join_count += 1
	return corner_drops

func _append_corner_part(
	corner_parts: Dictionary,
	face_run: Dictionary,
	is_start: bool
) -> void:
	var kind := StringName(face_run.get(
		"start_corner" if is_start else "end_corner",
		&""
	))
	if (
		kind != FALL_ZONE_BOUNDARY_RUNS.CORNER_CONCAVE
		and kind != FALL_ZONE_BOUNDARY_RUNS.CORNER_CONVEX
	):
		return
	var vertex := face_run.get(
		"start_vertex" if is_start else "end_vertex",
		Vector2i.ZERO
	) as Vector2i
	var default_drop := face_run.get("default_drop", Vector2.ZERO) as Vector2
	var part := corner_parts.get(vertex, {
		"drop": Vector2.ZERO,
		"has_horizontal": false,
		"has_vertical": false,
		"kind": kind,
	}) as Dictionary
	var combined_drop := part.get("drop", Vector2.ZERO) as Vector2
	if not is_zero_approx(default_drop.x):
		combined_drop.x = default_drop.x
		part["has_vertical"] = true
	if not is_zero_approx(default_drop.y):
		combined_drop.y = default_drop.y
		part["has_horizontal"] = true
	part["drop"] = combined_drop
	corner_parts[vertex] = part

func _append_face_run(
	buffers: Dictionary,
	face_run: Dictionary,
	corner_drops: Dictionary
) -> void:
	var start_point := face_run.get("start_point", Vector2.ZERO) as Vector2
	var end_point := face_run.get("end_point", Vector2.ZERO) as Vector2
	var default_drop := face_run.get("default_drop", Vector2.ZERO) as Vector2
	var start_drop := default_drop
	var end_drop := default_drop
	var is_vertical := is_equal_approx(start_point.x, end_point.x)
	var start_kind := StringName(face_run.get("start_corner", &""))
	var end_kind := StringName(face_run.get("end_corner", &""))
	if bool(face_run.get("joinable", false)):
		# Convex corners are owned by the horizontal face, which stays rectangular.
		# Vertical faces still read the combined drop so they can be clipped to the
		# horizontal deep edge. Concave corners use the combined drop on both runs.
		if is_vertical or start_kind != FALL_ZONE_BOUNDARY_RUNS.CORNER_CONVEX:
			start_drop = corner_drops.get(
				face_run.get("start_vertex", Vector2i.ZERO),
				default_drop
			) as Vector2
		if is_vertical or end_kind != FALL_ZONE_BOUNDARY_RUNS.CORNER_CONVEX:
			end_drop = corner_drops.get(
				face_run.get("end_vertex", Vector2i.ZERO),
				default_drop
			) as Vector2
	# At convex corners the horizontal wall owns the complete projected depth.
	# Clip a vertical face to that wall's deep edge instead of painting a texture
	# band over it. Concave joins have the opposite endpoint/drop directions and
	# therefore keep their shared diagonal seam untouched.
	if bool(face_run.get("joinable", false)) and is_vertical:
		if (
			start_kind == FALL_ZONE_BOUNDARY_RUNS.CORNER_CONVEX
			and start_drop.y > 0.0
		):
			start_point.y += start_drop.y
			start_drop.y = 0.0
		if (
			end_kind == FALL_ZONE_BOUNDARY_RUNS.CORNER_CONVEX
			and end_drop.y < 0.0
		):
			end_point.y += end_drop.y
			end_drop.y = 0.0
		if end_point.y <= start_point.y:
			return
	_append_projected_face(buffers, start_point, end_point, start_drop, end_drop)

func _far_face_depth(rect: Rect2, side: StringName, logical_scale: float) -> float:
	if _is_perimeter_side(side):
		return maxf(logical_scale * PERIMETER_FACE_DEPTH_TILES, PERIMETER_MIN_FACE_DEPTH)
	return minf(
		maxf(logical_scale * INTERNAL_FAR_FACE_DEPTH_TILES, 24.0),
		rect.size.y
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

func _append_projected_face(
	buffers: Dictionary,
	start_point: Vector2,
	end_point: Vector2,
	start_drop: Vector2,
	end_drop: Vector2
) -> void:
	# Every boundary run is a projected quad. Adjacent orthogonal runs receive the
	# same corner drop, so both faces share the complete crest-to-depth seam. This
	# is the corner geometry itself: no cap triangle or overlapping rectangle is
	# allowed to patch the join afterwards.
	if start_point.is_equal_approx(end_point):
		return
	if start_drop.length_squared() <= 0.001 or end_drop.length_squared() <= 0.001:
		return
	# Use one planar world-space projection for the complete outline. Sharing only
	# the U phase at the seam still let horizontal and vertical faces sample the
	# baked shadow in different directions immediately beside the corner, so the
	# join remained visibly light on one side and dark on the other. Mapping both
	# axes from the final vertex position gives incident faces identical texture
	# values all along their shared edge and a continuous derivative around it.
	# The vertex colors below remain the only crest-to-void fade.
	var start_deep_point := start_point + start_drop
	var end_deep_point := end_point + end_drop
	var quad_vertices := PackedVector2Array([
		start_point,
		end_point,
		end_deep_point,
		start_deep_point,
	])
	var quad_uvs := PackedVector2Array([
		_world_space_uv(start_point),
		_world_space_uv(end_point),
		_world_space_uv(end_deep_point),
		_world_space_uv(start_deep_point),
	])
	var cross := (end_point - start_point).cross(end_deep_point - start_point)
	if cross < 0.0:
		quad_vertices = PackedVector2Array([
			end_point,
			start_point,
			start_deep_point,
			end_deep_point,
		])
		quad_uvs = PackedVector2Array([
			_world_space_uv(end_point),
			_world_space_uv(start_point),
			_world_space_uv(start_deep_point),
			_world_space_uv(end_deep_point),
		])
	QuadMeshBuffers.append_quad(
		buffers,
		quad_vertices,
		quad_uvs,
		PackedColorArray([
			_boundary_color(),
			_boundary_color(),
			_inside_color(),
			_inside_color(),
		])
	)
	face_count += 1

func _world_space_uv(point: Vector2) -> Vector2:
	return point / TEXTURE_REPEAT_WORLD_SIZE

func _boundary_color() -> Color:
	return Color(1.0, 1.0, 1.0, 0.96)

func _inside_color() -> Color:
	return Color(0.52, 0.52, 0.52, 0.16)

