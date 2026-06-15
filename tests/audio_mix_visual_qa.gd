extends SceneTree

const OUTPUT_DIRECTORY: String = "res://build/qa"

var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main_scene := load("res://game/main/main.tscn") as PackedScene
	_expect(main_scene != null, "main scene can be loaded for audio menu QA")
	if main_scene == null:
		_finish()
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	await process_frame
	var main_menu := get_first_node_in_group("main_menu") as MainMenu
	_expect(main_menu != null and main_menu.is_open(), "main menu is visible")
	await process_frame
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(OUTPUT_DIRECTORY)
	)
	_expect(
		await _capture("milestone_18_audio_mix_menu.png"),
		"audio mix menu screenshot is captured"
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
		print("AUDIO_MIX_VISUAL_QA: PASS")
		quit(0)
		return
	print("AUDIO_MIX_VISUAL_QA: FAIL (%d)" % failures.size())
	quit(1)
