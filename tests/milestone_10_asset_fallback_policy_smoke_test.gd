extends SceneTree

const ASSET_SECTIONS: Array[StringName] = [
	&"tile_sets",
	&"tile_variants",
	&"terrain_tiles",
	&"edge_tiles",
	&"void_tiles",
	&"object_scenes",
	&"passage_tiles",
	&"biome_asset_sets"
]
const MISSING_ASSET_STATUSES: Array[String] = [
	"needs_asset",
	"procedural_fallback",
	"deprecated"
]
const STANDARD_SURVIVAL_CONTEXT := {
	"world_seed": 20260621,
	"biome_map_width": 3,
	"biome_map_height": 3,
	"extra_edge_chance": 0.5
}

var failures: PackedStringArray = []
var allowed_fallback_paths: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var manifest := IsometricEnvironmentManifest.reload_shared()
	_expect(manifest.load_error.is_empty(), "asset fallback policy manifest loads")
	_expect(manifest.version >= 9, "asset fallback policy uses manifest v9")
	var report := manifest.validate()
	_expect(bool(report.get("is_valid", false)), "asset fallback policy manifest validates")
	if not bool(report.get("is_valid", false)):
		for failure in report.get("failures", PackedStringArray()):
			push_error("manifest failure: " + String(failure))

	_run_policy_contract(manifest)
	_run_asset_contract_standard_paths(manifest)
	await _run_standard_survival_asset_path()
	_finish()

func _run_policy_contract(manifest: IsometricEnvironmentManifest) -> void:
	var policy := manifest.get_fallback_policy()
	_expect(not bool(policy.get("implicit_fallback_allowed", true)), "implicit fallback stays disabled")
	_expect(
		not bool(policy.get("bootstrap_requires_external_assets", true)),
		"bootstrap does not require external assets"
	)
	var allowed_statuses := policy.get("allowed_missing_asset_statuses", []) as Array
	for status in MISSING_ASSET_STATUSES:
		_expect(allowed_statuses.has(status), "policy documents %s as temporary fallback status" % status)

	var technical := policy.get("technical_fallbacks", {}) as Dictionary
	for key in [&"terrain", &"terrain_patch", &"object", &"void", &"passage", &"crate"]:
		var fallback_path := String(technical.get(key, ""))
		_expect(not fallback_path.is_empty(), "policy declares %s technical fallback" % String(key))
		_expect(_asset_exists(fallback_path), "%s technical fallback path exists" % String(key))
		_append_unique_path(fallback_path)
	_append_unique_path("res://game/modes/zombie/biome_tile_layer.gd")

func _run_asset_contract_standard_paths(manifest: IsometricEnvironmentManifest) -> void:
	var checked_contracts := 0
	for section in ASSET_SECTIONS:
		var ids := manifest.get_asset_contract_ids(section)
		_expect(not ids.is_empty(), "%s asset section is not empty" % String(section))
		for asset_id in ids:
			checked_contracts += 1
			_assert_standard_contract(manifest, section, asset_id)
	var checked_draw_objects := 0
	for object_id in manifest.get_object_ids():
		_check(
			manifest.has_asset_contract(&"object_scenes", object_id),
			"%s object has a standard object_scenes contract" % String(object_id)
		)
		if not manifest.blocks_movement(object_id):
			continue
		checked_draw_objects += 1
		_check(
			manifest.get_object_draw_mode(object_id) != &"generic_barrier",
			"%s avoids generic_barrier draw mode in standard manifest" % String(object_id)
		)
		_check(
			manifest.object_has_dedicated_draw(object_id),
			"%s keeps dedicated draw metadata" % String(object_id)
		)
	_expect(checked_contracts > 0, "standard asset contracts are checked")
	_expect(checked_draw_objects > 0, "standard blocking objects have draw metadata checked")

func _assert_standard_contract(
	manifest: IsometricEnvironmentManifest,
	section: StringName,
	asset_id: StringName
) -> void:
	var label := "%s/%s" % [String(section), String(asset_id)]
	var contract := manifest.get_asset_contract(section, asset_id)
	_expect(not contract.is_empty(), "%s contract exists" % label)
	if contract.is_empty():
		return
	var status := String(contract.get("status", ""))
	var asset_path := String(contract.get("asset_path", ""))
	var fallback_path := String(contract.get("fallback_path", ""))
	_check(not MISSING_ASSET_STATUSES.has(status), "%s is not a temporary missing-asset fallback" % label)
	_check(not asset_path.is_empty(), "%s declares asset_path" % label)
	_check(_asset_exists(asset_path), "%s asset_path exists" % label)
	_check(not _path_has_generic_marker(asset_path), "%s asset_path is not placeholder/generic" % label)
	_check(not fallback_path.is_empty(), "%s declares explicit fallback_path" % label)
	_check(_asset_exists(fallback_path), "%s fallback_path exists" % label)
	_check(
		allowed_fallback_paths.has(fallback_path),
		"%s fallback_path is one of the documented technical fallbacks" % label
	)
	_check(not _path_has_generic_marker(fallback_path), "%s fallback_path is not placeholder/generic" % label)

func _run_standard_survival_asset_path() -> void:
	var main_scene := load("res://game/main/main.tscn") as PackedScene
	_expect(main_scene != null, "main scene loads for standard asset path")
	if main_scene == null:
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame

	var game_mode_manager := get_first_node_in_group("game_mode_manager") as GameModeManager
	var wave_manager := get_first_node_in_group("wave_manager") as WaveManager
	var biome_manager := get_first_node_in_group("biome_manager") as BiomeManager
	var terrain_generator := get_first_node_in_group("terrain_generator") as TerrainGenerator
	var streamer := get_first_node_in_group("world_region_streamer") as WorldRegionStreamer
	_expect(game_mode_manager != null, "game mode manager is available")
	_expect(wave_manager != null, "wave manager is available")
	_expect(biome_manager != null, "biome manager is available")
	_expect(terrain_generator != null, "terrain generator is available")
	_expect(streamer != null, "world region streamer is available")
	if (
		game_mode_manager == null
		or wave_manager == null
		or biome_manager == null
		or terrain_generator == null
		or streamer == null
	):
		main.queue_free()
		current_scene = null
		await process_frame
		return

	wave_manager.initial_delay = 100.0
	_expect(
		game_mode_manager.set_mode(GameConstants.MODE_SURVIVAL, STANDARD_SURVIVAL_CONTEXT),
		"standard survival starts for asset fallback policy"
	)
	await process_frame
	await physics_frame
	await process_frame

	var current_region_id := biome_manager.get_current_region_id()
	var tile_layer := terrain_generator.get_active_tile_layer()
	_expect(not current_region_id.is_empty(), "standard survival resolves a current region")
	_expect(tile_layer != null, "standard survival uses a BiomeTileLayer")
	if tile_layer != null:
		_expect(tile_layer.get_missing_asset_count() == 0, "standard tile layer has no missing assets")
		_expect(not tile_layer.uses_procedural_fallback(), "standard tile layer avoids procedural fallback")
	_expect(
		streamer.get_content_level(current_region_id) == WorldRegionStreamer.ContentLevel.FULL,
		"current region is streamed as FULL gameplay content"
	)
	_expect(terrain_generator.get_active_ground() == null, "BiomeRegionGround stays fallback-only")
	_expect(terrain_generator.get_generated_patches().is_empty(), "BiomeTerrainPatch stays fallback-only")
	_expect(_count_biome_region_ground(main) == 0, "scene has no legacy BiomeRegionGround nodes")
	_expect(_count_biome_terrain_patch(main) == 0, "scene has no legacy BiomeTerrainPatch nodes")
	_expect(_count_named_prefix(main, "NeighborGround_") == 0, "scene has no legacy neighbor placeholders")
	_expect(get_nodes_in_group("multi_region_renderer").is_empty(), "scene has no legacy multi-region renderer")
	_expect(get_nodes_in_group("biome_transition_gates").is_empty(), "scene has no legacy transition gates")
	_assert_runtime_obstacle_assets()

	var survival_mode := get_first_node_in_group("survival_mode") as SurvivalMode
	if survival_mode != null:
		survival_mode.stop_mode()
	main.queue_free()
	current_scene = null
	await process_frame

func _assert_runtime_obstacle_assets() -> void:
	var inspected_asset_objects := 0
	var checked_runtime_obstacles := 0
	var obstacle_nodes := get_nodes_in_group("environment_obstacles")
	_expect(not obstacle_nodes.is_empty(), "standard survival streams environment obstacles")
	for node in obstacle_nodes:
		if not is_instance_valid(node):
			continue
		checked_runtime_obstacles += 1
		if node.has_method("uses_generic_fallback"):
			_check(
				not bool(node.call("uses_generic_fallback")),
				"%s avoids generic fallback at runtime" % String(node.name)
			)
		var obstacle := node as IsometricEnvironmentObject
		if obstacle == null:
			continue
		if obstacle.is_perimeter_wall():
			continue
		inspected_asset_objects += 1
		_check(obstacle.has_asset_sprite(), "%s has an asset sprite" % String(obstacle.obstacle_id))
		_check(
			not obstacle.uses_procedural_fallback(),
			"%s avoids procedural fallback at runtime" % String(obstacle.obstacle_id)
		)
		_check(
			not _path_has_generic_marker(obstacle.get_asset_path()),
			"%s runtime asset path is not placeholder/generic" % String(obstacle.obstacle_id)
		)
	_expect(checked_runtime_obstacles > 0, "standard survival runtime obstacles are checked")
	_expect(inspected_asset_objects > 0, "standard survival inspects asset-backed obstacle objects")

func _count_biome_region_ground(node: Node) -> int:
	var count := 1 if node is BiomeRegionGround else 0
	for child in node.get_children():
		count += _count_biome_region_ground(child)
	return count

func _count_biome_terrain_patch(node: Node) -> int:
	var count := 1 if node is BiomeTerrainPatch else 0
	for child in node.get_children():
		count += _count_biome_terrain_patch(child)
	return count

func _count_named_prefix(node: Node, prefix: String) -> int:
	var count := 1 if node.name.begins_with(prefix) else 0
	for child in node.get_children():
		count += _count_named_prefix(child, prefix)
	return count

func _append_unique_path(path: String) -> void:
	if path.is_empty() or allowed_fallback_paths.has(path):
		return
	allowed_fallback_paths.append(path)

func _path_has_generic_marker(path: String) -> bool:
	var lower_path := path.to_lower()
	return lower_path.contains("placeholder") or lower_path.contains("generic")

func _asset_exists(asset_path: String) -> bool:
	if asset_path.is_empty():
		return false
	if ResourceLoader.exists(asset_path):
		return true
	return FileAccess.file_exists(asset_path)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("MILESTONE_10_ASSET_FALLBACK_POLICY_SMOKE_TEST: PASS")
		quit(0)
		return
	print("MILESTONE_10_ASSET_FALLBACK_POLICY_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
