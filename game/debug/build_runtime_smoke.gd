extends Node

var failures: PackedStringArray = []
var feedback_events: Array[Dictionary] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	var game_mode_manager := get_tree().get_first_node_in_group(
		"game_mode_manager"
	) as GameModeManager
	var main_menu := get_tree().get_first_node_in_group("main_menu") as MainMenu
	var survival_mode := get_tree().get_first_node_in_group(
		"survival_mode"
	) as SurvivalMode
	var audio_manager := get_tree().get_first_node_in_group(
		"audio_manager"
	) as AudioManager
	var hud := get_tree().get_first_node_in_group("hud_manager") as HUDManager

	_expect(game_mode_manager != null, "game mode manager is available")
	_expect(main_menu != null, "main menu is available")
	_expect(survival_mode != null, "survival mode is available")
	_expect(audio_manager != null, "audio manager is available")
	_expect(hud != null, "HUD manager is available")
	if (
		game_mode_manager == null
		or main_menu == null
		or survival_mode == null
		or audio_manager == null
		or hud == null
	):
		_finish()
		return

	audio_manager.ui_feedback_generated.connect(_on_ui_feedback_generated)
	_expect(main_menu.is_open(), "release build starts on the main menu")
	_expect(
		get_viewport().gui_get_focus_owner() == main_menu.continue_button,
		"Continue receives initial UI focus"
	)
	_expect(
		_action_has_joypad_event(&"ui_down"),
		"Godot UI navigation includes joypad events"
	)
	_expect(
		_action_has_joypad_button(&"ui_accept", JOY_BUTTON_A),
		"UI confirmation maps joypad A for every controller"
	)

	var focus_frames := audio_manager.play_ui_focus()
	_expect(focus_frames > 0, "focus audio writes samples to the UI buffer")
	await _press_joypad_button(JOY_BUTTON_DPAD_DOWN)
	_expect(
		get_viewport().gui_get_focus_owner() == main_menu.first_mode_button,
		"D-pad down moves focus to Infinite Arena"
	)

	# Every gameplay mode now routes through Character Select so the shared RPG
	# character system applies, Infinite Arena included.
	await _press_joypad_button(JOY_BUTTON_A)
	await get_tree().process_frame
	_expect(
		main_menu.character_select_panel != null
		and main_menu.character_select_panel.visible,
		"joypad A opens Character Select for Infinite Arena"
	)
	_expect(
		not main_menu.character_card_buttons.is_empty()
		and get_viewport().gui_get_focus_owner()
		== main_menu.character_card_buttons[0],
		"first character receives focus for Infinite Arena"
	)
	await _press_joypad_button(JOY_BUTTON_A)
	await get_tree().process_frame
	_expect(
		not main_menu.character_start_button.disabled,
		"joypad A assigns a character for Infinite Arena"
	)
	await _press_joypad_button(JOY_BUTTON_START)
	await get_tree().process_frame
	_expect(
		game_mode_manager.active_mode_id == GameConstants.MODE_INFINITE_ARENA,
		"joypad Start launches Infinite Arena with the selected roster"
	)
	_expect(survival_mode.is_running, "shared survival runtime starts for Infinite Arena")
	_expect(not main_menu.is_open(), "menu hides after Infinite Arena starts")
	_expect(hud.visible, "HUD is visible during Infinite Arena")
	_expect(
		_has_audio_feedback(&"confirm"),
		"confirmation audio writes samples to the UI buffer"
	)

	await _press_escape()
	_expect(main_menu.is_open(), "Escape returns Infinite Arena to the menu")
	_expect(not survival_mode.is_running, "returning to menu stops Infinite Arena")

	await _press_joypad_button(JOY_BUTTON_DPAD_DOWN)
	await _press_joypad_button(JOY_BUTTON_DPAD_DOWN)
	_expect(
		_focused_button_text() == "Zombie Survival",
		"D-pad reaches the separate Zombie Survival button"
	)

	await _press_joypad_button(JOY_BUTTON_A)
	await get_tree().process_frame
	_expect(
		main_menu.character_select_panel != null
		and main_menu.character_select_panel.visible,
		"joypad A opens Character Select for survival"
	)
	_expect(
		not main_menu.character_card_buttons.is_empty()
		and get_viewport().gui_get_focus_owner()
		== main_menu.character_card_buttons[0],
		"first character receives focus"
	)
	await _press_joypad_button(JOY_BUTTON_A)
	await get_tree().process_frame
	_expect(
		not main_menu.character_start_button.disabled,
		"joypad A assigns the focused character"
	)
	_expect(
		get_viewport().gui_get_focus_owner() == main_menu.character_card_buttons[0],
		"character grid keeps focus after assignment"
	)
	await _press_joypad_button(JOY_BUTTON_START)
	await get_tree().process_frame
	_expect(
		game_mode_manager.active_mode_id == GameConstants.MODE_SURVIVAL,
		"joypad Start confirms the selected roster"
	)
	_expect(survival_mode.is_running, "survival starts in the release build")
	_expect(not main_menu.is_open(), "menu hides after joypad confirmation")
	_expect(hud.visible, "HUD is visible during gameplay")

	await _press_escape()
	_expect(main_menu.is_open(), "Escape returns the release build to the menu")
	_expect(not survival_mode.is_running, "returning to menu stops survival")

	var connected_joypads := Input.get_connected_joypads()
	print("BUILD_RUNTIME_JOYPADS: ", connected_joypads.size())
	for device_id in connected_joypads:
		print(
			"BUILD_RUNTIME_JOYPAD: ",
			device_id,
			" ",
			Input.get_joy_name(device_id)
		)
	_finish()

func _press_joypad_button(button_index: JoyButton) -> void:
	var pressed := InputEventJoypadButton.new()
	pressed.device = 0
	pressed.button_index = button_index
	pressed.pressed = true
	Input.parse_input_event(pressed)
	await get_tree().process_frame
	var released := pressed.duplicate() as InputEventJoypadButton
	released.pressed = false
	Input.parse_input_event(released)
	await get_tree().process_frame

func _press_escape() -> void:
	var pressed := InputEventKey.new()
	pressed.keycode = KEY_ESCAPE
	pressed.pressed = true
	Input.parse_input_event(pressed)
	await get_tree().process_frame
	var released := pressed.duplicate() as InputEventKey
	released.pressed = false
	Input.parse_input_event(released)
	await get_tree().process_frame

func _on_ui_feedback_generated(
	feedback_type: StringName,
	frames_written: int
) -> void:
	feedback_events.append({
		"type": feedback_type,
		"frames": frames_written
	})

func _action_has_joypad_event(action: StringName) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton or event is InputEventJoypadMotion:
			return true
	return false

func _action_has_joypad_button(
	action: StringName,
	button_index: JoyButton
) -> bool:
	for event in InputMap.action_get_events(action):
		if (
			event is InputEventJoypadButton
			and (event as InputEventJoypadButton).button_index == button_index
		):
			return true
	return false

func _has_audio_feedback(feedback_type: StringName) -> bool:
	for event in feedback_events:
		if (
			StringName(event.get("type", &"")) == feedback_type
			and int(event.get("frames", 0)) > 0
		):
			return true
	return false

func _focused_button_text() -> String:
	var focused := get_viewport().gui_get_focus_owner() as Button
	return focused.text if focused != null else ""

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	var diagnostics := get_tree().get_first_node_in_group("runtime_diagnostics")
	if diagnostics != null and diagnostics.has_method("mark_clean_shutdown"):
		diagnostics.call("mark_clean_shutdown", "build_runtime_smoke")
	if failures.is_empty():
		print("BUILD_RUNTIME_SMOKE: PASS")
		get_tree().quit(0)
		return
	print("BUILD_RUNTIME_SMOKE: FAIL (%d)" % failures.size())
	get_tree().quit(1)
