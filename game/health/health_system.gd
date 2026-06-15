extends Node
class_name HealthSystem

signal damage_requested(target: Node, amount: int)
signal heal_requested(target: Node, amount: int)

func _ready() -> void:
	add_to_group("health_system")

func apply_damage(
	target: Node,
	amount: int,
	source: Node = null,
	source_id: StringName = &"",
	hit_position: Vector2 = Vector2.ZERO
) -> int:
	var resolved_amount := _resolve_damage(
		target,
		amount,
		source,
		source_id,
		hit_position
	)
	damage_requested.emit(target, resolved_amount)
	if target == null:
		return 0
	var health_component := _find_health_component(target)
	if health_component != null:
		return health_component.apply_damage(resolved_amount)
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

func _resolve_damage(
	target: Node,
	amount: int,
	source: Node,
	source_id: StringName,
	hit_position: Vector2
) -> int:
	var resolved_amount := maxi(amount, 0)
	var source_rpg := _find_rpg_component(source)
	if source_rpg != null:
		resolved_amount = source_rpg.resolve_outgoing_damage(
			resolved_amount,
			target,
			hit_position,
			source_id
		)
	var target_rpg := _find_rpg_component(target)
	if target_rpg != null and source != null:
		resolved_amount = target_rpg.resolve_incoming_damage(
			resolved_amount,
			source
		)
	return resolved_amount

func _find_rpg_component(node: Node) -> RpgPlayerComponent:
	if node != null and node.has_node("RpgPlayerComponent"):
		return node.get_node("RpgPlayerComponent") as RpgPlayerComponent
	return null
