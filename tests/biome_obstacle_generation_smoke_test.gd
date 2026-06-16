extends SceneTree
func _initialize() -> void:
	for id in ["infected_plains", "toxic_wastes", "burning_fields", "frozen_outskirts", "drowned_marsh"]:
		var biome := load("res://game/modes/zombie/biomes/%s.tres" % id) as BiomeDefinition
		_assert(biome.environment_layout != null, "layout %s" % id)
		_assert(biome.environment_layout.obstacle_positions.size() > 0, "obstacles %s" % id)
		_assert(biome.environment_layout.central_corridor_width >= 80.0, "corridor %s" % id)
	print("biome_obstacle_generation_smoke_test passed"); quit(0)
func _assert(ok: bool, message: String) -> void:
	if not ok: push_error(message); quit(1)
