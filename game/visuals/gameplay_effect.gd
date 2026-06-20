extends Node2D
class_name GameplayEffect

var effect_kind: StringName = &"hit"
var effect_color: Color = Color.WHITE
var effect_size: float = 18.0
var duration: float = 0.25
var age: float = 0.0
var opacity_scale: float = 1.0
var reduced_motion: bool = false

func configure(
	kind: StringName,
	color: Color,
	size: float,
	lifetime: float,
	angle: float = 0.0,
	intensity: float = 1.0,
	motion_reduced: bool = false
) -> void:
	effect_kind = kind
	effect_color = color
	effect_size = size
	duration = maxf(lifetime, 0.01)
	rotation = angle
	opacity_scale = clampf(intensity, 0.0, 1.0)
	reduced_motion = motion_reduced

func _process(delta: float) -> void:
	age += delta
	if age >= duration:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var ratio := clampf(age / duration, 0.0, 1.0)
	var alpha := 1.0 - ratio
	var motion_ratio := ratio * (0.18 if reduced_motion else 1.0)
	var color := Color(
		effect_color,
		effect_color.a * alpha * opacity_scale
	)
	match effect_kind:
		&"muzzle":
			var length := effect_size * (1.0 - motion_ratio * 0.45)
			draw_colored_polygon(
				PackedVector2Array([
					Vector2(length, 0.0),
					Vector2(0.0, -effect_size * 0.34 * alpha),
					Vector2(0.0, effect_size * 0.34 * alpha)
				]),
				color
			)
		&"muzzle_shotgun":
			var length := effect_size * (1.0 - motion_ratio * 0.35)
			for index in range(3):
				var spread := (float(index) - 1.0) * 0.30
				var direction := Vector2.RIGHT.rotated(spread)
				var side := direction.orthogonal()
				draw_colored_polygon(
					PackedVector2Array([
						direction * length,
						side * effect_size * 0.26 - direction * effect_size * 0.12,
						-side * effect_size * 0.26 - direction * effect_size * 0.12
					]),
					Color(color, alpha * (0.72 - absf(float(index) - 1.0) * 0.16))
				)
		&"muzzle_rotor":
			for index in range(6):
				var direction := Vector2.RIGHT.rotated(TAU * float(index) / 6.0)
				draw_line(
					direction * effect_size * 0.12,
					direction * effect_size * (0.48 + alpha * 0.34),
					Color(color, alpha * 0.72),
					2.5,
					true
				)
			draw_circle(Vector2.ZERO, effect_size * 0.24, Color(color, alpha * 0.32))
		&"muzzle_rail":
			draw_line(
				Vector2.ZERO,
				Vector2(effect_size * (1.10 - motion_ratio * 0.28), 0.0),
				Color(color.lightened(0.18), alpha),
				5.0,
				true
			)
			draw_arc(
				Vector2.ZERO,
				effect_size * (0.24 + motion_ratio * 0.18),
				-0.70,
				0.70,
				18,
				color,
				3.0,
				true
			)
		&"muzzle_elemental":
			draw_arc(
				Vector2.ZERO,
				effect_size * (0.24 + motion_ratio * 0.18),
				0.0,
				TAU,
				28,
				color,
				3.0,
				true
			)
			for index in range(5):
				var direction := Vector2.RIGHT.rotated(TAU * float(index) / 5.0)
				draw_line(
					direction * effect_size * 0.18,
					direction * effect_size * (0.36 + alpha * 0.24),
					Color(color.lightened(0.16), alpha),
					2.5,
					true
				)
		&"death":
			draw_arc(
				Vector2.ZERO,
				effect_size * (0.35 + motion_ratio),
				0.0,
				TAU,
				28,
				color,
				3.0,
				true
			)
			for index in range(8):
				var direction := Vector2.RIGHT.rotated(TAU * float(index) / 8.0)
				var start := direction * effect_size * motion_ratio * 0.45
				var finish := direction * effect_size * (
					0.55 + motion_ratio * 0.75
				)
				draw_line(start, finish, color, 3.0, true)
		&"boss_death":
			for ring_index in range(3):
				var ring_ratio := clampf(
					ratio - float(ring_index) * 0.10,
					0.0,
					1.0
				)
				draw_arc(
					Vector2.ZERO,
					effect_size * (
						0.28 + ring_ratio * (0.20 if reduced_motion else 1.05)
					),
					0.0,
					TAU,
					40,
					Color(color, alpha * (1.0 - float(ring_index) * 0.22)),
					5.0,
					true
				)
			for index in range(12):
				var direction := Vector2.RIGHT.rotated(
					TAU * float(index) / 12.0 + ratio * 0.35
				)
				var side := direction.orthogonal()
				var center := direction * effect_size * (
					0.30 + motion_ratio * 0.92
				)
				draw_colored_polygon(
					PackedVector2Array([
						center + direction * 10.0,
						center - direction * 8.0 + side * 5.0,
						center - direction * 8.0 - side * 5.0
					]),
					Color(color, alpha)
				)
			draw_circle(
				Vector2.ZERO,
				effect_size * 0.22 * alpha,
				Color(1.0, 0.78, 0.28, alpha)
			)
		&"environment_explosion":
			draw_circle(
				Vector2.ZERO,
				effect_size * (0.12 + motion_ratio * 0.88),
				Color(color, alpha * 0.12)
			)
			for ring_index in range(2):
				draw_arc(
					Vector2.ZERO,
					effect_size * (
						0.24
						+ motion_ratio * (
							0.76 + float(ring_index) * 0.16
						)
					),
					0.0,
					TAU,
					48,
					Color(color, alpha * (1.0 - float(ring_index) * 0.35)),
					5.0,
					true
				)
			for index in range(10):
				var direction := Vector2.RIGHT.rotated(
					TAU * float(index) / 10.0
				)
				draw_line(
					direction * effect_size * motion_ratio * 0.25,
					direction * effect_size * (
						0.38 + motion_ratio * 0.68
					),
					Color(color, alpha),
					4.0,
					true
				)
		&"fall_damage":
			draw_circle(
				Vector2.ZERO,
				effect_size * (0.52 - motion_ratio * 0.32),
				Color(0.02, 0.025, 0.02, alpha * 0.82)
			)
			draw_arc(
				Vector2.ZERO,
				effect_size * (0.34 + motion_ratio * 0.72),
				0.0,
				TAU,
				36,
				color,
				4.0,
				true
			)
			for index in range(6):
				var direction := Vector2.RIGHT.rotated(
					TAU * float(index) / 6.0
				)
				draw_line(
					direction * effect_size * 0.18,
					direction * effect_size * (
						0.42 + motion_ratio * 0.48
					),
					Color(color, alpha),
					3.0,
					true
				)
		&"fall_respawn":
			for ring_index in range(2):
				draw_arc(
					Vector2.ZERO,
					effect_size * (
						0.24
						+ motion_ratio * (
							0.52 + float(ring_index) * 0.18
						)
					),
					0.0,
					TAU,
					36,
					Color(color, alpha * (1.0 - float(ring_index) * 0.30)),
					3.0,
					true
				)
			draw_line(
				Vector2(0.0, effect_size * 0.42),
				Vector2(0.0, -effect_size * (0.30 + motion_ratio * 0.50)),
				Color(color.lightened(0.20), alpha),
				3.0,
				true
			)
		&"environment_damage":
			draw_arc(
				Vector2.ZERO,
				effect_size * (0.28 + motion_ratio * 0.72),
				0.0,
				TAU,
				30,
				color,
				4.0,
				true
			)
			for index in range(5):
				var direction := Vector2.UP.rotated(
					(float(index) - 2.0) * 0.42
				)
				draw_line(
					direction * effect_size * 0.18,
					direction * effect_size * (
						0.42 + motion_ratio * 0.44
					),
					Color(color, alpha),
					3.0,
					true
				)
		&"weapon_impact_ballistic":
			for index in range(6):
				var direction := Vector2.RIGHT.rotated(TAU * float(index) / 6.0)
				draw_line(
					direction * effect_size * 0.08,
					direction * effect_size * (0.28 + motion_ratio * 0.42),
					color,
					2.5,
					true
				)
			draw_circle(Vector2.ZERO, effect_size * 0.12, Color(color, alpha * 0.35))
		&"weapon_impact_explosion":
			draw_circle(
				Vector2.ZERO,
				effect_size * (0.16 + motion_ratio * 0.40),
				Color(color, alpha * 0.18)
			)
			draw_arc(
				Vector2.ZERO,
				effect_size * (0.28 + motion_ratio * 0.62),
				0.0,
				TAU,
				38,
				color,
				4.0,
				true
			)
			for index in range(9):
				var direction := Vector2.RIGHT.rotated(TAU * float(index) / 9.0)
				draw_line(
					direction * effect_size * 0.22,
					direction * effect_size * (0.42 + motion_ratio * 0.56),
					Color(color.lightened(0.12), alpha),
					3.4,
					true
				)
		&"weapon_impact_fire":
			for index in range(5):
				var direction := Vector2.UP.rotated((float(index) - 2.0) * 0.26)
				draw_colored_polygon(
					PackedVector2Array([
						direction * effect_size * (0.28 + motion_ratio * 0.46),
						direction.rotated(0.55) * effect_size * 0.18,
						direction.rotated(-0.55) * effect_size * 0.18
					]),
					Color(color, alpha * 0.78)
				)
			draw_arc(Vector2.ZERO, effect_size * (0.24 + motion_ratio * 0.48), 0.0, TAU, 24, color, 3.0, true)
		&"weapon_impact_ice":
			for index in range(8):
				var direction := Vector2.RIGHT.rotated(TAU * float(index) / 8.0)
				draw_line(
					direction * effect_size * 0.10,
					direction * effect_size * (0.42 + motion_ratio * 0.42),
					Color(color.lightened(0.18), alpha),
					2.8,
					true
				)
			draw_colored_polygon(
				PackedVector2Array([
					Vector2(0.0, -effect_size * 0.28),
					Vector2(effect_size * 0.20, 0.0),
					Vector2(0.0, effect_size * 0.28),
					Vector2(-effect_size * 0.20, 0.0)
				]),
				Color(color, alpha * 0.24)
			)
		&"weapon_impact_lightning":
			for index in range(3):
				var offset := (float(index) - 1.0) * effect_size * 0.16
				draw_polyline(
					PackedVector2Array([
						Vector2(-effect_size * 0.42, offset),
						Vector2(-effect_size * 0.12, -effect_size * 0.18 + offset),
						Vector2(effect_size * 0.10, effect_size * 0.12 + offset),
						Vector2(effect_size * 0.46, -effect_size * 0.08 + offset)
					]),
					Color(color.lightened(0.20), alpha),
					3.0,
					true
				)
			draw_arc(Vector2.ZERO, effect_size * (0.20 + motion_ratio * 0.44), 0.0, TAU, 20, Color(color, alpha * 0.55), 2.5, true)
		&"weapon_impact_toxic":
			draw_circle(
				Vector2.ZERO,
				effect_size * (0.18 + motion_ratio * 0.42),
				Color(color, alpha * 0.20)
			)
			for index in range(7):
				var direction := Vector2.RIGHT.rotated(TAU * float(index) / 7.0)
				var center := direction * effect_size * (0.18 + motion_ratio * 0.46)
				draw_circle(center, effect_size * 0.10 * alpha, Color(color.lightened(0.10), alpha * 0.62))
			draw_arc(Vector2.ZERO, effect_size * (0.28 + motion_ratio * 0.46), 0.0, TAU, 30, color, 3.0, true)
		&"weapon_impact_seismic":
			for ring_index in range(2):
				draw_arc(
					Vector2.ZERO,
					effect_size * (0.20 + motion_ratio * (0.45 + float(ring_index) * 0.22)),
					0.0,
					TAU,
					36,
					Color(color, alpha * (0.86 - float(ring_index) * 0.26)),
					4.0,
					true
				)
			for index in range(5):
				var direction := Vector2.RIGHT.rotated(TAU * float(index) / 5.0)
				draw_line(
					direction * effect_size * 0.10,
					direction * effect_size * (0.32 + motion_ratio * 0.50),
					Color(color.darkened(0.18), alpha),
					3.2,
					true
				)
		&"weapon_impact_void":
			draw_circle(Vector2.ZERO, effect_size * (0.28 - motion_ratio * 0.08), Color(0.04, 0.02, 0.08, alpha * 0.64))
			for ring_index in range(3):
				draw_arc(
					Vector2.ZERO,
					effect_size * (0.18 + motion_ratio * (0.26 + float(ring_index) * 0.18)),
					0.0,
					TAU,
					34,
					Color(color, alpha * (0.90 - float(ring_index) * 0.24)),
					3.0,
					true
				)
			for index in range(6):
				var direction := Vector2.RIGHT.rotated(TAU * float(index) / 6.0)
				draw_line(
					direction * effect_size * (0.50 - motion_ratio * 0.24),
					direction * effect_size * 0.16,
					Color(color.lightened(0.16), alpha),
					2.6,
					true
				)
		&"weapon_impact_rail":
			draw_line(
				Vector2(-effect_size * 0.58, 0.0),
				Vector2(effect_size * 0.72, 0.0),
				Color(color.lightened(0.24), alpha),
				4.8,
				true
			)
			for index in range(6):
				var direction := Vector2.RIGHT.rotated(TAU * float(index) / 6.0)
				draw_line(
					direction * effect_size * 0.10,
					direction * effect_size * (0.34 + motion_ratio * 0.34),
					Color(color, alpha * 0.72),
					2.4,
					true
				)
		&"melee_hit_quick_stab":
			draw_line(
				Vector2(-effect_size * 0.42, 0.0),
				Vector2(effect_size * 0.50, 0.0),
				Color(color.lightened(0.18), alpha),
				3.0,
				true
			)
			draw_circle(Vector2(effect_size * 0.48, 0.0), effect_size * 0.10, Color(color, alpha * 0.70))
		&"melee_hit_thrust":
			draw_line(
				Vector2(-effect_size * 0.52, 0.0),
				Vector2(effect_size * 0.68, 0.0),
				Color(color.lightened(0.18), alpha),
				3.4,
				true
			)
			draw_line(
				Vector2(effect_size * 0.38, -effect_size * 0.18),
				Vector2(effect_size * 0.68, 0.0),
				color,
				2.2,
				true
			)
			draw_line(
				Vector2(effect_size * 0.38, effect_size * 0.18),
				Vector2(effect_size * 0.68, 0.0),
				color,
				2.2,
				true
			)
		&"melee_hit_cleave":
			draw_arc(
				Vector2.ZERO,
				effect_size * (0.26 + motion_ratio * 0.52),
				-0.72,
				0.82,
				24,
				color,
				4.0,
				true
			)
			draw_line(Vector2(-effect_size * 0.34, effect_size * 0.16), Vector2(effect_size * 0.46, -effect_size * 0.22), Color(color.lightened(0.14), alpha), 3.0, true)
		&"melee_hit_heavy_cleave":
			draw_arc(
				Vector2.ZERO,
				effect_size * (0.24 + motion_ratio * 0.60),
				-0.92,
				0.94,
				28,
				color,
				6.0,
				true
			)
			for index in range(3):
				var direction := Vector2.RIGHT.rotated(-0.55 + float(index) * 0.55)
				draw_line(direction * effect_size * 0.14, direction * effect_size * (0.42 + motion_ratio * 0.42), Color(color, alpha * 0.58), 3.0, true)
		&"melee_hit_broad_sweep":
			draw_arc(
				Vector2.ZERO,
				effect_size * (0.30 + motion_ratio * 0.56),
				-1.18,
				1.18,
				34,
				color,
				5.0,
				true
			)
			draw_arc(Vector2.ZERO, effect_size * (0.20 + motion_ratio * 0.42), -0.95, 0.95, 28, Color(color.lightened(0.20), alpha * 0.55), 2.5, true)
		&"melee_hit_hammer":
			for ring_index in range(2):
				draw_arc(
					Vector2.ZERO,
					effect_size * (0.18 + motion_ratio * (0.44 + float(ring_index) * 0.22)),
					0.0,
					TAU,
					36,
					Color(color, alpha * (0.86 - float(ring_index) * 0.24)),
					4.5,
					true
				)
			draw_line(Vector2(-effect_size * 0.36, 0.0), Vector2(effect_size * 0.42, 0.0), Color(color.darkened(0.12), alpha), 5.0, true)
		&"melee_hit_dash_cut":
			draw_line(
				Vector2(-effect_size * 0.52, effect_size * 0.26),
				Vector2(effect_size * 0.56, -effect_size * 0.30),
				Color(color.lightened(0.20), alpha),
				3.4,
				true
			)
			draw_line(
				Vector2(-effect_size * 0.28, effect_size * 0.42),
				Vector2(effect_size * 0.34, -effect_size * 0.18),
				Color(color, alpha * 0.62),
				2.2,
				true
			)
		&"melee_hit_spiked":
			for index in range(10):
				var direction := Vector2.RIGHT.rotated(TAU * float(index) / 10.0)
				draw_line(
					direction * effect_size * 0.12,
					direction * effect_size * (0.34 + motion_ratio * 0.34),
					color,
					2.6,
					true
				)
			draw_circle(Vector2.ZERO, effect_size * 0.14, Color(color, alpha * 0.38))
		&"melee_hit_crescent":
			draw_arc(
				Vector2.ZERO,
				effect_size * (0.24 + motion_ratio * 0.70),
				-1.36,
				1.36,
				38,
				color,
				4.5,
				true
			)
			draw_arc(Vector2.ZERO, effect_size * (0.34 + motion_ratio * 0.52), -1.12, 1.12, 34, Color(color.lightened(0.16), alpha * 0.42), 2.4, true)
		&"melee_hit_shield":
			var rect := Rect2(
				Vector2(-effect_size * 0.36, -effect_size * 0.32),
				Vector2(effect_size * 0.72, effect_size * 0.64)
			)
			draw_rect(rect, Color(color, alpha * 0.18), true)
			draw_rect(rect, color, false, 3.5)
			draw_line(Vector2(effect_size * 0.34, -effect_size * 0.32), Vector2(effect_size * 0.56, -effect_size * 0.12), Color(color.lightened(0.18), alpha), 2.5, true)
			draw_line(Vector2(effect_size * 0.34, effect_size * 0.32), Vector2(effect_size * 0.56, effect_size * 0.12), Color(color.lightened(0.18), alpha), 2.5, true)
		&"melee_hit_claw":
			for index in range(3):
				var y := (float(index) - 1.0) * effect_size * 0.20
				draw_line(
					Vector2(-effect_size * 0.44, y - effect_size * 0.14),
					Vector2(effect_size * 0.48, y + effect_size * 0.10),
					Color(color.lightened(0.18), alpha),
					2.8,
					true
				)
		&"melee_hit":
			draw_line(
				Vector2(-effect_size * 0.46, -effect_size * 0.18),
				Vector2(effect_size * 0.52, effect_size * 0.22),
				color,
				4.5,
				true
			)
			draw_line(
				Vector2(-effect_size * 0.28, effect_size * 0.34),
				Vector2(effect_size * 0.42, -effect_size * 0.30),
				Color(color.lightened(0.18), alpha),
				3.0,
				true
			)
			draw_arc(
				Vector2.ZERO,
				effect_size * (0.22 + motion_ratio * 0.52),
				-0.55,
				0.68,
				16,
				Color(color, alpha * 0.72),
				3.0,
				true
			)
		&"pickup":
			draw_arc(
				Vector2.ZERO,
				effect_size * (0.4 + motion_ratio * 0.8),
				0.0,
				TAU,
				24,
				color,
				2.5,
				true
			)
			draw_line(Vector2(0.0, 7.0), Vector2(0.0, -effect_size * alpha), color, 3.0, true)
		&"rpg_level_up":
			for ring_index in range(2):
				draw_arc(
					Vector2.ZERO,
					effect_size * (0.24 + motion_ratio * (0.55 + float(ring_index) * 0.22)),
					0.0,
					TAU,
					36,
					Color(color, alpha * (1.0 - float(ring_index) * 0.28)),
					3.5,
					true
				)
			for index in range(6):
				var direction := Vector2.UP.rotated(TAU * float(index) / 6.0)
				draw_line(
					direction * effect_size * 0.18,
					direction * effect_size * (0.36 + motion_ratio * 0.50),
					Color(color.lightened(0.25), alpha),
					3.0,
					true
				)
			draw_circle(Vector2.ZERO, effect_size * 0.12 * alpha, Color(1.0, 0.95, 0.45, alpha))
		&"rpg_super":
			draw_circle(
				Vector2.ZERO,
				effect_size * (0.10 + motion_ratio * 0.34),
				Color(color, alpha * 0.18)
			)
			draw_arc(
				Vector2.ZERO,
				effect_size * (0.30 + motion_ratio * 0.72),
				0.0,
				TAU,
				44,
				color,
				5.0,
				true
			)
			for index in range(10):
				var direction := Vector2.RIGHT.rotated(TAU * float(index) / 10.0 + ratio * 0.25)
				draw_line(
					direction * effect_size * motion_ratio * 0.22,
					direction * effect_size * (0.42 + motion_ratio * 0.48),
					Color(color, alpha),
					4.0,
					true
				)
		&"rpg_super_cone":
			var cone_angle := 0.78
			draw_arc(
				Vector2.ZERO,
				effect_size * (0.28 + motion_ratio * 1.08),
				-cone_angle,
				cone_angle,
				32,
				color,
				4.0,
				true
			)
			for index in range(7):
				var angle := lerpf(-cone_angle, cone_angle, float(index) / 6.0)
				var direction := Vector2.RIGHT.rotated(angle)
				draw_line(
					direction * effect_size * 0.16,
					direction * effect_size * (0.52 + motion_ratio * 0.72),
					Color(color.lightened(0.16), alpha),
					2.8,
					true
				)
		&"rpg_super_burst":
			for index in range(14):
				var direction := Vector2.RIGHT.rotated(TAU * float(index) / 14.0 + ratio * 0.18)
				var start := direction * effect_size * (0.12 + motion_ratio * 0.16)
				var finish := direction * effect_size * (0.32 + motion_ratio * 0.72)
				draw_line(start, finish, color, 3.0, true)
			draw_circle(Vector2.ZERO, effect_size * 0.16 * alpha, Color(1.0, 0.92, 0.58, alpha))
		&"rpg_super_radial":
			for ring_index in range(3):
				var ring_ratio := clampf(ratio - float(ring_index) * 0.12, 0.0, 1.0)
				draw_arc(
					Vector2.ZERO,
					effect_size * (0.24 + ring_ratio * 1.10),
					0.0,
					TAU,
					48,
					Color(color, alpha * (1.0 - float(ring_index) * 0.22)),
					5.0,
					true
				)
			for index in range(8):
				var direction := Vector2.RIGHT.rotated(TAU * float(index) / 8.0)
				draw_line(
					direction * effect_size * 0.20,
					direction * effect_size * (0.42 + motion_ratio * 0.52),
					Color(color.darkened(0.10), alpha),
					3.0,
					true
				)
		&"rpg_super_dash":
			draw_line(
				Vector2(-effect_size * (0.55 + motion_ratio * 0.45), 0.0),
				Vector2(effect_size * (0.70 + motion_ratio * 0.60), 0.0),
				color,
				6.0,
				true
			)
			draw_line(
				Vector2(-effect_size * 0.28, -effect_size * 0.22),
				Vector2(effect_size * (0.56 + motion_ratio * 0.72), effect_size * 0.18),
				Color(color.lightened(0.22), alpha),
				3.0,
				true
			)
			draw_colored_polygon(
				PackedVector2Array([
					Vector2(effect_size * 0.86, 0.0),
					Vector2(effect_size * 0.42, -effect_size * 0.18),
					Vector2(effect_size * 0.50, effect_size * 0.18)
				]),
				Color(color, alpha * 0.55)
			)
		_:
			for index in range(5):
				var direction := Vector2.RIGHT.rotated(TAU * float(index) / 5.0)
				draw_line(
					direction * effect_size * motion_ratio * 0.25,
					direction * effect_size * (
						0.45 + motion_ratio * 0.55
					),
					color,
					3.0,
					true
				)
