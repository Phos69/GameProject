extends Node
class_name InputManager

const MAX_PLAYERS: int = 4

func _enter_tree() -> void:
	add_to_group("input_manager")
	_register_default_actions()

func get_player_move_vector(player_slot: int) -> Vector2:
	return Input.get_vector(
		_action(player_slot, "move_left"),
		_action(player_slot, "move_right"),
		_action(player_slot, "move_up"),
		_action(player_slot, "move_down")
	)

func get_player_aim_vector(player_slot: int) -> Vector2:
	return Input.get_vector(
		_action(player_slot, "aim_left"),
		_action(player_slot, "aim_right"),
		_action(player_slot, "aim_up"),
		_action(player_slot, "aim_down")
	)

func is_player_fire_pressed(player_slot: int) -> bool:
	return Input.is_action_pressed(_action(player_slot, "fire"))

func is_player_reload_just_pressed(player_slot: int) -> bool:
	return Input.is_action_just_pressed(_action(player_slot, "reload"))

func is_player_interact_just_pressed(player_slot: int) -> bool:
	return Input.is_action_just_pressed(_action(player_slot, "interact"))

func _register_default_actions() -> void:
	for player_slot in range(1, MAX_PLAYERS + 1):
		_register_player_actions(player_slot)

func _register_player_actions(player_slot: int) -> void:
	_ensure_action(_action(player_slot, "move_left"), _joy_motion(player_slot, JOY_AXIS_LEFT_X, -1.0))
	_ensure_action(_action(player_slot, "move_right"), _joy_motion(player_slot, JOY_AXIS_LEFT_X, 1.0))
	_ensure_action(_action(player_slot, "move_up"), _joy_motion(player_slot, JOY_AXIS_LEFT_Y, -1.0))
	_ensure_action(_action(player_slot, "move_down"), _joy_motion(player_slot, JOY_AXIS_LEFT_Y, 1.0))
	_ensure_action(_action(player_slot, "aim_left"), _joy_motion(player_slot, JOY_AXIS_RIGHT_X, -1.0))
	_ensure_action(_action(player_slot, "aim_right"), _joy_motion(player_slot, JOY_AXIS_RIGHT_X, 1.0))
	_ensure_action(_action(player_slot, "aim_up"), _joy_motion(player_slot, JOY_AXIS_RIGHT_Y, -1.0))
	_ensure_action(_action(player_slot, "aim_down"), _joy_motion(player_slot, JOY_AXIS_RIGHT_Y, 1.0))
	_ensure_action(_action(player_slot, "fire"), _joy_button(player_slot, JOY_BUTTON_RIGHT_SHOULDER))
	InputMap.action_add_event(_action(player_slot, "fire"), _joy_motion(player_slot, JOY_AXIS_TRIGGER_RIGHT, 1.0))
	_ensure_action(_action(player_slot, "reload"), _joy_button(player_slot, JOY_BUTTON_X))
	_ensure_action(_action(player_slot, "interact"), _joy_button(player_slot, JOY_BUTTON_A))

	if player_slot == 1:
		_add_keyboard_debug_actions()

func _add_keyboard_debug_actions() -> void:
	InputMap.action_add_event(_action(1, "move_left"), _key(KEY_A))
	InputMap.action_add_event(_action(1, "move_right"), _key(KEY_D))
	InputMap.action_add_event(_action(1, "move_up"), _key(KEY_W))
	InputMap.action_add_event(_action(1, "move_down"), _key(KEY_S))
	InputMap.action_add_event(_action(1, "aim_left"), _key(KEY_LEFT))
	InputMap.action_add_event(_action(1, "aim_right"), _key(KEY_RIGHT))
	InputMap.action_add_event(_action(1, "aim_up"), _key(KEY_UP))
	InputMap.action_add_event(_action(1, "aim_down"), _key(KEY_DOWN))
	InputMap.action_add_event(_action(1, "fire"), _key(KEY_SPACE))
	InputMap.action_add_event(_action(1, "reload"), _key(KEY_R))
	InputMap.action_add_event(_action(1, "interact"), _key(KEY_E))

func _ensure_action(action: StringName, first_event: InputEvent) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.20)
		InputMap.action_add_event(action, first_event)

func _action(player_slot: int, suffix: String) -> StringName:
	return StringName("p%d_%s" % [player_slot, suffix])

func _joy_motion(player_slot: int, axis: int, axis_value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.device = player_slot - 1
	event.axis = axis
	event.axis_value = axis_value
	return event

func _joy_button(player_slot: int, button_index: int) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.device = player_slot - 1
	event.button_index = button_index
	return event

func _key(physical_keycode: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = physical_keycode
	event.physical_keycode = physical_keycode
	return event
