extends Node2D
class_name BiomeRegionGround

var layout: BiomeEnvironmentLayout
var palette: BiomePalette
var sample_step: int = 8
var base_seed: int = 0

func configure(
	next_layout: BiomeEnvironmentLayout,
	next_palette: BiomePalette,
	next_sample_step: int = 8
) -> void:
	layout = next_layout
	palette = next_palette
	sample_step = clampi(next_sample_step, 2, 32)
	base_seed = layout.generation_seed if layout != null else 0
	z_index = -9
	queue_redraw()

func get_sample_step() -> int:
	return sample_step

func _draw() -> void:
	if layout == null or palette == null:
		return
	for y in range(0, layout.zone_size.y, sample_step):
		for x in range(0, layout.zone_size.x, sample_step):
			_draw_sample_tile(Vector2i(x, y))

func _draw_sample_tile(cell: Vector2i) -> void:
	var center := layout.logical_to_world(cell + Vector2i(sample_step / 2, sample_step / 2))
	var scale := layout.logical_tile_scale * float(sample_step)
	var half_w := scale * 0.62
	var half_h := scale * 0.34
	var points := PackedVector2Array([
		center + Vector2(0.0, -half_h),
		center + Vector2(half_w, 0.0),
		center + Vector2(0.0, half_h),
		center + Vector2(-half_w, 0.0)
	])
	draw_colored_polygon(points, _tile_color(cell))
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, Color(palette.grid_color, 0.22), 1.0, true)

func _tile_color(cell: Vector2i) -> Color:
	var terrain_class := layout.get_terrain_class_at_cell(cell)
	match terrain_class:
		BiomeEnvironmentLayout.TERRAIN_FALL_ZONE:
			return palette.background_color.darkened(0.55)
		BiomeEnvironmentLayout.TERRAIN_HAZARD:
			return Color(palette.hazard_color, 0.54)
		BiomeEnvironmentLayout.TERRAIN_OBSTACLE:
			return palette.prop_color.darkened(0.24)
		BiomeEnvironmentLayout.TERRAIN_BORDER:
			return palette.floor_color.darkened(0.22)
		_:
			var hash_value := absi(base_seed + cell.x * 19 + cell.y * 31)
			var color := palette.floor_color
			if hash_value % 3 == 0:
				color = palette.alternate_floor_color
			if hash_value % 5 == 0:
				color = color.darkened(0.04)
			elif hash_value % 7 == 0:
				color = color.lightened(0.035)
			return color
