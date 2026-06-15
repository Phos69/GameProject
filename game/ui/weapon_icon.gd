extends Control
class_name WeaponIcon

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

func _draw() -> void:
	var profile_id := get_profile_id()
	var primary := Color(0.18, 0.22, 0.26, 1.0)
	var secondary := Color(1.0, 0.72, 0.24, 1.0)
	if visual_data != null:
		primary = visual_data.primary_color
		secondary = visual_data.secondary_color
	var center := Vector2(17.0, 12.0)
	match profile_id:
		&"rpg_bow":
			draw_arc(center, 15.0, -0.85, 0.85, 16, primary, 3.0, true)
			draw_line(
				center + Vector2(9.0, -11.0),
				center + Vector2(9.0, 11.0),
				secondary,
				1.7,
				true
			)
			draw_line(
				center + Vector2(-13.0, 0.0),
				center + Vector2(15.0, 0.0),
				secondary,
				2.0,
				true
			)
		&"rpg_axe":
			draw_line(
				center + Vector2(-13.0, 8.0),
				center + Vector2(10.0, -8.0),
				primary,
				4.0,
				true
			)
			draw_colored_polygon(
				PackedVector2Array([
					center + Vector2(6.0, -11.0),
					center + Vector2(17.0, -7.0),
					center + Vector2(15.0, 4.0),
					center + Vector2(5.0, 6.0),
					center + Vector2(9.0, -2.0)
				]),
				secondary
			)
		&"rpg_sword":
			draw_line(
				center + Vector2(-12.0, 8.0),
				center + Vector2(14.0, -8.0),
				secondary,
				4.0,
				true
			)
			draw_line(
				center + Vector2(-6.0, 4.0),
				center + Vector2(-1.0, 11.0),
				primary,
				4.0,
				true
			)
			draw_line(
				center + Vector2(-9.0, 3.0),
				center + Vector2(-2.0, -2.0),
				primary,
				3.0,
				true
			)
		&"prototype_blaster", &"rift_repeater":
			draw_colored_polygon(
				PackedVector2Array([
					center + Vector2(-14.0, -5.0),
					center + Vector2(10.0, -7.0),
					center + Vector2(16.0, -3.0),
					center + Vector2(16.0, 3.0),
					center + Vector2(10.0, 7.0),
					center + Vector2(-14.0, 5.0)
				]),
				primary
			)
			draw_line(
				center + Vector2(-7.0, -3.0),
				center + Vector2(14.0, -3.0),
				secondary,
				2.0,
				true
			)
			draw_line(
				center + Vector2(-7.0, 3.0),
				center + Vector2(14.0, 3.0),
				secondary,
				2.0,
				true
			)
		&"wave_cannon":
			draw_colored_polygon(
				PackedVector2Array([
					center + Vector2(-15.0, -6.0),
					center + Vector2(7.0, -9.0),
					center + Vector2(17.0, -5.0),
					center + Vector2(17.0, 5.0),
					center + Vector2(7.0, 9.0),
					center + Vector2(-15.0, 6.0)
				]),
				primary
			)
			draw_circle(center + Vector2(1.0, 0.0), 5.0, secondary)
			draw_line(
				center + Vector2(5.0, 0.0),
				center + Vector2(17.0, 0.0),
				secondary,
				3.0,
				true
			)
		_:
			draw_colored_polygon(
				PackedVector2Array([
					center + Vector2(-13.0, -4.0),
					center + Vector2(15.0, -4.0),
					center + Vector2(15.0, 3.0),
					center + Vector2(-13.0, 3.0)
				]),
				primary
			)
			draw_line(
				center + Vector2(-3.0, 2.0),
				center + Vector2(-7.0, 9.0),
				primary.darkened(0.25),
				4.0,
				true
			)
			draw_line(
				center + Vector2(-8.0, -1.0),
				center + Vector2(13.0, -1.0),
				secondary,
				2.0,
				true
			)
