extends Node
class_name HealthSystem

signal damage_requested(target: Node, amount: int)
signal heal_requested(target: Node, amount: int)

var last_damage_sources: Dictionary = {}

func _ready() -> void:
	add_to_group("health_system")

func apply_damage(
	target: Node,
	amount: int,
	source: Node = null,
	source_id: StringName = &"",
	hit_position: Vector2 = Vector2.ZERO,
	ignore_invulnerability: bool = false
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
	if source != null and resolved_amount > 0:
		last_damage_sources[target.get_instance_id()] = {
			"source": source,
			"source_id": source_id
		}
	var health_component := _find_health_component(target)
	if health_component != null:
		var applied_damage := health_component.apply_damage(
			resolved_amount,
			ignore_invulnerability
		)
		_notify_rpg_damage_applied(
			target,
			source,
			source_id,
			applied_damage
		)
		return applied_damage
	return 0

func get_last_damage_source(target: Node) -> Node:
	if target == null:
		return null
	var data: Dictionary = last_damage_sources.get(
		target.get_instance_id(),
		{}
	)
	var source: Node = data.get("source", null)
	if source != null and is_instance_valid(source):
		return source
	return null

func clear_last_damage_source(target: Node) -> void:
	if target != null:
		last_damage_sources.erase(target.get_instance_id())

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
	if (
		target != null
		and target.has_method("modify_incoming_damage")
	):
		resolved_amount = int(target.modify_incoming_damage(
			resolved_amount,
			source_id
		))
	return resolved_amount

func _find_rpg_component(node: Node) -> RpgPlayerComponent:
	if node != null and node.has_node("RpgPlayerComponent"):
		return node.get_node("RpgPlayerComponent") as RpgPlayerComponent
	return null

func _notify_rpg_damage_applied(
	target: Node,
	source: Node,
	source_id: StringName,
	applied_damage: int
) -> void:
	if applied_damage <= 0:
		return
	var source_rpg := _find_rpg_component(source)
	if source_rpg != null:
		source_rpg.notify_damage_dealt(applied_damage, target, source_id)
	var target_rpg := _find_rpg_component(target)
	if target_rpg != null and source != null:
		target_rpg.notify_damage_taken(applied_damage, source)
