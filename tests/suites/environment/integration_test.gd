extends GutTest
## Environment A2 — Cluster di integrazione con boot condiviso di main.tscn.
##
## Questi test bootavano ognuno `main.tscn` da solo (10 file legacy, 10 cold-start).
## Qui la scena principale viene istanziata UNA volta in before_all e riusata: ogni
## test riavvia survival (`set_mode`) per isolare il mondo. È il punto in cui il
## taglio dei boot rende il massimo.
##
## Migra e accorpa (batch corrente — streaming regioni):
##   tests/milestone_10_full_region_streaming_smoke_test.gd
##   tests/milestone_10_top_down_performance_smoke_test.gd
##   tests/milestone_10_legacy_cleanup_smoke_test.gd

const PERFORMANCE_ENEMY_IDS: Array[StringName] = [
	&"survival_zombie", &"survival_runner", &"survival_tank", &"survival_shooter"
]
const WorldGridConfig = preload("res://game/core/world_grid_config.gd")

var _scene
var _default_spawn_interval: float = 0.0
var _default_seam_cooldown: float = 0.0
var _default_transition_cooldown: float = 0.0
var _default_move_party: bool = true
var _default_active_radius: int = 1
var _default_loaded_region_radius: int = 1
var _default_unload_grace_seconds: float = 2.0
var _default_neighbor_radius: int = 1

# Stato raccolto dai segnali durante test_zombie_fall_hazard (resettato a inizio test).
var _cue_ids: Array[StringName] = []
var _spawned_drop_count: int = 0
var _void_enemy_death_reason: StringName = &""

func before_all() -> void:
	_scene = _new_main_scene_fixture()
	assert_true(_scene.boot(self), "main scene can be loaded")
	await wait_physics_frames(3)
	var wave_manager: WaveManager = _scene.node(&"wave_manager") as WaveManager
	if wave_manager != null:
		_default_spawn_interval = wave_manager.spawn_interval
	var seam_system = _scene.node(&"region_seam_system")
	if seam_system != null:
		_default_seam_cooldown = float(seam_system.get("transition_cooldown"))
	var transition_system: BiomeTransitionSystem = _scene.node(&"biome_transition_system") as BiomeTransitionSystem
	if transition_system != null:
		_default_transition_cooldown = transition_system.transition_cooldown
		_default_move_party = transition_system.move_party_on_transition
	var streamer = _scene.node(&"world_region_streamer")
	if streamer != null:
		_default_active_radius = int(streamer.get("active_radius"))
		_default_unload_grace_seconds = float(streamer.get("unload_grace_seconds"))
	var world_runtime: WorldRuntime = _scene.node(&"world_runtime") as WorldRuntime
	if world_runtime != null:
		_default_loaded_region_radius = world_runtime.loaded_region_radius
	var multi_region_renderer = _scene.node(&"multi_region_renderer")
	if multi_region_renderer != null:
		_default_neighbor_radius = int(multi_region_renderer.get("neighbor_radius"))

func before_each() -> void:
	# Ripristina i tunable che i singoli test mutano, così l'ordine non conta.
	var wave_manager: WaveManager = _scene.node(&"wave_manager") as WaveManager
	if wave_manager != null:
		wave_manager.spawn_interval = _default_spawn_interval
	var local_multiplayer: LocalMultiplayerManager = _scene.node(&"local_multiplayer_manager") as LocalMultiplayerManager
	if local_multiplayer != null:
		for slot in [4, 3, 2]:
			local_multiplayer.deactivate_slot(slot)
	var seam_system = _scene.node(&"region_seam_system")
	if seam_system != null:
		seam_system.set("transition_cooldown", _default_seam_cooldown)
		seam_system.set("cooldown_timer", 0.0)
	var transition_system: BiomeTransitionSystem = _scene.node(&"biome_transition_system") as BiomeTransitionSystem
	if transition_system != null:
		transition_system.transition_cooldown = _default_transition_cooldown
		transition_system.move_party_on_transition = _default_move_party
	var streamer = _scene.node(&"world_region_streamer")
	if streamer != null:
		streamer.set("active_radius", _default_active_radius)
		streamer.set("unload_grace_seconds", _default_unload_grace_seconds)
	var world_runtime: WorldRuntime = _scene.node(&"world_runtime") as WorldRuntime
	if world_runtime != null:
		world_runtime.loaded_region_radius = _default_loaded_region_radius
	var multi_region_renderer = _scene.node(&"multi_region_renderer")
	if multi_region_renderer != null:
		multi_region_renderer.set("neighbor_radius", _default_neighbor_radius)

func after_each() -> void:
	# Indispensabile: senza stop, il prossimo set_mode(SURVIVAL) non ricostruisce.
	_scene.stop_survival()
	await wait_physics_frames(1)

func after_all() -> void:
	if _scene != null:
		_scene.stop_survival()
		await wait_physics_frames(1)
		_scene.teardown()
	_scene = null
	WorldDataCache.clear()
	EnvironmentAssetManifest.clear_shared()
	EnvironmentObject.clear_content_metrics_cache()
	await wait_physics_frames(3)

# --- streaming near-world della regione corrente e del solo varco vicino ----
# (milestone_10_full_region_streaming)

func test_full_region_streaming() -> void:
	var streamer = _scene.node(&"world_region_streamer")
	var biome_manager: BiomeManager = _scene.node(&"biome_manager") as BiomeManager
	var world_runtime: WorldRuntime = _scene.node(&"world_runtime") as WorldRuntime
	var terrain_generator: TerrainGenerator = _scene.node(&"terrain_generator") as TerrainGenerator
	var obstacle_system: ObstacleSystem = _scene.node(&"obstacle_system") as ObstacleSystem
	var hazard_system: HazardSystem = _scene.node(&"hazard_system") as HazardSystem
	var crate_system: ResourceCrateSystem = _scene.node(&"resource_crate_system") as ResourceCrateSystem
	assert_not_null(streamer, "world region streamer is available")
	assert_not_null(terrain_generator, "terrain generator is available")
	assert_not_null(world_runtime, "world runtime is available")
	if streamer == null or biome_manager == null or world_runtime == null:
		return

	assert_true(_scene.start_survival({
		"world_seed": 81818, "biome_map_width": 3, "biome_map_height": 3, "extra_edge_chance": 0.5
	}), "survival starts with full region streaming")
	await wait_physics_frames(1)
	await wait_physics_frames(1)

	var graph := biome_manager.get_world_graph()
	var current_cell := biome_manager.get_current_biome_cell()
	assert_not_null(graph, "world graph exists")
	assert_not_null(current_cell, "current region exists")
	if graph == null or current_cell == null:
		return

	var expected_data_active := _expected_active_ids(graph, current_cell.id)
	assert_true(
		_same_ids(world_runtime.get_active_region_ids(), expected_data_active),
		"runtime keeps current and graph neighbors warm only as data"
	)
	var prefetched_neighbor_id: StringName = &""
	var connection := _first_connection_for_cell(graph, current_cell)
	assert_not_null(connection, "current region exposes a physical prefetch passage")
	if connection != null:
		prefetched_neighbor_id = connection.to_region_id
		var prefetch_position: Vector2 = (
			_scene.node(&"region_seam_system").get_crossing_position_for_connection(
				connection,
				graph.start_region_id
			)
		)
		var requested_ids: Array[StringName] = streamer.refresh_near_world_residency(
			prefetch_position
		)
		assert_true(
			requested_ids.has(prefetched_neighbor_id),
			"approaching one passage requests only its connected region"
		)
		assert_true(
			await _wait_for_streamed_region_full(streamer, prefetched_neighbor_id),
			"nearby passage destination reaches FULL before crossing"
		)
	var expected_resident: Array[StringName] = [current_cell.id]
	if not prefetched_neighbor_id.is_empty():
		expected_resident.append(prefetched_neighbor_id)
	var streamed: Array[StringName] = streamer.get_streamed_region_ids()
	var near_world_stats := streamer.get_streaming_stats() as Dictionary
	print(
		(
			"NEAR_WORLD_PROFILE: resident=%d main_build=%.3f ms geometry=%.3f ms "
			+ "signature_worker=%.3f ms mask_worker=%.3f ms phases=%s"
		)
		% [
			streamed.size(),
			float(near_world_stats.get("max_region_build_msec", 0.0)),
			float(near_world_stats.get("max_tile_geometry_phase_msec", 0.0)),
			float(near_world_stats.get("max_tile_signature_worker_msec", 0.0)),
			float(near_world_stats.get("max_surface_mask_worker_msec", 0.0)),
			str(near_world_stats.get("tile_geometry_phase_msec", {}))
		]
	)
	assert_true(
		_same_ids(streamed, expected_resident),
		"streamer contains current region plus the single nearby passage"
	)
	for region_id in expected_resident:
		assert_eq(int(streamer.get_content_level(region_id)), 2, "%s is streamed as FULL gameplay content" % String(region_id))
	var nonzero_texture_origins := 0
	for layer_node in _scene.nodes(&"biome_tile_layers"):
		var streamed_layer := layer_node as BiomeTileLayer
		var region_root := (
			streamed_layer.get_parent() as Node2D
			if streamed_layer != null
			else null
		)
		if streamed_layer == null or region_root == null:
			continue
		assert_eq(
			streamed_layer.terrain_texture_world_origin,
			region_root.position,
			"streamed terrain reuses its region offset for continuous texture UVs"
		)
		if not streamed_layer.terrain_texture_world_origin.is_zero_approx():
			nonzero_texture_origins += 1
	assert_gt(
		nonzero_texture_origins,
		0,
		"at least one neighboring region exercises a non-zero texture phase"
	)
	var distant_id := _find_distant_region(graph, current_cell.id)
	if not distant_id.is_empty():
		assert_eq(int(streamer.get_content_level(distant_id)), 0, "distant regions remain uninstantiated data")

	var current_counts: Dictionary = streamer.get_region_content_counts(current_cell.id)
	var current_layout := current_cell.generated_layout
	assert_eq(int(current_counts.get("tiles", 0)), current_layout.zone_size.x * current_layout.zone_size.y, "current region has a full tile layer")
	assert_eq(int(current_counts.get("obstacles", 0)), current_layout.obstacle_positions.size(), "current region streams all obstacles")
	assert_eq(int(current_counts.get("hazards", 0)), current_layout.hazard_positions.size(), "current region streams all hazards")
	var current_tile_layer := terrain_generator.get_active_tile_layer()
	assert_not_null(current_tile_layer, "current region exposes its chunked tile layer")
	if current_tile_layer != null:
		assert_gt(current_tile_layer.get_loaded_chunk_count(), 0,
			"camera halo keeps visible terrain chunks active")
		assert_lt(current_tile_layer.get_loaded_chunk_count(), current_tile_layer.get_chunk_count(),
			"chunks outside the camera halo are not rendered")
		assert_lt(current_tile_layer.get_loaded_visual_tile_count(), current_layout.zone_size.x * current_layout.zone_size.y,
			"resident visual tiles are bounded by the camera halo")
	var camera_rect := Rect2(Vector2(-320.0, -180.0), Vector2(640.0, 360.0))
	var mapped_once: Array[Vector2i] = streamer.get_chunk_coords_for_world_rect(
		current_cell.id,
		camera_rect,
		0
	)
	var mapped_twice: Array[Vector2i] = streamer.get_chunk_coords_for_world_rect(
		current_cell.id,
		camera_rect,
		0
	)
	var mapped_with_margin: Array[Vector2i] = streamer.get_chunk_coords_for_world_rect(
		current_cell.id,
		camera_rect,
		1
	)
	assert_eq(mapped_once, mapped_twice, "camera-to-chunk mapping is deterministic")
	assert_false(mapped_once.is_empty(), "camera rect maps to at least one current-region chunk")
	assert_gte(mapped_with_margin.size(), mapped_once.size(), "chunk margin never shrinks the visible set")
	assert_true(streamer.prepare_area(camera_rect),
		"prepare_area reports an already-prefetched active camera area as ready")
	assert_eq(int((streamer.get_streaming_stats() as Dictionary).get("pending_regions", -1)), 0,
		"initial gameplay ring is ready before the run starts")
	var initial_chunk_keys: Array[StringName] = streamer.get_loaded_visual_chunk_keys()
	var distant_camera_rect := Rect2(Vector2(1680.0, 1680.0), Vector2(24.0, 24.0))
	assert_false(streamer.prepare_area(distant_camera_rect),
		"prepare_area queues a distant debug/teleport target not yet prefetched")
	var hysteresis_stats := streamer.get_streaming_stats() as Dictionary
	assert_gt(int(hysteresis_stats.get("scheduled_chunk_unloads", 0)), 0,
		"resident chunks beyond the retention ring enter hysteresis")
	var retained_chunk_keys: Array[StringName] = streamer.get_loaded_visual_chunk_keys()
	assert_eq(retained_chunk_keys, initial_chunk_keys,
		"hysteresis keeps old chunks resident during its grace interval")

	if current_tile_layer != null:
		current_tile_layer.evict_chunks_except([])
	var approach_camera_rect := Rect2(
		Vector2(1080.0, 1080.0),
		Vector2(24.0, 24.0)
	)
	streamer.prepare_area(approach_camera_rect)
	streamer.prepare_area(distant_camera_rect)
	var distant_visible_keys: Array[StringName] = []
	for streamed_region_id in streamer.get_streamed_region_ids():
		var distant_visible_coords: Array[Vector2i] = (
			streamer.get_chunk_coords_for_world_rect(
				streamed_region_id,
				distant_camera_rect,
				0
			)
		)
		for coord in distant_visible_coords:
			distant_visible_keys.append(StringName(
				"%s:%d:%d" % [
					String(streamed_region_id),
					coord.x,
					coord.y
				]
			))
	var pending_chunk_keys: Array[StringName] = (
		streamer.get_pending_visual_chunk_keys()
	)
	assert_false(pending_chunk_keys.is_empty(),
		"the distant visible target leaves visual work pending")
	if not pending_chunk_keys.is_empty():
		assert_true(distant_visible_keys.has(pending_chunk_keys[0]),
			"an already-pending chunk is promoted when it enters the camera (%s in %s)"
			% [String(pending_chunk_keys[0]), str(distant_visible_keys)])

	var neighbor_id := prefetched_neighbor_id
	assert_false(neighbor_id.is_empty(), "at least one connected neighbor has generated content")
	if not neighbor_id.is_empty():
		_assert_neighbor_gameplay_queries(streamer, biome_manager, obstacle_system, hazard_system, neighbor_id)
		await _assert_neighbor_crate_persistence(streamer, graph, biome_manager, world_runtime,
			terrain_generator, obstacle_system, hazard_system, crate_system, current_cell.id, neighbor_id)

	assert_true(_obstacle_keys_unique(obstacle_system), "streamed obstacle keys are unique")
	assert_true(_crate_keys_unique(crate_system), "streamed crate keys are unique")

# --- profilo prestazioni dello streaming bilanciato -------------------------
# (milestone_10_top_down_performance)

func test_top_down_streaming_performance() -> void:
	var local_multiplayer: LocalMultiplayerManager = _scene.node(&"local_multiplayer_manager") as LocalMultiplayerManager
	var player_manager: PlayerManager = _scene.node(&"player_manager") as PlayerManager
	var wave_manager: WaveManager = _scene.node(&"wave_manager") as WaveManager
	var biome_manager: BiomeManager = _scene.node(&"biome_manager") as BiomeManager
	var enemy_system: EnemySystem = _scene.node(&"enemy_system") as EnemySystem
	var streamer = _scene.node(&"world_region_streamer")
	assert_not_null(local_multiplayer, "local multiplayer manager is available")
	assert_not_null(enemy_system, "enemy system is available")
	assert_not_null(streamer, "world region streamer is available")
	if local_multiplayer == null or player_manager == null or enemy_system == null or streamer == null:
		return

	for slot in range(2, 5):
		local_multiplayer.activate_slot(slot)
	wave_manager.spawn_interval = 0.08
	assert_true(_scene.start_survival({
		"world_seed": 641004, "biome_map_width": 3, "biome_map_height": 3, "extra_edge_chance": 0.5
	}), "survival starts with a 3x3 cardinal-grid world")
	await wait_physics_frames(1)
	await wait_physics_frames(1)
	await wait_physics_frames(1)

	assert_eq(biome_manager.get_generated_biome_map().size(), 9, "3x3 biome map is generated")
	var streamed_ids: Array[StringName] = streamer.get_streamed_region_ids()
	assert_eq(streamed_ids.size(), 1, "streamer starts with only the current nearby world resident")
	for region_id in streamed_ids:
		assert_eq(int(streamer.get_content_level(region_id)), 2, "%s is streamed as FULL gameplay content" % String(region_id))
		var counts: Dictionary = streamer.get_region_content_counts(region_id)
		var region := biome_manager.get_world_graph().get_region(region_id)
		var expected_tiles := (region.size_tiles.x * region.size_tiles.y if region != null
			else BiomeEnvironmentLayout.DEFAULT_ZONE_SIZE.x * BiomeEnvironmentLayout.DEFAULT_ZONE_SIZE.y)
		assert_eq(int(counts.get("tiles", 0)), expected_tiles, "%s has the full top-down tile layer" % String(region_id))

	var tile_layers = _scene.nodes(&"biome_tile_layers")
	assert_gte(tile_layers.size(), streamed_ids.size(), "streamed regions expose chunked tile layers")
	for layer_node in tile_layers:
		var tile_layer := layer_node as BiomeTileLayer
		if tile_layer == null:
			continue
		assert_eq(tile_layer.get_quality_preset(), &"balanced", "tile layer uses the balanced preset")
		assert_eq(tile_layer.get_visual_tile_count(), tile_layer.layout.zone_size.x * tile_layer.layout.zone_size.y,
			"tile layer caches every cell without per-tile nodes")
		assert_false(tile_layer.uses_procedural_fallback(), "tile layer resolves asset-backed tiles without missing assets")
	assert_true(_scene.nodes(&"biome_transition_gates").is_empty(), "survival path has no transition gates")
	assert_true(_scene.nodes(&"multi_region_renderer").is_empty(), "legacy multi-region renderer is not used in the standard path")

	var player_one := player_manager.players.get(1) as PlayerController
	assert_not_null(player_one, "player one is available for profiling")
	if player_one == null:
		return

	var spawned_enemies: Array[Node] = []
	for index in range(28):
		var angle := TAU * float(index) / 28.0
		var radius := 190.0 + float(index % 4) * 28.0
		var enemy := enemy_system.spawn_enemy(
			PERFORMANCE_ENEMY_IDS[index % PERFORMANCE_ENEMY_IDS.size()],
			player_one.global_position + Vector2.RIGHT.rotated(angle) * radius,
			null,
			{"wave_index": 4}
		)
		if enemy != null:
			spawned_enemies.append(enemy)
	assert_eq(spawned_enemies.size(), 28, "profiling scenario includes 28 mixed enemies")

	var profile_start := Time.get_ticks_usec()
	for _frame in range(120):
		await wait_physics_frames(1)
	var profile_elapsed_usec := Time.get_ticks_usec() - profile_start
	var average_frame_msec := float(profile_elapsed_usec) / 1000.0 / 120.0
	gut.p("TOP_DOWN_PROFILE: %d streamed regions, %d enemies, avg %.2f ms"
		% [streamed_ids.size(), spawned_enemies.size(), average_frame_msec])
	# Tetto sul tempo per frame: il preset "balanced" evita i nodi per-tile, quindi
	# una regressione vera (streaming a contenuto pieno di tutte le 9 regioni, o
	# nodi per cella) spingerebbe il frame a centinaia di ms. Il vecchio test usava
	# 35 ms in un processo dedicato; qui il boot condiviso GUT ha un baseline più
	# alto, quindi il tetto è 45 ms (mantiene il segnale anti-regressione senza
	# essere flaky sul margine di 1 ms).
	assert_lt(average_frame_msec, 45.0, "balanced top-down streaming stays within the frame budget")

	for enemy in spawned_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()

# --- prefetch direzionale durante movimento camera --------------------------

func test_directional_chunk_prefetch() -> void:
	var streamer: WorldRegionStreamer = (
		_scene.node(&"world_region_streamer") as WorldRegionStreamer
	)
	var camera := _scene.main.get_node_or_null("Camera2D") as Camera2D
	assert_not_null(streamer, "world region streamer is available")
	assert_not_null(camera, "main camera is available")
	if streamer == null or camera == null:
		return
	assert_true(_scene.start_survival({
		"world_seed": 641005,
		"biome_map_width": 3,
		"biome_map_height": 3,
		"extra_edge_chance": 0.5
	}), "survival starts for directional prefetch profiling")
	await wait_physics_frames(2)
	camera.set_process(false)
	camera.position_smoothing_enabled = false
	var start_position := camera.global_position
	var start_zoom := camera.zoom
	var max_visible_missing := 0
	var observed_commit_msec := 0.0
	for frame_index in range(90):
		var progress := float(frame_index + 1) / 90.0
		camera.global_position = (
			start_position + Vector2(float(frame_index + 1) * 16.0, 0.0)
		)
		var zoom_out_weight := sin(progress * PI)
		camera.zoom = Vector2.ONE * lerpf(
			start_zoom.x,
			0.68,
			zoom_out_weight
		)
		await wait_physics_frames(1)
		var stats := streamer.get_streaming_stats()
		max_visible_missing = maxi(
			max_visible_missing,
			int(stats.get("visible_missing_chunks", 0))
		)
		observed_commit_msec = maxf(
			observed_commit_msec,
			float(stats.get("last_frame_chunk_commit_msec", 0.0))
		)
	gut.p(
		"DIRECTIONAL_STREAM_PROFILE: visible_missing=%d max_commit=%.3f ms min_zoom=0.68"
		% [max_visible_missing, observed_commit_msec]
	)
	var terrain_generator := (
		_scene.node(&"terrain_generator") as TerrainGenerator
	)
	var current_tile_layer: BiomeTileLayer = null
	if terrain_generator != null:
		current_tile_layer = terrain_generator.get_active_tile_layer()
	assert_not_null(
		current_tile_layer,
		"directional profile exposes the current tile layer"
	)
	var building_visible_missing := 0
	var building_area_ready := true
	if current_tile_layer != null:
		current_tile_layer.set("_is_building", true)
		building_area_ready = streamer.prepare_area()
		building_visible_missing = int(
			streamer.get_streaming_stats().get(
				"visible_missing_chunks",
				0
			)
		)
		current_tile_layer.set("_is_building", false)
		streamer.prepare_area()
	camera.global_position = start_position
	camera.zoom = start_zoom
	camera.set_process(true)
	assert_eq(max_visible_missing, 0,
		"directional prefetch keeps every camera chunk resident while moving and zooming")
	assert_lt(observed_commit_msec, 50.0,
		"directional chunk commits stay below the seam frame ceiling")
	assert_false(
		building_area_ready,
		"a visible tile layer still in build is not reported ready"
	)
	assert_gt(
		building_visible_missing,
		0,
		"a visible tile layer still in build contributes missing chunks"
	)

# --- assenza di renderer/gate legacy nel percorso standard ------------------
# (milestone_10_legacy_cleanup)

func test_no_legacy_renderer_or_gates() -> void:
	_assert_source_audit()

	var biome_manager: BiomeManager = _scene.node(&"biome_manager") as BiomeManager
	var terrain_generator: TerrainGenerator = _scene.node(&"terrain_generator") as TerrainGenerator
	var transition_system: BiomeTransitionSystem = _scene.node(&"biome_transition_system") as BiomeTransitionSystem
	var streamer = _scene.node(&"world_region_streamer")
	assert_not_null(terrain_generator, "terrain generator is available")
	assert_not_null(transition_system, "legacy transition command API is available")
	assert_not_null(streamer, "world region streamer is available")
	if biome_manager == null or terrain_generator == null or streamer == null:
		return

	assert_true(_scene.start_survival({
		"world_seed": 101010, "biome_map_width": 3, "biome_map_height": 3, "extra_edge_chance": 0.5
	}), "survival starts with the asset-driven region streamer")
	await wait_physics_frames(1)
	await wait_physics_frames(1)
	await wait_physics_frames(1)

	var current_region_id := biome_manager.get_current_region_id()
	var streamed_ids: Array[StringName] = streamer.get_streamed_region_ids()
	assert_false(current_region_id.is_empty(), "current region is resolved")
	assert_eq(streamed_ids.size(), 1, "standard survival does not instantiate distant graph neighbors")
	assert_eq(int(streamer.get_content_level(current_region_id)), 2, "current region is streamed as FULL gameplay content")
	var current_counts: Dictionary = streamer.get_region_content_counts(current_region_id)
	assert_gt(int(current_counts.get("tiles", 0)), 0, "current streamed region owns an asset tile layer")
	assert_not_null(terrain_generator.get_active_tile_layer(), "terrain generator tracks the current streamed tile layer")
	assert_eq(_count_named_prefix(_scene.main, "NeighborGround_"), 0, "standard survival does not instantiate legacy neighbor ground placeholders")
	assert_true(_scene.nodes(&"multi_region_renderer").is_empty(), "legacy multi-region renderer is not instantiated during standard streaming")
	assert_true(_scene.nodes(&"biome_transition_gates").is_empty(), "standard survival does not instantiate biome transition gate nodes")

# --- attraversamento di un varco senza portali ------------------------------
# (milestone_10_no_portal_transition)

func test_seam_crossing_through_open_passage() -> void:
	var biome_manager: BiomeManager = _scene.node(&"biome_manager") as BiomeManager
	var world_runtime: WorldRuntime = _scene.node(&"world_runtime") as WorldRuntime
	var seam_system = _scene.node(&"region_seam_system")
	var transition_system: BiomeTransitionSystem = _scene.node(&"biome_transition_system") as BiomeTransitionSystem
	var player_manager: PlayerManager = _scene.node(&"player_manager") as PlayerManager
	var streamer: WorldRegionStreamer = _scene.node(&"world_region_streamer") as WorldRegionStreamer
	assert_not_null(seam_system, "region seam system is available")
	assert_not_null(transition_system, "legacy transition command API is available")
	assert_not_null(player_manager, "player manager is available")
	assert_not_null(streamer, "world region streamer is available")
	if biome_manager == null or world_runtime == null or seam_system == null or player_manager == null or streamer == null:
		return

	seam_system.set("transition_cooldown", 0.01)
	assert_true(_scene.start_survival({
		"world_seed": 31337, "biome_map_width": 3, "biome_map_height": 3, "extra_edge_chance": 0.5
	}), "survival starts with persistent megamap")
	await wait_physics_frames(1)
	await wait_physics_frames(1)

	assert_true(_scene.nodes(&"biome_transition_gates").is_empty(), "survival creates no biome transition gate nodes")
	var start_cell := biome_manager.get_current_biome_cell()
	var graph := biome_manager.get_world_graph()
	assert_not_null(start_cell, "current region cell exists")
	assert_not_null(graph, "world graph exists")
	if start_cell == null or graph == null or start_cell.passages.is_empty():
		return

	var connection := _first_connection_for_cell(graph, start_cell)
	assert_not_null(connection, "start region has an open connection")
	if connection == null:
		return
	var player := player_manager.players.get(1) as Node2D
	assert_not_null(player, "player one exists")
	var crossing_position: Vector2 = seam_system.get_crossing_position_for_connection(connection, graph.start_region_id)
	seam_system.set("cooldown_timer", 0.0)
	assert_false(
		seam_system.try_update_region_for_position(crossing_position),
		"the seam defers its biome change while the destination is not FULL"
	)
	assert_eq(
		biome_manager.get_current_region_id(),
		start_cell.id,
		"readiness wait keeps the source biome authoritative"
	)
	var requested_ids: Array[StringName] = streamer.refresh_near_world_residency(
		crossing_position
	)
	assert_true(
		requested_ids.has(connection.to_region_id),
		"approaching the seam requests its destination"
	)
	assert_true(
		await _wait_for_streamed_region_full(streamer, connection.to_region_id),
		"destination is gameplay-ready before the seam changes biome"
	)
	var source_root_id := streamer.get_region_environment_root_instance_id(start_cell.id)
	var target_root_id := streamer.get_region_environment_root_instance_id(connection.to_region_id)
	assert_ne(source_root_id, 0, "source region root exists before crossing")
	assert_ne(target_root_id, 0, "destination region is gameplay-ready before crossing")
	if player != null:
		player.global_position = crossing_position
	seam_system.set("cooldown_timer", 0.0)
	assert_true(seam_system.try_update_region_for_position(crossing_position),
		"world-space crossing through an open passage changes region")
	await wait_physics_frames(1)
	assert_eq(biome_manager.get_current_region_id(), connection.to_region_id, "biome manager follows the crossed seam")
	assert_eq(world_runtime.get_current_region_id(), connection.to_region_id, "world runtime follows the crossed seam")
	assert_eq(streamer.get_region_environment_root_instance_id(start_cell.id), source_root_id,
		"source region root is preserved instead of globally rebuilt")
	assert_eq(streamer.get_region_environment_root_instance_id(connection.to_region_id), target_root_id,
		"destination region root is reused without a loading rebuild")
	assert_true(_scene.nodes(&"biome_transition_gates").is_empty(), "crossing a seam still creates no gate nodes")

	var target_region := graph.get_region(connection.to_region_id)
	var reverse_connection: WorldRegionConnection = null
	if target_region != null:
		for candidate in target_region.connection_edges:
			if candidate.to_region_id == start_cell.id:
				reverse_connection = candidate
				break
	assert_not_null(reverse_connection, "destination exposes the reverse physical connection")
	if reverse_connection != null:
		var return_position: Vector2 = seam_system.get_crossing_position_for_connection(
			reverse_connection,
			graph.start_region_id
		)
		if player != null:
			player.global_position = return_position
		seam_system.set("cooldown_timer", 0.0)
		assert_true(seam_system.try_update_region_for_position(return_position),
			"the party can cross the same seam backwards")
		await wait_physics_frames(1)
		assert_eq(streamer.get_region_environment_root_instance_id(start_cell.id), source_root_id,
			"the source root is reused on the return crossing")
		assert_eq(streamer.get_region_environment_root_instance_id(connection.to_region_id), target_root_id,
			"the destination root is retained after the return crossing")
	seam_system.set("cooldown_timer", 0.0)
	var blocked_position := _blocked_border_position(graph, start_cell)
	assert_false(seam_system.try_update_region_for_position(blocked_position),
		"crossing a border without an open edge is rejected")
	assert_eq(biome_manager.get_current_region_id(), start_cell.id, "blocked border crossing keeps the current region")

# --- la transizione segue il movimento fisico, niente teleport --------------
# (open_passage_transition)

func test_open_passage_follows_physical_movement() -> void:
	var biome_manager: BiomeManager = _scene.node(&"biome_manager") as BiomeManager
	var world_runtime: WorldRuntime = _scene.node(&"world_runtime") as WorldRuntime
	var seam_system = _scene.node(&"region_seam_system")
	var transition_system: BiomeTransitionSystem = _scene.node(&"biome_transition_system") as BiomeTransitionSystem
	var player_manager: PlayerManager = _scene.node(&"player_manager") as PlayerManager
	var streamer: WorldRegionStreamer = _scene.node(&"world_region_streamer") as WorldRegionStreamer
	assert_not_null(seam_system, "region seam system is available")
	assert_not_null(transition_system, "transition system is available")
	assert_not_null(player_manager, "player manager is available")
	if biome_manager == null or world_runtime == null or seam_system == null or player_manager == null or streamer == null:
		return

	transition_system.transition_cooldown = 0.01
	transition_system.move_party_on_transition = false
	seam_system.set("transition_cooldown", 0.01)
	assert_true(_scene.start_survival({
		"world_seed": 31337, "biome_map_width": 3, "biome_map_height": 3, "extra_edge_chance": 0.5
	}), "survival starts with persistent megamap")
	await wait_physics_frames(1)
	await wait_physics_frames(1)

	var start_cell := biome_manager.get_current_biome_cell()
	var graph := biome_manager.get_world_graph()
	assert_not_null(start_cell, "current region cell exists")
	assert_not_null(graph, "world graph exists")
	assert_eq(world_runtime.get_current_region_id(), start_cell.id, "world runtime tracks current region")
	assert_true(_scene.nodes(&"biome_transition_gates").is_empty(), "no biome transition gate nodes exist")
	if start_cell == null or graph == null or start_cell.passages.is_empty():
		return
	var player := player_manager.players.get(1) as PlayerController
	assert_not_null(player, "player one exists")
	# Anchor the party at the region centre before measuring so this case is isolated
	# from whatever position a previous test left in the shared scene (the seam sits
	# at a region border, far from the centre, so a real crossing moves well past 80).
	if player != null:
		player.global_position = Vector2.ZERO
	var original_position: Vector2 = player.global_position if player != null else Vector2.ZERO
	var connection := _first_connection_for_cell(graph, start_cell)
	assert_not_null(connection, "start cell has an open WorldRegionConnection")
	if connection == null:
		return
	var crossing_position: Vector2 = seam_system.get_crossing_position_for_connection(connection, graph.start_region_id)
	streamer.refresh_near_world_residency(crossing_position)
	assert_true(
		await _wait_for_streamed_region_full(streamer, connection.to_region_id),
		"movement transition waits for its near-world destination"
	)
	if player != null:
		player.global_position = crossing_position
	seam_system.set("cooldown_timer", 0.0)
	assert_true(seam_system.try_update_region_for_position(crossing_position),
		"world-space seam crossing uses the target region id")
	await wait_physics_frames(1)
	assert_eq(biome_manager.get_current_region_id(), connection.to_region_id, "biome manager changes to target region")
	assert_eq(world_runtime.get_current_region_id(), connection.to_region_id, "world runtime changes to target region")
	if player != null:
		assert_gt(player.global_position.distance_to(original_position), 80.0,
			"transition follows physical movement instead of teleporting the party")
	assert_true(_scene.nodes(&"biome_transition_gates").is_empty(), "generated passages do not require open passage nodes")

# --- inseguimento di un nemico attraverso il seam ---------------------------
# (milestone_10_cross_biome_chase)

func test_enemy_chases_across_biome_seam() -> void:
	var biome_manager: BiomeManager = _scene.node(&"biome_manager") as BiomeManager
	var player_manager: PlayerManager = _scene.node(&"player_manager") as PlayerManager
	var enemy_system: EnemySystem = _scene.node(&"enemy_system") as EnemySystem
	var world_runtime: WorldRuntime = _scene.node(&"world_runtime") as WorldRuntime
	var seam_system = _scene.node(&"region_seam_system")
	var zombie_spawner: ZombieSpawner = _scene.node(&"zombie_spawner") as ZombieSpawner
	var streamer = _scene.node(&"world_region_streamer")
	var multi_region_renderer = _scene.node(&"multi_region_renderer")
	assert_not_null(enemy_system, "enemy system is available")
	assert_not_null(seam_system, "region seam system is available")
	assert_not_null(zombie_spawner, "zombie spawner is available")
	assert_not_null(streamer, "world region streamer is available")
	if biome_manager == null or player_manager == null or enemy_system == null or seam_system == null or zombie_spawner == null or streamer == null:
		return

	if streamer != null:
		streamer.set("active_radius", 0)
		streamer.set("unload_grace_seconds", 0.0)
	if world_runtime != null:
		world_runtime.loaded_region_radius = 0
	if multi_region_renderer != null:
		multi_region_renderer.set("neighbor_radius", 0)
	assert_true(_scene.start_survival({
		"world_seed": 91919, "biome_map_width": 3, "biome_map_height": 3, "extra_edge_chance": 0.5
	}), "survival starts for cross-biome chase")
	await wait_physics_frames(1)
	await wait_physics_frames(1)

	var graph := biome_manager.get_world_graph()
	var start_cell := biome_manager.get_current_biome_cell()
	assert_not_null(graph, "world graph exists")
	assert_not_null(start_cell, "current region exists")
	if graph == null or start_cell == null:
		return
	var connection := _first_connection_for_cell(graph, start_cell)
	assert_not_null(connection, "start region has an open connection")
	if connection == null:
		return

	var player := player_manager.players.get(1) as Node2D
	assert_not_null(player, "player one exists")
	if player == null:
		return
	var direction := _direction_for_side(connection.side)
	var crossing_position: Vector2 = seam_system.get_crossing_position_for_connection(connection, graph.start_region_id)
	streamer.refresh_near_world_residency(crossing_position)
	assert_true(
		await _wait_for_streamed_region_full(streamer, connection.to_region_id),
		"chase target region is FULL before crossing"
	)
	var source_root_id: int = int(
		streamer.get_region_environment_root_instance_id(start_cell.id)
	)
	var enemy_position := crossing_position - direction * 180.0
	var spawn_region_id := StringName(seam_system.get_region_id_for_world_position(enemy_position))
	assert_eq(spawn_region_id, start_cell.id, "enemy spawn remains in source region")
	var enemy := enemy_system.spawn_enemy(&"survival_zombie", enemy_position, null, {"wave_index": 1}) as BasicEnemy
	assert_not_null(enemy, "enemy spawns on source side of seam")
	if enemy == null:
		return
	player.global_position = crossing_position
	seam_system.set("cooldown_timer", 0.0)
	assert_true(seam_system.try_update_region_for_position(crossing_position),
		"player crossing updates the current region before chase")
	await wait_physics_frames(1)
	assert_eq(streamer.get_region_environment_root_instance_id(start_cell.id), source_root_id,
		"a source region containing an enemy stays pinned outside active_regions")
	player.global_position = crossing_position + direction * 220.0

	enemy.detection_range = 4000.0
	enemy.move_speed = 180.0
	enemy.target_refresh_interval = 0.01
	var health_before := enemy.health_component.current_health

	for _frame in range(180):
		await wait_physics_frames(1)
		if enemy == null or not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			break
		if enemy.current_region_id == connection.to_region_id:
			break

	assert_true(is_instance_valid(enemy) and not enemy.is_queued_for_deletion(), "enemy is not despawned by region crossing")
	assert_true(enemy_system.get_active_enemies().has(enemy), "enemy remains registered while chasing across biome")
	assert_eq(enemy.spawn_region_id, start_cell.id, "enemy keeps its spawn region metadata")
	assert_eq(enemy.current_region_id, connection.to_region_id, "enemy updates current region after crossing the seam")
	assert_eq(enemy.last_seen_player_region_id, connection.to_region_id, "enemy tracks target region across the seam")
	assert_true(enemy.get_state_name() == &"chase" or enemy.get_state_name() == &"attack", "enemy keeps chase/attack state across biome")
	assert_eq(enemy.target, player, "enemy keeps the same player target")
	assert_eq(enemy.health_component.current_health, health_before, "region change does not reset enemy health")
	assert_true(
		zombie_spawner.is_spawn_position_valid(player.global_position + direction * zombie_spawner.spawn_margin, biome_manager.get_current_biome())
		or not seam_system.get_region_id_for_world_position(player.global_position).is_empty(),
		"spawner can reason about positions in streamed world-space")

	if is_instance_valid(enemy):
		enemy.queue_free()
	var target_region := graph.get_region(connection.to_region_id)
	if target_region != null:
		player.global_position = seam_system.logical_tile_to_world_position(
			target_region.world_origin + target_region.size_tiles / 2,
			graph.start_region_id
		)
	for _frame in range(12):
		await wait_physics_frames(1)
	assert_eq(streamer.get_region_environment_root_instance_id(start_cell.id), 0,
		"the source region unloads after its last runtime pin leaves and the party exits its near-world band")

# --- generazione del mondo a biomi e transizione via comando ----------------
# (biome_world_generation)

func test_biome_world_generation() -> void:
	var biome_manager: BiomeManager = _scene.node(&"biome_manager") as BiomeManager
	var obstacle_system: ObstacleSystem = _scene.node(&"obstacle_system") as ObstacleSystem
	var hazard_system: HazardSystem = _scene.node(&"hazard_system") as HazardSystem
	var crate_system: ResourceCrateSystem = _scene.node(&"resource_crate_system") as ResourceCrateSystem
	var transition_system: BiomeTransitionSystem = _scene.node(&"biome_transition_system") as BiomeTransitionSystem
	var zombie_spawner: ZombieSpawner = _scene.node(&"zombie_spawner") as ZombieSpawner
	assert_not_null(biome_manager, "biome manager is available")
	assert_not_null(transition_system, "transition system is available")
	assert_not_null(zombie_spawner, "zombie spawner is available")
	if biome_manager == null or obstacle_system == null or hazard_system == null or crate_system == null or transition_system == null or zombie_spawner == null:
		return

	# Determinismo della mappa: build dirette del BiomeManager (no survival).
	var seed_context := {"world_seed": 424242, "preserve_biome_sequence": false}
	biome_manager.start_run(seed_context)
	var signature_a := biome_manager.get_generation_signature()
	biome_manager.start_run(seed_context)
	var signature_b := biome_manager.get_generation_signature()
	biome_manager.start_run({"world_seed": 424243, "preserve_biome_sequence": false})
	var signature_c := biome_manager.get_generation_signature()
	assert_eq(signature_a, signature_b, "same seed regenerates identical biome map")
	assert_ne(signature_a, signature_c, "different seed changes generated map signature")
	assert_eq(int(biome_manager.get_seed_record().get("global_seed", 0)), 424243, "seed record stores the current global seed")

	var cells := biome_manager.get_generated_biome_map()
	assert_gte(cells.size(), 4, "global biome map contains the planned biome cells")
	var start_cell := biome_manager.get_current_biome_cell()
	assert_true(start_cell != null and start_cell.biome_id == &"plains", "generated run starts from the base biome")
	for cell in cells:
		_validate_cell(cell)

	var base_layout := (start_cell.generated_layout if start_cell != null else null)
	assert_not_null(base_layout, "starting biome has a generated layout")
	if base_layout != null:
		assert_eq(base_layout.zone_size, BiomeEnvironmentLayout.DEFAULT_ZONE_SIZE, "starting biome uses the shared cardinal grid size")
		assert_eq(base_layout.parcel_types.count(BiomeEnvironmentLayout.PARCEL_MESA), 1,
			"base biome contains its guaranteed mesa parcel")
		assert_eq(base_layout.parcel_types.count(BiomeEnvironmentLayout.PARCEL_TOWN), 1,
			"base biome contains its guaranteed town parcel")
		assert_true((not base_layout.road_rects.is_empty() or not base_layout.get_road_cells().is_empty()) and not base_layout.crate_cells.is_empty(),
			"base biome has roads, corridors and resource crates")

	transition_system.transition_cooldown = 0.01
	assert_true(_scene.start_survival({"world_seed": 424242, "preserve_biome_sequence": true}), "survival starts with generated biome map context")
	await wait_physics_frames(1)
	await wait_physics_frames(1)

	var active_cell := biome_manager.get_current_biome_cell()
	var active_biome := biome_manager.get_current_biome() as BiomeDefinition
	var active_layout := (active_cell.generated_layout if active_cell != null else null)
	assert_true(active_cell != null and active_cell.biome_id == &"plains", "survival uses the generated starting cell")
	if active_layout != null and active_biome != null:
		assert_gte(obstacle_system.get_active_obstacles().size(), active_layout.obstacle_positions.size(),
			"obstacle system renders at least the generated current-region obstacle layout")
		assert_gte(hazard_system.get_active_hazards().size(), active_layout.hazard_positions.size(),
			"hazard system renders at least the current-region fall zones and biome hazards")
		assert_gte(crate_system.get_active_crates().size(), active_layout.crate_positions.size(),
			"resource crate system renders at least the current-region generated crates")
		assert_true(_scene.nodes(&"biome_transition_gates").is_empty(), "generated passages no longer instantiate transition gates")
		if not active_layout.fall_zone_rects.is_empty():
			var fall_position := active_layout.rect_center_to_world(active_layout.fall_zone_rects.front())
			assert_false(zombie_spawner.is_spawn_position_valid(fall_position, active_biome), "zombie spawner rejects generated fall zones")

	if active_cell != null and not active_cell.passages.is_empty():
		var passage: BiomePassage = active_cell.passages.front()
		transition_system.cooldown_timer = 0.0
		assert_true(transition_system.transition_to(passage.to_biome_id, passage.side, passage.to_cell_id),
			"generated passage transitions to the neighbor biome")
		await wait_physics_frames(1)
		assert_ne(biome_manager.get_current_biome_cell(), active_cell, "biome manager advances to the generated neighbor cell")

# --- transizioni multi-step con terreno/loot/HUD per biome ------------------
# (zombie_biome_transition)

func test_zombie_biome_transition() -> void:
	var biome_manager: BiomeManager = _scene.node(&"biome_manager") as BiomeManager
	var transition_system: BiomeTransitionSystem = _scene.node(&"biome_transition_system") as BiomeTransitionSystem
	var terrain_generator: TerrainGenerator = _scene.node(&"terrain_generator") as TerrainGenerator
	var obstacle_system: ObstacleSystem = _scene.node(&"obstacle_system") as ObstacleSystem
	var crate_system: ResourceCrateSystem = _scene.node(&"resource_crate_system") as ResourceCrateSystem
	var streamer = _scene.node(&"world_region_streamer")
	var multi_region_renderer = _scene.node(&"multi_region_renderer")
	var hud: HUDManager = _scene.node(&"hud_manager") as HUDManager
	assert_not_null(transition_system, "transition system is available")
	assert_not_null(terrain_generator, "terrain generator is available")
	assert_not_null(hud, "HUD is available")
	if biome_manager == null or transition_system == null or terrain_generator == null or obstacle_system == null or crate_system == null or streamer == null or hud == null:
		return

	transition_system.transition_cooldown = 0.01
	streamer.set("active_radius", 0)
	var world_runtime: WorldRuntime = _scene.node(&"world_runtime") as WorldRuntime
	if world_runtime != null:
		world_runtime.loaded_region_radius = 0
	if multi_region_renderer != null:
		multi_region_renderer.set("neighbor_radius", 0)
	assert_true(_scene.start_survival(), "survival starts with biome transitions")
	await wait_physics_frames(1)
	await wait_physics_frames(1)

	var graph := biome_manager.get_world_graph()
	assert_true(graph != null and graph.is_graph_connected(), "persistent biome graph is connected")
	var seen_biomes := {}
	for step in range(2):
		var cell := biome_manager.get_current_biome_cell()
		assert_not_null(cell, "current region exists at step %d" % step)
		if cell == null:
			break
		assert_true(
			await _wait_for_streamed_region_full(streamer, cell.id),
			"%s reaches FULL before its debug transition assertions"
			% String(cell.id)
		)
		var biome_id := cell.biome_id
		seen_biomes[biome_id] = true
		var biome := biome_manager.get_current_biome() as BiomeDefinition
		assert_true(biome != null and biome.biome_id == biome_id, "biome manager selects region %s biome %s" % [String(cell.id), String(biome_id)])
		if biome == null or biome.environment_layout == null:
			continue
		var layout := biome.environment_layout
		assert_eq(terrain_generator.get_active_biome_id(), biome_id, "terrain switches to %s" % String(biome_id))
		var tile_layer := terrain_generator.get_active_tile_layer()
		assert_not_null(tile_layer, "%s creates an asset tile layer" % String(biome_id))
		if tile_layer != null:
			assert_eq(tile_layer.get_visual_tile_count(), layout.zone_size.x * layout.zone_size.y, "%s tile layer covers every logical cell" % String(biome_id))
			assert_eq(tile_layer.get_missing_asset_count(), 0, "%s tile layer has no missing visual cells" % String(biome_id))
			assert_true(tile_layer.palette == biome.palette, "%s palette is applied to the tile layer" % String(biome_id))
		_expect_streamed_region_content(streamer, cell, layout)
		assert_true(_has_blocked_boundary(obstacle_system), "%s retains a physical blocked boundary" % String(biome_id))
		assert_true(_scene.nodes(&"biome_transition_gates").is_empty(), "%s exposes open passages without runtime gates" % String(biome_id))
		assert_true(_has_thematic_loot(crate_system, biome_id), "%s exposes biome-aware crate loot" % String(biome_id))
		await wait_physics_frames(1)
		assert_true(biome.display_name in hud.status_label.text, "HUD displays %s" % biome.display_name)
		if step == 0 and not cell.passages.is_empty():
			var passage: BiomePassage = cell.passages.front()
			transition_system.cooldown_timer = 0.0
			assert_true(transition_system.transition_to(passage.to_biome_id, passage.side, passage.to_cell_id),
				"transition follows physical passage to %s" % String(passage.to_cell_id))
			await wait_physics_frames(1)
			await wait_physics_frames(1)

	if graph != null:
		var graph_biomes := {}
		for region in graph.get_regions_sorted():
			graph_biomes[region.biome_id] = true
		for required_biome in [&"plains", &"burning_plains", &"frozen_tundra", &"swamp"]:
			assert_true(graph_biomes.has(required_biome), "graph contains %s" % String(required_biome))

	var marsh := biome_manager.get_biome_definition(&"swamp") as BiomeDefinition
	var themed_enemy_found := false
	if marsh != null:
		for spawn_index in range(40):
			var enemy_id := marsh.resolve_enemy_id(5, spawn_index, 40)
			if String(enemy_id).contains("drowned") or String(enemy_id).contains("marsh") or String(enemy_id).contains("water"):
				themed_enemy_found = true
				break
	assert_true(themed_enemy_found, "advanced biome wave resolves thematic enemies")

# --- ambiente generato: ostacoli, casse, corridoio, teardown ----------------
# (zombie_environment_milestone)

func test_zombie_environment_milestone() -> void:
	var biome_manager: BiomeManager = _scene.node(&"biome_manager") as BiomeManager
	var terrain_generator: TerrainGenerator = _scene.node(&"terrain_generator") as TerrainGenerator
	var obstacle_system: ObstacleSystem = _scene.node(&"obstacle_system") as ObstacleSystem
	var resource_crate_system: ResourceCrateSystem = _scene.node(&"resource_crate_system") as ResourceCrateSystem
	var hazard_system: HazardSystem = _scene.node(&"hazard_system") as HazardSystem
	var enemy_system: EnemySystem = _scene.node(&"enemy_system") as EnemySystem
	var survival_mode = _scene.survival_mode()
	assert_not_null(terrain_generator, "terrain generator is available")
	assert_not_null(obstacle_system, "obstacle system is available")
	assert_not_null(resource_crate_system, "resource crate system is available")
	assert_not_null(survival_mode, "survival mode is available")
	if biome_manager == null or terrain_generator == null or obstacle_system == null or resource_crate_system == null or hazard_system == null or enemy_system == null or survival_mode == null:
		return

	assert_true(_scene.start_survival(), "survival starts with the environment milestone enabled")
	await wait_physics_frames(2)
	await wait_physics_frames(1)

	var biome := biome_manager.get_current_biome() as BiomeDefinition
	var layout := biome.environment_layout
	var palette := biome.palette
	assert_eq(biome_manager.get_current_biome_id(), &"plains", "environment generation starts from Pianura Infetta")
	assert_not_null(layout, "starting biome exposes an environment layout")
	if layout == null or palette == null:
		return

	var tile_layer := terrain_generator.get_active_tile_layer()
	assert_not_null(tile_layer, "terrain generator creates the asset tile layer")
	if tile_layer != null:
		assert_eq(tile_layer.get_visual_tile_count(), layout.zone_size.x * layout.zone_size.y, "asset tile layer covers the full generated layout")
		assert_eq(tile_layer.get_missing_asset_count(), 0, "asset tile layer has no missing visual cells")
		assert_true(tile_layer.palette == palette, "starting biome palette is applied to the tile layer")

	var player: Node2D = _scene.node(&"players") as Node2D
	if player != null:
		player.global_position = Vector2.ZERO

	var obstacles: Array = obstacle_system.get_active_obstacles()
	assert_gte(obstacles.size(), layout.obstacle_positions.size(), "obstacle system creates at least the deterministic starting layout")
	var spawned_obstacle_ids: Array[StringName] = []
	var current_region_obstacles: Array = []
	for obstacle in obstacles:
		if obstacle == null:
			continue
		if obstacle is Node2D and _position_matches_any((obstacle as Node2D).global_position, layout.obstacle_positions):
			current_region_obstacles.append(obstacle)
		spawned_obstacle_ids.append(StringName(obstacle.get("obstacle_id")))
		assert_true(obstacle is StaticBody2D and int(obstacle.get("collision_layer")) & BiomeObstacle.MOVEMENT_BLOCK_LAYER_BIT != 0,
			"environment obstacle is a physical body on the shared movement layer")
		assert_true(obstacle.is_in_group("environment_obstacles") and obstacle.is_in_group("spawn_blockers"),
			"environment obstacle participates in spawn validation")
	assert_eq(current_region_obstacles.size(), layout.obstacle_positions.size(), "obstacle system creates every current-region configured obstacle")
	for required_id in [&"large_rock", &"forest_tree"]:
		assert_true(spawned_obstacle_ids.has(required_id), "%s is present in the starting biome" % String(required_id))
	if layout.obstacle_ids.has(&"boundary_fence"):
		assert_true(spawned_obstacle_ids.has(&"boundary_fence"), "generated solid boundary is represented at runtime")
	else:
		assert_false(layout.fall_zone_rects.is_empty(), "fall/cliff boundary replaces a solid fence when the generated edge is void")

	for safe_point in [Vector2.ZERO, Vector2(0.0, -180.0), Vector2(0.0, 180.0), Vector2(-120.0, 0.0), Vector2(120.0, 0.0)]:
		assert_false(obstacle_system.is_position_blocked(safe_point), "central combat corridor remains open at %s" % safe_point)
		assert_false(hazard_system.is_position_hazardous(safe_point), "central combat corridor avoids hazards at %s" % safe_point)

	if not current_region_obstacles.is_empty():
		var first_obstacle := current_region_obstacles[0] as Node2D
		assert_true(obstacle_system.is_position_blocked(first_obstacle.global_position), "obstacle center is rejected by placement validation")
		assert_true(_physics_query_finds_obstacle(first_obstacle), "physics space contains the generated obstacle collision")

	var crates: Array = resource_crate_system.get_active_crates()
	var crate_ids: Array[StringName] = resource_crate_system.get_active_crate_ids()
	var current_region_crates: Array = []
	for active_crate in crates:
		if active_crate is Node2D and _position_matches_any((active_crate as Node2D).global_position, layout.crate_positions):
			current_region_crates.append(active_crate)
	assert_true(crates.size() >= layout.crate_positions.size() and current_region_crates.size() == layout.crate_positions.size(),
		"resource crate system creates every current-region configured crate (%d current/%d configured)" % [current_region_crates.size(), layout.crate_positions.size()])
	assert_true(crate_ids.has(&"common") and crate_ids.has(&"medical"), "starting biome provides common and medical resources")
	for crate in current_region_crates:
		var crate_node := crate as SupplyCrate
		if crate_node == null:
			continue
		assert_false(obstacle_system.is_position_blocked(crate_node.global_position), "resource crate does not overlap a physical obstacle")
		assert_false(hazard_system.is_position_hazardous(crate_node.global_position), "resource crate does not overlap an environment hazard")
		assert_lte(_distance_to_nearest_player(crate_node.global_position), layout.logical_tile_scale * 30.0, "resource crate is reachable from the party start")
	assert_true(
		_crate_loot_contains(current_region_crates, &"common", GameConstants.DROP_MONEY)
		and _crate_loot_contains(current_region_crates, &"medical", GameConstants.DROP_HEALTH),
		"crate loot changes between common and medical containers")

	if player != null:
		player.global_position = Vector2.ZERO
	var lane_enemy := enemy_system.spawn_enemy(&"survival_zombie", Vector2(0.0, -180.0)) as BasicEnemy
	assert_not_null(lane_enemy, "a zombie can spawn in the open north lane")
	if lane_enemy != null and player != null:
		var initial_distance := lane_enemy.global_position.distance_to(player.global_position)
		for _frame in range(90):
			await wait_physics_frames(1)
		assert_true(is_instance_valid(lane_enemy), "zombie stays alive while crossing the preserved central corridor")
		if is_instance_valid(lane_enemy):
			var final_distance := lane_enemy.global_position.distance_to(player.global_position)
			assert_lt(final_distance, initial_distance - 80.0, "zombie advances through the preserved central corridor")
			lane_enemy.queue_free()

	survival_mode.stop_mode()
	await wait_physics_frames(2)
	assert_true(obstacle_system.get_active_obstacles().is_empty(), "physical obstacles are removed when survival stops")
	assert_true(resource_crate_system.get_active_crates().is_empty(), "environment resource crates are removed when survival stops")

# --- fall hazard: danno/respawn/invulnerabilità, dodge sul void, morte da void
# (zombie_fall_hazard)

func test_zombie_fall_hazard() -> void:
	_cue_ids = []
	_spawned_drop_count = 0
	_void_enemy_death_reason = &""

	var hazard_system: HazardSystem = _scene.node(&"hazard_system") as HazardSystem
	var zombie_spawner: ZombieSpawner = _scene.node(&"zombie_spawner") as ZombieSpawner
	var enemy_system: EnemySystem = _scene.node(&"enemy_system") as EnemySystem
	var drop_system: DropSystem = _scene.node(&"drop_system") as DropSystem
	var health_system: HealthSystem = _scene.node(&"health_system") as HealthSystem
	var gameplay_effects: GameplayEffects = _scene.node(&"gameplay_effects") as GameplayEffects
	var audio_manager: AudioManager = _scene.node(&"audio_manager") as AudioManager
	var player: PlayerController = _scene.node(&"players") as PlayerController
	assert_not_null(hazard_system, "hazard system is available")
	assert_not_null(drop_system, "drop system is available")
	assert_not_null(gameplay_effects, "gameplay effects are available")
	assert_not_null(audio_manager, "audio manager is available")
	assert_not_null(player, "player one is available")
	if hazard_system == null or zombie_spawner == null or enemy_system == null or drop_system == null or health_system == null or gameplay_effects == null or audio_manager == null or player == null:
		return

	audio_manager.cue_played.connect(_on_cue_played)
	drop_system.drop_spawned.connect(_on_drop_spawned)
	hazard_system.safe_position_update_interval = 0.05
	hazard_system.fall_respawn_invulnerability = 0.20
	hazard_system.fall_retrigger_cooldown = 0.15
	assert_eq(hazard_system.fall_damage, 20, "fall damage defaults to exactly 20 HP")
	assert_true(_scene.start_survival(), "survival starts with fall hazards enabled")
	await wait_physics_frames(2)
	await wait_physics_frames(1)

	var hazards := hazard_system.get_active_hazards()
	assert_gte(hazards.size(), 1, "starting biome creates fall zone coverage")
	if hazards.is_empty():
		_disconnect_fall_signals(audio_manager, drop_system)
		return
	var fall_zone := hazards[0] as BiomeFallZone
	assert_not_null(fall_zone, "generated hazard uses BiomeFallZone")
	if fall_zone == null:
		_disconnect_fall_signals(audio_manager, drop_system)
		return
	assert_true(fall_zone.is_in_group("fall_zones") and fall_zone.is_in_group("environment_hazards"),
		"fall zone is registered for hazard and spawn validation")
	assert_true(hazard_system.is_position_hazardous(fall_zone.global_position), "fall zone center is reported as hazardous")
	assert_true(hazard_system.is_position_fall_zone(fall_zone.global_position), "fall zone center is reported by the dedicated fall query")
	assert_false(hazard_system.is_position_environment_hazard(fall_zone.global_position), "fall zone is not reported as a generic environment hazard")
	assert_eq(fall_zone.get_fall_style(), &"cliff", "starting biome fall zone uses the default cliff visual style")

	var runtime_environment_hazard := hazard_system.spawn_runtime_hazard(&"fire_zone", Vector2(520.0, 0.0))
	assert_not_null(runtime_environment_hazard, "runtime environmental hazard can be spawned for query checks")
	if runtime_environment_hazard != null:
		await wait_physics_frames(1)
		assert_true(hazard_system.is_position_environment_hazard(runtime_environment_hazard.global_position), "environmental hazard is reported by the environment query")
		assert_false(hazard_system.is_position_fall_zone(runtime_environment_hazard.global_position), "environmental hazard is not reported as a fall zone")
	assert_false(zombie_spawner.is_spawn_position_valid(fall_zone.global_position), "zombie spawner rejects the fall zone")

	var safe_position := Vector2(120.0, 0.0)
	player.global_position = safe_position
	player.velocity = Vector2(80.0, 0.0)
	for _frame in range(8):
		await wait_physics_frames(1)
	var recorded_safe_position := hazard_system.get_last_safe_position(player)
	assert_lt(recorded_safe_position.distance_to(safe_position), 2.0, "safe-position tracker records a valid player location")
	assert_false(hazard_system.is_position_safe(fall_zone.global_position + Vector2(fall_zone.zone_size.x * 0.5 + 12.0, 0.0)),
		"safe positions require clearance from the fall zone")

	var health := player.health_component
	var health_before := health.current_health
	var external_source := &"test_external_invulnerability"
	var fall_source := StringName("fall_respawn_%d" % player.get_instance_id())
	health.add_invulnerability_source(external_source)
	var effect_count_before := gameplay_effects.effect_spawn_count
	player.global_position = fall_zone.global_position
	for _frame in range(30):
		await wait_physics_frames(1)
		if health.current_health < health_before:
			break

	assert_eq(health.current_health, health_before - 20, "fall applies exactly 20 HP even during another invulnerability")
	assert_lt(player.global_position.distance_to(recorded_safe_position), 2.0, "player respawns at the last safe position")
	assert_true(player.velocity.is_zero_approx(), "respawn clears player velocity")
	assert_true(health.has_invulnerability_source(fall_source), "fall grants a dedicated temporary invulnerability source")
	assert_true(health.has_invulnerability_source(external_source), "fall does not replace an existing invulnerability source")
	assert_true(
		gameplay_effects.effect_spawn_count >= effect_count_before + 2
		and _has_effect_kind(gameplay_effects, &"fall_damage")
		and _has_effect_kind(gameplay_effects, &"fall_respawn"),
		"fall generates damage and respawn visual feedback")
	assert_true(_cue_ids.has(&"player_fell"), "fall generates its environment audio cue")
	assert_false(hazard_system.trigger_fall(player, fall_zone), "fall cooldown prevents an immediate duplicate trigger")

	for _frame in range(24):
		await wait_physics_frames(1)
	assert_false(health.has_invulnerability_source(fall_source), "fall invulnerability expires after the configured duration")
	assert_true(health.has_invulnerability_source(external_source) and health.is_invulnerable(), "other invulnerability remains active after fall recovery")
	health.remove_invulnerability_source(external_source)
	assert_false(health.is_invulnerable(), "player becomes vulnerable when all sources are removed")

	var health_before_void_dodge := health.current_health
	_start_test_dodge(player, fall_zone.global_position, fall_zone.global_position, 0.18)
	for _frame in range(4):
		await wait_physics_frames(1)
	assert_true(player.get_entity_state_name() == &"dodging" and health.current_health == health_before_void_dodge,
		"void does not damage or interrupt an active dodge")
	for _frame in range(18):
		await wait_physics_frames(1)
		if player.get_entity_state_name() == &"falling":
			break
	assert_true(player.get_entity_state_name() == &"falling" and health.current_health == health_before_void_dodge,
		"dodge landing on void starts falling before damage")
	for _frame in range(40):
		await wait_physics_frames(1)
		if health.current_health < health_before_void_dodge:
			break
	assert_true(health.current_health == health_before_void_dodge - 20 and player.global_position.distance_to(recorded_safe_position) < 2.0,
		"void dodge landing applies one fall hit and respawns safely")

	var health_before_safe_dodge := health.current_health
	_start_test_dodge(player, recorded_safe_position, recorded_safe_position + Vector2(8.0, 0.0), 0.12)
	for _frame in range(16):
		await wait_physics_frames(1)
	assert_true(player.get_entity_state_name() == &"normal" and health.current_health == health_before_safe_dodge,
		"dodge landing on walkable terrain returns to normal without damage")

	var guaranteed_entry := DropEntry.new()
	guaranteed_entry.drop_type = GameConstants.DROP_MONEY
	guaranteed_entry.chance = 1.0
	guaranteed_entry.min_amount = 10
	guaranteed_entry.max_amount = 10
	var guaranteed_loot := LootTable.new()
	guaranteed_loot.entries.append(guaranteed_entry)
	var enemy := enemy_system.spawn_enemy(&"basic_zombie", recorded_safe_position + Vector2(32.0, 0.0)) as BasicEnemy
	assert_not_null(enemy, "test zombie spawns for void-death validation")
	if enemy != null:
		enemy.loot_table = guaranteed_loot
		enemy.kill_experience = 23
		enemy.died.connect(_on_test_enemy_died)
		health_system.apply_damage(enemy, 1, player, &"test_player_damage")
		var experience_before := player.rpg_component.experience
		var drops_before := _spawned_drop_count
		enemy.global_position = fall_zone.global_position
		# Lo scan void dei nemici gira a fette rotanti (HazardSystem.
		# VOID_CHECK_ENEMY_SLICES): copertura completa entro ~4 frame, quindi
		# il budget di attesa tiene un margine oltre il worst case.
		for _frame in range(10):
			await wait_physics_frames(1)
			if enemy.get_state_name() == &"falling":
				break
		assert_true(enemy.get_state_name() == &"falling" and enemy.health_component.is_alive(),
			"zombie enters falling state and stays alive during animation")
		for _frame in range(45):
			await wait_physics_frames(1)
			if not is_instance_valid(enemy):
				break
		await wait_physics_frames(1)
		assert_eq(_void_enemy_death_reason, &"void", "zombie void death exposes an explicit death reason")
		assert_eq(_spawned_drop_count, drops_before, "zombie void death does not spawn guaranteed loot")
		assert_eq(player.rpg_component.experience, experience_before, "zombie void death grants no kill experience")
	for _frame in range(12):
		await wait_physics_frames(1)

	_disconnect_fall_signals(audio_manager, drop_system)
	_scene.game_mode_manager().set_mode(GameConstants.MODE_MENU)
	await wait_physics_frames(2)
	assert_true(hazard_system.get_active_hazards().is_empty(), "fall zones are removed when survival stops")
	assert_false(health.has_invulnerability_source(fall_source), "stopping survival leaves no fall invulnerability token")

# --- helper di asserzione (porting dei test legacy) -------------------------

func _wait_for_streamed_region_full(
	streamer: WorldRegionStreamer,
	region_id: StringName
) -> bool:
	if streamer == null:
		return false
	for _frame in range(900):
		if (
			streamer.get_content_level(region_id)
			== WorldRegionStreamer.ContentLevel.FULL
		):
			return true
		await wait_process_frames(1)
	return false

func _assert_neighbor_gameplay_queries(streamer, biome_manager: BiomeManager,
		obstacle_system: ObstacleSystem, hazard_system: HazardSystem, neighbor_id: StringName) -> void:
	var cell := biome_manager.get_cell_by_region_id(neighbor_id)
	if cell == null or cell.generated_layout == null:
		assert_true(false, "%s has generated layout" % String(neighbor_id))
		return
	var layout := cell.generated_layout
	var offset: Vector2 = streamer.get_region_offset(neighbor_id)
	if not layout.obstacle_positions.is_empty():
		var obstacle_position: Vector2 = offset + layout.obstacle_positions.front()
		assert_true(obstacle_system.is_position_blocked(obstacle_position), "neighbor obstacle blocks movement before crossing")
	if not layout.hazard_positions.is_empty():
		var hazard_position: Vector2 = offset + layout.hazard_positions.front()
		assert_true(hazard_system.is_position_hazardous(hazard_position), "neighbor hazard is queryable before crossing")

func _assert_neighbor_crate_persistence(streamer, graph: WorldGraph, biome_manager: BiomeManager,
		world_runtime: WorldRuntime, terrain_generator: TerrainGenerator, obstacle_system: ObstacleSystem,
		hazard_system: HazardSystem, crate_system: ResourceCrateSystem,
		current_region_id: StringName, neighbor_id: StringName) -> void:
	var crate := _find_crate_for_region(crate_system, neighbor_id)
	assert_not_null(crate, "neighbor region streams a layout crate")
	if crate == null:
		return
	var crate_key := StringName(crate.get_meta("region_crate_key", &""))
	var root_instance_id: int = int(
		streamer.get_region_environment_root_instance_id(neighbor_id)
	)
	crate.opened.emit(crate, null)
	assert_true(world_runtime.is_region_item_consumed(neighbor_id, PersistentWorldState.CATEGORY_OPENED_CRATES, crate_key),
		"opening a neighbor crate records it in the neighbor ledger")
	var environment_container = _scene.main.get_node_or_null("World/EnvironmentProps")
	var pickup_container = _scene.main.get_node_or_null("World/Pickups")
	streamer.start_world(graph, current_region_id, biome_manager, world_runtime,
		environment_container, pickup_container, terrain_generator, obstacle_system, hazard_system, crate_system)
	await wait_physics_frames(1)
	assert_null(_find_crate_by_region_key(crate_system, neighbor_id, crate_key), "re-streaming skips the opened neighbor crate")
	assert_eq(streamer.get_region_environment_root_instance_id(neighbor_id), root_instance_id,
		"re-streaming preserves the existing neighbor root")

func _validate_cell(cell: BiomeCell) -> void:
	assert_eq(Vector2i(cell.width, cell.height), BiomeEnvironmentLayout.DEFAULT_ZONE_SIZE, "%s uses the shared cardinal grid size" % cell.id)
	assert_ne(cell.seed, 0, "%s has a local deterministic seed" % cell.id)
	assert_not_null(cell.generated_layout, "%s has generated terrain" % cell.id)
	if cell.generated_layout != null:
		assert_true(bool(cell.generated_layout.validation_report.get("is_valid", false)), "%s passes pathfinding validation" % cell.id)
		var placement_errors := (cell.generated_layout.validation_report.get("placement_errors", PackedStringArray()) as PackedStringArray)
		assert_true(placement_errors.is_empty(), "%s has valid spawn, crate and hazard placements" % cell.id)
	for side in BiomeCell.SIDES:
		if cell.has_neighbor(side):
			assert_eq(cell.get_border(side), BiomeCell.BorderType.CONNECTED, "%s %s border is connected" % [cell.id, side])
			assert_false(cell.get_passages_for_side(side).is_empty(), "%s %s border has a passage" % [cell.id, side])
		else:
			assert_true(cell.get_border(side) == BiomeCell.BorderType.FALL or cell.get_border(side) == BiomeCell.BorderType.BLOCKED,
				"%s %s border is fall or blocked by graph topology" % [cell.id, side])
	if cell.generated_layout != null:
		var classification := cell.generated_layout.get_classification_report()
		assert_true(bool(classification.get("is_complete", false)), "%s has complete terrain classification" % cell.id)

func _has_blocked_boundary(obstacle_system: ObstacleSystem) -> bool:
	for obstacle in obstacle_system.get_active_obstacles():
		if "boundary" in String(obstacle.get("obstacle_id")):
			return true
	return false

func _has_thematic_loot(crate_system: ResourceCrateSystem, biome_id: StringName) -> bool:
	if biome_id == &"plains":
		return crate_system.get_active_crate_ids().has(&"common") and crate_system.get_active_crate_ids().has(&"medical")
	for crate in crate_system.get_active_crates():
		if crate == null or crate.loot_table == null:
			continue
		for entry in crate.loot_table.entries:
			if entry != null and not entry.resource_tag.is_empty():
				return true
	return false

func _expect_streamed_region_content(streamer, cell: BiomeCell, layout: BiomeEnvironmentLayout) -> void:
	var counts: Dictionary = streamer.get_region_content_counts(cell.id)
	assert_eq(int(counts.get("tiles", 0)), layout.zone_size.x * layout.zone_size.y, "%s streams a full tile layer" % String(cell.biome_id))
	assert_eq(int(counts.get("obstacles", 0)), layout.obstacle_positions.size(), "%s streams all physical obstacles" % String(cell.biome_id))
	assert_eq(int(counts.get("hazards", 0)), layout.hazard_positions.size(), "%s streams all environment hazards" % String(cell.biome_id))
	assert_true(int(counts.get("crates", 0)) > 0 or layout.crate_positions.is_empty(), "%s streams biome resource crates" % String(cell.biome_id))

func _assert_source_audit() -> void:
	var controller_source := _read_text("res://game/modes/zombie/zombie_mode_controller.gd")
	var resolve_body := _extract_between(controller_source,
		"func _resolve_components() -> void:", "func _connect_wave_manager() -> void:")
	assert_false(resolve_body.contains("MultiRegionRenderer.new()"), "component resolution does not create the legacy renderer")
	assert_false(controller_source.contains("BiomeTransitionGate"), "zombie mode controller has no transition gate dependency")
	var transition_source := _read_text("res://game/modes/zombie/biome_transition_system.gd")
	var configure_body := _extract_between(transition_source,
		"func configure_biome(biome: BiomeDefinition) -> void:", "func stop_run() -> void:")
	assert_false(configure_body.contains("_spawn_gate"), "transition configuration does not spawn legacy gates")
	assert_false(configure_body.contains("_spawn_generated_map_gates"), "transition configuration does not spawn generated map gates")

# --- helper puri (porting dei test legacy) ----------------------------------

func _expected_active_ids(graph: WorldGraph, current_region_id: StringName) -> Array[StringName]:
	var ids: Array[StringName] = [current_region_id]
	for neighbor_id in graph.get_connected_region_ids(current_region_id):
		ids.append(neighbor_id)
	ids.sort()
	return ids

func _same_ids(first: Array[StringName], second: Array[StringName]) -> bool:
	if first.size() != second.size():
		return false
	var a := first.duplicate()
	var b := second.duplicate()
	a.sort()
	b.sort()
	return a == b

func _find_distant_region(graph: WorldGraph, current_region_id: StringName) -> StringName:
	var active := {current_region_id: true}
	for neighbor_id in graph.get_connected_region_ids(current_region_id):
		active[neighbor_id] = true
	for region_id in graph.regions.keys():
		if not active.has(region_id):
			return StringName(region_id)
	return &""

func _first_neighbor_with_content(graph: WorldGraph, biome_manager: BiomeManager, current_region_id: StringName) -> StringName:
	for neighbor_id in graph.get_connected_region_ids(current_region_id):
		var cell := biome_manager.get_cell_by_region_id(neighbor_id)
		if cell != null and cell.generated_layout != null:
			return neighbor_id
	return &""

func _find_crate_for_region(crate_system: ResourceCrateSystem, region_id: StringName) -> SupplyCrate:
	for crate in crate_system.get_active_crates():
		if StringName(crate.get_meta("region_id", &"")) == region_id:
			return crate
	return null

func _find_crate_by_region_key(crate_system: ResourceCrateSystem, region_id: StringName, crate_key: StringName) -> SupplyCrate:
	for crate in crate_system.get_active_crates():
		if (StringName(crate.get_meta("region_id", &"")) == region_id
				and StringName(crate.get_meta("region_crate_key", &"")) == crate_key):
			return crate
	return null

func _obstacle_keys_unique(obstacle_system: ObstacleSystem) -> bool:
	var seen := {}
	for obstacle in obstacle_system.get_active_obstacles():
		var key := StringName(obstacle.get("obstacle_key"))
		if key.is_empty() or seen.has(key):
			return false
		seen[key] = true
	return true

func _crate_keys_unique(crate_system: ResourceCrateSystem) -> bool:
	var seen := {}
	for crate in crate_system.get_active_crates():
		var region_id := StringName(crate.get_meta("region_id", &""))
		var crate_key := StringName(crate.get_meta("region_crate_key", &""))
		if region_id.is_empty() or crate_key.is_empty():
			continue
		var key := "%s:%s" % [String(region_id), String(crate_key)]
		if seen.has(key):
			return false
		seen[key] = true
	return true

func _count_named_prefix(node: Node, prefix: String) -> int:
	var count := 1 if node.name.begins_with(prefix) else 0
	for child in node.get_children():
		count += _count_named_prefix(child, prefix)
	return count

func _extract_between(text: String, start_marker: String, end_marker: String) -> String:
	var start_index := text.find(start_marker)
	if start_index < 0:
		return ""
	start_index += start_marker.length()
	var end_index := text.find(end_marker, start_index)
	if end_index < 0:
		return text.substr(start_index)
	return text.substr(start_index, end_index - start_index)

func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text

func _first_connection_for_cell(graph: WorldGraph, cell: BiomeCell) -> WorldRegionConnection:
	var region := graph.get_region(cell.id)
	if region == null:
		return null
	for connection in region.connection_edges:
		if connection.is_open and connection.physical_passage:
			return connection
	return null

func _blocked_border_position(graph: WorldGraph, cell: BiomeCell) -> Vector2:
	var region := graph.get_region(cell.id)
	var scale := (
		cell.generated_layout.logical_tile_scale
		if cell.generated_layout != null
		else WorldGridConfig.LOGICAL_TILE_SCALE
	)
	for side in BiomeCell.SIDES:
		if region != null and not graph.get_connected_region_ids(cell.id).has(region.get_neighbor_region_id(side)):
			return _position_outside_side(side, cell, scale)
	return Vector2(-float(cell.width) * scale, 0.0)

func _position_outside_side(side: StringName, cell: BiomeCell, scale: float) -> Vector2:
	var half_size := Vector2(cell.width, cell.height) * scale * 0.5
	match side:
		&"north":
			return Vector2(0.0, -half_size.y - scale * 4.0)
		&"south":
			return Vector2(0.0, half_size.y + scale * 4.0)
		&"west":
			return Vector2(-half_size.x - scale * 4.0, 0.0)
		_:
			return Vector2(half_size.x + scale * 4.0, 0.0)

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

func _position_matches_any(position: Vector2, expected_positions: Array[Vector2]) -> bool:
	for expected in expected_positions:
		if position.distance_to(expected) <= 0.5:
			return true
	return false

func _physics_query_finds_obstacle(obstacle: Node2D) -> bool:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = obstacle.global_position
	query.collision_mask = 1
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var results := obstacle.get_world_2d().direct_space_state.intersect_point(query, 16)
	for result in results:
		if result.get("collider") == obstacle:
			return true
	return false

func _distance_to_nearest_player(position: Vector2) -> float:
	var nearest := INF
	for player in _scene.nodes(&"players"):
		if player is Node2D:
			nearest = minf(nearest, position.distance_to((player as Node2D).global_position))
	return nearest

func _crate_loot_contains(crates: Array, crate_id: StringName, drop_type: StringName) -> bool:
	for crate in crates:
		var crate_node := crate as SupplyCrate
		if crate_node == null or StringName(crate_node.get_meta("biome_crate_id", &"")) != crate_id or crate_node.loot_table == null:
			continue
		for entry in crate_node.loot_table.entries:
			if entry != null and entry.drop_type == drop_type:
				return true
	return false

func _has_effect_kind(gameplay_effects: GameplayEffects, effect_kind: StringName) -> bool:
	for effect in gameplay_effects.get_children():
		if effect is GameplayEffect and effect.effect_kind == effect_kind:
			return true
	return false

func _start_test_dodge(player: PlayerController, start: Vector2, target: Vector2, duration: float) -> void:
	var component := player.dodge_component
	component.reset_runtime()
	player.global_position = start
	component.start_position = start
	component.target_position = target
	component.dodge_direction = start.direction_to(target)
	if component.dodge_direction.is_zero_approx():
		component.dodge_direction = Vector2.RIGHT
	component.dodge_duration = duration
	component.dodge_time_left = duration
	component.is_dodging = true
	component.dodge_started.emit(component.dodge_direction, target, start != target)

func _disconnect_fall_signals(audio_manager: AudioManager, drop_system: DropSystem) -> void:
	if audio_manager.cue_played.is_connected(_on_cue_played):
		audio_manager.cue_played.disconnect(_on_cue_played)
	if drop_system.drop_spawned.is_connected(_on_drop_spawned):
		drop_system.drop_spawned.disconnect(_on_drop_spawned)

func _on_cue_played(cue_id: StringName, _bus_name: StringName, _used_optional_stream: bool, _priority: int, _frames_written: int) -> void:
	_cue_ids.append(cue_id)

func _on_drop_spawned(_pickup: Node, _drop_data: Dictionary) -> void:
	_spawned_drop_count += 1

func _on_test_enemy_died(enemy: Node) -> void:
	if enemy != null and enemy.has_method("get_death_reason"):
		_void_enemy_death_reason = StringName(enemy.call("get_death_reason"))
func _new_main_scene_fixture():
	var script := ResourceLoader.load(
		"res://tests/support/main_scene_fixture.gd",
		"",
		ResourceLoader.CACHE_MODE_IGNORE
	) as Script
	assert_true(script != null, "main scene fixture script loads")
	return script.new() if script != null else null
