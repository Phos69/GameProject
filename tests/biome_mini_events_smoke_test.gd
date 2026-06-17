extends SceneTree

var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene_root := Node2D.new()
	root.add_child(scene_root)
	current_scene = scene_root
	var player := Node2D.new()
	player.name = "FarPlayer"
	player.add_to_group("players")
	scene_root.add_child(player)
	var exposed_player := Node2D.new()
	exposed_player.name = "ExposedPlayer"
	exposed_player.add_to_group("players")
	scene_root.add_child(exposed_player)
	var visual_settings := VisualSettingsManager.new()
	scene_root.add_child(visual_settings)
	var hazard_system := HazardSystem.new()
	scene_root.add_child(hazard_system)
	var crate_system := ResourceCrateSystem.new()
	scene_root.add_child(crate_system)
	var encounter := RandomEncounterSystem.new()
	scene_root.add_child(encounter)
	await process_frame
	encounter.danger_telegraph_duration = 0.01
	encounter.configure_seed(2026)
	visual_settings.apply_profile(&"high_contrast")
	var cases := {
		&"toxic_wastes": &"toxic_leak",
		&"burning_fields": &"fire_breakout",
		&"frozen_outskirts": &"whiteout",
		&"drowned_marsh": &"marsh_emergence"
	}
	for biome_id in cases.keys():
		_validate_biome_event(
			encounter,
			visual_settings,
			StringName(biome_id),
			StringName(cases[biome_id])
		)
	await _validate_whiteout_status_is_avoidable(
		encounter,
		hazard_system,
		player,
		exposed_player
	)
	await create_timer(0.05).timeout
	encounter.cleanup_encounter()
	hazard_system.stop_run()
	await process_frame
	if current_scene != null:
		current_scene.queue_free()
		current_scene = null
	await process_frame
	_finish()

func _validate_biome_event(
	encounter: RandomEncounterSystem,
	visual_settings: VisualSettingsManager,
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
	var telegraph := _find_telegraph(result)
	var reward_crate := _find_reward_crate(result)
	_expect(
		result.get("encounter_id") == expected_event_id,
		"%s starts expected event" % String(expected_event_id)
	)
	_expect(
		telegraph != null,
		"%s spawns a world-space telegraph" % String(expected_event_id)
	)
	if telegraph != null:
		_expect(
			telegraph.encounter_id == expected_event_id,
			"%s telegraph keeps the mini-event id" % String(expected_event_id)
		)
		_expect(
			telegraph.high_contrast,
			"%s telegraph supports high contrast" % String(expected_event_id)
		)
		visual_settings.apply_profile(&"reduced_motion")
		_expect(
			telegraph.reduced_motion,
			"%s telegraph supports reduced motion" % String(expected_event_id)
		)
		visual_settings.apply_profile(&"high_contrast")
	_expect(
		reward_crate != null,
		"%s spawns a concrete reward crate" % String(expected_event_id)
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
			_expect(
				StringName(tuning.get("reward_crate_id", &""))
				in [&"biome_toxic", &"biome_fire"],
				"%s uses a biome reward crate" % String(expected_event_id)
			)
		&"whiteout":
			_expect(
				result.get("reward") == "frost_cache",
				"whiteout exposes frost reward"
			)
			_expect(
				StringName(tuning.get("reward_crate_id", &""))
				== &"biome_frost",
				"whiteout uses frost crate reward"
			)
		&"marsh_emergence":
			_expect(
				int(tuning.get("enemy_count", 0)) >= 3,
				"marsh emergence scales enemy count"
			)
			_expect(
				StringName(tuning.get("reward_crate_id", &""))
				== &"biome_marsh",
				"marsh emergence uses marsh crate reward"
			)
		_:
			pass

func _validate_whiteout_status_is_avoidable(
	encounter: RandomEncounterSystem,
	hazard_system: HazardSystem,
	far_player: Node2D,
	exposed_player: Node2D
) -> void:
	var biome := load(
		"res://game/modes/zombie/biomes/frozen_outskirts.tres"
	) as BiomeDefinition
	_expect(biome != null, "frozen biome loads for whiteout status")
	if biome == null:
		return
	hazard_system.start_run(biome)
	far_player.global_position = Vector2.ZERO
	var result := encounter.force_encounter(biome, &"whiteout", 6)
	exposed_player.global_position = result.get("position") as Vector2
	await create_timer(0.05).timeout
	_expect(
		not hazard_system.has_status(far_player, &"freeze"),
		"whiteout does not affect players outside the telegraph"
	)
	_expect(
		hazard_system.has_status(exposed_player, &"freeze"),
		"whiteout affects players that remain inside the telegraph"
	)
	hazard_system.stop_run()

func _find_telegraph(result: Dictionary) -> EncounterTelegraphMarker:
	for entity in result.get("entities", []):
		if entity is EncounterTelegraphMarker:
			return entity as EncounterTelegraphMarker
	return null

func _find_reward_crate(result: Dictionary) -> SupplyCrate:
	for entity in result.get("entities", []):
		if entity is SupplyCrate:
			return entity as SupplyCrate
	return null

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
		return
	print("biome_mini_events_smoke_test failed: %d" % failures.size())
	quit(1)
