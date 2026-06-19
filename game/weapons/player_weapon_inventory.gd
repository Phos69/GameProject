extends RefCounted
class_name PlayerWeaponInventory

var instances: Array[WeaponInstance] = []
var selected_index: int = -1
var base_weapon_id: StringName = &""

func set_base_weapon(definition: WeaponData) -> WeaponInstance:
	if definition == null:
		return null
	var existing := get_instance(definition.weapon_id)
	if existing != null:
		base_weapon_id = definition.weapon_id
		selected_index = instances.find(existing)
		return existing
	var instance := WeaponInstance.new(definition)
	instances.push_front(instance)
	base_weapon_id = definition.weapon_id
	selected_index = 0
	return instance

func replace_base_weapon(definition: WeaponData) -> WeaponInstance:
	if definition == null:
		return null
	if not base_weapon_id.is_empty():
		var old_base := get_instance(base_weapon_id)
		if old_base != null:
			instances.erase(old_base)
	base_weapon_id = &""
	selected_index = clampi(selected_index, -1, instances.size() - 1)
	return set_base_weapon(definition)

func add_weapon(definition: WeaponData, select_new: bool = true) -> WeaponInstance:
	if definition == null or has_weapon(definition.weapon_id):
		return null
	var instance := WeaponInstance.new(definition)
	instances.append(instance)
	if selected_index < 0 or select_new:
		selected_index = instances.size() - 1
	return instance

func has_weapon(weapon_id: StringName) -> bool:
	return get_instance(weapon_id) != null

func get_instance(weapon_id: StringName) -> WeaponInstance:
	for instance in instances:
		if instance != null and instance.get_weapon_id() == weapon_id:
			return instance
	return null

func get_selected() -> WeaponInstance:
	if selected_index < 0 or selected_index >= instances.size():
		return null
	return instances[selected_index]

func select_weapon(weapon_id: StringName) -> WeaponInstance:
	for index in range(instances.size()):
		if instances[index].get_weapon_id() == weapon_id:
			selected_index = index
			return instances[index]
	return null

func cycle(direction: int) -> WeaponInstance:
	if instances.is_empty():
		selected_index = -1
		return null
	selected_index = posmod(selected_index + (1 if direction >= 0 else -1), instances.size())
	return instances[selected_index]

func get_weapon_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for instance in instances:
		ids.append(instance.get_weapon_id())
	return ids

func get_display_names() -> PackedStringArray:
	var names := PackedStringArray()
	for instance in instances:
		names.append(instance.definition.display_name)
	return names
