extends SceneTree

const OUTPUT_DIRECTORY: String = "res://build/qa"
const STREAMING_READY_TIMEOUT_FRAMES := 600

var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main_scene := load("res://game/main/main.tscn") as PackedScene
	_expect(main_scene != null, "main scene can be loaded for boss QA")
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
	var wave_manager := get_first_node_in_group("wave_manager") as WaveManager
	var player_manager := get_first_node_in_group(
		"player_manager"
	) as PlayerManager
	var boss_system := get_first_node_in_group("boss_system") as BossSystem
	var biome_manager := get_first_node_in_group("biome_manager") as BiomeManager
	var terrain_generator := get_first_node_in_group(
		"terrain_generator"
	) as TerrainGenerator
	var streamer := get_first_node_in_group(
		"world_region_streamer"
	) as WorldRegionStreamer
	_expect(game_mode_manager != null, "game mode manager is available")
	_expect(wave_manager != null, "wave manager is available")
	_expect(player_manager != null, "player manager is available")
	_expect(boss_system != null, "boss system is available")
	_expect(biome_manager != null, "biome manager is available")
	_expect(terrain_generator != null, "terrain generator is available")
	_expect(streamer != null, "world region streamer is available")
	if (
		game_mode_manager == null
		or wave_manager == null
		or player_manager == null
		or boss_system == null
		or biome_manager == null
		or terrain_generator == null
		or streamer == null
	):
		_finish()
		return

	wave_manager.initial_delay = 100.0
	var survival_started := game_mode_manager.set_mode(GameConstants.MODE_SURVIVAL, {
		"async_world_build": false,
		"biome_map_width": 3,
		"biome_map_height": 3,
		"extra_edge_chance": 0.5
	})
	_expect(
		survival_started,
		"survival starts for boss visual QA"
	)
	if not survival_started:
		_finish()
		return
	var initial_tiles_ready := await _wait_for_streamed_tiles(
		streamer,
		terrain_generator,
		biome_manager,
		"initial boss QA view"
	)
	_expect(
		initial_tiles_ready,
		"initial streamed tiles are loaded for boss QA"
	)
	if not initial_tiles_ready:
		_finish()
		return
	var player := player_manager.players.get(1) as PlayerController
	_expect(player != null, "player one is available")
	if player == null:
		_finish()
		return

	player.global_position = Vector2(250.0, 90.0)
	var boss := boss_system.request_boss(
		GameConstants.MODE_SURVIVAL,
		&"visual_qa",
		Vector2(-120.0, -20.0)
	) as BasicBoss
	_expect(boss != null, "Wave Warden is available for visual QA")
	if boss == null:
		_finish()
		return

	boss.move_speed = 0.0
	boss.attack_cooldown = 100.0
	boss.attack_timer = 100.0
	boss.aimed_telegraph_duration = 4.0
	boss.radial_telegraph_duration = 4.0
	boss.target = player

	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(OUTPUT_DIRECTORY)
	)
	_expect(
		boss.start_attack_telegraph(&"aimed_volley"),
		"aimed telegraph starts for visual QA"
	)
	await process_frame
	await process_frame
	var aimed_tiles_ready := await _wait_for_streamed_tiles(
		streamer,
		terrain_generator,
		biome_manager,
		"aimed telegraph screenshot"
	)
	_expect(aimed_tiles_ready, "streamed tiles are loaded for aimed screenshot")
	var aimed_capture := false
	if aimed_tiles_ready:
		aimed_capture = await _capture("milestone_11_boss_aimed.png")
	_expect(
		aimed_capture,
		"aimed telegraph screenshot is captured"
	)

	boss.cancel_attack_telegraph()
	_expect(
		boss.start_attack_telegraph(&"radial_burst"),
		"radial telegraph starts for visual QA"
	)
	await process_frame
	await process_frame
	var radial_tiles_ready := await _wait_for_streamed_tiles(
		streamer,
		terrain_generator,
		biome_manager,
		"radial telegraph screenshot"
	)
	_expect(radial_tiles_ready, "streamed tiles are loaded for radial screenshot")
	var radial_capture := false
	if radial_tiles_ready:
		radial_capture = await _capture("milestone_11_boss_radial.png")
	_expect(
		radial_capture,
		"radial telegraph screenshot is captured"
	)
	_finish()

func _capture(file_name: String) -> bool:
	await process_frame
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		return false
	var output_path := "%s/%s" % [OUTPUT_DIRECTORY, file_name]
	return image.save_png(ProjectSettings.globalize_path(output_path)) == OK

func _wait_for_streamed_tiles(
	streamer: WorldRegionStreamer,
	terrain_generator: TerrainGenerator,
	biome_manager: BiomeManager,
	label: String
) -> bool:
	for _attempt in range(STREAMING_READY_TIMEOUT_FRAMES):
		if _streamed_tiles_ready(streamer, terrain_generator, biome_manager):
			await process_frame
			return true
		await process_frame
	print(
		"STREAMING_READY_TIMEOUT %s: %s"
		% [
			label,
			_streaming_debug_state(
				streamer,
				terrain_generator,
				biome_manager
			)
		]
	)
	return false

func _streamed_tiles_ready(
	streamer: WorldRegionStreamer,
	terrain_generator: TerrainGenerator,
	biome_manager: BiomeManager
) -> bool:
	if streamer == null or terrain_generator == null or biome_manager == null:
		return false
	if biome_manager.get_world_graph() == null:
		return false
	if biome_manager.get_generated_biome_map().is_empty():
		return false
	var active_layer := terrain_generator.get_active_tile_layer()
	if active_layer == null or active_layer.is_building():
		return false
	if not _all_tile_layers_finished():
		return false
	streamer.prepare_area()
	if not streamer.is_area_ready():
		return false
	var stats := streamer.get_streaming_stats()
	return (
		int(stats.get("pending_regions", 0)) == 0
		and int(stats.get("pending_chunks", 0)) == 0
		and int(stats.get("visible_missing_chunks", 0)) == 0
		and not streamer.get_loaded_visual_chunk_keys().is_empty()
	)

func _all_tile_layers_finished() -> bool:
	var found_layer := false
	for node in get_nodes_in_group("biome_tile_layers"):
		var layer := node as BiomeTileLayer
		if (
			layer == null
			or not is_instance_valid(layer)
			or layer.is_queued_for_deletion()
		):
			continue
		found_layer = true
		if layer.is_building():
			return false
	return found_layer

func _streaming_debug_state(
	streamer: WorldRegionStreamer,
	terrain_generator: TerrainGenerator,
	biome_manager: BiomeManager
) -> String:
	if streamer == null:
		return "streamer=null"
	var active_layer: BiomeTileLayer = null
	if terrain_generator != null:
		active_layer = terrain_generator.get_active_tile_layer()
	var graph_ready := (
		biome_manager != null
		and biome_manager.get_world_graph() != null
	)
	var map_size := 0
	if biome_manager != null:
		map_size = biome_manager.get_generated_biome_map().size()
	return "stats=%s active_layer=%s graph_ready=%s map_size=%d" % [
		str(streamer.get_streaming_stats()),
		str(active_layer),
		str(graph_ready),
		map_size
	]

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("BOSS_TELEGRAPH_VISUAL_QA: PASS")
		quit(0)
		return
	print("BOSS_TELEGRAPH_VISUAL_QA: FAIL (%d)" % failures.size())
	quit(1)
