extends ZombieBossBase
class_name CarrionShepherd

@export var carrion_bolt_telegraph_duration: float = 0.68
@export var butcher_sweep_telegraph_duration: float = 0.74
@export var carrion_bolt_projectile_count: int = 3
@export var carrion_bolt_spread_radians: float = 0.075
@export var carrion_bolt_speed_scale: float = 1.12
@export var carrion_bolt_damage_scale: float = 0.92
@export var far_band_distance: float = 345.0
@export var melee_band_outer_distance: float = 165.0
@export var melee_band_inner_distance: float = 88.0
@export var butcher_sweep_range: float = 172.0
@export var butcher_sweep_width: float = 108.0
@export var butcher_sweep_arc_degrees: float = 154.0
@export var butcher_sweep_damage_scale: float = 1.10
@export var butcher_sweep_visual: WeaponVisualData = preload(
	"res://game/bosses/zombie/visuals/butcher_sweep_visual.tres"
)
@export var carrion_bolt_visual: WeaponVisualData = preload(
	"res://game/bosses/zombie/visuals/carrion_bolt_visual.tres"
)

var band_strafe_sign: float = 1.0

func _ready() -> void:
	if melee_visual == null:
		melee_visual = butcher_sweep_visual
	super._ready()

func _update_movement(delta: float) -> void:
	if stop_for_telegraph(delta):
		return
	var target_direction := get_target_direction()
	if target_direction.is_zero_approx():
		move_toward_velocity(Vector2.ZERO, delta)
		return
	var side_direction := target_direction.orthogonal() * band_strafe_sign
	var distance := get_target_distance()
	var desired_velocity := Vector2.ZERO
	if distance > far_band_distance:
		desired_velocity = target_direction * move_speed
	elif distance > melee_band_outer_distance:
		desired_velocity = (
			target_direction * 0.58 + side_direction * 0.82
		).normalized() * move_speed * 0.88
	elif distance < melee_band_inner_distance:
		desired_velocity = (
			-target_direction + side_direction * 0.28
		).normalized() * move_speed * 0.82
	else:
		desired_velocity = side_direction * move_speed * 0.58
	var phase_speed := 1.08 if phase_index > 1 else 1.0
	move_toward_velocity(desired_velocity * phase_speed, delta, 1.25)

func start_attack_telegraph(pattern_id: StringName) -> bool:
	if is_dead or not pending_pattern_id.is_empty():
		return false
	var direction := Vector2.ZERO
	var duration := 0.0
	match pattern_id:
		&"carrion_bolt":
			direction = get_target_direction()
			if direction.is_zero_approx():
				return false
			duration = maxf(carrion_bolt_telegraph_duration, 0.01)
			telegraph_visual.begin_projectile_cone(
				pattern_id,
				direction,
				duration,
				maxi(carrion_bolt_projectile_count, 1),
				maxf(carrion_bolt_spread_radians, 0.0)
			)
		&"butcher_sweep":
			direction = get_target_direction()
			if direction.is_zero_approx():
				return false
			duration = maxf(butcher_sweep_telegraph_duration, 0.01)
			telegraph_visual.begin_melee_arc(
				pattern_id,
				direction,
				duration,
				butcher_sweep_range,
				butcher_sweep_arc_degrees
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

func perform_carrion_bolt(
	direction_override: Vector2 = Vector2.ZERO
) -> int:
	var direction := _resolve_attack_direction(direction_override)
	if direction.is_zero_approx():
		return 0
	var count := maxi(carrion_bolt_projectile_count, 1)
	var center := float(count - 1) * 0.5
	var projectile_total := 0
	for index in range(count):
		var angle_offset := (
			(float(index) - center) * maxf(carrion_bolt_spread_radians, 0.0)
		)
		var projectile := spawn_hostile_projectile(
			direction.rotated(angle_offset),
			carrion_bolt_speed_scale,
			carrion_bolt_damage_scale,
			&"carrion_bolt",
			carrion_bolt_visual
		)
		if projectile != null:
			projectile_total += 1
	attack_pattern_started.emit(&"carrion_bolt", projectile_total)
	return projectile_total

func perform_butcher_sweep(
	direction_override: Vector2 = Vector2.ZERO
) -> MeleeAttack:
	var direction := _resolve_attack_direction(direction_override)
	if direction.is_zero_approx():
		return null
	return spawn_hostile_melee(
		&"butcher_sweep",
		direction,
		&"arc",
		butcher_sweep_range,
		butcher_sweep_width,
		butcher_sweep_arc_degrees,
		butcher_sweep_damage_scale,
		0.18,
		205.0,
		GameConstants.MAX_LOCAL_PLAYERS,
		&"heavy_cleave"
	)

func _get_next_scheduled_pattern() -> StringName:
	if get_target_distance() <= melee_band_outer_distance + 12.0:
		return &"butcher_sweep"
	return &"carrion_bolt"

func _execute_pattern(pattern_id: StringName, direction: Vector2) -> void:
	if pattern_id == &"butcher_sweep":
		perform_butcher_sweep(direction)
		band_strafe_sign *= -1.0
	else:
		perform_carrion_bolt(direction)

func _get_telegraph_duration(pattern_id: StringName) -> float:
	if pattern_id == &"butcher_sweep":
		return maxf(butcher_sweep_telegraph_duration, 0.01)
	return maxf(carrion_bolt_telegraph_duration, 0.01)

func _resolve_attack_direction(direction_override: Vector2) -> Vector2:
	var direction := direction_override.normalized()
	if direction.is_zero_approx():
		direction = get_target_direction()
	return direction
