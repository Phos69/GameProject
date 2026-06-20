extends SceneTree

const PICKUP_SCENE_PATH := "res://game/drops/drop_pickup.tscn"
const SAMPLE_WEAPON_IDS: Array[StringName] = [
	&"heavy_revolver",
	&"pump_shotgun",
	&"quick_knife",
	&"heavy_axe",
	&"fireball",
	&"ice_lance",
	&"chain_lightning"
]

var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var pickup_scene := load(PICKUP_SCENE_PATH) as PackedScene
	_expect(pickup_scene != null, "drop pickup scene can be loaded")
	if pickup_scene == null:
		_finish()
		return

	_validate_catalog_pickup_profiles()
	await _validate_sample_pickups(pickup_scene)
	await _validate_non_weapon_pickup(pickup_scene)
	await _validate_missing_weapon_visual(pickup_scene)
	_finish()

func _validate_catalog_pickup_profiles() -> void:
	for weapon_id in WeaponCatalog.get_ids():
		var definition := WeaponCatalog.get_definition(weapon_id)
		_expect(definition != null, "%s catalog definition exists" % weapon_id)
		if definition == null:
			continue
		_expect(
			definition.visual_data != null,
			"%s has visual data" % weapon_id
		)
		if definition.visual_data == null:
			continue
		_expect(
			definition.visual_data.pickup_shape_id == weapon_id,
			"%s uses a stable pickup shape id" % weapon_id
		)
		_expect(
			WeaponVisualRenderer.has_pickup_visual(definition.visual_data),
			"%s does not fall back to missing pickup visual" % weapon_id
		)

func _validate_sample_pickups(pickup_scene: PackedScene) -> void:
	var signatures: Dictionary = {}
	var heavy_revolver_signature := ""
	var pump_shotgun_signature := ""
	var heavy_revolver_color := Color.TRANSPARENT
	var pump_shotgun_color := Color.TRANSPARENT
	for weapon_id in SAMPLE_WEAPON_IDS:
		var definition := WeaponCatalog.get_definition(weapon_id)
		_expect(definition != null, "%s sample weapon exists" % weapon_id)
		if definition == null:
			continue
		var pickup := _spawn_pickup(
			pickup_scene,
			{
				"type": GameConstants.DROP_WEAPON,
				"amount": 1,
				"weapon_data": definition
			}
		)
		await process_frame
		var visual := pickup.visual
		_expect(
			visual.weapon_visual_data == definition.visual_data,
			"%s passes WeaponVisualData to DropPickupVisual" % weapon_id
		)
		_expect(
			visual.get_weapon_pickup_shape_id() == weapon_id,
			"%s pickup resolves its weapon silhouette id" % weapon_id
		)
		_expect(
			not visual.uses_missing_weapon_visual(),
			"%s pickup does not use missing visual fallback" % weapon_id
		)
		var body := visual.get_weapon_pickup_body_polygon()
		_expect(body.size() >= 3, "%s pickup has a drawable body" % weapon_id)
		var signature := _polygon_signature(body)
		_expect(
			not signatures.has(signature),
			"%s pickup silhouette is unique in the W2 sample grid" % weapon_id
		)
		signatures[signature] = weapon_id
		if weapon_id == &"heavy_revolver":
			heavy_revolver_signature = signature
			heavy_revolver_color = definition.visual_data.secondary_color
		elif weapon_id == &"pump_shotgun":
			pump_shotgun_signature = signature
			pump_shotgun_color = definition.visual_data.secondary_color
		_expect(
			definition.visual_data.rarity_glow <= 0.5,
			"%s rarity glow stays below silhouette-covering intensity" % weapon_id
		)
		pickup.queue_free()
		await process_frame
	_expect(
		heavy_revolver_signature != pump_shotgun_signature,
		"two firearm pickups are distinguishable by silhouette"
	)
	_expect(
		heavy_revolver_color != pump_shotgun_color,
		"two firearm pickups are distinguishable by color (W6 per-weapon palette)"
	)

func _validate_non_weapon_pickup(pickup_scene: PackedScene) -> void:
	var pickup := _spawn_pickup(
		pickup_scene,
		{"type": GameConstants.DROP_AMMO, "amount": 6}
	)
	await process_frame
	_expect(
		pickup.visual.weapon_visual_data == null,
		"non-weapon pickup keeps icon-only visual contract"
	)
	_expect(
		not pickup.visual.uses_missing_weapon_visual(),
		"non-weapon pickup does not use weapon missing fallback"
	)
	_expect(
		pickup.visual.get_weapon_pickup_shape_id().is_empty(),
		"non-weapon pickup has no weapon shape id"
	)
	pickup.queue_free()
	await process_frame

func _validate_missing_weapon_visual(pickup_scene: PackedScene) -> void:
	var pickup := _spawn_pickup(
		pickup_scene,
		{"type": GameConstants.DROP_WEAPON, "amount": 1}
	)
	await process_frame
	var visual := pickup.visual
	_expect(
		visual.uses_missing_weapon_visual(),
		"weapon pickup without WeaponVisualData uses explicit missing visual"
	)
	_expect(
		visual.get_weapon_pickup_shape_id()
		== WeaponVisualRenderer.MISSING_PICKUP_SHAPE,
		"missing weapon pickup exposes missing visual id"
	)
	_expect(
		visual.get_weapon_pickup_body_polygon().size() >= 4,
		"missing weapon pickup has an obvious drawable marker"
	)
	visual.animation_time = 3.5
	visual.apply_visual_settings({
		"high_contrast": true,
		"reduced_motion": true
	})
	_expect(visual.high_contrast, "weapon pickup accepts high contrast")
	_expect(visual.reduced_motion, "weapon pickup accepts reduced motion")
	_expect(
		is_equal_approx(visual.animation_time, 0.0),
		"reduced motion stops pickup bobbing animation"
	)
	pickup.queue_free()
	await process_frame

func _spawn_pickup(
	pickup_scene: PackedScene,
	drop_data: Dictionary
) -> DropPickup:
	var pickup := pickup_scene.instantiate() as DropPickup
	pickup.setup(drop_data)
	root.add_child(pickup)
	return pickup

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
		print("WEAPON_PICKUP_VISUAL_IDENTITY_SMOKE_TEST: PASS")
		quit(0)
		return
	print(
		"WEAPON_PICKUP_VISUAL_IDENTITY_SMOKE_TEST: FAIL (%d)"
		% failures.size()
	)
	quit(1)
