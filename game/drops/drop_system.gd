extends Node
class_name DropSystem

signal drops_rolled(source: Node, drops: Array[Dictionary])
signal drop_spawned(pickup: Node, drop_data: Dictionary)
signal drop_collected(drop_data: Dictionary, collector: Node)

@export var pickup_scene: PackedScene = preload("res://game/drops/drop_pickup.tscn")
@export var pickup_container_path: NodePath = NodePath("../../World/Pickups")

var rng := RandomNumberGenerator.new()
var dropped_weapon_ids_for_run: Dictionary = {}

func _ready() -> void:
	add_to_group("drop_system")
	rng.randomize()
	call_deferred("_connect_run_reset")

func roll_drops(
	source: Node,
	loot_table: LootTable,
	chance_multiplier: float = 1.0
) -> Array[Dictionary]:
	var drops: Array[Dictionary] = []
	if loot_table == null:
		drops_rolled.emit(source, drops)
		return drops

	var resolved_multiplier := maxf(chance_multiplier, 0.0)
	for entry in loot_table.entries:
		if (
			entry != null
			and rng.randf() <= minf(entry.chance * resolved_multiplier, 1.0)
		):
			var drop_data := entry.create_drop_data(rng)
			if StringName(drop_data.get("type", &"unknown")) == GameConstants.DROP_WEAPON:
				drop_data = _resolve_weapon_drop(drop_data)
			drops.append(drop_data)

	drops_rolled.emit(source, drops)
	return drops

func spawn_drops(
	source: Node,
	loot_table: LootTable,
	origin: Vector2,
	parent: Node = null,
	chance_multiplier: float = 1.0
) -> Array[Node]:
	var drops := roll_drops(source, loot_table, chance_multiplier)
	return _spawn_drop_data(drops, origin, parent)

func spawn_drops_deferred(
	source: Node,
	loot_table: LootTable,
	origin: Vector2,
	parent: Node = null,
	chance_multiplier: float = 1.0
) -> void:
	var drops := roll_drops(source, loot_table, chance_multiplier)
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
			var definition := drop_data.get("weapon_data") as WeaponData
			var weapon_system := collector.get_node_or_null("WeaponSystem") as WeaponSystem
			if weapon_system != null and definition != null and weapon_system.has_weapon(definition.weapon_id):
				var ammo_amount := maxi(definition.magazine_size, 6)
				applied = weapon_system.add_ammo_to_weapon(definition.weapon_id, ammo_amount) > 0
				if not applied:
					applied = _add_money(ammo_amount)
				if applied:
					var duplicate_feedback := drop_data.duplicate(true)
					duplicate_feedback["type"] = GameConstants.DROP_AMMO
					duplicate_feedback["amount"] = ammo_amount
					duplicate_feedback["resource_tag"] = &"duplicate_weapon_ammo"
					drop_collected.emit(duplicate_feedback, collector)
					return true
			else:
				applied = _equip_weapon(collector, definition)

	if not applied:
		return false
	drop_collected.emit(drop_data, collector)
	return true

func set_random_seed(seed: int) -> void:
	rng.seed = seed

func reset_run_weapon_registry() -> void:
	dropped_weapon_ids_for_run.clear()

func has_weapon_dropped(weapon_id: StringName) -> bool:
	return dropped_weapon_ids_for_run.has(weapon_id)

func get_remaining_catalog_weapon_ids() -> Array[StringName]:
	var remaining: Array[StringName] = []
	for weapon_id in WeaponCatalog.get_ids():
		if not dropped_weapon_ids_for_run.has(weapon_id):
			remaining.append(weapon_id)
	return remaining

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
	if amount <= 0:
		return false
	var applied_to_players := 0
	for player in PlayerQuery.alive(get_tree()):
		var weapon_system := player.get_node_or_null("WeaponSystem") as WeaponSystem
		if weapon_system != null and weapon_system.add_reserve_ammo(amount) > 0:
			applied_to_players += 1
	return applied_to_players > 0

func _heal_collector(collector: Node, amount: int) -> bool:
	var health_system = get_tree().get_first_node_in_group("health_system")
	if health_system == null:
		return false
	return health_system.heal(collector, amount) > 0

func _equip_weapon(collector: Node, weapon_data: WeaponData) -> bool:
	var weapon_system := collector.get_node_or_null("WeaponSystem") as WeaponSystem
	if weapon_system == null:
		return false
	return weapon_system.add_weapon(weapon_data, true)

func _resolve_weapon_drop(drop_data: Dictionary) -> Dictionary:
	var requested := drop_data.get("weapon_data") as WeaponData
	var use_catalog := StringName(drop_data.get("resource_tag", &"")) == &"weapon_catalog"
	if use_catalog:
		var remaining := get_remaining_catalog_weapon_ids()
		if remaining.is_empty():
			return _weapon_pool_fallback()
		requested = WeaponCatalog.get_definition(remaining[rng.randi_range(0, remaining.size() - 1)])
	if requested == null or dropped_weapon_ids_for_run.has(requested.weapon_id):
		return _weapon_pool_fallback()
	dropped_weapon_ids_for_run[requested.weapon_id] = true
	var resolved := drop_data.duplicate(true)
	resolved["weapon_data"] = requested
	resolved["weapon_id"] = requested.weapon_id
	return resolved

func _weapon_pool_fallback() -> Dictionary:
	return {
		"type": GameConstants.DROP_AMMO,
		"amount": rng.randi_range(8, 14),
		"resource_tag": &"weapon_pool_exhausted"
	}

func _connect_run_reset() -> void:
	var game_mode_manager := get_tree().get_first_node_in_group("game_mode_manager") as GameModeManager
	if game_mode_manager == null:
		return
	var callback := Callable(self, "_on_game_mode_started")
	if not game_mode_manager.game_mode_started.is_connected(callback):
		game_mode_manager.game_mode_started.connect(callback)

func _on_game_mode_started(_mode_id: StringName) -> void:
	reset_run_weapon_registry()

func _drop_offset(index: int, count: int) -> Vector2:
	if count <= 1:
		return Vector2.ZERO
	var angle := TAU * float(index) / float(count)
	return Vector2.RIGHT.rotated(angle) * 22.0
