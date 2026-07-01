extends RefCounted
class_name GeneratedBiomeTextureTools

const GENERATED_SURFACE_TEXTURE_EDGE_TRIM_PIXELS := 2
const GENERATED_CLIFF_TEXTURE_EDGE_TRIM_PIXELS := 12
const BURNING_FIELDS_GENERATED_TEXTURE_EDGE_TRIM_PIXELS := 10
const BURNING_FIELDS_EDGE_BLEND_PIXELS := 18
const FROZEN_ROUTE_SNOW_BLEND := 0.16
const FROZEN_ROAD_SNOW_BLEND := 0.24
const FROZEN_SNOW_BLEND_COLOR := Color(0.82, 0.90, 0.97, 1.0)

# Cache di sessione delle texture normalizzate, keyed su asset_path + parametri.
# La normalizzazione gira pixel-per-pixel in GDScript: senza cache veniva rifatta
# a ogni configure() di regione (hitch sul main thread durante lo streaming) e
# ogni chiamata caricava in VRAM una ImageTexture duplicata della stessa asset.
# Il path identifica il contenuto sorgente perche' gli asset generati sono PNG
# raster serviti dalla cache per-path di IsometricSvgTextureLoader.
static var _normalized_texture_cache: Dictionary = {}

static func clear_cache() -> void:
	_normalized_texture_cache.clear()

static func get_cached_normalized_texture_count() -> int:
	return _normalized_texture_cache.size()

static func surface_edge_trim_pixels(biome_id: StringName) -> int:
	if biome_id == &"burning_fields":
		return BURNING_FIELDS_GENERATED_TEXTURE_EDGE_TRIM_PIXELS
	return GENERATED_SURFACE_TEXTURE_EDGE_TRIM_PIXELS

static func cliff_edge_trim_pixels(_biome_id: StringName) -> int:
	return GENERATED_CLIFF_TEXTURE_EDGE_TRIM_PIXELS

static func should_harmonize_surface_edges(biome_id: StringName) -> bool:
	return biome_id == &"burning_fields"

static func should_harmonize_cliff_edges(biome_id: StringName) -> bool:
	return biome_id == &"burning_fields"

static func normalize_surface_texture(
	texture: Texture2D,
	biome_id: StringName,
	asset_path: String
) -> Texture2D:
	if texture == null:
		return null
	# Trim/harmonize/blend neve derivano tutti da biome_id + asset_path, quindi
	# la coppia identifica completamente l'output normalizzato.
	var cache_key := "surface|%s|%s" % [String(biome_id), asset_path]
	if not asset_path.is_empty() and _normalized_texture_cache.has(cache_key):
		return _normalized_texture_cache[cache_key] as Texture2D
	var normalized := _normalize_repeating_texture_uncached(
		texture,
		surface_edge_trim_pixels(biome_id),
		should_harmonize_surface_edges(biome_id),
		BURNING_FIELDS_EDGE_BLEND_PIXELS
	)
	if biome_id == &"frozen_outskirts":
		normalized = _harmonize_frozen_surface_texture(normalized, asset_path)
	if not asset_path.is_empty() and normalized != null:
		_normalized_texture_cache[cache_key] = normalized
	return normalized

## `cache_key` (di norma l'asset_path sorgente) abilita la cache di sessione:
## vuoto = normalizzazione sempre ricalcolata (input non identificabili per path).
static func normalize_repeating_texture(
	texture: Texture2D,
	trim: int,
	harmonize_edges: bool = false,
	blend_pixels: int = BURNING_FIELDS_EDGE_BLEND_PIXELS,
	cache_key: String = ""
) -> Texture2D:
	if texture == null:
		return null
	var full_key := ""
	if not cache_key.is_empty():
		full_key = "repeat|%s|%d|%s|%d" % [
			cache_key,
			trim,
			str(harmonize_edges),
			blend_pixels
		]
		if _normalized_texture_cache.has(full_key):
			return _normalized_texture_cache[full_key] as Texture2D
	var result := _normalize_repeating_texture_uncached(
		texture,
		trim,
		harmonize_edges,
		blend_pixels
	)
	# Anche i passthrough (immagine non leggibile) vengono cache-ati: rifallire
	# costa comunque un get_image() dalla VRAM a ogni chiamata.
	if not full_key.is_empty() and result != null:
		_normalized_texture_cache[full_key] = result
	return result

static func _normalize_repeating_texture_uncached(
	texture: Texture2D,
	trim: int,
	harmonize_edges: bool,
	blend_pixels: int
) -> Texture2D:
	if texture == null:
		return null
	var image := texture.get_image()
	if image == null or image.is_empty():
		return texture
	if image.is_compressed():
		var decompress_error := image.decompress()
		if decompress_error != OK:
			return texture
	var normalized := _copy_or_crop_image(image, trim)
	if normalized == null or normalized.is_empty():
		return texture
	normalized.convert(Image.FORMAT_RGBA8)
	if harmonize_edges:
		_harmonize_repeating_texture_edges(normalized, blend_pixels)
	# Generated cutouts often keep white RGB in transparent edge pixels.
	# Bleed neighbour colour into alpha so repeat/filter sampling cannot expose it.
	normalized.fix_alpha_edges()
	return ImageTexture.create_from_image(normalized)

static func _copy_or_crop_image(image: Image, trim: int) -> Image:
	var safe_trim := maxi(trim, 0)
	var source_rect := Rect2i(Vector2i.ZERO, image.get_size())
	if (
		safe_trim > 0
		and image.get_width() > safe_trim * 2
		and image.get_height() > safe_trim * 2
	):
		source_rect = Rect2i(
			Vector2i(safe_trim, safe_trim),
			Vector2i(
				image.get_width() - safe_trim * 2,
				image.get_height() - safe_trim * 2
			)
		)
	return image.get_region(source_rect)

static func _harmonize_repeating_texture_edges(
	image: Image,
	blend_pixels: int
) -> void:
	if image == null or image.is_empty() or blend_pixels <= 0:
		return
	var width := image.get_width()
	var height := image.get_height()
	var blend_width := mini(blend_pixels, int(mini(width, height) / 2))
	if blend_width <= 0:
		return
	for offset in range(blend_width):
		var blend := 1.0 - (float(offset) / float(blend_width))
		blend *= blend
		var left_x := offset
		var right_x := width - 1 - offset
		for y in range(height):
			var left := image.get_pixel(left_x, y)
			var right := image.get_pixel(right_x, y)
			var average := left.lerp(right, 0.5)
			image.set_pixel(left_x, y, left.lerp(average, blend))
			image.set_pixel(right_x, y, right.lerp(average, blend))
	for offset in range(blend_width):
		var blend := 1.0 - (float(offset) / float(blend_width))
		blend *= blend
		var top_y := offset
		var bottom_y := height - 1 - offset
		for x in range(width):
			var top := image.get_pixel(x, top_y)
			var bottom := image.get_pixel(x, bottom_y)
			var average := top.lerp(bottom, 0.5)
			image.set_pixel(x, top_y, top.lerp(average, blend))
			image.set_pixel(x, bottom_y, bottom.lerp(average, blend))

static func _harmonize_frozen_surface_texture(
	texture: Texture2D,
	asset_path: String
) -> Texture2D:
	var snow_blend := _frozen_surface_snow_blend(asset_path)
	if snow_blend <= 0.0 or texture == null:
		return texture
	var image := texture.get_image()
	if image == null or image.is_empty():
		return texture
	if image.is_compressed():
		var decompress_error := image.decompress()
		if decompress_error != OK:
			return texture
	image.convert(Image.FORMAT_RGBA8)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var source := image.get_pixel(x, y)
			if source.a <= 0.01:
				continue
			var adjusted := source.lerp(
				FROZEN_SNOW_BLEND_COLOR,
				snow_blend * source.a
			)
			adjusted.a = source.a
			image.set_pixel(x, y, adjusted)
	image.fix_alpha_edges()
	return ImageTexture.create_from_image(image)

static func _frozen_surface_snow_blend(asset_path: String) -> float:
	if asset_path.contains("road_variation"):
		return FROZEN_ROAD_SNOW_BLEND
	if asset_path.contains("path_variation"):
		return FROZEN_ROUTE_SNOW_BLEND
	return 0.0
