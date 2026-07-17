extends GutTest
## Runtime mesa contract: each blocker owns one local Y-sorted raised mesh.

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

func test_odd_zone_mesa_centers_preserve_half_tile_precision() -> void:
	var layout := BiomeEnvironmentLayout.new()
	layout.zone_size = Vector2i(75, 75)
	layout.logical_tile_scale = 48.0
	var sentinels: Array[Dictionary] = [
		{
			"rect": Rect2i(Vector2i(10, 10), Vector2i(3, 3)),
			"expected": Vector2(-1248.0, -1248.0),
		},
		{
			"rect": Rect2i(Vector2i(10, 10), Vector2i(4, 4)),
			"expected": Vector2(-1224.0, -1224.0),
		},
		{
			"rect": Rect2i(Vector2i(10, 10), Vector2i(5, 5)),
			"expected": Vector2(-1200.0, -1200.0),
		},
	]
	for sentinel in sentinels:
		var rect := sentinel["rect"] as Rect2i
		var expected := sentinel["expected"] as Vector2
		assert_true(
			layout.rect_geometric_center_to_world(rect).is_equal_approx(expected),
			"%dx%d mesa center matches independently calculated mesh coordinates"
			% [rect.size.x, rect.size.y]
		)

func test_all_biomes_render_one_themed_y_sorted_mesa_volume() -> void:
	var system := ObstacleSystem.new()
	add_child(system)
	await wait_process_frames(1)
	for biome_id_value in BIOME_PROFILES:
		var biome_id := StringName(biome_id_value)
		var profile_id := StringName(BIOME_PROFILES[biome_id])
		var layout := _mesa_layout(profile_id)
		var palette := _load_palette(biome_id)
		var layer := BiomeTileLayer.new()
		layer.configure(
			layout,
			palette,
			biome_id,
			&"performance",
			16,
			null,
			_manifest,
			false
		)
		assert_true(
			layer.has_mesa_area_art(),
			"%s keeps mesa geometry metadata for validation" % String(biome_id)
		)
		assert_false(
			layer.renders_mesa_area_batch(),
			"%s does not draw a terrain-layer mesa batch" % String(biome_id)
		)
		var counts := layer.get_mesa_area_counts()
		assert_eq(int(counts.get("areas", 0)), 1, "%s reports one crown" % String(biome_id))
		assert_eq(int(counts.get("faces", 0)), 17, "%s reports rounded visible wall segments" % String(biome_id))
		assert_eq(int(counts.get("profiles", 0)), 1, "%s reports one theme" % String(biome_id))
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

		var blocker := system.create_obstacle_instance(
			&"large_rock",
			layout.obstacle_sizes[0],
			layout.obstacle_shape_ids[0],
			layout.obstacle_rotations[0],
			Color(0.3, 0.3, 0.3),
			Color(0.6, 0.6, 0.6)
		) as EnvironmentObject
		assert_not_null(blocker, "%s creates its mesa blocker" % String(biome_id))
		if blocker != null:
			var sort_anchor := ObstacleSystem.attach_obstacle_at_layout_center(
				system,
				blocker,
				layout.obstacle_positions[0]
			)
			ObstacleSystem.configure_mesa_obstacle_visual(
				blocker,
				layout,
				0,
				biome_id,
				palette
			)
			await wait_process_frames(1)
			assert_not_null(sort_anchor, "%s owns a Y-sort anchor" % String(biome_id))
			assert_true(
				sort_anchor != null and sort_anchor.has_meta(ObstacleSystem.SORT_ANCHOR_META),
				"%s uses the obstacle sort-wrapper contract" % String(biome_id)
			)
			assert_eq(blocker.get_render_mode(), &"y_sorted_mesa", "%s uses the local mesa render mode" % String(biome_id))
			assert_true(blocker.has_mesa_visual(), "%s blocker owns its raised visual" % String(biome_id))
			assert_false(blocker.has_asset_sprite(), "%s does not duplicate the crown as a sprite" % String(biome_id))
			assert_eq(blocker.get_mesa_profile_id(), profile_id, "%s resolves the requested profile" % String(biome_id))
			var blocker_counts := blocker.get_mesa_geometry_counts()
			assert_eq(int(blocker_counts.get("areas", 0)), 1, "%s blocker owns one crown" % String(biome_id))
			assert_eq(int(blocker_counts.get("faces", 0)), 17, "%s blocker owns rounded wall segments" % String(biome_id))
			assert_eq(
				float(blocker_counts.get("top_texture_repeat_world_size", 0.0)),
				float(PROFILE_TOP_REPEAT[profile_id]),
				"%s local crown keeps the terrain material world scale" % String(biome_id)
			)
			_expect_profile_paths(profile_id, blocker.get_mesa_art_asset_paths())
			_assert_mesa_collision_visual_alignment(
				blocker,
				layout.obstacle_positions[0],
				layout.obstacle_sizes[0],
				String(biome_id)
			)
			if sort_anchor != null:
				sort_anchor.queue_free()
		layer.free()
	await wait_physics_frames(1)
	system.queue_free()
	await wait_physics_frames(1)

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
	assert_false(layer.renders_mesa_area_batch(), "the legacy terrain layer draws no mesa batch")
	assert_eq(int(layer.get_mesa_area_counts().get("areas", -1)), 0, "no duplicate legacy cap is emitted")
	layer.free()

func test_large_rock_collision_and_local_visual_share_the_layout_center() -> void:
	var system := ObstacleSystem.new()
	add_child(system)
	await wait_physics_frames(1)
	var layout := _mesa_layout(&"forest")
	var size := layout.obstacle_sizes[0]
	var layout_center := layout.obstacle_positions[0]
	var blocker := system.create_obstacle_instance(
		&"large_rock",
		size,
		&"rectangle",
		0.37,
		Color(0.3, 0.3, 0.3),
		Color(0.6, 0.6, 0.6)
	) as EnvironmentObject
	assert_not_null(blocker, "the mesa creates one physical and visual owner")
	if blocker != null:
		var sort_anchor := ObstacleSystem.attach_obstacle_at_layout_center(
			system,
			blocker,
			layout_center
		)
		ObstacleSystem.configure_mesa_obstacle_visual(
			blocker,
			layout,
			0,
			&"infected_plains",
			_load_palette(&"infected_plains")
		)
		await wait_process_frames(1)
		assert_true(blocker.has_mesa_visual(), "the blocker owns the themed raised mesh")
		assert_true(blocker.uses_mesa_visual(), "the local visual contract is active")
		assert_eq(
			blocker.texture_repeat,
			CanvasItem.TEXTURE_REPEAT_ENABLED,
			"world-space mesa UVs repeat instead of stretching their edge pixels"
		)
		assert_false(blocker.has_asset_sprite(), "the mesh is not duplicated by a crown sprite")
		assert_true(blocker.is_footprint_contract_aligned(), "the scalable collision follows the mesa rect")
		assert_almost_eq(blocker.rotation, 0.0, 0.0001, "stale generator rotations are cardinal-locked")
		assert_true(bool(blocker.get_meta("cardinal_rotation_locked", false)), "the cardinal lock is diagnostic")
		_assert_mesa_collision_visual_alignment(blocker, layout_center, size, "forest")
		assert_not_null(sort_anchor, "the mesa has a sort wrapper")
		if sort_anchor != null:
			assert_almost_eq(
				blocker.get_cliff_sort_line_y(),
				sort_anchor.global_position.y,
				0.0001,
				"front/back perspective pivots on the mesa base line"
			)
			sort_anchor.queue_free()
		await wait_physics_frames(1)
	system.queue_free()
	await wait_physics_frames(1)

func test_player_shadow_touches_mesa_north_and_south_edges() -> void:
	var system := ObstacleSystem.new()
	add_child(system)
	var layout := _mesa_layout(&"forest")
	var blocker := system.create_obstacle_instance(
		&"large_rock",
		layout.obstacle_sizes[0],
		layout.obstacle_shape_ids[0],
		0.0,
		Color(0.3, 0.3, 0.3),
		Color(0.6, 0.6, 0.6)
	) as EnvironmentObject
	assert_not_null(blocker, "the contact test creates a mesa blocker")
	var sort_anchor: Node2D = null
	if blocker != null:
		sort_anchor = ObstacleSystem.attach_obstacle_at_layout_center(
			system,
			blocker,
			layout.obstacle_positions[0]
		)
	var player_scene := load("res://game/player/player.tscn") as PackedScene
	var player := player_scene.instantiate() as PlayerController
	add_child(player)
	await wait_physics_frames(1)
	var player_collision := player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var player_rectangle := (
		player_collision.shape as RectangleShape2D
		if player_collision != null
		else null
	)
	assert_not_null(player_rectangle, "player uses a ground-contact rectangle")
	assert_true(
		player_collision != null
		and player_collision.position.is_equal_approx(PlayerVisual.GROUND_SHADOW_CENTER),
		"player collider is centered on the visible ground shadow"
	)
	assert_true(
		player_rectangle != null
		and player_rectangle.size.is_equal_approx(PlayerVisual.GROUND_COLLIDER_SIZE),
		"player collider keeps the existing lateral clearance and the shadow vertical span"
	)
	if blocker != null and player_rectangle != null:
		var mesa_center := layout.obstacle_positions[0]
		var mesa_half_height := layout.obstacle_sizes[0].y * 0.5
		var shadow_top := (
			PlayerVisual.GROUND_SHADOW_CENTER.y
			- PlayerVisual.GROUND_SHADOW_RADIUS.y
		)
		var shadow_bottom := (
			PlayerVisual.GROUND_SHADOW_CENTER.y
			+ PlayerVisual.GROUND_SHADOW_RADIUS.y
		)
		player.global_position = mesa_center + Vector2(0.0, mesa_half_height + 96.0)
		await wait_physics_frames(1)
		var south_collision := player.move_and_collide(Vector2(0.0, -192.0))
		assert_not_null(south_collision, "player reaches the mesa from the south")
		assert_almost_eq(
			player.global_position.y + shadow_top,
			mesa_center.y + mesa_half_height,
			0.3,
			"shadow north edge touches the mesa south base without a gap"
		)
		player.global_position = mesa_center - Vector2(0.0, mesa_half_height + 96.0)
		await wait_physics_frames(1)
		var north_collision := player.move_and_collide(Vector2(0.0, 192.0))
		assert_not_null(north_collision, "player reaches the mesa from the north")
		assert_almost_eq(
			player.global_position.y + shadow_bottom,
			mesa_center.y - mesa_half_height,
			0.3,
			"shadow south edge touches the mesa north base without penetrating it"
		)
	player.queue_free()
	if sort_anchor != null:
		sort_anchor.queue_free()
	system.queue_free()
	await wait_physics_frames(1)

func test_y_sorted_mesa_draw_callback_is_runtime_safe() -> void:
	var layout := _mesa_layout(&"urban_ruins")
	var palette := _load_palette(&"toxic_wastes")
	var layer := BiomeTileLayer.new()
	add_child(layer)
	layer.configure(
		layout,
		palette,
		&"toxic_wastes",
		&"performance",
		16,
		null,
		_manifest,
		false
	)
	var system := ObstacleSystem.new()
	add_child(system)
	var blocker := system.create_obstacle_instance(
		&"large_rock",
		layout.obstacle_sizes[0],
		layout.obstacle_shape_ids[0],
		layout.obstacle_rotations[0],
		Color(0.3, 0.3, 0.3),
		Color(0.6, 0.6, 0.6)
	) as EnvironmentObject
	assert_not_null(blocker, "the runtime-safe draw test creates a mesa")
	var sort_anchor: Node2D = null
	if blocker != null:
		sort_anchor = ObstacleSystem.attach_obstacle_at_layout_center(
			system,
			blocker,
			layout.obstacle_positions[0]
		)
		ObstacleSystem.configure_mesa_obstacle_visual(
			blocker,
			layout,
			0,
			&"toxic_wastes",
			palette
		)
	await wait_process_frames(2)
	assert_true(layer.is_visible_in_tree(), "the terrain layer remains canvas-safe")
	assert_false(layer.renders_mesa_area_batch(), "the terrain draw callback skips mesa geometry")
	if blocker != null:
		assert_true(blocker.is_visible_in_tree(), "the Y-sorted blocker reaches the canvas draw callback")
		assert_true(blocker.has_mesa_visual(), "the blocker draw callback owns one themed mesa")
	if sort_anchor != null:
		sort_anchor.queue_free()
	system.queue_free()
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
	layout.obstacle_positions.append(
		layout.obstacle_rect_center_to_world(MESA_RECT, &"large_rock")
	)
	layout.obstacle_sizes.append(layout.rect_size_to_world(MESA_RECT))
	layout.obstacle_rotations.append(0.0)
	layout.obstacle_shape_ids.append(&"rectangle")
	layout.rebuild_terrain_classification()
	return layout

func _load_palette(biome_id: StringName) -> BiomePalette:
	return load(
		"res://game/modes/zombie/biomes/%s_palette.tres" % String(biome_id)
	) as BiomePalette

func _assert_mesa_collision_visual_alignment(
	blocker: EnvironmentObject,
	layout_center: Vector2,
	expected_size: Vector2,
	context: String
) -> void:
	assert_true(
		blocker.global_position.is_equal_approx(layout_center),
		"%s visual owner remains on the authoritative layout center" % context
	)
	assert_true(
		blocker.get_collision_size().is_equal_approx(expected_size),
		"%s collision rectangle has the exact mesa visual base size" % context
	)
	assert_true(
		blocker.get_collision_offset().is_zero_approx(),
		"%s collision and local mesh share the same origin" % context
	)
	assert_true(
		blocker.contains_global_position(layout_center),
		"%s layout center is blocked" % context
	)
	assert_false(
		blocker.contains_global_position(
			layout_center + Vector2(expected_size.x * 0.5 + 1.0, 0.0)
		),
		"%s collision ends at the visible mesa base edge" % context
	)
	var collision_node := blocker.get_node_or_null("CollisionShape2D") as CollisionShape2D
	assert_not_null(collision_node, "%s owns a physical collision node" % context)
	if collision_node == null:
		return
	var rectangle := collision_node.shape as RectangleShape2D
	assert_not_null(rectangle, "%s uses a cardinal rectangle collider" % context)
	if rectangle != null:
		assert_true(
			rectangle.size.is_equal_approx(expected_size),
			"%s physical shape matches the raised mesh footprint" % context
		)

func _expect_profile_paths(profile_id: StringName, paths: Dictionary) -> void:
	var top_path := String(paths.get(&"top", ""))
	var face_path := String(paths.get(&"face", ""))
	assert_false(top_path.is_empty(), "%s mesa has a top asset" % String(profile_id))
	assert_false(face_path.is_empty(), "%s mesa has a face asset" % String(profile_id))
	assert_true(FileAccess.file_exists(top_path), "%s mesa top exists" % String(profile_id))
	assert_true(FileAccess.file_exists(face_path), "%s mesa face exists" % String(profile_id))
	if profile_id == &"forest":
		if paths.has(&"top_role"):
			assert_eq(StringName(paths.get(&"top_role", &"")), &"large_rock", "forest crown preserves its dedicated object role")
		if paths.has(&"face_role"):
			assert_eq(StringName(paths.get(&"face_role", &"")), &"rock_cliff_face_texture", "forest wall preserves its dedicated void role")
		assert_true(top_path.ends_with("rock_plateau_top_generated.png"), "forest preserves its dedicated plateau crown")
		assert_true(face_path.ends_with("rock_cliff_face_upward_generated.png"), "forest preserves its dedicated upward wall")
		return
	if paths.has(&"top_role"):
		assert_eq(StringName(paths.get(&"top_role", &"")), BiomeGeneratedArtCatalog.ROLE_GROUND, "%s crown consumes the ground role" % String(profile_id))
	if paths.has(&"face_role"):
		assert_eq(StringName(paths.get(&"face_role", &"")), BiomeGeneratedArtCatalog.ROLE_CLIFF_FACE, "%s wall consumes the cliff-face role" % String(profile_id))
	assert_true(top_path.contains("/terrain/%s/" % String(profile_id)), "%s top uses the existing ground role" % String(profile_id))
	assert_true(face_path.contains("/cliff/%s/" % String(profile_id)), "%s wall uses the existing cliff-face role" % String(profile_id))
