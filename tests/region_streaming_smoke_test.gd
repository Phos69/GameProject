extends SceneTree

# Milestone 3 - QA attraversamento megamappa e streaming regioni.
# Copre: contratto active_regions (regione corrente + vicini come dati, regioni
# lontane non attive), attraversamento continuo di 8+ regioni connesse,
# persistenza runtime per regione (casse aperte non ricompaiono al rientro,
# solo la regione corrente resta istanziata) e coerenza save v6 del ledger.

var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var biome_manager := BiomeManager.new()
	root.add_child(biome_manager)
	await process_frame
	biome_manager.start_run({
		"world_seed": 240617,
		"biome_map_width": 5,
		"biome_map_height": 5,
		"preserve_biome_sequence": false,
		"extra_edge_chance": 0.42
	})
	var graph := biome_manager.get_world_graph()
	_expect(graph != null and graph.is_graph_connected(), "megamap graph is connected")
	if graph == null:
		_finish()
		return

	var runtime := WorldRuntime.new()
	root.add_child(runtime)
	runtime.start_run(biome_manager.active_world_data, biome_manager)

	_run_streaming_contract(runtime, graph)
	await _run_crate_persistence(runtime, graph)
	_run_save_round_trip(runtime, graph)

	biome_manager.queue_free()
	runtime.queue_free()
	await process_frame
	_finish()

func _run_streaming_contract(runtime: WorldRuntime, graph: WorldGraph) -> void:
	var start_region := graph.start_region_id
	var traversal := _build_connected_walk(graph, start_region, 9)
	var distinct := {}
	for region_id in traversal:
		distinct[region_id] = true
	_expect(distinct.size() >= 8, "party can traverse at least 8 distinct regions")

	var continuous := true
	for index in range(1, traversal.size()):
		if not graph.get_connected_region_ids(traversal[index - 1]).has(traversal[index]):
			continuous = false
			break
	_expect(continuous, "every traversal step moves to a connected region (no teleport)")

	var contract_ok := true
	var unload_ok := true
	for region_id in traversal:
		if not runtime.set_current_region(region_id):
			contract_ok = false
			break
		if not runtime.is_region_active(region_id):
			contract_ok = false
			break
		for neighbor_id in graph.get_connected_region_ids(region_id):
			if not runtime.is_region_active(neighbor_id):
				contract_ok = false
				break
		var distant_id := _find_distant_region(runtime, graph, region_id)
		if not distant_id.is_empty() and runtime.is_region_active(distant_id):
			unload_ok = false
	_expect(contract_ok, "active_regions holds the current region and its neighbors")
	_expect(unload_ok, "regions beyond the radius stay unloaded data, not active")

func _run_crate_persistence(runtime: WorldRuntime, graph: WorldGraph) -> void:
	var region_a := graph.start_region_id
	var neighbors := graph.get_connected_region_ids(region_a)
	if neighbors.is_empty():
		_expect(false, "start region has at least one neighbor for re-entry test")
		return
	var region_b: StringName = neighbors.front()

	var biome := _build_crate_biome()
	var pickups := Node2D.new()
	pickups.name = "Pickups"
	root.add_child(pickups)
	var crate_system := ResourceCrateSystem.new()
	crate_system.crate_container_path = pickups.get_path()
	root.add_child(crate_system)
	await process_frame

	runtime.set_current_region(region_a)
	crate_system.start_run(biome)
	_expect(crate_system.get_active_crates().size() == 3, "region A spawns its three layout crates")

	var target := _find_crate_by_key(crate_system, &"layout_1")
	_expect(target != null, "layout crate index 1 is tagged with a stable region key")
	if target != null:
		target.opened.emit(target, null)
	_expect(
		runtime.is_region_item_consumed(
			region_a,
			PersistentWorldState.CATEGORY_OPENED_CRATES,
			&"layout_1"
		),
		"opening a layout crate records it as consumed for region A"
	)

	crate_system.start_run(biome)
	_expect(
		crate_system.get_active_crates().size() == 2,
		"re-generating region A skips the already opened crate"
	)
	_expect(
		_find_crate_by_key(crate_system, &"layout_1") == null,
		"the opened crate does not reappear in region A"
	)

	runtime.set_current_region(region_b)
	crate_system.start_run(biome)
	_expect(
		crate_system.get_active_crates().size() == 3,
		"region B is unaffected: only the current region's content is instantiated"
	)

	runtime.set_current_region(region_a)
	crate_system.start_run(biome)
	_expect(
		crate_system.get_active_crates().size() == 2,
		"re-entering region A keeps the opened crate consumed"
	)

	crate_system.stop_run()
	crate_system.queue_free()
	pickups.queue_free()
	await process_frame

func _run_save_round_trip(runtime: WorldRuntime, graph: WorldGraph) -> void:
	var region_a := graph.start_region_id
	runtime.mark_region_item_consumed(
		region_a,
		PersistentWorldState.CATEGORY_DESTROYED_OBSTACLES,
		&"obstacle_2"
	)
	runtime.mark_region_item_consumed(
		region_a,
		PersistentWorldState.CATEGORY_COMPLETED_ENCOUNTERS,
		&"encounter_3"
	)
	var saved := runtime.get_save_data()

	var restored := WorldRuntime.new()
	root.add_child(restored)
	restored.restore_save_data(saved)
	_expect(
		restored.is_region_item_consumed(
			region_a,
			PersistentWorldState.CATEGORY_OPENED_CRATES,
			&"layout_1"
		),
		"save v6 round-trip preserves opened crates"
	)
	_expect(
		restored.is_region_item_consumed(
			region_a,
			PersistentWorldState.CATEGORY_DESTROYED_OBSTACLES,
			&"obstacle_2"
		),
		"save v6 round-trip preserves destroyed obstacles"
	)
	_expect(
		restored.is_region_item_consumed(
			region_a,
			PersistentWorldState.CATEGORY_COMPLETED_ENCOUNTERS,
			&"encounter_3"
		),
		"save v6 round-trip preserves completed encounters"
	)
	_expect(
		not restored.is_region_item_consumed(
			region_a,
			PersistentWorldState.CATEGORY_OPENED_CRATES,
			&"layout_0"
		),
		"unconsumed crates remain available after reload"
	)
	restored.queue_free()

func _build_crate_biome() -> BiomeDefinition:
	var layout := BiomeEnvironmentLayout.new()
	var crate_ids: Array[StringName] = [&"common", &"common", &"common"]
	var crate_positions: Array[Vector2] = [
		Vector2(160.0, 0.0),
		Vector2(-160.0, 0.0),
		Vector2(0.0, 200.0)
	]
	layout.crate_ids = crate_ids
	layout.crate_positions = crate_positions
	var biome := BiomeDefinition.new()
	biome.biome_id = &"streaming_test_biome"
	biome.environment_layout = layout
	var allowed: Array[StringName] = [&"common"]
	biome.crate_ids = allowed
	return biome

func _find_crate_by_key(crate_system: ResourceCrateSystem, key: StringName) -> SupplyCrate:
	for crate in crate_system.get_active_crates():
		if StringName(crate.get_meta("region_crate_key", &"")) == key:
			return crate
	return null

func _build_connected_walk(
	graph: WorldGraph,
	start_region: StringName,
	target_count: int
) -> Array[StringName]:
	var traversal: Array[StringName] = [start_region]
	var visited := {start_region: true}
	var path_stack: Array[StringName] = [start_region]
	var current := start_region
	var guard := 0
	while visited.size() < target_count and guard < 400:
		guard += 1
		var next_id: StringName = &""
		for neighbor_id in graph.get_connected_region_ids(current):
			if not visited.has(neighbor_id):
				next_id = neighbor_id
				break
		if next_id.is_empty():
			path_stack.pop_back()
			if path_stack.is_empty():
				break
			current = path_stack.back()
			traversal.append(current)
			continue
		visited[next_id] = true
		path_stack.append(next_id)
		current = next_id
		traversal.append(current)
	return traversal

func _find_distant_region(
	runtime: WorldRuntime,
	graph: WorldGraph,
	region_id: StringName
) -> StringName:
	var near := {region_id: true}
	for neighbor_id in graph.get_connected_region_ids(region_id):
		near[neighbor_id] = true
	for candidate in graph.regions.keys():
		if not near.has(candidate):
			return StringName(candidate)
	return &""

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("REGION_STREAMING_SMOKE_TEST: PASS")
		quit(0)
		return
	print("REGION_STREAMING_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
