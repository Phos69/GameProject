extends RefCounted

const DEFAULT_SIZE := Vector2i(160, 120)

static func load_texture(
	asset_path: String,
	fallback_primary: Color,
	fallback_accent: Color,
	texture_size: Vector2i = DEFAULT_SIZE
) -> Texture2D:
	if asset_path.is_empty():
		return null
	if not asset_path.ends_with(".svg"):
		return load(asset_path) as Texture2D
	if not FileAccess.file_exists(asset_path):
		return null
	var content := _read_text(asset_path)
	if content.is_empty():
		return null
	var colors := _extract_hex_colors(content)
	var primary := fallback_primary
	var secondary := Color(0.14, 0.16, 0.18, 1.0)
	var accent := fallback_accent
	if colors.size() >= 1:
		primary = colors[0]
	if colors.size() >= 2:
		secondary = colors[1]
	if colors.size() >= 3:
		accent = colors[2]
	return _build_slot_texture(texture_size, primary, secondary, accent)

static func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text

static func _extract_hex_colors(content: String) -> Array[Color]:
	var result: Array[Color] = []
	var index := 0
	while index < content.length():
		var hash_index := content.find("#", index)
		if hash_index < 0 or hash_index + 7 > content.length():
			break
		var hex := content.substr(hash_index + 1, 6)
		if _is_hex_color(hex):
			var color := Color.html("#" + hex)
			if not result.has(color):
				result.append(color)
		index = hash_index + 7
	return result

static func _is_hex_color(value: String) -> bool:
	if value.length() != 6:
		return false
	for char_index in range(value.length()):
		var code := value.unicode_at(char_index)
		var is_digit := code >= 48 and code <= 57
		var is_upper := code >= 65 and code <= 70
		var is_lower := code >= 97 and code <= 102
		if not is_digit and not is_upper and not is_lower:
			return false
	return true

static func _build_slot_texture(
	texture_size: Vector2i,
	primary: Color,
	secondary: Color,
	accent: Color
) -> Texture2D:
	var width := maxi(texture_size.x, 32)
	var height := maxi(texture_size.y, 32)
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	_draw_ellipse(
		image,
		Vector2(width * 0.5, height * 0.70),
		Vector2(width * 0.36, height * 0.15),
		Color(0.01, 0.012, 0.016, 0.38)
	)
	_draw_diamond(
		image,
		Vector2(width * 0.5, height * 0.66),
		Vector2(width * 0.28, height * 0.17),
		secondary,
		accent
	)
	_draw_block(
		image,
		Rect2i(
			Vector2i(int(width * 0.34), int(height * 0.35)),
			Vector2i(int(width * 0.32), int(height * 0.27))
		),
		primary,
		accent
	)
	_draw_roof(
		image,
		Vector2(width * 0.5, height * 0.22),
		Vector2(width * 0.24, height * 0.15),
		primary.lightened(0.12),
		accent
	)
	return ImageTexture.create_from_image(image)

static func _draw_ellipse(
	image: Image,
	center: Vector2,
	radius: Vector2,
	color: Color
) -> void:
	var min_x := maxi(int(center.x - radius.x), 0)
	var max_x := mini(int(center.x + radius.x), image.get_width() - 1)
	var min_y := maxi(int(center.y - radius.y), 0)
	var max_y := mini(int(center.y + radius.y), image.get_height() - 1)
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var offset := Vector2(
				(float(x) - center.x) / radius.x,
				(float(y) - center.y) / radius.y
			)
			if offset.length_squared() <= 1.0:
				_blend_pixel(image, x, y, color)

static func _draw_diamond(
	image: Image,
	center: Vector2,
	radius: Vector2,
	fill: Color,
	stroke: Color
) -> void:
	var min_x := maxi(int(center.x - radius.x), 0)
	var max_x := mini(int(center.x + radius.x), image.get_width() - 1)
	var min_y := maxi(int(center.y - radius.y), 0)
	var max_y := mini(int(center.y + radius.y), image.get_height() - 1)
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var normalized := (
				absf(float(x) - center.x) / radius.x
				+ absf(float(y) - center.y) / radius.y
			)
			if normalized <= 1.0:
				var pixel_color := stroke if normalized > 0.88 else fill
				_blend_pixel(image, x, y, pixel_color)

static func _draw_block(
	image: Image,
	rect: Rect2i,
	fill: Color,
	stroke: Color
) -> void:
	var left := clampi(rect.position.x, 0, image.get_width() - 1)
	var top := clampi(rect.position.y, 0, image.get_height() - 1)
	var right := clampi(rect.position.x + rect.size.x, 0, image.get_width() - 1)
	var bottom := clampi(rect.position.y + rect.size.y, 0, image.get_height() - 1)
	for y in range(top, bottom + 1):
		for x in range(left, right + 1):
			var is_border := (
				x <= left + 2
				or x >= right - 2
				or y <= top + 2
				or y >= bottom - 2
			)
			var shade := 0.12 * clampf(float(y - top) / maxf(float(bottom - top), 1.0), 0.0, 1.0)
			var color := stroke if is_border else fill.darkened(shade)
			_blend_pixel(image, x, y, color)

static func _draw_roof(
	image: Image,
	apex: Vector2,
	radius: Vector2,
	fill: Color,
	stroke: Color
) -> void:
	var min_x := maxi(int(apex.x - radius.x), 0)
	var max_x := mini(int(apex.x + radius.x), image.get_width() - 1)
	var min_y := maxi(int(apex.y), 0)
	var max_y := mini(int(apex.y + radius.y), image.get_height() - 1)
	for y in range(min_y, max_y + 1):
		var progress := clampf((float(y) - apex.y) / radius.y, 0.0, 1.0)
		var half_width := lerpf(0.0, radius.x, progress)
		for x in range(maxi(int(apex.x - half_width), min_x), mini(int(apex.x + half_width), max_x) + 1):
			var border := (
				absf(float(x) - apex.x) >= half_width - 2.0
				or y >= max_y - 2
			)
			_blend_pixel(image, x, y, stroke if border else fill)

static func _blend_pixel(image: Image, x: int, y: int, color: Color) -> void:
	var existing := image.get_pixel(x, y)
	var alpha := color.a + existing.a * (1.0 - color.a)
	if alpha <= 0.0:
		image.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
		return
	var blended := Color(
		(color.r * color.a + existing.r * existing.a * (1.0 - color.a)) / alpha,
		(color.g * color.a + existing.g * existing.a * (1.0 - color.a)) / alpha,
		(color.b * color.a + existing.b * existing.a * (1.0 - color.a)) / alpha,
		alpha
	)
	image.set_pixel(x, y, blended)
