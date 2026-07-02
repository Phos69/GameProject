extends Node2D
class_name ZombieVisual

@export_enum("basic", "runner", "tank", "shooter") var archetype_id: String = "basic"

var facing_direction: Vector2 = Vector2.LEFT
var movement_ratio: float = 0.0
var animation_time: float = 0.0
var hit_flash_timer: float = 0.0
var current_state: StringName = &"idle"
var flash_intensity: float = 1.0
var reduced_motion: bool = false
var biome_theme_id: StringName = &""
var _screen_notifier: VisibleOnScreenNotifier2D

func _ready() -> void:
	add_to_group("visual_settings_consumers")
	VisualSettingsManager.sync_consumer(self)
	# Ridisegnare ~20 primitive antialiased per mob a ogni frame costa ~60µs
	# CPU + ~60µs GPU (misura P4 in tests/suites/soak/perf_bottleneck_stress_
	# test.gd): fuori dalla camera il re-record e' lavoro inutile, quindi il
	# redraw e' sospeso; animation_time continua ad avanzare, al rientro la
	# posa riparte coerente.
	_screen_notifier = VisibleOnScreenNotifier2D.new()
	_update_notifier_rect()
	add_child(_screen_notifier)

func apply_visual_settings(settings: Dictionary) -> void:
	flash_intensity = clampf(
		float(settings.get("flash_intensity", 1.0)),
		0.0,
		1.0
	)
	reduced_motion = bool(settings.get("reduced_motion", false))
	if reduced_motion:
		animation_time = 0.0
	queue_redraw()

func _process(delta: float) -> void:
	if not reduced_motion:
		animation_time += delta
	hit_flash_timer = maxf(hit_flash_timer - delta, 0.0)
	if _screen_notifier == null or _screen_notifier.is_on_screen():
		queue_redraw()

func set_motion(current_velocity: Vector2, max_speed: float) -> void:
	movement_ratio = clampf(
		current_velocity.length() / maxf(max_speed, 1.0),
		0.0,
		1.0
	)
	if current_velocity.length_squared() > 1.0:
		facing_direction = current_velocity.normalized()

func set_facing(direction: Vector2) -> void:
	if direction.length_squared() > 0.01:
		facing_direction = direction.normalized()

func set_state(state_name: StringName) -> void:
	current_state = state_name

func play_hit() -> void:
	hit_flash_timer = 0.12

func configure_biome_style(
	next_archetype_id: String,
	next_theme_id: StringName
) -> void:
	archetype_id = next_archetype_id
	biome_theme_id = next_theme_id
	_update_notifier_rect()
	queue_redraw()

func _update_notifier_rect() -> void:
	if _screen_notifier == null:
		return
	# Silhouette + margine per braccia/telegrafi; l'aura del tema biome arriva
	# a ~0.62 * larghezza di raggio, il margine la copre.
	var size := get_silhouette_size()
	var margin := Vector2(28.0, 28.0)
	_screen_notifier.rect = Rect2(-size * 0.5 - margin, size + margin * 2.0)

func get_silhouette_size() -> Vector2:
	match archetype_id:
		"runner":
			return Vector2(31.0, 50.0)
		"tank":
			return Vector2(68.0, 66.0)
		"shooter":
			return Vector2(42.0, 66.0)
		_:
			return Vector2(46.0, 52.0)

func _draw() -> void:
	_draw_biome_theme()
	match archetype_id:
		"runner":
			_draw_runner()
		"tank":
			_draw_tank()
		"shooter":
			_draw_shooter()
		_:
			_draw_basic()

func _draw_biome_theme() -> void:
	if biome_theme_id.is_empty():
		return
	var color := Color(0.55, 0.82, 0.34, 0.72)
	match biome_theme_id:
		&"toxic":
			color = Color(0.30, 1.0, 0.42, 0.78)
		&"fire":
			color = Color(1.0, 0.30, 0.08, 0.82)
		&"frost":
			color = Color(0.54, 0.90, 1.0, 0.82)
		&"marsh":
			color = Color(0.18, 0.68, 0.64, 0.78)
	draw_arc(
		Vector2(0.0, 10.0),
		get_silhouette_size().x * 0.62,
		0.0,
		TAU,
		24,
		Color(color, 0.34),
		3.0,
		true
	)
	for index in range(3):
		var direction := Vector2.UP.rotated(
			(float(index) - 1.0) * 0.55
		)
		draw_line(
			Vector2(0.0, -4.0),
			direction * (18.0 + float(index % 2) * 5.0),
			Color(color, 0.62),
			2.5,
			true
		)

func _draw_basic() -> void:
	var walk_phase := sin(animation_time * 8.0) * movement_ratio
	var lurch := sin(animation_time * 4.0) * 1.5
	var skin_color := Color(0.48, 0.66, 0.35, 1.0)
	var shirt_color := Color(0.27, 0.34, 0.31, 1.0)
	if hit_flash_timer > 0.0:
		skin_color = skin_color.lerp(
			Color(0.98, 0.78, 0.64, 1.0),
			flash_intensity
		)
		shirt_color = shirt_color.lerp(
			Color(0.72, 0.30, 0.25, 1.0),
			flash_intensity
		)

	draw_colored_polygon(
		_ellipse_points(Vector2(0.0, 18.0), Vector2(23.0, 8.0), 18),
		Color(0.01, 0.015, 0.015, 0.5)
	)
	draw_line(Vector2(-7.0, 9.0), Vector2(-9.0 + walk_phase * 4.0, 22.0), Color(0.11, 0.14, 0.13, 1.0), 7.0, true)
	draw_line(Vector2(7.0, 9.0), Vector2(9.0 - walk_phase * 4.0, 22.0), Color(0.11, 0.14, 0.13, 1.0), 7.0, true)

	var torso := PackedVector2Array([
		Vector2(-15.0, -12.0 + lurch),
		Vector2(12.0, -9.0 + lurch),
		Vector2(16.0, 10.0),
		Vector2(2.0, 17.0),
		Vector2(-15.0, 10.0)
	])
	draw_colored_polygon(torso, Color(0.04, 0.055, 0.05, 1.0))
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(-12.0, -10.0 + lurch),
			Vector2(9.0, -7.0 + lurch),
			Vector2(12.0, 8.0),
			Vector2(2.0, 13.0),
			Vector2(-12.0, 8.0)
		]),
		shirt_color
	)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(-10.0, 2.0),
			Vector2(-3.0, 4.0),
			Vector2(-7.0, 11.0),
			Vector2(-13.0, 8.0)
		]),
		Color(0.45, 0.16, 0.13, 0.9)
	)

	var head_position := Vector2(facing_direction.x * 3.0, -20.0 + lurch)
	draw_circle(head_position, 10.0, Color(0.04, 0.055, 0.05, 1.0))
	draw_circle(head_position, 8.0, skin_color)
	draw_circle(head_position + Vector2(facing_direction.x * 4.0, -1.0), 1.6, Color(0.98, 0.84, 0.30, 1.0))
	draw_line(
		head_position + Vector2(-4.0, 5.0),
		head_position + Vector2(4.0, 4.0),
		Color(0.24, 0.08, 0.07, 1.0),
		2.0
	)

	var reach := 23.0 if current_state == &"attack" else 18.0
	var arm_direction := facing_direction.normalized()
	var arm_sway := arm_direction.orthogonal() * walk_phase * 1.5
	draw_line(Vector2(-8.0, -5.0), arm_direction * reach + arm_sway, skin_color.darkened(0.12), 6.0, true)
	draw_line(Vector2(7.0, -4.0), arm_direction * (reach - 3.0) - arm_sway, skin_color, 6.0, true)

func _draw_runner() -> void:
	var run_phase := sin(animation_time * 14.0) * movement_ratio
	var bob := absf(sin(animation_time * 14.0)) * movement_ratio * 3.0
	var skin_color := Color(0.62, 0.78, 0.34, 1.0)
	var shirt_color := Color(0.38, 0.20, 0.22, 1.0)
	if hit_flash_timer > 0.0:
		skin_color = skin_color.lerp(
			Color(1.0, 0.84, 0.62, 1.0),
			flash_intensity
		)
		shirt_color = shirt_color.lerp(
			Color(0.86, 0.32, 0.24, 1.0),
			flash_intensity
		)

	draw_colored_polygon(
		_ellipse_points(Vector2(0.0, 17.0), Vector2(17.0, 6.0), 18),
		Color(0.01, 0.015, 0.015, 0.48)
	)
	draw_line(
		Vector2(-5.0, 7.0),
		Vector2(-10.0 + run_phase * 8.0, 22.0),
		Color(0.13, 0.11, 0.12, 1.0),
		5.0,
		true
	)
	draw_line(
		Vector2(5.0, 7.0),
		Vector2(10.0 - run_phase * 8.0, 22.0),
		Color(0.13, 0.11, 0.12, 1.0),
		5.0,
		true
	)
	var lean := facing_direction * 7.0
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(-9.0, -13.0 - bob) + lean,
			Vector2(8.0, -11.0 - bob) + lean,
			Vector2(9.0, 8.0 - bob),
			Vector2(0.0, 14.0 - bob),
			Vector2(-9.0, 7.0 - bob)
		]),
		Color(0.035, 0.045, 0.04, 1.0)
	)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(-7.0, -10.0 - bob) + lean,
			Vector2(6.0, -8.0 - bob) + lean,
			Vector2(6.0, 6.0 - bob),
			Vector2(0.0, 10.0 - bob),
			Vector2(-7.0, 5.0 - bob)
		]),
		shirt_color
	)
	var head_position := Vector2(0.0, -21.0 - bob) + lean * 1.15
	draw_circle(head_position, 8.5, Color(0.035, 0.045, 0.04, 1.0))
	draw_circle(head_position, 6.8, skin_color)
	draw_circle(
		head_position + facing_direction * 3.8,
		1.5,
		Color(1.0, 0.76, 0.18, 1.0)
	)
	var reach := 26.0 if current_state == &"attack" else 20.0
	var arm_direction := facing_direction.normalized()
	var arm_sway := arm_direction.orthogonal() * run_phase * 3.0
	draw_line(
		Vector2(-5.0, -7.0) + lean,
		arm_direction * reach + arm_sway,
		skin_color.darkened(0.12),
		4.0,
		true
	)
	draw_line(
		Vector2(5.0, -6.0) + lean,
		arm_direction * (reach - 2.0) - arm_sway,
		skin_color,
		4.0,
		true
	)

func _draw_tank() -> void:
	var step_phase := sin(animation_time * 5.2) * movement_ratio
	var weight_shift := sin(animation_time * 2.6) * movement_ratio * 2.0
	var skin_color := Color(0.38, 0.55, 0.30, 1.0)
	var armor_color := Color(0.25, 0.29, 0.27, 1.0)
	var hazard_color := Color(0.86, 0.46, 0.16, 1.0)
	if hit_flash_timer > 0.0:
		skin_color = skin_color.lerp(
			Color(0.96, 0.74, 0.58, 1.0),
			flash_intensity
		)
		armor_color = armor_color.lerp(
			Color(0.70, 0.34, 0.24, 1.0),
			flash_intensity
		)

	draw_colored_polygon(
		_ellipse_points(Vector2(0.0, 22.0), Vector2(34.0, 10.0), 20),
		Color(0.01, 0.015, 0.015, 0.58)
	)
	draw_line(
		Vector2(-14.0, 10.0),
		Vector2(-16.0 + step_phase * 3.0, 29.0),
		Color(0.10, 0.12, 0.11, 1.0),
		11.0,
		true
	)
	draw_line(
		Vector2(14.0, 10.0),
		Vector2(16.0 - step_phase * 3.0, 29.0),
		Color(0.10, 0.12, 0.11, 1.0),
		11.0,
		true
	)
	var torso := PackedVector2Array([
		Vector2(-29.0, -17.0 + weight_shift),
		Vector2(29.0, -17.0 - weight_shift),
		Vector2(31.0, 13.0),
		Vector2(18.0, 23.0),
		Vector2(-18.0, 23.0),
		Vector2(-31.0, 13.0)
	])
	draw_colored_polygon(torso, Color(0.035, 0.045, 0.04, 1.0))
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(-25.0, -13.0 + weight_shift),
			Vector2(25.0, -13.0 - weight_shift),
			Vector2(26.0, 10.0),
			Vector2(15.0, 18.0),
			Vector2(-15.0, 18.0),
			Vector2(-26.0, 10.0)
		]),
		armor_color
	)
	draw_line(
		Vector2(-20.0, -3.0),
		Vector2(20.0, 8.0),
		hazard_color,
		6.0,
		true
	)
	draw_line(
		Vector2(-19.0, 8.0),
		Vector2(18.0, -3.0),
		hazard_color.darkened(0.2),
		5.0,
		true
	)
	var head_position := Vector2(facing_direction.x * 4.0, -27.0 + weight_shift)
	draw_circle(head_position, 14.0, Color(0.035, 0.045, 0.04, 1.0))
	draw_circle(head_position, 11.5, skin_color)
	draw_circle(
		head_position + facing_direction * 5.0,
		2.0,
		Color(1.0, 0.64, 0.14, 1.0)
	)
	var reach := 34.0 if current_state == &"attack" else 25.0
	var arm_direction := facing_direction.normalized()
	draw_line(
		Vector2(-22.0, -7.0),
		arm_direction * reach + Vector2(0.0, 3.0),
		skin_color.darkened(0.18),
		10.0,
		true
	)
	draw_line(
		Vector2(22.0, -6.0),
		arm_direction * (reach - 3.0) - Vector2(0.0, 3.0),
		skin_color,
		10.0,
		true
	)

func _draw_shooter() -> void:
	var sway := sin(animation_time * 3.8) * 2.0
	var step := sin(animation_time * 7.0) * movement_ratio * 3.0
	var skin_color := Color(0.34, 0.68, 0.58, 1.0)
	var cloth_color := Color(0.10, 0.24, 0.24, 1.0)
	var toxin_color := Color(0.24, 0.96, 0.70, 1.0)
	if hit_flash_timer > 0.0:
		skin_color = skin_color.lerp(
			Color(0.86, 1.0, 0.90, 1.0),
			flash_intensity
		)
		cloth_color = cloth_color.lerp(
			Color(0.30, 0.62, 0.54, 1.0),
			flash_intensity
		)

	draw_colored_polygon(
		_ellipse_points(Vector2(0.0, 21.0), Vector2(21.0, 7.0), 18),
		Color(0.01, 0.02, 0.02, 0.52)
	)
	draw_line(
		Vector2(-7.0, 10.0),
		Vector2(-9.0 + step, 27.0),
		Color(0.07, 0.13, 0.13, 1.0),
		6.0,
		true
	)
	draw_line(
		Vector2(7.0, 10.0),
		Vector2(9.0 - step, 27.0),
		Color(0.07, 0.13, 0.13, 1.0),
		6.0,
		true
	)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(-13.0, -18.0 + sway),
			Vector2(13.0, -15.0 - sway),
			Vector2(16.0, 13.0),
			Vector2(0.0, 20.0),
			Vector2(-16.0, 13.0)
		]),
		Color(0.025, 0.06, 0.06, 1.0)
	)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(-10.0, -15.0 + sway),
			Vector2(10.0, -12.0 - sway),
			Vector2(12.0, 10.0),
			Vector2(0.0, 15.0),
			Vector2(-12.0, 10.0)
		]),
		cloth_color
	)
	var spine_direction := -facing_direction.normalized()
	for index in range(4):
		var spine_origin := Vector2(0.0, -11.0 + float(index) * 8.0)
		draw_line(
			spine_origin,
			spine_origin + spine_direction * (13.0 + float(index % 2) * 4.0),
			Color(toxin_color, 0.78),
			3.0,
			true
		)
	var head_position := Vector2(facing_direction.x * 4.0, -27.0 + sway)
	draw_circle(head_position, 11.0, Color(0.025, 0.06, 0.06, 1.0))
	draw_circle(head_position, 8.5, skin_color)
	draw_circle(head_position + facing_direction * 4.5, 2.0, toxin_color)
	var arm_direction := facing_direction.normalized()
	var weapon_origin := Vector2(0.0, -6.0)
	draw_line(
		weapon_origin - arm_direction.orthogonal() * 6.0,
		weapon_origin + arm_direction * 25.0,
		skin_color.darkened(0.14),
		5.0,
		true
	)
	draw_line(
		weapon_origin + arm_direction.orthogonal() * 6.0,
		weapon_origin + arm_direction * 25.0,
		skin_color,
		5.0,
		true
	)
	draw_circle(weapon_origin + arm_direction * 27.0, 5.0, Color(toxin_color, 0.9))

func _ellipse_points(center: Vector2, radius: Vector2, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(segments):
		var angle := TAU * float(index) / float(segments)
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	return points
