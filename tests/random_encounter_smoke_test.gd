extends SceneTree
func _initialize() -> void:
	var root := Node2D.new(); current_scene = root
	var player := Node2D.new(); player.add_to_group("players"); root.add_child(player)
	var encounter := RandomEncounterSystem.new(); root.add_child(encounter); encounter.configure_seed(1234)
	var biome := load("res://game/modes/zombie/biomes/toxic_wastes.tres") as BiomeDefinition
	var result := encounter.force_encounter(biome, &"survivor_cache", 2)
	_assert(result.get("encounter_id") == &"survivor_cache", "cache encounter")
	result = encounter.force_encounter(biome, &"cursed_crate", 2)
	_assert(result.get("reward") == "cursed_loot", "cursed reward")
	encounter.cleanup_encounter()
	print("random_encounter_smoke_test passed"); quit(0)
func _assert(ok: bool, message: String) -> void:
	if not ok: push_error(message); quit(1)
