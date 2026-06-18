extends SceneTree

const WORLD_SEED: int = 641004
const ENEMY_IDS: Array[StringName] = [
	&"survival_zombie",
	&"survival_runner",
	&"survival_tank",
	&"survival_shooter"
]

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

	var game_mode_manager := get_first_node_in_group(
		"game_mode_manager"
	) as GameModeManager
	var local_multiplayer := get_first_node_in_group(
		"local_multiplayer_manager"
	) as LocalMultiplayerManager
	var player_manager := get_first_node_in_group(
		"player_manager"
	) as PlayerManager
	var wave_manager := get_first_node_in_group("wave_manager") as WaveManager
	var biome_manager := get_first_node_in_group("biome_manager") as BiomeManager
	var enemy_system := get_first_node_in_group("enemy_system") as EnemySystem
	var streamer = get_first_node_in_group("world_region_streamer")
	_expect(game_mode_manager != null, "game mode manager is available")
	_expect(local_multiplayer != null, "local multiplayer manager is available")
	_expect(player_manager != null, "player manager is available")
	_expect(wave_manager != null, "wave manager is available")
	_expect(biome_manager != null, "biome manager is available")
	_expect(enemy_system != null, "enemy system is available")
	_expect(streamer != null, "world region streamer is available")
	if (
		game_mode_manager == null
		or local_multiplayer == null
		or player_manager == null
		or wave_manager == null
		or biome_manager == null
		or enemy_system == null
		or streamer == null
	):
		_finish()
		return

	for slot in range(2, 5):
		local_multiplayer.activate_slot(slot)
	wave_manager.initial_delay = 100.0
	wave_manager.spawn_interval = 0.08
	_expect(
		game_mode_manager.set_mode(GameConstants.MODE_SURVIVAL, {
			"world_seed": WORLD_SEED,
			"biome_map_width": 3,
			"biome_map_height": 3,
			"extra_edge_chance": 0.5
		}),
		"survival starts with a 3x3 isometric world"
	)
	await process_frame
	await physics_frame
	await process_frame

	_expect(
		biome_manager.get_generated_biome_map().size() == 9,
		"3x3 biome map is generated"
	)
	var streamed_ids: Array[StringName] = streamer.get_streamed_region_ids()
	_expect(
		streamed_ids.size() >= 2,
		"streamer loads current region and connected neighbors"
	)
	for region_id in streamed_ids:
		_expect(
			streamer.get_content_level(region_id) == 2,
			"%s is streamed as FULL gameplay content" % String(region_id)
		)
		var counts: Dictionary = streamer.get_region_content_counts(region_id)
		var region := biome_manager.get_world_graph().get_region(region_id)
		var expected_tiles := (
			region.size_tiles.x * region.size_tiles.y
			if region != null
			else BiomeEnvironmentLayout.DEFAULT_ZONE_SIZE.x * BiomeEnvironmentLayout.DEFAULT_ZONE_SIZE.y
		)
		_expect(
			int(counts.get("tiles", 0)) == expected_tiles,
			"%s has the full 500x500 tile layer" % String(region_id)
		)

	var tile_layers := get_nodes_in_group("biome_tile_layers")
	_expect(
		tile_layers.size() >= streamed_ids.size(),
		"streamed regions expose chunked tile layers"
	)
	for node in tile_layers:
		var tile_layer := node as BiomeTileLayer
		if tile_layer == null:
			continue
		_expect(
			tile_layer.get_quality_preset() == &"balanced",
			"tile layer uses the balanced preset"
		)
		_expect(
			tile_layer.get_visual_tile_count() == (
				tile_layer.layout.zone_size.x * tile_layer.layout.zone_size.y
			),
			"tile layer caches every cell without per-tile nodes"
		)
		_expect(
			not tile_layer.uses_procedural_fallback(),
			"tile layer resolves asset-backed tiles without missing assets"
		)
	_expect(
		get_nodes_in_group("biome_transition_gates").is_empty(),
		"survival path has no transition gates"
	)
	_expect(
		get_nodes_in_group("multi_region_renderer").is_empty(),
		"legacy multi-region renderer is not used in the standard path"
	)

	var player_one := player_manager.players.get(1) as PlayerController
	_expect(player_one != null, "player one is available for profiling")
	if player_one == null:
		_finish()
		return

	var spawned_enemies: Array[Node] = []
	for index in range(28):
		var angle := TAU * float(index) / 28.0
		var radius := 190.0 + float(index % 4) * 28.0
		var enemy := enemy_system.spawn_enemy(
			ENEMY_IDS[index % ENEMY_IDS.size()],
			player_one.global_position + Vector2.RIGHT.rotated(angle) * radius,
			null,
			{"wave_index": 4}
		)
		if enemy != null:
			spawned_enemies.append(enemy)
	_expect(
		spawned_enemies.size() == 28,
		"profiling scenario includes 28 mixed enemies"
	)

	var profile_start := Time.get_ticks_usec()
	for _frame in range(120):
		await physics_frame
	var profile_elapsed_usec := Time.get_ticks_usec() - profile_start
	var average_frame_msec := float(profile_elapsed_usec) / 1000.0 / 120.0
	print(
		"MILESTONE_10_ISOMETRIC_PROFILE: 3x3 world, %d streamed regions, %d enemies, avg %.2f ms"
		% [streamed_ids.size(), spawned_enemies.size(), average_frame_msec]
	)
	_expect(
		average_frame_msec < 35.0,
		"balanced isometric streaming stays within the 35 ms frame budget"
	)

	var survival_mode := get_first_node_in_group("survival_mode") as SurvivalMode
	if survival_mode != null:
		survival_mode.stop_mode()
	_finish()

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("MILESTONE_10_ISOMETRIC_PERFORMANCE_SMOKE_TEST: PASS")
		quit(0)
		return
	print(
		"MILESTONE_10_ISOMETRIC_PERFORMANCE_SMOKE_TEST: FAIL (%d)"
		% failures.size()
	)
	quit(1)
