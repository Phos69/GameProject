extends Node
class_name EntityVoidFallComponent

signal fall_started(origin: Vector2)
signal fall_finished(origin: Vector2)

@export_range(0.15, 1.5, 0.05) var fall_duration: float = 0.45
@export_range(12.0, 160.0, 2.0) var fall_distance: float = 58.0
@export_range(0.05, 0.8, 0.05) var final_scale_ratio: float = 0.18
@export_range(0.0, 0.95, 0.05) var fade_start_ratio: float = 0.35

var is_falling: bool = false
var fall_origin: Vector2 = Vector2.ZERO
var elapsed: float = 0.0
var visual_target: Node2D
var initial_visual_position: Vector2 = Vector2.ZERO
var initial_visual_scale: Vector2 = Vector2.ONE
var initial_visual_rotation: float = 0.0
var initial_visual_modulate: Color = Color.WHITE

func begin_fall(entity_position: Vector2, target: Node2D) -> bool:
	if is_falling or target == null:
		return false
	is_falling = true
	fall_origin = entity_position
	elapsed = 0.0
	visual_target = target
	initial_visual_position = target.position
	initial_visual_scale = target.scale
	initial_visual_rotation = target.rotation
	initial_visual_modulate = target.modulate
	fall_started.emit(fall_origin)
	return true

func _process(delta: float) -> void:
	if not is_falling:
		return
	if visual_target == null or not is_instance_valid(visual_target):
		_finish_fall()
		return
	elapsed = minf(elapsed + delta, fall_duration)
	var ratio := clampf(elapsed / maxf(fall_duration, 0.001), 0.0, 1.0)
	var drop_ratio := ratio * ratio
	visual_target.position = (
		initial_visual_position + Vector2.DOWN * fall_distance * drop_ratio
	)
	visual_target.scale = initial_visual_scale.lerp(
		initial_visual_scale * final_scale_ratio,
		drop_ratio
	)
	visual_target.rotation = initial_visual_rotation + sin(ratio * PI) * 0.18
	var fade_ratio := clampf(
		inverse_lerp(fade_start_ratio, 1.0, ratio),
		0.0,
		1.0
	)
	var next_modulate := initial_visual_modulate
	next_modulate.a = initial_visual_modulate.a * (1.0 - fade_ratio)
	visual_target.modulate = next_modulate
	if elapsed >= fall_duration:
		_finish_fall()

func reset_runtime() -> void:
	_restore_visual()
	is_falling = false
	elapsed = 0.0
	fall_origin = Vector2.ZERO
	visual_target = null

func _finish_fall() -> void:
	if not is_falling:
		return
	var completed_origin := fall_origin
	_restore_visual()
	is_falling = false
	elapsed = 0.0
	visual_target = null
	fall_finished.emit(completed_origin)

func _restore_visual() -> void:
	if visual_target == null or not is_instance_valid(visual_target):
		return
	visual_target.position = initial_visual_position
	visual_target.scale = initial_visual_scale
	visual_target.rotation = initial_visual_rotation
	visual_target.modulate = initial_visual_modulate
