extends RefCounted
class_name WeaponVisualShapeLibrary

const MISSING_PICKUP_SHAPE: StringName = &"missing_weapon_visual"

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
				Vector2(-16.0, -2.0),
				Vector2(-10.5, -2.6),
				Vector2(-8.5, -6.5),
				Vector2(-5.0, -5.8),
				Vector2(-4.0, -3.6),
				Vector2(8.0, -4.4),
				Vector2(16.5, 0.0),
				Vector2(6.0, 4.6),
				Vector2(-4.0, 3.8),
				Vector2(-5.5, 6.2),
				Vector2(-9.0, 6.8),
				Vector2(-10.5, 2.8),
				Vector2(-16.0, 2.2)
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
				Vector2(-17.0, -1.4),
				Vector2(3.0, -1.8),
				Vector2(4.5, -4.8),
				Vector2(10.5, -3.6),
				Vector2(17.0, 0.0),
				Vector2(10.5, 3.6),
				Vector2(4.5, 4.8),
				Vector2(3.0, 1.8),
				Vector2(-17.0, 1.4)
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
			return PackedVector2Array([
				Vector2(13.0, 0.0),
				Vector2(9.0, -6.0),
				Vector2(1.5, -7.5),
				Vector2(-5.0, -5.5),
				Vector2(-12.5, -7.0),
				Vector2(-7.5, -2.4),
				Vector2(-15.0, 0.0),
				Vector2(-7.5, 2.4),
				Vector2(-12.5, 7.0),
				Vector2(-5.0, 5.5),
				Vector2(1.5, 7.5),
				Vector2(9.0, 6.0)
			])
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
				Vector2(-12.5, 2.5),
				Vector2(-12.5, -7.0),
				Vector2(-3.0, -1.5),
				Vector2(-3.0, -9.0),
				Vector2(12.5, 4.5),
				Vector2(1.5, 0.5),
				Vector2(1.5, 9.0)
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
			return GeometryUtils.ellipse_points(Vector2(0.0, 0.0), Vector2(14.0, 9.0), 10)
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
			return PackedVector2Array([
				Vector2(12.0, 2.5),
				Vector2(2.5, 4.2),
				Vector2(-2.5, 12.0),
				Vector2(-4.2, 2.5),
				Vector2(-12.0, -2.5),
				Vector2(-2.5, -4.2),
				Vector2(2.5, -12.0),
				Vector2(4.2, -2.5)
			])
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
		&"machete", &"ruined_katana":
			lines.append(PackedVector2Array([Vector2(-12.0, 2.0), Vector2(13.0, -1.0)]))
			lines.append(PackedVector2Array([Vector2(-6.0, -4.0), Vector2(-3.0, 5.0)]))
		&"quick_knife":
			lines.append(PackedVector2Array([Vector2(-3.5, 0.2), Vector2(14.0, 0.2)]))
			lines.append(PackedVector2Array([Vector2(-7.5, -5.5), Vector2(-6.0, 5.5)]))
		&"spear":
			lines.append(PackedVector2Array([Vector2(-15.5, 0.0), Vector2(3.0, 0.0)]))
			lines.append(PackedVector2Array([Vector2(5.0, -3.6), Vector2(11.5, 0.0), Vector2(5.0, 3.6)]))
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
		&"fire_wand":
			lines.append(PackedVector2Array([Vector2(-8.0, 4.0), Vector2(7.0, -5.0)]))
			lines.append(PackedVector2Array([Vector2(4.0, 7.0), Vector2(12.0, 1.0)]))
		&"fireball":
			lines.append(PackedVector2Array([Vector2(6.0, -3.2), Vector2(9.8, 0.0), Vector2(6.0, 3.2)]))
			lines.append(PackedVector2Array([Vector2(-10.0, 0.0), Vector2(-2.0, 0.0)]))
		&"ice_lance", &"frost_nova", &"seismic_crystal":
			lines.append(PackedVector2Array([Vector2(-8.0, 4.0), Vector2(10.0, -3.0)]))
			lines.append(PackedVector2Array([Vector2(-2.0, -5.0), Vector2(4.0, 6.0)]))
		&"chain_lightning":
			lines.append(PackedVector2Array([Vector2(-10.5, -3.5), Vector2(-3.5, -3.0), Vector2(-1.0, -6.5)]))
			lines.append(PackedVector2Array([Vector2(-1.5, -2.0), Vector2(8.5, 2.5), Vector2(1.0, 5.5)]))
		&"acid_flask", &"toxic_spores":
			lines.append(PackedVector2Array([Vector2(-8.0, 3.0), Vector2(8.0, 4.0)]))
			lines.append(PackedVector2Array([Vector2(-3.0, -9.0), Vector2(3.0, -9.0)]))
		&"unstable_void":
			lines.append(PackedVector2Array([Vector2(7.0, 1.6), Vector2(1.8, 2.8), Vector2(-1.2, 7.5)]))
			lines.append(PackedVector2Array([Vector2(-7.0, -1.6), Vector2(-1.8, -2.8), Vector2(1.2, -7.5)]))
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
			return PackedVector2Array([
				Vector2(11.0, 0.0),
				Vector2(7.5, -4.8),
				Vector2(1.0, -6.0),
				Vector2(-4.0, -4.4),
				Vector2(-10.0, -5.5),
				Vector2(-6.0, -1.8),
				Vector2(-12.0, 0.0),
				Vector2(-6.0, 1.8),
				Vector2(-10.0, 5.5),
				Vector2(-4.0, 4.4),
				Vector2(1.0, 6.0),
				Vector2(7.5, 4.8)
			])
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
				Vector2(-11.0, 2.0),
				Vector2(-11.0, -5.5),
				Vector2(-2.5, -1.0),
				Vector2(-2.5, -7.5),
				Vector2(11.0, 3.5),
				Vector2(1.0, 0.5),
				Vector2(1.0, 7.5)
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
			return PackedVector2Array([
				Vector2(10.0, 2.0),
				Vector2(2.0, 3.4),
				Vector2(-2.0, 10.0),
				Vector2(-3.4, 2.0),
				Vector2(-10.0, -2.0),
				Vector2(-2.0, -3.4),
				Vector2(2.0, -10.0),
				Vector2(3.4, -2.0)
			])
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
