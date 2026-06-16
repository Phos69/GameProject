extends SceneTree

func _initialize() -> void:
	var paths := ["infected_plains", "toxic_wastes", "burning_fields", "frozen_outskirts", "drowned_marsh"]
	var thematic := {&"toxic_wastes": [&"toxic_zombie", &"toxic_exploder"], &"burning_fields": [&"burned_zombie", &"fire_runner", &"fire_exploder"], &"frozen_outskirts": [&"frozen_zombie", &"ice_armored_zombie", &"heavy_slow_zombie"], &"drowned_marsh": [&"drowned_zombie", &"marsh_zombie", &"water_emerging_zombie"]}
	for id in paths:
		var biome := load("res://game/modes/zombie/biomes/%s.tres" % id) as BiomeDefinition
		_assert(biome != null, "loads %s" % id)
		var found := false
		for i in range(16):
			if (thematic.get(biome.biome_id, [biome.base_enemy_id]) as Array).has(biome.resolve_enemy_id(4, i, 16)):
				found = true
		_assert(found, "thematic roster for %s" % id)
	print("biome_roster_smoke_test passed"); quit(0)
func _assert(ok: bool, message: String) -> void:
	if not ok: push_error(message); quit(1)
