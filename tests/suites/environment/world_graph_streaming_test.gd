extends GutTest
## Environment A2 — Grafo del mondo, connettivita, streaming regioni e persistenza.
##
## Migra e accorpa:
##   tests/world_graph_connectivity_smoke_test.gd
##   tests/milestone_7_graph_connectivity_smoke_test.gd
##   tests/region_streaming_smoke_test.gd
##
## Ottimizzazione: la megamappa 3x3 (grafo immutabile) viene costruita UNA volta
## in before_all e riusata. Ogni test che muta lo streaming crea il proprio
## WorldRuntime (economico) per restare isolato.

const WorldGen = preload("res://tests/support/world_gen_helpers.gd")

const GRAPH_SEED := 120120
const BIOME_IDS: Array[StringName] = [
	&"plains", &"burning_plains", &"frozen_tundra", &"swamp"
]

var _manager: BiomeManager
var _graph: WorldGraph

func before_all() -> void:
	_manager = WorldGen.start_biome_manager(self, {
		"world_seed": GRAPH_SEED,
		"biome_map_width": 3,
		"biome_map_height": 3,
		"preserve_biome_sequence": false,
		"extra_edge_chance": 0.42
	}, "GraphStreamingManager")
	await wait_physics_frames(1)
	_graph = _manager.get_world_graph()

func after_all() -> void:
	WorldGen.free_biome_manager(_manager)
	_manager = null
	_graph = null

func _make_runtime() -> WorldRuntime:
	var runtime := WorldRuntime.new()
	add_child(runtime)
	runtime.start_run(_manager.active_world_data, _manager)
	return runtime

func _free_runtime(runtime: WorldRuntime) -> void:
	runtime.stop_run()
	remove_child(runtime)
	runtime.free()

# --- struttura del grafo (world_graph_connectivity) -----------------------

func test_graph_structure() -> void:
	assert_not_null(_graph, "il grafo del mondo e generato")
	if _graph == null:
		return
	assert_eq(_graph.regions.size(), 9, "il grafo contiene 9 regioni persistenti")
	assert_eq(_graph.region_size, BiomeEnvironmentLayout.DEFAULT_ZONE_SIZE, "le regioni usano la griglia cardinale condivisa")
	assert_eq(_graph.start_region_id, &"biome_0_0", "la regione di partenza e stabile all'origine")
	assert_true(_graph.is_graph_connected(), "il grafo e completamente connesso")
	assert_true(_graph.get_unreachable_region_ids().is_empty(), "nessuna regione isolata")
	assert_gte(_graph.get_connection_count(), _graph.regions.size() - 1, "topologia con almeno uno spanning tree")
	assert_gt(_graph.get_connection_count(), _graph.regions.size() - 1, "topologia con edge extra (loop)")
	assert_true(bool(_graph.validate_physical_passages().get("is_valid", false)),
		"ogni edge del grafo ha passaggi fisici coerenti")

func test_graph_determinism() -> void:
	var signature_a := _graph.get_signature()
	var context := {
		"world_seed": GRAPH_SEED, "biome_map_width": 3, "biome_map_height": 3,
		"preserve_biome_sequence": false, "extra_edge_chance": 0.42
	}
	_manager.start_run(context)
	assert_eq(_manager.get_world_graph().get_signature(), signature_a,
		"stesso seed rigenera una megamappa identica")
	context["world_seed"] = GRAPH_SEED + 1
	_manager.start_run(context)
	assert_ne(_manager.get_world_graph().get_signature(), signature_a,
		"seed diverso cambia topologia o layout della megamappa")
	# ripristina la megamappa condivisa per i test successivi
	_manager.start_run({
		"world_seed": GRAPH_SEED, "biome_map_width": 3, "biome_map_height": 3,
		"preserve_biome_sequence": false, "extra_edge_chance": 0.42
	})
	_graph = _manager.get_world_graph()

# --- connettivita multi-seed (milestone_7) --------------------------------

func test_multi_seed_connectivity() -> void:
	var map_generator := BiomeMapGenerator.new()
	add_child(map_generator)
	var all_connected := true
	var any_unreachable := false
	var any_extra_edges := false
	var passages_ok := true
	var disconnected_seed := -1
	for seed_value in range(1, 101):
		map_generator.generate_map(seed_value, BIOME_IDS, {
			"biome_map_width": 3, "biome_map_height": 3,
			"preserve_biome_sequence": false, "extra_edge_chance": 0.42
		})
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
	assert_true(all_connected, "tutti i 100 seed generano grafi connessi (primo fail seed %d)" % disconnected_seed)
	assert_false(any_unreachable, "nessun seed lascia regioni irraggiungibili")
	assert_true(any_extra_edges, "la topologia include edge extra su piu seed")
	assert_true(passages_ok, "ogni edge ha passaggi fisici coerenti su piu seed")
	map_generator.free()

func test_overlay_summary_and_fog() -> void:
	var runtime := _make_runtime()
	var overlay := BiomeMapDebugOverlay.new()
	add_child(overlay)
	await wait_physics_frames(1)
	overlay.configure(_manager.get_generation_seed(), _manager.get_generated_biome_map())

	var summary := overlay.get_debug_summary()
	var graph_data := summary.get("graph", {}) as Dictionary
	assert_true(bool(graph_data.get("is_connected", false)), "l'overlay riporta un grafo connesso")
	assert_eq(int(graph_data.get("region_count", 0)), 9, "l'overlay riporta tutte le 9 regioni")
	assert_eq(int(graph_data.get("unreachable_count", -1)), 0, "l'overlay riporta zero regioni irraggiungibili")
	assert_gte(int(graph_data.get("connection_count", 0)), 8, "l'overlay riporta almeno uno spanning tree")
	assert_gte(int(summary.get("active_region_count", 0)), 1, "l'overlay riporta le regioni attive caricate")
	assert_false(String(summary.get("current_region_id", &"")).is_empty(), "l'overlay riporta la regione corrente")
	assert_gte(int(summary.get("unloaded_region_count", -1)), 0, "l'overlay riporta il numero di regioni scaricate")

	var exploration := runtime.get_exploration_state()
	assert_eq(exploration.get_state(&"biome_0_0"), &"visited", "la regione di partenza e visitata")
	assert_eq(exploration.get_state(&"biome_2_2"), WorldExplorationState.STATE_UNKNOWN,
		"una regione lontana resta sconosciuta dietro la fog")

	overlay.free()
	_free_runtime(runtime)

# --- contratto di streaming (region_streaming) ----------------------------

func test_streaming_contract() -> void:
	var runtime := _make_runtime()
	var start_region := _graph.start_region_id
	var traversal := _build_connected_walk(_graph, start_region, 9)
	var distinct := {}
	for region_id in traversal:
		distinct[region_id] = true
	assert_gte(distinct.size(), 8, "la party puo attraversare almeno 8 regioni distinte")

	var continuous := true
	for index in range(1, traversal.size()):
		if not _graph.get_connected_region_ids(traversal[index - 1]).has(traversal[index]):
			continuous = false
			break
	assert_true(continuous, "ogni passo di traversata va a una regione connessa (no teleport)")

	var contract_ok := true
	var unload_ok := true
	for region_id in traversal:
		if not runtime.set_current_region(region_id) or not runtime.is_region_active(region_id):
			contract_ok = false
			break
		for neighbor_id in _graph.get_connected_region_ids(region_id):
			if not runtime.is_region_active(neighbor_id):
				contract_ok = false
				break
		var distant_id := _find_distant_region(_graph, region_id)
		if not distant_id.is_empty() and runtime.is_region_active(distant_id):
			unload_ok = false
	assert_true(contract_ok, "active_regions contiene la regione corrente e i vicini")
	assert_true(unload_ok, "le regioni oltre il raggio restano dati non attivi")
	_free_runtime(runtime)

func test_crate_persistence_and_save_round_trip() -> void:
	var runtime := _make_runtime()
	var region_a := _graph.start_region_id
	var neighbors := _graph.get_connected_region_ids(region_a)
	assert_false(neighbors.is_empty(), "la regione di partenza ha almeno un vicino")
	if neighbors.is_empty():
		_free_runtime(runtime)
		return
	var region_b: StringName = neighbors.front()

	var biome := _build_crate_biome()
	var pickups := Node2D.new()
	pickups.name = "Pickups"
	add_child(pickups)
	var crate_system := ResourceCrateSystem.new()
	crate_system.crate_container_path = pickups.get_path()
	add_child(crate_system)
	await wait_physics_frames(1)

	runtime.set_current_region(region_a)
	crate_system.start_run(biome)
	assert_eq(crate_system.get_active_crates().size(), 3, "la regione A genera le sue tre casse di layout")

	var target := _find_crate_by_key(crate_system, &"layout_1")
	assert_not_null(target, "la cassa layout indice 1 ha una chiave regione stabile")
	if target != null:
		target.opened.emit(target, null)
	assert_true(runtime.is_region_item_consumed(region_a, PersistentWorldState.CATEGORY_OPENED_CRATES, &"layout_1"),
		"aprire una cassa la registra come consumata per la regione A")

	crate_system.start_run(biome)
	assert_eq(crate_system.get_active_crates().size(), 2, "rigenerare la regione A salta la cassa gia aperta")
	assert_null(_find_crate_by_key(crate_system, &"layout_1"), "la cassa aperta non ricompare nella regione A")

	runtime.set_current_region(region_b)
	crate_system.start_run(biome)
	assert_eq(crate_system.get_active_crates().size(), 3, "la regione B non e influenzata")

	runtime.set_current_region(region_a)
	crate_system.start_run(biome)
	assert_eq(crate_system.get_active_crates().size(), 2, "rientrare nella regione A mantiene la cassa consumata")

	# save v6 round-trip
	runtime.mark_region_item_consumed(region_a, PersistentWorldState.CATEGORY_DESTROYED_OBSTACLES, &"obstacle_2")
	runtime.mark_region_item_consumed(region_a, PersistentWorldState.CATEGORY_COMPLETED_ENCOUNTERS, &"encounter_3")
	var saved := runtime.get_save_data()
	var restored := WorldRuntime.new()
	add_child(restored)
	restored.restore_save_data(saved)
	assert_true(restored.is_region_item_consumed(region_a, PersistentWorldState.CATEGORY_OPENED_CRATES, &"layout_1"),
		"il round-trip save v6 preserva le casse aperte")
	assert_true(restored.is_region_item_consumed(region_a, PersistentWorldState.CATEGORY_DESTROYED_OBSTACLES, &"obstacle_2"),
		"il round-trip save v6 preserva gli ostacoli distrutti")
	assert_true(restored.is_region_item_consumed(region_a, PersistentWorldState.CATEGORY_COMPLETED_ENCOUNTERS, &"encounter_3"),
		"il round-trip save v6 preserva gli encounter completati")
	assert_false(restored.is_region_item_consumed(region_a, PersistentWorldState.CATEGORY_OPENED_CRATES, &"layout_0"),
		"le casse non consumate restano disponibili dopo il reload")

	restored.free()
	crate_system.stop_run()
	crate_system.free()
	pickups.free()
	_free_runtime(runtime)

# --- helper (porting dei test legacy) -------------------------------------

func _build_crate_biome() -> BiomeDefinition:
	var layout := BiomeEnvironmentLayout.new()
	layout.crate_ids = [&"common", &"common", &"common"] as Array[StringName]
	layout.crate_positions = [Vector2(160.0, 0.0), Vector2(-160.0, 0.0), Vector2(0.0, 200.0)] as Array[Vector2]
	var biome := BiomeDefinition.new()
	biome.biome_id = &"streaming_test_biome"
	biome.environment_layout = layout
	biome.crate_ids = [&"common"] as Array[StringName]
	return biome

func _find_crate_by_key(crate_system: ResourceCrateSystem, key: StringName) -> SupplyCrate:
	for crate in crate_system.get_active_crates():
		if StringName(crate.get_meta("region_crate_key", &"")) == key:
			return crate
	return null

func _build_connected_walk(graph: WorldGraph, start_region: StringName, target_count: int) -> Array[StringName]:
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

func _find_distant_region(graph: WorldGraph, region_id: StringName) -> StringName:
	var near := {region_id: true}
	for neighbor_id in graph.get_connected_region_ids(region_id):
		near[neighbor_id] = true
	for candidate in graph.regions.keys():
		if not near.has(candidate):
			return StringName(candidate)
	return &""
