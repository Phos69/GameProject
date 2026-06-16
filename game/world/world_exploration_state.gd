extends RefCounted
class_name WorldExplorationState

const STATE_UNKNOWN: StringName = &"unknown"
const STATE_DISCOVERED: StringName = &"discovered"
const STATE_VISITED: StringName = &"visited"
const STATE_CLEARED: StringName = &"cleared"

var region_states: Dictionary = {}
var discovered_cells: Dictionary = {}
var current_region_id: StringName = &""

func initialize_from_graph(graph: WorldGraph) -> void:
	if graph == null:
		return
	for region_id in graph.regions.keys():
		if not region_states.has(region_id):
			region_states[region_id] = STATE_UNKNOWN
		if not discovered_cells.has(region_id):
			discovered_cells[region_id] = {}
	if not graph.start_region_id.is_empty():
		mark_visited(graph.start_region_id)
		reveal_neighbors(graph, graph.start_region_id)

func mark_discovered(region_id: StringName) -> void:
	if region_id.is_empty():
		return
	var current := StringName(region_states.get(region_id, STATE_UNKNOWN))
	if current == STATE_UNKNOWN:
		region_states[region_id] = STATE_DISCOVERED

func mark_visited(region_id: StringName) -> void:
	if region_id.is_empty():
		return
	current_region_id = region_id
	var current := StringName(region_states.get(region_id, STATE_UNKNOWN))
	if current != STATE_CLEARED:
		region_states[region_id] = STATE_VISITED

func mark_cleared(region_id: StringName) -> void:
	if region_id.is_empty():
		return
	region_states[region_id] = STATE_CLEARED

func reveal_neighbors(graph: WorldGraph, region_id: StringName) -> void:
	if graph == null or region_id.is_empty():
		return
	for neighbor_id in graph.get_connected_region_ids(region_id):
		mark_discovered(neighbor_id)

func mark_cell_seen(region_id: StringName, cell: Vector2i) -> void:
	if region_id.is_empty():
		return
	if not discovered_cells.has(region_id):
		discovered_cells[region_id] = {}
	(discovered_cells[region_id] as Dictionary)[cell] = true

func get_state(region_id: StringName) -> StringName:
	return StringName(region_states.get(region_id, STATE_UNKNOWN))

func is_visible(region_id: StringName) -> bool:
	return get_state(region_id) != STATE_UNKNOWN

func to_save_data() -> Dictionary:
	var states := {}
	for region_id in region_states.keys():
		states[String(region_id)] = String(region_states[region_id])
	var seen := {}
	for region_id in discovered_cells.keys():
		var cells := PackedStringArray()
		for cell in (discovered_cells[region_id] as Dictionary).keys():
			cells.append("%d,%d" % [cell.x, cell.y])
		seen[String(region_id)] = cells
	return {
		"current_region_id": String(current_region_id),
		"region_states": states,
		"discovered_cells": seen
	}

func restore_save_data(data: Dictionary) -> void:
	current_region_id = StringName(data.get("current_region_id", ""))
	region_states.clear()
	var states := data.get("region_states", {}) as Dictionary
	for key in states.keys():
		region_states[StringName(str(key))] = StringName(states[key])
	discovered_cells.clear()
	var seen := data.get("discovered_cells", {}) as Dictionary
	for key in seen.keys():
		var cells: Dictionary = {}
		for encoded in seen[key]:
			var parts := str(encoded).split(",")
			if parts.size() == 2:
				cells[Vector2i(int(parts[0]), int(parts[1]))] = true
		discovered_cells[StringName(str(key))] = cells
