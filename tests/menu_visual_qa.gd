extends SceneTree

const OUTPUT_DIRECTORY: String = "res://build/qa"

var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main_scene := load("res://game/main/main.tscn") as PackedScene
	_expect(main_scene != null, "main scene can be loaded for visual QA")
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
	var game_mode_manager := get_first_node_in_group(
		"game_mode_manager"
	) as GameModeManager
	var audio_manager := get_first_node_in_group("audio_manager") as AudioManager
	_expect(main_menu != null, "main menu is available for visual QA")
	_expect(game_mode_manager != null, "game mode manager is available")
	_expect(audio_manager != null, "audio manager is available")
	if main_menu == null or game_mode_manager == null or audio_manager == null:
		_finish()
		return

	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(OUTPUT_DIRECTORY)
	)
	_expect(
		await _capture("menu_initial.png"),
		"initial menu screenshot is captured"
	)

	await _press_joypad_button(JOY_BUTTON_DPAD_DOWN)
	_expect(
		root.gui_get_focus_owner() == main_menu.first_mode_button,
		"simulated D-pad focuses Infinite Arena"
	)
	_expect(
		await _capture("menu_joypad_focus.png"),
		"joypad focus screenshot is captured"
	)

	await _press_joypad_button(JOY_BUTTON_A)
	await process_frame
	_expect(
		game_mode_manager.active_mode_id == GameConstants.MODE_INFINITE_ARENA,
		"simulated joypad A starts Infinite Arena"
	)
	_expect(
		await _capture("infinite_arena_started.png"),
		"Infinite Arena screenshot is captured"
	)
	await _press_escape()
	await process_frame
	_expect(main_menu.is_open(), "Escape returns from Infinite Arena to the menu")

	await _press_joypad_button(JOY_BUTTON_DPAD_DOWN)
	await _press_joypad_button(JOY_BUTTON_DPAD_DOWN)
	_expect(
		_focused_button_text() == "Zombie Survival",
		"simulated D-pad reaches Zombie Survival"
	)
	await _press_joypad_button(JOY_BUTTON_A)
	await process_frame
	_expect(
		main_menu.character_select_panel.visible,
		"simulated joypad A opens character select before survival"
	)
	_expect(
		await _capture("character_select_opened.png"),
		"character select screenshot is captured"
	)
	await _press_joypad_button(JOY_BUTTON_A)
	_expect(
		not main_menu.character_start_button.disabled,
		"simulated joypad A assigns the focused character"
	)
	main_menu.character_start_button.grab_focus()
	await process_frame
	await _press_joypad_button(JOY_BUTTON_A)
	await process_frame
	_expect(
		game_mode_manager.active_mode_id == GameConstants.MODE_SURVIVAL,
		"simulated joypad A confirms selected character and starts survival"
	)
	_expect(
		await _capture("survival_started.png"),
		"survival screenshot is captured"
	)

	await _press_escape()
	_expect(main_menu.is_open(), "Escape returns to the menu")
	_expect(
		await _capture("menu_returned.png"),
		"returned menu screenshot is captured"
	)

	print("VISUAL_QA_AUDIO_DRIVER: ", AudioServer.get_driver_name())
	var connected_joypads := Input.get_connected_joypads()
	print("VISUAL_QA_JOYPADS: ", connected_joypads.size())
	for device_id in connected_joypads:
		print("VISUAL_QA_JOYPAD: ", device_id, " ", Input.get_joy_name(device_id))
	print("VISUAL_QA_FOCUS_AUDIO_FRAMES: ", audio_manager.play_ui_focus())
	print("VISUAL_QA_CONFIRM_AUDIO_FRAMES: ", audio_manager.play_ui_confirm())
	_finish()

func _focused_button_text() -> String:
	var focused := root.gui_get_focus_owner() as Button
	return focused.text if focused != null else ""

func _capture(file_name: String) -> bool:
	await process_frame
	if DisplayServer.get_name() == "headless":
		print("VISUAL_QA_CAPTURE_SKIPPED: ", file_name, " headless display")
		return true
	var viewport_texture := root.get_texture()
	if viewport_texture == null:
		print("VISUAL_QA_CAPTURE_SKIPPED: ", file_name, " no viewport texture")
		return false
	var image := viewport_texture.get_image()
	if image == null or image.is_empty():
		print("VISUAL_QA_CAPTURE_SKIPPED: ", file_name, " empty viewport image")
		return false
	var output_path := "%s/%s" % [OUTPUT_DIRECTORY, file_name]
	return image.save_png(ProjectSettings.globalize_path(output_path)) == OK

func _press_joypad_button(button_index: JoyButton) -> void:
	var pressed := InputEventJoypadButton.new()
	pressed.device = 0
	pressed.button_index = button_index
	pressed.pressed = true
	Input.parse_input_event(pressed)
	await process_frame
	var released := pressed.duplicate() as InputEventJoypadButton
	released.pressed = false
	Input.parse_input_event(released)
	await process_frame

func _press_escape() -> void:
	var pressed := InputEventKey.new()
	pressed.keycode = KEY_ESCAPE
	pressed.pressed = true
	Input.parse_input_event(pressed)
	await process_frame
	var released := pressed.duplicate() as InputEventKey
	released.pressed = false
	Input.parse_input_event(released)
	await process_frame

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("MENU_VISUAL_QA: PASS")
		quit(0)
		return
	print("MENU_VISUAL_QA: FAIL (%d)" % failures.size())
	quit(1)
