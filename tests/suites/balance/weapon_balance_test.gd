extends GutTest
## Balance A10 — Bilanciamento delle classi RPG e delle loro armi base.
##
## Migra:
##   tests/milestone_rpg_10_balance_smoke_test.gd  (registry + WeaponData, logica pura)

func test_rpg_class_and_weapon_balance() -> void:
	var ranger := RpgCharacterRegistry.get_character_profile(&"ranger")
	var pistoliere := RpgCharacterRegistry.get_character_profile(&"pistoliere")
	var berserker := RpgCharacterRegistry.get_character_profile(&"berserker")
	var spadaccino := RpgCharacterRegistry.get_character_profile(&"spadaccino")
	var bow := load("res://game/weapons/rpg_bow.tres") as WeaponData
	var pistol := load("res://game/weapons/rpg_pistol.tres") as WeaponData
	var axe := load("res://game/weapons/rpg_axe.tres") as WeaponData
	var sword := load("res://game/weapons/rpg_sword.tres") as WeaponData
	assert_true(
		bow != null and pistol != null and axe != null and sword != null,
		"all RPG weapons load"
	)
	if bow == null or pistol == null or axe == null or sword == null:
		return

	assert_lt(int(ranger["max_hp"]), int(pistoliere["max_hp"]), "ranger stays fragile")
	assert_true(
		bow.max_range > pistol.max_range and bow.scatter_degrees < pistol.scatter_degrees,
		"ranger owns precision range"
	)
	assert_gt(
		_distance_damage(bow, ranger), _raw_hit_damage(pistol, pistoliere),
		"ranger gets a clear distance payoff"
	)

	assert_gt(float(pistoliere["speed"]), float(ranger["speed"]), "pistoliere is the fastest starter")
	assert_true(
		pistol.magazine_size == 8 and pistol.fire_rate >= 5.5,
		"pistoliere remains accessible and rhythmic"
	)
	assert_lte(_simple_dps(pistol, pistoliere), 85.0, "pistoliere DPS is capped below runaway values")

	assert_gt(int(berserker["max_hp"]), int(spadaccino["max_hp"]), "berserker has the largest HP pool")
	assert_lt(float(berserker["speed"]), 1.0, "berserker pays for power with speed")
	assert_true(
		axe.damage > bow.damage and axe.max_hit_count >= 4,
		"berserker owns heavy multi-hit damage"
	)

	assert_gt(int(spadaccino["defense"]), int(pistoliere["defense"]), "spadaccino owns the defense niche")
	assert_true(
		sword.max_range > axe.max_range and sword.max_hit_count >= 3,
		"spadaccino has safer melee control"
	)
	assert_lt(sword.reload_duration, axe.reload_duration, "spadaccino recovers faster than berserker")

func _raw_hit_damage(weapon_data: WeaponData, profile: Dictionary) -> float:
	return float(weapon_data.damage + int(profile.get("attack", 0)))

func _distance_damage(weapon_data: WeaponData, profile: Dictionary) -> float:
	return _raw_hit_damage(weapon_data, profile) * 1.30

func _simple_dps(weapon_data: WeaponData, profile: Dictionary) -> float:
	return _raw_hit_damage(weapon_data, profile) * weapon_data.fire_rate
