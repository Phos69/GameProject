extends Resource
class_name BiomeEnvironmentLayout

@export var zone_size: Vector2i = Vector2i(200, 200)
@export var generation_seed: int = 0
@export var logical_tile_scale: float = 8.0

@export var terrain_patch_tags: Array[StringName] = []
@export var terrain_patch_positions: Array[Vector2] = []
@export var terrain_patch_radii: Array[float] = []

@export var obstacle_ids: Array[StringName] = []
@export var obstacle_positions: Array[Vector2] = []
@export var obstacle_sizes: Array[Vector2] = []
@export var obstacle_rotations: Array[float] = []
@export var obstacle_shape_ids: Array[StringName] = []

@export var crate_ids: Array[StringName] = []
@export var crate_positions: Array[Vector2] = []

@export var hazard_ids: Array[StringName] = []
@export var hazard_positions: Array[Vector2] = []
@export var hazard_sizes: Array[Vector2] = []
@export var hazard_rotations: Array[float] = []

@export_range(80.0, 500.0, 10.0) var central_corridor_width: float = 220.0

var road_rects: Array[Rect2i] = []
var passage_rects: Array[Rect2i] = []
var obstacle_rects: Array[Rect2i] = []
var fall_zone_rects: Array[Rect2i] = []
var hazard_rects: Array[Rect2i] = []
var crate_cells: Array[Vector2i] = []
var player_spawn_cell: Vector2i = Vector2i(100, 100)
var validation_report: Dictionary = {}
var terrain_classification_counts: Dictionary = {}
var terrain_classification_total: int = 0
var terrain_classification_complete: bool = false

const TERRAIN_WALKABLE: StringName = &"walkable"
const TERRAIN_OBSTACLE: StringName = &"obstacle"
const TERRAIN_HAZARD: StringName = &"hazard"
const TERRAIN_BORDER: StringName = &"border"
const TERRAIN_VOID: StringName = &"void"
const TERRAIN_FALL_ZONE: StringName = &"fall_zone"

func has_generated_map_data() -> bool:
	return (
		zone_size == Vector2i(200, 200)
		and generation_seed != 0
		and not road_rects.is_empty()
	)

func logical_to_world(cell: Vector2i) -> Vector2:
	return (
		Vector2(cell.x - zone_size.x / 2, cell.y - zone_size.y / 2)
		* logical_tile_scale
	)

func rect_center_to_world(rect: Rect2i) -> Vector2:
	return logical_to_world(rect.position + rect.size / 2)

func rect_size_to_world(rect: Rect2i) -> Vector2:
	return Vector2(rect.size) * logical_tile_scale

func world_to_logical(position: Vector2) -> Vector2i:
	return Vector2i(
		roundi(position.x / logical_tile_scale + float(zone_size.x) * 0.5),
		roundi(position.y / logical_tile_scale + float(zone_size.y) * 0.5)
	)

func is_world_position_inside_zone(position: Vector2) -> bool:
	var cell := world_to_logical(position)
	return (
		cell.x >= 0
		and cell.y >= 0
		and cell.x < zone_size.x
		and cell.y < zone_size.y
	)

func get_generation_signature() -> String:
	return "%d:%s:%d:%d:%d:%d" % [
		generation_seed,
		str(zone_size),
		road_rects.size(),
		obstacle_rects.size(),
		fall_zone_rects.size(),
		hazard_rects.size()
	]

func rebuild_terrain_classification(cell: BiomeCell = null) -> void:
	terrain_classification_counts = {
		TERRAIN_WALKABLE: 0,
		TERRAIN_OBSTACLE: 0,
		TERRAIN_HAZARD: 0,
		TERRAIN_BORDER: 0,
		TERRAIN_VOID: 0,
		TERRAIN_FALL_ZONE: 0
	}
	terrain_classification_total = 0
	for y in range(zone_size.y):
		for x in range(zone_size.x):
			var terrain_class := get_terrain_class_at_cell(Vector2i(x, y), cell)
			terrain_classification_counts[terrain_class] = (
				int(terrain_classification_counts.get(terrain_class, 0)) + 1
			)
			terrain_classification_total += 1
	terrain_classification_complete = (
		terrain_classification_total == zone_size.x * zone_size.y
	)

func get_terrain_class_at_cell(
	cell: Vector2i,
	biome_cell: BiomeCell = null
) -> StringName:
	if (
		cell.x < 0
		or cell.y < 0
		or cell.x >= zone_size.x
		or cell.y >= zone_size.y
	):
		return TERRAIN_VOID
	if _cell_inside_any_rect(cell, fall_zone_rects):
		return TERRAIN_FALL_ZONE
	if _cell_inside_any_rect(cell, obstacle_rects):
		return TERRAIN_OBSTACLE
	if _cell_inside_any_rect(cell, hazard_rects):
		return TERRAIN_HAZARD
	if _cell_inside_any_rect(cell, passage_rects):
		return TERRAIN_WALKABLE
	if _is_border_cell(cell, biome_cell):
		return TERRAIN_BORDER
	return TERRAIN_WALKABLE

func get_classification_report() -> Dictionary:
	return {
		"is_complete": terrain_classification_complete,
		"total": terrain_classification_total,
		"expected_total": zone_size.x * zone_size.y,
		"counts": terrain_classification_counts.duplicate(true)
	}

func _is_border_cell(cell: Vector2i, biome_cell: BiomeCell = null) -> bool:
	if cell.y == 0:
		return _side_is_non_fall_border(&"north", biome_cell)
	if cell.y == zone_size.y - 1:
		return _side_is_non_fall_border(&"south", biome_cell)
	if cell.x == 0:
		return _side_is_non_fall_border(&"west", biome_cell)
	if cell.x == zone_size.x - 1:
		return _side_is_non_fall_border(&"east", biome_cell)
	return false

func _side_is_non_fall_border(
	side: StringName,
	biome_cell: BiomeCell = null
) -> bool:
	if biome_cell == null:
		return true
	return biome_cell.get_border(side) != BiomeCell.BorderType.FALL

func _cell_inside_any_rect(cell: Vector2i, rects: Array[Rect2i]) -> bool:
	for rect in rects:
		if rect.has_point(cell):
			return true
	return false
