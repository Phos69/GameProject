extends Node
class_name BaseGameMode

signal mode_started(mode_id: StringName)
signal mode_stopped(mode_id: StringName)
signal boss_requested(mode_id: StringName, reason: StringName)

@export var mode_id: StringName = &"base"

var is_running: bool = false

func start_mode(_context: Dictionary = {}) -> void:
	if is_running:
		return
	is_running = true
	mode_started.emit(mode_id)

func stop_mode() -> void:
	if not is_running:
		return
	is_running = false
	mode_stopped.emit(mode_id)

func request_boss(reason: StringName) -> void:
	boss_requested.emit(mode_id, reason)
