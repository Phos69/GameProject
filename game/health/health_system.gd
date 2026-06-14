extends Node
class_name HealthSystem

signal damage_requested(target: Node, amount: int)
signal heal_requested(target: Node, amount: int)

func _ready() -> void:
	add_to_group("health_system")

func apply_damage(target: Node, amount: int) -> void:
	damage_requested.emit(target, amount)
	if target == null:
		return
	var health_component := _find_health_component(target)
	if health_component != null and health_component.has_method("apply_damage"):
		health_component.apply_damage(amount)

func heal(target: Node, amount: int) -> void:
	heal_requested.emit(target, amount)
	if target == null:
		return
	var health_component := _find_health_component(target)
	if health_component != null and health_component.has_method("heal"):
		health_component.heal(amount)

func _find_health_component(target: Node) -> Node:
	if target.has_node("HealthComponent"):
		return target.get_node("HealthComponent")
	return null

