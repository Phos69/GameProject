extends Resource
class_name DropEntry

@export var drop_type: StringName = &"experience"
@export_range(0.0, 1.0, 0.01) var chance: float = 1.0
@export_range(0, 9999) var min_amount: int = 1
@export_range(0, 9999) var max_amount: int = 1
@export var weapon_data: WeaponData

func create_drop_data(rng: RandomNumberGenerator) -> Dictionary:
	var minimum := mini(min_amount, max_amount)
	var maximum := maxi(min_amount, max_amount)
	var drop_data: Dictionary = {
		"type": drop_type,
		"amount": rng.randi_range(minimum, maximum)
	}
	if weapon_data != null:
		drop_data["weapon_data"] = weapon_data
		drop_data["weapon_id"] = weapon_data.weapon_id
	return drop_data
