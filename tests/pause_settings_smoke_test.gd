extends SceneTree

const TEMP_SAVE_PATH: String = "user://pause_settings_smoke_test.json"

var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_remove_temp_save()
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
	await process_frame

	var game_mode_manager := get_first_node_in_group(
		"game_mode_manager"
	) as GameModeManager
	var main_menu := get_first_node_in_group("main_menu") as MainMenu
	var pause_menu := get_first_node_in_group("pause_menu") as PauseMenu
	var save_manager := get_first_node_in_group("save_manager") as SaveManager
	var video_settings := get_first_node_in_group(
		"video_settings_manager"
	) as VideoSettingsManager
	var input_manager := get_first_node_in_group(
		"input_manager"
	) as InputManager
	var local_multiplayer := get_first_node_in_group(
		"local_multiplayer_manager"
	) as LocalMultiplayerManager
	_expect(game_mode_manager != null, "game mode manager is available")
	_expect(main_menu != null, "main menu is available")
	_expect(pause_menu != null, "pause menu is available")
	_expect(save_manager != null, "save manager is available")
	_expect(video_settings != null, "video settings manager is available")
	_expect(input_manager != null, "input manager is available")
	_expect(local_multiplayer != null, "local multiplayer manager is available")
	if (
		game_mode_manager == null
		or main_menu == null
		or pause_menu == null
		or save_manager == null
		or video_settings == null
		or input_manager == null
		or local_multiplayer == null
	):
		_finish()
		return

	main_menu._open_settings(&"audio")
	await process_frame
	_expect(
		main_menu.settings_panel != null and main_menu.settings_panel.visible,
		"main menu opens the shared settings page"
	)
	_expect(
		main_menu.volume_sliders.has(&"Master")
		and main_menu.volume_sliders.has(&"Music")
		and main_menu.volume_sliders.has(&"SFX"),
		"audio controls live in the settings page"
	)
	await _press_joypad_button(JOY_BUTTON_RIGHT_SHOULDER)
	await _wait_navigation_cooldown()
	_expect(
		main_menu.settings_panel.tab_container.current_tab
		== int(main_menu.settings_panel.tab_indices[&"video"]),
		"RB moves settings from Audio to Video"
	)
	_expect(
		root.gui_get_focus_owner()
		== main_menu.settings_panel.video_controls.get(&"display_mode"),
		"settings focuses a valid video control after RB"
	)
	await _press_joypad_button(JOY_BUTTON_LEFT_SHOULDER)
	await _wait_navigation_cooldown()
	_expect(
		main_menu.settings_panel.tab_container.current_tab
		== int(main_menu.settings_panel.tab_indices[&"audio"]),
		"LB moves settings from Video to Audio"
	)
	await _press_joypad_button(JOY_BUTTON_LEFT_SHOULDER)
	await _wait_navigation_cooldown()
	_expect(
		main_menu.settings_panel.tab_container.current_tab
		== int(main_menu.settings_panel.tab_indices[&"controls"]),
		"LB wraps settings from first tab to last tab"
	)
	await _press_joypad_button(JOY_BUTTON_BACK)
	await _wait_navigation_cooldown()
	_expect(
		not main_menu.settings_panel.visible and main_menu.primary_panel.visible,
		"Back closes Settings and restores the previous menu"
	)
	main_menu._open_settings(&"audio")
	await process_frame
	main_menu._open_visual_settings()
	await process_frame
	_expect(
		main_menu.settings_panel.tab_container.current_tab
		== int(main_menu.settings_panel.tab_indices[&"video"]),
		"legacy visual settings entry opens the video tab"
	)
	main_menu._close_visual_settings()

	_expect(
		video_settings.set_resolution(Vector2i(1600, 900)),
		"video resolution can be changed"
	)
	_expect(video_settings.set_max_fps(120), "frame limit can be changed")
	_expect(
		video_settings.set_display_mode(&"windowed"),
		"window mode can be selected"
	)
	video_settings.set_borderless(true)
	video_settings.set_vsync(false)

	var fire_event := InputEventJoypadButton.new()
	fire_event.device = 0
	fire_event.button_index = JOY_BUTTON_B
	fire_event.pressed = true
	_expect(
		input_manager.rebind_joystick_action(&"fire", fire_event),
		"fire can be rebound to a joypad button"
	)
	_expect(
		_action_has_button(&"p1_fire", 0, JOY_BUTTON_B)
		and _action_has_button(&"p2_fire", 1, JOY_BUTTON_B),
		"rebinding a player action updates every local player slot"
	)
	var join_event := InputEventJoypadButton.new()
	join_event.device = 0
	join_event.button_index = JOY_BUTTON_LEFT_SHOULDER
	join_event.pressed = true
	_expect(
		local_multiplayer.rebind_joystick_button(&"join", join_event),
		"join can be rebound as a joystick control"
	)

	save_manager.save_path = TEMP_SAVE_PATH
	save_manager.auto_persist_in_headless = true
	save_manager.autosave_progression = false
	save_manager.autosave_mode_selection = false
	_expect(save_manager.save_game(), "save v5 writes video and controls")
	var saved := _read_temp_save()
	var saved_settings := saved.get("settings", {}) as Dictionary
	_expect(
		int(saved.get("version", 0)) == SaveManager.SAVE_VERSION,
		"settings save uses the current schema"
	)
	_expect(
		saved_settings.get("video", null) is Dictionary
		and saved_settings.get("controls", null) is Dictionary,
		"save contains dedicated video and controls sections"
	)

	input_manager.reset_joystick_bindings()
	local_multiplayer.reset_joystick_buttons()
	video_settings.restore_settings_data({})
	_expect(save_manager.load_game(), "save v5 reload succeeds")
	_expect(
		_action_has_button(&"p1_fire", 0, JOY_BUTTON_B),
		"rebound fire survives save/load"
	)
	_expect(
		local_multiplayer.join_button == JOY_BUTTON_LEFT_SHOULDER,
		"rebound join survives save/load"
	)
	_expect(
		int(video_settings.get_setting(&"resolution_width")) == 1600
		and int(video_settings.get_setting(&"resolution_height")) == 900
		and int(video_settings.get_setting(&"max_fps")) == 120
		and bool(video_settings.get_setting(&"borderless"))
		and not bool(video_settings.get_setting(&"vsync")),
		"video settings survive save/load"
	)

	_expect(
		game_mode_manager.set_mode(GameConstants.MODE_DUNGEON),
		"test gameplay mode can start"
	)
	await process_frame
	await _press_pause_button()
	_expect(
		pause_menu.is_open() and paused,
		"Start opens the pause menu and pauses gameplay"
	)
	pause_menu._open_settings()
	await process_frame
	_expect(
		pause_menu.settings_panel.visible
		and not pause_menu.pause_panel.visible,
		"pause menu opens the shared settings page"
	)
	pause_menu.settings_panel.close()
	await process_frame
	_expect(
		pause_menu.pause_panel.visible,
		"closing settings returns to the pause menu"
	)
	await _press_pause_button()
	_expect(
		not pause_menu.is_open() and not paused,
		"Start resumes gameplay from the pause menu"
	)

	_remove_temp_save()
	_finish()

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

func _wait_navigation_cooldown() -> void:
	await create_timer(0.22).timeout
	await process_frame

func _press_pause_button() -> void:
	await _press_joypad_button(JOY_BUTTON_START)

func _action_has_button(
	action_name: StringName,
	device_id: int,
	button_index: int
) -> bool:
	for event in InputMap.action_get_events(action_name):
		if event is InputEventJoypadButton:
			var button_event := event as InputEventJoypadButton
			if (
				button_event.device == device_id
				and button_event.button_index == button_index
			):
				return true
	return false

func _read_temp_save() -> Dictionary:
	var file := FileAccess.open(TEMP_SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed as Dictionary if parsed is Dictionary else {}

func _remove_temp_save() -> void:
	for suffix in ["", ".tmp", ".bak"]:
		var path: String = TEMP_SAVE_PATH + str(suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	paused = false
	_remove_temp_save()
	if failures.is_empty():
		print("PAUSE_SETTINGS_SMOKE_TEST: PASS")
		quit(0)
		return
	print("PAUSE_SETTINGS_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
