extends Node
class_name EnemySystem

signal enemy_spawn_requested(enemy_id: StringName, position: Vector2)
signal enemy_spawned(enemy: Node)
signal enemy_died(enemy: Node)

@export var enemy_scene: PackedScene = preload("res://game/enemies/basic_enemy.tscn")
@export var enemy_container_path: NodePath = NodePath("../../World/Enemies")
@export var spawn_initial_enemies: bool = false
@export var initial_spawn_points: Array[Vector2] = []

var active_enemies: Array[Node] = []
var registered_enemy_scenes: Dictionary = {}

func _ready() -> void:
	add_to_group("enemy_system")
	if spawn_initial_enemies:
		call_deferred("_spawn_initial_enemies")

func register_enemy_scene(enemy_id: StringName, scene: PackedScene) -> void:
	if enemy_id.is_empty() or scene == null:
		return
	registered_enemy_scenes[enemy_id] = scene

func spawn_enemy(
	enemy_id: StringName,
	position: Vector2,
	parent: Node = null,
	spawn_config: Dictionary = {}
) -> Node:
	enemy_spawn_requested.emit(enemy_id, position)
	var scene := registered_enemy_scenes.get(enemy_id, enemy_scene) as PackedScene
	if scene == null:
		return null

	var enemy := scene.instantiate()
	if enemy.has_method("configure_spawn"):
		enemy.configure_spawn(spawn_config)
	elif enemy is BasicEnemy:
		(enemy as BasicEnemy).enemy_id = enemy_id
		(enemy as BasicEnemy).configure_wave_scaling(spawn_config)
	if enemy is Node2D:
		(enemy as Node2D).global_position = position

	var target_parent := parent
	if target_parent == null:
		target_parent = get_node_or_null(enemy_container_path)
	if target_parent == null:
		target_parent = get_tree().current_scene
	if target_parent != null:
		target_parent.add_child(enemy)
	active_enemies.append(enemy)
	if enemy.has_signal("died"):
		enemy.connect("died", Callable(self, "_on_enemy_died"))
	enemy.tree_exited.connect(_on_enemy_tree_exited.bind(enemy))
	enemy_spawned.emit(enemy)
	return enemy

func get_active_enemies() -> Array[Node]:
	var result: Array[Node] = []
	for enemy in active_enemies:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			result.append(enemy)
	return result

func _spawn_initial_enemies() -> void:
	for spawn_position in initial_spawn_points:
		spawn_enemy(&"basic_zombie", spawn_position)

func _on_enemy_died(enemy: Node) -> void:
	active_enemies.erase(enemy)
	enemy_died.emit(enemy)

func _on_enemy_tree_exited(enemy: Node) -> void:
	active_enemies.erase(enemy)
