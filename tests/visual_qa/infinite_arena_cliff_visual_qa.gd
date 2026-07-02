extends SceneTree

const OUTPUT_DIR := "res://build/qa/infinite_arena_cliffs"
const WORLD_SEED := 8800555
const VISUAL_QA_RUNTIME = preload(
	"res://tests/visual_qa/helpers/visual_qa_runtime.gd"
)

var failures := PackedStringArray()
var world_build_ready := false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed := load("res://game/main/main.tscn") as PackedScene
	_expect(packed != null, "main scene loads for Infinite Arena cliff QA")
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
	var biome_manager := get_first_node_in_group("biome_manager") as BiomeManager
	var player_manager := get_first_node_in_group("player_manager") as PlayerManager
	var wave_manager := get_first_node_in_group("wave_manager") as WaveManager
	var zombie_controller := get_first_node_in_group("zombie_mode_controller")
	_expect(game_mode_manager != null, "game mode manager is available")
	_expect(biome_manager != null, "biome manager is available")
	_expect(player_manager != null, "player manager is available")
	_expect(zombie_controller != null, "zombie controller is available")
	if (
		game_mode_manager == null
		or biome_manager == null
		or player_manager == null
		or zombie_controller == null
	):
		_finish()
		return
	if wave_manager != null:
		wave_manager.initial_delay = 100.0
	zombie_controller.world_ready.connect(_on_world_ready, CONNECT_ONE_SHOT)
	_expect(
		game_mode_manager.set_mode(GameConstants.MODE_INFINITE_ARENA, {
			"world_seed": WORLD_SEED,
			"character_id": &"ranger"
		}),
		"Infinite Arena starts for cliff QA"
	)
	await _wait_for_world()
	if not world_build_ready:
		_finish()
		return

	var cell := biome_manager.get_current_biome_cell()
	_expect(cell != null and cell.generated_layout != null, "Infinite Arena layout is available")
	if cell == null or cell.generated_layout == null:
		_finish()
		return
	var layout := cell.generated_layout
	_expect(layout.uses_raised_perimeter_cliffs(), "Infinite Arena selects raised cliffs")
	var perimeter_fall_zones := 0
	for index in range(layout.hazard_ids.size()):
		if (
			layout.hazard_ids[index] == &"fall_zone"
			and (
				index >= layout.hazard_sides.size()
				or layout.hazard_sides[index] != &"internal"
			)
		):
			perimeter_fall_zones += 1
	_expect(
		perimeter_fall_zones == 0,
		"Infinite Arena raised perimeter cliffs are not fall zones"
	)
	var cliff_count := 0
	var all_cliffs_have_art := true
	for node in get_nodes_in_group("environment_obstacles"):
		var obstacle := node as BiomeObstacle
		if obstacle == null or not obstacle.is_perimeter_wall():
			continue
		cliff_count += 1
		all_cliffs_have_art = all_cliffs_have_art and obstacle.has_raised_cliff_art()
	_expect(all_cliffs_have_art, "every perimeter cliff has face and crown art")
	_expect(
		cliff_count == layout.wall_segment_rects.size(),
		"every generated raised cliff segment exists at runtime"
	)

	var player := player_manager.players.get(1) as PlayerController
	var camera := root.get_camera_2d()
	_expect(player != null, "player one is available")
	_expect(camera != null, "game camera is available")
	if player != null:
		player.set_physics_process(false)
	if camera != null:
		camera.set_process(false)
	var output_absolute := ProjectSettings.globalize_path(OUTPUT_DIR)
	_expect(
		DirAccess.make_dir_recursive_absolute(output_absolute) == OK,
		"cliff QA output directory is available"
	)
	var focuses := {
		"north": Vector2i(layout.zone_size.x / 2, 18),
		"south": Vector2i(layout.zone_size.x / 2, layout.zone_size.y - 18),
		"west": Vector2i(18, layout.zone_size.y / 2),
		"east": Vector2i(layout.zone_size.x - 18, layout.zone_size.y / 2),
		"north_west_corner": Vector2i(22, 22)
	}
	for label in focuses:
		await _capture_focus(
			label,
			layout.logical_to_world(focuses[label]),
			player,
			camera,
			output_absolute
		)

	game_mode_manager.set_mode(GameConstants.MODE_MENU)
	_finish()

func _wait_for_world() -> void:
	var deadline := Time.get_ticks_msec() + 150000
	while not world_build_ready and Time.get_ticks_msec() < deadline:
		await create_timer(0.05).timeout
	_expect(world_build_ready, "Infinite Arena async world build completes")

func _capture_focus(
	label: String,
	focus: Vector2,
	player: PlayerController,
	camera: Camera2D,
	output_absolute: String
) -> void:
	if player != null:
		player.global_position = focus
		player.velocity = Vector2.ZERO
	if camera != null:
		camera.global_position = focus
		camera.reset_smoothing()
	var capture_ready: Dictionary = (
		await VISUAL_QA_RUNTIME.wait_for_capture_ready(
			self,
			func() -> bool:
				return (
					player != null
					and camera != null
					and player.global_position.is_equal_approx(focus)
					and camera.global_position.is_equal_approx(focus)
				),
			false
		)
	)
	_expect(
		bool(capture_ready.get("ready", false)),
		"%s raised cliff marker is capture-ready: %s"
		% [label, VISUAL_QA_RUNTIME.describe_failure(capture_ready)]
	)
	if not bool(capture_ready.get("ready", false)):
		return
	var image := root.get_texture().get_image()
	_expect(image != null and not image.is_empty(), "%s capture is available" % label)
	if image == null or image.is_empty():
		return
	_expect(
		image.save_png(output_absolute.path_join("%s.png" % label)) == OK,
		"%s raised cliff screenshot is saved" % label
	)

func _on_world_ready(_biome_id: StringName) -> void:
	world_build_ready = true

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	var exit_code := 0
	if failures.is_empty():
		print("INFINITE_ARENA_CLIFF_VISUAL_QA: PASS")
	else:
		exit_code = 1
		print("INFINITE_ARENA_CLIFF_VISUAL_QA: FAIL (%d)" % failures.size())
	await VISUAL_QA_RUNTIME.cleanup_scene(self)
	quit(exit_code)
