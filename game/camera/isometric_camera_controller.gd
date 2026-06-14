extends Camera2D
class_name IsometricCameraController

@export var follow_group: StringName = &"players"
@export var follow_speed: float = 7.5
@export var close_zoom: Vector2 = Vector2(1.0, 1.0)
@export var far_zoom: Vector2 = Vector2(0.82, 0.82)
@export var zoom_distance: float = 520.0

func _ready() -> void:
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

func _target_zoom(players: Array[Node]) -> Vector2:
	if players.size() <= 1:
		return close_zoom

	var max_distance := 0.0
	for a in players:
		for b in players:
			max_distance = maxf(max_distance, (a as Node2D).global_position.distance_to((b as Node2D).global_position))

	var zoom_factor := clampf(max_distance / zoom_distance, 0.0, 1.0)
	return close_zoom.lerp(far_zoom, zoom_factor)
