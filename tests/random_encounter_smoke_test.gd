extends SceneTree

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
	encounter.base_chance = 1.0
	encounter.configure_seed(1234)
	var biome := load("res://game/modes/zombie/biomes/toxic_wastes.tres") as BiomeDefinition

	_assert(
		not encounter.can_start_encounter(biome, 2, true),
		"encounter skips critical/boss state"
	)
	_assert(
		encounter.can_start_encounter(biome, 2, false),
		"encounter can start after wave one"
	)
	var result := encounter.force_encounter(biome, &"survivor_cache", 2)
	_assert(result.get("encounter_id") == &"survivor_cache", "cache encounter")
	_assert(result.has("threat_score"), "encounter exposes threat score")
	var cache_tuning := result.get("tuning") as Dictionary
	_assert(
		int(cache_tuning.get("party_size", 0)) == 1,
		"encounter tuning records active party size"
	)
	_assert(
		not encounter.can_start_encounter(biome, 3, false),
		"encounter cooldown prevents immediate repeats"
	)
	result = encounter.force_encounter(biome, &"cursed_crate", 2)
	_assert(result.get("reward") == "cursed_loot", "cursed reward")
	var cursed_snapshot := encounter.get_debug_snapshot()
	_assert(
		int(cursed_snapshot.get("pending_telegraph_count", 0)) == 1,
		"cursed crate starts a warning telegraph"
	)
	_assert(
		(result.get("position") as Vector2).distance_to(player.global_position)
		>= encounter.safe_distance * 0.75,
		"encounter position stays away from the player"
	)
	result = encounter.force_encounter(biome, &"hazard_burst", 5)
	var hazard_tuning := result.get("tuning") as Dictionary
	_assert(
		int(hazard_tuning.get("hazard_count", 0)) >= 3,
		"hazard burst tuning scales hazard count"
	)
	_assert(
		float(hazard_tuning.get("hazard_lifetime", 0.0)) > 3.0,
		"hazard burst tuning exposes lifetime"
	)
	var hazard_snapshot := encounter.get_debug_snapshot()
	_assert(
		int(hazard_snapshot.get("pending_telegraph_count", 0)) == 1,
		"hazard burst starts a warning telegraph"
	)
	result = encounter.force_encounter(biome, &"toxic_leak", 6)
	var toxic_tuning := result.get("tuning") as Dictionary
	_assert(
		int(toxic_tuning.get("hazard_count", 0)) >= 3,
		"toxic mini-event scales hazard count"
	)
	_assert(
		result.get("reward") == "toxic_salvage",
		"toxic mini-event exposes biome reward"
	)
	encounter.cleanup_encounter()
	print("random_encounter_smoke_test passed")
	quit(0)

func _assert(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		quit(1)
