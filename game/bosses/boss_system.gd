extends Node
class_name BossSystem

signal boss_requested(mode_id: StringName, reason: StringName)
signal boss_spawned(boss: Node)
signal boss_defeated(mode_id: StringName)

@export var boss_scene: PackedScene

func _ready() -> void:
	add_to_group("boss_system")

func request_boss(mode_id: StringName, reason: StringName, position: Vector2 = Vector2.ZERO, parent: Node = null) -> Node:
	boss_requested.emit(mode_id, reason)
	if boss_scene == null:
		return null

	var boss := boss_scene.instantiate()
	if boss is Node2D:
		(boss as Node2D).global_position = position

	var target_parent := parent if parent != null else get_tree().current_scene
	if target_parent != null:
		target_parent.add_child(boss)
	boss_spawned.emit(boss)
	return boss

func notify_boss_defeated(mode_id: StringName) -> void:
	boss_defeated.emit(mode_id)

