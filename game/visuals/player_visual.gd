extends Node2D
class_name PlayerVisual

@export var accent_color: Color = Color(0.18, 0.74, 0.95, 1.0)

var facing_direction: Vector2 = Vector2.RIGHT
var movement_ratio: float = 0.0
var animation_time: float = 0.0
var fire_flash_timer: float = 0.0
var reload_timer: float = 0.0
var reload_duration: float = 0.0
var hurt_flash_timer: float = 0.0
var is_dead: bool = false
var is_downed: bool = false
var weapon_visual_data: WeaponVisualData
var player_slot: int = 1
var flash_intensity: float = 1.0
var glow_intensity: float = 1.0
var high_contrast: bool = false
var reduced_motion: bool = false

func _ready() -> void:
	add_to_group("visual_settings_consumers")
	VisualSettingsManager.sync_consumer(self)
	queue_redraw()

func _process(delta: float) -> void:
	if not reduced_motion:
		animation_time += delta
	fire_flash_timer = maxf(fire_flash_timer - delta, 0.0)
	reload_timer = maxf(reload_timer - delta, 0.0)
	hurt_flash_timer = maxf(hurt_flash_timer - delta, 0.0)
	queue_redraw()

func apply_visual_settings(settings: Dictionary) -> void:
	flash_intensity = clampf(
		float(settings.get("flash_intensity", 1.0)),
		0.0,
		1.0
	)
	glow_intensity = clampf(
		float(settings.get("glow_intensity", 1.0)),
		0.0,
		1.0
	)
	high_contrast = bool(settings.get("high_contrast", false))
	reduced_motion = bool(settings.get("reduced_motion", false))
	if reduced_motion:
		animation_time = 0.0
	queue_redraw()

func set_player_slot(slot: int) -> void:
	player_slot = clampi(slot, 1, 4)
	queue_redraw()

func set_slot_color(color: Color) -> void:
	accent_color = color
	queue_redraw()

func set_weapon_data(weapon_data: WeaponData) -> void:
	weapon_visual_data = (
		weapon_data.visual_data
		if weapon_data != null
		else null
	)
	queue_redraw()

func get_weapon_profile_id() -> StringName:
	return (
		weapon_visual_data.profile_id
		if weapon_visual_data != null
		else &"weapon"
	)

func set_motion(current_velocity: Vector2, max_speed: float) -> void:
	movement_ratio = clampf(
		current_velocity.length() / maxf(max_speed, 1.0),
		0.0,
		1.0
	)

func set_facing(direction: Vector2) -> void:
	if direction.length_squared() > 0.01:
		facing_direction = direction.normalized()

func play_fire() -> void:
	fire_flash_timer = 0.09

func play_reload(duration: float) -> void:
	reload_duration = maxf(duration, 0.01)
	reload_timer = reload_duration

func play_hurt() -> void:
	hurt_flash_timer = 0.12

func play_dead() -> void:
	is_dead = true
	is_downed = false
	queue_redraw()

func play_downed() -> void:
	is_downed = true
	is_dead = false
	queue_redraw()

func reset_visual() -> void:
	is_dead = false
	is_downed = false
	fire_flash_timer = 0.0
	reload_timer = 0.0
	hurt_flash_timer = 0.0
	queue_redraw()

func _draw() -> void:
	var display_color := accent_color
	if hurt_flash_timer > 0.0:
		display_color = display_color.lerp(
			Color(1.0, 0.92, 0.82, 1.0),
			flash_intensity
		)
	if is_dead or is_downed:
		_draw_dead_survivor(
			display_color if is_downed else display_color.darkened(0.45)
		)
		return

	var walk_phase := sin(animation_time * 11.0) * movement_ratio
	var bob := absf(sin(animation_time * 11.0)) * movement_ratio * 2.0
	var side := 1.0 if facing_direction.x >= 0.0 else -1.0
	var weapon_direction := facing_direction.normalized()
	var torso_color := display_color.darkened(0.18)
	var outline_color := Color(0.035, 0.045, 0.055, 1.0)

	draw_set_transform(Vector2(0.0, -bob), 0.0, Vector2.ONE)
	draw_colored_polygon(
		_ellipse_points(Vector2(0.0, 17.0 + bob), Vector2(22.0, 8.0), 18),
		Color(0.01, 0.015, 0.02, 0.48)
	)
	_draw_leg(Vector2(-7.0, 8.0), walk_phase * 5.0, outline_color)
	_draw_leg(Vector2(7.0, 8.0), -walk_phase * 5.0, outline_color)

	var torso := PackedVector2Array([
		Vector2(-14.0, -12.0),
		Vector2(13.0, -12.0),
		Vector2(16.0, 10.0),
		Vector2(0.0, 17.0),
		Vector2(-16.0, 10.0)
	])
	draw_colored_polygon(torso, outline_color)
	var jacket := PackedVector2Array([
		Vector2(-11.0, -10.0),
		Vector2(10.0, -10.0),
		Vector2(12.0, 8.0),
		Vector2(0.0, 13.0),
		Vector2(-12.0, 8.0)
	])
	draw_colored_polygon(jacket, torso_color)
	draw_line(Vector2(0.0, -9.0), Vector2(0.0, 11.0), display_color.lightened(0.2), 2.0)

	draw_circle(Vector2(0.0, -19.0), 9.0, outline_color)
	draw_circle(Vector2(0.0, -20.0), 7.0, Color(0.86, 0.67, 0.49, 1.0))
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(-8.0, -23.0),
			Vector2(-4.0, -29.0),
			Vector2(7.0, -26.0),
			Vector2(8.0, -20.0),
			Vector2(2.0, -23.0)
		]),
		outline_color
	)

	var shoulder := Vector2(side * 8.0, -7.0)
	var hand := weapon_direction * 15.0 + Vector2(0.0, -4.0)
	draw_line(shoulder, hand, Color(0.82, 0.61, 0.44, 1.0), 5.0, true)
	draw_line(-shoulder, hand * 0.72, Color(0.82, 0.61, 0.44, 1.0), 4.0, true)
	var muzzle := _draw_weapon(hand, weapon_direction, display_color)

	if fire_flash_timer > 0.0:
		var muzzle_color := (
			weapon_visual_data.muzzle_color
			if weapon_visual_data != null
			else Color(1.0, 0.78, 0.24, 0.95)
		)
		var base_flash_size := (
			weapon_visual_data.muzzle_size
			if weapon_visual_data != null
			else 6.0
		)
		var flash_size := (
			base_flash_size + fire_flash_timer * 45.0
		) * maxf(flash_intensity, 0.1)
		draw_colored_polygon(
			PackedVector2Array([
				muzzle + weapon_direction * flash_size,
				muzzle + weapon_direction.orthogonal() * 4.0,
				muzzle - weapon_direction.orthogonal() * 4.0
			]),
			Color(
				muzzle_color,
				0.95 * flash_intensity * glow_intensity
			)
		)

	if reload_timer > 0.0:
		var reload_ratio := 1.0 - reload_timer / reload_duration
		draw_arc(
			Vector2(0.0, -34.0),
			11.0,
			-PI * 0.5,
			-PI * 0.5 + TAU * reload_ratio,
			20,
			Color(1.0, 0.79, 0.28, 0.95),
			3.0,
			true
		)
	_draw_slot_marker()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_slot_marker() -> void:
	var center := Vector2(0.0, -39.0)
	var outline := Color(0.01, 0.015, 0.02, 1.0)
	var fill := Color.WHITE if high_contrast else accent_color.lightened(0.28)
	match player_slot:
		2:
			var triangle := PackedVector2Array([
				center + Vector2(0.0, -6.0),
				center + Vector2(6.0, 5.0),
				center + Vector2(-6.0, 5.0),
				center + Vector2(0.0, -6.0)
			])
			draw_polyline(triangle, outline, 6.0, true)
			draw_polyline(triangle, fill, 2.5, true)
		3:
			draw_rect(Rect2(center - Vector2(5.0, 5.0), Vector2(10.0, 10.0)), outline, false, 6.0)
			draw_rect(Rect2(center - Vector2(5.0, 5.0), Vector2(10.0, 10.0)), fill, false, 2.5)
		4:
			var diamond := PackedVector2Array([
				center + Vector2(0.0, -7.0),
				center + Vector2(7.0, 0.0),
				center + Vector2(0.0, 7.0),
				center + Vector2(-7.0, 0.0),
				center + Vector2(0.0, -7.0)
			])
			draw_polyline(diamond, outline, 6.0, true)
			draw_polyline(diamond, fill, 2.5, true)
		_:
			draw_arc(center, 6.0, 0.0, TAU, 18, outline, 6.0, true)
			draw_arc(center, 6.0, 0.0, TAU, 18, fill, 2.5, true)

func _draw_weapon(
	hand: Vector2,
	direction: Vector2,
	fallback_color: Color
) -> Vector2:
	var profile_id := get_weapon_profile_id()
	var primary := Color(0.10, 0.13, 0.16, 1.0)
	var secondary := fallback_color.lightened(0.1)
	var glow := Color(secondary, 0.35)
	var length := 24.0
	var width := 6.0
	if weapon_visual_data != null:
		primary = weapon_visual_data.primary_color
		secondary = weapon_visual_data.secondary_color
		glow = weapon_visual_data.glow_color
		length = weapon_visual_data.weapon_length
		width = weapon_visual_data.weapon_width

	var perpendicular := direction.orthogonal()
	var muzzle := hand + direction * length
	match profile_id:
		&"prototype_blaster", &"rift_repeater":
			var rear := hand - direction * 3.0
			draw_colored_polygon(
				PackedVector2Array([
					rear + perpendicular * width * 0.65,
					hand + direction * (length * 0.72) + perpendicular * width,
					muzzle + perpendicular * width * 0.42,
					muzzle - perpendicular * width * 0.42,
					hand + direction * (length * 0.72) - perpendicular * width,
					rear - perpendicular * width * 0.65
				]),
				primary
			)
			draw_line(
				hand + perpendicular * width * 0.58,
				muzzle + perpendicular * width * 0.38,
				secondary,
				3.0,
				true
			)
			draw_line(
				hand - perpendicular * width * 0.58,
				muzzle - perpendicular * width * 0.38,
				secondary,
				3.0,
				true
			)
			draw_circle(
				hand + direction * length * 0.45,
				width * 0.42,
				glow
			)
		&"wave_cannon":
			draw_colored_polygon(
				PackedVector2Array([
					hand - direction * 5.0 + perpendicular * width * 0.52,
					hand + direction * length * 0.56 + perpendicular * width,
					muzzle + perpendicular * width * 0.48,
					muzzle - perpendicular * width * 0.48,
					hand + direction * length * 0.56 - perpendicular * width,
					hand - direction * 5.0 - perpendicular * width * 0.52
				]),
				primary
			)
			var core := hand + direction * length * 0.48
			draw_circle(core, width * 0.62, glow)
			draw_arc(
				core,
				width * 0.56,
				0.0,
				TAU,
				16,
				secondary,
				3.0,
				true
			)
			draw_line(
				hand + direction * length * 0.66,
				muzzle,
				secondary,
				5.0,
				true
			)
		_:
			draw_colored_polygon(
				PackedVector2Array([
					hand + perpendicular * width * 0.5,
					muzzle + perpendicular * width * 0.42,
					muzzle - perpendicular * width * 0.42,
					hand - perpendicular * width * 0.5
				]),
				primary
			)
			draw_line(
				hand + direction * 2.0,
				muzzle - direction * 2.0,
				secondary,
				2.5,
				true
			)
			draw_line(
				hand + direction * 3.0,
				hand - direction * 2.0 - perpendicular * 7.0,
				primary.darkened(0.2),
				4.0,
				true
			)
	return muzzle

func _draw_leg(origin: Vector2, stride: float, color: Color) -> void:
	var foot := origin + Vector2(stride, 12.0)
	draw_line(origin, foot, color, 7.0, true)
	draw_circle(foot + Vector2(2.0 if stride >= 0.0 else -2.0, 1.0), 4.0, color)

func _draw_dead_survivor(display_color: Color) -> void:
	draw_colored_polygon(
		_ellipse_points(Vector2(0.0, 8.0), Vector2(25.0, 9.0), 18),
		Color(0.01, 0.015, 0.02, 0.52)
	)
	draw_line(Vector2(-15.0, 2.0), Vector2(13.0, 8.0), display_color.darkened(0.58), 13.0, true)
	draw_circle(Vector2(16.0, 9.0), 7.0, Color(0.32, 0.29, 0.27, 1.0))
	draw_line(Vector2(-5.0, 5.0), Vector2(-20.0, 15.0), Color(0.12, 0.14, 0.16, 1.0), 5.0, true)

func _ellipse_points(center: Vector2, radius: Vector2, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(segments):
		var angle := TAU * float(index) / float(segments)
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	return points
