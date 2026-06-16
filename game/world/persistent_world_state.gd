extends RefCounted
class_name PersistentWorldState

var seed_value: int = 0
var graph_signature: String = ""
var current_region_id: StringName = &""
var party_position: Vector2 = Vector2.ZERO
var region_runtime_state: Dictionary = {}
var exploration_state := WorldExplorationState.new()

func configure(seed: int, graph: WorldGraph) -> void:
	seed_value = seed
	graph_signature = graph.get_signature() if graph != null else ""
	if graph != null:
		exploration_state.initialize_from_graph(graph)
		current_region_id = graph.start_region_id

func set_current_region(region_id: StringName, graph: WorldGraph = null) -> void:
	if region_id.is_empty():
		return
	current_region_id = region_id
	exploration_state.mark_visited(region_id)
	if graph != null:
		exploration_state.reveal_neighbors(graph, region_id)

func mark_region_cleared(region_id: StringName) -> void:
	exploration_state.mark_cleared(region_id)

func set_party_position(position: Vector2) -> void:
	party_position = position

func set_region_runtime_value(
	region_id: StringName,
	key: StringName,
	value: Variant
) -> void:
	if region_id.is_empty() or key.is_empty():
		return
	if not region_runtime_state.has(region_id):
		region_runtime_state[region_id] = {}
	(region_runtime_state[region_id] as Dictionary)[key] = value

func get_region_runtime_state(region_id: StringName) -> Dictionary:
	return (region_runtime_state.get(region_id, {}) as Dictionary).duplicate(true)

func to_save_data() -> Dictionary:
	var runtime := {}
	for region_id in region_runtime_state.keys():
		runtime[String(region_id)] = (
			region_runtime_state[region_id] as Dictionary
		).duplicate(true)
	return {
		"seed": seed_value,
		"graph_signature": graph_signature,
		"current_region_id": String(current_region_id),
		"party_position": [party_position.x, party_position.y],
		"region_runtime_state": runtime,
		"exploration": exploration_state.to_save_data()
	}

func restore_save_data(data: Dictionary) -> void:
	seed_value = int(data.get("seed", 0))
	graph_signature = String(data.get("graph_signature", ""))
	current_region_id = StringName(data.get("current_region_id", ""))
	var position_values := data.get("party_position", [0.0, 0.0]) as Array
	party_position = Vector2(float(position_values[0]), float(position_values[1]))
	region_runtime_state.clear()
	var runtime := data.get("region_runtime_state", {}) as Dictionary
	for key in runtime.keys():
		region_runtime_state[StringName(str(key))] = (
			runtime[key] as Dictionary
		).duplicate(true)
	exploration_state.restore_save_data(data.get("exploration", {}) as Dictionary)

static func create_empty_save_data() -> Dictionary:
	return {
		"seed": 0,
		"graph_signature": "",
		"current_region_id": "",
		"party_position": [0.0, 0.0],
		"region_runtime_state": {},
		"exploration": {
			"current_region_id": "",
			"region_states": {},
			"discovered_cells": {}
		}
	}
