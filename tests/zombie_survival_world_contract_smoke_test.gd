extends SceneTree

var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var harness := Node.new()
	harness.name = "ZombieWorldContractHarness"
	root.add_child(harness)

	var biome_manager := BiomeManager.new()
	biome_manager.name = "BiomeManager"
	harness.add_child(biome_manager)

	var controller := ZombieModeController.new()
	controller.name = "ZombieModeController"
	controller.biome_manager_path = NodePath("../BiomeManager")
	controller.enable_multi_region_render = false
	harness.add_child(controller)
	await process_frame

	controller.start_run({})
	_expect_default_survival_world(biome_manager)
	controller.stop_run()

	controller.start_run({
		"single_biome_arena": true
	})
	_expect_single_biome_quick_arena(biome_manager)
	controller.stop_run()

	controller.start_run({
		"single_biome_arena": true,
		"arena_boundary_mode": "walled"
	})
	_expect_walled_infinite_arena_profile(biome_manager)
	controller.stop_run()

	controller.start_run({
		"single_biome_arena": true,
		"biome_map_width": 2,
		"biome_map_height": 2
	})
	_expect(
		biome_manager.get_generated_biome_map().size() == 4,
		"explicit map dimensions override single-biome arena profile"
	)
	controller.stop_run()

	harness.queue_free()
	await process_frame
	_finish()

func _expect_default_survival_world(biome_manager: BiomeManager) -> void:
	var cells := biome_manager.get_generated_biome_map()
	_expect(cells.size() == 9, "default survival generates a 3x3 biome map")
	var graph := biome_manager.get_world_graph()
	_expect(graph != null and graph.is_graph_connected(), "default survival graph is connected")
	var graph_biomes: Dictionary = {}
	if graph != null:
		for region in graph.get_regions_sorted():
			graph_biomes[region.biome_id] = true
	for required_biome in [
		&"infected_plains",
		&"toxic_wastes",
		&"burning_fields",
		&"frozen_outskirts",
		&"drowned_marsh"
	]:
		_expect(
			graph_biomes.has(required_biome),
			"default survival graph contains %s" % String(required_biome)
		)
	var start_cell := biome_manager.get_current_biome_cell()
	_expect(
		start_cell != null and start_cell.biome_id == &"infected_plains",
		"default survival starts from infected_plains"
	)
	var connected_border_count := 0
	var outer_fall_count := 0
	for cell in cells:
		for side in BiomeCell.SIDES:
			if cell.has_neighbor(side):
				connected_border_count += 1
			elif cell.get_border(side) == BiomeCell.BorderType.FALL:
				outer_fall_count += 1
	_expect(
		connected_border_count > 0,
		"default survival contains connected biome passages"
	)
	_expect(
		outer_fall_count > 0,
		"default survival keeps fall boundary on the outer world edge"
	)

func _expect_single_biome_quick_arena(biome_manager: BiomeManager) -> void:
	var cells := biome_manager.get_generated_biome_map()
	_expect(cells.size() == 1, "quick arena profile generates one cell")
	var start_cell := biome_manager.get_current_biome_cell()
	_expect(
		start_cell != null and start_cell.biome_id == &"infected_plains",
		"quick arena starts from infected_plains"
	)
	if start_cell == null:
		return
	_expect(
		start_cell.passages.is_empty(),
		"quick arena has no inter-region passages"
	)
	for side in BiomeCell.SIDES:
		_expect(
			start_cell.get_border(side) == BiomeCell.BorderType.FALL,
			"quick arena %s border falls to void" % String(side)
		)

func _expect_walled_infinite_arena_profile(biome_manager: BiomeManager) -> void:
	var cells := biome_manager.get_generated_biome_map()
	_expect(cells.size() == 1, "walled arena profile generates one cell")
	var start_cell := biome_manager.get_current_biome_cell()
	_expect(
		start_cell != null and start_cell.biome_id == &"infected_plains",
		"walled arena starts from infected_plains"
	)
	if start_cell == null:
		return
	_expect(
		start_cell.passages.is_empty(),
		"walled arena has no inter-region passages"
	)
	for side in BiomeCell.SIDES:
		_expect(
			start_cell.get_border(side) == BiomeCell.BorderType.BLOCKED,
			"walled arena %s border is blocked by walls" % String(side)
		)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("ZOMBIE_SURVIVAL_WORLD_CONTRACT_SMOKE_TEST: PASS")
		quit(0)
		return
	print(
		"ZOMBIE_SURVIVAL_WORLD_CONTRACT_SMOKE_TEST: FAIL (%d)"
		% failures.size()
	)
	quit(1)
