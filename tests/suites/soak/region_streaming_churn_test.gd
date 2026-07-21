extends GutTest
## Soak reale dello streaming multi-bioma. A differenza dei soak wave storici,
## non passa disable_region_streaming e ripete lo stesso seam in entrambe le
## direzioni per osservare residency, retirement e crescita ObjectDB.

const CROSSINGS := 8


func test_repeated_biome_crossings_drain_streaming_backlog() -> void:
	var scene = _new_main_scene_fixture()
	assert_true(scene.boot(self), "main scene can be loaded")
	await wait_physics_frames(2)
	var game_mode_manager: GameModeManager = scene.node(&"game_mode_manager") as GameModeManager
	var wave_manager: WaveManager = scene.node(&"wave_manager") as WaveManager
	var biome_manager: BiomeManager = scene.node(&"biome_manager") as BiomeManager
	var streamer: WorldRegionStreamer = scene.node(&"world_region_streamer") as WorldRegionStreamer
	var seam: RegionSeamSystem = scene.node(&"region_seam_system") as RegionSeamSystem
	var player_manager: PlayerManager = scene.node(&"player_manager") as PlayerManager
	assert_not_null(streamer, "streamer is available")
	assert_not_null(seam, "seam system is available")
	if (
		game_mode_manager == null
		or wave_manager == null
		or biome_manager == null
		or streamer == null
		or seam == null
		or player_manager == null
	):
		scene.teardown()
		return

	wave_manager.initial_delay = 600.0
	streamer.unload_grace_seconds = 0.01
	streamer.explicit_prefetch_hold_seconds = 0.05
	assert_true(
		game_mode_manager.set_mode(GameConstants.MODE_SURVIVAL, {"world_seed": 20260721}),
		"streaming survival starts"
	)
	assert_true(await _wait_for_current_area(streamer), "initial streamed area becomes ready")
	var graph := biome_manager.get_world_graph()
	var player := player_manager.players.get(1) as Node2D
	assert_not_null(graph, "world graph is available")
	assert_not_null(player, "player one is available")
	if graph == null or player == null:
		scene.stop_survival()
		scene.teardown()
		return

	var first_region_id := streamer.current_region_id
	var first_connection := _first_physical_connection(graph, first_region_id)
	assert_not_null(first_connection, "start region has a physical passage")
	if first_connection == null:
		scene.stop_survival()
		scene.teardown()
		return
	var second_region_id := first_connection.to_region_id
	var baseline_nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))

	for crossing_index in range(CROSSINGS):
		var source_id := streamer.current_region_id
		var target_id := second_region_id if source_id == first_region_id else first_region_id
		var connection := _connection_to(graph, source_id, target_id)
		assert_not_null(connection, "crossing %d has the return passage" % (crossing_index + 1))
		if connection == null:
			break
		var target_region := graph.get_region(target_id)
		assert_not_null(target_region, "crossing %d target region exists" % (crossing_index + 1))
		if target_region == null:
			break
		var crossing_position := seam.get_crossing_position_for_connection(connection, graph.start_region_id)
		player.global_position = crossing_position
		streamer.refresh_near_world_residency(crossing_position)
		seam.cooldown_timer = 0.05
		assert_false(
			seam.try_update_region_for_position(crossing_position),
			"crossing %d latches while cooldown is active" % (crossing_index + 1)
		)
		# Ogni iterazione include il rimbalzo di un frame visto nel playtest:
		# geometricamente di nuovo nella sorgente, ma ancora dentro il passaggio.
		var source_seam_tile := (
			connection.world_rect.position + connection.world_rect.size / 2
		)
		player.global_position = seam.logical_tile_to_world_position(
			source_seam_tile,
			graph.start_region_id
		)
		seam.try_update_region_for_position(player.global_position)
		assert_eq(
			String(seam.get_transition_diagnostics().get("pending_target_region_id", "")),
			String(target_id),
			"crossing %d survives source-side seam jitter" % (crossing_index + 1)
		)
		# Riproduce il bug reale: la party continua a muoversi mentre il target sta
		# ancora diventando FULL e lascia la stretta banda del passaggio.
		player.global_position = seam.logical_tile_to_world_position(
			target_region.world_origin + target_region.size_tiles / 2,
			graph.start_region_id
		)
		seam.cooldown_timer = 0.0
		var transition_completed := await _wait_for_current_region(streamer, target_id)
		if not transition_completed:
			gut.p("STREAMING_CHURN_STALL: %s" % str(streamer.get_streaming_stats()), 1)
		assert_true(
			transition_completed,
			"crossing %d commits after leaving the passage band" % (crossing_index + 1)
		)
		if not transition_completed:
			break
		assert_eq(
			streamer.get_content_level(target_id),
			WorldRegionStreamer.ContentLevel.FULL,
			"crossing %d target is FULL at commit" % (crossing_index + 1)
		)
		streamer.refresh_near_world_residency()
		assert_true(
			await _wait_for_streaming_drain(streamer),
			"crossing %d drains unload and retirement queues" % (crossing_index + 1)
		)
		var stats := streamer.get_streaming_stats()
		assert_lte(int(stats.get("gameplay_regions", 99)), 2, "near-world residency remains bounded")
		assert_eq(int(stats.get("pending_retirement_roots", -1)), 0, "retired roots return to zero")

	var final_nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	assert_lte(
		final_nodes,
		baseline_nodes + 160,
		"repeated return paths do not grow the live node set monotonically"
	)
	scene.stop_survival()
	scene.teardown()
	scene = null
	await wait_physics_frames(3)


func _wait_for_current_area(streamer: WorldRegionStreamer) -> bool:
	for _frame in range(1200):
		if (
			streamer.get_content_level(streamer.current_region_id)
			== WorldRegionStreamer.ContentLevel.FULL
			and streamer.is_area_ready()
		):
			return true
		await wait_process_frames(1)
	return false


func _wait_for_current_region(
	streamer: WorldRegionStreamer,
	region_id: StringName
) -> bool:
	for _frame in range(1200):
		if streamer.current_region_id == region_id:
			return true
		await wait_process_frames(1)
	return false


func _wait_for_streaming_drain(streamer: WorldRegionStreamer) -> bool:
	for _frame in range(1200):
		var stats := streamer.get_streaming_stats()
		if (
			int(stats.get("pending_regions", 0)) == 0
			and int(stats.get("pending_content", 0)) == 0
			and int(stats.get("scheduled_unloads", 0)) == 0
			and int(stats.get("pending_retirement_roots", 0)) == 0
		):
			return true
		await wait_process_frames(1)
	return false


func _first_physical_connection(graph: WorldGraph, region_id: StringName) -> WorldRegionConnection:
	var region := graph.get_region(region_id)
	if region == null:
		return null
	for connection_value in region.connection_edges:
		var connection := connection_value as WorldRegionConnection
		if connection != null and connection.is_open and connection.physical_passage:
			return connection
	return null


func _connection_to(
	graph: WorldGraph,
	region_id: StringName,
	target_id: StringName
) -> WorldRegionConnection:
	var region := graph.get_region(region_id)
	if region == null:
		return null
	for connection_value in region.connection_edges:
		var connection := connection_value as WorldRegionConnection
		if (
			connection != null
			and connection.to_region_id == target_id
			and connection.is_open
			and connection.physical_passage
		):
			return connection
	return null


func _new_main_scene_fixture():
	var script := ResourceLoader.load(
		"res://tests/support/main_scene_fixture.gd",
		"",
		ResourceLoader.CACHE_MODE_IGNORE
	) as Script
	assert_true(script != null, "main scene fixture script loads")
	return script.new() if script != null else null
