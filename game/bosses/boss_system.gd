extends Node
class_name BossSystem

signal boss_requested(mode_id: StringName, reason: StringName)
signal boss_spawned(boss: Node)
signal boss_defeated(mode_id: StringName)

@export var boss_scene: PackedScene = preload("res://game/bosses/basic_boss.tscn")
@export var boss_container_path: NodePath = NodePath("../../World/Bosses")

var active_boss: Node
var active_mode_id: StringName = &""

func _ready() -> void:
	add_to_group("boss_system")

func request_boss(
	mode_id: StringName,
	reason: StringName,
	position: Vector2 = Vector2.ZERO,
	parent: Node = null,
	config: Dictionary = {}
) -> Node:
	boss_requested.emit(mode_id, reason)
	if is_instance_valid(active_boss) and not active_boss.is_queued_for_deletion():
		return active_boss
	if boss_scene == null:
		return null

	var boss := boss_scene.instantiate()
	if boss.has_method("configure_boss"):
		boss.configure_boss(config)
	if boss is Node2D:
		(boss as Node2D).global_position = position

	var target_parent := parent
	if target_parent == null:
		target_parent = get_node_or_null(boss_container_path)
	if target_parent == null:
		target_parent = get_tree().current_scene
	if target_parent != null:
		target_parent.add_child(boss)
	active_boss = boss
	active_mode_id = mode_id
	if boss.has_signal("died"):
		boss.connect("died", Callable(self, "_on_boss_died"))
	boss.tree_exited.connect(_on_boss_tree_exited.bind(boss))
	boss_spawned.emit(boss)
	return boss

func notify_boss_defeated(mode_id: StringName) -> void:
	boss_defeated.emit(mode_id)

func get_active_boss() -> Node:
	if is_instance_valid(active_boss) and not active_boss.is_queued_for_deletion():
		return active_boss
	return null

func _on_boss_died(_boss: Node) -> void:
	var defeated_mode := active_mode_id
	active_boss = null
	active_mode_id = &""
	notify_boss_defeated(defeated_mode)

func _on_boss_tree_exited(boss: Node) -> void:
	if active_boss == boss:
		active_boss = null
		active_mode_id = &""
