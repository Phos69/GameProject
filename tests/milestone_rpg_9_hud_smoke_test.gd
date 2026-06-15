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
	_expect(rpg_component != null, "rpg component is available")
	if rpg_component == null:
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
	_expect(card.ammo_pips.size() == 1, "ammo remains graphical through pips")
	_expect(card.xp_bar.value == 20.0, "XP bar exposes per-run XP")
	_expect(
		card.adrenaline_bar.value == float(RpgPlayerComponent.ADRENALINE_MAX),
		"adrenaline bar fills at super cap"
	)
	_expect(card.super_icon != null, "HUD card has a super icon")
	_expect(card.super_icon.icon_id == &"arrow_rain", "super icon follows profile")
	_expect(card.super_icon.is_ready, "super icon exposes ready state")
	_expect(card.super_label.text == "SUPER READY", "super label exposes ready state")

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
