extends Node2D
class_name IsometricPlayground

@export var grid_radius: int = 9
@export var tile_width: float = 96.0
@export var tile_height: float = 48.0
@export var line_color: Color = Color(0.20, 0.26, 0.31, 0.65)
@export var major_line_color: Color = Color(0.34, 0.50, 0.58, 0.95)
@export var floor_color: Color = Color(0.08, 0.10, 0.12, 1.0)

func _draw() -> void:
	var arena_size := Vector2(tile_width * grid_radius * 1.45, tile_height * grid_radius * 1.45)
	draw_rect(Rect2(-arena_size, arena_size * 2.0), floor_color, true)

	for x in range(-grid_radius, grid_radius + 1):
		for y in range(-grid_radius, grid_radius + 1):
			if abs(x) + abs(y) <= grid_radius:
				_draw_tile(Vector2i(x, y))

	_draw_axis(Vector2i(-grid_radius, 0), Vector2i(grid_radius, 0), Color(0.25, 0.72, 0.95, 0.85))
	_draw_axis(Vector2i(0, -grid_radius), Vector2i(0, grid_radius), Color(0.95, 0.58, 0.23, 0.85))

func _draw_tile(cell: Vector2i) -> void:
	var center := iso_to_screen(cell)
	var half_w := tile_width * 0.5
	var half_h := tile_height * 0.5
	var points := PackedVector2Array([
		center + Vector2(0.0, -half_h),
		center + Vector2(half_w, 0.0),
		center + Vector2(0.0, half_h),
		center + Vector2(-half_w, 0.0),
		center + Vector2(0.0, -half_h)
	])
	var color := major_line_color if (cell.x == 0 or cell.y == 0) else line_color
	draw_polyline(points, color, 1.2)

func _draw_axis(start_cell: Vector2i, end_cell: Vector2i, color: Color) -> void:
	draw_line(iso_to_screen(start_cell), iso_to_screen(end_cell), color, 3.0)

func iso_to_screen(cell: Vector2i) -> Vector2:
	return Vector2(
		(float(cell.x) - float(cell.y)) * tile_width * 0.5,
		(float(cell.x) + float(cell.y)) * tile_height * 0.5
	)

