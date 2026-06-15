extends Camera2D
class_name IsometricCameraController

@export var follow_group: StringName = &"players"
@export var follow_speed: float = 7.5
@export var close_zoom: Vector2 = Vector2(1.0, 1.0)
@export var far_zoom: Vector2 = Vector2(0.82, 0.82)
@export var zoom_distance: float = 520.0

var camera_shake_intensity: float = 1.0
var reduced_motion: bool = false
var shake_strength: float = 0.0
var shake_duration: float = 0.0
var shake_time_left: float = 0.0
var shake_seed: float = 0.0
var last_applied_shake_strength: float = 0.0

func _ready() -> void:
	add_to_group("visual_settings_consumers")
	VisualSettingsManager.sync_consumer(self)
	make_current()

func _process(delta: float) -> void:
	var players := get_tree().get_nodes_in_group(follow_group)
	if players.is_empty():
		return

	var center := Vector2.ZERO
	for player in players:
		center += (player as Node2D).global_position
	center /= float(players.size())

	global_position = global_position.lerp(center, 1.0 - exp(-follow_speed * delta))
	zoom = _target_zoom(players)
	_update_shake(delta)

func apply_visual_settings(settings: Dictionary) -> void:
	camera_shake_intensity = clampf(
		float(settings.get("camera_shake_intensity", 1.0)),
		0.0,
		1.0
	)
	reduced_motion = bool(settings.get("reduced_motion", false))
	if reduced_motion or camera_shake_intensity <= 0.0:
		shake_time_left = 0.0
		offset = Vector2.ZERO
		last_applied_shake_strength = 0.0

func request_shake(strength: float, duration: float) -> void:
	var applied_intensity := (
		0.0
		if reduced_motion
		else camera_shake_intensity
	)
	last_applied_shake_strength = maxf(strength, 0.0) * applied_intensity
	if last_applied_shake_strength <= 0.0 or duration <= 0.0:
		return
	shake_strength = maxf(shake_strength, last_applied_shake_strength)
	shake_duration = maxf(duration, 0.01)
	shake_time_left = maxf(shake_time_left, shake_duration)
	shake_seed += 1.37

func _update_shake(delta: float) -> void:
	if shake_time_left <= 0.0:
		offset = Vector2.ZERO
		shake_strength = 0.0
		return
	shake_time_left = maxf(shake_time_left - delta, 0.0)
	var ratio := shake_time_left / maxf(shake_duration, 0.01)
	var elapsed := Time.get_ticks_msec() * 0.001
	offset = Vector2(
		sin((elapsed + shake_seed) * 73.0),
		cos((elapsed * 1.13 + shake_seed) * 61.0)
	) * shake_strength * ratio

func _target_zoom(players: Array[Node]) -> Vector2:
	if players.size() <= 1:
		return close_zoom

	var max_distance := 0.0
	for a in players:
		for b in players:
			max_distance = maxf(max_distance, (a as Node2D).global_position.distance_to((b as Node2D).global_position))

	var zoom_factor := clampf(max_distance / zoom_distance, 0.0, 1.0)
	return close_zoom.lerp(far_zoom, zoom_factor)
