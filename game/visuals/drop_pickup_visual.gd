extends Node2D
class_name DropPickupVisual

const WEAPON_VISUAL_RENDERER := preload("res://game/weapons/weapon_visual_renderer.gd")

var drop_type: StringName = &"unknown"
var weapon_visual_data: WeaponVisualData
var accent_color: Color = Color(0.72, 0.76, 0.80, 1.0)
var animation_time: float = 0.0
var high_contrast: bool = false
var reduced_motion: bool = false
var missing_weapon_visual: bool = false

func _ready() -> void:
	add_to_group("visual_settings_consumers")
	VisualSettingsManager.sync_consumer(self)

func _process(delta: float) -> void:
	if not reduced_motion:
		animation_time += delta
	queue_redraw()

func apply_visual_settings(settings: Dictionary) -> void:
	high_contrast = bool(settings.get("high_contrast", false))
	reduced_motion = bool(settings.get("reduced_motion", false))
	if reduced_motion:
		animation_time = 0.0
	queue_redraw()

func configure(
	value: StringName,
	visual_data: WeaponVisualData = null
) -> void:
	drop_type = value
	weapon_visual_data = visual_data if drop_type == GameConstants.DROP_WEAPON else null
	missing_weapon_visual = (
		drop_type == GameConstants.DROP_WEAPON
		and not WEAPON_VISUAL_RENDERER.has_pickup_visual(weapon_visual_data)
	)
	accent_color = _color_for_type(drop_type)
	if drop_type == GameConstants.DROP_WEAPON and weapon_visual_data != null:
		accent_color = weapon_visual_data.secondary_color
	elif missing_weapon_visual:
		accent_color = Color(1.0, 0.82, 0.12, 1.0)
	queue_redraw()

func get_weapon_pickup_shape_id() -> StringName:
	if drop_type != GameConstants.DROP_WEAPON:
		return &""
	return WEAPON_VISUAL_RENDERER.get_pickup_shape_id(weapon_visual_data)

func get_weapon_pickup_body_polygon() -> PackedVector2Array:
	if drop_type != GameConstants.DROP_WEAPON:
		return PackedVector2Array()
	return WEAPON_VISUAL_RENDERER.get_pickup_body_polygon(weapon_visual_data)

func uses_missing_weapon_visual() -> bool:
	return missing_weapon_visual

func _draw() -> void:
	var bob := sin(animation_time * 4.0) * 2.5
	var pulse := 1.0 + sin(animation_time * 5.0) * 0.04
	draw_colored_polygon(
		_ellipse_points(Vector2(0.0, 13.0), Vector2(15.0, 5.0), 16),
		Color(0.01, 0.015, 0.02, 0.45)
	)
	draw_set_transform(Vector2(0.0, bob), 0.0, Vector2(pulse, pulse))
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(0.0, -17.0),
			Vector2(16.0, -4.0),
			Vector2(13.0, 13.0),
			Vector2(-13.0, 13.0),
			Vector2(-16.0, -4.0)
		]),
		Color(0.035, 0.05, 0.065, 0.98)
	)
	# Per i pickup arma leggibili il contenitore resta un fondale: bordo
	# attenuato, la silhouette dell'arma deve dominare (VIS-011).
	var weapon_focus := (
		drop_type == GameConstants.DROP_WEAPON
		and not missing_weapon_visual
		and not high_contrast
	)
	draw_polyline(
		PackedVector2Array([
			Vector2(0.0, -17.0),
			Vector2(16.0, -4.0),
			Vector2(13.0, 13.0),
			Vector2(-13.0, 13.0),
			Vector2(-16.0, -4.0),
			Vector2(0.0, -17.0)
		]),
		Color(accent_color, 0.42) if weapon_focus
			else (Color.WHITE if high_contrast else accent_color),
		1.6 if weapon_focus else (3.5 if high_contrast else 2.5),
		true
	)
	_draw_icon()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_icon() -> void:
	match drop_type:
		GameConstants.DROP_EXPERIENCE:
			draw_colored_polygon(
				PackedVector2Array([
					Vector2(0.0, -11.0),
					Vector2(7.0, 0.0),
					Vector2(0.0, 10.0),
					Vector2(-7.0, 0.0)
				]),
				accent_color
			)
			draw_line(Vector2(-9.0, -5.0), Vector2(-4.0, -2.0), accent_color.lightened(0.3), 2.0)
			draw_line(Vector2(7.0, 5.0), Vector2(11.0, 2.0), accent_color.lightened(0.3), 2.0)
		GameConstants.DROP_MONEY:
			draw_circle(Vector2.ZERO, 9.0, accent_color.darkened(0.25))
			draw_arc(Vector2.ZERO, 7.0, 0.0, TAU, 20, accent_color, 2.0, true)
			draw_line(Vector2(-3.0, -4.0), Vector2(3.0, -4.0), accent_color.lightened(0.35), 2.0)
			draw_line(Vector2(-3.0, 0.0), Vector2(4.0, 0.0), accent_color.lightened(0.35), 2.0)
			draw_line(Vector2(-3.0, 4.0), Vector2(3.0, 4.0), accent_color.lightened(0.35), 2.0)
		GameConstants.DROP_AMMO:
			draw_rect(Rect2(-9.0, -8.0, 18.0, 16.0), accent_color.darkened(0.25), true)
			for index in range(3):
				var x := -6.0 + float(index) * 6.0
				draw_line(Vector2(x, -6.0), Vector2(x, 4.0), accent_color.lightened(0.25), 3.0, true)
				draw_circle(Vector2(x, -6.0), 1.6, accent_color.lightened(0.4))
		GameConstants.DROP_HEALTH:
			draw_rect(Rect2(-9.0, -7.0, 18.0, 14.0), accent_color.darkened(0.28), true)
			draw_rect(Rect2(-2.5, -9.0, 5.0, 18.0), Color.WHITE, true)
			draw_rect(Rect2(-8.0, -2.5, 16.0, 5.0), Color.WHITE, true)
		GameConstants.DROP_WEAPON:
			_draw_weapon_pickup_icon()
		_:
			draw_circle(Vector2.ZERO, 7.0, accent_color)

func _draw_weapon_pickup_icon() -> void:
	var body := WEAPON_VISUAL_RENDERER.get_pickup_body_polygon(weapon_visual_data)
	var primary := Color(0.12, 0.15, 0.18, 1.0)
	var secondary := accent_color
	var glow := Color(accent_color, 0.28)
	var outline := Color(0.94, 0.98, 1.0, 0.92)
	var rarity_glow := 0.0
	if weapon_visual_data != null:
		primary = weapon_visual_data.primary_color
		secondary = weapon_visual_data.secondary_color
		glow = weapon_visual_data.glow_color
		outline = WEAPON_VISUAL_RENDERER.get_outline_color(weapon_visual_data)
		if outline.a <= 0.01:
			outline = primary.darkened(0.55)
		rarity_glow = weapon_visual_data.rarity_glow
	if missing_weapon_visual:
		primary = Color(0.18, 0.02, 0.16, 1.0)
		secondary = Color(1.0, 0.82, 0.12, 1.0)
		glow = Color(1.0, 0.18, 0.75, 0.34)
		outline = Color(1.0, 0.95, 0.15, 1.0)
		rarity_glow = 0.45
	if high_contrast:
		primary = Color(0.02, 0.02, 0.025, 1.0)
		secondary = Color.WHITE
		outline = Color.WHITE
		glow = Color(1.0, 1.0, 1.0, 0.18)

	if rarity_glow > 0.0:
		draw_colored_polygon(
			WEAPON_VISUAL_RENDERER.expand_polygon(body, 1.42),
			Color(glow, minf(0.28, 0.08 + rarity_glow * 0.34))
		)
	draw_colored_polygon(body, primary)
	draw_polyline(
		_closed_polygon(body),
		outline,
		3.2 if high_contrast or missing_weapon_visual else 2.0,
		true
	)
	for line in WEAPON_VISUAL_RENDERER.get_pickup_detail_lines(weapon_visual_data):
		draw_polyline(
			line,
			secondary,
			2.8 if high_contrast else 2.0,
			true
		)

func _color_for_type(value: StringName) -> Color:
	match value:
		GameConstants.DROP_EXPERIENCE:
			return Color(0.32, 0.72, 1.0, 1.0)
		GameConstants.DROP_MONEY:
			return Color(1.0, 0.76, 0.18, 1.0)
		GameConstants.DROP_AMMO:
			return Color(1.0, 0.42, 0.16, 1.0)
		GameConstants.DROP_HEALTH:
			return Color(0.30, 0.92, 0.48, 1.0)
		GameConstants.DROP_WEAPON:
			return Color(0.76, 0.38, 1.0, 1.0)
		_:
			return Color(0.72, 0.76, 0.80, 1.0)

func _ellipse_points(center: Vector2, radius: Vector2, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(segments):
		var angle := TAU * float(index) / float(segments)
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	return points

func _closed_polygon(points: PackedVector2Array) -> PackedVector2Array:
	var closed := PackedVector2Array(points)
	if not closed.is_empty():
		closed.append(closed[0])
	return closed
