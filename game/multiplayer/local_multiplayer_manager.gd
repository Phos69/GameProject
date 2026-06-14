extends Node
class_name LocalMultiplayerManager

signal active_slots_changed(active_slots: Array[int])
signal slot_activated(player_slot: int)
signal slot_deactivated(player_slot: int)

@export var max_players: int = 4
@export var join_button: int = JOY_BUTTON_START
@export var leave_button: int = JOY_BUTTON_BACK

var active_slots: Array[int] = [1]

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
