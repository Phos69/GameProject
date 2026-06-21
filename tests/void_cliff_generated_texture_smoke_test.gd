extends SceneTree

const CLIFF_TEXTURE_IDS: Array[StringName] = [
	&"cliff_face_texture",
	&"cliff_lip_texture"
]
const TRANSITION_IDS: Array[StringName] = [
	IsometricTileResolver.TILE_VOID_EDGE_NORTH,
	IsometricTileResolver.TILE_VOID_EDGE_EAST,
	IsometricTileResolver.TILE_VOID_EDGE_SOUTH,
	IsometricTileResolver.TILE_VOID_EDGE_WEST,
	IsometricTileResolver.TILE_VOID_CORNER_INNER_NORTH_EAST,
	IsometricTileResolver.TILE_VOID_CORNER_INNER_SOUTH_EAST,
	IsometricTileResolver.TILE_VOID_CORNER_INNER_SOUTH_WEST,
	IsometricTileResolver.TILE_VOID_CORNER_INNER_NORTH_WEST,
	IsometricTileResolver.TILE_VOID_CORNER_OUTER_NORTH_EAST,
	IsometricTileResolver.TILE_VOID_CORNER_OUTER_SOUTH_EAST,
	IsometricTileResolver.TILE_VOID_CORNER_OUTER_SOUTH_WEST,
	IsometricTileResolver.TILE_VOID_CORNER_OUTER_NORTH_WEST,
	IsometricTileResolver.TILE_VOID_DIAGONAL_NORTH_EAST_SOUTH_WEST,
	IsometricTileResolver.TILE_VOID_DIAGONAL_NORTH_WEST_SOUTH_EAST
]

var failures := PackedStringArray()

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var manifest := IsometricEnvironmentManifest.reload_shared()
	_validate_manifest_assets(manifest)
	_validate_all_transition_meshes()
	await _validate_tile_layer_consumes_textures(manifest)
	await _validate_fall_gameplay_unchanged()
	_finish()

func _validate_manifest_assets(manifest: IsometricEnvironmentManifest) -> void:
	for asset_id in CLIFF_TEXTURE_IDS:
		var contract := manifest.get_void_asset_contract(asset_id)
		var asset_path := String(contract.get("asset_path", ""))
		_expect(not contract.is_empty(), "%s has a void asset contract" % String(asset_id))
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
		if load_error == OK:
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

func _validate_all_transition_meshes() -> void:
	var palette := load(
		"res://game/modes/zombie/biomes/infected_plains_palette.tres"
	) as BiomePalette
	_expect(palette != null, "infected plains palette loads for cliff mesh QA")
	if palette == null:
		return
	var builder := IsometricCliffMeshBuilder.new()
	builder.configure(palette, 424242, true)
	for index in range(TRANSITION_IDS.size()):
		builder.append_transition(
			TRANSITION_IDS[index],
			Vector2(float(index % 7) * 100.0, float(index / 7) * 120.0),
			42.0,
			22.0
		)
	builder.build_meshes()
	_expect(builder.transition_count == TRANSITION_IDS.size(), "all 14 cliff variants build")
	_expect(_mesh_has_uvs(builder.face_mesh), "cliff face mesh exposes texture UVs")
	_expect(_mesh_has_uvs(builder.lip_mesh), "cliff lip mesh exposes texture UVs")
	_expect(not builder.lip_lines.is_empty(), "crisp cliff crest remains available")
	_expect(not builder.fissure_lines.is_empty(), "procedural fissure detail remains available")

func _validate_tile_layer_consumes_textures(
	manifest: IsometricEnvironmentManifest
) -> void:
	var palette := load(
		"res://game/modes/zombie/biomes/infected_plains_palette.tres"
	) as BiomePalette
	var layout := BiomeEnvironmentLayout.new()
	layout.zone_size = Vector2i(16, 16)
	layout.generation_seed = 515151
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
	_expect(layer.has_cliff_art_textures(), "tile layer loads face and lip textures")
	var paths := layer.get_cliff_art_asset_paths()
	for asset_id in CLIFF_TEXTURE_IDS:
		_expect(
			not String(paths.get(asset_id, "")).is_empty(),
			"tile layer exposes %s asset path" % String(asset_id)
		)
	_expect(layer.get_cliff_transition_count() > 0, "synthetic void builds textured cliff transitions")
	layer.queue_free()
	await process_frame

func _validate_fall_gameplay_unchanged() -> void:
	var zone := BiomeFallZone.new()
	root.add_child(zone)
	zone.configure(
		&"fall_zone",
		Vector2(180.0, 64.0),
		0.0,
		Color(0.82, 0.58, 0.16, 0.92),
		&"cliff",
		&"north",
		616161
	)
	await process_frame
	_expect(zone.contains_global_position(zone.global_position), "fall-zone collision still owns the drop")
	_expect(zone.uses_procedural_fallback(), "fall zone does not duplicate tile-layer cliff art")
	var collision := zone.get_node_or_null("CollisionShape2D") as CollisionShape2D
	_expect(
		collision != null
		and collision.shape is RectangleShape2D
		and (collision.shape as RectangleShape2D).size == zone.zone_size,
		"generated cliff art does not change fall collision"
	)
	zone.queue_free()
	await process_frame

func _mesh_has_uvs(mesh: ArrayMesh) -> bool:
	if mesh == null or mesh.get_surface_count() <= 0:
		return false
	var arrays := mesh.surface_get_arrays(0)
	var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector2Array
	var uvs := arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array
	return not vertices.is_empty() and uvs.size() == vertices.size()

func _edge_seam_score(image: Image) -> float:
	if image == null or image.is_empty():
		return 1.0
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
		print("VOID_CLIFF_GENERATED_TEXTURE_SMOKE_TEST: PASS")
		quit(0)
		return
	print("VOID_CLIFF_GENERATED_TEXTURE_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
