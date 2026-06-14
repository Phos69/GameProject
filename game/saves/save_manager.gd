extends Node
class_name SaveManager

const SAVE_VERSION: int = 1

func _ready() -> void:
	add_to_group("save_manager")

func create_empty_save() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"party": {
			"level": 1,
			"experience": 0,
			"money": 0
		}
	}

