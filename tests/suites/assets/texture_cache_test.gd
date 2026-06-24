extends GutTest
## Assets — Cache di rasterizzazione SVG del loader isometrico.
##
## Migra:
##   tests/isometric_texture_cache_smoke_test.gd  (loader, logica pura)
##
## Verifica che il loader rasterizzi un SVG una sola volta per (path, size) e poi
## riusi la stessa istanza: tile layer, streaming regioni, cambi bioma e run
## successive non ricaricano gli stessi asset.

const LOADER = preload("res://game/modes/zombie/isometric_svg_texture_loader.gd")
const SVG_PATH := "res://assets/environment/isometric/tiles/shared/floor_base.svg"

func test_svg_rasterization_cache() -> void:
	LOADER.clear_cache()
	assert_eq(LOADER.get_cached_texture_count(), 0, "cache starts empty")

	var size := Vector2i(160, 120)
	var first := LOADER.load_texture(SVG_PATH, Color.WHITE, Color(0.5, 0.5, 0.5), size)
	assert_not_null(first, "svg texture loads")
	assert_true(LOADER.has_cached_texture(SVG_PATH, size), "loaded svg texture is cached for its (path, size)")
	assert_eq(LOADER.get_cached_texture_count(), 1, "one texture is cached")

	var second := LOADER.load_texture(SVG_PATH, Color.WHITE, Color(0.5, 0.5, 0.5), size)
	assert_eq(second, first, "a second load returns the cached instance, not a re-rasterization")
	assert_eq(LOADER.get_cached_texture_count(), 1, "loading the same (path, size) does not add a cache entry")

	# A different requested size is a distinct rasterization and a separate entry.
	var bigger := LOADER.load_texture(SVG_PATH, Color.WHITE, Color(0.5, 0.5, 0.5), Vector2i(512, 512))
	assert_not_null(bigger, "svg texture loads at a larger size")
	assert_ne(bigger, first, "a different size yields a different texture instance")
	assert_eq(LOADER.get_cached_texture_count(), 2, "a different size adds a cache entry")

	# A non-svg path is served by the engine resource cache, not tracked here.
	var png := LOADER.load_texture(
		"res://assets/environment/isometric/tiles/forest/textures/forest_grass_generated.png",
		Color.WHITE,
		Color(0.5, 0.5, 0.5)
	)
	assert_not_null(png, "non-svg asset still loads")
	assert_eq(LOADER.get_cached_texture_count(), 2, "non-svg assets are not added to the svg rasterization cache")

	LOADER.clear_cache()
	assert_eq(LOADER.get_cached_texture_count(), 0, "clear_cache empties the cache")
	assert_false(LOADER.has_cached_texture(SVG_PATH, size), "cleared cache no longer reports the texture")
