extends SceneTree

# Milestone D - pre-generazione/cache asset.
# Verifica che il loader rasterizzi un SVG una sola volta per (path, size) e poi
# riusi la stessa istanza, cosi tile layer, streaming regioni, cambi bioma e run
# successive non ricaricano gli stessi asset ogni volta.

const LOADER = preload("res://game/modes/zombie/isometric_svg_texture_loader.gd")
const SVG_PATH := "res://assets/environment/isometric/tiles/shared/floor_base.svg"

var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	LOADER.clear_cache()
	_expect(LOADER.get_cached_texture_count() == 0, "cache starts empty")

	var size := Vector2i(160, 120)
	var first := LOADER.load_texture(SVG_PATH, Color.WHITE, Color(0.5, 0.5, 0.5), size)
	_expect(first != null, "svg texture loads")
	_expect(
		LOADER.has_cached_texture(SVG_PATH, size),
		"loaded svg texture is cached for its (path, size)"
	)
	_expect(LOADER.get_cached_texture_count() == 1, "one texture is cached")

	var second := LOADER.load_texture(SVG_PATH, Color.WHITE, Color(0.5, 0.5, 0.5), size)
	_expect(second == first, "a second load returns the cached instance, not a re-rasterization")
	_expect(
		LOADER.get_cached_texture_count() == 1,
		"loading the same (path, size) does not add a cache entry"
	)

	# A different requested size is a distinct rasterization and a separate entry.
	var bigger := LOADER.load_texture(SVG_PATH, Color.WHITE, Color(0.5, 0.5, 0.5), Vector2i(512, 512))
	_expect(bigger != null, "svg texture loads at a larger size")
	_expect(bigger != first, "a different size yields a different texture instance")
	_expect(LOADER.get_cached_texture_count() == 2, "a different size adds a cache entry")

	# A non-svg path is served by the engine resource cache, not tracked here.
	var png := LOADER.load_texture(
		"res://assets/environment/isometric/tiles/forest/textures/forest_grass_generated.png",
		Color.WHITE,
		Color(0.5, 0.5, 0.5)
	)
	_expect(png != null, "non-svg asset still loads")
	_expect(
		LOADER.get_cached_texture_count() == 2,
		"non-svg assets are not added to the svg rasterization cache"
	)

	LOADER.clear_cache()
	_expect(LOADER.get_cached_texture_count() == 0, "clear_cache empties the cache")
	_expect(
		not LOADER.has_cached_texture(SVG_PATH, size),
		"cleared cache no longer reports the texture"
	)

	_finish()

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("ISOMETRIC_TEXTURE_CACHE_SMOKE_TEST: PASS")
		quit(0)
		return
	print("ISOMETRIC_TEXTURE_CACHE_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
