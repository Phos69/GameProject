extends Node2D
class_name SupplyCrateVisual

var animation_time: float = 0.0

func _process(delta: float) -> void:
	animation_time += delta
	queue_redraw()

func _draw() -> void:
	var glow_alpha := 0.16 + (sin(animation_time * 3.0) + 1.0) * 0.05
	draw_colored_polygon(
		_ellipse_points(Vector2(0.0, 20.0), Vector2(29.0, 8.0), 18),
		Color(0.01, 0.015, 0.02, 0.52)
	)
	draw_circle(Vector2.ZERO, 31.0, Color(0.18, 0.75, 0.92, glow_alpha))
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(-27.0, -14.0),
			Vector2(21.0, -14.0),
			Vector2(27.0, -7.0),
			Vector2(27.0, 16.0),
			Vector2(-27.0, 16.0)
		]),
		Color(0.055, 0.10, 0.13, 1.0)
	)
	draw_rect(Rect2(-24.0, -11.0, 48.0, 23.0), Color(0.18, 0.58, 0.68, 1.0), true)
	draw_rect(Rect2(-24.0, -11.0, 48.0, 23.0), Color(0.55, 0.92, 1.0, 0.9), false, 2.0)
	draw_rect(Rect2(-5.0, -11.0, 10.0, 23.0), Color(0.95, 0.66, 0.15, 1.0), true)
	draw_rect(Rect2(-9.0, -2.0, 18.0, 8.0), Color(0.05, 0.08, 0.09, 1.0), true)
	draw_rect(Rect2(-2.0, -6.0, 4.0, 16.0), Color(0.86, 0.96, 0.98, 1.0), true)
	draw_rect(Rect2(-7.0, -1.0, 14.0, 5.0), Color(0.86, 0.96, 0.98, 1.0), true)
	for x in [-20.0, 20.0]:
		draw_circle(Vector2(x, 9.0), 2.5, Color(0.04, 0.07, 0.08, 1.0))

func _ellipse_points(center: Vector2, radius: Vector2, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(segments):
		var angle := TAU * float(index) / float(segments)
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	return points
