extends GutTest
## Assets A4 — Asset degli object scenes (factory, texture runtime, integrazione).
##
## Migra: tests/milestone_10_object_asset_smoke_test.gd
## Verifica i contratti object_scenes, le silhouette runtime distinte via SVG
## loader, la factory che crea ogni ostacolo come IsometricEnvironmentObject con
## collisione/sort coerenti, l'integrazione con ObstacleSystem e la supply crate.

const REQUIRED_OBSTACLE_ASSET_IDS: Array[StringName] = [
	&"ruined_house", &"burned_house", &"snow_cabin", &"sunken_house", &"lab_block",
	&"boundary_fence", &"toxic_boundary_wall", &"lava_boundary", &"ice_boundary", &"deep_water_boundary",
	&"industrial_fence", &"charred_wall", &"snow_wall", &"ash_barrier", &"pipe_stack",
	&"burned_car", &"ice_block", &"dead_tree", &"marsh_log", &"broken_walkway", &"toxic_barrel", &"chemical_barrel"
]
const REQUIRED_CRATE_ASSET_ID := &"supply_crate"
const ISOMETRIC_OBJECT_SCRIPT = preload("res://game/modes/zombie/isometric_environment_object.gd")
const ISOMETRIC_OBJECT_FACTORY_SCRIPT = preload("res://game/modes/zombie/isometric_environment_object_factory.gd")
const SVG_TEXTURE_LOADER = preload("res://game/modes/zombie/isometric_svg_texture_loader.gd")

var _manifest: IsometricEnvironmentManifest

func before_all() -> void:
	_manifest = IsometricEnvironmentManifest.reload_shared()

func test_manifest_valid() -> void:
	assert_true(_manifest.load_error.is_empty(), "manifest loads")
	assert_true(bool(_manifest.validate().get("is_valid", false)), "manifest validates")
	assert_not_null(load("res://game/modes/zombie/isometric_environment_object.tscn") as PackedScene, "isometric environment object scene loads")

func test_asset_contract_coverage() -> void:
	for obstacle_id in REQUIRED_OBSTACLE_ASSET_IDS:
		assert_true(_manifest.has_asset_contract(&"object_scenes", obstacle_id), "%s has object_scenes contract" % String(obstacle_id))
		var contract := _manifest.get_object_asset_contract(obstacle_id)
		assert_true(_asset_exists(String(contract.get("asset_path", ""))), "%s asset path exists" % String(obstacle_id))
		assert_false(String(contract.get("asset_path", "")).is_empty(), "%s declares an asset path" % String(obstacle_id))
	var crate_contract := _manifest.get_object_asset_contract(REQUIRED_CRATE_ASSET_ID)
	assert_false(crate_contract.is_empty(), "supply_crate has object_scenes contract")
	assert_true(_asset_exists(String(crate_contract.get("asset_path", ""))), "supply_crate asset path exists")

func test_runtime_texture_shapes() -> void:
	var house_contract := _manifest.get_object_asset_contract(&"ruined_house")
	var barrel_contract := _manifest.get_object_asset_contract(&"toxic_barrel")
	var house_texture := SVG_TEXTURE_LOADER.load_texture(String(house_contract.get("asset_path", "")), Color(0.42, 0.38, 0.30, 1.0), Color(0.86, 0.68, 0.22, 1.0))
	var barrel_texture := SVG_TEXTURE_LOADER.load_texture(String(barrel_contract.get("asset_path", "")), Color(0.20, 0.52, 0.34, 1.0), Color(0.82, 0.96, 0.34, 1.0))
	assert_not_null(house_texture, "ruined_house runtime texture loads")
	assert_not_null(barrel_texture, "toxic_barrel runtime texture loads")
	if house_texture == null or barrel_texture == null:
		return
	assert_gt(_alpha_mask_difference_score(house_texture, barrel_texture), 0.04, "ruined_house and toxic_barrel have distinct runtime silhouettes")

func test_loader_fallback_shapes() -> void:
	var house_path := "user://isometric_loader_house_test.svg"
	var barrel_path := "user://isometric_loader_barrel_test.svg"
	assert_true(_write_test_svg(house_path, &"ruined_house") and _write_test_svg(barrel_path, &"toxic_barrel"), "temporary SVG fallback fixtures are writable")
	var house_texture := SVG_TEXTURE_LOADER.load_texture(house_path, Color(0.42, 0.38, 0.30, 1.0), Color(0.86, 0.68, 0.22, 1.0))
	var barrel_texture := SVG_TEXTURE_LOADER.load_texture(barrel_path, Color(0.20, 0.52, 0.34, 1.0), Color(0.82, 0.96, 0.34, 1.0))
	assert_not_null(house_texture, "house SVG fallback texture loads")
	assert_not_null(barrel_texture, "barrel SVG fallback texture loads")
	if house_texture == null or barrel_texture == null:
		return
	assert_gt(_alpha_mask_difference_score(house_texture, barrel_texture), 0.04, "SVG fallback produces object-specific silhouettes")

func test_factory_obstacle_coverage() -> void:
	var factory := ISOMETRIC_OBJECT_FACTORY_SCRIPT.new(_manifest)
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
		assert_eq(obstacle.get_script(), ISOMETRIC_OBJECT_SCRIPT, "%s uses IsometricEnvironmentObject scene path" % String(obstacle_id))
		if obstacle.get_script() == ISOMETRIC_OBJECT_SCRIPT:
			if obstacle.is_perimeter_wall():
				assert_true(bool(obstacle.call("uses_procedural_fallback")), "%s uses the explicit tileable wall renderer" % String(obstacle_id))
			else:
				assert_true(bool(obstacle.call("has_asset_visual")), "%s has loaded asset-backed visual" % String(obstacle_id))
				assert_false(bool(obstacle.call("uses_procedural_fallback")), "%s does not use procedural fallback" % String(obstacle_id))
				assert_eq(String(obstacle.call("get_asset_path")), String(_manifest.get_object_asset_contract(obstacle_id).get("asset_path", "")), "%s sprite path comes from manifest" % String(obstacle_id))
			assert_true(obstacle.has_ground_shadow(), "%s keeps ground shadow contract" % String(obstacle_id))
			assert_eq(obstacle.get_obstacle_category(), _manifest.get_category(obstacle_id), "%s category comes from manifest" % String(obstacle_id))
			assert_false(obstacle.uses_generic_fallback(), "%s avoids generic visual fallback" % String(obstacle_id))
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
			assert_eq(obstacle.get_script(), ISOMETRIC_OBJECT_SCRIPT, "%s obstacle system uses asset scene" % String(obstacle_id))
			if obstacle.get_script() != ISOMETRIC_OBJECT_SCRIPT:
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
	assert_eq(crate.collision_layer, 8, "supply crate collision layer unchanged")
	assert_eq(crate.collision_mask, 1, "supply crate collision mask unchanged")
	var shape := crate.get_node_or_null("CollisionShape2D") as CollisionShape2D
	assert_true(shape != null and shape.shape is RectangleShape2D, "supply crate keeps rectangle collision")
	crate.queue_free()
	await wait_physics_frames(1)

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
	var expects_center_hit := _manifest.get_collision_shape(obstacle_id) != &"open"
	assert_eq(obstacle.contains_global_position(obstacle.global_position), expects_center_hit, "%s center containment matches collision shape" % String(obstacle_id))
	var shape := obstacle.get_node_or_null("CollisionShape2D") as CollisionShape2D
	assert_not_null(shape, "%s collision shape node exists" % String(obstacle_id))
	if shape == null:
		return
	match _manifest.get_collision_shape(obstacle_id):
		&"circle":
			assert_true(shape.shape is CircleShape2D, "%s uses circle collision" % String(obstacle_id))
		&"open":
			assert_true(shape.disabled, "%s disables open collision" % String(obstacle_id))
		_:
			assert_true(shape.shape is RectangleShape2D, "%s uses rectangle collision" % String(obstacle_id))

func _size_for(obstacle_id: StringName) -> Vector2:
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
