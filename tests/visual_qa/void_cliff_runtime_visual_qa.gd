extends SceneTree

const OUTPUT_DIR := "res://build/qa/void_cliffs"
const OUTPUT_FILE := "void_cliff_runtime_game.png"
const FOREST_OUTPUT_FILE := "forest_grass_cliff_runtime_game.png"
const FOREST_SURFACE_OUTPUT_DIR := "res://build/qa/forest_surfaces"
const WORLD_SEED := 641004

var failures := PackedStringArray()

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed := load("res://game/main/main.tscn") as PackedScene
	_expect(packed != null, "main scene loads for runtime cliff QA")
	if packed == null:
		_finish()
		return
	var main := packed.instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame

	var game_mode_manager := get_first_node_in_group(
		"game_mode_manager"
	) as GameModeManager
	var wave_manager := get_first_node_in_group("wave_manager") as WaveManager
	var biome_manager := get_first_node_in_group("biome_manager") as BiomeManager
	var player_manager := get_first_node_in_group("player_manager") as PlayerManager
	var streamer = get_first_node_in_group("world_region_streamer")
	_expect(game_mode_manager != null, "game mode manager is available")
	_expect(biome_manager != null, "biome manager is available")
	_expect(player_manager != null, "player manager is available")
	_expect(streamer != null, "world region streamer is available")
	if (
		game_mode_manager == null
		or biome_manager == null
		or player_manager == null
		or streamer == null
	):
		_finish()
		return
	if wave_manager != null:
		wave_manager.initial_delay = 100.0
	_expect(
		game_mode_manager.set_mode(GameConstants.MODE_SURVIVAL, {
			"world_seed": WORLD_SEED,
			"biome_map_width": 1,
			"biome_map_height": 1,
			"extra_edge_chance": 0.0
		}),
		"single-region survival starts for runtime cliff QA"
	)
	await _wait_for_tile_layers()

	var layers := get_nodes_in_group("biome_tile_layers")
	_expect(not layers.is_empty(), "runtime creates the asset-driven tile layer")
	for node in layers:
		var layer := node as BiomeTileLayer
		if layer == null:
			continue
		_expect(layer.has_cliff_art_textures(), "runtime tile layer has generated cliff art")
		_expect(
			layer.has_forest_cliff_border_art(),
			"runtime tile layer applies dedicated horizontal and vertical cliff art"
		)
		_expect(layer.has_forest_ground_art_texture(), "runtime tile layer has generated grass art")
		_expect(layer.has_forest_surface_art_textures(), "runtime tile layer has every forest surface")
		_expect(layer.get_cliff_transition_count() > 0, "runtime tile layer builds cliff transitions")
		_expect(
			int(layer.get_forest_cliff_border_counts().get("total", 0)) > 0,
			"runtime fall zones build visible straight border segments"
		)
		_expect(
			int(layer.get_forest_cliff_border_counts().get("faces", 0)) > 0,
			"runtime forest cliffs replace angled per-cell faces with rectilinear faces"
		)

	var cells := biome_manager.get_generated_biome_map()
	_expect(not cells.is_empty(), "runtime generated region exists")
	if cells.is_empty():
		_finish()
		return
	var cell := cells.front() as BiomeCell
	var focus_position := _fall_focus_position(cell, streamer)
	var player := player_manager.players.get(1) as PlayerController
	_expect(player != null, "player one is available in rendered game")
	if player != null:
		player.global_position = focus_position
		player.velocity = Vector2.ZERO
	var camera := root.get_camera_2d()
	_expect(camera != null, "game camera is available")
	if camera != null:
		camera.global_position = focus_position
		camera.reset_smoothing()

	for _frame in range(120):
		await process_frame
	await physics_frame
	var output_absolute := ProjectSettings.globalize_path(OUTPUT_DIR)
	_expect(
		DirAccess.make_dir_recursive_absolute(output_absolute) == OK,
		"runtime cliff QA output directory is available"
	)
	var image := root.get_texture().get_image()
	_expect(image != null and not image.is_empty(), "rendered game capture is available")
	if image != null and not image.is_empty():
		_expect(
			image.save_png(output_absolute.path_join(OUTPUT_FILE)) == OK,
			"rendered game cliff screenshot is saved"
		)
		_expect(
			image.save_png(output_absolute.path_join(FOREST_OUTPUT_FILE)) == OK,
			"rendered grass and cliff screenshot is saved"
		)

	var surface_output_absolute := ProjectSettings.globalize_path(
		FOREST_SURFACE_OUTPUT_DIR
	)
	_expect(
		DirAccess.make_dir_recursive_absolute(surface_output_absolute) == OK,
		"forest surface runtime QA output directory is available"
	)
	var surface_focuses := _find_surface_focuses(layers)
	await _capture_surface_focus(
		surface_focuses,
		&"road",
		"forest_road_runtime.png",
		player,
		camera,
		surface_output_absolute
	)
	await _capture_surface_focus(
		surface_focuses,
		&"path",
		"forest_path_runtime.png",
		player,
		camera,
		surface_output_absolute
	)
	await _capture_surface_focus(
		surface_focuses,
		&"transition",
		"forest_transition_runtime.png",
		player,
		camera,
		surface_output_absolute
	)

	var survival_mode := get_first_node_in_group("survival_mode") as SurvivalMode
	if survival_mode != null:
		survival_mode.stop_mode()
	_finish()

func _wait_for_tile_layers() -> void:
	for _attempt in range(600):
		var layers := get_nodes_in_group("biome_tile_layers")
		var all_ready := not layers.is_empty()
		for node in layers:
			var layer := node as BiomeTileLayer
			if layer != null and layer.is_building():
				all_ready = false
				break
		if all_ready:
			await process_frame
			return
		await create_timer(0.05).timeout
	_expect(false, "runtime tile layer finishes within 30 seconds")

func _fall_focus_position(cell: BiomeCell, streamer) -> Vector2:
	if cell == null or cell.generated_layout == null:
		return Vector2.ZERO
	var layout := cell.generated_layout
	var offset: Vector2 = streamer.get_region_offset(cell.id)
	for index in range(layout.hazard_ids.size()):
		if layout.hazard_ids[index] != &"fall_zone":
			continue
		if index >= layout.hazard_rects.size() or index >= layout.hazard_sides.size():
			continue
		if layout.hazard_sides[index] != &"north":
			continue
		var rect := layout.hazard_rects[index]
		var inside_cell := Vector2i(
			rect.position.x + rect.size.x / 2,
			rect.end.y + 8
		)
		return offset + layout.logical_to_world(inside_cell)
	if not layout.fall_zone_rects.is_empty():
		return offset + layout.rect_center_to_world(layout.fall_zone_rects.front())
	return offset

func _find_surface_focuses(layers: Array[Node]) -> Dictionary:
	var focuses: Dictionary = {}
	var best_scores := {
		&"road": INF,
		&"path": INF,
		&"transition": INF
	}
	for node in layers:
		var layer := node as BiomeTileLayer
		if layer == null or layer.layout == null:
			continue
		var cell_center := Vector2(layer.layout.zone_size) * 0.5
		for y in range(layer.layout.zone_size.y):
			for x in range(layer.layout.zone_size.x):
				var cell := Vector2i(x, y)
				var sample_key := _surface_sample_key(layer.get_resolved_tile_id(cell))
				if sample_key.is_empty():
					continue
				var score := Vector2(cell).distance_squared_to(cell_center)
				if score >= float(best_scores.get(sample_key, INF)):
					continue
				best_scores[sample_key] = score
				focuses[sample_key] = layer.to_global(layer._cell_center_to_world(cell))
	return focuses

func _surface_sample_key(tile_id: StringName) -> StringName:
	match tile_id:
		IsometricTileResolver.TILE_FOREST_ROAD:
			return &"road"
		IsometricTileResolver.TILE_FOREST_PATH:
			return &"path"
		IsometricTileResolver.TILE_GRASS_TO_PATH, IsometricTileResolver.TILE_GRASS_TO_ROAD, IsometricTileResolver.TILE_PATH_TO_ROAD:
			return &"transition"
		_:
			return &""

func _capture_surface_focus(
	focuses: Dictionary,
	sample_key: StringName,
	file_name: String,
	player: PlayerController,
	camera: Camera2D,
	output_absolute: String
) -> void:
	_expect(focuses.has(sample_key), "runtime generated %s sample exists" % String(sample_key))
	if not focuses.has(sample_key):
		return
	var focus: Vector2 = focuses[sample_key]
	if player != null:
		player.global_position = focus
		player.velocity = Vector2.ZERO
	if camera != null:
		camera.global_position = focus
		camera.reset_smoothing()
	for _frame in range(30):
		await process_frame
	var image := root.get_texture().get_image()
	_expect(image != null and not image.is_empty(), "%s runtime capture is available" % String(sample_key))
	if image != null and not image.is_empty():
		_expect(
			image.save_png(output_absolute.path_join(file_name)) == OK,
			"%s runtime screenshot is saved" % String(sample_key)
		)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("VOID_CLIFF_RUNTIME_VISUAL_QA: PASS")
		quit(0)
		return
	print("VOID_CLIFF_RUNTIME_VISUAL_QA: FAIL (%d)" % failures.size())
	quit(1)
