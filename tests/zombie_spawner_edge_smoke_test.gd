extends SceneTree

var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main_scene := load("res://game/main/main.tscn") as PackedScene
	_expect(main_scene != null, "main scene can be loaded")
	if main_scene == null:
		_finish()
		return

	var main := main_scene.instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame

	var spawner = get_first_node_in_group("zombie_spawner")
	var player := get_first_node_in_group("players") as Node2D
	_expect(spawner != null, "zombie spawner is available")
	_expect(player != null, "player one is available for distance checks")
	if spawner == null or player == null:
		_finish()
		return

	spawner.spawn_group_radius = 0.0
	spawner.spawn_margin = 160.0
	var visible_rect: Rect2 = spawner.get_visible_world_rect()
	_expect(visible_rect.size.x > 0.0, "camera visible rect is available")

	var edges: Array = [&"north", &"south", &"east", &"west"]
	for index in range(edges.size()):
		var edge := StringName(edges[index])
		spawner.spawn_edge_weights = _weights_for_edge(edge)
		var spawn_position: Vector2 = spawner.get_spawn_position(index)
		_expect(
			_edge_match(edge, spawn_position, visible_rect)
			and spawner.get_last_spawn_edge() == edge,
			"%s edge spawns outside the camera" % String(edge)
		)
		var attempt_report: Array = spawner.get_last_spawn_attempt_report()
		_expect(
			not attempt_report.is_empty()
			and StringName(attempt_report.back().get("reason", &"missing"))
			== &"",
			"%s edge exposes successful spawn diagnostics" % String(edge)
		)

	_expect(
		not spawner.is_spawn_position_valid(player.global_position),
		"spawner rejects positions on top of the player"
	)

	spawner.spawn_edge_weights = _weights_for_edge(&"north")
	var blocked_position: Vector2 = spawner.get_spawn_position(7)
	var fall_zone := Node2D.new()
	fall_zone.name = "TestFallZone"
	fall_zone.global_position = blocked_position
	fall_zone.set_meta("zone_radius", 48.0)
	fall_zone.add_to_group("fall_zones")
	current_scene.add_child(fall_zone)
	await process_frame
	_expect(
		not spawner.is_spawn_position_valid(blocked_position),
		"spawner rejects fall zone positions"
	)
	_expect(
		spawner.get_spawn_rejection_reason(blocked_position) == &"hazard",
		"spawner reports fall zones as hazardous spawn rejection"
	)
	fall_zone.queue_free()
	await process_frame

	var obstacle_position: Vector2 = spawner.get_spawn_position(8)
	var obstacle := Node2D.new()
	obstacle.name = "TestSpawnBlocker"
	obstacle.global_position = obstacle_position
	obstacle.set_meta("zone_radius", 48.0)
	obstacle.add_to_group("spawn_blockers")
	current_scene.add_child(obstacle)
	await process_frame
	_expect(
		not spawner.is_spawn_position_valid(obstacle_position),
		"spawner rejects spawn blocker positions"
	)
	_expect(
		spawner.get_spawn_rejection_reason(obstacle_position) == &"blocked",
		"spawner reports spawn blockers as blocked spawn rejection"
	)
	obstacle.queue_free()
	await process_frame

	var old_attempts: int = spawner.max_spawn_attempts
	spawner.max_spawn_attempts = 0
	var fallback_points: Array[Vector2] = [
		Vector2(64.0, 0.0),
		Vector2(960.0, 0.0)
	]
	spawner.configure_fallback_spawn_points(fallback_points)
	var fallback_position: Vector2 = spawner.get_spawn_position(9)
	_expect(
		fallback_position == Vector2(960.0, 0.0),
		"spawner uses the farthest configured fallback when attempts are exhausted"
	)
	spawner.max_spawn_attempts = old_attempts

	_finish()

func _weights_for_edge(edge: StringName) -> Dictionary:
	var weights := {
		&"north": 0.0,
		&"south": 0.0,
		&"east": 0.0,
		&"west": 0.0
	}
	weights[edge] = 1.0
	return weights

func _edge_match(edge: StringName, position: Vector2, visible_rect: Rect2) -> bool:
	if visible_rect.has_point(position):
		return false
	match edge:
		&"north":
			return position.y < visible_rect.position.y
		&"south":
			return position.y > visible_rect.end.y
		&"east":
			return position.x > visible_rect.end.x
		&"west":
			return position.x < visible_rect.position.x
	return false

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("ZOMBIE_SPAWNER_EDGE_SMOKE_TEST: PASS")
		quit(0)
		return

	print("ZOMBIE_SPAWNER_EDGE_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
