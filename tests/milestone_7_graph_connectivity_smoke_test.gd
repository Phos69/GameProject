extends SceneTree

# Milestone 7 - Grafo biomi completamente connesso.
# Copre: garanzia di grafo connesso su 100 seed, presenza di edge extra (loop),
# passaggi fisici coerenti, e il report di connettivita / active regions esposto
# da BiomeMapDebugOverlay piu la regola di fog della mappa esplorazione.

const BIOME_IDS: Array[StringName] = [
	&"infected_plains",
	&"toxic_wastes",
	&"burning_fields",
	&"frozen_outskirts",
	&"drowned_marsh"
]
const SEED_COUNT := 100

var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_run_multi_seed_connectivity()
	await _run_overlay_graph_summary()
	_finish()

func _run_multi_seed_connectivity() -> void:
	var map_generator := BiomeMapGenerator.new()
	root.add_child(map_generator)
	var all_connected := true
	var any_unreachable := false
	var any_extra_edges := false
	var passages_ok := true
	var disconnected_seed := -1
	for seed_value in range(1, SEED_COUNT + 1):
		var context := {
			"biome_map_width": 3,
			"biome_map_height": 3,
			"preserve_biome_sequence": false,
			"extra_edge_chance": 0.42
		}
		map_generator.generate_map(seed_value, BIOME_IDS, context)
		var graph := map_generator.get_world_graph()
		if graph == null or not graph.is_graph_connected():
			all_connected = false
			disconnected_seed = seed_value
		elif not graph.get_unreachable_region_ids().is_empty():
			any_unreachable = true
		if graph != null and graph.get_connection_count() > graph.regions.size() - 1:
			any_extra_edges = true
		if graph != null and not bool(graph.validate_physical_passages().get("is_valid", false)):
			passages_ok = false
		map_generator.clear_generated_data()
	_expect(all_connected, "all %d seeds generate fully connected graphs (first fail seed %d)" % [SEED_COUNT, disconnected_seed])
	_expect(not any_unreachable, "no seed leaves unreachable regions")
	_expect(any_extra_edges, "topology includes extra loop edges across seeds")
	_expect(passages_ok, "every graph edge has matching physical passages across seeds")
	map_generator.queue_free()

func _run_overlay_graph_summary() -> void:
	var biome_manager := BiomeManager.new()
	root.add_child(biome_manager)
	await process_frame
	biome_manager.start_run({
		"world_seed": 7777,
		"biome_map_width": 3,
		"biome_map_height": 3,
		"preserve_biome_sequence": false,
		"extra_edge_chance": 0.42
	})

	var world_runtime := WorldRuntime.new()
	root.add_child(world_runtime)
	world_runtime.start_run(biome_manager.active_world_data, biome_manager)

	var overlay := BiomeMapDebugOverlay.new()
	root.add_child(overlay)
	await process_frame
	overlay.configure(
		biome_manager.get_generation_seed(),
		biome_manager.get_generated_biome_map()
	)

	var summary := overlay.get_debug_summary()
	var graph_data := summary.get("graph", {}) as Dictionary
	_expect(bool(graph_data.get("is_connected", false)), "overlay reports a connected graph")
	_expect(int(graph_data.get("region_count", 0)) == 9, "overlay reports all 9 regions")
	_expect(int(graph_data.get("unreachable_count", -1)) == 0, "overlay reports no unreachable regions")
	_expect(
		int(graph_data.get("connection_count", 0)) >= 8,
		"overlay reports at least a spanning tree of edges"
	)
	_expect(
		int(summary.get("active_region_count", 0)) >= 1,
		"overlay reports the loaded (active) regions"
	)
	_expect(
		not String(summary.get("current_region_id", &"")).is_empty(),
		"overlay reports the current region id"
	)
	_expect(
		int(summary.get("unloaded_region_count", -1)) >= 0,
		"overlay reports the count of unloaded regions"
	)

	# Fog rule: the map only reveals the start region and its neighbors; distant
	# regions stay unknown.
	var exploration := world_runtime.get_exploration_state()
	_expect(
		exploration.get_state(&"biome_0_0") == &"visited",
		"start region is visited"
	)
	_expect(
		exploration.get_state(&"biome_2_2") == WorldExplorationState.STATE_UNKNOWN,
		"a distant region stays unknown behind the fog"
	)

	world_runtime.stop_run()
	overlay.queue_free()
	world_runtime.queue_free()
	biome_manager.queue_free()
	await process_frame

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("MILESTONE_7_GRAPH_CONNECTIVITY_SMOKE_TEST: PASS")
		quit(0)
		return
	print("MILESTONE_7_GRAPH_CONNECTIVITY_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
