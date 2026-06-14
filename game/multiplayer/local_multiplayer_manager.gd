extends Node
class_name LocalMultiplayerManager

signal active_slots_changed(active_slots: Array[int])

@export var max_players: int = 4

var active_slots: Array[int] = [1]

func _ready() -> void:
	add_to_group("local_multiplayer_manager")
	active_slots_changed.emit(active_slots)

func get_active_slots() -> Array[int]:
	return active_slots.duplicate()

func activate_slot(player_slot: int) -> void:
	if player_slot < 1 or player_slot > max_players:
		return
	if active_slots.has(player_slot):
		return
	active_slots.append(player_slot)
	active_slots.sort()
	active_slots_changed.emit(active_slots)

func deactivate_slot(player_slot: int) -> void:
	if player_slot == 1:
		return
	if active_slots.has(player_slot):
		active_slots.erase(player_slot)
		active_slots_changed.emit(active_slots)
