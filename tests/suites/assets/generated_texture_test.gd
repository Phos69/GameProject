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
	&"forest_grass", &"forest_path", &"forest_road", &"forest_road_border",
	&"grass_to_path", &"grass_to_road", &"path_to_road"
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
const ROAD_BORDER_TILE_IDS: Array[StringName] = [
	IsometricTileResolver.TILE_ROAD_EDGE,
	IsometricTileResolver.TILE_ROAD_CURVE_NORTH,
	IsometricTileResolver.TILE_ROAD_CURVE_EAST,
	IsometricTileResolver.TILE_ROAD_CURVE_SOUTH,
	IsometricTileResolver.TILE_ROAD_CURVE_WEST
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
		assert_true(
			(
				asset_path.contains("_generated")
				or asset_path.contains("_defined")
			)
			and asset_path.ends_with(".png"),
			"forest tile layer exposes %s generated path" % String(asset_id)
		)
	assert_true(layer.has_cliff_art_textures(), "forest tile layer loads grass-cliff edge")
	assert_gt(layer.get_cliff_transition_count(), 0, "forest void builds textured cliff transitions")
	assert_eq(layer._surface_mesh_overdraw_pixels(), 0.0, "forest legacy surface keeps exact mesh bounds")
	layer.queue_free()
	await wait_physics_frames(1)

func test_forest_route_transitions_render_with_route_surfaces() -> void:
	var palette := load("res://game/modes/zombie/biomes/infected_plains_palette.tres") as BiomePalette
	var layout := BiomeEnvironmentLayout.new()
	layout.zone_size = Vector2i(28, 24)
	layout.generation_seed = 712449
	layout.add_floor_rect(Rect2i(Vector2i.ZERO, layout.zone_size), &"forest_grass")
	layout.road_rects.append(Rect2i(Vector2i(3, 10), Vector2i(22, 5)))
	layout.road_rect_tags.append(&"main_road")
	layout.road_rects.append(Rect2i(Vector2i(12, 3), Vector2i(4, 18)))
	layout.road_rect_tags.append(&"broken_street")
	layout.road_rects.append(Rect2i(Vector2i(22, 3), Vector2i(5, 17)))
	layout.road_rect_tags.append(&"main_road")
	layout.rebuild_terrain_classification()
	var layer := BiomeTileLayer.new()
	add_child(layer)
	layer.configure(layout, palette, &"infected_plains", &"quality", 14, null, _manifest, false)
	await wait_physics_frames(1)

	assert_eq(
		layer._forest_surface_texture_id(IsometricTileResolver.TILE_GRASS_TO_PATH),
		&"forest_road_border",
		"forest grass/path contact renders with the defined road-border surface"
	)
	assert_eq(
		layer._forest_surface_texture_id(IsometricTileResolver.TILE_FOREST_ROAD),
		&"forest_road_border",
		"forest road interiors render with the same defined road-border material as the edges"
	)
	assert_eq(
		layer._forest_surface_texture_id(IsometricTileResolver.TILE_GRASS_TO_ROAD),
		&"forest_road_border",
		"forest grass/road contact renders with the defined road-border surface"
	)
	assert_eq(
		layer._forest_surface_texture_id(IsometricTileResolver.TILE_PATH_TO_ROAD),
		&"forest_road_border",
		"forest path/road crossing stays in the defined road-border material family"
	)
	assert_eq(
		layer._surface_texture_id_for_cell(
			Vector2i(4, 10),
			layer.get_resolved_tile_id(Vector2i(4, 10))
		),
		&"forest_road_border__horizontal",
		"forest horizontal road edge uses the rotated road-border surface"
	)
	assert_eq(
		layer._surface_texture_id_for_cell(
			Vector2i(22, 4),
			layer.get_resolved_tile_id(Vector2i(22, 4))
		),
		&"forest_road_border__vertical",
		"forest vertical road edge uses the native road-border surface"
	)
	assert_eq(
		layer._surface_texture_id_for_cell(
			Vector2i(4, 12),
			layer.get_resolved_tile_id(Vector2i(4, 12))
		),
		&"forest_road_border__core_horizontal",
		"forest horizontal road interior uses the core derived from the defined road-border asset"
	)
	assert_eq(
		layer._surface_texture_id_for_cell(
			Vector2i(24, 5),
			layer.get_resolved_tile_id(Vector2i(24, 5))
		),
		&"forest_road_border__core_vertical",
		"forest vertical road interior uses the core derived from the defined road-border asset"
	)
	assert_eq(
		layer.get_resolved_tile_id(Vector2i(13, 12)),
		IsometricTileResolver.TILE_PATH_TO_ROAD,
		"forest route crossing keeps the path-to-road semantic tile id"
	)
	assert_eq(
		layer._surface_texture_id_for_cell(
			Vector2i(13, 12),
			layer.get_resolved_tile_id(Vector2i(13, 12))
		),
		&"forest_road_border__core_horizontal",
		"forest path/road crossing renders as road core, not a grass border patch"
	)
	var rendered_ids := layer.get_rendered_surface_material_ids()
	assert_false(
		rendered_ids.has(&"forest_path"),
		"forest dirt path texture is loaded but no longer rendered on route corridors"
	)
	assert_false(
		rendered_ids.has(&"forest_road"),
		"forest asphalt texture is loaded but no longer rendered on route corridors"
	)
	assert_true(
		rendered_ids.has(&"forest_road_border__horizontal"),
		"horizontal defined road-border surface is rendered"
	)
	assert_true(
		rendered_ids.has(&"forest_road_border__vertical"),
		"vertical defined road-border surface is rendered"
	)
	assert_true(
		rendered_ids.has(&"forest_road_border__core_horizontal"),
		"horizontal defined road core surface is rendered"
	)
	assert_true(
		rendered_ids.has(&"forest_road_border__core_vertical"),
		"vertical defined road core surface is rendered"
	)
	assert_false(
		rendered_ids.has(&"forest_road_border"),
		"unoriented forest road-border base texture is loaded but not rendered"
	)
	assert_false(rendered_ids.has(&"grass_to_path"), "grass/path intermediate surface is not rendered")
	assert_false(rendered_ids.has(&"grass_to_road"), "grass/road intermediate surface is not rendered")
	assert_false(rendered_ids.has(&"path_to_road"), "path/road intermediate surface is not rendered")

	layer.queue_free()
	await wait_physics_frames(1)

func test_forest_road_passages_do_not_render_as_dirt_paths() -> void:
	var palette := load("res://game/modes/zombie/biomes/infected_plains_palette.tres") as BiomePalette
	var layout := BiomeEnvironmentLayout.new()
	layout.zone_size = Vector2i(18, 12)
	layout.generation_seed = 443118
	layout.add_floor_rect(Rect2i(Vector2i.ZERO, layout.zone_size), &"forest_grass")
	var passage_rect := Rect2i(Vector2i(0, 5), Vector2i(2, 4))
	var connector_rect := Rect2i(Vector2i(0, 5), Vector2i(9, 4))
	layout.passage_rects.append(passage_rect)
	layout.passage_connector_rects.append(connector_rect)
	layout.road_rects.append(passage_rect)
	layout.road_rect_tags.append(&"road")
	layout.road_rects.append(connector_rect)
	layout.road_rect_tags.append(&"road")
	layout.rebuild_terrain_classification()
	var layer := BiomeTileLayer.new()
	add_child(layer)
	layer.configure(layout, palette, &"infected_plains", &"quality", 9, null, _manifest, false)
	await wait_physics_frames(1)

	var connector_probe := Vector2i(4, 6)
	var connector_tile := layer.get_resolved_tile_id(connector_probe)
	assert_eq(connector_tile, &"road", "forest road connector keeps the passage tile id")
	assert_eq(
		layer.get_resolved_tile_section(connector_probe),
		&"passage_tiles",
		"forest road connector remains debuggable as a passage tile"
	)
	assert_eq(
		layer._surface_texture_id_for_cell(connector_probe, connector_tile),
		&"forest_road_border__core_horizontal",
		"forest road connector interior renders with the derived core road material"
	)
	var connector_edge_probe := Vector2i(4, 5)
	assert_eq(
		layer._surface_texture_id_for_cell(
			connector_edge_probe,
			layer.get_resolved_tile_id(connector_edge_probe)
		),
		&"forest_road_border__horizontal",
		"forest road connector edge renders with the oriented defined road-border material"
	)
	var rendered_ids := layer.get_rendered_surface_material_ids()
	assert_true(
		rendered_ids.has(&"forest_road_border__horizontal"),
		"forest road passage renders the defined road-border material"
	)
	assert_true(
		rendered_ids.has(&"forest_road_border__core_horizontal"),
		"forest road passage renders the derived core road material"
	)
	assert_false(
		rendered_ids.has(&"forest_path"),
		"forest road passage no longer renders as a dirt path"
	)
	assert_false(
		rendered_ids.has(&"forest_road"),
		"forest road passage no longer mixes in the old asphalt texture"
	)

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
const GENERATED_BIOME_ROUTE_TAGS: Dictionary = {
	&"toxic_wastes": &"service_lane",
	&"burning_fields": &"ash_lane",
	&"frozen_outskirts": &"packed_snow_path",
	&"drowned_marsh": &"wooden_walkway",
}
const FROZEN_SNOW_REFERENCE := Color(0.82, 0.90, 0.97, 1.0)

func test_generated_biome_catalog_contract() -> void:
	var failures := BiomeGeneratedArtCatalog.validate_catalog()
	assert_true(
		failures.is_empty(),
		"generated biome catalog is complete: %s" % "; ".join(failures)
	)
	assert_eq(
		BiomeGeneratedArtCatalog.get_total_asset_count(),
		195,
		"all generated PNG files are catalogued"
	)
	assert_eq(
		BiomeGeneratedArtCatalog.get_active_asset_count(),
		133,
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
	var toxic_road_path := BiomeGeneratedArtCatalog.select_surface_asset_path(
		&"toxic_wastes",
		BiomeGeneratedArtCatalog.ROLE_ROAD,
		13001,
		Vector2i.ZERO
	)
	assert_true(
		toxic_road_path.contains("road_border_defined"),
		"toxic_wastes road role selects the defined-border road asset"
	)
	assert_eq(
		BiomeGeneratedArtCatalog.road_border_source_orientation(toxic_road_path),
		BiomeGeneratedArtCatalog.ROAD_BORDER_ORIENTATION_HORIZONTAL,
		"urban_ruins defined road-border source is horizontal"
	)
	var volcanic_road_path := BiomeGeneratedArtCatalog.select_surface_asset_path(
		&"burning_fields",
		BiomeGeneratedArtCatalog.ROLE_ROAD,
		13001,
		Vector2i.ZERO
	)
	assert_eq(
		BiomeGeneratedArtCatalog.road_border_source_orientation(volcanic_road_path),
		BiomeGeneratedArtCatalog.ROAD_BORDER_ORIENTATION_VERTICAL,
		"non-toxic defined road-border sources stay vertical"
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
			ground_path.contains("base_ground_variation_02")
			or ground_path.contains("base_ground_variation_03")
			or ground_path.contains("base_ground_variation_04"),
			"frozen ground keeps dirty snow and ice sheets out of the base surface"
		)
		assert_true(
			ground_path.contains("base_ground_variation_01"),
			"frozen ground uses the clean snow material as its full-surface base"
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
			Vector2i(113, 129)
		)
		assert_eq(
			adjacent,
			first,
			"frozen %s keeps the same material across the region"
			% String(role)
		)
	assert_eq(
		BiomeGeneratedArtCatalog.resolve_runtime_surface_role(
			biome_id,
			BiomeGeneratedArtCatalog.ROLE_GROUND_TO_PATH
		),
		BiomeGeneratedArtCatalog.ROLE_PATH,
		"frozen ground/path transitions render with the path surface"
	)
	assert_eq(
		BiomeGeneratedArtCatalog.resolve_runtime_surface_role(
			biome_id,
			BiomeGeneratedArtCatalog.ROLE_GROUND_TO_ROAD
		),
		BiomeGeneratedArtCatalog.ROLE_GROUND_TO_ROAD,
		"frozen ground/road transitions render with the defined road-border surface"
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
			Vector2i(121, 137)
		)
		assert_eq(
			adjacent,
			first,
			"swamp %s keeps the same material across the region"
			% String(role)
		)
	assert_eq(
		BiomeGeneratedArtCatalog.resolve_runtime_surface_role(
			biome_id,
			BiomeGeneratedArtCatalog.ROLE_GROUND_TO_PATH
		),
		BiomeGeneratedArtCatalog.ROLE_PATH,
		"swamp ground/path transitions render with the path surface"
	)
	assert_eq(
		BiomeGeneratedArtCatalog.resolve_runtime_surface_role(
			biome_id,
			BiomeGeneratedArtCatalog.ROLE_GROUND_TO_ROAD
		),
		BiomeGeneratedArtCatalog.ROLE_GROUND_TO_ROAD,
		"swamp ground/road transitions render with the defined road-border surface"
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
		assert_false(
			ground_path.contains("base_ground_variation_01")
			or ground_path.contains("base_ground_variation_04"),
			"toxic ground keeps lichen sheet and brown gravel out of the base surface"
		)
		assert_true(
			ground_path.contains("base_ground_variation_02")
			or ground_path.contains("base_ground_variation_03"),
			"toxic ground uses the coherent grey rubble pair as its base surface"
		)
		assert_eq(
			ground_path,
			BiomeGeneratedArtCatalog.select_surface_asset_path(
				biome_id,
				BiomeGeneratedArtCatalog.ROLE_GROUND,
				87031 + sample,
				Vector2i(sample * 5 + 97, sample * 7 + 131)
			),
			"toxic ground keeps one material across the region"
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
			Vector2i(69, 77)
		)
		assert_eq(
			adjacent,
			first,
			"toxic %s keeps the same material across the region"
			% String(role)
		)
	assert_eq(
		BiomeGeneratedArtCatalog.resolve_runtime_surface_role(
			biome_id,
			BiomeGeneratedArtCatalog.ROLE_GROUND_TO_PATH
		),
		BiomeGeneratedArtCatalog.ROLE_PATH,
		"toxic ground/path transitions render with the path surface"
	)
	assert_eq(
		BiomeGeneratedArtCatalog.resolve_runtime_surface_role(
			biome_id,
			BiomeGeneratedArtCatalog.ROLE_GROUND_TO_ROAD
		),
		BiomeGeneratedArtCatalog.ROLE_GROUND_TO_ROAD,
		"toxic ground/road transitions render with the defined road-border surface"
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
			ground_path.contains("base_ground_variation_01")
			or ground_path.contains("base_ground_variation_03")
			or ground_path.contains("base_ground_variation_04"),
			"burning ground keeps bright cracks and lava features out of the base surface"
		)
		assert_true(
			ground_path.contains("base_ground_variation_02"),
			"burning ground uses the quiet ember material as its full-surface base"
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
			Vector2i(137, 153)
		)
		assert_eq(
			adjacent,
			first,
			"burning %s keeps the same material across the region"
			% String(role)
		)
	assert_eq(
		BiomeGeneratedArtCatalog.resolve_runtime_surface_role(
			biome_id,
			BiomeGeneratedArtCatalog.ROLE_GROUND_TO_PATH
		),
		BiomeGeneratedArtCatalog.ROLE_PATH,
		"burning ground/path transitions render with the path surface"
	)
	assert_eq(
		BiomeGeneratedArtCatalog.resolve_runtime_surface_role(
			biome_id,
			BiomeGeneratedArtCatalog.ROLE_GROUND_TO_ROAD
		),
		BiomeGeneratedArtCatalog.ROLE_GROUND_TO_ROAD,
		"burning ground/road transitions render with the defined road-border surface"
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
	assert_eq(expected_paths.size(), 133, "active themes expose 133 unique PNGs")
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
			Rect2i(Vector2i(20, 4), Vector2i(3, 8))
		)
		layout.road_rect_tags.append(&"main_road")
		layout.road_rects.append(
			Rect2i(Vector2i(10, 2), Vector2i(3, 20))
		)
		layout.road_rect_tags.append(&"broken_street")
		layout.road_rects.append(
			Rect2i(Vector2i(2, 16), Vector2i(10, 3))
		)
		layout.road_rect_tags.append(
			GENERATED_BIOME_ROUTE_TAGS[biome_id] as StringName
		)
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
		var loaded_surface_ids := layer.get_loaded_surface_texture_ids()
		assert_gte(
			layer.get_loaded_surface_texture_ids().size(),
			BiomeGeneratedArtCatalog.get_all_surface_asset_paths(biome_id).size(),
			"%s exposes every generated material plus manifest tile surfaces"
			% String(biome_id)
		)
		var route_tag := GENERATED_BIOME_ROUTE_TAGS[biome_id] as StringName
		var passage_tag := GENERATED_BIOME_PASSAGE_TAGS[biome_id] as StringName
		var route_texture_id := _manifest_surface_texture_id(&"terrain_tiles", route_tag)
		var passage_texture_id := _manifest_surface_texture_id(&"passage_tiles", passage_tag)
		assert_true(
			loaded_surface_ids.has(route_texture_id),
			"%s loads terrain tile texture %s"
			% [String(biome_id), String(route_texture_id)]
		)
		assert_true(
			loaded_surface_ids.has(passage_texture_id),
			"%s loads passage tile texture %s"
			% [String(biome_id), String(passage_texture_id)]
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
		var expected_theme_fragment := (
			"/%s/" % String(GENERATED_BIOME_THEMES[biome_id])
		)
		var first_rendered_id := &""
		for rendered_id in layer.get_rendered_surface_material_ids():
			var rendered_path := String(
				layer.get_forest_surface_art_asset_paths().get(rendered_id, "")
			)
			if rendered_path.contains(expected_theme_fragment):
				first_rendered_id = rendered_id
				break
		assert_false(
			first_rendered_id.is_empty(),
			"%s renders at least one generated PNG material" % String(biome_id)
		)
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
		var first_rendered_text := String(first_rendered_id)
		var expected_runtime_width := (
			(
				source_image.get_height()
				if first_rendered_text.ends_with("__horizontal")
				else source_image.get_width()
			)
			- expected_surface_trim * 2
		)
		if (
			biome_id == &"toxic_wastes"
			and (
				source_path.contains("base_ground_variation")
				or source_path.contains("path_variation")
				or source_path.contains("road_variation")
				or source_path.contains("road_border_defined")
			)
		):
			expected_runtime_width *= 2
		if (
			(
				biome_id == &"frozen_outskirts"
				or biome_id == &"drowned_marsh"
			)
			and source_path.contains("base_ground_variation_01")
		):
			expected_runtime_width *= 2
		assert_eq(
			runtime_texture.get_width(),
			expected_runtime_width,
			"%s normalizes the generated surface dimensions at runtime"
			% String(biome_id)
		)
		if biome_id == &"burning_fields":
			var runtime_image := runtime_texture.get_image()
			assert_lte(
				_edge_seam_score(runtime_image),
				0.04,
				"burning_fields runtime surface harmonizes opposite edges"
			)
			assert_eq(
				layer._forest_surface_texture_world_size(first_rendered_id),
				BiomeTileLayer.BURNING_SURFACE_TEXTURE_WORLD_SIZE,
				"burning_fields uses a broad repeat period"
			)
		if biome_id == &"drowned_marsh":
			_assert_marsh_routes_are_lifted(layer, expected_surface_trim)
		if biome_id == &"burning_fields":
			_assert_volcanic_embers_are_damped(layer, expected_surface_trim)
		if biome_id == &"toxic_wastes":
			var toxic_runtime_image := runtime_texture.get_image()
			assert_lte(
				_edge_seam_score(toxic_runtime_image),
				0.04,
				"toxic_wastes runtime surface harmonizes opposite edges"
			)
			assert_eq(
				layer._forest_surface_texture_world_size(first_rendered_id),
				BiomeTileLayer.TOXIC_SURFACE_TEXTURE_WORLD_SIZE,
				"toxic_wastes uses a broad repeat period"
			)
		if biome_id == &"frozen_outskirts":
			var frozen_ground_id := _find_surface_material_id(
				layer,
				"base_ground_variation_01"
			)
			assert_false(
				frozen_ground_id.is_empty(),
				"frozen_outskirts exposes its clean snow ground material"
			)
			var frozen_ground_texture := (
				layer._forest_surface_textures.get(frozen_ground_id)
				as Texture2D
			)
			assert_not_null(
				frozen_ground_texture,
				"frozen_outskirts builds its macro ground texture"
			)
			var frozen_runtime_image := frozen_ground_texture.get_image()
			assert_lte(
				_edge_seam_score(frozen_runtime_image),
				0.04,
				"frozen_outskirts runtime surface has continuous repeat edges"
			)
			assert_lte(
				_internal_half_seam_score(frozen_runtime_image),
				0.04,
				"frozen ground macro has no visible internal quilt seam"
			)
			assert_gt(
				_half_period_rgb_difference_score(frozen_runtime_image),
				0.015,
				"frozen ground macro period does not duplicate the same half"
			)
			assert_eq(
				layer._forest_surface_texture_world_size(frozen_ground_id),
				BiomeTileLayer.FROZEN_GROUND_TEXTURE_WORLD_SIZE,
				"frozen ground uses a double-width non-mirrored macro period"
			)
			var frozen_path_id := _find_surface_material_id(
				layer,
				"path_variation"
			)
			assert_false(
				frozen_path_id.is_empty(),
				"frozen_outskirts exposes a path material"
			)
			assert_eq(
				layer._forest_surface_texture_world_size(frozen_path_id),
				BiomeTileLayer.FROZEN_SURFACE_TEXTURE_WORLD_SIZE,
				"frozen route keeps native material density"
			)
			_assert_frozen_ground_is_toned_down(layer, expected_surface_trim)
			_assert_frozen_route_textures_are_snow_softened(
				layer,
				"path_variation",
				expected_surface_trim,
				"frozen path"
			)
			_assert_frozen_route_textures_are_snow_softened(
				layer,
				"road_border_defined",
				expected_surface_trim,
				"frozen road"
			)
		if biome_id == &"drowned_marsh":
			var marsh_ground_id := _find_surface_material_id(
				layer,
				"base_ground_variation_01"
			)
			assert_false(
				marsh_ground_id.is_empty(),
				"drowned_marsh exposes its quiet ground material"
			)
			var marsh_ground_texture := (
				layer._forest_surface_textures.get(marsh_ground_id)
				as Texture2D
			)
			assert_not_null(
				marsh_ground_texture,
				"drowned_marsh builds its macro ground texture"
			)
			var marsh_runtime_image := marsh_ground_texture.get_image()
			assert_lte(
				_edge_seam_score(marsh_runtime_image),
				0.04,
				"drowned_marsh runtime surface has continuous repeat edges"
			)
			assert_lte(
				_internal_half_seam_score(marsh_runtime_image),
				0.04,
				"drowned marsh ground macro has no visible internal quilt seam"
			)
			assert_gt(
				_half_period_rgb_difference_score(marsh_runtime_image),
				0.015,
				"drowned marsh ground macro period does not duplicate the same half"
			)
			assert_eq(
				layer._forest_surface_texture_world_size(marsh_ground_id),
				BiomeTileLayer.MARSH_GROUND_TEXTURE_WORLD_SIZE,
				"drowned marsh ground uses a double-width non-mirrored macro period"
			)
			var marsh_path_id := _find_surface_material_id(
				layer,
				"path_variation"
			)
			assert_false(
				marsh_path_id.is_empty(),
				"drowned_marsh exposes a path material"
			)
			assert_eq(
				layer._forest_surface_texture_world_size(marsh_path_id),
				BiomeTileLayer.MARSH_SURFACE_TEXTURE_WORLD_SIZE,
				"drowned marsh route keeps native material density"
			)
		var selected_material_ids: Dictionary = {}
		var selected_material_paths: Dictionary = {}
		var road_border_material_seen := false
		var horizontal_border_cell := Vector2i(6, 10)
		var vertical_border_cell := Vector2i(10, 5)
		var horizontal_border_id := layer.get_resolved_material_asset_id(
			horizontal_border_cell
		)
		var vertical_border_id := layer.get_resolved_material_asset_id(
			vertical_border_cell
		)
		for y in range(layout.zone_size.y):
			for x in range(layout.zone_size.x):
				var cell := Vector2i(x, y)
				var selected_id := layer.get_resolved_material_asset_id(cell)
				if not selected_id.is_empty():
					selected_material_ids[selected_id] = true
					var selected_path := layer.get_resolved_material_asset_path(cell)
					selected_material_paths[selected_path] = true
					if (
						ROAD_BORDER_TILE_IDS.has(layer.get_resolved_tile_id(cell))
						and selected_path.contains("road_border_defined")
					):
						road_border_material_seen = true
		for selected_path in selected_material_paths:
			assert_true(
				String(selected_path).contains(expected_theme_fragment),
				"%s resolver never falls back outside its generated theme: %s"
				% [String(biome_id), String(selected_path)]
			)
		assert_true(
			road_border_material_seen,
			"%s maps road edge/curve cells to defined road-border material"
			% String(biome_id)
		)
		assert_eq(
			layer.get_resolved_tile_id(horizontal_border_cell),
			IsometricTileResolver.TILE_ROAD_EDGE,
			"%s horizontal route border resolves as a road edge"
			% String(biome_id)
		)
		assert_true(
			String(horizontal_border_id).ends_with("__horizontal"),
			"%s horizontal route border selects the rotated road-border material"
			% String(biome_id)
		)
		assert_true(
			layer.get_resolved_material_asset_path(
				horizontal_border_cell
			).contains("road_border_defined"),
			"%s horizontal route border uses the defined road-border source"
			% String(biome_id)
		)
		assert_eq(
			layer.get_resolved_tile_id(vertical_border_cell),
			IsometricTileResolver.TILE_ROAD_EDGE,
			"%s vertical route border resolves as a road edge"
			% String(biome_id)
		)
		assert_true(
			String(vertical_border_id).ends_with("__vertical"),
			"%s vertical route border selects the native road-border material"
			% String(biome_id)
		)
		assert_true(
			layer.get_resolved_material_asset_path(
				vertical_border_cell
			).contains("road_border_defined"),
			"%s vertical route border uses the defined road-border source"
			% String(biome_id)
		)
		assert_true(
			loaded_surface_ids.has(horizontal_border_id),
			"%s loads the horizontal road-border texture variant"
			% String(biome_id)
		)
		assert_true(
			loaded_surface_ids.has(vertical_border_id),
			"%s loads the vertical road-border texture variant"
			% String(biome_id)
		)
		if biome_id == &"toxic_wastes":
			var toxic_border_base_id := (
				BiomeGeneratedArtCatalog.material_id_from_path(
					layer.get_resolved_material_asset_path(horizontal_border_cell)
				)
			)
			assert_true(
				_surface_textures_have_same_pixels(
					layer,
					toxic_border_base_id,
					horizontal_border_id
				),
				"toxic horizontal road border uses the native source texture"
			)
			assert_false(
				_surface_textures_have_same_pixels(
					layer,
					toxic_border_base_id,
					vertical_border_id
				),
				"toxic vertical road border rotates the horizontal source texture"
			)
		assert_true(
			layer.get_resolved_material_asset_path(
				Vector2i(4, 4)
			).contains(expected_theme_fragment),
			"%s hazard underlay uses its generated theme" % String(biome_id)
		)
		var main_road_probe := Vector2i(5, 11)
		var vertical_main_road_probe := Vector2i(21, 6)
		assert_eq(
			layer.get_resolved_tile_id(main_road_probe),
			IsometricTileResolver.TILE_MAIN_ROAD,
			"%s main road keeps its semantic tile id" % String(biome_id)
		)
		assert_true(
			layer.get_resolved_material_asset_path(main_road_probe).contains(
				expected_theme_fragment
			),
			"%s main road uses its generated theme material"
			% String(biome_id)
		)
		assert_true(
			layer.get_resolved_material_asset_path(main_road_probe).contains(
				"road_border_defined"
			),
			"%s main road renders with the defined-border road PNG"
			% String(biome_id)
		)
		assert_true(
			String(layer.get_resolved_material_asset_id(main_road_probe)).ends_with(
				"__horizontal"
			),
			"%s horizontal main road uses the rotated road surface material"
			% String(biome_id)
		)
		assert_eq(
			layer.get_resolved_tile_id(vertical_main_road_probe),
			IsometricTileResolver.TILE_MAIN_ROAD,
			"%s vertical main road keeps its semantic tile id" % String(biome_id)
		)
		assert_true(
			layer.get_resolved_material_asset_path(
				vertical_main_road_probe
			).contains("road_border_defined"),
			"%s vertical main road renders with the defined-border road PNG"
			% String(biome_id)
		)
		assert_true(
			String(
				layer.get_resolved_material_asset_id(vertical_main_road_probe)
			).ends_with("__vertical"),
			"%s vertical main road uses the native road surface material"
			% String(biome_id)
		)
		assert_true(
			loaded_surface_ids.has(
				layer.get_resolved_material_asset_id(main_road_probe)
			),
			"%s loads the horizontal road surface texture variant"
			% String(biome_id)
		)
		assert_true(
			loaded_surface_ids.has(
				layer.get_resolved_material_asset_id(vertical_main_road_probe)
			),
			"%s loads the vertical road surface texture variant"
			% String(biome_id)
		)
		var route_probe := Vector2i(5, 17)
		assert_eq(
			layer.get_resolved_tile_id(route_probe),
			route_tag,
			"%s route keeps its biome tile id" % String(biome_id)
		)
		assert_eq(
			layer.get_resolved_tile_section(route_probe),
			&"terrain_tiles",
			"%s route remains a terrain tile" % String(biome_id)
		)
		assert_true(
			layer.get_resolved_material_asset_path(route_probe).contains(
				expected_theme_fragment
			),
			"%s route uses its generated theme material"
			% String(biome_id)
		)
		assert_true(
			layer.get_resolved_material_asset_path(route_probe).contains(
				"path_variation"
			),
			"%s route renders with the generated path PNG"
			% String(biome_id)
		)
		var passage_probe := Vector2i(19, 3)
		assert_eq(
			layer.get_resolved_tile_id(passage_probe),
			passage_tag,
			"%s passage keeps its biome tile id" % String(biome_id)
		)
		assert_eq(
			layer.get_resolved_tile_section(passage_probe),
			&"passage_tiles",
			"%s passage remains a passage tile" % String(biome_id)
		)
		assert_true(
			layer.get_resolved_material_asset_path(passage_probe).contains(
				expected_theme_fragment
			),
			"%s passage uses its generated theme material"
			% String(biome_id)
		)
		assert_true(
			layer.get_resolved_material_asset_path(passage_probe).contains(
				"road_border_defined"
			),
			"%s passage renders with the defined-border road PNG"
			% String(biome_id)
		)
		var passage_material_id := layer.get_resolved_material_asset_id(passage_probe)
		assert_true(
			String(passage_material_id).ends_with("__horizontal")
			or String(passage_material_id).ends_with("__vertical"),
			"%s passage road material is oriented"
			% String(biome_id)
		)
		assert_true(
			loaded_surface_ids.has(passage_material_id),
			"%s loads the generated passage road texture variant"
			% String(biome_id)
		)
		var rendered_material_ids: Dictionary = {}
		for rendered_id in layer.get_rendered_surface_material_ids():
			rendered_material_ids[rendered_id] = true
		assert_gte(
			rendered_material_ids.size(),
			selected_material_ids.size(),
			"%s builds meshes for selected generated materials and manifest tiles"
			% String(biome_id)
		)
		for selected_id in selected_material_ids:
			assert_true(
				rendered_material_ids.has(selected_id),
				"%s renders selected material %s"
			% [String(biome_id), String(selected_id)]
			)
		assert_true(
			rendered_material_ids.has(horizontal_border_id),
			"%s renders the horizontal road-border material"
			% String(biome_id)
		)
		assert_true(
			rendered_material_ids.has(vertical_border_id),
			"%s renders the vertical road-border material"
			% String(biome_id)
		)
		assert_true(
			rendered_material_ids.has(
				layer.get_resolved_material_asset_id(main_road_probe)
			),
			"%s renders the horizontal generated road material" % String(biome_id)
		)
		assert_true(
			rendered_material_ids.has(
				layer.get_resolved_material_asset_id(vertical_main_road_probe)
			),
			"%s renders the vertical generated road material" % String(biome_id)
		)
		assert_true(
			rendered_material_ids.has(
				layer.get_resolved_material_asset_id(route_probe)
			),
			"%s renders the generated route material" % String(biome_id)
		)
		assert_true(
			rendered_material_ids.has(passage_material_id),
			"%s renders the generated passage road material" % String(biome_id)
		)
		assert_true(
			not rendered_material_ids.has(route_texture_id),
			"%s no longer renders legacy semantic route texture %s"
			% [String(biome_id), String(route_texture_id)]
		)
		assert_true(
			not rendered_material_ids.has(passage_texture_id),
			"%s no longer renders legacy semantic passage texture %s"
			% [String(biome_id), String(passage_texture_id)]
		)
		if biome_id == &"toxic_wastes":
			for rendered_id in rendered_material_ids:
				assert_false(
					String(rendered_id).contains("transition_ground_"),
					"toxic_wastes does not render intermediate transition textures"
				)
		if biome_id == &"frozen_outskirts":
			for rendered_id in rendered_material_ids:
				assert_false(
					String(rendered_id).contains("transition_ground_"),
					"frozen_outskirts does not render intermediate transition textures"
				)
		if biome_id == &"drowned_marsh":
			for rendered_id in rendered_material_ids:
				assert_false(
					String(rendered_id).contains("transition_ground_"),
					"drowned_marsh does not render intermediate transition textures"
				)
		if biome_id == &"burning_fields":
			for rendered_id in rendered_material_ids:
				assert_false(
					String(rendered_id).contains("transition_ground_"),
					"burning_fields does not render intermediate transition textures"
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
		var expected_cliff_downscale := (
			_expected_generated_cliff_texture_downscale(biome_id)
		)
		assert_eq(
			layer._cliff_lip_texture.get_width(),
			_expected_normalized_width(
				cliff_lip_source_image.get_width(),
				expected_cliff_trim,
				expected_cliff_downscale
			),
			"%s trims generated cliff lips before repeat sampling"
			% String(biome_id)
		)
		_assert_generated_cliff_texture_is_normalized(
			layer._cliff_face_texture,
			String(cliff_paths.get(&"cliff_face_texture", "")),
			expected_cliff_trim,
			"%s cliff face" % String(biome_id),
			expected_cliff_downscale
		)
		_assert_generated_cliff_texture_is_normalized(
			layer._cliff_lip_texture,
			String(cliff_paths.get(&"cliff_lip_texture", "")),
			expected_cliff_trim,
			"%s horizontal cliff lip" % String(biome_id),
			expected_cliff_downscale
		)
		_assert_generated_cliff_texture_is_normalized(
			layer._cliff_lip_vertical_texture,
			String(cliff_paths.get(&"cliff_lip_vertical_texture", "")),
			expected_cliff_trim,
			"%s vertical cliff lip" % String(biome_id),
			expected_cliff_downscale
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
		_assert_runtime_texture_width_matches_trim(
			profile.face_texture,
			String(paths.get(&"face", "")),
			_expected_generated_cliff_texture_trim_pixels(biome_id),
			"%s upward cliff face" % String(biome_id)
		)
		_assert_runtime_texture_width_matches_trim(
			profile.top_texture,
			String(paths.get(&"top", "")),
			_expected_generated_surface_texture_trim_pixels(biome_id),
			"%s upward cliff crown" % String(biome_id)
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

func test_flush_pending_surface_matches_single_shot_build() -> void:
	var palette := load("res://game/modes/zombie/biomes/infected_plains_palette.tres") as BiomePalette
	assert_not_null(palette, "infected plains palette loads for cliff mesh QA")
	if palette == null:
		return
	# Simula lo streaming a chunk: 3 batch flushati uno alla volta, come farebbe
	# BiomeTileLayer._build_chunk_for_coord() per 3 chunk successivi.
	var incremental := IsometricCliffMeshBuilder.new()
	incremental.configure(palette, 424242, true)
	var batches := [
		[TRANSITION_IDS[0], TRANSITION_IDS[1]],
		[TRANSITION_IDS[2], TRANSITION_IDS[3], TRANSITION_IDS[4]],
		[TRANSITION_IDS[5]]
	]
	for batch_index in range(batches.size()):
		for tile_id in batches[batch_index]:
			incremental.append_transition(
				tile_id,
				Vector2(float(batch_index) * 200.0, 0.0),
				42.0,
				22.0
			)
		incremental.flush_pending_surface()
	assert_eq(incremental.face_mesh.get_surface_count(), batches.size(),
		"each flushed batch adds exactly one face surface")
	assert_eq(incremental.lip_mesh.get_surface_count(), batches.size(),
		"each flushed batch adds exactly one lip surface")
	var surfaces_before := incremental.face_mesh.get_surface_count()
	incremental.flush_pending_surface()
	assert_eq(incremental.face_mesh.get_surface_count(), surfaces_before,
		"flushing with nothing pending is a no-op")

	var single_shot := IsometricCliffMeshBuilder.new()
	single_shot.configure(palette, 424242, true)
	for batch_index in range(batches.size()):
		for tile_id in batches[batch_index]:
			single_shot.append_transition(
				tile_id,
				Vector2(float(batch_index) * 200.0, 0.0),
				42.0,
				22.0
			)
	single_shot.build_meshes()

	assert_eq(incremental.transition_count, single_shot.transition_count,
		"transition_count is unaffected by flush strategy")
	assert_true(
		_mesh_vertex_multiset_matches(incremental.face_mesh, single_shot.face_mesh),
		"splitting face geometry across surfaces does not change the rendered geometry"
	)
	assert_true(
		_mesh_vertex_multiset_matches(incremental.lip_mesh, single_shot.lip_mesh),
		"splitting lip geometry across surfaces does not change the rendered geometry"
	)

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
	builder.build([Rect2i(Vector2i(0, 0), Vector2i(16, 1))], [&"north"], Vector2i(16, 16), 48.0)
	var perimeter_h := _mesh_bounds(builder.horizontal_mesh)
	var fall_boundary_y := (1.0 - 8.0) * 48.0
	assert_true(
		is_equal_approx(perimeter_h.end.y, fall_boundary_y)
		and perimeter_h.size.y <= 18.0,
		"perimeter cliff rim stays narrow and ends at the fall boundary"
	)

func test_rectilinear_face_meshes() -> void:
	var builder := RectilinearCliffFaceMeshBuilder.new()
	builder.build([Rect2i(Vector2i(4, 5), Vector2i(6, 4))], [&"internal"], Vector2i(16, 16), 8.0)
	assert_eq(builder.face_count, 4, "internal fall rectangle builds four cliff faces")
	assert_true(_mesh_has_uvs(builder.face_mesh), "rectilinear cliff faces expose UVs")
	assert_true(_mesh_is_axis_aligned_quads(builder.face_mesh), "internal cliff faces avoid diagonal lower-corner wedges")
	assert_eq(_mesh_sheared_quad_count(builder.face_mesh), 0, "internal side walls stay rectilinear")
	var bounds := _mesh_bounds(builder.face_mesh)
	assert_true(bounds.position.is_equal_approx(Vector2(-32.0, -24.0)) and bounds.end.is_equal_approx(Vector2(16.0, 8.0)), "rectilinear cliff faces stay inside the fall rectangle")
	builder.build([Rect2i(Vector2i(0, 0), Vector2i(16, 1))], [&"north"], Vector2i(16, 16), 48.0)
	var north_bounds := _mesh_bounds(builder.face_mesh)
	var north_fall_boundary_y := (1.0 - 8.0) * 48.0
	assert_true(
		is_equal_approx(north_bounds.end.y, north_fall_boundary_y)
		and north_bounds.size.y >= 48.0,
		"perimeter north cliff face starts at the fall boundary and keeps readable depth"
	)
	builder.build([Rect2i(Vector2i(0, 15), Vector2i(16, 1))], [&"south"], Vector2i(16, 16), 48.0)
	var south_bounds := _mesh_bounds(builder.face_mesh)
	var south_fall_boundary_y := (15.0 - 8.0) * 48.0
	assert_true(
		is_equal_approx(south_bounds.position.y, south_fall_boundary_y)
		and south_bounds.size.y >= 48.0,
		"perimeter south cliff face starts at the fall boundary and keeps readable depth"
	)

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
	var transition_tile := layer.get_resolved_tile_id(Vector2i(6, 6))
	assert_true(
		layer._uses_rectilinear_void_transition_art(transition_tile),
		"rectilinear cliff renderer owns void transition art"
	)
	assert_gt(
		layer.get_suppressed_void_texture_count(),
		4,
		"rectilinear cliff renderer suppresses enlarged flat transition diamonds"
	)
	layer.queue_free()
	await wait_physics_frames(1)

func test_void_transition_cells_do_not_receive_ground_surface() -> void:
	var resolver := IsometricTileResolver.new(_manifest)
	var layout := BiomeEnvironmentLayout.new()
	layout.zone_size = Vector2i(16, 16)
	layout.generation_seed = 717171
	layout.add_floor_rect(Rect2i(Vector2i.ZERO, layout.zone_size), &"floor_base")
	layout.add_fall_zone_rect(Rect2i(Vector2i(6, 6), Vector2i(2, 2)), &"internal")
	layout.rebuild_terrain_classification()

	var void_cell := Vector2i(6, 6)
	var ground_cell := Vector2i(5, 6)
	var void_data := resolver.resolve_tile_data(
		layout,
		void_cell,
		&"toxic_wastes",
		&"quality"
	)
	var ground_data := resolver.resolve_tile_data(
		layout,
		ground_cell,
		&"toxic_wastes",
		&"quality"
	)
	var void_tile := StringName(void_data.get("tile_id", &""))
	assert_true(
		resolver.is_void_transition_tile_id(void_tile),
		"fall-zone edge cell still resolves to an oriented cliff tile"
	)
	assert_true(
		StringName(void_data.get("material_asset_id", &"")).is_empty(),
		"void transition cell does not inherit generated ground material"
	)
	assert_false(
		StringName(ground_data.get("material_asset_id", &"")).is_empty(),
		"walkable ground touching void still reaches the cliff crest"
	)

	var palette := load("res://game/modes/zombie/biomes/toxic_wastes_palette.tres") as BiomePalette
	var layer := BiomeTileLayer.new()
	add_child(layer)
	layer.configure(layout, palette, &"toxic_wastes", &"quality", 16, resolver, _manifest, false)
	await wait_physics_frames(1)
	assert_true(
		layer._surface_texture_id_for_cell(void_cell, void_tile).is_empty(),
		"tile layer does not bake terrain surface over a void transition"
	)
	assert_eq(
		layer._forest_underlay_key(void_tile),
		&"void",
		"void transition underlay stays void-coloured behind the cliff face"
	)
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
	assert_true(cliff_underlay_key == &"void" and layer._forest_underlay_color(cliff_underlay_key) == layer.get_void_background_color(),
		"forest cliff transition cells keep void colour behind the directional crest")
	assert_true(layer._forest_surface_texture_id(IsometricTileResolver.TILE_VOID_EDGE_WEST).is_empty(),
		"forest cliff transition cells do not bake grass past the cliff edge")
	assert_eq(layer._forest_surface_texture_id(IsometricTileResolver.TILE_GROUND_TO_VOID_CLIFF), &"forest_grass",
		"walkable ground beside void still reaches the cliff crest")
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

func _expected_generated_cliff_texture_trim_pixels(_biome_id: StringName) -> int:
	return 12

func _expected_generated_cliff_texture_downscale(biome_id: StringName) -> float:
	return GeneratedBiomeTextureTools.cliff_texture_downscale(biome_id)

# Rispecchia _normalize_repeating_texture_uncached: crop del trim, poi
# eventuale downscale anti-aliasing (con floor a 8 px).
func _expected_normalized_width(
	source_width: int,
	expected_trim: int,
	expected_downscale: float
) -> int:
	var trimmed := source_width - expected_trim * 2
	if expected_downscale > 0.0 and expected_downscale < 1.0:
		return maxi(roundi(trimmed * expected_downscale), 8)
	return trimmed

func _assert_generated_cliff_texture_is_normalized(
	texture: Texture2D,
	source_path: String,
	expected_trim: int,
	label: String,
	expected_downscale: float = 1.0
) -> void:
	_assert_runtime_texture_width_matches_trim(
		texture,
		source_path,
		expected_trim,
		label,
		expected_downscale
	)
	if texture == null:
		return
	var image := texture.get_image()
	assert_not_null(image, "%s runtime image is available" % label)
	if image == null:
		return
	assert_lte(
		_edge_visible_matte_ratio(image),
		0.04,
		"%s runtime edge has no visible white matte" % label
	)

func _assert_runtime_texture_width_matches_trim(
	texture: Texture2D,
	source_path: String,
	expected_trim: int,
	label: String,
	expected_downscale: float = 1.0
) -> void:
	assert_not_null(texture, "%s runtime texture exists" % label)
	if texture == null:
		return
	var source_image := Image.new()
	var load_error := source_image.load(ProjectSettings.globalize_path(source_path))
	assert_eq(load_error, OK, "%s source image loads" % label)
	if load_error != OK:
		return
	assert_eq(
		texture.get_width(),
		_expected_normalized_width(
			source_image.get_width(),
			expected_trim,
			expected_downscale
		),
		"%s runtime width reflects generated texture trim" % label
	)

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

# Confronta due mesh come insiemi di vertici (vertex+color+uv), ignorando come
# i triangoli sono distribuiti tra le superfici: prova che spezzare la
# geometria su piu' superfici (flush incrementale) non cambia cosa viene
# disegnato rispetto a un'unica build da tutti i dati (build_meshes()).
func _mesh_vertex_multiset_matches(a: ArrayMesh, b: ArrayMesh) -> bool:
	var a_entries := _mesh_vertex_entries(a)
	var b_entries := _mesh_vertex_entries(b)
	if a_entries.size() != b_entries.size():
		return false
	a_entries.sort()
	b_entries.sort()
	return a_entries == b_entries

func _mesh_vertex_entries(mesh: ArrayMesh) -> Array[String]:
	var entries: Array[String] = []
	if mesh == null:
		return entries
	for surface_index in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(surface_index)
		var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector2Array
		var colors := arrays[Mesh.ARRAY_COLOR] as PackedColorArray
		var uvs := arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array
		for index in range(vertices.size()):
			entries.append("%s|%s|%s" % [vertices[index], colors[index], uvs[index]])
	return entries

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

func _half_period_rgb_difference_score(image: Image) -> float:
	if image == null or image.is_empty():
		return 0.0
	var half_width := image.get_width() / 2
	var half_height := image.get_height() / 2
	if half_width <= 0 or half_height <= 0:
		return 0.0
	var step := maxi(mini(half_width, half_height) / 96, 1)
	var total := 0.0
	var samples := 0
	for y in range(0, half_height, step):
		for x in range(0, half_width, step):
			total += _rgb_delta(
				image.get_pixel(x, y),
				image.get_pixel(x + half_width, y)
			)
			total += _rgb_delta(
				image.get_pixel(x, y),
				image.get_pixel(x, y + half_height)
			)
			samples += 2
	return total / float(maxi(samples, 1))

func _internal_half_seam_score(image: Image) -> float:
	if image == null or image.is_empty():
		return 1.0
	var seam_x := image.get_width() / 2
	var seam_y := image.get_height() / 2
	if seam_x <= 0 or seam_y <= 0:
		return 1.0
	var step := maxi(mini(image.get_width(), image.get_height()) / 256, 1)
	var total := 0.0
	var samples := 0
	for y in range(0, image.get_height(), step):
		total += _rgb_delta(
			image.get_pixel(seam_x - 1, y),
			image.get_pixel(seam_x, y)
		)
		samples += 1
	for x in range(0, image.get_width(), step):
		total += _rgb_delta(
			image.get_pixel(x, seam_y - 1),
			image.get_pixel(x, seam_y)
		)
		samples += 1
	return total / float(maxi(samples, 1))

func _rgb_delta(first: Color, second: Color) -> float:
	return (absf(first.r - second.r) + absf(first.g - second.g) + absf(first.b - second.b)) / 3.0

func _edge_visible_matte_ratio(image: Image) -> float:
	if image == null or image.is_empty():
		return 1.0
	var samples := 0
	var matte_samples := 0
	var last_x := image.get_width() - 1
	var last_y := image.get_height() - 1
	for y in range(image.get_height()):
		if _is_visible_white_matte(image.get_pixel(0, y)):
			matte_samples += 1
		if _is_visible_white_matte(image.get_pixel(last_x, y)):
			matte_samples += 1
		samples += 2
	for x in range(image.get_width()):
		if _is_visible_white_matte(image.get_pixel(x, 0)):
			matte_samples += 1
		if _is_visible_white_matte(image.get_pixel(x, last_y)):
			matte_samples += 1
		samples += 2
	return float(matte_samples) / float(maxi(samples, 1))

func _find_surface_material_id(
	layer: BiomeTileLayer,
	asset_fragment: String
) -> StringName:
	var paths := layer.get_forest_surface_art_asset_paths()
	for material_id in layer.get_loaded_surface_texture_ids():
		if String(paths.get(material_id, "")).contains(asset_fragment):
			return material_id
	return &""

func _surface_textures_have_same_pixels(
	layer: BiomeTileLayer,
	first_id: StringName,
	second_id: StringName
) -> bool:
	var first_texture := layer._forest_surface_textures.get(first_id) as Texture2D
	var second_texture := layer._forest_surface_textures.get(second_id) as Texture2D
	if first_texture == null or second_texture == null:
		return false
	var first_image := first_texture.get_image()
	var second_image := second_texture.get_image()
	if (
		first_image == null
		or second_image == null
		or first_image.is_empty()
		or second_image.is_empty()
	):
		return false
	if first_image.get_size() != second_image.get_size():
		return false
	return first_image.get_data() == second_image.get_data()

func _manifest_surface_texture_id(section: StringName, tile_id: StringName) -> StringName:
	return StringName("%s/%s" % [String(section), String(tile_id)])

func _is_visible_white_matte(color: Color) -> bool:
	var minimum := minf(color.r, minf(color.g, color.b))
	var maximum := maxf(color.r, maxf(color.g, color.b))
	return (
		color.a >= 0.98
		and minimum >= 0.86
		and maximum - minimum <= 0.08
	)

# Il ground vulcanico deve uscire dal runtime con le braci smorzate rispetto
# alla sorgente (damping selettivo ART-VIS-FIX): il rumore arancio non deve
# competere con telegraph e fire hazard.
func _assert_volcanic_embers_are_damped(
	layer: BiomeTileLayer,
	expected_trim: int
) -> void:
	var matched := 0
	var paths := layer.get_forest_surface_art_asset_paths()
	for material_id in layer.get_loaded_surface_texture_ids():
		var source_path := String(paths.get(material_id, ""))
		if not source_path.contains("base_ground_variation"):
			continue
		matched += 1
		var runtime_texture := (
			layer._forest_surface_textures.get(material_id) as Texture2D
		)
		assert_not_null(runtime_texture, "volcanic ground runtime texture exists")
		if runtime_texture == null:
			continue
		var source_image := Image.new()
		if source_image.load(ProjectSettings.globalize_path(source_path)) != OK:
			continue
		var trimmed_source := _trimmed_image_copy(source_image, expected_trim)
		assert_lt(
			_average_ember_intensity(runtime_texture.get_image()),
			_average_ember_intensity(trimmed_source) * 0.92,
			"volcanic ground embers are damped against telegraph competition"
		)
	assert_gt(matched, 0, "volcanic ground has generated textures to validate")

# Media dell'intensita' brace sui soli pixel sopra la soglia di damping: il
# fix agisce sulla coda calda, quindi la media su tutti i pixel non e' un
# segnale utile (i pixel freddi dominano e restano intatti).
func _average_ember_intensity(image: Image) -> float:
	if image == null or image.is_empty():
		return 1.0
	var samples := 0
	var total := 0.0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var color := image.get_pixel(x, y)
			if color.a <= 0.01:
				continue
			var ember := maxf(color.r - (color.g + color.b) * 0.5, 0.0)
			if ember <= GeneratedBiomeTextureTools.VOLCANIC_EMBER_THRESHOLD:
				continue
			total += ember
			samples += 1
	if samples <= 0:
		return 0.0
	return total / float(samples)

# Le route della palude devono uscire dal runtime piu' chiare della sorgente
# (lift caldo ART-VIS-FIX): fango, strada e acqua vivevano tutti nella stessa
# banda di luminanza e la strada non si separava dal terreno.
func _assert_marsh_routes_are_lifted(
	layer: BiomeTileLayer,
	expected_trim: int
) -> void:
	var matched := 0
	var paths := layer.get_forest_surface_art_asset_paths()
	for material_id in layer.get_loaded_surface_texture_ids():
		var source_path := String(paths.get(material_id, ""))
		if (
			not source_path.contains("path_variation")
			and not source_path.contains("road_variation")
			and not source_path.contains("road_border_defined")
		):
			continue
		matched += 1
		var runtime_texture := (
			layer._forest_surface_textures.get(material_id) as Texture2D
		)
		assert_not_null(runtime_texture, "marsh route runtime texture exists")
		if runtime_texture == null:
			continue
		var source_image := Image.new()
		if source_image.load(ProjectSettings.globalize_path(source_path)) != OK:
			continue
		var trimmed_source := _trimmed_image_copy(source_image, expected_trim)
		assert_gt(
			_average_visible_luminance(runtime_texture.get_image()),
			_average_visible_luminance(trimmed_source) * 1.05,
			"marsh route is lifted above the mud value range"
		)
	assert_gt(matched, 0, "marsh has generated route textures to validate")

# Il manto nevoso base deve uscire dal runtime piu' scuro della sorgente
# (tinta anti-sovraesposizione ART-VIS-FIX): attori, crate e route chiare
# devono restare separabili sulla neve.
func _assert_frozen_ground_is_toned_down(
	layer: BiomeTileLayer,
	expected_trim: int
) -> void:
	var matched := 0
	var paths := layer.get_forest_surface_art_asset_paths()
	for material_id in layer.get_loaded_surface_texture_ids():
		var source_path := String(paths.get(material_id, ""))
		if not source_path.contains("base_ground_variation"):
			continue
		matched += 1
		var runtime_texture := (
			layer._forest_surface_textures.get(material_id) as Texture2D
		)
		assert_not_null(runtime_texture, "frozen ground runtime texture exists")
		if runtime_texture == null:
			continue
		var source_image := Image.new()
		if source_image.load(ProjectSettings.globalize_path(source_path)) != OK:
			continue
		var trimmed_source := _trimmed_image_copy(source_image, expected_trim)
		var source_luminance := _average_visible_luminance(trimmed_source)
		var runtime_luminance := _average_visible_luminance(
			runtime_texture.get_image()
		)
		assert_lt(
			runtime_luminance,
			source_luminance * 0.97,
			"frozen ground is toned down against overexposure"
		)
	assert_gt(matched, 0, "frozen ground has generated textures to validate")

func _average_visible_luminance(image: Image) -> float:
	if image == null or image.is_empty():
		return 1.0
	var samples := 0
	var total := 0.0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var color := image.get_pixel(x, y)
			if color.a <= 0.01:
				continue
			total += color.get_luminance()
			samples += 1
	if samples <= 0:
		return 1.0
	return total / float(samples)

func _assert_frozen_route_textures_are_snow_softened(
	layer: BiomeTileLayer,
	asset_fragment: String,
	expected_trim: int,
	label: String
) -> void:
	var matched := 0
	var paths := layer.get_forest_surface_art_asset_paths()
	for material_id in layer.get_loaded_surface_texture_ids():
		var source_path := String(paths.get(material_id, ""))
		if not source_path.contains(asset_fragment):
			continue
		matched += 1
		var runtime_texture := (
			layer._forest_surface_textures.get(material_id) as Texture2D
		)
		assert_not_null(runtime_texture, "%s runtime texture exists" % label)
		if runtime_texture == null:
			continue
		var runtime_image := runtime_texture.get_image()
		var source_image := Image.new()
		var load_error := source_image.load(
			ProjectSettings.globalize_path(source_path)
		)
		assert_eq(load_error, OK, "%s source image loads" % label)
		if load_error != OK:
			continue
		var trimmed_source := _trimmed_image_copy(source_image, expected_trim)
		var source_delta := _average_visible_rgb_delta_to_color(
			trimmed_source,
			FROZEN_SNOW_REFERENCE
		)
		var runtime_delta := _average_visible_rgb_delta_to_color(
			runtime_image,
			FROZEN_SNOW_REFERENCE
		)
		assert_lte(
			runtime_delta,
			source_delta * 0.92,
			"%s texture is softened toward the snow palette" % label
		)
	assert_gt(matched, 0, "%s has generated route textures to validate" % label)

func _trimmed_image_copy(image: Image, trim: int) -> Image:
	if image == null or image.is_empty():
		return Image.new()
	var safe_trim := maxi(trim, 0)
	var source_rect := Rect2i(Vector2i.ZERO, image.get_size())
	if (
		safe_trim > 0
		and image.get_width() > safe_trim * 2
		and image.get_height() > safe_trim * 2
	):
		source_rect = Rect2i(
			Vector2i(safe_trim, safe_trim),
			Vector2i(
				image.get_width() - safe_trim * 2,
				image.get_height() - safe_trim * 2
			)
		)
	return image.get_region(source_rect)

func _average_visible_rgb_delta_to_color(image: Image, target: Color) -> float:
	if image == null or image.is_empty():
		return 1.0
	var samples := 0
	var total := 0.0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var color := image.get_pixel(x, y)
			if color.a <= 0.01:
				continue
			total += _rgb_delta(color, target)
			samples += 1
	if samples <= 0:
		return 1.0
	return total / float(samples)
