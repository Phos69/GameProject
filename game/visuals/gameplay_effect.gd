extends Node2D
class_name GameplayEffect

var effect_kind: StringName = &"hit"
var effect_color: Color = Color.WHITE
var effect_size: float = 18.0
var duration: float = 0.25
var age: float = 0.0

func configure(
	kind: StringName,
	color: Color,
	size: float,
	lifetime: float,
	angle: float = 0.0
) -> void:
	effect_kind = kind
	effect_color = color
	effect_size = size
	duration = maxf(lifetime, 0.01)
	rotation = angle

func _process(delta: float) -> void:
	age += delta
	if age >= duration:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var ratio := clampf(age / duration, 0.0, 1.0)
	var alpha := 1.0 - ratio
	var color := Color(effect_color, effect_color.a * alpha)
	match effect_kind:
		&"muzzle":
			var length := effect_size * (1.0 - ratio * 0.45)
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
				effect_size * (0.35 + ratio),
				0.0,
				TAU,
				28,
				color,
				3.0,
				true
			)
			for index in range(8):
				var direction := Vector2.RIGHT.rotated(TAU * float(index) / 8.0)
				var start := direction * effect_size * ratio * 0.45
				var finish := direction * effect_size * (0.55 + ratio * 0.75)
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
					effect_size * (0.28 + ring_ratio * 1.05),
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
				var center := direction * effect_size * (0.30 + ratio * 0.92)
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
		&"pickup":
			draw_arc(
				Vector2.ZERO,
				effect_size * (0.4 + ratio * 0.8),
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
					direction * effect_size * ratio * 0.25,
					direction * effect_size * (0.45 + ratio * 0.55),
					color,
					3.0,
					true
				)
