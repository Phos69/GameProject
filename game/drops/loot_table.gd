extends Resource
class_name LootTable

@export var entries: Array[Dictionary] = [
	{"type": &"experience", "chance": 1.0, "amount": 3},
	{"type": &"money", "chance": 0.55, "amount": 1},
	{"type": &"ammo", "chance": 0.20, "amount": 6},
	{"type": &"health", "chance": 0.10, "amount": 15},
	{"type": &"weapon", "chance": 0.03, "weapon_id": &"prototype_weapon"}
]
