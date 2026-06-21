extends RefCounted
class_name WeaponVisualRenderer

const TARGET_PICKUP: StringName = &"pickup"
const TARGET_HELD: StringName = &"held"
const TARGET_HUD: StringName = &"hud"
const TARGET_PROJECTILE: StringName = &"projectile"
const TARGET_SLASH: StringName = &"slash"
const TARGET_IMPACT: StringName = &"impact"
const TARGET_MUZZLE: StringName = &"muzzle"
const MISSING_PICKUP_SHAPE: StringName = &"missing_weapon_visual"
const SHAPE_LIBRARY := preload("res://game/weapons/weapon_visual_shape_library.gd")

static func get_shape_id(
	visual_data: WeaponVisualData,
	target: StringName
) -> StringName:
	if visual_data == null:
		return &"weapon"
	var shape_id := _get_explicit_shape_id(visual_data, target)
	if shape_id.is_empty():
		return visual_data.profile_id
	return shape_id

static func get_asset_path(
	visual_data: WeaponVisualData,
	target: StringName
) -> String:
	if visual_data == null:
		return ""
	match target:
		TARGET_PICKUP:
			return visual_data.pickup_sprite_path
		TARGET_HELD:
			return visual_data.held_sprite_path
		TARGET_PROJECTILE:
			return visual_data.projectile_sprite_path
		TARGET_SLASH:
			return visual_data.slash_sprite_path
		_:
			return ""

static func get_family_id(visual_data: WeaponVisualData) -> StringName:
	if visual_data == null:
		return &""
	if not visual_data.family_id.is_empty():
		return visual_data.family_id
	return visual_data.profile_id

static func get_scale(
	visual_data: WeaponVisualData,
	target: StringName
) -> Vector2:
	if visual_data == null:
		return Vector2.ONE
	match target:
		TARGET_PICKUP:
			return visual_data.pickup_scale
		TARGET_HELD:
			return visual_data.held_scale
		TARGET_PROJECTILE:
			return visual_data.projectile_scale
		_:
			return Vector2.ONE

static func get_outline_color(visual_data: WeaponVisualData) -> Color:
	if visual_data == null:
		return Color(1.0, 1.0, 1.0, 0.0)
	return visual_data.outline_color

static func get_impact_vfx_id(visual_data: WeaponVisualData) -> StringName:
	if visual_data == null:
		return &""
	return visual_data.impact_vfx_id

static func get_muzzle_effect_kind(visual_data: WeaponVisualData) -> StringName:
	if visual_data == null:
		return &"muzzle"
	var shape_id := get_shape_id(visual_data, TARGET_MUZZLE)
	match shape_id:
		&"pump_shotgun", &"sawed_off_double":
			return &"muzzle_shotgun"
		&"rusty_minigun":
			return &"muzzle_rotor"
		&"scrap_railgun":
			return &"muzzle_rail"
		&"fire_wand", &"fireball", &"ice_lance", &"frost_nova", &"chain_lightning", &"arcane_taser", &"acid_flask", &"toxic_spores", &"seismic_crystal", &"unstable_void":
			return &"muzzle_elemental"
		_:
			return &"muzzle"

static func get_impact_effect_kind(visual_data: WeaponVisualData) -> StringName:
	var vfx_id := get_impact_vfx_id(visual_data)
	if vfx_id.is_empty() and visual_data != null:
		vfx_id = get_shape_id(visual_data, TARGET_IMPACT)
	match vfx_id:
		&"ballistic":
			return &"weapon_impact_ballistic"
		&"explosive":
			return &"weapon_impact_explosion"
		&"fire":
			return &"weapon_impact_fire"
		&"ice":
			return &"weapon_impact_ice"
		&"lightning":
			return &"weapon_impact_lightning"
		&"toxic":
			return &"weapon_impact_toxic"
		&"seismic":
			return &"weapon_impact_seismic"
		&"void":
			return &"weapon_impact_void"
		&"rail":
			return &"weapon_impact_rail"
		&"grenade_launcher", &"fireball":
			return &"weapon_impact_explosion"
		&"fire_wand":
			return &"weapon_impact_fire"
		&"ice_lance", &"frost_nova":
			return &"weapon_impact_ice"
		&"chain_lightning", &"arcane_taser":
			return &"weapon_impact_lightning"
		&"acid_flask", &"toxic_spores":
			return &"weapon_impact_toxic"
		&"seismic_crystal":
			return &"weapon_impact_seismic"
		&"unstable_void":
			return &"weapon_impact_void"
		&"scrap_railgun":
			return &"weapon_impact_rail"
		_:
			return &"hit"

static func get_impact_color(visual_data: WeaponVisualData) -> Color:
	if visual_data == null:
		return Color(1.0, 0.42, 0.24, 1.0)
	if visual_data.projectile_glow_color.a > 0.0:
		return Color(visual_data.projectile_glow_color, 1.0)
	return Color(visual_data.projectile_color, 1.0)

static func get_impact_size(visual_data: WeaponVisualData) -> float:
	if visual_data == null:
		return 20.0
	var shape_id := get_shape_id(visual_data, TARGET_IMPACT)
	match shape_id:
		&"unstable_smg", &"pump_shotgun", &"sawed_off_double", &"burst_pistol", &"rusty_minigun":
			return 16.0
		&"heavy_revolver", &"tactical_carbine", &"fire_wand", &"arcane_taser":
			return 21.0
		&"improvised_sniper", &"ice_lance", &"chain_lightning":
			return 26.0
		&"grenade_launcher", &"fireball", &"frost_nova", &"toxic_spores":
			return 34.0
		&"scrap_railgun", &"seismic_crystal", &"unstable_void":
			return 38.0
		&"acid_flask":
			return 28.0
		_:
			return maxf(visual_data.muzzle_size * 2.2, 18.0)

static func get_impact_shake_strength(visual_data: WeaponVisualData) -> float:
	if visual_data == null:
		return 1.5
	match get_impact_effect_kind(visual_data):
		&"weapon_impact_explosion", &"weapon_impact_seismic", &"weapon_impact_void":
			return 3.2
		&"weapon_impact_rail":
			return 2.8
		&"weapon_impact_ice", &"weapon_impact_lightning":
			return 2.0
		&"weapon_impact_toxic":
			return 1.8
		&"weapon_impact_ballistic":
			return 1.4
		_:
			return 1.5

static func get_impact_shake_duration(visual_data: WeaponVisualData) -> float:
	if visual_data == null:
		return 0.08
	match get_impact_effect_kind(visual_data):
		&"weapon_impact_explosion", &"weapon_impact_seismic", &"weapon_impact_void":
			return 0.12
		&"weapon_impact_rail":
			return 0.10
		_:
			return 0.08

static func get_slash_shape_id(visual_data: WeaponVisualData) -> StringName:
	return get_shape_id(visual_data, TARGET_SLASH)

static func get_slash_style_id(
	visual_data: WeaponVisualData,
	fallback_attack_shape: StringName = &"rectangle",
	fallback_trail_style: StringName = &""
) -> StringName:
	var shape_style := _slash_style_for_shape(get_slash_shape_id(visual_data))
	if not shape_style.is_empty():
		return shape_style
	match fallback_trail_style:
		&"heavy_arc":
			return &"heavy_cleave"
		&"thin_sweep", &"sword_slash":
			return &"broad_sweep"
		&"claw_arc", &"claw_slash":
			return &"claw_arc"
		_:
			pass
	if not fallback_trail_style.is_empty():
		return fallback_trail_style
	match fallback_attack_shape:
		&"arc":
			return &"machete_cleave"
		&"dash":
			return &"katana_dash_cut"
		_:
			return &"quick_stab"

static func get_melee_impact_effect_kind(
	visual_data: WeaponVisualData,
	fallback_attack_shape: StringName = &"rectangle",
	fallback_trail_style: StringName = &""
) -> StringName:
	var vfx_id := get_impact_vfx_id(visual_data)
	if vfx_id.is_empty():
		vfx_id = get_slash_style_id(
			visual_data,
			fallback_attack_shape,
			fallback_trail_style
		)
	match vfx_id:
		&"quick_stab":
			return &"melee_hit_quick_stab"
		&"machete_cleave":
			return &"melee_hit_cleave"
		&"heavy_cleave":
			return &"melee_hit_heavy_cleave"
		&"broad_sweep":
			return &"melee_hit_broad_sweep"
		&"hammer_shockwave":
			return &"melee_hit_hammer"
		&"spear_thrust":
			return &"melee_hit_thrust"
		&"katana_dash_cut":
			return &"melee_hit_dash_cut"
		&"spiked_impact":
			return &"melee_hit_spiked"
		&"scythe_crescent":
			return &"melee_hit_crescent"
		&"shield_bash":
			return &"melee_hit_shield"
		&"claw_arc":
			return &"melee_hit_claw"
		_:
			return &"melee_hit"

static func get_melee_impact_color(visual_data: WeaponVisualData) -> Color:
	if visual_data == null:
		return Color(1.0, 0.80, 0.34, 1.0)
	if visual_data.projectile_glow_color.a > 0.0:
		return Color(visual_data.projectile_glow_color, 1.0)
	return Color(visual_data.projectile_color, 1.0)

static func get_melee_impact_size(
	visual_data: WeaponVisualData,
	fallback_attack_shape: StringName = &"rectangle",
	fallback_trail_style: StringName = &""
) -> float:
	match get_slash_style_id(visual_data, fallback_attack_shape, fallback_trail_style):
		&"quick_stab":
			return 16.0
		&"spear_thrust":
			return 20.0
		&"katana_dash_cut", &"claw_arc":
			return 24.0
		&"machete_cleave":
			return 26.0
		&"spiked_impact", &"shield_bash":
			return 30.0
		&"heavy_cleave", &"scythe_crescent":
			return 34.0
		&"broad_sweep":
			return 36.0
		&"hammer_shockwave":
			return 40.0
		_:
			return 24.0

static func get_melee_impact_shake_strength(
	visual_data: WeaponVisualData,
	fallback_attack_shape: StringName = &"rectangle",
	fallback_trail_style: StringName = &""
) -> float:
	match get_slash_style_id(visual_data, fallback_attack_shape, fallback_trail_style):
		&"quick_stab":
			return 0.8
		&"spear_thrust", &"katana_dash_cut", &"claw_arc":
			return 1.4
		&"machete_cleave":
			return 2.0
		&"spiked_impact", &"shield_bash":
			return 2.6
		&"heavy_cleave", &"broad_sweep":
			return 3.4
		&"hammer_shockwave":
			return 4.0
		&"scythe_crescent":
			return 3.0
		_:
			return 2.0

static func get_melee_impact_shake_duration(
	visual_data: WeaponVisualData,
	fallback_attack_shape: StringName = &"rectangle",
	fallback_trail_style: StringName = &""
) -> float:
	match get_slash_style_id(visual_data, fallback_attack_shape, fallback_trail_style):
		&"hammer_shockwave", &"heavy_cleave", &"broad_sweep":
			return 0.12
		_:
			return 0.09

static func get_pickup_shape_id(visual_data: WeaponVisualData) -> StringName:
	if visual_data == null:
		return MISSING_PICKUP_SHAPE
	var shape_id := _get_explicit_shape_id(visual_data, TARGET_PICKUP)
	if shape_id.is_empty():
		shape_id = visual_data.profile_id
	if shape_id.is_empty() or shape_id == &"weapon":
		return MISSING_PICKUP_SHAPE
	return shape_id

static func has_pickup_visual(visual_data: WeaponVisualData) -> bool:
	return get_pickup_shape_id(visual_data) != MISSING_PICKUP_SHAPE

static func get_pickup_body_polygon(
	visual_data: WeaponVisualData
) -> PackedVector2Array:
	return scale_polygon(
		get_pickup_body_polygon_for_shape(get_pickup_shape_id(visual_data)),
		get_scale(visual_data, TARGET_PICKUP)
	)

static func get_pickup_detail_lines(
	visual_data: WeaponVisualData
) -> Array[PackedVector2Array]:
	var scale := get_scale(visual_data, TARGET_PICKUP)
	var result: Array[PackedVector2Array] = []
	for line in get_pickup_detail_lines_for_shape(get_pickup_shape_id(visual_data)):
		result.append(scale_polygon(line, scale))
	return result

static func get_weapon_body_polygon(
	visual_data: WeaponVisualData,
	target: StringName
) -> PackedVector2Array:
	return scale_polygon(
		get_pickup_body_polygon_for_shape(get_shape_id(visual_data, target)),
		get_scale(visual_data, target)
	)

static func get_weapon_detail_lines(
	visual_data: WeaponVisualData,
	target: StringName
) -> Array[PackedVector2Array]:
	var scale := get_scale(visual_data, target)
	var result: Array[PackedVector2Array] = []
	for line in get_pickup_detail_lines_for_shape(get_shape_id(visual_data, target)):
		result.append(scale_polygon(line, scale))
	return result

static func get_oriented_weapon_body_polygon(
	visual_data: WeaponVisualData,
	target: StringName,
	origin: Vector2,
	direction: Vector2,
	scale_factor: Vector2
) -> PackedVector2Array:
	return orient_polygon(
		get_weapon_body_polygon(visual_data, target),
		origin,
		direction,
		scale_factor
	)

static func get_oriented_weapon_detail_lines(
	visual_data: WeaponVisualData,
	target: StringName,
	origin: Vector2,
	direction: Vector2,
	scale_factor: Vector2
) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for line in get_weapon_detail_lines(visual_data, target):
		result.append(orient_polygon(line, origin, direction, scale_factor))
	return result

static func get_projectile_polygon(
	visual_data: WeaponVisualData,
	fallback_shape_id: StringName = &"weapon"
) -> PackedVector2Array:
	var shape_id := fallback_shape_id
	if visual_data != null:
		shape_id = get_shape_id(visual_data, TARGET_PROJECTILE)
	return get_projectile_polygon_for_shape(shape_id)

static func get_projectile_glow_polygon(
	visual_data: WeaponVisualData,
	fallback_shape_id: StringName = &"weapon"
) -> PackedVector2Array:
	return expand_polygon(
		get_projectile_polygon(visual_data, fallback_shape_id),
		1.65
	)

static func expand_polygon(
	points: PackedVector2Array,
	scale_factor: float
) -> PackedVector2Array:
	return SHAPE_LIBRARY.expand_polygon(points, scale_factor)

static func scale_polygon(
	points: PackedVector2Array,
	scale_factor: Vector2
) -> PackedVector2Array:
	return SHAPE_LIBRARY.scale_polygon(points, scale_factor)

static func orient_polygon(
	points: PackedVector2Array,
	origin: Vector2,
	direction: Vector2,
	scale_factor: Vector2
) -> PackedVector2Array:
	return SHAPE_LIBRARY.orient_polygon(points, origin, direction, scale_factor)

static func get_pickup_body_polygon_for_shape(
	shape_id: StringName
) -> PackedVector2Array:
	return SHAPE_LIBRARY.get_pickup_body_polygon_for_shape(shape_id)

static func get_pickup_detail_lines_for_shape(
	shape_id: StringName
) -> Array[PackedVector2Array]:
	return SHAPE_LIBRARY.get_pickup_detail_lines_for_shape(shape_id)

static func get_projectile_polygon_for_shape(
	shape_id: StringName
) -> PackedVector2Array:
	return SHAPE_LIBRARY.get_projectile_polygon_for_shape(shape_id)

static func _slash_style_for_shape(shape_id: StringName) -> StringName:
	match shape_id:
		&"quick_knife":
			return &"quick_stab"
		&"machete":
			return &"machete_cleave"
		&"heavy_axe", &"rpg_axe":
			return &"heavy_cleave"
		&"greatsword", &"rpg_sword":
			return &"broad_sweep"
		&"demolition_hammer":
			return &"hammer_shockwave"
		&"spear":
			return &"spear_thrust"
		&"ruined_katana":
			return &"katana_dash_cut"
		&"spiked_mace":
			return &"spiked_impact"
		&"scythe":
			return &"scythe_crescent"
		&"offensive_shield":
			return &"shield_bash"
		&"rpg_claws":
			return &"claw_arc"
		_:
			return &""

static func _get_explicit_shape_id(
	visual_data: WeaponVisualData,
	target: StringName
) -> StringName:
	match target:
		TARGET_PICKUP:
			return visual_data.pickup_shape_id
		TARGET_HELD:
			return visual_data.held_shape_id
		TARGET_HUD:
			return visual_data.hud_shape_id
		TARGET_PROJECTILE:
			return visual_data.projectile_shape_id
		TARGET_SLASH:
			return visual_data.slash_shape_id
		TARGET_IMPACT:
			return visual_data.impact_shape_id
		TARGET_MUZZLE:
			return visual_data.muzzle_shape_id
		_:
			return &""
