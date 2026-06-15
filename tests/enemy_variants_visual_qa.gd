extends SceneTree

const OUTPUT_DIRECTORY: String = "res://build/qa"

var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main_scene := load("res://game/main/main.tscn") as PackedScene
	_expect(main_scene != null, "main scene can be loaded for variant QA")
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
	await process_frame
	await process_frame

	var player_positions := [
		Vector2(-150.0, 185.0),
		Vector2(-50.0, 215.0),
		Vector2(50.0, 215.0),
		Vector2(150.0, 185.0)
	]
	for player_slot in range(1, 5):
		var player := player_manager.players.get(player_slot) as PlayerController
		if player != null:
			player.global_position = player_positions[player_slot - 1]

	var enemy_specs := [
		[&"survival_zombie", Vector2(-210.0, -75.0), &"chase"],
		[&"survival_runner", Vector2(0.0, -95.0), &"chase"],
		[&"survival_tank", Vector2(220.0, -65.0), &"attack"]
	]
	for spec in enemy_specs:
		var enemy := enemy_system.spawn_enemy(
			spec[0],
			spec[1]
		) as BasicEnemy
		_expect(enemy != null, "%s is available for visual QA" % spec[0])
		if enemy == null:
			continue
		enemy.set_physics_process(false)
		enemy.visual.set_state(spec[2])
		enemy.visual.set_facing(Vector2.DOWN)
		enemy.visual.set_motion(Vector2(0.0, enemy.move_speed), enemy.move_speed)

	await process_frame
	await process_frame
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(OUTPUT_DIRECTORY)
	)
	_expect(
		await _capture("milestone_12_enemy_variants.png"),
		"enemy variant couch-readability screenshot is captured"
	)
	_finish()

func _capture(file_name: String) -> bool:
	await process_frame
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
	if failures.is_empty():
		print("ENEMY_VARIANTS_VISUAL_QA: PASS")
		quit(0)
		return
	print("ENEMY_VARIANTS_VISUAL_QA: FAIL (%d)" % failures.size())
	quit(1)
