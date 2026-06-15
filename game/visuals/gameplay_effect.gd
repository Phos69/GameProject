extends Node2D
class_name GameplayEffect

var effect_kind: StringName = &"hit"
var effect_color: Color = Color.WHITE
var effect_size: float = 18.0
var duration: float = 0.25
var age: float = 0.0
var opacity_scale: float = 1.0
var reduced_motion: bool = false

func configure(
	kind: StringName,
	color: Color,
	size: float,
	lifetime: float,
	angle: float = 0.0,
	intensity: float = 1.0,
	motion_reduced: bool = false
) -> void:
	effect_kind = kind
	effect_color = color
	effect_size = size
	duration = maxf(lifetime, 0.01)
	rotation = angle
	opacity_scale = clampf(intensity, 0.0, 1.0)
	reduced_motion = motion_reduced

func _process(delta: float) -> void:
	age += delta
	if age >= duration:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var ratio := clampf(age / duration, 0.0, 1.0)
	var alpha := 1.0 - ratio
	var motion_ratio := ratio * (0.18 if reduced_motion else 1.0)
	var color := Color(
		effect_color,
		effect_color.a * alpha * opacity_scale
	)
	match effect_kind:
		&"muzzle":
			var length := effect_size * (1.0 - motion_ratio * 0.45)
			draw_colored_polygon(
				PackedVector2Array([
					Vector2(length, 0.0),
					Vector2(0.0, -effect_size * 0.34 * alpha),
					Vector2(0.0, effect_size * 0.34 * alpha)
				]),
				color
			)
		&"death":
			draw_arc(
				Vector2.ZERO,
				effect_size * (0.35 + motion_ratio),
				0.0,
				TAU,
				28,
				color,
				3.0,
				true
			)
			for index in range(8):
				var direction := Vector2.RIGHT.rotated(TAU * float(index) / 8.0)
				var start := direction * effect_size * motion_ratio * 0.45
				var finish := direction * effect_size * (
					0.55 + motion_ratio * 0.75
				)
				draw_line(start, finish, color, 3.0, true)
		&"boss_death":
			for ring_index in range(3):
				var ring_ratio := clampf(
					ratio - float(ring_index) * 0.10,
					0.0,
					1.0
				)
				draw_arc(
					Vector2.ZERO,
					effect_size * (
						0.28 + ring_ratio * (0.20 if reduced_motion else 1.05)
					),
					0.0,
					TAU,
					40,
					Color(color, alpha * (1.0 - float(ring_index) * 0.22)),
					5.0,
					true
				)
			for index in range(12):
				var direction := Vector2.RIGHT.rotated(
					TAU * float(index) / 12.0 + ratio * 0.35
				)
				var side := direction.orthogonal()
				var center := direction * effect_size * (
					0.30 + motion_ratio * 0.92
				)
				draw_colored_polygon(
					PackedVector2Array([
						center + direction * 10.0,
						center - direction * 8.0 + side * 5.0,
						center - direction * 8.0 - side * 5.0
					]),
					Color(color, alpha)
				)
			draw_circle(
				Vector2.ZERO,
				effect_size * 0.22 * alpha,
				Color(1.0, 0.78, 0.28, alpha)
			)
		&"environment_explosion":
			draw_circle(
				Vector2.ZERO,
				effect_size * (0.12 + motion_ratio * 0.88),
				Color(color, alpha * 0.12)
			)
			for ring_index in range(2):
				draw_arc(
					Vector2.ZERO,
					effect_size * (
						0.24
						+ motion_ratio * (
							0.76 + float(ring_index) * 0.16
						)
					),
					0.0,
					TAU,
					48,
					Color(color, alpha * (1.0 - float(ring_index) * 0.35)),
					5.0,
					true
				)
			for index in range(10):
				var direction := Vector2.RIGHT.rotated(
					TAU * float(index) / 10.0
				)
				draw_line(
					direction * effect_size * motion_ratio * 0.25,
					direction * effect_size * (
						0.38 + motion_ratio * 0.68
					),
					Color(color, alpha),
					4.0,
					true
				)
		&"pickup":
			draw_arc(
				Vector2.ZERO,
				effect_size * (0.4 + motion_ratio * 0.8),
				0.0,
				TAU,
				24,
				color,
				2.5,
				true
			)
			draw_line(Vector2(0.0, 7.0), Vector2(0.0, -effect_size * alpha), color, 3.0, true)
		_:
			for index in range(5):
				var direction := Vector2.RIGHT.rotated(TAU * float(index) / 5.0)
				draw_line(
					direction * effect_size * motion_ratio * 0.25,
					direction * effect_size * (
						0.45 + motion_ratio * 0.55
					),
					color,
					3.0,
					true
				)
