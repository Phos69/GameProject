extends Node
class_name TowerDefenseManager

signal base_health_changed(current_health: int, max_health: int)
signal base_destroyed()
signal tower_build_requested(build_slot_id: StringName)
signal tower_built(build_slot_id: StringName, tower: Node)
signal tower_build_failed(build_slot_id: StringName, reason: StringName)
signal tower_upgraded(build_slot_id: StringName, tower: Node, new_level: int)
signal tower_upgrade_failed(build_slot_id: StringName, reason: StringName)
signal credits_changed(credits: int)

@export var base_max_health: int = 250

var base_health: int = 250
var credits: int = 0

func _ready() -> void:
	add_to_group("tower_defense_manager")
	base_health = base_max_health

func reset_run(starting_credits: int) -> void:
	base_health = base_max_health
	credits = maxi(starting_credits, 0)
	base_health_changed.emit(base_health, base_max_health)
	credits_changed.emit(credits)

func damage_base(amount: int) -> void:
	if amount <= 0 or base_health <= 0:
		return
	base_health = maxi(base_health - amount, 0)
	base_health_changed.emit(base_health, base_max_health)
	if base_health == 0:
		base_destroyed.emit()

func request_tower_build(build_slot_id: StringName) -> void:
	tower_build_requested.emit(build_slot_id)

func add_credits(amount: int) -> void:
	if amount <= 0:
		return
	credits += amount
	credits_changed.emit(credits)

func spend_credits(amount: int) -> bool:
	if amount <= 0 or credits < amount:
		return false
	credits -= amount
	credits_changed.emit(credits)
	return true

func try_build_tower(build_slot: TowerBuildSlot, tower_parent: Node) -> Node:
	if build_slot == null or not build_slot.can_build():
		var invalid_slot_id := build_slot.slot_id if build_slot != null else &"unknown"
		tower_build_failed.emit(invalid_slot_id, &"unavailable")
		return null
	request_tower_build(build_slot.slot_id)
	if not spend_credits(build_slot.tower_cost):
		tower_build_failed.emit(build_slot.slot_id, &"insufficient_credits")
		return null
	var tower := build_slot.build_tower(tower_parent)
	if tower == null:
		add_credits(build_slot.tower_cost)
		tower_build_failed.emit(build_slot.slot_id, &"spawn_failed")
		return null
	tower_built.emit(build_slot.slot_id, tower)
	return tower

## Upgrade TD-001: speculare a try_build_tower — stesso flusso crediti con
## rimborso se l'effetto non si applica, e feedback via segnali dedicati.
func try_upgrade_tower(build_slot: TowerBuildSlot) -> bool:
	if build_slot == null or not build_slot.can_upgrade_tower():
		var invalid_slot_id := build_slot.slot_id if build_slot != null else &"unknown"
		tower_upgrade_failed.emit(invalid_slot_id, &"unavailable")
		return false
	var tower := build_slot.get_built_tower() as DefenseTower
	if tower == null:
		tower_upgrade_failed.emit(build_slot.slot_id, &"unavailable")
		return false
	var upgrade_cost := tower.get_upgrade_cost()
	if not spend_credits(upgrade_cost):
		tower_upgrade_failed.emit(build_slot.slot_id, &"insufficient_credits")
		return false
	if not tower.upgrade():
		add_credits(upgrade_cost)
		tower_upgrade_failed.emit(build_slot.slot_id, &"upgrade_failed")
		return false
	build_slot.refresh_prompt()
	tower_upgraded.emit(build_slot.slot_id, tower, tower.tower_level)
	return true
