extends CharacterBody2D
class_name TowerDefenseEnemy

signal base_reached(enemy: Node, damage: int)
signal died(enemy: Node)

@export var enemy_id: StringName = &"tower_defense_raider"
@export var move_speed: float = 105.0
@export var acceleration: float = 720.0
@export var base_damage: int = 12
@export var waypoint_tolerance: float = 10.0
@export var loot_table: LootTable = preload("res://game/drops/default_enemy_loot.tres")

@onready var visual := $Visual as Polygon2D
@onready var health_bar := $HealthBar as Line2D
@onready var health_component := $HealthComponent as HealthComponent

var path_points: PackedVector2Array = PackedVector2Array()
var path_index: int = 1
var health_multiplier: float = 1.0
var move_speed_multiplier: float = 1.0
var damage_multiplier: float = 1.0
var is_dead: bool = false

func configure_spawn(config: Dictionary) -> void:
	health_multiplier = maxf(float(config.get("health_multiplier", 1.0)), 0.01)
	move_speed_multiplier = maxf(float(config.get("move_speed_multiplier", 1.0)), 0.01)
	damage_multiplier = maxf(float(config.get("damage_multiplier", 1.0)), 0.01)
	base_damage = maxi(int(config.get("base_damage", base_damage)), 1)
	var configured_path = config.get("path_points", PackedVector2Array())
	if configured_path is PackedVector2Array:
		path_points = configured_path
	elif configured_path is Array:
		for point in configured_path:
			path_points.append(Vector2(point))

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("damageable_targets")
	add_to_group("tower_defense_targets")
	_apply_scaling()
	health_component.damaged.connect(_on_health_changed)
	health_component.healed.connect(_on_health_changed)
	health_component.died.connect(_on_died)
	_update_health_bar()

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if path_points.is_empty() or path_index >= path_points.size():
		_reach_base()
		return

	var target_point := path_points[path_index]
	var travel_distance := move_speed * delta
	if global_position.distance_to(target_point) <= maxf(waypoint_tolerance, travel_distance):
		global_position = target_point
		path_index += 1
		if path_index >= path_points.size():
			_reach_base()
			return
		target_point = path_points[path_index]

	var direction := global_position.direction_to(target_point)
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

func _on_health_changed(_amount: int, _current_health: int, _max_health: int) -> void:
	_update_health_bar()

func _on_died() -> void:
	if is_dead:
		return
	is_dead = true
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	visual.modulate = Color(0.35, 0.35, 0.35, 0.55)
	health_bar.hide()
	var drop_system := get_tree().get_first_node_in_group("drop_system")
	if drop_system != null:
		drop_system.spawn_drops_deferred(self, loot_table, global_position)
	died.emit(self)
	queue_free()

func _apply_scaling() -> void:
	health_component.max_health = maxi(
		1,
		roundi(float(health_component.max_health) * health_multiplier)
	)
	health_component.reset_health()
	move_speed *= move_speed_multiplier
	base_damage = maxi(1, roundi(float(base_damage) * damage_multiplier))

func _update_health_bar() -> void:
	var ratio := health_component.get_health_ratio()
	health_bar.points = PackedVector2Array([
		Vector2(-22.0, -30.0),
		Vector2(-22.0 + 44.0 * ratio, -30.0)
	])
	health_bar.default_color = Color(1.0 - ratio, ratio, 0.18, 1.0)
