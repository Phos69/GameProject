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

## BAL-001: anche le tre classi avanzate hanno una nicchia data-driven chiara,
## e nessuna coppia di classi condivide la stessa statline.
func test_advanced_class_niches() -> void:
	var mago := RpgCharacterRegistry.get_character_profile(&"mago")
	var domatrice := RpgCharacterRegistry.get_character_profile(&"domatrice")
	var licantropo := RpgCharacterRegistry.get_character_profile(&"licantropo")
	var ranger := RpgCharacterRegistry.get_character_profile(&"ranger")
	var pistoliere := RpgCharacterRegistry.get_character_profile(&"pistoliere")
	var berserker := RpgCharacterRegistry.get_character_profile(&"berserker")
	var spadaccino := RpgCharacterRegistry.get_character_profile(&"spadaccino")
	var staff := load("res://game/weapons/rpg_staff.tres") as WeaponData
	var slingshot := load("res://game/weapons/rpg_slingshot.tres") as WeaponData
	var claws := load("res://game/weapons/rpg_claws.tres") as WeaponData
	var pistol := load("res://game/weapons/rpg_pistol.tres") as WeaponData
	var bow := load("res://game/weapons/rpg_bow.tres") as WeaponData
	var sword := load("res://game/weapons/rpg_sword.tres") as WeaponData
	var axe := load("res://game/weapons/rpg_axe.tres") as WeaponData
	assert_true(
		staff != null and slingshot != null and claws != null,
		"all advanced RPG weapons load"
	)
	if staff == null or slingshot == null or claws == null:
		return

	# Mago: glass cannon di precisione — attack piu' alto del comparto ranged,
	# arma senza dispersione e burst per caricatore, pagati col pool HP minimo.
	assert_true(
		int(mago["attack"]) > int(ranger["attack"])
		and int(mago["attack"]) > int(pistoliere["attack"])
		and int(mago["attack"]) > int(domatrice["attack"]),
		"mago owns the highest ranged attack stat"
	)
	assert_eq(staff.scatter_degrees, 0.0, "mago fires with perfect accuracy")
	assert_gt(staff.magazine_size, bow.magazine_size, "mago sustains a burst where ranger reloads every shot")
	for other in [ranger, pistoliere, berserker, spadaccino, domatrice, licantropo]:
		assert_lt(int(mago["max_hp"]), int(other["max_hp"]), "mago pays precision with the lowest HP pool")

	# Domatrice: pressione continua — reload piu' rapido del comparto ranged e
	# dispersione dimezzata rispetto alla pistola.
	assert_true(
		float(domatrice["reload_speed"]) > float(ranger["reload_speed"])
		and float(domatrice["reload_speed"]) > float(pistoliere["reload_speed"])
		and float(domatrice["reload_speed"]) > float(mago["reload_speed"]),
		"domatrice owns ranged reload uptime"
	)
	assert_lt(slingshot.scatter_degrees, pistol.scatter_degrees, "domatrice is steadier than the pistol")
	assert_gte(slingshot.fire_rate, 4.0, "domatrice keeps constant pressure")

	# Licantropo: melee veloce — cadenza e recupero migliori del comparto melee,
	# con un pool HP tra spadaccino e berserker.
	assert_true(
		claws.fire_rate > sword.fire_rate and sword.fire_rate > axe.fire_rate,
		"licantropo owns melee attack speed"
	)
	assert_lt(claws.reload_duration, sword.reload_duration, "licantropo recovers fastest in melee")
	assert_true(
		float(licantropo["speed"]) > float(spadaccino["speed"])
		and float(spadaccino["speed"]) > float(berserker["speed"]),
		"licantropo is the fastest melee class"
	)
	assert_true(
		int(berserker["max_hp"]) > int(licantropo["max_hp"])
		and int(licantropo["max_hp"]) > int(spadaccino["max_hp"]),
		"licantropo sits between bruiser and duelist HP pools"
	)

	# Nessuna coppia di classi condivide la stessa statline: ogni scelta nel
	# roster resta distinguibile sui numeri, non solo sull'arma.
	var seen_statlines: Dictionary = {}
	for profile in RpgCharacterRegistry.get_character_profiles():
		var statline := "%d|%d|%d|%.2f" % [
			int(profile.get("max_hp", 0)),
			int(profile.get("attack", 0)),
			int(profile.get("defense", 0)),
			float(profile.get("speed", 0.0))
		]
		assert_false(
			seen_statlines.has(statline),
			"%s has a unique statline (shared with %s)" % [
				str(profile.get("id", "?")),
				str(seen_statlines.get(statline, ""))
			]
		)
		seen_statlines[statline] = str(profile.get("id", "?"))

func _raw_hit_damage(weapon_data: WeaponData, profile: Dictionary) -> float:
	return float(weapon_data.damage + int(profile.get("attack", 0)))

func _distance_damage(weapon_data: WeaponData, profile: Dictionary) -> float:
	return _raw_hit_damage(weapon_data, profile) * 1.30

func _simple_dps(weapon_data: WeaponData, profile: Dictionary) -> float:
	return _raw_hit_damage(weapon_data, profile) * weapon_data.fire_rate
