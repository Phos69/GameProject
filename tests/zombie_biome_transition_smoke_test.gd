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
		or hud == null
		or playground == null
	):
		_finish()
		return

	wave_manager.initial_delay = 100.0
	transition_system.transition_cooldown = 0.01
	_expect(
		game_mode_manager.set_mode(GameConstants.MODE_SURVIVAL),
		"survival starts with biome transitions"
	)
	await process_frame
	await physics_frame

	var biome_path: Array[StringName] = [
		&"infected_plains",
		&"toxic_wastes",
		&"burning_fields",
		&"frozen_outskirts",
		&"drowned_marsh"
	]
	for index in range(biome_path.size()):
		var biome_id := biome_path[index]
		if index > 0:
			transition_system.cooldown_timer = 0.0
			_expect(
				transition_system.transition_to(biome_id, &"east"),
				"transition reaches %s" % String(biome_id)
			)
			await process_frame
			await physics_frame
		var biome := biome_manager.get_current_biome() as BiomeDefinition
		_expect(
			biome != null and biome.biome_id == biome_id,
			"biome manager selects %s" % String(biome_id)
		)
		if biome == null or biome.environment_layout == null:
			continue
		var layout := biome.environment_layout
		_expect(
			terrain_generator.get_active_biome_id() == biome_id,
			"terrain switches to %s" % String(biome_id)
		)
		_expect(
			terrain_generator.get_generated_patches().size()
			== layout.terrain_patch_positions.size(),
			"%s creates all terrain patches" % String(biome_id)
		)
		_expect(
			obstacle_system.get_active_obstacles().size()
			== layout.obstacle_positions.size(),
			"%s creates all physical obstacles" % String(biome_id)
		)
		_expect(
			crate_system.get_active_crates().size()
			== layout.crate_positions.size(),
			"%s creates all resource crates" % String(biome_id)
		)
		_expect(
			hazard_system.get_active_hazards().size()
			== layout.hazard_positions.size(),
			"%s creates all environment hazards" % String(biome_id)
		)
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
		var expected_gate_count := (
			1 if index == 0 or index == biome_path.size() - 1 else 2
		)
		_expect(
			transition_system.get_active_gates().size()
			== expected_gate_count,
			"%s exposes the expected traversable borders" % String(biome_id)
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

	var marsh := biome_manager.get_current_biome() as BiomeDefinition
	var themed_enemy_found := false
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
