extends Node
class_name DropSystem

signal drops_rolled(source: Node, drops: Array[Dictionary])
signal drop_spawned(pickup: Node, drop_data: Dictionary)
signal drop_collected(drop_data: Dictionary, collector: Node)

@export var pickup_scene: PackedScene = preload("res://game/drops/drop_pickup.tscn")
@export var pickup_container_path: NodePath = NodePath("../../World/Pickups")

var rng := RandomNumberGenerator.new()

func _ready() -> void:
	add_to_group("drop_system")
	rng.randomize()

func roll_drops(source: Node, loot_table: LootTable) -> Array[Dictionary]:
	var drops: Array[Dictionary] = []
	if loot_table == null:
		drops_rolled.emit(source, drops)
		return drops

	for entry in loot_table.entries:
		if entry != null and rng.randf() <= entry.chance:
			drops.append(entry.create_drop_data(rng))

	drops_rolled.emit(source, drops)
	return drops

func spawn_drops(
	source: Node,
	loot_table: LootTable,
	origin: Vector2,
	parent: Node = null
) -> Array[Node]:
	var drops := roll_drops(source, loot_table)
	return _spawn_drop_data(drops, origin, parent)

func spawn_drops_deferred(
	source: Node,
	loot_table: LootTable,
	origin: Vector2,
	parent: Node = null
) -> void:
	var drops := roll_drops(source, loot_table)
	call_deferred("_spawn_drop_data", drops, origin, parent)

func _spawn_drop_data(
	drops: Array[Dictionary],
	origin: Vector2,
	parent: Node = null
) -> Array[Node]:
	var pickups: Array[Node] = []
	if pickup_scene == null:
		return pickups

	var target_parent := parent
	if target_parent == null:
		target_parent = get_node_or_null(pickup_container_path)
	if target_parent == null:
		target_parent = get_tree().current_scene

	for index in range(drops.size()):
		var pickup := pickup_scene.instantiate()
		if pickup.has_method("setup"):
			pickup.setup(drops[index])
		if pickup is Node2D:
			(pickup as Node2D).global_position = origin + _drop_offset(index, drops.size())
		target_parent.add_child(pickup)
		pickups.append(pickup)
		drop_spawned.emit(pickup, drops[index])
	return pickups

func collect_drop(drop_data: Dictionary, collector: Node) -> bool:
	if collector == null:
		return false

	var applied := false
	var drop_type := StringName(drop_data.get("type", &"unknown"))
	var amount := int(drop_data.get("amount", 0))
	match drop_type:
		GameConstants.DROP_EXPERIENCE:
			applied = _add_experience(amount)
		GameConstants.DROP_MONEY:
			applied = _add_money(amount)
		GameConstants.DROP_AMMO:
			applied = _add_ammo(collector, amount)
		GameConstants.DROP_HEALTH:
			applied = _heal_collector(collector, amount)
		GameConstants.DROP_WEAPON:
			applied = _equip_weapon(collector, drop_data.get("weapon_data") as WeaponData)

	if not applied:
		return false
	drop_collected.emit(drop_data, collector)
	return true

func set_random_seed(seed: int) -> void:
	rng.seed = seed

func _add_experience(amount: int) -> bool:
	var progression = get_tree().get_first_node_in_group("progression_manager")
	if progression == null or amount <= 0:
		return false
	progression.add_experience(amount)
	return true

func _add_money(amount: int) -> bool:
	var progression = get_tree().get_first_node_in_group("progression_manager")
	if progression == null or amount <= 0:
		return false
	progression.add_money(amount)
	return true

func _add_ammo(collector: Node, amount: int) -> bool:
	var weapon_system := collector.get_node_or_null("WeaponSystem") as WeaponSystem
	if weapon_system == null:
		return false
	return weapon_system.add_reserve_ammo(amount) > 0

func _heal_collector(collector: Node, amount: int) -> bool:
	var health_system = get_tree().get_first_node_in_group("health_system")
	if health_system == null:
		return false
	return health_system.heal(collector, amount) > 0

func _equip_weapon(collector: Node, weapon_data: WeaponData) -> bool:
	var weapon_system := collector.get_node_or_null("WeaponSystem") as WeaponSystem
	if weapon_system == null:
		return false
	return weapon_system.equip_weapon(weapon_data)

func _drop_offset(index: int, count: int) -> Vector2:
	if count <= 1:
		return Vector2.ZERO
	var angle := TAU * float(index) / float(count)
	return Vector2.RIGHT.rotated(angle) * 22.0
