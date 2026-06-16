extends SceneTree

var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene_root := Node2D.new()
	root.add_child(scene_root)
	current_scene = scene_root
	var player := Node2D.new()
	player.add_to_group("players")
	scene_root.add_child(player)
	var encounter := RandomEncounterSystem.new()
	scene_root.add_child(encounter)
	await process_frame
	encounter.configure_seed(2026)
	var cases := {
		&"toxic_wastes": &"toxic_leak",
		&"burning_fields": &"fire_breakout",
		&"frozen_outskirts": &"whiteout",
		&"drowned_marsh": &"marsh_emergence"
	}
	for biome_id in cases.keys():
		_validate_biome_event(encounter, StringName(biome_id), StringName(cases[biome_id]))
	encounter.cleanup_encounter()
	_finish()

func _validate_biome_event(
	encounter: RandomEncounterSystem,
	biome_id: StringName,
	expected_event_id: StringName
) -> void:
	var biome := load("res://game/modes/zombie/biomes/%s.tres" % String(biome_id)) as BiomeDefinition
	_expect(biome != null, "%s biome loads" % String(biome_id))
	if biome == null:
		return
	_expect(
		encounter.get_biome_mini_event_id(biome_id) == expected_event_id,
		"%s exposes its mini-event id" % String(biome_id)
	)
	var result := encounter.force_encounter(biome, expected_event_id, 6)
	var tuning := result.get("tuning") as Dictionary
	var snapshot := encounter.get_debug_snapshot()
	_expect(
		result.get("encounter_id") == expected_event_id,
		"%s starts expected event" % String(expected_event_id)
	)
	_expect(
		int(snapshot.get("pending_telegraph_count", 0)) == 1,
		"%s starts a telegraph" % String(expected_event_id)
	)
	_expect(
		int(tuning.get("threat_score", 0)) >= 4,
		"%s has meaningful threat score" % String(expected_event_id)
	)
	match expected_event_id:
		&"toxic_leak", &"fire_breakout":
			_expect(
				int(tuning.get("hazard_count", 0)) >= 3,
				"%s scales hazards" % String(expected_event_id)
			)
		&"whiteout":
			_expect(
				result.get("reward") == "frost_cache",
				"whiteout exposes frost reward"
			)
		&"marsh_emergence":
			_expect(
				int(tuning.get("enemy_count", 0)) >= 3,
				"marsh emergence scales enemy count"
			)
		_:
			pass

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("biome_mini_events_smoke_test passed")
		quit(0)
	print("biome_mini_events_smoke_test failed: %d" % failures.size())
	quit(1)
