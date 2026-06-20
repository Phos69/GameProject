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
	var expanded := PackedVector2Array()
	for point in points:
		expanded.append(point * scale_factor)
	return expanded

static func scale_polygon(
	points: PackedVector2Array,
	scale_factor: Vector2
) -> PackedVector2Array:
	var scaled := PackedVector2Array()
	for point in points:
		scaled.append(point * scale_factor)
	return scaled

static func orient_polygon(
	points: PackedVector2Array,
	origin: Vector2,
	direction: Vector2,
	scale_factor: Vector2
) -> PackedVector2Array:
	var oriented := PackedVector2Array()
	var forward := direction.normalized()
	if forward.is_zero_approx():
		forward = Vector2.RIGHT
	var side := forward.orthogonal()
	for point in points:
		oriented.append(
			origin
			+ forward * point.x * scale_factor.x
			+ side * point.y * scale_factor.y
		)
	return oriented

static func get_pickup_body_polygon_for_shape(
	shape_id: StringName
) -> PackedVector2Array:
	match shape_id:
		&"starter_pistol", &"rpg_pistol":
			return PackedVector2Array([
				Vector2(-13.0, -4.0),
				Vector2(9.0, -4.5),
				Vector2(15.0, -1.0),
				Vector2(13.0, 3.0),
				Vector2(-1.0, 3.5),
				Vector2(-4.0, 9.0),
				Vector2(-8.0, 8.0),
				Vector2(-7.0, 3.0),
				Vector2(-13.0, 2.0)
			])
		&"heavy_revolver":
			return PackedVector2Array([
				Vector2(-13.0, -5.0),
				Vector2(2.0, -7.0),
				Vector2(13.0, -4.0),
				Vector2(13.0, 1.5),
				Vector2(1.0, 3.5),
				Vector2(-3.0, 9.0),
				Vector2(-8.0, 8.0),
				Vector2(-6.0, 3.0),
				Vector2(-13.0, 2.0)
			])
		&"unstable_smg":
			return PackedVector2Array([
				Vector2(-15.0, -5.0),
				Vector2(13.0, -5.0),
				Vector2(16.0, -1.0),
				Vector2(13.0, 3.5),
				Vector2(-2.0, 4.0),
				Vector2(-4.0, 10.0),
				Vector2(-9.0, 9.0),
				Vector2(-8.0, 4.0),
				Vector2(-15.0, 3.0)
			])
		&"pump_shotgun":
			return PackedVector2Array([
				Vector2(-16.0, -4.5),
				Vector2(8.0, -5.0),
				Vector2(16.0, -1.0),
				Vector2(15.0, 2.5),
				Vector2(-12.0, 5.5),
				Vector2(-16.0, 1.0)
			])
		&"tactical_carbine":
			return PackedVector2Array([
				Vector2(-15.0, -4.0),
				Vector2(15.0, -3.5),
				Vector2(16.0, 2.0),
				Vector2(-1.0, 4.0),
				Vector2(-4.0, 9.0),
				Vector2(-9.0, 8.0),
				Vector2(-8.0, 3.0),
				Vector2(-15.0, 2.0)
			])
		&"improvised_sniper":
			return PackedVector2Array([
				Vector2(-17.0, -3.0),
				Vector2(16.0, -3.0),
				Vector2(18.0, -0.5),
				Vector2(16.0, 2.5),
				Vector2(-6.0, 3.5),
				Vector2(-9.0, 8.0),
				Vector2(-13.0, 7.0),
				Vector2(-12.0, 2.5),
				Vector2(-17.0, 1.5)
			])
		&"grenade_launcher":
			return PackedVector2Array([
				Vector2(-14.0, -7.0),
				Vector2(7.0, -8.0),
				Vector2(16.0, -3.0),
				Vector2(16.0, 3.0),
				Vector2(6.0, 8.0),
				Vector2(-6.0, 6.5),
				Vector2(-10.0, 11.0),
				Vector2(-15.0, 8.0),
				Vector2(-12.0, 4.0),
				Vector2(-16.0, 2.0)
			])
		&"sawed_off_double":
			return PackedVector2Array([
				Vector2(-14.0, -6.0),
				Vector2(10.0, -6.0),
				Vector2(14.0, -2.0),
				Vector2(12.0, 4.0),
				Vector2(-9.0, 5.5),
				Vector2(-13.0, 10.0),
				Vector2(-16.0, 8.0),
				Vector2(-12.0, 3.0),
				Vector2(-16.0, 1.0)
			])
		&"burst_pistol":
			return PackedVector2Array([
				Vector2(-13.0, -4.0),
				Vector2(8.0, -4.5),
				Vector2(14.0, -1.0),
				Vector2(12.0, 3.0),
				Vector2(-1.0, 3.5),
				Vector2(-4.0, 9.0),
				Vector2(-8.0, 8.0),
				Vector2(-7.0, 3.0),
				Vector2(-13.0, 2.0)
			])
		&"rusty_minigun":
			return PackedVector2Array([
				Vector2(-15.0, -7.0),
				Vector2(5.0, -8.0),
				Vector2(17.0, -4.0),
				Vector2(17.0, 4.0),
				Vector2(5.0, 8.0),
				Vector2(-5.0, 7.0),
				Vector2(-8.0, 11.0),
				Vector2(-13.0, 10.0),
				Vector2(-11.0, 5.0),
				Vector2(-16.0, 3.0)
			])
		&"scrap_railgun":
			return PackedVector2Array([
				Vector2(-18.0, -5.0),
				Vector2(10.0, -6.5),
				Vector2(18.0, -2.0),
				Vector2(18.0, 2.0),
				Vector2(9.0, 6.0),
				Vector2(-10.0, 4.5),
				Vector2(-13.0, 9.0),
				Vector2(-17.0, 7.0),
				Vector2(-15.0, 3.0),
				Vector2(-18.0, 1.0)
			])
		&"quick_knife":
			return PackedVector2Array([
				Vector2(-14.0, 2.0),
				Vector2(-4.0, -4.5),
				Vector2(12.0, -2.0),
				Vector2(16.0, 0.0),
				Vector2(12.0, 2.0),
				Vector2(-4.0, 4.5)
			])
		&"rpg_bow":
			return PackedVector2Array([
				Vector2(-15.0, -2.0),
				Vector2(-1.0, -11.0),
				Vector2(15.0, -3.0),
				Vector2(17.0, 0.0),
				Vector2(15.0, 3.0),
				Vector2(-1.0, 11.0),
				Vector2(-15.0, 2.0),
				Vector2(-8.0, 0.0)
			])
		&"machete":
			return PackedVector2Array([
				Vector2(-14.0, 3.0),
				Vector2(-3.0, -6.0),
				Vector2(15.0, -5.0),
				Vector2(17.0, -1.0),
				Vector2(9.0, 5.0),
				Vector2(-4.0, 5.0)
			])
		&"heavy_axe", &"rpg_axe":
			return PackedVector2Array([
				Vector2(-14.0, 5.0),
				Vector2(1.0, -9.0),
				Vector2(13.0, -9.0),
				Vector2(16.0, 0.0),
				Vector2(8.0, 9.0),
				Vector2(0.0, 5.0),
				Vector2(-10.0, 10.0)
			])
		&"greatsword", &"rpg_sword":
			return PackedVector2Array([
				Vector2(-15.0, 4.0),
				Vector2(-7.0, -5.0),
				Vector2(12.0, -3.0),
				Vector2(17.0, 0.0),
				Vector2(12.0, 3.0),
				Vector2(-7.0, 5.0)
			])
		&"rpg_staff":
			return PackedVector2Array([
				Vector2(-16.0, 2.0),
				Vector2(5.0, -5.0),
				Vector2(13.0, -9.0),
				Vector2(17.0, -3.0),
				Vector2(14.0, 5.0),
				Vector2(6.0, 7.0),
				Vector2(-13.0, 5.0)
			])
		&"rpg_slingshot":
			return PackedVector2Array([
				Vector2(-14.0, 4.0),
				Vector2(2.0, -8.0),
				Vector2(14.0, -8.0),
				Vector2(17.0, -4.0),
				Vector2(7.0, 0.0),
				Vector2(17.0, 4.0),
				Vector2(14.0, 8.0),
				Vector2(1.0, 7.0)
			])
		&"rpg_claws":
			return PackedVector2Array([
				Vector2(-13.0, -6.0),
				Vector2(3.0, -9.0),
				Vector2(17.0, -6.0),
				Vector2(6.0, 0.0),
				Vector2(17.0, 6.0),
				Vector2(3.0, 9.0),
				Vector2(-13.0, 6.0),
				Vector2(-5.0, 0.0)
			])
		&"demolition_hammer":
			return PackedVector2Array([
				Vector2(-14.0, 7.0),
				Vector2(2.0, -9.0),
				Vector2(15.0, -8.0),
				Vector2(17.0, 1.0),
				Vector2(11.0, 8.0),
				Vector2(2.0, 6.0),
				Vector2(-8.0, 11.0)
			])
		&"spear":
			return PackedVector2Array([
				Vector2(-16.0, 2.0),
				Vector2(7.0, -2.0),
				Vector2(16.0, 0.0),
				Vector2(7.0, 2.0),
				Vector2(-16.0, 4.0)
			])
		&"ruined_katana":
			return PackedVector2Array([
				Vector2(-15.0, 5.0),
				Vector2(-7.0, -3.0),
				Vector2(10.0, -5.0),
				Vector2(17.0, -2.0),
				Vector2(10.0, 2.0),
				Vector2(-5.0, 5.0)
			])
		&"spiked_mace":
			return PackedVector2Array([
				Vector2(-15.0, 7.0),
				Vector2(2.0, -7.0),
				Vector2(11.0, -9.0),
				Vector2(17.0, -3.0),
				Vector2(15.0, 6.0),
				Vector2(7.0, 10.0),
				Vector2(-7.0, 9.0)
			])
		&"scythe":
			return PackedVector2Array([
				Vector2(-16.0, 6.0),
				Vector2(-3.0, -6.0),
				Vector2(13.0, -9.0),
				Vector2(17.0, -5.0),
				Vector2(8.0, 1.0),
				Vector2(13.0, 8.0),
				Vector2(5.0, 10.0),
				Vector2(-5.0, 5.0)
			])
		&"offensive_shield":
			return PackedVector2Array([
				Vector2(-10.0, -10.0),
				Vector2(8.0, -8.0),
				Vector2(14.0, -1.0),
				Vector2(9.0, 9.0),
				Vector2(-2.0, 12.0),
				Vector2(-13.0, 6.0),
				Vector2(-15.0, -3.0)
			])
		&"fire_wand":
			return PackedVector2Array([
				Vector2(-15.0, 3.0),
				Vector2(7.0, -6.0),
				Vector2(15.0, -4.0),
				Vector2(12.0, 3.0),
				Vector2(2.0, 6.0),
				Vector2(-12.0, 7.0)
			])
		&"fireball":
			return _ellipse_points(Vector2(0.0, 0.0), Vector2(13.0, 10.0), 12)
		&"ice_lance":
			return PackedVector2Array([
				Vector2(-15.0, 0.0),
				Vector2(-6.0, -6.0),
				Vector2(13.0, -3.0),
				Vector2(17.0, 0.0),
				Vector2(13.0, 3.0),
				Vector2(-6.0, 6.0)
			])
		&"frost_nova":
			return PackedVector2Array([
				Vector2(0.0, -12.0),
				Vector2(5.0, -4.0),
				Vector2(13.0, -4.0),
				Vector2(7.0, 2.0),
				Vector2(10.0, 10.0),
				Vector2(1.0, 6.0),
				Vector2(-7.0, 11.0),
				Vector2(-6.0, 2.0),
				Vector2(-14.0, -3.0),
				Vector2(-5.0, -5.0)
			])
		&"chain_lightning":
			return PackedVector2Array([
				Vector2(-13.0, -6.0),
				Vector2(-1.0, -3.0),
				Vector2(-5.0, 2.0),
				Vector2(13.0, -2.0),
				Vector2(2.0, 4.0),
				Vector2(5.0, 10.0),
				Vector2(-12.0, 5.0),
				Vector2(-5.0, 1.0)
			])
		&"arcane_taser":
			return PackedVector2Array([
				Vector2(-14.0, -5.0),
				Vector2(8.0, -6.0),
				Vector2(15.0, -2.0),
				Vector2(12.0, 2.0),
				Vector2(4.0, 2.0),
				Vector2(3.0, 8.0),
				Vector2(-4.0, 8.0),
				Vector2(-5.0, 2.0),
				Vector2(-14.0, 2.0)
			])
		&"acid_flask":
			return PackedVector2Array([
				Vector2(-6.0, -11.0),
				Vector2(5.0, -11.0),
				Vector2(4.0, -3.0),
				Vector2(13.0, 5.0),
				Vector2(8.0, 12.0),
				Vector2(-9.0, 11.0),
				Vector2(-14.0, 4.0),
				Vector2(-5.0, -3.0)
			])
		&"toxic_spores":
			return _ellipse_points(Vector2(0.0, 0.0), Vector2(14.0, 9.0), 10)
		&"seismic_crystal":
			return PackedVector2Array([
				Vector2(0.0, -13.0),
				Vector2(10.0, -6.0),
				Vector2(13.0, 6.0),
				Vector2(3.0, 13.0),
				Vector2(-11.0, 8.0),
				Vector2(-14.0, -4.0)
			])
		&"unstable_void":
			return _ellipse_points(Vector2(0.0, 0.0), Vector2(12.0, 12.0), 14)
		&"prototype_blaster", &"rift_repeater":
			return PackedVector2Array([
				Vector2(-14.0, -6.0),
				Vector2(8.0, -8.0),
				Vector2(16.0, -3.0),
				Vector2(16.0, 3.0),
				Vector2(8.0, 8.0),
				Vector2(-14.0, 6.0)
			])
		&"defense_tower":
			return PackedVector2Array([
				Vector2(-14.0, -6.0),
				Vector2(7.0, -7.0),
				Vector2(16.0, -2.0),
				Vector2(16.0, 2.0),
				Vector2(7.0, 7.0),
				Vector2(-14.0, 6.0),
				Vector2(-9.0, 0.0)
			])
		&"rift_lane", &"rift_cross":
			return PackedVector2Array([
				Vector2(-13.0, -6.0),
				Vector2(5.0, -7.0),
				Vector2(16.0, 0.0),
				Vector2(5.0, 7.0),
				Vector2(-13.0, 6.0),
				Vector2(-7.0, 0.0)
			])
		&"wave_cannon":
			return PackedVector2Array([
				Vector2(-15.0, -7.0),
				Vector2(7.0, -10.0),
				Vector2(17.0, -4.0),
				Vector2(17.0, 4.0),
				Vector2(7.0, 10.0),
				Vector2(-15.0, 7.0)
			])
		MISSING_PICKUP_SHAPE:
			return PackedVector2Array([
				Vector2(0.0, -12.0),
				Vector2(12.0, 0.0),
				Vector2(0.0, 12.0),
				Vector2(-12.0, 0.0)
			])
		_:
			return PackedVector2Array([
				Vector2(-13.0, -4.0),
				Vector2(13.0, -4.0),
				Vector2(16.0, 0.0),
				Vector2(13.0, 4.0),
				Vector2(-13.0, 4.0)
			])

static func get_pickup_detail_lines_for_shape(
	shape_id: StringName
) -> Array[PackedVector2Array]:
	var lines: Array[PackedVector2Array] = []
	match shape_id:
		&"starter_pistol", &"rpg_pistol", &"heavy_revolver", &"burst_pistol", &"arcane_taser":
			lines.append(PackedVector2Array([Vector2(-6.0, -1.0), Vector2(11.0, -1.0)]))
			lines.append(PackedVector2Array([Vector2(-2.0, 2.0), Vector2(-5.0, 8.0)]))
		&"pump_shotgun", &"sawed_off_double":
			lines.append(PackedVector2Array([Vector2(-13.0, -2.0), Vector2(12.0, -2.0)]))
			lines.append(PackedVector2Array([Vector2(-8.0, 2.5), Vector2(6.0, 3.0)]))
		&"unstable_smg", &"tactical_carbine":
			lines.append(PackedVector2Array([Vector2(-12.0, -2.0), Vector2(14.0, -2.0)]))
			lines.append(PackedVector2Array([Vector2(-2.0, 3.0), Vector2(-4.0, 9.0)]))
		&"improvised_sniper", &"scrap_railgun":
			lines.append(PackedVector2Array([Vector2(-16.0, -1.0), Vector2(17.0, -1.0)]))
			lines.append(PackedVector2Array([Vector2(-5.0, -6.0), Vector2(5.0, -6.0)]))
		&"grenade_launcher", &"rusty_minigun":
			lines.append(PackedVector2Array([Vector2(-8.0, 0.0), Vector2(15.0, 0.0)]))
			lines.append(PackedVector2Array([Vector2(4.0, -6.0), Vector2(4.0, 6.0)]))
		&"quick_knife", &"machete", &"ruined_katana", &"spear":
			lines.append(PackedVector2Array([Vector2(-12.0, 2.0), Vector2(13.0, -1.0)]))
			lines.append(PackedVector2Array([Vector2(-6.0, -4.0), Vector2(-3.0, 5.0)]))
		&"rpg_bow":
			lines.append(PackedVector2Array([Vector2(-12.0, 0.0), Vector2(16.0, 0.0)]))
			lines.append(PackedVector2Array([Vector2(-1.0, -9.0), Vector2(-1.0, 9.0)]))
		&"heavy_axe", &"rpg_axe", &"demolition_hammer", &"spiked_mace", &"scythe":
			lines.append(PackedVector2Array([Vector2(-12.0, 7.0), Vector2(7.0, -5.0)]))
			lines.append(PackedVector2Array([Vector2(3.0, -7.0), Vector2(12.0, 6.0)]))
		&"greatsword", &"rpg_sword", &"offensive_shield":
			lines.append(PackedVector2Array([Vector2(-10.0, 3.0), Vector2(13.0, 0.0)]))
			lines.append(PackedVector2Array([Vector2(-7.0, -5.0), Vector2(-5.0, 5.0)]))
		&"rpg_staff":
			lines.append(PackedVector2Array([Vector2(-13.0, 3.0), Vector2(9.0, -4.0)]))
			lines.append(PackedVector2Array([Vector2(10.0, -7.0), Vector2(15.0, 4.0)]))
		&"rpg_slingshot":
			lines.append(PackedVector2Array([Vector2(-10.0, 3.0), Vector2(8.0, -5.0)]))
			lines.append(PackedVector2Array([Vector2(8.0, -5.0), Vector2(8.0, 5.0)]))
		&"rpg_claws":
			lines.append(PackedVector2Array([Vector2(-8.0, -4.0), Vector2(14.0, -6.0)]))
			lines.append(PackedVector2Array([Vector2(-8.0, 0.0), Vector2(15.0, 0.0)]))
			lines.append(PackedVector2Array([Vector2(-8.0, 4.0), Vector2(14.0, 6.0)]))
		&"fire_wand", &"fireball":
			lines.append(PackedVector2Array([Vector2(-8.0, 4.0), Vector2(7.0, -5.0)]))
			lines.append(PackedVector2Array([Vector2(4.0, 7.0), Vector2(12.0, 1.0)]))
		&"ice_lance", &"frost_nova", &"seismic_crystal":
			lines.append(PackedVector2Array([Vector2(-8.0, 4.0), Vector2(10.0, -3.0)]))
			lines.append(PackedVector2Array([Vector2(-2.0, -5.0), Vector2(4.0, 6.0)]))
		&"chain_lightning":
			lines.append(PackedVector2Array([Vector2(-10.0, -4.0), Vector2(-3.0, 0.0), Vector2(8.0, -2.0)]))
			lines.append(PackedVector2Array([Vector2(-7.0, 4.0), Vector2(3.0, 3.0), Vector2(5.0, 8.0)]))
		&"acid_flask", &"toxic_spores":
			lines.append(PackedVector2Array([Vector2(-8.0, 3.0), Vector2(8.0, 4.0)]))
			lines.append(PackedVector2Array([Vector2(-3.0, -9.0), Vector2(3.0, -9.0)]))
		&"unstable_void":
			lines.append(PackedVector2Array([Vector2(-9.0, 0.0), Vector2(9.0, 0.0)]))
			lines.append(PackedVector2Array([Vector2(0.0, -9.0), Vector2(0.0, 9.0)]))
		&"prototype_blaster", &"rift_repeater":
			lines.append(PackedVector2Array([Vector2(-8.0, -3.0), Vector2(14.0, -3.0)]))
			lines.append(PackedVector2Array([Vector2(-8.0, 3.0), Vector2(14.0, 3.0)]))
		&"defense_tower", &"rift_lane", &"rift_cross":
			lines.append(PackedVector2Array([Vector2(-9.0, 0.0), Vector2(14.0, 0.0)]))
			lines.append(PackedVector2Array([Vector2(-2.0, -5.0), Vector2(5.0, 5.0)]))
		&"wave_cannon":
			lines.append(PackedVector2Array([Vector2(-8.0, 0.0), Vector2(15.0, 0.0)]))
			lines.append(PackedVector2Array([Vector2(-1.0, -7.0), Vector2(-1.0, 7.0)]))
		MISSING_PICKUP_SHAPE:
			lines.append(PackedVector2Array([Vector2(-7.0, -7.0), Vector2(7.0, 7.0)]))
			lines.append(PackedVector2Array([Vector2(7.0, -7.0), Vector2(-7.0, 7.0)]))
		_:
			lines.append(PackedVector2Array([Vector2(-10.0, 0.0), Vector2(12.0, 0.0)]))
	return lines

static func get_projectile_polygon_for_shape(
	shape_id: StringName
) -> PackedVector2Array:
	match shape_id:
		&"heavy_revolver":
			return PackedVector2Array([
				Vector2(-7.0, -4.2),
				Vector2(3.0, -4.8),
				Vector2(10.0, -2.2),
				Vector2(12.5, 0.0),
				Vector2(10.0, 2.2),
				Vector2(3.0, 4.8),
				Vector2(-7.0, 4.2)
			])
		&"unstable_smg":
			return PackedVector2Array([
				Vector2(-6.0, -2.4),
				Vector2(4.0, -2.0),
				Vector2(10.0, 0.0),
				Vector2(4.0, 2.0),
				Vector2(-6.0, 2.4),
				Vector2(-3.0, 0.0)
			])
		&"pump_shotgun":
			return PackedVector2Array([
				Vector2(-4.5, -4.5),
				Vector2(2.0, -5.2),
				Vector2(6.0, -2.0),
				Vector2(6.5, 2.2),
				Vector2(1.5, 5.4),
				Vector2(-5.0, 3.8)
			])
		&"tactical_carbine":
			return PackedVector2Array([
				Vector2(-8.0, -3.0),
				Vector2(6.0, -2.8),
				Vector2(12.0, 0.0),
				Vector2(6.0, 2.8),
				Vector2(-8.0, 3.0)
			])
		&"improvised_sniper":
			return PackedVector2Array([
				Vector2(-13.0, -1.8),
				Vector2(8.0, -2.2),
				Vector2(16.0, 0.0),
				Vector2(8.0, 2.2),
				Vector2(-13.0, 1.8)
			])
		&"grenade_launcher":
			return PackedVector2Array([
				Vector2(-7.5, -7.0),
				Vector2(2.0, -8.0),
				Vector2(9.0, -3.2),
				Vector2(10.5, 3.0),
				Vector2(4.0, 8.0),
				Vector2(-5.5, 7.2),
				Vector2(-10.0, 1.0)
			])
		&"sawed_off_double":
			return PackedVector2Array([
				Vector2(-5.5, -5.5),
				Vector2(4.0, -5.0),
				Vector2(8.0, -1.8),
				Vector2(8.0, 1.8),
				Vector2(4.0, 5.0),
				Vector2(-5.5, 5.5),
				Vector2(-2.0, 0.0)
			])
		&"burst_pistol":
			return PackedVector2Array([
				Vector2(-5.5, -3.0),
				Vector2(5.0, -3.0),
				Vector2(9.0, 0.0),
				Vector2(5.0, 3.0),
				Vector2(-5.5, 3.0),
				Vector2(-2.5, 0.0)
			])
		&"rusty_minigun":
			return PackedVector2Array([
				Vector2(-7.0, -2.0),
				Vector2(6.0, -2.0),
				Vector2(11.0, 0.0),
				Vector2(6.0, 2.0),
				Vector2(-7.0, 2.0)
			])
		&"scrap_railgun":
			return PackedVector2Array([
				Vector2(-16.0, -2.4),
				Vector2(9.0, -2.8),
				Vector2(18.0, 0.0),
				Vector2(9.0, 2.8),
				Vector2(-16.0, 2.4),
				Vector2(-11.0, 0.0)
			])
		&"fire_wand":
			return PackedVector2Array([
				Vector2(-8.0, 0.0),
				Vector2(-3.5, -5.0),
				Vector2(5.5, -3.2),
				Vector2(12.0, 0.0),
				Vector2(4.5, 3.8),
				Vector2(-2.5, 5.8)
			])
		&"fireball":
			return _ellipse_points(Vector2.ZERO, Vector2(9.5, 8.0), 12)
		&"ice_lance":
			return PackedVector2Array([
				Vector2(-13.0, 0.0),
				Vector2(-5.0, -4.2),
				Vector2(8.0, -3.4),
				Vector2(15.0, 0.0),
				Vector2(8.0, 3.4),
				Vector2(-5.0, 4.2)
			])
		&"frost_nova":
			return PackedVector2Array([
				Vector2(0.0, -10.0),
				Vector2(3.0, -3.0),
				Vector2(10.0, 0.0),
				Vector2(3.0, 3.0),
				Vector2(0.0, 10.0),
				Vector2(-3.0, 3.0),
				Vector2(-10.0, 0.0),
				Vector2(-3.0, -3.0)
			])
		&"chain_lightning":
			return PackedVector2Array([
				Vector2(-12.0, -2.0),
				Vector2(-3.0, -6.0),
				Vector2(-5.0, -1.0),
				Vector2(4.0, -1.0),
				Vector2(1.0, 6.0),
				Vector2(12.0, 0.0),
				Vector2(4.0, 2.0),
				Vector2(6.0, -3.0)
			])
		&"arcane_taser":
			return PackedVector2Array([
				Vector2(-7.0, -2.0),
				Vector2(1.0, -5.5),
				Vector2(9.0, -2.0),
				Vector2(5.0, 0.0),
				Vector2(10.0, 3.5),
				Vector2(1.0, 2.0),
				Vector2(-7.0, 3.0)
			])
		&"acid_flask":
			return PackedVector2Array([
				Vector2(-4.0, -8.0),
				Vector2(4.0, -7.5),
				Vector2(5.0, -2.0),
				Vector2(9.0, 4.0),
				Vector2(4.0, 9.0),
				Vector2(-5.5, 7.5),
				Vector2(-9.0, 1.5)
			])
		&"toxic_spores":
			return PackedVector2Array([
				Vector2(-9.0, -2.0),
				Vector2(-5.0, -7.5),
				Vector2(2.0, -8.0),
				Vector2(9.0, -3.0),
				Vector2(10.0, 4.0),
				Vector2(4.0, 8.5),
				Vector2(-4.0, 7.0),
				Vector2(-10.0, 2.0)
			])
		&"seismic_crystal":
			return PackedVector2Array([
				Vector2(-9.0, -2.0),
				Vector2(-2.0, -9.0),
				Vector2(8.0, -6.0),
				Vector2(12.0, 2.0),
				Vector2(3.0, 10.0),
				Vector2(-8.0, 6.0)
			])
		&"unstable_void":
			return _ellipse_points(Vector2.ZERO, Vector2(8.5, 8.5), 14)
		&"prototype_blaster":
			return PackedVector2Array([
				Vector2(-8.0, 0.0),
				Vector2(-2.0, -5.0),
				Vector2(10.0, 0.0),
				Vector2(-2.0, 5.0)
			])
		&"wave_cannon":
			return PackedVector2Array([
				Vector2(-10.0, -5.5),
				Vector2(4.0, -4.0),
				Vector2(12.0, 0.0),
				Vector2(4.0, 4.0),
				Vector2(-10.0, 5.5),
				Vector2(-5.0, 0.0)
			])
		&"defense_tower":
			return PackedVector2Array([
				Vector2(-7.0, -4.0),
				Vector2(9.0, -2.5),
				Vector2(12.0, 0.0),
				Vector2(9.0, 2.5),
				Vector2(-7.0, 4.0)
			])
		&"boss_aimed":
			return PackedVector2Array([
				Vector2(-10.0, -5.0),
				Vector2(2.0, -5.0),
				Vector2(12.0, 0.0),
				Vector2(2.0, 5.0),
				Vector2(-10.0, 5.0),
				Vector2(-5.0, 0.0)
			])
		&"boss_radial":
			return PackedVector2Array([
				Vector2(-8.0, 0.0),
				Vector2(-3.0, -6.0),
				Vector2(5.0, -5.0),
				Vector2(10.0, 0.0),
				Vector2(5.0, 5.0),
				Vector2(-3.0, 6.0)
			])
		&"enemy_shooter":
			return PackedVector2Array([
				Vector2(-8.0, -3.0),
				Vector2(-2.0, -5.0),
				Vector2(9.0, 0.0),
				Vector2(-2.0, 5.0),
				Vector2(-8.0, 3.0)
			])
		&"rpg_bow":
			return PackedVector2Array([
				Vector2(-13.0, -2.0),
				Vector2(12.0, 0.0),
				Vector2(-13.0, 2.0),
				Vector2(-8.0, 0.0)
			])
		&"rpg_pistol":
			return PackedVector2Array([
				Vector2(-4.5, -3.5),
				Vector2(5.5, -3.5),
				Vector2(7.0, 0.0),
				Vector2(5.5, 3.5),
				Vector2(-4.5, 3.5)
			])
		&"rpg_axe":
			return PackedVector2Array([
				Vector2(-10.0, -8.0),
				Vector2(8.0, -10.0),
				Vector2(13.0, 0.0),
				Vector2(8.0, 10.0),
				Vector2(-10.0, 8.0),
				Vector2(-4.0, 0.0)
			])
		&"rpg_sword":
			return PackedVector2Array([
				Vector2(-8.0, -5.0),
				Vector2(10.0, -4.0),
				Vector2(15.0, 0.0),
				Vector2(10.0, 4.0),
				Vector2(-8.0, 5.0)
			])
		&"rift_lane", &"rift_repeater":
			return PackedVector2Array([
				Vector2(-9.0, -3.5),
				Vector2(4.0, -3.0),
				Vector2(11.0, 0.0),
				Vector2(4.0, 3.0),
				Vector2(-9.0, 3.5),
				Vector2(-4.0, 0.0)
			])
		&"rift_cross":
			return PackedVector2Array([
				Vector2(-7.0, -5.0),
				Vector2(0.0, -3.0),
				Vector2(9.0, 0.0),
				Vector2(0.0, 3.0),
				Vector2(-7.0, 5.0),
				Vector2(-3.0, 0.0)
			])
		_:
			return PackedVector2Array([
				Vector2(-6.0, -3.0),
				Vector2(8.0, 0.0),
				Vector2(-6.0, 3.0)
			])

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

static func _ellipse_points(
	center: Vector2,
	radius: Vector2,
	segments: int
) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(segments):
		var angle := TAU * float(index) / float(segments)
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	return points
