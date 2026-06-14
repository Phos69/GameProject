extends Node
class_name HealthSystem

signal damage_requested(target: Node, amount: int)
signal heal_requested(target: Node, amount: int)

func _ready() -> void:
	add_to_group("health_system")

func apply_damage(target: Node, amount: int) -> int:
	damage_requested.emit(target, amount)
	if target == null:
		return 0
	var health_component := _find_health_component(target)
	if health_component != null:
		return health_component.apply_damage(amount)
	return 0

func heal(target: Node, amount: int) -> int:
	heal_requested.emit(target, amount)
	if target == null:
		return 0
	var health_component := _find_health_component(target)
	if health_component != null:
		return health_component.heal(amount)
	return 0

func _find_health_component(target: Node) -> HealthComponent:
	if target.has_node("HealthComponent"):
		return target.get_node("HealthComponent") as HealthComponent
	return null
