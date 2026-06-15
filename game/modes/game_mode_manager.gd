extends Node
class_name GameModeManager

signal game_mode_changed(mode_id: StringName)
signal mode_boss_requested(mode_id: StringName, reason: StringName)

@export var default_mode: StringName = GameConstants.MODE_MENU
@export var debug_mode_hotkeys: bool = true

var active_mode_id: StringName = GameConstants.MODE_MENU
var registered_modes: Dictionary = {}

func _ready() -> void:
	add_to_group("game_mode_manager")
	active_mode_id = default_mode
	game_mode_changed.emit(active_mode_id)

func _unhandled_input(event: InputEvent) -> void:
	if not debug_mode_hotkeys or not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_F1:
			set_mode(GameConstants.MODE_SURVIVAL)
		KEY_F5:
			set_mode(GameConstants.MODE_DUNGEON)
		KEY_F6:
			set_mode(GameConstants.MODE_TOWER_DEFENSE)
		_:
			return
	get_viewport().set_input_as_handled()

func register_mode(mode: Node) -> void:
	if mode == null:
		return
	var mode_id := mode.get("mode_id") as StringName
	registered_modes[mode_id] = mode
	var callback := Callable(self, "_on_mode_boss_requested")
	if mode.has_signal("boss_requested") and not mode.is_connected("boss_requested", callback):
		mode.connect("boss_requested", callback)
	if mode_id == active_mode_id and mode.has_method("start_mode"):
		mode.call_deferred("start_mode")

func set_mode(mode_id: StringName, context: Dictionary = {}) -> bool:
	if active_mode_id == mode_id:
		var current_mode: Node = registered_modes.get(active_mode_id)
		if (
			current_mode != null
			and current_mode.has_method("start_mode")
			and not bool(current_mode.get("is_running"))
		):
			current_mode.start_mode(context)
		return true
	if mode_id != GameConstants.MODE_MENU and not registered_modes.has(mode_id):
		return false
	var previous_mode: Node = registered_modes.get(active_mode_id)
	if previous_mode != null and previous_mode.has_method("stop_mode"):
		previous_mode.stop_mode()
	active_mode_id = mode_id
	game_mode_changed.emit(active_mode_id)
	var next_mode: Node = registered_modes.get(active_mode_id)
	if next_mode != null and next_mode.has_method("start_mode"):
		next_mode.start_mode(context)
	return true

func has_mode(mode_id: StringName) -> bool:
	return registered_modes.has(mode_id)

func is_gameplay_active() -> bool:
	return registered_modes.has(active_mode_id)

func request_boss(
	reason: StringName,
	position: Vector2 = Vector2.ZERO,
	parent: Node = null,
	config: Dictionary = {}
) -> Node:
	mode_boss_requested.emit(active_mode_id, reason)
	var boss_system = get_tree().get_first_node_in_group("boss_system")
	if boss_system == null:
		return null
	return boss_system.request_boss(active_mode_id, reason, position, parent, config)

func _on_mode_boss_requested(mode_id: StringName, reason: StringName) -> void:
	mode_boss_requested.emit(mode_id, reason)
	var boss_system = get_tree().get_first_node_in_group("boss_system")
	if boss_system != null:
		boss_system.request_boss(mode_id, reason)
