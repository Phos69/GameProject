extends Node
class_name EnemySystem

signal enemy_spawn_requested(enemy_id: StringName, position: Vector2)
signal enemy_spawned(enemy: Node)

@export var enemy_scene: PackedScene

func _ready() -> void:
	add_to_group("enemy_system")

func spawn_enemy(enemy_id: StringName, position: Vector2, parent: Node = null) -> Node:
	enemy_spawn_requested.emit(enemy_id, position)
	if enemy_scene == null:
		return null

	var enemy := enemy_scene.instantiate()
	if enemy is Node2D:
		(enemy as Node2D).global_position = position

	var target_parent := parent if parent != null else get_tree().current_scene
	if target_parent != null:
		target_parent.add_child(enemy)
	enemy_spawned.emit(enemy)
	return enemy

