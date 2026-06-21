extends SceneTree

var failures: PackedStringArray = []
var _async_world_ready: bool = false

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
	var main_menu := get_first_node_in_group("main_menu") as MainMenu
	var save_manager := get_first_node_in_group("save_manager") as SaveManager
	var infinite_arena_mode := get_first_node_in_group(
		"infinite_arena_mode"
	)
	var survival_mode := get_first_node_in_group("survival_mode") as SurvivalMode
	var biome_manager := get_first_node_in_group("biome_manager") as BiomeManager
	var world_runtime := get_first_node_in_group("world_runtime") as WorldRuntime
	var world_region_streamer := get_first_node_in_group(
		"world_region_streamer"
	) as WorldRegionStreamer
	var hud := get_first_node_in_group("hud_manager") as HUDManager

	_expect(game_mode_manager != null, "game mode manager is available")
	_expect(main_menu != null, "main menu is available")
	_expect(save_manager != null, "save manager is available")
	_expect(infinite_arena_mode != null, "infinite arena mode is registered")
	_expect(survival_mode != null, "shared survival runtime is available")
	_expect(biome_manager != null, "biome manager is available")
	_expect(world_runtime != null, "world runtime node is available")
	_expect(world_region_streamer != null, "world region streamer is available")
	if (
		game_mode_manager == null
		or main_menu == null
		or save_manager == null
		or infinite_arena_mode == null
		or survival_mode == null
		or biome_manager == null
		or world_runtime == null
		or world_region_streamer == null
	):
		_finish()
		return

	_expect(
		game_mode_manager.has_mode(GameConstants.MODE_INFINITE_ARENA),
		"game mode manager exposes infinite arena"
	)
	_expect(
		game_mode_manager.has_mode(GameConstants.MODE_SURVIVAL),
		"game mode manager keeps zombie survival available"
	)
	_expect(
		main_menu.first_mode_button != null
		and main_menu.first_mode_button.text == "Infinite Arena",
		"main menu first mode is Infinite Arena"
	)
	_expect(
		_find_menu_button(main_menu, "Zombie Survival") != null,
		"main menu exposes Zombie Survival as a separate mode"
	)
	_expect(
		String(
			(save_manager.create_empty_save()["settings"] as Dictionary).get(
				"last_mode",
				""
			)
		) == String(GameConstants.MODE_INFINITE_ARENA),
		"new saves default Continue to Infinite Arena"
	)

	var zombie_controller := get_first_node_in_group("zombie_mode_controller")
	_expect(zombie_controller != null, "zombie mode controller is available")
	_expect(
		main_menu.start_selected_mode(GameConstants.MODE_INFINITE_ARENA),
		"main menu starts Infinite Arena"
	)
	await process_frame
	await process_frame
	await physics_frame

	# Infinite Arena builds the chunk asynchronously (worker thread + loading screen),
	# so wait for the world to be ready before asserting on the generated world.
	var world_is_ready := await _await_world_ready(zombie_controller)
	_expect(world_is_ready, "Infinite Arena finishes its async world build")

	_expect(
		game_mode_manager.active_mode_id == GameConstants.MODE_INFINITE_ARENA,
		"Infinite Arena becomes the active mode"
	)
	_expect(
		bool(infinite_arena_mode.get("is_running")),
		"infinite arena adapter is running"
	)
	_expect(survival_mode.is_running, "shared survival runtime is running")
	_expect(not main_menu.is_open(), "menu hides after Infinite Arena starts")
	_expect(
		main_menu.character_select_panel == null
		or not main_menu.character_select_panel.visible,
		"Infinite Arena does not open Character Select"
	)

	_expect(
		not world_runtime.is_active
		and world_runtime.graph == null
		and world_runtime.get_active_region_ids().is_empty(),
		"Infinite Arena does not start WorldRuntime exploration"
	)
	_expect(
		world_region_streamer.get_streamed_region_ids().is_empty(),
		"Infinite Arena does not stream connected regions"
	)
	_expect(
		get_nodes_in_group("biome_transition_gates").is_empty(),
		"Infinite Arena creates no biome transition gates"
	)
	if hud != null:
		_expect(
			hud.exploration_map_panel == null
			or not hud.exploration_map_panel.visible,
			"Infinite Arena leaves exploration map hidden"
		)

	_expect_infinite_arena_world(biome_manager)
	_expect_arena_terrain_is_solid()

	main_menu.open_menu()
	await process_frame
	_expect(
		game_mode_manager.active_mode_id == GameConstants.MODE_MENU,
		"returning to menu restores menu mode"
	)
	_expect(
		not bool(infinite_arena_mode.get("is_running")),
		"Infinite Arena stops on menu return"
	)
	_expect(not survival_mode.is_running, "shared survival runtime stops on menu return")

	_finish()

func _expect_infinite_arena_world(biome_manager: BiomeManager) -> void:
	var cells := biome_manager.get_generated_biome_map()
	_expect(cells.size() == 1, "Infinite Arena generates one biome cell")
	var start_cell := biome_manager.get_current_biome_cell()
	_expect(start_cell != null, "Infinite Arena has an active arena cell")
	if start_cell == null:
		return
	_expect(
		Vector2i(start_cell.width, start_cell.height) == Vector2i(500, 500),
		"Infinite Arena cell is 500x500"
	)
	_expect(
		start_cell.passages.is_empty(),
		"Infinite Arena has no inter-biome passages"
	)
	for side in BiomeCell.SIDES:
		_expect(
			start_cell.get_border(side) == BiomeCell.BorderType.BLOCKED,
			"Infinite Arena %s border is a wall" % String(side)
		)
	var layout := start_cell.generated_layout
	_expect(layout != null, "Infinite Arena has generated terrain")
	if layout == null:
		return
	_expect(
		layout.wall_segment_rects.size() > 0,
		"Infinite Arena layout emits perimeter wall segments"
	)
	_expect(
		layout.fall_zone_rects.is_empty(),
		"Infinite Arena layout has no fall boundary"
	)
	_expect(
		bool(layout.validation_report.get("is_valid", false)),
		"Infinite Arena layout passes validation"
	)

# Regression: with WorldRuntime/region streaming disabled the RegionSeamSystem is
# never started, so its graph stays null. The hazard terrain query must fall back
# to the active biome layout instead of treating every position as void -- otherwise
# the player takes continuous fall damage on solid arena ground.
func _expect_arena_terrain_is_solid() -> void:
	var hazard_system := get_first_node_in_group("hazard_system") as HazardSystem
	_expect(hazard_system != null, "hazard system is available in Infinite Arena")
	if hazard_system == null:
		return
	_expect(
		not hazard_system.is_void_at_world_position(Vector2.ZERO),
		"Infinite Arena spawn center is solid ground, not void"
	)
	var player := get_first_node_in_group("players") as Node2D
	_expect(player != null, "Infinite Arena has an active player")
	if player != null:
		_expect(
			not hazard_system.is_void_at_world_position(player.global_position),
			"Infinite Arena player spawn is not classified as void"
		)

func _await_world_ready(zombie_controller: Node) -> bool:
	if zombie_controller == null:
		return false
	# A member flag (not a lambda-captured local: GDScript lambdas capture locals by
	# value, so mutating one inside the closure would not be visible here).
	_async_world_ready = false
	zombie_controller.world_ready.connect(_on_async_world_ready, CONNECT_ONE_SHOT)
	# Wall-clock bounded: the worker-thread build takes real time even though headless
	# frames are cheap, so poll on elapsed time rather than a frame count.
	var deadline := Time.get_ticks_msec() + 150000
	while not _async_world_ready and Time.get_ticks_msec() < deadline:
		await process_frame
	return _async_world_ready

func _on_async_world_ready(_biome_id: StringName) -> void:
	_async_world_ready = true

func _find_menu_button(main_menu: MainMenu, label_text: String) -> Button:
	for button in main_menu.menu_buttons:
		if button != null and button.text == label_text:
			return button
	return null

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("INFINITE_ARENA_DEFAULT_MODE_SMOKE_TEST: PASS")
		quit(0)
		return
	print(
		"INFINITE_ARENA_DEFAULT_MODE_SMOKE_TEST: FAIL (%d)"
		% failures.size()
	)
	quit(1)
