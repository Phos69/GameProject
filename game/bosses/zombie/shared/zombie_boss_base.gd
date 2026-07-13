extends BasicBoss
class_name ZombieBossBase

const MELEE_ATTACK_SCRIPT := preload("res://game/weapons/melee_attack.gd")

@export var movement_style_id: StringName = &"zombie_boss"
@export var melee_damage: int = 18
@export var melee_active_time: float = 0.12
@export var melee_knockback: float = 150.0
@export var melee_visual: WeaponVisualData

var active_melee_attacks: Array[Node] = []

func _ready() -> void:
	super._ready()
	add_to_group("zombie_bosses")

func get_movement_style_id() -> StringName:
	return movement_style_id

func get_scaled_melee_damage(scale: float = 1.0) -> int:
	return maxi(
		1,
		roundi(float(melee_damage) * damage_multiplier * maxf(scale, 0.01))
	)

func spawn_hostile_melee(
	pattern_id: StringName,
	direction: Vector2,
	shape: StringName,
	range_value: float,
	width_value: float,
	arc_degrees_value: float,
	damage_scale: float = 1.0,
	active_time_value: float = -1.0,
	knockback_value: float = -1.0,
	max_hits: int = GameConstants.MAX_LOCAL_PLAYERS,
	trail_style: StringName = &"heavy_cleave"
) -> MeleeAttack:
	if is_dead:
		return null
	var resolved_direction := direction.normalized()
	if resolved_direction.is_zero_approx():
		resolved_direction = Vector2.RIGHT
	var attack := MELEE_ATTACK_SCRIPT.new() as MeleeAttack
	if attack == null:
		return null
	attack.configure(
		global_position,
		resolved_direction,
		self,
		get_scaled_melee_damage(damage_scale),
		pattern_id,
		shape,
		range_value,
		width_value,
		arc_degrees_value,
		0.0,
		melee_active_time if active_time_value < 0.0 else active_time_value,
		melee_knockback if knockback_value < 0.0 else knockback_value,
		0.0,
		maxi(max_hits, 1),
		melee_visual,
		trail_style,
		pattern_id,
		&"players",
		GameConstants.LAYER_BODIES
	)
	var root := get_tree().current_scene
	if root == null:
		root = get_parent()
	if root == null:
		root = get_tree().root
	root.add_child(attack)
	active_melee_attacks.append(attack)
	attack.tree_exited.connect(_on_melee_attack_exited.bind(attack))
	attack_pattern_started.emit(pattern_id, 1)
	return attack

func spawn_hostile_projectile(
	direction: Vector2,
	speed_scale: float,
	damage_scale: float,
	source_id: StringName,
	projectile_visual: WeaponVisualData,
	arc_height: float = 0.0,
	origin_offset: float = 44.0
) -> Projectile:
	var projectile_system := _get_projectile_system()
	var resolved_direction := direction.normalized()
	if projectile_system == null or resolved_direction.is_zero_approx():
		return null
	var projectile := projectile_system.spawn_projectile(
		global_position + resolved_direction * origin_offset,
		resolved_direction,
		projectile_speed * maxf(speed_scale, 0.05),
		self,
		projectile_scene,
		maxi(1, roundi(float(projectile_damage) * maxf(damage_scale, 0.01))),
		source_id,
		projectile_visual
	) as Projectile
	if projectile != null and arc_height > 0.0:
		projectile.set_arc_height(arc_height)
	return projectile

func get_target_direction() -> Vector2:
	if not _is_valid_target(target):
		_select_target()
	if target == null:
		return Vector2.ZERO
	return global_position.direction_to(target.global_position)

func get_target_distance() -> float:
	if not _is_valid_target(target):
		_select_target()
	if target == null:
		return INF
	return global_position.distance_to(target.global_position)

func move_toward_velocity(
	desired_velocity: Vector2,
	delta: float,
	acceleration_scale: float = 1.0
) -> void:
	velocity = velocity.move_toward(
		desired_velocity,
		acceleration * maxf(acceleration_scale, 0.01) * delta
	)
	move_and_slide()

func stop_for_telegraph(delta: float) -> bool:
	if pending_pattern_id.is_empty():
		return false
	move_toward_velocity(Vector2.ZERO, delta, 1.35)
	return true

func _on_died() -> void:
	_cancel_active_melee_attacks()
	super._on_died()

func _exit_tree() -> void:
	_cancel_active_melee_attacks()

func _cancel_active_melee_attacks() -> void:
	for attack in active_melee_attacks:
		if is_instance_valid(attack) and not attack.is_queued_for_deletion():
			attack.queue_free()
	active_melee_attacks.clear()

func _on_melee_attack_exited(attack: Node) -> void:
	active_melee_attacks.erase(attack)
