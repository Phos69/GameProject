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
	await physics_frame

	var game_mode_manager := get_first_node_in_group(
		"game_mode_manager"
	) as GameModeManager
	var survival_mode := get_first_node_in_group(
		"survival_mode"
	) as SurvivalMode
	var wave_manager := get_first_node_in_group(
		"wave_manager"
	) as WaveManager
	var biome_manager := get_first_node_in_group(
		"biome_manager"
	) as BiomeManager
	var obstacle_system := get_first_node_in_group(
		"obstacle_system"
	) as ObstacleSystem
	var hazard_system := get_first_node_in_group(
		"hazard_system"
	) as HazardSystem
	var crate_system := get_first_node_in_group(
		"resource_crate_system"
	) as ResourceCrateSystem
	var transition_system := get_first_node_in_group(
		"biome_transition_system"
	) as BiomeTransitionSystem
	var zombie_spawner := get_first_node_in_group(
		"zombie_spawner"
	) as ZombieSpawner

	_expect(game_mode_manager != null, "game mode manager is available")
	_expect(survival_mode != null, "survival mode is available")
	_expect(wave_manager != null, "wave manager is available")
	_expect(biome_manager != null, "biome manager is available")
	_expect(obstacle_system != null, "obstacle system is available")
	_expect(hazard_system != null, "hazard system is available")
	_expect(crate_system != null, "crate system is available")
	_expect(transition_system != null, "transition system is available")
	_expect(zombie_spawner != null, "zombie spawner is available")
	if (
		game_mode_manager == null
		or survival_mode == null
		or wave_manager == null
		or biome_manager == null
		or obstacle_system == null
		or hazard_system == null
		or crate_system == null
		or transition_system == null
		or zombie_spawner == null
	):
		_finish()
		return

	var seed_context := {
		"world_seed": 424242,
		"preserve_biome_sequence": false
	}
	biome_manager.start_run(seed_context)
	var signature_a := biome_manager.get_generation_signature()
	biome_manager.start_run(seed_context)
	var signature_b := biome_manager.get_generation_signature()
	biome_manager.start_run({
		"world_seed": 424243,
		"preserve_biome_sequence": false
	})
	var signature_c := biome_manager.get_generation_signature()
	_expect(signature_a == signature_b, "same seed regenerates identical biome map")
	_expect(signature_a != signature_c, "different seed changes generated map signature")
	_expect(
		int(biome_manager.get_seed_record().get("global_seed", 0)) == 424243,
		"seed record stores the current global seed"
	)

	var cells := biome_manager.get_generated_biome_map()
	_expect(cells.size() >= 5, "global biome map contains the planned biome cells")
	var start_cell := biome_manager.get_current_biome_cell()
	_expect(
		start_cell != null and start_cell.biome_id == &"infected_plains",
		"generated run starts from the base biome"
	)
	for cell in cells:
		_validate_cell(cell)

	var base_layout := (
		start_cell.generated_layout
		if start_cell != null
		else null
	)
	_expect(base_layout != null, "starting biome has a generated layout")
	if base_layout != null:
		_expect(
			base_layout.zone_size == Vector2i(200, 200),
			"starting biome is generated as 200x200 logical cells"
		)
		_expect(
			_has_large_house(base_layout),
			"base biome contains large blocking houses"
		)
		_expect(
			(not base_layout.road_rects.is_empty() or not base_layout.get_road_cells().is_empty())
			and not base_layout.crate_cells.is_empty(),
			"base biome has roads, corridors and resource crates"
		)

	wave_manager.initial_delay = 100.0
	transition_system.transition_cooldown = 0.01
	_expect(
		game_mode_manager.set_mode(GameConstants.MODE_SURVIVAL, {
			"world_seed": 424242,
			"preserve_biome_sequence": true
		}),
		"survival starts with generated biome map context"
	)
	await process_frame
	await physics_frame

	var active_cell := biome_manager.get_current_biome_cell()
	var active_biome := biome_manager.get_current_biome() as BiomeDefinition
	var active_layout := (
		active_cell.generated_layout
		if active_cell != null
		else null
	)
	_expect(
		active_cell != null and active_cell.biome_id == &"infected_plains",
		"survival uses the generated starting cell"
	)
	if active_layout != null and active_biome != null:
		_expect(
			obstacle_system.get_active_obstacles().size()
			== active_layout.obstacle_positions.size(),
			"obstacle system renders the generated obstacle layout"
		)
		_expect(
			hazard_system.get_active_hazards().size()
			== active_layout.hazard_positions.size(),
			"hazard system renders fall zones and biome hazards"
		)
		_expect(
			crate_system.get_active_crates().size()
			== active_layout.crate_positions.size(),
			"resource crate system renders generated crates"
		)
		_expect(
			transition_system.get_active_gates().size()
			== active_cell.passages.size(),
			"transition gates mirror generated passages"
		)
		if not active_layout.fall_zone_rects.is_empty():
			var fall_position := active_layout.rect_center_to_world(
				active_layout.fall_zone_rects.front()
			)
			_expect(
				not zombie_spawner.is_spawn_position_valid(
					fall_position,
					active_biome
				),
				"zombie spawner rejects generated fall zones"
			)

	if active_cell != null and not active_cell.passages.is_empty():
		var passage: BiomePassage = active_cell.passages.front()
		transition_system.cooldown_timer = 0.0
		_expect(
			transition_system.transition_to(
				passage.to_biome_id,
				passage.side,
				passage.to_cell_id
			),
			"generated passage transitions to the neighbor biome"
		)
		await process_frame
		_expect(
			biome_manager.get_current_biome_cell() != active_cell,
			"biome manager advances to the generated neighbor cell"
		)

	survival_mode.stop_mode()
	_finish()

func _validate_cell(cell: BiomeCell) -> void:
	_expect(cell.width == 200 and cell.height == 200, "%s is 200x200" % cell.id)
	_expect(cell.seed != 0, "%s has a local deterministic seed" % cell.id)
	_expect(cell.generated_layout != null, "%s has generated terrain" % cell.id)
	if cell.generated_layout != null:
		_expect(
			bool(cell.generated_layout.validation_report.get("is_valid", false)),
			"%s passes pathfinding validation" % cell.id
		)
		var placement_errors := (
			cell.generated_layout.validation_report.get(
				"placement_errors",
				PackedStringArray()
			) as PackedStringArray
		)
		_expect(
			placement_errors.is_empty(),
			"%s has valid spawn, crate and hazard placements" % cell.id
		)
	for side in BiomeCell.SIDES:
		if cell.has_neighbor(side):
			_expect(
				cell.get_border(side) == BiomeCell.BorderType.CONNECTED,
				"%s %s border is connected" % [cell.id, side]
			)
			_expect(
				not cell.get_passages_for_side(side).is_empty(),
				"%s %s border has a passage" % [cell.id, side]
			)
		else:
			_expect(
				cell.get_border(side) == BiomeCell.BorderType.FALL
				or cell.get_border(side) == BiomeCell.BorderType.BLOCKED,
				"%s %s border is fall or blocked by graph topology" % [cell.id, side]
			)
	if cell.generated_layout != null:
		var classification := cell.generated_layout.get_classification_report()
		_expect(
			bool(classification.get("is_complete", false)),
			"%s has complete 200x200 terrain classification" % cell.id
		)

func _has_large_house(layout: BiomeEnvironmentLayout) -> bool:
	for index in range(layout.obstacle_rects.size()):
		var rect := layout.obstacle_rects[index]
		var obstacle_id := layout.obstacle_ids[index]
		if (
			obstacle_id == &"ruined_house"
			and rect.size.x >= 12
			and rect.size.y >= 12
		):
			return true
	return false

func _has_biome_navigation_identity(
	layout: BiomeEnvironmentLayout,
	biome_id: StringName
) -> bool:
	var expected_tag := &"broken_street"
	var expected_obstacle := &"ruined_house"
	match biome_id:
		&"toxic_wastes":
			expected_tag = &"service_lane"
			expected_obstacle = &"pipe_stack"
		&"burning_fields":
			expected_tag = &"ash_lane"
			expected_obstacle = &"burned_car"
		&"frozen_outskirts":
			expected_tag = &"packed_snow_path"
			expected_obstacle = &"ice_block"
		&"drowned_marsh":
			expected_tag = &"wooden_walkway"
			expected_obstacle = &"dead_tree"
		_:
			expected_tag = &"broken_street"
			expected_obstacle = &"ruined_house"
	return (
		layout.terrain_patch_tags.has(expected_tag)
		and layout.obstacle_ids.has(expected_obstacle)
	)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("BIOME_WORLD_GENERATION_SMOKE_TEST: PASS")
		quit(0)
		return
	print("BIOME_WORLD_GENERATION_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
