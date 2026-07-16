extends BasicEnemy
class_name RangedEnemy

signal attack_telegraph_started(duration: float, direction: Vector2)
signal attack_telegraph_finished()
signal ranged_shot_fired(direction: Vector2)

@export var preferred_distance: float = 330.0
@export var retreat_distance: float = 220.0
@export var maximum_shot_distance: float = 560.0
@export var windup_duration: float = 0.85
@export var projectile_speed: float = 235.0
@export var projectile_scene: PackedScene = preload(
	"res://game/projectiles/boss_projectile.tscn"
)
@export var projectile_visual: WeaponVisualData = preload(
	"res://game/weapons/shooter_projectile_visual.tres"
)

@onready var shot_telegraph := $ShotTelegraph

var windup_timer: float = 0.0
var locked_shot_direction: Vector2 = Vector2.ZERO

func _physics_process(delta: float) -> void:
	if current_state == State.DEAD or current_state == State.FALLING:
		velocity = Vector2.ZERO
		return

	attack_timer = maxf(attack_timer - delta, 0.0)
	target_refresh_timer = maxf(target_refresh_timer - delta, 0.0)
	if target_refresh_timer <= 0.0 or not _is_valid_target(target):
		_select_target()
		target_refresh_timer = target_refresh_interval

	if target == null:
		cancel_windup()
		_set_state(State.IDLE)
		velocity = velocity.move_toward(Vector2.ZERO, acceleration * delta)
		move_and_slide()
		_update_visual()
		return

	var distance_to_target := global_position.distance_to(target.global_position)
	if windup_timer > 0.0:
		_process_windup(delta)
	elif distance_to_target <= maximum_shot_distance and attack_timer <= 0.0:
		start_windup()
	else:
		_update_ranged_movement(delta, distance_to_target)

	move_and_slide()
	_update_visual()

func start_windup() -> bool:
	if (
		current_state == State.DEAD
		or windup_timer > 0.0
		or not _is_valid_target(target)
	):
		return false
	locked_shot_direction = global_position.direction_to(
		_target_aim_position(target)
	)
	if locked_shot_direction.is_zero_approx():
		return false
	windup_timer = maxf(windup_duration, 0.05)
	velocity = Vector2.ZERO
	_set_state(State.ATTACK)
	shot_telegraph.begin_warning(locked_shot_direction, windup_timer)
	attack_telegraph_started.emit(windup_timer, locked_shot_direction)
	return true

func cancel_windup() -> void:
	if windup_timer <= 0.0 and locked_shot_direction.is_zero_approx():
		return
	windup_timer = 0.0
	locked_shot_direction = Vector2.ZERO
	if shot_telegraph != null:
		shot_telegraph.finish_warning()

func _process_windup(delta: float) -> void:
	_set_state(State.ATTACK)
	velocity = velocity.move_toward(Vector2.ZERO, acceleration * delta)
	windup_timer = maxf(windup_timer - delta, 0.0)
	if windup_timer > 0.0:
		return
	shot_telegraph.finish_warning()
	attack_telegraph_finished.emit()
	_fire_locked_shot()

func _fire_locked_shot() -> void:
	var direction := locked_shot_direction
	locked_shot_direction = Vector2.ZERO
	attack_timer = maxf(attack_cooldown, 0.10)
	if direction.is_zero_approx():
		return
	var projectile_system := get_tree().get_first_node_in_group(
		"projectile_system"
	) as ProjectileSystem
	if projectile_system == null:
		return
	projectile_system.spawn_projectile(
		global_position + direction * 30.0,
		direction,
		projectile_speed,
		self,
		projectile_scene,
		attack_damage,
		&"enemy_shooter",
		projectile_visual
	)
	ranged_shot_fired.emit(direction)

func _update_ranged_movement(delta: float, distance_to_target: float) -> void:
	var direction := global_position.direction_to(target.global_position)
	var desired_velocity := Vector2.ZERO
	if distance_to_target > preferred_distance:
		# Approach through the pathfinder so ranged enemies also route around
		# obstacles/pits; retreat and strafe stay direct (short close-range moves).
		desired_velocity = _navigate_direction(target.global_position, delta) * move_speed
		_set_state(State.CHASE)
	elif distance_to_target < retreat_distance:
		desired_velocity = -direction * move_speed
		_set_state(State.CHASE)
	else:
		desired_velocity = direction.orthogonal() * move_speed * 0.28
		_set_state(State.ATTACK)
	velocity = velocity.move_toward(desired_velocity, acceleration * delta)

func _target_aim_position(target_node: Node2D) -> Vector2:
	if target_node == null or not is_instance_valid(target_node):
		return global_position
	var collision := target_node.get_node_or_null(
		"CollisionShape2D"
	) as CollisionShape2D
	if collision != null and not collision.disabled and collision.shape != null:
		return collision.global_position
	return target_node.global_position

func _on_died() -> void:
	cancel_windup()
	super._on_died()
