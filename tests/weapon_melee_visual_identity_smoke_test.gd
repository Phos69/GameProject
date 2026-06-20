extends SceneTree

const MELEE_WEAPON_IDS: Array[StringName] = [
	&"quick_knife",
	&"machete",
	&"heavy_axe",
	&"greatsword",
	&"demolition_hammer",
	&"spear",
	&"ruined_katana",
	&"spiked_mace",
	&"scythe",
	&"offensive_shield"
]
const EXPECTED_EFFECT_KIND: Dictionary = {
	&"quick_knife": &"melee_hit_quick_stab",
	&"machete": &"melee_hit_cleave",
	&"heavy_axe": &"melee_hit_heavy_cleave",
	&"greatsword": &"melee_hit_broad_sweep",
	&"demolition_hammer": &"melee_hit_hammer",
	&"spear": &"melee_hit_thrust",
	&"ruined_katana": &"melee_hit_dash_cut",
	&"spiked_mace": &"melee_hit_spiked",
	&"scythe": &"melee_hit_crescent",
	&"offensive_shield": &"melee_hit_shield"
}
const LEGACY_MELEE_PATHS: Array[String] = [
	"res://game/weapons/rpg_axe.tres",
	"res://game/weapons/rpg_sword.tres",
	"res://game/weapons/rpg_claws.tres"
]

var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_validate_catalog_melee_profiles()
	await _validate_melee_attack_runtime()
	_validate_legacy_melee_profiles()
	_finish()

func _validate_catalog_melee_profiles() -> void:
	var style_ids: Dictionary = {}
	for weapon_id in MELEE_WEAPON_IDS:
		var definition := WeaponCatalog.get_definition(weapon_id)
		_expect(definition != null, "%s catalog definition exists" % weapon_id)
		if definition == null:
			continue
		_expect(definition.uses_melee_attack(), "%s uses melee runtime" % weapon_id)
		_expect(not definition.trail_style.is_empty(), "%s has melee trail style" % weapon_id)
		var visual := definition.visual_data
		_expect(visual != null, "%s has visual data" % weapon_id)
		if visual == null:
			continue
		_expect(
			visual.slash_shape_id == weapon_id,
			"%s has stable slash shape id" % weapon_id
		)
		_expect(
			visual.impact_shape_id == weapon_id,
			"%s has stable melee impact shape id" % weapon_id
		)
		_expect(
			not visual.impact_vfx_id.is_empty(),
			"%s has non-empty melee impact VFX id" % weapon_id
		)
		var style_id := WeaponVisualRenderer.get_slash_style_id(
			visual,
			definition.get_resolved_melee_shape(),
			definition.trail_style
		)
		_expect(not style_id.is_empty(), "%s resolves a slash style" % weapon_id)
		_expect(
			not style_ids.has(style_id),
			"%s slash style is unique in catalog melee set" % weapon_id
		)
		style_ids[style_id] = weapon_id
		_expect(
			WeaponVisualRenderer.get_melee_impact_effect_kind(
				visual,
				definition.get_resolved_melee_shape(),
				definition.trail_style
			) == EXPECTED_EFFECT_KIND[weapon_id],
			"%s resolves expected melee hit effect kind" % weapon_id
		)

func _validate_melee_attack_runtime() -> void:
	var effects := GameplayEffects.new()
	root.add_child(effects)
	await process_frame
	for weapon_id in MELEE_WEAPON_IDS:
		var definition := WeaponCatalog.get_definition(weapon_id)
		var attack := _make_attack(definition)
		_expect(
			attack.get_slash_shape_id() == weapon_id,
			"%s attack exposes slash shape id" % weapon_id
		)
		_expect(
			attack.get_slash_style_id()
			== WeaponVisualRenderer.get_slash_style_id(
				definition.visual_data,
				definition.get_resolved_melee_shape(),
				definition.trail_style
			),
			"%s attack exposes renderer slash style" % weapon_id
		)
		_expect(
			attack.attack_shape == definition.get_resolved_melee_shape(),
			"%s attack keeps gameplay hitbox shape separate from visual style" % weapon_id
		)
		var expected_effect := WeaponVisualRenderer.get_melee_impact_effect_kind(
			definition.visual_data,
			attack.attack_shape,
			attack.trail_style
		)
		effects._on_melee_attack_hit(attack, null, definition.damage, Vector2.ZERO)
		await process_frame
		var effect := _last_effect(effects)
		_expect(
			effect != null and effect.effect_kind == expected_effect,
			"%s gameplay effect uses themed melee hit kind" % weapon_id
		)
		_expect(
			effect != null and effect.effect_size >= 16.0,
			"%s melee hit effect exposes a readable size" % weapon_id
		)
		attack.free()
		if effect != null:
			effect.queue_free()
		await process_frame
	effects.queue_free()
	await process_frame

func _validate_legacy_melee_profiles() -> void:
	var expected_styles: Dictionary = {
		&"rpg_axe": &"heavy_cleave",
		&"rpg_sword": &"broad_sweep",
		&"rpg_claws": &"claw_arc"
	}
	for path in LEGACY_MELEE_PATHS:
		var definition := load(path) as WeaponData
		_expect(definition != null, "%s legacy melee loads" % path)
		if definition == null:
			continue
		var style := WeaponVisualRenderer.get_slash_style_id(
			definition.visual_data,
			definition.get_resolved_melee_shape(),
			definition.trail_style
		)
		_expect(
			style == expected_styles[definition.weapon_id],
			"%s legacy melee resolves expected slash fallback" % definition.weapon_id
		)
		_expect(
			WeaponVisualRenderer.get_melee_impact_effect_kind(
				definition.visual_data,
				definition.get_resolved_melee_shape(),
				definition.trail_style
			) != &"melee_hit",
			"%s legacy melee does not regress to generic hit effect" % definition.weapon_id
		)

func _make_attack(definition: WeaponData) -> MeleeAttack:
	var attack := MeleeAttack.new()
	attack.configure(
		Vector2.ZERO,
		Vector2.RIGHT,
		null,
		definition.damage,
		definition.weapon_id,
		definition.get_resolved_melee_shape(),
		definition.get_resolved_melee_range(),
		definition.get_resolved_melee_width(),
		definition.melee_arc_degrees,
		definition.windup_time,
		definition.active_time,
		definition.knockback,
		definition.hitstop,
		definition.max_hit_count,
		definition.visual_data,
		definition.trail_style,
		definition.effect_key
	)
	return attack

func _last_effect(effects: GameplayEffects) -> GameplayEffect:
	var child_count := effects.get_child_count()
	if child_count <= 0:
		return null
	return effects.get_child(child_count - 1) as GameplayEffect

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("WEAPON_MELEE_VISUAL_IDENTITY_SMOKE_TEST: PASS")
		quit(0)
		return
	print(
		"WEAPON_MELEE_VISUAL_IDENTITY_SMOKE_TEST: FAIL (%d)"
		% failures.size()
	)
	quit(1)
