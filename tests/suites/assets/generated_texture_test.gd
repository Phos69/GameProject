extends GutTest
## Assets A4 — Texture generate (forest surfaces, cliff/void) e loro consumo.
##
## Migra e accorpa:
##   tests/forest_grass_generated_texture_smoke_test.gd
##   tests/void_cliff_generated_texture_smoke_test.gd

const FALL_ZONE_BOUNDARY_RUNS_SCRIPT = preload(
	"res://game/modes/zombie/cliffs/fall_zone_boundary_runs.gd"
)
const TERRAIN_SURFACE_CLASSIFIER = preload(
	"res://game/modes/zombie/terrain/terrain_surface_classifier.gd"
)
const TERRAIN_BOUNDARY_MASK_BUILDER = preload(
	"res://game/modes/zombie/terrain/terrain_boundary_mask_builder.gd"
)
##   tests/forest_top_down_texture_transition_smoke_test.gd
##
## Verifica i contratti delle texture generate (esistenza/provenienza/tileability
## di bordo, non qualità artistica), le mesh di cliff/bordo e il consumo runtime
## via BiomeTileLayer. La risoluzione su mappa generata usa una build 3x3 dedicata.

const REQUIRED_FOREST_TERRAIN_ASSET_IDS: Array[StringName] = [
	&"forest_grass",
	&"forest_path",
	&"forest_road",
	&"terrain_divider_dirt",
]
const EDGE_ID := &"cliff_lip_texture"
const CLIFF_TEXTURE_IDS: Array[StringName] = [
	&"cliff_face_texture", &"cliff_lip_texture", &"cliff_lip_vertical_texture"
]
const TRANSITION_IDS: Array[StringName] = [
	BiomeTileResolver.TILE_VOID_EDGE_NORTH, BiomeTileResolver.TILE_VOID_EDGE_EAST,
	BiomeTileResolver.TILE_VOID_EDGE_SOUTH, BiomeTileResolver.TILE_VOID_EDGE_WEST,
	BiomeTileResolver.TILE_VOID_CORNER_INNER_NORTH_EAST, BiomeTileResolver.TILE_VOID_CORNER_INNER_SOUTH_EAST,
	BiomeTileResolver.TILE_VOID_CORNER_INNER_SOUTH_WEST, BiomeTileResolver.TILE_VOID_CORNER_INNER_NORTH_WEST,
	BiomeTileResolver.TILE_VOID_CORNER_OUTER_NORTH_EAST, BiomeTileResolver.TILE_VOID_CORNER_OUTER_SOUTH_EAST,
	BiomeTileResolver.TILE_VOID_CORNER_OUTER_SOUTH_WEST, BiomeTileResolver.TILE_VOID_CORNER_OUTER_NORTH_WEST,
	BiomeTileResolver.TILE_VOID_DIAGONAL_NORTH_EAST_SOUTH_WEST, BiomeTileResolver.TILE_VOID_DIAGONAL_NORTH_WEST_SOUTH_EAST
]
const REQUIRED_FOREST_TILE_IDS: Array[StringName] = [
	&"forest_grass", &"forest_grass_variant_01", &"forest_grass_variant_02", &"forest_tall_grass",
	&"forest_path", &"forest_road", &"forest_void", &"forest_cliff_edge", &"forest_mountain_wall",
	&"grass_to_path", &"grass_to_road", &"grass_to_tall_grass", &"path_to_road",
	&"ground_to_void_cliff", &"ground_to_mountain_wall"
]

var _manifest: EnvironmentAssetManifest

func before_all() -> void:
	_manifest = EnvironmentAssetManifest.reload_shared()

func test_biome_wall_transition_texture_follows_boundary_axis() -> void:
	GeneratedBiomeTextureTools.clear_cache()
	var warm := _solid_texture(Color(0.9, 0.1, 0.05, 1.0))
	var cold := _solid_texture(Color(0.05, 0.2, 0.9, 1.0))
	var east := GeneratedBiomeTextureTools.blend_biome_wall_transition_texture(
		warm, cold, &"east", "test-east"
	)
	var west := GeneratedBiomeTextureTools.blend_biome_wall_transition_texture(
		warm, cold, &"west", "test-west"
	)
	assert_not_null(east, "east-facing shared wall creates a transition texture")
	assert_not_null(west, "west-facing shared wall creates a transition texture")
	if east == null or west == null:
		return
	var east_image := east.get_image()
	var west_image := west.get_image()
	assert_gt(
		east_image.get_pixel(0, 4).r,
		east_image.get_pixel(7, 4).r,
		"east transition starts with the source mountain"
	)
	assert_gt(
		east_image.get_pixel(7, 4).b,
		east_image.get_pixel(0, 4).b,
		"east transition ends with the neighboring mountain"
	)
	assert_gt(
		west_image.get_pixel(0, 4).b,
		west_image.get_pixel(7, 4).b,
		"west transition reverses the cross-wall gradient"
	)

# --- forest surface textures (forest_grass_generated_texture) ---------------

func test_forest_surface_textures() -> void:
	for asset_id in REQUIRED_FOREST_TERRAIN_ASSET_IDS:
		_validate_generated_asset(_manifest.get_terrain_asset_contract(asset_id), asset_id)
	_validate_generated_asset(_manifest.get_void_asset_contract(EDGE_ID), EDGE_ID)

func test_forest_runtime_consumption() -> void:
	var palette := load("res://game/modes/zombie/biomes/plains_palette.tres") as BiomePalette
	var layout := BiomeEnvironmentLayout.new()
	layout.zone_size = Vector2i(16, 16)
	layout.generation_seed = 862041
	layout.add_floor_rect(Rect2i(Vector2i.ZERO, layout.zone_size), &"forest_grass")
	layout.road_rects.append(Rect2i(Vector2i(1, 2), Vector2i(14, 2)))
	layout.road_rect_tags.append(&"main_road")
	layout.road_rects.append(Rect2i(Vector2i(2, 12), Vector2i(12, 2)))
	layout.road_rect_tags.append(&"broken_street")
	layout.add_fall_zone_rect(Rect2i(Vector2i(6, 6), Vector2i(4, 4)), &"internal")
	layout.rebuild_terrain_classification()
	var terrain_texture_world_origin := Vector2(3600.0, -1800.0)
	var layer := BiomeTileLayer.new()
	add_child(layer)
	layer.configure(
		layout,
		palette,
		&"plains",
		&"quality",
		16,
		null,
		_manifest,
		false,
		true,
		terrain_texture_world_origin
	)
	await wait_physics_frames(1)
	assert_true(layer.has_forest_ground_art_texture(), "forest tile layer loads generated grass")
	assert_true(layer.has_forest_surface_art_textures(), "forest tile layer loads every surface texture")
	assert_true(layer.get_forest_ground_art_asset_path().ends_with("forest_grass_generated.png"), "forest tile layer exposes generated grass path")
	var paths := layer.get_forest_surface_art_asset_paths()
	assert_eq(
		paths.get(BiomeTileLayer.TERRAIN_DIVIDER_TEXTURE_ID),
		paths.get(BiomeTileLayer.FOREST_PATH_TEXTURE_ID),
		"forest dirt dividers reuse the exact path asset"
	)
	assert_true(
		layer._forest_surface_textures.get(
			BiomeTileLayer.TERRAIN_DIVIDER_TEXTURE_ID
		) == layer._forest_surface_textures.get(
			BiomeTileLayer.FOREST_PATH_TEXTURE_ID
		),
		"forest dirt dividers reuse the normalized path texture instance"
	)
	assert_eq(
		layer._cliff_border_mesh_builder.transition_texture_repeat_world_size,
		BiomeTileLayer.FOREST_SURFACE_TEXTURE_WORLD_SIZE,
		"forest cliff dirt uses the same world-space repeat as paths"
	)
	assert_eq(
		layer._mesa_dirt_border_mesh_builder.transition_texture_repeat_world_size,
		BiomeTileLayer.FOREST_SURFACE_TEXTURE_WORLD_SIZE,
		"forest mesa dirt uses the same world-space repeat as paths"
	)
	assert_eq(
		GeneratedBiomeTextureTools.surface_edge_trim_pixels(
			BiomeTileResolver.FOREST_BIOME_ID
		),
		GeneratedBiomeTextureTools.INFECTED_PLAINS_SURFACE_EDGE_TRIM_PIXELS,
		"forest surfaces crop the baked perimeter shadow"
	)
	assert_eq(
		GeneratedBiomeTextureTools.surface_edge_blend_pixels(
			BiomeTileResolver.FOREST_BIOME_ID
		),
		GeneratedBiomeTextureTools.INFECTED_PLAINS_SURFACE_EDGE_BLEND_PIXELS,
		"forest surfaces use the selected narrow edge blend"
	)
	for asset_id in REQUIRED_FOREST_TERRAIN_ASSET_IDS:
		var asset_path := String(paths.get(asset_id, ""))
		assert_true(
			asset_path.begins_with(
				"res://assets/environment/top_down/tiles/forest/textures/"
			)
			and asset_path.ends_with(".png"),
			"forest tile layer exposes %s generated path" % String(asset_id)
		)
	for texture_id in BiomeTileLayer.FOREST_SURFACE_TEXTURE_IDS:
		var runtime_texture := (
			layer._forest_surface_textures.get(texture_id) as Texture2D
		)
		assert_not_null(
			runtime_texture,
			"forest %s runtime surface exists" % String(texture_id)
		)
		if runtime_texture == null:
			continue
		var imported_texture := load(String(paths.get(texture_id, ""))) as Texture2D
		assert_not_null(
			imported_texture,
			"forest %s imported source exists" % String(texture_id)
		)
		if imported_texture != null:
			var forest_trim := (
				GeneratedBiomeTextureTools.INFECTED_PLAINS_SURFACE_EDGE_TRIM_PIXELS
			)
			var expected_texture := (
				GeneratedBiomeTextureTools.normalize_repeating_texture(
					imported_texture,
					forest_trim,
					true,
					GeneratedBiomeTextureTools.INFECTED_PLAINS_SURFACE_EDGE_BLEND_PIXELS
				)
			)
			assert_eq(
				runtime_texture.get_width(),
				imported_texture.get_width() - forest_trim * 2,
				"forest %s crops the full shadow band without an atlas" % String(texture_id)
			)
			assert_lte(
				_image_rgb_difference_score(
					runtime_texture.get_image(),
					expected_texture.get_image()
				),
				0.0001,
				"forest %s repeats the normalized source without transforms"
				% String(texture_id)
			)
			assert_lte(
				absf(_vertical_texture_shadow_score(runtime_texture.get_image())),
				0.015,
				"forest %s has no visible top/bottom shadow band"
				% String(texture_id)
			)
		assert_eq(
			layer._forest_surface_texture_world_size(texture_id),
			BiomeTileLayer.FOREST_SURFACE_TEXTURE_WORLD_SIZE,
			"forest %s repeats the original tile at the historical period" % String(texture_id)
		)
	assert_true(layer.has_cliff_art_textures(), "forest tile layer loads grass-cliff edge")
	assert_gt(layer.get_cliff_transition_count(), 0, "forest void builds textured cliff transitions")
	var chunk := layer._chunk_nodes.get(Vector2i.ZERO) as BiomeTileChunk
	assert_not_null(chunk, "forest runtime builds the terrain chunk")
	var surface_canvas := chunk.terrain_surface_canvas if chunk != null else null
	assert_not_null(surface_canvas, "forest runtime builds the shared-mask canvas")
	if surface_canvas != null:
		assert_eq(
			surface_canvas.surface_material.get_shader_parameter(
				&"texture_world_origin"
			),
			terrain_texture_world_origin + surface_canvas.chunk_world_rect.position,
			"the shader phase combines streamed-region and local chunk origins"
		)
		assert_eq(
			surface_canvas.surface_material.get_shader_parameter(
				&"divider_repeat_world"
			),
			surface_canvas.surface_material.get_shader_parameter(
				&"path_repeat_world"
			),
			"forest divider and path share the same world-space scale"
		)
	_assert_terrain_surface_runtime_contract(layer, layout, "forest")
	layer.queue_free()
	await wait_physics_frames(1)

func test_forest_route_surfaces_feed_boundary_mask() -> void:
	var palette := load("res://game/modes/zombie/biomes/plains_palette.tres") as BiomePalette
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
	layer.configure(layout, palette, &"plains", &"quality", 14, null, _manifest, false)
	await wait_physics_frames(1)

	assert_eq(
		layer.get_terrain_surface_kind(Vector2i(1, 1)),
		TERRAIN_SURFACE_CLASSIFIER.SURFACE_GRASS,
		"forest floor feeds the grass channel"
	)
	assert_eq(
		layer.get_terrain_surface_kind(Vector2i(13, 4)),
		TERRAIN_SURFACE_CLASSIFIER.SURFACE_PATH,
		"forest lane feeds the path channel"
	)
	assert_eq(
		layer.get_terrain_surface_kind(Vector2i(4, 12)),
		TERRAIN_SURFACE_CLASSIFIER.SURFACE_ASPHALT,
		"forest main road feeds the asphalt channel"
	)
	assert_eq(
		layer.get_resolved_material_asset_id(Vector2i(13, 4)),
		&"forest_path",
		"forest lane resolves to the full-bleed path texture"
	)
	assert_eq(
		layer.get_resolved_material_asset_id(Vector2i(4, 12)),
		&"forest_road",
		"forest main road resolves to the full-bleed asphalt texture"
	)
	assert_eq(
		layer.get_resolved_tile_id(Vector2i(13, 12)),
		BiomeTileResolver.TILE_PATH_TO_ROAD,
		"route crossing keeps its semantic tile id"
	)
	_assert_terrain_surface_runtime_contract(layer, layout, "forest routes")

	layer.queue_free()
	await wait_physics_frames(1)

func test_forest_road_passages_use_asphalt_surface() -> void:
	var palette := load("res://game/modes/zombie/biomes/plains_palette.tres") as BiomePalette
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
	layer.configure(layout, palette, &"plains", &"quality", 9, null, _manifest, false)
	await wait_physics_frames(1)

	var connector_probe := Vector2i(4, 6)
	assert_eq(
		layer.get_resolved_tile_id(connector_probe),
		&"road",
		"forest road connector keeps the passage tile id"
	)
	assert_eq(
		layer.get_resolved_tile_section(connector_probe),
		&"passage_tiles",
		"forest road connector remains debuggable as a passage tile"
	)
	assert_eq(
		layer.get_terrain_surface_kind(connector_probe),
		TERRAIN_SURFACE_CLASSIFIER.SURFACE_ASPHALT,
		"forest road connector feeds the asphalt channel"
	)
	assert_eq(
		layer.get_resolved_material_asset_id(connector_probe),
		&"forest_road",
		"forest road connector uses the full-bleed road texture"
	)
	_assert_terrain_surface_runtime_contract(layer, layout, "forest passage")

	layer.queue_free()
	await wait_physics_frames(1)

func test_surface_mesh_overdraw_expands_vertices_without_moving_uvs() -> void:
	var run := Rect2i(Vector2i(1, 2), Vector2i(3, 1))
	var base_mesh := ForestGroundMeshBuilder.build_mesh(
		[run],
		Vector2i(8, 8),
		24.0,
		128.0
	)
	var overdraw_mesh := ForestGroundMeshBuilder.build_mesh(
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

func test_passage_over_lane_spoke_uses_asphalt_surface() -> void:
	var layout := BiomeEnvironmentLayout.new()
	layout.zone_size = Vector2i(12, 12)
	layout.add_floor_rect(Rect2i(Vector2i.ZERO, layout.zone_size), &"open_block")
	var corridor := Rect2i(Vector2i(5, 0), Vector2i(3, 12))
	layout.road_rects.append(corridor)
	layout.road_rect_tags.append(&"broken_gate")
	layout.passage_connector_rects.append(corridor)
	for y in range(corridor.position.y, corridor.end.y):
		for x in range(corridor.position.x, corridor.end.x):
			layout.add_road_cell(Vector2i(x, y), &"service_lane")
	layout.rebuild_terrain_classification()
	var resolver := BiomeTileResolver.new(_manifest)
	var corridor_edge := Vector2i(5, 6)
	assert_false(
		resolver.route_cell_uses_lane_surface(layout, corridor_edge),
		"passage corridor over a lane spoke is not classified as lane surface"
	)
	assert_eq(
		TERRAIN_SURFACE_CLASSIFIER.classify_cell(layout, resolver, corridor_edge),
		TERRAIN_SURFACE_CLASSIFIER.SURFACE_ASPHALT,
		"passage corridor over a lane spoke feeds the asphalt channel"
	)

	var lane_only_layout := BiomeEnvironmentLayout.new()
	lane_only_layout.zone_size = Vector2i(12, 12)
	lane_only_layout.add_floor_rect(
		Rect2i(Vector2i.ZERO, lane_only_layout.zone_size),
		&"open_block"
	)
	for y in range(3, 9):
		lane_only_layout.add_road_cell(Vector2i(6, y), &"service_lane")
	lane_only_layout.rebuild_terrain_classification()
	assert_true(
		resolver.route_cell_uses_lane_surface(lane_only_layout, Vector2i(6, 6)),
		"pure lane spokes keep the path surface"
	)
	assert_eq(
		TERRAIN_SURFACE_CLASSIFIER.classify_cell(
			lane_only_layout,
			resolver,
			Vector2i(6, 6)
		),
		TERRAIN_SURFACE_CLASSIFIER.SURFACE_PATH,
		"pure lane spokes feed the path channel"
	)

const GENERATED_BIOME_THEMES: Dictionary = {
	&"toxic_wastes": &"urban_ruins",
	&"burning_plains": &"burning_plains",
	&"frozen_tundra": &"frozen_tundra",
	&"swamp": &"swamp",
}
const GENERATED_BIOME_ASSET_DIRECTORIES: Dictionary = {
	&"toxic_wastes": &"urban_ruins",
	&"burning_plains": &"volcanic",
	&"frozen_tundra": &"frozen_tundra",
	&"swamp": &"swamp",
}
const GENERATED_BIOME_PASSAGE_TAGS: Dictionary = {
	&"toxic_wastes": &"broken_gate",
	&"burning_plains": &"burned_road",
	&"frozen_tundra": &"snow_pass",
	&"swamp": &"bridge",
}
const GENERATED_BIOME_ROUTE_TAGS: Dictionary = {
	&"toxic_wastes": &"service_lane",
	&"burning_plains": &"ash_lane",
	&"frozen_tundra": &"packed_snow_path",
	&"swamp": &"wooden_walkway",
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
		95,
		"all PNG files for the three generated active variants are catalogued"
	)
	assert_eq(
		BiomeGeneratedArtCatalog.get_unassigned_theme_ids(),
		[&"desert", &"forest", &"urban_ruins"],
		"desert, replacement forest and retired urban art remain unassigned"
	)
	var legacy_swamp_directory := DirAccess.open(
		"res://assets/environment/top_down/tiles/swamp/textures"
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
		toxic_road_path.contains("road_variation"),
		"toxic_wastes road role selects a full-bleed road surface"
	)
	var volcanic_road_path := BiomeGeneratedArtCatalog.select_surface_asset_path(
		&"burning_plains",
		BiomeGeneratedArtCatalog.ROLE_ROAD,
		13001,
		Vector2i.ZERO
	)
	assert_true(
		volcanic_road_path.contains("road_variation"),
		"burning_plains road role selects a full-bleed road surface"
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
	var biome_id := &"frozen_tundra"
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
	var biome_id := &"swamp"
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
	var biome_id := &"burning_plains"
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
		var path_path := BiomeGeneratedArtCatalog.select_surface_asset_path(
			biome_id,
			BiomeGeneratedArtCatalog.ROLE_PATH,
			88013 + sample,
			Vector2i(sample * 5, sample * 7)
		)
		assert_true(
			path_path.contains("path_variation_01"),
			"burning paths use the new dedicated ash-and-dirt surface"
		)
		assert_false(
			path_path.contains("path_variation_02"),
			"burning paths exclude the old dirt surface from the runtime pool"
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
			loaded_surface_ids.size(),
			4,
			"%s loads ground, path, road and the terrain divider"
			% String(biome_id)
		)
		_assert_terrain_surface_runtime_contract(
			layer,
			layout,
			String(biome_id)
		)
		var route_tag := GENERATED_BIOME_ROUTE_TAGS[biome_id] as StringName
		var passage_tag := GENERATED_BIOME_PASSAGE_TAGS[biome_id] as StringName
		assert_gt(
			layer.get_rendered_surface_material_ids().size(),
			0,
			"%s produces a non-empty masked surface canvas" % String(biome_id)
		)
		var expected_theme_fragment := (
			"/%s/" % String(GENERATED_BIOME_ASSET_DIRECTORIES[biome_id])
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
			)
		):
			expected_runtime_width *= 2
		if (
			(
				biome_id == &"frozen_tundra"
				or biome_id == &"swamp"
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
		if biome_id == &"burning_plains":
			var runtime_image := runtime_texture.get_image()
			assert_lte(
				_edge_seam_score(runtime_image),
				0.04,
				"burning_plains runtime surface harmonizes opposite edges"
			)
			assert_eq(
				layer._forest_surface_texture_world_size(first_rendered_id),
				BiomeTileLayer.BURNING_SURFACE_TEXTURE_WORLD_SIZE,
				"burning_plains uses a broad repeat period"
			)
		if (
			biome_id == &"burning_plains"
			or biome_id == &"frozen_tundra"
			or biome_id == &"swamp"
		):
			_assert_generated_path_divider_reuse(layer, biome_id)
		if biome_id == &"swamp":
			_assert_marsh_routes_are_lifted(layer, expected_surface_trim)
		if biome_id == &"burning_plains":
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
		if biome_id == &"frozen_tundra":
			var frozen_ground_id := _find_surface_material_id(
				layer,
				"base_ground_variation_01"
			)
			assert_false(
				frozen_ground_id.is_empty(),
				"frozen_tundra exposes its clean snow ground material"
			)
			var frozen_ground_texture := (
				layer._forest_surface_textures.get(frozen_ground_id)
				as Texture2D
			)
			assert_not_null(
				frozen_ground_texture,
				"frozen_tundra builds its macro ground texture"
			)
			var frozen_runtime_image := frozen_ground_texture.get_image()
			assert_lte(
				_edge_seam_score(frozen_runtime_image),
				0.04,
				"frozen_tundra runtime surface has continuous repeat edges"
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
				"frozen_tundra exposes a path material"
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
				"road_variation",
				expected_surface_trim,
				"frozen road"
			)
		if biome_id == &"swamp":
			var marsh_ground_id := _find_surface_material_id(
				layer,
				"base_ground_variation_01"
			)
			assert_false(
				marsh_ground_id.is_empty(),
				"swamp exposes its quiet ground material"
			)
			var marsh_ground_texture := (
				layer._forest_surface_textures.get(marsh_ground_id)
				as Texture2D
			)
			assert_not_null(
				marsh_ground_texture,
				"swamp builds its macro ground texture"
			)
			var marsh_runtime_image := marsh_ground_texture.get_image()
			assert_lte(
				_edge_seam_score(marsh_runtime_image),
				0.04,
				"swamp runtime surface has continuous repeat edges"
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
				"swamp exposes a path material"
			)
			assert_eq(
				layer._forest_surface_texture_world_size(marsh_path_id),
				BiomeTileLayer.MARSH_SURFACE_TEXTURE_WORLD_SIZE,
				"drowned marsh route keeps native material density"
			)
		var selected_material_paths: Dictionary = {}
		for y in range(layout.zone_size.y):
			for x in range(layout.zone_size.x):
				var selected_path := layer.get_resolved_material_asset_path(
					Vector2i(x, y)
				)
				if not selected_path.is_empty():
					selected_material_paths[selected_path] = true
		for selected_path in selected_material_paths:
			assert_true(
				String(selected_path).contains(expected_theme_fragment),
				"%s resolver never falls back outside its generated theme: %s"
				% [String(biome_id), String(selected_path)]
			)

		var lane_border_cell := Vector2i(10, 5)
		assert_eq(
			layer.get_resolved_tile_id(lane_border_cell),
			BiomeTileResolver.TILE_ROAD_EDGE,
			"%s lane border keeps the road edge tile id" % String(biome_id)
		)
		assert_eq(
			layer.get_terrain_surface_kind(lane_border_cell),
			TERRAIN_SURFACE_CLASSIFIER.SURFACE_PATH,
			"%s lane border feeds the path channel" % String(biome_id)
		)
		assert_true(
			layer.get_resolved_material_asset_path(lane_border_cell).contains(
				"path_variation"
			),
			"%s lane border resolves to a full-bleed path texture"
			% String(biome_id)
		)
		assert_true(
			layer.get_resolved_material_asset_path(
				Vector2i(4, 4)
			).contains(expected_theme_fragment),
			"%s hazard cell keeps its generated ground theme" % String(biome_id)
		)
		var main_road_probe := Vector2i(5, 11)
		var vertical_main_road_probe := Vector2i(21, 6)
		for road_probe in [main_road_probe, vertical_main_road_probe]:
			assert_eq(
				layer.get_resolved_tile_id(road_probe),
				BiomeTileResolver.TILE_MAIN_ROAD,
				"%s main road keeps its semantic tile id" % String(biome_id)
			)
			assert_eq(
				layer.get_terrain_surface_kind(road_probe),
				TERRAIN_SURFACE_CLASSIFIER.SURFACE_ASPHALT,
				"%s main road feeds the asphalt channel" % String(biome_id)
			)
			assert_true(
				layer.get_resolved_material_asset_path(road_probe).contains(
					expected_theme_fragment
				),
				"%s main road resolves inside its generated theme"
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
		assert_eq(
			layer.get_terrain_surface_kind(route_probe),
			TERRAIN_SURFACE_CLASSIFIER.SURFACE_PATH,
			"%s route feeds the path channel" % String(biome_id)
		)
		assert_true(
			layer.get_resolved_material_asset_path(route_probe).contains(
				expected_theme_fragment
			),
			"%s route uses its generated theme material" % String(biome_id)
		)
		assert_true(
			layer.get_resolved_material_asset_path(route_probe).contains(
				"path_variation"
			),
			"%s route resolves to a full-bleed path texture" % String(biome_id)
		)

		var intersection_probe := Vector2i(21, 11)
		assert_eq(
			layer.get_resolved_tile_id(intersection_probe),
			BiomeTileResolver.TILE_ROAD_INTERSECTION,
			"%s internal road overlap keeps the intersection tile id"
			% String(biome_id)
		)
		assert_eq(
			layer.get_terrain_surface_kind(intersection_probe),
			TERRAIN_SURFACE_CLASSIFIER.SURFACE_ASPHALT,
			"%s internal road overlap stays asphalt" % String(biome_id)
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
		assert_eq(
			layer.get_terrain_surface_kind(passage_probe),
			TERRAIN_SURFACE_CLASSIFIER.SURFACE_ASPHALT,
			"%s passage feeds the asphalt channel" % String(biome_id)
		)
		assert_true(
			layer.get_resolved_material_asset_path(passage_probe).contains(
				expected_theme_fragment
			),
			"%s passage uses its generated theme material" % String(biome_id)
		)

		for rendered_id in layer.get_rendered_surface_material_ids():
			var rendered_text := String(rendered_id)
			assert_false(
				rendered_text.contains("__core_")
				or rendered_text.contains("__edge_"),
				"%s masked renderer emits no legacy core/edge material: %s"
				% [String(biome_id), rendered_text]
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
		if biome_id == &"burning_plains":
			var runtime_cliff_lip_image := layer._cliff_lip_texture.get_image()
			assert_lte(
				_edge_seam_score(runtime_cliff_lip_image),
				0.06,
				"burning_plains runtime cliff lip harmonizes opposite edges"
			)
		var probe := Vector2i(3, 3)
		var material_path := layer.get_resolved_material_asset_path(probe)
		assert_true(
			material_path.contains(
				"/%s/" % String(GENERATED_BIOME_ASSET_DIRECTORIES[biome_id])
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
		var theme_id := String(GENERATED_BIOME_ASSET_DIRECTORIES[biome_id])
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
	var palette := load("res://game/modes/zombie/biomes/plains_palette.tres") as BiomePalette
	assert_not_null(palette, "infected plains palette loads for cliff mesh QA")
	if palette == null:
		return
	var builder := TopDownCliffMeshBuilder.new()
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
	var palette := load("res://game/modes/zombie/biomes/plains_palette.tres") as BiomePalette
	assert_not_null(palette, "infected plains palette loads for cliff mesh QA")
	if palette == null:
		return
	# Simula lo streaming a chunk: 3 batch flushati uno alla volta, come farebbe
	# BiomeTileLayer._build_chunk_for_coord() per 3 chunk successivi.
	var incremental := TopDownCliffMeshBuilder.new()
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

	var single_shot := TopDownCliffMeshBuilder.new()
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
	var builder := TopDownCliffBorderMeshBuilder.new()
	var runtime_rim_width := 48.0 * TopDownCliffBorderMeshBuilder.RIM_WIDTH_TILES
	assert_almost_eq(
		builder._horizontal_rock_depth(runtime_rim_width),
		runtime_rim_width * TopDownCliffBorderMeshBuilder.ROCK_DEPTH_RATIO,
		0.01,
		"horizontal cliff lip leaves comparable room for the terrain transition"
	)
	assert_almost_eq(
		builder._vertical_rock_depth(runtime_rim_width),
		runtime_rim_width * TopDownCliffBorderMeshBuilder.ROCK_DEPTH_RATIO,
		0.01,
		"vertical cliff lip leaves comparable room for the terrain transition"
	)
	assert_almost_eq(
		builder._transition_width(48.0),
		48.0 * (
			TERRAIN_BOUNDARY_MASK_BUILDER.DIVIDER_HALF_WIDTH_TILES
			+ TERRAIN_BOUNDARY_MASK_BUILDER.DIVIDER_FEATHER_TILES
		),
		0.01,
		"fall-zone dirt uses the same nominal one-side thickness as a road divider"
	)
	assert_almost_eq(
		builder._transition_inner_color().a,
		1.0,
		0.001,
		"dirt starts opaque at the adjacent rock edge instead of reading as an overlay"
	)
	assert_almost_eq(
		builder._transition_core_width(48.0),
		48.0 * TopDownCliffBorderMeshBuilder.TRANSITION_CORE_WIDTH_TILES,
		0.01,
		"cliff dirt retains a road-like opaque core before its outer feather"
	)
	assert_lt(
		builder._transition_core_width(48.0),
		builder._transition_width(48.0),
		"only the outside of the dirt strip fades into grass"
	)
	assert_almost_eq(
		builder._transition_inner_feather_width(48.0),
		48.0 * TopDownCliffBorderMeshBuilder.TRANSITION_INNER_FEATHER_WIDTH_TILES,
		0.01,
		"cliff dirt adds a short inner feather over the flat-rock edge"
	)
	assert_almost_eq(
		builder._horizontal_rock_uv_end(
			builder._horizontal_rock_depth(runtime_rim_width)
		) - TopDownCliffBorderMeshBuilder.HORIZONTAL_ROCK_UV_START,
		builder._horizontal_rock_depth(runtime_rim_width)
			/ TopDownCliffBorderMeshBuilder.TEXTURE_REPEAT_WORLD_SIZE,
		0.001,
		"narrower forest rock keeps 1:1 UV density instead of recompressing the band"
	)
	builder.build([Rect2i(Vector2i(4, 5), Vector2i(6, 4))], [&"internal"], Vector2i(16, 16), 8.0)
	assert_true(builder.horizontal_segment_count == 2 and builder.vertical_segment_count == 2 and builder.corner_count == 4,
		"one fall rectangle builds two horizontal edges, two vertical edges and four corners")
	assert_true(_mesh_has_uvs(builder.horizontal_mesh), "horizontal cliff border exposes UVs")
	assert_true(_mesh_has_uvs(builder.vertical_mesh), "vertical cliff border exposes UVs")
	assert_true(_mesh_has_uvs(builder.terrain_transition_mesh), "cliff border exposes a world-space terrain transition mesh")
	assert_true(
		_mesh_uses_flat_rock_planar_uv(builder.horizontal_mesh)
		and _mesh_uses_flat_rock_planar_uv(builder.vertical_mesh),
		"forest flat rim uses one planar mesa-top UV projection across edges and corners"
	)
	assert_eq(builder.terrain_transition_segment_count, 4, "every exposed cliff run receives one terrain transition")
	assert_eq(
		builder.terrain_transition_corner_count,
		4,
		"fall-zone dirt replaces square extensions with four rounded convex corners"
	)
	var mesa_outline_builder := TopDownCliffBorderMeshBuilder.new()
	mesa_outline_builder.build_dirt_outline(
		[Rect2i(Vector2i(4, 5), Vector2i(6, 4))],
		Vector2i(16, 16),
		8.0
	)
	assert_eq(
		mesa_outline_builder.terrain_transition_segment_count,
		4,
		"one mesa footprint receives the shared dirt outline on all four sides"
	)
	assert_eq(
		mesa_outline_builder.terrain_transition_corner_count,
		4,
		"one mesa footprint receives four rounded dirt corners"
	)
	assert_eq(
		mesa_outline_builder.mesa_inset_corner_patch_count,
		4,
		"dirt fills all four cut-outs left by the rounded mesa footprint"
	)
	assert_true(
		_mesh_has_opaque_triangle_at(
			mesa_outline_builder.terrain_transition_mesh,
			Vector2(-31.4, -23.6)
		),
		"the rounded north-west mesa join cannot expose the grass underlay"
	)
	assert_true(
		_mesh_has_uvs(mesa_outline_builder.terrain_transition_mesh),
		"mesa dirt outline exposes the same world-space divider UVs"
	)
	var h := _mesh_bounds(builder.horizontal_mesh)
	var v := _mesh_bounds(builder.vertical_mesh)
	var transition_bounds := _mesh_bounds(builder.terrain_transition_mesh)
	var expected_horizontal_depth := builder._horizontal_rock_depth(12.0)
	var expected_vertical_depth := builder._vertical_rock_depth(12.0)
	var expected_transition_width := builder._transition_width(8.0)
	assert_true(
		is_equal_approx(h.position.x, -32.0 - expected_vertical_depth)
		and is_equal_approx(h.end.x, 16.0 + expected_vertical_depth)
		and is_equal_approx(h.position.y, -24.0 - expected_horizontal_depth)
		and is_equal_approx(h.end.y, 8.0 + expected_horizontal_depth)
		and is_equal_approx(v.position.x, -32.0 - expected_vertical_depth)
		and is_equal_approx(v.end.x, 16.0 + expected_vertical_depth)
		and is_equal_approx(v.position.y, -24.0)
		and is_equal_approx(v.end.y, 8.0),
		"rock crest preserves texture aspect and fills all four convex corner quadrants"
	)
	assert_true(
		is_equal_approx(
			transition_bounds.position.x,
			-32.0 - expected_vertical_depth - expected_transition_width
		)
		and is_equal_approx(
			transition_bounds.end.x,
			16.0 + expected_vertical_depth + expected_transition_width
		)
		and is_equal_approx(
			transition_bounds.position.y,
			-24.0 - expected_horizontal_depth - expected_transition_width
		)
		and is_equal_approx(
			transition_bounds.end.y,
			8.0 + expected_horizontal_depth + expected_transition_width
		),
		"terrain transition wraps edges and convex corners outside the rock crest"
	)
	var transition_arrays := builder.terrain_transition_mesh.surface_get_arrays(0)
	var transition_colors := transition_arrays[Mesh.ARRAY_COLOR] as PackedColorArray
	assert_true(
		_transition_colors_fade_outward(transition_colors),
		"terrain transition fades from opaque dirt beside rock to transparent terrain"
	)
	var horizontal_arrays := builder.horizontal_mesh.surface_get_arrays(0)
	var horizontal_vertices := (
		horizontal_arrays[Mesh.ARRAY_VERTEX] as PackedVector2Array
	)
	for vertex in horizontal_vertices:
		assert_false(
			vertex.y > -24.0 + 0.001 and vertex.y < 8.0 - 0.001,
			"horizontal crest vertex never enters the fall rectangle"
		)
	var vertical_arrays := builder.vertical_mesh.surface_get_arrays(0)
	var vertical_vertices := vertical_arrays[Mesh.ARRAY_VERTEX] as PackedVector2Array
	for vertex in vertical_vertices:
		assert_false(
			vertex.x > -32.0 + 0.001 and vertex.x < 16.0 - 0.001,
			"vertical crest vertex never enters the fall rectangle"
		)
	builder.build([Rect2i(Vector2i(0, 0), Vector2i(16, 3))], [&"north"], Vector2i(16, 16), 8.0)
	assert_true(builder.horizontal_segment_count == 1 and builder.vertical_segment_count == 0 and builder.corner_count == 2,
		"perimeter fall zone draws only the edge facing walkable terrain")
	builder.build([Rect2i(Vector2i(0, 0), Vector2i(16, 1))], [&"north"], Vector2i(16, 16), 48.0)
	var perimeter_h := _mesh_bounds(builder.horizontal_mesh)
	var fall_boundary_y := (1.0 - 8.0) * 48.0
	assert_true(
		is_equal_approx(perimeter_h.position.y, fall_boundary_y)
		and is_equal_approx(
			perimeter_h.size.y,
			builder._horizontal_rock_depth(48.0 * TopDownCliffBorderMeshBuilder.RIM_WIDTH_TILES)
		),
		"perimeter cliff rim preserves material aspect and begins at the fall boundary"
	)

func test_rectilinear_face_meshes() -> void:
	var builder := RectilinearCliffFaceMeshBuilder.new()
	var shallow_depth := builder._far_face_depth(
		Rect2(Vector2.ZERO, Vector2(192.0, 192.0)),
		&"internal",
		48.0
	)
	var deep_depth := builder._far_face_depth(
		Rect2(Vector2.ZERO, Vector2(192.0, 576.0)),
		&"internal",
		48.0
	)
	assert_eq(
		shallow_depth,
		deep_depth,
		"internal cliff drop height is independent from fall-zone length"
	)
	assert_eq(
		shallow_depth,
		48.0 * RectilinearCliffFaceMeshBuilder.INTERNAL_FAR_FACE_DEPTH_TILES,
		"internal cliff drop uses the canonical visual depth"
	)
	builder.build([Rect2i(Vector2i(4, 5), Vector2i(6, 4))], [&"internal"], Vector2i(16, 16), 8.0)
	assert_eq(builder.face_count, 4, "internal fall rectangle builds four cliff faces")
	assert_true(_mesh_has_uvs(builder.face_mesh), "rectilinear cliff faces expose UVs")
	assert_true(
		_mesh_uses_planar_world_uv(builder.face_mesh),
		"rectilinear cliff faces share one planar world-space texture projection"
	)
	assert_eq(
		_mesh_sheared_quad_count(builder.face_mesh),
		0,
		"a simple rectangle gives convex corners to horizontal faces without sheared side bands"
	)
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

func test_touching_fall_rectangles_share_one_void_outline() -> void:
	# T-shaped union: the upper pit joins the left half of the lower pit. The
	# shared x=4..8 boundary at y=6 must not become a horizontal cliff seam.
	var rects: Array[Rect2i] = [
		Rect2i(Vector2i(4, 2), Vector2i(4, 4)),
		Rect2i(Vector2i(4, 6), Vector2i(8, 4)),
	]
	var sides: Array[StringName] = [&"internal", &"internal"]
	var runs: Array[Dictionary] = FALL_ZONE_BOUNDARY_RUNS_SCRIPT.build(
		rects,
		sides,
		Vector2i(16, 16)
	)
	assert_eq(runs.size(), 6, "touching rectangles expose only the six runs of their union outline")
	var shared_seam_found := false
	var concave_run_endpoints := 0
	for run in runs:
		var orientation := StringName(run.get("orientation", &""))
		if StringName(run.get("start_corner", &"")) == FALL_ZONE_BOUNDARY_RUNS_SCRIPT.CORNER_CONCAVE:
			concave_run_endpoints += 1
		if StringName(run.get("end_corner", &"")) == FALL_ZONE_BOUNDARY_RUNS_SCRIPT.CORNER_CONCAVE:
			concave_run_endpoints += 1
		if (
			int(run.get("boundary", -1)) == 6
			and int(run.get("start", -1)) < 8
			and int(run.get("end", -1)) > 4
			and (
				orientation == FALL_ZONE_BOUNDARY_RUNS_SCRIPT.TOP
				or orientation == FALL_ZONE_BOUNDARY_RUNS_SCRIPT.BOTTOM
			)
		):
			shared_seam_found = true
	assert_false(shared_seam_found, "the joined void has no cliff run across its shared horizontal edge")
	assert_eq(
		concave_run_endpoints,
		2,
		"the union outline marks both runs that meet at its concave vertex"
	)

	var border_builder := TopDownCliffBorderMeshBuilder.new()
	border_builder.build(rects, sides, Vector2i(16, 16), 8.0)
	assert_eq(border_builder.horizontal_segment_count, 3, "the joined void renders three exposed horizontal lip runs")
	assert_eq(border_builder.vertical_segment_count, 3, "the joined void renders three exposed vertical lip runs")
	assert_eq(
		border_builder.concave_corner_count,
		1,
		"the joined void terminates its lip at the concave corner once"
	)

	var face_builder := RectilinearCliffFaceMeshBuilder.new()
	face_builder.build(rects, sides, Vector2i(16, 16), 8.0)
	assert_eq(face_builder.face_count, 6, "cliff faces follow the union outline instead of both source rectangles")
	assert_eq(
		face_builder.concave_join_count,
		1,
		"the concave vertex is owned by one shared projected seam"
	)
	var concave_vertex := Vector2i(8, 6)
	assert_true(
		face_builder.corner_drop_by_vertex.has(concave_vertex),
		"the concave vertex exposes its combined horizontal and vertical drop"
	)
	var concave_drop := face_builder.corner_drop_by_vertex.get(
		concave_vertex,
		Vector2.ZERO
	) as Vector2
	assert_true(
		not is_zero_approx(concave_drop.x) and not is_zero_approx(concave_drop.y),
		"the shared concave drop contains both projection components"
	)
	var concave_crest := (
		Vector2(concave_vertex) - Vector2(16, 16) * 0.5
	) * 8.0
	var shared_deep_vertex := concave_crest + concave_drop
	var face_arrays := face_builder.face_mesh.surface_get_arrays(0)
	var face_vertices := face_arrays[Mesh.ARRAY_VERTEX] as PackedVector2Array
	var face_indices := face_arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
	assert_eq(
		face_vertices.size(),
		face_builder.face_count * 4,
		"every outline run remains one quad with no patch triangles"
	)
	assert_eq(
		face_indices.size(),
		face_builder.face_count * 6,
		"every outline run keeps exactly two triangles"
	)
	var shared_vertex_occurrences := 0
	for vertex in face_vertices:
		if vertex.is_equal_approx(shared_deep_vertex):
			shared_vertex_occurrences += 1
	assert_eq(
		shared_vertex_occurrences,
		2,
		"both incident faces terminate on the exact same deep corner vertex"
	)
	assert_true(
		_mesh_uvs_match_at_vertex(face_builder.face_mesh, concave_crest),
		"both incident faces share one UV phase at the concave crest"
	)
	assert_true(
		_mesh_uvs_match_at_vertex(face_builder.face_mesh, shared_deep_vertex),
		"both incident faces share one UV phase at the concave deep vertex"
	)

func test_diagonal_fall_corners_receive_rounded_dirt_joins() -> void:
	var rects: Array[Rect2i] = [
		Rect2i(Vector2i(2, 2), Vector2i(4, 4)),
		Rect2i(Vector2i(6, 6), Vector2i(4, 4)),
	]
	var sides: Array[StringName] = [&"internal", &"internal"]
	var runs: Array[Dictionary] = FALL_ZONE_BOUNDARY_RUNS_SCRIPT.build(
		rects,
		sides,
		Vector2i(16, 16)
	)
	var diagonal_endpoints := 0
	for run in runs:
		if (
			StringName(run.get("start_corner", &""))
			== FALL_ZONE_BOUNDARY_RUNS_SCRIPT.CORNER_DIAGONAL
		):
			diagonal_endpoints += 1
		if (
			StringName(run.get("end_corner", &""))
			== FALL_ZONE_BOUNDARY_RUNS_SCRIPT.CORNER_DIAGONAL
		):
			diagonal_endpoints += 1
	assert_eq(
		diagonal_endpoints,
		4,
		"checkerboard void topology exposes four run endpoints at one diagonal vertex"
	)

	var builder := TopDownCliffBorderMeshBuilder.new()
	builder.build(rects, sides, Vector2i(16, 16), 48.0)
	assert_eq(
		builder.terrain_transition_corner_count,
		8,
		"six outer corners plus two opposite diagonal quarters round the shared junction"
	)
	var transition_arrays := builder.terrain_transition_mesh.surface_get_arrays(0)
	var transition_vertices := (
		transition_arrays[Mesh.ARRAY_VERTEX] as PackedVector2Array
	)
	var diagonal_center := (
		Vector2(6, 6) - Vector2(16, 16) * 0.5
	) * 48.0
	var diagonal_radius := (
		(
			TopDownCliffBorderMeshBuilder.DIAGONAL_CORNER_RADIUS_TILES
			+ TopDownCliffBorderMeshBuilder.TRANSITION_WIDTH_TILES
		) * 48.0
	)
	var rounded_quadrants := {
		"north_west": 0,
		"north_east": 0,
		"south_west": 0,
		"south_east": 0,
	}
	for vertex in transition_vertices:
		var delta := vertex - diagonal_center
		if (
			absf(delta.x) <= 0.5
			or absf(delta.y) <= 0.5
			or delta.length() > diagonal_radius + 0.5
		):
			continue
		if delta.x < 0.0 and delta.y < 0.0:
			rounded_quadrants["north_west"] += 1
		elif delta.x > 0.0 and delta.y < 0.0:
			rounded_quadrants["north_east"] += 1
		elif delta.x < 0.0 and delta.y > 0.0:
			rounded_quadrants["south_west"] += 1
		else:
			rounded_quadrants["south_east"] += 1
	assert_gt(
		int(rounded_quadrants["north_west"]),
		0,
		"the north-west void corner receives a recessed radial dirt join"
	)
	assert_gt(
		int(rounded_quadrants["south_east"]),
		0,
		"the south-east void corner receives a recessed radial dirt join"
	)
	assert_lt(
		TopDownCliffBorderMeshBuilder.DIAGONAL_CORNER_RADIUS_TILES,
		0.5,
		"checkerboard curvature stays compact and affects only the dirt join"
	)
	assert_eq(
		builder.diagonal_void_patch_count,
		1,
		"the shared checkerboard vertex receives one visible void patch"
	)
	assert_not_null(
		builder.diagonal_void_mesh,
		"the checkerboard void patch has renderable geometry"
	)
	var rock_arrays := builder.horizontal_mesh.surface_get_arrays(0)
	var rock_vertices := rock_arrays[Mesh.ARRAY_VERTEX] as PackedVector2Array
	var curved_rock_vertices := 0
	for vertex in rock_vertices:
		var delta := vertex - diagonal_center
		if (
			delta.length() < diagonal_radius + 0.5
			and absf(delta.x) > 0.5
			and absf(delta.y) > 0.5
		):
			curved_rock_vertices += 1
	assert_eq(
		curved_rock_vertices,
		0,
		"checkerboard curvature affects dirt only, never the flat-rock mesh"
	)

	var compact_builder := TopDownCliffBorderMeshBuilder.new()
	compact_builder.build(
		[
			Rect2i(Vector2i(2, 2), Vector2i.ONE),
			Rect2i(Vector2i(3, 3), Vector2i.ONE),
		],
		sides,
		Vector2i(8, 8),
		48.0
	)
	assert_eq(
		compact_builder.terrain_transition_corner_count,
		8,
		"one-tile diagonal voids retain both bounded checkerboard joins"
	)
	assert_eq(
		compact_builder.diagonal_void_patch_count,
		1,
		"compact diagonal voids still share one central void marker"
	)
	var compact_arrays := compact_builder.terrain_transition_mesh.surface_get_arrays(0)
	var compact_vertices := compact_arrays[Mesh.ARRAY_VERTEX] as PackedVector2Array
	var compact_vertices_are_finite := true
	for vertex in compact_vertices:
		compact_vertices_are_finite = (
			compact_vertices_are_finite and vertex.is_finite()
		)
	assert_true(
		compact_vertices_are_finite,
		"short checkerboard runs clamp their corner radius to finite geometry"
	)

func test_three_void_quadrants_build_one_unforked_dirt_corner() -> void:
	var rects: Array[Rect2i] = [
		Rect2i(Vector2i(6, 2), Vector2i(4, 4)),
		Rect2i(Vector2i(2, 6), Vector2i(4, 4)),
		Rect2i(Vector2i(6, 6), Vector2i(4, 4)),
	]
	var sides: Array[StringName] = [&"internal", &"internal", &"internal"]
	var runs: Array[Dictionary] = FALL_ZONE_BOUNDARY_RUNS_SCRIPT.build(
		rects,
		sides,
		Vector2i(16, 16)
	)
	var concave_endpoints := 0
	for run in runs:
		if (
			StringName(run.get("start_corner", &""))
			== FALL_ZONE_BOUNDARY_RUNS_SCRIPT.CORNER_CONCAVE
		):
			concave_endpoints += 1
		if (
			StringName(run.get("end_corner", &""))
			== FALL_ZONE_BOUNDARY_RUNS_SCRIPT.CORNER_CONCAVE
		):
			concave_endpoints += 1
	assert_eq(
		concave_endpoints,
		2,
		"three void quadrants expose one shared horizontal/vertical concave join"
	)

	var builder := TopDownCliffBorderMeshBuilder.new()
	var logical_scale := 48.0
	builder.build(rects, sides, Vector2i(16, 16), logical_scale)
	assert_eq(
		builder.terrain_transition_corner_count,
		6,
		"five outer dirt corners plus one terrain-side quarter form the L outline"
	)
	var rim_width := logical_scale * TopDownCliffBorderMeshBuilder.RIM_WIDTH_TILES
	var rock_depth := builder._horizontal_rock_depth(rim_width)
	var grid_vertex := (
		Vector2(6, 6) - Vector2(16, 16) * 0.5
	) * logical_scale
	var dirt_corner_center := grid_vertex - Vector2(rock_depth, rock_depth)
	var transition_arrays := builder.terrain_transition_mesh.surface_get_arrays(0)
	var transition_vertices := (
		transition_arrays[Mesh.ARRAY_VERTEX] as PackedVector2Array
	)
	var fork_vertices := 0
	for vertex in transition_vertices:
		if (
			vertex.x > dirt_corner_center.x + 0.5
			and vertex.x <= grid_vertex.x + 0.5
			and vertex.y < dirt_corner_center.y - 0.5
			and vertex.y >= (
				dirt_corner_center.y
				- builder._transition_width(logical_scale)
				- 0.5
			)
		):
			fork_vertices += 1
	assert_eq(
		fork_vertices,
		0,
		"horizontal dirt stops at the tangent instead of forking toward the void vertex"
	)

func test_projected_corner_seams_cover_l_t_cross_and_mirrors() -> void:
	var cases: Array[Dictionary] = [
		{
			"label": "L south-east",
			"rects": [
				Rect2i(Vector2i(4, 2), Vector2i(4, 4)),
				Rect2i(Vector2i(4, 6), Vector2i(8, 4)),
			],
			"concave_count": 1,
		},
		{
			"label": "L south-west",
			"rects": [
				Rect2i(Vector2i(4, 2), Vector2i(4, 4)),
				Rect2i(Vector2i(0, 6), Vector2i(8, 4)),
			],
			"concave_count": 1,
		},
		{
			"label": "L north-east",
			"rects": [
				Rect2i(Vector2i(4, 6), Vector2i(4, 4)),
				Rect2i(Vector2i(4, 2), Vector2i(8, 4)),
			],
			"concave_count": 1,
		},
		{
			"label": "L north-west",
			"rects": [
				Rect2i(Vector2i(4, 6), Vector2i(4, 4)),
				Rect2i(Vector2i(0, 2), Vector2i(8, 4)),
			],
			"concave_count": 1,
		},
		{
			"label": "T",
			"rects": [
				Rect2i(Vector2i(7, 2), Vector2i(3, 10)),
				Rect2i(Vector2i(2, 5), Vector2i(5, 4)),
			],
			"concave_count": 2,
		},
		{
			"label": "cross",
			"rects": [
				Rect2i(Vector2i(7, 2), Vector2i(3, 10)),
				Rect2i(Vector2i(2, 5), Vector2i(11, 4)),
			],
			"concave_count": 4,
		},
	]
	var zone_size := Vector2i(16, 16)
	var logical_scale := 32.0
	for case_data in cases:
		var label := String(case_data.get("label", "shape"))
		var rects: Array[Rect2i] = []
		for value in case_data.get("rects", []) as Array:
			rects.append(value as Rect2i)
		var sides: Array[StringName] = []
		for _rect in rects:
			sides.append(&"internal")
		var concave_vertices := _concave_boundary_vertices(rects, sides, zone_size)
		var expected_count := int(case_data.get("concave_count", 0))
		assert_eq(
			concave_vertices.size(),
			expected_count,
			"%s exposes every expected concave outline vertex" % label
		)
		var builder := RectilinearCliffFaceMeshBuilder.new()
		builder.build(rects, sides, zone_size, logical_scale)
		assert_eq(
			builder.concave_join_count,
			expected_count,
			"%s resolves every concave vertex through the shared-drop model" % label
		)
		var arrays := builder.face_mesh.surface_get_arrays(0)
		var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector2Array
		var indices := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
		assert_eq(
			vertices.size(),
			builder.face_count * 4,
			"%s emits only projected run quads" % label
		)
		assert_eq(
			indices.size(),
			builder.face_count * 6,
			"%s emits no independent corner primitives" % label
		)
		for concave_vertex in concave_vertices:
			assert_true(
				builder.corner_drop_by_vertex.has(concave_vertex),
				"%s maps concave vertex %s" % [label, str(concave_vertex)]
			)
			var drop := builder.corner_drop_by_vertex.get(
				concave_vertex,
				Vector2.ZERO
			) as Vector2
			assert_true(
				not is_zero_approx(drop.x) and not is_zero_approx(drop.y),
				"%s combines both drop axes at %s" % [label, str(concave_vertex)]
			)
			var crest := (
				Vector2(concave_vertex) - Vector2(zone_size) * 0.5
			) * logical_scale
			var deep_vertex := crest + drop
			assert_eq(
				_mesh_vertex_occurrences(builder.face_mesh, deep_vertex),
				2,
				"%s incident faces share one deep vertex at %s" % [
					label,
					str(concave_vertex),
				]
			)
			assert_true(
				_mesh_uvs_match_at_vertex(builder.face_mesh, crest),
				"%s incident faces share crest UV phase at %s" % [
					label,
					str(concave_vertex),
				]
			)
			assert_true(
				_mesh_uvs_match_at_vertex(builder.face_mesh, deep_vertex),
				"%s incident faces share deep UV phase at %s" % [
					label,
					str(concave_vertex),
				]
			)

func test_tile_layer_consumes_cliff_textures() -> void:
	var palette := load("res://game/modes/zombie/biomes/plains_palette.tres") as BiomePalette
	var layout := BiomeEnvironmentLayout.new()
	layout.zone_size = Vector2i(16, 16)
	layout.generation_seed = 515151
	layout.add_floor_rect(Rect2i(Vector2i.ZERO, layout.zone_size), &"forest_grass")
	layout.add_fall_zone_rect(Rect2i(Vector2i(6, 6), Vector2i(4, 4)), &"internal")
	layout.mesa_rects.append(Rect2i(Vector2i(1, 1), Vector2i(3, 3)))
	layout.mesa_profile_ids.append(&"forest")
	layout.rebuild_terrain_classification()
	var layer := BiomeTileLayer.new()
	add_child(layer)
	layer.configure(layout, palette, &"plains", &"quality", 16, null, _manifest, false)
	await wait_physics_frames(1)
	assert_true(layer.has_cliff_art_textures(), "tile layer loads face and lip textures")
	assert_true(layer.has_forest_cliff_border_art(), "forest tile layer loads horizontal and vertical cliff border art")
	assert_true(
		layer.uses_mesa_top_for_fall_zone_rim(),
		"forest fall-zone rim reuses the flat top texture from mesas"
	)
	var paths := layer.get_cliff_art_asset_paths()
	for asset_id in CLIFF_TEXTURE_IDS:
		assert_false(String(paths.get(asset_id, "")).is_empty(), "tile layer exposes %s asset path" % String(asset_id))
	assert_gt(layer.get_cliff_transition_count(), 0, "synthetic void builds textured cliff transitions")
	var border_counts := layer.get_forest_cliff_border_counts()
	assert_true(int(border_counts.get("horizontal", 0)) == 2 and int(border_counts.get("vertical", 0)) == 2 and int(border_counts.get("corners", 0)) == 4,
		"synthetic fall rectangle applies every dedicated border mesh")
	assert_eq(
		int(border_counts.get("terrain_transitions", 0)),
		4,
		"synthetic fall rectangle applies dirt transition to all four border runs"
	)
	assert_eq(int(border_counts.get("faces", 0)), 4, "synthetic fall rectangle replaces angled per-cell faces with four linear faces")
	assert_eq(
		int(layer.get_mesa_area_counts().get("dirt_transitions", 0)),
		0,
		"Plains mesa omits the legacy dirt outline"
	)
	assert_eq(
		int(layer.get_mesa_area_counts().get("dirt_corners", 0)),
		0,
		"Plains mesa emits no dirt corner patches"
	)
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
	var resolver := BiomeTileResolver.new(_manifest)
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
	assert_eq(
		layer.get_terrain_surface_kind(void_cell),
		TERRAIN_SURFACE_CLASSIFIER.SURFACE_VOID,
		"void transition feeds the visual void channel"
	)
	assert_eq(
		layer.get_terrain_surface_kind(ground_cell),
		TERRAIN_SURFACE_CLASSIFIER.SURFACE_GRASS,
		"walkable terrain beside the cliff remains a ground surface"
	)
	_assert_terrain_surface_runtime_contract(layer, layout, "void transition")
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

# --- forest tile resolver su mappa generata (forest_top_down_transition) ----

func test_forest_tile_contracts() -> void:
	var resolver := BiomeTileResolver.new(_manifest)
	for tile_id in REQUIRED_FOREST_TILE_IDS:
		var section := resolver.resolve_tile_section(tile_id)
		var contract := _manifest.get_asset_contract(section, tile_id)
		assert_false(contract.is_empty(), "%s has a forest asset contract" % String(tile_id))
		assert_true(_asset_exists(String(contract.get("asset_path", ""))), "%s asset file exists" % String(tile_id))
	var biome_set := _manifest.get_biome_asset_set_contract(&"plains")
	assert_true(_string_name_array(biome_set.get("terrain_tiles", [])).has(&"forest_path"), "base biome asset set includes forest terrain tiles")
	assert_true(_string_name_array(biome_set.get("void_tiles", [])).has(&"forest_cliff_edge"), "base biome asset set includes forest cliff edge")
	assert_true(_string_name_array(biome_set.get("edge_tiles", [])).has(&"forest_mountain_wall"), "base biome asset set includes forest mountain wall")

func test_generated_forest_resolver() -> void:
	var resolver := BiomeTileResolver.new(_manifest)
	var biome_manager := BiomeManager.new()
	add_child(biome_manager)
	await wait_physics_frames(1)
	biome_manager.start_run({"world_seed": 772031, "biome_map_width": 3, "biome_map_height": 3, "preserve_biome_sequence": false, "extra_edge_chance": 0.25})
	var cell := _first_cell_for_biome(biome_manager.get_generated_biome_map(), &"plains")
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
	var oriented_cliff_cell := Vector2i(-1, -1)
	var tall_grass_cell := Vector2i(-1, -1)
	var checked := 0
	for y in range(layout.zone_size.y):
		for x in range(layout.zone_size.x):
			var probe := Vector2i(x, y)
			var tile_id := resolver.resolve_tile_id(layout, probe, cell.biome_id, &"balanced", cell)
			saw_tiles[tile_id] = true
			if resolver.is_void_transition_tile_id(tile_id):
				saw_oriented_cliff = true
				if oriented_cliff_cell == Vector2i(-1, -1):
					oriented_cliff_cell = probe
			if (
				layout.get_floor_tag_at_cell(probe) == &"forest_tall_grass"
				and [&"forest_tall_grass", &"grass_to_tall_grass"].has(tile_id)
				and layout.get_terrain_class_at_cell(probe, cell) == BiomeEnvironmentLayout.TERRAIN_WALKABLE
			):
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

	var palette := load("res://game/modes/zombie/biomes/plains_palette.tres") as BiomePalette
	var layer := BiomeTileLayer.new()
	add_child(layer)
	layer.configure(layout, palette, cell.biome_id, &"balanced", 20, resolver, _manifest)
	assert_eq(layer.get_missing_asset_count(), 0, "forest tile layer has no missing assets")
	assert_gt(layer.get_suppressed_void_texture_count(), 0, "forest tile layer keeps pure void free of repeated tile texture")
	assert_eq(layer.get_void_background_color(), ZombieModeController.get_void_background_color(palette), "forest void uses the same color as the off-world backdrop")
	assert_eq(
		layer.get_terrain_surface_kind(oriented_cliff_cell),
		TERRAIN_SURFACE_CLASSIFIER.SURFACE_VOID,
		"forest cliff transition feeds the visual void channel"
	)
	_assert_terrain_surface_runtime_contract(layer, layout, "generated forest")
	assert_gt(layer.get_cliff_transition_count(), 0, "forest tile layer bakes vertical cliff faces")
	layer.free()
	biome_manager.queue_free()
	await wait_physics_frames(1)

func test_synthetic_forest_wall() -> void:
	var resolver := BiomeTileResolver.new(_manifest)
	var layout := BiomeEnvironmentLayout.new()
	layout.zone_size = Vector2i(16, 16)
	layout.generation_seed = 21
	layout.add_floor_rect(Rect2i(Vector2i(0, 0), layout.zone_size), &"open_block")
	var wall_rect := Rect2i(Vector2i(0, 0), Vector2i(16, 4))
	layout.add_wall_segment(wall_rect, &"north")
	layout.obstacle_rects.append(wall_rect)
	layout.obstacle_ids.append(&"boundary_fence")
	layout.rebuild_terrain_classification()
	assert_eq(resolver.resolve_tile_id(layout, Vector2i(4, 1), &"plains"), &"forest_mountain_wall", "forest wall cells resolve to the mountain wall tile")
	assert_eq(resolver.resolve_tile_id(layout, Vector2i(4, 4), &"plains"), &"ground_to_mountain_wall", "ground beside wall resolves to a mountain transition")

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
	var builder := TopDownCliffMeshBuilder.new()
	builder.configure(palette, 424242, true)
	builder.append_transition(BiomeTileResolver.TILE_VOID_EDGE_NORTH, Vector2.ZERO, 42.0, 22.0)
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

func _assert_terrain_surface_runtime_contract(
	layer: BiomeTileLayer,
	layout: BiomeEnvironmentLayout,
	label: String
) -> void:
	var loaded_ids := layer.get_loaded_surface_texture_ids()
	var rendered_ids := layer.get_rendered_surface_material_ids()
	var surface_contracts := [
		[TERRAIN_SURFACE_CLASSIFIER.SURFACE_GRASS, "ground"],
		[TERRAIN_SURFACE_CLASSIFIER.SURFACE_PATH, "path"],
		[TERRAIN_SURFACE_CLASSIFIER.SURFACE_ASPHALT, "road"],
	]
	for surface_contract in surface_contracts:
		var surface_kind := int(surface_contract[0])
		var role_name := String(surface_contract[1])
		var texture_id := StringName(
			layer._terrain_surface_texture_ids.get(surface_kind, &"")
		)
		assert_false(
			texture_id.is_empty(),
			"%s resolves a %s texture id" % [label, role_name]
		)
		assert_true(
			loaded_ids.has(texture_id),
			"%s loads the %s texture" % [label, role_name]
		)
		assert_true(
			rendered_ids.has(texture_id),
			"%s terrain canvas consumes the %s texture" % [label, role_name]
		)
	assert_true(
		loaded_ids.has(BiomeTileLayer.TERRAIN_DIVIDER_TEXTURE_ID),
		"%s loads terrain_divider_dirt" % label
	)
	assert_true(
		rendered_ids.has(BiomeTileLayer.TERRAIN_DIVIDER_TEXTURE_ID),
		"%s terrain canvas consumes terrain_divider_dirt" % label
	)

	var report := layer.get_terrain_boundary_report()
	assert_false(report.is_empty(), "%s exposes a terrain mask report" % label)
	assert_eq(
		report.get("image_size"),
		layout.zone_size * 8,
		"%s mask uses eight pixels per tile" % label
	)
	assert_eq(
		int(report.get("pixels_per_tile", 0)),
		8,
		"%s reports the mask resolution" % label
	)
	assert_gt(
		int(report.get("boundary_segment_count", 0)),
		0,
		"%s reports terrain boundary segments" % label
	)
	assert_gt(
		int(report.get("divider_pixel_count", 0)),
		0,
		"%s reports rasterized divider pixels" % label
	)
	var expected_divider_asset := "terrain_divider_dirt"
	if layer.biome_id == BiomeTileResolver.FOREST_BIOME_ID:
		expected_divider_asset = "forest_dirt_path_generated"
	elif (
		layer.biome_id == &"burning_plains"
		or layer.biome_id == &"frozen_tundra"
		or layer.biome_id == &"swamp"
	):
		expected_divider_asset = "path_variation"
	assert_true(
		String(report.get("divider_asset_path", "")).contains(
			expected_divider_asset
		),
		"%s report exposes the dirt divider asset" % label
	)

	for material_id in loaded_ids + rendered_ids:
		var material_text := String(material_id)
		assert_false(
			material_text.contains("__core_")
			or material_text.contains("__edge_"),
			"%s contains no legacy core/edge material: %s"
			% [label, material_text]
		)
	var terrain_canvas_count := 0
	for child in layer.get_children():
		var chunk := child as BiomeTileChunk
		if chunk == null or chunk.terrain_surface_canvas == null:
			continue
		terrain_canvas_count += 1
		assert_not_null(
			chunk.terrain_surface_canvas.surface_material,
			"%s chunk owns a configured terrain surface material" % label
		)
	assert_gt(
		terrain_canvas_count,
		0,
		"%s renders terrain through chunk surface canvases" % label
	)

func _assert_generated_path_divider_reuse(
	layer: BiomeTileLayer,
	biome_id: StringName
) -> void:
	var path_id := StringName(layer._terrain_surface_texture_ids.get(
		TERRAIN_SURFACE_CLASSIFIER.SURFACE_PATH,
		&""
	))
	var paths := layer.get_forest_surface_art_asset_paths()
	assert_false(
		path_id.is_empty(),
		"%s exposes its path material" % String(biome_id)
	)
	assert_eq(
		paths.get(BiomeTileLayer.TERRAIN_DIVIDER_TEXTURE_ID),
		paths.get(path_id),
		"%s dirt dividers reuse the exact path asset" % String(biome_id)
	)
	assert_true(
		layer._forest_surface_textures.get(
			BiomeTileLayer.TERRAIN_DIVIDER_TEXTURE_ID
		) == layer._forest_surface_textures.get(path_id),
		"%s dirt dividers reuse the normalized path texture instance"
		% String(biome_id)
	)
	assert_eq(
		layer._terrain_divider_texture_world_size(),
		layer._forest_surface_texture_world_size(path_id),
		"%s dirt dividers reuse the path world-space period"
		% String(biome_id)
	)

func _expected_generated_surface_texture_trim_pixels(
	biome_id: StringName
) -> int:
	if biome_id == &"burning_plains":
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

func _transition_colors_fade_outward(colors: PackedColorArray) -> bool:
	if colors.is_empty():
		return false
	var minimum_alpha := 1.0
	var maximum_alpha := 0.0
	for color in colors:
		minimum_alpha = minf(minimum_alpha, color.a)
		maximum_alpha = maxf(maximum_alpha, color.a)
	return minimum_alpha <= 0.001 and maximum_alpha >= 0.80

func _mesh_has_opaque_triangle_at(mesh: ArrayMesh, point: Vector2) -> bool:
	if mesh == null or mesh.get_surface_count() <= 0:
		return false
	var arrays := mesh.surface_get_arrays(0)
	var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector2Array
	var colors := arrays[Mesh.ARRAY_COLOR] as PackedColorArray
	var indices := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
	if colors.size() != vertices.size() or indices.size() % 3 != 0:
		return false
	for offset in range(0, indices.size(), 3):
		var index_a := indices[offset]
		var index_b := indices[offset + 1]
		var index_c := indices[offset + 2]
		if (
			colors[index_a].a < 0.99
			or colors[index_b].a < 0.99
			or colors[index_c].a < 0.99
		):
			continue
		var triangle := PackedVector2Array([
			vertices[index_a],
			vertices[index_b],
			vertices[index_c],
		])
		if Geometry2D.is_point_in_polygon(point, triangle):
			return true
	return false

func _concave_boundary_vertices(
	rects: Array[Rect2i],
	sides: Array[StringName],
	zone_size: Vector2i
) -> Array[Vector2i]:
	var unique := {}
	var runs: Array[Dictionary] = FALL_ZONE_BOUNDARY_RUNS_SCRIPT.build(
		rects,
		sides,
		zone_size
	)
	for run in runs:
		var orientation := StringName(run.get("orientation", &""))
		var boundary := int(run.get("boundary", 0))
		var start := int(run.get("start", 0))
		var end := int(run.get("end", 0))
		var start_vertex := (
			Vector2i(start, boundary)
			if orientation == FALL_ZONE_BOUNDARY_RUNS_SCRIPT.TOP
			or orientation == FALL_ZONE_BOUNDARY_RUNS_SCRIPT.BOTTOM
			else Vector2i(boundary, start)
		)
		var end_vertex := (
			Vector2i(end, boundary)
			if orientation == FALL_ZONE_BOUNDARY_RUNS_SCRIPT.TOP
			or orientation == FALL_ZONE_BOUNDARY_RUNS_SCRIPT.BOTTOM
			else Vector2i(boundary, end)
		)
		if StringName(run.get("start_corner", &"")) == FALL_ZONE_BOUNDARY_RUNS_SCRIPT.CORNER_CONCAVE:
			unique[start_vertex] = true
		if StringName(run.get("end_corner", &"")) == FALL_ZONE_BOUNDARY_RUNS_SCRIPT.CORNER_CONCAVE:
			unique[end_vertex] = true
	var result: Array[Vector2i] = []
	for vertex in unique:
		result.append(vertex as Vector2i)
	return result

func _mesh_vertex_occurrences(mesh: ArrayMesh, expected: Vector2) -> int:
	if mesh == null or mesh.get_surface_count() <= 0:
		return 0
	var arrays := mesh.surface_get_arrays(0)
	var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector2Array
	var count := 0
	for vertex in vertices:
		if vertex.is_equal_approx(expected):
			count += 1
	return count

func _mesh_uvs_match_at_vertex(mesh: ArrayMesh, expected: Vector2) -> bool:
	if mesh == null or mesh.get_surface_count() <= 0:
		return false
	var arrays := mesh.surface_get_arrays(0)
	var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector2Array
	var uvs := arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array
	var first_uv := Vector2.ZERO
	var matches := 0
	for index in range(vertices.size()):
		if not vertices[index].is_equal_approx(expected):
			continue
		if matches == 0:
			first_uv = uvs[index]
		elif not uvs[index].is_equal_approx(first_uv):
			return false
		matches += 1
	return matches >= 2

func _mesh_uses_planar_world_uv(mesh: ArrayMesh) -> bool:
	if mesh == null or mesh.get_surface_count() <= 0:
		return false
	var arrays := mesh.surface_get_arrays(0)
	var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector2Array
	var uvs := arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array
	if vertices.is_empty() or vertices.size() != uvs.size():
		return false
	for index in range(vertices.size()):
		var expected := (
			vertices[index]
			/ RectilinearCliffFaceMeshBuilder.TEXTURE_REPEAT_WORLD_SIZE
		)
		if not uvs[index].is_equal_approx(expected):
			return false
	return true

func _mesh_uses_flat_rock_planar_uv(mesh: ArrayMesh) -> bool:
	if mesh == null or mesh.get_surface_count() <= 0:
		return false
	var arrays := mesh.surface_get_arrays(0)
	var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector2Array
	var uvs := arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array
	if vertices.is_empty() or vertices.size() != uvs.size():
		return false
	for index in range(vertices.size()):
		var expected := (
			vertices[index]
			/ TopDownCliffBorderMeshBuilder.FLAT_ROCK_TEXTURE_REPEAT_WORLD_SIZE
		)
		if not uvs[index].is_equal_approx(expected):
			return false
	return true

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

func _image_rgb_difference_score(first: Image, second: Image) -> float:
	if first == null or second == null or first.is_empty() or second.is_empty():
		return 1.0
	if first.get_size() != second.get_size():
		return 1.0
	var step := maxi(mini(first.get_width(), first.get_height()) / 128, 1)
	var total := 0.0
	var samples := 0
	for y in range(0, first.get_height(), step):
		for x in range(0, first.get_width(), step):
			total += _rgb_delta(first.get_pixel(x, y), second.get_pixel(x, y))
			samples += 1
	return total / float(maxi(samples, 1))

func _vertical_texture_shadow_score(image: Image) -> float:
	if image == null or image.is_empty():
		return 1.0
	var width := image.get_width()
	var height := image.get_height()
	var band_height := mini(32, height / 4)
	var center_luma := _image_rect_luminance(
		image,
		Rect2i(0, height / 4, width, height / 2)
	)
	var top_luma := _image_rect_luminance(
		image,
		Rect2i(0, 0, width, band_height)
	)
	var bottom_luma := _image_rect_luminance(
		image,
		Rect2i(0, height - band_height, width, band_height)
	)
	return center_luma - (top_luma + bottom_luma) * 0.5

func _image_rect_luminance(image: Image, rect: Rect2i) -> float:
	var total := 0.0
	var samples := 0
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			total += image.get_pixel(x, y).get_luminance()
			samples += 1
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
	var edge_samples := 0
	var edge_matte_samples := 0
	var last_x := image.get_width() - 1
	var last_y := image.get_height() - 1
	for y in range(image.get_height()):
		if _is_visible_white_matte(image.get_pixel(0, y)):
			edge_matte_samples += 1
		if _is_visible_white_matte(image.get_pixel(last_x, y)):
			edge_matte_samples += 1
		edge_samples += 2
	for x in range(image.get_width()):
		if _is_visible_white_matte(image.get_pixel(x, 0)):
			edge_matte_samples += 1
		if _is_visible_white_matte(image.get_pixel(x, last_y)):
			edge_matte_samples += 1
		edge_samples += 2
	var edge_ratio := float(edge_matte_samples) / float(maxi(edge_samples, 1))
	# A matte is an anomalous white frame around darker art. Snow and other pale
	# opaque materials are allowed to reach the image boundary, so compare the
	# frame with a representative interior grid instead of treating white itself
	# as an error.
	var interior_samples := 0
	var interior_matte_samples := 0
	var inset_x := maxi(image.get_width() / 8, 1)
	var inset_y := maxi(image.get_height() / 8, 1)
	var step_x := maxi((image.get_width() - inset_x * 2) / 16, 1)
	var step_y := maxi((image.get_height() - inset_y * 2) / 16, 1)
	for y in range(inset_y, image.get_height() - inset_y, step_y):
		for x in range(inset_x, image.get_width() - inset_x, step_x):
			if _is_visible_white_matte(image.get_pixel(x, y)):
				interior_matte_samples += 1
			interior_samples += 1
	var interior_ratio := (
		float(interior_matte_samples) / float(maxi(interior_samples, 1))
	)
	return maxf(edge_ratio - interior_ratio, 0.0)

func _find_surface_material_id(
	layer: BiomeTileLayer,
	asset_fragment: String
) -> StringName:
	var paths := layer.get_forest_surface_art_asset_paths()
	for material_id in layer.get_loaded_surface_texture_ids():
		if String(paths.get(material_id, "")).contains(asset_fragment):
			return material_id
	return &""

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

func _solid_texture(color: Color) -> Texture2D:
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)
