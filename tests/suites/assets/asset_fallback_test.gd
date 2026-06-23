extends GutTest
## Assets A4 — Politica di fallback degli asset e percorso standard runtime.
##
## Migra: tests/milestone_10_asset_fallback_policy_smoke_test.gd
## Verifica che la policy disabiliti i fallback impliciti, che ogni contratto punti
## a un asset reale e non-generico con un fallback documentato, e che il survival
## standard non ricada su asset procedurali/placeholder a runtime.

const MainSceneFixture = preload("res://tests/support/main_scene_fixture.gd")

const ASSET_SECTIONS: Array[StringName] = [
	&"tile_sets", &"tile_variants", &"terrain_tiles", &"edge_tiles",
	&"void_tiles", &"object_scenes", &"passage_tiles", &"biome_asset_sets"
]
const MISSING_ASSET_STATUSES: Array[String] = ["needs_asset", "procedural_fallback", "deprecated"]
const STANDARD_SURVIVAL_CONTEXT := {
	"world_seed": 20260621, "biome_map_width": 3, "biome_map_height": 3, "extra_edge_chance": 0.5
}

var _manifest: IsometricEnvironmentManifest
var _allowed_fallback_paths: Array[String] = []

func before_all() -> void:
	_manifest = IsometricEnvironmentManifest.reload_shared()
	var technical := _manifest.get_fallback_policy().get("technical_fallbacks", {}) as Dictionary
	for key in technical.keys():
		_append_unique_path(String(technical.get(key, "")))
	_append_unique_path("res://game/modes/zombie/biome_tile_layer.gd")

func test_manifest_valid() -> void:
	assert_true(_manifest.load_error.is_empty(), "asset fallback policy manifest loads")
	assert_gte(_manifest.version, 9, "asset fallback policy uses manifest v9")
	var report := _manifest.validate()
	assert_true(bool(report.get("is_valid", false)), "asset fallback policy manifest validates")
	if not bool(report.get("is_valid", false)):
		for failure in report.get("failures", PackedStringArray()):
			push_error("manifest failure: " + String(failure))

func test_policy_contract() -> void:
	var policy := _manifest.get_fallback_policy()
	assert_false(bool(policy.get("implicit_fallback_allowed", true)), "implicit fallback stays disabled")
	assert_false(bool(policy.get("bootstrap_requires_external_assets", true)), "bootstrap does not require external assets")
	var allowed_statuses := policy.get("allowed_missing_asset_statuses", []) as Array
	for status in MISSING_ASSET_STATUSES:
		assert_true(allowed_statuses.has(status), "policy documents %s as temporary fallback status" % status)
	var technical := policy.get("technical_fallbacks", {}) as Dictionary
	for required_key in [&"terrain", &"object", &"void", &"passage", &"crate"]:
		assert_true(technical.has(required_key) or technical.has(String(required_key)), "policy declares the %s technical fallback" % String(required_key))
	for key in technical.keys():
		var fallback_path := String(technical.get(key, ""))
		assert_false(fallback_path.is_empty(), "policy declares %s technical fallback" % String(key))
		assert_true(_asset_exists(fallback_path), "%s technical fallback path exists" % String(key))

func test_standard_contract_paths() -> void:
	var checked_contracts := 0
	for section in ASSET_SECTIONS:
		var ids := _manifest.get_asset_contract_ids(section)
		assert_false(ids.is_empty(), "%s asset section is not empty" % String(section))
		for asset_id in ids:
			checked_contracts += 1
			_assert_standard_contract(section, asset_id)
	var checked_draw_objects := 0
	for object_id in _manifest.get_object_ids():
		assert_true(_manifest.has_asset_contract(&"object_scenes", object_id), "%s object has a standard object_scenes contract" % String(object_id))
		if not _manifest.blocks_movement(object_id):
			continue
		checked_draw_objects += 1
		assert_ne(_manifest.get_object_draw_mode(object_id), &"generic_barrier", "%s avoids generic_barrier draw mode in standard manifest" % String(object_id))
		assert_true(_manifest.object_has_dedicated_draw(object_id), "%s keeps dedicated draw metadata" % String(object_id))
	assert_gt(checked_contracts, 0, "standard asset contracts are checked")
	assert_gt(checked_draw_objects, 0, "standard blocking objects have draw metadata checked")

func test_standard_survival_runtime_assets() -> void:
	var scene := MainSceneFixture.new()
	assert_true(scene.boot(self), "main scene loads for standard asset path")
	await wait_frames(2)

	var biome_manager := scene.node(&"biome_manager") as BiomeManager
	var terrain_generator := scene.node(&"terrain_generator") as TerrainGenerator
	var streamer := scene.node(&"world_region_streamer") as WorldRegionStreamer
	assert_not_null(biome_manager, "biome manager is available")
	assert_not_null(terrain_generator, "terrain generator is available")
	assert_not_null(streamer, "world region streamer is available")
	if biome_manager == null or terrain_generator == null or streamer == null:
		scene.teardown()
		await wait_frames(1)
		return

	assert_true(scene.start_survival(STANDARD_SURVIVAL_CONTEXT), "standard survival starts for asset fallback policy")
	await wait_frames(1)
	await wait_physics_frames(1)
	await wait_frames(1)

	var current_region_id := biome_manager.get_current_region_id()
	var tile_layer := terrain_generator.get_active_tile_layer()
	assert_false(current_region_id.is_empty(), "standard survival resolves a current region")
	assert_not_null(tile_layer, "standard survival uses a BiomeTileLayer")
	if tile_layer != null:
		assert_eq(tile_layer.get_missing_asset_count(), 0, "standard tile layer has no missing assets")
		assert_false(tile_layer.uses_procedural_fallback(), "standard tile layer avoids procedural fallback")
	assert_eq(streamer.get_content_level(current_region_id), WorldRegionStreamer.ContentLevel.FULL, "current region is streamed as FULL gameplay content")
	assert_eq(_count_named_prefix(scene.main, "NeighborGround_"), 0, "scene has no legacy neighbor placeholders")
	assert_true(scene.nodes(&"multi_region_renderer").is_empty(), "scene has no legacy multi-region renderer")
	assert_true(scene.nodes(&"biome_transition_gates").is_empty(), "scene has no legacy transition gates")
	_assert_runtime_obstacle_assets(scene)

	scene.stop_survival()
	scene.teardown()
	await wait_frames(1)

# --- helper (porting dei test legacy) ---------------------------------------

func _assert_standard_contract(section: StringName, asset_id: StringName) -> void:
	var label := "%s/%s" % [String(section), String(asset_id)]
	var contract := _manifest.get_asset_contract(section, asset_id)
	assert_false(contract.is_empty(), "%s contract exists" % label)
	if contract.is_empty():
		return
	var status := String(contract.get("status", ""))
	var asset_path := String(contract.get("asset_path", ""))
	var fallback_path := String(contract.get("fallback_path", ""))
	assert_false(MISSING_ASSET_STATUSES.has(status), "%s is not a temporary missing-asset fallback" % label)
	assert_false(asset_path.is_empty(), "%s declares asset_path" % label)
	assert_true(_asset_exists(asset_path), "%s asset_path exists" % label)
	assert_false(_path_has_generic_marker(asset_path), "%s asset_path is not placeholder/generic" % label)
	assert_false(fallback_path.is_empty(), "%s declares explicit fallback_path" % label)
	assert_true(_asset_exists(fallback_path), "%s fallback_path exists" % label)
	assert_true(_allowed_fallback_paths.has(fallback_path), "%s fallback_path is one of the documented technical fallbacks" % label)
	assert_false(_path_has_generic_marker(fallback_path), "%s fallback_path is not placeholder/generic" % label)

func _assert_runtime_obstacle_assets(scene: MainSceneFixture) -> void:
	var inspected_asset_objects := 0
	var checked_runtime_obstacles := 0
	var obstacle_nodes := scene.nodes(&"environment_obstacles")
	assert_false(obstacle_nodes.is_empty(), "standard survival streams environment obstacles")
	for node in obstacle_nodes:
		if not is_instance_valid(node):
			continue
		checked_runtime_obstacles += 1
		if node.has_method("uses_generic_fallback"):
			assert_false(bool(node.call("uses_generic_fallback")), "%s avoids generic fallback at runtime" % String(node.name))
		var obstacle := node as IsometricEnvironmentObject
		if obstacle == null:
			continue
		if obstacle.is_perimeter_wall():
			continue
		inspected_asset_objects += 1
		assert_true(obstacle.has_asset_sprite(), "%s has an asset sprite" % String(obstacle.obstacle_id))
		assert_false(obstacle.uses_procedural_fallback(), "%s avoids procedural fallback at runtime" % String(obstacle.obstacle_id))
		assert_false(_path_has_generic_marker(obstacle.get_asset_path()), "%s runtime asset path is not placeholder/generic" % String(obstacle.obstacle_id))
	assert_gt(checked_runtime_obstacles, 0, "standard survival runtime obstacles are checked")
	assert_gt(inspected_asset_objects, 0, "standard survival inspects asset-backed obstacle objects")

func _count_named_prefix(node: Node, prefix: String) -> int:
	var count := 1 if node.name.begins_with(prefix) else 0
	for child in node.get_children():
		count += _count_named_prefix(child, prefix)
	return count

func _append_unique_path(path: String) -> void:
	if not path.is_empty() and not _allowed_fallback_paths.has(path):
		_allowed_fallback_paths.append(path)

func _path_has_generic_marker(path: String) -> bool:
	var lower_path := path.to_lower()
	return lower_path.contains("placeholder") or lower_path.contains("generic")

func _asset_exists(asset_path: String) -> bool:
	if asset_path.is_empty():
		return false
	return ResourceLoader.exists(asset_path) or FileAccess.file_exists(asset_path)
