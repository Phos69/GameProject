extends Control
class_name WeaponIcon

const WEAPON_VISUAL_RENDERER := preload("res://game/weapons/weapon_visual_renderer.gd")

var visual_data: WeaponVisualData

func _ready() -> void:
	custom_minimum_size = Vector2(38.0, 24.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func set_visual_data(data: WeaponVisualData) -> void:
	if visual_data == data:
		return
	visual_data = data
	queue_redraw()

func get_profile_id() -> StringName:
	return visual_data.profile_id if visual_data != null else &"weapon"

func get_hud_shape_id() -> StringName:
	return WEAPON_VISUAL_RENDERER.get_shape_id(
		visual_data,
		WEAPON_VISUAL_RENDERER.TARGET_HUD
	)

func get_hud_body_polygon() -> PackedVector2Array:
	return WEAPON_VISUAL_RENDERER.get_weapon_body_polygon(
		visual_data,
		WEAPON_VISUAL_RENDERER.TARGET_HUD
	)

func _draw() -> void:
	var primary := Color(0.18, 0.22, 0.26, 1.0)
	var secondary := Color(1.0, 0.72, 0.24, 1.0)
	var outline := primary.darkened(0.45)
	if visual_data != null:
		primary = visual_data.primary_color
		secondary = visual_data.secondary_color
		outline = WEAPON_VISUAL_RENDERER.get_outline_color(visual_data)
		if outline.a <= 0.01:
			outline = primary.darkened(0.45)

	var source_body := get_hud_body_polygon()
	if source_body.size() < 3:
		return
	var source_bounds := _polygon_bounds(source_body)
	var target_rect := _content_rect()
	var body := _fit_polygon(source_body, source_bounds, target_rect)
	draw_colored_polygon(body, primary)
	draw_polyline(_closed_polygon(body), outline, 1.4, true)
	for line in WEAPON_VISUAL_RENDERER.get_weapon_detail_lines(
		visual_data,
		WEAPON_VISUAL_RENDERER.TARGET_HUD
	):
		draw_polyline(
			_fit_polygon(line, source_bounds, target_rect),
			secondary,
			1.6,
			true
		)

func _content_rect() -> Rect2:
	var draw_size := Vector2(
		maxf(size.x, custom_minimum_size.x),
		maxf(size.y, custom_minimum_size.y)
	)
	return Rect2(Vector2(2.0, 2.0), draw_size - Vector2(4.0, 4.0))

func _polygon_bounds(points: PackedVector2Array) -> Rect2:
	if points.is_empty():
		return Rect2()
	var min_position := points[0]
	var max_position := points[0]
	for point in points:
		min_position.x = minf(min_position.x, point.x)
		min_position.y = minf(min_position.y, point.y)
		max_position.x = maxf(max_position.x, point.x)
		max_position.y = maxf(max_position.y, point.y)
	return Rect2(min_position, max_position - min_position)

func _fit_polygon(
	points: PackedVector2Array,
	source_bounds: Rect2,
	target_rect: Rect2
) -> PackedVector2Array:
	var fitted := PackedVector2Array()
	if points.is_empty():
		return fitted
	var bounds_size := Vector2(
		maxf(source_bounds.size.x, 0.001),
		maxf(source_bounds.size.y, 0.001)
	)
	var scale_factor := minf(
		target_rect.size.x / bounds_size.x,
		target_rect.size.y / bounds_size.y
	)
	var source_center := source_bounds.position + source_bounds.size * 0.5
	var target_center := target_rect.position + target_rect.size * 0.5
	for point in points:
		fitted.append(target_center + (point - source_center) * scale_factor)
	return fitted

func _closed_polygon(points: PackedVector2Array) -> PackedVector2Array:
	var closed := PackedVector2Array(points)
	if not closed.is_empty():
		closed.append(closed[0])
	return closed
