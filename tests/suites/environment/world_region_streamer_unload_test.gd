extends GutTest
## Regressioni mirate per l'unload regione: ownership diretta, riferimenti gia'
## liberati e scansione dei pin soltanto quando una deadline e' maturata.

const REGION_ID := &"unload_test_region"

func test_unload_uses_region_ownership_with_freed_hazard() -> void:
	var streamer := WorldRegionStreamer.new()
	var obstacle_system := ObstacleSystem.new()
	var hazard_system := HazardSystem.new()
	var crate_system := ResourceCrateSystem.new()
	add_child_autofree(streamer)
	add_child_autofree(obstacle_system)
	add_child_autofree(hazard_system)
	add_child_autofree(crate_system)

	var env_root := Node2D.new()
	var pickup_root := Node2D.new()
	add_child_autofree(env_root)
	add_child_autofree(pickup_root)
	var obstacle := Node2D.new()
	var hazard := Node2D.new()
	var crate := crate_system.supply_crate_scene.instantiate() as SupplyCrate
	env_root.add_child(obstacle)
	env_root.add_child(hazard)
	pickup_root.add_child(crate)
	obstacle.set_meta("region_id", REGION_ID)
	hazard.set_meta("region_id", REGION_ID)
	crate.set_meta("region_id", REGION_ID)
	obstacle_system.register_streamed_obstacle(obstacle, &"forest_tree")
	hazard_system.register_streamed_hazard(hazard, &"fall_zone")
	crate_system.register_streamed_crate(crate, &"common")

	streamer.obstacle_system = obstacle_system
	streamer.hazard_system = hazard_system
	streamer.resource_crate_system = crate_system
	streamer._entries[String(REGION_ID)] = {
		"region_id": REGION_ID,
		"state": WorldRegionStreamer.RegionState.ACTIVE,
		"level": WorldRegionStreamer.ContentLevel.FULL,
		"env_root": env_root,
		"pickup_root": pickup_root,
		"tile_layer": null,
		"owned_obstacles": [obstacle.get_instance_id()],
		"owned_hazards": [hazard.get_instance_id()],
		"owned_crates": [crate.get_instance_id()]
	}

	# Riproduce il caso del crash: un hazard si elimina nello stesso intervallo
	# in cui la regione entra nella coda di unload.
	hazard.queue_free()
	await wait_process_frames(1)
	streamer._unstream_region(REGION_ID)
	streamer._unstream_region(REGION_ID)

	assert_false(streamer._entries.has(String(REGION_ID)), "l'unload idempotente rimuove una sola volta la regione")
	assert_true(obstacle_system.get_active_obstacles().is_empty(), "l'ostacolo owned viene deregistrato senza scansione globale")
	assert_true(hazard_system.get_active_hazards().is_empty(), "il riferimento hazard gia' liberato viene ignorato in sicurezza")
	assert_true(crate_system.get_active_crates().is_empty(), "la crate owned viene deregistrata")

func test_pin_scan_waits_for_a_mature_unload_deadline() -> void:
	var streamer := WorldRegionStreamer.new()
	add_child_autofree(streamer)
	var env_root := Node2D.new()
	add_child_autofree(env_root)
	streamer._entries[String(REGION_ID)] = {
		"region_id": REGION_ID,
		"state": WorldRegionStreamer.RegionState.ACTIVE,
		"level": WorldRegionStreamer.ContentLevel.FULL,
		"env_root": env_root,
		"pickup_root": null,
		"tile_layer": null,
		"owned_obstacles": [],
		"owned_hazards": [],
		"owned_crates": []
	}
	streamer._unload_deadlines[String(REGION_ID)] = Time.get_ticks_msec() + 60_000

	streamer._process_scheduled_unloads()
	assert_eq(streamer._pin_collection_count, 0, "il grace period non scansiona player e nemici a ogni frame")
	assert_true(streamer._entries.has(String(REGION_ID)), "la regione resta residente prima della deadline")

	streamer._unload_deadlines[String(REGION_ID)] = Time.get_ticks_msec()
	streamer._process_scheduled_unloads()
	assert_eq(streamer._pin_collection_count, 1, "la scansione pin avviene una sola volta a deadline matura")
	assert_false(streamer._entries.has(String(REGION_ID)), "la regione non pinned viene scaricata")

func test_region_tree_is_retired_from_leaves_with_a_per_frame_cap() -> void:
	var streamer := WorldRegionStreamer.new()
	add_child_autofree(streamer)
	streamer.max_retired_nodes_per_frame = 1
	streamer.retirement_budget_msec = 4.0
	var env_root := Node2D.new()
	add_child_autofree(env_root)
	for index in range(6):
		var child := Node2D.new()
		child.name = "RetirementChild%d" % index
		env_root.add_child(child)
	streamer._entries[String(REGION_ID)] = {
		"region_id": REGION_ID,
		"state": WorldRegionStreamer.RegionState.ACTIVE,
		"level": WorldRegionStreamer.ContentLevel.FULL,
		"env_root": env_root,
		"pickup_root": null,
		"tile_layer": null,
		"owned_obstacles": [],
		"owned_hazards": [],
		"owned_crates": []
	}

	streamer._unstream_region(REGION_ID)
	var queued_stats := streamer._retirement_queue.get_stats()
	assert_eq(int(queued_stats.get("pending_retirement_roots", 0)), 1, "la root entra nella coda retirement")
	assert_false(env_root.visible, "la regione sparisce prima dello smaltimento")
	assert_eq(env_root.process_mode, Node.PROCESS_MODE_DISABLED, "la regione retired non processa gameplay")
	assert_false(env_root.is_queued_for_deletion(), "la root non viene distrutta ricorsivamente nell'unload")

	streamer._retirement_queue.process(4.0, 1)
	var first_frame_stats := streamer._retirement_queue.get_stats()
	assert_eq(int(first_frame_stats.get("last_frame_retired_nodes", 0)), 1, "un solo nodo viene accodato nel frame")
	assert_false(env_root.is_queued_for_deletion(), "la root resta viva mentre le foglie vengono drenate")

	for _index in range(8):
		streamer._retirement_queue.process(4.0, 1)
	assert_eq(int(streamer._retirement_queue.get_stats().get("pending_retirement_roots", 1)), 0, "la coda termina dopo aver drenato tutte le foglie")
	assert_true(env_root.is_queued_for_deletion(), "la root viene liberata soltanto per ultima")

func test_async_tile_build_uses_pool_and_incremental_geometry_phases() -> void:
	var layout := BiomeEnvironmentLayout.new()
	layout.zone_size = Vector2i(2, 2)
	layout.generation_seed = 424_242
	layout.add_floor_rect(Rect2i(Vector2i.ZERO, layout.zone_size), &"open_block")
	layout.rebuild_terrain_classification()
	var palette := load(
		"res://game/modes/zombie/biomes/plains_palette.tres"
	) as BiomePalette
	var layer := BiomeTileLayer.new()
	add_child_autofree(layer)
	layer.configure(
		layout,
		palette,
		&"async_stream_test",
		&"performance",
		2,
		null,
		EnvironmentAssetManifest.get_shared(),
		true,
		false
	)

	for _frame in range(120):
		if not layer.is_building():
			break
		await wait_process_frames(1)
	var stats := layer.get_async_build_stats()
	assert_false(layer.is_building(), "il task del pool e tutte le fasi main-thread terminano")
	assert_eq(int(stats.get("phase", 99)), BiomeTileLayer.AsyncGeometryPhase.IDLE, "la state machine torna idle")
	assert_eq(layer.get_cached_visual_tile_count(), 4, "il worker prepara la cache numerica completa")
	assert_gte(float(stats.get("max_geometry_phase_msec", -1.0)), 0.0, "la finalizzazione espone timing per fase")

func test_runtime_registries_prune_freed_typed_entries_by_index() -> void:
	var obstacle_system := ObstacleSystem.new()
	var hazard_system := HazardSystem.new()
	var crate_system := ResourceCrateSystem.new()
	add_child_autofree(obstacle_system)
	add_child_autofree(hazard_system)
	add_child_autofree(crate_system)
	var obstacle := Node2D.new()
	var hazard := Node2D.new()
	var crate := crate_system.supply_crate_scene.instantiate() as SupplyCrate
	add_child_autofree(obstacle)
	add_child_autofree(hazard)
	add_child_autofree(crate)
	obstacle_system.register_streamed_obstacle(obstacle, &"forest_tree")
	hazard_system.register_streamed_hazard(hazard, &"fall_zone")
	crate_system.register_streamed_crate(crate, &"common")
	obstacle.queue_free()
	hazard.queue_free()
	crate.queue_free()
	await wait_process_frames(1)

	assert_true(obstacle_system.get_active_obstacles().is_empty(), "il registro ostacoli rimuove per indice un Object freed")
	assert_true(hazard_system.get_active_hazards().is_empty(), "il registro hazard rimuove per indice un Object freed")
	assert_true(crate_system.get_active_crates().is_empty(), "il registro crate rimuove per indice un Object freed")

func test_terrain_surface_reuses_quad_mesh_and_shader_material() -> void:
	var render_data := {
		"chunk_world_rect": Rect2(0.0, 0.0, 480.0, 480.0),
		"mask_uv_rect": Rect2(0.0, 0.0, 0.25, 0.25),
		"texture_world_origin": Vector2.ZERO,
		"surface_material_ids": []
	}
	var first := TerrainSurfaceCanvas.new()
	add_child(first)
	first.configure(render_data)
	var first_mesh := first.surface_mesh
	var first_material := first.surface_material
	first.queue_free()
	await wait_process_frames(1)

	var second := TerrainSurfaceCanvas.new()
	add_child_autofree(second)
	second.configure(render_data)
	assert_same(second.surface_mesh, first_mesh, "la geometria quad identica e' condivisa tra chunk")
	assert_same(second.surface_material, first_material, "il materiale shader liberato viene riusato")

func test_mature_chunk_evictions_are_capped_globally_per_frame() -> void:
	var layout := BiomeEnvironmentLayout.new()
	layout.zone_size = Vector2i(6, 2)
	layout.generation_seed = 91_337
	layout.add_floor_rect(Rect2i(Vector2i.ZERO, layout.zone_size), &"open_block")
	layout.rebuild_terrain_classification()
	var palette := load(
		"res://game/modes/zombie/biomes/plains_palette.tres"
	) as BiomePalette
	var layer := BiomeTileLayer.new()
	add_child_autofree(layer)
	layer.configure(
		layout,
		palette,
		&"eviction_cap_test",
		&"performance",
		2,
		null,
		EnvironmentAssetManifest.get_shared(),
		false,
		false
	)
	var resident_coords: Array[Vector2i] = [
		Vector2i(0, 0),
		Vector2i(1, 0),
		Vector2i(2, 0)
	]
	for coord in resident_coords:
		assert_true(layer.ensure_chunk(coord), "il chunk fixture diventa residente")

	var controller := WorldChunkVisibilityController.new()
	controller.max_evictions_per_frame = 1
	controller.eviction_budget_msec = 4.0
	for coord in resident_coords:
		var key := controller._make_chunk_key(&"eviction_region", coord)
		controller._eviction_deadlines[key] = Time.get_ticks_msec() - 1
	controller._apply_retention_policy(&"eviction_region", layer, [])
	assert_eq(layer.get_resident_chunk_coords().size(), 2, "una sola eviction matura avviene nel frame")
	controller._apply_retention_policy(&"eviction_region", layer, [])
	assert_eq(layer.get_resident_chunk_coords().size(), 2, "un secondo refresh nello stesso frame non aggira il cap")
	assert_eq(int(controller.get_streaming_stats().get("last_frame_chunk_evictions", 0)), 1, "la telemetria espone il cap effettivo")

	await wait_process_frames(1)
	controller._apply_retention_policy(&"eviction_region", layer, [])
	assert_eq(layer.get_resident_chunk_coords().size(), 1, "il chunk successivo viene drenato nel frame seguente")

func test_batch_unregister_preserves_nodes_from_other_regions() -> void:
	var obstacle_system := ObstacleSystem.new()
	var hazard_system := HazardSystem.new()
	var crate_system := ResourceCrateSystem.new()
	add_child_autofree(obstacle_system)
	add_child_autofree(hazard_system)
	add_child_autofree(crate_system)
	var owned_obstacle := Node2D.new()
	var foreign_obstacle := Node2D.new()
	var owned_hazard := Node2D.new()
	var foreign_hazard := Node2D.new()
	var owned_crate := crate_system.supply_crate_scene.instantiate() as SupplyCrate
	var foreign_crate := crate_system.supply_crate_scene.instantiate() as SupplyCrate
	for node in [
		owned_obstacle,
		foreign_obstacle,
		owned_hazard,
		foreign_hazard,
		owned_crate,
		foreign_crate
	]:
		add_child_autofree(node)
	owned_obstacle.set_meta("region_id", REGION_ID)
	owned_hazard.set_meta("region_id", REGION_ID)
	owned_crate.set_meta("region_id", REGION_ID)
	foreign_obstacle.set_meta("region_id", &"foreign_region")
	foreign_hazard.set_meta("region_id", &"foreign_region")
	foreign_crate.set_meta("region_id", &"foreign_region")
	obstacle_system.register_streamed_obstacle(owned_obstacle, &"owned")
	obstacle_system.register_streamed_obstacle(foreign_obstacle, &"foreign")
	hazard_system.register_streamed_hazard(owned_hazard, &"owned")
	hazard_system.register_streamed_hazard(foreign_hazard, &"foreign")
	crate_system.register_streamed_crate(owned_crate, &"common")
	crate_system.register_streamed_crate(foreign_crate, &"common")
	var mixed_ids := [
		owned_obstacle.get_instance_id(),
		foreign_obstacle.get_instance_id()
	]
	obstacle_system.unregister_streamed_obstacles_by_instance_ids(mixed_ids, REGION_ID)
	hazard_system.unregister_streamed_hazards_by_instance_ids([
		owned_hazard.get_instance_id(),
		foreign_hazard.get_instance_id()
	], REGION_ID)
	crate_system.unregister_streamed_crates_by_instance_ids([
		owned_crate.get_instance_id(),
		foreign_crate.get_instance_id()
	], REGION_ID)

	assert_eq(obstacle_system.get_active_obstacles(), [foreign_obstacle], "il batch ostacoli conserva le altre regioni")
	assert_eq(hazard_system.get_active_hazards(), [foreign_hazard], "il batch hazard conserva le altre regioni")
	assert_eq(crate_system.get_active_crates(), [foreign_crate], "il batch crate conserva le altre regioni")
