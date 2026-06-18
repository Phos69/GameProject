extends SceneTree

var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var biome_manager := BiomeManager.new()
	root.add_child(biome_manager)
	await process_frame
	biome_manager.start_run({
		"world_seed": 998877,
		"biome_map_width": 3,
		"biome_map_height": 3,
		"preserve_biome_sequence": false
	})
	var graph := biome_manager.get_world_graph()
	_expect(graph != null and graph.is_graph_connected(), "persistent world graph is connected")
	if graph == null:
		_finish()
		return

	var state := PersistentWorldState.new()
	state.configure(998877, graph)
	state.set_current_region(&"biome_1_0", graph)
	state.mark_region_cleared(&"biome_0_0")
	state.set_region_runtime_value(&"biome_0_0", &"opened_crates", ["crate_a"])
	state.set_party_position(Vector2(128.0, -32.0))
	var saved := state.to_save_data()

	var restored := PersistentWorldState.new()
	restored.restore_save_data(saved)
	_expect(restored.seed_value == 998877, "seed persists")
	_expect(restored.graph_signature == graph.get_signature(), "graph signature persists")
	_expect(restored.current_region_id == &"biome_1_0", "current region persists")
	_expect(
		restored.exploration_state.get_state(&"biome_0_0")
		== WorldExplorationState.STATE_CLEARED,
		"cleared region state persists"
	)
	_expect(
		(restored.get_region_runtime_state(&"biome_0_0").get("opened_crates", []) as Array).has("crate_a"),
		"region runtime state persists"
	)
	_expect(restored.party_position.is_equal_approx(Vector2(128.0, -32.0)), "party position persists")

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
		print("PERSISTENT_WORLD_GENERATION_SMOKE_TEST: PASS")
		quit(0)
		return
	print("PERSISTENT_WORLD_GENERATION_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
