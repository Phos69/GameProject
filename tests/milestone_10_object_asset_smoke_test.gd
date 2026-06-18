extends SceneTree

const REQUIRED_OBSTACLE_ASSET_IDS: Array[StringName] = [
	&"ruined_house",
	&"burned_house",
	&"snow_cabin",
	&"sunken_house",
	&"lab_block",
	&"boundary_fence",
	&"toxic_boundary_wall",
	&"lava_boundary",
	&"ice_boundary",
	&"deep_water_boundary",
	&"industrial_fence",
	&"charred_wall",
	&"snow_wall",
	&"ash_barrier",
	&"pipe_stack",
	&"burned_car",
	&"ice_block",
	&"dead_tree",
	&"marsh_log",
	&"broken_walkway",
	&"toxic_barrel",
	&"chemical_barrel"
]
const REQUIRED_CRATE_ASSET_ID := &"supply_crate"
const ISOMETRIC_OBJECT_SCRIPT = preload(
	"res://game/modes/zombie/isometric_environment_object.gd"
)
const ISOMETRIC_OBJECT_FACTORY_SCRIPT = preload(
	"res://game/modes/zombie/isometric_environment_object_factory.gd"
)

var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var manifest := IsometricEnvironmentManifest.reload_shared()
	_expect(manifest.load_error.is_empty(), "manifest loads")
	var report := manifest.validate()
	_expect(bool(report.get("is_valid", false)), "manifest validates")
	if not bool(report.get("is_valid", false)):
		for failure in report.get("failures", PackedStringArray()):
			push_error("manifest failure: " + String(failure))

	var object_scene := load(
		"res://game/modes/zombie/isometric_environment_object.tscn"
	) as PackedScene
	_expect(object_scene != null, "isometric environment object scene loads")

	_run_asset_contract_coverage(manifest)
	await _run_factory_obstacle_coverage(manifest)
	await _run_obstacle_system_integration()
	await _run_supply_crate_asset_visual(manifest)
	_finish()

func _run_asset_contract_coverage(manifest: IsometricEnvironmentManifest) -> void:
	for obstacle_id in REQUIRED_OBSTACLE_ASSET_IDS:
		_expect(
			manifest.has_asset_contract(&"object_scenes", obstacle_id),
			"%s has object_scenes contract" % String(obstacle_id)
		)
		var contract := manifest.get_object_asset_contract(obstacle_id)
		_expect(
			_asset_exists(String(contract.get("asset_path", ""))),
			"%s asset path exists" % String(obstacle_id)
		)
		_expect(
			not String(contract.get("asset_path", "")).is_empty(),
			"%s declares an asset path" % String(obstacle_id)
		)

	var crate_contract := manifest.get_object_asset_contract(REQUIRED_CRATE_ASSET_ID)
	_expect(not crate_contract.is_empty(), "supply_crate has object_scenes contract")
	_expect(
		_asset_exists(String(crate_contract.get("asset_path", ""))),
		"supply_crate asset path exists"
	)

func _run_factory_obstacle_coverage(manifest: IsometricEnvironmentManifest) -> void:
	var factory := ISOMETRIC_OBJECT_FACTORY_SCRIPT.new(manifest)
	for obstacle_id in REQUIRED_OBSTACLE_ASSET_IDS:
		var size := _size_for(manifest, obstacle_id)
		var shape_id := _layout_shape_for(manifest, obstacle_id)
		var obstacle := factory.create_obstacle(
			obstacle_id,
			size,
			shape_id,
			0.0,
			Color(0.42, 0.38, 0.30, 1.0),
			Color(0.86, 0.68, 0.22, 1.0),
			manifest.get_sort_offset(obstacle_id)
		)
		_expect(obstacle != null, "%s factory creates obstacle" % String(obstacle_id))
		if obstacle == null:
			continue
		root.add_child(obstacle)
		obstacle.global_position = Vector2(320.0, 240.0)
		await process_frame
		_expect(
			obstacle.get_script() == ISOMETRIC_OBJECT_SCRIPT,
			"%s uses IsometricEnvironmentObject scene path" % String(obstacle_id)
		)
		if obstacle.get_script() == ISOMETRIC_OBJECT_SCRIPT:
			_expect(
				bool(obstacle.call("has_asset_sprite")),
				"%s has loaded sprite texture" % String(obstacle_id)
			)
			_expect(
				not bool(obstacle.call("uses_procedural_fallback")),
				"%s does not use procedural fallback" % String(obstacle_id)
			)
			_expect(
				String(obstacle.call("get_asset_path"))
				== String(manifest.get_object_asset_contract(obstacle_id).get("asset_path", "")),
				"%s sprite path comes from manifest" % String(obstacle_id)
			)
			_expect(
				obstacle.has_ground_shadow(),
				"%s keeps ground shadow contract" % String(obstacle_id)
			)
			_expect(
				obstacle.get_obstacle_category() == manifest.get_category(obstacle_id),
				"%s category comes from manifest" % String(obstacle_id)
			)
			_expect(
				not obstacle.uses_generic_fallback(),
				"%s avoids generic visual fallback" % String(obstacle_id)
			)
		_check_collision_contract(manifest, obstacle_id, obstacle)
		obstacle.queue_free()
		await process_frame

func _run_obstacle_system_integration() -> void:
	var container := Node2D.new()
	container.name = "EnvironmentProps"
	root.add_child(container)
	var system := ObstacleSystem.new()
	system.environment_container_path = NodePath("../EnvironmentProps")
	root.add_child(system)
	await process_frame

	var biome := load(
		"res://game/modes/zombie/biomes/infected_plains.tres"
	) as BiomeDefinition
	_expect(biome != null, "infected_plains biome loads")
	if biome != null:
		system.start_run(biome)
		await process_frame
		var active_obstacles := system.get_active_obstacles()
		_expect(not active_obstacles.is_empty(), "obstacle system spawns obstacles")
		for obstacle in active_obstacles:
			var biome_obstacle := obstacle as BiomeObstacle
			var obstacle_id := (
				biome_obstacle.obstacle_id
				if biome_obstacle != null
				else &"unknown"
			)
			_expect(
				obstacle.get_script() == ISOMETRIC_OBJECT_SCRIPT,
				"%s obstacle system uses asset scene"
				% String(obstacle_id)
			)
			if obstacle.get_script() != ISOMETRIC_OBJECT_SCRIPT:
				continue
			_expect(
				bool(obstacle.call("has_asset_sprite")),
				"%s runtime obstacle has sprite"
				% String(obstacle_id)
			)
			_expect(
				not bool(obstacle.call("uses_procedural_fallback")),
				"%s runtime obstacle avoids procedural fallback"
				% String(obstacle_id)
			)
			_expect(
				obstacle.is_in_group("environment_obstacles"),
				"%s runtime obstacle keeps environment group"
				% String(obstacle_id)
			)
			_expect(
				obstacle.is_in_group("spawn_blockers"),
				"%s runtime obstacle keeps spawn blocker group"
				% String(obstacle_id)
			)

	system.queue_free()
	container.queue_free()
	await process_frame

func _run_supply_crate_asset_visual(manifest: IsometricEnvironmentManifest) -> void:
	var crate_scene := load("res://game/drops/supply_crate.tscn") as PackedScene
	_expect(crate_scene != null, "supply crate scene loads")
	if crate_scene == null:
		return
	var crate := crate_scene.instantiate() as SupplyCrate
	_expect(crate != null, "supply crate instantiates")
	if crate == null:
		return
	root.add_child(crate)
	await process_frame
	var visual := crate.get_node_or_null("Visual")
	_expect(visual != null, "supply crate visual exists")
	if visual != null:
		_expect(
			visual.has_method("has_asset_sprite")
			and bool(visual.call("has_asset_sprite")),
			"supply crate visual uses asset sprite"
		)
		_expect(
			visual.has_method("uses_procedural_fallback")
			and not bool(visual.call("uses_procedural_fallback")),
			"supply crate visual avoids procedural fallback"
		)
		_expect(
			String(visual.call("get_asset_path"))
			== String(manifest.get_object_asset_contract(REQUIRED_CRATE_ASSET_ID).get("asset_path", "")),
			"supply crate visual path comes from manifest"
		)
	_expect(crate.collision_layer == 8, "supply crate collision layer unchanged")
	_expect(crate.collision_mask == 1, "supply crate collision mask unchanged")
	var shape := crate.get_node_or_null("CollisionShape2D") as CollisionShape2D
	_expect(
		shape != null and shape.shape is RectangleShape2D,
		"supply crate keeps rectangle collision"
	)
	crate.queue_free()
	await process_frame

func _check_collision_contract(
	manifest: IsometricEnvironmentManifest,
	obstacle_id: StringName,
	obstacle: BiomeObstacle
) -> void:
	var expected_layer := 0
	if manifest.blocks_movement(obstacle_id):
		expected_layer |= BiomeObstacle.MOVEMENT_BLOCK_LAYER_BIT
	if manifest.blocks_projectiles(obstacle_id):
		expected_layer |= BiomeObstacle.PROJECTILE_BLOCK_LAYER_BIT
	_expect(
		obstacle.collision_layer == expected_layer,
		"%s collision layer matches movement/projectile contract"
		% String(obstacle_id)
	)
	_expect(
		obstacle.collision_mask == 0,
		"%s collision mask remains passive environment"
		% String(obstacle_id)
	)
	_expect(
		is_equal_approx(obstacle.sort_offset, manifest.get_sort_offset(obstacle_id)),
		"%s sort offset comes from manifest" % String(obstacle_id)
	)
	_expect(obstacle.z_index == 0, "%s participates in Y-sort" % String(obstacle_id))
	var expects_center_hit := manifest.get_collision_shape(obstacle_id) != &"open"
	_expect(
		obstacle.contains_global_position(obstacle.global_position)
		== expects_center_hit,
		"%s center containment matches collision shape" % String(obstacle_id)
	)
	var shape := obstacle.get_node_or_null("CollisionShape2D") as CollisionShape2D
	_expect(shape != null, "%s collision shape node exists" % String(obstacle_id))
	if shape == null:
		return
	match manifest.get_collision_shape(obstacle_id):
		&"circle":
			_expect(
				shape.shape is CircleShape2D,
				"%s uses circle collision" % String(obstacle_id)
			)
		&"open":
			_expect(shape.disabled, "%s disables open collision" % String(obstacle_id))
		_:
			_expect(
				shape.shape is RectangleShape2D,
				"%s uses rectangle collision" % String(obstacle_id)
			)

func _size_for(
	manifest: IsometricEnvironmentManifest,
	obstacle_id: StringName
) -> Vector2:
	var contract := manifest.get_object_asset_contract(obstacle_id)
	var footprint := contract.get("footprint_tiles", Vector2i(6, 4)) as Vector2i
	return Vector2(
		maxf(float(footprint.x) * 8.0, 32.0),
		maxf(float(footprint.y) * 8.0, 28.0)
	)

func _layout_shape_for(
	manifest: IsometricEnvironmentManifest,
	obstacle_id: StringName
) -> StringName:
	return (
		&"circle"
		if manifest.get_collision_shape(obstacle_id) == &"circle"
		else &"rectangle"
	)

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
		print("MILESTONE_10_OBJECT_ASSET_SMOKE_TEST: PASS")
		quit(0)
		return
	print("MILESTONE_10_OBJECT_ASSET_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
