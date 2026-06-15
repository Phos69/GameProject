extends SceneTree

var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var ranger := RpgCharacterRegistry.get_character_profile(&"ranger")
	var pistoliere := RpgCharacterRegistry.get_character_profile(&"pistoliere")
	var berserker := RpgCharacterRegistry.get_character_profile(&"berserker")
	var spadaccino := RpgCharacterRegistry.get_character_profile(&"spadaccino")
	var bow := load("res://game/weapons/rpg_bow.tres") as WeaponData
	var pistol := load("res://game/weapons/rpg_pistol.tres") as WeaponData
	var axe := load("res://game/weapons/rpg_axe.tres") as WeaponData
	var sword := load("res://game/weapons/rpg_sword.tres") as WeaponData
	_expect(bow != null and pistol != null and axe != null and sword != null, "all RPG weapons load")
	if bow == null or pistol == null or axe == null or sword == null:
		_finish()
		return

	_expect(int(ranger["max_hp"]) < int(pistoliere["max_hp"]), "ranger stays fragile")
	_expect(bow.max_range > pistol.max_range and bow.scatter_degrees < pistol.scatter_degrees, "ranger owns precision range")
	_expect(_distance_damage(bow, ranger) > _raw_hit_damage(pistol, pistoliere), "ranger gets a clear distance payoff")

	_expect(float(pistoliere["speed"]) > float(ranger["speed"]), "pistoliere is the fastest starter")
	_expect(pistol.magazine_size == 8 and pistol.fire_rate >= 5.5, "pistoliere remains accessible and rhythmic")
	_expect(_simple_dps(pistol, pistoliere) <= 85.0, "pistoliere DPS is capped below runaway values")

	_expect(int(berserker["max_hp"]) > int(spadaccino["max_hp"]), "berserker has the largest HP pool")
	_expect(float(berserker["speed"]) < 1.0, "berserker pays for power with speed")
	_expect(axe.damage > bow.damage and axe.max_hit_count >= 4, "berserker owns heavy multi-hit damage")

	_expect(int(spadaccino["defense"]) > int(pistoliere["defense"]), "spadaccino owns the defense niche")
	_expect(sword.max_range > axe.max_range and sword.max_hit_count >= 3, "spadaccino has safer melee control")
	_expect(sword.reload_duration < axe.reload_duration, "spadaccino recovers faster than berserker")

	_finish()

func _raw_hit_damage(weapon_data: WeaponData, profile: Dictionary) -> float:
	return float(weapon_data.damage + int(profile.get("attack", 0)))

func _distance_damage(weapon_data: WeaponData, profile: Dictionary) -> float:
	return _raw_hit_damage(weapon_data, profile) * 1.30

func _simple_dps(weapon_data: WeaponData, profile: Dictionary) -> float:
	return _raw_hit_damage(weapon_data, profile) * weapon_data.fire_rate

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("MILESTONE_RPG_10_BALANCE_SMOKE_TEST: PASS")
		quit(0)
		return

	print("MILESTONE_RPG_10_BALANCE_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
