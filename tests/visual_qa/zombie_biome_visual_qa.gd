extends SceneTree

const OUTPUT_DIRECTORY: String = "res://build/qa"
const VISUAL_QA_RUNTIME = preload(
	"res://tests/visual_qa/helpers/visual_qa_runtime.gd"
)

var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main_scene := load("res://game/main/main.tscn") as PackedScene
	_expect(main_scene != null, "main scene can be loaded for biome QA")
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
	var enemy_system := get_first_node_in_group(
		"enemy_system"
	) as EnemySystem
	var streamer := get_first_node_in_group(
		"world_region_streamer"
	) as WorldRegionStreamer
	var player := get_first_node_in_group("players") as PlayerController
	_expect(game_mode_manager != null, "game mode manager is available")
	_expect(wave_manager != null, "wave manager is available")
	_expect(biome_manager != null, "biome manager is available")
	_expect(transition_system != null, "transition system is available")
	_expect(enemy_system != null, "enemy system is available")
	_expect(streamer != null, "world region streamer is available")
	_expect(player != null, "player one is available")
	if (
		game_mode_manager == null
		or wave_manager == null
		or biome_manager == null
		or transition_system == null
		or enemy_system == null
		or streamer == null
		or player == null
	):
		_finish()
		return

	wave_manager.initial_delay = 100.0
	transition_system.transition_cooldown = 0.01
	game_mode_manager.set_mode(GameConstants.MODE_SURVIVAL)
	var world_ready: Dictionary = await VISUAL_QA_RUNTIME.wait_for_capture_ready(
		self,
		func() -> bool:
			return (
				game_mode_manager.active_mode_id == GameConstants.MODE_SURVIVAL
				and player.is_inside_tree()
			)
	)
	_expect(
		bool(world_ready.get("ready", false)),
		"biome QA world is capture-ready: %s"
		% VISUAL_QA_RUNTIME.describe_failure(world_ready)
	)
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(OUTPUT_DIRECTORY)
	)

	var biome_ids: Array[StringName] = [
		&"plains",
		&"toxic_wastes",
		&"burning_plains",
		&"frozen_tundra",
		&"swamp"
	]
	for biome_id in biome_ids:
		if biome_manager.get_current_biome_id() != biome_id:
			transition_system.cooldown_timer = 0.0
			transition_system.transition_to(biome_id, &"east")
			await process_frame
			await physics_frame
		var cell := biome_manager.get_current_biome_cell()
		if cell != null and cell.generated_layout != null:
			var focus := (
				streamer.get_region_offset(cell.id)
				+ cell.generated_layout.logical_to_world(
					cell.generated_layout.player_spawn_cell
				)
			)
			player.global_position = focus
			var camera := root.get_camera_2d()
			if camera != null:
				camera.global_position = focus
				camera.reset_smoothing()
		_clear_qa_enemies()
		await process_frame
		_spawn_biome_roster(enemy_system, biome_id)
		var capture_ready: Dictionary = (
			await VISUAL_QA_RUNTIME.wait_for_capture_ready(
				self,
				func() -> bool: return _biome_capture_marker_is_ready(
					biome_manager,
					biome_id
				)
			)
		)
		_expect(
			bool(capture_ready.get("ready", false)),
			"%s scenario marker is capture-ready: %s"
			% [
				biome_id,
				VISUAL_QA_RUNTIME.describe_failure(capture_ready)
			]
		)
		_expect(
			await _capture("zombie_biome_%s.png" % String(biome_id)),
			"%s screenshot is captured" % String(biome_id)
		)

	_finish()

func _spawn_biome_roster(
	enemy_system: EnemySystem,
	biome_id: StringName
) -> void:
	var roster: Array[StringName] = [&"survival_zombie", &"survival_runner"]
	match biome_id:
		&"toxic_wastes":
			roster = [&"toxic_zombie", &"toxic_exploder"]
		&"burning_plains":
			roster = [&"burned_zombie", &"fire_runner", &"fire_exploder"]
		&"frozen_tundra":
			roster = [&"frozen_zombie", &"ice_armored_zombie"]
		&"swamp":
			roster = [&"drowned_zombie", &"marsh_zombie", &"water_emerging_zombie"]
	for index in range(roster.size()):
		var enemy := enemy_system.spawn_enemy(
			roster[index],
			Vector2(-170.0 + float(index) * 170.0, -85.0)
		)
		if enemy == null:
			continue
		enemy.add_to_group("biome_qa_enemies")
		enemy.set_physics_process(false)
		var visual := enemy.get_node_or_null("Visual") as ZombieVisual
		if visual != null:
			visual.modulate = Color.WHITE
			visual.set_state(&"chase")
			visual.set_facing(Vector2.DOWN)

func _biome_capture_marker_is_ready(
	biome_manager: BiomeManager,
	biome_id: StringName
) -> bool:
	return (
		biome_manager.get_current_biome_id() == biome_id
		and get_nodes_in_group("biome_qa_enemies").size() > 0
	)

func _clear_qa_enemies() -> void:
	for enemy in get_nodes_in_group("biome_qa_enemies"):
		if is_instance_valid(enemy):
			enemy.queue_free()

func _capture(file_name: String) -> bool:
	await process_frame
	if VISUAL_QA_RUNTIME.has_loading_overlay(self):
		return false
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		return false
	return image.save_png(ProjectSettings.globalize_path(
		"%s/%s" % [OUTPUT_DIRECTORY, file_name]
	)) == OK

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	var exit_code := 0
	if failures.is_empty():
		print("ZOMBIE_BIOME_VISUAL_QA: PASS")
	else:
		exit_code = 1
		print("ZOMBIE_BIOME_VISUAL_QA: FAIL (%d)" % failures.size())
	await VISUAL_QA_RUNTIME.cleanup_scene(self)
	quit(exit_code)
