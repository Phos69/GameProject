extends Area2D
class_name MeleeAttack

signal hit_target(target: Node, applied_damage: int, hit_position: Vector2)
signal attack_finished()

enum Phase {
	WINDUP,
	ACTIVE,
	DONE
}

var owner_node: Node
var damage: int = 1
var source_id: StringName = &"melee"
var attack_shape: StringName = &"rectangle"
var attack_range: float = 80.0
var attack_width: float = 42.0
var arc_degrees: float = 90.0
var windup_time: float = 0.0
var active_time: float = 0.08
var knockback: float = 0.0
var hitstop_time: float = 0.0
var hitstop_timer: float = 0.0
var max_hit_count: int = 1
var trail_style: StringName = &""
var effect_key: StringName = &""
var visual_data: WeaponVisualData
var attack_direction: Vector2 = Vector2.RIGHT
var phase: int = Phase.WINDUP
var phase_timer: float = 0.0
var age: float = 0.0
var hit_targets: Dictionary = {}
var collision_shape: CollisionShape2D

func configure(
	origin: Vector2,
	direction: Vector2,
	owner_ref: Node,
	damage_amount: int,
	damage_source_id: StringName,
	shape: StringName,
	range_value: float,
	width_value: float,
	arc_degrees_value: float,
	windup_value: float,
	active_value: float,
	knockback_value: float,
	hitstop_value: float,
	max_hits: int,
	weapon_visual_data: WeaponVisualData = null,
	trail_style_value: StringName = &"",
	effect_key_value: StringName = &""
) -> void:
	global_position = origin
	attack_direction = (
		direction.normalized()
		if direction.length_squared() > 0.01
		else Vector2.RIGHT
	)
	rotation = attack_direction.angle()
	owner_node = owner_ref
	damage = maxi(damage_amount, 1)
	source_id = damage_source_id
	attack_shape = shape
	attack_range = maxf(range_value, 1.0)
	attack_width = maxf(width_value, 1.0)
	arc_degrees = clampf(arc_degrees_value, 1.0, 360.0)
	windup_time = maxf(windup_value, 0.0)
	active_time = maxf(active_value, 0.01)
	knockback = maxf(knockback_value, 0.0)
	hitstop_time = maxf(hitstop_value, 0.0)
	max_hit_count = maxi(max_hits, 1)
	visual_data = weapon_visual_data
	trail_style = trail_style_value
	effect_key = effect_key_value

func _ready() -> void:
	z_index = 3
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	monitoring = false
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	_create_collision_shape()
	phase = Phase.WINDUP
	phase_timer = windup_time
	if windup_time <= 0.0:
		_activate()
	queue_redraw()

func _physics_process(delta: float) -> void:
	age += delta
	match phase:
		Phase.WINDUP:
			phase_timer = maxf(phase_timer - delta, 0.0)
			if phase_timer <= 0.0:
				_activate()
		Phase.ACTIVE:
			if hitstop_timer > 0.0:
				hitstop_timer = maxf(hitstop_timer - delta, 0.0)
				queue_redraw()
				return
			_scan_overlaps()
			phase_timer = maxf(phase_timer - delta, 0.0)
			if phase_timer <= 0.0:
				_finish()
		Phase.DONE:
			return
	queue_redraw()

func _draw() -> void:
	var base_color := (
		visual_data.projectile_glow_color
		if visual_data != null
		else Color(1.0, 0.72, 0.24, 0.72)
	)
	var blade_color := (
		visual_data.projectile_color
		if visual_data != null
		else Color(1.0, 0.86, 0.42, 1.0)
	)
	var windup_ratio := (
		1.0 - phase_timer / maxf(windup_time, 0.01)
		if phase == Phase.WINDUP
		else 1.0
	)
	var active_ratio := (
		1.0 - phase_timer / maxf(active_time, 0.01)
		if phase == Phase.ACTIVE
		else 0.0
	)
	if phase == Phase.WINDUP:
		_draw_attack_preview(base_color, windup_ratio)
	elif phase == Phase.ACTIVE:
		_draw_attack_trail(blade_color, base_color, active_ratio)

func _create_collision_shape() -> void:
	if collision_shape == null:
		collision_shape = CollisionShape2D.new()
		add_child(collision_shape)
	collision_shape.position = Vector2.ZERO
	collision_shape.rotation = 0.0
	match attack_shape:
		&"arc":
			var arc := ConvexPolygonShape2D.new()
			arc.points = _arc_points()
			collision_shape.shape = arc
		&"dash":
			var rectangle := RectangleShape2D.new()
			rectangle.size = Vector2(attack_range, attack_width)
			collision_shape.position = Vector2(attack_range * 0.5, 0.0)
			collision_shape.shape = rectangle
		_:
			var rectangle := RectangleShape2D.new()
			rectangle.size = Vector2(attack_range, attack_width)
			collision_shape.position = Vector2(attack_range * 0.5, 0.0)
			collision_shape.shape = rectangle
	collision_shape.disabled = true

func _activate() -> void:
	phase = Phase.ACTIVE
	phase_timer = active_time
	if collision_shape != null:
		collision_shape.disabled = false
	monitoring = true
	_scan_overlaps()

func _finish() -> void:
	if phase == Phase.DONE:
		return
	phase = Phase.DONE
	monitoring = false
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)
	attack_finished.emit()
	queue_free()

func _scan_overlaps() -> void:
	if phase != Phase.ACTIVE or not is_inside_tree():
		return
	for body in get_overlapping_bodies():
		_try_hit_target(body)
	for area in get_overlapping_areas():
		_try_hit_target(area)
	_scan_damageable_targets_by_geometry()

func _on_body_entered(body: Node2D) -> void:
	_try_hit_target(body)

func _on_area_entered(area: Area2D) -> void:
	_try_hit_target(area)

func _try_hit_target(target: Node) -> void:
	if phase != Phase.ACTIVE:
		return
	if target == null or target == owner_node:
		return
	if hit_targets.size() >= max_hit_count:
		return
	var target_id := target.get_instance_id()
	if hit_targets.has(target_id):
		return
	hit_targets[target_id] = true
	var hit_position := global_position
	if target is Node2D:
		hit_position = (target as Node2D).global_position
	var applied_damage := 0
	var health_system := get_tree().get_first_node_in_group(
		"health_system"
	) as HealthSystem
	if health_system != null:
		applied_damage = health_system.apply_damage(
			target,
			damage,
			owner_node,
			source_id,
			hit_position
		)
	else:
		var health_component := target.get_node_or_null(
			"HealthComponent"
		) as HealthComponent
		if health_component != null:
			applied_damage = health_component.apply_damage(damage)
	if applied_damage > 0:
		_apply_knockback(target)
		hitstop_timer = maxf(hitstop_timer, hitstop_time)
	hit_target.emit(target, applied_damage, hit_position)
	if hit_targets.size() >= max_hit_count:
		_finish()

func _scan_damageable_targets_by_geometry() -> void:
	for candidate in get_tree().get_nodes_in_group("damageable_targets"):
		if (
			candidate == owner_node
			or not (candidate is Node2D)
			or not is_instance_valid(candidate)
			or candidate.is_queued_for_deletion()
		):
			continue
		if not _contains_world_point((candidate as Node2D).global_position):
			continue
		_try_hit_target(candidate)

func _contains_world_point(world_position: Vector2) -> bool:
	var local_point := to_local(world_position)
	match attack_shape:
		&"arc":
			if local_point.x < 0.0:
				return false
			if local_point.length() > attack_range:
				return false
			var half_angle := deg_to_rad(arc_degrees * 0.5)
			return absf(local_point.angle()) <= half_angle
		_:
			return (
				local_point.x >= 0.0
				and local_point.x <= attack_range
				and absf(local_point.y) <= attack_width * 0.5
			)

func _apply_knockback(target: Node) -> void:
	if knockback <= 0.0 or not (target is CharacterBody2D):
		return
	var body := target as CharacterBody2D
	var origin := global_position
	if owner_node is Node2D:
		origin = (owner_node as Node2D).global_position
	var direction := origin.direction_to(body.global_position)
	if direction.length_squared() <= 0.01:
		direction = attack_direction
	body.velocity += direction.normalized() * knockback

func _draw_attack_preview(color: Color, ratio: float) -> void:
	var alpha := 0.16 + ratio * 0.24
	match attack_shape:
		&"arc":
			var half_angle := deg_to_rad(arc_degrees * 0.5)
			draw_arc(
				Vector2.ZERO,
				attack_range,
				-half_angle,
				half_angle,
				26,
				Color(color, alpha),
				3.0,
				true
			)
			draw_line(
				Vector2.ZERO,
				Vector2.RIGHT.rotated(-half_angle) * attack_range,
				Color(color, alpha * 0.65),
				2.0,
				true
			)
			draw_line(
				Vector2.ZERO,
				Vector2.RIGHT.rotated(half_angle) * attack_range,
				Color(color, alpha * 0.65),
				2.0,
				true
			)
		_:
			var rect := Rect2(
				Vector2(0.0, -attack_width * 0.5),
				Vector2(attack_range, attack_width)
			)
			draw_rect(rect, Color(color, alpha * 0.40), true)
			draw_rect(rect, Color(color, alpha), false, 2.0)

func _draw_attack_trail(
	blade_color: Color,
	glow_color: Color,
	ratio: float
) -> void:
	var alpha := 1.0 - ratio * 0.42
	match attack_shape:
		&"arc":
			var half_angle := deg_to_rad(arc_degrees * 0.5)
			var start_angle := lerpf(-half_angle, half_angle * 0.10, ratio)
			var end_angle := lerpf(half_angle * 0.10, half_angle, ratio)
			if trail_style == &"heavy_arc":
				draw_arc(
					Vector2.ZERO,
					attack_range * 0.68,
					-half_angle,
					half_angle,
					28,
					Color(glow_color, 0.14 * alpha),
					attack_width * 0.24,
					true
				)
			draw_arc(
				Vector2.ZERO,
				attack_range * 0.86,
				start_angle,
				end_angle,
				28,
				Color(blade_color, 0.84 * alpha),
				maxf(attack_width * 0.08, 5.0),
				true
			)
			for index in range(3):
				var angle := lerpf(-half_angle, half_angle, float(index) / 2.0)
				draw_line(
					Vector2.RIGHT.rotated(angle) * attack_range * 0.28,
					Vector2.RIGHT.rotated(angle) * attack_range,
					Color(glow_color, 0.28 * alpha),
					2.0,
					true
				)
		_:
			var y := lerpf(-attack_width * 0.48, attack_width * 0.48, ratio)
			draw_rect(
				Rect2(
					Vector2(0.0, -attack_width * 0.5),
					Vector2(attack_range, attack_width)
				),
				Color(glow_color, 0.10 * alpha),
				true
			)
			draw_line(
				Vector2(8.0, -attack_width * 0.45),
				Vector2(attack_range, y),
				Color(blade_color, 0.90 * alpha),
				maxf(attack_width * 0.12, 4.0),
				true
			)
			draw_line(
				Vector2(attack_range * 0.26, attack_width * 0.36),
				Vector2(attack_range * 0.92, -attack_width * 0.28),
				Color(glow_color, 0.34 * alpha),
				2.0,
				true
			)

func _arc_points() -> PackedVector2Array:
	var points := PackedVector2Array([Vector2.ZERO])
	var half_angle := deg_to_rad(arc_degrees * 0.5)
	var segments := 10
	for index in range(segments + 1):
		var ratio := float(index) / float(segments)
		var angle := lerpf(-half_angle, half_angle, ratio)
		points.append(Vector2(cos(angle), sin(angle)) * attack_range)
	return points
