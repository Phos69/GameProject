extends Control
class_name RpgHudIcon

var icon_id: StringName = &"survivor"
var accent_color: Color = Color(0.72, 0.84, 0.92, 1.0)
var is_ready: bool = false

func _ready() -> void:
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(32.0, 28.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func set_icon(
	next_icon_id: StringName,
	next_accent_color: Color,
	next_is_ready: bool = false
) -> void:
	if (
		icon_id == next_icon_id
		and accent_color == next_accent_color
		and is_ready == next_is_ready
	):
		return
	icon_id = next_icon_id
	accent_color = next_accent_color
	is_ready = next_is_ready
	queue_redraw()

func _draw() -> void:
	var rect := Rect2(Vector2(1.0, 1.0), size - Vector2(2.0, 2.0))
	var background := Color(0.035, 0.05, 0.06, 0.95)
	var border := Color.WHITE if is_ready else accent_color.darkened(0.10)
	draw_rect(rect, background, true)
	draw_rect(rect, border, false, 2.0)
	if is_ready:
		draw_rect(rect.grow(-3.0), accent_color.lightened(0.25), false, 2.0)

	var center := rect.get_center()
	var primary := accent_color
	var secondary := Color(0.92, 0.96, 1.0, 1.0)
	match icon_id:
		&"ranger", &"arrow_rain":
			_draw_arrow(center, primary, secondary)
		&"pistoliere", &"final_barrage":
			_draw_bullets(center, primary, secondary)
		&"berserker", &"blood_quake":
			_draw_quake(center, primary, secondary)
		&"spadaccino", &"phantom_blade":
			_draw_blade(center, primary, secondary)
		&"mago", &"falling_star", &"arcane_resonance":
			_draw_rune(center, primary, secondary)
		&"domatrice", &"scrap_pack", &"briciola_attack":
			_draw_paw(center, primary, secondary)
		&"licantropo", &"beast_night", &"blood_scent":
			_draw_claw(center, primary, secondary)
		_:
			_draw_survivor(center, primary, secondary)

func _draw_arrow(center: Vector2, primary: Color, secondary: Color) -> void:
	draw_line(center + Vector2(-10.0, 5.0), center + Vector2(9.0, -6.0), primary, 3.0, true)
	draw_colored_polygon(
		PackedVector2Array([
			center + Vector2(7.0, -8.0),
			center + Vector2(12.0, -8.0),
			center + Vector2(9.0, -3.0)
		]),
		secondary
	)
	draw_arc(center + Vector2(-2.0, 0.0), 10.0, -1.1, 1.1, 16, primary.darkened(0.2), 2.0, true)

func _draw_bullets(center: Vector2, primary: Color, secondary: Color) -> void:
	for index in range(3):
		var offset := Vector2(-8.0 + float(index) * 8.0, 0.0)
		draw_circle(center + offset, 4.0, primary)
		draw_circle(center + offset + Vector2(1.0, -1.0), 1.6, secondary)
	draw_line(center + Vector2(-11.0, 8.0), center + Vector2(11.0, 8.0), primary.darkened(0.2), 2.0, true)

func _draw_quake(center: Vector2, primary: Color, secondary: Color) -> void:
	draw_circle(center, 9.0, primary.darkened(0.15))
	draw_arc(center, 12.0, 0.0, TAU, 24, primary, 2.0, true)
	draw_line(center + Vector2(-8.0, 0.0), center + Vector2(-2.0, 7.0), secondary, 2.0, true)
	draw_line(center + Vector2(1.0, -7.0), center + Vector2(8.0, 0.0), secondary, 2.0, true)

func _draw_blade(center: Vector2, primary: Color, secondary: Color) -> void:
	draw_line(center + Vector2(-10.0, 8.0), center + Vector2(10.0, -8.0), secondary, 4.0, true)
	draw_line(center + Vector2(-8.0, 6.0), center + Vector2(-2.0, 11.0), primary, 4.0, true)
	draw_line(center + Vector2(-4.0, 4.0), center + Vector2(8.0, -6.0), primary, 1.5, true)

func _draw_survivor(center: Vector2, primary: Color, secondary: Color) -> void:
	draw_circle(center + Vector2(0.0, -6.0), 5.0, secondary)
	draw_rect(Rect2(center + Vector2(-6.0, -1.0), Vector2(12.0, 10.0)), primary, true)
	draw_line(center + Vector2(-5.0, 4.0), center + Vector2(-10.0, 11.0), primary, 2.0, true)
	draw_line(center + Vector2(5.0, 4.0), center + Vector2(10.0, 11.0), primary, 2.0, true)

func _draw_rune(center: Vector2, primary: Color, secondary: Color) -> void:
	var points := PackedVector2Array([
		center + Vector2(0.0, -11.0),
		center + Vector2(10.0, 7.0),
		center + Vector2(-10.0, 7.0),
		center + Vector2(0.0, -11.0)
	])
	draw_polyline(points, primary, 2.5, true)
	draw_circle(center, 4.5, secondary)
	draw_arc(center, 13.0, 0.0, TAU, 24, primary.darkened(0.15), 2.0, true)

func _draw_paw(center: Vector2, primary: Color, secondary: Color) -> void:
	draw_circle(center + Vector2(0.0, 4.0), 6.0, primary)
	for offset in [Vector2(-7.0, -4.0), Vector2(-2.5, -8.0), Vector2(3.0, -8.0), Vector2(8.0, -4.0)]:
		draw_circle(center + offset, 2.8, secondary)
	draw_line(center + Vector2(-10.0, 9.0), center + Vector2(10.0, 9.0), primary.darkened(0.25), 2.0, true)

func _draw_claw(center: Vector2, primary: Color, secondary: Color) -> void:
	for index in range(3):
		var x_offset := -6.0 + float(index) * 6.0
		draw_line(center + Vector2(x_offset, 9.0), center + Vector2(x_offset + 5.0, -10.0), secondary, 3.0, true)
	draw_arc(center, 12.0, 0.25, PI - 0.25, 18, primary, 2.5, true)
