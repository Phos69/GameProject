extends Node2D
class_name ZombieBossVisual

@export var profile_id: StringName = &"zombie_boss"
@export_file("*.png") var sprite_path: String = ""
@export var sprite_target_height: float = 172.0
@export var sprite_offset: Vector2 = Vector2(0.0, -42.0)
@export var body_color: Color = Color(0.34, 0.42, 0.28, 1.0)
@export var armor_color: Color = Color(0.20, 0.22, 0.21, 1.0)
@export var accent_color: Color = Color(0.38, 0.92, 0.78, 1.0)
@export var phase_two_tint: Color = Color(1.0, 0.82, 0.72, 1.0)
@export var shadow_size: Vector2 = Vector2(58.0, 16.0)

var phase_index: int = 1
var aim_direction: Vector2 = Vector2.RIGHT
var active_pattern: StringName = &""
var animation_time: float = 0.0
var hurt_timer: float = 0.0
var spawn_timer: float = 0.0
var flash_intensity: float = 1.0
var glow_intensity: float = 1.0
var reduced_motion: bool = false
var sprite: Sprite2D

func _ready() -> void:
	add_to_group("visual_settings_consumers")
	_load_sprite_asset()
	VisualSettingsManager.sync_consumer(self)
	queue_redraw()

func _process(delta: float) -> void:
	if not reduced_motion:
		animation_time += delta
	hurt_timer = maxf(hurt_timer - delta, 0.0)
	spawn_timer = maxf(spawn_timer - delta, 0.0)
	_update_sprite_transform()
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
	_update_sprite_transform()
	queue_redraw()

func set_facing(direction: Vector2) -> void:
	if direction.length_squared() <= 0.01:
		return
	aim_direction = direction.normalized()
	_update_sprite_transform()

func set_phase(value: int) -> void:
	phase_index = maxi(value, 1)
	_update_sprite_transform()
	queue_redraw()

func set_attack_charge(pattern_id: StringName) -> void:
	active_pattern = pattern_id
	queue_redraw()

func clear_attack_charge() -> void:
	active_pattern = &""
	queue_redraw()

func play_hurt() -> void:
	hurt_timer = 0.14
	_update_sprite_transform()
	queue_redraw()

func play_spawn() -> void:
	spawn_timer = 0.65
	queue_redraw()

func get_profile_id() -> StringName:
	return profile_id

func get_sprite_path() -> String:
	return sprite_path

func uses_sprite_asset() -> bool:
	return sprite != null and sprite.texture != null

func _load_sprite_asset() -> void:
	if sprite_path.is_empty() or not ResourceLoader.exists(sprite_path):
		return
	var texture := ResourceLoader.load(sprite_path) as Texture2D
	if texture == null or texture.get_height() <= 0:
		return
	sprite = Sprite2D.new()
	sprite.name = "GeneratedBossSprite"
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.centered = true
	sprite.z_index = 0
	add_child(sprite)
	_update_sprite_transform()

func _update_sprite_transform() -> void:
	if sprite == null or sprite.texture == null:
		return
	var base_scale := sprite_target_height / maxf(
		float(sprite.texture.get_height()),
		1.0
	)
	var flip_sign := -1.0 if aim_direction.x < -0.02 else 1.0
	var phase_pulse := (
		1.0 + sin(animation_time * 3.8) * 0.018
		if phase_index >= 2 and not reduced_motion
		else 1.0
	)
	sprite.scale = Vector2(flip_sign * base_scale, base_scale) * phase_pulse
	var hover := sin(animation_time * 2.5) * 2.5 if not reduced_motion else 0.0
	sprite.position = sprite_offset + Vector2(0.0, hover)
	var tint := phase_two_tint if phase_index >= 2 else Color.WHITE
	if hurt_timer > 0.0:
		tint = tint.lerp(Color.WHITE, flash_intensity)
	sprite.modulate = tint

func _draw() -> void:
	_draw_shadow()
	if not uses_sprite_asset():
		_draw_procedural_fallback()
	if not active_pattern.is_empty():
		_draw_attack_charge()
	if spawn_timer > 0.0:
		_draw_spawn_ring()

func _draw_shadow() -> void:
	draw_colored_polygon(
		_ellipse_points(Vector2(0.0, 35.0), shadow_size, 28),
		Color(0.01, 0.015, 0.012, 0.54)
	)

func _draw_attack_charge() -> void:
	var charge_radius := 48.0
	if not reduced_motion:
		charge_radius += sin(animation_time * 13.0) * 4.0
	var charge_color := Color(
		accent_color,
		0.34 + 0.58 * maxf(glow_intensity, 0.10)
	)
	draw_arc(
		Vector2(0.0, -5.0),
		charge_radius,
		0.0,
		TAU,
		40,
		charge_color,
		4.5,
		true
	)
	for index in range(6):
		var direction := Vector2.RIGHT.rotated(
		animation_time * 1.8 + TAU * float(index) / 6.0
		)
		draw_line(
			direction * 54.0 + Vector2(0.0, -5.0),
			direction * 65.0 + Vector2(0.0, -5.0),
			Color(charge_color, charge_color.a * 0.72),
			3.0,
			true
		)

func _draw_spawn_ring() -> void:
	var ratio := 1.0 - spawn_timer / 0.65
	draw_arc(
		Vector2(0.0, -5.0),
		84.0 - ratio * 28.0,
		0.0,
		TAU,
		44,
		Color(accent_color, 1.0 - ratio),
		5.0,
		true
	)

func _draw_procedural_fallback() -> void:
	var resolved_body := body_color
	var resolved_armor := armor_color
	if phase_index >= 2:
		resolved_body = resolved_body.lerp(accent_color, 0.20)
		resolved_armor = resolved_armor.lerp(accent_color, 0.16)
	if hurt_timer > 0.0:
		resolved_body = resolved_body.lerp(Color.WHITE, flash_intensity)
		resolved_armor = resolved_armor.lerp(Color.WHITE, flash_intensity)
	match profile_id:
		&"grave_colossus":
			_draw_grave_colossus(resolved_body, resolved_armor)
		&"gore_charger":
			_draw_gore_charger(resolved_body, resolved_armor)
		&"plague_spitter":
			_draw_plague_spitter(resolved_body, resolved_armor)
		&"bone_mortar":
			_draw_bone_mortar(resolved_body, resolved_armor)
		&"carrion_shepherd":
			_draw_carrion_shepherd(resolved_body, resolved_armor)
		_:
			draw_circle(Vector2(0.0, -8.0), 42.0, resolved_body)

func _draw_grave_colossus(body: Color, armor: Color) -> void:
	draw_rect(Rect2(-34.0, -58.0, 68.0, 92.0), body, true)
	draw_rect(Rect2(-44.0, -68.0, 34.0, 74.0), armor, true)
	draw_rect(Rect2(27.0, -28.0, 54.0, 22.0), accent_color.darkened(0.35), true)
	draw_circle(Vector2(12.0, -48.0), 6.0, accent_color)

func _draw_gore_charger(body: Color, armor: Color) -> void:
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(-50.0, 24.0), Vector2(-40.0, -35.0),
			Vector2(24.0, -49.0), Vector2(55.0, 6.0), Vector2(34.0, 34.0)
		]),
		body
	)
	draw_arc(Vector2(22.0, -32.0), 37.0, -1.9, -0.15, 18, armor, 10.0, true)
	draw_arc(Vector2(18.0, -26.0), 48.0, 0.15, 1.55, 18, armor, 9.0, true)

func _draw_plague_spitter(body: Color, armor: Color) -> void:
	draw_circle(Vector2(-14.0, -12.0), 44.0, body)
	draw_circle(Vector2(-26.0, -54.0), 25.0, accent_color.darkened(0.18))
	draw_circle(Vector2(5.0, -60.0), 20.0, accent_color)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(16.0, -38.0), Vector2(62.0, -20.0),
			Vector2(18.0, -4.0)
		]),
		armor
	)

func _draw_bone_mortar(body: Color, armor: Color) -> void:
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(-36.0, 32.0), Vector2(-26.0, -48.0),
			Vector2(18.0, -55.0), Vector2(38.0, 30.0)
		]),
		body
	)
	draw_rect(Rect2(-18.0, -92.0, 28.0, 84.0), armor, true)
	draw_circle(Vector2(-4.0, -88.0), 11.0, accent_color)

func _draw_carrion_shepherd(body: Color, armor: Color) -> void:
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(-23.0, 35.0), Vector2(-31.0, -44.0),
			Vector2(8.0, -68.0), Vector2(24.0, 30.0)
		]),
		body
	)
	draw_arc(Vector2(32.0, -35.0), 47.0, -1.35, 1.15, 22, armor, 8.0, true)
	for index in range(3):
		draw_circle(Vector2(-30.0 + index * 14.0, -54.0), 11.0, accent_color)

func _ellipse_points(
	center: Vector2,
	radius: Vector2,
	segments: int
) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(segments):
		var angle := TAU * float(index) / float(segments)
		points.append(
			center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y)
		)
	return points
