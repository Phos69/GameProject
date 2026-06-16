extends RefCounted
class_name WorldRegion

var region_id: StringName = &""
var biome_id: StringName = &""
var grid_position: Vector2i = Vector2i.ZERO
var world_origin: Vector2i = Vector2i.ZERO
var size_tiles: Vector2i = Vector2i(200, 200)
var seed: int = 0
var neighbors: Dictionary = {}
var border_types: Dictionary = {}
var connection_edges: Array[WorldRegionConnection] = []
var generated_layout: BiomeEnvironmentLayout
var exploration_state: StringName = &"unknown"
var discovered_cells: Dictionary = {}
var visited: bool = false
var cleared: bool = false

func configure_from_cell(cell: BiomeCell) -> void:
	if cell == null:
		return
	region_id = cell.id
	biome_id = cell.biome_id
	grid_position = cell.grid
	world_origin = cell.world_origin
	size_tiles = cell.get_zone_size()
	seed = cell.seed
	generated_layout = cell.generated_layout
	for side in BiomeCell.SIDES:
		var neighbor := cell.get_neighbor(side)
		neighbors[side] = neighbor.id if neighbor != null else &""
		border_types[side] = cell.get_border(side)

func add_connection(connection: WorldRegionConnection) -> void:
	if connection == null:
		return
	for existing in connection_edges:
		if existing.connection_id == connection.connection_id:
			return
	connection_edges.append(connection)
	neighbors[connection.side] = connection.to_region_id
	border_types[connection.side] = BiomeCell.BorderType.CONNECTED

func get_neighbor_region_id(side: StringName) -> StringName:
	return StringName(neighbors.get(side, &""))

func has_neighbor(side: StringName) -> bool:
	return not get_neighbor_region_id(side).is_empty()

func get_border_type(side: StringName) -> int:
	return int(border_types.get(side, BiomeCell.BorderType.FALL))

func get_connections_for_side(side: StringName) -> Array[WorldRegionConnection]:
	var result: Array[WorldRegionConnection] = []
	for connection in connection_edges:
		if connection.side == side:
			result.append(connection)
	return result

func get_signature() -> String:
	var side_parts := PackedStringArray()
	for side in BiomeCell.SIDES:
		side_parts.append("%s:%s:%d" % [
			String(side),
			String(get_neighbor_region_id(side)),
			get_border_type(side)
		])
	var edge_parts := PackedStringArray()
	for connection in connection_edges:
		edge_parts.append(connection.get_signature())
	edge_parts.sort()
	return "%s:%s:%s:%s:%d:%s:%s" % [
		String(region_id),
		String(biome_id),
		str(grid_position),
		str(world_origin),
		seed,
		"|".join(side_parts),
		"|".join(edge_parts)
	]

func to_save_data() -> Dictionary:
	var neighbor_data := {}
	var border_data := {}
	for side in BiomeCell.SIDES:
		neighbor_data[String(side)] = String(get_neighbor_region_id(side))
		border_data[String(side)] = get_border_type(side)
	return {
		"region_id": String(region_id),
		"biome_id": String(biome_id),
		"grid_position": [grid_position.x, grid_position.y],
		"world_origin": [world_origin.x, world_origin.y],
		"size_tiles": [size_tiles.x, size_tiles.y],
		"seed": seed,
		"neighbors": neighbor_data,
		"border_types": border_data,
		"exploration_state": String(exploration_state),
		"visited": visited,
		"cleared": cleared
	}

static func from_save_data(data: Dictionary) -> WorldRegion:
	var region := WorldRegion.new()
	region.region_id = StringName(data.get("region_id", ""))
	region.biome_id = StringName(data.get("biome_id", ""))
	var grid_values := data.get("grid_position", [0, 0]) as Array
	var origin_values := data.get("world_origin", [0, 0]) as Array
	var size_values := data.get("size_tiles", [200, 200]) as Array
	region.grid_position = Vector2i(int(grid_values[0]), int(grid_values[1]))
	region.world_origin = Vector2i(int(origin_values[0]), int(origin_values[1]))
	region.size_tiles = Vector2i(int(size_values[0]), int(size_values[1]))
	region.seed = int(data.get("seed", 0))
	var neighbor_data := data.get("neighbors", {}) as Dictionary
	var border_data := data.get("border_types", {}) as Dictionary
	for side in BiomeCell.SIDES:
		region.neighbors[side] = StringName(neighbor_data.get(String(side), ""))
		region.border_types[side] = int(
			border_data.get(String(side), BiomeCell.BorderType.FALL)
		)
	region.exploration_state = StringName(data.get("exploration_state", "unknown"))
	region.visited = bool(data.get("visited", false))
	region.cleared = bool(data.get("cleared", false))
	return region
