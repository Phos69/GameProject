extends Resource
class_name RpgCharacterData

@export var character_id: StringName = &""
@export var display_name: String = ""
@export var class_label: String = ""
@export var base_weapon_id: StringName = &""
@export var base_weapon_name: String = ""
@export var max_hp: int = 100
@export var attack: int = 0
@export var defense: int = 0
@export var speed: float = 1.0
@export var reload_speed: float = 1.0
@export var adrenaline_gain: float = 1.0
@export var crit_chance: float = 0.0
@export var crit_multiplier: float = 1.0
@export var passive_id: StringName = &""
@export var passive_name: String = ""
@export_multiline var passive_description: String = ""
@export var super_id: StringName = &""
@export var super_name: String = ""
@export_multiline var super_description: String = ""
@export var difficulty: String = "Media"

func to_profile() -> Dictionary:
	return {
		"id": character_id,
		"display_name": display_name,
		"class_name": class_label,
		"base_weapon_id": base_weapon_id,
		"base_weapon_name": base_weapon_name,
		"max_hp": max_hp,
		"attack": attack,
		"defense": defense,
		"speed": speed,
		"reload_speed": reload_speed,
		"adrenaline_gain": adrenaline_gain,
		"crit_chance": crit_chance,
		"crit_multiplier": crit_multiplier,
		"passive_id": passive_id,
		"passive_name": passive_name,
		"passive_description": passive_description,
		"super_id": super_id,
		"super_name": super_name,
		"super_description": super_description,
		"difficulty": difficulty
	}
