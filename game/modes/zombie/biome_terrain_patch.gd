extends Node2D
class_name BiomeTerrainPatch

var terrain_tag: StringName = &"dirt"
var patch_radius: float = 34.0
var primary_color: Color = Color(0.18, 0.20, 0.13, 0.72)
var accent_color: Color = Color(0.42, 0.46, 0.28, 0.52)
var visual_seed: int = 0

func configure(
	tag: StringName,
	radius: float,
	base_color: Color,
	detail_color: Color,
	seed_value: int
) -> void:
	terrain_tag = tag
	patch_radius = maxf(radius, 8.0)
	primary_color = base_color
	accent_color = detail_color
	visual_seed = seed_value
	z_index = -6
	queue_redraw()

func _draw() -> void:
	match terrain_tag:
		&"dry_grass":
			_draw_dry_grass()
		&"broken_fence":
			_draw_debris()
		&"chemical_puddle", &"shallow_water", &"ice":
			_draw_pool()
		&"corrupted_plants", &"reeds", &"deep_snow":
			_draw_growth()
		&"hot_crack":
			_draw_crack()
		&"ash", &"burned_ground", &"snow", &"mud", &"toxic_soil":
			_draw_dirt()
		&"broken_bridge":
			_draw_debris()
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
