extends CharacterBody2D
class_name BasicBoss

signal phase_changed(phase_index: int)
signal target_changed(target: Node)
signal attack_pattern_started(pattern_id: StringName, projectile_count: int)
signal died(boss: Node)

@export var boss_id: StringName = &"wave_warden"
@export var display_name: String = "Wave Warden"
@export var move_speed: float = 82.0
@export var acceleration: float = 520.0
@export var preferred_distance: float = 250.0
@export var retreat_distance: float = 150.0
@export var target_refresh_interval: float = 0.20
@export var attack_cooldown: float = 1.35
@export var phase_two_health_ratio: float = 0.50
@export var aimed_projectile_count: int = 3
@export var aimed_spread_radians: float = 0.16
@export var radial_projectile_count: int = 12
@export var projectile_damage: int = 10
@export var projectile_speed: float = 270.0
@export var projectile_scene: PackedScene = preload("res://game/projectiles/boss_projectile.tscn")
@export var loot_table: LootTable = preload("res://game/drops/boss_loot.tres")

@onready var visual := $Visual as Polygon2D
@onready var core_visual := $Core as Polygon2D
@onready var health_component := $HealthComponent as HealthComponent

var phase_index: int = 1
var target: Node2D
var target_refresh_timer: float = 0.0
var attack_timer: float = 0.0
var phase_two_pattern_index: int = 0
var strafe_sign: float = 1.0
var wave_index: int = 0
var health_multiplier: float = 1.0
var damage_multiplier: float = 1.0
var is_dead: bool = false

func configure_boss(config: Dictionary) -> void:
	wave_index = int(config.get("wave_index", 0))
	health_multiplier = maxf(float(config.get("health_multiplier", 1.0)), 0.01)
	damage_multiplier = maxf(float(config.get("damage_multiplier", 1.0)), 0.01)

func _ready() -> void:
	add_to_group("bosses")
	add_to_group("damageable_targets")
	_apply_scaling()
	health_component.damaged.connect(_on_damaged)
	health_component.died.connect(_on_died)
	attack_timer = attack_cooldown * 0.65

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	target_refresh_timer = maxf(target_refresh_timer - delta, 0.0)
	attack_timer = maxf(attack_timer - delta, 0.0)
	if target_refresh_timer <= 0.0 or not _is_valid_target(target):
		_select_target()
		target_refresh_timer = target_refresh_interval

	if target == null:
		velocity = velocity.move_toward(Vector2.ZERO, acceleration * delta)
		move_and_slide()
		return

	_update_movement(delta)
	if attack_timer <= 0.0:
		_perform_scheduled_pattern()

func perform_aimed_volley() -> int:
	if not _is_valid_target(target):
		_select_target()
	if target == null:
		return 0

	var projectile_system := _get_projectile_system()
	if projectile_system == null:
		return 0
	var base_direction := global_position.direction_to(target.global_position)
	var center := float(aimed_projectile_count - 1) * 0.5
	for index in range(aimed_projectile_count):
		var angle_offset := (float(index) - center) * aimed_spread_radians
		projectile_system.spawn_projectile(
			global_position + base_direction * 42.0,
			base_direction.rotated(angle_offset),
			projectile_speed,
			self,
			projectile_scene,
			projectile_damage,
			&"boss_aimed"
		)
	attack_pattern_started.emit(&"aimed_volley", aimed_projectile_count)
	return aimed_projectile_count

func perform_radial_burst() -> int:
	var projectile_system := _get_projectile_system()
	if projectile_system == null:
		return 0
	for index in range(radial_projectile_count):
		var direction := Vector2.RIGHT.rotated(
			TAU * float(index) / float(radial_projectile_count)
		)
		projectile_system.spawn_projectile(
			global_position + direction * 42.0,
			direction,
			projectile_speed * 0.88,
			self,
			projectile_scene,
			maxi(1, roundi(float(projectile_damage) * 0.75)),
			&"boss_radial"
		)
	attack_pattern_started.emit(&"radial_burst", radial_projectile_count)
	return radial_projectile_count

func _update_movement(delta: float) -> void:
	var direction := global_position.direction_to(target.global_position)
	var distance := global_position.distance_to(target.global_position)
	var desired_velocity := Vector2.ZERO
	if distance > preferred_distance:
		desired_velocity = direction * move_speed
	elif distance < retreat_distance:
		desired_velocity = -direction * move_speed
	else:
		desired_velocity = direction.orthogonal() * move_speed * 0.65 * strafe_sign
	velocity = velocity.move_toward(desired_velocity, acceleration * delta)
	move_and_slide()

func _perform_scheduled_pattern() -> void:
	if phase_index == 1:
		perform_aimed_volley()
	else:
		if phase_two_pattern_index % 2 == 0:
			perform_radial_burst()
		else:
			perform_aimed_volley()
		phase_two_pattern_index += 1
		strafe_sign *= -1.0
	attack_timer = attack_cooldown if phase_index == 1 else attack_cooldown * 0.78

func _select_target() -> void:
	var nearest_target: Node2D
	var nearest_distance := INF
	for candidate in get_tree().get_nodes_in_group("players"):
		if not candidate is Node2D or not _is_valid_target(candidate as Node2D):
			continue
		var distance := global_position.distance_to((candidate as Node2D).global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_target = candidate as Node2D
	if target == nearest_target:
		return
	target = nearest_target
	target_changed.emit(target)

func _is_valid_target(candidate: Node2D) -> bool:
	if candidate == null or not is_instance_valid(candidate) or candidate.is_queued_for_deletion():
		return false
	var candidate_health := candidate.get_node_or_null("HealthComponent") as HealthComponent
	return candidate_health != null and candidate_health.is_alive()

func _on_damaged(_amount: int, _current_health: int, _max_health: int) -> void:
	if phase_index == 1 and health_component.get_health_ratio() <= phase_two_health_ratio:
		phase_index = 2
		attack_timer = minf(attack_timer, 0.25)
		visual.color = Color(0.92, 0.22, 0.48, 1.0)
		core_visual.color = Color(1.0, 0.78, 0.22, 1.0)
		phase_changed.emit(phase_index)

func _on_died() -> void:
	if is_dead:
		return
	is_dead = true
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	var drop_system = get_tree().get_first_node_in_group("drop_system")
	if drop_system != null:
		drop_system.spawn_drops(self, loot_table, global_position)
	died.emit(self)
	queue_free()

func _apply_scaling() -> void:
	health_component.max_health = maxi(
		1,
		roundi(float(health_component.max_health) * health_multiplier)
	)
	health_component.reset_health()
	projectile_damage = maxi(1, roundi(float(projectile_damage) * damage_multiplier))

func _get_projectile_system() -> ProjectileSystem:
	return get_tree().get_first_node_in_group("projectile_system") as ProjectileSystem
