extends RefCounted
class_name GeneratedBiomeTextureTools

const GENERATED_SURFACE_TEXTURE_EDGE_TRIM_PIXELS := 2
const GENERATED_CLIFF_TEXTURE_EDGE_TRIM_PIXELS := 12
const INFECTED_PLAINS_SURFACE_EDGE_TRIM_PIXELS := 40
const INFECTED_PLAINS_SURFACE_EDGE_BLEND_PIXELS := 8
const BURNING_FIELDS_GENERATED_TEXTURE_EDGE_TRIM_PIXELS := 10
const BURNING_FIELDS_EDGE_BLEND_PIXELS := 18
const BURNING_SURFACE_EDGE_BLEND_PIXELS := 40
const FROZEN_SURFACE_EDGE_BLEND_PIXELS := 40
const MARSH_SURFACE_EDGE_BLEND_PIXELS := 40
const GROUND_MACRO_SEAM_BLEND_PIXELS := 128
## Frazione di larghezza del PNG road_border_defined occupata da ciascuna
## striscia di bordo; il core interno e' la fascia centrale restante.
## Stesso rapporto usato dal core forestale di plains.
const ROAD_CORE_CROP_MARGIN_RATIO := 0.32
## L'overlay bordo usa la fascia esterna piu una piccola porzione di strada,
## cosi il profilo ground->road resta leggibile anche quando viene compresso
## dentro mezza cella logica.
## Stessa frazione del crop core: la strip mostra esattamente la banda di
## bordo che il core scarta, cosi' core + strip ricompongono l'asset madre.
const ROAD_BORDER_SIDE_STRIP_RATIO := 0.32
## Feather minimo: serve solo a non far leggere il rettangolo dell'overlay;
## con valori alti la banda di bordo dell'asset sparisce in trasparenza.
const ROAD_TRANSITION_OVERLAY_FEATHER_RATIO := 0.08
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
# swamp: fango, strada e acqua vivono tutti fra lum 54-66 (VIS-006,
# "valori troppo scuri e vicini"). Il lift caldo porta walkway/strade sopra il
# fango senza toccare il ground, che resta scuro per la leggibilita' attori.
const SWAMP_ROUTE_LIFT_COLOR := Color(0.82, 0.72, 0.52, 1.0)
const SWAMP_ROUTE_LIFT := 0.22
# swamp: le strip lip dei cliff hanno dettaglio organico ad alta
# frequenza; minificate ~10x sul bordo dei chasm senza mipmap diventano
# "glitter" dorato (VIS-002 bordo chiaro residuo). Il pre-downscale le porta
# vicine alla scala di rendering reale.
const SWAMP_CLIFF_TEXTURE_DOWNSCALE := 0.45
# burning_plains: i pixel brace piu' accesi del ground competono con telegraph
# e fire hazard (VIS-006). Il cap selettivo limita la sola dominanza rossa dei
# pixel caldi, lasciando invariati lava feature, path e il tono ocra del grass.
const VOLCANIC_EMBER_THRESHOLD := 0.18
const SURFACE_NORMALIZATION_CACHE_REVISION := "surface-v7-burning-ember-cap"

# Cache di sessione delle texture normalizzate, keyed su asset_path + parametri.
# La normalizzazione gira pixel-per-pixel in GDScript: senza cache veniva rifatta
# a ogni configure() di regione (hitch sul main thread durante lo streaming) e
# ogni chiamata caricava in VRAM una ImageTexture duplicata della stessa asset.
# Il path identifica il contenuto sorgente perche' gli asset generati sono PNG
# raster serviti dalla cache per-path di EnvironmentTextureLoader.
static var _normalized_texture_cache: Dictionary = {}

static func clear_cache() -> void:
	_normalized_texture_cache.clear()

static func get_cached_normalized_texture_count() -> int:
	return _normalized_texture_cache.size()

static func surface_edge_trim_pixels(biome_id: StringName) -> int:
	if biome_id == &"plains":
		# The three forest surface PNGs contain a broad baked shadow around their
		# perimeter. Removing the full band prevents two dark edges from forming a
		# visible line when the unchanged tile repeats vertically or horizontally.
		return INFECTED_PLAINS_SURFACE_EDGE_TRIM_PIXELS
	if biome_id == &"burning_plains":
		return BURNING_FIELDS_GENERATED_TEXTURE_EDGE_TRIM_PIXELS
	return GENERATED_SURFACE_TEXTURE_EDGE_TRIM_PIXELS

static func cliff_edge_trim_pixels(_biome_id: StringName) -> int:
	return GENERATED_CLIFF_TEXTURE_EDGE_TRIM_PIXELS

static func should_harmonize_surface_edges(biome_id: StringName) -> bool:
	# I raster generati non sono perfettamente tileable: senza armonizzazione la
	# differenza fra bordi opposti diventa una banda a ogni repeat world-UV.
	return (
		biome_id == &"plains"
		or biome_id == &"burning_plains"
		or biome_id == &"swamp"
		or biome_id == &"frozen_tundra"
		or biome_id == &"toxic_wastes"
	)

static func should_harmonize_cliff_edges(biome_id: StringName) -> bool:
	return biome_id == &"burning_plains" or biome_id == &"toxic_wastes"

static func cliff_texture_downscale(biome_id: StringName) -> float:
	if biome_id == &"swamp":
		return SWAMP_CLIFF_TEXTURE_DOWNSCALE
	return 1.0

static func surface_edge_blend_pixels(biome_id: StringName) -> int:
	match biome_id:
		&"plains":
			return INFECTED_PLAINS_SURFACE_EDGE_BLEND_PIXELS
		&"burning_plains":
			return BURNING_SURFACE_EDGE_BLEND_PIXELS
		&"swamp":
			return MARSH_SURFACE_EDGE_BLEND_PIXELS
		&"frozen_tundra":
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
	# Keep processing changes from reusing a stale texture during an editor
	# hot-reload or a long-lived runtime session.
	var cache_key := "%s|%s|%s" % [
		SURFACE_NORMALIZATION_CACHE_REVISION,
		String(biome_id),
		asset_path,
	]
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
	if biome_id == &"frozen_tundra":
		normalized = _harmonize_frozen_surface_texture(normalized, asset_path)
	if biome_id == &"swamp":
		normalized = _harmonize_swamp_surface_texture(normalized, asset_path)
	if biome_id == &"burning_plains":
		normalized = _harmonize_volcanic_surface_texture(normalized, asset_path)
	if not asset_path.is_empty() and normalized != null:
		_normalized_texture_cache[cache_key] = normalized
	return normalized

## Interno carreggiata: ritaglia le strisce di bordo dal PNG road_border_defined.
## `source_orientation` indica dove corrono le strisce nel PNG sorgente:
## &"vertical" = strisce a sinistra/destra, &"horizontal" = strisce in alto/basso.
static func crop_road_core_texture(
	source_texture: Texture2D,
	source_orientation: StringName,
	cache_key: String = "",
	margin_ratio: float = ROAD_CORE_CROP_MARGIN_RATIO
) -> Texture2D:
	if source_texture == null:
		return null
	var full_key := ""
	if not cache_key.is_empty():
		full_key = "road_core_crop|%s|%s|%.2f" % [
			cache_key,
			String(source_orientation),
			margin_ratio,
		]
		if _normalized_texture_cache.has(full_key):
			return _normalized_texture_cache[full_key] as Texture2D
	var image := _readable_texture_image(source_texture)
	if image == null or image.is_empty():
		return null
	image.convert(Image.FORMAT_RGBA8)
	var margin_x := 0
	var margin_y := 0
	if source_orientation == &"horizontal":
		margin_y = roundi(float(image.get_height()) * margin_ratio)
	else:
		margin_x = roundi(float(image.get_width()) * margin_ratio)
	var source_rect := Rect2i(
		Vector2i(margin_x, margin_y),
		Vector2i(
			image.get_width() - margin_x * 2,
			image.get_height() - margin_y * 2
		)
	)
	if source_rect.size.x <= 0 or source_rect.size.y <= 0:
		return null
	var core_image := image.get_region(source_rect)
	core_image.fix_alpha_edges()
	core_image.generate_mipmaps()
	var result := ImageTexture.create_from_image(core_image)
	if not full_key.is_empty():
		_normalized_texture_cache[full_key] = result
	return result

## Ritaglia una sola fascia ground->road da una texture di transizione o,
## come fallback, dal PNG road_border_defined. La texture risultante viene
## mappata con UV locali sull'asse corto e world-space sull'asse lungo, quindi
## non deve contenere entrambi i lati della strada.
static func crop_road_border_side_texture(
	source_texture: Texture2D,
	side: StringName,
	cache_key: String = "",
	strip_ratio: float = ROAD_BORDER_SIDE_STRIP_RATIO
) -> Texture2D:
	if source_texture == null:
		return null
	var full_key := ""
	if not cache_key.is_empty():
		full_key = "road_border_side|%s|%s|%.2f" % [
			cache_key,
			String(side),
			strip_ratio,
		]
		if _normalized_texture_cache.has(full_key):
			return _normalized_texture_cache[full_key] as Texture2D
	var image := _readable_texture_image(source_texture)
	if image == null or image.is_empty():
		return null
	image.convert(Image.FORMAT_RGBA8)
	var strip_w := clampi(
		roundi(float(image.get_width()) * strip_ratio),
		1,
		image.get_width()
	)
	var strip_h := clampi(
		roundi(float(image.get_height()) * strip_ratio),
		1,
		image.get_height()
	)
	var source_rect := Rect2i(Vector2i.ZERO, image.get_size())
	match side:
		&"west":
			source_rect = Rect2i(Vector2i.ZERO, Vector2i(strip_w, image.get_height()))
		&"east":
			source_rect = Rect2i(
				Vector2i(image.get_width() - strip_w, 0),
				Vector2i(strip_w, image.get_height())
			)
		&"north":
			source_rect = Rect2i(Vector2i.ZERO, Vector2i(image.get_width(), strip_h))
		&"south":
			source_rect = Rect2i(
				Vector2i(0, image.get_height() - strip_h),
				Vector2i(image.get_width(), strip_h)
			)
		_:
			source_rect = Rect2i(Vector2i.ZERO, Vector2i(strip_w, image.get_height()))
	var side_image := image.get_region(source_rect)
	side_image.fix_alpha_edges()
	side_image.generate_mipmaps()
	var result := ImageTexture.create_from_image(side_image)
	if not full_key.is_empty():
		_normalized_texture_cache[full_key] = result
	return result

static func fade_road_transition_overlay_texture(
	source_texture: Texture2D,
	side: StringName,
	cache_key: String = "",
	feather_ratio: float = ROAD_TRANSITION_OVERLAY_FEATHER_RATIO
) -> Texture2D:
	if source_texture == null:
		return null
	var full_key := ""
	if not cache_key.is_empty():
		full_key = "road_transition_fade|%s|%s|%.2f" % [
			cache_key,
			String(side),
			feather_ratio,
		]
		if _normalized_texture_cache.has(full_key):
			return _normalized_texture_cache[full_key] as Texture2D
	var image := _readable_texture_image(source_texture)
	if image == null or image.is_empty():
		return null
	image.convert(Image.FORMAT_RGBA8)
	var width := image.get_width()
	var height := image.get_height()
	var use_x_axis := side == &"west" or side == &"east"
	var denom := float(maxi(width - 1, 1)) if use_x_axis else float(maxi(height - 1, 1))
	var safe_feather := clampf(feather_ratio, 0.01, 0.49)
	for y in range(height):
		for x in range(width):
			var axis_position := float(x) if use_x_axis else float(y)
			var t := axis_position / denom
			var fade_alpha := minf(t / safe_feather, (1.0 - t) / safe_feather)
			fade_alpha = clampf(fade_alpha, 0.0, 1.0)
			var color := image.get_pixel(x, y)
			color.a *= fade_alpha
			image.set_pixel(x, y, color)
	image.fix_alpha_edges()
	image.generate_mipmaps()
	var result := ImageTexture.create_from_image(image)
	if not full_key.is_empty():
		_normalized_texture_cache[full_key] = result
	return result

## Striscia di bordo mono-lato ritagliata dal PNG madre road_border_defined,
## con la stessa pipeline di normalize_surface_texture ma il crop inserito
## prima dell'atlas specchiato (ritagliare l'atlas gia' composto non isola la
## striscia, toxic_wastes) e gli harmonize per-bioma applicati alla striscia.
static func build_road_border_side_surface_texture(
	raw_texture: Texture2D,
	biome_id: StringName,
	asset_path: String,
	source_orientation: StringName,
	side: StringName
) -> Texture2D:
	if raw_texture == null:
		return null
	var cache_key := "road_border_side_surface|%s|%s|%s|%s" % [
		String(biome_id),
		asset_path,
		String(source_orientation),
		String(side),
	]
	if not asset_path.is_empty() and _normalized_texture_cache.has(cache_key):
		return _normalized_texture_cache[cache_key] as Texture2D
	var normalized := _normalize_repeating_texture_uncached(
		raw_texture,
		surface_edge_trim_pixels(biome_id),
		should_harmonize_surface_edges(biome_id),
		surface_edge_blend_pixels(biome_id)
	)
	if normalized == null:
		return null
	var side_needs_horizontal := side == &"north" or side == &"south"
	var source_is_horizontal := source_orientation == &"horizontal"
	var oriented := normalized
	if side_needs_horizontal != source_is_horizontal:
		oriented = rotate_repeating_texture_clockwise(
			oriented,
			"%s|road_border_side_orient_%s" % [asset_path, String(side)]
		)
	var strip := crop_road_border_side_texture(oriented, side)
	if strip == null:
		return null
	if biome_id == &"frozen_tundra":
		strip = _harmonize_frozen_surface_texture(strip, asset_path)
	if biome_id == &"swamp":
		strip = _harmonize_swamp_surface_texture(strip, asset_path)
	if biome_id == &"burning_plains":
		strip = _harmonize_volcanic_surface_texture(strip, asset_path)
	if not asset_path.is_empty() and strip != null:
		_normalized_texture_cache[cache_key] = strip
	return strip

## Come normalize_surface_texture ma con il ritaglio core inserito prima
## dell'atlas specchiato: ritagliare l'atlas gia' composto lascerebbe le
## strisce di bordo duplicate al centro della carreggiata (toxic_wastes).
static func build_road_core_surface_texture(
	raw_texture: Texture2D,
	biome_id: StringName,
	asset_path: String,
	source_orientation: StringName
) -> Texture2D:
	if raw_texture == null:
		return null
	var cache_key := "road_core_surface|%s|%s|%s" % [
		String(biome_id),
		asset_path,
		String(source_orientation),
	]
	if not asset_path.is_empty() and _normalized_texture_cache.has(cache_key):
		return _normalized_texture_cache[cache_key] as Texture2D
	var normalized := _normalize_repeating_texture_uncached(
		raw_texture,
		surface_edge_trim_pixels(biome_id),
		should_harmonize_surface_edges(biome_id),
		surface_edge_blend_pixels(biome_id)
	)
	var core := crop_road_core_texture(normalized, source_orientation)
	if core == null:
		return null
	if _surface_uses_mirrored_atlas(biome_id, asset_path):
		core = _build_mirrored_repeat_atlas(core)
	if biome_id == &"frozen_tundra":
		core = _harmonize_frozen_surface_texture(core, asset_path)
	if biome_id == &"swamp":
		core = _harmonize_swamp_surface_texture(core, asset_path)
	if biome_id == &"burning_plains":
		core = _harmonize_volcanic_surface_texture(core, asset_path)
	if not asset_path.is_empty() and core != null:
		_normalized_texture_cache[cache_key] = core
	return core

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
		Vector2i(tile_size.x * 7 / 13, tile_size.y * 11 / 17)
	)
	var base_bottom_left := _offset_periodic_image(
		base,
		Vector2i(tile_size.x * 5 / 11, tile_size.y * 13 / 19)
	)
	var base_bottom_right := _offset_periodic_image(
		base,
		Vector2i(tile_size.x * 9 / 16, tile_size.y * 3 / 14)
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
	atlas.generate_mipmaps()
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
	atlas.generate_mipmaps()
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
			var adjusted := source
			adjusted.r = minf(
				source.r,
				(source.g + source.b) * 0.5 + VOLCANIC_EMBER_THRESHOLD
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
