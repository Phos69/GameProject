extends SceneTree

var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var manifest := IsometricEnvironmentManifest.reload_shared()
	_expect(manifest.load_error.is_empty(), "tile layer manifest loads")
	_expect(manifest.version >= 7, "tile layer uses manifest v7")
	var manifest_report := manifest.validate()
	_expect(bool(manifest_report.get("is_valid", false)), "tile layer manifest validates")
	if not bool(manifest_report.get("is_valid", false)):
		for failure in manifest_report.get("failures", PackedStringArray()):
			push_error("manifest failure: " + String(failure))

	var resolver := IsometricTileResolver.new(manifest)
	_run_required_contract_smoke(manifest, resolver)

	var biome_manager := BiomeManager.new()
	root.add_child(biome_manager)
	await process_frame
	biome_manager.start_run({
		"world_seed": 610303,
		"biome_map_width": 5,
		"biome_map_height": 5,
		"preserve_biome_sequence": false
	})
	var cells := biome_manager.get_generated_biome_map()
	_expect(cells.size() == 25, "tile layer smoke generates a 5x5 biome map")
	var sample_cells := _first_cell_per_biome(cells)
	_expect(sample_cells.size() >= 5, "tile layer smoke samples all five biome palettes")

	_run_resolver_coverage_smoke(manifest, resolver, sample_cells)
	_run_layer_chunk_smoke(manifest, resolver, sample_cells)
	await _run_terrain_generator_integration_smoke(biome_manager)

	biome_manager.queue_free()
	_finish()

func _run_required_contract_smoke(
	manifest: IsometricEnvironmentManifest,
	resolver: IsometricTileResolver
) -> void:
	for tile_id in resolver.get_required_tile_ids():
		var section := resolver.resolve_tile_section(tile_id)
		var contract := manifest.get_asset_contract(section, tile_id)
		var asset_path := String(contract.get("asset_path", ""))
		_expect(not contract.is_empty(), "%s has an asset contract" % String(tile_id))
		_expect(_asset_exists(asset_path), "%s asset file exists" % String(tile_id))

func _run_resolver_coverage_smoke(
	manifest: IsometricEnvironmentManifest,
	resolver: IsometricTileResolver,
	cells: Array[BiomeCell]
) -> void:
	var saw_tile_ids: Dictionary = {}
	var saw_biome_ids: Dictionary = {}
	var saw_route_tile := false
	var saw_passage_endpoint := false
	var saw_void_edge := false
	var saw_void_depth := false
	var saw_hazard_floor := false
	var asset_exists_by_tile_id: Dictionary = {}
	for cell in cells:
		var layout := cell.generated_layout
		_expect(layout != null, "%s has generated layout" % String(cell.id))
		if layout == null:
			continue
		var biome_id := cell.biome_id
		saw_biome_ids[biome_id] = true
		var stable_probe := _find_first_floor_cell(resolver, layout, cell)
		var first_tile := resolver.resolve_tile_id(layout, stable_probe, biome_id, &"balanced", cell)
		var second_tile := resolver.resolve_tile_id(layout, stable_probe, biome_id, &"balanced", cell)
		_expect(first_tile == second_tile, "%s resolves the same cell to a stable tile" % String(cell.id))
		var walkable_count := 0
		var missing_walkable := 0
		var missing_any := 0
		for y in range(layout.zone_size.y):
			for x in range(layout.zone_size.x):
				var probe := Vector2i(x, y)
				var terrain_class := layout.get_terrain_class_at_cell(probe, cell)
				var tile_id := resolver.resolve_tile_id(layout, probe, biome_id, &"balanced", cell)
				if not asset_exists_by_tile_id.has(tile_id):
					var resolved_asset_path := String(resolver.resolve_tile_contract(tile_id).get("asset_path", ""))
					asset_exists_by_tile_id[tile_id] = _asset_exists(resolved_asset_path)
				saw_tile_ids[tile_id] = true
				if resolver.is_route_tile_id(tile_id):
					saw_route_tile = true
				if String(tile_id).ends_with("_entry") or String(tile_id).ends_with("_exit"):
					saw_passage_endpoint = true
				elif tile_id == IsometricTileResolver.TILE_VOID_EDGE_NEAR:
					saw_void_edge = true
				elif tile_id == IsometricTileResolver.TILE_VOID_DEPTH:
					saw_void_depth = true
				elif tile_id == IsometricTileResolver.TILE_HAZARD_FLOOR:
					saw_hazard_floor = true
				if tile_id.is_empty() or not bool(asset_exists_by_tile_id[tile_id]):
					missing_any += 1
				if terrain_class == BiomeEnvironmentLayout.TERRAIN_WALKABLE:
					walkable_count += 1
					if tile_id.is_empty() or not bool(asset_exists_by_tile_id[tile_id]):
						missing_walkable += 1
				if (
					terrain_class == BiomeEnvironmentLayout.TERRAIN_WALKABLE
					and (
						_cell_inside_any_rect(probe, layout.road_rects)
						or _cell_inside_any_rect(probe, layout.passage_rects)
					)
					and not resolver.is_route_tile_id(tile_id)
				):
					failures.append("%s road cell %s resolved to %s" % [String(cell.id), str(probe), String(tile_id)])
		_expect(walkable_count > 0, "%s has walkable cells" % String(cell.id))
		_expect(missing_walkable == 0, "%s has no walkable cell without a visual tile" % String(cell.id))
		_expect(missing_any == 0, "%s resolves every 200x200 cell to an asset-backed tile" % String(cell.id))
		_expect(
			manifest.get_biome_asset_set_contract(biome_id).has("asset_path"),
			"%s has a biome asset set contract" % String(biome_id)
		)
	var void_depth_probe := resolver.resolve_tile_id(
		cells[0].generated_layout,
		Vector2i(-1, -1),
		cells[0].biome_id,
		&"balanced",
		cells[0]
	)
	_expect(void_depth_probe == IsometricTileResolver.TILE_VOID_DEPTH, "out-of-bounds cells resolve to void_depth")
	_expect(saw_biome_ids.size() >= 5, "resolver coverage includes five biome ids")
	_expect(saw_tile_ids.has(IsometricTileResolver.TILE_FLOOR_BASE), "resolver emits floor_base")
	_expect(saw_tile_ids.has(IsometricTileResolver.TILE_FLOOR_VARIANT_01), "resolver emits floor_variant_01")
	_expect(saw_tile_ids.has(IsometricTileResolver.TILE_FLOOR_VARIANT_02), "resolver emits floor_variant_02")
	_expect(saw_route_tile, "resolver emits asset route tiles for road and passage rects")
	_expect(saw_passage_endpoint, "resolver emits passage endpoint tiles for border openings")
	_expect(saw_void_edge, "resolver emits void_edge_near for cliff lips")
	_expect(saw_void_depth or void_depth_probe == IsometricTileResolver.TILE_VOID_DEPTH, "resolver emits void_depth")
	_expect(saw_hazard_floor, "resolver emits hazard_floor for hazard cells")

func _run_layer_chunk_smoke(
	manifest: IsometricEnvironmentManifest,
	resolver: IsometricTileResolver,
	cells: Array[BiomeCell]
) -> void:
	var cell := cells[0]
	var palette := _palette_for_biome(cell.biome_id)
	var layer := BiomeTileLayer.new()
	layer.configure(cell.generated_layout, palette, cell.biome_id, &"balanced", 20, resolver, manifest)
	_expect(layer.get_chunk_size() == 20, "balanced tile layer keeps 20x20 chunks")
	_expect(layer.get_chunk_count() == 100, "balanced tile layer chunks the 200x200 region into 100 chunks")
	_expect(layer.get_visual_tile_count() == 40000, "tile layer caches all 200x200 visual cells")
	_expect(layer.get_missing_asset_count() == 0, "tile layer cache has no missing asset-backed cells")
	_expect(not layer.uses_procedural_fallback(), "tile layer does not use the procedural ground fallback")
	var probe := _find_first_floor_cell(resolver, cell.generated_layout, cell)
	_expect(
		layer.get_resolved_tile_id(probe) == resolver.resolve_tile_id(cell.generated_layout, probe, cell.biome_id, &"balanced", cell),
		"tile layer cache matches the resolver for a stable floor cell"
	)
	_expect(layer.has_visual_tile_for_cell(probe), "tile layer returns a visual asset for the stable floor cell")
	layer.free()

	var performance_layer := BiomeTileLayer.new()
	performance_layer.configure(cell.generated_layout, palette, cell.biome_id, &"performance", 0, resolver, manifest)
	_expect(performance_layer.get_chunk_size() == 25, "performance preset uses larger chunks")
	_expect(
		resolver.get_floor_variants_for_preset(&"performance").size()
		< resolver.get_floor_variants_for_preset(&"quality").size(),
		"performance preset reduces floor variants compared with quality"
	)
	performance_layer.free()

func _run_terrain_generator_integration_smoke(biome_manager: BiomeManager) -> void:
	var scene := Node2D.new()
	scene.name = "TileLayerIntegrationScene"
	var container := Node2D.new()
	container.name = "EnvironmentProps"
	scene.add_child(container)
	root.add_child(scene)
	current_scene = scene

	var terrain_generator := TerrainGenerator.new()
	terrain_generator.environment_container_path = NodePath("../EnvironmentProps")
	terrain_generator.region_ground_quality_preset = "balanced"
	scene.add_child(terrain_generator)
	await process_frame

	var biome := biome_manager.get_current_biome() as BiomeDefinition
	terrain_generator.start_run(biome)
	var layer := terrain_generator.get_active_tile_layer()
	_expect(layer != null, "TerrainGenerator creates BiomeTileLayer as primary ground")
	_expect(terrain_generator.get_active_ground() == null, "TerrainGenerator keeps BiomeRegionGround as fallback only")
	_expect(terrain_generator.get_generated_patches().is_empty(), "TerrainGenerator suppresses legacy terrain patches in tile layer mode")
	_expect(container.get_node_or_null("BiomeTileLayer") != null, "BiomeTileLayer is added to the environment container")
	if layer != null:
		_expect(layer.get_visual_tile_count() == 40000, "TerrainGenerator tile layer covers the full 200x200 region")
		_expect(layer.get_missing_asset_count() == 0, "TerrainGenerator tile layer has no missing assets")

	terrain_generator.stop_run()
	await process_frame
	_expect(
		container.get_node_or_null("BiomeTileLayer") == null
		or (container.get_node_or_null("BiomeTileLayer") as Node).is_queued_for_deletion(),
		"TerrainGenerator removes the tile layer on stop"
	)
	scene.queue_free()
	await process_frame

func _first_cell_per_biome(cells: Array[BiomeCell]) -> Array[BiomeCell]:
	var by_biome: Dictionary = {}
	var result: Array[BiomeCell] = []
	for cell in cells:
		if by_biome.has(cell.biome_id):
			continue
		by_biome[cell.biome_id] = true
		result.append(cell)
	return result

func _palette_for_biome(biome_id: StringName) -> BiomePalette:
	match biome_id:
		&"toxic_wastes":
			return load("res://game/modes/zombie/biomes/toxic_wastes_palette.tres") as BiomePalette
		&"burning_fields":
			return load("res://game/modes/zombie/biomes/burning_fields_palette.tres") as BiomePalette
		&"frozen_outskirts":
			return load("res://game/modes/zombie/biomes/frozen_outskirts_palette.tres") as BiomePalette
		&"drowned_marsh":
			return load("res://game/modes/zombie/biomes/drowned_marsh_palette.tres") as BiomePalette
		_:
			return load("res://game/modes/zombie/biomes/infected_plains_palette.tres") as BiomePalette

func _find_first_floor_cell(
	resolver: IsometricTileResolver,
	layout: BiomeEnvironmentLayout,
	cell: BiomeCell
) -> Vector2i:
	for y in range(layout.zone_size.y):
		for x in range(layout.zone_size.x):
			var probe := Vector2i(x, y)
			var tile_id := resolver.resolve_tile_id(layout, probe, cell.biome_id, &"balanced", cell)
			if (
				tile_id == IsometricTileResolver.TILE_FLOOR_BASE
				or tile_id == IsometricTileResolver.TILE_FLOOR_VARIANT_01
				or tile_id == IsometricTileResolver.TILE_FLOOR_VARIANT_02
			):
				return probe
	return Vector2i(layout.zone_size.x / 2, layout.zone_size.y / 2)

func _cell_inside_any_rect(cell: Vector2i, rects: Array[Rect2i]) -> bool:
	for rect in rects:
		if rect.has_point(cell):
			return true
	return false

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
		print("MILESTONE_10_TILE_LAYER_SMOKE_TEST: PASS")
		quit(0)
		return
	print("MILESTONE_10_TILE_LAYER_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
