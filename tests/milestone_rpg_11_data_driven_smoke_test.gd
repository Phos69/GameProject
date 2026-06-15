extends SceneTree

var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var ids := RpgCharacterRegistry.get_character_ids()
	_expect(ids.size() == 4, "registry exposes four starter characters")
	_expect(ids.has(&"ranger"), "registry exposes ranger")
	_expect(ids.has(&"pistoliere"), "registry exposes pistoliere")
	_expect(ids.has(&"berserker"), "registry exposes berserker")
	_expect(ids.has(&"spadaccino"), "registry exposes spadaccino")

	for character_id in ids:
		var path := str(
			RpgCharacterRegistry.CHARACTER_RESOURCE_PATHS[character_id]
		)
		var data := load(path) as RpgCharacterData
		_expect(data != null, "%s resource loads" % str(character_id))
		if data == null:
			continue
		var profile := RpgCharacterRegistry.get_character_profile(character_id)
		_expect(profile.get("id", &"") == character_id, "%s profile id matches" % str(character_id))
		_expect(
			profile.get("base_weapon_id", &"") == data.base_weapon_id,
			"%s profile comes from resource weapon id" % str(character_id)
		)
		_expect(
			profile.get("super_id", &"") == data.super_id,
			"%s profile comes from resource super id" % str(character_id)
		)

	var fallback := RpgCharacterRegistry.get_character_profile(&"missing_class")
	_expect(
		fallback.get("id", &"") == RpgCharacterRegistry.DEFAULT_CHARACTER_ID,
		"unknown character falls back to default profile"
	)

	_finish()

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("MILESTONE_RPG_11_DATA_DRIVEN_SMOKE_TEST: PASS")
		quit(0)
		return

	print("MILESTONE_RPG_11_DATA_DRIVEN_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
