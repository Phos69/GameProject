extends CharacterBody2D
class_name PlayerController

@export_range(1, 4) var player_slot: int = 1
@export var move_speed: float = 260.0
@export var acceleration: float = 1700.0
@export var friction: float = 1900.0
@export var iso_y_scale: float = 0.58
@export var aim_line_length: float = 46.0
@export var slot_colors: Array[Color] = [
	Color(0.18, 0.74, 0.95, 1.0),
	Color(0.95, 0.42, 0.34, 1.0),
	Color(0.52, 0.86, 0.32, 1.0),
	Color(0.94, 0.78, 0.28, 1.0)
]

@onready var visual := $Visual as Polygon2D
@onready var aim_line := $AimLine as Line2D
@onready var weapon_system = $WeaponSystem

var facing_direction: Vector2 = Vector2.RIGHT
var input_manager

func _ready() -> void:
	add_to_group("players")
	input_manager = get_tree().get_first_node_in_group("input_manager")
	_apply_slot_color()
	_update_aim_line()

func _physics_process(delta: float) -> void:
	if input_manager == null:
		input_manager = get_tree().get_first_node_in_group("input_manager")
		if input_manager == null:
			return

	var move_input: Vector2 = input_manager.get_player_move_vector(player_slot)
	var desired_velocity: Vector2 = _movement_to_isometric(move_input) * move_speed

	if desired_velocity.length_squared() > 0.01:
		velocity = velocity.move_toward(desired_velocity, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	move_and_slide()
	_update_facing(move_input)
	_handle_fire()

func _movement_to_isometric(input_vector: Vector2) -> Vector2:
	if input_vector.length_squared() <= 0.01:
		return Vector2.ZERO
	var iso_vector := Vector2(input_vector.x - input_vector.y, (input_vector.x + input_vector.y) * iso_y_scale)
	return iso_vector.normalized() * minf(input_vector.length(), 1.0)

func _update_facing(move_input: Vector2) -> void:
	var aim_input: Vector2 = input_manager.get_player_aim_vector(player_slot)
	if aim_input.length() > 0.20:
		facing_direction = aim_input.normalized()
	elif move_input.length() > 0.20:
		var move_direction := _movement_to_isometric(move_input)
		if move_direction.length_squared() > 0.01:
			facing_direction = move_direction.normalized()
	_update_aim_line()

func _update_aim_line() -> void:
	if aim_line == null:
		return
	aim_line.points = PackedVector2Array([Vector2.ZERO, facing_direction * aim_line_length])

func _apply_slot_color() -> void:
	if visual == null or slot_colors.is_empty():
		return
	var index := clampi(player_slot - 1, 0, slot_colors.size() - 1)
	visual.color = slot_colors[index]

func _handle_fire() -> void:
	if weapon_system == null:
		return
	if input_manager.is_player_fire_pressed(player_slot):
		weapon_system.try_fire(global_position + facing_direction * 22.0, facing_direction, self)
