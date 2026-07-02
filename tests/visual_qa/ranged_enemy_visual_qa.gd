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
	_expect(main_scene != null, "main scene can be loaded for ranged QA")
	if main_scene == null:
		_finish()
		return

	var main := main_scene.instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	await process_frame

	var game_mode_manager := get_first_node_in_group(
		"game_mode_manager"
	) as GameModeManager
	var wave_manager := get_first_node_in_group("wave_manager") as WaveManager
	var local_multiplayer := get_first_node_in_group(
		"local_multiplayer_manager"
	) as LocalMultiplayerManager
	var player_manager := get_first_node_in_group(
		"player_manager"
	) as PlayerManager
	var enemy_system := get_first_node_in_group("enemy_system") as EnemySystem
	_expect(game_mode_manager != null, "game mode manager is available")
	_expect(wave_manager != null, "wave manager is available")
	_expect(local_multiplayer != null, "local multiplayer manager is available")
	_expect(player_manager != null, "player manager is available")
	_expect(enemy_system != null, "enemy system is available")
	if (
		game_mode_manager == null
		or wave_manager == null
		or local_multiplayer == null
		or player_manager == null
		or enemy_system == null
	):
		_finish()
		return

	wave_manager.initial_delay = 100.0
	for player_slot in range(2, 5):
		local_multiplayer.activate_slot(player_slot)
	game_mode_manager.set_mode(GameConstants.MODE_SURVIVAL)
	var world_ready: Dictionary = await VISUAL_QA_RUNTIME.wait_for_capture_ready(
		self,
		func() -> bool:
			return (
				game_mode_manager.active_mode_id == GameConstants.MODE_SURVIVAL
				and player_manager.players.size() == 4
			)
	)
	_expect(
		bool(world_ready.get("ready", false)),
		"ranged enemy world is capture-ready: %s"
		% VISUAL_QA_RUNTIME.describe_failure(world_ready)
	)

	var player_positions := [
		Vector2(-165.0, 190.0),
		Vector2(-55.0, 225.0),
		Vector2(55.0, 225.0),
		Vector2(165.0, 190.0)
	]
	for player_slot in range(1, 5):
		var player := player_manager.players.get(player_slot) as PlayerController
		if player != null:
			player.global_position = player_positions[player_slot - 1]

	var roster := [
		[&"survival_zombie", Vector2(-250.0, -90.0)],
		[&"survival_runner", Vector2(-80.0, -120.0)],
		[&"survival_tank", Vector2(110.0, -85.0)]
	]
	var spawned_roster: Array[BasicEnemy] = []
	for spec in roster:
		var enemy := enemy_system.spawn_enemy(spec[0], spec[1]) as BasicEnemy
		if enemy != null:
			spawned_roster.append(enemy)
			enemy.set_physics_process(false)
			enemy.visual.set_state(&"chase")
			enemy.visual.set_facing(Vector2.DOWN)

	var shooter: Node = enemy_system.spawn_enemy(
		&"survival_shooter",
		Vector2(285.0, -115.0)
	)
	_expect(shooter != null, "shooter is available for visual QA")
	if shooter != null:
		shooter.set_physics_process(false)
		shooter.windup_duration = 6.0
		shooter.target = player_manager.players.get(3) as Node2D
		_expect(shooter.start_windup(), "shooter telegraph starts for QA")

	await process_frame
	await process_frame
	_expect(
		spawned_roster.size() == roster.size()
		and shooter != null
		and float(shooter.get("windup_timer")) > 0.0,
		"ranged roster marker includes the active shooter telegraph"
	)
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(OUTPUT_DIRECTORY)
	)
	_expect(
		await _capture("milestone_15_ranged_enemy.png"),
		"ranged roster screenshot is captured"
	)
	_finish()

func _capture(file_name: String) -> bool:
	await process_frame
	if VISUAL_QA_RUNTIME.has_loading_overlay(self):
		return false
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		return false
	var output_path := "%s/%s" % [OUTPUT_DIRECTORY, file_name]
	return image.save_png(ProjectSettings.globalize_path(output_path)) == OK

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	var exit_code := 0
	if failures.is_empty():
		print("RANGED_ENEMY_VISUAL_QA: PASS")
	else:
		exit_code = 1
		print("RANGED_ENEMY_VISUAL_QA: FAIL (%d)" % failures.size())
	await VISUAL_QA_RUNTIME.cleanup_scene(self)
	quit(exit_code)
