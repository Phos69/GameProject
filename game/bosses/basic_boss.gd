extends CharacterBody2D
class_name BasicBoss

signal phase_changed(phase_index: int)
signal target_changed(target: Node)
signal attack_telegraph_started(
	pattern_id: StringName,
	duration: float,
	direction: Vector2
)
signal attack_telegraph_finished(pattern_id: StringName)
signal attack_pattern_started(pattern_id: StringName, projectile_count: int)
signal base_reached(boss: Node, damage: int)
signal died(boss: Node)

@export var boss_id: StringName = &"wave_warden"
@export var display_name: String = "Wave Warden"
@export var move_speed: float = 82.0
@export var acceleration: float = 520.0
@export var preferred_distance: float = 250.0
@export var retreat_distance: float = 150.0
@export var target_refresh_interval: float = 0.20
@export var attack_cooldown: float = 1.35
@export var aimed_telegraph_duration: float = 0.70
@export var radial_telegraph_duration: float = 0.90
@export var phase_two_health_ratio: float = 0.50
@export var aimed_projectile_count: int = 3
@export var aimed_spread_radians: float = 0.16
@export var radial_projectile_count: int = 12
@export var projectile_damage: int = 10
@export var defense: int = 2
@export var kill_experience: int = 100
@export var projectile_speed: float = 270.0
@export var projectile_scene: PackedScene = preload("res://game/projectiles/boss_projectile.tscn")
@export var aimed_projectile_visual: WeaponVisualData = preload(
	"res://game/weapons/wave_warden_aimed_visual.tres"
)
@export var radial_projectile_visual: WeaponVisualData = preload(
	"res://game/weapons/wave_warden_radial_visual.tres"
)
@export var loot_table: LootTable = preload("res://game/drops/boss_loot.tres")

@onready var visual = $Visual
@onready var telegraph_visual := $TelegraphVisual as BossTelegraphVisual
@onready var health_component := $HealthComponent as HealthComponent

var phase_index: int = 1
var target: Node2D
var target_refresh_timer: float = 0.0
var attack_timer: float = 0.0
var pending_pattern_id: StringName = &""
var pending_pattern_direction: Vector2 = Vector2.ZERO
var pending_pattern_phase: int = 1
var telegraph_timer: float = 0.0
var phase_two_pattern_index: int = 0
var strafe_sign: float = 1.0
var wave_index: int = 0
var health_multiplier: float = 1.0
var damage_multiplier: float = 1.0
var is_dead: bool = false
var path_points: PackedVector2Array = PackedVector2Array()
var path_index: int = 1
var base_damage: int = 40

func configure_boss(config: Dictionary) -> void:
	wave_index = int(config.get("wave_index", 0))
	health_multiplier = maxf(float(config.get("health_multiplier", 1.0)), 0.01)
	damage_multiplier = maxf(float(config.get("damage_multiplier", 1.0)), 0.01)
	base_damage = maxi(int(config.get("base_damage", base_damage)), 1)
	var configured_path = config.get("path_points", PackedVector2Array())
	if configured_path is PackedVector2Array:
		path_points = configured_path
	elif configured_path is Array:
		for point in configured_path:
			path_points.append(Vector2(point))

func _ready() -> void:
	add_to_group("bosses")
	add_to_group("damageable_targets")
	if not path_points.is_empty():
		add_to_group("tower_defense_targets")
	_apply_scaling()
	health_component.damaged.connect(_on_damaged)
	health_component.died.connect(_on_died)
	visual.set_phase(phase_index)
	visual.play_spawn()
	attack_timer = maxf(
		attack_cooldown * 0.65 - aimed_telegraph_duration,
		0.10
	)

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if not path_points.is_empty():
		_update_path_movement(delta)
		return

	target_refresh_timer = maxf(target_refresh_timer - delta, 0.0)
	if target_refresh_timer <= 0.0 or not _is_valid_target(target):
		_select_target()
		target_refresh_timer = target_refresh_interval

	if target == null:
		velocity = velocity.move_toward(Vector2.ZERO, acceleration * delta)
		move_and_slide()
		return

	visual.set_facing(global_position.direction_to(target.global_position))
	_update_movement(delta)
	if not pending_pattern_id.is_empty():
		telegraph_timer = maxf(telegraph_timer - delta, 0.0)
		if telegraph_timer <= 0.0:
			_finish_attack_telegraph()
		return

	attack_timer = maxf(attack_timer - delta, 0.0)
	if attack_timer <= 0.0:
		_start_scheduled_pattern()

func _update_path_movement(delta: float) -> void:
	if path_index >= path_points.size():
		_reach_base()
		return
	var target_point := path_points[path_index]
	var travel_distance := move_speed * delta
	if global_position.distance_to(target_point) <= maxf(12.0, travel_distance):
		global_position = target_point
		path_index += 1
		if path_index >= path_points.size():
			_reach_base()
			return
		target_point = path_points[path_index]
	var direction := global_position.direction_to(target_point)
	visual.set_facing(direction)
	velocity = direction * move_speed
	global_position = global_position.move_toward(target_point, travel_distance)

func _reach_base() -> void:
	if is_dead:
		return
	is_dead = true
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	var tower_defense_manager := get_tree().get_first_node_in_group("tower_defense_manager")
	if tower_defense_manager != null:
		tower_defense_manager.damage_base(base_damage)
	base_reached.emit(self, base_damage)
	queue_free()

func perform_aimed_volley(
	direction_override: Vector2 = Vector2.ZERO
) -> int:
	var projectile_system := _get_projectile_system()
	if projectile_system == null:
		return 0
	var base_direction := direction_override.normalized()
	if base_direction.is_zero_approx():
		if not _is_valid_target(target):
			_select_target()
		if target == null:
			return 0
		base_direction = global_position.direction_to(target.global_position)
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
			&"boss_aimed",
			aimed_projectile_visual
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
			&"boss_radial",
			radial_projectile_visual
		)
	attack_pattern_started.emit(&"radial_burst", radial_projectile_count)
	return radial_projectile_count

func start_attack_telegraph(pattern_id: StringName) -> bool:
	if is_dead or not pending_pattern_id.is_empty():
		return false

	var direction := Vector2.ZERO
	var duration := 0.0
	match pattern_id:
		&"aimed_volley":
			if not _is_valid_target(target):
				_select_target()
			if target == null:
				return false
			direction = global_position.direction_to(target.global_position)
			duration = maxf(aimed_telegraph_duration, 0.01)
			telegraph_visual.begin_aimed(
				direction,
				duration,
				aimed_projectile_count,
				aimed_spread_radians
			)
		&"radial_burst":
			duration = maxf(radial_telegraph_duration, 0.01)
			telegraph_visual.begin_radial(
				duration,
				radial_projectile_count
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

func cancel_attack_telegraph() -> void:
	pending_pattern_id = &""
	pending_pattern_direction = Vector2.ZERO
	pending_pattern_phase = phase_index
	telegraph_timer = 0.0
	telegraph_visual.finish_telegraph()
	visual.clear_attack_charge()

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

func _start_scheduled_pattern() -> void:
	var pattern_id := _get_next_scheduled_pattern()
	if not start_attack_telegraph(pattern_id):
		attack_timer = 0.10

func _finish_attack_telegraph() -> void:
	var pattern_id := pending_pattern_id
	var direction := pending_pattern_direction
	var pattern_phase := pending_pattern_phase
	pending_pattern_id = &""
	pending_pattern_direction = Vector2.ZERO
	pending_pattern_phase = phase_index
	telegraph_timer = 0.0
	telegraph_visual.finish_telegraph()
	visual.clear_attack_charge()
	attack_telegraph_finished.emit(pattern_id)

	_execute_pattern(pattern_id, direction)
	if pattern_phase > 1:
		phase_two_pattern_index += 1
		strafe_sign *= -1.0
	var cooldown := (
		attack_cooldown
		if phase_index == 1
		else attack_cooldown * 0.78
	)
	attack_timer = maxf(
		cooldown - _get_telegraph_duration(
			_get_next_scheduled_pattern()
		),
		0.10
	)

func _get_next_scheduled_pattern() -> StringName:
	if phase_index > 1 and phase_two_pattern_index % 2 == 0:
		return &"radial_burst"
	return &"aimed_volley"

func _execute_pattern(pattern_id: StringName, direction: Vector2) -> void:
	if pattern_id == &"radial_burst":
		perform_radial_burst()
	else:
		perform_aimed_volley(direction)

func _get_telegraph_duration(pattern_id: StringName) -> float:
	if pattern_id == &"radial_burst":
		return maxf(radial_telegraph_duration, 0.01)
	return maxf(aimed_telegraph_duration, 0.01)

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
	visual.play_hurt()
	if phase_index == 1 and health_component.get_health_ratio() <= phase_two_health_ratio:
		phase_index = 2
		attack_timer = 0.0
		visual.set_phase(phase_index)
		telegraph_visual.play_phase_change()
		phase_changed.emit(phase_index)

func _on_died() -> void:
	if is_dead:
		return
	is_dead = true
	cancel_attack_telegraph()
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	_grant_kill_experience()
	var drop_system = get_tree().get_first_node_in_group("drop_system")
	if drop_system != null:
		drop_system.spawn_drops_deferred(self, loot_table, global_position)
	var gameplay_effects := get_tree().get_first_node_in_group(
		"gameplay_effects"
	) as GameplayEffects
	if gameplay_effects != null:
		gameplay_effects.spawn_boss_death(global_position)
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

func _grant_kill_experience() -> void:
	if kill_experience <= 0:
		return
	var health_system := get_tree().get_first_node_in_group(
		"health_system"
	) as HealthSystem
	if health_system == null:
		return
	var killer := health_system.get_last_damage_source(self)
	health_system.clear_last_damage_source(self)
	if killer == null:
		return
	var rpg_component := killer.get_node_or_null(
		"RpgPlayerComponent"
	) as RpgPlayerComponent
	if rpg_component != null:
		rpg_component.add_experience(kill_experience)
		rpg_component.notify_kill_confirmed()
