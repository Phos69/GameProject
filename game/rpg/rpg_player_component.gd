extends Node
class_name RpgPlayerComponent

signal character_changed(character_id: StringName, profile: Dictionary)

var character_id: StringName = &""
var character_profile: Dictionary = {}

func apply_character(next_character_id: StringName) -> bool:
	if not RpgCharacterRegistry.is_character_available(next_character_id):
		next_character_id = RpgCharacterRegistry.DEFAULT_CHARACTER_ID
	character_id = next_character_id
	character_profile = RpgCharacterRegistry.get_character_profile(character_id)
	character_changed.emit(character_id, character_profile.duplicate(true))
	return true

func clear_character() -> void:
	character_id = &""
	character_profile = {}
	character_changed.emit(character_id, {})

func has_character() -> bool:
	return not character_id.is_empty() and not character_profile.is_empty()

func get_display_name() -> String:
	return str(character_profile.get("display_name", "Survivor"))

func get_class_name() -> String:
	return str(character_profile.get("class_name", "Survivor"))

func get_base_weapon_name() -> String:
	return str(character_profile.get("base_weapon_name", "Starter Pistol"))

func get_passive_name() -> String:
	return str(character_profile.get("passive_name", ""))

func get_super_name() -> String:
	return str(character_profile.get("super_name", ""))

func get_selection_summary() -> String:
	if not has_character():
		return "Generic survivor"
	return "%s  %s  %s" % [
		get_display_name(),
		get_class_name(),
		get_base_weapon_name()
	]
