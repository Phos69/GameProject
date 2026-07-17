extends RefCounted
class_name BiomePassage

const WorldGridConfig = preload("res://game/core/world_grid_config.gd")

var from_cell_id: StringName = &""
var to_cell_id: StringName = &""
var from_biome_id: StringName = &""
var to_biome_id: StringName = &""
var side: StringName = &"east"
var opposite_side: StringName = &"west"
var position: int = 100
var width: int = WorldGridConfig.PASSAGE_WIDTH_TILES
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
	width = clampi(
		passage_width,
		WorldGridConfig.PASSAGE_MIN_WIDTH_TILES,
		min(source_cell.width, source_cell.height)
	)
	passage_type = resolved_type
	from_world_origin = source_cell.world_origin
	to_world_origin = target_cell.world_origin
	seed = passage_seed

func get_local_rect(zone_size: Vector2i) -> Rect2i:
	var span_before := _span_before_center(width)
	var edge_depth := WorldGridConfig.PASSAGE_EDGE_DEPTH_TILES
	match side:
		&"north":
			return Rect2i(
				Vector2i(position - span_before, 0),
				Vector2i(width, edge_depth)
			)
		&"south":
			return Rect2i(
				Vector2i(position - span_before, zone_size.y - edge_depth),
				Vector2i(width, edge_depth)
			)
		&"west":
			return Rect2i(
				Vector2i(0, position - span_before),
				Vector2i(edge_depth, width)
			)
		_:
			return Rect2i(
				Vector2i(zone_size.x - edge_depth, position - span_before),
				Vector2i(edge_depth, width)
			)

func get_connector_rect(zone_size: Vector2i) -> Rect2i:
	var center := zone_size / 2
	var span_before := _span_before_center(width)
	match side:
		&"north":
			return Rect2i(
				Vector2i(position - span_before, 0),
				Vector2i(width, center.y)
			)
		&"south":
			return Rect2i(
				Vector2i(position - span_before, center.y),
				Vector2i(width, zone_size.y - center.y)
			)
		&"west":
			return Rect2i(
				Vector2i(0, position - span_before),
				Vector2i(center.x, width)
			)
		_:
			return Rect2i(
				Vector2i(center.x, position - span_before),
				Vector2i(zone_size.x - center.x, width)
			)

func _span_before_center(span: int) -> int:
	return maxi(floori(float(span) * 0.5), 0)

# Cella interna adiacente all'imbocco del passaggio, alla profondita' standard
# del bordo. Prima duplicata come _passage_probe_cell (MapValidationSystem) e
# _passage_inner_anchor (ObstacleLayoutGenerator).
func edge_anchor_cell(zone_size: Vector2i) -> Vector2i:
	var edge_depth := WorldGridConfig.PASSAGE_EDGE_DEPTH_TILES
	match side:
		&"north":
			return Vector2i(position, edge_depth)
		&"south":
			return Vector2i(position, zone_size.y - edge_depth - 1)
		&"west":
			return Vector2i(edge_depth, position)
		_:
			return Vector2i(zone_size.x - edge_depth - 1, position)

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

# Copia indipendente del passaggio. Tutti i campi sono value-type (StringName/int/
# Vector2i), quindi una copia per assegnazione e gia un deep-copy.
func clone() -> BiomePassage:
	var copy := BiomePassage.new()
	copy.from_cell_id = from_cell_id
	copy.to_cell_id = to_cell_id
	copy.from_biome_id = from_biome_id
	copy.to_biome_id = to_biome_id
	copy.side = side
	copy.opposite_side = opposite_side
	copy.position = position
	copy.width = width
	copy.passage_type = passage_type
	copy.from_world_origin = from_world_origin
	copy.to_world_origin = to_world_origin
	copy.seed = seed
	return copy

func get_signature() -> String:
	return "%s>%s:%s:%d:%d:%s" % [
		String(from_cell_id),
		String(to_cell_id),
		String(side),
		position,
		width,
		String(passage_type)
	]

# --- Serializzazione (WorldSnapshotCodec / cache su disco) ------------------
# Rappresentazione a Dictionary puro di soli value-type, salvabile con
# FileAccess.store_var(). Speculare a clone(): tutti i campi sono value-type.
func to_dict() -> Dictionary:
	return {
		"from_cell_id": from_cell_id,
		"to_cell_id": to_cell_id,
		"from_biome_id": from_biome_id,
		"to_biome_id": to_biome_id,
		"side": side,
		"opposite_side": opposite_side,
		"position": position,
		"width": width,
		"passage_type": passage_type,
		"from_world_origin": from_world_origin,
		"to_world_origin": to_world_origin,
		"seed": seed
	}

static func from_dict(data: Dictionary) -> BiomePassage:
	var passage := BiomePassage.new()
	passage.from_cell_id = StringName(data.get("from_cell_id", &""))
	passage.to_cell_id = StringName(data.get("to_cell_id", &""))
	passage.from_biome_id = StringName(data.get("from_biome_id", &""))
	passage.to_biome_id = StringName(data.get("to_biome_id", &""))
	passage.side = StringName(data.get("side", &"east"))
	passage.opposite_side = StringName(data.get("opposite_side", &"west"))
	passage.position = int(data.get("position", 100))
	passage.width = int(data.get("width", WorldGridConfig.PASSAGE_WIDTH_TILES))
	passage.passage_type = StringName(data.get("passage_type", &"road"))
	passage.from_world_origin = data.get("from_world_origin", Vector2i.ZERO)
	passage.to_world_origin = data.get("to_world_origin", Vector2i.ZERO)
	passage.seed = int(data.get("seed", 0))
	return passage
