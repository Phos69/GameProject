extends Node
class_name RpgPlayerComponent

signal character_changed(character_id: StringName, profile: Dictionary)
signal stats_changed()
signal experience_changed(experience: int, level: int, experience_to_next: int)
signal leveled_up(level: int)

var character_id: StringName = &""
var character_profile: Dictionary = {}
var level: int = 1
var experience: int = 0
var experience_to_next_level: int = 45

const MAX_HP_PER_LEVEL: int = 10
const ATTACK_PER_LEVEL: int = 2
const DEFENSE_PER_LEVEL: int = 1

func apply_character(next_character_id: StringName) -> bool:
	if not RpgCharacterRegistry.is_character_available(next_character_id):
		next_character_id = RpgCharacterRegistry.DEFAULT_CHARACTER_ID
	character_id = next_character_id
	character_profile = RpgCharacterRegistry.get_character_profile(character_id)
	reset_run_progression()
	character_changed.emit(character_id, character_profile.duplicate(true))
	stats_changed.emit()
	return true

func clear_character() -> void:
	character_id = &""
	character_profile = {}
	reset_run_progression()
	character_changed.emit(character_id, {})
	stats_changed.emit()

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

func reset_run_progression() -> void:
	level = 1
	experience = 0
	experience_to_next_level = 45
	experience_changed.emit(experience, level, experience_to_next_level)

func add_experience(amount: int) -> void:
	if amount <= 0 or not has_character():
		return
	experience += amount
	while experience >= experience_to_next_level:
		experience -= experience_to_next_level
		level += 1
		experience_to_next_level = _experience_required_for_level(level)
		leveled_up.emit(level)
		stats_changed.emit()
	experience_changed.emit(experience, level, experience_to_next_level)

func get_max_hp() -> int:
	return int(character_profile.get("max_hp", 100)) + (level - 1) * MAX_HP_PER_LEVEL

func get_attack() -> int:
	return int(character_profile.get("attack", 0)) + (level - 1) * ATTACK_PER_LEVEL

func get_defense() -> int:
	return int(character_profile.get("defense", 0)) + (level - 1) * DEFENSE_PER_LEVEL

func get_speed_multiplier() -> float:
	return maxf(float(character_profile.get("speed", 1.0)), 0.10)

func get_reload_speed_multiplier() -> float:
	return maxf(float(character_profile.get("reload_speed", 1.0)), 0.10)

func get_experience_ratio() -> float:
	if experience_to_next_level <= 0:
		return 0.0
	return clampf(
		float(experience) / float(experience_to_next_level),
		0.0,
		1.0
	)

func resolve_outgoing_damage(
	weapon_damage: int,
	target: Node,
	_hit_position: Vector2 = Vector2.ZERO,
	_source_id: StringName = &""
) -> int:
	if not has_character():
		return maxi(weapon_damage, 1)
	var target_defense := _get_target_defense(target)
	return maxi(1, weapon_damage + get_attack() - target_defense)

func resolve_incoming_damage(raw_damage: int, _source: Node = null) -> int:
	if not has_character():
		return maxi(raw_damage, 0)
	return maxi(1, raw_damage - get_defense())

func get_stats_text() -> String:
	if not has_character():
		return "ATK 0  DEF 0  SPD 1.00"
	return "ATK %d  DEF %d  SPD %.2f" % [
		get_attack(),
		get_defense(),
		get_speed_multiplier()
	]

func get_selection_summary() -> String:
	if not has_character():
		return "Generic survivor"
	return "%s  %s  %s" % [
		get_display_name(),
		get_class_name(),
		get_base_weapon_name()
	]

func _experience_required_for_level(next_level: int) -> int:
	return 45 + maxi(next_level - 1, 0) * 20

func _get_target_defense(target: Node) -> int:
	if target == null:
		return 0
	var value: Variant = target.get("defense")
	if value == null:
		return 0
	return maxi(roundi(float(value)), 0)
