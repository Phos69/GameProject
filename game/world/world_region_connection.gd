extends RefCounted
class_name WorldRegionConnection

const IsoGridConfig = preload("res://game/core/iso_grid_config.gd")

var connection_id: StringName = &""
var from_region_id: StringName = &""
var to_region_id: StringName = &""
var from_biome_id: StringName = &""
var to_biome_id: StringName = &""
var side: StringName = &"east"
var opposite_side: StringName = &"west"
var passage_position: int = 100
var passage_width: int = IsoGridConfig.PASSAGE_WIDTH_TILES
var passage_type: StringName = &"road"
var local_rect: Rect2i = Rect2i()
var connector_local_rect: Rect2i = Rect2i()
var target_local_rect: Rect2i = Rect2i()
var world_rect: Rect2i = Rect2i()
var world_connector_rect: Rect2i = Rect2i()
var target_world_rect: Rect2i = Rect2i()
var target_connector_local_rect: Rect2i = Rect2i()
var target_world_connector_rect: Rect2i = Rect2i()
var entry_tile_id: StringName = &"road_entry"
var exit_tile_id: StringName = &"road_exit"
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
	connector_local_rect = passage.get_connector_rect(source_cell.get_zone_size())
	target_local_rect = _target_rect_for_passage(passage, target_cell)
	target_connector_local_rect = _target_connector_rect_for_passage(passage, target_cell)
	world_rect = Rect2i(source_cell.world_origin + local_rect.position, local_rect.size)
	world_connector_rect = Rect2i(
		source_cell.world_origin + connector_local_rect.position,
		connector_local_rect.size
	)
	target_world_rect = Rect2i(
		target_cell.world_origin + target_local_rect.position,
		target_local_rect.size
	)
	target_world_connector_rect = Rect2i(
		target_cell.world_origin + target_connector_local_rect.position,
		target_connector_local_rect.size
	)
	entry_tile_id = passage.get_entry_tile_id()
	exit_tile_id = passage.get_exit_tile_id()
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
		"entry_tile_id": String(entry_tile_id),
		"exit_tile_id": String(exit_tile_id),
		"local_rect": _rect_to_data(local_rect),
		"connector_local_rect": _rect_to_data(connector_local_rect),
		"target_local_rect": _rect_to_data(target_local_rect),
		"world_rect": _rect_to_data(world_rect),
		"world_connector_rect": _rect_to_data(world_connector_rect),
		"target_world_rect": _rect_to_data(target_world_rect),
		"target_connector_local_rect": _rect_to_data(target_connector_local_rect),
		"target_world_connector_rect": _rect_to_data(target_world_connector_rect),
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
	connection.passage_width = int(data.get(
		"passage_width",
		IsoGridConfig.PASSAGE_WIDTH_TILES
	))
	connection.passage_type = StringName(data.get("passage_type", "road"))
	connection.entry_tile_id = StringName(data.get("entry_tile_id", "road_entry"))
	connection.exit_tile_id = StringName(data.get("exit_tile_id", "road_exit"))
	connection.local_rect = _rect_from_data(data.get("local_rect", []))
	connection.connector_local_rect = _rect_from_data(data.get("connector_local_rect", []))
	connection.target_local_rect = _rect_from_data(data.get("target_local_rect", []))
	connection.world_rect = _rect_from_data(data.get("world_rect", []))
	connection.world_connector_rect = _rect_from_data(data.get("world_connector_rect", []))
	connection.target_world_rect = _rect_from_data(data.get("target_world_rect", []))
	connection.target_connector_local_rect = _rect_from_data(
		data.get("target_connector_local_rect", [])
	)
	connection.target_world_connector_rect = _rect_from_data(
		data.get("target_world_connector_rect", [])
	)
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

func _target_connector_rect_for_passage(
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
	return clone.get_connector_rect(target_cell.get_zone_size())

static func _rect_to_data(rect: Rect2i) -> Array[int]:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]

static func _rect_from_data(value: Variant) -> Rect2i:
	if not value is Array:
		return Rect2i()
	var values := value as Array
	if values.size() < 4:
		return Rect2i()
	return Rect2i(
		Vector2i(int(values[0]), int(values[1])),
		Vector2i(int(values[2]), int(values[3]))
	)
