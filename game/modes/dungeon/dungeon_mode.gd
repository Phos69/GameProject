extends BaseGameMode
class_name DungeonMode

func _ready() -> void:
	mode_id = &"dungeon"

func request_area_boss() -> void:
	request_boss(&"dungeon_area_end")
