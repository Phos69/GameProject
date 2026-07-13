extends ZombieBossBase
class_name GraveColossus

@export var short_stop_distance: float = 96.0
@export var chase_acceleration_scale: float = 0.82
@export var cleaver_telegraph_duration: float = 0.72
@export var cleaver_range: float = 154.0
@export var cleaver_arc_degrees: float = 126.0
@export var cleaver_damage_scale: float = 1.0
@export var slam_telegraph_duration: float = 0.94
@export var slam_radius: float = 132.0
@export var slam_damage_scale: float = 1.28

func start_attack_telegraph(pattern_id: StringName) -> bool:
	if is_dead or not pending_pattern_id.is_empty():
		return false

	var direction := get_target_direction()
	var duration := 0.0
	match pattern_id:
		&"cleaver_sweep":
			if direction.is_zero_approx():
				return false
			duration = maxf(cleaver_telegraph_duration, 0.01)
			telegraph_visual.begin_melee_arc(
				pattern_id,
				direction,
				duration,
				cleaver_range,
				cleaver_arc_degrees
			)
		&"grave_slam":
			duration = maxf(slam_telegraph_duration, 0.01)
			telegraph_visual.begin_area(pattern_id, duration, slam_radius)
		_:
			return false

	pending_pattern_id = pattern_id
	pending_pattern_direction = direction
	pending_pattern_phase = phase_index
	telegraph_timer = duration
	visual.set_attack_charge(pattern_id)
	attack_telegraph_started.emit(pattern_id, duration, direction)
	return true

func perform_cleaver_sweep(direction: Vector2) -> MeleeAttack:
	return spawn_hostile_melee(
		&"cleaver_sweep",
		direction,
		&"arc",
		cleaver_range,
		cleaver_range,
		cleaver_arc_degrees,
		cleaver_damage_scale,
		melee_active_time,
		melee_knockback,
		GameConstants.MAX_LOCAL_PLAYERS,
		&"heavy_cleave"
	)

func perform_grave_slam(direction: Vector2) -> MeleeAttack:
	return spawn_hostile_melee(
		&"grave_slam",
		direction,
		&"circle",
		slam_radius,
		slam_radius * 2.0,
		360.0,
		slam_damage_scale,
		melee_active_time * 1.25,
		melee_knockback * 1.35,
		GameConstants.MAX_LOCAL_PLAYERS,
		&"ground_slam"
	)

func _update_movement(delta: float) -> void:
	if stop_for_telegraph(delta):
		return
	var direction := get_target_direction()
	if direction.is_zero_approx():
		move_toward_velocity(Vector2.ZERO, delta, chase_acceleration_scale)
		return
	var desired_velocity := Vector2.ZERO
	if get_target_distance() > short_stop_distance:
		desired_velocity = direction * move_speed
	move_toward_velocity(
		desired_velocity,
		delta,
		chase_acceleration_scale
	)

func _get_next_scheduled_pattern() -> StringName:
	if phase_index > 1 and phase_two_pattern_index % 2 == 0:
		return &"grave_slam"
	return &"cleaver_sweep"

func _get_telegraph_duration(pattern_id: StringName) -> float:
	if pattern_id == &"grave_slam":
		return maxf(slam_telegraph_duration, 0.01)
	return maxf(cleaver_telegraph_duration, 0.01)

func _execute_pattern(pattern_id: StringName, direction: Vector2) -> void:
	if pattern_id == &"grave_slam":
		perform_grave_slam(direction)
	else:
		perform_cleaver_sweep(direction)
