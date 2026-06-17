extends Node
class_name PlayerDodgeComponent

signal dodge_started(direction: Vector2, target_position: Vector2, crosses_gap: bool)
signal dodge_finished()

@export_range(32.0, 280.0, 4.0) var dodge_distance: float = 132.0
@export_range(0.05, 0.6, 0.01) var dodge_duration: float = 0.22
@export_range(0.1, 3.0, 0.05) var cooldown: float = 0.78
@export_range(0.0, 1.0, 0.05) var invulnerability_start_ratio: float = 0.18
@export_range(0.0, 1.0, 0.05) var invulnerability_end_ratio: float = 0.72
@export var can_cross_gap: bool = true
@export_range(24.0, 220.0, 4.0) var max_gap_cross_distance: float = 156.0
@export_range(4, 24, 1) var trajectory_samples: int = 10
@export_range(0.10, 0.80, 0.05) var invalid_roll_distance_ratio: float = 0.35

var is_dodging: bool = false
var cooldown_timer: float = 0.0
var dodge_time_left: float = 0.0
var start_position: Vector2 = Vector2.ZERO
var target_position: Vector2 = Vector2.ZERO
var dodge_direction: Vector2 = Vector2.RIGHT
var current_crosses_gap: bool = false
var invulnerability_active: bool = false
var invulnerability_source_id: StringName = &""

func process_cooldown(delta: float) -> void:
	if cooldown_timer > 0.0 and not is_dodging:
		cooldown_timer = maxf(cooldown_timer - delta, 0.0)

func physics_process_dodge(delta: float) -> bool:
	process_cooldown(delta)
	if not is_dodging:
		return false
	var player := get_parent() as CharacterBody2D
	if player == null:
		_finish_dodge()
		return false
	dodge_time_left = maxf(dodge_time_left - delta, 0.0)
	var elapsed_ratio := 1.0 - (dodge_time_left / maxf(dodge_duration, 0.001))
	_update_invulnerability(elapsed_ratio)
	var eased_ratio := sin(clampf(elapsed_ratio, 0.0, 1.0) * PI * 0.5)
	player.global_position = start_position.lerp(target_position, eased_ratio)
	player.velocity = dodge_direction * (dodge_distance / maxf(dodge_duration, 0.001))
	if dodge_time_left <= 0.0:
		player.global_position = target_position
		player.velocity = Vector2.ZERO
		_finish_dodge()
	return true

func try_start(direction: Vector2) -> bool:
	if is_dodging or cooldown_timer > 0.0:
		return false
	var player := get_parent() as CharacterBody2D
	if player == null:
		return false
	var health_component := player.get_node_or_null("HealthComponent") as HealthComponent
	if health_component != null and health_component.is_incapacitated():
		return false
	var resolved_direction := direction
	if resolved_direction.length_squared() <= 0.01:
		resolved_direction = Vector2.RIGHT
	resolved_direction = resolved_direction.normalized()
	var resolved_target: Variant = _resolve_target(
		player.global_position,
		resolved_direction
	)
	if resolved_target == null:
		return false
	start_position = player.global_position
	target_position = resolved_target as Vector2
	dodge_direction = resolved_direction
	dodge_time_left = dodge_duration
	is_dodging = true
	invulnerability_active = false
	invulnerability_source_id = StringName("dodge_%d" % player.get_instance_id())
	dodge_started.emit(dodge_direction, target_position, current_crosses_gap)
	return true

func get_cooldown_ratio() -> float:
	if cooldown <= 0.0:
		return 0.0
	return clampf(cooldown_timer / cooldown, 0.0, 1.0)

func reset_runtime() -> void:
	_clear_invulnerability()
	is_dodging = false
	cooldown_timer = 0.0
	dodge_time_left = 0.0
	current_crosses_gap = false

func validate_gap_trajectory(
	start: Vector2,
	finish: Vector2,
	obstacle_rects: Array,
	fall_rects: Array,
	landing_rects: Array = [],
	hazard_rects: Array = []
) -> Dictionary:
	var crossed_gap := false
	var blocked := false
	var hazard_blocked := false
	var sample_count := maxi(trajectory_samples, 2)
	for index in range(1, sample_count + 1):
		var ratio := float(index) / float(sample_count)
		var point := start.lerp(finish, ratio)
		if _point_inside_rects(point, obstacle_rects):
			blocked = true
			break
		if _point_inside_rects(point, hazard_rects):
			hazard_blocked = true
			break
		if _point_inside_rects(point, fall_rects):
			crossed_gap = true
	var landing_valid := (
		(landing_rects.is_empty() or _point_inside_rects(finish, landing_rects))
		and not _point_inside_rects(finish, hazard_rects)
	)
	var distance := start.distance_to(finish)
	var valid := (
		not blocked
		and not hazard_blocked
		and landing_valid
		and (
			not crossed_gap
			or (can_cross_gap and distance <= max_gap_cross_distance)
		)
	)
	return {
		"is_valid": valid,
		"crosses_gap": crossed_gap,
		"blocked": blocked,
		"hazard_blocked": hazard_blocked,
		"landing_valid": landing_valid,
		"distance": distance
	}

func _resolve_target(start: Vector2, direction: Vector2) -> Variant:
	var full_target := start + direction * dodge_distance
	var full_report := _validate_world_trajectory(start, full_target)
	if bool(full_report.get("is_valid", false)):
		current_crosses_gap = bool(full_report.get("crosses_gap", false))
		return full_target
	var short_target := start + direction * dodge_distance * invalid_roll_distance_ratio
	var short_report := _validate_world_trajectory(start, short_target)
	if bool(short_report.get("is_valid", false)) and not bool(short_report.get("crosses_gap", false)):
		current_crosses_gap = false
		return short_target
	return null

func _validate_world_trajectory(start: Vector2, finish: Vector2) -> Dictionary:
	var crossed_gap := false
	var obstacle_system := get_tree().get_first_node_in_group("obstacle_system")
	var hazard_system := get_tree().get_first_node_in_group("hazard_system")
	var sample_count := maxi(trajectory_samples, 2)
	for index in range(1, sample_count + 1):
		var ratio := float(index) / float(sample_count)
		var point := start.lerp(finish, ratio)
		if (
			obstacle_system != null
			and obstacle_system.has_method("is_position_blocked")
			and obstacle_system.is_position_blocked(point)
		):
			return {"is_valid": false, "blocked": true, "crosses_gap": crossed_gap}
		if (
			hazard_system != null
			and hazard_system.has_method("is_position_fall_zone")
			and hazard_system.is_position_fall_zone(point)
		):
			crossed_gap = true
		elif (
			hazard_system != null
			and hazard_system.has_method("is_position_hazardous")
			and hazard_system.is_position_hazardous(point)
		):
			return {
				"is_valid": false,
				"blocked": false,
				"hazard_blocked": true,
				"crosses_gap": crossed_gap
			}
	var landing_valid := _is_landing_valid(finish)
	var distance := start.distance_to(finish)
	return {
		"is_valid": (
			landing_valid
			and (
				not crossed_gap
				or (can_cross_gap and distance <= max_gap_cross_distance)
			)
		),
		"blocked": false,
		"crosses_gap": crossed_gap,
		"landing_valid": landing_valid,
		"distance": distance
	}

func _is_landing_valid(position: Vector2) -> bool:
	var obstacle_system := get_tree().get_first_node_in_group("obstacle_system")
	if (
		obstacle_system != null
		and obstacle_system.has_method("is_position_blocked")
		and obstacle_system.is_position_blocked(position)
	):
		return false
	var hazard_system := get_tree().get_first_node_in_group("hazard_system")
	if (
		hazard_system != null
		and hazard_system.has_method("is_position_hazardous")
		and hazard_system.is_position_hazardous(position)
	):
		return false
	return true

func _update_invulnerability(elapsed_ratio: float) -> void:
	var player := get_parent()
	var health_component := (
		player.get_node_or_null("HealthComponent") as HealthComponent
		if player != null
		else null
	)
	if health_component == null:
		return
	var should_be_invulnerable := (
		elapsed_ratio >= invulnerability_start_ratio
		and elapsed_ratio <= invulnerability_end_ratio
	)
	if should_be_invulnerable and not invulnerability_active:
		health_component.add_invulnerability_source(invulnerability_source_id)
		invulnerability_active = true
	elif invulnerability_active and not should_be_invulnerable:
		health_component.remove_invulnerability_source(invulnerability_source_id)
		invulnerability_active = false

func _finish_dodge() -> void:
	_clear_invulnerability()
	is_dodging = false
	dodge_time_left = 0.0
	cooldown_timer = cooldown
	dodge_finished.emit()

func _clear_invulnerability() -> void:
	var player := get_parent()
	var health_component := (
		player.get_node_or_null("HealthComponent") as HealthComponent
		if player != null
		else null
	)
	if health_component != null and invulnerability_active:
		health_component.remove_invulnerability_source(invulnerability_source_id)
	invulnerability_active = false

func _exit_tree() -> void:
	_clear_invulnerability()

func _point_inside_rects(point: Vector2, rects: Array) -> bool:
	for rect_value in rects:
		var rect := rect_value as Rect2
		if rect.has_point(point):
			return true
	return false
