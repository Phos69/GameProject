extends SceneTree

var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_run_source_audit()

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

	var game_mode_manager := get_first_node_in_group("game_mode_manager") as GameModeManager
	var wave_manager := get_first_node_in_group("wave_manager") as WaveManager
	var biome_manager := get_first_node_in_group("biome_manager") as BiomeManager
	var terrain_generator := get_first_node_in_group("terrain_generator") as TerrainGenerator
	var transition_system := get_first_node_in_group(
		"biome_transition_system"
	) as BiomeTransitionSystem
	var streamer = get_first_node_in_group("world_region_streamer")
	_expect(game_mode_manager != null, "game mode manager is available")
	_expect(wave_manager != null, "wave manager is available")
	_expect(biome_manager != null, "biome manager is available")
	_expect(terrain_generator != null, "terrain generator is available")
	_expect(transition_system != null, "legacy transition command API is available")
	_expect(streamer != null, "world region streamer is available")
	if (
		game_mode_manager == null
		or wave_manager == null
		or biome_manager == null
		or terrain_generator == null
		or transition_system == null
		or streamer == null
	):
		_finish()
		return

	wave_manager.initial_delay = 100.0
	_expect(
		game_mode_manager.set_mode(GameConstants.MODE_SURVIVAL, {
			"world_seed": 101010,
			"biome_map_width": 5,
			"biome_map_height": 5,
			"extra_edge_chance": 0.5
		}),
		"survival starts with the asset-driven region streamer"
	)
	await process_frame
	await physics_frame
	await process_frame

	var current_region_id := biome_manager.get_current_region_id()
	var streamed_ids: Array[StringName] = streamer.get_streamed_region_ids()
	_expect(not current_region_id.is_empty(), "current region is resolved")
	_expect(streamed_ids.size() > 1, "standard survival streams current plus neighbors")
	_expect(
		streamer.get_content_level(current_region_id) == 2,
		"current region is streamed as FULL gameplay content"
	)
	var current_counts: Dictionary = streamer.get_region_content_counts(current_region_id)
	_expect(
		int(current_counts.get("tiles", 0)) > 0,
		"current streamed region owns an asset tile layer"
	)
	_expect(
		terrain_generator.get_active_tile_layer() != null,
		"terrain generator tracks the current streamed tile layer"
	)
	_expect(
		terrain_generator.get_active_ground() == null,
		"standard survival does not instantiate BiomeRegionGround"
	)
	_expect(
		terrain_generator.get_generated_patches().is_empty(),
		"standard survival does not instantiate BiomeTerrainPatch nodes"
	)
	_expect(
		_count_biome_region_ground(main) == 0,
		"scene tree contains no legacy BiomeRegionGround nodes"
	)
	_expect(
		_count_biome_terrain_patch(main) == 0,
		"scene tree contains no legacy BiomeTerrainPatch nodes"
	)
	_expect(
		_count_named_prefix(main, "NeighborGround_") == 0,
		"standard survival does not instantiate legacy neighbor ground placeholders"
	)
	_expect(
		get_nodes_in_group("multi_region_renderer").is_empty(),
		"legacy multi-region renderer is not instantiated during standard streaming"
	)
	_expect(
		get_nodes_in_group("biome_transition_gates").is_empty(),
		"standard survival does not instantiate biome transition gate nodes"
	)
	_expect(
		transition_system.get_active_gates().is_empty(),
		"legacy transition command API has no active gates"
	)

	var survival_mode := get_first_node_in_group("survival_mode") as SurvivalMode
	if survival_mode != null:
		survival_mode.stop_mode()
	_finish()

func _run_source_audit() -> void:
	var controller_source := _read_text(
		"res://game/modes/zombie/zombie_mode_controller.gd"
	)
	var resolve_body := _extract_between(
		controller_source,
		"func _resolve_components() -> void:",
		"func _connect_wave_manager() -> void:"
	)
	_expect(
		not resolve_body.contains("MultiRegionRenderer.new()"),
		"component resolution does not create the legacy renderer"
	)
	_expect(
		not controller_source.contains("BiomeTransitionGate"),
		"zombie mode controller has no transition gate dependency"
	)
	var transition_source := _read_text(
		"res://game/modes/zombie/biome_transition_system.gd"
	)
	var configure_body := _extract_between(
		transition_source,
		"func configure_biome(biome: BiomeDefinition) -> void:",
		"func stop_run() -> void:"
	)
	_expect(
		not configure_body.contains("_spawn_gate"),
		"transition configuration does not spawn legacy gates"
	)
	_expect(
		not configure_body.contains("_spawn_generated_map_gates"),
		"transition configuration does not spawn generated map gates"
	)

func _count_biome_region_ground(node: Node) -> int:
	var count := 1 if node is BiomeRegionGround else 0
	for child in node.get_children():
		count += _count_biome_region_ground(child)
	return count

func _count_biome_terrain_patch(node: Node) -> int:
	var count := 1 if node is BiomeTerrainPatch else 0
	for child in node.get_children():
		count += _count_biome_terrain_patch(child)
	return count

func _count_named_prefix(node: Node, prefix: String) -> int:
	var count := 1 if node.name.begins_with(prefix) else 0
	for child in node.get_children():
		count += _count_named_prefix(child, prefix)
	return count

func _extract_between(text: String, start_marker: String, end_marker: String) -> String:
	var start_index := text.find(start_marker)
	if start_index < 0:
		return ""
	start_index += start_marker.length()
	var end_index := text.find(end_marker, start_index)
	if end_index < 0:
		return text.substr(start_index)
	return text.substr(start_index, end_index - start_index)

func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("MILESTONE_10_LEGACY_CLEANUP_SMOKE_TEST: PASS")
		quit(0)
		return
	print("MILESTONE_10_LEGACY_CLEANUP_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
