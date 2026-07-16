extends RefCounted
class_name TopDownCliffBorderMeshBuilder

## Builds a continuous orthogonal rim around rectangular fall zones. The
## rectilinear face builder owns the descending rock faces; this builder
## owns the clearly readable grass-to-rock crest and its geometric joins. The
## crest always lies on the walkable side of the terrain/fall boundary; the
## face builder alone is allowed to project geometry into the void.

const RIM_WIDTH_TILES := 0.75
# The forest lip uses a compact flat-rock crest followed by the same nominal
# dirt-to-grass thickness used on one side of a road boundary.
const HORIZONTAL_ROCK_UV_START := 0.76
const VERTICAL_ROCK_UV_START := 0.64
const TEXTURE_REPEAT_WORLD_SIZE := 128.0
const FLAT_ROCK_TEXTURE_REPEAT_WORLD_SIZE := 256.0
const ROCK_DEPTH_RATIO := 0.40
const ROCK_MIN_DEPTH := 8.0
const FALL_ZONE_BOUNDARY_RUNS = preload(
	"res://game/modes/zombie/cliffs/fall_zone_boundary_runs.gd"
)
const TERRAIN_BOUNDARY_MASK_BUILDER = preload(
	"res://game/modes/zombie/terrain/terrain_boundary_mask_builder.gd"
)
const TRANSITION_WIDTH_TILES: float = (
	TERRAIN_BOUNDARY_MASK_BUILDER.DIVIDER_HALF_WIDTH_TILES
	+ TERRAIN_BOUNDARY_MASK_BUILDER.DIVIDER_FEATHER_TILES
)
const TRANSITION_MIN_WIDTH := 2.0
const TRANSITION_CORE_WIDTH_TILES: float = (
	TERRAIN_BOUNDARY_MASK_BUILDER.DIVIDER_HALF_WIDTH_TILES
	- TERRAIN_BOUNDARY_MASK_BUILDER.DIVIDER_FEATHER_TILES
)
const TRANSITION_CORE_MIN_WIDTH := 1.0
const TRANSITION_INNER_FEATHER_WIDTH_TILES: float = (
	TERRAIN_BOUNDARY_MASK_BUILDER.DIVIDER_FEATHER_TILES
)
const TRANSITION_INNER_FEATHER_MIN_WIDTH := 1.0
const TRANSITION_TEXTURE_REPEAT_WORLD_SIZE := 256.0
const ROUND_CORNER_SEGMENTS := 6

var horizontal_mesh: ArrayMesh
var vertical_mesh: ArrayMesh
var terrain_transition_mesh: ArrayMesh
var horizontal_segment_count: int = 0
var vertical_segment_count: int = 0
var terrain_transition_segment_count: int = 0
var terrain_transition_corner_count: int = 0
var corner_count: int = 0
var concave_corner_count: int = 0
var sample_full_texture: bool = false

func reset() -> void:
	horizontal_mesh = null
	vertical_mesh = null
	terrain_transition_mesh = null
	horizontal_segment_count = 0
	vertical_segment_count = 0
	terrain_transition_segment_count = 0
	terrain_transition_corner_count = 0
	corner_count = 0
	concave_corner_count = 0

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
	var terrain_transition := _mesh_buffers()
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
			terrain_transition,
			run,
			zone_offset,
			logical_scale,
			border_width
		)
	horizontal_mesh = _build_mesh(horizontal)
	vertical_mesh = _build_mesh(vertical)
	terrain_transition_mesh = _build_mesh(terrain_transition)

func build_dirt_outline(
	outline_rects: Array[Rect2i],
	zone_size: Vector2i,
	logical_scale: float
) -> void:
	reset()
	if outline_rects.is_empty() or logical_scale <= 0.0:
		return
	var terrain_transition := _mesh_buffers()
	var sides: Array[StringName] = []
	sides.resize(outline_rects.size())
	sides.fill(&"internal")
	var zone_offset := Vector2(zone_size) * 0.5
	var boundary_runs: Array[Dictionary] = FALL_ZONE_BOUNDARY_RUNS.build(
		outline_rects,
		sides,
		zone_size
	)
	for run in boundary_runs:
		_append_dirt_outline_run(
			terrain_transition,
			run,
			zone_offset,
			logical_scale
		)
	terrain_transition_mesh = _build_mesh(terrain_transition)

func get_total_segment_count() -> int:
	return horizontal_segment_count + vertical_segment_count + corner_count

func _append_dirt_outline_run(
	transition_buffers: Dictionary,
	run: Dictionary,
	zone_offset: Vector2,
	logical_scale: float
) -> void:
	var orientation := StringName(run.get("orientation", &""))
	var boundary := float(int(run.get("boundary", 0)))
	var start := float(int(run.get("start", 0)))
	var end := float(int(run.get("end", 0)))
	var transition_width := _transition_width(logical_scale)
	var transition_core_width := _transition_core_width(logical_scale)
	var inner_feather_width := _transition_inner_feather_width(logical_scale)
	var start_corner := StringName(run.get("start_corner", &""))
	var end_corner := StringName(run.get("end_corner", &""))
	match orientation:
		FALL_ZONE_BOUNDARY_RUNS.TOP, FALL_ZONE_BOUNDARY_RUNS.BOTTOM:
			var left := (start - zone_offset.x) * logical_scale
			var right := (end - zone_offset.x) * logical_scale
			var boundary_y := (boundary - zone_offset.y) * logical_scale
			if orientation == FALL_ZONE_BOUNDARY_RUNS.TOP:
				_append_profiled_transition_quad(
					transition_buffers,
					Rect2(
						Vector2(left, boundary_y - transition_width),
						Vector2(
							right - left,
							transition_width + inner_feather_width
						)
					),
					&"bottom",
					transition_core_width,
					inner_feather_width
				)
				_append_convex_dirt_corners(
					transition_buffers,
					Vector2(left, boundary_y),
					Vector2(right, boundary_y),
					start_corner,
					end_corner,
					true,
					transition_core_width,
					transition_width
				)
			else:
				_append_profiled_transition_quad(
					transition_buffers,
					Rect2(
						Vector2(left, boundary_y - inner_feather_width),
						Vector2(
							right - left,
							transition_width + inner_feather_width
						)
					),
					&"top",
					transition_core_width,
					inner_feather_width
				)
				_append_convex_dirt_corners(
					transition_buffers,
					Vector2(left, boundary_y),
					Vector2(right, boundary_y),
					start_corner,
					end_corner,
					false,
					transition_core_width,
					transition_width
				)
		FALL_ZONE_BOUNDARY_RUNS.LEFT, FALL_ZONE_BOUNDARY_RUNS.RIGHT:
			var top := (start - zone_offset.y) * logical_scale
			var bottom := (end - zone_offset.y) * logical_scale
			var boundary_x := (boundary - zone_offset.x) * logical_scale
			if orientation == FALL_ZONE_BOUNDARY_RUNS.LEFT:
				_append_profiled_transition_quad(
					transition_buffers,
					Rect2(
						Vector2(boundary_x - transition_width, top),
						Vector2(
							transition_width + inner_feather_width,
							bottom - top
						)
					),
					&"right",
					transition_core_width,
					inner_feather_width
				)
			else:
				_append_profiled_transition_quad(
					transition_buffers,
					Rect2(
						Vector2(boundary_x - inner_feather_width, top),
						Vector2(
							transition_width + inner_feather_width,
							bottom - top
						)
					),
					&"left",
					transition_core_width,
					inner_feather_width
				)
	terrain_transition_segment_count += 1

func _append_boundary_run(
	horizontal: Dictionary,
	vertical: Dictionary,
	terrain_transition: Dictionary,
	run: Dictionary,
	zone_offset: Vector2,
	logical_scale: float,
	border_width: float
) -> void:
	var orientation := StringName(run.get("orientation", &""))
	var boundary := float(int(run.get("boundary", 0)))
	var start := float(int(run.get("start", 0)))
	var end := float(int(run.get("end", 0)))
	var joint_depth := _horizontal_rock_depth(border_width)
	var start_corner := StringName(run.get("start_corner", &""))
	var end_corner := StringName(run.get("end_corner", &""))
	match orientation:
		FALL_ZONE_BOUNDARY_RUNS.TOP:
			var top_left := (start - zone_offset.x) * logical_scale
			var top_right := (end - zone_offset.x) * logical_scale
			if StringName(run.get("start_corner", &"")) == FALL_ZONE_BOUNDARY_RUNS.CORNER_CONCAVE:
				concave_corner_count += 1
			if StringName(run.get("end_corner", &"")) == FALL_ZONE_BOUNDARY_RUNS.CORNER_CONCAVE:
				concave_corner_count += 1
			_append_horizontal(
				horizontal,
				terrain_transition,
				top_left,
				top_right,
				(boundary - zone_offset.y) * logical_scale,
				border_width,
				false,
				start_corner,
				end_corner,
				logical_scale
			)
			horizontal_segment_count += 1
			corner_count += 2
		FALL_ZONE_BOUNDARY_RUNS.BOTTOM:
			var bottom_left := (start - zone_offset.x) * logical_scale
			var bottom_right := (end - zone_offset.x) * logical_scale
			if StringName(run.get("start_corner", &"")) == FALL_ZONE_BOUNDARY_RUNS.CORNER_CONCAVE:
				concave_corner_count += 1
			if StringName(run.get("end_corner", &"")) == FALL_ZONE_BOUNDARY_RUNS.CORNER_CONCAVE:
				concave_corner_count += 1
			_append_horizontal(
				horizontal,
				terrain_transition,
				bottom_left,
				bottom_right,
				(boundary - zone_offset.y) * logical_scale,
				border_width,
				true,
				start_corner,
				end_corner,
				logical_scale
			)
			horizontal_segment_count += 1
			corner_count += 2
		FALL_ZONE_BOUNDARY_RUNS.LEFT, FALL_ZONE_BOUNDARY_RUNS.RIGHT:
			var top := (start - zone_offset.y) * logical_scale
			var bottom := (end - zone_offset.y) * logical_scale
			# Once the crest is kept on walkable terrain, horizontal and vertical
			# strips overlap only at concave corners (the single walkable quadrant).
			# The horizontal strip owns that join. Convex corners occupy different
			# walkable quadrants and must retain the complete vertical endpoint.
			if (
				StringName(run.get("start_corner", &""))
				== FALL_ZONE_BOUNDARY_RUNS.CORNER_CONCAVE
			):
				top += joint_depth
			if (
				StringName(run.get("end_corner", &""))
				== FALL_ZONE_BOUNDARY_RUNS.CORNER_CONCAVE
			):
				bottom -= joint_depth
			_append_vertical(
				vertical,
				terrain_transition,
				top,
				bottom,
				(boundary - zone_offset.x) * logical_scale,
				border_width,
				orientation == FALL_ZONE_BOUNDARY_RUNS.RIGHT,
				start_corner,
				end_corner,
				logical_scale
			)
			vertical_segment_count += 1
			if StringName(run.get("perimeter_side", &"internal")) != &"internal":
				corner_count += 2

func _append_horizontal(
	buffers: Dictionary,
	transition_buffers: Dictionary,
	left: float,
	right: float,
	boundary_y: float,
	width: float,
	flip_vertical: bool,
	start_corner: StringName,
	end_corner: StringName,
	logical_scale: float
) -> void:
	# The old strip compressed the complete rock band into ~0.25 tile and stopped
	# exactly at run endpoints. Preserve the source aspect ratio and let the
	# horizontal run own the diagonal quadrant of every convex corner.
	var rock_depth := _horizontal_rock_depth(width)
	var corner_depth := _vertical_rock_depth(width)
	var transition_width := _transition_width(logical_scale)
	var transition_core_width := _transition_core_width(logical_scale)
	var inner_feather_width := minf(
		_transition_inner_feather_width(logical_scale),
		rock_depth * 0.5
	)
	var has_start_corner := start_corner == FALL_ZONE_BOUNDARY_RUNS.CORNER_CONVEX
	var has_end_corner := end_corner == FALL_ZONE_BOUNDARY_RUNS.CORNER_CONVEX
	var rim_left := left - corner_depth if has_start_corner else left
	var rim_right := right + corner_depth if has_end_corner else right
	var top: float
	var bottom: float
	var top_v: float
	var bottom_v: float
	var rock_v_end := _horizontal_rock_uv_end(rock_depth)
	if flip_vertical:
		top = boundary_y
		bottom = boundary_y + rock_depth
		top_v = 1.0 if sample_full_texture else rock_v_end
		bottom_v = 0.0 if sample_full_texture else HORIZONTAL_ROCK_UV_START
	else:
		top = boundary_y - rock_depth
		bottom = boundary_y
		top_v = 0.0 if sample_full_texture else HORIZONTAL_ROCK_UV_START
		bottom_v = 1.0 if sample_full_texture else rock_v_end
	var rim_rect := Rect2(
		Vector2(rim_left, top),
		Vector2(rim_right - rim_left, bottom - top)
	)
	var u_left := rim_left / TEXTURE_REPEAT_WORLD_SIZE
	var u_right := rim_right / TEXTURE_REPEAT_WORLD_SIZE
	var rim_uvs := PackedVector2Array([
		Vector2(u_left, top_v),
		Vector2(u_right, top_v),
		Vector2(u_right, bottom_v),
		Vector2(u_left, bottom_v)
	])
	if not sample_full_texture:
		rim_uvs = _planar_flat_rock_uvs(rim_rect)
	_append_quad(
		buffers,
		rim_rect,
		rim_uvs
	)
	# Dirt transition uses the same repeating material as road boundaries. It is
	# opaque beside the rock and fades into the existing terrain at the outer edge.
	var transition_left := rim_left
	var transition_right := rim_right
	if flip_vertical:
		_append_profiled_transition_quad(
			transition_buffers,
			Rect2(
				Vector2(transition_left, bottom - inner_feather_width),
				Vector2(
					transition_right - transition_left,
					transition_width + inner_feather_width
				)
			),
			&"top",
			transition_core_width,
			inner_feather_width
		)
		_append_convex_dirt_corners(
			transition_buffers,
			Vector2(rim_left, bottom),
			Vector2(rim_right, bottom),
			start_corner,
			end_corner,
			false,
			transition_core_width,
			transition_width
		)
	else:
		_append_profiled_transition_quad(
			transition_buffers,
			Rect2(
				Vector2(transition_left, top - transition_width),
				Vector2(
					transition_right - transition_left,
					transition_width + inner_feather_width
				)
			),
			&"bottom",
			transition_core_width,
			inner_feather_width
		)
		_append_convex_dirt_corners(
			transition_buffers,
			Vector2(rim_left, top),
			Vector2(rim_right, top),
			start_corner,
			end_corner,
			true,
			transition_core_width,
			transition_width
		)
	terrain_transition_segment_count += 1

func _append_vertical(
	buffers: Dictionary,
	transition_buffers: Dictionary,
	top: float,
	bottom: float,
	boundary_x: float,
	width: float,
	flip_horizontal: bool,
	start_corner: StringName,
	end_corner: StringName,
	logical_scale: float
) -> void:
	# Keep the directional rock interval on the walkable side. This prevents the
	# vertical rim from reading as a narrow ledge inside the fall collision.
	var rock_width := _vertical_rock_depth(width)
	var horizontal_corner_depth := _horizontal_rock_depth(width)
	var transition_width := _transition_width(logical_scale)
	var transition_core_width := _transition_core_width(logical_scale)
	var inner_feather_width := minf(
		_transition_inner_feather_width(logical_scale),
		rock_width * 0.5
	)
	var transition_top := (
		top - horizontal_corner_depth
		if start_corner == FALL_ZONE_BOUNDARY_RUNS.CORNER_CONVEX
		else top
	)
	var transition_bottom := (
		bottom + horizontal_corner_depth
		if end_corner == FALL_ZONE_BOUNDARY_RUNS.CORNER_CONVEX
		else bottom
	)
	var left: float
	var right: float
	var left_u: float
	var right_u: float
	var rock_u_end := _vertical_rock_uv_end(rock_width)
	if flip_horizontal:
		left = boundary_x
		right = boundary_x + rock_width
		left_u = 1.0 if sample_full_texture else rock_u_end
		right_u = 0.0 if sample_full_texture else VERTICAL_ROCK_UV_START
	else:
		left = boundary_x - rock_width
		right = boundary_x
		left_u = 0.0 if sample_full_texture else VERTICAL_ROCK_UV_START
		right_u = 1.0 if sample_full_texture else rock_u_end
	var v_top := top / TEXTURE_REPEAT_WORLD_SIZE
	var v_bottom := bottom / TEXTURE_REPEAT_WORLD_SIZE
	var rim_rect := Rect2(
		Vector2(left, top),
		Vector2(right - left, bottom - top)
	)
	var rim_uvs := PackedVector2Array([
		Vector2(left_u, v_top),
		Vector2(right_u, v_top),
		Vector2(right_u, v_bottom),
		Vector2(left_u, v_bottom)
	])
	if not sample_full_texture:
		rim_uvs = _planar_flat_rock_uvs(rim_rect)
	_append_quad(
		buffers,
		rim_rect,
		rim_uvs
	)
	if flip_horizontal:
		_append_profiled_transition_quad(
			transition_buffers,
			Rect2(
				Vector2(right - inner_feather_width, transition_top),
				Vector2(
					transition_width + inner_feather_width,
					transition_bottom - transition_top
				)
			),
			&"left",
			transition_core_width,
			inner_feather_width
		)
	else:
		_append_profiled_transition_quad(
			transition_buffers,
			Rect2(
				Vector2(left - transition_width, transition_top),
				Vector2(
					transition_width + inner_feather_width,
					transition_bottom - transition_top
				)
			),
			&"right",
			transition_core_width,
			inner_feather_width
		)
	terrain_transition_segment_count += 1

func _horizontal_rock_depth(width: float) -> float:
	if sample_full_texture:
		return width
	return minf(width, maxf(width * ROCK_DEPTH_RATIO, ROCK_MIN_DEPTH))

func _vertical_rock_depth(width: float) -> float:
	if sample_full_texture:
		return width
	return minf(width, maxf(width * ROCK_DEPTH_RATIO, ROCK_MIN_DEPTH))

func _horizontal_rock_uv_end(rock_depth: float) -> float:
	return minf(
		HORIZONTAL_ROCK_UV_START + rock_depth / TEXTURE_REPEAT_WORLD_SIZE,
		1.0
	)

func _vertical_rock_uv_end(rock_depth: float) -> float:
	return minf(
		VERTICAL_ROCK_UV_START + rock_depth / TEXTURE_REPEAT_WORLD_SIZE,
		1.0
	)

func _planar_flat_rock_uvs(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([
		rect.position / FLAT_ROCK_TEXTURE_REPEAT_WORLD_SIZE,
		Vector2(rect.end.x, rect.position.y) / FLAT_ROCK_TEXTURE_REPEAT_WORLD_SIZE,
		rect.end / FLAT_ROCK_TEXTURE_REPEAT_WORLD_SIZE,
		Vector2(rect.position.x, rect.end.y) / FLAT_ROCK_TEXTURE_REPEAT_WORLD_SIZE,
	])

func _transition_width(logical_scale: float) -> float:
	return maxf(logical_scale * TRANSITION_WIDTH_TILES, TRANSITION_MIN_WIDTH)

func _transition_core_width(logical_scale: float) -> float:
	return minf(
		_transition_width(logical_scale),
		maxf(
			logical_scale * TRANSITION_CORE_WIDTH_TILES,
			TRANSITION_CORE_MIN_WIDTH
		)
	)

func _transition_inner_feather_width(logical_scale: float) -> float:
	return maxf(
		logical_scale * TRANSITION_INNER_FEATHER_WIDTH_TILES,
		TRANSITION_INNER_FEATHER_MIN_WIDTH
	)

func _transition_inner_color() -> Color:
	# The solid color is shared by the dirt core and the inner endpoints of both
	# feathers; only their far endpoints become transparent.
	return Color.WHITE

func _transition_outer_color() -> Color:
	return Color(1.0, 1.0, 1.0, 0.0)

func _append_convex_dirt_corners(
	buffers: Dictionary,
	start_center: Vector2,
	end_center: Vector2,
	start_corner: StringName,
	end_corner: StringName,
	top_side: bool,
	core_radius: float,
	outer_radius: float
) -> void:
	if start_corner == FALL_ZONE_BOUNDARY_RUNS.CORNER_CONVEX:
		_append_profiled_dirt_corner(
			buffers,
			start_center,
			PI if top_side else PI * 0.5,
			PI * 1.5 if top_side else PI,
			core_radius,
			outer_radius
		)
	elif start_corner == FALL_ZONE_BOUNDARY_RUNS.CORNER_DIAGONAL:
		# At a checkerboard vertex, the geometrically adjacent quadrant belongs
		# to the other void. Join the two bands through the opposite walkable
		# quadrant instead of painting another arm into the central cross.
		_append_profiled_dirt_corner(
			buffers,
			start_center,
			PI * 1.5 if top_side else 0.0,
			TAU if top_side else PI * 0.5,
			core_radius,
			outer_radius
		)
	if end_corner == FALL_ZONE_BOUNDARY_RUNS.CORNER_CONVEX:
		_append_profiled_dirt_corner(
			buffers,
			end_center,
			PI * 1.5 if top_side else 0.0,
			TAU if top_side else PI * 0.5,
			core_radius,
			outer_radius
		)
	elif end_corner == FALL_ZONE_BOUNDARY_RUNS.CORNER_DIAGONAL:
		_append_profiled_dirt_corner(
			buffers,
			end_center,
			PI if top_side else PI * 0.5,
			PI * 1.5 if top_side else PI,
			core_radius,
			outer_radius
		)

func _append_profiled_dirt_corner(
	buffers: Dictionary,
	center: Vector2,
	start_angle: float,
	end_angle: float,
	core_radius: float,
	outer_radius: float
) -> void:
	var clamped_outer_radius := maxf(outer_radius, 0.0)
	var clamped_core_radius := clampf(
		core_radius,
		0.0,
		clamped_outer_radius
	)
	if clamped_outer_radius <= 0.001:
		return
	for segment_index in range(ROUND_CORNER_SEGMENTS):
		var start_weight := float(segment_index) / float(ROUND_CORNER_SEGMENTS)
		var end_weight := float(segment_index + 1) / float(ROUND_CORNER_SEGMENTS)
		var angle_a := lerpf(start_angle, end_angle, start_weight)
		var angle_b := lerpf(start_angle, end_angle, end_weight)
		var direction_a := Vector2(cos(angle_a), sin(angle_a))
		var direction_b := Vector2(cos(angle_b), sin(angle_b))
		var core_a := center + direction_a * clamped_core_radius
		var core_b := center + direction_b * clamped_core_radius
		var outer_a := center + direction_a * clamped_outer_radius
		var outer_b := center + direction_b * clamped_outer_radius
		_append_transition_triangle(
			buffers,
			center,
			core_a,
			core_b,
			_transition_inner_color(),
			_transition_inner_color(),
			_transition_inner_color()
		)
		_append_transition_triangle(
			buffers,
			core_a,
			outer_a,
			outer_b,
			_transition_inner_color(),
			_transition_outer_color(),
			_transition_outer_color()
		)
		_append_transition_triangle(
			buffers,
			core_a,
			outer_b,
			core_b,
			_transition_inner_color(),
			_transition_outer_color(),
			_transition_inner_color()
		)
	terrain_transition_corner_count += 1

func _append_transition_triangle(
	buffers: Dictionary,
	point_a: Vector2,
	point_b: Vector2,
	point_c: Vector2,
	color_a: Color,
	color_b: Color,
	color_c: Color
) -> void:
	var vertices := buffers["vertices"] as PackedVector2Array
	var colors := buffers["colors"] as PackedColorArray
	var uvs := buffers["uvs"] as PackedVector2Array
	var indices := buffers["indices"] as PackedInt32Array
	var base := vertices.size()
	vertices.append(point_a)
	vertices.append(point_b)
	vertices.append(point_c)
	uvs.append(point_a / TRANSITION_TEXTURE_REPEAT_WORLD_SIZE)
	uvs.append(point_b / TRANSITION_TEXTURE_REPEAT_WORLD_SIZE)
	uvs.append(point_c / TRANSITION_TEXTURE_REPEAT_WORLD_SIZE)
	colors.append(color_a)
	colors.append(color_b)
	colors.append(color_c)
	indices.append(base)
	indices.append(base + 1)
	indices.append(base + 2)
	buffers["vertices"] = vertices
	buffers["colors"] = colors
	buffers["uvs"] = uvs
	buffers["indices"] = indices

func _append_profiled_transition_quad(
	buffers: Dictionary,
	rect: Rect2,
	inner_edge: StringName,
	core_width: float,
	inner_feather_width: float
) -> void:
	var maximum_core_width := rect.size.x
	if inner_edge == &"top" or inner_edge == &"bottom":
		maximum_core_width = rect.size.y
	var clamped_inner_feather_width := clampf(
		inner_feather_width,
		0.0,
		maximum_core_width
	)
	var clamped_core_width := clampf(
		core_width,
		0.0,
		maximum_core_width - clamped_inner_feather_width
	)
	var inner_feather_rect := rect
	var core_rect := rect
	var outer_feather_rect := rect
	var inner_feather_colors := PackedColorArray()
	var outer_feather_colors := PackedColorArray()
	match inner_edge:
		&"top":
			inner_feather_rect.size.y = clamped_inner_feather_width
			core_rect.position.y += clamped_inner_feather_width
			core_rect.size.y = clamped_core_width
			outer_feather_rect.position.y += (
				clamped_inner_feather_width + clamped_core_width
			)
			outer_feather_rect.size.y -= (
				clamped_inner_feather_width + clamped_core_width
			)
			inner_feather_colors = PackedColorArray([
				_transition_outer_color(),
				_transition_outer_color(),
				_transition_inner_color(),
				_transition_inner_color(),
			])
			outer_feather_colors = PackedColorArray([
				_transition_inner_color(),
				_transition_inner_color(),
				_transition_outer_color(),
				_transition_outer_color(),
			])
		&"bottom":
			inner_feather_rect.position.y = (
				rect.end.y - clamped_inner_feather_width
			)
			inner_feather_rect.size.y = clamped_inner_feather_width
			core_rect.position.y = (
				inner_feather_rect.position.y - clamped_core_width
			)
			core_rect.size.y = clamped_core_width
			outer_feather_rect.size.y -= (
				clamped_inner_feather_width + clamped_core_width
			)
			inner_feather_colors = PackedColorArray([
				_transition_inner_color(),
				_transition_inner_color(),
				_transition_outer_color(),
				_transition_outer_color(),
			])
			outer_feather_colors = PackedColorArray([
				_transition_outer_color(),
				_transition_outer_color(),
				_transition_inner_color(),
				_transition_inner_color(),
			])
		&"left":
			inner_feather_rect.size.x = clamped_inner_feather_width
			core_rect.position.x += clamped_inner_feather_width
			core_rect.size.x = clamped_core_width
			outer_feather_rect.position.x += (
				clamped_inner_feather_width + clamped_core_width
			)
			outer_feather_rect.size.x -= (
				clamped_inner_feather_width + clamped_core_width
			)
			inner_feather_colors = PackedColorArray([
				_transition_outer_color(),
				_transition_inner_color(),
				_transition_inner_color(),
				_transition_outer_color(),
			])
			outer_feather_colors = PackedColorArray([
				_transition_inner_color(),
				_transition_outer_color(),
				_transition_outer_color(),
				_transition_inner_color(),
			])
		&"right":
			inner_feather_rect.position.x = (
				rect.end.x - clamped_inner_feather_width
			)
			inner_feather_rect.size.x = clamped_inner_feather_width
			core_rect.position.x = (
				inner_feather_rect.position.x - clamped_core_width
			)
			core_rect.size.x = clamped_core_width
			outer_feather_rect.size.x -= (
				clamped_inner_feather_width + clamped_core_width
			)
			inner_feather_colors = PackedColorArray([
				_transition_inner_color(),
				_transition_outer_color(),
				_transition_outer_color(),
				_transition_inner_color(),
			])
			outer_feather_colors = PackedColorArray([
				_transition_outer_color(),
				_transition_inner_color(),
				_transition_inner_color(),
				_transition_outer_color(),
			])
		_:
			return
	if inner_feather_rect.size.x > 0.001 and inner_feather_rect.size.y > 0.001:
		_append_transition_quad(
			buffers,
			inner_feather_rect,
			inner_feather_colors
		)
	_append_transition_quad(
		buffers,
		core_rect,
		PackedColorArray([
			_transition_inner_color(),
			_transition_inner_color(),
			_transition_inner_color(),
			_transition_inner_color(),
		])
	)
	if outer_feather_rect.size.x > 0.001 and outer_feather_rect.size.y > 0.001:
		_append_transition_quad(
			buffers,
			outer_feather_rect,
			outer_feather_colors
		)

func _append_transition_quad(
	buffers: Dictionary,
	rect: Rect2,
	quad_colors: PackedColorArray
) -> void:
	var top_left := rect.position
	var top_right := Vector2(rect.end.x, rect.position.y)
	var bottom_right := rect.end
	var bottom_left := Vector2(rect.position.x, rect.end.y)
	_append_colored_quad(
		buffers,
		rect,
		PackedVector2Array([
			top_left / TRANSITION_TEXTURE_REPEAT_WORLD_SIZE,
			top_right / TRANSITION_TEXTURE_REPEAT_WORLD_SIZE,
			bottom_right / TRANSITION_TEXTURE_REPEAT_WORLD_SIZE,
			bottom_left / TRANSITION_TEXTURE_REPEAT_WORLD_SIZE,
		]),
		quad_colors
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
	_append_colored_quad(
		buffers,
		rect,
		quad_uvs,
		PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])
	)

func _append_colored_quad(
	buffers: Dictionary,
	rect: Rect2,
	quad_uvs: PackedVector2Array,
	quad_colors: PackedColorArray
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
