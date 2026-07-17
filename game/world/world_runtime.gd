extends Node
class_name WorldRuntime

## Streaming contract:
## `active_regions` is the set of regions the runtime keeps "warm" as data: the
## current region plus every neighbor within `loaded_region_radius` hops on the
## world graph. WorldRegionStreamer treats this set as the authority for FULL
## gameplay content; visual ground residency is handled separately around the
## camera. Regions outside the set remain pure save data unless temporarily
## pinned by a runtime entity. Consumed content (opened crates, completed
## encounters, destroyed obstacles) is recorded per region in
## `persistent_state` so re-entering a streamed region does not respawn it.

signal current_region_changed(region_id: StringName)
signal exploration_changed(state: WorldExplorationState)
signal active_regions_changed(region_ids: Array[StringName])
signal region_runtime_changed(region_id: StringName)

@export_range(0, 3, 1) var loaded_region_radius: int = 1

var graph: WorldGraph
var persistent_state := PersistentWorldState.new()
var active_regions: Dictionary = {}
var biome_manager: BiomeManager
var is_active: bool = false
var pending_save_data: Dictionary = {}

func _ready() -> void:
	add_to_group("world_runtime")

func start_run(world_data: Dictionary, manager: BiomeManager = null) -> void:
	biome_manager = manager
	graph = world_data.get("world_graph", null) as WorldGraph
	if graph == null:
		var cells: Array[BiomeCell] = []
		for value in world_data.get("cells", []) as Array:
			var cell := value as BiomeCell
			if cell != null:
				cells.append(cell)
		graph = WorldGraph.new()
		graph.configure_from_biome_cells(cells, int(world_data.get("seed", 0)))
	persistent_state.configure(int(world_data.get("seed", 0)), graph)
	_apply_pending_save_if_compatible()
	var start_region_id := graph.start_region_id
	var start_cell := world_data.get("start_cell", null) as BiomeCell
	if start_cell != null:
		start_region_id = start_cell.id
	if (
		not persistent_state.current_region_id.is_empty()
		and graph.get_region(persistent_state.current_region_id) != null
	):
		start_region_id = persistent_state.current_region_id
	var current_cell := _find_cell(world_data, start_region_id)
	persistent_state.migrate_terrain_if_needed(current_cell, start_cell)
	set_current_region(start_region_id)
	is_active = true

func stop_run() -> void:
	is_active = false
	active_regions.clear()
	graph = null
	biome_manager = null
	active_regions_changed.emit([])

func set_current_region(region_id: StringName) -> bool:
	if graph == null or graph.get_region(region_id) == null:
		return false
	persistent_state.set_current_region(region_id, graph)
	_refresh_active_regions(region_id)
	current_region_changed.emit(region_id)
	exploration_changed.emit(persistent_state.exploration_state)
	return true

func update_from_biome_manager(manager: BiomeManager = null) -> void:
	if manager != null:
		biome_manager = manager
	if biome_manager == null:
		return
	var cell := biome_manager.get_current_biome_cell()
	if cell != null:
		set_current_region(cell.id)

func mark_current_region_cleared() -> void:
	var region_id := persistent_state.current_region_id
	if region_id.is_empty():
		return
	persistent_state.mark_region_cleared(region_id)
	exploration_changed.emit(persistent_state.exploration_state)

func update_party_position_from_players(players: Array[Node]) -> void:
	if players.is_empty():
		return
	var sum := Vector2.ZERO
	var count := 0
	for player in players:
		if player is Node2D:
			sum += (player as Node2D).global_position
			count += 1
	if count > 0:
		persistent_state.set_party_position(sum / float(count))

func get_current_region_id() -> StringName:
	return persistent_state.current_region_id

func get_exploration_state() -> WorldExplorationState:
	return persistent_state.exploration_state

func get_active_region_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for region_id in active_regions.keys():
		result.append(StringName(region_id))
	result.sort()
	return result

func is_region_active(region_id: StringName) -> bool:
	return active_regions.has(region_id)

func mark_region_item_consumed(
	region_id: StringName,
	category: StringName,
	key: StringName
) -> bool:
	var changed := persistent_state.mark_region_item_consumed(
		region_id,
		category,
		key
	)
	if changed:
		region_runtime_changed.emit(region_id)
	return changed

func is_region_item_consumed(
	region_id: StringName,
	category: StringName,
	key: StringName
) -> bool:
	return persistent_state.is_region_item_consumed(region_id, category, key)

func get_region_consumed_items(
	region_id: StringName,
	category: StringName
) -> Array[StringName]:
	return persistent_state.get_region_consumed_items(region_id, category)

func get_save_data() -> Dictionary:
	return persistent_state.to_save_data()

func restore_save_data(data: Dictionary) -> void:
	if data.is_empty():
		return
	pending_save_data = data.duplicate(true)
	persistent_state.restore_save_data(data)
	if graph != null and not persistent_state.current_region_id.is_empty():
		_refresh_active_regions(persistent_state.current_region_id)
	exploration_changed.emit(persistent_state.exploration_state)

func _apply_pending_save_if_compatible() -> void:
	if pending_save_data.is_empty() or graph == null:
		return
	var saved_seed := int(pending_save_data.get("seed", 0))
	var saved_signature := String(pending_save_data.get("graph_signature", ""))
	if saved_seed != 0 and saved_seed != graph.seed_value:
		return
	if not saved_signature.is_empty() and saved_signature != graph.get_signature():
		return
	persistent_state.restore_save_data(pending_save_data)
	pending_save_data.clear()

func _find_cell(world_data: Dictionary, region_id: StringName) -> BiomeCell:
	for value in world_data.get("cells", []) as Array:
		var cell := value as BiomeCell
		if cell != null and cell.id == region_id:
			return cell
	return null

func _refresh_active_regions(center_region_id: StringName) -> void:
	active_regions.clear()
	if graph == null:
		return
	active_regions[center_region_id] = true
	if loaded_region_radius <= 0:
		active_regions_changed.emit(get_active_region_ids())
		return
	var frontier: Array[StringName] = [center_region_id]
	var depth := {center_region_id: 0}
	while not frontier.is_empty():
		var current: StringName = frontier.pop_front()
		var current_depth := int(depth[current])
		if current_depth >= loaded_region_radius:
			continue
		for neighbor_id in graph.get_connected_region_ids(current):
			if depth.has(neighbor_id):
				continue
			depth[neighbor_id] = current_depth + 1
			active_regions[neighbor_id] = true
			frontier.append(neighbor_id)
	active_regions_changed.emit(get_active_region_ids())
