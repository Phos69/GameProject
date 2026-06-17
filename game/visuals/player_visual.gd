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
var status_feedback_id: StringName = &""
var status_feedback_timer: float = 0.0
var character_profile: Dictionary = {}
var weapon_attack_type: StringName = &"projectile"
var weapon_trail_style: StringName = &""

func _ready() -> void:
	add_to_group("visual_settings_consumers")
	_sync_visual_settings()
	queue_redraw()

func _process(delta: float) -> void:
	if not reduced_motion:
		animation_time += delta
	fire_flash_timer = maxf(fire_flash_timer - delta, 0.0)
	reload_timer = maxf(reload_timer - delta, 0.0)
	hurt_flash_timer = maxf(hurt_flash_timer - delta, 0.0)
	status_feedback_timer = maxf(status_feedback_timer - delta, 0.0)
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

func _sync_visual_settings() -> void:
	var manager := get_tree().get_first_node_in_group(
		"visual_settings_manager"
	)
	if manager != null and manager.has_method("get_settings_data"):
		apply_visual_settings(manager.get_settings_data())

func set_player_slot(slot: int) -> void:
	player_slot = clampi(slot, 1, 4)
	queue_redraw()

func set_slot_color(color: Color) -> void:
	accent_color = color
	queue_redraw()

func set_character_profile(profile: Dictionary) -> void:
	character_profile = profile.duplicate(true)
	if not character_profile.is_empty():
		accent_color = Color(character_profile.get("palette_primary", accent_color))
	queue_redraw()

func set_weapon_data(weapon_data: WeaponData) -> void:
	weapon_visual_data = (
		weapon_data.visual_data
		if weapon_data != null
		else null
	)
	weapon_attack_type = weapon_data.attack_type if weapon_data != null else &"projectile"
	weapon_trail_style = weapon_data.trail_style if weapon_data != null else &""
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

func play_status_feedback(status_id: StringName) -> void:
	status_feedback_id = BiomeStatusRuntime.canonical_status_id(status_id)
	status_feedback_timer = 0.75 if not reduced_motion else 0.32
	queue_redraw()

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
	status_feedback_timer = 0.0
	status_feedback_id = &""
	queue_redraw()

func _draw() -> void:
	_draw_status_feedback()
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
	var torso_color := Color(character_profile.get("palette_primary", display_color)).darkened(0.10)
	var outfit_secondary := Color(character_profile.get("palette_secondary", display_color.lightened(0.25)))
	var visual_accent := Color(character_profile.get("palette_accent", display_color.lightened(0.20)))
	var character_id := StringName(character_profile.get("id", &""))
	var rpg_component: RpgPlayerComponent = null
	if get_parent() != null:
		rpg_component = get_parent().get_node_or_null("RpgPlayerComponent") as RpgPlayerComponent
	var beast_scale := 1.0
	if rpg_component != null and rpg_component.is_beast_transformed():
		beast_scale = 1.28
	elif rpg_component != null and rpg_component.is_beast_recovering():
		beast_scale = 1.08
	var outline_color := Color(0.035, 0.045, 0.055, 1.0)

	draw_set_transform(Vector2(0.0, -bob), 0.0, Vector2.ONE * beast_scale)
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
	draw_line(Vector2(0.0, -9.0), Vector2(0.0, 11.0), visual_accent, 2.0)
	_draw_character_silhouette_details(character_id, torso_color, outfit_secondary, visual_accent, outline_color)

	draw_circle(Vector2(0.0, -19.0), 9.0, outline_color)
	draw_circle(Vector2(0.0, -20.0), 7.0, outfit_secondary.lightened(0.18))
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
	if _is_melee_weapon_attack() and fire_flash_timer > 0.0:
		hand += weapon_direction * 5.0
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
		if _is_melee_weapon_attack():
			_draw_melee_fire_feedback(
				hand,
				muzzle,
				weapon_direction,
				muzzle_color,
				flash_size
			)
		else:
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
	if rpg_component != null and rpg_component.is_beast_recovering():
		_draw_beast_recovery_marker(visual_accent)
	_draw_slot_marker()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_beast_recovery_marker(color: Color) -> void:
	var alpha := 0.70 * flash_intensity * glow_intensity
	draw_arc(
		Vector2(0.0, -7.0),
		31.0,
		-PI * 0.20,
		PI * 1.20,
		28,
		Color(color.lightened(0.30), alpha),
		3.0,
		true
	)
	draw_line(
		Vector2(-18.0, 18.0),
		Vector2(18.0, 18.0),
		Color(color, alpha * 0.55),
		3.0,
		true
	)

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
		&"rpg_bow":
			var bow_center := hand + direction * length * 0.42
			draw_line(
				bow_center - perpendicular * width * 2.4,
				bow_center + perpendicular * width * 2.4,
				primary,
				width,
				true
			)
			draw_arc(
				bow_center,
				width * 3.3,
				direction.angle() - 0.95,
				direction.angle() + 0.95,
				18,
				secondary,
				2.0,
				true
			)
			draw_line(
				hand,
				muzzle,
				secondary,
				1.6,
				true
			)
		&"rpg_axe":
			draw_line(
				hand - direction * 3.0,
				muzzle,
				primary,
				width * 0.55,
				true
			)
			draw_colored_polygon(
				PackedVector2Array([
					muzzle - direction * 8.0 + perpendicular * width * 1.10,
					muzzle + perpendicular * width * 0.40,
					muzzle - direction * 4.0 - perpendicular * width * 1.15,
					muzzle - direction * 14.0 - perpendicular * width * 0.45,
					muzzle - direction * 10.0 + perpendicular * width * 0.30
				]),
				secondary
			)
		&"rpg_staff":
			draw_line(hand - direction * 4.0, muzzle + direction * 6.0, primary, width * 0.55, true)
			draw_circle(muzzle + direction * 5.0, width * 1.1, glow)
			draw_arc(muzzle + direction * 5.0, width * 1.5, 0.0, TAU, 18, secondary, 2.0, true)
		&"rpg_slingshot":
			var fork := hand + direction * length * 0.55
			draw_line(hand, fork, primary, width * 0.7, true)
			draw_line(fork, muzzle + perpendicular * width, primary, width * 0.45, true)
			draw_line(fork, muzzle - perpendicular * width, primary, width * 0.45, true)
			draw_line(muzzle + perpendicular * width, muzzle - perpendicular * width, secondary, 1.8, true)
		&"rpg_claws":
			for claw_index in range(3):
				var offset := (float(claw_index) - 1.0) * width * 0.45
				draw_line(hand + perpendicular * offset, muzzle + perpendicular * offset + direction * 3.0, secondary, 2.4, true)
		&"rpg_sword":
			draw_line(
				hand - direction * 3.0,
				hand + direction * 7.0,
				primary,
				width * 1.4,
				true
			)
			draw_colored_polygon(
				PackedVector2Array([
					hand + direction * 5.0 + perpendicular * width * 0.34,
					muzzle + perpendicular * width * 0.20,
					muzzle + direction * 5.0,
					muzzle - perpendicular * width * 0.20,
					hand + direction * 5.0 - perpendicular * width * 0.34
				]),
				secondary
			)
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

func _draw_melee_fire_feedback(
	hand: Vector2,
	muzzle: Vector2,
	direction: Vector2,
	color: Color,
	flash_size: float
) -> void:
	var alpha := 0.82 * flash_intensity * glow_intensity
	var perpendicular := direction.orthogonal()
	match weapon_attack_type:
		&"melee_arc":
			var radius := 42.0 + flash_size * 0.42
			var angle := direction.angle()
			var half_angle := 1.02 if weapon_trail_style == &"heavy_arc" else 0.76
			draw_arc(
				Vector2.ZERO,
				radius,
				angle - half_angle,
				angle + half_angle,
				28,
				Color(color, alpha),
				6.0 if weapon_trail_style == &"heavy_arc" else 4.0,
				true
			)
			draw_arc(
				Vector2.ZERO,
				radius * 0.72,
				angle - half_angle * 0.82,
				angle + half_angle * 0.82,
				22,
				Color(color, alpha * 0.32),
				8.0,
				true
			)
		&"melee_rect", &"melee_sweep", &"dash_slash":
			draw_line(
				hand - perpendicular * 8.0,
				muzzle + direction * 14.0 + perpendicular * 11.0,
				Color(color, alpha),
				4.5,
				true
			)
			draw_line(
				hand + perpendicular * 7.0,
				muzzle + direction * 7.0 - perpendicular * 8.0,
				Color(color.lightened(0.18), alpha * 0.55),
				2.5,
				true
			)
		_:
			draw_line(
				hand,
				muzzle + direction * 10.0,
				Color(color, alpha),
				4.0,
				true
			)

func _is_melee_weapon_attack() -> bool:
	return (
		weapon_attack_type == &"melee_arc"
		or weapon_attack_type == &"melee_rect"
		or weapon_attack_type == &"melee_sweep"
		or weapon_attack_type == &"dash_slash"
	)

func _draw_status_feedback() -> void:
	if status_feedback_timer <= 0.0 or status_feedback_id.is_empty():
		return
	var alpha := clampf(status_feedback_timer / 0.75, 0.0, 1.0)
	var color := Color(0.30, 1.0, 0.42, alpha)
	match status_feedback_id:
		&"burn": color = Color(1.0, 0.30, 0.08, alpha)
		&"bleed": color = Color(0.72, 0.02, 0.04, alpha)
		&"freeze": color = Color(0.54, 0.90, 1.0, alpha)
		&"shock": color = Color(1.0, 0.92, 0.14, alpha)
	if high_contrast:
		color = Color.WHITE
	draw_arc(Vector2(0.0, -6.0), 28.0 + 7.0 * alpha, 0.0, TAU, 24, Color(color, 0.66), 3.0, true)
	for index in range(5):
		var angle := TAU * float(index) / 5.0 + animation_time * (0.0 if reduced_motion else 2.0)
		var start := Vector2(cos(angle), sin(angle)) * 18.0
		var end := start + Vector2(cos(angle), sin(angle)) * (8.0 + 5.0 * alpha)
		draw_line(start, end, color, 2.5, true)

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

func _draw_character_silhouette_details(
	character_id: StringName,
	_primary: Color,
	secondary: Color,
	accent: Color,
	outline: Color
) -> void:
	match character_id:
		&"mago":
			draw_colored_polygon(PackedVector2Array([Vector2(-13.0, -12.0), Vector2(13.0, -12.0), Vector2(18.0, 14.0), Vector2(0.0, 22.0), Vector2(-18.0, 14.0)]), secondary.darkened(0.20))
			draw_line(Vector2(14.0, -30.0), Vector2(14.0, 16.0), outline, 5.0, true)
			draw_circle(Vector2(14.0, -31.0), 5.0, accent)
		&"domatrice":
			draw_rect(Rect2(Vector2(-14.0, -13.0), Vector2(9.0, 22.0)), secondary, true)
			draw_line(Vector2(10.0, -7.0), Vector2(19.0, -16.0), outline, 3.0, true)
			draw_line(Vector2(10.0, -7.0), Vector2(20.0, 2.0), outline, 3.0, true)
			draw_circle(Vector2(-8.0, -26.0), 2.0, accent)
		&"licantropo":
			draw_line(Vector2(-16.0, -4.0), Vector2(-25.0, 9.0), accent, 4.0, true)
			draw_line(Vector2(16.0, -4.0), Vector2(25.0, 9.0), accent, 4.0, true)
			draw_arc(Vector2(0.0, -21.0), 10.0, PI * 0.1, PI * 0.9, 12, secondary.lightened(0.35), 2.0, true)
			draw_circle(Vector2(3.0, -21.0), 2.0, accent)
		&"ranger":
			draw_colored_polygon(PackedVector2Array([Vector2(-9.0, -23.0), Vector2(0.0, -34.0), Vector2(10.0, -23.0), Vector2(0.0, -18.0)]), outline)
			draw_line(Vector2(-12.0, -7.0), Vector2(12.0, 12.0), secondary, 3.0, true)
			draw_circle(Vector2(4.0, -21.0), 2.0, accent)
		&"pistoliere":
			draw_rect(Rect2(Vector2(-11.0, -13.0), Vector2(22.0, 9.0)), secondary.darkened(0.15), true)
			draw_line(Vector2(-7.0, -29.0), Vector2(9.0, -27.0), accent, 3.0, true)
			draw_circle(Vector2(12.0, -6.0), 3.0, accent)
		&"berserker":
			draw_line(Vector2(-18.0, -8.0), Vector2(18.0, -8.0), outline, 9.0, true)
			draw_line(Vector2(-15.0, 0.0), Vector2(15.0, 0.0), accent, 3.0, true)
			draw_rect(Rect2(Vector2(-19.0, -14.0), Vector2(10.0, 11.0)), secondary, true)
		&"spadaccino":
			draw_colored_polygon(PackedVector2Array([Vector2(-11.0, -11.0), Vector2(12.0, -8.0), Vector2(9.0, 15.0), Vector2(-3.0, 19.0)]), secondary.darkened(0.08))
			draw_line(Vector2(-13.0, -3.0), Vector2(-18.0, 8.0), accent, 4.0, true)
			draw_line(Vector2(8.0, -25.0), Vector2(19.0, -20.0), accent, 2.5, true)
