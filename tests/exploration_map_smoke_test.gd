extends SceneTree

var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var biome_manager := BiomeManager.new()
	root.add_child(biome_manager)
	await process_frame
	biome_manager.start_run({
		"world_seed": 717171,
		"biome_map_width": 5,
		"biome_map_height": 5,
		"extra_edge_chance": 0.4
	})
	var runtime := WorldRuntime.new()
	root.add_child(runtime)
	runtime.start_run(biome_manager.active_world_data, biome_manager)
	var state := runtime.get_exploration_state()
	_expect(state.current_region_id == &"biome_0_0", "start region is current")
	_expect(state.get_state(&"biome_0_0") == WorldExplorationState.STATE_VISITED, "start region is visited")
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
	_expect(discovered_count > 0, "neighbors are discovered")
	_expect(unknown_count > 0, "fog keeps distant regions unknown")

	var next_region: StringName = runtime.graph.get_connected_region_ids(&"biome_0_0").front()
	_expect(runtime.set_current_region(next_region), "runtime can visit a connected region")
	_expect(state.get_state(next_region) == WorldExplorationState.STATE_VISITED, "visited region updates exploration")
	runtime.mark_current_region_cleared()
	_expect(state.get_state(next_region) == WorldExplorationState.STATE_CLEARED, "cleared state is tracked")

	var panel := ExplorationMapPanel.new()
	root.add_child(panel)
	await process_frame
	var active_ids := runtime.get_active_region_ids()
	panel.configure(runtime.graph, state, active_ids)
	panel.show_map()
	_expect(panel.visible, "exploration map panel opens")
	_expect(panel.graph == runtime.graph, "map panel receives graph")

	# Active / loaded region markers come from the streaming set.
	_expect(not active_ids.is_empty(), "runtime exposes active regions to the map")
	_expect(
		panel.is_region_active(next_region),
		"the current region is marked as loaded on the map"
	)
	_expect(
		panel.get_active_region_ids() == active_ids,
		"map active markers match the runtime streaming set"
	)

	# Known passages mirror the graph but never reveal unknown topology.
	var known := panel.get_known_connections()
	var fog_respected := true
	for connection in known:
		if (
			not state.is_visible(connection.from_region_id)
			or not state.is_visible(connection.to_region_id)
		):
			fog_respected = false
	_expect(fog_respected, "known passages only connect visible regions (fog respected)")
	_expect(
		known.size() < runtime.graph.connections.size(),
		"unknown regions keep some passages hidden"
	)

	# High contrast strengthens the geometric markers without changing data.
	panel.apply_visual_settings({"high_contrast": true})
	_expect(panel.high_contrast, "map honors the high-contrast visual setting")
	panel.apply_visual_settings({"high_contrast": false})

	panel.hide_map()
	_expect(not panel.visible, "exploration map panel closes")

	var saved := runtime.get_save_data()
	var restored := WorldRuntime.new()
	root.add_child(restored)
	restored.restore_save_data(saved)
	restored.start_run(biome_manager.active_world_data, biome_manager)
	_expect(
		restored.get_exploration_state().get_state(next_region)
		== WorldExplorationState.STATE_CLEARED,
		"exploration state persists across runtime reload"
	)

	panel.queue_free()
	runtime.queue_free()
	restored.queue_free()
	biome_manager.queue_free()
	_finish()

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("EXPLORATION_MAP_SMOKE_TEST: PASS")
		quit(0)
		return
	print("EXPLORATION_MAP_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
