extends RefCounted
class_name RpgCharacterRegistry

const DEFAULT_CHARACTER_ID: StringName = &"pistoliere"

const BASE_WEAPON_PATHS: Dictionary = {
	&"bow": "res://game/weapons/rpg_bow.tres",
	&"pistol": "res://game/weapons/rpg_pistol.tres",
	&"axe": "res://game/weapons/rpg_axe.tres",
	&"sword": "res://game/weapons/rpg_sword.tres"
}

const CHARACTER_RESOURCE_PATHS: Dictionary = {
	&"ranger": "res://game/rpg/characters/ranger.tres",
	&"pistoliere": "res://game/rpg/characters/pistoliere.tres",
	&"berserker": "res://game/rpg/characters/berserker.tres",
	&"spadaccino": "res://game/rpg/characters/spadaccino.tres"
}

static func get_character_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for character_id in CHARACTER_RESOURCE_PATHS.keys():
		ids.append(StringName(character_id))
	ids.sort()
	return ids

static func get_character_profiles() -> Array[Dictionary]:
	var profiles: Array[Dictionary] = []
	for character_id in get_character_ids():
		profiles.append(get_character_profile(character_id))
	return profiles

static func get_character_profile(character_id: StringName) -> Dictionary:
	var resolved_id := (
		character_id
		if CHARACTER_RESOURCE_PATHS.has(character_id)
		else DEFAULT_CHARACTER_ID
	)
	var character_data := load(str(CHARACTER_RESOURCE_PATHS[resolved_id])) as RpgCharacterData
	if character_data == null:
		return {}
	return character_data.to_profile()

static func is_character_available(character_id: StringName) -> bool:
	return CHARACTER_RESOURCE_PATHS.has(character_id)

static func get_character_label(character_id: StringName) -> String:
	var profile := get_character_profile(character_id)
	return str(profile.get("display_name", "Pistoliere"))

static func load_base_weapon(weapon_id: StringName) -> WeaponData:
	var path := str(BASE_WEAPON_PATHS.get(weapon_id, ""))
	if path.is_empty():
		return null
	return load(path) as WeaponData
