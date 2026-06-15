extends Node2D
class_name SpawnGateVisual

var accent_color: Color = Color(0.30, 0.82, 0.72, 1.0)
var gate_index: int = 0
var pulse_timer: float = 0.0
var pulse_duration: float = 0.45
var animation_time: float = 0.0
var glow_intensity: float = 1.0
var high_contrast: bool = false
var reduced_motion: bool = false

func _ready() -> void:
	add_to_group("visual_settings_consumers")
	VisualSettingsManager.sync_consumer(self)

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

func configure(color: Color, index: int, inward_direction: Vector2) -> void:
	accent_color = color
	gate_index = index
	rotation = inward_direction.angle()
	queue_redraw()

func play_spawn_pulse() -> void:
	pulse_timer = pulse_duration
	queue_redraw()

func _process(delta: float) -> void:
	if not reduced_motion:
		animation_time += delta
	pulse_timer = maxf(pulse_timer - delta, 0.0)
	queue_redraw()

func _draw() -> void:
	var idle_pulse := 0.5 + sin(animation_time * 2.4 + float(gate_index)) * 0.12
	var spawn_ratio := pulse_timer / pulse_duration if pulse_duration > 0.0 else 0.0
	var alpha := clampf(idle_pulse + spawn_ratio * 0.45, 0.0, 1.0)
	var display_color := Color.WHITE if high_contrast else accent_color
	var color := Color(
		display_color,
		display_color.a * alpha * maxf(glow_intensity, 0.25)
	)
	var dim_color := Color(accent_color, accent_color.a * 0.18)
	draw_arc(Vector2.ZERO, 29.0 + spawn_ratio * 7.0, -1.05, 1.05, 20, color, 4.0, true)
	draw_line(Vector2(-2.0, -25.0), Vector2(-2.0, 25.0), color, 3.0, true)
	draw_line(Vector2(-8.0, -31.0), Vector2(-8.0, 31.0), dim_color, 7.0, true)
	for index in range(3):
		var x := 8.0 + float(index) * 10.0
		draw_colored_polygon(
			PackedVector2Array([
				Vector2(x + 8.0, 0.0),
				Vector2(x, -6.0),
				Vector2(x, 6.0)
			]),
			Color(accent_color, accent_color.a * (0.34 + spawn_ratio * 0.5))
		)
