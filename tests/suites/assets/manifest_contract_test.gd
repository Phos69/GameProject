extends GutTest
## Assets A4 — Contratto del manifest ambiente top-down + copertura generata.
##
## Migra e accorpa:
##   tests/milestone_10_asset_manifest_v7_smoke_test.gd
##   tests/top_down_environment_manifest_smoke_test.gd
##   tests/biome_obstacle_generation_smoke_test.gd
##
## Il manifest e la megamappa 3x3 (necessaria a verificare che ogni id generato
## abbia un contratto) si costruiscono una sola volta in before_all e si riusano:
## i due test legacy bootavano la mappa separatamente (seed diversi, asserzioni
## generiche sugli id generati), qui basta una build condivisa.

const REQUIRED_SECTIONS: Array[StringName] = [
	&"tile_sets", &"tile_variants", &"terrain_tiles", &"edge_tiles",
	&"void_tiles", &"object_scenes", &"passage_tiles", &"biome_asset_sets"
]
const BIOME_IDS: Array[String] = [
	"infected_plains", "toxic_wastes", "burning_fields", "frozen_outskirts", "drowned_marsh"
]
const GENERATED_WORLD_CONTEXT := {
	"world_seed": 717171, "biome_map_width": 3, "biome_map_height": 3, "preserve_biome_sequence": false
}
const BORDER_IDS: Array[StringName] = [
	&"boundary_fence", &"toxic_boundary_wall", &"lava_boundary", &"ice_boundary", &"deep_water_boundary"
]

var _manifest: EnvironmentAssetManifest
var _biome_manager: BiomeManager
var _cells: Array[BiomeCell]

func before_all() -> void:
	_manifest = EnvironmentAssetManifest.reload_shared()
	_biome_manager = BiomeManager.new()
	add_child(_biome_manager)
	await wait_physics_frames(1)
	_biome_manager.start_run(GENERATED_WORLD_CONTEXT)
	_cells = _biome_manager.get_generated_biome_map()

func after_all() -> void:
	if _biome_manager != null and is_instance_valid(_biome_manager):
		_free_test_node(_biome_manager)
	_biome_manager = null
	_cells = []

# --- validazione e inventario del manifest ----------------------------------

func test_manifest_valid() -> void:
	assert_true(_manifest.load_error.is_empty(), "manifest loads without error")
	assert_gte(_manifest.version, 7, "manifest version is v7 or newer")
	var report := _manifest.validate()
	assert_true(bool(report.get("is_valid", false)), "manifest validates")
	if not bool(report.get("is_valid", false)):
		for failure in report.get("failures", PackedStringArray()):
			push_error("manifest failure: " + String(failure))

func test_section_inventory() -> void:
	for section in REQUIRED_SECTIONS:
		var ids := _manifest.get_asset_contract_ids(section)
		assert_false(ids.is_empty(), "%s section has asset contracts" % String(section))
		for asset_id in ids:
			_assert_contract_shape(_manifest.get_asset_contract(section, asset_id), "%s/%s" % [String(section), String(asset_id)])
	for biome_id in [&"infected_plains", &"toxic_wastes", &"burning_fields", &"frozen_outskirts", &"drowned_marsh"]:
		assert_true(_manifest.has_asset_contract(&"biome_asset_sets", biome_id), "%s has a biome asset set" % String(biome_id))

func test_fallback_policy() -> void:
	var policy := _manifest.get_fallback_policy()
	assert_false(bool(policy.get("implicit_fallback_allowed", true)), "implicit fallback is disabled")
	assert_false(bool(policy.get("bootstrap_requires_external_assets", true)), "bootstrap does not require external assets")
	var technical := policy.get("technical_fallbacks", {}) as Dictionary
	for key in [&"terrain", &"terrain_patch", &"object", &"void", &"passage", &"crate"]:
		assert_false(String(technical.get(key, "")).is_empty(), "fallback policy declares %s fallback" % String(key))

func test_planned_art_status() -> void:
	var contract := _manifest.get_object_asset_contract(&"small_rock")
	_assert_contract_shape(contract, "object_scenes/small_rock")
	var asset_path := String(contract.get("asset_path", ""))
	var status := String(contract.get("status", ""))
	assert_true(["needs_asset", "base_complete", "needs_polish", "final"].has(status), "planned art status is explicit")
	assert_false(asset_path.is_empty(), "planned art declares target asset_path")
	assert_false(String(contract.get("fallback_path", "")).is_empty(), "planned art keeps explicit fallback_path")
	assert_true(status == "needs_asset" or ResourceLoader.exists(asset_path) or FileAccess.file_exists(asset_path),
		"generated art exists once status advances beyond needs_asset")

func test_no_external_assets() -> void:
	var external := PackedStringArray()
	for object_id in _manifest.get_object_ids():
		if _manifest.requires_external_asset(object_id):
			external.append(String(object_id))
	assert_true(external.is_empty(), "no manifest object requires a mandatory external asset (%s)" % ", ".join(external))

# --- copertura degli id generati (megamappa 3x3 condivisa) ------------------

func test_generated_contract_coverage() -> void:
	assert_eq(_cells.size(), 9, "contract smoke generates a 3x3 map")
	var generated_object_ids: Array[StringName] = []
	var generated_terrain_tags: Array[StringName] = []
	var generated_passage_types: Array[StringName] = []
	var generated_border_ids: Array[StringName] = []
	var has_fall_zone := false
	for cell in _cells:
		var layout := cell.generated_layout
		assert_not_null(layout, "%s has generated layout" % String(cell.id))
		if layout == null:
			continue
		for obstacle_id in layout.obstacle_ids:
			_append_unique(generated_object_ids, obstacle_id)
			if BORDER_IDS.has(obstacle_id):
				_append_unique(generated_border_ids, obstacle_id)
		for terrain_tag in layout.terrain_patch_tags:
			_append_unique(generated_terrain_tags, terrain_tag)
		for passage in cell.passages:
			_append_unique(generated_passage_types, passage.passage_type)
		if not layout.fall_zone_rects.is_empty():
			has_fall_zone = true

	for object_id in generated_object_ids:
		assert_true(_manifest.has_asset_contract(&"object_scenes", object_id), "%s generated object has object_scenes contract" % String(object_id))
	for terrain_tag in generated_terrain_tags:
		assert_true(_manifest.has_asset_contract(&"terrain_tiles", terrain_tag), "%s generated terrain tag has terrain_tiles contract" % String(terrain_tag))
	for passage_type in generated_passage_types:
		assert_true(_manifest.has_asset_contract(&"passage_tiles", passage_type), "%s generated passage type has passage_tiles contract" % String(passage_type))
	for border_id in generated_border_ids:
		assert_true(_manifest.has_asset_contract(&"edge_tiles", border_id), "%s generated border has edge_tiles contract" % String(border_id))
	assert_true(has_fall_zone, "generated map contains at least one fall zone")
	assert_true(_manifest.has_asset_contract(&"void_tiles", &"fall_zone"), "fall_zone has void_tiles contract")

func test_generated_layout_visual_coverage() -> void:
	var generated_categories := ObstacleLayoutGenerator.get_generated_obstacle_categories()
	var generated_ids: Array[StringName] = []
	var missing_from_manifest := PackedStringArray()
	var missing_from_categories := PackedStringArray()
	for cell in _cells:
		var layout := cell.generated_layout
		if layout == null:
			continue
		for obstacle_id in layout.obstacle_ids:
			_append_unique(generated_ids, obstacle_id)
			if not _manifest.has_object(obstacle_id):
				_append_unique_string(missing_from_manifest, "%s:%s" % [String(cell.id), String(obstacle_id)])
			if not generated_categories.has(obstacle_id):
				_append_unique_string(missing_from_categories, "%s:%s" % [String(cell.id), String(obstacle_id)])

	var category_mismatches := PackedStringArray()
	for obstacle_id in generated_ids:
		if not _manifest.has_object(obstacle_id) or not generated_categories.has(obstacle_id):
			continue
		var expected_category := StringName(generated_categories[obstacle_id])
		if _manifest.get_category(obstacle_id) != expected_category:
			category_mismatches.append("%s:%s!=%s" % [String(obstacle_id), String(_manifest.get_category(obstacle_id)), String(expected_category)])

	var category_ids_missing := PackedStringArray()
	var generic_visuals := PackedStringArray()
	var missing_dedicated := PackedStringArray()
	for category_id in generated_categories.keys():
		var obstacle_id := StringName(category_id)
		if not _manifest.has_object(obstacle_id):
			category_ids_missing.append(String(obstacle_id))
			continue
		if _manifest.get_object_draw_mode(obstacle_id) == &"generic_barrier":
			generic_visuals.append(String(obstacle_id))
		if not _manifest.object_has_dedicated_draw(obstacle_id):
			missing_dedicated.append(String(obstacle_id))

	assert_false(generated_ids.is_empty(), "generated layouts emit obstacle ids")
	assert_true(missing_from_manifest.is_empty(), "every generated layout obstacle id is in the manifest (%s)" % ", ".join(missing_from_manifest))
	assert_true(missing_from_categories.is_empty(), "every generated layout obstacle id has a generator category (%s)" % ", ".join(missing_from_categories))
	assert_true(category_ids_missing.is_empty(), "every generator category id is described in the manifest (%s)" % ", ".join(category_ids_missing))
	assert_true(category_mismatches.is_empty(), "generator categories match manifest categories (%s)" % ", ".join(category_mismatches))
	assert_true(generic_visuals.is_empty(), "every generated obstacle id has an explicit non-generic draw mode (%s)" % ", ".join(generic_visuals))
	assert_true(missing_dedicated.is_empty(), "every generated obstacle id has dedicated procedural draw enabled (%s)" % ", ".join(missing_dedicated))

func test_biome_obstacle_coverage() -> void:
	var missing := PackedStringArray()
	for biome_id in BIOME_IDS:
		var biome := load("res://game/modes/zombie/biomes/%s.tres" % biome_id) as BiomeDefinition
		if biome == null:
			assert_true(false, "biome %s loads" % biome_id)
			continue
		for obstacle_id in biome.obstacle_ids:
			if not _manifest.has_object(obstacle_id):
				missing.append("%s:%s" % [biome_id, String(obstacle_id)])
	assert_true(missing.is_empty(), "every biome obstacle id is described in the manifest (%s)" % ", ".join(missing))

func test_biome_obstacle_categories() -> void:
	for biome_id in BIOME_IDS:
		var biome := load("res://game/modes/zombie/biomes/%s.tres" % biome_id) as BiomeDefinition
		assert_not_null(biome.environment_layout, "layout %s" % biome_id)
		assert_gt(biome.environment_layout.obstacle_positions.size(), 0, "obstacles %s" % biome_id)
		assert_gte(biome.environment_layout.central_corridor_width, 80.0, "corridor %s" % biome_id)
		assert_true(_has_two_obstacle_categories(biome), "obstacle categories %s" % biome_id)
		assert_true(_has_dedicated_obstacle_draws(biome), "dedicated obstacle draws %s" % biome_id)

# --- coerenza runtime degli ostacoli (BiomeObstacle) ------------------------

func test_obstacle_coherence() -> void:
	var rectangle := _build_obstacle(&"ruined_house", Vector2(126.0, 78.0), &"rectangle")
	assert_not_null(rectangle, "rectangle obstacle builds")
	if rectangle != null:
		var shape := rectangle.get_node_or_null("CollisionShape2D") as CollisionShape2D
		assert_true(shape != null and shape.shape is RectangleShape2D, "building has a rectangle collision footprint")
		assert_eq(rectangle.z_index, 0, "obstacle z_index is 0 so it participates in Y-sort")
		assert_true(is_equal_approx(rectangle.sort_offset, _manifest.get_sort_offset(&"ruined_house")), "obstacle sort offset comes from the manifest")
		assert_true(rectangle.contains_global_position(rectangle.global_position), "rectangle footprint contains its center")
		_free_test_node(rectangle)

	var circle := _build_obstacle(&"small_rock", Vector2(48.0, 48.0), &"circle")
	assert_not_null(circle, "circle obstacle builds")
	if circle != null:
		var shape := circle.get_node_or_null("CollisionShape2D") as CollisionShape2D
		assert_true(shape != null and shape.shape is CircleShape2D, "rock has a circle collision footprint")
		assert_gt(circle.get_clearance_radius(), 0.0, "rock exposes a positive clearance radius")
		_free_test_node(circle)

	var explicit_barrier := _build_obstacle(&"wood_barrier", Vector2(108.0, 22.0), &"rectangle")
	assert_true(explicit_barrier != null and explicit_barrier.get_node_or_null("CollisionShape2D") != null, "explicit barrier obstacle still has collision")
	if explicit_barrier != null:
		assert_eq(explicit_barrier.get_draw_mode(), &"wood_barrier", "wood_barrier uses its manifest draw mode")
		assert_false(explicit_barrier.uses_generic_fallback(), "wood_barrier does not use implicit generic fallback")
		_free_test_node(explicit_barrier)
	await wait_physics_frames(1)

func test_generated_obstacle_visual_coherence() -> void:
	var generated_categories := ObstacleLayoutGenerator.get_generated_obstacle_categories()
	for category_id in generated_categories.keys():
		var obstacle_id := StringName(category_id)
		if not _manifest.has_object(obstacle_id):
			continue
		var entry := _manifest.get_object(obstacle_id)
		var collision_shape := StringName(str(entry.get("collision_shape", "rectangle")))
		var shape_id := &"circle" if collision_shape == &"circle" else &"rectangle"
		var footprint := entry.get("footprint_tiles", Vector2i(8, 8)) as Vector2i
		var size := Vector2(maxf(float(footprint.x) * 8.0, 28.0), maxf(float(footprint.y) * 8.0, 28.0))
		var obstacle := _build_obstacle(obstacle_id, size, shape_id)
		assert_not_null(obstacle, "%s generated obstacle builds" % String(obstacle_id))
		if obstacle == null:
			continue
		assert_eq(obstacle.get_draw_mode(), _manifest.get_object_draw_mode(obstacle_id), "%s draw mode comes from manifest" % String(obstacle_id))
		assert_true(obstacle.has_dedicated_draw(), "%s uses dedicated procedural draw" % String(obstacle_id))
		assert_false(obstacle.uses_generic_fallback(), "%s avoids implicit generic fallback" % String(obstacle_id))
		assert_true(obstacle.has_ground_shadow(), "%s keeps a coherent ground shadow/base contract" % String(obstacle_id))
		_free_test_node(obstacle)
	await wait_physics_frames(1)

func test_scene_y_sort() -> void:
	var packed := load("res://game/main/main.tscn") as PackedScene
	assert_not_null(packed, "main scene loads")
	if packed == null:
		return
	var state := packed.get_state()
	var required := {"World": false, "Players": false, "Enemies": false, "Bosses": false, "Pickups": false, "EnvironmentProps": false}
	for node_index in range(state.get_node_count()):
		var node_name := String(state.get_node_name(node_index))
		if not required.has(node_name):
			continue
		for property_index in range(state.get_node_property_count(node_index)):
			if String(state.get_node_property_name(node_index, property_index)) == "y_sort_enabled":
				if bool(state.get_node_property_value(node_index, property_index)):
					required[node_name] = true
	for node_name in required.keys():
		assert_true(bool(required[node_name]), "%s has Y-sort enabled in main scene" % node_name)

# --- helper (porting dei test legacy) ---------------------------------------

func _assert_contract_shape(contract: Dictionary, label: String) -> void:
	assert_false(contract.is_empty(), "%s contract is present" % label)
	if contract.is_empty():
		return
	for key in ["asset_path", "status", "biome_ids", "footprint_tiles", "anchor", "sort_offset",
			"collision_shape", "collision_size_ratio", "collision_offset_ratio", "blocks_movement", "blocks_projectiles", "source", "license", "attribution_key"]:
		assert_true(contract.has(key), "%s declares %s" % [label, key])
	assert_false(String(contract.get("asset_path", "")).is_empty(), "%s asset_path is explicit" % label)
	assert_false(String(contract.get("source", "")).is_empty(), "%s source is explicit" % label)
	assert_false(String(contract.get("license", "")).is_empty(), "%s license is explicit" % label)
	assert_false(String(contract.get("attribution_key", "")).is_empty(), "%s attribution is explicit" % label)
	assert_false((contract.get("biome_ids", []) as Array).is_empty(), "%s biome_ids are explicit" % label)
	var footprint := contract.get("footprint_tiles", Vector2i.ZERO) as Vector2i
	assert_true(footprint.x > 0 and footprint.y > 0, "%s footprint is positive" % label)

func _build_obstacle(obstacle_id: StringName, size: Vector2, shape_id: StringName) -> BiomeObstacle:
	var obstacle := BiomeObstacle.new()
	add_child(obstacle)
	obstacle.configure(obstacle_id, size, shape_id, 0.0,
		Color(0.4, 0.4, 0.4, 1.0), Color(0.8, 0.8, 0.4, 1.0), _manifest.get_sort_offset(obstacle_id))
	return obstacle

func _free_test_node(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	var parent := node.get_parent()
	if parent != null:
		parent.remove_child(node)
	node.free()

func _has_two_obstacle_categories(biome: BiomeDefinition) -> bool:
	var categories := {}
	for obstacle_id in biome.environment_layout.obstacle_ids:
		if _manifest.has_object(obstacle_id):
			categories[_manifest.get_category(obstacle_id)] = true
	return categories.size() >= 2

func _has_dedicated_obstacle_draws(biome: BiomeDefinition) -> bool:
	for obstacle_id in biome.environment_layout.obstacle_ids:
		if not _manifest.has_object(obstacle_id):
			return false
		if not _manifest.object_has_dedicated_draw(obstacle_id):
			return false
		if _manifest.get_object_draw_mode(obstacle_id) == &"generic_barrier":
			return false
	return true

func _append_unique(values: Array[StringName], value: StringName) -> void:
	if not values.has(value):
		values.append(value)

func _append_unique_string(values: PackedStringArray, value: String) -> void:
	if not values.has(value):
		values.append(value)
