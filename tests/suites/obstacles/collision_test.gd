extends GutTest
## Obstacles A3 — Contratto di collisione di props e strutture.
##
## Migra: tests/milestone_4_obstacle_collision_smoke_test.gd
## Copre: collision_shape e flag (blocks_projectiles, is_jumpable_gap_anchor) dal
## manifest, costruzione runtime della collisione (rectangle/circle/open),
## traduzione di blocks_projectiles in layer/mask, query jumpable/non-jumpable,
## chiavi stabili e proiettili fermati dai muri solidi.
##
## Il manifest si carica localmente nei test che lo interrogano: tenere il
## singleton in un campo condiviso dello script insieme ai riferimenti a
## ObstacleSystem lascia risorse vive al teardown headless di Godot.

const GENERATED_OBSTACLE_IDS: Array[String] = [
	"ash_barrier", "boundary_fence", "broken_fence", "broken_walkway",
	"burned_car", "burned_house", "charred_wall", "dead_tree",
	"deep_water_boundary", "fallen_log", "ice_boundary", "ice_block",
	"ice_rock", "industrial_fence", "lab_block", "lab_wall", "lava_boundary",
	"marsh_log", "pipe_stack", "reed_wall", "ruined_house", "small_rock",
	"snow_cabin", "snow_wall", "sunken_house", "toxic_barrel",
	"toxic_boundary_wall", "wood_barrier"
]

func after_each() -> void:
	EnvironmentAssetManifest.clear_shared()

# --- contratto di collisione dal manifest -----------------------------------

func test_manifest_collision_contract() -> void:
	var manifest := _load_manifest()
	for id_string in GENERATED_OBSTACLE_IDS:
		var obstacle_id := StringName(id_string)
		assert_true(manifest.has_object(obstacle_id), "%s is described in the manifest" % id_string)
		var shape := manifest.get_collision_shape(obstacle_id)
		assert_true(shape == &"rectangle" or shape == &"circle", "%s uses a buildable collision shape (%s)" % [id_string, String(shape)])
		assert_true(manifest.blocks_projectiles(obstacle_id), "%s is a solid wall that blocks projectiles" % id_string)
		assert_false(manifest.is_jumpable_gap_anchor(obstacle_id), "%s is not a jumpable gap anchor" % id_string)

	assert_eq(manifest.get_collision_shape(&"bridge_passage"), &"open", "bridge_passage exposes an open (non-colliding) shape")
	assert_false(manifest.blocks_projectiles(&"bridge_passage"), "bridge_passage does not block projectiles")
	assert_true(manifest.is_jumpable_gap_anchor(&"fall_zone"), "fall_zone is flagged as a jumpable gap anchor")

# --- costruzione runtime della collisione -----------------------------------

func test_obstacle_runtime_contract() -> void:
	var rectangle := _build_obstacle(&"ruined_house", Vector2(126.0, 78.0))
	var rect_shape := rectangle.get_node_or_null("CollisionShape2D") as CollisionShape2D
	assert_true(rect_shape != null and rect_shape.shape is RectangleShape2D and not rect_shape.disabled, "manifest rectangle drives a runtime RectangleShape2D")
	assert_ne(rectangle.collision_layer & BiomeObstacle.MOVEMENT_BLOCK_LAYER_BIT, 0, "solid obstacle keeps the movement collision layer bit")
	assert_ne(rectangle.collision_layer & BiomeObstacle.PROJECTILE_BLOCK_LAYER_BIT, 0, "projectile-blocking obstacle gains the environment projectile layer bit")
	assert_true(rectangle.is_projectile_blocker(), "ruined_house reports as projectile blocker")
	assert_false(rectangle.is_jumpable_obstacle(), "ruined_house is not jumpable")
	await _free_node(rectangle)

	var circle := _build_obstacle(&"small_rock", Vector2(48.0, 48.0))
	var circle_shape := circle.get_node_or_null("CollisionShape2D") as CollisionShape2D
	assert_true(circle_shape != null and circle_shape.shape is CircleShape2D, "manifest circle drives a runtime CircleShape2D")
	await _free_node(circle)

	var open_obstacle := _build_obstacle(&"bridge_passage", Vector2(96.0, 24.0))
	var open_shape := open_obstacle.get_node_or_null("CollisionShape2D") as CollisionShape2D
	assert_true(open_shape != null and open_shape.disabled, "manifest open shape disables the runtime collision")
	assert_eq(open_obstacle.collision_layer, 0, "open obstacle occupies no collision layer")
	assert_false(open_obstacle.contains_global_position(open_obstacle.global_position), "open obstacle does not block positions")
	await _free_node(open_obstacle)

func test_tree_colliders_are_root_centered_circles() -> void:
	var forest_tree := _build_obstacle(&"forest_tree", Vector2(96.0, 96.0))
	_assert_root_circle_contract(forest_tree, Vector2(48.0, 48.0), Vector2(0.0, 24.0), 24.0, "forest_tree")
	await _free_node(forest_tree)

	var dead_tree := _build_obstacle(&"dead_tree", Vector2(48.0, 96.0))
	_assert_root_circle_contract(dead_tree, Vector2(24.0, 24.0), Vector2(0.0, 24.0), 12.0, "dead_tree")
	await _free_node(dead_tree)

func test_obstacle_rotation_is_locked_to_cardinal_axes() -> void:
	var obstacle := BiomeObstacle.new()
	add_child(obstacle)
	var requested_rotation := 0.35
	var manifest := _load_manifest()
	obstacle.configure(
		&"burned_car",
		Vector2(96.0, 144.0),
		&"rectangle",
		requested_rotation,
		Color(0.4, 0.4, 0.4, 1.0),
		Color(0.8, 0.8, 0.4, 1.0),
		manifest.get_sort_offset(&"burned_car")
	)
	assert_true(is_zero_approx(obstacle.rotation), "runtime obstacle ignores non-cardinal layout rotation")
	assert_true(bool(obstacle.get_meta("cardinal_rotation_locked", false)), "runtime obstacle records the cardinal lock")
	assert_true(is_equal_approx(float(obstacle.get_meta("requested_rotation_radians", 0.0)), requested_rotation), "requested legacy rotation remains available for diagnostics")
	await _free_node(obstacle)

func test_hazard_rotations_are_locked_to_cardinal_axes() -> void:
	var requested_rotation := -0.27
	var hazard := BiomeHazardZone.new()
	add_child(hazard)
	hazard.configure(
		&"toxic_puddle",
		Vector2(144.0, 80.0),
		requested_rotation,
		Color(0.2, 0.9, 0.4, 0.8)
	)
	assert_true(is_zero_approx(hazard.rotation), "runtime hazard ignores non-cardinal layout rotation")
	assert_true(bool(hazard.get_meta("cardinal_rotation_locked", false)), "runtime hazard records the cardinal lock")
	assert_true(is_equal_approx(float(hazard.get_meta("requested_rotation_radians", 0.0)), requested_rotation), "hazard keeps the stale angle only as diagnostics")
	await _free_node(hazard)

	var fall_zone := BiomeFallZone.new()
	add_child(fall_zone)
	fall_zone.configure(
		&"fall_zone",
		Vector2(192.0, 96.0),
		requested_rotation,
		Color(0.9, 0.5, 0.2, 1.0),
		&"cliff",
		&"north",
		42
	)
	assert_true(is_zero_approx(fall_zone.rotation), "runtime fall zone stays aligned to the cardinal grid")
	assert_true(bool(fall_zone.get_meta("cardinal_rotation_locked", false)), "fall zone records the cardinal lock")
	assert_true(is_equal_approx(float(fall_zone.get_meta("requested_rotation_radians", 0.0)), requested_rotation), "fall zone keeps the stale angle only as diagnostics")
	await _free_node(fall_zone)

# --- query jumpable/non-jumpable dell'ObstacleSystem ------------------------

func test_obstacle_system_queries() -> void:
	var obstacle_system := ObstacleSystem.new()
	add_child(obstacle_system)
	var obstacle := _build_obstacle(&"ruined_house", Vector2(120.0, 80.0))
	obstacle.global_position = Vector2(400.0, 400.0)
	await wait_physics_frames(1)
	var center := obstacle.global_position

	assert_true(obstacle_system.is_position_blocked(center), "solid obstacle blocks its center")
	assert_true(obstacle_system.is_position_blocked_by_non_jumpable(center), "non-jumpable query blocks a solid obstacle")
	assert_false(obstacle_system.is_position_jumpable_obstacle(center), "solid obstacle is not reported as jumpable")

	obstacle.jumpable = true
	assert_true(obstacle_system.is_position_blocked(center), "jumpable obstacle still counts as occupied for spawns")
	assert_false(obstacle_system.is_position_blocked_by_non_jumpable(center), "non-jumpable query skips a jumpable obstacle")
	assert_true(obstacle_system.is_position_jumpable_obstacle(center), "jumpable obstacle is reported by the jumpable query")

	await _free_node(obstacle)
	await _free_node(obstacle_system)

# --- chiavi stabili degli ostacoli ------------------------------------------

func test_stable_obstacle_keys() -> void:
	var first := ObstacleSystem.make_obstacle_key(&"infected_plains", 3, &"ruined_house")
	var second := ObstacleSystem.make_obstacle_key(&"infected_plains", 3, &"ruined_house")
	assert_eq(first, second, "obstacle key is stable for identical inputs")
	assert_eq(first, &"infected_plains:3:ruined_house", "obstacle key encodes region, index and id")
	assert_ne(ObstacleSystem.make_obstacle_key(&"infected_plains", 4, &"ruined_house"), first, "obstacle key differs by layout index")

# --- maschere dei proiettili e muro solido ----------------------------------

func test_projectile_scene_masks() -> void:
	assert_true(_scene_mask_has_bit("res://game/projectiles/projectile.tscn", BiomeObstacle.PROJECTILE_BLOCK_LAYER_BIT),
		"player projectile mask reads the environment projectile-block layer")
	assert_true(_scene_mask_has_bit("res://game/projectiles/boss_projectile.tscn", BiomeObstacle.PROJECTILE_BLOCK_LAYER_BIT),
		"hostile projectile mask reads the environment projectile-block layer")

func test_projectile_blocked_by_wall() -> void:
	var wall := _build_obstacle(&"ruined_house", Vector2(120.0, 120.0))
	wall.global_position = Vector2(0.0, 0.0)

	var projectile := _spawn_projectile(Vector2(-80.0, 0.0), Vector2.RIGHT)
	for _frame in range(30):
		if not is_instance_valid(projectile):
			break
		await wait_physics_frames(1)
	assert_false(is_instance_valid(projectile), "a projectile fired into a solid wall is consumed")
	await _free_node(wall)

	# Controllo: senza muro, il proiettile sopravvive la stessa finestra.
	var free_projectile := _spawn_projectile(Vector2(-80.0, 200.0), Vector2.RIGHT)
	for _frame in range(20):
		await wait_physics_frames(1)
	assert_true(is_instance_valid(free_projectile), "a projectile without an obstacle keeps flying")
	if is_instance_valid(free_projectile):
		free_projectile.queue_free()
		await wait_physics_frames(1)

# --- helper (porting dei test legacy) ---------------------------------------

func _build_obstacle(obstacle_id: StringName, size: Vector2) -> BiomeObstacle:
	var obstacle := BiomeObstacle.new()
	add_child(obstacle)
	var manifest := _load_manifest()
	obstacle.configure(obstacle_id, size, &"rectangle", 0.0,
		Color(0.4, 0.4, 0.4, 1.0), Color(0.8, 0.8, 0.4, 1.0), manifest.get_sort_offset(obstacle_id))
	return obstacle

func _assert_root_circle_contract(
	obstacle: BiomeObstacle,
	expected_size: Vector2,
	expected_offset: Vector2,
	expected_radius: float,
	label: String
) -> void:
	assert_not_null(obstacle, "%s builds" % label)
	if obstacle == null:
		return
	assert_eq(obstacle.get_collision_size(), expected_size, "%s collider size follows the root contract" % label)
	assert_eq(obstacle.get_collision_offset(), expected_offset, "%s collider is centered on the roots" % label)
	var collision := obstacle.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var circle := collision.shape as CircleShape2D if collision != null else null
	assert_true(circle != null and is_equal_approx(circle.radius, expected_radius), "%s uses the expected circular root radius" % label)
	assert_true(collision != null and collision.position.is_equal_approx(expected_offset), "%s physics shape uses the root offset" % label)
	var root_center := obstacle.to_global(expected_offset)
	assert_true(obstacle.contains_global_position(root_center), "%s blocks its root center" % label)
	assert_true(obstacle.contains_global_position(root_center + Vector2(expected_radius - 1.0, 0.0)), "%s blocks just inside its root radius" % label)
	assert_false(obstacle.contains_global_position(root_center + Vector2(expected_radius + 1.0, 0.0)), "%s does not retain the old square hitbox" % label)

func _spawn_projectile(origin: Vector2, direction: Vector2) -> Node:
	var scene := load("res://game/projectiles/projectile.tscn") as PackedScene
	var projectile := scene.instantiate()
	(projectile as Node2D).global_position = origin
	add_child(projectile)
	projectile.launch(direction, 420.0)
	return projectile

func _scene_mask_has_bit(path: String, bit: int) -> bool:
	var packed := load(path) as PackedScene
	if packed == null:
		return false
	var state := packed.get_state()
	for property_index in range(state.get_node_property_count(0)):
		if String(state.get_node_property_name(0, property_index)) == "collision_mask":
			return int(state.get_node_property_value(0, property_index)) & bit != 0
	return false

func _free_node(node: Node) -> void:
	if is_instance_valid(node):
		node.queue_free()
	await wait_physics_frames(1)

func _load_manifest() -> EnvironmentAssetManifest:
	var manifest := EnvironmentAssetManifest.get_shared()
	assert_true(manifest.load_error.is_empty(), "manifest loads without error")
	return manifest
