extends RefCounted
class_name WorldGraph

var seed_value: int = 0
var region_size: Vector2i = Vector2i(200, 200)
var regions: Dictionary = {}
var connections: Array[WorldRegionConnection] = []
var start_region_id: StringName = &""

func configure_from_biome_cells(
	cells: Array[BiomeCell],
	seed: int
) -> void:
	seed_value = seed
	regions.clear()
	connections.clear()
	start_region_id = &""
	for cell in cells:
		var region := WorldRegion.new()
		region.configure_from_cell(cell)
		regions[region.region_id] = region
		region_size = region.size_tiles
		if start_region_id.is_empty() or cell.grid == Vector2i.ZERO:
			start_region_id = cell.id
	for cell in cells:
		var region := get_region(cell.id)
		if region == null:
			continue
		for passage in cell.passages:
			var target := _find_cell(cells, passage.to_cell_id)
			if target == null:
				continue
			var connection := WorldRegionConnection.new()
			connection.configure_from_passage(passage, cell, target)
			region.add_connection(connection)
			connections.append(connection)

func get_region(region_id: StringName) -> WorldRegion:
	return regions.get(region_id, null) as WorldRegion

func get_regions_sorted() -> Array[WorldRegion]:
	var ids := regions.keys()
	ids.sort()
	var result: Array[WorldRegion] = []
	for region_id in ids:
		var region := get_region(region_id)
		if region != null:
			result.append(region)
	return result

func get_connection_count() -> int:
	var undirected := {}
	for connection in connections:
		var ids := [String(connection.from_region_id), String(connection.to_region_id)]
		ids.sort()
		undirected["%s:%s" % [ids[0], ids[1]]] = true
	return undirected.size()

func get_connected_region_ids(region_id: StringName) -> Array[StringName]:
	var region := get_region(region_id)
	var result: Array[StringName] = []
	if region == null:
		return result
	for connection in region.connection_edges:
		if not result.has(connection.to_region_id):
			result.append(connection.to_region_id)
	result.sort()
	return result

func get_connections_for_region(region_id: StringName) -> Array[WorldRegionConnection]:
	var region := get_region(region_id)
	return region.connection_edges.duplicate() if region != null else []

func get_region_at_grid(grid_position: Vector2i) -> WorldRegion:
	for region in regions.values():
		var typed_region := region as WorldRegion
		if typed_region != null and typed_region.grid_position == grid_position:
			return typed_region
	return null

func is_graph_connected() -> bool:
	if regions.is_empty():
		return false
	if start_region_id.is_empty():
		return false
	var visited := {}
	var queue: Array[StringName] = [start_region_id]
	visited[start_region_id] = true
	while not queue.is_empty():
		var current: StringName = queue.pop_front()
		for neighbor_id in get_connected_region_ids(current):
			if visited.has(neighbor_id):
				continue
			visited[neighbor_id] = true
			queue.append(neighbor_id)
	return visited.size() == regions.size()

func get_unreachable_region_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	if start_region_id.is_empty():
		for region_id in regions.keys():
			result.append(region_id)
		result.sort()
		return result
	var visited := {}
	var queue: Array[StringName] = [start_region_id]
	visited[start_region_id] = true
	while not queue.is_empty():
		var current: StringName = queue.pop_front()
		for neighbor_id in get_connected_region_ids(current):
			if visited.has(neighbor_id):
				continue
			visited[neighbor_id] = true
			queue.append(neighbor_id)
	for region_id in regions.keys():
		if not visited.has(region_id):
			result.append(region_id)
	result.sort()
	return result

func validate_physical_passages() -> Dictionary:
	var failures := PackedStringArray()
	for connection in connections:
		var source := get_region(connection.from_region_id)
		var target := get_region(connection.to_region_id)
		if source == null or target == null:
			failures.append("%s:missing_region" % String(connection.connection_id))
			continue
		if not connection.is_open or not connection.physical_passage:
			failures.append("%s:not_open" % String(connection.connection_id))
		var expected_grid := source.grid_position + BorderGenerator.get_side_offset(
			connection.side
		)
		if target.grid_position != expected_grid:
			failures.append("%s:grid_mismatch" % String(connection.connection_id))
		var reverse_found := false
		for reverse in target.connection_edges:
			if (
				reverse.to_region_id == source.region_id
				and reverse.side == connection.opposite_side
				and reverse.passage_position == connection.passage_position
				and reverse.passage_width == connection.passage_width
			):
				reverse_found = true
				break
		if not reverse_found:
			failures.append("%s:missing_reverse" % String(connection.connection_id))
	return {
		"is_valid": failures.is_empty(),
		"failures": failures,
		"connection_count": get_connection_count()
	}

func get_signature() -> String:
	var parts := PackedStringArray()
	for region in get_regions_sorted():
		parts.append(region.get_signature())
	return "seed=%d size=%s connected=%s\n%s" % [
		seed_value,
		str(region_size),
		str(is_graph_connected()),
		"\n".join(parts)
	]

func to_save_data() -> Dictionary:
	var region_data: Array[Dictionary] = []
	for region in get_regions_sorted():
		region_data.append(region.to_save_data())
	var connection_data: Array[Dictionary] = []
	for connection in connections:
		connection_data.append(connection.to_save_data())
	return {
		"seed": seed_value,
		"region_size": [region_size.x, region_size.y],
		"start_region_id": String(start_region_id),
		"regions": region_data,
		"connections": connection_data
	}

static func from_save_data(data: Dictionary) -> WorldGraph:
	var graph := WorldGraph.new()
	graph.seed_value = int(data.get("seed", 0))
	var size_values := data.get("region_size", [200, 200]) as Array
	graph.region_size = Vector2i(int(size_values[0]), int(size_values[1]))
	graph.start_region_id = StringName(data.get("start_region_id", ""))
	for region_value in data.get("regions", []):
		var region := WorldRegion.from_save_data(region_value as Dictionary)
		graph.regions[region.region_id] = region
	for connection_value in data.get("connections", []):
		var connection := WorldRegionConnection.from_save_data(
			connection_value as Dictionary
		)
		graph.connections.append(connection)
		var source := graph.get_region(connection.from_region_id)
		if source != null:
			source.add_connection(connection)
	return graph

func _find_cell(cells: Array[BiomeCell], cell_id: StringName) -> BiomeCell:
	for cell in cells:
		if cell.id == cell_id:
			return cell
	return null
