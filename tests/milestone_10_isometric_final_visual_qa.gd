extends SceneTree

const OUTPUT_DIRECTORY: String = "res://build/qa"
const WORLD_SEED: int = 641004

var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main_scene := load("res://game/main/main.tscn") as PackedScene
	_expect(main_scene != null, "main scene can be loaded for final isometric QA")
	if main_scene == null:
		_finish()
		return

	var main := main_scene.instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame

	var game_mode_manager := get_first_node_in_group(
		"game_mode_manager"
	) as GameModeManager
	var wave_manager := get_first_node_in_group("wave_manager") as WaveManager
	var biome_manager := get_first_node_in_group("biome_manager") as BiomeManager
	var enemy_system := get_first_node_in_group("enemy_system") as EnemySystem
	var player_manager := get_first_node_in_group(
		"player_manager"
	) as PlayerManager
	var seam_system = get_first_node_in_group("region_seam_system")
	var streamer = get_first_node_in_group("world_region_streamer")
	_expect(game_mode_manager != null, "game mode manager is available")
	_expect(wave_manager != null, "wave manager is available")
	_expect(biome_manager != null, "biome manager is available")
	_expect(enemy_system != null, "enemy system is available")
	_expect(player_manager != null, "player manager is available")
	_expect(seam_system != null, "region seam system is available")
	_expect(streamer != null, "world region streamer is available")
	if (
		game_mode_manager == null
		or wave_manager == null
		or biome_manager == null
		or enemy_system == null
		or player_manager == null
		or seam_system == null
		or streamer == null
	):
		_finish()
		return

	wave_manager.initial_delay = 100.0
	_expect(
		game_mode_manager.set_mode(GameConstants.MODE_SURVIVAL, {
			"world_seed": WORLD_SEED,
			"biome_map_width": 3,
			"biome_map_height": 3,
			"extra_edge_chance": 0.5
		}),
		"survival starts for final isometric QA"
	)
	await process_frame
	await physics_frame
	await process_frame

	var player := player_manager.players.get(1) as PlayerController
	_expect(player != null, "player one is available")
	if player == null:
		_finish()
		return

	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(OUTPUT_DIRECTORY)
	)

	await _capture_biome(
		biome_manager,
		streamer,
		enemy_system,
		player,
		&"infected_plains",
		&"center",
		"plains_full_region.png"
	)
	await _capture_biome(
		biome_manager,
		streamer,
		enemy_system,
		player,
		&"toxic_wastes",
		&"fall",
		"toxic_void_edge.png"
	)
	await _capture_biome(
		biome_manager,
		streamer,
		enemy_system,
		player,
		&"burning_fields",
		&"passage",
		"ash_passage_crossing.png"
	)
	await _capture_biome(
		biome_manager,
		streamer,
		enemy_system,
		player,
		&"frozen_outskirts",
		&"obstacle",
		"snow_objects_slots.png"
	)
	await _capture_biome(
		biome_manager,
		streamer,
		enemy_system,
		player,
		&"drowned_marsh",
		&"passage",
		"marsh_bridge_void.png"
	)
	await _capture_cross_biome_chase(
		biome_manager,
		seam_system,
		enemy_system,
		player
	)

	var survival_mode := get_first_node_in_group("survival_mode") as SurvivalMode
	if survival_mode != null:
		survival_mode.stop_mode()
	_finish()

func _capture_biome(
	biome_manager: BiomeManager,
	streamer,
	enemy_system: EnemySystem,
	player: PlayerController,
	biome_id: StringName,
	focus: StringName,
	file_name: String
) -> void:
	var region_id: StringName = await _select_region_for_biome(
		biome_manager,
		biome_id
	)
	if region_id.is_empty():
		return
	var focus_position := _get_focus_position(
		biome_manager,
		streamer,
		region_id,
		focus
	)
	_move_node(player, focus_position)
	_clear_qa_enemies()
	_spawn_biome_roster(enemy_system, biome_id, focus_position)
	await process_frame
	await physics_frame
	await process_frame
	_expect(
		await _capture(file_name),
		"%s screenshot is captured" % file_name
	)

func _select_region_for_biome(
	biome_manager: BiomeManager,
	biome_id: StringName
) -> StringName:
	var cell := _first_cell_for_biome(biome_manager, biome_id)
	_expect(cell != null, "%s generated region exists" % String(biome_id))
	if cell == null:
		return &""
	_expect(
		biome_manager.set_current_region(cell.id),
		"%s region is selected for visual QA" % String(biome_id)
	)
	await process_frame
	await physics_frame
	await process_frame
	return cell.id

func _first_cell_for_biome(
	biome_manager: BiomeManager,
	biome_id: StringName
) -> BiomeCell:
	for cell in biome_manager.get_generated_biome_map():
		if cell.biome_id == biome_id and cell.generated_layout != null:
			return cell
	return null

func _get_focus_position(
	biome_manager: BiomeManager,
	streamer,
	region_id: StringName,
	focus: StringName
) -> Vector2:
	var cell := biome_manager.get_cell_by_region_id(region_id)
	if cell == null or cell.generated_layout == null:
		return Vector2.ZERO
	var layout := cell.generated_layout
	var offset: Vector2 = streamer.get_region_offset(region_id)
	match focus:
		&"fall":
			if not layout.fall_zone_rects.is_empty():
				return offset + layout.rect_center_to_world(layout.fall_zone_rects.front())
			if not layout.hazard_positions.is_empty():
				return offset + layout.hazard_positions.front()
		&"passage":
			if not layout.passage_connector_rects.is_empty():
				return offset + layout.rect_center_to_world(layout.passage_connector_rects.front())
			if not layout.passage_rects.is_empty():
				return offset + layout.rect_center_to_world(layout.passage_rects.front())
			if not layout.fall_zone_rects.is_empty():
				return offset + layout.rect_center_to_world(layout.fall_zone_rects.front())
		&"obstacle":
			if not layout.obstacle_positions.is_empty():
				return offset + layout.obstacle_positions.front()
	return offset

func _spawn_biome_roster(
	enemy_system: EnemySystem,
	biome_id: StringName,
	origin: Vector2
) -> void:
	var roster: Array[StringName] = [&"survival_zombie", &"survival_runner"]
	match biome_id:
		&"toxic_wastes":
			roster = [&"toxic_zombie", &"toxic_exploder"]
		&"burning_fields":
			roster = [&"burned_zombie", &"fire_runner", &"fire_exploder"]
		&"frozen_outskirts":
			roster = [&"frozen_zombie", &"ice_armored_zombie", &"heavy_slow_zombie"]
		&"drowned_marsh":
			roster = [&"drowned_zombie", &"marsh_zombie", &"water_emerging_zombie"]
	for index in range(roster.size()):
		var enemy := enemy_system.spawn_enemy(
			roster[index],
			origin + Vector2(-170.0 + float(index) * 170.0, -95.0)
		)
		if enemy == null:
			continue
		enemy.add_to_group("milestone_10_final_qa_enemies")
		enemy.set_physics_process(false)
		var visual := enemy.get_node_or_null("Visual") as ZombieVisual
		if visual != null:
			visual.modulate = Color.WHITE
			visual.set_state(&"chase")
			visual.set_facing(Vector2.DOWN)

func _capture_cross_biome_chase(
	biome_manager: BiomeManager,
	seam_system,
	enemy_system: EnemySystem,
	player: PlayerController
) -> void:
	var graph := biome_manager.get_world_graph()
	_expect(graph != null, "world graph exists for chase screenshots")
	if graph == null:
		return
	var start_cell := biome_manager.get_cell_by_region_id(graph.start_region_id)
	_expect(start_cell != null, "start region exists for chase screenshots")
	if start_cell == null:
		return
	_expect(
		biome_manager.set_current_region(start_cell.id),
		"start region is selected for chase screenshots"
	)
	await process_frame
	await physics_frame
	var connection := _first_connection_for_cell(graph, start_cell)
	_expect(connection != null, "start region has an open chase connection")
	if connection == null:
		return
	var direction := _direction_for_side(connection.side)
	var crossing_position: Vector2 = seam_system.get_crossing_position_for_connection(
		connection,
		graph.start_region_id
	)
	_clear_qa_enemies()
	_move_node(player, crossing_position - direction * 70.0)
	var enemy := enemy_system.spawn_enemy(
		&"survival_zombie",
		crossing_position - direction * 230.0,
		null,
		{"wave_index": 1}
	) as BasicEnemy
	_expect(enemy != null, "enemy spawns for chase screenshots")
	if enemy == null:
		return
	enemy.add_to_group("milestone_10_final_qa_enemies")
	enemy.detection_range = 4000.0
	enemy.move_speed = 180.0
	enemy.target_refresh_interval = 0.01
	enemy.target = player
	await process_frame
	_expect(
		await _capture("cross_biome_chase_sequence_01.png"),
		"cross_biome_chase_sequence_01.png screenshot is captured"
	)
	_move_node(player, crossing_position)
	seam_system.cooldown_timer = 0.0
	seam_system.try_update_region_for_position(crossing_position)
	await process_frame
	_move_node(player, crossing_position + direction * 260.0)
	for _frame in range(180):
		await physics_frame
		if (
			is_instance_valid(enemy)
			and not enemy.is_queued_for_deletion()
			and enemy.current_region_id == connection.to_region_id
		):
			break
	_expect(
		is_instance_valid(enemy) and not enemy.is_queued_for_deletion(),
		"chase screenshot enemy survives region crossing"
	)
	_expect(
		is_instance_valid(enemy) and enemy.current_region_id == connection.to_region_id,
		"chase screenshot enemy reaches target region"
	)
	_expect(
		await _capture("cross_biome_chase_sequence_02.png"),
		"cross_biome_chase_sequence_02.png screenshot is captured"
	)

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

func _direction_for_side(side: StringName) -> Vector2:
	match side:
		&"west":
			return Vector2.LEFT
		&"north":
			return Vector2.UP
		&"south":
			return Vector2.DOWN
		_:
			return Vector2.RIGHT

func _move_node(node: Node2D, position: Vector2) -> void:
	node.global_position = position
	if node is CharacterBody2D:
		(node as CharacterBody2D).velocity = Vector2.ZERO

func _clear_qa_enemies() -> void:
	for enemy in get_nodes_in_group("milestone_10_final_qa_enemies"):
		if is_instance_valid(enemy):
			enemy.queue_free()

func _capture(file_name: String) -> bool:
	await process_frame
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		return false
	var output_path := "%s/%s" % [OUTPUT_DIRECTORY, file_name]
	return image.save_png(ProjectSettings.globalize_path(output_path)) == OK

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("MILESTONE_10_ISOMETRIC_FINAL_VISUAL_QA: PASS")
		quit(0)
		return
	print(
		"MILESTONE_10_ISOMETRIC_FINAL_VISUAL_QA: FAIL (%d)"
		% failures.size()
	)
	quit(1)
