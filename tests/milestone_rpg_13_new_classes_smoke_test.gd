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

	var rpg_component := player.get_node("RpgPlayerComponent") as RpgPlayerComponent
	var weapon_system := player.get_node("WeaponSystem") as WeaponSystem
	_expect(rpg_component != null, "rpg component is available")
	_expect(weapon_system != null, "weapon system is available")
	if rpg_component == null or weapon_system == null:
		_finish()
		return

	var expected := {
		&"mago": [&"rpg_staff", &"arcane_resonance", &"falling_star"],
		&"domatrice": [&"rpg_slingshot", &"briciola_attack", &"scrap_pack"],
		&"licantropo": [&"rpg_claws", &"blood_scent", &"beast_night"]
	}
	for character_id in expected.keys():
		_expect(player.apply_rpg_character(character_id), "%s can be applied" % str(character_id))
		_expect(weapon_system.weapon_data.weapon_id == expected[character_id][0], "%s equips expected weapon" % str(character_id))
		_expect(rpg_component.get_passive_id() == expected[character_id][1], "%s exposes expected passive" % str(character_id))
		_expect(rpg_component.get_super_id() == expected[character_id][2], "%s exposes expected super" % str(character_id))
		_expect(not str(rpg_component.get_hero_name()).is_empty(), "%s exposes hero name" % str(character_id))

	player.apply_rpg_character(&"domatrice")
	await process_frame
	_expect(
		rpg_component.briciola_companion != null and is_instance_valid(rpg_component.briciola_companion),
		"domatrice spawns Briciola companion"
	)
	player.apply_rpg_character(&"mago")
	await process_frame
	_expect(
		rpg_component.briciola_companion == null or not is_instance_valid(rpg_component.briciola_companion),
		"changing away from domatrice removes Briciola"
	)

	player.apply_rpg_character(&"licantropo")
	rpg_component.add_adrenaline(100)
	var beast_used := rpg_component.try_activate_super(Vector2.RIGHT)
	_expect(beast_used, "licantropo super activates")
	_expect(rpg_component.is_beast_transformed(), "licantropo enters transformed state")

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
		print("MILESTONE_RPG_13_NEW_CLASSES_SMOKE_TEST: PASS")
		quit(0)
		return

	print("MILESTONE_RPG_13_NEW_CLASSES_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
