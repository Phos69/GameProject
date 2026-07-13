extends ZombieBossBase
class_name GoreCharger

@export var orbit_distance: float = 238.0
@export var orbit_band: float = 34.0
@export var orbit_speed_scale: float = 0.76
@export var charge_telegraph_duration: float = 0.78
@export var charge_distance: float = 430.0
@export var charge_speed: float = 540.0
@export var charge_hitbox_length: float = 112.0
@export var charge_width: float = 86.0
@export var charge_damage_scale: float = 1.22
@export var horn_telegraph_duration: float = 0.58
@export var horn_range: float = 126.0
@export var horn_arc_degrees: float = 152.0
@export var horn_damage_scale: float = 0.92

var charge_direction: Vector2 = Vector2.ZERO
var charge_time_remaining: float = 0.0
var charge_attack: MeleeAttack

func start_attack_telegraph(pattern_id: StringName) -> bool:
	if is_dead or not pending_pattern_id.is_empty():
		return false

	var direction := get_target_direction()
	if direction.is_zero_approx():
		return false
	var duration := 0.0
	match pattern_id:
		&"gore_charge":
			duration = maxf(charge_telegraph_duration, 0.01)
			telegraph_visual.begin_charge_lane(
				pattern_id,
				direction,
				duration,
				charge_distance,
				charge_width
			)
		&"horn_combo":
			duration = maxf(horn_telegraph_duration, 0.01)
			telegraph_visual.begin_melee_arc(
				pattern_id,
				direction,
				duration,
				horn_range,
				horn_arc_degrees
			)
		_:
			return false

	pending_pattern_id = pattern_id
	pending_pattern_direction = direction
	pending_pattern_phase = phase_index
	telegraph_timer = duration
	visual.set_attack_charge(pattern_id)
	attack_telegraph_started.emit(pattern_id, duration, direction)
	return true

func perform_gore_charge(direction: Vector2) -> MeleeAttack:
	charge_direction = direction.normalized()
	if charge_direction.is_zero_approx():
		return null
	charge_time_remaining = charge_distance / maxf(charge_speed, 1.0)
	charge_attack = spawn_hostile_melee(
		&"gore_charge",
		charge_direction,
		&"dash",
		charge_hitbox_length,
		charge_width,
		1.0,
		charge_damage_scale,
		charge_time_remaining + 0.05,
		melee_knockback * 1.45,
		GameConstants.MAX_LOCAL_PLAYERS,
		&"katana_dash_cut"
	)
	return charge_attack

func perform_horn_combo(direction: Vector2) -> MeleeAttack:
	return spawn_hostile_melee(
		&"horn_combo",
		direction,
		&"arc",
		horn_range,
		horn_range,
		horn_arc_degrees,
		horn_damage_scale,
		melee_active_time,
		melee_knockback,
		GameConstants.MAX_LOCAL_PLAYERS,
		&"claw_arc"
	)

func _update_movement(delta: float) -> void:
	if charge_time_remaining > 0.0:
		_update_charge(delta)
		return
	if stop_for_telegraph(delta):
		return

	var direction := get_target_direction()
	if direction.is_zero_approx():
		move_toward_velocity(Vector2.ZERO, delta)
		return
	var distance := get_target_distance()
	var desired_velocity := direction.orthogonal() * (
		move_speed * orbit_speed_scale * strafe_sign
	)
	if distance > orbit_distance + orbit_band:
		desired_velocity = direction * move_speed
	elif distance < orbit_distance - orbit_band:
		desired_velocity = -direction * move_speed
	move_toward_velocity(desired_velocity, delta)

func _update_charge(delta: float) -> void:
	visual.set_facing(charge_direction)
	velocity = charge_direction * charge_speed
	move_and_slide()
	if is_instance_valid(charge_attack):
		charge_attack.global_position = global_position
	charge_time_remaining = maxf(charge_time_remaining - delta, 0.0)
	if charge_time_remaining <= 0.0:
		velocity = Vector2.ZERO
		if is_instance_valid(charge_attack):
			charge_attack.queue_free()
		charge_attack = null

func _get_next_scheduled_pattern() -> StringName:
	if phase_index > 1 and phase_two_pattern_index % 2 == 1:
		return &"horn_combo"
	return &"gore_charge"

func _get_telegraph_duration(pattern_id: StringName) -> float:
	if pattern_id == &"horn_combo":
		return maxf(horn_telegraph_duration, 0.01)
	return maxf(charge_telegraph_duration, 0.01)

func _execute_pattern(pattern_id: StringName, direction: Vector2) -> void:
	if pattern_id == &"horn_combo":
		perform_horn_combo(direction)
	else:
		perform_gore_charge(direction)
