extends PatternBossVisual
class_name RiftArchitectVisual

@export var armor_color: Color = Color(0.08, 0.42, 0.48, 1.0)
@export var phase_two_color: Color = Color(0.12, 0.72, 0.62, 1.0)
@export var core_color: Color = Color(1.0, 0.58, 0.18, 1.0)

func get_profile_id() -> StringName:
	return &"rift_architect"

func _draw() -> void:
	var phase_two := is_phase_two_visual()
	var body_color := phase_two_color if phase_two else armor_color
	var energy_color := (
		Color(0.30, 0.96, 1.0, 1.0)
		if phase_two
		else core_color
	)
	if hurt_timer > 0.0:
		body_color = body_color.lerp(Color.WHITE, flash_intensity)
		energy_color = energy_color.lerp(Color.WHITE, flash_intensity)
	energy_color = Color(
		energy_color,
		energy_color.a * maxf(glow_intensity, 0.25)
	)
	var hover := sin(animation_time * 2.6) * 3.0
	var rotation_phase := animation_time * (1.2 if phase_two else 0.65)
	draw_set_transform(Vector2(0.0, hover), 0.0, Vector2.ONE)
	draw_colored_polygon(
		GeometryUtils.ellipse_points(Vector2(0.0, 42.0), Vector2(54.0, 14.0), 24),
		Color(0.01, 0.02, 0.025, 0.54)
	)
	for index in range(4):
		var angle := rotation_phase + TAU * float(index) / 4.0
		var direction := Vector2.RIGHT.rotated(angle)
		var side := direction.orthogonal()
		var center := direction * 39.0
		draw_colored_polygon(
			PackedVector2Array([
				center + direction * 17.0,
				center + side * 13.0,
				center - direction * 14.0,
				center - side * 13.0
			]),
			Color(0.02, 0.07, 0.08, 1.0)
		)
		draw_colored_polygon(
			PackedVector2Array([
				center + direction * 13.0,
				center + side * 9.0,
				center - direction * 10.0,
				center - side * 9.0
			]),
			body_color
		)
		draw_line(
			center - side * 8.0,
			center + side * 8.0,
			Color(energy_color, 0.86),
			3.0,
			true
		)
	draw_colored_polygon(
		_regular_polygon(28.0, 4, PI * 0.25),
		Color(0.02, 0.08, 0.10, 1.0)
	)
	draw_colored_polygon(
		_regular_polygon(19.0, 4, PI * 0.25),
		Color(energy_color, 0.42)
	)
	draw_circle(Vector2.ZERO, 10.0, energy_color)
	draw_circle(Vector2.ZERO, 4.0, Color.WHITE)
	var marker := aim_direction * 35.0
	draw_line(
		marker - aim_direction.orthogonal() * 8.0,
		marker + aim_direction.orthogonal() * 8.0,
		Color(1.0, 0.72, 0.24, 1.0),
		5.0,
		true
	)
	if phase_two:
		for index in range(4):
			var direction := Vector2.RIGHT.rotated(
				rotation_phase * -1.4 + TAU * float(index) / 4.0
			)
			draw_line(
				direction * 55.0,
				direction * 72.0,
				Color(energy_color, 0.78),
				4.0,
				true
			)
	if not active_pattern.is_empty():
		var charge_color := (
			Color(0.30, 0.92, 1.0, 1.0)
			if active_pattern == &"cross_burst"
			else Color(0.28, 1.0, 0.68, 1.0)
		)
		draw_arc(
			Vector2.ZERO,
			35.0 + sin(animation_time * 13.0) * 4.0,
			0.0,
			TAU,
			32,
			charge_color,
			4.0,
			true
		)
	if spawn_timer > 0.0:
		var ratio := 1.0 - spawn_timer / 0.65
		draw_arc(
			Vector2.ZERO,
			82.0 - ratio * 28.0,
			0.0,
			TAU,
			40,
			Color(energy_color, 1.0 - ratio),
			5.0,
			true
		)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _regular_polygon(
	radius: float,
	sides: int,
	rotation_offset: float
) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(sides):
		points.append(
			Vector2.RIGHT.rotated(
				rotation_offset + TAU * float(index) / float(sides)
			) * radius
		)
	return points

