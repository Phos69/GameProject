extends SceneTree
func _initialize() -> void:
	var manifest := IsometricEnvironmentManifest.reload_shared()
	_assert(manifest.load_error.is_empty(), "manifest loads")
	for id in ["infected_plains", "toxic_wastes", "burning_fields", "frozen_outskirts", "drowned_marsh"]:
		var biome := load("res://game/modes/zombie/biomes/%s.tres" % id) as BiomeDefinition
		_assert(biome.environment_layout != null, "layout %s" % id)
		_assert(biome.environment_layout.obstacle_positions.size() > 0, "obstacles %s" % id)
		_assert(biome.environment_layout.central_corridor_width >= 80.0, "corridor %s" % id)
		_assert(_has_two_obstacle_categories(manifest, biome), "obstacle categories %s" % id)
		_assert(_has_dedicated_obstacle_draws(manifest, biome), "dedicated obstacle draws %s" % id)
	print("biome_obstacle_generation_smoke_test passed"); quit(0)

func _has_two_obstacle_categories(
	manifest: IsometricEnvironmentManifest,
	biome: BiomeDefinition
) -> bool:
	var categories := {}
	for obstacle_id in biome.environment_layout.obstacle_ids:
		if not manifest.has_object(obstacle_id):
			continue
		categories[manifest.get_category(obstacle_id)] = true
	return categories.size() >= 2

func _has_dedicated_obstacle_draws(
	manifest: IsometricEnvironmentManifest,
	biome: BiomeDefinition
) -> bool:
	for obstacle_id in biome.environment_layout.obstacle_ids:
		if not manifest.has_object(obstacle_id):
			return false
		if not manifest.object_has_dedicated_draw(obstacle_id):
			return false
		if manifest.get_object_draw_mode(obstacle_id) == &"generic_barrier":
			return false
	return true

func _assert(ok: bool, message: String) -> void:
	if not ok: push_error(message); quit(1)
