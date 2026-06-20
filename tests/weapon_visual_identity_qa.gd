extends SceneTree

const OUTPUT_DIRECTORY := "res://build/qa"
const PICKUP_SCENE_PATH := "res://game/drops/drop_pickup.tscn"
const PICKUP_GRID_FILE := "weapon_visual_identity_pickup_grid.png"
const HELD_HUD_GRID_FILE := "weapon_visual_identity_held_hud_grid.png"
const PICKUP_SAMPLE_WEAPON_IDS: Array[StringName] = [
	&"heavy_revolver",
	&"pump_shotgun",
	&"quick_knife",
	&"heavy_axe",
	&"fireball",
	&"ice_lance",
	&"chain_lightning"
]
const HELD_HUD_SAMPLE_WEAPON_IDS: Array[StringName] = [
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

var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var pickup_scene := load(PICKUP_SCENE_PATH) as PackedScene
	_expect(pickup_scene != null, "pickup scene can be loaded for W2 QA")
	if pickup_scene == null:
		_finish()
		return

	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(OUTPUT_DIRECTORY)
	)
	var stage := Node2D.new()
	stage.name = "WeaponPickupVisualIdentityQaStage"
	root.add_child(stage)
	_spawn_pickup_grid(stage, pickup_scene)
	await process_frame
	await process_frame
	_expect(
		await _capture(PICKUP_GRID_FILE),
		"W2 pickup grid screenshot is captured"
	)
	stage.queue_free()
	await process_frame

	var held_stage := Node2D.new()
	held_stage.name = "WeaponHeldVisualIdentityQaStage"
	root.add_child(held_stage)
	var hud_stage := Control.new()
	hud_stage.name = "WeaponHudVisualIdentityQaStage"
	root.add_child(hud_stage)
	_spawn_held_hud_grid(held_stage, hud_stage)
	await process_frame
	await process_frame
	_expect(
		await _capture(HELD_HUD_GRID_FILE),
		"W3 held/HUD grid screenshot is captured"
	)
	_finish()

func _spawn_pickup_grid(stage: Node2D, pickup_scene: PackedScene) -> void:
	var start := Vector2(160.0, 170.0)
	var spacing := Vector2(120.0, 96.0)
	for index in range(PICKUP_SAMPLE_WEAPON_IDS.size()):
		var weapon_id := PICKUP_SAMPLE_WEAPON_IDS[index]
		var definition := WeaponCatalog.get_definition(weapon_id)
		if definition == null:
			failures.append("%s sample weapon missing" % weapon_id)
			continue
		var pickup := pickup_scene.instantiate() as DropPickup
		pickup.setup({
			"type": GameConstants.DROP_WEAPON,
			"amount": 1,
			"weapon_data": definition
		})
		pickup.position = start + Vector2(
			float(index % 4) * spacing.x,
			float(index / 4) * spacing.y
		)
		stage.add_child(pickup)
	var missing := pickup_scene.instantiate() as DropPickup
	missing.setup({
		"type": GameConstants.DROP_WEAPON,
		"amount": 1
	})
	missing.position = start + Vector2(3.0 * spacing.x, spacing.y)
	stage.add_child(missing)

func _spawn_held_hud_grid(stage: Node2D, hud_stage: Control) -> void:
	var start := Vector2(100.0, 130.0)
	var spacing := Vector2(180.0, 150.0)
	for index in range(HELD_HUD_SAMPLE_WEAPON_IDS.size()):
		var weapon_id := HELD_HUD_SAMPLE_WEAPON_IDS[index]
		var definition := WeaponCatalog.get_definition(weapon_id)
		if definition == null:
			failures.append("%s held/HUD sample weapon missing" % weapon_id)
			continue
		var position := start + Vector2(
			float(index % 4) * spacing.x,
			float(index / 4) * spacing.y
		)
		var player_visual := PlayerVisual.new()
		player_visual.position = position
		player_visual.scale = Vector2(0.88, 0.88)
		player_visual.set_weapon_data(definition)
		player_visual.set_facing(Vector2(0.92, -0.30).normalized())
		player_visual.set_player_slot((index % 4) + 1)
		player_visual.set_process(false)
		stage.add_child(player_visual)

		var icon := WeaponIcon.new()
		icon.position = position + Vector2(-28.0, 46.0)
		icon.size = Vector2(38.0, 24.0)
		icon.set_visual_data(definition.visual_data)
		hud_stage.add_child(icon)

func _capture(file_name: String) -> bool:
	await process_frame
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		return false
	return image.save_png(
		ProjectSettings.globalize_path("%s/%s" % [OUTPUT_DIRECTORY, file_name])
	) == OK

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("WEAPON_VISUAL_IDENTITY_QA: PASS")
		quit(0)
		return
	print("WEAPON_VISUAL_IDENTITY_QA: FAIL (%d)" % failures.size())
	quit(1)
