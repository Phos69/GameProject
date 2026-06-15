extends Node
class_name HazardSystem

signal hazard_rules_configured(biome_id: StringName)

var active_biome
var is_active: bool = false

func _ready() -> void:
	add_to_group("hazard_system")

func start_run(biome) -> void:
	active_biome = biome
	is_active = true
	hazard_rules_configured.emit(
		StringName(active_biome.get("biome_id")) if active_biome != null else &""
	)

func stop_run() -> void:
	is_active = false
	active_biome = null

func is_position_hazardous(position: Vector2) -> bool:
	for hazard in get_tree().get_nodes_in_group("fall_zones"):
		if _node_contains_position(hazard, position):
			return true
	for hazard in get_tree().get_nodes_in_group("environment_hazards"):
		if _node_contains_position(hazard, position):
			return true
	return false

func _node_contains_position(node: Node, position: Vector2) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	if node.has_method("contains_global_position"):
		return bool(node.contains_global_position(position))
	if node is Node2D:
		var radius := float(node.get_meta("zone_radius", 32.0))
		return (node as Node2D).global_position.distance_squared_to(position) <= radius * radius
	if node is Area2D and node is Node2D:
		return (node as Node2D).global_position.distance_squared_to(position) <= 32.0 * 32.0
	return false
