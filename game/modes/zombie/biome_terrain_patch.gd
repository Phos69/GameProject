extends Node2D
class_name BiomeTerrainPatch

var terrain_tag: StringName = &"dirt"
var terrain_category: StringName = &"terrain"
var draw_mode: StringName = &"dirt"
var patch_radius: float = 34.0
var primary_color: Color = Color(0.18, 0.20, 0.13, 0.72)
var accent_color: Color = Color(0.42, 0.46, 0.28, 0.52)
var visual_seed: int = 0

func configure(
	tag: StringName,
	radius: float,
	base_color: Color,
	detail_color: Color,
	seed_value: int,
	style: Dictionary = {}
) -> void:
	terrain_tag = tag
	terrain_category = StringName(style.get("category", &"terrain"))
	draw_mode = StringName(style.get("draw_mode", _default_draw_mode_for_tag(tag)))
	patch_radius = maxf(radius, 8.0)
	primary_color = base_color
	accent_color = detail_color
	visual_seed = seed_value
	z_index = -6
	queue_redraw()

func get_draw_mode() -> StringName:
	return draw_mode

func _draw() -> void:
	match draw_mode:
		&"main_road":
			_draw_main_road()
		&"road":
			_draw_road()
		&"broken_street":
			_draw_broken_street()
		&"service_lane":
			_draw_service_lane()
		&"ash_lane":
			_draw_ash_lane()
		&"burned_road":
			_draw_burned_road()
		&"snow_path":
			_draw_snow_path()
		&"wooden_walkway":
			_draw_wooden_walkway()
		&"bridge_path":
			_draw_bridge_path()
		&"broken_gate":
			_draw_broken_gate()
		&"dry_grass":
			_draw_dry_grass()
		&"debris":
			_draw_debris()
		&"pool":
			_draw_pool()
		&"growth":
			_draw_growth()
		&"crack":
			_draw_crack()
		_:
			_draw_dirt()

func _draw_dry_grass() -> void:
	draw_colored_polygon(
		_ellipse_points(Vector2(patch_radius * 1.4, patch_radius * 0.58)),
		Color(primary_color, primary_color.a * 0.42)
	)
	for index in range(7):
		var offset := _sample_offset(index)
		var height := 7.0 + float((visual_seed + index * 5) % 8)
		draw_line(
			offset + Vector2(0.0, 3.0),
			offset + Vector2(float((index % 3) - 1) * 3.0, -height),
			Color(accent_color, 0.54),
			1.5,
			true
		)

func _draw_dirt() -> void:
	draw_colored_polygon(
		_ellipse_points(Vector2(patch_radius * 1.55, patch_radius * 0.64)),
		Color(primary_color.darkened(0.12), 0.46)
	)
	for index in range(4):
		var offset := _sample_offset(index)
		draw_line(
			offset + Vector2(-8.0, -1.0),
			offset + Vector2(7.0, 2.0),
			Color(accent_color.darkened(0.18), 0.34),
			1.2,
			true
		)

func _draw_debris() -> void:
	draw_colored_polygon(
		_ellipse_points(Vector2(patch_radius * 1.3, patch_radius * 0.5)),
		Color(primary_color.darkened(0.18), 0.38)
	)
	for index in range(3):
		var offset := _sample_offset(index)
		var direction := Vector2.RIGHT.rotated(
			float((visual_seed + index * 37) % 100) * 0.025
		)
		draw_line(
			offset - direction * 12.0,
			offset + direction * 12.0,
			Color(accent_color.darkened(0.28), 0.62),
			3.0,
			true
		)

func _draw_pool() -> void:
	draw_colored_polygon(
		_ellipse_points(Vector2(patch_radius * 1.45, patch_radius * 0.58)),
		Color(accent_color, 0.30)
	)
	for index in range(3):
		draw_arc(
			_sample_offset(index) * 0.35,
			patch_radius * (0.12 + float(index) * 0.05),
			0.0,
			TAU,
			18,
			Color(accent_color.lightened(0.18), 0.44),
			1.5,
			true
		)

func _draw_growth() -> void:
	draw_colored_polygon(
		_ellipse_points(Vector2(patch_radius * 1.30, patch_radius * 0.50)),
		Color(primary_color.darkened(0.08), 0.34)
	)
	for index in range(8):
		var offset := _sample_offset(index)
		var bend := float((index % 3) - 1) * 5.0
		draw_line(
			offset + Vector2(0.0, 5.0),
			offset + Vector2(bend, -12.0 - float(index % 4) * 3.0),
			Color(accent_color, 0.58),
			2.0,
			true
		)

func _draw_crack() -> void:
	draw_colored_polygon(
		_ellipse_points(Vector2(patch_radius * 1.42, patch_radius * 0.54)),
		Color(primary_color.darkened(0.22), 0.40)
	)
	var points := PackedVector2Array([
		Vector2(-patch_radius, -4.0),
		Vector2(-patch_radius * 0.52, 5.0),
		Vector2(-patch_radius * 0.14, -3.0),
		Vector2(patch_radius * 0.30, 6.0),
		Vector2(patch_radius, -2.0)
	])
	draw_polyline(points, Color(accent_color.lightened(0.28), 0.78), 4.0, true)
	draw_polyline(points, Color(primary_color.darkened(0.45), 0.82), 1.5, true)

func _draw_main_road() -> void:
	_draw_path_base(
		Color(primary_color.darkened(0.30), 0.58),
		Color(accent_color.lightened(0.08), 0.36),
		1.95,
		0.42
	)
	for index in range(-2, 3):
		var x := float(index) * patch_radius * 0.34
		draw_line(
			Vector2(x - 8.0, -2.0),
			Vector2(x + 8.0, 2.0),
			Color(accent_color.lightened(0.36), 0.46),
			2.0,
			true
		)
	_draw_side_lines(Color(accent_color.darkened(0.12), 0.32))

func _draw_road() -> void:
	_draw_path_base(
		Color(primary_color.darkened(0.12), 0.50),
		Color(accent_color.darkened(0.12), 0.30),
		1.65,
		0.36
	)
	for index in range(4):
		var offset := _sample_offset(index) * Vector2(1.0, 0.35)
		draw_circle(offset, 1.8, Color(accent_color.darkened(0.20), 0.42))

func _draw_broken_street() -> void:
	_draw_path_base(
		Color(primary_color.darkened(0.34), 0.56),
		Color(accent_color.lightened(0.04), 0.28),
		1.70,
		0.38
	)
	for index in range(4):
		var offset := _sample_offset(index) * Vector2(1.0, 0.28)
		var crack := PackedVector2Array([
			offset + Vector2(-10.0, -2.0),
			offset + Vector2(-2.0, 3.0),
			offset + Vector2(7.0, -1.0)
		])
		draw_polyline(crack, Color(accent_color.lightened(0.20), 0.44), 1.4, true)
		draw_polyline(crack, Color(primary_color.darkened(0.48), 0.56), 0.8, true)

func _draw_service_lane() -> void:
	_draw_path_base(
		Color(primary_color.darkened(0.24), 0.54),
		Color(accent_color.lightened(0.10), 0.34),
		1.58,
		0.34
	)
	for index in range(-3, 4):
		var x := float(index) * patch_radius * 0.24
		var stripe_color := Color(0.86, 0.72, 0.18, 0.48)
		draw_line(
			Vector2(x - 5.0, 8.0),
			Vector2(x + 5.0, -8.0),
			stripe_color,
			2.0,
			true
		)

func _draw_ash_lane() -> void:
	_draw_path_base(
		Color(primary_color.darkened(0.40), 0.56),
		Color(accent_color.darkened(0.18), 0.30),
		1.66,
		0.36
	)
	_draw_heat_cracks(Color(1.0, 0.36, 0.12, 0.42), 3)

func _draw_burned_road() -> void:
	_draw_path_base(
		Color(primary_color.darkened(0.48), 0.60),
		Color(accent_color.darkened(0.24), 0.34),
		1.82,
		0.40
	)
	_draw_heat_cracks(Color(1.0, 0.28, 0.08, 0.58), 5)

func _draw_snow_path() -> void:
	_draw_path_base(
		Color(primary_color.lightened(0.30), 0.48),
		Color(accent_color.lightened(0.45), 0.40),
		1.70,
		0.38
	)
	for index in range(5):
		var offset := _sample_offset(index) * Vector2(0.9, 0.25)
		draw_line(
			offset + Vector2(-8.0, -1.0),
			offset + Vector2(8.0, 2.0),
			Color(accent_color.lightened(0.55), 0.36),
			1.3,
			true
		)

func _draw_wooden_walkway() -> void:
	_draw_planked_path(
		Color(0.30, 0.22, 0.12, 0.60),
		Color(0.66, 0.48, 0.25, 0.58),
		1.56,
		0.34
	)

func _draw_bridge_path() -> void:
	_draw_path_base(
		Color(primary_color.darkened(0.34), 0.30),
		Color(accent_color.lightened(0.18), 0.22),
		1.82,
		0.44
	)
	_draw_planked_path(
		Color(0.26, 0.18, 0.10, 0.64),
		Color(0.68, 0.48, 0.24, 0.62),
		1.58,
		0.30
	)

func _draw_broken_gate() -> void:
	_draw_path_base(
		Color(primary_color.darkened(0.26), 0.54),
		Color(accent_color.lightened(0.05), 0.32),
		1.58,
		0.36
	)
	for side in [-1.0, 1.0]:
		var post_x: float = float(side) * patch_radius * 0.55
		draw_rect(
			Rect2(Vector2(post_x - 4.0, -16.0), Vector2(8.0, 32.0)),
			Color(accent_color.darkened(0.24), 0.56)
		)
	for index in range(3):
		var x := -patch_radius * 0.32 + float(index) * patch_radius * 0.32
		draw_line(
			Vector2(x - 8.0, -10.0),
			Vector2(x + 8.0, 10.0),
			Color(0.90, 0.72, 0.18, 0.46),
			2.0,
			true
		)

func _draw_path_base(
	fill_color: Color,
	outline_color: Color,
	length_scale: float,
	height_scale: float
) -> void:
	var points := _ellipse_points(Vector2(
		patch_radius * length_scale,
		patch_radius * height_scale
	))
	draw_colored_polygon(points, fill_color)
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, outline_color, 1.2, true)

func _draw_side_lines(color: Color) -> void:
	for y in [-patch_radius * 0.21, patch_radius * 0.21]:
		draw_line(
			Vector2(-patch_radius * 1.32, y),
			Vector2(patch_radius * 1.32, y),
			color,
			1.0,
			true
		)

func _draw_heat_cracks(color: Color, count: int) -> void:
	for index in range(count):
		var offset := _sample_offset(index) * Vector2(1.0, 0.22)
		var points := PackedVector2Array([
			offset + Vector2(-patch_radius * 0.28, -2.0),
			offset + Vector2(-patch_radius * 0.08, 4.0),
			offset + Vector2(patch_radius * 0.12, -3.0),
			offset + Vector2(patch_radius * 0.30, 2.0)
		])
		draw_polyline(points, color, 2.2, true)
		draw_polyline(points, Color(primary_color.darkened(0.55), 0.58), 0.9, true)

func _draw_planked_path(
	fill_color: Color,
	line_color: Color,
	length_scale: float,
	height_scale: float
) -> void:
	_draw_path_base(
		fill_color,
		Color(line_color.darkened(0.35), 0.36),
		length_scale,
		height_scale
	)
	var start_x := -patch_radius * length_scale * 0.55
	var end_x := patch_radius * length_scale * 0.55
	for index in range(6):
		var x := lerpf(start_x, end_x, float(index) / 5.0)
		draw_line(
			Vector2(x, -patch_radius * height_scale * 0.92),
			Vector2(x, patch_radius * height_scale * 0.92),
			line_color,
			1.5,
			true
		)
	draw_line(
		Vector2(start_x, 0.0),
		Vector2(end_x, 0.0),
		Color(line_color.lightened(0.15), 0.42),
		1.2,
		true
	)

func _default_draw_mode_for_tag(tag: StringName) -> StringName:
	match tag:
		&"dry_grass":
			return &"dry_grass"
		&"broken_fence", &"broken_bridge":
			return &"debris"
		&"chemical_puddle", &"shallow_water", &"ice":
			return &"pool"
		&"corrupted_plants", &"reeds", &"deep_snow":
			return &"growth"
		&"hot_crack":
			return &"crack"
		_:
			return &"dirt"

func _sample_offset(index: int) -> Vector2:
	var angle := float((visual_seed * 31 + index * 79) % 360) * PI / 180.0
	var distance := patch_radius * (
		0.18 + float((visual_seed + index * 17) % 55) / 100.0
	)
	return Vector2.RIGHT.rotated(angle) * distance

func _ellipse_points(size: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(18):
		var angle := TAU * float(index) / 18.0
		points.append(Vector2(cos(angle) * size.x, sin(angle) * size.y))
	return points
