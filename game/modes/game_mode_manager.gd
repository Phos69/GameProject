extends Node
class_name GameModeManager

signal game_mode_changed(mode_id: StringName)
signal game_mode_started(mode_id: StringName)
signal mode_boss_requested(mode_id: StringName, reason: StringName)
signal run_finished(result: Dictionary)

@export var default_mode: StringName = GameConstants.MODE_MENU
@export var debug_mode_hotkeys: bool = true

var active_mode_id: StringName = GameConstants.MODE_MENU
var registered_modes: Dictionary = {}
var mode_contexts: Dictionary = {}
var run_result_active: bool = false
var last_run_result: Dictionary = {}

func _ready() -> void:
	add_to_group("game_mode_manager")
	active_mode_id = default_mode
	game_mode_changed.emit(active_mode_id)

func _unhandled_input(event: InputEvent) -> void:
	# Le hotkey F1/F5/F6/F7 sono uno strumento di sviluppo: nelle build release
	# salterebbero Character Select e permetterebbero un cambio modalita' a
	# meta' caricamento.
	if not debug_mode_hotkeys or not OS.is_debug_build():
		return
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_F1:
			set_mode(GameConstants.MODE_INFINITE_ARENA)
		KEY_F7:
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
		call_deferred("_start_registered_mode", mode_id, {})

func set_mode(mode_id: StringName, context: Dictionary = {}) -> bool:
	run_result_active = false
	if active_mode_id == mode_id:
		var current_mode: Node = registered_modes.get(active_mode_id)
		if (
			current_mode != null
			and current_mode.has_method("start_mode")
			and not bool(current_mode.get("is_running"))
		):
			var restart_context: Dictionary = (
				context
				if not context.is_empty()
				else mode_contexts.get(mode_id, {}) as Dictionary
			)
			mode_contexts[mode_id] = restart_context.duplicate(true)
			current_mode.start_mode(restart_context)
			if bool(current_mode.get("is_running")):
				game_mode_started.emit(active_mode_id)
		return true
	if mode_id != GameConstants.MODE_MENU and not registered_modes.has(mode_id):
		return false
	var previous_mode: Node = registered_modes.get(active_mode_id)
	if previous_mode != null and previous_mode.has_method("stop_mode"):
		previous_mode.stop_mode()
	active_mode_id = mode_id
	if mode_id != GameConstants.MODE_MENU:
		mode_contexts[mode_id] = context.duplicate(true)
	game_mode_changed.emit(active_mode_id)
	var next_mode: Node = registered_modes.get(active_mode_id)
	if next_mode != null and next_mode.has_method("start_mode"):
		next_mode.start_mode(context)
		if bool(next_mode.get("is_running")):
			game_mode_started.emit(active_mode_id)
	return true

func has_mode(mode_id: StringName) -> bool:
	return registered_modes.has(mode_id)

func is_gameplay_active() -> bool:
	if run_result_active or not registered_modes.has(active_mode_id):
		return false
	var active_mode: Node = registered_modes.get(active_mode_id)
	return active_mode != null and bool(active_mode.get("is_running"))

func finish_run(result: Dictionary) -> bool:
	if run_result_active or not registered_modes.has(active_mode_id):
		return false
	last_run_result = result.duplicate(true)
	last_run_result["mode_id"] = active_mode_id
	run_result_active = true
	run_finished.emit(last_run_result.duplicate(true))
	return true

func retry_active_mode() -> bool:
	if not registered_modes.has(active_mode_id):
		return false
	var current_mode: Node = registered_modes.get(active_mode_id)
	if current_mode != null and current_mode.has_method("stop_mode"):
		# Retry keeps the built world parked so a same-seed restart reuses it and
		# only the gameplay layer resets, instead of rebuilding everything.
		current_mode.stop_mode(true)
	run_result_active = false
	last_run_result = {}
	var context := mode_contexts.get(active_mode_id, {}) as Dictionary
	current_mode.start_mode(context.duplicate(true))
	if bool(current_mode.get("is_running")):
		game_mode_started.emit(active_mode_id)
		return true
	return false

func change_to_next_mode() -> bool:
	var modes: Array[StringName] = [
		GameConstants.MODE_INFINITE_ARENA,
		GameConstants.MODE_SURVIVAL,
		GameConstants.MODE_DUNGEON,
		GameConstants.MODE_TOWER_DEFENSE
	]
	var current_index := modes.find(active_mode_id)
	var next_index := (current_index + 1) % modes.size()
	return set_mode(modes[next_index])

func return_to_menu() -> bool:
	var save_manager := get_tree().get_first_node_in_group(
		"save_manager"
	) as SaveManager
	if save_manager != null:
		save_manager.save_game()
	return set_mode(GameConstants.MODE_MENU)

func get_next_mode_id() -> StringName:
	match active_mode_id:
		GameConstants.MODE_INFINITE_ARENA:
			return GameConstants.MODE_SURVIVAL
		GameConstants.MODE_SURVIVAL:
			return GameConstants.MODE_DUNGEON
		GameConstants.MODE_DUNGEON:
			return GameConstants.MODE_TOWER_DEFENSE
		_:
			return GameConstants.MODE_INFINITE_ARENA

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

func _start_registered_mode(mode_id: StringName, context: Dictionary) -> void:
	var mode: Node = registered_modes.get(mode_id)
	if mode == null or not mode.has_method("start_mode"):
		return
	mode.start_mode(context)
	if bool(mode.get("is_running")):
		game_mode_started.emit(mode_id)
