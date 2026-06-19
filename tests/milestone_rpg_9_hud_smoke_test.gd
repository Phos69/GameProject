extends SceneTree

var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var player_scene := load("res://game/player/player.tscn") as PackedScene
	_expect(player_scene != null, "player scene can be loaded")
	if player_scene == null:
		_finish()
		return

	var player := player_scene.instantiate() as PlayerController
	root.add_child(player)
	await process_frame
	await process_frame

	var rpg_component := player.get_node(
		"RpgPlayerComponent"
	) as RpgPlayerComponent
	var world_hud := player.get_node("WorldHud")
	_expect(rpg_component != null, "rpg component is available")
	_expect(world_hud != null, "world-space player HUD is available")
	if rpg_component == null or world_hud == null:
		_finish()
		return

	player.apply_rpg_character(&"ranger")
	rpg_component.add_experience(20)
	rpg_component.add_adrenaline(100)

	var card := PlayerHudCard.new()
	root.add_child(card)
	await process_frame
	card.configure(1, Color(0.18, 0.74, 0.95, 1.0))
	card.refresh(player)

	_expect(card.portrait_icon != null, "HUD card has a portrait icon")
	_expect(card.portrait_icon.icon_id == &"ranger", "portrait follows selected class")
	_expect(card.weapon_icon.get_profile_id() == &"rpg_bow", "weapon icon follows base weapon")
	_expect(card.ammo_pips.is_empty(), "corner card does not duplicate magazine pips")
	_expect(card.xp_bar == null, "corner card no longer duplicates XP")
	_expect(card.adrenaline_bar == null, "corner card no longer duplicates adrenaline")
	_expect(card.slot_label.text == "P1", "corner card keeps the slot label compact")
	_expect(world_hud.get_magazine_size() == 1, "world HUD exposes bow magazine")
	_expect(world_hud.get_current_ammo() == 1, "world HUD exposes current ammo")
	_expect(
		is_equal_approx(world_hud.get_exp_ratio(), 20.0 / 45.0),
		"world HUD exposes per-run XP ratio"
	)
	_expect(world_hud.get_level() == 1, "world HUD exposes current level")
	_expect(
		is_equal_approx(world_hud.get_super_ratio(), 1.0),
		"world HUD fills super bar at cap"
	)
	_expect(world_hud.is_super_ready_display(), "world HUD exposes super ready state")

	card.queue_free()
	player.queue_free()
	_finish()

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("MILESTONE_RPG_9_HUD_SMOKE_TEST: PASS")
		quit(0)
		return

	print("MILESTONE_RPG_9_HUD_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
