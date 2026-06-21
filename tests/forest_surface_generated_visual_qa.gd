extends SceneTree

const OUTPUT_DIR := "res://build/qa/forest_surfaces"
const OUTPUT_FILE := "forest_surface_materials.png"
const TEXTURE_LOADER = preload(
	"res://game/modes/zombie/isometric_svg_texture_loader.gd"
)
const SURFACE_IDS: Array[StringName] = [
	&"forest_grass",
	&"forest_path",
	&"forest_road",
	&"grass_to_path",
	&"grass_to_road",
	&"path_to_road"
]
const LABELS: Array[String] = [
	"PRATO",
	"SENTIERO - TERRA E SASSI",
	"STRADA - ASFALTO",
	"PRATO / SENTIERO",
	"PRATO / ASFALTO",
	"SENTIERO / ASFALTO"
]

var failures := PackedStringArray()

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var output_absolute := ProjectSettings.globalize_path(OUTPUT_DIR)
	_expect(
		DirAccess.make_dir_recursive_absolute(output_absolute) == OK,
		"forest surface QA output directory is available"
	)
	var board := Control.new()
	board.name = "ForestSurfaceGeneratedQa"
	board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(board)
	current_scene = board
	_add_background(board)
	_add_title(board)
	var manifest := IsometricEnvironmentManifest.reload_shared()
	var palette := load(
		"res://game/modes/zombie/biomes/infected_plains_palette.tres"
	) as BiomePalette
	for index in range(SURFACE_IDS.size()):
		var texture := _load_texture(manifest, SURFACE_IDS[index], palette)
		_expect(texture != null, "%s QA texture loads" % String(SURFACE_IDS[index]))
		_add_surface_panel(board, index, texture)
	for _frame in range(4):
		await process_frame
	var image := root.get_texture().get_image()
	_expect(image != null and not image.is_empty(), "forest surface QA capture is available")
	if image != null and not image.is_empty():
		_expect(
			image.save_png(output_absolute.path_join(OUTPUT_FILE)) == OK,
			"forest surface materials screenshot is saved"
		)
	_finish()

func _add_background(board: Control) -> void:
	var background := ColorRect.new()
	background.color = Color("0b1115")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board.add_child(background)

func _add_title(board: Control) -> void:
	var title := Label.new()
	title.text = "MATERIALI TERRENO FORESTALE"
	title.position = Vector2(0.0, 20.0)
	title.size = Vector2(1280.0, 42.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color("f1dda6"))
	board.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Base seamless + transizioni modulari world-space"
	subtitle.position = Vector2(0.0, 60.0)
	subtitle.size = Vector2(1280.0, 26.0)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 15)
	subtitle.add_theme_color_override("font_color", Color("9fb39f"))
	board.add_child(subtitle)

func _add_surface_panel(board: Control, index: int, texture: Texture2D) -> void:
	var column := index % 3
	var row := index / 3
	var position := Vector2(34.0 + float(column) * 414.0, 128.0 + float(row) * 286.0)
	var frame := ColorRect.new()
	frame.position = position - Vector2(2.0, 2.0)
	frame.size = Vector2(388.0, 232.0)
	frame.color = Color("53645a")
	board.add_child(frame)
	var preview := TextureRect.new()
	preview.position = position
	preview.size = Vector2(384.0, 228.0)
	preview.texture = texture
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	board.add_child(preview)
	var label := Label.new()
	label.text = LABELS[index]
	label.position = position + Vector2(0.0, 234.0)
	label.size = Vector2(384.0, 28.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color("dbe8cf"))
	board.add_child(label)

func _load_texture(
	manifest: IsometricEnvironmentManifest,
	asset_id: StringName,
	palette: BiomePalette
) -> Texture2D:
	var contract := manifest.get_terrain_asset_contract(asset_id)
	return TEXTURE_LOADER.load_texture(
		String(contract.get("asset_path", "")),
		palette.floor_color,
		palette.alternate_floor_color,
		Vector2i(512, 512)
	)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("FOREST_SURFACE_GENERATED_VISUAL_QA: PASS")
		quit(0)
		return
	print("FOREST_SURFACE_GENERATED_VISUAL_QA: FAIL (%d)" % failures.size())
	quit(1)
