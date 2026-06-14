extends Node
class_name TowerDefenseManager

signal base_health_changed(current_health: int, max_health: int)
signal base_destroyed()
signal tower_build_requested(build_slot_id: StringName)

@export var base_max_health: int = 250

var base_health: int = 250

func _ready() -> void:
	add_to_group("tower_defense_manager")
	base_health = base_max_health

func damage_base(amount: int) -> void:
	if amount <= 0:
		return
	base_health = maxi(base_health - amount, 0)
	base_health_changed.emit(base_health, base_max_health)
	if base_health == 0:
		base_destroyed.emit()

func request_tower_build(build_slot_id: StringName) -> void:
	tower_build_requested.emit(build_slot_id)

