extends SceneTree

const REQUIRED_FOREST_TILE_IDS: Array[StringName] = [
	&"forest_grass",
	&"forest_grass_variant_01",
	&"forest_grass_variant_02",
	&"forest_tall_grass",
	&"forest_path",
	&"forest_road",
	&"forest_void",
	&"forest_cliff_edge",
	&"forest_mountain_wall",
	&"grass_to_path",
	&"grass_to_road",
	&"grass_to_tall_grass",
	&"path_to_road",
	&"ground_to_void_cliff",
	&"ground_to_mountain_wall"
]

var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var manifest := IsometricEnvironmentManifest.reload_shared()
	_expect(manifest.load_error.is_empty(), "forest texture manifest loads")
	var report := manifest.validate()
	_expect(bool(report.get("is_valid", false)), "forest texture manifest validates")
	if not bool(report.get("is_valid", false)):
		for failure in report.get("failures", PackedStringArray()):
			push_error("manifest failure: " + String(failure))

	var resolver := IsometricTileResolver.new(manifest)
	_run_manifest_contract_smoke(manifest, resolver)
	await _run_generated_forest_smoke(manifest, resolver)
	_run_synthetic_wall_smoke(resolver)
	_finish()

func _run_manifest_contract_smoke(
	manifest: IsometricEnvironmentManifest,
	resolver: IsometricTileResolver
) -> void:
	for tile_id in REQUIRED_FOREST_TILE_IDS:
		var section := resolver.resolve_tile_section(tile_id)
		var contract := manifest.get_asset_contract(section, tile_id)
		var asset_path := String(contract.get("asset_path", ""))
		_expect(not contract.is_empty(), "%s has a forest asset contract" % String(tile_id))
		_expect(_asset_exists(asset_path), "%s asset file exists" % String(tile_id))
	var biome_set := manifest.get_biome_asset_set_contract(&"infected_plains")
	_expect(
		_string_name_array(biome_set.get("terrain_tiles", [])).has(&"forest_path"),
		"base biome asset set includes forest terrain tiles"
	)
	_expect(
		_string_name_array(biome_set.get("void_tiles", [])).has(&"forest_cliff_edge"),
		"base biome asset set includes forest cliff edge"
	)
	_expect(
		_string_name_array(biome_set.get("edge_tiles", [])).has(&"forest_mountain_wall"),
		"base biome asset set includes forest mountain wall"
	)

func _run_generated_forest_smoke(
	manifest: IsometricEnvironmentManifest,
	resolver: IsometricTileResolver
) -> void:
	var biome_manager := BiomeManager.new()
	root.add_child(biome_manager)
	await process_frame
	biome_manager.start_run({
		"world_seed": 772031,
		"biome_map_width": 3,
		"biome_map_height": 3,
		"preserve_biome_sequence": false,
		"extra_edge_chance": 0.25
	})
	var cell := _first_cell_for_biome(
		biome_manager.get_generated_biome_map(),
		&"infected_plains"
	)
	_expect(cell != null, "generated map contains the base forest biome")
	if cell == null:
		biome_manager.queue_free()
		await process_frame
		return
	var layout := cell.generated_layout
	_expect(layout != null, "base forest biome has generated layout")
	if layout == null:
		biome_manager.queue_free()
		await process_frame
		return

	var saw_tiles: Dictionary = {}
	var tall_grass_cell := Vector2i(-1, -1)
	var checked := 0
	for y in range(layout.zone_size.y):
		for x in range(layout.zone_size.x):
			var probe := Vector2i(x, y)
			var tile_id := resolver.resolve_tile_id(
				layout,
				probe,
				cell.biome_id,
				&"balanced",
				cell
			)
			saw_tiles[tile_id] = true
			if layout.get_floor_tag_at_cell(probe) == &"forest_tall_grass":
				tall_grass_cell = probe
			checked += 1
	_expect(checked == layout.zone_size.x * layout.zone_size.y, "forest resolver covers the full chunk")
	for tile_id in [
		&"forest_grass",
		&"forest_path",
		&"forest_road",
		&"forest_void",
		&"forest_cliff_edge",
		&"grass_to_path",
		&"grass_to_road",
		&"path_to_road",
		&"ground_to_void_cliff"
	]:
		_expect(saw_tiles.has(tile_id), "generated forest emits %s" % String(tile_id))
	_expect(tall_grass_cell != Vector2i(-1, -1), "generated forest has tall grass floor cells")
	if tall_grass_cell != Vector2i(-1, -1):
		_expect(
			layout.get_terrain_class_at_cell(tall_grass_cell, cell) == BiomeEnvironmentLayout.TERRAIN_WALKABLE,
			"forest tall grass remains walkable terrain"
		)
		_expect(
			[
				&"forest_tall_grass",
				&"grass_to_tall_grass"
			].has(resolver.resolve_tile_id(layout, tall_grass_cell, cell.biome_id, &"balanced", cell)),
			"forest tall grass resolves to tall grass or its edge transition"
		)

	var palette := load("res://game/modes/zombie/biomes/infected_plains_palette.tres") as BiomePalette
	var layer := BiomeTileLayer.new()
	layer.configure(layout, palette, cell.biome_id, &"balanced", 20, resolver, manifest)
	_expect(layer.get_missing_asset_count() == 0, "forest tile layer has no missing assets")
	_expect(layer.get_texture_detail_line_count() > 0, "forest tile layer bakes texture detail lines")
	layer.free()

	biome_manager.queue_free()
	await process_frame

func _run_synthetic_wall_smoke(resolver: IsometricTileResolver) -> void:
	var layout := BiomeEnvironmentLayout.new()
	layout.zone_size = Vector2i(16, 16)
	layout.generation_seed = 21
	layout.add_floor_rect(Rect2i(Vector2i(0, 0), layout.zone_size), &"open_block")
	var wall_rect := Rect2i(Vector2i(0, 0), Vector2i(16, 4))
	layout.add_wall_segment(wall_rect, &"north")
	layout.obstacle_rects.append(wall_rect)
	layout.obstacle_ids.append(&"boundary_fence")
	layout.rebuild_terrain_classification()
	_expect(
		resolver.resolve_tile_id(layout, Vector2i(4, 1), &"infected_plains")
		== &"forest_mountain_wall",
		"forest wall cells resolve to the mountain wall tile"
	)
	_expect(
		resolver.resolve_tile_id(layout, Vector2i(4, 4), &"infected_plains")
		== &"ground_to_mountain_wall",
		"ground beside wall resolves to a mountain transition"
	)

func _first_cell_for_biome(cells: Array[BiomeCell], biome_id: StringName) -> BiomeCell:
	for cell in cells:
		if cell.biome_id == biome_id:
			return cell
	return null

func _string_name_array(value: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if value is Array:
		for item in value as Array:
			result.append(StringName(str(item)))
	return result

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

func _finish() -> void:
	if failures.is_empty():
		print("FOREST_ISOMETRIC_TEXTURE_TRANSITION_SMOKE_TEST: PASS")
		quit(0)
		return
	print("FOREST_ISOMETRIC_TEXTURE_TRANSITION_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
