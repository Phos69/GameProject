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
	player.apply_rpg_character(&"ranger")
	var world_hud := player.get_node("WorldHud")
	_expect(world_hud != null, "player has a world-space HUD package")
	var weapon_system := player.get_node("WeaponSystem") as WeaponSystem
	weapon_system.current_ammo = 0
	weapon_system.start_reload()
	var expected_reload := 0.55 / 1.08
	_expect(
		is_equal_approx(weapon_system.reload_timer, expected_reload),
		"reload speed multiplier modifies reload duration"
	)
	_expect(weapon_system.get_reload_ratio() == 0.0, "reload ratio starts empty")
	_expect(world_hud.is_showing_reload(), "world HUD switches to reload state")
	await process_frame
	_expect(weapon_system.get_reload_ratio() >= 0.0, "reload ratio is exposed during reload")
	_expect(world_hud.get_reload_ratio() >= 0.0, "world HUD exposes reload progress")

	var card := PlayerHudCard.new()
	root.add_child(card)
	await process_frame
	card.configure(1, Color(0.18, 0.74, 0.95, 1.0))
	card.refresh(player)
	_expect(card.ammo_pips.is_empty(), "corner card no longer owns magazine pips")
	_expect(card.reload_bar == null, "corner card no longer duplicates reload bar")
	_expect(world_hud.get_magazine_size() == 1, "bow world HUD uses one ammo segment")

	player.apply_rpg_character(&"pistoliere")
	await process_frame
	card.refresh(player)
	_expect(world_hud.get_magazine_size() == 8, "pistol world HUD shows eight-shot magazine")

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
		print("MILESTONE_RPG_5_AMMO_RELOAD_SMOKE_TEST: PASS")
		quit(0)
		return

	print("MILESTONE_RPG_5_AMMO_RELOAD_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
