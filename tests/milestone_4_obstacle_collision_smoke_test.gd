extends SceneTree

# Milestone 4 - Collisioni coerenti con props e strutture.
# Copre: collision_shape e flag (blocks_projectiles, is_jumpable_gap_anchor)
# letti dal manifest, costruzione runtime della collisione da manifest
# (rectangle/circle/open), traduzione di blocks_projectiles in layer/mask,
# query jumpable/non-jumpable, chiavi stabili per ostacoli e proiettili
# fermati dai muri solidi.

const GENERATED_OBSTACLE_IDS := [
	"ash_barrier", "boundary_fence", "broken_fence", "broken_walkway",
	"burned_car", "burned_house", "charred_wall", "dead_tree",
	"deep_water_boundary", "fallen_log", "ice_boundary", "ice_block",
	"ice_rock", "industrial_fence", "lab_block", "lab_wall", "lava_boundary",
	"marsh_log", "pipe_stack", "reed_wall", "ruined_house", "small_rock",
	"snow_cabin", "snow_wall", "sunken_house", "toxic_barrel",
	"toxic_boundary_wall", "wood_barrier"
]

var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var manifest := IsometricEnvironmentManifest.reload_shared()
	_expect(manifest.load_error.is_empty(), "manifest loads without error")

	_run_manifest_collision_contract(manifest)
	await _run_obstacle_runtime_contract(manifest)
	await _run_obstacle_system_queries(manifest)
	_run_stable_keys()
	_run_projectile_scene_masks()
	await _run_projectile_blocked_by_wall(manifest)

	_finish()

func _run_manifest_collision_contract(manifest: IsometricEnvironmentManifest) -> void:
	for id_string in GENERATED_OBSTACLE_IDS:
		var obstacle_id := StringName(id_string)
		_expect(
			manifest.has_object(obstacle_id),
			"%s is described in the manifest" % id_string
		)
		var shape := manifest.get_collision_shape(obstacle_id)
		_expect(
			shape == &"rectangle" or shape == &"circle",
			"%s uses a buildable collision shape (%s)" % [id_string, String(shape)]
		)
		_expect(
			manifest.blocks_projectiles(obstacle_id),
			"%s is a solid wall that blocks projectiles" % id_string
		)
		_expect(
			not manifest.is_jumpable_gap_anchor(obstacle_id),
			"%s is not a jumpable gap anchor" % id_string
		)

	# Gap/passage entries are non-solid and jumpable.
	_expect(
		manifest.get_collision_shape(&"bridge_passage") == &"open",
		"bridge_passage exposes an open (non-colliding) shape"
	)
	_expect(
		not manifest.blocks_projectiles(&"bridge_passage"),
		"bridge_passage does not block projectiles"
	)
	_expect(
		manifest.is_jumpable_gap_anchor(&"fall_zone"),
		"fall_zone is flagged as a jumpable gap anchor"
	)

func _run_obstacle_runtime_contract(manifest: IsometricEnvironmentManifest) -> void:
	var rectangle := _build_obstacle(manifest, &"ruined_house", Vector2(126.0, 78.0))
	var rect_shape := rectangle.get_node_or_null("CollisionShape2D") as CollisionShape2D
	_expect(
		rect_shape != null and rect_shape.shape is RectangleShape2D and not rect_shape.disabled,
		"manifest rectangle drives a runtime RectangleShape2D"
	)
	_expect(
		rectangle.collision_layer & BiomeObstacle.MOVEMENT_BLOCK_LAYER_BIT != 0,
		"solid obstacle keeps the movement collision layer bit"
	)
	_expect(
		rectangle.collision_layer & BiomeObstacle.PROJECTILE_BLOCK_LAYER_BIT != 0,
		"projectile-blocking obstacle gains the environment projectile layer bit"
	)
	_expect(rectangle.is_projectile_blocker(), "ruined_house reports as projectile blocker")
	_expect(not rectangle.is_jumpable_obstacle(), "ruined_house is not jumpable")
	await _free_node(rectangle)

	var circle := _build_obstacle(manifest, &"small_rock", Vector2(48.0, 48.0))
	var circle_shape := circle.get_node_or_null("CollisionShape2D") as CollisionShape2D
	_expect(
		circle_shape != null and circle_shape.shape is CircleShape2D,
		"manifest circle drives a runtime CircleShape2D"
	)
	await _free_node(circle)

	# Open shape: no collision, no blocking layers.
	var open_obstacle := _build_obstacle(manifest, &"bridge_passage", Vector2(96.0, 24.0))
	var open_shape := open_obstacle.get_node_or_null("CollisionShape2D") as CollisionShape2D
	_expect(
		open_shape != null and open_shape.disabled,
		"manifest open shape disables the runtime collision"
	)
	_expect(open_obstacle.collision_layer == 0, "open obstacle occupies no collision layer")
	_expect(
		not open_obstacle.contains_global_position(open_obstacle.global_position),
		"open obstacle does not block positions"
	)
	await _free_node(open_obstacle)

func _run_obstacle_system_queries(manifest: IsometricEnvironmentManifest) -> void:
	var obstacle_system := ObstacleSystem.new()
	root.add_child(obstacle_system)
	var obstacle := _build_obstacle(manifest, &"ruined_house", Vector2(120.0, 80.0))
	obstacle.global_position = Vector2(400.0, 400.0)
	await process_frame
	var center := obstacle.global_position

	_expect(obstacle_system.is_position_blocked(center), "solid obstacle blocks its center")
	_expect(
		obstacle_system.is_position_blocked_by_non_jumpable(center),
		"non-jumpable query blocks a solid obstacle"
	)
	_expect(
		not obstacle_system.is_position_jumpable_obstacle(center),
		"solid obstacle is not reported as jumpable"
	)

	# Flip the obstacle to jumpable: still occupied, but crossable by a dodge.
	obstacle.jumpable = true
	_expect(
		obstacle_system.is_position_blocked(center),
		"jumpable obstacle still counts as occupied for spawns"
	)
	_expect(
		not obstacle_system.is_position_blocked_by_non_jumpable(center),
		"non-jumpable query skips a jumpable obstacle"
	)
	_expect(
		obstacle_system.is_position_jumpable_obstacle(center),
		"jumpable obstacle is reported by the jumpable query"
	)

	await _free_node(obstacle)
	await _free_node(obstacle_system)

func _run_stable_keys() -> void:
	var first := ObstacleSystem.make_obstacle_key(&"infected_plains", 3, &"ruined_house")
	var second := ObstacleSystem.make_obstacle_key(&"infected_plains", 3, &"ruined_house")
	_expect(first == second, "obstacle key is stable for identical inputs")
	_expect(
		first == &"infected_plains:3:ruined_house",
		"obstacle key encodes region, index and id"
	)
	_expect(
		ObstacleSystem.make_obstacle_key(&"infected_plains", 4, &"ruined_house") != first,
		"obstacle key differs by layout index"
	)

func _run_projectile_scene_masks() -> void:
	_expect(
		_scene_mask_has_bit("res://game/projectiles/projectile.tscn", BiomeObstacle.PROJECTILE_BLOCK_LAYER_BIT),
		"player projectile mask reads the environment projectile-block layer"
	)
	_expect(
		_scene_mask_has_bit("res://game/projectiles/boss_projectile.tscn", BiomeObstacle.PROJECTILE_BLOCK_LAYER_BIT),
		"hostile projectile mask reads the environment projectile-block layer"
	)

func _run_projectile_blocked_by_wall(manifest: IsometricEnvironmentManifest) -> void:
	var wall := _build_obstacle(manifest, &"ruined_house", Vector2(120.0, 120.0))
	wall.global_position = Vector2(0.0, 0.0)

	var projectile := _spawn_projectile(Vector2(-80.0, 0.0), Vector2.RIGHT)
	for _frame in range(30):
		if not is_instance_valid(projectile):
			break
		await physics_frame
	_expect(
		not is_instance_valid(projectile),
		"a projectile fired into a solid wall is consumed"
	)
	await _free_node(wall)

	# Control: with no wall, the projectile survives the same window.
	var free_projectile := _spawn_projectile(Vector2(-80.0, 200.0), Vector2.RIGHT)
	for _frame in range(20):
		await physics_frame
	_expect(
		is_instance_valid(free_projectile),
		"a projectile without an obstacle keeps flying"
	)
	if is_instance_valid(free_projectile):
		free_projectile.queue_free()
		await process_frame

func _spawn_projectile(origin: Vector2, direction: Vector2) -> Node:
	var scene := load("res://game/projectiles/projectile.tscn") as PackedScene
	var projectile := scene.instantiate()
	(projectile as Node2D).global_position = origin
	root.add_child(projectile)
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

func _build_obstacle(
	manifest: IsometricEnvironmentManifest,
	obstacle_id: StringName,
	size: Vector2
) -> BiomeObstacle:
	var obstacle := BiomeObstacle.new()
	root.add_child(obstacle)
	obstacle.configure(
		obstacle_id,
		size,
		&"rectangle",
		0.0,
		Color(0.4, 0.4, 0.4, 1.0),
		Color(0.8, 0.8, 0.4, 1.0),
		manifest.get_sort_offset(obstacle_id)
	)
	return obstacle

func _free_node(node: Node) -> void:
	if is_instance_valid(node):
		node.queue_free()
	await process_frame

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("MILESTONE_4_OBSTACLE_COLLISION_SMOKE_TEST: PASS")
		quit(0)
		return
	print("MILESTONE_4_OBSTACLE_COLLISION_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
