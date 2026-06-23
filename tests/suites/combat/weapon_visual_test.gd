extends GutTest
## Combat A5 — Identità visiva delle armi (contratti shape/VFX, non pixel).
##
## Migra e accorpa:
##   tests/weapon_visual_catalog_smoke_test.gd
##   tests/weapon_held_hud_visual_identity_smoke_test.gd
##   tests/weapon_pickup_visual_identity_smoke_test.gd
##   tests/weapon_melee_visual_identity_smoke_test.gd
##   tests/weapon_projectile_vfx_identity_smoke_test.gd
##
## Sono test di contratto: id di shape stabili e per-arma, silhouette uniche
## (signature poligonali), palette distinte e tipi di effetto tematici. Nessuno
## screenshot/confronto di pixel (quelli restano nei Visual QA differiti).

const CATALOG_VISUAL_PALETTE = preload("res://game/weapons/weapon_catalog_visual_palette.gd")
const PICKUP_SCENE_PATH := "res://game/drops/drop_pickup.tscn"
const PROJECTILE_SCENE_PATH := "res://game/projectiles/projectile.tscn"

const ALL_WEAPON_IDS: Array[StringName] = [
	&"heavy_revolver", &"unstable_smg", &"pump_shotgun", &"tactical_carbine", &"improvised_sniper",
	&"grenade_launcher", &"sawed_off_double", &"burst_pistol", &"rusty_minigun", &"scrap_railgun",
	&"quick_knife", &"machete", &"heavy_axe", &"greatsword", &"demolition_hammer",
	&"spear", &"ruined_katana", &"spiked_mace", &"scythe", &"offensive_shield",
	&"fire_wand", &"fireball", &"ice_lance", &"frost_nova", &"chain_lightning",
	&"arcane_taser", &"acid_flask", &"toxic_spores", &"seismic_crystal", &"unstable_void"
]
const GENERIC_PROFILES: Array[StringName] = [&"prototype_blaster", &"rpg_sword", &"wave_cannon", &"weapon"]
const HELD_SAMPLE_IDS: Array[StringName] = [
	&"heavy_revolver", &"pump_shotgun", &"improvised_sniper", &"grenade_launcher", &"rusty_minigun",
	&"scrap_railgun", &"quick_knife", &"heavy_axe", &"spear", &"fireball", &"ice_lance", &"chain_lightning"
]
const LEGACY_WEAPON_PATHS: Array[String] = [
	"res://game/weapons/starter_pistol.tres", "res://game/weapons/prototype_blaster.tres", "res://game/weapons/wave_cannon.tres"
]
const PICKUP_SAMPLE_IDS: Array[StringName] = [
	&"heavy_revolver", &"pump_shotgun", &"quick_knife", &"heavy_axe", &"fireball", &"ice_lance", &"chain_lightning"
]
const MELEE_WEAPON_IDS: Array[StringName] = [
	&"quick_knife", &"machete", &"heavy_axe", &"greatsword", &"demolition_hammer",
	&"spear", &"ruined_katana", &"spiked_mace", &"scythe", &"offensive_shield"
]
const EXPECTED_EFFECT_KIND: Dictionary = {
	&"quick_knife": &"melee_hit_quick_stab", &"machete": &"melee_hit_cleave", &"heavy_axe": &"melee_hit_heavy_cleave",
	&"greatsword": &"melee_hit_broad_sweep", &"demolition_hammer": &"melee_hit_hammer", &"spear": &"melee_hit_thrust",
	&"ruined_katana": &"melee_hit_dash_cut", &"spiked_mace": &"melee_hit_spiked", &"scythe": &"melee_hit_crescent",
	&"offensive_shield": &"melee_hit_shield"
}
const LEGACY_MELEE_PATHS: Array[String] = [
	"res://game/weapons/rpg_axe.tres", "res://game/weapons/rpg_sword.tres", "res://game/weapons/rpg_claws.tres"
]
const RANGED_WEAPON_IDS: Array[StringName] = [
	&"heavy_revolver", &"unstable_smg", &"pump_shotgun", &"tactical_carbine", &"improvised_sniper",
	&"grenade_launcher", &"sawed_off_double", &"burst_pistol", &"rusty_minigun", &"scrap_railgun",
	&"fire_wand", &"fireball", &"ice_lance", &"frost_nova", &"chain_lightning",
	&"arcane_taser", &"acid_flask", &"toxic_spores", &"seismic_crystal", &"unstable_void"
]
const RUNTIME_SAMPLE_IDS: Array[StringName] = [
	&"heavy_revolver", &"pump_shotgun", &"scrap_railgun", &"fireball", &"ice_lance", &"chain_lightning", &"acid_flask", &"unstable_void"
]

# --- catalogo: copertura, profili unici, shape, palette ---------------------

func test_catalog_coverage() -> void:
	var catalog_ids := WeaponCatalog.get_ids()
	assert_eq(catalog_ids.size(), ALL_WEAPON_IDS.size(), "catalog contains exactly the 30 W6 weapons")
	for weapon_id in catalog_ids:
		assert_true(ALL_WEAPON_IDS.has(weapon_id), "catalog weapon %s is covered by the W6 smoke" % weapon_id)

func test_unique_profiles() -> void:
	var seen_profiles: Dictionary = {}
	for weapon_id in ALL_WEAPON_IDS:
		var definition := WeaponCatalog.get_definition(weapon_id)
		assert_not_null(definition, "%s catalog definition exists" % weapon_id)
		if definition == null:
			continue
		var visual := definition.visual_data
		assert_not_null(visual, "%s has visual_data" % weapon_id)
		if visual == null:
			continue
		assert_eq(visual.profile_id, weapon_id, "%s profile_id matches weapon_id (got '%s')" % [weapon_id, visual.profile_id])
		assert_false(GENERIC_PROFILES.has(visual.profile_id), "%s does not use a generic category profile" % weapon_id)
		assert_false(seen_profiles.has(visual.profile_id), "%s has a unique profile_id" % weapon_id)
		seen_profiles[visual.profile_id] = weapon_id
		assert_eq(visual.family_id, definition.category, "%s family_id matches category" % weapon_id)

func test_pickup_shapes() -> void:
	for weapon_id in ALL_WEAPON_IDS:
		var visual := _visual_of(weapon_id)
		if visual == null:
			continue
		assert_eq(visual.pickup_shape_id, weapon_id, "%s pickup_shape_id is weapon-specific" % weapon_id)
		assert_ne(WeaponVisualRenderer.get_pickup_shape_id(visual), WeaponVisualRenderer.MISSING_PICKUP_SHAPE, "%s resolves a real pickup shape (not missing placeholder)" % weapon_id)
		assert_gte(WeaponVisualRenderer.get_pickup_body_polygon(visual).size(), 4, "%s pickup body polygon has at least 4 vertices" % weapon_id)

func test_held_hud_catalog_shapes() -> void:
	for weapon_id in ALL_WEAPON_IDS:
		var visual := _visual_of(weapon_id)
		if visual == null:
			continue
		assert_eq(visual.held_shape_id, weapon_id, "%s held_shape_id is weapon-specific" % weapon_id)
		assert_eq(visual.hud_shape_id, weapon_id, "%s hud_shape_id is weapon-specific" % weapon_id)
		assert_gte(WeaponVisualRenderer.get_weapon_body_polygon(visual, WeaponVisualRenderer.TARGET_HELD).size(), 4, "%s held body polygon has at least 4 vertices" % weapon_id)

func test_projectile_melee_shapes() -> void:
	var seen_slash_styles: Dictionary = {}
	for weapon_id in ALL_WEAPON_IDS:
		var definition := WeaponCatalog.get_definition(weapon_id)
		if definition == null or definition.visual_data == null:
			continue
		var visual := definition.visual_data
		if definition.category == &"melee":
			assert_eq(visual.slash_shape_id, weapon_id, "%s slash_shape_id is weapon-specific" % weapon_id)
			assert_eq(visual.impact_shape_id, weapon_id, "%s melee impact_shape_id is weapon-specific" % weapon_id)
			assert_false(visual.impact_vfx_id.is_empty(), "%s has a non-empty melee impact_vfx_id" % weapon_id)
			var slash_style := WeaponVisualRenderer.get_slash_style_id(visual, definition.get_resolved_melee_shape(), definition.trail_style)
			assert_false(slash_style.is_empty(), "%s resolves a slash style" % weapon_id)
			assert_false(seen_slash_styles.has(slash_style), "%s has a unique slash style" % weapon_id)
			seen_slash_styles[slash_style] = weapon_id
		else:
			assert_eq(visual.projectile_shape_id, weapon_id, "%s projectile_shape_id is weapon-specific" % weapon_id)
			assert_eq(visual.muzzle_shape_id, weapon_id, "%s muzzle_shape_id is weapon-specific" % weapon_id)
			assert_eq(visual.impact_shape_id, weapon_id, "%s projectile impact_shape_id is weapon-specific" % weapon_id)
			assert_false(visual.impact_vfx_id.is_empty(), "%s has a non-empty projectile impact_vfx_id" % weapon_id)
			assert_gte(WeaponVisualRenderer.get_projectile_polygon(visual).size(), 3, "%s projectile polygon has at least 3 vertices" % weapon_id)

func test_palettes() -> void:
	var seen_primaries: Array[Color] = []
	for weapon_id in ALL_WEAPON_IDS:
		var visual := _visual_of(weapon_id)
		if visual == null:
			continue
		assert_true(CATALOG_VISUAL_PALETTE.has_palette(weapon_id), "%s has an explicit catalog palette" % weapon_id)
		var primary := visual.primary_color
		assert_true(primary == CATALOG_VISUAL_PALETTE.get_primary_color(weapon_id)
			and visual.secondary_color == CATALOG_VISUAL_PALETTE.get_secondary_color(weapon_id)
			and visual.glow_color == CATALOG_VISUAL_PALETTE.get_glow_color(weapon_id),
			"%s consumes its explicit body, accent and glow palette" % weapon_id)
		assert_gt(primary.a, 0.0, "%s primary_color is non-transparent" % weapon_id)
		assert_ne(primary, Color(0.15, 0.18, 0.22, 1.0), "%s primary_color is not the generic weapon default" % weapon_id)
		var is_duplicate := false
		for seen in seen_primaries:
			if seen.is_equal_approx(primary):
				is_duplicate = true
				break
		assert_false(is_duplicate, "%s primary_color is distinct from previously seen weapons" % weapon_id)
		seen_primaries.append(primary)
		assert_ne(visual.secondary_color, visual.primary_color, "%s secondary_color differs from primary_color" % weapon_id)
		assert_gt(visual.glow_color.a, 0.0, "%s glow_color has non-zero alpha" % weapon_id)

# --- identità held/HUD su nodi runtime --------------------------------------

func test_held_hud_runtime_identity() -> void:
	var held_signatures: Dictionary = {}
	var hud_signatures: Dictionary = {}
	var sig := {"revolver_held": "", "shotgun_held": "", "revolver_hud": "", "shotgun_hud": ""}
	var revolver_color := Color.TRANSPARENT
	var shotgun_color := Color.TRANSPARENT
	for weapon_id in HELD_SAMPLE_IDS:
		var definition := WeaponCatalog.get_definition(weapon_id)
		assert_not_null(definition, "%s catalog definition exists" % weapon_id)
		if definition == null or definition.visual_data == null:
			continue
		assert_eq(definition.visual_data.held_shape_id, weapon_id, "%s has stable held shape id" % weapon_id)
		assert_eq(definition.visual_data.hud_shape_id, weapon_id, "%s has stable HUD shape id" % weapon_id)

		var player_visual := PlayerVisual.new()
		add_child(player_visual)
		player_visual.set_weapon_data(definition)
		var icon := WeaponIcon.new()
		add_child(icon)
		icon.size = Vector2(38.0, 24.0)
		icon.set_visual_data(definition.visual_data)
		await wait_frames(1)

		assert_eq(player_visual.get_weapon_held_shape_id(), weapon_id, "%s player visual resolves held shape" % weapon_id)
		assert_eq(icon.get_hud_shape_id(), weapon_id, "%s HUD icon resolves HUD shape" % weapon_id)
		var held_body := player_visual.get_weapon_held_body_polygon()
		var hud_body := icon.get_hud_body_polygon()
		assert_gte(held_body.size(), 3, "%s held body is drawable" % weapon_id)
		assert_gte(hud_body.size(), 3, "%s HUD body is drawable" % weapon_id)
		var held_signature := _polygon_signature(held_body)
		var hud_signature := _polygon_signature(hud_body)
		assert_false(held_signatures.has(held_signature), "%s held silhouette is unique in the W3 sample" % weapon_id)
		assert_false(hud_signatures.has(hud_signature), "%s HUD silhouette is unique in the W3 sample" % weapon_id)
		held_signatures[held_signature] = weapon_id
		hud_signatures[hud_signature] = weapon_id
		if weapon_id == &"heavy_revolver":
			sig["revolver_held"] = held_signature
			sig["revolver_hud"] = hud_signature
			revolver_color = definition.visual_data.secondary_color
		elif weapon_id == &"pump_shotgun":
			sig["shotgun_held"] = held_signature
			sig["shotgun_hud"] = hud_signature
			shotgun_color = definition.visual_data.secondary_color
		player_visual.queue_free()
		icon.queue_free()
		await wait_frames(1)

	assert_true(sig["revolver_held"] != sig["shotgun_held"] and sig["revolver_hud"] != sig["shotgun_hud"], "firearm samples differ by held and HUD silhouette")
	assert_ne(revolver_color, shotgun_color, "firearm samples differ by color (W6 per-weapon palette)")

	for path in LEGACY_WEAPON_PATHS:
		var definition := load(path) as WeaponData
		assert_not_null(definition, "%s legacy weapon loads" % path)
		if definition == null or definition.visual_data == null:
			continue
		var profile_id := definition.visual_data.profile_id
		assert_gte(WeaponVisualRenderer.get_weapon_body_polygon(definition.visual_data, WeaponVisualRenderer.TARGET_HELD).size(), 3, "%s legacy held silhouette remains drawable" % profile_id)
		assert_gte(WeaponVisualRenderer.get_weapon_body_polygon(definition.visual_data, WeaponVisualRenderer.TARGET_HUD).size(), 3, "%s legacy HUD silhouette remains drawable" % profile_id)

# --- identità dei pickup ----------------------------------------------------

func test_pickup_runtime_identity() -> void:
	for weapon_id in WeaponCatalog.get_ids():
		var visual_data := _visual_of(weapon_id)
		if visual_data == null:
			continue
		assert_eq(visual_data.pickup_shape_id, weapon_id, "%s uses a stable pickup shape id" % weapon_id)
		assert_true(WeaponVisualRenderer.has_pickup_visual(visual_data), "%s does not fall back to missing pickup visual" % weapon_id)

	var pickup_scene := load(PICKUP_SCENE_PATH) as PackedScene
	assert_not_null(pickup_scene, "drop pickup scene can be loaded")
	if pickup_scene == null:
		return

	var signatures: Dictionary = {}
	var revolver_signature := ""
	var shotgun_signature := ""
	var revolver_color := Color.TRANSPARENT
	var shotgun_color := Color.TRANSPARENT
	for weapon_id in PICKUP_SAMPLE_IDS:
		var definition := WeaponCatalog.get_definition(weapon_id)
		assert_not_null(definition, "%s sample weapon exists" % weapon_id)
		if definition == null:
			continue
		var pickup := _spawn_pickup(pickup_scene, {"type": GameConstants.DROP_WEAPON, "amount": 1, "weapon_data": definition})
		await wait_frames(1)
		var visual := pickup.visual
		assert_eq(visual.weapon_visual_data, definition.visual_data, "%s passes WeaponVisualData to DropPickupVisual" % weapon_id)
		assert_eq(visual.get_weapon_pickup_shape_id(), weapon_id, "%s pickup resolves its weapon silhouette id" % weapon_id)
		assert_false(visual.uses_missing_weapon_visual(), "%s pickup does not use missing visual fallback" % weapon_id)
		var body := visual.get_weapon_pickup_body_polygon()
		assert_gte(body.size(), 3, "%s pickup has a drawable body" % weapon_id)
		var signature := _polygon_signature(body)
		assert_false(signatures.has(signature), "%s pickup silhouette is unique in the W2 sample grid" % weapon_id)
		signatures[signature] = weapon_id
		if weapon_id == &"heavy_revolver":
			revolver_signature = signature
			revolver_color = definition.visual_data.secondary_color
		elif weapon_id == &"pump_shotgun":
			shotgun_signature = signature
			shotgun_color = definition.visual_data.secondary_color
		assert_lte(definition.visual_data.rarity_glow, 0.5, "%s rarity glow stays below silhouette-covering intensity" % weapon_id)
		pickup.queue_free()
		await wait_frames(1)
	assert_ne(revolver_signature, shotgun_signature, "two firearm pickups are distinguishable by silhouette")
	assert_ne(revolver_color, shotgun_color, "two firearm pickups are distinguishable by color (W6 per-weapon palette)")

	var ammo_pickup := _spawn_pickup(pickup_scene, {"type": GameConstants.DROP_AMMO, "amount": 6})
	await wait_frames(1)
	assert_null(ammo_pickup.visual.weapon_visual_data, "non-weapon pickup keeps icon-only visual contract")
	assert_false(ammo_pickup.visual.uses_missing_weapon_visual(), "non-weapon pickup does not use weapon missing fallback")
	assert_true(ammo_pickup.visual.get_weapon_pickup_shape_id().is_empty(), "non-weapon pickup has no weapon shape id")
	ammo_pickup.queue_free()
	await wait_frames(1)

	var missing_pickup := _spawn_pickup(pickup_scene, {"type": GameConstants.DROP_WEAPON, "amount": 1})
	await wait_frames(1)
	var missing_visual := missing_pickup.visual
	assert_true(missing_visual.uses_missing_weapon_visual(), "weapon pickup without WeaponVisualData uses explicit missing visual")
	assert_eq(missing_visual.get_weapon_pickup_shape_id(), WeaponVisualRenderer.MISSING_PICKUP_SHAPE, "missing weapon pickup exposes missing visual id")
	assert_gte(missing_visual.get_weapon_pickup_body_polygon().size(), 4, "missing weapon pickup has an obvious drawable marker")
	missing_visual.animation_time = 3.5
	missing_visual.apply_visual_settings({"high_contrast": true, "reduced_motion": true})
	assert_true(missing_visual.high_contrast, "weapon pickup accepts high contrast")
	assert_true(missing_visual.reduced_motion, "weapon pickup accepts reduced motion")
	assert_true(is_equal_approx(missing_visual.animation_time, 0.0), "reduced motion stops pickup bobbing animation")
	missing_pickup.queue_free()
	await wait_frames(1)

# --- identità melee runtime -------------------------------------------------

func test_melee_runtime_identity() -> void:
	var style_ids: Dictionary = {}
	for weapon_id in MELEE_WEAPON_IDS:
		var definition := WeaponCatalog.get_definition(weapon_id)
		assert_not_null(definition, "%s catalog definition exists" % weapon_id)
		if definition == null:
			continue
		assert_true(definition.uses_melee_attack(), "%s uses melee runtime" % weapon_id)
		assert_false(definition.trail_style.is_empty(), "%s has melee trail style" % weapon_id)
		var visual := definition.visual_data
		if visual == null:
			continue
		assert_eq(visual.slash_shape_id, weapon_id, "%s has stable slash shape id" % weapon_id)
		assert_eq(visual.impact_shape_id, weapon_id, "%s has stable melee impact shape id" % weapon_id)
		assert_false(visual.impact_vfx_id.is_empty(), "%s has non-empty melee impact VFX id" % weapon_id)
		var style_id := WeaponVisualRenderer.get_slash_style_id(visual, definition.get_resolved_melee_shape(), definition.trail_style)
		assert_false(style_id.is_empty(), "%s resolves a slash style" % weapon_id)
		assert_false(style_ids.has(style_id), "%s slash style is unique in catalog melee set" % weapon_id)
		style_ids[style_id] = weapon_id
		assert_eq(WeaponVisualRenderer.get_melee_impact_effect_kind(visual, definition.get_resolved_melee_shape(), definition.trail_style), EXPECTED_EFFECT_KIND[weapon_id], "%s resolves expected melee hit effect kind" % weapon_id)

	var effects := GameplayEffects.new()
	add_child(effects)
	await wait_frames(1)
	for weapon_id in MELEE_WEAPON_IDS:
		var definition := WeaponCatalog.get_definition(weapon_id)
		var attack := _make_attack(definition)
		assert_eq(attack.get_slash_shape_id(), weapon_id, "%s attack exposes slash shape id" % weapon_id)
		assert_eq(attack.get_slash_style_id(), WeaponVisualRenderer.get_slash_style_id(definition.visual_data, definition.get_resolved_melee_shape(), definition.trail_style), "%s attack exposes renderer slash style" % weapon_id)
		assert_eq(attack.attack_shape, definition.get_resolved_melee_shape(), "%s attack keeps gameplay hitbox shape separate from visual style" % weapon_id)
		var expected_effect := WeaponVisualRenderer.get_melee_impact_effect_kind(definition.visual_data, attack.attack_shape, attack.trail_style)
		effects._on_melee_attack_hit(attack, null, definition.damage, Vector2.ZERO)
		await wait_frames(1)
		var effect := _last_effect(effects)
		assert_true(effect != null and effect.effect_kind == expected_effect, "%s gameplay effect uses themed melee hit kind" % weapon_id)
		assert_true(effect != null and effect.effect_size >= 16.0, "%s melee hit effect exposes a readable size" % weapon_id)
		attack.free()
		if effect != null:
			effect.queue_free()
		await wait_frames(1)
	effects.queue_free()
	await wait_frames(1)

	var expected_styles: Dictionary = {&"rpg_axe": &"heavy_cleave", &"rpg_sword": &"broad_sweep", &"rpg_claws": &"claw_arc"}
	for path in LEGACY_MELEE_PATHS:
		var definition := load(path) as WeaponData
		assert_not_null(definition, "%s legacy melee loads" % path)
		if definition == null:
			continue
		var style := WeaponVisualRenderer.get_slash_style_id(definition.visual_data, definition.get_resolved_melee_shape(), definition.trail_style)
		assert_eq(style, expected_styles[definition.weapon_id], "%s legacy melee resolves expected slash fallback" % definition.weapon_id)
		assert_ne(WeaponVisualRenderer.get_melee_impact_effect_kind(definition.visual_data, definition.get_resolved_melee_shape(), definition.trail_style), &"melee_hit", "%s legacy melee does not regress to generic hit effect" % definition.weapon_id)

# --- identità proiettile/VFX runtime ----------------------------------------

func test_projectile_vfx_identity() -> void:
	var signatures: Dictionary = {}
	for weapon_id in RANGED_WEAPON_IDS:
		var visual := _visual_of(weapon_id)
		assert_not_null(visual, "%s has visual data" % weapon_id)
		if visual == null:
			continue
		assert_eq(visual.projectile_shape_id, weapon_id, "%s has stable projectile shape id" % weapon_id)
		assert_eq(visual.muzzle_shape_id, weapon_id, "%s has stable muzzle shape id" % weapon_id)
		assert_eq(visual.impact_shape_id, weapon_id, "%s has stable impact shape id" % weapon_id)
		assert_false(visual.impact_vfx_id.is_empty(), "%s has non-empty impact VFX id" % weapon_id)
		var polygon := WeaponVisualRenderer.get_projectile_polygon(visual)
		assert_gte(polygon.size(), 3, "%s projectile polygon is drawable" % weapon_id)
		var signature := _polygon_signature(polygon)
		assert_false(signatures.has(signature), "%s projectile silhouette is unique in the W4 ranged set" % weapon_id)
		signatures[signature] = weapon_id

	var projectile_scene := load(PROJECTILE_SCENE_PATH) as PackedScene
	assert_not_null(projectile_scene, "projectile scene can be loaded")
	if projectile_scene == null:
		return
	for weapon_id in RUNTIME_SAMPLE_IDS:
		var definition := WeaponCatalog.get_definition(weapon_id)
		var projectile := projectile_scene.instantiate() as Projectile
		add_child(projectile)
		await wait_frames(1)
		projectile.launch(Vector2.RIGHT, 400.0, null, definition.damage, definition.weapon_id, definition.visual_data, 160.0, definition.hitbox_type, definition.hitbox_size, definition.max_hit_count)
		await wait_frames(1)
		var expected_signature := _polygon_signature(WeaponVisualRenderer.get_projectile_polygon(definition.visual_data))
		assert_not_null(projectile.visual, "%s runtime projectile has visual polygon node" % weapon_id)
		if projectile.visual != null:
			assert_eq(_polygon_signature(projectile.visual.polygon), expected_signature, "%s runtime projectile uses renderer polygon" % weapon_id)
		assert_eq(projectile.get_muzzle_effect_kind(), WeaponVisualRenderer.get_muzzle_effect_kind(definition.visual_data), "%s projectile exposes themed muzzle kind" % weapon_id)
		assert_eq(projectile.get_impact_effect_kind(), WeaponVisualRenderer.get_impact_effect_kind(definition.visual_data), "%s projectile exposes themed impact kind" % weapon_id)
		assert_gte(projectile.get_impact_size(), 16.0, "%s projectile exposes non-trivial impact size" % weapon_id)
		projectile.queue_free()
		await wait_frames(1)

	var effects := GameplayEffects.new()
	add_child(effects)
	await wait_frames(1)
	await _expect_spawn_effect_kind(effects, &"pump_shotgun", &"muzzle_shotgun")
	await _expect_spawn_effect_kind(effects, &"rusty_minigun", &"muzzle_rotor")
	await _expect_spawn_effect_kind(effects, &"scrap_railgun", &"muzzle_rail")
	await _expect_spawn_effect_kind(effects, &"fireball", &"muzzle_elemental")
	await _expect_impact_effect_kind(effects, &"heavy_revolver", &"weapon_impact_ballistic")
	await _expect_impact_effect_kind(effects, &"fireball", &"weapon_impact_explosion")
	await _expect_impact_effect_kind(effects, &"ice_lance", &"weapon_impact_ice")
	await _expect_impact_effect_kind(effects, &"chain_lightning", &"weapon_impact_lightning")
	await _expect_impact_effect_kind(effects, &"acid_flask", &"weapon_impact_toxic")
	await _expect_impact_effect_kind(effects, &"seismic_crystal", &"weapon_impact_seismic")
	await _expect_impact_effect_kind(effects, &"unstable_void", &"weapon_impact_void")
	effects.queue_free()
	await wait_frames(1)

# --- helper -----------------------------------------------------------------

func _visual_of(weapon_id: StringName) -> WeaponVisualData:
	var definition := WeaponCatalog.get_definition(weapon_id)
	if definition == null:
		return null
	return definition.visual_data

func _spawn_pickup(pickup_scene: PackedScene, drop_data: Dictionary) -> DropPickup:
	var pickup := pickup_scene.instantiate() as DropPickup
	pickup.setup(drop_data)
	add_child(pickup)
	return pickup

func _make_attack(definition: WeaponData) -> MeleeAttack:
	var attack := MeleeAttack.new()
	attack.configure(Vector2.ZERO, Vector2.RIGHT, null, definition.damage, definition.weapon_id,
		definition.get_resolved_melee_shape(), definition.get_resolved_melee_range(), definition.get_resolved_melee_width(),
		definition.melee_arc_degrees, definition.windup_time, definition.active_time, definition.knockback, definition.hitstop,
		definition.max_hit_count, definition.visual_data, definition.trail_style, definition.effect_key)
	return attack

func _make_projectile_for(weapon_id: StringName) -> Projectile:
	var definition := WeaponCatalog.get_definition(weapon_id)
	var projectile := Projectile.new()
	projectile.global_position = Vector2(24.0, 12.0)
	projectile.launch(Vector2.RIGHT, 400.0, null, definition.damage, definition.weapon_id, definition.visual_data, 160.0, definition.hitbox_type, definition.hitbox_size, definition.max_hit_count)
	add_child(projectile)
	return projectile

func _expect_spawn_effect_kind(effects: GameplayEffects, weapon_id: StringName, expected_kind: StringName) -> void:
	var projectile := _make_projectile_for(weapon_id)
	effects._on_projectile_spawned(projectile)
	await wait_frames(1)
	var effect := _last_effect(effects)
	assert_true(effect != null and effect.effect_kind == expected_kind, "%s spawn effect uses %s" % [weapon_id, expected_kind])
	projectile.queue_free()
	if effect != null:
		effect.queue_free()
	await wait_frames(1)

func _expect_impact_effect_kind(effects: GameplayEffects, weapon_id: StringName, expected_kind: StringName) -> void:
	var projectile := _make_projectile_for(weapon_id)
	effects._on_projectile_impacted(projectile, null, projectile.damage)
	await wait_frames(1)
	var effect := _last_effect(effects)
	assert_true(effect != null and effect.effect_kind == expected_kind, "%s impact effect uses %s" % [weapon_id, expected_kind])
	projectile.queue_free()
	if effect != null:
		effect.queue_free()
	await wait_frames(1)

func _last_effect(effects: GameplayEffects) -> GameplayEffect:
	var child_count := effects.get_child_count()
	if child_count <= 0:
		return null
	return effects.get_child(child_count - 1) as GameplayEffect

func _polygon_signature(points: PackedVector2Array) -> String:
	var parts := PackedStringArray()
	for point in points:
		parts.append("%.1f,%.1f" % [point.x, point.y])
	return "|".join(parts)
