extends RefCounted
class_name GeneratedBiomeTextureTools

const GENERATED_SURFACE_TEXTURE_EDGE_TRIM_PIXELS := 2
const GENERATED_CLIFF_TEXTURE_EDGE_TRIM_PIXELS := 12
const BURNING_FIELDS_GENERATED_TEXTURE_EDGE_TRIM_PIXELS := 10
const BURNING_FIELDS_EDGE_BLEND_PIXELS := 18
const BURNING_SURFACE_EDGE_BLEND_PIXELS := 40
const FROZEN_SURFACE_EDGE_BLEND_PIXELS := 40
const MARSH_SURFACE_EDGE_BLEND_PIXELS := 40
const GROUND_MACRO_SEAM_BLEND_PIXELS := 128
# Blend ridotti (ART-VIS-FIX): a 0.16/0.24 route e ghiaccio diventavano quasi
# indistinguibili dalla neve sovraesposta (VIS-002/VIS-006). Il minimo utile per
# il contratto "snow softened" del test e' ~0.10.
const FROZEN_ROUTE_SNOW_BLEND := 0.10
const FROZEN_ROAD_SNOW_BLEND := 0.12
const FROZEN_SNOW_BLEND_COLOR := Color(0.82, 0.90, 0.97, 1.0)
# Tinta moltiplicativa del manto nevoso base: abbassa l'esposizione del bianco
# pieno verso un grigio neutro (niente dominante azzurra aggiuntiva), cosi'
# attori, crate e route chiare recuperano separazione (VIS-006) e i patch di
# neve base non staccano dai materiali granulosi di route e passaggi.
const FROZEN_GROUND_TONE := Color(0.90, 0.91, 0.93, 1.0)
# drowned_marsh: fango, strada e acqua vivono tutti fra lum 54-66 (VIS-006,
# "valori troppo scuri e vicini"). Il lift caldo porta walkway/strade sopra il
# fango senza toccare il ground, che resta scuro per la leggibilita' attori.
const SWAMP_ROUTE_LIFT_COLOR := Color(0.82, 0.72, 0.52, 1.0)
const SWAMP_ROUTE_LIFT := 0.22
# drowned_marsh: le strip lip dei cliff hanno dettaglio organico ad alta
# frequenza; minificate ~10x sul bordo dei chasm senza mipmap diventano
# "glitter" dorato (VIS-002 bordo chiaro residuo). Il pre-downscale le porta
# vicine alla scala di rendering reale.
const SWAMP_CLIFF_TEXTURE_DOWNSCALE := 0.45
# burning_fields: i pixel brace piu' accesi del ground competono con telegraph
# e fire hazard (VIS-006). Il damping selettivo scurisce solo i pixel a
# dominanza arancio, lasciando lava feature e path intatti.
const VOLCANIC_EMBER_THRESHOLD := 0.18
const VOLCANIC_EMBER_DAMPING := 0.34

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
	# frozen_outskirts: i bordi chiari della neve formavano una griglia bianca
	# regolare a ogni repeat world-UV (ART-VIS-FIX, VIS-002).
	return (
		biome_id == &"burning_fields"
		or biome_id == &"drowned_marsh"
		or biome_id == &"frozen_outskirts"
		or biome_id == &"toxic_wastes"
	)

static func should_harmonize_cliff_edges(biome_id: StringName) -> bool:
	return biome_id == &"burning_fields" or biome_id == &"toxic_wastes"

static func cliff_texture_downscale(biome_id: StringName) -> float:
	if biome_id == &"drowned_marsh":
		return SWAMP_CLIFF_TEXTURE_DOWNSCALE
	return 1.0

static func surface_edge_blend_pixels(biome_id: StringName) -> int:
	match biome_id:
		&"burning_fields":
			return BURNING_SURFACE_EDGE_BLEND_PIXELS
		&"drowned_marsh":
			return MARSH_SURFACE_EDGE_BLEND_PIXELS
		&"frozen_outskirts":
			return FROZEN_SURFACE_EDGE_BLEND_PIXELS
		_:
			return BURNING_FIELDS_EDGE_BLEND_PIXELS

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
		surface_edge_blend_pixels(biome_id)
	)
	if _surface_uses_mirrored_atlas(biome_id, asset_path):
		normalized = _build_mirrored_repeat_atlas(normalized)
	if biome_id == &"frozen_outskirts":
		normalized = _harmonize_frozen_surface_texture(normalized, asset_path)
	if biome_id == &"drowned_marsh":
		normalized = _harmonize_swamp_surface_texture(normalized, asset_path)
	if biome_id == &"burning_fields":
		normalized = _harmonize_volcanic_surface_texture(normalized, asset_path)
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
	cache_key: String = "",
	downscale: float = 1.0
) -> Texture2D:
	if texture == null:
		return null
	var full_key := ""
	if not cache_key.is_empty():
		full_key = "repeat|%s|%d|%s|%d|%.2f" % [
			cache_key,
			trim,
			str(harmonize_edges),
			blend_pixels,
			downscale
		]
		if _normalized_texture_cache.has(full_key):
			return _normalized_texture_cache[full_key] as Texture2D
	var result := _normalize_repeating_texture_uncached(
		texture,
		trim,
		harmonize_edges,
		blend_pixels,
		downscale
	)
	# Anche i passthrough (immagine non leggibile) vengono cache-ati: rifallire
	# costa comunque un get_image() dalla VRAM a ogni chiamata.
	if not full_key.is_empty() and result != null:
		_normalized_texture_cache[full_key] = result
	return result

static func build_offset_ground_macro_texture(
	base_texture: Texture2D,
	cache_key: String = ""
) -> Texture2D:
	if base_texture == null:
		return base_texture
	var full_key := ""
	if not cache_key.is_empty():
		full_key = "offset_ground_macro|%s" % cache_key
		if _normalized_texture_cache.has(full_key):
			return _normalized_texture_cache[full_key] as Texture2D
	var base := _readable_texture_image(base_texture)
	if base == null or base.is_empty():
		return base_texture
	base.convert(Image.FORMAT_RGBA8)
	var tile_size := base.get_size()
	var atlas := Image.create(
		tile_size.x * 2,
		tile_size.y * 2,
		false,
		Image.FORMAT_RGBA8
	)
	var base_top_right := _offset_periodic_image(
		base,
		Vector2i(tile_size.x / 3, tile_size.y / 7)
	)
	var base_bottom_left := _offset_periodic_image(
		base,
		Vector2i(tile_size.x * 2 / 3, tile_size.y * 3 / 5)
	)
	var base_bottom_right := _offset_periodic_image(
		base,
		Vector2i(tile_size.x / 5, tile_size.y * 2 / 5)
	)
	var source_rect := Rect2i(Vector2i.ZERO, tile_size)
	atlas.blit_rect(base, source_rect, Vector2i.ZERO)
	atlas.blit_rect(
		base_top_right,
		source_rect,
		Vector2i(tile_size.x, 0)
	)
	atlas.blit_rect(
		base_bottom_left,
		source_rect,
		Vector2i(0, tile_size.y)
	)
	atlas.blit_rect(
		base_bottom_right,
		source_rect,
		tile_size
	)
	_blend_internal_vertical_seam(
		atlas,
		tile_size.x,
		GROUND_MACRO_SEAM_BLEND_PIXELS
	)
	_blend_internal_horizontal_seam(
		atlas,
		tile_size.y,
		GROUND_MACRO_SEAM_BLEND_PIXELS
	)
	_harmonize_repeating_texture_edges(
		atlas,
		GROUND_MACRO_SEAM_BLEND_PIXELS
	)
	atlas.fix_alpha_edges()
	var result := ImageTexture.create_from_image(atlas)
	if not full_key.is_empty():
		_normalized_texture_cache[full_key] = result
	return result

static func rotate_repeating_texture_clockwise(
	texture: Texture2D,
	cache_key: String = ""
) -> Texture2D:
	if texture == null:
		return null
	var full_key := ""
	if not cache_key.is_empty():
		full_key = "rotate90cw|%s" % cache_key
		if _normalized_texture_cache.has(full_key):
			return _normalized_texture_cache[full_key] as Texture2D
	var source := _readable_texture_image(texture)
	if source == null or source.is_empty():
		return texture
	source.convert(Image.FORMAT_RGBA8)
	var rotated := Image.create(
		source.get_height(),
		source.get_width(),
		false,
		Image.FORMAT_RGBA8
	)
	for y in range(source.get_height()):
		for x in range(source.get_width()):
			rotated.set_pixel(
				source.get_height() - y - 1,
				x,
				source.get_pixel(x, y)
			)
	rotated.fix_alpha_edges()
	rotated.generate_mipmaps()
	var result := ImageTexture.create_from_image(rotated)
	if not full_key.is_empty():
		_normalized_texture_cache[full_key] = result
	return result

static func _normalize_repeating_texture_uncached(
	texture: Texture2D,
	trim: int,
	harmonize_edges: bool,
	blend_pixels: int,
	downscale: float = 1.0
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
	if downscale > 0.0 and downscale < 1.0:
		# Pre-minifica il dettaglio ad alta frequenza: le strip cliff strette
		# campionate senza mipmap altrimenti scintillano (aliasing).
		normalized.resize(
			maxi(roundi(normalized.get_width() * downscale), 8),
			maxi(roundi(normalized.get_height() * downscale), 8),
			Image.INTERPOLATE_LANCZOS
		)
	# Generated cutouts often keep white RGB in transparent edge pixels.
	# Bleed neighbour colour into alpha so repeat/filter sampling cannot expose it.
	normalized.fix_alpha_edges()
	# Le strip cliff vengono minificate anche 10x sul bordo dei chasm: senza
	# mipmap il sampling salta righe e produce speckle (ART-VIS-FIX, VIS-002).
	normalized.generate_mipmaps()
	return ImageTexture.create_from_image(normalized)

static func _readable_texture_image(texture: Texture2D) -> Image:
	if texture == null:
		return null
	var image := texture.get_image()
	if image == null or image.is_empty():
		return null
	if image.is_compressed():
		var decompress_error := image.decompress()
		if decompress_error != OK:
			return null
	return image.duplicate()

static func _offset_periodic_image(
	image: Image,
	offset: Vector2i
) -> Image:
	if image == null or image.is_empty():
		return Image.new()
	var size := image.get_size()
	var safe_offset := Vector2i(
		posmod(offset.x, size.x),
		posmod(offset.y, size.y)
	)
	var result := Image.create(size.x, size.y, false, image.get_format())
	var left_width := size.x - safe_offset.x
	var top_height := size.y - safe_offset.y
	_blit_positive_rect(
		result,
		image,
		Rect2i(safe_offset, Vector2i(left_width, top_height)),
		Vector2i.ZERO
	)
	_blit_positive_rect(
		result,
		image,
		Rect2i(
			Vector2i(0, safe_offset.y),
			Vector2i(safe_offset.x, top_height)
		),
		Vector2i(left_width, 0)
	)
	_blit_positive_rect(
		result,
		image,
		Rect2i(
			Vector2i(safe_offset.x, 0),
			Vector2i(left_width, safe_offset.y)
		),
		Vector2i(0, top_height)
	)
	_blit_positive_rect(
		result,
		image,
		Rect2i(Vector2i.ZERO, safe_offset),
		Vector2i(left_width, top_height)
	)
	return result

static func _blit_positive_rect(
	target: Image,
	source: Image,
	source_rect: Rect2i,
	target_position: Vector2i
) -> void:
	if source_rect.size.x <= 0 or source_rect.size.y <= 0:
		return
	target.blit_rect(source, source_rect, target_position)

static func _blend_internal_vertical_seam(
	image: Image,
	seam_x: int,
	blend_pixels: int
) -> void:
	var blend_width := mini(
		blend_pixels,
		mini(seam_x, image.get_width() - seam_x)
	)
	for offset in range(blend_width):
		var blend := 1.0 - float(offset) / float(blend_width)
		blend *= blend
		var left_x := seam_x - 1 - offset
		var right_x := seam_x + offset
		for y in range(image.get_height()):
			var left := image.get_pixel(left_x, y)
			var right := image.get_pixel(right_x, y)
			var average := left.lerp(right, 0.5)
			image.set_pixel(left_x, y, left.lerp(average, blend))
			image.set_pixel(right_x, y, right.lerp(average, blend))

static func _blend_internal_horizontal_seam(
	image: Image,
	seam_y: int,
	blend_pixels: int
) -> void:
	var blend_width := mini(
		blend_pixels,
		mini(seam_y, image.get_height() - seam_y)
	)
	for offset in range(blend_width):
		var blend := 1.0 - float(offset) / float(blend_width)
		blend *= blend
		var top_y := seam_y - 1 - offset
		var bottom_y := seam_y + offset
		for x in range(image.get_width()):
			var top := image.get_pixel(x, top_y)
			var bottom := image.get_pixel(x, bottom_y)
			var average := top.lerp(bottom, 0.5)
			image.set_pixel(x, top_y, top.lerp(average, blend))
			image.set_pixel(x, bottom_y, bottom.lerp(average, blend))

static func _build_mirrored_repeat_atlas(texture: Texture2D) -> Texture2D:
	if texture == null:
		return null
	var source := texture.get_image()
	if source == null or source.is_empty():
		return texture
	if source.is_compressed():
		var decompress_error := source.decompress()
		if decompress_error != OK:
			return texture
	source.convert(Image.FORMAT_RGBA8)
	var source_size := source.get_size()
	var atlas := Image.create(
		source_size.x * 2,
		source_size.y * 2,
		false,
		Image.FORMAT_RGBA8
	)
	for y in range(atlas.get_height()):
		var source_y := (
			y
			if y < source_size.y
			else atlas.get_height() - 1 - y
		)
		for x in range(atlas.get_width()):
			var source_x := (
				x
				if x < source_size.x
				else atlas.get_width() - 1 - x
			)
			atlas.set_pixel(x, y, source.get_pixel(source_x, source_y))
	atlas.fix_alpha_edges()
	return ImageTexture.create_from_image(atlas)

static func _surface_uses_mirrored_atlas(
	biome_id: StringName,
	asset_path: String
) -> bool:
	return (
		biome_id == &"toxic_wastes"
		and (
			asset_path.contains("base_ground_variation")
			or asset_path.contains("path_variation")
			or asset_path.contains("road_variation")
			or asset_path.contains("road_border_defined")
		)
	)

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
	var shade_ground := asset_path.contains("base_ground_variation")
	if (snow_blend <= 0.0 and not shade_ground) or texture == null:
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
			var adjusted := source
			if shade_ground:
				adjusted = Color(
					source.r * FROZEN_GROUND_TONE.r,
					source.g * FROZEN_GROUND_TONE.g,
					source.b * FROZEN_GROUND_TONE.b,
					source.a
				)
			else:
				adjusted = source.lerp(
					FROZEN_SNOW_BLEND_COLOR,
					snow_blend * source.a
				)
				adjusted.a = source.a
			image.set_pixel(x, y, adjusted)
	image.fix_alpha_edges()
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

static func _harmonize_volcanic_surface_texture(
	texture: Texture2D,
	asset_path: String
) -> Texture2D:
	if texture == null:
		return null
	if not asset_path.contains("base_ground_variation"):
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
			var ember := maxf(
				source.r - (source.g + source.b) * 0.5,
				0.0
			)
			if ember <= VOLCANIC_EMBER_THRESHOLD:
				continue
			var strength := minf(
				(ember - VOLCANIC_EMBER_THRESHOLD) / 0.30,
				1.0
			)
			var adjusted := source.darkened(
				VOLCANIC_EMBER_DAMPING * strength
			)
			adjusted.a = source.a
			image.set_pixel(x, y, adjusted)
	image.fix_alpha_edges()
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

static func _frozen_surface_snow_blend(asset_path: String) -> float:
	if (
		asset_path.contains("road_variation")
		or asset_path.contains("road_border_defined")
	):
		return FROZEN_ROAD_SNOW_BLEND
	if asset_path.contains("path_variation"):
		return FROZEN_ROUTE_SNOW_BLEND
	return 0.0

static func _harmonize_swamp_surface_texture(
	texture: Texture2D,
	asset_path: String
) -> Texture2D:
	if texture == null:
		return null
	if (
		not asset_path.contains("path_variation")
		and not asset_path.contains("road_variation")
		and not asset_path.contains("road_border_defined")
	):
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
				SWAMP_ROUTE_LIFT_COLOR,
				SWAMP_ROUTE_LIFT * source.a
			)
			adjusted.a = source.a
			image.set_pixel(x, y, adjusted)
	image.fix_alpha_edges()
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)
