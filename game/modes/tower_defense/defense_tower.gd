extends Node2D
class_name DefenseTower

signal target_acquired(target: Node)
signal fired(target: Node, projectile: Node)

@export var attack_range: float = 260.0
@export var fire_rate: float = 2.5
@export var projectile_damage: int = 16
@export var projectile_speed: float = 460.0
@export var visual_data: WeaponVisualData = preload(
	"res://game/weapons/defense_tower_visual.tres"
)

@onready var visual := $Visual as DefenseTowerVisual

var fire_timer: float = 0.0
var target

func _ready() -> void:
	add_to_group("defense_towers")
	visual.visual_data = visual_data

func _process(delta: float) -> void:
	fire_timer = maxf(fire_timer - delta, 0.0)
	if not _is_valid_target(target):
		target = null
		_select_target()
	if target != null:
		visual.set_aim_direction(
			global_position.direction_to(
				(target as Node2D).global_position
			)
		)
		if fire_timer <= 0.0:
			_fire_at_target()
	else:
		visual.clear_target()

func _select_target() -> void:
	var nearest_target
	var nearest_distance := attack_range
	for candidate in get_tree().get_nodes_in_group("tower_defense_targets"):
		if not _is_valid_target(candidate):
			continue
		var distance := global_position.distance_to((candidate as Node2D).global_position)
		if distance <= nearest_distance:
			nearest_distance = distance
			nearest_target = candidate
	if target == nearest_target:
		return
	target = nearest_target
	if target != null:
		target_acquired.emit(target)

func _is_valid_target(candidate) -> bool:
	if (
		candidate == null
		or not is_instance_valid(candidate)
		or not candidate is Node2D
		or candidate.is_queued_for_deletion()
	):
		return false
	var target_node := candidate as Node2D
	if global_position.distance_to(target_node.global_position) > attack_range:
		return false
	var health_component := target_node.get_node_or_null("HealthComponent") as HealthComponent
	return health_component != null and health_component.is_alive()

func _fire_at_target() -> void:
	var projectile_system := get_tree().get_first_node_in_group("projectile_system") as ProjectileSystem
	if projectile_system == null or not _is_valid_target(target):
		return
	var target_node := target as Node2D
	var direction := global_position.direction_to(target_node.global_position)
	visual.set_aim_direction(direction)
	var projectile_origin := global_position + visual.get_barrel_tip_local()
	var projectile := projectile_system.spawn_projectile(
		projectile_origin,
		direction,
		projectile_speed,
		self,
		null,
		projectile_damage,
		&"defense_tower",
		visual_data
	)
	visual.play_fire()
	fire_timer = 1.0 / maxf(fire_rate, 0.01)
	fired.emit(target, projectile)
