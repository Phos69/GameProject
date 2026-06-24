extends SceneTree

const OUTPUT_DIRECTORY: String = "res://build/qa"

var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main_scene := load("res://game/main/main.tscn") as PackedScene
	_expect(main_scene != null, "main scene can be loaded for results QA")
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
	var progression := get_first_node_in_group(
		"progression_manager"
	) as ProgressionManager
	var player_manager := get_first_node_in_group(
		"player_manager"
	) as PlayerManager
	var result_screen := get_first_node_in_group(
		"run_results_screen"
	) as RunResultsScreen
	_expect(game_mode_manager != null, "game mode manager is available")
	_expect(wave_manager != null, "wave manager is available")
	_expect(progression != null, "progression manager is available")
	_expect(player_manager != null, "player manager is available")
	_expect(result_screen != null, "results screen is available")
	if (
		game_mode_manager == null
		or wave_manager == null
		or progression == null
		or player_manager == null
		or result_screen == null
	):
		_finish()
		return

	wave_manager.initial_delay = 100.0
	game_mode_manager.set_mode(GameConstants.MODE_SURVIVAL)
	await process_frame
	progression.add_experience(100)
	progression.add_money(24)
	var player := player_manager.players.get(1) as PlayerController
	if player != null:
		player.health_component.apply_damage(9999)
	await process_frame
	await process_frame
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(OUTPUT_DIRECTORY)
	)
	_expect(
		await _capture("milestone_17_run_results.png"),
		"run results screenshot is captured"
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
		print("RUN_RESULTS_VISUAL_QA: PASS")
		quit(0)
		return
	print("RUN_RESULTS_VISUAL_QA: FAIL (%d)" % failures.size())
	quit(1)
