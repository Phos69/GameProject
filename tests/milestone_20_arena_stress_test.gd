extends SceneTree

const ENEMY_IDS: Array[StringName] = [
	&"survival_zombie",
	&"survival_runner",
	&"survival_tank",
	&"survival_shooter"
]

var failures: PackedStringArray = []
var finishing: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main_scene := load("res://game/main/main.tscn") as PackedScene
	_expect(main_scene != null, "main scene can be loaded for arena stress")
	if main_scene == null:
		_finish()
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	await process_frame

	var game_mode_manager := get_first_node_in_group(
		"game_mode_manager"
	) as GameModeManager
	var arena_manager := get_first_node_in_group(
		"survival_arena_manager"
	) as SurvivalArenaManager
	var local_multiplayer := get_first_node_in_group(
		"local_multiplayer_manager"
	) as LocalMultiplayerManager
	var wave_manager := get_first_node_in_group(
		"wave_manager"
	) as WaveManager
	var enemy_system := get_first_node_in_group(
		"enemy_system"
	) as EnemySystem
	_expect(game_mode_manager != null, "game mode manager is available")
	_expect(arena_manager != null, "arena manager is available")
	_expect(local_multiplayer != null, "local multiplayer manager is available")
	_expect(wave_manager != null, "wave manager is available")
	_expect(enemy_system != null, "enemy system is available")
	if (
		game_mode_manager == null
		or arena_manager == null
		or local_multiplayer == null
		or wave_manager == null
		or enemy_system == null
	):
		_finish()
		return

	for player_slot in range(2, 5):
		local_multiplayer.activate_slot(player_slot)
	wave_manager.initial_delay = 100.0
	game_mode_manager.set_mode(
		GameConstants.MODE_SURVIVAL,
		{"arena_id": &"rift_foundry"}
	)
	await process_frame
	await process_frame
	_expect(
		get_nodes_in_group("players").size() == 4,
		"stress scenario activates four local players"
	)

	var spawned: Array[Node] = []
	var spawn_points := arena_manager.active_profile.enemy_spawn_points
	var start_msec := Time.get_ticks_msec()
	for index in range(32):
		var gate_position := spawn_points[index % spawn_points.size()]
		var inward := gate_position.direction_to(Vector2.ZERO)
		var side := inward.orthogonal()
		var enemy := enemy_system.spawn_enemy(
			ENEMY_IDS[index % ENEMY_IDS.size()],
			gate_position
			+ inward * float(28 + (index / spawn_points.size()) * 16)
			+ side * float((index % 3) - 1) * 18.0
		)
		if enemy != null:
			spawned.append(enemy)
	for _frame in range(90):
		await physics_frame
	var elapsed_msec := Time.get_ticks_msec() - start_msec
	var roster_ids: Dictionary = {}
	for enemy in spawned:
		if is_instance_valid(enemy):
			roster_ids[StringName(enemy.get("enemy_id"))] = true
	_expect(spawned.size() == 32, "stress scenario spawns the full mixed roster")
	for enemy_id in ENEMY_IDS:
		_expect(
			roster_ids.has(enemy_id),
			"stress scenario keeps %s active" % enemy_id
		)
	_expect(
		elapsed_msec < 5000,
		"mixed arena scenario processes 90 physics frames within budget"
	)
	_expect(
		arena_manager.get_spawn_gates().size() == spawn_points.size(),
		"all spawn gates remain valid under load"
	)
	_expect(
		arena_manager.get_interactive_props().size() == 3,
		"interactive props remain valid under load"
	)
	game_mode_manager.set_mode(GameConstants.MODE_MENU)
	for _frame in range(5):
		await process_frame
	_finish()

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if finishing:
		return
	finishing = true
	var exit_code := 0
	if failures.is_empty():
		print("MILESTONE_20_ARENA_STRESS_TEST: PASS")
	else:
		print("MILESTONE_20_ARENA_STRESS_TEST: FAIL (%d)" % failures.size())
		exit_code = 1
	call_deferred("_shutdown", exit_code)

func _shutdown(exit_code: int) -> void:
	for _frame in range(5):
		await process_frame
	if current_scene != null:
		current_scene.queue_free()
		current_scene = null
	for _frame in range(5):
		await process_frame
	quit(exit_code)
