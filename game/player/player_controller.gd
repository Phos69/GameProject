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

@onready var visual := $Visual as PlayerVisual
@onready var aim_line := $AimLine as Line2D
@onready var weapon_system = $WeaponSystem
@onready var health_component := $HealthComponent as HealthComponent
@onready var revive_indicator := $ReviveIndicator as ReviveIndicatorVisual

var facing_direction: Vector2 = Vector2.RIGHT
var input_manager
var game_mode_manager: GameModeManager
var base_max_health: int = 100

func _ready() -> void:
	add_to_group("players")
	input_manager = get_tree().get_first_node_in_group("input_manager")
	game_mode_manager = get_tree().get_first_node_in_group(
		"game_mode_manager"
	) as GameModeManager
	health_component.died.connect(_on_died)
	health_component.downed.connect(_on_downed)
	health_component.revived.connect(_on_revived)
	health_component.damaged.connect(_on_damaged)
	weapon_system.fired.connect(_on_weapon_fired)
	weapon_system.reload_started.connect(_on_reload_started)
	weapon_system.weapon_changed.connect(_on_weapon_changed)
	base_max_health = health_component.max_health
	_apply_slot_color()
	visual.set_player_slot(player_slot)
	visual.set_weapon_data(weapon_system.weapon_data)
	_update_aim_line()

func _physics_process(delta: float) -> void:
	if health_component.is_incapacitated():
		velocity = Vector2.ZERO
		visual.set_motion(velocity, move_speed)
		return
	if game_mode_manager == null:
		game_mode_manager = get_tree().get_first_node_in_group(
			"game_mode_manager"
		) as GameModeManager
	if game_mode_manager != null and not game_mode_manager.is_gameplay_active():
		velocity = Vector2.ZERO
		visual.set_motion(velocity, move_speed)
		return
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
	visual.set_motion(velocity, move_speed)
	_handle_weapon_input()

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
	visual.set_facing(facing_direction)

func _apply_slot_color() -> void:
	if visual == null or slot_colors.is_empty():
		return
	var index := clampi(player_slot - 1, 0, slot_colors.size() - 1)
	visual.set_slot_color(slot_colors[index])
	revive_indicator.set_slot_color(slot_colors[index])

func _handle_weapon_input() -> void:
	if weapon_system == null:
		return
	if input_manager.is_player_reload_just_pressed(player_slot):
		weapon_system.start_reload()
	if input_manager.is_player_fire_pressed(player_slot):
		weapon_system.try_fire(global_position + facing_direction * 22.0, facing_direction, self)

func prepare_for_run(max_health_bonus: int = 0) -> void:
	health_component.set_max_health(
		base_max_health + maxi(max_health_bonus, 0),
		true
	)
	velocity = Vector2.ZERO
	visual.reset_visual()
	revive_indicator.set_downed(false)
	aim_line.show()

func set_revive_progress(ratio: float, active: bool) -> void:
	revive_indicator.set_revive_progress(ratio, active)

func is_downed() -> bool:
	return health_component.is_downed

func _on_downed() -> void:
	velocity = Vector2.ZERO
	visual.play_downed()
	revive_indicator.set_downed(true)
	aim_line.hide()

func _on_revived(_current_health: int, _max_health: int) -> void:
	velocity = Vector2.ZERO
	visual.reset_visual()
	revive_indicator.set_downed(false)
	aim_line.show()

func _on_died() -> void:
	velocity = Vector2.ZERO
	visual.play_dead()
	aim_line.hide()

func _on_damaged(_amount: int, _current_health: int, _max_health: int) -> void:
	visual.play_hurt()

func _on_weapon_fired(
	_origin: Vector2,
	_direction: Vector2,
	_damage: int
) -> void:
	visual.play_fire()

func _on_reload_started(duration: float) -> void:
	visual.play_reload(duration)

func _on_weapon_changed(weapon_data: WeaponData) -> void:
	visual.set_weapon_data(weapon_data)
