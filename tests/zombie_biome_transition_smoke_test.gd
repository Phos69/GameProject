extends SceneTree

var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main_scene := load("res://game/main/main.tscn") as PackedScene
	_expect(main_scene != null, "main scene can be loaded")
	if main_scene == null:
		_finish()
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame

	var game_mode_manager := get_first_node_in_group(
		"game_mode_manager"
	) as GameModeManager
	var wave_manager := get_first_node_in_group(
		"wave_manager"
	) as WaveManager
	var biome_manager := get_first_node_in_group(
		"biome_manager"
	) as BiomeManager
	var transition_system := get_first_node_in_group(
		"biome_transition_system"
	) as BiomeTransitionSystem
	var terrain_generator := get_first_node_in_group(
		"terrain_generator"
	) as TerrainGenerator
	var obstacle_system := get_first_node_in_group(
		"obstacle_system"
	) as ObstacleSystem
	var crate_system := get_first_node_in_group(
		"resource_crate_system"
	) as ResourceCrateSystem
	var hazard_system := get_first_node_in_group(
		"hazard_system"
	) as HazardSystem
	var streamer = get_first_node_in_group("world_region_streamer")
	var multi_region_renderer = get_first_node_in_group("multi_region_renderer")
	var hud := get_first_node_in_group("hud_manager") as HUDManager
	var playground := main.get_node_or_null(
		"World/Playground"
	) as IsometricPlayground
	_expect(game_mode_manager != null, "game mode manager is available")
	_expect(wave_manager != null, "wave manager is available")
	_expect(biome_manager != null, "biome manager is available")
	_expect(transition_system != null, "transition system is available")
	_expect(terrain_generator != null, "terrain generator is available")
	_expect(obstacle_system != null, "obstacle system is available")
	_expect(crate_system != null, "crate system is available")
	_expect(hazard_system != null, "hazard system is available")
	_expect(streamer != null, "world region streamer is available")
	_expect(hud != null, "HUD is available")
	_expect(playground != null, "playground is available")
	if (
		game_mode_manager == null
		or wave_manager == null
		or biome_manager == null
		or transition_system == null
		or terrain_generator == null
		or obstacle_system == null
		or crate_system == null
		or hazard_system == null
		or streamer == null
		or hud == null
		or playground == null
	):
		_finish()
		return

	wave_manager.initial_delay = 100.0
	transition_system.transition_cooldown = 0.01
	if streamer != null:
		streamer.set("active_radius", 0)
	if multi_region_renderer != null:
		multi_region_renderer.set("neighbor_radius", 0)
	_expect(
		game_mode_manager.set_mode(GameConstants.MODE_SURVIVAL),
		"survival starts with biome transitions"
	)
	await process_frame
	await physics_frame

	var graph := biome_manager.get_world_graph()
	_expect(graph != null and graph.is_graph_connected(), "persistent biome graph is connected")
	var seen_biomes: Dictionary = {}
	for step in range(2):
		var cell := biome_manager.get_current_biome_cell()
		_expect(cell != null, "current region exists at step %d" % step)
		if cell == null:
			break
		var biome_id := cell.biome_id
		seen_biomes[biome_id] = true
		var biome := biome_manager.get_current_biome() as BiomeDefinition
		_expect(
			biome != null and biome.biome_id == biome_id,
			"biome manager selects region %s biome %s" % [
				String(cell.id),
				String(biome_id)
			]
		)
		if biome == null or biome.environment_layout == null:
			continue
		var layout := biome.environment_layout
		_expect(
			terrain_generator.get_active_biome_id() == biome_id,
			"terrain switches to %s" % String(biome_id)
		)
		var tile_layer := terrain_generator.get_active_tile_layer()
		_expect(tile_layer != null, "%s creates an asset tile layer" % String(biome_id))
		if tile_layer != null:
			_expect(
				tile_layer.get_visual_tile_count() == layout.zone_size.x * layout.zone_size.y,
				"%s tile layer covers every logical cell" % String(biome_id)
			)
			_expect(
				tile_layer.get_missing_asset_count() == 0,
				"%s tile layer has no missing visual cells" % String(biome_id)
			)
		_expect_streamed_region_content(streamer, cell, layout)
		_expect(
			playground.floor_color.is_equal_approx(
				biome.palette.background_color
			),
			"%s palette is applied" % String(biome_id)
		)
		_expect(
			_has_blocked_boundary(obstacle_system),
			"%s retains a physical blocked boundary" % String(biome_id)
		)
		_expect(
			get_nodes_in_group("biome_transition_gates").is_empty(),
			"%s exposes open passages without runtime gates" % String(biome_id)
		)
		_expect(
			_has_thematic_loot(crate_system, biome_id),
			"%s exposes biome-aware crate loot" % String(biome_id)
		)
		await process_frame
		_expect(
			biome.display_name in hud.status_label.text,
			"HUD displays %s" % biome.display_name
		)
		if step == 0 and not cell.passages.is_empty():
			var passage: BiomePassage = cell.passages.front()
			transition_system.cooldown_timer = 0.0
			_expect(
				transition_system.transition_to(
					passage.to_biome_id,
					passage.side,
					passage.to_cell_id
				),
				"transition follows physical passage to %s" % String(passage.to_cell_id)
			)
			await process_frame
			await physics_frame

	if graph != null:
		var graph_biomes: Dictionary = {}
		for region in graph.get_regions_sorted():
			graph_biomes[region.biome_id] = true
		for required_biome in [
			&"infected_plains",
			&"toxic_wastes",
			&"burning_fields",
			&"frozen_outskirts",
			&"drowned_marsh"
		]:
			_expect(graph_biomes.has(required_biome), "graph contains %s" % String(required_biome))

	var marsh := biome_manager.get_biome_definition(&"drowned_marsh") as BiomeDefinition
	var themed_enemy_found := false
	if marsh != null:
		for spawn_index in range(40):
			var enemy_id := marsh.resolve_enemy_id(5, spawn_index, 40)
			if String(enemy_id).contains("drowned") or String(enemy_id).contains("marsh") or String(enemy_id).contains("water"):
				themed_enemy_found = true
				break
	_expect(themed_enemy_found, "advanced biome wave resolves thematic enemies")

	var survival_mode := get_first_node_in_group(
		"survival_mode"
	) as SurvivalMode
	if survival_mode != null:
		survival_mode.stop_mode()
	_finish()

func _has_blocked_boundary(obstacle_system: ObstacleSystem) -> bool:
	for obstacle in obstacle_system.get_active_obstacles():
		var obstacle_id := String(obstacle.get("obstacle_id"))
		if "boundary" in obstacle_id:
			return true
	return false

func _has_thematic_loot(
	crate_system: ResourceCrateSystem,
	biome_id: StringName
) -> bool:
	if biome_id == &"infected_plains":
		return (
			crate_system.get_active_crate_ids().has(&"common")
			and crate_system.get_active_crate_ids().has(&"medical")
		)
	for crate in crate_system.get_active_crates():
		if crate == null or crate.loot_table == null:
			continue
		for entry in crate.loot_table.entries:
			if entry != null and not entry.resource_tag.is_empty():
				return true
	return false

func _expect_streamed_region_content(
	streamer,
	cell: BiomeCell,
	layout: BiomeEnvironmentLayout
) -> void:
	var counts: Dictionary = streamer.get_region_content_counts(cell.id)
	_expect(
		int(counts.get("tiles", 0)) == layout.zone_size.x * layout.zone_size.y,
		"%s streams a full tile layer" % String(cell.biome_id)
	)
	_expect(
		int(counts.get("obstacles", 0)) == layout.obstacle_positions.size(),
		"%s streams all physical obstacles" % String(cell.biome_id)
	)
	_expect(
		int(counts.get("hazards", 0)) == layout.hazard_positions.size(),
		"%s streams all environment hazards" % String(cell.biome_id)
	)
	_expect(
		int(counts.get("crates", 0)) > 0 or layout.crate_positions.is_empty(),
		"%s streams biome resource crates" % String(cell.biome_id)
	)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("ZOMBIE_BIOME_TRANSITION_SMOKE_TEST: PASS")
		quit(0)
		return
	print(
		"ZOMBIE_BIOME_TRANSITION_SMOKE_TEST: FAIL (%d)"
		% failures.size()
	)
	quit(1)
