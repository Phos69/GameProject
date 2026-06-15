extends Node2D
class_name WaveWardenVisual

@export var phase_one_color: Color = Color(0.48, 0.20, 0.78, 1.0)
@export var phase_two_color: Color = Color(0.88, 0.16, 0.44, 1.0)
@export var core_color: Color = Color(0.24, 0.88, 1.0, 1.0)
@export var phase_two_core_color: Color = Color(1.0, 0.70, 0.18, 1.0)

var phase_index: int = 1
var aim_direction: Vector2 = Vector2.DOWN
var active_pattern: StringName = &""
var animation_time: float = 0.0
var hurt_timer: float = 0.0
var spawn_timer: float = 0.0
var flash_intensity: float = 1.0
var glow_intensity: float = 1.0
var reduced_motion: bool = false

func _ready() -> void:
	add_to_group("visual_settings_consumers")
	VisualSettingsManager.sync_consumer(self)
	queue_redraw()

func _process(delta: float) -> void:
	if not reduced_motion:
		animation_time += delta
	hurt_timer = maxf(hurt_timer - delta, 0.0)
	spawn_timer = maxf(spawn_timer - delta, 0.0)
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
	reduced_motion = bool(settings.get("reduced_motion", false))
	if reduced_motion:
		animation_time = 0.0
	queue_redraw()

func set_facing(direction: Vector2) -> void:
	if direction.length_squared() <= 0.01:
		return
	aim_direction = direction.normalized()

func set_phase(new_phase_index: int) -> void:
	phase_index = maxi(new_phase_index, 1)
	queue_redraw()

func set_attack_charge(pattern_id: StringName) -> void:
	active_pattern = pattern_id
	queue_redraw()

func clear_attack_charge() -> void:
	active_pattern = &""
	queue_redraw()

func play_hurt() -> void:
	hurt_timer = 0.14
	queue_redraw()

func play_spawn() -> void:
	spawn_timer = 0.65
	queue_redraw()

func get_profile_id() -> StringName:
	return &"wave_warden"

func is_phase_two_visual() -> bool:
	return phase_index >= 2

func _draw() -> void:
	var phase_two := is_phase_two_visual()
	var armor_color := phase_two_color if phase_two else phase_one_color
	var energy_color := phase_two_core_color if phase_two else core_color
	if hurt_timer > 0.0:
		armor_color = armor_color.lerp(
			Color(1.0, 0.90, 0.96, 1.0),
			flash_intensity
		)
		energy_color = energy_color.lerp(Color.WHITE, flash_intensity)
	energy_color = Color(
		energy_color,
		energy_color.a * maxf(glow_intensity, 0.25)
	)

	var hover := sin(animation_time * (3.2 if phase_two else 2.2)) * 3.0
	var pulse := 0.84 + sin(animation_time * 4.4) * 0.12
	var orbit_angle := animation_time * (1.45 if phase_two else 0.78)
	draw_set_transform(Vector2(0.0, hover), 0.0, Vector2.ONE)

	draw_colored_polygon(
		_ellipse_points(Vector2(0.0, 44.0), Vector2(48.0, 14.0), 24),
		Color(0.01, 0.015, 0.025, 0.52)
	)

	for ring_index in range(2):
		var ring_radius := 49.0 + float(ring_index) * 8.0
		var ring_alpha := 0.30 - float(ring_index) * 0.09
		draw_arc(
			Vector2.ZERO,
			ring_radius,
			orbit_angle + float(ring_index) * PI,
			orbit_angle + float(ring_index) * PI + PI * 1.45,
			32,
			Color(energy_color, ring_alpha),
			2.5,
			true
		)

	var plate_count := 8
	for index in range(plate_count):
		var angle := TAU * float(index) / float(plate_count)
		var plate_radius := 40.0 + sin(animation_time * 2.4 + float(index)) * 2.5
		_draw_armor_plate(
			angle,
			plate_radius,
			armor_color,
			phase_two
		)

	if phase_two:
		for index in range(8):
			var angle := TAU * float(index) / 8.0 + PI * 0.125
			var direction := Vector2.RIGHT.rotated(angle)
			draw_colored_polygon(
				PackedVector2Array([
					direction * 47.0 + direction.orthogonal() * 5.0,
					direction * 65.0,
					direction * 47.0 - direction.orthogonal() * 5.0
				]),
				Color(phase_two_core_color, 0.82)
			)

	draw_colored_polygon(
		_regular_polygon(30.0, 10, orbit_angle * -0.16),
		Color(0.035, 0.035, 0.075, 1.0)
	)
	draw_colored_polygon(
		_regular_polygon(23.0, 6, PI / 6.0),
		Color(energy_color, 0.26)
	)
	draw_colored_polygon(
		_regular_polygon(17.0 * pulse, 6, PI / 6.0),
		energy_color
	)
	draw_colored_polygon(
		_regular_polygon(8.0 * pulse, 6, PI / 6.0),
		Color(0.94, 0.98, 1.0, 0.96)
	)

	var eye_origin := aim_direction * 27.0
	var eye_side := aim_direction.orthogonal()
	draw_colored_polygon(
		PackedVector2Array([
			eye_origin + aim_direction * 14.0,
			eye_origin - aim_direction * 4.0 + eye_side * 7.0,
			eye_origin - aim_direction * 4.0 - eye_side * 7.0
		]),
		Color(1.0, 0.72, 0.22, 1.0)
	)

	for node_index in range(3):
		var node_angle := orbit_angle + TAU * float(node_index) / 3.0
		var node_position := Vector2.RIGHT.rotated(node_angle) * 58.0
		draw_circle(node_position, 4.5, Color(energy_color, 0.85))
		draw_circle(node_position, 2.0, Color.WHITE)

	if not active_pattern.is_empty():
		var charge_color := (
			Color(1.0, 0.34, 0.16, 1.0)
			if active_pattern == &"radial_burst"
			else Color(1.0, 0.26, 0.72, 1.0)
		)
		var charge_radius := 34.0 + sin(animation_time * 14.0) * 4.0
		draw_arc(
			Vector2.ZERO,
			charge_radius,
			0.0,
			TAU,
			32,
			Color(charge_color, 0.92),
			4.0,
			true
		)
		for index in range(6):
			var direction := Vector2.RIGHT.rotated(
				animation_time * 2.6 + TAU * float(index) / 6.0
			)
			draw_line(
				direction * 48.0,
				direction * 61.0,
				Color(charge_color, 0.76),
				3.0,
				true
			)

	if spawn_timer > 0.0:
		var spawn_ratio := 1.0 - spawn_timer / 0.65
		draw_arc(
			Vector2.ZERO,
			78.0 - spawn_ratio * 24.0,
			0.0,
			TAU,
			40,
			Color(energy_color, 1.0 - spawn_ratio),
			5.0,
			true
		)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_armor_plate(
	angle: float,
	radius: float,
	color: Color,
	phase_two: bool
) -> void:
	var direction := Vector2.RIGHT.rotated(angle)
	var side := direction.orthogonal()
	var center := direction * radius
	var outer_length := 16.0 if phase_two else 12.0
	var half_width := 11.0
	draw_colored_polygon(
		PackedVector2Array([
			center + direction * outer_length,
			center + direction * 3.0 + side * half_width,
			center - direction * 9.0 + side * 7.0,
			center - direction * 12.0 - side * 7.0,
			center + direction * 3.0 - side * half_width
		]),
		Color(0.025, 0.025, 0.055, 1.0)
	)
	draw_colored_polygon(
		PackedVector2Array([
			center + direction * (outer_length - 3.0),
			center + direction * 2.0 + side * 7.5,
			center - direction * 7.0 + side * 5.0,
			center - direction * 9.0 - side * 5.0,
			center + direction * 2.0 - side * 7.5
		]),
		color.darkened(0.06 + 0.12 * absf(sin(angle)))
	)

func _regular_polygon(
	radius: float,
	sides: int,
	rotation_offset: float = 0.0
) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(sides):
		var angle := rotation_offset + TAU * float(index) / float(sides)
		points.append(Vector2.RIGHT.rotated(angle) * radius)
	return points

func _ellipse_points(
	center: Vector2,
	radius: Vector2,
	segments: int
) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(segments):
		var angle := TAU * float(index) / float(segments)
		points.append(
			center + Vector2(
				cos(angle) * radius.x,
				sin(angle) * radius.y
			)
		)
	return points
