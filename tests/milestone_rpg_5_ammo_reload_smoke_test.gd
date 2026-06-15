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
	var weapon_system := player.get_node("WeaponSystem") as WeaponSystem
	weapon_system.current_ammo = 0
	weapon_system.start_reload()
	var expected_reload := 0.55 / 1.08
	_expect(
		is_equal_approx(weapon_system.reload_timer, expected_reload),
		"reload speed multiplier modifies reload duration"
	)
	_expect(weapon_system.get_reload_ratio() == 0.0, "reload ratio starts empty")
	await process_frame
	_expect(weapon_system.get_reload_ratio() >= 0.0, "reload ratio is exposed during reload")

	var card := PlayerHudCard.new()
	root.add_child(card)
	await process_frame
	card.configure(1, Color(0.18, 0.74, 0.95, 1.0))
	card.refresh(player)
	_expect(card.ammo_pips.size() == 1, "bow HUD shows one ammo pip")
	_expect(card.reload_bar.value >= 0.0, "HUD reload bar is available")

	player.apply_rpg_character(&"pistoliere")
	card.refresh(player)
	_expect(card.ammo_pips.size() == 8, "pistol HUD shows eight ammo pips")

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
