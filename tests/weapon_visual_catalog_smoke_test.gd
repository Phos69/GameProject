extends SceneTree

const CATALOG_VISUAL_PALETTE := preload(
	"res://game/weapons/weapon_catalog_visual_palette.gd"
)
const ALL_WEAPON_IDS: Array[StringName] = [
	# Firearms
	&"heavy_revolver",
	&"unstable_smg",
	&"pump_shotgun",
	&"tactical_carbine",
	&"improvised_sniper",
	&"grenade_launcher",
	&"sawed_off_double",
	&"burst_pistol",
	&"rusty_minigun",
	&"scrap_railgun",
	# Melee
	&"quick_knife",
	&"machete",
	&"heavy_axe",
	&"greatsword",
	&"demolition_hammer",
	&"spear",
	&"ruined_katana",
	&"spiked_mace",
	&"scythe",
	&"offensive_shield",
	# Elemental
	&"fire_wand",
	&"fireball",
	&"ice_lance",
	&"frost_nova",
	&"chain_lightning",
	&"arcane_taser",
	&"acid_flask",
	&"toxic_spores",
	&"seismic_crystal",
	&"unstable_void",
]
const GENERIC_PROFILES: Array[StringName] = [
	&"prototype_blaster",
	&"rpg_sword",
	&"wave_cannon",
	&"weapon",
]

var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_validate_catalog_coverage()
	_validate_unique_profiles()
	_validate_pickup_shapes()
	_validate_held_hud_shapes()
	_validate_projectile_melee_shapes()
	_validate_palettes()
	_finish()

func _validate_catalog_coverage() -> void:
	var catalog_ids := WeaponCatalog.get_ids()
	_expect(
		catalog_ids.size() == ALL_WEAPON_IDS.size(),
		"catalog contains exactly the 30 W6 weapons"
	)
	for weapon_id in catalog_ids:
		_expect(
			ALL_WEAPON_IDS.has(weapon_id),
			"catalog weapon %s is covered by the W6 smoke" % weapon_id
		)

func _validate_unique_profiles() -> void:
	var seen_profiles: Dictionary = {}
	for weapon_id in ALL_WEAPON_IDS:
		var definition := WeaponCatalog.get_definition(weapon_id)
		_expect(definition != null, "%s catalog definition exists" % weapon_id)
		if definition == null:
			continue
		var visual := definition.visual_data
		_expect(visual != null, "%s has visual_data" % weapon_id)
		if visual == null:
			continue
		_expect(
			visual.profile_id == weapon_id,
			"%s profile_id matches weapon_id (got '%s')" % [weapon_id, visual.profile_id]
		)
		_expect(
			not GENERIC_PROFILES.has(visual.profile_id),
			"%s does not use a generic category profile" % weapon_id
		)
		_expect(
			not seen_profiles.has(visual.profile_id),
			"%s has a unique profile_id" % weapon_id
		)
		seen_profiles[visual.profile_id] = weapon_id
		_expect(
			visual.family_id == definition.category,
			"%s family_id matches category" % weapon_id
		)

func _validate_pickup_shapes() -> void:
	for weapon_id in ALL_WEAPON_IDS:
		var definition := WeaponCatalog.get_definition(weapon_id)
		if definition == null:
			continue
		var visual := definition.visual_data
		if visual == null:
			continue
		_expect(
			visual.pickup_shape_id == weapon_id,
			"%s pickup_shape_id is weapon-specific" % weapon_id
		)
		var pickup_id := WeaponVisualRenderer.get_pickup_shape_id(visual)
		_expect(
			pickup_id != WeaponVisualRenderer.MISSING_PICKUP_SHAPE,
			"%s resolves a real pickup shape (not missing placeholder)" % weapon_id
		)
		var body := WeaponVisualRenderer.get_pickup_body_polygon(visual)
		_expect(
			body.size() >= 4,
			"%s pickup body polygon has at least 4 vertices" % weapon_id
		)

func _validate_held_hud_shapes() -> void:
	for weapon_id in ALL_WEAPON_IDS:
		var definition := WeaponCatalog.get_definition(weapon_id)
		if definition == null:
			continue
		var visual := definition.visual_data
		if visual == null:
			continue
		_expect(
			visual.held_shape_id == weapon_id,
			"%s held_shape_id is weapon-specific" % weapon_id
		)
		_expect(
			visual.hud_shape_id == weapon_id,
			"%s hud_shape_id is weapon-specific" % weapon_id
		)
		var held_body := WeaponVisualRenderer.get_weapon_body_polygon(
			visual, WeaponVisualRenderer.TARGET_HELD
		)
		_expect(
			held_body.size() >= 4,
			"%s held body polygon has at least 4 vertices" % weapon_id
		)

func _validate_projectile_melee_shapes() -> void:
	var seen_slash_styles: Dictionary = {}
	for weapon_id in ALL_WEAPON_IDS:
		var definition := WeaponCatalog.get_definition(weapon_id)
		if definition == null:
			continue
		var visual := definition.visual_data
		if visual == null:
			continue
		if definition.category == &"melee":
			_expect(
				visual.slash_shape_id == weapon_id,
				"%s slash_shape_id is weapon-specific" % weapon_id
			)
			_expect(
				visual.impact_shape_id == weapon_id,
				"%s melee impact_shape_id is weapon-specific" % weapon_id
			)
			_expect(
				not visual.impact_vfx_id.is_empty(),
				"%s has a non-empty melee impact_vfx_id" % weapon_id
			)
			var slash_style := WeaponVisualRenderer.get_slash_style_id(
				visual,
				definition.get_resolved_melee_shape(),
				definition.trail_style
			)
			_expect(not slash_style.is_empty(), "%s resolves a slash style" % weapon_id)
			_expect(
				not seen_slash_styles.has(slash_style),
				"%s has a unique slash style" % weapon_id
			)
			seen_slash_styles[slash_style] = weapon_id
		else:
			_expect(
				visual.projectile_shape_id == weapon_id,
				"%s projectile_shape_id is weapon-specific" % weapon_id
			)
			_expect(
				visual.muzzle_shape_id == weapon_id,
				"%s muzzle_shape_id is weapon-specific" % weapon_id
			)
			_expect(
				visual.impact_shape_id == weapon_id,
				"%s projectile impact_shape_id is weapon-specific" % weapon_id
			)
			_expect(
				not visual.impact_vfx_id.is_empty(),
				"%s has a non-empty projectile impact_vfx_id" % weapon_id
			)
			var proj_poly := WeaponVisualRenderer.get_projectile_polygon(visual)
			_expect(
				proj_poly.size() >= 3,
				"%s projectile polygon has at least 3 vertices" % weapon_id
			)

func _validate_palettes() -> void:
	var seen_primaries: Array[Color] = []
	for weapon_id in ALL_WEAPON_IDS:
		var definition := WeaponCatalog.get_definition(weapon_id)
		if definition == null:
			continue
		var visual := definition.visual_data
		if visual == null:
			continue
		_expect(
			CATALOG_VISUAL_PALETTE.has_palette(weapon_id),
			"%s has an explicit catalog palette" % weapon_id
		)
		var primary := visual.primary_color
		_expect(
			primary == CATALOG_VISUAL_PALETTE.get_primary_color(weapon_id)
			and visual.secondary_color == CATALOG_VISUAL_PALETTE.get_secondary_color(weapon_id)
			and visual.glow_color == CATALOG_VISUAL_PALETTE.get_glow_color(weapon_id),
			"%s consumes its explicit body, accent and glow palette" % weapon_id
		)
		_expect(
			primary.a > 0.0,
			"%s primary_color is non-transparent" % weapon_id
		)
		_expect(
			primary != Color(0.15, 0.18, 0.22, 1.0),
			"%s primary_color is not the generic weapon default" % weapon_id
		)
		var is_duplicate := false
		for seen in seen_primaries:
			if seen.is_equal_approx(primary):
				is_duplicate = true
				break
		_expect(
			not is_duplicate,
			"%s primary_color is distinct from previously seen weapons" % weapon_id
		)
		seen_primaries.append(primary)
		_expect(
			visual.secondary_color != visual.primary_color,
			"%s secondary_color differs from primary_color" % weapon_id
		)
		_expect(
			visual.glow_color.a > 0.0,
			"%s glow_color has non-zero alpha" % weapon_id
		)

func _finish() -> void:
	if failures.is_empty():
		print("WEAPON_VISUAL_CATALOG_SMOKE_TEST: PASS")
		quit(0)
		return
	print(
		"WEAPON_VISUAL_CATALOG_SMOKE_TEST: FAIL (%d)" % failures.size()
	)
	quit(1)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)
