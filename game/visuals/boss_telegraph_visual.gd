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
var warning_range: float = 0.0
var warning_width: float = 0.0
var warning_arc_degrees: float = 0.0
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

func begin_crescent(
	direction: Vector2,
	duration: float,
	count: int,
	spread: float
) -> void:
	active_pattern = &"crescent_barrage"
	telegraph_duration = maxf(duration, 0.01)
	time_remaining = telegraph_duration
	projectile_count = maxi(count, 2)
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

func begin_projectile_cone(
	pattern_id: StringName,
	direction: Vector2,
	duration: float,
	count: int,
	spread: float
) -> void:
	active_pattern = pattern_id
	telegraph_duration = maxf(duration, 0.01)
	time_remaining = telegraph_duration
	projectile_count = maxi(count, 1)
	spread_radians = maxf(spread, 0.0)
	rotation = direction.angle()
	_show_active()

func begin_projectile_radial(
	pattern_id: StringName,
	duration: float,
	count: int
) -> void:
	active_pattern = pattern_id
	telegraph_duration = maxf(duration, 0.01)
	time_remaining = telegraph_duration
	projectile_count = maxi(count, 1)
	spread_radians = 0.0
	rotation = 0.0
	_show_active()

func begin_melee_arc(
	pattern_id: StringName,
	direction: Vector2,
	duration: float,
	range_value: float,
	arc_degrees: float
) -> void:
	active_pattern = pattern_id
	telegraph_duration = maxf(duration, 0.01)
	time_remaining = telegraph_duration
	warning_range = maxf(range_value, 1.0)
	warning_arc_degrees = clampf(arc_degrees, 1.0, 360.0)
	rotation = direction.angle()
	_show_active()

func begin_area(
	pattern_id: StringName,
	duration: float,
	radius: float
) -> void:
	active_pattern = pattern_id
	telegraph_duration = maxf(duration, 0.01)
	time_remaining = telegraph_duration
	warning_range = maxf(radius, 1.0)
	rotation = 0.0
	_show_active()

func begin_charge_lane(
	pattern_id: StringName,
	direction: Vector2,
	duration: float,
	length: float,
	width: float
) -> void:
	active_pattern = pattern_id
	telegraph_duration = maxf(duration, 0.01)
	time_remaining = telegraph_duration
	warning_range = maxf(length, 1.0)
	warning_width = maxf(width, 1.0)
	rotation = direction.angle()
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
	elif active_pattern == &"crescent_barrage":
		_draw_crescent_warning()
	elif active_pattern == &"radial_burst":
		_draw_radial_warning()
	elif active_pattern == &"lane_sweep":
		_draw_lane_warning()
	elif active_pattern == &"cross_burst":
		_draw_cross_warning()
	elif active_pattern in [
		&"plague_fan", &"bone_mortar", &"carrion_bolt"
	]:
		_draw_aimed_warning()
	elif active_pattern in [&"spore_ring", &"bone_shards"]:
		_draw_radial_warning()
	elif active_pattern in [
		&"cleaver_sweep", &"horn_combo", &"butcher_sweep"
	]:
		_draw_melee_arc_warning()
	elif active_pattern == &"grave_slam":
		_draw_area_warning()
	elif active_pattern == &"gore_charge":
		_draw_charge_lane_warning()
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

func _draw_crescent_warning() -> void:
	var pulse := _warning_pulse(0.026)
	var half_angle := (
		spread_radians * float(maxi(projectile_count - 1, 1)) * 0.5
		+ 0.04
	)
	var center := float(projectile_count - 1) * 0.5
	for index in range(projectile_count):
		var angle_offset := (float(index) - center) * spread_radians
		var direction := Vector2.RIGHT.rotated(angle_offset)
		draw_line(
			direction * 44.0,
			direction * (aimed_length * 0.82),
			Color(warning_color, 0.78 * pulse),
			3.0,
			true
		)
	# Il fronte a mezzaluna avanza col countdown: comunica quando e dove il
	# ventaglio colpira' senza infliggere danno durante il warning.
	var front_radius := lerpf(
		96.0,
		aimed_length * 0.62,
		get_progress_ratio()
	)
	draw_arc(
		Vector2.ZERO,
		front_radius,
		-half_angle,
		half_angle,
		36,
		Color(warning_color, 0.92 * pulse),
		5.0,
		true
	)
	draw_arc(
		Vector2.ZERO,
		front_radius * 0.86,
		-half_angle * 0.8,
		half_angle * 0.8,
		30,
		Color(warning_color, 0.38 * pulse),
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

func _draw_melee_arc_warning() -> void:
	var pulse := _warning_pulse(0.026)
	var half_angle := deg_to_rad(warning_arc_degrees * 0.5)
	var wedge := PackedVector2Array([Vector2.ZERO])
	for index in range(25):
		var ratio := float(index) / 24.0
		var angle := lerpf(-half_angle, half_angle, ratio)
		wedge.append(Vector2.RIGHT.rotated(angle) * warning_range)
	draw_colored_polygon(wedge, Color(warning_color, 0.13 * pulse))
	draw_arc(
		Vector2.ZERO,
		warning_range,
		-half_angle,
		half_angle,
		28,
		Color(warning_color, 0.92 * pulse),
		5.0,
		true
	)
	draw_line(
		Vector2.ZERO,
		Vector2.RIGHT.rotated(-half_angle) * warning_range,
		Color(warning_color, 0.62 * pulse),
		2.5,
		true
	)
	draw_line(
		Vector2.ZERO,
		Vector2.RIGHT.rotated(half_angle) * warning_range,
		Color(warning_color, 0.62 * pulse),
		2.5,
		true
	)
	_draw_countdown_ring()

func _draw_area_warning() -> void:
	var pulse := _warning_pulse(0.027)
	draw_circle(
		Vector2.ZERO,
		warning_range,
		Color(warning_color, 0.12 * pulse),
		true,
		-1.0,
		true
	)
	draw_arc(
		Vector2.ZERO,
		warning_range,
		0.0,
		TAU,
		44,
		Color(warning_color, 0.88 * pulse),
		5.0,
		true
	)
	var impact_radius := lerpf(
		warning_range,
		countdown_radius * 0.55,
		get_progress_ratio()
	)
	draw_arc(
		Vector2.ZERO,
		impact_radius,
		0.0,
		TAU,
		36,
		Color(warning_color, 0.72 * pulse),
		3.0,
		true
	)
	_draw_countdown_ring()

func _draw_charge_lane_warning() -> void:
	var pulse := _warning_pulse(0.026)
	var rect := Rect2(
		Vector2(38.0, -warning_width * 0.5),
		Vector2(maxf(warning_range - 38.0, 1.0), warning_width)
	)
	draw_rect(rect, Color(warning_color, 0.12 * pulse), true)
	draw_rect(rect, Color(warning_color, 0.88 * pulse), false, 4.0)
	var front_x := lerpf(44.0, warning_range, get_progress_ratio())
	draw_line(
		Vector2(front_x, -warning_width * 0.55),
		Vector2(front_x, warning_width * 0.55),
		Color(warning_color, 0.96 * pulse),
		6.0,
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
