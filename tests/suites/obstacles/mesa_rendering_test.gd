extends GutTest
## Shared mesa renderer: one raised mesh owner plus one collision-only blocker.

const WorldGridConfig = preload("res://game/core/world_grid_config.gd")

const BIOME_PROFILES: Dictionary = {
	&"infected_plains": &"forest",
	&"toxic_wastes": &"urban_ruins",
	&"burning_fields": &"volcanic",
	&"frozen_outskirts": &"frozen_tundra",
	&"drowned_marsh": &"swamp",
}
const PROFILE_TOP_REPEAT: Dictionary = {
	&"forest": BiomeTileLayer.FOREST_SURFACE_TEXTURE_WORLD_SIZE,
	&"urban_ruins": BiomeTileLayer.TOXIC_SURFACE_TEXTURE_WORLD_SIZE,
	&"volcanic": BiomeTileLayer.BURNING_SURFACE_TEXTURE_WORLD_SIZE,
	&"frozen_tundra": BiomeTileLayer.FROZEN_GROUND_TEXTURE_WORLD_SIZE,
	&"swamp": BiomeTileLayer.MARSH_GROUND_TEXTURE_WORLD_SIZE,
}
const MESA_RECT := Rect2i(Vector2i(5, 5), Vector2i(6, 5))

var _manifest: EnvironmentAssetManifest

func before_all() -> void:
	_manifest = EnvironmentAssetManifest.reload_shared()

func after_all() -> void:
	_manifest = null
	EnvironmentAssetManifest.clear_shared()
	EnvironmentObject.clear_content_metrics_cache()

func test_all_biomes_render_one_themed_mesa_volume() -> void:
	for biome_id_value in BIOME_PROFILES:
		var biome_id := StringName(biome_id_value)
		var profile_id := StringName(BIOME_PROFILES[biome_id])
		var layout := _mesa_layout(profile_id)
		var layer := BiomeTileLayer.new()
		layer.configure(
			layout,
			_load_palette(biome_id),
			biome_id,
			&"performance",
			16,
			null,
			_manifest,
			false
		)
		assert_true(
			layer.has_mesa_area_art(),
			"%s renders its mesa as a raised textured volume" % String(biome_id)
		)
		var counts := layer.get_mesa_area_counts()
		assert_eq(int(counts.get("areas", 0)), 1, "%s draws one crown" % String(biome_id))
		assert_eq(int(counts.get("faces", 0)), 3, "%s draws three visible faces" % String(biome_id))
		assert_eq(int(counts.get("profiles", 0)), 1, "%s uses one theme batch" % String(biome_id))
		assert_eq(int(counts.get("profile_mismatches", -1)), 0, "%s keeps profile arrays aligned" % String(biome_id))
		var report := layer.get_mesa_profile_render_report()
		assert_true(report.has(profile_id), "%s reports the requested mesa profile" % String(biome_id))
		var profile_report := report.get(profile_id, {}) as Dictionary
		assert_true(bool(profile_report.get("has_top_texture", false)), "%s loads the mesa top role" % String(biome_id))
		assert_true(bool(profile_report.get("has_face_texture", false)), "%s loads the mesa face role" % String(biome_id))
		assert_eq(
			float(profile_report.get("top_texture_repeat_world_size", 0.0)),
			float(PROFILE_TOP_REPEAT[profile_id]),
			"%s crown keeps the terrain material world scale" % String(biome_id)
		)
		var paths := profile_report.get("asset_paths", {}) as Dictionary
		_expect_profile_paths(profile_id, paths)
		layer.free()

func test_advanced_legacy_mass_is_not_promoted_to_a_mesa() -> void:
	var layout := BiomeEnvironmentLayout.new()
	layout.zone_size = Vector2i(16, 16)
	layout.generation_seed = 941
	layout.add_floor_rect(Rect2i(Vector2i.ZERO, layout.zone_size), &"open_block")
	layout.rock_rects.append(MESA_RECT)
	layout.rebuild_terrain_classification()
	var layer := BiomeTileLayer.new()
	layer.configure(
		layout,
		_load_palette(&"toxic_wastes"),
		&"toxic_wastes",
		&"performance",
		16,
		null,
		_manifest,
		false
	)
	assert_false(
		layer.has_mesa_area_art(),
		"advanced legacy rock_rects remain generic masses, not accidental mesas"
	)
	assert_eq(int(layer.get_mesa_area_counts().get("areas", -1)), 0, "no duplicate legacy cap is emitted")
	layer.free()

func test_large_rock_is_collision_only_for_shared_mesa_visuals() -> void:
	var system := ObstacleSystem.new()
	add_child(system)
	await wait_physics_frames(1)
	var size := Vector2(MESA_RECT.size) * WorldGridConfig.LOGICAL_TILE_SCALE
	var blocker := system.create_obstacle_instance(
		&"large_rock",
		size,
		&"rectangle",
		0.0,
		Color(0.3, 0.3, 0.3),
		Color(0.6, 0.6, 0.6)
	)
	assert_not_null(blocker, "the shared mesa keeps a technical blocker")
	if blocker != null:
		system.add_child(blocker)
		await wait_physics_frames(1)
		assert_true(bool(blocker.call("uses_tile_layer_mesa_visual")), "the blocker delegates visual authority to BiomeTileLayer")
		assert_false(bool(blocker.call("has_asset_sprite")), "the blocker does not duplicate the mesa crown")
		assert_true(bool(blocker.call("is_footprint_contract_aligned")), "the scalable collision follows the mesa rect")
		blocker.queue_free()
		await wait_physics_frames(1)
	system.queue_free()
	await wait_physics_frames(1)

func test_generated_mesa_draw_callback_is_runtime_safe() -> void:
	var layer := BiomeTileLayer.new()
	add_child(layer)
	layer.configure(
		_mesa_layout(&"urban_ruins"),
		_load_palette(&"toxic_wastes"),
		&"toxic_wastes",
		&"performance",
		16,
		null,
		_manifest,
		false
	)
	await wait_process_frames(2)
	assert_true(layer.is_visible_in_tree(), "the generated mesa reaches the canvas draw callback")
	assert_true(layer.has_mesa_area_art(), "the draw callback owns one themed mesa batch")
	layer.queue_free()
	await wait_physics_frames(1)

func _mesa_layout(profile_id: StringName) -> BiomeEnvironmentLayout:
	var layout := BiomeEnvironmentLayout.new()
	layout.zone_size = Vector2i(16, 16)
	layout.generation_seed = 441902
	layout.add_floor_rect(Rect2i(Vector2i.ZERO, layout.zone_size), &"open_block")
	layout.mesa_rects.append(MESA_RECT)
	layout.mesa_profile_ids.append(profile_id)
	layout.obstacle_rects.append(MESA_RECT)
	layout.obstacle_ids.append(&"large_rock")
	layout.obstacle_positions.append(layout.rect_center_to_world(MESA_RECT))
	layout.obstacle_sizes.append(layout.rect_size_to_world(MESA_RECT))
	layout.obstacle_rotations.append(0.0)
	layout.obstacle_shape_ids.append(&"rectangle")
	layout.rebuild_terrain_classification()
	return layout

func _load_palette(biome_id: StringName) -> BiomePalette:
	return load(
		"res://game/modes/zombie/biomes/%s_palette.tres" % String(biome_id)
	) as BiomePalette

func _expect_profile_paths(profile_id: StringName, paths: Dictionary) -> void:
	var top_path := String(paths.get(&"top", ""))
	var face_path := String(paths.get(&"face", ""))
	assert_false(top_path.is_empty(), "%s mesa has a top asset" % String(profile_id))
	assert_false(face_path.is_empty(), "%s mesa has a face asset" % String(profile_id))
	assert_true(FileAccess.file_exists(top_path), "%s mesa top exists" % String(profile_id))
	assert_true(FileAccess.file_exists(face_path), "%s mesa face exists" % String(profile_id))
	if profile_id == &"forest":
		assert_eq(StringName(paths.get(&"top_role", &"")), &"large_rock", "forest crown preserves its dedicated object role")
		assert_eq(StringName(paths.get(&"face_role", &"")), &"rock_cliff_face_texture", "forest wall preserves its dedicated void role")
		assert_true(top_path.ends_with("rock_plateau_top_generated.png"), "forest preserves its dedicated plateau crown")
		assert_true(face_path.ends_with("rock_cliff_face_upward_generated.png"), "forest preserves its dedicated upward wall")
		return
	assert_eq(StringName(paths.get(&"top_role", &"")), BiomeGeneratedArtCatalog.ROLE_GROUND, "%s crown consumes the ground role" % String(profile_id))
	assert_eq(StringName(paths.get(&"face_role", &"")), BiomeGeneratedArtCatalog.ROLE_CLIFF_FACE, "%s wall consumes the cliff-face role" % String(profile_id))
	assert_true(top_path.contains("/terrain/%s/" % String(profile_id)), "%s top uses the existing ground role" % String(profile_id))
	assert_true(face_path.contains("/cliff/%s/" % String(profile_id)), "%s wall uses the existing cliff-face role" % String(profile_id))
