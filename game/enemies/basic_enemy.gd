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
@export var attack_cooldown: float = 0.85
@export var target_refresh_interval: float = 0.20
@export var loot_table: LootTable = preload("res://game/drops/default_enemy_loot.tres")

@onready var visual := $Visual as Polygon2D
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

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("damageable_targets")
	_apply_wave_scaling()
	health_component.damaged.connect(_on_health_changed)
	health_component.healed.connect(_on_health_changed)
	health_component.died.connect(_on_died)
	_update_health_bar()

func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
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
	var applied_damage: int = health_system.apply_damage(target, attack_damage)
	if applied_damage > 0:
		attacked.emit(target, applied_damage)

func _set_state(next_state: State) -> void:
	if current_state == next_state:
		return
	var previous_state := get_state_name()
	current_state = next_state
	state_changed.emit(previous_state, get_state_name())

func _on_health_changed(_amount: int, _current_health: int, _max_health: int) -> void:
	_update_health_bar()

func _on_died() -> void:
	_set_state(State.DEAD)
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	visual.modulate = Color(0.35, 0.35, 0.35, 0.55)
	health_bar.hide()

	var drop_system = get_tree().get_first_node_in_group("drop_system")
	if drop_system != null and drop_system.has_method("spawn_drops_deferred"):
		drop_system.spawn_drops_deferred(self, loot_table, global_position)

	died.emit(self)
	queue_free()

func _update_health_bar() -> void:
	var ratio := health_component.get_health_ratio()
	health_bar.points = PackedVector2Array([
		Vector2(-22.0, -30.0),
		Vector2(-22.0 + 44.0 * ratio, -30.0)
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
