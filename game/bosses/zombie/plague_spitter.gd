extends ZombieBossBase
class_name PlagueSpitter

@export var plague_fan_telegraph_duration: float = 0.72
@export var spore_ring_telegraph_duration: float = 0.92
@export var plague_fan_projectile_count: int = 7
@export var plague_fan_spread_radians: float = 0.13
@export var spore_ring_projectile_count: int = 12
@export var plague_fan_speed_scale: float = 0.94
@export var spore_ring_speed_scale: float = 0.78
@export var plague_fan_damage_scale: float = 0.82
@export var spore_ring_damage_scale: float = 0.68
@export var strafe_switch_interval: float = 1.45
@export var plague_fan_visual: WeaponVisualData = preload(
	"res://game/bosses/zombie/visuals/plague_fan_visual.tres"
)
@export var spore_ring_visual: WeaponVisualData = preload(
	"res://game/bosses/zombie/visuals/spore_ring_visual.tres"
)

var pattern_sequence_index: int = 0
var kite_strafe_sign: float = 1.0
var strafe_switch_timer: float = 0.0

func _ready() -> void:
	super._ready()
	strafe_switch_timer = maxf(strafe_switch_interval, 0.10)

func _update_movement(delta: float) -> void:
	if stop_for_telegraph(delta):
		return
	var target_direction := get_target_direction()
	if target_direction.is_zero_approx():
		move_toward_velocity(Vector2.ZERO, delta)
		return
	strafe_switch_timer = maxf(strafe_switch_timer - delta, 0.0)
	if strafe_switch_timer <= 0.0:
		kite_strafe_sign *= -1.0
		var phase_scale := 0.78 if phase_index > 1 else 1.0
		strafe_switch_timer = maxf(
			strafe_switch_interval * phase_scale,
			0.10
		)
	var side_direction := target_direction.orthogonal() * kite_strafe_sign
	var distance := get_target_distance()
	var desired_velocity := Vector2.ZERO
	if distance < retreat_distance:
		desired_velocity = (
			-target_direction + side_direction * 0.42
		).normalized() * move_speed
	elif distance > preferred_distance + 42.0:
		desired_velocity = (
			target_direction + side_direction * 0.34
		).normalized() * move_speed * 0.92
	else:
		desired_velocity = side_direction * move_speed * 0.82
	var phase_speed := 1.10 if phase_index > 1 else 1.0
	move_toward_velocity(desired_velocity * phase_speed, delta, 1.15)

func start_attack_telegraph(pattern_id: StringName) -> bool:
	if is_dead or not pending_pattern_id.is_empty():
		return false
	var direction := Vector2.ZERO
	var duration := 0.0
	match pattern_id:
		&"plague_fan":
			direction = get_target_direction()
			if direction.is_zero_approx():
				return false
			duration = maxf(plague_fan_telegraph_duration, 0.01)
			telegraph_visual.begin_projectile_cone(
				pattern_id,
				direction,
				duration,
				maxi(plague_fan_projectile_count, 1),
				maxf(plague_fan_spread_radians, 0.0)
			)
		&"spore_ring":
			duration = maxf(spore_ring_telegraph_duration, 0.01)
			telegraph_visual.begin_projectile_radial(
				pattern_id,
				duration,
				maxi(spore_ring_projectile_count, 1)
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

func perform_plague_fan(
	direction_override: Vector2 = Vector2.ZERO
) -> int:
	var direction := _resolve_attack_direction(direction_override)
	if direction.is_zero_approx():
		return 0
	var count := maxi(plague_fan_projectile_count, 1)
	var center := float(count - 1) * 0.5
	var projectile_total := 0
	for index in range(count):
		var angle_offset := (
			(float(index) - center) * maxf(plague_fan_spread_radians, 0.0)
		)
		var projectile := spawn_hostile_projectile(
			direction.rotated(angle_offset),
			plague_fan_speed_scale,
			plague_fan_damage_scale,
			&"plague_fan",
			plague_fan_visual
		)
		if projectile != null:
			projectile_total += 1
	attack_pattern_started.emit(&"plague_fan", projectile_total)
	return projectile_total

func perform_spore_ring() -> int:
	var count := maxi(spore_ring_projectile_count, 1)
	var projectile_total := 0
	for index in range(count):
		var direction := Vector2.RIGHT.rotated(
			TAU * float(index) / float(count)
		)
		var projectile := spawn_hostile_projectile(
			direction,
			spore_ring_speed_scale,
			spore_ring_damage_scale,
			&"spore_ring",
			spore_ring_visual
		)
		if projectile != null:
			projectile_total += 1
	attack_pattern_started.emit(&"spore_ring", projectile_total)
	return projectile_total

func _get_next_scheduled_pattern() -> StringName:
	if phase_index > 1:
		return (
			&"spore_ring"
			if pattern_sequence_index % 2 == 1
			else &"plague_fan"
		)
	return (
		&"spore_ring"
		if pattern_sequence_index % 3 == 2
		else &"plague_fan"
	)

func _execute_pattern(pattern_id: StringName, direction: Vector2) -> void:
	if pattern_id == &"spore_ring":
		perform_spore_ring()
	else:
		perform_plague_fan(direction)
	pattern_sequence_index += 1

func _get_telegraph_duration(pattern_id: StringName) -> float:
	if pattern_id == &"spore_ring":
		return maxf(spore_ring_telegraph_duration, 0.01)
	return maxf(plague_fan_telegraph_duration, 0.01)

func _resolve_attack_direction(direction_override: Vector2) -> Vector2:
	var direction := direction_override.normalized()
	if direction.is_zero_approx():
		direction = get_target_direction()
	return direction
