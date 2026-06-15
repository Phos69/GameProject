extends Node
class_name RpgPlayerComponent

signal character_changed(character_id: StringName, profile: Dictionary)
signal stats_changed()
signal experience_changed(experience: int, level: int, experience_to_next: int)
signal leveled_up(level: int)
signal passive_state_changed()

var character_id: StringName = &""
var character_profile: Dictionary = {}
var level: int = 1
var experience: int = 0
var experience_to_next_level: int = 45
var quick_hand_timer: float = 0.0
var perfect_guard_timer: float = 0.0
var passive_notice_text: String = ""
var passive_notice_timer: float = 0.0

const MAX_HP_PER_LEVEL: int = 10
const ATTACK_PER_LEVEL: int = 2
const DEFENSE_PER_LEVEL: int = 1
const PASSIVE_PREDATOR_EYE := &"predator_eye"
const PASSIVE_QUICK_HAND := &"quick_hand"
const PASSIVE_BLOOD_FURY := &"blood_fury"
const PASSIVE_PERFECT_GUARD := &"perfect_guard"
const PREDATOR_EYE_MAX_DISTANCE: float = 650.0
const PREDATOR_EYE_MAX_DAMAGE_BONUS: float = 0.30
const PREDATOR_EYE_NOTICE_DURATION: float = 0.85
const QUICK_HAND_DURATION: float = 3.0
const QUICK_HAND_FIRE_RATE_MULTIPLIER: float = 1.20
const BLOOD_FURY_HEALTH_THRESHOLD: float = 0.40
const BLOOD_FURY_DAMAGE_MULTIPLIER: float = 1.25
const PERFECT_GUARD_DURATION: float = 1.5
const PERFECT_GUARD_DAMAGE_MULTIPLIER: float = 0.80

func _process(delta: float) -> void:
	var changed := false
	if quick_hand_timer > 0.0:
		quick_hand_timer = maxf(quick_hand_timer - delta, 0.0)
		changed = changed or quick_hand_timer <= 0.0
	if perfect_guard_timer > 0.0:
		perfect_guard_timer = maxf(perfect_guard_timer - delta, 0.0)
		changed = changed or perfect_guard_timer <= 0.0
	if passive_notice_timer > 0.0:
		passive_notice_timer = maxf(passive_notice_timer - delta, 0.0)
		if passive_notice_timer <= 0.0:
			passive_notice_text = ""
			changed = true
	if changed:
		passive_state_changed.emit()

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
	_reset_passive_state()
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

func get_fire_rate_multiplier() -> float:
	if get_passive_id() == PASSIVE_QUICK_HAND and quick_hand_timer > 0.0:
		return QUICK_HAND_FIRE_RATE_MULTIPLIER
	return 1.0

func get_passive_id() -> StringName:
	return StringName(character_profile.get("passive_id", &""))

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
	var resolved_damage := maxi(1, weapon_damage + get_attack() - target_defense)
	resolved_damage = roundi(
		float(resolved_damage) * _get_outgoing_passive_multiplier(
			target,
			_hit_position
		)
	)
	if get_passive_id() == PASSIVE_PERFECT_GUARD and _can_trigger_guard(target):
		_activate_perfect_guard()
	return maxi(1, resolved_damage)

func resolve_incoming_damage(raw_damage: int, _source: Node = null) -> int:
	if not has_character():
		return maxi(raw_damage, 0)
	var resolved_damage := maxi(1, raw_damage - get_defense())
	if get_passive_id() == PASSIVE_PERFECT_GUARD and perfect_guard_timer > 0.0:
		resolved_damage = roundi(
			float(resolved_damage) * PERFECT_GUARD_DAMAGE_MULTIPLIER
		)
	return maxi(1, resolved_damage)

func notify_reload_finished() -> void:
	if get_passive_id() != PASSIVE_QUICK_HAND:
		return
	quick_hand_timer = QUICK_HAND_DURATION
	passive_state_changed.emit()

func get_active_passive_text() -> String:
	match get_passive_id():
		PASSIVE_QUICK_HAND:
			if quick_hand_timer > 0.0:
				return "MANO VELOCE +20%"
		PASSIVE_PERFECT_GUARD:
			if perfect_guard_timer > 0.0:
				return "GUARDIA -20%"
		PASSIVE_BLOOD_FURY:
			if _is_blood_fury_active():
				return "FURIA +25%"
		PASSIVE_PREDATOR_EYE:
			if passive_notice_timer > 0.0:
				return passive_notice_text
	return ""

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

func _get_outgoing_passive_multiplier(
	target: Node,
	hit_position: Vector2
) -> float:
	match get_passive_id():
		PASSIVE_PREDATOR_EYE:
			return _get_predator_eye_multiplier(target, hit_position)
		PASSIVE_BLOOD_FURY:
			if _is_blood_fury_active():
				return BLOOD_FURY_DAMAGE_MULTIPLIER
	return 1.0

func _get_predator_eye_multiplier(target: Node, hit_position: Vector2) -> float:
	var distance := _get_distance_to_target(target, hit_position)
	if distance <= 0.0:
		return 1.0
	var ratio := clampf(distance / PREDATOR_EYE_MAX_DISTANCE, 0.0, 1.0)
	var damage_bonus := ratio * PREDATOR_EYE_MAX_DAMAGE_BONUS
	if damage_bonus > 0.01:
		_set_passive_notice(
			"OCCHIO +%d%%" % roundi(damage_bonus * 100.0),
			PREDATOR_EYE_NOTICE_DURATION
		)
	return 1.0 + damage_bonus

func _get_distance_to_target(target: Node, hit_position: Vector2) -> float:
	var parent_node := get_parent()
	if not (parent_node is Node2D):
		return 0.0
	var source_position := (parent_node as Node2D).global_position
	if target is Node2D:
		return source_position.distance_to((target as Node2D).global_position)
	if hit_position != Vector2.ZERO:
		return source_position.distance_to(hit_position)
	return 0.0

func _is_blood_fury_active() -> bool:
	var health_component := _get_parent_health_component()
	return (
		health_component != null
		and health_component.is_alive()
		and health_component.get_health_ratio() <= BLOOD_FURY_HEALTH_THRESHOLD
	)

func _can_trigger_guard(target: Node) -> bool:
	return target != null and target.has_node("HealthComponent")

func _activate_perfect_guard() -> void:
	perfect_guard_timer = PERFECT_GUARD_DURATION
	passive_state_changed.emit()

func _set_passive_notice(text: String, duration: float) -> void:
	passive_notice_text = text
	passive_notice_timer = maxf(duration, 0.0)
	passive_state_changed.emit()

func _reset_passive_state() -> void:
	var had_active_state := (
		quick_hand_timer > 0.0
		or perfect_guard_timer > 0.0
		or not passive_notice_text.is_empty()
	)
	quick_hand_timer = 0.0
	perfect_guard_timer = 0.0
	passive_notice_text = ""
	passive_notice_timer = 0.0
	if had_active_state:
		passive_state_changed.emit()

func _get_parent_health_component() -> HealthComponent:
	var parent_node := get_parent()
	if parent_node == null:
		return null
	return parent_node.get_node_or_null("HealthComponent") as HealthComponent
