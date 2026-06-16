extends Resource
class_name RpgCharacterData

@export var character_id: StringName = &""
@export var display_name: String = ""
@export var hero_name: String = ""
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
@export var portrait_full_path: String = ""
@export var portrait_hud_path: String = ""
@export var gameplay_palette_id: String = ""
@export var sprite_sheet_path: String = ""
@export var weapon_sprite_path: String = ""
@export var passive_icon_path: String = ""
@export var super_icon_path: String = ""
@export var animation_profile_id: String = ""
@export var palette_primary: Color = Color(0.18, 0.74, 0.95, 1.0)
@export var palette_secondary: Color = Color(0.72, 0.84, 0.92, 1.0)
@export var palette_accent: Color = Color(1.0, 0.80, 0.34, 1.0)

func to_profile() -> Dictionary:
	return {
		"id": character_id,
		"display_name": display_name,
		"hero_name": hero_name,
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
		"difficulty": difficulty,
		"portrait_full_path": portrait_full_path,
		"portrait_hud_path": portrait_hud_path,
		"gameplay_palette_id": gameplay_palette_id,
		"sprite_sheet_path": sprite_sheet_path,
		"weapon_sprite_path": weapon_sprite_path,
		"passive_icon_path": passive_icon_path,
		"super_icon_path": super_icon_path,
		"animation_profile_id": animation_profile_id,
		"palette_primary": palette_primary,
		"palette_secondary": palette_secondary,
		"palette_accent": palette_accent
	}
