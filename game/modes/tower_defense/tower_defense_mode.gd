extends BaseGameMode
class_name TowerDefenseMode

@export var boss_wave_interval: int = 5

func _ready() -> void:
	mode_id = &"tower_defense"

func should_spawn_boss_for_wave(wave_index: int) -> bool:
	return boss_wave_interval > 0 and wave_index % boss_wave_interval == 0
