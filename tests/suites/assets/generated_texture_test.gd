extends GutTest
## Assets A4 — Texture generate (forest surfaces, cliff/void) e loro consumo.
##
## Migra e accorpa:
##   tests/forest_grass_generated_texture_smoke_test.gd
##   tests/void_cliff_generated_texture_smoke_test.gd
##   tests/forest_isometric_texture_transition_smoke_test.gd
##
## Verifica i contratti delle texture generate (esistenza/provenienza/tileability
## di bordo, non qualità artistica), le mesh di cliff/bordo e il consumo runtime
## via BiomeTileLayer. La risoluzione su mappa generata usa una build 3x3 dedicata.

const FOREST_SURFACE_IDS: Array[StringName] = [
	&"forest_grass", &"forest_path", &"forest_road", &"grass_to_path", &"grass_to_road", &"path_to_road"
]
const EDGE_ID := &"cliff_lip_texture"
const CLIFF_TEXTURE_IDS: Array[StringName] = [
	&"cliff_face_texture", &"cliff_lip_texture", &"cliff_lip_vertical_texture"
]
const TRANSITION_IDS: Array[StringName] = [
	IsometricTileResolver.TILE_VOID_EDGE_NORTH, IsometricTileResolver.TILE_VOID_EDGE_EAST,
	IsometricTileResolver.TILE_VOID_EDGE_SOUTH, IsometricTileResolver.TILE_VOID_EDGE_WEST,
	IsometricTileResolver.TILE_VOID_CORNER_INNER_NORTH_EAST, IsometricTileResolver.TILE_VOID_CORNER_INNER_SOUTH_EAST,
	IsometricTileResolver.TILE_VOID_CORNER_INNER_SOUTH_WEST, IsometricTileResolver.TILE_VOID_CORNER_INNER_NORTH_WEST,
	IsometricTileResolver.TILE_VOID_CORNER_OUTER_NORTH_EAST, IsometricTileResolver.TILE_VOID_CORNER_OUTER_SOUTH_EAST,
	IsometricTileResolver.TILE_VOID_CORNER_OUTER_SOUTH_WEST, IsometricTileResolver.TILE_VOID_CORNER_OUTER_NORTH_WEST,
	IsometricTileResolver.TILE_VOID_DIAGONAL_NORTH_EAST_SOUTH_WEST, IsometricTileResolver.TILE_VOID_DIAGONAL_NORTH_WEST_SOUTH_EAST
]
const REQUIRED_FOREST_TILE_IDS: Array[StringName] = [
	&"forest_grass", &"forest_grass_variant_01", &"forest_grass_variant_02", &"forest_tall_grass",
	&"forest_path", &"forest_road", &"forest_void", &"forest_cliff_edge", &"forest_mountain_wall",
	&"grass_to_path", &"grass_to_road", &"grass_to_tall_grass", &"path_to_road",
	&"ground_to_void_cliff", &"ground_to_mountain_wall"
]

var _manifest: IsometricEnvironmentManifest

func before_all() -> void:
	_manifest = IsometricEnvironmentManifest.reload_shared()

# --- forest surface textures (forest_grass_generated_texture) ---------------

func test_forest_surface_textures() -> void:
	for asset_id in FOREST_SURFACE_IDS:
		_validate_generated_asset(_manifest.get_terrain_asset_contract(asset_id), asset_id)
	_validate_generated_asset(_manifest.get_void_asset_contract(EDGE_ID), EDGE_ID)

func test_forest_runtime_consumption() -> void:
	var palette := load("res://game/modes/zombie/biomes/infected_plains_palette.tres") as BiomePalette
	var layout := BiomeEnvironmentLayout.new()
	layout.zone_size = Vector2i(16, 16)
	layout.generation_seed = 862041
	layout.add_floor_rect(Rect2i(Vector2i.ZERO, layout.zone_size), &"forest_grass")
	layout.add_fall_zone_rect(Rect2i(Vector2i(6, 6), Vector2i(4, 4)), &"internal")
	layout.rebuild_terrain_classification()
	var layer := BiomeTileLayer.new()
	add_child(layer)
	layer.configure(layout, palette, &"infected_plains", &"quality", 16, null, _manifest, false)
	await wait_physics_frames(1)
	assert_true(layer.has_forest_ground_art_texture(), "forest tile layer loads generated grass")
	assert_true(layer.has_forest_surface_art_textures(), "forest tile layer loads every surface texture")
	assert_true(layer.get_forest_ground_art_asset_path().ends_with("forest_grass_generated.png"), "forest tile layer exposes generated grass path")
	var paths := layer.get_forest_surface_art_asset_paths()
	for asset_id in FOREST_SURFACE_IDS:
		var asset_path := String(paths.get(asset_id, ""))
		assert_true(asset_path.contains("_generated") and asset_path.ends_with(".png"), "forest tile layer exposes %s generated path" % String(asset_id))
	assert_true(layer.has_cliff_art_textures(), "forest tile layer loads grass-cliff edge")
	assert_gt(layer.get_cliff_transition_count(), 0, "forest void builds textured cliff transitions")
	assert_eq(layer._surface_mesh_overdraw_pixels(), 0.0, "forest legacy surface keeps exact mesh bounds")
	layer.queue_free()
	await wait_physics_frames(1)

func test_surface_mesh_overdraw_expands_vertices_without_moving_uvs() -> void:
	var run := Rect2i(Vector2i(1, 2), Vector2i(3, 1))
	var base_mesh := IsometricForestGroundMeshBuilder.build_mesh(
		[run],
		Vector2i(8, 8),
		24.0,
		128.0
	)
	var overdraw_mesh := IsometricForestGroundMeshBuilder.build_mesh(
		[run],
		Vector2i(8, 8),
		24.0,
		128.0,
		1.5
	)
	var base_bounds := _mesh_bounds(base_mesh)
	var overdraw_bounds := _mesh_bounds(overdraw_mesh)
	assert_true(
		overdraw_bounds.position.is_equal_approx(base_bounds.position - Vector2(1.5, 1.5))
		and overdraw_bounds.end.is_equal_approx(base_bounds.end + Vector2(1.5, 1.5)),
		"surface mesh overdraw covers subpixel seams around the run"
	)
	var base_uvs := (
		base_mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
		as PackedVector2Array
	)
	var overdraw_uvs := (
		overdraw_mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
		as PackedVector2Array
	)
	assert_eq(overdraw_uvs, base_uvs, "surface mesh overdraw leaves world-space UVs unchanged")

const GENERATED_BIOME_THEMES: Dictionary = {
	&"toxic_wastes": &"urban_ruins",
	&"burning_fields": &"volcanic",
	&"frozen_outskirts": &"frozen_tundra",
	&"drowned_marsh": &"swamp",
}
const GENERATED_BIOME_PASSAGE_TAGS: Dictionary = {
	&"toxic_wastes": &"broken_gate",
	&"burning_fields": &"burned_road",
	&"frozen_outskirts": &"snow_pass",
	&"drowned_marsh": &"bridge",
}

func test_generated_biome_catalog_contract() -> void:
	var failures := BiomeGeneratedArtCatalog.validate_catalog()
	assert_true(
		failures.is_empty(),
		"generated biome catalog is complete: %s" % "; ".join(failures)
	)
	assert_eq(
		BiomeGeneratedArtCatalog.get_total_asset_count(),
		191,
		"all generated PNG files are catalogued"
	)
	assert_eq(
		BiomeGeneratedArtCatalog.get_active_asset_count(),
		129,
		"all PNG files for the four active themes are catalogued"
	)
	assert_eq(
		BiomeGeneratedArtCatalog.get_unassigned_theme_ids(),
		[&"desert", &"forest"],
		"desert and replacement forest art remain explicitly unassigned"
	)
	var legacy_swamp_directory := DirAccess.open(
		"res://assets/environment/isometric/tiles/swamp/textures"
	)
	assert_true(
		legacy_swamp_directory == null
		or legacy_swamp_directory.get_files().is_empty(),
		"the nine temporary swamp duplicates are removed"
	)
	for biome_id_value in GENERATED_BIOME_THEMES:
		var biome_id := biome_id_value as StringName
		assert_eq(
			BiomeGeneratedArtCatalog.get_theme_id_for_biome(biome_id),
			GENERATED_BIOME_THEMES[biome_id],
			"%s resolves its intended generated theme" % String(biome_id)
		)
		var set_contract := _manifest.get_biome_asset_set_contract(biome_id)
		assert_eq(
			StringName(set_contract.get("generated_theme_id", &"")),
			GENERATED_BIOME_THEMES[biome_id],
			"%s manifest records the same generated theme" % String(biome_id)
		)
		assert_eq(
			String(set_contract.get("status", "")),
			"final",
			"%s generated pool is final" % String(biome_id)
		)
		assert_eq(
			String(set_contract.get("source", "")),
			"openai_image_generation",
			"%s generated pool keeps provenance" % String(biome_id)
		)
		assert_eq(
			String(set_contract.get("license", "")),
			"Project original",
			"%s generated pool keeps its license" % String(biome_id)
		)
		assert_eq(
			BiomeGeneratedArtCatalog.get_asset_paths_for_role(
				biome_id,
				BiomeGeneratedArtCatalog.ROLE_CLIFF_FACE
			).size(),
			2,
			"%s maps cliff 01/02 to face variants" % String(biome_id)
		)
		assert_eq(
			BiomeGeneratedArtCatalog.get_asset_paths_for_role(
				biome_id,
				BiomeGeneratedArtCatalog.ROLE_CLIFF_OUTER_CORNER
			).size(),
			4,
			"%s maps cliff 05-08 to outer corners" % String(biome_id)
		)
		assert_eq(
			BiomeGeneratedArtCatalog.get_asset_paths_for_role(
				biome_id,
				BiomeGeneratedArtCatalog.ROLE_CLIFF_INNER_CORNER
			).size(),
			2,
			"%s maps cliff 09/10 to mirrorable inner corners" % String(biome_id)
		)
		assert_eq(
			BiomeGeneratedArtCatalog.get_asset_paths_for_role(
				biome_id,
				BiomeGeneratedArtCatalog.ROLE_CLIFF_CAP
			).size(),
			1,
			"%s maps cliff 11 to the short cap" % String(biome_id)
		)

func test_frozen_surface_selection_uses_coherent_materials() -> void:
	var biome_id := &"frozen_outskirts"
	for sample in range(128):
		var ground_path := BiomeGeneratedArtCatalog.select_surface_asset_path(
			biome_id,
			BiomeGeneratedArtCatalog.ROLE_GROUND,
			85001 + sample,
			Vector2i(sample * 5, sample * 7)
		)
		assert_false(
			ground_path.contains("detail_decal"),
			"frozen ground avoids full-surface detail decals"
		)
		assert_false(
			ground_path.contains("base_ground_variation_04"),
			"frozen ground avoids ice-sheet blocks as the base surface"
		)
	var coherent_roles: Array[StringName] = [
		BiomeGeneratedArtCatalog.ROLE_PATH,
		BiomeGeneratedArtCatalog.ROLE_ROAD,
		BiomeGeneratedArtCatalog.ROLE_GROUND_TO_PATH,
		BiomeGeneratedArtCatalog.ROLE_GROUND_TO_ROAD,
	]
	for role in coherent_roles:
		var first := BiomeGeneratedArtCatalog.select_surface_asset_path(
			biome_id,
			role,
			94117,
			Vector2i(16, 24)
		)
		var adjacent := BiomeGeneratedArtCatalog.select_surface_asset_path(
			biome_id,
			role,
			94117,
			Vector2i(17, 25)
		)
		assert_eq(
			adjacent,
			first,
			"frozen %s keeps the same material within one macro patch"
			% String(role)
		)

func test_swamp_surface_selection_uses_coherent_materials() -> void:
	var biome_id := &"drowned_marsh"
	for sample in range(128):
		var ground_path := BiomeGeneratedArtCatalog.select_surface_asset_path(
			biome_id,
			BiomeGeneratedArtCatalog.ROLE_GROUND,
			86011 + sample,
			Vector2i(sample * 5, sample * 7)
		)
		assert_false(
			ground_path.contains("detail_decal"),
			"swamp ground avoids full-surface detail decals"
		)
		assert_false(
			ground_path.contains("base_ground_variation_02")
			or ground_path.contains("base_ground_variation_03"),
			"swamp ground avoids moss/lily feature blocks as the base surface"
		)
	var coherent_roles: Array[StringName] = [
		BiomeGeneratedArtCatalog.ROLE_PATH,
		BiomeGeneratedArtCatalog.ROLE_ROAD,
		BiomeGeneratedArtCatalog.ROLE_GROUND_TO_PATH,
		BiomeGeneratedArtCatalog.ROLE_GROUND_TO_ROAD,
	]
	for role in coherent_roles:
		var first := BiomeGeneratedArtCatalog.select_surface_asset_path(
			biome_id,
			role,
			94223,
			Vector2i(24, 32)
		)
		var adjacent := BiomeGeneratedArtCatalog.select_surface_asset_path(
			biome_id,
			role,
			94223,
			Vector2i(25, 33)
		)
		assert_eq(
			adjacent,
			first,
			"swamp %s keeps the same material within one macro patch"
			% String(role)
		)

func test_toxic_surface_selection_uses_coherent_materials() -> void:
	var biome_id := &"toxic_wastes"
	for sample in range(128):
		var ground_path := BiomeGeneratedArtCatalog.select_surface_asset_path(
			biome_id,
			BiomeGeneratedArtCatalog.ROLE_GROUND,
			87031 + sample,
			Vector2i(sample * 5, sample * 7)
		)
		assert_false(
			ground_path.contains("detail_decal"),
			"toxic ground avoids white-backed detail decals"
		)
	var coherent_roles: Array[StringName] = [
		BiomeGeneratedArtCatalog.ROLE_PATH,
		BiomeGeneratedArtCatalog.ROLE_ROAD,
		BiomeGeneratedArtCatalog.ROLE_GROUND_TO_PATH,
		BiomeGeneratedArtCatalog.ROLE_GROUND_TO_ROAD,
	]
	for role in coherent_roles:
		var first := BiomeGeneratedArtCatalog.select_surface_asset_path(
			biome_id,
			role,
			94337,
			Vector2i(32, 40)
		)
		var adjacent := BiomeGeneratedArtCatalog.select_surface_asset_path(
			biome_id,
			role,
			94337,
			Vector2i(33, 41)
		)
		assert_eq(
			adjacent,
			first,
			"toxic %s keeps the same material within one macro patch"
			% String(role)
		)

func test_burning_surface_selection_uses_coherent_materials() -> void:
	var biome_id := &"burning_fields"
	for sample in range(128):
		var ground_path := BiomeGeneratedArtCatalog.select_surface_asset_path(
			biome_id,
			BiomeGeneratedArtCatalog.ROLE_GROUND,
			88013 + sample,
			Vector2i(sample * 5, sample * 7)
		)
		assert_false(
			ground_path.contains("detail_decal"),
			"burning ground avoids full-surface lava detail decals"
		)
		assert_false(
			ground_path.contains("base_ground_variation_04"),
			"burning ground avoids flowing-lava feature blocks as the base surface"
		)
	var coherent_roles: Array[StringName] = [
		BiomeGeneratedArtCatalog.ROLE_PATH,
		BiomeGeneratedArtCatalog.ROLE_ROAD,
		BiomeGeneratedArtCatalog.ROLE_GROUND_TO_PATH,
		BiomeGeneratedArtCatalog.ROLE_GROUND_TO_ROAD,
	]
	for role in coherent_roles:
		var first := BiomeGeneratedArtCatalog.select_surface_asset_path(
			biome_id,
			role,
			94451,
			Vector2i(40, 48)
		)
		var adjacent := BiomeGeneratedArtCatalog.select_surface_asset_path(
			biome_id,
			role,
			94451,
			Vector2i(41, 49)
		)
		assert_eq(
			adjacent,
			first,
			"burning %s keeps the same material within one macro patch"
			% String(role)
		)

func test_generated_biome_catalog_deterministically_covers_active_assets() -> void:
	var selected_paths: Dictionary = {}
	var expected_paths: Dictionary = {}
	for biome_id_value in GENERATED_BIOME_THEMES:
		var biome_id := biome_id_value as StringName
		for asset_path in BiomeGeneratedArtCatalog.get_all_surface_asset_paths(
			biome_id
		):
			expected_paths[asset_path] = true
		for asset_path in BiomeGeneratedArtCatalog.get_all_cliff_asset_paths(
			biome_id
		):
			expected_paths[asset_path] = true
		for role in BiomeGeneratedArtCatalog.SURFACE_ROLES:
			for sample in range(1024):
				var cell := Vector2i(sample * 8, sample * 13)
				var selected := (
					BiomeGeneratedArtCatalog.select_surface_asset_path(
						biome_id,
						role,
						73001 + sample,
						cell
					)
				)
				selected_paths[selected] = true
				if sample == 0:
					assert_eq(
						selected,
						BiomeGeneratedArtCatalog.select_surface_asset_path(
							biome_id,
							role,
							73001 + sample,
							cell
						),
						"surface selection is deterministic"
					)
		for role in BiomeGeneratedArtCatalog.CLIFF_ROLES:
			for sample in range(256):
				var selected := (
					BiomeGeneratedArtCatalog.select_cliff_asset_path(
						biome_id,
						role,
						91003,
						sample
					)
				)
				selected_paths[selected] = true
				if sample == 0:
					assert_eq(
						selected,
						BiomeGeneratedArtCatalog.select_cliff_asset_path(
							biome_id,
							role,
							91003,
							sample
						),
						"cliff selection is deterministic"
					)
	selected_paths.erase("")
	assert_eq(expected_paths.size(), 129, "active themes expose 129 unique PNGs")
	assert_eq(
		selected_paths.size(),
		expected_paths.size(),
		"deterministic selectors can reach every active generated PNG"
	)
	for asset_path in expected_paths:
		assert_true(
			selected_paths.has(asset_path),
			"active generated asset is selectable: %s" % asset_path
		)

func test_generated_biome_runtime_consumption() -> void:
	for biome_id_value in GENERATED_BIOME_THEMES:
		var biome_id := biome_id_value as StringName
		var palette_path := (
			"res://game/modes/zombie/biomes/%s_palette.tres"
			% String(biome_id)
		)
		var palette := load(palette_path) as BiomePalette
		var layout := BiomeEnvironmentLayout.new()
		layout.zone_size = Vector2i(24, 24)
		layout.generation_seed = 990077 + String(biome_id).hash()
		layout.add_floor_rect(
			Rect2i(Vector2i.ZERO, layout.zone_size),
			&"open_block"
		)
		layout.road_rects.append(
			Rect2i(Vector2i(2, 10), Vector2i(20, 3))
		)
		layout.road_rect_tags.append(&"main_road")
		layout.road_rects.append(
			Rect2i(Vector2i(10, 2), Vector2i(3, 20))
		)
		layout.road_rect_tags.append(&"broken_street")
		layout.road_rects.append(
			Rect2i(Vector2i(18, 2), Vector2i(3, 5))
		)
		layout.road_rect_tags.append(
			GENERATED_BIOME_PASSAGE_TAGS[biome_id] as StringName
		)
		layout.add_hazard_rect(
			Rect2i(Vector2i(3, 3), Vector2i(3, 3)),
			&"test_hazard"
		)
		layout.add_fall_zone_rect(
			Rect2i(Vector2i(9, 9), Vector2i(6, 6)),
			&"internal"
		)
		layout.rebuild_terrain_classification()
		var layer := BiomeTileLayer.new()
		add_child(layer)
		layer.configure(
			layout,
			palette,
			biome_id,
			&"quality",
			24,
			null,
			_manifest,
			false
		)
		await wait_physics_frames(1)
		assert_true(
			layer.has_forest_surface_art_textures(),
			"%s loads every generated surface texture" % String(biome_id)
		)
		assert_eq(
			layer.get_loaded_surface_texture_ids().size(),
			BiomeGeneratedArtCatalog.get_all_surface_asset_paths(biome_id).size(),
			"%s exposes every surface material" % String(biome_id)
		)
		assert_gt(
			layer.get_rendered_surface_material_ids().size(),
			0,
			"%s produces non-empty generated surface meshes" % String(biome_id)
		)
		assert_gt(
			layer._surface_mesh_overdraw_pixels(),
			0.0,
			"%s generated surface mesh uses seam-covering overdraw"
			% String(biome_id)
		)
		var first_rendered_id := layer.get_rendered_surface_material_ids()[0]
		var runtime_texture := (
			layer._forest_surface_textures.get(first_rendered_id) as Texture2D
		)
		var source_path := String(
			layer.get_forest_surface_art_asset_paths().get(first_rendered_id, "")
		)
		var source_image := Image.new()
		var source_load_error := source_image.load(
			ProjectSettings.globalize_path(source_path)
		)
		assert_eq(source_load_error, OK, "%s source surface image loads" % String(biome_id))
		var expected_surface_trim := (
			_expected_generated_surface_texture_trim_pixels(biome_id)
		)
		assert_eq(
			runtime_texture.get_width(),
			source_image.get_width() - expected_surface_trim * 2,
			"%s trims the bright generated surface border at runtime"
			% String(biome_id)
		)
		if biome_id == &"burning_fields":
			var runtime_image := runtime_texture.get_image()
			assert_lte(
				_edge_seam_score(runtime_image),
				0.04,
				"burning_fields runtime surface harmonizes opposite edges"
			)
		var selected_material_ids: Dictionary = {}
		var selected_material_paths: Dictionary = {}
		for y in range(layout.zone_size.y):
			for x in range(layout.zone_size.x):
				var cell := Vector2i(x, y)
				var selected_id := layer.get_resolved_material_asset_id(cell)
				if not selected_id.is_empty():
					selected_material_ids[selected_id] = true
					selected_material_paths[
						layer.get_resolved_material_asset_path(cell)
					] = true
		var expected_theme_fragment := (
			"/%s/" % String(GENERATED_BIOME_THEMES[biome_id])
		)
		for selected_path in selected_material_paths:
			assert_true(
				String(selected_path).contains(expected_theme_fragment),
				"%s resolver never falls back outside its generated theme: %s"
				% [String(biome_id), String(selected_path)]
			)
		assert_true(
			layer.get_resolved_material_asset_path(
				Vector2i(4, 4)
			).contains(expected_theme_fragment),
			"%s hazard underlay uses its generated theme" % String(biome_id)
		)
		assert_true(
			layer.get_resolved_material_asset_path(
				Vector2i(19, 3)
			).contains(expected_theme_fragment),
			"%s passage surface uses its generated theme" % String(biome_id)
		)
		var rendered_material_ids: Dictionary = {}
		for rendered_id in layer.get_rendered_surface_material_ids():
			rendered_material_ids[rendered_id] = true
		assert_eq(
			rendered_material_ids.size(),
			selected_material_ids.size(),
			"%s builds one non-empty mesh for every selected material"
			% String(biome_id)
		)
		for selected_id in selected_material_ids:
			assert_true(
				rendered_material_ids.has(selected_id),
				"%s renders selected material %s"
				% [String(biome_id), String(selected_id)]
			)
		assert_eq(
			layer.get_loaded_cliff_variant_count(),
			11,
			"%s loads face, lip, corner and cap cliff art" % String(biome_id)
		)
		var cliff_paths := layer.get_cliff_art_asset_paths()
		var cliff_lip_path := String(
			cliff_paths.get(&"cliff_lip_texture", "")
		)
		var cliff_lip_source_image := Image.new()
		var cliff_lip_source_load_error := cliff_lip_source_image.load(
			ProjectSettings.globalize_path(cliff_lip_path)
		)
		assert_eq(
			cliff_lip_source_load_error,
			OK,
			"%s source cliff lip image loads" % String(biome_id)
		)
		var expected_cliff_trim := (
			_expected_generated_cliff_texture_trim_pixels(biome_id)
		)
		assert_eq(
			layer._cliff_lip_texture.get_width(),
			cliff_lip_source_image.get_width() - expected_cliff_trim * 2,
			"%s trims generated cliff lips only where the source has matte edges"
			% String(biome_id)
		)
		if biome_id == &"burning_fields":
			var runtime_cliff_lip_image := layer._cliff_lip_texture.get_image()
			assert_lte(
				_edge_seam_score(runtime_cliff_lip_image),
				0.06,
				"burning_fields runtime cliff lip harmonizes opposite edges"
			)
		var probe := Vector2i(3, 3)
		var material_path := layer.get_resolved_material_asset_path(probe)
		assert_true(
			material_path.contains(
				"/%s/" % String(GENERATED_BIOME_THEMES[biome_id])
			),
			"%s ground resolves to its generated theme: %s"
			% [String(biome_id), material_path]
		)
		assert_true(
			layer.get_resolved_material_asset_id(probe) != &"",
			"%s cache exposes the selected material id" % String(biome_id)
		)
		layer.queue_free()
		await wait_physics_frames(1)

func test_generated_chunk_rebuild_profile() -> void:
	var biome_id := &"toxic_wastes"
	var palette := load(
		"res://game/modes/zombie/biomes/toxic_wastes_palette.tres"
	) as BiomePalette
	var layout := BiomeEnvironmentLayout.new()
	layout.zone_size = Vector2i(40, 40)
	layout.generation_seed = 880041
	layout.add_floor_rect(Rect2i(Vector2i.ZERO, layout.zone_size), &"open_block")
	layout.road_rects.append(Rect2i(Vector2i(0, 17), Vector2i(40, 5)))
	layout.road_rect_tags.append(&"main_road")
	layout.road_rects.append(Rect2i(Vector2i(17, 0), Vector2i(5, 40)))
	layout.road_rect_tags.append(&"broken_street")
	layout.add_hazard_rect(
		Rect2i(Vector2i(5, 5), Vector2i(8, 8)),
		&"test_hazard"
	)
	layout.add_fall_zone_rect(
		Rect2i(Vector2i(25, 25), Vector2i(8, 8)),
		&"internal"
	)
	layout.rebuild_terrain_classification()
	var layer := BiomeTileLayer.new()
	add_child(layer)
	layer.configure(
		layout,
		palette,
		biome_id,
		&"balanced",
		20,
		null,
		_manifest,
		false,
		false
	)
	var rebuild_times_usec := PackedInt64Array()
	for coord in [
		Vector2i(0, 0),
		Vector2i(1, 0),
		Vector2i(0, 1),
		Vector2i(1, 1)
	]:
		var started_usec := Time.get_ticks_usec()
		assert_true(layer.ensure_chunk(coord), "generated chunk %s rebuilds" % coord)
		rebuild_times_usec.append(Time.get_ticks_usec() - started_usec)
		layer.evict_chunks_except([])
	var total_usec := 0
	var max_usec := 0
	for elapsed_usec in rebuild_times_usec:
		total_usec += elapsed_usec
		max_usec = maxi(max_usec, elapsed_usec)
	var average_msec := (
		float(total_usec)
		/ float(maxi(rebuild_times_usec.size(), 1))
		/ 1000.0
	)
	gut.p(
		"GENERATED_CHUNK_PROFILE: avg %.3f ms, max %.3f ms"
		% [average_msec, float(max_usec) / 1000.0]
	)
	assert_lt(float(max_usec) / 1000.0, 50.0,
		"a single generated chunk stays below the seam frame ceiling")
	layer.queue_free()
	await wait_physics_frames(1)

func test_generated_biome_upward_cliff_profiles() -> void:
	for biome_id_value in GENERATED_BIOME_THEMES:
		var biome_id := biome_id_value as StringName
		var profile := PerimeterCliffVisualProfile.new()
		profile.configure(
			BiomeEnvironmentLayout.PERIMETER_VISUAL_RAISED_CLIFF,
			&"north",
			Vector2.ZERO,
			BiomeEnvironmentLayout.RAISED_CLIFF_HEIGHT_CELLS,
			8.0,
			Color("665544"),
			Color("aa8866"),
			biome_id
		)
		assert_true(
			profile.has_raised_cliff_art(),
			"%s upward cliff loads generated face and crown art"
			% String(biome_id)
		)
		var paths := profile.asset_paths
		var theme_id := String(GENERATED_BIOME_THEMES[biome_id])
		assert_true(
			String(paths.get(&"face", "")).contains("/%s/" % theme_id),
			"%s upward face uses its biome theme" % String(biome_id)
		)
		assert_true(
			String(paths.get(&"top", "")).contains("/%s/" % theme_id),
			"%s upward crown uses its biome theme" % String(biome_id)
		)

# --- cliff/void textures e mesh (void_cliff_generated_texture) --------------

func test_cliff_manifest_assets() -> void:
	for asset_id in CLIFF_TEXTURE_IDS:
		_validate_generated_asset(_manifest.get_void_asset_contract(asset_id), asset_id)
	assert_true(String(_manifest.get_void_asset_contract(&"cliff_lip_texture").get("asset_path", "")).ends_with("grass_cliff_edge_generated_v2.png"),
		"cliff lip uses the directional grass-to-rock v2 material")

func test_transition_meshes() -> void:
	var palette := load("res://game/modes/zombie/biomes/infected_plains_palette.tres") as BiomePalette
	assert_not_null(palette, "infected plains palette loads for cliff mesh QA")
	if palette == null:
		return
	var builder := IsometricCliffMeshBuilder.new()
	builder.configure(palette, 424242, true)
	for index in range(TRANSITION_IDS.size()):
		builder.append_transition(TRANSITION_IDS[index], Vector2(float(index % 7) * 100.0, float(index / 7) * 120.0), 42.0, 22.0)
	builder.build_meshes()
	assert_eq(builder.transition_count, TRANSITION_IDS.size(), "all 14 cliff variants build")
	assert_true(_mesh_has_uvs(builder.face_mesh), "cliff face mesh exposes texture UVs")
	assert_true(_mesh_has_uvs(builder.lip_mesh), "cliff lip mesh exposes texture UVs")
	assert_false(builder.lip_lines.is_empty(), "crisp cliff crest remains available")
	assert_false(builder.fissure_lines.is_empty(), "procedural fissure detail remains available")
	_validate_lip_uv_direction(palette)

func test_rectangular_border_meshes() -> void:
	var builder := IsometricCliffBorderMeshBuilder.new()
	builder.build([Rect2i(Vector2i(4, 5), Vector2i(6, 4))], [&"internal"], Vector2i(16, 16), 8.0)
	assert_true(builder.horizontal_segment_count == 2 and builder.vertical_segment_count == 2 and builder.corner_count == 4,
		"one fall rectangle builds two horizontal edges, two vertical edges and four corners")
	assert_true(_mesh_has_uvs(builder.horizontal_mesh), "horizontal cliff border exposes UVs")
	assert_true(_mesh_has_uvs(builder.vertical_mesh), "vertical cliff border exposes UVs")
	var h := _mesh_bounds(builder.horizontal_mesh)
	var v := _mesh_bounds(builder.vertical_mesh)
	assert_true(is_equal_approx(h.position.x, -32.0) and is_equal_approx(h.end.x, 16.0) and is_equal_approx(h.position.y, -24.0) and is_equal_approx(h.end.y, 8.0)
		and is_equal_approx(v.position.x, -32.0) and is_equal_approx(v.end.x, 16.0) and v.position.y > -24.0 and v.end.y < 8.0,
		"both rock edges stay inside the fall rectangle with horizontal corner ownership")
	builder.build([Rect2i(Vector2i(0, 0), Vector2i(16, 3))], [&"north"], Vector2i(16, 16), 8.0)
	assert_true(builder.horizontal_segment_count == 1 and builder.vertical_segment_count == 0 and builder.corner_count == 2,
		"perimeter fall zone draws only the edge facing walkable terrain")

func test_rectilinear_face_meshes() -> void:
	var builder := RectilinearCliffFaceMeshBuilder.new()
	builder.build([Rect2i(Vector2i(4, 5), Vector2i(6, 4))], [&"internal"], Vector2i(16, 16), 8.0)
	assert_eq(builder.face_count, 4, "internal fall rectangle builds four cliff faces")
	assert_true(_mesh_has_uvs(builder.face_mesh), "rectilinear cliff faces expose UVs")
	assert_false(_mesh_is_axis_aligned_quads(builder.face_mesh), "lateral cliff faces are sheared into an oblique ravine in fake perspective")
	assert_eq(_mesh_sheared_quad_count(builder.face_mesh), 2, "both side walls (east/west) lean toward the void interior")
	var bounds := _mesh_bounds(builder.face_mesh)
	assert_true(bounds.position.is_equal_approx(Vector2(-32.0, -24.0)) and bounds.end.is_equal_approx(Vector2(16.0, 8.0)), "rectilinear cliff faces stay inside the fall rectangle")

func test_tile_layer_consumes_cliff_textures() -> void:
	var palette := load("res://game/modes/zombie/biomes/infected_plains_palette.tres") as BiomePalette
	var layout := BiomeEnvironmentLayout.new()
	layout.zone_size = Vector2i(16, 16)
	layout.generation_seed = 515151
	layout.add_floor_rect(Rect2i(Vector2i.ZERO, layout.zone_size), &"forest_grass")
	layout.add_fall_zone_rect(Rect2i(Vector2i(6, 6), Vector2i(4, 4)), &"internal")
	layout.rebuild_terrain_classification()
	var layer := BiomeTileLayer.new()
	add_child(layer)
	layer.configure(layout, palette, &"infected_plains", &"quality", 16, null, _manifest, false)
	await wait_physics_frames(1)
	assert_true(layer.has_cliff_art_textures(), "tile layer loads face and lip textures")
	assert_true(layer.has_forest_cliff_border_art(), "forest tile layer loads horizontal and vertical cliff border art")
	var paths := layer.get_cliff_art_asset_paths()
	for asset_id in CLIFF_TEXTURE_IDS:
		assert_false(String(paths.get(asset_id, "")).is_empty(), "tile layer exposes %s asset path" % String(asset_id))
	assert_gt(layer.get_cliff_transition_count(), 0, "synthetic void builds textured cliff transitions")
	var border_counts := layer.get_forest_cliff_border_counts()
	assert_true(int(border_counts.get("horizontal", 0)) == 2 and int(border_counts.get("vertical", 0)) == 2 and int(border_counts.get("corners", 0)) == 4,
		"synthetic fall rectangle applies every dedicated border mesh")
	assert_eq(int(border_counts.get("faces", 0)), 4, "synthetic fall rectangle replaces angled per-cell faces with four linear faces")
	layer.queue_free()
	await wait_physics_frames(1)

func test_fall_gameplay_unchanged() -> void:
	var zone := BiomeFallZone.new()
	add_child(zone)
	zone.configure(&"fall_zone", Vector2(180.0, 64.0), 0.0, Color(0.82, 0.58, 0.16, 0.92), &"cliff", &"north", 616161)
	await wait_physics_frames(1)
	assert_true(zone.contains_global_position(zone.global_position), "fall-zone collision still owns the drop")
	assert_true(zone.uses_procedural_fallback(), "fall zone does not duplicate tile-layer cliff art")
	var collision := zone.get_node_or_null("CollisionShape2D") as CollisionShape2D
	assert_true(collision != null and collision.shape is RectangleShape2D and (collision.shape as RectangleShape2D).size == zone.zone_size,
		"generated cliff art does not change fall collision")
	zone.queue_free()
	await wait_physics_frames(1)

# --- forest tile resolver su mappa generata (forest_iso_transition) ---------

func test_forest_tile_contracts() -> void:
	var resolver := IsometricTileResolver.new(_manifest)
	for tile_id in REQUIRED_FOREST_TILE_IDS:
		var section := resolver.resolve_tile_section(tile_id)
		var contract := _manifest.get_asset_contract(section, tile_id)
		assert_false(contract.is_empty(), "%s has a forest asset contract" % String(tile_id))
		assert_true(_asset_exists(String(contract.get("asset_path", ""))), "%s asset file exists" % String(tile_id))
	var biome_set := _manifest.get_biome_asset_set_contract(&"infected_plains")
	assert_true(_string_name_array(biome_set.get("terrain_tiles", [])).has(&"forest_path"), "base biome asset set includes forest terrain tiles")
	assert_true(_string_name_array(biome_set.get("void_tiles", [])).has(&"forest_cliff_edge"), "base biome asset set includes forest cliff edge")
	assert_true(_string_name_array(biome_set.get("edge_tiles", [])).has(&"forest_mountain_wall"), "base biome asset set includes forest mountain wall")

func test_generated_forest_resolver() -> void:
	var resolver := IsometricTileResolver.new(_manifest)
	var biome_manager := BiomeManager.new()
	add_child(biome_manager)
	await wait_physics_frames(1)
	biome_manager.start_run({"world_seed": 772031, "biome_map_width": 3, "biome_map_height": 3, "preserve_biome_sequence": false, "extra_edge_chance": 0.25})
	var cell := _first_cell_for_biome(biome_manager.get_generated_biome_map(), &"infected_plains")
	assert_not_null(cell, "generated map contains the base forest biome")
	if cell == null:
		biome_manager.queue_free()
		await wait_physics_frames(1)
		return
	var layout := cell.generated_layout
	assert_not_null(layout, "base forest biome has generated layout")
	if layout == null:
		biome_manager.queue_free()
		await wait_physics_frames(1)
		return

	var saw_tiles: Dictionary = {}
	var saw_oriented_cliff := false
	var tall_grass_cell := Vector2i(-1, -1)
	var checked := 0
	for y in range(layout.zone_size.y):
		for x in range(layout.zone_size.x):
			var probe := Vector2i(x, y)
			var tile_id := resolver.resolve_tile_id(layout, probe, cell.biome_id, &"balanced", cell)
			saw_tiles[tile_id] = true
			if resolver.is_void_transition_tile_id(tile_id):
				saw_oriented_cliff = true
			if layout.get_floor_tag_at_cell(probe) == &"forest_tall_grass" and [&"forest_tall_grass", &"grass_to_tall_grass"].has(tile_id):
				tall_grass_cell = probe
			checked += 1
	assert_eq(checked, layout.zone_size.x * layout.zone_size.y, "forest resolver covers the full chunk")
	for tile_id in [&"forest_grass", &"forest_path", &"forest_road", &"forest_void", &"grass_to_path", &"grass_to_road", &"path_to_road", &"ground_to_void_cliff"]:
		assert_true(saw_tiles.has(tile_id), "generated forest emits %s" % String(tile_id))
	assert_true(saw_oriented_cliff, "generated forest emits neighbor-aware cliff transitions")
	assert_ne(tall_grass_cell, Vector2i(-1, -1), "generated forest has tall grass floor cells")
	if tall_grass_cell != Vector2i(-1, -1):
		assert_eq(layout.get_terrain_class_at_cell(tall_grass_cell, cell), BiomeEnvironmentLayout.TERRAIN_WALKABLE, "forest tall grass remains walkable terrain")
		assert_true([&"forest_tall_grass", &"grass_to_tall_grass"].has(resolver.resolve_tile_id(layout, tall_grass_cell, cell.biome_id, &"balanced", cell)),
			"forest tall grass resolves to grass or its vegetation transition")

	var palette := load("res://game/modes/zombie/biomes/infected_plains_palette.tres") as BiomePalette
	var layer := BiomeTileLayer.new()
	layer.configure(layout, palette, cell.biome_id, &"balanced", 20, resolver, _manifest)
	assert_eq(layer.get_missing_asset_count(), 0, "forest tile layer has no missing assets")
	assert_gt(layer.get_texture_detail_line_count(), 0, "forest tile layer bakes texture detail lines")
	assert_gt(layer.get_suppressed_void_texture_count(), 0, "forest tile layer keeps pure void free of repeated tile texture")
	assert_eq(layer.get_void_background_color(), ZombieModeController.get_void_background_color(palette), "forest void uses the same color as the off-world backdrop")
	var cliff_underlay_key := layer._forest_underlay_key(IsometricTileResolver.TILE_VOID_EDGE_WEST)
	assert_true(cliff_underlay_key == &"grass" and layer._forest_underlay_color(cliff_underlay_key) == layer._forest_underlay_color(&"grass"),
		"forest cliff transitions keep grass beneath the directional crest")
	assert_eq(layer._forest_surface_texture_id(IsometricTileResolver.TILE_VOID_EDGE_WEST), &"forest_grass", "forest grass texture reaches the exact cliff crest")
	assert_gt(layer.get_cliff_transition_count(), 0, "forest tile layer bakes vertical cliff faces")
	layer.free()
	biome_manager.queue_free()
	await wait_physics_frames(1)

func test_synthetic_forest_wall() -> void:
	var resolver := IsometricTileResolver.new(_manifest)
	var layout := BiomeEnvironmentLayout.new()
	layout.zone_size = Vector2i(16, 16)
	layout.generation_seed = 21
	layout.add_floor_rect(Rect2i(Vector2i(0, 0), layout.zone_size), &"open_block")
	var wall_rect := Rect2i(Vector2i(0, 0), Vector2i(16, 4))
	layout.add_wall_segment(wall_rect, &"north")
	layout.obstacle_rects.append(wall_rect)
	layout.obstacle_ids.append(&"boundary_fence")
	layout.rebuild_terrain_classification()
	assert_eq(resolver.resolve_tile_id(layout, Vector2i(4, 1), &"infected_plains"), &"forest_mountain_wall", "forest wall cells resolve to the mountain wall tile")
	assert_eq(resolver.resolve_tile_id(layout, Vector2i(4, 4), &"infected_plains"), &"ground_to_mountain_wall", "ground beside wall resolves to a mountain transition")

# --- helper (porting dei test legacy) ---------------------------------------

func _validate_generated_asset(contract: Dictionary, asset_id: StringName) -> void:
	var asset_path := String(contract.get("asset_path", ""))
	assert_false(contract.is_empty(), "%s has an asset contract" % String(asset_id))
	assert_true(asset_path.ends_with(".png"), "%s uses generated PNG art" % String(asset_id))
	assert_true(FileAccess.file_exists(asset_path), "%s PNG exists" % String(asset_id))
	assert_eq(String(contract.get("status", "")), "final", "%s art is final" % String(asset_id))
	assert_eq(String(contract.get("source", "")), "openai_image_generation", "%s records generated-art provenance" % String(asset_id))
	var image := Image.new()
	var load_error := image.load(ProjectSettings.globalize_path(asset_path))
	assert_eq(load_error, OK, "%s source image loads" % String(asset_id))
	if load_error != OK:
		return
	assert_true(image.get_width() >= 512 and image.get_height() >= 512, "%s source supports mipmapped runtime downscale" % String(asset_id))
	var seam_score := _edge_seam_score(image)
	assert_lte(seam_score, 0.24, "%s opposite edges are visually tileable (score %.3f)" % [String(asset_id), seam_score])

func _validate_lip_uv_direction(palette: BiomePalette) -> void:
	var builder := IsometricCliffMeshBuilder.new()
	builder.configure(palette, 424242, true)
	builder.append_transition(IsometricTileResolver.TILE_VOID_EDGE_NORTH, Vector2.ZERO, 42.0, 22.0)
	builder.build_meshes()
	var arrays := builder.lip_mesh.surface_get_arrays(0)
	var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector2Array
	var uvs := arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array
	var ground_y := 0.0
	var void_y := 0.0
	var ground_count := 0
	var void_count := 0
	for index in range(vertices.size()):
		if is_zero_approx(uvs[index].y):
			ground_y += vertices[index].y
			ground_count += 1
		elif is_equal_approx(uvs[index].y, 1.0):
			void_y += vertices[index].y
			void_count += 1
	assert_true(ground_count > 0 and void_count > 0 and void_y / float(void_count) > ground_y / float(ground_count),
		"cliff lip UV runs from walkable grass toward the void")

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
	return ResourceLoader.exists(asset_path) or FileAccess.file_exists(asset_path)

func _expected_generated_surface_texture_trim_pixels(
	biome_id: StringName
) -> int:
	if biome_id == &"burning_fields":
		return 10
	return 2

func _expected_generated_cliff_texture_trim_pixels(biome_id: StringName) -> int:
	if biome_id == &"burning_fields":
		return 10
	return 0

func _mesh_has_uvs(mesh: ArrayMesh) -> bool:
	if mesh == null or mesh.get_surface_count() <= 0:
		return false
	var arrays := mesh.surface_get_arrays(0)
	var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector2Array
	var uvs := arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array
	return not vertices.is_empty() and uvs.size() == vertices.size()

func _mesh_bounds(mesh: ArrayMesh) -> Rect2:
	if mesh == null or mesh.get_surface_count() <= 0:
		return Rect2()
	var arrays := mesh.surface_get_arrays(0)
	var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector2Array
	if vertices.is_empty():
		return Rect2()
	var bounds := Rect2(vertices[0], Vector2.ZERO)
	for vertex in vertices:
		bounds = bounds.expand(vertex)
	return bounds

func _mesh_is_axis_aligned_quads(mesh: ArrayMesh) -> bool:
	if mesh == null or mesh.get_surface_count() <= 0:
		return false
	var arrays := mesh.surface_get_arrays(0)
	var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector2Array
	if vertices.is_empty() or vertices.size() % 4 != 0:
		return false
	for base in range(0, vertices.size(), 4):
		if (not is_equal_approx(vertices[base].y, vertices[base + 1].y)
				or not is_equal_approx(vertices[base + 1].x, vertices[base + 2].x)
				or not is_equal_approx(vertices[base + 2].y, vertices[base + 3].y)
				or not is_equal_approx(vertices[base + 3].x, vertices[base].x)):
			return false
	return true

func _mesh_sheared_quad_count(mesh: ArrayMesh) -> int:
	if mesh == null or mesh.get_surface_count() <= 0:
		return 0
	var arrays := mesh.surface_get_arrays(0)
	var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector2Array
	if vertices.is_empty() or vertices.size() % 4 != 0:
		return 0
	var count := 0
	for base in range(0, vertices.size(), 4):
		if not is_equal_approx(vertices[base].y, vertices[base + 1].y) and not is_equal_approx(vertices[base].x, vertices[base + 1].x):
			count += 1
	return count

func _edge_seam_score(image: Image) -> float:
	if image == null or image.is_empty():
		return 1.0
	var last_x := image.get_width() - 1
	var last_y := image.get_height() - 1
	var step := maxi(mini(image.get_width(), image.get_height()) / 256, 1)
	var total := 0.0
	var samples := 0
	for y in range(0, image.get_height(), step):
		total += _rgb_delta(image.get_pixel(0, y), image.get_pixel(last_x, y))
		samples += 1
	for x in range(0, image.get_width(), step):
		total += _rgb_delta(image.get_pixel(x, 0), image.get_pixel(x, last_y))
		samples += 1
	return total / float(maxi(samples, 1))

func _rgb_delta(first: Color, second: Color) -> float:
	return (absf(first.r - second.r) + absf(first.g - second.g) + absf(first.b - second.b)) / 3.0
