extends Node
class_name MenuNavigationController

const AXIS_THRESHOLD: float = 0.55
const INPUT_COOLDOWN: float = 0.18

var owner_control: Control
var active: bool = true
var wrap_navigation: bool = true
var focus_controls: Array[Control] = []
var back_callback: Callable = Callable()
var previous_tab_callback: Callable = Callable()
var next_tab_callback: Callable = Callable()
var input_blocked_callback: Callable = Callable()

var _cooldown: float = 0.0
var _held_axis_by_device: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)

func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown = maxf(_cooldown - delta, 0.0)
	if not _can_navigate() or _cooldown > 0.0:
		return
	var direction := _dominant_held_direction()
	if direction != Vector2i.ZERO and _move_focus(direction):
		_cooldown = INPUT_COOLDOWN

func _input(event: InputEvent) -> void:
	if not _can_navigate():
		return
	if _is_back_event(event):
		if _invoke_callback(back_callback):
			get_viewport().set_input_as_handled()
			_cooldown = INPUT_COOLDOWN
		return
	if _is_tab_previous_event(event):
		if _invoke_callback(previous_tab_callback):
			get_viewport().set_input_as_handled()
			_cooldown = INPUT_COOLDOWN
		return
	if _is_tab_next_event(event):
		if _invoke_callback(next_tab_callback):
			get_viewport().set_input_as_handled()
			_cooldown = INPUT_COOLDOWN
		return
	var direction := _direction_from_event(event)
	if direction == Vector2i.ZERO or _cooldown > 0.0:
		return
	if _move_focus(direction):
		get_viewport().set_input_as_handled()
		_cooldown = INPUT_COOLDOWN

func set_focus_controls(next_controls: Array) -> void:
	focus_controls.clear()
	for control in next_controls:
		if control != null:
			focus_controls.append(control)

func ensure_focus(preferred: Control = null) -> void:
	if not _can_navigate():
		return
	var controls := _available_focus_controls()
	if controls.is_empty():
		return
	var current := get_viewport().gui_get_focus_owner()
	if current != null and controls.has(current):
		return
	if preferred != null and _is_focusable(preferred):
		preferred.grab_focus()
		return
	controls[0].grab_focus()

func _can_navigate() -> bool:
	if not active:
		return false
	if owner_control != null and not owner_control.is_visible_in_tree():
		return false
	if input_blocked_callback.is_valid() and bool(input_blocked_callback.call()):
		return false
	return true

func _direction_from_event(event: InputEvent) -> Vector2i:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return Vector2i.ZERO
		match key_event.keycode:
			KEY_DOWN, KEY_RIGHT:
				return Vector2i.RIGHT
			KEY_UP, KEY_LEFT:
				return Vector2i.LEFT
	if event is InputEventJoypadButton:
		var button_event := event as InputEventJoypadButton
		if not button_event.pressed:
			return Vector2i.ZERO
		match button_event.button_index:
			JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_RIGHT:
				return Vector2i.RIGHT
			JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_LEFT:
				return Vector2i.LEFT
	if event is InputEventJoypadMotion:
		return _direction_from_motion(event as InputEventJoypadMotion)
	if event.is_action_pressed(&"ui_down") or event.is_action_pressed(&"ui_right"):
		return Vector2i.RIGHT
	if event.is_action_pressed(&"ui_up") or event.is_action_pressed(&"ui_left"):
		return Vector2i.LEFT
	return Vector2i.ZERO

func _direction_from_motion(event: InputEventJoypadMotion) -> Vector2i:
	if event.axis != JOY_AXIS_LEFT_X and event.axis != JOY_AXIS_LEFT_Y:
		return Vector2i.ZERO
	var state: Vector2 = _held_axis_by_device.get(event.device, Vector2.ZERO)
	if event.axis == JOY_AXIS_LEFT_X:
		state.x = event.axis_value if absf(event.axis_value) >= AXIS_THRESHOLD else 0.0
	else:
		state.y = event.axis_value if absf(event.axis_value) >= AXIS_THRESHOLD else 0.0
	_held_axis_by_device[event.device] = state
	if absf(state.x) > absf(state.y):
		return Vector2i.RIGHT if state.x > 0.0 else Vector2i.LEFT
	if absf(state.y) > 0.0:
		return Vector2i.RIGHT if state.y > 0.0 else Vector2i.LEFT
	return Vector2i.ZERO

func _dominant_held_direction() -> Vector2i:
	for device_id in _held_axis_by_device.keys():
		var state: Vector2 = _held_axis_by_device[device_id]
		if absf(state.x) < AXIS_THRESHOLD and absf(state.y) < AXIS_THRESHOLD:
			continue
		if absf(state.x) > absf(state.y):
			return Vector2i.RIGHT if state.x > 0.0 else Vector2i.LEFT
		return Vector2i.RIGHT if state.y > 0.0 else Vector2i.LEFT
	return Vector2i.ZERO

func _move_focus(direction: Vector2i) -> bool:
	var controls := _available_focus_controls()
	if controls.is_empty():
		return false
	var step := 1 if direction.x >= 0 else -1
	var current := get_viewport().gui_get_focus_owner()
	var current_index := controls.find(current)
	var next_index := 0
	if current_index < 0:
		next_index = 0 if step > 0 else controls.size() - 1
	else:
		next_index = current_index + step
		if wrap_navigation:
			next_index = posmod(next_index, controls.size())
		else:
			next_index = clampi(next_index, 0, controls.size() - 1)
	var next_control := controls[next_index]
	if next_control == null:
		return false
	next_control.grab_focus()
	return true

func _available_focus_controls() -> Array[Control]:
	var controls: Array[Control] = []
	for control in focus_controls:
		if _is_focusable(control):
			controls.append(control)
	return controls

func _is_focusable(control: Control) -> bool:
	if control == null:
		return false
	if not control.is_inside_tree() or not control.is_visible_in_tree():
		return false
	if control.focus_mode == Control.FOCUS_NONE:
		return false
	if control is BaseButton and (control as BaseButton).disabled:
		return false
	if control is Slider and not (control as Slider).editable:
		return false
	return true

func _is_back_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.echo:
			return false
	if event.is_action_pressed(&"ui_cancel"):
		return true
	if event is InputEventJoypadButton:
		var button_event := event as InputEventJoypadButton
		return (
			button_event.pressed
			and button_event.button_index == JOY_BUTTON_BACK
		)
	return false

func _is_tab_previous_event(event: InputEvent) -> bool:
	if not event is InputEventJoypadButton:
		return false
	var button_event := event as InputEventJoypadButton
	return (
		button_event.pressed
		and button_event.button_index == JOY_BUTTON_LEFT_SHOULDER
	)

func _is_tab_next_event(event: InputEvent) -> bool:
	if not event is InputEventJoypadButton:
		return false
	var button_event := event as InputEventJoypadButton
	return (
		button_event.pressed
		and button_event.button_index == JOY_BUTTON_RIGHT_SHOULDER
	)

func _invoke_callback(callback: Callable) -> bool:
	if not callback.is_valid():
		return false
	var result: Variant = callback.call()
	return bool(result) if result is bool else true
