extends RefCounted
class_name PersistentWorldState

## Per-region runtime ledger categories. Each is stored as an array of stable
## string keys under region_runtime_state[region_id][category], so re-entering a
## streamed region can skip content that the party already consumed.
const CATEGORY_OPENED_CRATES: StringName = &"opened_crates"
const CATEGORY_DESTROYED_OBSTACLES: StringName = &"destroyed_obstacles"
const CATEGORY_COMPLETED_ENCOUNTERS: StringName = &"completed_encounters"
const TERRAIN_GENERATION_REVISION: int = 6

var seed_value: int = 0
var graph_signature: String = ""
var current_region_id: StringName = &""
var party_position: Vector2 = Vector2.ZERO
var terrain_generation_revision: int = TERRAIN_GENERATION_REVISION
var region_runtime_state: Dictionary = {}
var exploration_state := WorldExplorationState.new()

func configure(seed: int, graph: WorldGraph) -> void:
	seed_value = seed
	graph_signature = graph.get_signature() if graph != null else ""
	terrain_generation_revision = TERRAIN_GENERATION_REVISION
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

func migrate_terrain_if_needed(
	current_cell: BiomeCell,
	anchor_cell: BiomeCell
) -> bool:
	if terrain_generation_revision == TERRAIN_GENERATION_REVISION:
		return false
	# Layout-indexed object/crate keys cannot be carried across a terrain rewrite.
	# Exploration and graph state remain valid because region IDs/topology did not
	# change. Place the party on the regenerated route-safe spawn.
	region_runtime_state.clear()
	if current_cell != null and current_cell.generated_layout != null:
		var anchor_origin := anchor_cell.world_origin if anchor_cell != null else Vector2i.ZERO
		var region_offset := Vector2(current_cell.world_origin - anchor_origin) * current_cell.generated_layout.logical_tile_scale
		party_position = region_offset + current_cell.generated_layout.logical_to_world(
			current_cell.generated_layout.player_spawn_cell
		)
	else:
		party_position = Vector2.ZERO
	terrain_generation_revision = TERRAIN_GENERATION_REVISION
	return true

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

func mark_region_item_consumed(
	region_id: StringName,
	category: StringName,
	key: StringName
) -> bool:
	if region_id.is_empty() or category.is_empty() or key.is_empty():
		return false
	if not region_runtime_state.has(region_id):
		region_runtime_state[region_id] = {}
	var region_data := region_runtime_state[region_id] as Dictionary
	if not region_data.has(category):
		region_data[category] = []
	var items := region_data[category] as Array
	var key_text := String(key)
	for existing in items:
		if String(existing) == key_text:
			return false
	items.append(key_text)
	return true

func is_region_item_consumed(
	region_id: StringName,
	category: StringName,
	key: StringName
) -> bool:
	if not region_runtime_state.has(region_id):
		return false
	var region_data := region_runtime_state[region_id] as Dictionary
	if not region_data.has(category):
		return false
	var key_text := String(key)
	for existing in (region_data[category] as Array):
		if String(existing) == key_text:
			return true
	return false

func get_region_consumed_items(
	region_id: StringName,
	category: StringName
) -> Array[StringName]:
	var result: Array[StringName] = []
	if not region_runtime_state.has(region_id):
		return result
	var region_data := region_runtime_state[region_id] as Dictionary
	if not region_data.has(category):
		return result
	for existing in (region_data[category] as Array):
		result.append(StringName(String(existing)))
	return result

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
		"terrain_generation_revision": terrain_generation_revision,
		"region_runtime_state": runtime,
		"exploration": exploration_state.to_save_data()
	}

func restore_save_data(data: Dictionary) -> void:
	seed_value = int(data.get("seed", 0))
	graph_signature = String(data.get("graph_signature", ""))
	current_region_id = StringName(data.get("current_region_id", ""))
	var position_values := data.get("party_position", [0.0, 0.0]) as Array
	party_position = Vector2(float(position_values[0]), float(position_values[1]))
	terrain_generation_revision = int(data.get("terrain_generation_revision", 0))
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
		"terrain_generation_revision": TERRAIN_GENERATION_REVISION,
		"region_runtime_state": {},
		"exploration": {
			"current_region_id": "",
			"region_states": {},
			"discovered_cells": {}
		}
	}
