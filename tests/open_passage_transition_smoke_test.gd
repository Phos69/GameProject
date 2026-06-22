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

	var game_mode_manager := get_first_node_in_group("game_mode_manager") as GameModeManager
	var wave_manager := get_first_node_in_group("wave_manager") as WaveManager
	var biome_manager := get_first_node_in_group("biome_manager") as BiomeManager
	var transition_system := get_first_node_in_group("biome_transition_system") as BiomeTransitionSystem
	var seam_system = get_first_node_in_group("region_seam_system")
	var world_runtime := get_first_node_in_group("world_runtime") as WorldRuntime
	var player_manager := get_first_node_in_group("player_manager") as PlayerManager
	_expect(game_mode_manager != null, "game mode manager is available")
	_expect(wave_manager != null, "wave manager is available")
	_expect(biome_manager != null, "biome manager is available")
	_expect(transition_system != null, "transition system is available")
	_expect(seam_system != null, "region seam system is available")
	_expect(world_runtime != null, "world runtime is available")
	_expect(player_manager != null, "player manager is available")
	if (
		game_mode_manager == null
		or wave_manager == null
		or biome_manager == null
		or transition_system == null
		or seam_system == null
		or world_runtime == null
		or player_manager == null
	):
		_finish()
		return

	wave_manager.initial_delay = 100.0
	transition_system.transition_cooldown = 0.01
	transition_system.move_party_on_transition = false
	seam_system.transition_cooldown = 0.01
	_expect(
		game_mode_manager.set_mode(GameConstants.MODE_SURVIVAL, {
			"world_seed": 31337,
			"biome_map_width": 3,
			"biome_map_height": 3,
			"extra_edge_chance": 0.5
		}),
		"survival starts with persistent megamap"
	)
	await process_frame
	await physics_frame

	var start_cell := biome_manager.get_current_biome_cell()
	var graph := biome_manager.get_world_graph()
	_expect(start_cell != null, "current region cell exists")
	_expect(graph != null, "world graph exists")
	_expect(world_runtime.get_current_region_id() == start_cell.id, "world runtime tracks current region")
	_expect(get_nodes_in_group("biome_transition_gates").is_empty(), "no biome transition gate nodes exist")
	if start_cell == null or graph == null or start_cell.passages.is_empty():
		_finish()
		return
	var player := player_manager.players.get(1) as PlayerController
	_expect(player != null, "player one exists")
	var original_position: Vector2 = player.global_position if player != null else Vector2.ZERO
	var connection := _first_connection_for_cell(graph, start_cell)
	_expect(connection != null, "start cell has an open WorldRegionConnection")
	if connection == null:
		_finish()
		return
	var crossing_position: Vector2 = seam_system.get_crossing_position_for_connection(
		connection,
		graph.start_region_id
	)
	if player != null:
		player.global_position = crossing_position
	seam_system.cooldown_timer = 0.0
	_expect(
		seam_system.try_update_region_for_position(crossing_position),
		"world-space seam crossing uses the target region id"
	)
	await process_frame
	_expect(biome_manager.get_current_region_id() == connection.to_region_id, "biome manager changes to target region")
	_expect(world_runtime.get_current_region_id() == connection.to_region_id, "world runtime changes to target region")
	if player != null:
		_expect(
			player.global_position.distance_to(original_position) > 80.0,
			"transition follows physical movement instead of teleporting the party"
		)
	_expect(
		get_nodes_in_group("biome_transition_gates").is_empty(),
		"generated passages do not require open passage nodes"
	)

	var survival_mode := get_first_node_in_group("survival_mode") as SurvivalMode
	if survival_mode != null:
		survival_mode.stop_mode()
	_finish()

func _first_connection_for_cell(
	graph: WorldGraph,
	cell: BiomeCell
) -> WorldRegionConnection:
	var region := graph.get_region(cell.id)
	if region == null:
		return null
	for connection in region.connection_edges:
		if connection.is_open and connection.physical_passage:
			return connection
	return null

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("OPEN_PASSAGE_TRANSITION_SMOKE_TEST: PASS")
		quit(0)
		return
	print("OPEN_PASSAGE_TRANSITION_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
