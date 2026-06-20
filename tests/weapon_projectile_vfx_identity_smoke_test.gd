extends SceneTree

const PROJECTILE_SCENE_PATH := "res://game/projectiles/projectile.tscn"
const RANGED_WEAPON_IDS: Array[StringName] = [
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
	&"fire_wand",
	&"fireball",
	&"ice_lance",
	&"frost_nova",
	&"chain_lightning",
	&"arcane_taser",
	&"acid_flask",
	&"toxic_spores",
	&"seismic_crystal",
	&"unstable_void"
]
const RUNTIME_SAMPLE_IDS: Array[StringName] = [
	&"heavy_revolver",
	&"pump_shotgun",
	&"scrap_railgun",
	&"fireball",
	&"ice_lance",
	&"chain_lightning",
	&"acid_flask",
	&"unstable_void"
]

var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_validate_catalog_projectile_profiles()
	await _validate_projectile_runtime()
	await _validate_gameplay_effect_profiles()
	_finish()

func _validate_catalog_projectile_profiles() -> void:
	var signatures: Dictionary = {}
	for weapon_id in RANGED_WEAPON_IDS:
		var definition := WeaponCatalog.get_definition(weapon_id)
		_expect(definition != null, "%s catalog definition exists" % weapon_id)
		if definition == null:
			continue
		var visual := definition.visual_data
		_expect(visual != null, "%s has visual data" % weapon_id)
		if visual == null:
			continue
		_expect(
			visual.projectile_shape_id == weapon_id,
			"%s has stable projectile shape id" % weapon_id
		)
		_expect(
			visual.muzzle_shape_id == weapon_id,
			"%s has stable muzzle shape id" % weapon_id
		)
		_expect(
			visual.impact_shape_id == weapon_id,
			"%s has stable impact shape id" % weapon_id
		)
		_expect(
			not visual.impact_vfx_id.is_empty(),
			"%s has non-empty impact VFX id" % weapon_id
		)
		var polygon := WeaponVisualRenderer.get_projectile_polygon(visual)
		_expect(polygon.size() >= 3, "%s projectile polygon is drawable" % weapon_id)
		var signature := _polygon_signature(polygon)
		_expect(
			not signatures.has(signature),
			"%s projectile silhouette is unique in the W4 ranged set" % weapon_id
		)
		signatures[signature] = weapon_id

func _validate_projectile_runtime() -> void:
	var projectile_scene := load(PROJECTILE_SCENE_PATH) as PackedScene
	_expect(projectile_scene != null, "projectile scene can be loaded")
	if projectile_scene == null:
		return
	for weapon_id in RUNTIME_SAMPLE_IDS:
		var definition := WeaponCatalog.get_definition(weapon_id)
		var projectile := projectile_scene.instantiate() as Projectile
		root.add_child(projectile)
		await process_frame
		projectile.launch(
			Vector2.RIGHT,
			400.0,
			null,
			definition.damage,
			definition.weapon_id,
			definition.visual_data,
			160.0,
			definition.hitbox_type,
			definition.hitbox_size,
			definition.max_hit_count
		)
		await process_frame
		var expected_signature := _polygon_signature(
			WeaponVisualRenderer.get_projectile_polygon(definition.visual_data)
		)
		_expect(
			projectile.visual != null,
			"%s runtime projectile has visual polygon node" % weapon_id
		)
		if projectile.visual != null:
			_expect(
				_polygon_signature(projectile.visual.polygon) == expected_signature,
				"%s runtime projectile uses renderer polygon" % weapon_id
			)
		_expect(
			projectile.get_muzzle_effect_kind()
			== WeaponVisualRenderer.get_muzzle_effect_kind(definition.visual_data),
			"%s projectile exposes themed muzzle kind" % weapon_id
		)
		_expect(
			projectile.get_impact_effect_kind()
			== WeaponVisualRenderer.get_impact_effect_kind(definition.visual_data),
			"%s projectile exposes themed impact kind" % weapon_id
		)
		_expect(
			projectile.get_impact_size() >= 16.0,
			"%s projectile exposes non-trivial impact size" % weapon_id
		)
		projectile.queue_free()
		await process_frame

func _validate_gameplay_effect_profiles() -> void:
	var effects := GameplayEffects.new()
	root.add_child(effects)
	await process_frame
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
	await process_frame

func _expect_spawn_effect_kind(
	effects: GameplayEffects,
	weapon_id: StringName,
	expected_kind: StringName
) -> void:
	var projectile := _make_projectile_for(weapon_id)
	effects._on_projectile_spawned(projectile)
	await process_frame
	var child_count := effects.get_child_count()
	var effect := (
		effects.get_child(child_count - 1) as GameplayEffect
		if child_count > 0
		else null
	)
	_expect(
		effect != null and effect.effect_kind == expected_kind,
		"%s spawn effect uses %s" % [weapon_id, expected_kind]
	)
	projectile.queue_free()
	if effect != null:
		effect.queue_free()
	await process_frame

func _expect_impact_effect_kind(
	effects: GameplayEffects,
	weapon_id: StringName,
	expected_kind: StringName
) -> void:
	var projectile := _make_projectile_for(weapon_id)
	effects._on_projectile_impacted(projectile, null, projectile.damage)
	await process_frame
	var child_count := effects.get_child_count()
	var effect := (
		effects.get_child(child_count - 1) as GameplayEffect
		if child_count > 0
		else null
	)
	_expect(
		effect != null and effect.effect_kind == expected_kind,
		"%s impact effect uses %s" % [weapon_id, expected_kind]
	)
	projectile.queue_free()
	if effect != null:
		effect.queue_free()
	await process_frame

func _make_projectile_for(weapon_id: StringName) -> Projectile:
	var definition := WeaponCatalog.get_definition(weapon_id)
	var projectile := Projectile.new()
	projectile.global_position = Vector2(24.0, 12.0)
	projectile.launch(
		Vector2.RIGHT,
		400.0,
		null,
		definition.damage,
		definition.weapon_id,
		definition.visual_data,
		160.0,
		definition.hitbox_type,
		definition.hitbox_size,
		definition.max_hit_count
	)
	root.add_child(projectile)
	return projectile

func _polygon_signature(points: PackedVector2Array) -> String:
	var parts := PackedStringArray()
	for point in points:
		parts.append("%.1f,%.1f" % [point.x, point.y])
	return "|".join(parts)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("WEAPON_PROJECTILE_VFX_IDENTITY_SMOKE_TEST: PASS")
		quit(0)
		return
	print(
		"WEAPON_PROJECTILE_VFX_IDENTITY_SMOKE_TEST: FAIL (%d)"
		% failures.size()
	)
	quit(1)
