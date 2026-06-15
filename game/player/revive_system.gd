extends Node
class_name ReviveSystem

signal revive_started(target: Node, reviver: Node)
signal revive_progressed(target: Node, reviver: Node, progress_ratio: float)
signal revive_interrupted(target: Node, reviver: Node)
signal player_revived(target: Node, reviver: Node, restored_health: int)

@export var revive_radius: float = 78.0
@export var revive_duration: float = 2.4
@export_range(0.05, 1.0, 0.05) var restored_health_ratio: float = 0.35

var progress_by_target: Dictionary = {}
var reviver_by_target: Dictionary = {}
var input_manager: InputManager

func _ready() -> void:
	add_to_group("revive_system")
	input_manager = get_tree().get_first_node_in_group(
		"input_manager"
	) as InputManager

func _physics_process(delta: float) -> void:
	_prune_progress()
	for target in get_tree().get_nodes_in_group("players"):
		var health_component := target.get_node_or_null(
			"HealthComponent"
		) as HealthComponent
		if health_component == null or not health_component.is_downed:
			continue
		var reviver := _find_active_reviver(target)
		if reviver == null:
			interrupt_revive(target)
			continue
		advance_revive(target, reviver, delta)

func advance_revive(target: Node, reviver: Node, delta: float) -> bool:
	if not _can_revive(target, reviver):
		interrupt_revive(target)
		return false
	var target_id := target.get_instance_id()
	var previous_reviver: Node = reviver_by_target.get(target_id)
	if previous_reviver != reviver:
		if previous_reviver != null:
			revive_interrupted.emit(target, previous_reviver)
		progress_by_target[target_id] = 0.0
		reviver_by_target[target_id] = reviver
		revive_started.emit(target, reviver)
	var next_progress := float(progress_by_target.get(target_id, 0.0)) + maxf(delta, 0.0)
	progress_by_target[target_id] = next_progress
	var ratio := clampf(next_progress / maxf(revive_duration, 0.01), 0.0, 1.0)
	_set_indicator_progress(target, ratio, true)
	revive_progressed.emit(target, reviver, ratio)
	if ratio < 1.0:
		return false
	return _complete_revive(target, reviver)

func interrupt_revive(target: Node) -> void:
	if target == null:
		return
	var target_id := target.get_instance_id()
	if not progress_by_target.has(target_id):
		_set_indicator_progress(target, 0.0, false)
		return
	var reviver_value: Variant = reviver_by_target.get(target_id)
	progress_by_target.erase(target_id)
	reviver_by_target.erase(target_id)
	_set_indicator_progress(target, 0.0, false)
	if is_instance_valid(reviver_value):
		revive_interrupted.emit(target, reviver_value as Node)

func get_revive_progress(target: Node) -> float:
	if target == null:
		return 0.0
	return clampf(
		float(progress_by_target.get(target.get_instance_id(), 0.0))
		/ maxf(revive_duration, 0.01),
		0.0,
		1.0
	)

func _find_active_reviver(target: Node) -> Node:
	if not target is Node2D:
		return null
	if input_manager == null:
		input_manager = get_tree().get_first_node_in_group(
			"input_manager"
		) as InputManager
	if input_manager == null:
		return null
	var nearest: Node
	var nearest_distance := revive_radius
	for candidate in get_tree().get_nodes_in_group("players"):
		if candidate == target or not candidate is Node2D:
			continue
		var health_component := candidate.get_node_or_null(
			"HealthComponent"
		) as HealthComponent
		if health_component == null or not health_component.is_alive():
			continue
		var distance := (target as Node2D).global_position.distance_to(
			(candidate as Node2D).global_position
		)
		if distance > nearest_distance:
			continue
		var player_slot := int(candidate.get("player_slot"))
		if not input_manager.is_player_interact_pressed(player_slot):
			continue
		nearest = candidate
		nearest_distance = distance
	return nearest

func _can_revive(target: Node, reviver: Node) -> bool:
	if (
		target == null
		or reviver == null
		or target == reviver
		or not target is Node2D
		or not reviver is Node2D
	):
		return false
	var target_health := target.get_node_or_null(
		"HealthComponent"
	) as HealthComponent
	var reviver_health := reviver.get_node_or_null(
		"HealthComponent"
	) as HealthComponent
	if (
		target_health == null
		or not target_health.is_downed
		or reviver_health == null
		or not reviver_health.is_alive()
	):
		return false
	return (target as Node2D).global_position.distance_to(
		(reviver as Node2D).global_position
	) <= revive_radius

func _complete_revive(target: Node, reviver: Node) -> bool:
	var health_component := target.get_node_or_null(
		"HealthComponent"
	) as HealthComponent
	if health_component == null:
		interrupt_revive(target)
		return false
	var restored_health := maxi(
		1,
		roundi(float(health_component.max_health) * restored_health_ratio)
	)
	if not health_component.revive(restored_health):
		interrupt_revive(target)
		return false
	var target_id := target.get_instance_id()
	progress_by_target.erase(target_id)
	reviver_by_target.erase(target_id)
	_set_indicator_progress(target, 0.0, false)
	player_revived.emit(target, reviver, health_component.current_health)
	return true

func _set_indicator_progress(target: Node, ratio: float, active: bool) -> void:
	if target != null and target.has_method("set_revive_progress"):
		target.set_revive_progress(ratio, active)

func _prune_progress() -> void:
	var valid_target_ids: Dictionary = {}
	for player in get_tree().get_nodes_in_group("players"):
		valid_target_ids[player.get_instance_id()] = true
	for target_id in progress_by_target.keys():
		if not valid_target_ids.has(target_id):
			progress_by_target.erase(target_id)
			reviver_by_target.erase(target_id)
