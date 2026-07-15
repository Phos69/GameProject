extends RefCounted
class_name BiomeObstaclePainter

const RAISED_CLIFF_FACE_REPEAT_WORLD_SIZE := 128.0
const RAISED_CLIFF_TOP_REPEAT_WORLD_SIZE := 256.0
const RAISED_CLIFF_LEAN_RATIO := 0.42

static func draw_raised_perimeter_cliff(
	canvas: CanvasItem,
	obstacle_size: Vector2,
	side: StringName,
	wall_height: float,
	face_texture: Texture2D,
	top_texture: Texture2D,
	uv_origin: Vector2
) -> void:
	_draw_raised_cliff_shadow(canvas, obstacle_size)
	if obstacle_size.x >= obstacle_size.y:
		_draw_horizontal_raised_cliff(
			canvas,
			obstacle_size,
			side,
			wall_height,
			face_texture,
			top_texture,
			uv_origin
		)
	else:
		_draw_vertical_raised_cliff(
			canvas,
			obstacle_size,
			side,
			wall_height,
			face_texture,
			top_texture,
			uv_origin
		)

static func _draw_horizontal_raised_cliff(
	canvas: CanvasItem,
	obstacle_size: Vector2,
	side: StringName,
	wall_height: float,
	face_texture: Texture2D,
	top_texture: Texture2D,
	uv_origin: Vector2
) -> void:
	var half := obstacle_size * 0.5
	var lift := Vector2(0.0, -wall_height)
	var north_west := Vector2(-half.x, -half.y)
	var north_east := Vector2(half.x, -half.y)
	var south_east := Vector2(half.x, half.y)
	var south_west := Vector2(-half.x, half.y)
	var top_north_west := north_west + lift
	var top_north_east := north_east + lift
	var top_south_east := south_east + lift
	var top_south_west := south_west + lift
	var face_brightness := 0.94 if side == &"north" else 1.0
	_draw_cliff_face(
		canvas,
		PackedVector2Array([
			south_west,
			south_east,
			top_south_east,
			top_south_west
		]),
		uv_origin.x,
		uv_origin.x + obstacle_size.x,
		wall_height,
		face_brightness,
		face_texture
	)
	_draw_cliff_top(
		canvas,
		PackedVector2Array([
			top_north_west,
			top_north_east,
			top_south_east,
			top_south_west
		]),
		uv_origin,
		half,
		top_texture
	)

static func _draw_vertical_raised_cliff(
	canvas: CanvasItem,
	obstacle_size: Vector2,
	side: StringName,
	wall_height: float,
	face_texture: Texture2D,
	top_texture: Texture2D,
	uv_origin: Vector2
) -> void:
	var half := obstacle_size * 0.5
	var lean := minf(
		wall_height * RAISED_CLIFF_LEAN_RATIO,
		obstacle_size.x * 0.30
	)
	var north_west := Vector2(-half.x, -half.y)
	var north_east := Vector2(half.x, -half.y)
	var south_east := Vector2(half.x, half.y)
	var south_west := Vector2(-half.x, half.y)
	var top_north_west := north_west + Vector2(lean, -wall_height)
	var top_north_east := north_east + Vector2(-lean, -wall_height)
	var top_south_east := south_east + Vector2(-lean, -wall_height)
	var top_south_west := south_west + Vector2(lean, -wall_height)
	var west_brightness := 0.88 if side == &"east" else 0.68
	var east_brightness := 0.88 if side == &"west" else 0.76
	_draw_cliff_face(
		canvas,
		PackedVector2Array([
			north_west,
			south_west,
			top_south_west,
			top_north_west
		]),
		uv_origin.y,
		uv_origin.y + obstacle_size.y,
		wall_height,
		west_brightness,
		face_texture
	)
	_draw_cliff_face(
		canvas,
		PackedVector2Array([
			south_east,
			north_east,
			top_north_east,
			top_south_east
		]),
		uv_origin.y + obstacle_size.y,
		uv_origin.y,
		wall_height,
		east_brightness,
		face_texture
	)
	_draw_cliff_top(
		canvas,
		PackedVector2Array([
			top_north_west,
			top_north_east,
			top_south_east,
			top_south_west
		]),
		uv_origin,
		half,
		top_texture
	)

static func _draw_cliff_face(
	canvas: CanvasItem,
	points: PackedVector2Array,
	run_start: float,
	run_finish: float,
	wall_height: float,
	brightness: float,
	texture: Texture2D
) -> void:
	var run_start_uv := run_start / RAISED_CLIFF_FACE_REPEAT_WORLD_SIZE
	var run_finish_uv := run_finish / RAISED_CLIFF_FACE_REPEAT_WORLD_SIZE
	var rise_uv := wall_height / RAISED_CLIFF_FACE_REPEAT_WORLD_SIZE
	var ground_shade := brightness * 0.70
	canvas.draw_polygon(
		points,
		PackedColorArray([
			Color(ground_shade, ground_shade, ground_shade, 1.0),
			Color(ground_shade, ground_shade, ground_shade, 1.0),
			Color(brightness, brightness, brightness, 1.0),
			Color(brightness, brightness, brightness, 1.0)
		]),
		PackedVector2Array([
			Vector2(run_start_uv, rise_uv),
			Vector2(run_finish_uv, rise_uv),
			Vector2(run_finish_uv, 0.0),
			Vector2(run_start_uv, 0.0)
		]),
		texture
	)

static func _draw_cliff_top(
	canvas: CanvasItem,
	points: PackedVector2Array,
	uv_origin: Vector2,
	half_size: Vector2,
	texture: Texture2D
) -> void:
	var uvs := PackedVector2Array()
	for point in points:
		uvs.append(
			(
				uv_origin
				+ point
				+ half_size
			) / RAISED_CLIFF_TOP_REPEAT_WORLD_SIZE
		)
	canvas.draw_polygon(
		points,
		PackedColorArray([
			Color(1.06, 1.06, 1.06, 1.0),
			Color(1.06, 1.06, 1.06, 1.0),
			Color(1.02, 1.02, 1.02, 1.0),
			Color(1.02, 1.02, 1.02, 1.0)
		]),
		uvs,
		texture
	)

static func _draw_raised_cliff_shadow(
	canvas: CanvasItem,
	obstacle_size: Vector2
) -> void:
	var half := obstacle_size * 0.5
	canvas.draw_colored_polygon(
		PackedVector2Array([
			Vector2(-half.x + 5.0, half.y + 3.0),
			Vector2(half.x + 5.0, half.y + 3.0),
			Vector2(half.x + 16.0, half.y + 12.0),
			Vector2(-half.x + 16.0, half.y + 12.0)
		]),
		Color(0.02, 0.025, 0.02, 0.34)
	)

static func draw_perimeter_wall(
	canvas: CanvasItem,
	obstacle_size: Vector2,
	primary_color: Color,
	accent_color: Color,
	draw_mode: StringName,
	wall_height: float
) -> void:
	if obstacle_size.x >= obstacle_size.y:
		_draw_horizontal_wall(
			canvas,
			obstacle_size,
			primary_color,
			accent_color,
			draw_mode,
			wall_height
		)
	else:
		_draw_vertical_wall(
			canvas,
			obstacle_size,
			primary_color,
			accent_color,
			draw_mode,
			wall_height
		)

static func draw_boundary(
	canvas: CanvasItem,
	obstacle_size: Vector2,
	primary_color: Color,
	accent_color: Color
) -> void:
	var half_size := obstacle_size * 0.5
	canvas.draw_rect(Rect2(-half_size, obstacle_size), primary_color.darkened(0.38), true)
	for index in range(7):
		var ratio := float(index) / 6.0
		var x_position := lerpf(-half_size.x, half_size.x, ratio)
		canvas.draw_line(
			Vector2(x_position, -half_size.y),
			Vector2(x_position, half_size.y),
			Color(accent_color, 0.52),
			3.0,
			true
		)
	canvas.draw_line(
		Vector2(-half_size.x, 0.0),
		Vector2(half_size.x, 0.0),
		accent_color,
		5.0,
		true
	)

static func draw_toxic_boundary_wall(
	canvas: CanvasItem,
	obstacle_size: Vector2,
	primary_color: Color,
	accent_color: Color
) -> void:
	var half_size := obstacle_size * 0.5
	canvas.draw_rect(Rect2(-half_size, obstacle_size), primary_color.darkened(0.42), true)
	for index in range(8):
		var ratio := float(index) / 7.0
		var x_position := lerpf(-half_size.x, half_size.x, ratio)
		var stripe_color := accent_color if index % 2 == 0 else primary_color.lightened(0.18)
		canvas.draw_line(
			Vector2(x_position - 10.0, half_size.y),
			Vector2(x_position + 10.0, -half_size.y),
			Color(stripe_color, 0.62),
			4.0,
			true
		)
	canvas.draw_line(
		Vector2(-half_size.x, -half_size.y * 0.42),
		Vector2(half_size.x, -half_size.y * 0.18),
		accent_color.lightened(0.12),
		4.0,
		true
	)
	for index in range(4):
		var x_position := lerpf(-half_size.x * 0.68, half_size.x * 0.68, float(index) / 3.0)
		canvas.draw_circle(
			Vector2(x_position, half_size.y * 0.18),
			maxf(half_size.y * 0.18, 3.0),
			Color(accent_color.lightened(0.20), 0.58)
		)

static func draw_lava_boundary(
	canvas: CanvasItem,
	obstacle_size: Vector2,
	primary_color: Color,
	accent_color: Color
) -> void:
	var half_size := obstacle_size * 0.5
	canvas.draw_rect(Rect2(-half_size, obstacle_size), primary_color.darkened(0.50), true)
	var crack_points := PackedVector2Array()
	for index in range(7):
		var ratio := float(index) / 6.0
		crack_points.append(Vector2(
			lerpf(-half_size.x + 4.0, half_size.x - 4.0, ratio),
			sin(float(index) * 1.7) * half_size.y * 0.34
		))
	canvas.draw_polyline(crack_points, accent_color.lightened(0.20), 5.0, true)
	canvas.draw_polyline(crack_points, Color(1.0, 0.18, 0.04, 0.78), 2.0, true)
	for index in range(5):
		var x_position := lerpf(-half_size.x * 0.78, half_size.x * 0.78, float(index) / 4.0)
		canvas.draw_colored_polygon(
			PackedVector2Array([
				Vector2(x_position - 5.0, half_size.y * 0.36),
				Vector2(x_position + 5.0, half_size.y * 0.36),
				Vector2(x_position, -half_size.y * 0.52)
			]),
			primary_color.darkened(0.18)
		)

static func draw_ice_boundary(
	canvas: CanvasItem,
	obstacle_size: Vector2,
	primary_color: Color,
	accent_color: Color
) -> void:
	var half_size := obstacle_size * 0.5
	canvas.draw_rect(Rect2(-half_size, obstacle_size), primary_color.darkened(0.16), true)
	for index in range(6):
		var ratio := float(index) / 5.0
		var x_position := lerpf(-half_size.x, half_size.x, ratio)
		canvas.draw_colored_polygon(
			PackedVector2Array([
				Vector2(x_position - 8.0, half_size.y * 0.44),
				Vector2(x_position + 8.0, half_size.y * 0.38),
				Vector2(x_position + 3.0, -half_size.y),
				Vector2(x_position - 5.0, -half_size.y * 0.54)
			]),
			primary_color.lightened(0.24)
		)
	canvas.draw_line(
		Vector2(-half_size.x + 6.0, -half_size.y * 0.36),
		Vector2(half_size.x - 6.0, half_size.y * 0.10),
		accent_color.lightened(0.16),
		3.0,
		true
	)

static func draw_deep_water_boundary(
	canvas: CanvasItem,
	obstacle_size: Vector2,
	primary_color: Color,
	accent_color: Color
) -> void:
	var half_size := obstacle_size * 0.5
	canvas.draw_rect(Rect2(-half_size, obstacle_size), primary_color.darkened(0.34), true)
	for index in range(4):
		var y_position := lerpf(-half_size.y * 0.42, half_size.y * 0.42, float(index) / 3.0)
		var wave_points := PackedVector2Array()
		for point_index in range(9):
			var ratio := float(point_index) / 8.0
			var x_position := lerpf(-half_size.x + 4.0, half_size.x - 4.0, ratio)
			wave_points.append(Vector2(
				x_position,
				y_position + sin(ratio * TAU * 2.0 + float(index)) * 3.0
			))
		canvas.draw_polyline(wave_points, Color(accent_color.lightened(0.10), 0.72), 2.0, true)
	for index in range(5):
		var x_position := lerpf(-half_size.x * 0.78, half_size.x * 0.78, float(index) / 4.0)
		canvas.draw_line(
			Vector2(x_position, half_size.y * 0.48),
			Vector2(x_position + sin(float(index)) * 3.0, -half_size.y * 0.65),
			primary_color.lightened(0.16),
			3.0,
			true
		)

static func _draw_horizontal_wall(
	canvas: CanvasItem,
	obstacle_size: Vector2,
	primary_color: Color,
	accent_color: Color,
	draw_mode: StringName,
	wall_height: float
) -> void:
	var half := obstacle_size * 0.5
	var up := Vector2(0.0, -wall_height)

	var bl := Vector2(-half.x, half.y)
	var br := Vector2(half.x, half.y)
	var tr := Vector2(half.x, -half.y)
	var tl := Vector2(-half.x, -half.y)
	var bl_top := bl + up
	var br_top := br + up
	var tr_top := tr + up
	var tl_top := tl + up

	var top_color := primary_color.lightened(0.18)
	var near_color := primary_color.darkened(0.08)
	var side_color := primary_color.darkened(0.30)

	canvas.draw_colored_polygon(
		PackedVector2Array([
			bl + Vector2(6.0, 4.0),
			br + Vector2(6.0, 4.0),
			br + Vector2(18.0, 13.0),
			bl + Vector2(18.0, 13.0)
		]),
		Color(0.02, 0.03, 0.04, 0.34)
	)
	canvas.draw_colored_polygon(PackedVector2Array([tl, bl, bl_top, tl_top]), side_color)
	canvas.draw_colored_polygon(
		PackedVector2Array([tr, br, br_top, tr_top]),
		side_color.darkened(0.06)
	)
	canvas.draw_colored_polygon(PackedVector2Array([bl, br, br_top, bl_top]), near_color)
	canvas.draw_colored_polygon(
		PackedVector2Array([tl_top, tr_top, br_top, bl_top]),
		top_color
	)
	canvas.draw_line(tl_top, tr_top, accent_color, 2.0, true)
	canvas.draw_line(bl_top, br_top, accent_color.darkened(0.10), 2.0, true)

	_draw_wall_grooves(canvas, bl, br, up, accent_color)
	_draw_wall_style_accent(canvas, bl, br, up, accent_color, draw_mode)

static func _draw_vertical_wall(
	canvas: CanvasItem,
	obstacle_size: Vector2,
	primary_color: Color,
	accent_color: Color,
	draw_mode: StringName,
	wall_height: float
) -> void:
	var half := obstacle_size * 0.5
	var lift := Vector2(0.0, -wall_height)
	var crown_inset := minf(wall_height * 0.18, obstacle_size.x * 0.22)

	var bl := Vector2(-half.x, half.y)
	var br := Vector2(half.x, half.y)
	var tr := Vector2(half.x, -half.y)
	var tl := Vector2(-half.x, -half.y)
	# The footprint and crown both remain axis-aligned rectangles. A small
	# symmetric inset exposes west/east faces without shearing the entire wall;
	# the south face carries the apparent height.
	var top_bl := bl + lift + Vector2(crown_inset, 0.0)
	var top_br := br + lift + Vector2(-crown_inset, 0.0)
	var top_tr := tr + lift + Vector2(-crown_inset, 0.0)
	var top_tl := tl + lift + Vector2(crown_inset, 0.0)

	var top_color := primary_color.lightened(0.18)
	var near_color := primary_color.darkened(0.04)
	var base_color := primary_color.darkened(0.34)

	canvas.draw_colored_polygon(
		PackedVector2Array([
			tl + Vector2(5.0, 5.0),
			tr + Vector2(5.0, 5.0),
			br + Vector2(11.0, 11.0),
			bl + Vector2(11.0, 11.0)
		]),
		Color(0.02, 0.03, 0.04, 0.30)
	)
	canvas.draw_colored_polygon(PackedVector2Array([tl, tr, br, bl]), base_color)
	canvas.draw_colored_polygon(
		PackedVector2Array([bl, br, top_br, top_bl]),
		base_color.darkened(0.04)
	)
	canvas.draw_colored_polygon(
		PackedVector2Array([tl, bl, top_bl, top_tl]),
		near_color
	)
	canvas.draw_colored_polygon(
		PackedVector2Array([br, tr, top_tr, top_br]),
		base_color.darkened(0.14)
	)
	canvas.draw_colored_polygon(
		PackedVector2Array([top_tl, top_tr, top_br, top_bl]),
		top_color
	)
	canvas.draw_line(top_bl, top_br, accent_color, 2.0, true)
	canvas.draw_line(top_tl, top_tr, accent_color.darkened(0.10), 1.5, true)

	var course := accent_color.darkened(0.40)
	for depth in [0.34, 0.68]:
		canvas.draw_line(bl + lift * depth, br + lift * depth, course, 1.0, true)
	_draw_wall_grooves(canvas, bl, br, lift, accent_color)
	_draw_wall_style_accent(canvas, bl, br, lift, accent_color, draw_mode)

static func _draw_wall_grooves(
	canvas: CanvasItem,
	face_a: Vector2,
	face_b: Vector2,
	lift: Vector2,
	accent_color: Color
) -> void:
	var groove := accent_color.darkened(0.32)
	var run := face_a.distance_to(face_b)
	var count := maxi(2, int(run / 28.0))
	for index in range(1, count):
		var base := face_a.lerp(face_b, float(index) / float(count))
		canvas.draw_line(base, base + lift, groove, 1.5, true)

static func _draw_wall_style_accent(
	canvas: CanvasItem,
	face_a: Vector2,
	face_b: Vector2,
	lift: Vector2,
	accent_color: Color,
	draw_mode: StringName
) -> void:
	var mid_a := face_a + lift * 0.42
	var mid_b := face_b + lift * 0.42
	match draw_mode:
		&"forest_mountain_wall":
			canvas.draw_line(mid_a, mid_b, Color(0.34, 0.50, 0.23, 0.62), 2.2, true)
			canvas.draw_line(
				face_a + lift * 0.72,
				face_b + lift * 0.72,
				Color(accent_color.lightened(0.10), 0.48),
				1.6,
				true
			)
			for ratio in [0.18, 0.42, 0.66, 0.84]:
				var root_base := face_a.lerp(face_b, ratio)
				canvas.draw_line(
					root_base + lift * 0.18,
					root_base + lift * 0.48 + Vector2(4.0, 3.0),
					Color(0.18, 0.10, 0.045, 0.46),
					1.6,
					true
				)
		&"lava_boundary":
			canvas.draw_line(mid_a, mid_b, Color(0.98, 0.32, 0.10, 0.82), 2.5, true)
			canvas.draw_line(
				face_a + lift * 0.7,
				face_b + lift * 0.7,
				Color(1.0, 0.55, 0.18, 0.55),
				1.5,
				true
			)
		&"ice_boundary":
			canvas.draw_line(face_a + lift, face_b + lift, Color(0.62, 0.86, 0.98, 0.7), 2.0, true)
			canvas.draw_line(mid_a, mid_b, Color(0.74, 0.90, 1.0, 0.45), 1.5, true)
		&"toxic_boundary_wall":
			canvas.draw_line(mid_a, mid_b, Color(0.44, 0.92, 0.52, 0.6), 2.0, true)
		&"deep_water_boundary":
			canvas.draw_line(
				face_a + lift * 0.18,
				face_b + lift * 0.18,
				Color(0.34, 0.66, 0.78, 0.6),
				2.0,
				true
			)
		_:
			canvas.draw_line(mid_a, mid_b, accent_color.darkened(0.12), 1.5, true)
