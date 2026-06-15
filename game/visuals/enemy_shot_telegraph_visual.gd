extends Node2D
class_name EnemyShotTelegraphVisual

@export var lane_length: float = 620.0
@export var lane_half_width: float = 15.0
@export var countdown_radius: float = 34.0
@export var warning_color: Color = Color(0.28, 0.94, 0.74, 1.0)

var warning_duration: float = 0.0
var time_remaining: float = 0.0
var high_contrast: bool = false
var reduced_motion: bool = false

func _ready() -> void:
	add_to_group("visual_settings_consumers")
	VisualSettingsManager.sync_consumer(self)
	hide()
	set_process(false)

func apply_visual_settings(settings: Dictionary) -> void:
	high_contrast = bool(settings.get("high_contrast", false))
	reduced_motion = bool(settings.get("reduced_motion", false))
	queue_redraw()

func begin_warning(direction: Vector2, duration: float) -> void:
	warning_duration = maxf(duration, 0.01)
	time_remaining = warning_duration
	rotation = direction.angle()
	show()
	set_process(true)
	queue_redraw()

func finish_warning() -> void:
	warning_duration = 0.0
	time_remaining = 0.0
	hide()
	set_process(false)
	queue_redraw()

func is_warning_active() -> bool:
	return time_remaining > 0.0

func get_progress_ratio() -> float:
	if warning_duration <= 0.0:
		return 1.0
	return clampf(1.0 - time_remaining / warning_duration, 0.0, 1.0)

func _process(delta: float) -> void:
	time_remaining = maxf(time_remaining - delta, 0.0)
	queue_redraw()

func _draw() -> void:
	if time_remaining <= 0.0:
		return
	var pulse := (
		0.84
		if reduced_motion
		else 0.72 + sin(Time.get_ticks_msec() * 0.026) * 0.18
	)
	var display_color := Color.WHITE if high_contrast else warning_color
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(24.0, -lane_half_width),
			Vector2(lane_length, -lane_half_width),
			Vector2(lane_length, lane_half_width),
			Vector2(24.0, lane_half_width)
		]),
		Color(display_color, 0.12 * pulse if high_contrast else 0.09 * pulse)
	)
	draw_line(
		Vector2(24.0, -lane_half_width),
		Vector2(lane_length, -lane_half_width),
		Color(display_color, 0.72 * pulse),
		3.5 if high_contrast else 2.0,
		true
	)
	draw_line(
		Vector2(24.0, lane_half_width),
		Vector2(lane_length, lane_half_width),
		Color(display_color, 0.72 * pulse),
		3.5 if high_contrast else 2.0,
		true
	)
	draw_line(
		Vector2(24.0, 0.0),
		Vector2(lane_length, 0.0),
		Color(display_color, 0.92 * pulse),
		4.5 if high_contrast else 3.0,
		true
	)
	draw_arc(
		Vector2.ZERO,
		countdown_radius,
		-PI * 0.5,
		-PI * 0.5 + TAU * get_progress_ratio(),
		24,
		Color(display_color, 0.96),
		5.0 if high_contrast else 4.0,
		true
	)
