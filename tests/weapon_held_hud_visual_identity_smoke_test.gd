extends SceneTree

const SAMPLE_WEAPON_IDS: Array[StringName] = [
	&"heavy_revolver",
	&"pump_shotgun",
	&"improvised_sniper",
	&"grenade_launcher",
	&"rusty_minigun",
	&"scrap_railgun",
	&"quick_knife",
	&"heavy_axe",
	&"spear",
	&"fireball",
	&"ice_lance",
	&"chain_lightning"
]
const LEGACY_WEAPON_PATHS: Array[String] = [
	"res://game/weapons/starter_pistol.tres",
	"res://game/weapons/prototype_blaster.tres",
	"res://game/weapons/wave_cannon.tres"
]

var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var held_signatures: Dictionary = {}
	var hud_signatures: Dictionary = {}
	var revolver_held_signature := ""
	var shotgun_held_signature := ""
	var revolver_hud_signature := ""
	var shotgun_hud_signature := ""
	var revolver_color := Color.TRANSPARENT
	var shotgun_color := Color.TRANSPARENT

	for weapon_id in SAMPLE_WEAPON_IDS:
		var definition := WeaponCatalog.get_definition(weapon_id)
		_expect(definition != null, "%s catalog definition exists" % weapon_id)
		if definition == null:
			continue
		_expect(definition.visual_data != null, "%s has visual data" % weapon_id)
		if definition.visual_data == null:
			continue
		_expect(
			definition.visual_data.held_shape_id == weapon_id,
			"%s has stable held shape id" % weapon_id
		)
		_expect(
			definition.visual_data.hud_shape_id == weapon_id,
			"%s has stable HUD shape id" % weapon_id
		)

		var player_visual := PlayerVisual.new()
		root.add_child(player_visual)
		player_visual.set_weapon_data(definition)
		var icon := WeaponIcon.new()
		root.add_child(icon)
		icon.size = Vector2(38.0, 24.0)
		icon.set_visual_data(definition.visual_data)
		await process_frame

		_expect(
			player_visual.get_weapon_held_shape_id() == weapon_id,
			"%s player visual resolves held shape" % weapon_id
		)
		_expect(
			icon.get_hud_shape_id() == weapon_id,
			"%s HUD icon resolves HUD shape" % weapon_id
		)
		var held_body := player_visual.get_weapon_held_body_polygon()
		var hud_body := icon.get_hud_body_polygon()
		_expect(held_body.size() >= 3, "%s held body is drawable" % weapon_id)
		_expect(hud_body.size() >= 3, "%s HUD body is drawable" % weapon_id)
		var held_signature := _polygon_signature(held_body)
		var hud_signature := _polygon_signature(hud_body)
		_expect(
			not held_signatures.has(held_signature),
			"%s held silhouette is unique in the W3 sample" % weapon_id
		)
		_expect(
			not hud_signatures.has(hud_signature),
			"%s HUD silhouette is unique in the W3 sample" % weapon_id
		)
		held_signatures[held_signature] = weapon_id
		hud_signatures[hud_signature] = weapon_id

		if weapon_id == &"heavy_revolver":
			revolver_held_signature = held_signature
			revolver_hud_signature = hud_signature
			revolver_color = definition.visual_data.secondary_color
		elif weapon_id == &"pump_shotgun":
			shotgun_held_signature = held_signature
			shotgun_hud_signature = hud_signature
			shotgun_color = definition.visual_data.secondary_color

		player_visual.queue_free()
		icon.queue_free()
		await process_frame

	_expect(
		revolver_held_signature != shotgun_held_signature
		and revolver_hud_signature != shotgun_hud_signature,
		"firearm samples differ by held and HUD silhouette"
	)
	_expect(
		revolver_color != shotgun_color,
		"firearm samples differ by color (W6 per-weapon palette)"
	)
	_validate_legacy_weapons()
	_finish()

func _validate_legacy_weapons() -> void:
	for path in LEGACY_WEAPON_PATHS:
		var definition := load(path) as WeaponData
		_expect(definition != null, "%s legacy weapon loads" % path)
		if definition == null or definition.visual_data == null:
			continue
		var profile_id := definition.visual_data.profile_id
		_expect(
			WeaponVisualRenderer.get_weapon_body_polygon(
				definition.visual_data,
				WeaponVisualRenderer.TARGET_HELD
			).size() >= 3,
			"%s legacy held silhouette remains drawable" % profile_id
		)
		_expect(
			WeaponVisualRenderer.get_weapon_body_polygon(
				definition.visual_data,
				WeaponVisualRenderer.TARGET_HUD
			).size() >= 3,
			"%s legacy HUD silhouette remains drawable" % profile_id
		)

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
		print("WEAPON_HELD_HUD_VISUAL_IDENTITY_SMOKE_TEST: PASS")
		quit(0)
		return
	print(
		"WEAPON_HELD_HUD_VISUAL_IDENTITY_SMOKE_TEST: FAIL (%d)"
		% failures.size()
	)
	quit(1)
