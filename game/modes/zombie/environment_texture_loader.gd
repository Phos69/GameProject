extends RefCounted

const DEFAULT_SIZE := Vector2i(160, 120)
const MIN_TEXTURE_SIZE := 32
const FALLBACK_TEXTURE_BUILDER := preload(
	"res://game/modes/zombie/top_down_fallback_texture_builder.gd"
)

# Session cache keyed by "asset_path@WxH": a rasterized SVG is built once and
# reused across every tile-layer build, region stream, biome change and run.
static var _texture_cache: Dictionary = {}
static var _raster_texture_cache: Dictionary = {}

static func _cache_key(asset_path: String, texture_size: Vector2i) -> String:
	return "%s@%dx%d" % [asset_path, texture_size.x, texture_size.y]

static func clear_cache() -> void:
	_texture_cache.clear()
	_raster_texture_cache.clear()

static func get_cached_texture_count() -> int:
	return _texture_cache.size()

static func has_cached_texture(
	asset_path: String,
	texture_size: Vector2i = DEFAULT_SIZE
) -> bool:
	return _texture_cache.has(_cache_key(asset_path, texture_size))

static func load_texture(
	asset_path: String,
	fallback_primary: Color,
	fallback_accent: Color,
	texture_size: Vector2i = DEFAULT_SIZE
) -> Texture2D:
	if asset_path.is_empty():
		return null
	if not asset_path.ends_with(".svg"):
		return _load_raster_texture(asset_path)
	var cache_key := _cache_key(asset_path, texture_size)
	if _texture_cache.has(cache_key):
		return _texture_cache[cache_key] as Texture2D
	if not FileAccess.file_exists(asset_path):
		return null
	var content := _read_text(asset_path)
	if content.is_empty():
		return null
	var svg_texture := _load_svg_texture_from_content(content, texture_size)
	if svg_texture != null:
		_texture_cache[cache_key] = svg_texture
		return svg_texture
	var imported_texture := _load_imported_texture(asset_path)
	if (
		imported_texture != null
		and _texture_has_transparent_corners(imported_texture)
	):
		_texture_cache[cache_key] = imported_texture
		return imported_texture
	# The procedural fallback depends on the caller's palette colours, so it is
	# intentionally NOT cached by asset path/size (different biomes derive
	# different fallback colours from the same asset id).
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
	return FALLBACK_TEXTURE_BUILDER.build_texture(
		content,
		asset_path,
		texture_size,
		primary,
		secondary,
		accent
	)

static func _load_imported_texture(asset_path: String) -> Texture2D:
	if not ResourceLoader.exists(asset_path):
		return null
	var resource := ResourceLoader.load(asset_path)
	return resource as Texture2D

static func _load_raster_texture(asset_path: String) -> Texture2D:
	var cache_key := "%s@native" % asset_path
	if _raster_texture_cache.has(cache_key):
		return _raster_texture_cache[cache_key] as Texture2D
	if _imported_texture_available(asset_path):
		var imported_texture := _load_imported_texture(asset_path)
		if imported_texture != null:
			_raster_texture_cache[cache_key] = imported_texture
			return imported_texture
	if FileAccess.file_exists(asset_path):
		var image := Image.new()
		var error_code := image.load(ProjectSettings.globalize_path(asset_path))
		if error_code == OK and image.get_width() > 0 and image.get_height() > 0:
			var source_texture := ImageTexture.create_from_image(image)
			_raster_texture_cache[cache_key] = source_texture
			return source_texture
	return null

static func _imported_texture_available(asset_path: String) -> bool:
	var import_path := "%s.import" % asset_path
	if not FileAccess.file_exists(import_path):
		return ResourceLoader.exists(asset_path)
	var config := ConfigFile.new()
	if config.load(import_path) != OK:
		return false
	var imported_path := String(config.get_value("remap", "path", ""))
	return not imported_path.is_empty() and FileAccess.file_exists(imported_path)

static func _load_svg_texture_from_content(
	content: String,
	texture_size: Vector2i
) -> Texture2D:
	var image := Image.new()
	var error_code := ERR_UNAVAILABLE
	if image.has_method("load_svg_from_string"):
		error_code = int(image.call("load_svg_from_string", content, 1.0))
	elif image.has_method("load_svg_from_buffer"):
		error_code = int(
			image.call("load_svg_from_buffer", content.to_utf8_buffer(), 1.0)
		)
	if error_code != OK:
		return null
	if not _image_has_visible_pixels(image):
		return null
	if not _image_has_transparent_corners(image):
		return null
	var target_width := maxi(texture_size.x, MIN_TEXTURE_SIZE)
	var target_height := maxi(texture_size.y, MIN_TEXTURE_SIZE)
	if image.get_width() != target_width or image.get_height() != target_height:
		image.resize(target_width, target_height, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(image)

static func _texture_has_transparent_corners(texture: Texture2D) -> bool:
	if texture == null:
		return false
	var image := texture.get_image()
	if image == null:
		return false
	return _image_has_transparent_corners(image)

static func _image_has_visible_pixels(image: Image) -> bool:
	if image == null or image.get_width() <= 0 or image.get_height() <= 0:
		return false
	var step_x := maxi(int(image.get_width() / 32), 1)
	var step_y := maxi(int(image.get_height() / 24), 1)
	for y in range(0, image.get_height(), step_y):
		for x in range(0, image.get_width(), step_x):
			if image.get_pixel(x, y).a > 0.02:
				return true
	return false

static func _image_has_transparent_corners(image: Image) -> bool:
	if image == null or image.get_width() <= 0 or image.get_height() <= 0:
		return false
	var right := image.get_width() - 1
	var bottom := image.get_height() - 1
	return (
		image.get_pixel(0, 0).a < 0.05
		and image.get_pixel(right, 0).a < 0.05
		and image.get_pixel(0, bottom).a < 0.05
		and image.get_pixel(right, bottom).a < 0.05
	)

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
