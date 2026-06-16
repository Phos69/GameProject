extends Control
class_name CharacterGameplayPreview

var character_profile: Dictionary = {}
var weapon_data: WeaponData
var gameplay_texture: Texture2D
var gameplay_texture_path: String = ""
var gameplay_texture_cache: Dictionary = {}
var animation_time: float = 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(292.0, 178.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	animation_time += delta
	queue_redraw()

func set_profile(profile: Dictionary, next_weapon_data: WeaponData = null) -> void:
	character_profile = profile.duplicate(true)
	weapon_data = next_weapon_data
	gameplay_texture_path = str(character_profile.get("gameplay_sprite_path", ""))
	gameplay_texture = _load_gameplay_texture(gameplay_texture_path)
	queue_redraw()

func has_asset_preview() -> bool:
	return gameplay_texture != null

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var primary := Color(character_profile.get("palette_primary", Color(0.22, 0.58, 0.82, 1.0)))
	var secondary := Color(character_profile.get("palette_secondary", Color(0.70, 0.78, 0.86, 1.0)))
	var accent := Color(character_profile.get("palette_accent", Color(1.0, 0.76, 0.28, 1.0)))
	_draw_background(rect, primary, accent)
	if character_profile.is_empty():
		return
	if gameplay_texture != null:
		_draw_asset_preview(
			Vector2(size.x * 0.50, size.y * 0.62),
			minf(size.x / 290.0, size.y / 178.0),
			primary,
			accent
		)
		return
	_draw_player_preview(
		Vector2(size.x * 0.50, size.y * 0.62),
		minf(size.x / 290.0, size.y / 178.0),
		primary,
		secondary,
		accent
	)

func _draw_asset_preview(
	origin: Vector2,
	scale: float,
	primary: Color,
	accent: Color
) -> void:
	var bob := sin(animation_time * 2.4) * 2.0
	var pulse := 1.0 + sin(animation_time * 3.0) * 0.018
	var target_size := Vector2(118.0, 118.0) * scale * pulse
	var texture_size := gameplay_texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		_draw_player_preview(
			origin,
			scale,
			primary,
			Color(character_profile.get("palette_secondary", primary.lightened(0.3))),
			accent
		)
		return
	var aspect := texture_size.x / texture_size.y
	if aspect >= 1.0:
		target_size.y = target_size.x / aspect
	else:
		target_size.x = target_size.y * aspect
	var rect := Rect2(
		origin - Vector2(target_size.x * 0.5, target_size.y * 0.58) + Vector2(0.0, bob),
		target_size
	)
	draw_colored_polygon(
		_ellipse_points(origin + Vector2(0.0, 33.0), Vector2(48.0, 12.0) * scale, 24),
		Color(0.0, 0.0, 0.0, 0.42)
	)
	draw_arc(
		origin + Vector2(0.0, -10.0),
		64.0 * scale,
		0.0,
		TAU,
		40,
		Color(accent, 0.20),
		5.0,
		true
	)
	draw_texture_rect(gameplay_texture, rect, false)
	draw_arc(
		origin + Vector2(0.0, -10.0),
		68.0 * scale,
		0.0,
		TAU,
		40,
		Color(primary.lightened(0.20), 0.22),
		2.0,
		true
	)

func _draw_background(rect: Rect2, primary: Color, accent: Color) -> void:
	draw_rect(rect, Color(0.018, 0.025, 0.032, 1.0), true)
	var floor_center := Vector2(rect.size.x * 0.50, rect.size.y * 0.68)
	var floor := PackedVector2Array([
		floor_center + Vector2(0.0, -54.0),
		floor_center + Vector2(118.0, 0.0),
		floor_center + Vector2(0.0, 54.0),
		floor_center + Vector2(-118.0, 0.0)
	])
	var closed_floor := PackedVector2Array(floor)
	closed_floor.append(floor[0])
	draw_colored_polygon(floor, Color(0.055, 0.070, 0.076, 1.0))
	draw_polyline(closed_floor, Color(0.18, 0.22, 0.24, 0.9), 2.0, true)
	for index in range(-3, 4):
		var offset := float(index) * 28.0
		draw_line(
			floor_center + Vector2(offset, -54.0),
			floor_center + Vector2(offset + 118.0, 0.0),
			Color(0.11, 0.14, 0.15, 0.38),
			1.0
		)
		draw_line(
			floor_center + Vector2(offset, -54.0),
			floor_center + Vector2(offset - 118.0, 0.0),
			Color(0.11, 0.14, 0.15, 0.38),
			1.0
		)
	for marker in [
		Vector2(rect.size.x * 0.16, rect.size.y * 0.47),
		Vector2(rect.size.x * 0.83, rect.size.y * 0.45),
		Vector2(rect.size.x * 0.76, rect.size.y * 0.79)
	]:
		draw_circle(marker + Vector2(0.0, 10.0), 13.0, Color(0.0, 0.0, 0.0, 0.24))
		draw_circle(marker, 8.0, Color(0.05, 0.11, 0.08, 0.55))
		draw_line(marker + Vector2(-5.0, 8.0), marker + Vector2(5.0, -6.0), Color(0.02, 0.05, 0.035, 0.7), 4.0, true)
	draw_arc(rect.get_center(), minf(rect.size.x, rect.size.y) * 0.47, 0.0, TAU, 48, Color(primary, 0.12), 8.0, true)
	draw_line(
		Vector2(12.0, rect.size.y - 16.0),
		Vector2(rect.size.x - 12.0, rect.size.y - 16.0),
		Color(accent, 0.38),
		2.0,
		true
	)

func _draw_player_preview(
	origin: Vector2,
	scale: float,
	primary: Color,
	secondary: Color,
	accent: Color
) -> void:
	var character_id := StringName(character_profile.get("id", &""))
	var weapon_id := weapon_data.weapon_id if weapon_data != null else StringName("rpg_%s" % str(character_profile.get("base_weapon_id", "weapon")))
	var bob := sin(animation_time * 2.4) * 2.0
	var pulse := 1.0 + sin(animation_time * 3.0) * 0.025
	draw_set_transform(origin + Vector2(0.0, bob), 0.0, Vector2.ONE * scale * pulse)
	draw_colored_polygon(_ellipse_points(Vector2(0.0, 27.0), Vector2(34.0, 10.0), 22), Color(0.0, 0.0, 0.0, 0.44))
	var outline := Color(0.016, 0.020, 0.025, 1.0)
	var torso := PackedVector2Array([
		Vector2(-19.0, -14.0),
		Vector2(18.0, -14.0),
		Vector2(22.0, 13.0),
		Vector2(0.0, 24.0),
		Vector2(-22.0, 13.0)
	])
	draw_line(Vector2(-10.0, 12.0), Vector2(-16.0, 32.0), outline, 8.0, true)
	draw_line(Vector2(10.0, 12.0), Vector2(16.0, 32.0), outline, 8.0, true)
	draw_colored_polygon(torso, outline)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-15.0, -11.0),
		Vector2(14.0, -11.0),
		Vector2(17.0, 10.0),
		Vector2(0.0, 19.0),
		Vector2(-17.0, 10.0)
	]), primary.darkened(0.08))
	draw_line(Vector2(0.0, -10.0), Vector2(0.0, 17.0), accent, 3.0, true)
	_draw_class_details(character_id, secondary, accent, outline)
	draw_circle(Vector2(0.0, -25.0), 13.0, outline)
	draw_circle(Vector2(0.0, -26.0), 9.5, secondary.lightened(0.18))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-10.0, -28.0),
		Vector2(-4.0, -39.0),
		Vector2(10.0, -34.0),
		Vector2(8.0, -25.0),
		Vector2(1.0, -29.0)
	]), outline)
	var direction := Vector2(1.0, -0.22).normalized()
	var hand := Vector2(18.0, -5.0)
	draw_line(Vector2(11.0, -8.0), hand, Color(0.78, 0.58, 0.40, 1.0), 6.0, true)
	draw_line(Vector2(-11.0, -8.0), hand * 0.62, Color(0.78, 0.58, 0.40, 1.0), 5.0, true)
	_draw_weapon(hand, direction, weapon_id, primary, accent)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_class_details(
	character_id: StringName,
	secondary: Color,
	accent: Color,
	outline: Color
) -> void:
	match character_id:
		&"ranger":
			draw_colored_polygon(PackedVector2Array([Vector2(-12.0, -28.0), Vector2(0.0, -44.0), Vector2(13.0, -28.0), Vector2(0.0, -20.0)]), outline)
			draw_line(Vector2(-16.0, -5.0), Vector2(13.0, 18.0), secondary, 4.0, true)
		&"pistoliere":
			draw_rect(Rect2(Vector2(-15.0, -16.0), Vector2(30.0, 12.0)), secondary.darkened(0.18), true)
			draw_line(Vector2(-10.0, -39.0), Vector2(12.0, -36.0), accent, 4.0, true)
		&"berserker":
			draw_line(Vector2(-24.0, -9.0), Vector2(24.0, -9.0), outline, 11.0, true)
			draw_rect(Rect2(Vector2(-25.0, -18.0), Vector2(12.0, 14.0)), secondary, true)
		&"spadaccino":
			draw_colored_polygon(PackedVector2Array([Vector2(-15.0, -13.0), Vector2(16.0, -10.0), Vector2(12.0, 20.0), Vector2(-4.0, 25.0)]), secondary.darkened(0.10))
			draw_line(Vector2(10.0, -34.0), Vector2(25.0, -27.0), accent, 3.0, true)
		&"mago":
			draw_colored_polygon(PackedVector2Array([Vector2(-18.0, -13.0), Vector2(18.0, -13.0), Vector2(24.0, 20.0), Vector2(0.0, 30.0), Vector2(-24.0, 20.0)]), secondary.darkened(0.25))
			draw_circle(Vector2(18.0, -39.0), 6.0, accent)
		&"domatrice":
			draw_rect(Rect2(Vector2(-20.0, -16.0), Vector2(12.0, 27.0)), secondary, true)
			draw_circle(Vector2(-15.0, -34.0), 3.0, accent)
		&"licantropo":
			draw_line(Vector2(-22.0, -4.0), Vector2(-34.0, 13.0), accent, 5.0, true)
			draw_line(Vector2(22.0, -4.0), Vector2(34.0, 13.0), accent, 5.0, true)

func _draw_weapon(
	hand: Vector2,
	direction: Vector2,
	weapon_id: StringName,
	primary: Color,
	accent: Color
) -> void:
	var perpendicular := direction.orthogonal()
	var length := 34.0
	var muzzle := hand + direction * length
	match weapon_id:
		&"rpg_bow":
			var bow_center := hand + direction * 16.0
			draw_arc(bow_center, 22.0, direction.angle() - 1.0, direction.angle() + 1.0, 22, accent, 3.0, true)
			draw_line(hand - perpendicular * 16.0, hand + perpendicular * 16.0, primary.darkened(0.28), 3.0, true)
			draw_line(hand, muzzle, accent.lightened(0.18), 2.0, true)
		&"rpg_axe":
			draw_line(hand - direction * 4.0, muzzle, primary.darkened(0.35), 8.0, true)
			draw_colored_polygon(PackedVector2Array([
				muzzle - direction * 12.0 + perpendicular * 14.0,
				muzzle + perpendicular * 8.0,
				muzzle - direction * 6.0 - perpendicular * 16.0,
				muzzle - direction * 20.0 - perpendicular * 5.0
			]), accent)
		&"rpg_sword":
			draw_line(hand - direction * 4.0, hand + direction * 9.0, primary.darkened(0.35), 9.0, true)
			draw_colored_polygon(PackedVector2Array([
				hand + direction * 8.0 + perpendicular * 4.0,
				muzzle + perpendicular * 2.0,
				muzzle + direction * 7.0,
				muzzle - perpendicular * 2.0,
				hand + direction * 8.0 - perpendicular * 4.0
			]), accent.lightened(0.15))
		&"rpg_staff":
			draw_line(hand - direction * 8.0, muzzle + direction * 8.0, primary.darkened(0.25), 5.0, true)
			draw_circle(muzzle + direction * 8.0, 9.0, Color(accent, 0.45))
			draw_arc(muzzle + direction * 8.0, 11.0, 0.0, TAU, 24, accent, 3.0, true)
		&"rpg_slingshot":
			var fork := hand + direction * 22.0
			draw_line(hand, fork, primary.darkened(0.30), 6.0, true)
			draw_line(fork, muzzle + perpendicular * 9.0, primary.darkened(0.25), 4.0, true)
			draw_line(fork, muzzle - perpendicular * 9.0, primary.darkened(0.25), 4.0, true)
			draw_line(muzzle + perpendicular * 9.0, muzzle - perpendicular * 9.0, accent, 2.0, true)
		&"rpg_claws":
			for claw_index in range(3):
				var offset := (float(claw_index) - 1.0) * 5.0
				draw_line(hand + perpendicular * offset, muzzle + perpendicular * offset + direction * 5.0, accent, 3.0, true)
		_:
			draw_colored_polygon(PackedVector2Array([
				hand + perpendicular * 5.0,
				muzzle + perpendicular * 4.0,
				muzzle - perpendicular * 4.0,
				hand - perpendicular * 5.0
			]), primary.darkened(0.35))
			draw_line(hand + direction * 4.0, muzzle - direction * 2.0, accent, 3.0, true)

func _ellipse_points(center: Vector2, radius: Vector2, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(segments):
		var angle := TAU * float(index) / float(segments)
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	return points

func _load_gameplay_texture(path: String) -> Texture2D:
	if path.is_empty() or not FileAccess.file_exists(path):
		return null
	if gameplay_texture_cache.has(path):
		return gameplay_texture_cache[path] as Texture2D
	var image := Image.new()
	if image.load(path) != OK:
		return null
	var texture := ImageTexture.create_from_image(image)
	gameplay_texture_cache[path] = texture
	return texture
