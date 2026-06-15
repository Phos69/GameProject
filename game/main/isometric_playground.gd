extends Node2D
class_name IsometricPlayground

@export var grid_radius: int = 9
@export var tile_width: float = 96.0
@export var tile_height: float = 48.0
@export var line_color: Color = Color(0.19, 0.23, 0.23, 0.68)
@export var major_line_color: Color = Color(0.38, 0.43, 0.38, 0.82)
@export var floor_color: Color = Color(0.055, 0.065, 0.064, 1.0)
@export var concrete_color: Color = Color(0.16, 0.18, 0.17, 1.0)
@export var hazard_color: Color = Color(0.72, 0.53, 0.16, 0.78)

var arena_id: StringName = &"industrial_crossroads"
var layout_kind: StringName = &"crossroads"
var lane_color: Color = Color(0.66, 0.61, 0.43, 0.26)
var alternate_concrete_color: Color = Color(0.19, 0.21, 0.20, 1.0)

func configure_arena(profile: SurvivalArenaProfile) -> void:
	if profile == null:
		return
	arena_id = profile.arena_id
	layout_kind = profile.layout_kind
	grid_radius = profile.grid_radius
	if profile.biome != null:
		floor_color = profile.biome.background_color
		concrete_color = profile.biome.floor_color
		alternate_concrete_color = profile.biome.alternate_floor_color
		line_color = profile.biome.grid_color
		major_line_color = profile.biome.major_grid_color
		lane_color = profile.biome.lane_color
		hazard_color = profile.biome.hazard_color
	queue_redraw()

func _draw() -> void:
	var arena_size := Vector2(tile_width * grid_radius * 1.45, tile_height * grid_radius * 1.45)
	draw_rect(Rect2(-arena_size, arena_size * 2.0), floor_color, true)

	for x in range(-grid_radius, grid_radius + 1):
		for y in range(-grid_radius, grid_radius + 1):
			if abs(x) + abs(y) <= grid_radius:
				_draw_tile(Vector2i(x, y))

	if layout_kind == &"ring":
		_draw_ring_layout()
	else:
		_draw_faded_lane(Vector2i(-grid_radius + 1, 0), Vector2i(grid_radius - 1, 0))
		_draw_faded_lane(Vector2i(0, -grid_radius + 1), Vector2i(0, grid_radius - 1))
	_draw_boundary_markers()
	if layout_kind == &"ring":
		_draw_barricade(Vector2(-410.0, -100.0), 0.18)
		_draw_barricade(Vector2(410.0, 100.0), PI + 0.18)
		_draw_barricade(Vector2(0.0, 280.0), -0.58)
	else:
		_draw_barricade(Vector2(-485.0, -120.0), -0.16)
		_draw_barricade(Vector2(470.0, 135.0), PI - 0.16)
		_draw_barricade(Vector2(-120.0, 285.0), -0.62)

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
	var fill_points := points.duplicate()
	fill_points.remove_at(fill_points.size() - 1)
	draw_colored_polygon(fill_points, _tile_color(cell))
	var color := major_line_color if (cell.x == 0 or cell.y == 0) else line_color
	draw_polyline(points, color, 1.1, true)
	_draw_tile_wear(cell, center)

func _draw_faded_lane(start_cell: Vector2i, end_cell: Vector2i) -> void:
	var start := iso_to_screen(start_cell)
	var finish := iso_to_screen(end_cell)
	draw_dashed_line(
		start,
		finish,
		lane_color,
		2.5,
		18.0,
		true
	)

func _draw_ring_layout() -> void:
	for radius in [128.0, 242.0]:
		draw_arc(
			Vector2.ZERO,
			radius,
			0.0,
			TAU,
			72,
			lane_color,
			3.0,
			true
		)
	for index in range(6):
		var direction := Vector2.RIGHT.rotated(TAU * float(index) / 6.0)
		draw_dashed_line(
			direction * 70.0,
			direction * 430.0,
			Color(lane_color, lane_color.a * 0.86),
			2.0,
			16.0,
			true
		)

func _draw_boundary_markers() -> void:
	for index in range(-grid_radius + 1, grid_radius):
		if index % 2 != 0:
			continue
		var north := iso_to_screen(Vector2i(index, -grid_radius + abs(index)))
		var south := iso_to_screen(Vector2i(index, grid_radius - abs(index)))
		draw_line(north + Vector2(-13.0, 0.0), north + Vector2(13.0, 0.0), hazard_color, 4.0, true)
		draw_line(south + Vector2(-13.0, 0.0), south + Vector2(13.0, 0.0), hazard_color, 4.0, true)

func _draw_tile_wear(cell: Vector2i, center: Vector2) -> void:
	var hash_value: int = absi(cell.x * 19 + cell.y * 31)
	if hash_value % 7 == 0:
		var offset := Vector2(float((hash_value % 5) - 2) * 3.0, float((hash_value % 3) - 1) * 2.0)
		draw_line(
			center + offset + Vector2(-12.0, -2.0),
			center + offset + Vector2(-2.0, 3.0),
			Color(0.04, 0.05, 0.05, 0.56),
			1.5,
			true
		)
		draw_line(
			center + offset + Vector2(-2.0, 3.0),
			center + offset + Vector2(8.0, -1.0),
			Color(0.04, 0.05, 0.05, 0.48),
			1.2,
			true
		)
	if hash_value % 13 == 0:
		draw_circle(center + Vector2(14.0, 4.0), 4.0, Color(0.16, 0.19, 0.14, 0.42))

func _draw_barricade(position: Vector2, angle: float) -> void:
	var direction := Vector2.RIGHT.rotated(angle)
	var normal := direction.orthogonal()
	var offsets: Array[float] = [-18.0, 18.0]
	for offset in offsets:
		var center: Vector2 = position + direction * offset
		draw_line(center - normal * 15.0, center + normal * 15.0, Color(0.08, 0.09, 0.085, 1.0), 9.0, true)
		draw_line(center - normal * 13.0, center + normal * 13.0, hazard_color, 4.0, true)
	draw_line(position - direction * 31.0, position + direction * 31.0, Color(0.24, 0.25, 0.21, 1.0), 6.0, true)
	draw_line(position - direction * 28.0, position + direction * 28.0, Color(0.49, 0.38, 0.17, 0.9), 2.0, true)

func _tile_color(cell: Vector2i) -> Color:
	var variant: int = absi(cell.x * 11 + cell.y * 17) % 5
	var blend := float(variant) * 0.025
	var base_color := (
		alternate_concrete_color
		if layout_kind == &"ring" and (cell.x + cell.y) % 3 == 0
		else concrete_color
	)
	var color := base_color.lightened(blend)
	if (cell.x + cell.y) % 4 == 0:
		color = color.darkened(0.035)
	return color

func iso_to_screen(cell: Vector2i) -> Vector2:
	return Vector2(
		(float(cell.x) - float(cell.y)) * tile_width * 0.5,
		(float(cell.x) + float(cell.y)) * tile_height * 0.5
	)
