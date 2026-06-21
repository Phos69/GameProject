extends SceneTree

const FOREST_SURFACE_IDS: Array[StringName] = [
	&"forest_grass",
	&"forest_path",
	&"forest_road",
	&"grass_to_path",
	&"grass_to_road",
	&"path_to_road"
]
const EDGE_ID := &"cliff_lip_texture"

var failures := PackedStringArray()

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var manifest := IsometricEnvironmentManifest.reload_shared()
	for asset_id in FOREST_SURFACE_IDS:
		_validate_generated_asset(manifest.get_terrain_asset_contract(asset_id), asset_id)
	_validate_generated_asset(manifest.get_void_asset_contract(EDGE_ID), EDGE_ID)
	await _validate_runtime_consumption(manifest)
	_finish()

func _validate_generated_asset(contract: Dictionary, asset_id: StringName) -> void:
	var asset_path := String(contract.get("asset_path", ""))
	_expect(not contract.is_empty(), "%s has an asset contract" % String(asset_id))
	_expect(asset_path.ends_with(".png"), "%s uses generated PNG art" % String(asset_id))
	_expect(FileAccess.file_exists(asset_path), "%s PNG exists" % String(asset_id))
	_expect(String(contract.get("status", "")) == "final", "%s art is final" % String(asset_id))
	_expect(
		String(contract.get("source", "")) == "openai_image_generation",
		"%s records generated-art provenance" % String(asset_id)
	)
	var image := Image.new()
	var load_error := image.load(ProjectSettings.globalize_path(asset_path))
	_expect(load_error == OK, "%s source image loads" % String(asset_id))
	if load_error != OK:
		return
	_expect(
		image.get_width() >= 512 and image.get_height() >= 512,
		"%s source supports mipmapped runtime downscale" % String(asset_id)
	)
	var seam_score := _edge_seam_score(image)
	_expect(
		seam_score <= 0.24,
		"%s opposite edges are visually tileable (score %.3f)"
		% [String(asset_id), seam_score]
	)

func _validate_runtime_consumption(manifest: IsometricEnvironmentManifest) -> void:
	var palette := load(
		"res://game/modes/zombie/biomes/infected_plains_palette.tres"
	) as BiomePalette
	var layout := BiomeEnvironmentLayout.new()
	layout.zone_size = Vector2i(16, 16)
	layout.generation_seed = 862041
	layout.add_floor_rect(Rect2i(Vector2i.ZERO, layout.zone_size), &"forest_grass")
	layout.add_fall_zone_rect(Rect2i(Vector2i(6, 6), Vector2i(4, 4)), &"internal")
	layout.rebuild_terrain_classification()
	var layer := BiomeTileLayer.new()
	root.add_child(layer)
	layer.configure(
		layout,
		palette,
		&"infected_plains",
		&"quality",
		16,
		null,
		manifest,
		false
	)
	await process_frame
	_expect(layer.has_forest_ground_art_texture(), "forest tile layer loads generated grass")
	_expect(layer.has_forest_surface_art_textures(), "forest tile layer loads every surface texture")
	_expect(
		layer.get_forest_ground_art_asset_path().ends_with("forest_grass_generated.png"),
		"forest tile layer exposes generated grass path"
	)
	var paths := layer.get_forest_surface_art_asset_paths()
	for asset_id in FOREST_SURFACE_IDS:
		var asset_path := String(paths.get(asset_id, ""))
		_expect(
			asset_path.contains("_generated") and asset_path.ends_with(".png"),
			"forest tile layer exposes %s generated path" % String(asset_id)
		)
	_expect(layer.has_cliff_art_textures(), "forest tile layer loads grass-cliff edge")
	_expect(layer.get_cliff_transition_count() > 0, "forest void builds textured cliff transitions")
	layer.queue_free()
	await process_frame

func _edge_seam_score(image: Image) -> float:
	var last_x := image.get_width() - 1
	var last_y := image.get_height() - 1
	var step := maxi(mini(image.get_width(), image.get_height()) / 256, 1)
	var total := 0.0
	var samples := 0
	for y in range(0, image.get_height(), step):
		total += _rgb_delta(image.get_pixel(0, y), image.get_pixel(last_x, y))
		samples += 1
	for x in range(0, image.get_width(), step):
		total += _rgb_delta(image.get_pixel(x, 0), image.get_pixel(x, last_y))
		samples += 1
	return total / float(maxi(samples, 1))

func _rgb_delta(first: Color, second: Color) -> float:
	return (
		absf(first.r - second.r)
		+ absf(first.g - second.g)
		+ absf(first.b - second.b)
	) / 3.0

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("FOREST_GRASS_GENERATED_TEXTURE_SMOKE_TEST: PASS")
		quit(0)
		return
	print("FOREST_GRASS_GENERATED_TEXTURE_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
