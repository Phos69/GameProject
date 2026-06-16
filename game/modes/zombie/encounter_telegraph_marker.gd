extends Node2D
class_name EncounterTelegraphMarker

@export var encounter_id: StringName = &""
@export var warning_radius: float = 96.0
@export var warning_duration: float = 0.8
@export var warning_color: Color = Color(1.0, 0.58, 0.16, 1.0)

var time_remaining: float = 0.0
var high_contrast: bool = false
var reduced_motion: bool = false

func _ready() -> void:
	add_to_group("encounter_telegraphs")
	add_to_group("visual_settings_consumers")
	VisualSettingsManager.sync_consumer(self)
	set_process(true)
	queue_redraw()

func configure(
	new_encounter_id: StringName,
	radius: float,
	duration: float,
	color: Color
) -> void:
	encounter_id = new_encounter_id
	warning_radius = maxf(radius, 16.0)
	warning_duration = maxf(duration, 0.05)
	time_remaining = warning_duration
	warning_color = color
	queue_redraw()

func apply_visual_settings(settings: Dictionary) -> void:
	high_contrast = bool(settings.get("high_contrast", false))
	reduced_motion = bool(settings.get("reduced_motion", false))
	queue_redraw()

func get_progress_ratio() -> float:
	if warning_duration <= 0.0:
		return 1.0
	return clampf(1.0 - time_remaining / warning_duration, 0.0, 1.0)

func _process(delta: float) -> void:
	time_remaining = maxf(time_remaining - delta, 0.0)
	queue_redraw()
	if time_remaining <= 0.0:
		queue_free()

func _draw() -> void:
	var progress := get_progress_ratio()
	var pulse := 1.0
	if not reduced_motion:
		pulse = 0.75 + 0.25 * sin(progress * TAU * 3.0)
	var display_color := Color.WHITE if high_contrast else warning_color
	var fill := Color(display_color, 0.10 * pulse)
	var outline := Color(display_color, 0.82)
	var radius := warning_radius
	if not reduced_motion:
		radius = lerpf(warning_radius * 1.18, warning_radius, progress)
	draw_circle(Vector2.ZERO, radius, fill)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 72, outline, 3.0)
	draw_line(Vector2(-radius, 0.0), Vector2(radius, 0.0), outline, 2.0)
	draw_line(Vector2(0.0, -radius), Vector2(0.0, radius), outline, 2.0)
