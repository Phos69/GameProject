extends Node
class_name RpgPlayerComponent

signal character_changed(character_id: StringName, profile: Dictionary)
signal stats_changed()
signal experience_changed(experience: int, level: int, experience_to_next: int)
signal leveled_up(level: int)
signal passive_state_changed()
signal adrenaline_changed(adrenaline: int, max_adrenaline: int, super_ready: bool)
signal super_activated(super_id: StringName, super_name: String)

var character_id: StringName = &""
var character_profile: Dictionary = {}
var level: int = 1
var experience: int = 0
var experience_to_next_level: int = 45
var quick_hand_timer: float = 0.0
var perfect_guard_timer: float = 0.0
var passive_notice_text: String = ""
var passive_notice_timer: float = 0.0
var adrenaline: int = 0
var super_notice_text: String = ""
var super_notice_timer: float = 0.0
var final_barrage_timer: float = 0.0
var final_barrage_fire_timer: float = 0.0
var super_invulnerable_timer: float = 0.0
var super_invulnerable_previous: bool = false
var arcane_hit_count: int = 0
var briciola_companion: BriciolaCompanion
var beast_night_timer: float = 0.0
var beast_recovery_timer: float = 0.0

const MAX_HP_PER_LEVEL: int = 10
const ATTACK_PER_LEVEL: int = 2
const DEFENSE_PER_LEVEL: int = 1
const ADRENALINE_MAX: int = 100
const ADRENALINE_HIT_GAIN: int = 1
const ADRENALINE_KILL_GAIN: int = 5
const ADRENALINE_WAVE_GAIN: int = 10
const PASSIVE_PREDATOR_EYE := &"predator_eye"
const PASSIVE_QUICK_HAND := &"quick_hand"
const PASSIVE_BLOOD_FURY := &"blood_fury"
const PASSIVE_PERFECT_GUARD := &"perfect_guard"
const PASSIVE_ARCANE_RESONANCE := &"arcane_resonance"
const PASSIVE_BRICIOLA_ATTACK := &"briciola_attack"
const PASSIVE_BLOOD_SCENT := &"blood_scent"
const SUPER_ARROW_RAIN := &"arrow_rain"
const SUPER_FINAL_BARRAGE := &"final_barrage"
const SUPER_BLOOD_QUAKE := &"blood_quake"
const SUPER_PHANTOM_BLADE := &"phantom_blade"
const SUPER_FALLING_STAR := &"falling_star"
const SUPER_SCRAP_PACK := &"scrap_pack"
const SUPER_BEAST_NIGHT := &"beast_night"
const PREDATOR_EYE_MAX_DISTANCE: float = 650.0
const PREDATOR_EYE_MAX_DAMAGE_BONUS: float = 0.30
const PREDATOR_EYE_NOTICE_DURATION: float = 0.85
const QUICK_HAND_DURATION: float = 3.0
const QUICK_HAND_FIRE_RATE_MULTIPLIER: float = 1.20
const BLOOD_FURY_HEALTH_THRESHOLD: float = 0.40
const BLOOD_FURY_DAMAGE_MULTIPLIER: float = 1.25
const PERFECT_GUARD_DURATION: float = 1.5
const PERFECT_GUARD_DAMAGE_MULTIPLIER: float = 0.80
const SUPER_NOTICE_DURATION: float = 1.80
const FINAL_BARRAGE_DURATION: float = 4.0
const FINAL_BARRAGE_FIRE_INTERVAL: float = 0.11
const PHANTOM_BLADE_INVULNERABLE_DURATION: float = 0.35
const ARCANE_RESONANCE_HITS: int = 3
const ARCANE_RESONANCE_RADIUS: float = 86.0
const ARCANE_RESONANCE_DAMAGE_MULTIPLIER: float = 0.45
const SCRAP_PACK_DURATION: float = 5.0
const BEAST_NIGHT_DURATION: float = 6.0
const BEAST_RECOVERY_DURATION: float = 0.75
const BEAST_DAMAGE_MULTIPLIER: float = 1.45
const BLOOD_SCENT_HEALTH_THRESHOLD: float = 0.50
const BLOOD_SCENT_DAMAGE_MULTIPLIER: float = 1.30

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
	if beast_recovery_timer > 0.0:
		beast_recovery_timer = maxf(beast_recovery_timer - delta, 0.0)
		changed = changed or beast_recovery_timer <= 0.0
	if changed:
		passive_state_changed.emit()
	_tick_super_timers(delta)

func apply_character(next_character_id: StringName) -> bool:
	if not RpgCharacterRegistry.is_character_available(next_character_id):
		next_character_id = RpgCharacterRegistry.DEFAULT_CHARACTER_ID
	character_id = next_character_id
	character_profile = RpgCharacterRegistry.get_character_profile(character_id)
	reset_run_progression()
	character_changed.emit(character_id, character_profile.duplicate(true))
	stats_changed.emit()
	_update_companion_presence()
	return true

func clear_character() -> void:
	character_id = &""
	character_profile = {}
	reset_run_progression()
	character_changed.emit(character_id, {})
	stats_changed.emit()
	_update_companion_presence()

func has_character() -> bool:
	return not character_id.is_empty() and not character_profile.is_empty()

func get_display_name() -> String:
	return str(character_profile.get("display_name", "Survivor"))

func get_hero_name() -> String:
	return str(character_profile.get("hero_name", get_display_name()))

func get_class_name() -> String:
	return str(character_profile.get("class_name", "Survivor"))

func get_base_weapon_name() -> String:
	return str(character_profile.get("base_weapon_name", "Starter Pistol"))

func get_passive_name() -> String:
	return str(character_profile.get("passive_name", ""))

func get_super_name() -> String:
	return str(character_profile.get("super_name", ""))

func get_super_id() -> StringName:
	return StringName(character_profile.get("super_id", &""))

func reset_run_progression() -> void:
	level = 1
	experience = 0
	experience_to_next_level = 45
	_set_adrenaline(0)
	_reset_passive_state()
	_reset_super_state()
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

func get_adrenaline_ratio() -> float:
	return clampf(float(adrenaline) / float(ADRENALINE_MAX), 0.0, 1.0)

func is_super_ready() -> bool:
	return has_character() and adrenaline >= ADRENALINE_MAX

func add_adrenaline(amount: int) -> void:
	if amount <= 0 or not has_character():
		return
	_set_adrenaline(adrenaline + _scale_adrenaline_gain(amount))

func notify_damage_dealt(
	applied_damage: int,
	target: Node,
	source_id: StringName = &""
) -> void:
	if applied_damage > 0:
		add_adrenaline(ADRENALINE_HIT_GAIN)
		if get_passive_id() == PASSIVE_ARCANE_RESONANCE and source_id != PASSIVE_ARCANE_RESONANCE:
			_notify_arcane_hit(target)

func notify_damage_taken(applied_damage: int, _source: Node = null) -> void:
	if applied_damage > 0:
		add_adrenaline(ADRENALINE_HIT_GAIN)

func notify_kill_confirmed() -> void:
	add_adrenaline(ADRENALINE_KILL_GAIN)

func notify_wave_completed() -> void:
	add_adrenaline(ADRENALINE_WAVE_GAIN)

func try_activate_super(direction: Vector2 = Vector2.RIGHT) -> bool:
	if not is_super_ready():
		return false
	var player := get_parent() as Node2D
	if player == null:
		return false

	var activated := false
	match get_super_id():
		SUPER_ARROW_RAIN:
			activated = RpgSuperResolver.execute_arrow_rain(
				self,
				player,
				direction
			)
		SUPER_FINAL_BARRAGE:
			final_barrage_timer = FINAL_BARRAGE_DURATION
			final_barrage_fire_timer = 0.0
			_fire_final_barrage_shot()
			final_barrage_fire_timer = FINAL_BARRAGE_FIRE_INTERVAL
			activated = true
		SUPER_BLOOD_QUAKE:
			activated = RpgSuperResolver.execute_blood_quake(self, player)
		SUPER_PHANTOM_BLADE:
			activated = RpgSuperResolver.execute_phantom_blade(
				self,
				player,
				direction
			)
			if activated:
				_begin_super_invulnerability()
		SUPER_FALLING_STAR:
			activated = RpgSuperResolver.execute_falling_star(self, player)
		SUPER_SCRAP_PACK:
			activated = _activate_scrap_pack()
		SUPER_BEAST_NIGHT:
			activated = RpgSuperResolver.execute_beast_night(self, player)
			if activated:
				_begin_beast_night()

	if not activated:
		return false
	_set_adrenaline(0)
	_set_super_notice(get_super_name().to_upper(), SUPER_NOTICE_DURATION)
	super_activated.emit(get_super_id(), get_super_name())
	return true

func get_super_status_text() -> String:
	if super_notice_timer > 0.0:
		return super_notice_text
	if final_barrage_timer > 0.0:
		return "SCARICA FINALE"
	if beast_night_timer > 0.0:
		return "NOTTE BESTIALE"
	if beast_recovery_timer > 0.0:
		return "RECUPERO"
	if is_super_ready():
		return "SUPER READY"
	if has_character():
		return get_super_name()
	return "SUPER"

func get_current_weapon_damage() -> int:
	var parent_node := get_parent()
	if parent_node == null:
		return 10
	var weapon_system := parent_node.get_node_or_null(
		"WeaponSystem"
	) as WeaponSystem
	if weapon_system == null or weapon_system.weapon_data == null:
		return 10
	return weapon_system.weapon_data.damage

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
	if beast_night_timer > 0.0:
		resolved_damage = roundi(float(resolved_damage) * BEAST_DAMAGE_MULTIPLIER)
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
		PASSIVE_ARCANE_RESONANCE:
			if passive_notice_timer > 0.0:
				return passive_notice_text
		PASSIVE_BRICIOLA_ATTACK:
			if briciola_companion != null and is_instance_valid(briciola_companion):
				return "BRICIOLA"
		PASSIVE_BLOOD_SCENT:
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
		PASSIVE_BLOOD_SCENT:
			return _get_blood_scent_multiplier(target)
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
		or arcane_hit_count > 0
		or not passive_notice_text.is_empty()
	)
	quick_hand_timer = 0.0
	perfect_guard_timer = 0.0
	arcane_hit_count = 0
	passive_notice_text = ""
	passive_notice_timer = 0.0
	if had_active_state:
		passive_state_changed.emit()

func _get_parent_health_component() -> HealthComponent:
	var parent_node := get_parent()
	if parent_node == null:
		return null
	return parent_node.get_node_or_null("HealthComponent") as HealthComponent

func _set_adrenaline(value: int) -> void:
	var previous := adrenaline
	adrenaline = clampi(value, 0, ADRENALINE_MAX)
	if adrenaline != previous:
		adrenaline_changed.emit(adrenaline, ADRENALINE_MAX, is_super_ready())

func _scale_adrenaline_gain(amount: int) -> int:
	var gain_multiplier := maxf(
		float(character_profile.get("adrenaline_gain", 1.0)),
		0.10
	)
	return maxi(1, roundi(float(amount) * gain_multiplier))

func _tick_super_timers(delta: float) -> void:
	if final_barrage_timer > 0.0:
		final_barrage_timer = maxf(final_barrage_timer - delta, 0.0)
		final_barrage_fire_timer = maxf(final_barrage_fire_timer - delta, 0.0)
		if final_barrage_timer > 0.0 and final_barrage_fire_timer <= 0.0:
			_fire_final_barrage_shot()
			final_barrage_fire_timer = FINAL_BARRAGE_FIRE_INTERVAL
	if super_invulnerable_timer > 0.0:
		super_invulnerable_timer = maxf(super_invulnerable_timer - delta, 0.0)
		if super_invulnerable_timer <= 0.0:
			_restore_super_invulnerability()
	if beast_night_timer > 0.0:
		beast_night_timer = maxf(beast_night_timer - delta, 0.0)
		if beast_night_timer <= 0.0:
			_end_beast_night()
	if super_notice_timer > 0.0:
		super_notice_timer = maxf(super_notice_timer - delta, 0.0)
		if super_notice_timer <= 0.0:
			super_notice_text = ""

func _fire_final_barrage_shot() -> bool:
	var player := get_parent() as Node2D
	if player == null:
		return false
	return RpgSuperResolver.fire_final_barrage_shot(self, player)

func _begin_super_invulnerability() -> void:
	var health_component := _get_parent_health_component()
	if health_component == null:
		return
	super_invulnerable_previous = health_component.invulnerable
	health_component.invulnerable = true
	super_invulnerable_timer = PHANTOM_BLADE_INVULNERABLE_DURATION

func _restore_super_invulnerability() -> void:
	var health_component := _get_parent_health_component()
	if health_component != null:
		health_component.invulnerable = super_invulnerable_previous
	super_invulnerable_timer = 0.0

func _set_super_notice(text: String, duration: float) -> void:
	super_notice_text = text
	super_notice_timer = maxf(duration, 0.0)

func _reset_super_state() -> void:
	if super_invulnerable_timer > 0.0:
		_restore_super_invulnerability()
	final_barrage_timer = 0.0
	final_barrage_fire_timer = 0.0
	beast_night_timer = 0.0
	beast_recovery_timer = 0.0
	super_notice_text = ""
	super_notice_timer = 0.0

func _notify_arcane_hit(target: Node) -> void:
	if target == null:
		return
	arcane_hit_count += 1
	if arcane_hit_count < ARCANE_RESONANCE_HITS:
		_set_passive_notice("RUNE %d/%d" % [arcane_hit_count, ARCANE_RESONANCE_HITS], 0.55)
		return
	arcane_hit_count = 0
	var player := get_parent() as Node2D
	var target_node := target as Node2D
	if player == null or target_node == null:
		return
	var health_system := get_tree().get_first_node_in_group("health_system") as HealthSystem
	if health_system == null:
		return
	var damage := maxi(1, roundi(float(get_current_weapon_damage()) * ARCANE_RESONANCE_DAMAGE_MULTIPLIER))
	for candidate in get_tree().get_nodes_in_group("damageable_targets"):
		if not (candidate is Node2D):
			continue
		var health_component := candidate.get_node_or_null("HealthComponent") as HealthComponent
		if health_component == null or not health_component.is_alive():
			continue
		if target_node.global_position.distance_to((candidate as Node2D).global_position) <= ARCANE_RESONANCE_RADIUS:
			health_system.apply_damage(candidate, damage, player, PASSIVE_ARCANE_RESONANCE, (candidate as Node2D).global_position)
	_set_passive_notice("RISONANZA", 0.90)

func _get_blood_scent_multiplier(target: Node) -> float:
	if target == null:
		return 1.0
	var health_component := target.get_node_or_null("HealthComponent") as HealthComponent
	if health_component != null and health_component.get_health_ratio() <= BLOOD_SCENT_HEALTH_THRESHOLD:
		_set_passive_notice("ODORE +30%", 0.75)
		return BLOOD_SCENT_DAMAGE_MULTIPLIER
	return 1.0

func _update_companion_presence() -> void:
	if get_passive_id() == PASSIVE_BRICIOLA_ATTACK:
		_ensure_briciola_companion()
	else:
		_remove_briciola_companion()

func _ensure_briciola_companion() -> void:
	if briciola_companion != null and is_instance_valid(briciola_companion):
		return
	var player := get_parent() as Node2D
	if player == null or player.get_parent() == null:
		return
	briciola_companion = BriciolaCompanion.new()
	player.get_parent().add_child(briciola_companion)
	briciola_companion.setup(player)

func _remove_briciola_companion() -> void:
	if briciola_companion != null and is_instance_valid(briciola_companion):
		briciola_companion.queue_free()
	briciola_companion = null

func _activate_scrap_pack() -> bool:
	_ensure_briciola_companion()
	if briciola_companion == null or not is_instance_valid(briciola_companion):
		return false
	briciola_companion.start_frenzy(SCRAP_PACK_DURATION)
	_set_passive_notice("BRANCO", SCRAP_PACK_DURATION)
	return true

func _begin_beast_night() -> void:
	beast_night_timer = BEAST_NIGHT_DURATION
	beast_recovery_timer = 0.0
	_begin_super_invulnerability()
	super_invulnerable_timer = BEAST_NIGHT_DURATION

func _end_beast_night() -> void:
	_restore_super_invulnerability()
	beast_recovery_timer = BEAST_RECOVERY_DURATION
	passive_state_changed.emit()

func is_beast_transformed() -> bool:
	return beast_night_timer > 0.0

func is_beast_recovering() -> bool:
	return beast_recovery_timer > 0.0
