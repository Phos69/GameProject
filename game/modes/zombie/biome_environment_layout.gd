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
