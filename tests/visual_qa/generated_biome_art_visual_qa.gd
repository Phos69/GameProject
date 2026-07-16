extends SceneTree

const OUTPUT_DIR := "res://build/qa/generated_biome_art"
const OUTPUT_FILE := "generated_biome_materials.png"
const BIOMES: Array[StringName] = [
	&"toxic_wastes",
	&"burning_fields",
	&"frozen_outskirts",
	&"drowned_marsh",
]

var failures := PackedStringArray()

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.content_scale_size = Vector2i(1600, 1040)
	root.size = Vector2i(1600, 1040)
	var output_absolute := ProjectSettings.globalize_path(OUTPUT_DIR)
	_expect(
		DirAccess.make_dir_recursive_absolute(output_absolute) == OK,
		"generated-biome QA output directory is available"
	)
	var board := Control.new()
	board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(board)
	current_scene = board
	var background := ColorRect.new()
	background.color = Color("0a1015")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board.add_child(background)
	_add_label(
		board,
		"GENERATED BIOME ART / FULL-BLEED SURFACES / DIRT DIVIDER / VOID CLIFF",
		Vector2(0.0, 18.0),
		Vector2(1600.0, 42.0),
		24
	)
	var manifest := EnvironmentAssetManifest.reload_shared()
	_expect(manifest.load_error.is_empty(), "environment asset manifest loads")
	var divider_contract := manifest.get_terrain_asset_contract(&"terrain_divider_dirt")
	var divider_path := String(divider_contract.get("asset_path", ""))
	_expect(
		not divider_path.is_empty(),
		"terrain_divider_dirt resolves from the manifest"
	)
	for index in range(BIOMES.size()):
		_add_biome_panel(board, BIOMES[index], index, divider_path)
	for _frame in range(4):
		await process_frame
	var image := root.get_texture().get_image()
	_expect(image != null and not image.is_empty(), "QA capture is available")
	if image != null and not image.is_empty():
		_expect(
			image.save_png(output_absolute.path_join(OUTPUT_FILE)) == OK,
			"generated-biome QA screenshot is saved"
		)
	_finish()

func _add_biome_panel(
	board: Control,
	biome_id: StringName,
	index: int,
	divider_path: String
) -> void:
	var origin := Vector2(18.0 + float(index) * 394.0, 76.0)
	var panel := ColorRect.new()
	panel.position = origin
	panel.size = Vector2(374.0, 940.0)
	panel.color = Color("17212a")
	board.add_child(panel)
	var theme_id := BiomeGeneratedArtCatalog.get_theme_id_for_biome(biome_id)
	_add_label(
		board,
		"%s\n%s" % [String(biome_id), String(theme_id)],
		origin + Vector2(12.0, 10.0),
		Vector2(350.0, 58.0),
		18
	)
	var seed := 8800 + index
	var ground_path := BiomeGeneratedArtCatalog.select_surface_asset_path(
		biome_id,
		BiomeGeneratedArtCatalog.ROLE_GROUND,
		seed,
		Vector2i(index * 8, 0)
	)
	var path_path := BiomeGeneratedArtCatalog.select_surface_asset_path(
		biome_id,
		BiomeGeneratedArtCatalog.ROLE_PATH,
		seed,
		Vector2i.ZERO
	)
	var road_path := BiomeGeneratedArtCatalog.select_surface_asset_path(
		biome_id,
		BiomeGeneratedArtCatalog.ROLE_ROAD,
		seed,
		Vector2i.ZERO
	)
	var face_path := BiomeGeneratedArtCatalog.select_cliff_asset_path(
		biome_id,
		BiomeGeneratedArtCatalog.ROLE_CLIFF_FACE,
		seed
	)
	var lip_path := BiomeGeneratedArtCatalog.select_cliff_asset_path(
		biome_id,
		BiomeGeneratedArtCatalog.ROLE_CLIFF_LIP_HORIZONTAL,
		seed
	)
	_expect(
		road_path.get_file().contains("road_variation"),
		"%s road role selects full-bleed road_variation: %s"
		% [String(biome_id), road_path]
	)
	_add_texture(board, ground_path, origin + Vector2(12.0, 78.0), Vector2(350.0, 220.0))
	_add_label(
		board,
		"GROUND / FULL-BLEED",
		origin + Vector2(12.0, 300.0),
		Vector2(350.0, 24.0),
		13
	)
	_add_texture(board, path_path, origin + Vector2(12.0, 330.0), Vector2(110.0, 118.0))
	_add_texture(board, road_path, origin + Vector2(132.0, 330.0), Vector2(230.0, 118.0))
	_add_label(
		board,
		"PATH / FULL-BLEED",
		origin + Vector2(12.0, 450.0),
		Vector2(110.0, 22.0),
		11
	)
	_add_label(
		board,
		"ROAD / ASPHALT FULL-BLEED",
		origin + Vector2(132.0, 450.0),
		Vector2(230.0, 22.0),
		11
	)
	_add_texture(board, divider_path, origin + Vector2(12.0, 486.0), Vector2(350.0, 116.0))
	_add_label(
		board,
		"DIRT DIVIDER / MASK A",
		origin + Vector2(12.0, 604.0),
		Vector2(350.0, 22.0),
		12
	)
	_add_texture(board, face_path, origin + Vector2(12.0, 660.0), Vector2(220.0, 218.0))
	_add_texture(board, lip_path, origin + Vector2(242.0, 660.0), Vector2(120.0, 104.0))
	_add_texture(board, ground_path, origin + Vector2(242.0, 772.0), Vector2(120.0, 106.0))
	_add_label(board, "VOID CLIFF FACE", origin + Vector2(12.0, 882.0), Vector2(220.0, 22.0), 12)
	_add_label(
		board,
		"CLIFF LIP / GROUND",
		origin + Vector2(238.0, 882.0),
		Vector2(128.0, 22.0),
		11
	)

func _add_texture(
	board: Control,
	asset_path: String,
	position: Vector2,
	size: Vector2
) -> void:
	var texture := load(asset_path) as Texture2D
	_expect(texture != null, "texture loads: %s" % asset_path)
	_add_texture_instance(board, texture, position, size)

func _add_texture_instance(
	board: Control,
	texture: Texture2D,
	position: Vector2,
	size: Vector2
) -> void:
	if texture == null:
		return
	var preview := TextureRect.new()
	preview.position = position
	preview.size = size
	preview.texture = texture
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	board.add_child(preview)

func _add_label(
	board: Control,
	text: String,
	position: Vector2,
	size: Vector2,
	font_size: int
) -> void:
	var label := Label.new()
	label.text = text
	label.position = position
	label.size = size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("e5edf2"))
	board.add_child(label)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("GENERATED_BIOME_ART_VISUAL_QA: PASS")
		quit(0)
		return
	print("GENERATED_BIOME_ART_VISUAL_QA: FAIL (%d)" % failures.size())
	quit(1)
