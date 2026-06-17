extends SceneTree

# Milestone 3 - Asset isometrici ambiente e ostacoli coerenti.
# Copre: manifest live e validato, copertura di tutti gli obstacle_id dei biomi,
# nessun asset esterno obbligatorio per il bootstrap, draw mode dedicati per gli
# obstacle_id generati, collisione/footprint/sort coerenti su BiomeObstacle e
# Y-sort abilitato nella scena principale.

const BIOME_IDS: Array[String] = [
	"infected_plains",
	"toxic_wastes",
	"burning_fields",
	"frozen_outskirts",
	"drowned_marsh"
]
const GENERATED_WORLD_CONTEXT := {
	"world_seed": 515151,
	"biome_map_width": 5,
	"biome_map_height": 5,
	"preserve_biome_sequence": false
}

var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var manifest := IsometricEnvironmentManifest.reload_shared()
	_expect(manifest.load_error.is_empty(), "manifest loads without error")
	_expect(manifest.version >= 5, "manifest version is current")

	var report := manifest.validate()
	_expect(bool(report.get("is_valid", false)), "manifest passes validation")
	if not bool(report.get("is_valid", false)):
		for failure in report.get("failures", PackedStringArray()):
			push_error("manifest failure: " + String(failure))

	_run_biome_coverage(manifest)
	await _run_generated_layout_coverage(manifest)
	_run_no_external_assets(manifest)
	_run_obstacle_coherence(manifest)
	_run_scene_y_sort()

	_finish()

func _run_biome_coverage(manifest: IsometricEnvironmentManifest) -> void:
	var missing := PackedStringArray()
	for biome_id in BIOME_IDS:
		var biome := load("res://game/modes/zombie/biomes/%s.tres" % biome_id) as BiomeDefinition
		if biome == null:
			_expect(false, "biome %s loads" % biome_id)
			continue
		for obstacle_id in biome.obstacle_ids:
			if not manifest.has_object(obstacle_id):
				missing.append("%s:%s" % [biome_id, String(obstacle_id)])
	_expect(
		missing.is_empty(),
		"every biome obstacle id is described in the manifest (%s)" % ", ".join(missing)
	)

func _run_generated_layout_coverage(manifest: IsometricEnvironmentManifest) -> void:
	var biome_manager := BiomeManager.new()
	root.add_child(biome_manager)
	await process_frame
	biome_manager.start_run(GENERATED_WORLD_CONTEXT)

	var generated_categories := ObstacleLayoutGenerator.get_generated_obstacle_categories()
	var cells := biome_manager.get_generated_biome_map()
	var generated_ids: Array[StringName] = []
	var missing_from_manifest := PackedStringArray()
	var missing_from_categories := PackedStringArray()
	var category_mismatches := PackedStringArray()
	var category_ids_missing_from_manifest := PackedStringArray()
	var generic_visuals := PackedStringArray()
	var missing_dedicated_visuals := PackedStringArray()

	_expect(cells.size() == 25, "manifest smoke generates a 5x5 biome map")
	for cell in cells:
		var layout := cell.generated_layout
		_expect(layout != null, "%s generated layout is available" % String(cell.id))
		if layout == null:
			continue
		for obstacle_id in layout.obstacle_ids:
			_append_unique_obstacle_id(generated_ids, obstacle_id)
			if not manifest.has_object(obstacle_id):
				_append_unique_string(
					missing_from_manifest,
					"%s:%s" % [String(cell.id), String(obstacle_id)]
				)
			if not generated_categories.has(obstacle_id):
				_append_unique_string(
					missing_from_categories,
					"%s:%s" % [String(cell.id), String(obstacle_id)]
				)

	for obstacle_id in generated_ids:
		if not manifest.has_object(obstacle_id) or not generated_categories.has(obstacle_id):
			continue
		var expected_category := StringName(generated_categories[obstacle_id])
		var actual_category := manifest.get_category(obstacle_id)
		if actual_category != expected_category:
			category_mismatches.append(
				"%s:%s!=%s"
				% [String(obstacle_id), String(actual_category), String(expected_category)]
			)

	for category_id in generated_categories.keys():
		var obstacle_id := StringName(category_id)
		if not manifest.has_object(obstacle_id):
			category_ids_missing_from_manifest.append(String(obstacle_id))
			continue
		if manifest.get_object_draw_mode(obstacle_id) == &"generic_barrier":
			generic_visuals.append(String(obstacle_id))
		if not manifest.object_has_dedicated_draw(obstacle_id):
			missing_dedicated_visuals.append(String(obstacle_id))

	_expect(not generated_ids.is_empty(), "generated layouts emit obstacle ids")
	_expect(
		missing_from_manifest.is_empty(),
		"every generated layout obstacle id is in the manifest (%s)"
		% ", ".join(missing_from_manifest)
	)
	_expect(
		missing_from_categories.is_empty(),
		"every generated layout obstacle id has a generator category (%s)"
		% ", ".join(missing_from_categories)
	)
	_expect(
		category_ids_missing_from_manifest.is_empty(),
		"every generator category id is described in the manifest (%s)"
		% ", ".join(category_ids_missing_from_manifest)
	)
	_expect(
		category_mismatches.is_empty(),
		"generator categories match manifest categories (%s)"
		% ", ".join(category_mismatches)
	)
	_expect(
		generic_visuals.is_empty(),
		"every generated obstacle id has an explicit non-generic draw mode (%s)"
		% ", ".join(generic_visuals)
	)
	_expect(
		missing_dedicated_visuals.is_empty(),
		"every generated obstacle id has dedicated procedural draw enabled (%s)"
		% ", ".join(missing_dedicated_visuals)
	)

	biome_manager.queue_free()
	await process_frame

func _run_no_external_assets(manifest: IsometricEnvironmentManifest) -> void:
	var external := PackedStringArray()
	for object_id in manifest.get_object_ids():
		if manifest.requires_external_asset(object_id):
			external.append(String(object_id))
	_expect(
		external.is_empty(),
		"no manifest object requires a mandatory external asset (%s)" % ", ".join(external)
	)

func _run_obstacle_coherence(manifest: IsometricEnvironmentManifest) -> void:
	var rectangle := _build_obstacle(manifest, &"ruined_house", Vector2(126.0, 78.0), &"rectangle")
	_expect(rectangle != null, "rectangle obstacle builds")
	if rectangle != null:
		var shape := rectangle.get_node_or_null("CollisionShape2D") as CollisionShape2D
		_expect(shape != null and shape.shape is RectangleShape2D, "building has a rectangle collision footprint")
		_expect(rectangle.z_index == 0, "obstacle z_index is 0 so it participates in Y-sort")
		_expect(is_equal_approx(rectangle.sort_offset, manifest.get_sort_offset(&"ruined_house")), "obstacle sort offset comes from the manifest")
		_expect(rectangle.contains_global_position(rectangle.global_position), "rectangle footprint contains its center")
		rectangle.queue_free()

	var circle := _build_obstacle(manifest, &"small_rock", Vector2(48.0, 48.0), &"circle")
	_expect(circle != null, "circle obstacle builds")
	if circle != null:
		var shape := circle.get_node_or_null("CollisionShape2D") as CollisionShape2D
		_expect(shape != null and shape.shape is CircleShape2D, "rock has a circle collision footprint")
		_expect(circle.get_clearance_radius() > 0.0, "rock exposes a positive clearance radius")
		circle.queue_free()

	var explicit_barrier := _build_obstacle(manifest, &"wood_barrier", Vector2(108.0, 22.0), &"rectangle")
	_expect(
		explicit_barrier != null and explicit_barrier.get_node_or_null("CollisionShape2D") != null,
		"explicit barrier obstacle still has collision"
	)
	if explicit_barrier != null:
		_expect(explicit_barrier.get_draw_mode() == &"wood_barrier", "wood_barrier uses its manifest draw mode")
		_expect(not explicit_barrier.uses_generic_fallback(), "wood_barrier does not use implicit generic fallback")
		explicit_barrier.queue_free()

	_run_generated_obstacle_visual_coherence(manifest)

func _run_generated_obstacle_visual_coherence(manifest: IsometricEnvironmentManifest) -> void:
	var generated_categories := ObstacleLayoutGenerator.get_generated_obstacle_categories()
	for category_id in generated_categories.keys():
		var obstacle_id := StringName(category_id)
		if not manifest.has_object(obstacle_id):
			continue
		var entry := manifest.get_object(obstacle_id)
		var collision_shape := StringName(str(entry.get("collision_shape", "rectangle")))
		var shape_id := &"circle" if collision_shape == &"circle" else &"rectangle"
		var footprint := entry.get("footprint_tiles", Vector2i(8, 8)) as Vector2i
		var size := Vector2(
			maxf(float(footprint.x) * 8.0, 28.0),
			maxf(float(footprint.y) * 8.0, 28.0)
		)
		var obstacle := _build_obstacle(manifest, obstacle_id, size, shape_id)
		_expect(obstacle != null, "%s generated obstacle builds" % String(obstacle_id))
		if obstacle == null:
			continue
		_expect(
			obstacle.get_draw_mode() == manifest.get_object_draw_mode(obstacle_id),
			"%s draw mode comes from manifest" % String(obstacle_id)
		)
		_expect(
			obstacle.has_dedicated_draw(),
			"%s uses dedicated procedural draw" % String(obstacle_id)
		)
		_expect(
			not obstacle.uses_generic_fallback(),
			"%s avoids implicit generic fallback" % String(obstacle_id)
		)
		_expect(
			obstacle.has_ground_shadow(),
			"%s keeps a coherent ground shadow/base contract" % String(obstacle_id)
		)
		obstacle.queue_free()

func _run_scene_y_sort() -> void:
	var packed := load("res://game/main/main.tscn") as PackedScene
	_expect(packed != null, "main scene loads")
	if packed == null:
		return
	var state := packed.get_state()
	var required := {
		"World": false,
		"Enemies": false,
		"Pickups": false,
		"EnvironmentProps": false
	}
	for node_index in range(state.get_node_count()):
		var node_name := String(state.get_node_name(node_index))
		if not required.has(node_name):
			continue
		for property_index in range(state.get_node_property_count(node_index)):
			if String(state.get_node_property_name(node_index, property_index)) == "y_sort_enabled":
				if bool(state.get_node_property_value(node_index, property_index)):
					required[node_name] = true
	for node_name in required.keys():
		_expect(bool(required[node_name]), "%s has Y-sort enabled in main scene" % node_name)

func _build_obstacle(
	manifest: IsometricEnvironmentManifest,
	obstacle_id: StringName,
	size: Vector2,
	shape_id: StringName
) -> BiomeObstacle:
	var obstacle := BiomeObstacle.new()
	root.add_child(obstacle)
	obstacle.configure(
		obstacle_id,
		size,
		shape_id,
		0.0,
		Color(0.4, 0.4, 0.4, 1.0),
		Color(0.8, 0.8, 0.4, 1.0),
		manifest.get_sort_offset(obstacle_id)
	)
	return obstacle

func _append_unique_obstacle_id(ids: Array[StringName], obstacle_id: StringName) -> void:
	if not ids.has(obstacle_id):
		ids.append(obstacle_id)

func _append_unique_string(values: PackedStringArray, value: String) -> void:
	if not values.has(value):
		values.append(value)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("ISOMETRIC_ENVIRONMENT_MANIFEST_SMOKE_TEST: PASS")
		quit(0)
		return
	print("ISOMETRIC_ENVIRONMENT_MANIFEST_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
