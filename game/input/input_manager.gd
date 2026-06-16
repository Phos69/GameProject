extends Node
class_name InputManager

signal controls_changed(settings: Dictionary)

const MAX_PLAYERS: int = 4
const JOY_MOTION_REBIND_THRESHOLD: float = 0.65
const PLAYER_JOYSTICK_ACTIONS: Array[StringName] = [
	&"move_left",
	&"move_right",
	&"move_up",
	&"move_down",
	&"aim_left",
	&"aim_right",
	&"aim_up",
	&"aim_down",
	&"fire",
	&"reload",
	&"super",
	&"interact",
	&"dodge"
]
const ALL_JOYSTICK_ACTIONS: Array[StringName] = [
	&"move_left",
	&"move_right",
	&"move_up",
	&"move_down",
	&"aim_left",
	&"aim_right",
	&"aim_up",
	&"aim_down",
	&"fire",
	&"reload",
	&"super",
	&"interact",
	&"dodge",
	&"pause"
]
const ACTION_LABELS: Dictionary = {
	&"move_left": "Move left",
	&"move_right": "Move right",
	&"move_up": "Move up",
	&"move_down": "Move down",
	&"aim_left": "Aim left",
	&"aim_right": "Aim right",
	&"aim_up": "Aim up",
	&"aim_down": "Aim down",
	&"fire": "Fire",
	&"reload": "Reload",
	&"super": "Super",
	&"interact": "Interact",
	&"dodge": "Dodge/Roll",
	&"pause": "Pause"
}
const DEFAULT_JOYSTICK_BINDINGS: Dictionary = {
	&"move_left": {
		"type": "axis",
		"axis": JOY_AXIS_LEFT_X,
		"axis_value": -1.0
	},
	&"move_right": {
		"type": "axis",
		"axis": JOY_AXIS_LEFT_X,
		"axis_value": 1.0
	},
	&"move_up": {
		"type": "axis",
		"axis": JOY_AXIS_LEFT_Y,
		"axis_value": -1.0
	},
	&"move_down": {
		"type": "axis",
		"axis": JOY_AXIS_LEFT_Y,
		"axis_value": 1.0
	},
	&"aim_left": {
		"type": "axis",
		"axis": JOY_AXIS_RIGHT_X,
		"axis_value": -1.0
	},
	&"aim_right": {
		"type": "axis",
		"axis": JOY_AXIS_RIGHT_X,
		"axis_value": 1.0
	},
	&"aim_up": {
		"type": "axis",
		"axis": JOY_AXIS_RIGHT_Y,
		"axis_value": -1.0
	},
	&"aim_down": {
		"type": "axis",
		"axis": JOY_AXIS_RIGHT_Y,
		"axis_value": 1.0
	},
	&"fire": {
		"type": "button",
		"button_index": JOY_BUTTON_RIGHT_SHOULDER
	},
	&"reload": {
		"type": "button",
		"button_index": JOY_BUTTON_X
	},
	&"super": {
		"type": "button",
		"button_index": JOY_BUTTON_Y
	},
	&"interact": {
		"type": "button",
		"button_index": JOY_BUTTON_A
	},
	&"dodge": {
		"type": "button",
		"button_index": JOY_BUTTON_B
	},
	&"pause": {
		"type": "button",
		"button_index": JOY_BUTTON_START
	}
}

var joystick_bindings: Dictionary = DEFAULT_JOYSTICK_BINDINGS.duplicate(true)

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

func is_player_super_just_pressed(player_slot: int) -> bool:
	return Input.is_action_just_pressed(_action(player_slot, "super"))

func is_player_interact_just_pressed(player_slot: int) -> bool:
	return Input.is_action_just_pressed(_action(player_slot, "interact"))

func is_player_interact_pressed(player_slot: int) -> bool:
	return Input.is_action_pressed(_action(player_slot, "interact"))

func is_player_dodge_just_pressed(player_slot: int) -> bool:
	return Input.is_action_just_pressed(_action(player_slot, "dodge"))

func is_world_map_just_pressed() -> bool:
	return Input.is_action_just_pressed(&"world_map")

func _register_default_actions() -> void:
	_register_menu_actions()
	for player_slot in range(1, MAX_PLAYERS + 1):
		_register_player_actions(player_slot)
	_apply_all_joystick_bindings()

func _register_menu_actions() -> void:
	if not InputMap.has_action(&"ui_accept"):
		InputMap.add_action(&"ui_accept")
	var accept_event := InputEventJoypadButton.new()
	accept_event.device = -1
	accept_event.button_index = JOY_BUTTON_A
	if not InputMap.action_has_event(&"ui_accept", accept_event):
		InputMap.action_add_event(&"ui_accept", accept_event)
	if not InputMap.has_action(&"pause"):
		InputMap.add_action(&"pause", 0.20)
	var pause_key := _key(KEY_P)
	if not InputMap.action_has_event(&"pause", pause_key):
		InputMap.action_add_event(&"pause", pause_key)
	if not InputMap.has_action(&"world_map"):
		InputMap.add_action(&"world_map", 0.20)
	var map_key := _key(KEY_M)
	if not InputMap.action_has_event(&"world_map", map_key):
		InputMap.action_add_event(&"world_map", map_key)
	var map_button := InputEventJoypadButton.new()
	map_button.device = -1
	map_button.button_index = JOY_BUTTON_BACK
	if not InputMap.action_has_event(&"world_map", map_button):
		InputMap.action_add_event(&"world_map", map_button)

func _register_player_actions(player_slot: int) -> void:
	for action_id in PLAYER_JOYSTICK_ACTIONS:
		var action_name := _action(player_slot, String(action_id))
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name, 0.20)

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
	InputMap.action_add_event(_action(1, "super"), _key(KEY_Q))
	InputMap.action_add_event(_action(1, "interact"), _key(KEY_E))
	InputMap.action_add_event(_action(1, "dodge"), _key(KEY_SHIFT))
	InputMap.action_add_event(_action(1, "dodge"), _key(KEY_CTRL))

func _ensure_action(action: StringName, first_event: InputEvent) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.20)
		InputMap.action_add_event(action, first_event)

func get_joystick_action_specs() -> Array[Dictionary]:
	var specs: Array[Dictionary] = []
	for action_id in ALL_JOYSTICK_ACTIONS:
		specs.append({
			"id": action_id,
			"label": String(ACTION_LABELS.get(action_id, String(action_id)))
		})
	return specs

func get_joystick_binding_label(action_id: StringName) -> String:
	var spec := joystick_bindings.get(action_id, {}) as Dictionary
	if spec.is_empty():
		return "Unassigned"
	var label := _binding_label(spec)
	if (
		action_id == &"fire"
		and _binding_specs_equal(
			spec,
			DEFAULT_JOYSTICK_BINDINGS[&"fire"] as Dictionary
		)
	):
		label += " / Right Trigger"
	return label

func rebind_joystick_action(
	action_id: StringName,
	event: InputEvent
) -> bool:
	if not ALL_JOYSTICK_ACTIONS.has(action_id):
		return false
	var spec := _event_to_binding_spec(event)
	if spec.is_empty():
		return false
	joystick_bindings[action_id] = spec
	_apply_joystick_binding(action_id)
	controls_changed.emit(get_settings_data())
	return true

func reset_joystick_bindings() -> void:
	joystick_bindings = DEFAULT_JOYSTICK_BINDINGS.duplicate(true)
	_apply_all_joystick_bindings()
	controls_changed.emit(get_settings_data())

func get_settings_data() -> Dictionary:
	var bindings: Dictionary = {}
	for action_id in ALL_JOYSTICK_ACTIONS:
		bindings[String(action_id)] = (
			joystick_bindings.get(action_id, {}) as Dictionary
		).duplicate(true)
	return {"joystick_bindings": bindings}

func restore_settings_data(data: Dictionary) -> void:
	var restored := DEFAULT_JOYSTICK_BINDINGS.duplicate(true)
	var saved_bindings := data.get("joystick_bindings", {}) as Dictionary
	for action_key in saved_bindings:
		var action_id := StringName(str(action_key))
		if not ALL_JOYSTICK_ACTIONS.has(action_id):
			continue
		var spec := _sanitize_binding_spec(
			saved_bindings[action_key] as Dictionary,
			DEFAULT_JOYSTICK_BINDINGS[action_id] as Dictionary
		)
		restored[action_id] = spec
	joystick_bindings = restored
	_apply_all_joystick_bindings()
	controls_changed.emit(get_settings_data())

static func create_default_settings_data() -> Dictionary:
	var bindings: Dictionary = {}
	for action_id in ALL_JOYSTICK_ACTIONS:
		bindings[String(action_id)] = (
			DEFAULT_JOYSTICK_BINDINGS[action_id] as Dictionary
		).duplicate(true)
	return {"joystick_bindings": bindings}

static func joy_button_name(button_index: int) -> String:
	match button_index:
		JOY_BUTTON_A:
			return "A"
		JOY_BUTTON_B:
			return "B"
		JOY_BUTTON_X:
			return "X"
		JOY_BUTTON_Y:
			return "Y"
		JOY_BUTTON_LEFT_SHOULDER:
			return "Left Shoulder"
		JOY_BUTTON_RIGHT_SHOULDER:
			return "Right Shoulder"
		JOY_BUTTON_BACK:
			return "Back"
		JOY_BUTTON_START:
			return "Start"
		JOY_BUTTON_LEFT_STICK:
			return "Left Stick Press"
		JOY_BUTTON_RIGHT_STICK:
			return "Right Stick Press"
		JOY_BUTTON_DPAD_UP:
			return "D-pad Up"
		JOY_BUTTON_DPAD_DOWN:
			return "D-pad Down"
		JOY_BUTTON_DPAD_LEFT:
			return "D-pad Left"
		JOY_BUTTON_DPAD_RIGHT:
			return "D-pad Right"
		_:
			return "Button %d" % button_index

static func joy_axis_name(axis: int, axis_value: float) -> String:
	var direction := "+" if axis_value >= 0.0 else "-"
	match axis:
		JOY_AXIS_LEFT_X:
			return "Left Stick Right" if axis_value >= 0.0 else "Left Stick Left"
		JOY_AXIS_LEFT_Y:
			return "Left Stick Down" if axis_value >= 0.0 else "Left Stick Up"
		JOY_AXIS_RIGHT_X:
			return "Right Stick Right" if axis_value >= 0.0 else "Right Stick Left"
		JOY_AXIS_RIGHT_Y:
			return "Right Stick Down" if axis_value >= 0.0 else "Right Stick Up"
		JOY_AXIS_TRIGGER_LEFT:
			return "Left Trigger"
		JOY_AXIS_TRIGGER_RIGHT:
			return "Right Trigger"
		_:
			return "Axis %d %s" % [axis, direction]

func _apply_all_joystick_bindings() -> void:
	for action_id in ALL_JOYSTICK_ACTIONS:
		_apply_joystick_binding(action_id)

func _apply_joystick_binding(action_id: StringName) -> void:
	if action_id == &"pause":
		_apply_binding_to_action(&"pause", -1, joystick_bindings[action_id])
		return
	for player_slot in range(1, MAX_PLAYERS + 1):
		_apply_binding_to_action(
			_action(player_slot, String(action_id)),
			player_slot - 1,
			joystick_bindings[action_id]
		)

func _apply_binding_to_action(
	action_name: StringName,
	device_id: int,
	spec: Dictionary
) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name, 0.20)
	_clear_joy_events(action_name)
	var event := _binding_to_event(spec, device_id)
	if event != null:
		InputMap.action_add_event(action_name, event)
	if (
		String(action_name).ends_with("_fire")
		and _binding_specs_equal(
			spec,
			DEFAULT_JOYSTICK_BINDINGS[&"fire"] as Dictionary
		)
	):
		InputMap.action_add_event(
			action_name,
			_joy_motion_device(device_id, JOY_AXIS_TRIGGER_RIGHT, 1.0)
		)

func _clear_joy_events(action_name: StringName) -> void:
	for event in InputMap.action_get_events(action_name):
		if event is InputEventJoypadButton or event is InputEventJoypadMotion:
			InputMap.action_erase_event(action_name, event)

func _binding_to_event(spec: Dictionary, device_id: int) -> InputEvent:
	match str(spec.get("type", "")):
		"button":
			return _joy_button_device(
				device_id,
				int(spec.get("button_index", JOY_BUTTON_A))
			)
		"axis":
			return _joy_motion_device(
				device_id,
				int(spec.get("axis", JOY_AXIS_LEFT_X)),
				float(spec.get("axis_value", 1.0))
			)
		_:
			return null

func _event_to_binding_spec(event: InputEvent) -> Dictionary:
	if event is InputEventJoypadButton:
		var button_event := event as InputEventJoypadButton
		if not button_event.pressed:
			return {}
		return {
			"type": "button",
			"button_index": button_event.button_index
		}
	if event is InputEventJoypadMotion:
		var motion_event := event as InputEventJoypadMotion
		if absf(motion_event.axis_value) < JOY_MOTION_REBIND_THRESHOLD:
			return {}
		return {
			"type": "axis",
			"axis": motion_event.axis,
			"axis_value": 1.0 if motion_event.axis_value >= 0.0 else -1.0
		}
	return {}

func _sanitize_binding_spec(
	spec: Dictionary,
	fallback: Dictionary
) -> Dictionary:
	match str(spec.get("type", "")):
		"button":
			return {
				"type": "button",
				"button_index": clampi(
					int(spec.get("button_index", fallback.get("button_index", 0))),
					0,
					127
				)
			}
		"axis":
			var axis_value := float(spec.get(
				"axis_value",
				fallback.get("axis_value", 1.0)
			))
			return {
				"type": "axis",
				"axis": clampi(
					int(spec.get("axis", fallback.get("axis", 0))),
					0,
					127
				),
				"axis_value": 1.0 if axis_value >= 0.0 else -1.0
			}
		_:
			return fallback.duplicate(true)

func _binding_label(spec: Dictionary) -> String:
	match str(spec.get("type", "")):
		"button":
			return joy_button_name(int(spec.get("button_index", 0)))
		"axis":
			return joy_axis_name(
				int(spec.get("axis", 0)),
				float(spec.get("axis_value", 1.0))
			)
		_:
			return "Unassigned"

func _binding_specs_equal(left: Dictionary, right: Dictionary) -> bool:
	if str(left.get("type", "")) != str(right.get("type", "")):
		return false
	match str(left.get("type", "")):
		"button":
			return int(left.get("button_index", -1)) == int(
				right.get("button_index", -2)
			)
		"axis":
			return (
				int(left.get("axis", -1)) == int(right.get("axis", -2))
				and signf(float(left.get("axis_value", 0.0)))
					== signf(float(right.get("axis_value", 0.0)))
			)
		_:
			return false

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

func _joy_motion_device(
	device_id: int,
	axis: int,
	axis_value: float
) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.device = device_id
	event.axis = axis
	event.axis_value = axis_value
	return event

func _joy_button_device(
	device_id: int,
	button_index: int
) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.device = device_id
	event.button_index = button_index
	return event

func _key(physical_keycode: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = physical_keycode
	event.physical_keycode = physical_keycode
	return event
