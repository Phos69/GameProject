extends Node2D
class_name SupplyCrateVisual

var animation_time: float = 0.0
var glow_intensity: float = 1.0
var high_contrast: bool = false
var reduced_motion: bool = false
var crate_type: StringName = &"common"
var body_color: Color = Color(0.18, 0.58, 0.68, 1.0)
var accent_color: Color = Color(0.95, 0.66, 0.15, 1.0)

func _ready() -> void:
	add_to_group("visual_settings_consumers")
	VisualSettingsManager.sync_consumer(self)

func _process(delta: float) -> void:
	if not reduced_motion:
		animation_time += delta
	queue_redraw()

func apply_visual_settings(settings: Dictionary) -> void:
	glow_intensity = clampf(
		float(settings.get("glow_intensity", 1.0)),
		0.0,
		1.0
	)
	high_contrast = bool(settings.get("high_contrast", false))
	reduced_motion = bool(settings.get("reduced_motion", false))
	if reduced_motion:
		animation_time = 0.0
	queue_redraw()

func configure_crate_type(next_crate_type: StringName) -> void:
	crate_type = next_crate_type
	match crate_type:
		&"medical":
			body_color = Color(0.24, 0.68, 0.42, 1.0)
			accent_color = Color(0.92, 0.98, 0.94, 1.0)
		&"military":
			body_color = Color(0.35, 0.38, 0.24, 1.0)
			accent_color = Color(0.94, 0.72, 0.20, 1.0)
		&"biome_toxic":
			body_color = Color(0.20, 0.62, 0.26, 1.0)
			accent_color = Color(0.58, 1.0, 0.26, 1.0)
		&"biome_fire":
			body_color = Color(0.62, 0.24, 0.12, 1.0)
			accent_color = Color(1.0, 0.55, 0.12, 1.0)
		&"biome_frost":
			body_color = Color(0.28, 0.56, 0.68, 1.0)
			accent_color = Color(0.70, 0.94, 1.0, 1.0)
		&"biome_marsh":
			body_color = Color(0.18, 0.46, 0.40, 1.0)
			accent_color = Color(0.34, 0.82, 0.70, 1.0)
		_:
			body_color = Color(0.18, 0.58, 0.68, 1.0)
			accent_color = Color(0.95, 0.66, 0.15, 1.0)
	queue_redraw()

func _draw() -> void:
	var glow_alpha := (
		0.16 + (sin(animation_time * 3.0) + 1.0) * 0.05
	) * glow_intensity
	draw_colored_polygon(
		_ellipse_points(Vector2(0.0, 20.0), Vector2(29.0, 8.0), 18),
		Color(0.01, 0.015, 0.02, 0.52)
	)
	draw_circle(Vector2.ZERO, 31.0, Color(accent_color, glow_alpha))
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
	draw_rect(Rect2(-24.0, -11.0, 48.0, 23.0), body_color, true)
	draw_rect(
		Rect2(-24.0, -11.0, 48.0, 23.0),
		Color.WHITE if high_contrast else Color(0.55, 0.92, 1.0, 0.9),
		false,
		3.0 if high_contrast else 2.0
	)
	draw_rect(Rect2(-5.0, -11.0, 10.0, 23.0), accent_color, true)
	draw_rect(Rect2(-9.0, -2.0, 18.0, 8.0), Color(0.05, 0.08, 0.09, 1.0), true)
	if crate_type == &"medical":
		draw_rect(Rect2(-2.0, -7.0, 4.0, 18.0), accent_color, true)
		draw_rect(Rect2(-8.0, -2.0, 16.0, 6.0), accent_color, true)
	else:
		draw_colored_polygon(
			PackedVector2Array([
				Vector2(-7.0, 5.0),
				Vector2(0.0, -6.0),
				Vector2(7.0, 5.0)
			]),
			accent_color.lightened(0.18)
		)
	for x in [-20.0, 20.0]:
		draw_circle(Vector2(x, 9.0), 2.5, Color(0.04, 0.07, 0.08, 1.0))

func _ellipse_points(center: Vector2, radius: Vector2, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(segments):
		var angle := TAU * float(index) / float(segments)
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	return points
