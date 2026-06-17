extends Node2D
class_name ReviveIndicatorVisual

@export var radius: float = 31.0

var slot_color: Color = Color(0.18, 0.74, 0.95, 1.0)
var progress_ratio: float = 0.0
var is_downed: bool = false
var has_active_reviver: bool = false
var high_contrast: bool = false
var reduced_motion: bool = false

func _ready() -> void:
	add_to_group("visual_settings_consumers")
	_sync_visual_settings()
	hide()
	queue_redraw()

func apply_visual_settings(settings: Dictionary) -> void:
	high_contrast = bool(settings.get("high_contrast", false))
	reduced_motion = bool(settings.get("reduced_motion", false))
	queue_redraw()

func _sync_visual_settings() -> void:
	var manager := get_tree().get_first_node_in_group(
		"visual_settings_manager"
	)
	if manager != null and manager.has_method("get_settings_data"):
		apply_visual_settings(manager.get_settings_data())

func set_slot_color(color: Color) -> void:
	slot_color = color
	queue_redraw()

func set_downed(value: bool) -> void:
	is_downed = value
	if not value:
		progress_ratio = 0.0
		has_active_reviver = false
	visible = value
	queue_redraw()

func set_revive_progress(ratio: float, active: bool) -> void:
	progress_ratio = clampf(ratio, 0.0, 1.0)
	has_active_reviver = active
	queue_redraw()

func _process(_delta: float) -> void:
	if is_downed:
		queue_redraw()

func _draw() -> void:
	if not is_downed:
		return
	var pulse := (
		0.82
		if reduced_motion
		else 0.72 + sin(Time.get_ticks_msec() * 0.012) * 0.14
	)
	var ring_color := Color.WHITE if high_contrast else slot_color
	draw_circle(Vector2.ZERO, radius + 5.0, Color(0.01, 0.02, 0.025, 0.58))
	draw_arc(
		Vector2.ZERO,
		radius,
		0.0,
		TAU,
		36,
		Color(ring_color, 0.48 * pulse if high_contrast else 0.36 * pulse),
		5.0 if high_contrast else 4.0,
		true
	)
	if progress_ratio > 0.0:
		draw_arc(
			Vector2.ZERO,
			radius,
			-PI * 0.5,
			-PI * 0.5 + TAU * progress_ratio,
			36,
			Color.WHITE if high_contrast else slot_color.lightened(0.18),
			7.0 if high_contrast else 6.0,
			true
		)
	var cross_color := (
		Color(0.46, 1.0, 0.64, 1.0)
		if has_active_reviver
		else Color(slot_color, 0.86)
	)
	draw_rect(Rect2(-3.0, -13.0, 6.0, 26.0), cross_color, true)
	draw_rect(Rect2(-13.0, -3.0, 26.0, 6.0), cross_color, true)
