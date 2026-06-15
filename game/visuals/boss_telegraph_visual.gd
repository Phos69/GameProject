extends Node2D
class_name BossTelegraphVisual

@export var aimed_length: float = 680.0
@export var radial_length: float = 460.0
@export var countdown_radius: float = 64.0
@export var warning_color: Color = Color(1.0, 0.30, 0.16, 1.0)
@export var phase_color: Color = Color(1.0, 0.20, 0.64, 1.0)

var active_pattern: StringName = &""
var telegraph_duration: float = 0.0
var time_remaining: float = 0.0
var projectile_count: int = 0
var spread_radians: float = 0.0
var phase_pulse_duration: float = 0.0
var phase_pulse_remaining: float = 0.0
var lane_spacing: float = 0.0
var lane_gap_index: int = -1
var cross_rotation: float = 0.0
var high_contrast: bool = false
var reduced_motion: bool = false

func _ready() -> void:
	add_to_group("visual_settings_consumers")
	VisualSettingsManager.sync_consumer(self)
	hide()
	set_process(false)

func apply_visual_settings(settings: Dictionary) -> void:
	high_contrast = bool(settings.get("high_contrast", false))
	reduced_motion = bool(settings.get("reduced_motion", false))
	queue_redraw()

func begin_aimed(
	direction: Vector2,
	duration: float,
	count: int,
	spread: float
) -> void:
	active_pattern = &"aimed_volley"
	telegraph_duration = maxf(duration, 0.01)
	time_remaining = telegraph_duration
	projectile_count = maxi(count, 1)
	spread_radians = maxf(spread, 0.0)
	rotation = direction.angle()
	_show_active()

func begin_radial(duration: float, count: int) -> void:
	active_pattern = &"radial_burst"
	telegraph_duration = maxf(duration, 0.01)
	time_remaining = telegraph_duration
	projectile_count = maxi(count, 1)
	spread_radians = 0.0
	rotation = 0.0
	_show_active()

func begin_lanes(
	direction: Vector2,
	duration: float,
	count: int,
	spacing: float,
	gap_index: int
) -> void:
	active_pattern = &"lane_sweep"
	telegraph_duration = maxf(duration, 0.01)
	time_remaining = telegraph_duration
	projectile_count = maxi(count, 2)
	lane_spacing = maxf(spacing, 12.0)
	lane_gap_index = clampi(gap_index, 0, projectile_count - 1)
	rotation = direction.angle()
	_show_active()

func begin_cross(duration: float, count: int, rotation_offset: float) -> void:
	active_pattern = &"cross_burst"
	telegraph_duration = maxf(duration, 0.01)
	time_remaining = telegraph_duration
	projectile_count = maxi(count, 4)
	cross_rotation = rotation_offset
	rotation = 0.0
	_show_active()

func finish_telegraph() -> void:
	active_pattern = &""
	telegraph_duration = 0.0
	time_remaining = 0.0
	_refresh_processing()

func play_phase_change(duration: float = 0.80) -> void:
	phase_pulse_duration = maxf(duration, 0.01)
	phase_pulse_remaining = phase_pulse_duration
	_show_active()

func is_telegraph_active() -> bool:
	return not active_pattern.is_empty()

func get_progress_ratio() -> float:
	if telegraph_duration <= 0.0:
		return 1.0
	return clampf(
		1.0 - time_remaining / telegraph_duration,
		0.0,
		1.0
	)

func _process(delta: float) -> void:
	if not active_pattern.is_empty():
		time_remaining = maxf(time_remaining - delta, 0.0)
	if phase_pulse_remaining > 0.0:
		phase_pulse_remaining = maxf(phase_pulse_remaining - delta, 0.0)
	_refresh_processing()
	queue_redraw()

func _show_active() -> void:
	show()
	set_process(true)
	queue_redraw()

func _refresh_processing() -> void:
	var should_process := (
		not active_pattern.is_empty()
		or phase_pulse_remaining > 0.0
	)
	set_process(should_process)
	visible = should_process

func _draw() -> void:
	if active_pattern == &"aimed_volley":
		_draw_aimed_warning()
	elif active_pattern == &"radial_burst":
		_draw_radial_warning()
	elif active_pattern == &"lane_sweep":
		_draw_lane_warning()
	elif active_pattern == &"cross_burst":
		_draw_cross_warning()
	if phase_pulse_remaining > 0.0:
		_draw_phase_pulse()

func _draw_aimed_warning() -> void:
	var pulse := _warning_pulse(0.024)
	var half_angle := (
		spread_radians * float(maxi(projectile_count - 1, 1)) * 0.5
		+ 0.045
	)
	var end_half_width := tan(half_angle) * aimed_length + 18.0
	var fill_color := Color(warning_color, 0.10 * pulse)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(38.0, -18.0),
			Vector2(aimed_length, -end_half_width),
			Vector2(aimed_length, end_half_width),
			Vector2(38.0, 18.0)
		]),
		fill_color
	)
	draw_line(
		Vector2(38.0, -18.0),
		Vector2(aimed_length, -end_half_width),
		Color(warning_color, 0.62 * pulse),
		2.0,
		true
	)
	draw_line(
		Vector2(38.0, 18.0),
		Vector2(aimed_length, end_half_width),
		Color(warning_color, 0.62 * pulse),
		2.0,
		true
	)
	var center := float(projectile_count - 1) * 0.5
	for index in range(projectile_count):
		var angle_offset := (float(index) - center) * spread_radians
		var direction := Vector2.RIGHT.rotated(angle_offset)
		draw_line(
			direction * 42.0,
			direction * aimed_length,
			Color(warning_color, 0.82 * pulse),
			3.0,
			true
		)
	_draw_countdown_ring()

func _draw_radial_warning() -> void:
	var pulse := _warning_pulse(0.028)
	draw_circle(
		Vector2.ZERO,
		150.0,
		Color(warning_color, 0.075 * pulse),
		true,
		-1.0,
		true
	)
	for index in range(projectile_count):
		var direction := Vector2.RIGHT.rotated(
			TAU * float(index) / float(projectile_count)
		)
		draw_line(
			direction * 44.0,
			direction * radial_length,
			Color(warning_color, 0.76 * pulse),
			2.5,
			true
		)
	var warning_radius := lerpf(
		190.0,
		82.0,
		get_progress_ratio()
	)
	draw_arc(
		Vector2.ZERO,
		warning_radius,
		0.0,
		TAU,
		48,
		Color(warning_color, 0.90 * pulse),
		4.0,
		true
	)
	_draw_countdown_ring()

func _draw_countdown_ring() -> void:
	var progress := get_progress_ratio()
	var display_color := Color.WHITE if high_contrast else warning_color
	draw_arc(
		Vector2.ZERO,
		countdown_radius,
		-PI * 0.5,
		-PI * 0.5 + TAU * progress,
		32,
		Color(display_color, 0.96),
		7.0 if high_contrast else 5.0,
		true
	)

func _draw_lane_warning() -> void:
	var pulse := _warning_pulse(0.025)
	var center := float(projectile_count - 1) * 0.5
	for index in range(projectile_count):
		var offset := (float(index) - center) * lane_spacing
		var lane_color := (
			Color(0.22, 1.0, 0.78, 0.20)
			if index == lane_gap_index
			else Color(warning_color, 0.82 * pulse)
		)
		if index == lane_gap_index:
			draw_dashed_line(
				Vector2(42.0, offset),
				Vector2(aimed_length, offset),
				lane_color,
				2.0,
				14.0,
				true
			)
		else:
			draw_line(
				Vector2(42.0, offset),
				Vector2(aimed_length, offset),
				lane_color,
				5.0,
				true
			)
	_draw_countdown_ring()

func _draw_cross_warning() -> void:
	var pulse := _warning_pulse(0.028)
	for index in range(projectile_count):
		var direction := Vector2.RIGHT.rotated(
			cross_rotation + TAU * float(index) / float(projectile_count)
		)
		draw_line(
			direction * 46.0,
			direction * radial_length,
			Color(0.30, 0.92, 1.0, 0.78 * pulse),
			4.0 if index % 2 == 0 else 2.0,
			true
		)
	var warning_radius := lerpf(170.0, 72.0, get_progress_ratio())
	draw_arc(
		Vector2.ZERO,
		warning_radius,
		0.0,
		TAU,
		40,
		Color(0.30, 0.92, 1.0, 0.90 * pulse),
		4.0,
		true
	)
	_draw_countdown_ring()

func _draw_phase_pulse() -> void:
	var ratio := 1.0 - phase_pulse_remaining / phase_pulse_duration
	var alpha := 1.0 - ratio
	for ring_index in range(3):
		var delayed_ratio := clampf(
			ratio - float(ring_index) * 0.16,
			0.0,
			1.0
		)
		draw_arc(
			Vector2.ZERO,
			54.0 + delayed_ratio * 110.0,
			0.0,
			TAU,
			40,
			Color(phase_color, alpha * (0.90 - float(ring_index) * 0.18)),
			4.0,
			true
		)

func _warning_pulse(frequency: float) -> float:
	if reduced_motion:
		return 0.84
	return 0.72 + sin(Time.get_ticks_msec() * frequency) * 0.18
