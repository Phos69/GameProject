extends SceneTree

var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var biome_manager := BiomeManager.new()
	root.add_child(biome_manager)
	await process_frame

	var context := {
		"world_seed": 120120,
		"biome_map_width": 5,
		"biome_map_height": 5,
		"preserve_biome_sequence": false,
		"extra_edge_chance": 0.42
	}
	biome_manager.start_run(context)
	var graph := biome_manager.get_world_graph()
	_expect(graph != null, "world graph is generated")
	if graph == null:
		_finish()
		return
	_expect(graph.regions.size() == 25, "graph contains 25 persistent regions")
	_expect(graph.region_size == Vector2i(200, 200), "regions are 200x200")
	_expect(graph.start_region_id == &"biome_0_0", "start region is stable at grid origin")
	_expect(graph.is_graph_connected(), "graph is fully connected")
	_expect(graph.get_unreachable_region_ids().is_empty(), "no isolated regions exist")
	_expect(
		graph.get_connection_count() >= graph.regions.size() - 1,
		"topology includes at least a spanning tree"
	)
	_expect(
		graph.get_connection_count() > graph.regions.size() - 1,
		"topology includes extra loop edges"
	)
	var passage_report := graph.validate_physical_passages()
	_expect(bool(passage_report.get("is_valid", false)), "every graph edge has matching physical passages")

	var signature_a := graph.get_signature()
	biome_manager.start_run(context)
	var signature_b := biome_manager.get_world_graph().get_signature()
	_expect(signature_a == signature_b, "same seed regenerates identical megamap")
	context["world_seed"] = 120121
	biome_manager.start_run(context)
	var signature_c := biome_manager.get_world_graph().get_signature()
	_expect(signature_a != signature_c, "different seed changes megamap topology or layout")

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
		print("WORLD_GRAPH_CONNECTIVITY_SMOKE_TEST: PASS")
		quit(0)
		return
	print("WORLD_GRAPH_CONNECTIVITY_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
