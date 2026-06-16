extends RefCounted
class_name WorldRegionConnection

var connection_id: StringName = &""
var from_region_id: StringName = &""
var to_region_id: StringName = &""
var from_biome_id: StringName = &""
var to_biome_id: StringName = &""
var side: StringName = &"east"
var opposite_side: StringName = &"west"
var passage_position: int = 100
var passage_width: int = 10
var passage_type: StringName = &"road"
var local_rect: Rect2i = Rect2i()
var target_local_rect: Rect2i = Rect2i()
var world_rect: Rect2i = Rect2i()
var seed: int = 0
var is_open: bool = true
var physical_passage: bool = true

func configure_from_passage(
	passage: BiomePassage,
	source_cell: BiomeCell,
	target_cell: BiomeCell
) -> void:
	if passage == null or source_cell == null or target_cell == null:
		return
	from_region_id = source_cell.id
	to_region_id = target_cell.id
	from_biome_id = source_cell.biome_id
	to_biome_id = target_cell.biome_id
	side = passage.side
	opposite_side = passage.opposite_side
	passage_position = passage.position
	passage_width = passage.width
	passage_type = passage.passage_type
	seed = passage.seed
	connection_id = StringName("%s_%s_%s" % [
		String(from_region_id),
		String(side),
		String(to_region_id)
	])
	local_rect = passage.get_local_rect(source_cell.get_zone_size())
	target_local_rect = _target_rect_for_passage(passage, target_cell)
	world_rect = Rect2i(source_cell.world_origin + local_rect.position, local_rect.size)
	is_open = true
	physical_passage = true

func get_signature() -> String:
	return "%s>%s:%s:%d:%d:%s:%s" % [
		String(from_region_id),
		String(to_region_id),
		String(side),
		passage_position,
		passage_width,
		String(passage_type),
		str(world_rect)
	]

func to_save_data() -> Dictionary:
	return {
		"connection_id": String(connection_id),
		"from_region_id": String(from_region_id),
		"to_region_id": String(to_region_id),
		"from_biome_id": String(from_biome_id),
		"to_biome_id": String(to_biome_id),
		"side": String(side),
		"opposite_side": String(opposite_side),
		"passage_position": passage_position,
		"passage_width": passage_width,
		"passage_type": String(passage_type),
		"seed": seed,
		"is_open": is_open,
		"physical_passage": physical_passage
	}

static func from_save_data(data: Dictionary) -> WorldRegionConnection:
	var connection := WorldRegionConnection.new()
	connection.connection_id = StringName(data.get("connection_id", ""))
	connection.from_region_id = StringName(data.get("from_region_id", ""))
	connection.to_region_id = StringName(data.get("to_region_id", ""))
	connection.from_biome_id = StringName(data.get("from_biome_id", ""))
	connection.to_biome_id = StringName(data.get("to_biome_id", ""))
	connection.side = StringName(data.get("side", "east"))
	connection.opposite_side = StringName(data.get("opposite_side", "west"))
	connection.passage_position = int(data.get("passage_position", 100))
	connection.passage_width = int(data.get("passage_width", 10))
	connection.passage_type = StringName(data.get("passage_type", "road"))
	connection.seed = int(data.get("seed", 0))
	connection.is_open = bool(data.get("is_open", true))
	connection.physical_passage = bool(data.get("physical_passage", true))
	return connection

func _target_rect_for_passage(
	passage: BiomePassage,
	target_cell: BiomeCell
) -> Rect2i:
	var clone := BiomePassage.new()
	clone.configure(
		target_cell,
		target_cell,
		passage.opposite_side,
		passage.position,
		passage.width,
		passage.passage_type,
		passage.seed
	)
	return clone.get_local_rect(target_cell.get_zone_size())
