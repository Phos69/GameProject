extends ZombieBossBase
class_name BoneMortar

@export var bone_mortar_telegraph_duration: float = 0.96
@export var bone_shards_telegraph_duration: float = 0.88
@export var bone_mortar_projectile_count: int = 4
@export var bone_mortar_spread_radians: float = 0.10
@export var bone_shards_projectile_count: int = 14
@export var bone_mortar_speed_scale: float = 0.72
@export var bone_shards_speed_scale: float = 0.86
@export var bone_mortar_damage_scale: float = 1.05
@export var bone_shards_damage_scale: float = 0.72
@export var bone_mortar_arc_height: float = 118.0
@export var anchor_duration: float = 1.30
@export var reposition_duration: float = 0.38
@export var reposition_speed_scale: float = 1.72
@export var bone_mortar_visual: WeaponVisualData = preload(
	"res://game/bosses/zombie/visuals/bone_mortar_visual.tres"
)
@export var bone_shards_visual: WeaponVisualData = preload(
	"res://game/bosses/zombie/visuals/bone_shards_visual.tres"
)

var pattern_sequence_index: int = 0
var anchor_timer: float = 0.0
var reposition_timer: float = 0.0
var reposition_direction: Vector2 = Vector2.ZERO
var reposition_side: float = 1.0

func _ready() -> void:
	super._ready()
	anchor_timer = maxf(anchor_duration * 0.55, 0.10)

func _update_movement(delta: float) -> void:
	if stop_for_telegraph(delta):
		return
	if reposition_timer > 0.0:
		reposition_timer = maxf(reposition_timer - delta, 0.0)
		move_toward_velocity(
			reposition_direction * move_speed * reposition_speed_scale,
			delta,
			2.4
		)
		return
	anchor_timer = maxf(anchor_timer - delta, 0.0)
	if anchor_timer <= 0.0:
		_begin_reposition_burst()
		return
	move_toward_velocity(Vector2.ZERO, delta, 1.9)

func start_attack_telegraph(pattern_id: StringName) -> bool:
	if is_dead or not pending_pattern_id.is_empty():
		return false
	var direction := Vector2.ZERO
	var duration := 0.0
	match pattern_id:
		&"bone_mortar":
			direction = get_target_direction()
			if direction.is_zero_approx():
				return false
			duration = maxf(bone_mortar_telegraph_duration, 0.01)
			telegraph_visual.begin_projectile_cone(
				pattern_id,
				direction,
				duration,
				maxi(bone_mortar_projectile_count, 1),
				maxf(bone_mortar_spread_radians, 0.0)
			)
		&"bone_shards":
			duration = maxf(bone_shards_telegraph_duration, 0.01)
			telegraph_visual.begin_projectile_radial(
				pattern_id,
				duration,
				maxi(bone_shards_projectile_count, 1)
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

func perform_bone_mortar(
	direction_override: Vector2 = Vector2.ZERO
) -> int:
	var direction := _resolve_attack_direction(direction_override)
	if direction.is_zero_approx():
		return 0
	var count := maxi(bone_mortar_projectile_count, 1)
	var center := float(count - 1) * 0.5
	var projectile_total := 0
	for index in range(count):
		var center_offset := float(index) - center
		var angle_offset := (
			center_offset * maxf(bone_mortar_spread_radians, 0.0)
		)
		var speed_stagger := 0.94 + float(index) * 0.04
		var projectile := spawn_hostile_projectile(
			direction.rotated(angle_offset),
			bone_mortar_speed_scale * speed_stagger,
			bone_mortar_damage_scale,
			&"bone_mortar",
			bone_mortar_visual,
			bone_mortar_arc_height + absf(center_offset) * 14.0
		)
		if projectile != null:
			projectile_total += 1
	attack_pattern_started.emit(&"bone_mortar", projectile_total)
	return projectile_total

func perform_bone_shards() -> int:
	var count := maxi(bone_shards_projectile_count, 1)
	var projectile_total := 0
	for index in range(count):
		var direction := Vector2.RIGHT.rotated(
			TAU * float(index) / float(count)
		)
		var projectile := spawn_hostile_projectile(
			direction,
			bone_shards_speed_scale,
			bone_shards_damage_scale,
			&"bone_shards",
			bone_shards_visual
		)
		if projectile != null:
			projectile_total += 1
	attack_pattern_started.emit(&"bone_shards", projectile_total)
	return projectile_total

func _begin_reposition_burst() -> void:
	var target_direction := get_target_direction()
	if target_direction.is_zero_approx():
		reposition_direction = Vector2.ZERO
		anchor_timer = maxf(anchor_duration, 0.10)
		return
	var side_direction := target_direction.orthogonal() * reposition_side
	var distance := get_target_distance()
	if distance < retreat_distance:
		reposition_direction = (
			-target_direction + side_direction * 0.48
		).normalized()
	elif distance > preferred_distance + 80.0:
		reposition_direction = (
			target_direction + side_direction * 0.46
		).normalized()
	else:
		reposition_direction = side_direction
	reposition_side *= -1.0
	var phase_scale := 0.82 if phase_index > 1 else 1.0
	reposition_timer = maxf(reposition_duration * phase_scale, 0.08)
	anchor_timer = maxf(anchor_duration * phase_scale, 0.10)

func _get_next_scheduled_pattern() -> StringName:
	if phase_index > 1:
		return (
			&"bone_shards"
			if pattern_sequence_index % 2 == 1
			else &"bone_mortar"
		)
	return (
		&"bone_shards"
		if pattern_sequence_index % 3 == 2
		else &"bone_mortar"
	)

func _execute_pattern(pattern_id: StringName, direction: Vector2) -> void:
	if pattern_id == &"bone_shards":
		perform_bone_shards()
	else:
		perform_bone_mortar(direction)
	pattern_sequence_index += 1

func _get_telegraph_duration(pattern_id: StringName) -> float:
	if pattern_id == &"bone_shards":
		return maxf(bone_shards_telegraph_duration, 0.01)
	return maxf(bone_mortar_telegraph_duration, 0.01)

func _resolve_attack_direction(direction_override: Vector2) -> Vector2:
	var direction := direction_override.normalized()
	if direction.is_zero_approx():
		direction = get_target_direction()
	return direction
