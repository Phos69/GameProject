extends Node
class_name WaveManager

signal wave_started(wave_index: int)
signal wave_completed(wave_index: int)
signal boss_wave_requested(wave_index: int)

@export var boss_wave_interval: int = 5

var current_wave: int = 0
var wave_running: bool = false

func _ready() -> void:
	add_to_group("wave_manager")

func start_next_wave() -> void:
	current_wave += 1
	wave_running = true
	wave_started.emit(current_wave)
	if should_spawn_boss(current_wave):
		boss_wave_requested.emit(current_wave)

func complete_current_wave() -> void:
	if not wave_running:
		return
	wave_running = false
	wave_completed.emit(current_wave)

func should_spawn_boss(wave_index: int) -> bool:
	return boss_wave_interval > 0 and wave_index > 0 and wave_index % boss_wave_interval == 0
