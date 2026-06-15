extends Node2D
class_name DropPickupVisual

var drop_type: StringName = &"unknown"
var accent_color: Color = Color(0.72, 0.76, 0.80, 1.0)
var animation_time: float = 0.0
var high_contrast: bool = false
var reduced_motion: bool = false

func _ready() -> void:
	add_to_group("visual_settings_consumers")
	VisualSettingsManager.sync_consumer(self)

func _process(delta: float) -> void:
	if not reduced_motion:
		animation_time += delta
	queue_redraw()

func apply_visual_settings(settings: Dictionary) -> void:
	high_contrast = bool(settings.get("high_contrast", false))
	reduced_motion = bool(settings.get("reduced_motion", false))
	if reduced_motion:
		animation_time = 0.0
	queue_redraw()

func configure(value: StringName) -> void:
	drop_type = value
	accent_color = _color_for_type(drop_type)
	queue_redraw()

func _draw() -> void:
	var bob := sin(animation_time * 4.0) * 2.5
	var pulse := 1.0 + sin(animation_time * 5.0) * 0.04
	draw_colored_polygon(
		_ellipse_points(Vector2(0.0, 13.0), Vector2(15.0, 5.0), 16),
		Color(0.01, 0.015, 0.02, 0.45)
	)
	draw_set_transform(Vector2(0.0, bob), 0.0, Vector2(pulse, pulse))
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(0.0, -17.0),
			Vector2(16.0, -4.0),
			Vector2(13.0, 13.0),
			Vector2(-13.0, 13.0),
			Vector2(-16.0, -4.0)
		]),
		Color(0.035, 0.05, 0.065, 0.98)
	)
	draw_polyline(
		PackedVector2Array([
			Vector2(0.0, -17.0),
			Vector2(16.0, -4.0),
			Vector2(13.0, 13.0),
			Vector2(-13.0, 13.0),
			Vector2(-16.0, -4.0),
			Vector2(0.0, -17.0)
		]),
		Color.WHITE if high_contrast else accent_color,
		3.5 if high_contrast else 2.5,
		true
	)
	_draw_icon()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_icon() -> void:
	match drop_type:
		GameConstants.DROP_EXPERIENCE:
			draw_colored_polygon(
				PackedVector2Array([
					Vector2(0.0, -11.0),
					Vector2(7.0, 0.0),
					Vector2(0.0, 10.0),
					Vector2(-7.0, 0.0)
				]),
				accent_color
			)
			draw_line(Vector2(-9.0, -5.0), Vector2(-4.0, -2.0), accent_color.lightened(0.3), 2.0)
			draw_line(Vector2(7.0, 5.0), Vector2(11.0, 2.0), accent_color.lightened(0.3), 2.0)
		GameConstants.DROP_MONEY:
			draw_circle(Vector2.ZERO, 9.0, accent_color.darkened(0.25))
			draw_arc(Vector2.ZERO, 7.0, 0.0, TAU, 20, accent_color, 2.0, true)
			draw_line(Vector2(-3.0, -4.0), Vector2(3.0, -4.0), accent_color.lightened(0.35), 2.0)
			draw_line(Vector2(-3.0, 0.0), Vector2(4.0, 0.0), accent_color.lightened(0.35), 2.0)
			draw_line(Vector2(-3.0, 4.0), Vector2(3.0, 4.0), accent_color.lightened(0.35), 2.0)
		GameConstants.DROP_AMMO:
			draw_rect(Rect2(-9.0, -8.0, 18.0, 16.0), accent_color.darkened(0.25), true)
			for index in range(3):
				var x := -6.0 + float(index) * 6.0
				draw_line(Vector2(x, -6.0), Vector2(x, 4.0), accent_color.lightened(0.25), 3.0, true)
				draw_circle(Vector2(x, -6.0), 1.6, accent_color.lightened(0.4))
		GameConstants.DROP_HEALTH:
			draw_rect(Rect2(-9.0, -7.0, 18.0, 14.0), accent_color.darkened(0.28), true)
			draw_rect(Rect2(-2.5, -9.0, 5.0, 18.0), Color.WHITE, true)
			draw_rect(Rect2(-8.0, -2.5, 16.0, 5.0), Color.WHITE, true)
		GameConstants.DROP_WEAPON:
			draw_line(Vector2(-10.0, 3.0), Vector2(8.0, -4.0), accent_color, 6.0, true)
			draw_line(Vector2(-1.0, 1.0), Vector2(2.0, 9.0), accent_color.darkened(0.25), 5.0, true)
			draw_circle(Vector2(10.0, -5.0), 2.5, accent_color.lightened(0.35))
		_:
			draw_circle(Vector2.ZERO, 7.0, accent_color)

func _color_for_type(value: StringName) -> Color:
	match value:
		GameConstants.DROP_EXPERIENCE:
			return Color(0.32, 0.72, 1.0, 1.0)
		GameConstants.DROP_MONEY:
			return Color(1.0, 0.76, 0.18, 1.0)
		GameConstants.DROP_AMMO:
			return Color(1.0, 0.42, 0.16, 1.0)
		GameConstants.DROP_HEALTH:
			return Color(0.30, 0.92, 0.48, 1.0)
		GameConstants.DROP_WEAPON:
			return Color(0.76, 0.38, 1.0, 1.0)
		_:
			return Color(0.72, 0.76, 0.80, 1.0)

func _ellipse_points(center: Vector2, radius: Vector2, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(segments):
		var angle := TAU * float(index) / float(segments)
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	return points
