extends CharacterBody2D
class_name BasicEnemy

signal state_changed(previous_state: StringName, current_state: StringName)
signal target_changed(target: Node)
signal attacked(target: Node, damage: int)
signal died(enemy: Node)

enum State {
	IDLE,
	CHASE,
	ATTACK,
	DEAD
}

@export var enemy_id: StringName = &"basic_zombie"
@export var move_speed: float = 95.0
@export var acceleration: float = 650.0
@export var detection_range: float = 900.0
@export var attack_range: float = 42.0
@export var attack_damage: int = 8
@export var defense: int = 0
@export var kill_experience: int = 5
@export var attack_cooldown: float = 0.85
@export var target_refresh_interval: float = 0.20
@export var health_bar_width: float = 44.0
@export var health_bar_y: float = -30.0
@export var loot_table: LootTable = preload("res://game/drops/default_enemy_loot.tres")

@onready var visual := $Visual as ZombieVisual
@onready var health_bar := $HealthBar as Line2D
@onready var health_component := $HealthComponent as HealthComponent

var current_state: State = State.IDLE
var target: Node2D
var attack_timer: float = 0.0
var target_refresh_timer: float = 0.0
var wave_index: int = 0
var health_multiplier: float = 1.0
var move_speed_multiplier: float = 1.0
var damage_multiplier: float = 1.0
var resource_drop_modifier: float = 1.0
var enemy_profile: BiomeEnemyProfile
var incoming_damage_multiplier: float = 1.0
var contact_status_id: StringName = &""
var contact_status_duration: float = 0.0
var contact_movement_multiplier: float = 1.0
var contact_damage_per_tick: int = 0
var death_hazard_id: StringName = &""
var death_hazard_duration: float = 0.0
var death_hazard_radius: float = 68.0
var emerge_timer: float = 0.0
var active_collision_layer: int = 2

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("damageable_targets")
	active_collision_layer = collision_layer
	_apply_wave_scaling()
	_apply_profile_visual()
	if emerge_timer > 0.0:
		collision_layer = 0
		visual.modulate = Color(1.0, 1.0, 1.0, 0.28)
	health_component.damaged.connect(_on_health_changed)
	health_component.healed.connect(_on_health_changed)
	health_component.died.connect(_on_died)
	_update_health_bar()

func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
		return
	if emerge_timer > 0.0:
		emerge_timer = maxf(emerge_timer - delta, 0.0)
		velocity = Vector2.ZERO
		if emerge_timer <= 0.0:
			collision_layer = active_collision_layer
			visual.modulate = Color.WHITE
		_set_state(State.CHASE)
		return

	attack_timer = maxf(attack_timer - delta, 0.0)
	target_refresh_timer = maxf(target_refresh_timer - delta, 0.0)
	if target_refresh_timer <= 0.0 or not _is_valid_target(target):
		_select_target()
		target_refresh_timer = target_refresh_interval

	if target == null:
		_set_state(State.IDLE)
		velocity = velocity.move_toward(Vector2.ZERO, acceleration * delta)
		move_and_slide()
		_update_visual()
		return

	var distance_to_target := global_position.distance_to(target.global_position)
	if distance_to_target > attack_range:
		_set_state(State.CHASE)
		var direction := global_position.direction_to(target.global_position)
		velocity = velocity.move_toward(direction * move_speed, acceleration * delta)
	else:
		_set_state(State.ATTACK)
		velocity = velocity.move_toward(Vector2.ZERO, acceleration * delta)
		if attack_timer <= 0.0:
			_attack_target()
	move_and_slide()
	_update_visual()

func get_state_name() -> StringName:
	match current_state:
		State.CHASE:
			return &"chase"
		State.ATTACK:
			return &"attack"
		State.DEAD:
			return &"dead"
		_:
			return &"idle"

func configure_wave_scaling(config: Dictionary) -> void:
	wave_index = int(config.get("wave_index", 0))
	health_multiplier = maxf(float(config.get("health_multiplier", 1.0)), 0.01)
	move_speed_multiplier = maxf(float(config.get("move_speed_multiplier", 1.0)), 0.01)
	damage_multiplier = maxf(float(config.get("damage_multiplier", 1.0)), 0.01)
	resource_drop_modifier = maxf(
		float(config.get("resource_drop_modifier", 1.0)),
		0.0
	)

func configure_spawn(config: Dictionary) -> void:
	enemy_id = StringName(config.get("enemy_id", enemy_id))
	enemy_profile = config.get("enemy_profile") as BiomeEnemyProfile
	if enemy_profile != null:
		_apply_enemy_profile(enemy_profile)
	configure_wave_scaling(config)

func modify_incoming_damage(
	amount: int,
	_source_id: StringName = &""
) -> int:
	return maxi(
		1 if amount > 0 else 0,
		roundi(float(maxi(amount, 0)) * incoming_damage_multiplier)
	)

func _select_target() -> void:
	var nearest_target: Node2D
	var nearest_distance := detection_range
	for candidate in get_tree().get_nodes_in_group("players"):
		if not candidate is Node2D or not _is_valid_target(candidate as Node2D):
			continue
		var distance := global_position.distance_to((candidate as Node2D).global_position)
		if distance <= nearest_distance:
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

func _attack_target() -> void:
	if not _is_valid_target(target):
		target = null
		return

	attack_timer = attack_cooldown
	var health_system = get_tree().get_first_node_in_group("health_system")
	if health_system == null:
		return
	var applied_damage: int = health_system.apply_damage(
		target,
		attack_damage,
		self,
		enemy_id,
		global_position
	)
	if applied_damage > 0:
		attacked.emit(target, applied_damage)
		_apply_contact_status(target)

func _set_state(next_state: State) -> void:
	if current_state == next_state:
		return
	var previous_state := get_state_name()
	current_state = next_state
	visual.set_state(get_state_name())
	state_changed.emit(previous_state, get_state_name())

func _on_health_changed(_amount: int, _current_health: int, _max_health: int) -> void:
	_update_health_bar()
	visual.play_hit()

func _on_died() -> void:
	_set_state(State.DEAD)
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	health_bar.hide()
	_grant_kill_experience()

	var drop_system = get_tree().get_first_node_in_group("drop_system")
	if drop_system != null and drop_system.has_method("spawn_drops_deferred"):
		drop_system.spawn_drops_deferred(
			self,
			loot_table,
			global_position,
			null,
			resource_drop_modifier
		)

	_spawn_death_hazard()

	died.emit(self)
	queue_free()

func _update_health_bar() -> void:
	var ratio := health_component.get_health_ratio()
	var half_width := health_bar_width * 0.5
	health_bar.points = PackedVector2Array([
		Vector2(-half_width, health_bar_y),
		Vector2(-half_width + health_bar_width * ratio, health_bar_y)
	])
	var background := get_node_or_null("HealthBarBackground") as Line2D
	if background != null:
		background.points = PackedVector2Array([
			Vector2(-half_width, health_bar_y),
			Vector2(half_width, health_bar_y)
		])
	health_bar.default_color = Color(1.0 - ratio, ratio, 0.18, 1.0)

func _apply_wave_scaling() -> void:
	health_component.max_health = maxi(
		1,
		roundi(float(health_component.max_health) * health_multiplier)
	)
	health_component.reset_health()
	move_speed *= move_speed_multiplier
	attack_damage = maxi(1, roundi(float(attack_damage) * damage_multiplier))

func _update_visual() -> void:
	visual.set_motion(velocity, move_speed)
	if target != null:
		visual.set_facing(global_position.direction_to(target.global_position))

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

func _apply_enemy_profile(profile: BiomeEnemyProfile) -> void:
	move_speed = profile.move_speed
	acceleration = profile.acceleration
	attack_range = profile.attack_range
	attack_damage = profile.attack_damage
	attack_cooldown = profile.attack_cooldown
	kill_experience = profile.kill_experience
	incoming_damage_multiplier = profile.incoming_damage_multiplier
	contact_status_id = profile.contact_status_id
	contact_status_duration = profile.contact_status_duration
	contact_movement_multiplier = profile.contact_movement_multiplier
	contact_damage_per_tick = profile.contact_damage_per_tick
	death_hazard_id = profile.death_hazard_id
	death_hazard_duration = profile.death_hazard_duration
	death_hazard_radius = profile.death_hazard_radius
	emerge_timer = profile.emerge_duration
	var profile_health := get_node_or_null("HealthComponent") as HealthComponent
	if profile_health != null:
		profile_health.max_health = profile.max_health

func _apply_profile_visual() -> void:
	if enemy_profile == null or visual == null:
		return
	visual.configure_biome_style(
		enemy_profile.visual_archetype,
		enemy_profile.theme_id
	)

func _apply_contact_status(target_node: Node) -> void:
	if contact_status_id.is_empty() or contact_status_duration <= 0.0:
		return
	var hazard_system := get_tree().get_first_node_in_group(
		"hazard_system"
	) as HazardSystem
	if hazard_system != null:
		hazard_system.apply_status_to_player(
			target_node,
			contact_status_id,
			contact_status_duration,
			contact_movement_multiplier,
			contact_damage_per_tick
		)

func _spawn_death_hazard() -> void:
	if death_hazard_id.is_empty():
		return
	var hazard_system := get_tree().get_first_node_in_group(
		"hazard_system"
	) as HazardSystem
	if hazard_system == null:
		return
	hazard_system.spawn_runtime_hazard(
		death_hazard_id,
		global_position,
		{
			"lifetime": death_hazard_duration,
			"radius": death_hazard_radius
		}
	)
