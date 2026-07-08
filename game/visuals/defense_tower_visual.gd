extends Node2D
class_name DefenseTowerVisual

@export var visual_data: WeaponVisualData = preload(
	"res://game/weapons/defense_tower_visual.tres"
)

var aim_direction: Vector2 = Vector2.UP
var tower_level: int = 1
var tracking_target: bool = false
var fire_flash_timer: float = 0.0
var recoil_timer: float = 0.0
var animation_time: float = 0.0
var flash_intensity: float = 1.0
var glow_intensity: float = 1.0
var reduced_motion: bool = false

func _ready() -> void:
	add_to_group("visual_settings_consumers")
	VisualSettingsManager.sync_consumer(self)

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

func _process(delta: float) -> void:
	if not reduced_motion:
		animation_time += delta
	fire_flash_timer = maxf(fire_flash_timer - delta, 0.0)
	recoil_timer = maxf(recoil_timer - delta, 0.0)
	if not tracking_target:
		var idle_angle := -PI * 0.5 + sin(animation_time * 0.8) * 0.32
		aim_direction = Vector2.RIGHT.rotated(idle_angle)
	queue_redraw()

func set_tower_level(level: int) -> void:
	tower_level = maxi(level, 1)
	queue_redraw()

func set_aim_direction(direction: Vector2) -> void:
	if direction.length_squared() <= 0.01:
		return
	aim_direction = direction.normalized()
	tracking_target = true

func clear_target() -> void:
	tracking_target = false

func play_fire() -> void:
	fire_flash_timer = 0.10
	recoil_timer = 0.13
	queue_redraw()

func get_barrel_tip_local() -> Vector2:
	var recoil := (
		5.0 * recoil_timer / 0.13
		if recoil_timer > 0.0
		else 0.0
	)
	return aim_direction * (43.0 - recoil)

func is_fire_feedback_active() -> bool:
	return fire_flash_timer > 0.0 or recoil_timer > 0.0

func _draw() -> void:
	var primary := (
		visual_data.primary_color
		if visual_data != null
		else Color(0.12, 0.28, 0.46, 1.0)
	)
	var secondary := (
		visual_data.secondary_color
		if visual_data != null
		else Color(0.26, 0.90, 1.0, 1.0)
	)
	var glow := (
		visual_data.glow_color
		if visual_data != null
		else Color(0.16, 0.72, 1.0, 0.46)
	)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(0.0, -25.0),
			Vector2(29.0, -13.0),
			Vector2(31.0, 13.0),
			Vector2(0.0, 27.0),
			Vector2(-31.0, 13.0),
			Vector2(-29.0, -13.0)
		]),
		Color(0.035, 0.055, 0.075, 1.0)
	)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(0.0, -20.0),
			Vector2(24.0, -10.0),
			Vector2(25.0, 10.0),
			Vector2(0.0, 21.0),
			Vector2(-25.0, 10.0),
			Vector2(-24.0, -10.0)
		]),
		primary
	)
	var pulse := (
		0.76
		if reduced_motion
		else 0.68 + sin(animation_time * 3.2) * 0.16
	)
	draw_arc(
		Vector2.ZERO,
		19.0,
		0.0,
		TAU,
		24,
		Color(glow, glow.a * pulse * glow_intensity),
		3.0,
		true
	)

	var perpendicular := aim_direction.orthogonal()
	var recoil := (
		5.0 * recoil_timer / 0.13
		if recoil_timer > 0.0
		else 0.0
	)
	var barrel_start := aim_direction * 5.0
	var barrel_end := aim_direction * (43.0 - recoil)
	draw_line(
		barrel_start + perpendicular * 5.0,
		barrel_end + perpendicular * 4.0,
		Color(0.025, 0.04, 0.055, 1.0),
		9.0,
		true
	)
	draw_line(
		barrel_start + perpendicular * 5.0,
		barrel_end + perpendicular * 4.0,
		secondary,
		4.0,
		true
	)
	draw_line(
		barrel_start - perpendicular * 5.0,
		barrel_end - perpendicular * 4.0,
		Color(0.025, 0.04, 0.055, 1.0),
		9.0,
		true
	)
	draw_line(
		barrel_start - perpendicular * 5.0,
		barrel_end - perpendicular * 4.0,
		secondary.darkened(0.18),
		4.0,
		true
	)
	# Pip di livello (TD-001): un rombo accent per ogni upgrade comprato,
	# sul fronte della base, cosi' il livello si legge a colpo d'occhio.
	for pip_index in range(tower_level - 1):
		var pip_center := Vector2(-8.0 + float(pip_index) * 16.0, 20.0)
		draw_colored_polygon(
			PackedVector2Array([
				pip_center + Vector2(0.0, -4.0),
				pip_center + Vector2(3.5, 0.0),
				pip_center + Vector2(0.0, 4.0),
				pip_center + Vector2(-3.5, 0.0)
			]),
			Color(0.025, 0.04, 0.055, 1.0)
		)
		draw_colored_polygon(
			PackedVector2Array([
				pip_center + Vector2(0.0, -2.6),
				pip_center + Vector2(2.3, 0.0),
				pip_center + Vector2(0.0, 2.6),
				pip_center + Vector2(-2.3, 0.0)
			]),
			secondary.lightened(0.18)
		)
	draw_circle(Vector2.ZERO, 15.0, Color(0.025, 0.04, 0.055, 1.0))
	draw_circle(Vector2.ZERO, 11.0, secondary.darkened(0.26))
	draw_circle(
		Vector2.ZERO,
		5.5,
		Color(glow, 0.90 * glow_intensity)
	)

	if tracking_target:
		draw_arc(
			Vector2.ZERO,
			29.0,
			aim_direction.angle() - 0.22,
			aim_direction.angle() + 0.22,
			10,
			Color(secondary, 0.72),
			2.0,
			true
		)
	if fire_flash_timer > 0.0:
		var muzzle_color := (
			visual_data.muzzle_color
			if visual_data != null
			else secondary
		)
		var flash_size := (
			8.0 + fire_flash_timer * 65.0
		) * maxf(flash_intensity, 0.1)
		draw_colored_polygon(
			PackedVector2Array([
				barrel_end + aim_direction * flash_size,
				barrel_end + perpendicular * 6.0,
				barrel_end - perpendicular * 6.0
			]),
			Color(muzzle_color, 0.96 * flash_intensity)
		)
