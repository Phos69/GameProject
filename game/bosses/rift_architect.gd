extends BasicBoss
class_name RiftArchitect

@export var lane_telegraph_duration: float = 0.80
@export var cross_telegraph_duration: float = 0.95
@export var lane_projectile_count: int = 5
@export var lane_gap_index: int = 2
@export var lane_spacing: float = 52.0
@export var cross_projectile_count: int = 8
@export var cross_rotation: float = PI * 0.125
@export var lane_projectile_visual: WeaponVisualData = preload(
	"res://game/weapons/rift_architect_lane_visual.tres"
)
@export var cross_projectile_visual: WeaponVisualData = preload(
	"res://game/weapons/rift_architect_cross_visual.tres"
)

func start_attack_telegraph(pattern_id: StringName) -> bool:
	if is_dead or not pending_pattern_id.is_empty():
		return false
	var direction := Vector2.ZERO
	var duration := 0.0
	match pattern_id:
		&"lane_sweep":
			if not _is_valid_target(target):
				_select_target()
			if target == null:
				return false
			direction = global_position.direction_to(target.global_position)
			duration = maxf(lane_telegraph_duration, 0.01)
			telegraph_visual.begin_lanes(
				direction,
				duration,
				lane_projectile_count,
				lane_spacing,
				lane_gap_index
			)
		&"cross_burst":
			duration = maxf(cross_telegraph_duration, 0.01)
			telegraph_visual.begin_cross(
				duration,
				cross_projectile_count,
				cross_rotation
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

func perform_lane_sweep(direction_override: Vector2) -> int:
	var projectile_system := _get_projectile_system()
	var direction := direction_override.normalized()
	if projectile_system == null or direction.is_zero_approx():
		return 0
	var side := direction.orthogonal()
	var center := float(lane_projectile_count - 1) * 0.5
	var projectile_total := 0
	for index in range(lane_projectile_count):
		if index == lane_gap_index:
			continue
		var offset := (float(index) - center) * lane_spacing
		projectile_system.spawn_projectile(
			global_position + direction * 44.0 + side * offset,
			direction,
			projectile_speed * 1.05,
			self,
			projectile_scene,
			projectile_damage,
			&"rift_lane",
			lane_projectile_visual
		)
		projectile_total += 1
	attack_pattern_started.emit(&"lane_sweep", projectile_total)
	return projectile_total

func perform_cross_burst() -> int:
	var projectile_system := _get_projectile_system()
	if projectile_system == null:
		return 0
	for index in range(cross_projectile_count):
		var direction := Vector2.RIGHT.rotated(
			cross_rotation
			+ TAU * float(index) / float(cross_projectile_count)
		)
		projectile_system.spawn_projectile(
			global_position + direction * 44.0,
			direction,
			projectile_speed * 0.92,
			self,
			projectile_scene,
			maxi(1, roundi(float(projectile_damage) * 0.82)),
			&"rift_cross",
			cross_projectile_visual
		)
	attack_pattern_started.emit(&"cross_burst", cross_projectile_count)
	return cross_projectile_count

func _get_next_scheduled_pattern() -> StringName:
	if phase_index > 1 and phase_two_pattern_index % 2 == 0:
		return &"cross_burst"
	return &"lane_sweep"

func _get_telegraph_duration(pattern_id: StringName) -> float:
	if pattern_id == &"cross_burst":
		return maxf(cross_telegraph_duration, 0.01)
	return maxf(lane_telegraph_duration, 0.01)

func _execute_pattern(pattern_id: StringName, direction: Vector2) -> void:
	if pattern_id == &"cross_burst":
		perform_cross_burst()
	else:
		perform_lane_sweep(direction)
