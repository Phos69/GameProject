extends SceneTree

var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var manifest := IsometricEnvironmentManifest.reload_shared()
	_expect(manifest.load_error.is_empty(), "terrain manifest loads")
	_expect(manifest.version >= 4, "terrain manifest version is current")
	var manifest_report := manifest.validate()
	_expect(bool(manifest_report.get("is_valid", false)), "terrain manifest validates")
	if not bool(manifest_report.get("is_valid", false)):
		for failure in manifest_report.get("failures", PackedStringArray()):
			push_error("manifest failure: " + String(failure))
	_run_manifest_terrain_inventory(manifest)
	_run_patch_draw_mode_smoke(manifest)
	_run_region_ground_sample_step_smoke(manifest)

	var biome_manager := BiomeManager.new()
	root.add_child(biome_manager)
	await process_frame
	biome_manager.start_run({
		"world_seed": 515151,
		"biome_map_width": 5,
		"biome_map_height": 5,
		"preserve_biome_sequence": false
	})
	var cells := biome_manager.get_generated_biome_map()
	_expect(cells.size() == 25, "megamap generates 25 regions")
	_run_generated_terrain_coverage(manifest, cells)
	for cell in cells:
		var layout := cell.generated_layout
		_expect(layout != null, "%s has layout" % String(cell.id))
		if layout == null:
			continue
		var report := layout.get_classification_report()
		_expect(bool(report.get("is_complete", false)), "%s classifies every tile" % String(cell.id))
		_expect(int(report.get("total", 0)) == 40000, "%s classification covers 200x200" % String(cell.id))
		var counts := report.get("counts", {}) as Dictionary
		var sum := 0
		for value in counts.values():
			sum += int(value)
		_expect(sum == 40000, "%s classification counts sum to 40000" % String(cell.id))
		_expect(int(counts.get(BiomeEnvironmentLayout.TERRAIN_WALKABLE, 0)) > 0, "%s has walkable terrain" % String(cell.id))
		for passage in cell.passages:
			var probe := _passage_probe_cell(passage, layout.zone_size)
			_expect(
				layout.get_terrain_class_at_cell(probe, cell) == BiomeEnvironmentLayout.TERRAIN_WALKABLE,
				"%s passage %s is classified walkable" % [String(cell.id), String(passage.side)]
			)

	biome_manager.queue_free()
	_finish()

func _run_manifest_terrain_inventory(manifest: IsometricEnvironmentManifest) -> void:
	var expected_categories := _get_expected_generated_terrain_categories()
	var missing_from_manifest := PackedStringArray()
	var missing_dedicated_draw := PackedStringArray()
	var category_mismatches := PackedStringArray()
	for tag_key in expected_categories.keys():
		var terrain_tag := StringName(tag_key)
		if not manifest.has_terrain_tag(terrain_tag):
			missing_from_manifest.append(String(terrain_tag))
			continue
		if not manifest.terrain_tag_has_dedicated_draw(terrain_tag):
			missing_dedicated_draw.append(String(terrain_tag))
		var style := manifest.get_terrain_style(terrain_tag)
		var expected_category := StringName(expected_categories[terrain_tag])
		var actual_category := StringName(style.get("category", &""))
		if actual_category != expected_category:
			category_mismatches.append(
				"%s:%s!=%s"
				% [String(terrain_tag), String(actual_category), String(expected_category)]
			)
	_expect(
		missing_from_manifest.is_empty(),
		"every generated terrain tag is described in the manifest (%s)"
		% ", ".join(missing_from_manifest)
	)
	_expect(
		missing_dedicated_draw.is_empty(),
		"every generated terrain tag has dedicated draw metadata (%s)"
		% ", ".join(missing_dedicated_draw)
	)
	_expect(
		category_mismatches.is_empty(),
		"generated terrain categories match the manifest (%s)"
		% ", ".join(category_mismatches)
	)
	_expect(manifest.get_terrain_sample_step(&"performance") == 12, "performance ground preset is 12")
	_expect(manifest.get_terrain_sample_step(&"balanced") == 8, "balanced ground preset is 8")
	_expect(manifest.get_terrain_sample_step(&"quality") == 4, "quality ground preset is 4")

func _run_patch_draw_mode_smoke(manifest: IsometricEnvironmentManifest) -> void:
	var patch := BiomeTerrainPatch.new()
	patch.configure(
		&"bridge",
		42.0,
		Color(0.18, 0.20, 0.14, 1.0),
		Color(0.58, 0.48, 0.28, 1.0),
		7,
		manifest.get_terrain_style(&"bridge")
	)
	_expect(patch.get_draw_mode() == &"bridge_path", "bridge passage uses bridge draw mode")
	patch.configure(
		&"burned_road",
		42.0,
		Color(0.18, 0.20, 0.14, 1.0),
		Color(0.58, 0.48, 0.28, 1.0),
		8,
		manifest.get_terrain_style(&"burned_road")
	)
	_expect(patch.get_draw_mode() == &"burned_road", "burned road uses burned road draw mode")
	patch.free()

func _run_region_ground_sample_step_smoke(manifest: IsometricEnvironmentManifest) -> void:
	var ground := BiomeRegionGround.new()
	var layout := BiomeEnvironmentLayout.new()
	layout.generation_seed = 1
	var palette := BiomePalette.new()
	ground.configure(layout, palette, manifest.get_terrain_sample_step(&"quality"))
	_expect(ground.get_sample_step() == 4, "region ground accepts quality sample step")
	ground.configure(layout, palette, manifest.get_terrain_sample_step(&"balanced"))
	_expect(ground.get_sample_step() == 8, "region ground keeps balanced sample step")
	ground.free()

func _run_generated_terrain_coverage(
	manifest: IsometricEnvironmentManifest,
	cells: Array[BiomeCell]
) -> void:
	var generated_tags: Array[StringName] = []
	var missing_from_manifest := PackedStringArray()
	var fallback_tags := PackedStringArray()
	for cell in cells:
		var layout := cell.generated_layout
		if layout == null:
			continue
		for terrain_tag in layout.terrain_patch_tags:
			_append_unique_tag(generated_tags, terrain_tag)
		for passage in cell.passages:
			_append_unique_tag(generated_tags, passage.passage_type)
	for terrain_tag in generated_tags:
		if not manifest.has_terrain_tag(terrain_tag):
			missing_from_manifest.append(String(terrain_tag))
			continue
		if not manifest.terrain_tag_has_dedicated_draw(terrain_tag):
			fallback_tags.append(String(terrain_tag))
	_expect(not generated_tags.is_empty(), "generated layouts emit terrain tags")
	_expect(
		missing_from_manifest.is_empty(),
		"all generated layout terrain tags are in the manifest (%s)"
		% ", ".join(missing_from_manifest)
	)
	_expect(
		fallback_tags.is_empty(),
		"generated road and passage tags avoid dirt fallback (%s)"
		% ", ".join(fallback_tags)
	)

func _get_expected_generated_terrain_categories() -> Dictionary:
	var expected := {}
	_merge_expected_tags(
		expected,
		ObstacleLayoutGenerator.get_generated_terrain_tag_categories()
	)
	_merge_expected_tags(
		expected,
		BiomePassageGenerator.get_generated_passage_terrain_tag_categories()
	)
	return expected

func _merge_expected_tags(target: Dictionary, source: Dictionary) -> void:
	for key in source.keys():
		target[StringName(key)] = StringName(source[key])

func _append_unique_tag(tags: Array[StringName], terrain_tag: StringName) -> void:
	if not tags.has(terrain_tag):
		tags.append(terrain_tag)

func _passage_probe_cell(passage: BiomePassage, zone_size: Vector2i) -> Vector2i:
	match passage.side:
		&"north":
			return Vector2i(passage.position, 3)
		&"south":
			return Vector2i(passage.position, zone_size.y - 4)
		&"west":
			return Vector2i(3, passage.position)
		_:
			return Vector2i(zone_size.x - 4, passage.position)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("ISOMETRIC_BIOME_TERRAIN_COVERAGE_SMOKE_TEST: PASS")
		quit(0)
		return
	print("ISOMETRIC_BIOME_TERRAIN_COVERAGE_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
