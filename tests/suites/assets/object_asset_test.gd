extends GutTest
## Assets A4 — Asset degli object scenes (factory, texture runtime, integrazione).
##
## Migra: tests/milestone_10_object_asset_smoke_test.gd
## Verifica i contratti object_scenes, le silhouette runtime distinte via SVG
## loader, la factory che crea ogni ostacolo come EnvironmentObject con
## collisione/sort coerenti, l'integrazione con ObstacleSystem e la supply crate.

const REQUIRED_OBSTACLE_ASSET_IDS: Array[StringName] = [
	&"ruined_house", &"burned_house", &"snow_cabin", &"sunken_house", &"lab_block",
	&"abandoned_car", &"wood_barrier", &"lab_ruin", &"corroded_barrier",
	&"scorched_barricade", &"ice_rock", &"sunken_wreck",
	&"boundary_fence", &"toxic_boundary_wall", &"lava_boundary", &"ice_boundary", &"deep_water_boundary",
	&"industrial_fence", &"charred_wall", &"snow_wall", &"ash_barrier", &"pipe_stack",
	&"burned_car", &"ice_block", &"dead_tree", &"marsh_log", &"reed_wall",
	&"broken_walkway", &"toxic_barrel", &"chemical_barrel", &"broken_fence"
]
const GENERATED_PROP_ASSET_IDS: Array[StringName] = [
	&"ruined_house", &"abandoned_car", &"broken_fence", &"wood_barrier",
	&"lab_block", &"lab_ruin", &"pipe_stack", &"toxic_barrel",
	&"chemical_barrel", &"industrial_fence", &"corroded_barrier",
	&"burned_house", &"burned_car", &"charred_wall", &"scorched_barricade",
	&"snow_cabin", &"ice_rock", &"ice_block", &"snow_wall",
	&"sunken_house", &"sunken_wreck", &"dead_tree", &"marsh_log"
]
const INFECTED_PLAINS_RASTER_IDS: Array[StringName] = [
	&"small_rock", &"broken_fence", &"wood_barrier", &"ruined_house",
	&"abandoned_house", &"abandoned_car", &"dense_vegetation"
]
const INFECTED_PLAINS_RASTER_COLLIDER_IDS: Array[StringName] = [
	&"small_rock", &"broken_fence", &"wood_barrier", &"fallen_log",
	&"ruined_house", &"abandoned_house", &"abandoned_car", &"dense_vegetation"
]
const REQUIRED_CRATE_ASSET_ID := &"supply_crate"
const ENVIRONMENT_OBJECT_SCRIPT = preload("res://game/modes/zombie/environment_object.gd")
const ENVIRONMENT_OBJECT_FACTORY_SCRIPT = preload("res://game/modes/zombie/environment_object_factory.gd")
const SVG_TEXTURE_LOADER = preload("res://game/modes/zombie/environment_texture_loader.gd")
const SVG_FALLBACK_TEXTURE_BUILDER = preload(
	"res://game/modes/zombie/top_down_fallback_texture_builder.gd"
)

var _manifest: EnvironmentAssetManifest

func before_all() -> void:
	_manifest = EnvironmentAssetManifest.reload_shared()

func test_manifest_valid() -> void:
	assert_true(_manifest.load_error.is_empty(), "manifest loads")
	assert_true(bool(_manifest.validate().get("is_valid", false)), "manifest validates")
	assert_not_null(load("res://game/modes/zombie/environment_object.tscn") as PackedScene, "top-down environment object scene loads")

func test_asset_contract_coverage() -> void:
	for obstacle_id in REQUIRED_OBSTACLE_ASSET_IDS:
		assert_true(_manifest.has_asset_contract(&"object_scenes", obstacle_id), "%s has object_scenes contract" % String(obstacle_id))
		var contract := _manifest.get_object_asset_contract(obstacle_id)
		assert_true(_asset_exists(String(contract.get("asset_path", ""))), "%s asset path exists" % String(obstacle_id))
		assert_false(String(contract.get("asset_path", "")).is_empty(), "%s declares an asset path" % String(obstacle_id))
	var crate_contract := _manifest.get_object_asset_contract(REQUIRED_CRATE_ASSET_ID)
	assert_false(crate_contract.is_empty(), "supply_crate has object_scenes contract")
	assert_true(_asset_exists(String(crate_contract.get("asset_path", ""))), "supply_crate asset path exists")
	for crate_type in [&"common", &"medical"]:
		var crate_path := _manifest.get_object_asset_path(REQUIRED_CRATE_ASSET_ID, crate_type)
		assert_true(_asset_exists(crate_path), "supply_crate %s variant exists" % String(crate_type))
		assert_true(crate_path.ends_with(".png"), "supply_crate %s uses raster art" % String(crate_type))
	var plains_log_path := _manifest.get_object_asset_path(&"fallen_log", &"infected_plains")
	assert_true(_asset_exists(plains_log_path), "infected_plains fallen_log variant exists")
	assert_true(plains_log_path.ends_with(".png"), "infected_plains fallen_log uses raster art")
	assert_true(_manifest.get_object_asset_path(&"fallen_log").ends_with(".svg"), "other biomes keep fallen_log default until their art pass")

func test_runtime_texture_shapes() -> void:
	SVG_TEXTURE_LOADER.clear_cache()
	var house_contract := _manifest.get_object_asset_contract(&"ruined_house")
	var barrel_contract := _manifest.get_object_asset_contract(&"toxic_barrel")
	var lab_contract := _manifest.get_object_asset_contract(&"lab_ruin")
	var lab_block_contract := _manifest.get_object_asset_contract(&"lab_block")
	var reed_wall_contract := _manifest.get_object_asset_contract(&"reed_wall")
	var crate_contract := _manifest.get_object_asset_contract(&"supply_crate")
	var house_texture := SVG_TEXTURE_LOADER.load_texture(String(house_contract.get("asset_path", "")), Color(0.42, 0.38, 0.30, 1.0), Color(0.86, 0.68, 0.22, 1.0))
	var barrel_texture := SVG_TEXTURE_LOADER.load_texture(String(barrel_contract.get("asset_path", "")), Color(0.20, 0.52, 0.34, 1.0), Color(0.82, 0.96, 0.34, 1.0))
	var lab_texture := SVG_TEXTURE_LOADER.load_texture(String(lab_contract.get("asset_path", "")), Color(0.20, 0.52, 0.34, 1.0), Color(0.82, 0.96, 0.34, 1.0))
	var lab_block_texture := SVG_TEXTURE_LOADER.load_texture(String(lab_block_contract.get("asset_path", "")), Color(0.20, 0.52, 0.34, 1.0), Color(0.82, 0.96, 0.34, 1.0))
	var reed_wall_native_size := _manifest.get_native_visual_size(&"reed_wall")
	var reed_wall_texture := SVG_TEXTURE_LOADER.load_texture(
		String(reed_wall_contract.get("asset_path", "")),
		Color(0.21, 0.36, 0.35, 1.0),
		Color(0.76, 0.69, 0.44, 1.0),
		Vector2i(
			roundi(reed_wall_native_size.x),
			roundi(reed_wall_native_size.y)
		)
	)
	var crate_texture := SVG_TEXTURE_LOADER.load_texture(String(crate_contract.get("asset_path", "")), Color(0.20, 0.52, 0.34, 1.0), Color(0.82, 0.96, 0.34, 1.0))
	assert_not_null(house_texture, "ruined_house runtime texture loads")
	assert_not_null(barrel_texture, "toxic_barrel runtime texture loads")
	assert_not_null(lab_texture, "lab_ruin runtime texture loads")
	assert_not_null(lab_block_texture, "lab_block runtime texture loads")
	assert_not_null(reed_wall_texture, "reed_wall runtime texture loads")
	assert_not_null(crate_texture, "supply_crate runtime texture loads")
	if house_texture == null or barrel_texture == null or lab_texture == null or lab_block_texture == null or reed_wall_texture == null or crate_texture == null:
		return
	assert_gt(_alpha_mask_difference_score(house_texture, barrel_texture), 0.04, "ruined_house and toxic_barrel have distinct runtime silhouettes")
	assert_lt(
		_first_opaque_row_ratio(lab_texture),
		0.16,
		"lab_ruin has a tall asymmetric building silhouette"
	)
	assert_lt(
		_first_opaque_row_ratio(lab_block_texture),
		0.25,
		"lab_block reads as a tall building silhouette, not a crate"
	)
	assert_lt(
		_first_opaque_row_ratio(reed_wall_texture),
		0.12,
		"reed_wall uses the reserved vertical canvas instead of top padding"
	)
	assert_gt(
		_opaque_height_ratio(reed_wall_texture),
		0.78,
		"reed_wall keeps a substantial tall vegetation silhouette"
	)
	assert_gt(
		_first_opaque_row_ratio(crate_texture),
		0.10,
		"supply_crate keeps transparent breathing room above its raster"
	)
	assert_gt(
		_opaque_height_ratio(crate_texture),
		0.45,
		"supply_crate keeps a substantial readable top-down silhouette"
	)

func test_loader_fallback_shapes() -> void:
	var house_path := "user://environment_loader_house_test.svg"
	var barrel_path := "user://environment_loader_barrel_test.svg"
	assert_true(_write_test_svg(house_path, &"ruined_house") and _write_test_svg(barrel_path, &"toxic_barrel"), "temporary SVG fallback fixtures are writable")
	var house_texture := SVG_TEXTURE_LOADER.load_texture(house_path, Color(0.42, 0.38, 0.30, 1.0), Color(0.86, 0.68, 0.22, 1.0))
	var barrel_texture := SVG_TEXTURE_LOADER.load_texture(barrel_path, Color(0.20, 0.52, 0.34, 1.0), Color(0.82, 0.96, 0.34, 1.0))
	assert_not_null(house_texture, "house SVG fallback texture loads")
	assert_not_null(barrel_texture, "barrel SVG fallback texture loads")
	if house_texture == null or barrel_texture == null:
		return
	assert_gt(_alpha_mask_difference_score(house_texture, barrel_texture), 0.04, "SVG fallback produces object-specific silhouettes")
	var void_texture := SVG_FALLBACK_TEXTURE_BUILDER._build_void_texture(
		Vector2i(128, 128),
		Color(0.20, 0.24, 0.28, 1.0),
		Color(0.08, 0.10, 0.12, 0.9),
		Color(0.62, 0.72, 0.82, 1.0)
	)
	assert_not_null(void_texture, "cardinal void fallback texture builds")
	if void_texture != null:
		var void_image := void_texture.get_image()
		assert_gt(
			void_image.get_pixel(14, 38).a,
			0.5,
			"void fallback fills the corner of its axis-aligned rectangular surface"
		)

func test_factory_obstacle_coverage() -> void:
	var factory := ENVIRONMENT_OBJECT_FACTORY_SCRIPT.new(_manifest)
	for obstacle_id in REQUIRED_OBSTACLE_ASSET_IDS:
		var size := _size_for(obstacle_id)
		var shape_id := _layout_shape_for(obstacle_id)
		var obstacle := factory.create_obstacle(obstacle_id, size, shape_id, 0.0, Color(0.42, 0.38, 0.30, 1.0), Color(0.86, 0.68, 0.22, 1.0), _manifest.get_sort_offset(obstacle_id))
		assert_not_null(obstacle, "%s factory creates obstacle" % String(obstacle_id))
		if obstacle == null:
			continue
		add_child(obstacle)
		obstacle.global_position = Vector2(320.0, 240.0)
		await wait_physics_frames(1)
		assert_eq(obstacle.get_script(), ENVIRONMENT_OBJECT_SCRIPT, "%s uses EnvironmentObject scene path" % String(obstacle_id))
		if obstacle.get_script() == ENVIRONMENT_OBJECT_SCRIPT:
			if obstacle.is_perimeter_wall():
				assert_true(bool(obstacle.call("uses_procedural_fallback")), "%s uses the explicit tileable wall renderer" % String(obstacle_id))
			else:
				assert_true(bool(obstacle.call("has_asset_visual")), "%s has loaded asset-backed visual" % String(obstacle_id))
				assert_false(bool(obstacle.call("uses_procedural_fallback")), "%s does not use procedural fallback" % String(obstacle_id))
				assert_eq(String(obstacle.call("get_asset_path")), String(_manifest.get_object_asset_contract(obstacle_id).get("asset_path", "")), "%s sprite path comes from manifest" % String(obstacle_id))
			assert_true(obstacle.has_ground_shadow(), "%s keeps ground shadow contract" % String(obstacle_id))
			assert_eq(obstacle.get_obstacle_category(), _manifest.get_category(obstacle_id), "%s category comes from manifest" % String(obstacle_id))
			assert_false(obstacle.uses_generic_fallback(), "%s avoids generic visual fallback" % String(obstacle_id))
			if obstacle_id in [&"reed_wall", &"dead_tree"]:
				var native_object := obstacle as EnvironmentObject
				var native_size := _manifest.get_native_visual_size(obstacle_id)
				var expected_size := Vector2(
					roundi(native_size.x),
					roundi(native_size.y)
				)
				assert_eq(
					native_object.asset_sprite.texture.get_size(),
					expected_size,
					"%s rasterizes at its native canvas without letterboxing" % String(obstacle_id)
				)
				assert_eq(
					native_object.asset_sprite.scale,
					Vector2.ONE,
					"%s keeps the manifest visual size at runtime" % String(obstacle_id)
				)
			elif INFECTED_PLAINS_RASTER_IDS.has(obstacle_id):
				var raster_object := obstacle as EnvironmentObject
				assert_true(
					raster_object.get_asset_path().ends_with(".png"),
					"%s uses final infected-plains raster art" % String(obstacle_id)
				)
				assert_false(
					raster_object.asset_sprite.texture is AtlasTexture,
					"%s uses a direct raster instead of an atlas crop" % String(obstacle_id)
				)
			elif GENERATED_PROP_ASSET_IDS.has(obstacle_id):
				var generated_object := obstacle as EnvironmentObject
				assert_true(
					generated_object.get_asset_path().ends_with(".svg"),
					"%s uses its dedicated cardinal SVG at runtime" % String(obstacle_id)
				)
				assert_false(
					generated_object.asset_sprite.texture is AtlasTexture,
					"%s no longer consumes a legacy atlas crop" % String(obstacle_id)
				)
				var rendered_size := (
					generated_object.asset_sprite.texture.get_size()
					* generated_object.asset_sprite.scale.abs()
				)
				var target_size := _manifest.get_native_visual_size(obstacle_id)
				assert_gt(rendered_size.x, 8.0, "%s generated art remains visible" % String(obstacle_id))
				assert_gt(rendered_size.y, 8.0, "%s generated art keeps visible height" % String(obstacle_id))
				assert_lte(
					rendered_size.x,
					target_size.x + 0.1,
					"%s generated art fits its horizontal footprint contract" % String(obstacle_id)
				)
				assert_lte(
					rendered_size.y,
					target_size.y + 0.1,
					"%s generated art fits its vertical visual contract" % String(obstacle_id)
				)
		_check_collision_contract(obstacle_id, obstacle)
		obstacle.queue_free()
		await wait_physics_frames(1)

func test_obstacle_system_integration() -> void:
	var container := Node2D.new()
	container.name = "EnvironmentProps"
	add_child(container)
	var system := ObstacleSystem.new()
	system.environment_container_path = NodePath("../EnvironmentProps")
	container.add_sibling(system)
	await wait_physics_frames(1)

	var biome := load("res://game/modes/zombie/biomes/infected_plains.tres") as BiomeDefinition
	assert_not_null(biome, "infected_plains biome loads")
	if biome != null:
		system.start_run(biome)
		await wait_physics_frames(1)
		var active_obstacles := system.get_active_obstacles()
		assert_false(active_obstacles.is_empty(), "obstacle system spawns obstacles")
		for obstacle in active_obstacles:
			var biome_obstacle := obstacle as BiomeObstacle
			var obstacle_id := biome_obstacle.obstacle_id if biome_obstacle != null else &"unknown"
			assert_eq(obstacle.get_script(), ENVIRONMENT_OBJECT_SCRIPT, "%s obstacle system uses asset scene" % String(obstacle_id))
			if obstacle.get_script() != ENVIRONMENT_OBJECT_SCRIPT:
				continue
			if biome_obstacle != null and biome_obstacle.is_perimeter_wall():
				assert_true(bool(obstacle.call("uses_procedural_fallback")), "%s runtime wall uses its tileable renderer" % String(obstacle_id))
			else:
				assert_true(bool(obstacle.call("has_asset_visual")), "%s runtime obstacle has an asset-backed visual" % String(obstacle_id))
				assert_false(bool(obstacle.call("uses_procedural_fallback")), "%s runtime obstacle avoids procedural fallback" % String(obstacle_id))
			assert_true(obstacle.is_in_group("environment_obstacles"), "%s runtime obstacle keeps environment group" % String(obstacle_id))
			assert_true(obstacle.is_in_group("spawn_blockers"), "%s runtime obstacle keeps spawn blocker group" % String(obstacle_id))

	system.queue_free()
	container.queue_free()
	await wait_physics_frames(1)

func test_forest_tree_variation_is_visual_only() -> void:
	var factory := ENVIRONMENT_OBJECT_FACTORY_SCRIPT.new(_manifest)
	var tree_size := _size_for(&"forest_tree")
	var first := factory.create_obstacle(
		&"forest_tree",
		tree_size,
		&"rectangle",
		0.0,
		Color(0.28, 0.36, 0.18, 1.0),
		Color(0.72, 0.56, 0.18, 1.0),
		_manifest.get_sort_offset(&"forest_tree")
	)
	var second := factory.create_obstacle(
		&"forest_tree",
		tree_size,
		&"rectangle",
		0.0,
		Color(0.28, 0.36, 0.18, 1.0),
		Color(0.72, 0.56, 0.18, 1.0),
		_manifest.get_sort_offset(&"forest_tree")
	)
	assert_not_null(first, "first forest_tree creates")
	assert_not_null(second, "second forest_tree creates")
	if first == null or second == null:
		return
	var first_object := first as EnvironmentObject
	var second_object := second as EnvironmentObject
	assert_not_null(first_object, "first forest_tree uses top-down environment object")
	assert_not_null(second_object, "second forest_tree uses top-down environment object")
	if first_object == null or second_object == null:
		first.queue_free()
		second.queue_free()
		return
	add_child(first)
	add_child(second)
	first.global_position = Vector2(120.0, 180.0)
	second.global_position = Vector2(216.0, 180.0)
	await wait_physics_frames(2)

	assert_eq(first.obstacle_size, second.obstacle_size, "forest_tree visual variation keeps placement size")
	assert_eq(_manifest.get_visual_scale(&"forest_tree"), 2.0, "forest_tree doubles its manifest-driven visual size")
	assert_eq(first.get_collision_size(), Vector2(96.0, 96.0), "first tree uses the doubled root collider")
	assert_eq(second.get_collision_size(), Vector2(96.0, 96.0), "second tree uses the doubled root collider")
	assert_true(first.contains_global_position(first.to_global(first.get_collision_offset())), "first tree still blocks its roots")
	assert_true(second.contains_global_position(second.to_global(second.get_collision_offset())), "second tree still blocks its roots")
	assert_true(first_object.asset_sprite != null and second_object.asset_sprite != null, "forest_tree sprites are available")
	if first_object.asset_sprite != null and second_object.asset_sprite != null:
		assert_true(
			first_object.asset_sprite.flip_h != second_object.asset_sprite.flip_h
			or first_object.asset_sprite.modulate != second_object.asset_sprite.modulate,
			"forest_tree instances get visible flip/tint variation"
		)
	first.queue_free()
	second.queue_free()
	await wait_physics_frames(1)

func test_supply_crate_asset_visual() -> void:
	var crate_scene := load("res://game/drops/supply_crate.tscn") as PackedScene
	assert_not_null(crate_scene, "supply crate scene loads")
	if crate_scene == null:
		return
	var crate := crate_scene.instantiate() as SupplyCrate
	assert_not_null(crate, "supply crate instantiates")
	if crate == null:
		return
	add_child(crate)
	await wait_physics_frames(1)
	var visual := crate.get_node_or_null("Visual")
	assert_not_null(visual, "supply crate visual exists")
	if visual != null:
		assert_true(visual.has_method("has_asset_sprite") and bool(visual.call("has_asset_sprite")), "supply crate visual uses asset sprite")
		assert_true(visual.has_method("uses_procedural_fallback") and not bool(visual.call("uses_procedural_fallback")), "supply crate visual avoids procedural fallback")
		assert_eq(String(visual.call("get_asset_path")), String(_manifest.get_object_asset_contract(REQUIRED_CRATE_ASSET_ID).get("asset_path", "")), "supply crate visual path comes from manifest")
		visual.call("configure_crate_type", &"medical")
		assert_eq(
			String(visual.call("get_asset_path")),
			_manifest.get_object_asset_path(REQUIRED_CRATE_ASSET_ID, &"medical"),
			"medical crate selects its raster variant"
		)
		assert_true(bool(visual.call("has_asset_sprite")), "medical crate variant remains asset-backed")
	assert_eq(crate.collision_layer, 8, "supply crate collision layer unchanged")
	assert_eq(crate.collision_mask, 1, "supply crate collision mask unchanged")
	var shape := crate.get_node_or_null("CollisionShape2D") as CollisionShape2D
	assert_true(shape != null and shape.shape is RectangleShape2D, "supply crate keeps rectangle collision")
	if visual is SupplyCrateVisual and shape != null and shape.shape is RectangleShape2D:
		var crate_visual := visual as SupplyCrateVisual
		var collision_size := (shape.shape as RectangleShape2D).size
		for crate_type in [&"common", &"medical"]:
			crate_visual.configure_crate_type(crate_type)
			var visual_bounds := crate_visual.get_asset_visual_bounds()
			var collision_bounds := Rect2(-collision_size * 0.5, collision_size)
			assert_gte(
				visual_bounds.size.x + 0.25,
				collision_size.x,
				"%s crate art covers the hitbox width" % String(crate_type)
			)
			assert_gte(
				visual_bounds.size.y + 0.25,
				collision_size.y,
				"%s crate art covers the hitbox height" % String(crate_type)
			)
			assert_true(
				is_equal_approx(
					crate_visual.asset_sprite.scale.x,
					crate_visual.asset_sprite.scale.y
				),
				"%s crate preserves its source proportions" % String(crate_type)
			)
			_assert_visual_contains_hitbox(
				"%s crate" % String(crate_type),
				visual_bounds,
				collision_bounds
			)
	crate.queue_free()
	await wait_physics_frames(1)

func test_infected_plains_raster_art_covers_hitboxes_without_stretch() -> void:
	assert_eq(
		_manifest.get_visual_scale(&"fallen_log"),
		1.0,
		"shared fallen_log keeps its default SVG scale"
	)
	assert_eq(
		_manifest.get_object_visual_scale(&"fallen_log", &"infected_plains"),
		1.85,
		"infected-plains fallen_log uses only its raster-specific scale"
	)
	assert_eq(
		_manifest.get_object_visual_scale(&"fallen_log", &"frozen_outskirts"),
		1.0,
		"other biomes keep the shared fallen_log SVG scale"
	)
	var factory := ENVIRONMENT_OBJECT_FACTORY_SCRIPT.new(_manifest)
	for obstacle_id in INFECTED_PLAINS_RASTER_COLLIDER_IDS:
		var logical_footprint := WorldGridConfig.legacy_size_to_new_tiles(
			_manifest.get_footprint_tiles(obstacle_id)
		)
		var world_size := (
			Vector2(logical_footprint) * WorldGridConfig.LOGICAL_TILE_SCALE
		)
		var obstacle := factory.create_obstacle(
			obstacle_id,
			world_size,
			_manifest.get_collision_shape(obstacle_id),
			0.0,
			Color.WHITE,
			Color.WHITE,
			_manifest.get_sort_offset(obstacle_id),
			&"infected_plains"
		) as EnvironmentObject
		assert_not_null(obstacle, "%s raster obstacle builds" % String(obstacle_id))
		if obstacle == null:
			continue
		add_child(obstacle)
		await wait_physics_frames(1)
		var visual_bounds := obstacle.get_asset_visual_bounds()
		var collision_size := obstacle.get_collision_size()
		var collision_bounds := Rect2(
			obstacle.get_collision_offset() - collision_size * 0.5,
			collision_size
		)
		assert_gte(
			visual_bounds.size.x + 0.25,
			collision_size.x,
			"%s art covers the hitbox width" % String(obstacle_id)
		)
		assert_gte(
			visual_bounds.size.y + 0.25,
			collision_size.y,
			"%s art covers the hitbox height" % String(obstacle_id)
		)
		assert_true(
			is_equal_approx(
				obstacle.asset_sprite.scale.x,
				obstacle.asset_sprite.scale.y
			),
			"%s preserves its source proportions" % String(obstacle_id)
		)
		_assert_visual_contains_hitbox(
			String(obstacle_id),
			visual_bounds,
			collision_bounds
		)
		obstacle.queue_free()
		await wait_physics_frames(1)

func test_infected_plains_fallen_log_variant() -> void:
	var factory := ENVIRONMENT_OBJECT_FACTORY_SCRIPT.new(_manifest)
	var obstacle := factory.create_obstacle(
		&"fallen_log",
		Vector2(96.0, 32.0),
		&"rectangle",
		0.0,
		Color(0.38, 0.30, 0.16, 1.0),
		Color(0.74, 0.58, 0.16, 0.78),
		_manifest.get_sort_offset(&"fallen_log"),
		&"infected_plains"
	)
	assert_not_null(obstacle, "infected plains fallen log builds")
	if obstacle != null:
		add_child(obstacle)
		await wait_physics_frames(1)
		assert_eq(
			String(obstacle.call("get_asset_path")),
			_manifest.get_object_asset_path(&"fallen_log", &"infected_plains"),
			"fallen log resolves the biome-specific raster"
		)
		assert_true(bool(obstacle.call("has_asset_visual")), "fallen log raster loads")
		obstacle.queue_free()
		await wait_physics_frames(1)

func _assert_visual_contains_hitbox(
	label: String,
	visual_bounds: Rect2,
	collision_bounds: Rect2
) -> void:
	const EDGE_TOLERANCE := 0.05
	assert_lte(
		visual_bounds.position.x,
		collision_bounds.position.x + EDGE_TOLERANCE,
		"%s art reaches the hitbox left edge" % label
	)
	assert_lte(
		visual_bounds.position.y,
		collision_bounds.position.y + EDGE_TOLERANCE,
		"%s art reaches the hitbox top edge" % label
	)
	assert_gte(
		visual_bounds.end.x,
		collision_bounds.end.x - EDGE_TOLERANCE,
		"%s art reaches the hitbox right edge" % label
	)
	assert_gte(
		visual_bounds.end.y,
		collision_bounds.end.y - EDGE_TOLERANCE,
		"%s art reaches the hitbox bottom edge" % label
	)

# --- helper (porting dei test legacy) ---------------------------------------

func _check_collision_contract(obstacle_id: StringName, obstacle: BiomeObstacle) -> void:
	var expected_layer := 0
	if _manifest.blocks_movement(obstacle_id):
		expected_layer |= BiomeObstacle.MOVEMENT_BLOCK_LAYER_BIT
	if _manifest.blocks_projectiles(obstacle_id):
		expected_layer |= BiomeObstacle.PROJECTILE_BLOCK_LAYER_BIT
	assert_eq(obstacle.collision_layer, expected_layer, "%s collision layer matches movement/projectile contract" % String(obstacle_id))
	assert_eq(obstacle.collision_mask, 0, "%s collision mask remains passive environment" % String(obstacle_id))
	assert_true(is_equal_approx(obstacle.sort_offset, _manifest.get_sort_offset(obstacle_id)), "%s sort offset comes from manifest" % String(obstacle_id))
	assert_eq(obstacle.z_index, 0, "%s participates in Y-sort" % String(obstacle_id))
	var expects_collider_hit := _manifest.get_collision_shape(obstacle_id) != &"open"
	var collider_center := obstacle.to_global(obstacle.get_collision_offset())
	assert_eq(obstacle.contains_global_position(collider_center), expects_collider_hit, "%s collider-center containment matches collision shape" % String(obstacle_id))
	var shape := obstacle.get_node_or_null("CollisionShape2D") as CollisionShape2D
	assert_not_null(shape, "%s collision shape node exists" % String(obstacle_id))
	if shape == null:
		return
	assert_true(shape.position.is_equal_approx(obstacle.get_collision_offset()), "%s CollisionShape2D follows the manifest offset" % String(obstacle_id))
	match _manifest.get_collision_shape(obstacle_id):
		&"circle":
			assert_true(shape.shape is CircleShape2D, "%s uses circle collision" % String(obstacle_id))
			var circle := shape.shape as CircleShape2D
			assert_true(is_equal_approx(circle.radius, minf(obstacle.get_collision_size().x, obstacle.get_collision_size().y) * 0.5), "%s circle radius follows the manifest collision size" % String(obstacle_id))
		&"open":
			assert_true(shape.disabled, "%s disables open collision" % String(obstacle_id))
		_:
			assert_true(shape.shape is RectangleShape2D, "%s uses rectangle collision" % String(obstacle_id))

func _size_for(obstacle_id: StringName) -> Vector2:
	if obstacle_id == &"forest_tree":
		return Vector2(96.0, 96.0)
	if obstacle_id == &"dead_tree":
		return Vector2(48.0, 96.0)
	var footprint := _manifest.get_object_asset_contract(obstacle_id).get("footprint_tiles", Vector2i(6, 4)) as Vector2i
	return Vector2(maxf(float(footprint.x) * 8.0, 32.0), maxf(float(footprint.y) * 8.0, 28.0))

func _layout_shape_for(obstacle_id: StringName) -> StringName:
	return &"circle" if _manifest.get_collision_shape(obstacle_id) == &"circle" else &"rectangle"

func _asset_exists(asset_path: String) -> bool:
	if asset_path.is_empty():
		return false
	return ResourceLoader.exists(asset_path) or FileAccess.file_exists(asset_path)

func _write_test_svg(path: String, asset_id: StringName) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"160\" height=\"120\" "
		+ "viewBox=\"0 0 160 120\" data-section=\"object_scenes\" data-id=\"%s\">"
		+ "<rect width=\"160\" height=\"120\" fill=\"#4f5a61\"/>"
		+ "<rect x=\"20\" y=\"20\" width=\"120\" height=\"80\" fill=\"#b98238\"/>"
		+ "<path d=\"M20 80 L80 35 L140 80\" fill=\"#222831\"/>"
		+ "</svg>") % String(asset_id))
	file.close()
	return FileAccess.file_exists(path)

func _alpha_mask_difference_score(texture_a: Texture2D, texture_b: Texture2D) -> float:
	if texture_a == null or texture_b == null:
		return 0.0
	var image_a := texture_a.get_image()
	var image_b := texture_b.get_image()
	if image_a == null or image_b == null:
		return 0.0
	var width := mini(image_a.get_width(), image_b.get_width())
	var height := mini(image_a.get_height(), image_b.get_height())
	if width <= 0 or height <= 0:
		return 0.0
	var step_x := maxi(int(width / 48), 1)
	var step_y := maxi(int(height / 36), 1)
	var changed := 0
	var samples := 0
	for y in range(0, height, step_y):
		for x in range(0, width, step_x):
			if (image_a.get_pixel(x, y).a > 0.08) != (image_b.get_pixel(x, y).a > 0.08):
				changed += 1
			samples += 1
	if samples <= 0:
		return 0.0
	return float(changed) / float(samples)

func _first_opaque_row_ratio(texture: Texture2D) -> float:
	if texture == null:
		return 1.0
	var image := texture.get_image()
	if image == null or image.get_height() <= 0:
		return 1.0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.08:
				return float(y) / float(image.get_height())
	return 1.0

func _opaque_height_ratio(texture: Texture2D) -> float:
	if texture == null:
		return 0.0
	var image := texture.get_image()
	if image == null or image.get_height() <= 0:
		return 0.0
	var first_opaque_row := image.get_height()
	var last_opaque_row := -1
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a <= 0.08:
				continue
			first_opaque_row = mini(first_opaque_row, y)
			last_opaque_row = maxi(last_opaque_row, y)
			break
	if last_opaque_row < first_opaque_row:
		return 0.0
	return float(last_opaque_row - first_opaque_row + 1) / float(image.get_height())
