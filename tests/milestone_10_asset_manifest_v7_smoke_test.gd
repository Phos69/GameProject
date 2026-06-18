extends SceneTree

const REQUIRED_SECTIONS: Array[StringName] = [
	&"tile_sets",
	&"tile_variants",
	&"terrain_tiles",
	&"edge_tiles",
	&"void_tiles",
	&"object_scenes",
	&"passage_tiles",
	&"biome_asset_sets"
]
const GENERATED_WORLD_CONTEXT := {
	"world_seed": 717171,
	"biome_map_width": 5,
	"biome_map_height": 5,
	"preserve_biome_sequence": false
}

var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var manifest := IsometricEnvironmentManifest.reload_shared()
	_expect(manifest.load_error.is_empty(), "manifest v7 loads")
	_expect(manifest.version >= 7, "manifest version is v7 or newer")
	var report := manifest.validate()
	_expect(bool(report.get("is_valid", false)), "manifest v7 validates")
	if not bool(report.get("is_valid", false)):
		for failure in report.get("failures", PackedStringArray()):
			push_error("manifest v7 failure: " + String(failure))

	_run_section_inventory(manifest)
	_run_fallback_policy(manifest)
	await _run_generated_contract_coverage(manifest)
	_run_asset_fallback_smoke(manifest)

	_finish()

func _run_section_inventory(manifest: IsometricEnvironmentManifest) -> void:
	for section in REQUIRED_SECTIONS:
		var ids := manifest.get_asset_contract_ids(section)
		_expect(not ids.is_empty(), "%s section has asset contracts" % String(section))
		for asset_id in ids:
			_assert_contract_shape(manifest.get_asset_contract(section, asset_id), "%s/%s" % [String(section), String(asset_id)])
	for biome_id in [
		&"infected_plains",
		&"toxic_wastes",
		&"burning_fields",
		&"frozen_outskirts",
		&"drowned_marsh"
	]:
		_expect(
			manifest.has_asset_contract(&"biome_asset_sets", biome_id),
			"%s has a biome asset set" % String(biome_id)
		)

func _run_fallback_policy(manifest: IsometricEnvironmentManifest) -> void:
	var policy := manifest.get_fallback_policy()
	_expect(not bool(policy.get("implicit_fallback_allowed", true)), "implicit fallback is disabled")
	_expect(not bool(policy.get("bootstrap_requires_external_assets", true)), "bootstrap does not require external assets")
	var technical := policy.get("technical_fallbacks", {}) as Dictionary
	for key in [&"terrain", &"terrain_patch", &"object", &"void", &"passage", &"crate"]:
		_expect(not String(technical.get(key, "")).is_empty(), "fallback policy declares %s fallback" % String(key))

func _run_generated_contract_coverage(manifest: IsometricEnvironmentManifest) -> void:
	var biome_manager := BiomeManager.new()
	root.add_child(biome_manager)
	await process_frame
	biome_manager.start_run(GENERATED_WORLD_CONTEXT)

	var cells := biome_manager.get_generated_biome_map()
	_expect(cells.size() == 25, "v7 contract smoke generates a 5x5 map")
	var generated_object_ids: Array[StringName] = []
	var generated_terrain_tags: Array[StringName] = []
	var generated_passage_types: Array[StringName] = []
	var generated_border_ids: Array[StringName] = []
	var has_fall_zone := false
	for cell in cells:
		var layout := cell.generated_layout
		_expect(layout != null, "%s has generated layout" % String(cell.id))
		if layout == null:
			continue
		for obstacle_id in layout.obstacle_ids:
			_append_unique(generated_object_ids, obstacle_id)
			if _is_border_id(obstacle_id):
				_append_unique(generated_border_ids, obstacle_id)
		for terrain_tag in layout.terrain_patch_tags:
			_append_unique(generated_terrain_tags, terrain_tag)
		for passage in cell.passages:
			_append_unique(generated_passage_types, passage.passage_type)
		if not layout.fall_zone_rects.is_empty():
			has_fall_zone = true

	for object_id in generated_object_ids:
		_expect(
			manifest.has_asset_contract(&"object_scenes", object_id),
			"%s generated object has object_scenes contract" % String(object_id)
		)
	for terrain_tag in generated_terrain_tags:
		_expect(
			manifest.has_asset_contract(&"terrain_tiles", terrain_tag),
			"%s generated terrain tag has terrain_tiles contract" % String(terrain_tag)
		)
	for passage_type in generated_passage_types:
		_expect(
			manifest.has_asset_contract(&"passage_tiles", passage_type),
			"%s generated passage type has passage_tiles contract" % String(passage_type)
		)
	for border_id in generated_border_ids:
		_expect(
			manifest.has_asset_contract(&"edge_tiles", border_id),
			"%s generated border has edge_tiles contract" % String(border_id)
		)
	_expect(has_fall_zone, "generated map contains at least one fall zone")
	_expect(manifest.has_asset_contract(&"void_tiles", &"fall_zone"), "fall_zone has void_tiles contract")

	biome_manager.queue_free()
	await process_frame

func _run_asset_fallback_smoke(manifest: IsometricEnvironmentManifest) -> void:
	var contract := manifest.get_object_asset_contract(&"small_rock")
	_assert_contract_shape(contract, "object_scenes/small_rock")
	var asset_path := String(contract.get("asset_path", ""))
	var status := String(contract.get("status", ""))
	_expect(["needs_asset", "base_complete", "needs_polish", "final"].has(status), "planned art status is explicit")
	_expect(not asset_path.is_empty(), "planned art declares target asset_path")
	_expect(not String(contract.get("fallback_path", "")).is_empty(), "planned art keeps explicit fallback_path")
	_expect(
		status == "needs_asset" or ResourceLoader.exists(asset_path) or FileAccess.file_exists(asset_path),
		"generated art exists once status advances beyond needs_asset"
	)

func _assert_contract_shape(contract: Dictionary, label: String) -> void:
	_expect(not contract.is_empty(), "%s contract is present" % label)
	if contract.is_empty():
		return
	for key in [
		"asset_path",
		"status",
		"biome_ids",
		"footprint_tiles",
		"anchor",
		"sort_offset",
		"collision_shape",
		"blocks_movement",
		"blocks_projectiles",
		"source",
		"license",
		"attribution_key"
	]:
		_expect(contract.has(key), "%s declares %s" % [label, key])
	_expect(not String(contract.get("asset_path", "")).is_empty(), "%s asset_path is explicit" % label)
	_expect(not String(contract.get("source", "")).is_empty(), "%s source is explicit" % label)
	_expect(not String(contract.get("license", "")).is_empty(), "%s license is explicit" % label)
	_expect(not String(contract.get("attribution_key", "")).is_empty(), "%s attribution is explicit" % label)
	_expect(not (contract.get("biome_ids", []) as Array).is_empty(), "%s biome_ids are explicit" % label)
	var footprint := contract.get("footprint_tiles", Vector2i.ZERO) as Vector2i
	_expect(footprint.x > 0 and footprint.y > 0, "%s footprint is positive" % label)

func _append_unique(values: Array[StringName], value: StringName) -> void:
	if not values.has(value):
		values.append(value)

func _is_border_id(obstacle_id: StringName) -> bool:
	return [
		&"boundary_fence",
		&"toxic_boundary_wall",
		&"lava_boundary",
		&"ice_boundary",
		&"deep_water_boundary"
	].has(obstacle_id)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("MILESTONE_10_ASSET_MANIFEST_V7_SMOKE_TEST: PASS")
		quit(0)
		return
	print("MILESTONE_10_ASSET_MANIFEST_V7_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
