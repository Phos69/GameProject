extends RefCounted
class_name RpgCharacterRegistry

const DEFAULT_CHARACTER_ID: StringName = &"pistoliere"

const CHARACTER_PROFILES: Dictionary = {
	&"ranger": {
		"id": &"ranger",
		"display_name": "Ranger",
		"class_name": "Ranger",
		"base_weapon_id": &"bow",
		"base_weapon_name": "Arco",
		"max_hp": 90,
		"attack": 8,
		"defense": 2,
		"speed": 1.05,
		"reload_speed": 1.08,
		"adrenaline_gain": 1.10,
		"crit_chance": 0.12,
		"crit_multiplier": 1.70,
		"passive_id": &"predator_eye",
		"passive_name": "Occhio del Predatore",
		"passive_description": "Piu danno sui bersagli lontani.",
		"super_id": &"arrow_rain",
		"super_name": "Pioggia di Frecce",
		"super_description": "Raffica conica a lungo raggio.",
		"difficulty": "Media"
	},
	&"pistoliere": {
		"id": &"pistoliere",
		"display_name": "Pistoliere",
		"class_name": "Pistoliere",
		"base_weapon_id": &"pistol",
		"base_weapon_name": "Pistola",
		"max_hp": 100,
		"attack": 6,
		"defense": 3,
		"speed": 1.10,
		"reload_speed": 1.0,
		"adrenaline_gain": 1.0,
		"crit_chance": 0.08,
		"crit_multiplier": 1.50,
		"passive_id": &"quick_hand",
		"passive_name": "Mano Veloce",
		"passive_description": "Reload completati aumentano la cadenza.",
		"super_id": &"final_barrage",
		"super_name": "Scarica Finale",
		"super_description": "Fuoco automatico sui nemici vicini.",
		"difficulty": "Facile"
	},
	&"berserker": {
		"id": &"berserker",
		"display_name": "Berserker",
		"class_name": "Berserker",
		"base_weapon_id": &"axe",
		"base_weapon_name": "Ascia",
		"max_hp": 120,
		"attack": 11,
		"defense": 1,
		"speed": 0.92,
		"reload_speed": 0.85,
		"adrenaline_gain": 1.15,
		"crit_chance": 0.05,
		"crit_multiplier": 1.60,
		"passive_id": &"blood_fury",
		"passive_name": "Furia di Sangue",
		"passive_description": "Sotto il 40% HP aumenta il danno.",
		"super_id": &"blood_quake",
		"super_name": "Terremoto di Sangue",
		"super_description": "Colpo ad area attorno al player.",
		"difficulty": "Difficile"
	},
	&"spadaccino": {
		"id": &"spadaccino",
		"display_name": "Spadaccino",
		"class_name": "Spadaccino",
		"base_weapon_id": &"sword",
		"base_weapon_name": "Spada",
		"max_hp": 110,
		"attack": 7,
		"defense": 5,
		"speed": 1.0,
		"reload_speed": 1.05,
		"adrenaline_gain": 1.0,
		"crit_chance": 0.07,
		"crit_multiplier": 1.45,
		"passive_id": &"perfect_guard",
		"passive_name": "Guardia Perfetta",
		"passive_description": "Colpire concede riduzione danno breve.",
		"super_id": &"phantom_blade",
		"super_name": "Lama Fantasma",
		"super_description": "Dash offensivo che attraversa i nemici.",
		"difficulty": "Media"
	}
}

static func get_character_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for character_id in CHARACTER_PROFILES.keys():
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
		if CHARACTER_PROFILES.has(character_id)
		else DEFAULT_CHARACTER_ID
	)
	return (CHARACTER_PROFILES.get(resolved_id, {}) as Dictionary).duplicate(true)

static func is_character_available(character_id: StringName) -> bool:
	return CHARACTER_PROFILES.has(character_id)

static func get_character_label(character_id: StringName) -> String:
	var profile := get_character_profile(character_id)
	return str(profile.get("display_name", "Pistoliere"))
