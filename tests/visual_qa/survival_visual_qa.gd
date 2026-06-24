extends SceneTree

const OUTPUT_DIRECTORY: String = "res://build/qa"

var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main_scene := load("res://game/main/main.tscn") as PackedScene
	_expect(main_scene != null, "main scene can be loaded for survival visual QA")
	if main_scene == null:
		_finish()
		return

	var main := main_scene.instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame

	var wave_manager := get_first_node_in_group("wave_manager") as WaveManager
	var game_mode_manager := get_first_node_in_group(
		"game_mode_manager"
	) as GameModeManager
	var local_multiplayer := get_first_node_in_group(
		"local_multiplayer_manager"
	) as LocalMultiplayerManager
	_expect(wave_manager != null, "wave manager is available")
	_expect(game_mode_manager != null, "game mode manager is available")
	_expect(local_multiplayer != null, "local multiplayer manager is available")
	if wave_manager == null or game_mode_manager == null or local_multiplayer == null:
		_finish()
		return

	wave_manager.initial_delay = 0.0
	wave_manager.spawn_interval = 0.08
	local_multiplayer.activate_slot(2)
	game_mode_manager.set_mode(GameConstants.MODE_SURVIVAL)
	for _frame in range(180):
		if wave_manager.state == WaveManager.State.COMBAT:
			break
		await physics_frame
	await process_frame

	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(OUTPUT_DIRECTORY)
	)
	_expect(
		await _capture("milestone_10_survival.png"),
		"survival visual QA screenshot is captured"
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
		print("SURVIVAL_VISUAL_QA: PASS")
		quit(0)
		return
	print("SURVIVAL_VISUAL_QA: FAIL (%d)" % failures.size())
	quit(1)
