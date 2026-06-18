extends RefCounted
class_name BiomePassage

var from_cell_id: StringName = &""
var to_cell_id: StringName = &""
var from_biome_id: StringName = &""
var to_biome_id: StringName = &""
var side: StringName = &"east"
var opposite_side: StringName = &"west"
var position: int = 100
var width: int = 40
var passage_type: StringName = &"road"
var from_world_origin: Vector2i = Vector2i.ZERO
var to_world_origin: Vector2i = Vector2i.ZERO
var seed: int = 0

func configure(
	source_cell: BiomeCell,
	target_cell: BiomeCell,
	source_side: StringName,
	passage_position: int,
	passage_width: int,
	resolved_type: StringName,
	passage_seed: int
) -> void:
	from_cell_id = source_cell.id
	to_cell_id = target_cell.id
	from_biome_id = source_cell.biome_id
	to_biome_id = target_cell.biome_id
	side = source_side
	opposite_side = BorderGenerator.get_opposite_side(source_side)
	position = clampi(passage_position, 1, source_cell.height - 2)
	width = clampi(passage_width, 4, min(source_cell.width, source_cell.height))
	passage_type = resolved_type
	from_world_origin = source_cell.world_origin
	to_world_origin = target_cell.world_origin
	seed = passage_seed

func get_local_rect(zone_size: Vector2i) -> Rect2i:
	var half_width := maxi(width / 2, 2)
	match side:
		&"north":
			return Rect2i(
				Vector2i(position - half_width, 0),
				Vector2i(width, 3)
			)
		&"south":
			return Rect2i(
				Vector2i(position - half_width, zone_size.y - 3),
				Vector2i(width, 3)
			)
		&"west":
			return Rect2i(
				Vector2i(0, position - half_width),
				Vector2i(3, width)
			)
		_:
			return Rect2i(
				Vector2i(zone_size.x - 3, position - half_width),
				Vector2i(3, width)
			)

func get_connector_rect(zone_size: Vector2i) -> Rect2i:
	var center := zone_size / 2
	var half_width := maxi(width / 2, 2)
	match side:
		&"north":
			return Rect2i(
				Vector2i(position - half_width, 0),
				Vector2i(width, center.y)
			)
		&"south":
			return Rect2i(
				Vector2i(position - half_width, center.y),
				Vector2i(width, zone_size.y - center.y)
			)
		&"west":
			return Rect2i(
				Vector2i(0, position - half_width),
				Vector2i(center.x, width)
			)
		_:
			return Rect2i(
				Vector2i(center.x, position - half_width),
				Vector2i(zone_size.x - center.x, width)
			)

func get_global_local_rect(zone_size: Vector2i) -> Rect2i:
	var local_rect := get_local_rect(zone_size)
	return Rect2i(from_world_origin + local_rect.position, local_rect.size)

func get_global_connector_rect(zone_size: Vector2i) -> Rect2i:
	var connector_rect := get_connector_rect(zone_size)
	return Rect2i(from_world_origin + connector_rect.position, connector_rect.size)

func get_entry_tile_id() -> StringName:
	match passage_type:
		&"bridge":
			return &"bridge_entry"
		&"snow_pass":
			return &"snow_pass_entry"
		&"broken_gate":
			return &"broken_gate_entry"
		&"burned_road":
			return &"burned_road_entry"
		_:
			return &"road_entry"

func get_exit_tile_id() -> StringName:
	match passage_type:
		&"bridge":
			return &"bridge_exit"
		&"snow_pass":
			return &"snow_pass_exit"
		&"broken_gate":
			return &"broken_gate_exit"
		&"burned_road":
			return &"burned_road_exit"
		_:
			return &"road_exit"

func get_signature() -> String:
	return "%s>%s:%s:%d:%d:%s" % [
		String(from_cell_id),
		String(to_cell_id),
		String(side),
		position,
		width,
		String(passage_type)
	]
