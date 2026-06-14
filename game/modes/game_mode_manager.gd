extends Node
class_name GameModeManager

signal game_mode_changed(mode_id: StringName)
signal mode_boss_requested(mode_id: StringName, reason: StringName)

@export var default_mode: StringName = &"survival"

var active_mode_id: StringName = &"prototype"
var registered_modes: Dictionary = {}

func _ready() -> void:
	add_to_group("game_mode_manager")
	active_mode_id = default_mode
	game_mode_changed.emit(active_mode_id)

func register_mode(mode: Node) -> void:
	if mode == null:
		return
	var mode_id := mode.get("mode_id") as StringName
	registered_modes[mode_id] = mode
	var callback := Callable(self, "_on_mode_boss_requested")
	if mode.has_signal("boss_requested") and not mode.is_connected("boss_requested", callback):
		mode.connect("boss_requested", callback)

func set_mode(mode_id: StringName) -> void:
	active_mode_id = mode_id
	game_mode_changed.emit(active_mode_id)

func request_boss(reason: StringName) -> Node:
	mode_boss_requested.emit(active_mode_id, reason)
	var boss_system = get_tree().get_first_node_in_group("boss_system")
	if boss_system == null:
		return null
	return boss_system.request_boss(active_mode_id, reason)

func _on_mode_boss_requested(mode_id: StringName, reason: StringName) -> void:
	mode_boss_requested.emit(mode_id, reason)
	var boss_system = get_tree().get_first_node_in_group("boss_system")
	if boss_system != null:
		boss_system.request_boss(mode_id, reason)
