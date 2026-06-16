extends Node
class_name LocalMultiplayerManager

signal active_slots_changed(active_slots: Array[int])
signal slot_activated(player_slot: int)
signal slot_deactivated(player_slot: int)
signal multiplayer_controls_changed(settings: Dictionary)

@export var max_players: int = 4
@export var join_button: int = JOY_BUTTON_START
@export var leave_button: int = JOY_BUTTON_BACK

var active_slots: Array[int] = [1]

const DEFAULT_JOIN_BUTTON: int = JOY_BUTTON_START
const DEFAULT_LEAVE_BUTTON: int = JOY_BUTTON_BACK
const JOYSTICK_CONTROL_ORDER: Array[StringName] = [
	&"join",
	&"leave"
]
const JOYSTICK_CONTROL_LABELS: Dictionary = {
	&"join": "Join slot",
	&"leave": "Leave slot"
}

const DEBUG_SLOT_KEYS := {
	KEY_F2: 2,
	KEY_F3: 3,
	KEY_F4: 4
}

func _enter_tree() -> void:
	add_to_group("local_multiplayer_manager")

func _ready() -> void:
	active_slots_changed.emit(active_slots)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		_handle_joypad_button(event as InputEventJoypadButton)
	elif event is InputEventKey:
		_handle_keyboard_debug(event as InputEventKey)

func get_active_slots() -> Array[int]:
	var result: Array[int] = []
	for player_slot in active_slots:
		result.append(player_slot)
	return result

func activate_slot(player_slot: int) -> void:
	if player_slot < 1 or player_slot > max_players:
		return
	if active_slots.has(player_slot):
		return
	active_slots.append(player_slot)
	active_slots.sort()
	slot_activated.emit(player_slot)
	active_slots_changed.emit(active_slots)

func deactivate_slot(player_slot: int) -> void:
	if player_slot == 1:
		return
	if active_slots.has(player_slot):
		active_slots.erase(player_slot)
		slot_deactivated.emit(player_slot)
		active_slots_changed.emit(active_slots)

func get_joystick_control_specs() -> Array[Dictionary]:
	var specs: Array[Dictionary] = []
	for control_id in JOYSTICK_CONTROL_ORDER:
		specs.append({
			"id": control_id,
			"label": String(JOYSTICK_CONTROL_LABELS.get(
				control_id,
				String(control_id)
			))
		})
	return specs

func get_joystick_button_label(control_id: StringName) -> String:
	match control_id:
		&"join":
			return InputManager.joy_button_name(join_button)
		&"leave":
			return InputManager.joy_button_name(leave_button)
		_:
			return "Unassigned"

func rebind_joystick_button(
	control_id: StringName,
	event: InputEvent
) -> bool:
	if not event is InputEventJoypadButton:
		return false
	var button_event := event as InputEventJoypadButton
	if not button_event.pressed:
		return false
	match control_id:
		&"join":
			join_button = button_event.button_index
		&"leave":
			leave_button = button_event.button_index
		_:
			return false
	multiplayer_controls_changed.emit(get_settings_data())
	return true

func reset_joystick_buttons() -> void:
	join_button = DEFAULT_JOIN_BUTTON
	leave_button = DEFAULT_LEAVE_BUTTON
	multiplayer_controls_changed.emit(get_settings_data())

func get_settings_data() -> Dictionary:
	return {
		"join_button": join_button,
		"leave_button": leave_button
	}

func restore_settings_data(data: Dictionary) -> void:
	join_button = clampi(
		int(data.get("join_button", DEFAULT_JOIN_BUTTON)),
		0,
		127
	)
	leave_button = clampi(
		int(data.get("leave_button", DEFAULT_LEAVE_BUTTON)),
		0,
		127
	)
	multiplayer_controls_changed.emit(get_settings_data())

static func create_default_settings_data() -> Dictionary:
	return {
		"join_button": DEFAULT_JOIN_BUTTON,
		"leave_button": DEFAULT_LEAVE_BUTTON
	}

func _handle_joypad_button(event: InputEventJoypadButton) -> void:
	if not event.pressed:
		return

	var player_slot := event.device + 1
	if player_slot < 1 or player_slot > max_players:
		return

	if event.button_index == join_button:
		activate_slot(player_slot)
		get_viewport().set_input_as_handled()
	elif event.button_index == leave_button:
		deactivate_slot(player_slot)
		get_viewport().set_input_as_handled()

func _handle_keyboard_debug(event: InputEventKey) -> void:
	if not event.pressed or event.echo:
		return
	if not DEBUG_SLOT_KEYS.has(event.keycode):
		return

	var player_slot := int(DEBUG_SLOT_KEYS[event.keycode])
	if active_slots.has(player_slot):
		deactivate_slot(player_slot)
	else:
		activate_slot(player_slot)
	get_viewport().set_input_as_handled()
