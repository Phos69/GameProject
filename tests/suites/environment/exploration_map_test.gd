extends GutTest
## Environment A2 — Stato di esplorazione (fog) e pannello mappa.
##
## Migra: tests/exploration_map_smoke_test.gd
## Flusso sequenziale (visita -> cleared -> pannello -> save): un test coeso.

const WorldGen = preload("res://tests/support/world_gen_helpers.gd")

var _manager: BiomeManager

func before_all() -> void:
	_manager = WorldGen.start_biome_manager(self, {
		"world_seed": 717171, "biome_map_width": 3, "biome_map_height": 3, "extra_edge_chance": 0.4
	}, "ExplorationMapManager")
	await wait_physics_frames(1)

func after_all() -> void:
	WorldGen.free_biome_manager(_manager)
	_manager = null

func test_exploration_flow() -> void:
	var runtime := WorldRuntime.new()
	add_child(runtime)
	runtime.start_run(_manager.active_world_data, _manager)
	var state := runtime.get_exploration_state()
	assert_eq(state.current_region_id, &"biome_0_0", "la regione di partenza e corrente")
	assert_eq(state.get_state(&"biome_0_0"), WorldExplorationState.STATE_VISITED, "la regione di partenza e visitata")

	var discovered_count := 0
	var unknown_count := 0
	for region_id in runtime.graph.regions.keys():
		match state.get_state(region_id):
			WorldExplorationState.STATE_DISCOVERED:
				discovered_count += 1
			WorldExplorationState.STATE_UNKNOWN:
				unknown_count += 1
			_:
				pass
	assert_gt(discovered_count, 0, "i vicini sono scoperti")
	assert_gt(unknown_count, 0, "la fog tiene sconosciute le regioni lontane")

	var next_region: StringName = runtime.graph.get_connected_region_ids(&"biome_0_0").front()
	assert_true(runtime.set_current_region(next_region), "il runtime puo visitare una regione connessa")
	assert_eq(state.get_state(next_region), WorldExplorationState.STATE_VISITED, "la regione visitata aggiorna l'esplorazione")
	runtime.mark_current_region_cleared()
	assert_eq(state.get_state(next_region), WorldExplorationState.STATE_CLEARED, "lo stato cleared e tracciato")

	var panel := ExplorationMapPanel.new()
	add_child(panel)
	await wait_physics_frames(1)
	var active_ids := runtime.get_active_region_ids()
	panel.configure(runtime.graph, state, active_ids)
	panel.show_map()
	assert_true(panel.visible, "il pannello mappa si apre")
	assert_eq(panel.graph, runtime.graph, "il pannello riceve il grafo")

	assert_false(active_ids.is_empty(), "il runtime espone le regioni attive alla mappa")
	assert_true(panel.is_region_active(next_region), "la regione corrente e marcata come caricata sulla mappa")
	assert_eq(panel.get_active_region_ids(), active_ids, "i marker attivi della mappa combaciano col set di streaming")

	var known := panel.get_known_connections()
	var fog_respected := true
	for connection in known:
		if not state.is_visible(connection.from_region_id) or not state.is_visible(connection.to_region_id):
			fog_respected = false
	assert_true(fog_respected, "i passaggi noti connettono solo regioni visibili (fog rispettata)")
	assert_lt(known.size(), runtime.graph.connections.size(), "le regioni sconosciute tengono nascosti alcuni passaggi")

	panel.apply_visual_settings({"high_contrast": true})
	assert_true(panel.high_contrast, "la mappa onora l'impostazione high-contrast")
	panel.apply_visual_settings({"high_contrast": false})
	panel.hide_map()
	assert_false(panel.visible, "il pannello mappa si chiude")

	var saved := runtime.get_save_data()
	var restored := WorldRuntime.new()
	add_child(restored)
	restored.restore_save_data(saved)
	restored.start_run(_manager.active_world_data, _manager)
	assert_eq(restored.get_exploration_state().get_state(next_region), WorldExplorationState.STATE_CLEARED,
		"lo stato di esplorazione persiste dopo il reload del runtime")

	panel.free()
	restored.stop_run()
	restored.free()
	runtime.stop_run()
	runtime.free()
