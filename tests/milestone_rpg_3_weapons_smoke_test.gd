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

	var weapon_system := player.get_node("WeaponSystem") as WeaponSystem
	_expect(weapon_system != null, "weapon system is available")
	if weapon_system == null:
		_finish()
		return

	var expected_weapons := {
		&"ranger": &"rpg_bow",
		&"pistoliere": &"rpg_pistol",
		&"berserker": &"rpg_axe",
		&"spadaccino": &"rpg_sword"
	}
	for character_id in expected_weapons.keys():
		_expect(
			player.apply_rpg_character(StringName(character_id)),
			"%s character can be applied" % str(character_id)
		)
		_expect(
			weapon_system.weapon_data.weapon_id == expected_weapons[character_id],
			"%s equips expected base weapon" % str(character_id)
		)
		_expect(
			weapon_system.weapon_data.infinite_reserve_ammo,
			"%s base weapon keeps an infinite reserve" % str(character_id)
		)

	var bow := load("res://game/weapons/rpg_bow.tres") as WeaponData
	var pistol := load("res://game/weapons/rpg_pistol.tres") as WeaponData
	var axe := load("res://game/weapons/rpg_axe.tres") as WeaponData
	var sword := load("res://game/weapons/rpg_sword.tres") as WeaponData
	_expect(bow.damage == 20 and bow.max_range == 750.0, "bow has long precise profile")
	_expect(pistol.magazine_size == 8 and pistol.scatter_degrees == 8.0, "pistol has eight shots and scatter")
	_expect(axe.damage == 28 and axe.max_range == 95.0, "axe is high damage and short range")
	_expect(sword.magazine_size == 4 and sword.reload_duration == 0.85, "sword has fast four-swing reload")

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
		print("MILESTONE_RPG_3_WEAPONS_SMOKE_TEST: PASS")
		quit(0)
		return

	print("MILESTONE_RPG_3_WEAPONS_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
