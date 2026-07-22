extends SceneTree

## Artistic comparison for the two approved cross sources. Each panel draws a
## single RGBA texture for crown, crest and descending faces, so no atlas seam
## or independent top/wall sampling can influence the review.

const OUTPUT_DIR := "res://build/qa/plains_rock_cliffs"
const OUTPUT_FILE := "plains_rock_cross_continuous_texture_comparison.png"
const GRASS_TEXTURE_PATH := (
	"res://assets/environment/top_down/tiles/forest/textures/"
	+ "forest_grass_generated.png"
)
const SOURCE_PATHS: Array[String] = [
	"res://assets/environment/top_down/rock_cliffs/plains/"
	+ "plains_dark_fantasy_wall_cross_source_v2_alpha.png",
	"res://assets/environment/top_down/rock_cliffs/plains/"
	+ "plains_dark_fantasy_wall_cross_source_v3_alpha.png",
]
const PANEL_RECTS: Array[Rect2] = [
	Rect2(44.0, 92.0, 584.0, 578.0),
	Rect2(652.0, 92.0, 584.0, 578.0),
]
const VARIANT_LABELS: Array[String] = [
	"V2 - DISCESA MORBIDA",
	"V3 - FIANCHI PIU SCOSCESI",
]
const PREVIEW_SIZE := Vector2(432.0, 432.0)

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var output_absolute := ProjectSettings.globalize_path(OUTPUT_DIR)
	_expect(
		DirAccess.make_dir_recursive_absolute(output_absolute) == OK,
		"continuous cross preview output directory is available"
	)
	var grass_texture := load(GRASS_TEXTURE_PATH) as Texture2D
	_expect(grass_texture != null, "Plains grass texture loads")

	var scene_root := Control.new()
	scene_root.name = "PlainsRockCrossContinuousTextureVisualQa"
	scene_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(scene_root)
	current_scene = scene_root
	_add_background(scene_root)
	_add_header(scene_root)

	for index in range(SOURCE_PATHS.size()):
		var source_texture := _load_used_square_texture(SOURCE_PATHS[index])
		_expect(source_texture != null, "cross source %s loads" % VARIANT_LABELS[index])
		_add_variant_panel(
			scene_root,
			PANEL_RECTS[index],
			VARIANT_LABELS[index],
			source_texture,
			grass_texture
		)

	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	_expect(image != null and not image.is_empty(), "continuous cross capture is available")
	if image != null and not image.is_empty():
		_expect(
			image.save_png(output_absolute.path_join(OUTPUT_FILE)) == OK,
			"continuous cross comparison is saved"
		)
	_finish()


func _add_background(parent: Control) -> void:
	var background := ColorRect.new()
	background.color = Color("0d1210")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.z_index = -20
	parent.add_child(background)


func _add_header(parent: Control) -> void:
	var title := Label.new()
	title.text = "MONTAGNA A CROCE - TEXTURE CONTINUA"
	title.position = Vector2(40.0, 16.0)
	title.size = Vector2(1200.0, 36.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color("ead9af"))
	parent.add_child(title)

	var subtitle := Label.new()
	subtitle.text = (
		"Una sola sorgente RGBA per pavimento, bordo e discesa verticale"
		+ "  |  sagoma 9x9 a circa 48 px/tile"
	)
	subtitle.position = Vector2(40.0, 52.0)
	subtitle.size = Vector2(1200.0, 26.0)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color("aeb9b0"))
	parent.add_child(subtitle)


func _add_variant_panel(
	parent: Control,
	panel_rect: Rect2,
	variant_label: String,
	source_texture: Texture2D,
	grass_texture: Texture2D
) -> void:
	var panel := ColorRect.new()
	panel.position = panel_rect.position
	panel.size = panel_rect.size
	panel.color = Color("171d1a")
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(panel)

	var heading := Label.new()
	heading.text = variant_label
	heading.position = panel_rect.position + Vector2(16.0, 14.0)
	heading.size = Vector2(panel_rect.size.x - 32.0, 32.0)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 19)
	heading.add_theme_color_override("font_color", Color("d8c895"))
	parent.add_child(heading)

	var field_rect := Rect2(
		panel_rect.position + Vector2(16.0, 54.0),
		Vector2(panel_rect.size.x - 32.0, 474.0)
	)
	var field := TextureRect.new()
	field.position = field_rect.position
	field.size = field_rect.size
	field.texture = grass_texture
	field.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	field.stretch_mode = TextureRect.STRETCH_SCALE
	field.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	field.modulate = Color(0.62, 0.68, 0.59, 1.0)
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(field)

	var shade := ColorRect.new()
	shade.position = field_rect.position
	shade.size = field_rect.size
	shade.color = Color(0.04, 0.07, 0.05, 0.16)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(shade)

	if source_texture != null:
		var cross := TextureRect.new()
		cross.name = variant_label.replace(" ", "_")
		cross.position = (
			field_rect.position
			+ (field_rect.size - PREVIEW_SIZE) * 0.5
		)
		cross.size = PREVIEW_SIZE
		cross.texture = source_texture
		cross.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		cross.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		cross.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(cross)

	var footer := Label.new()
	footer.text = "1 texture  |  top + cresta + parete  |  nessun modulo separato"
	footer.position = panel_rect.position + Vector2(16.0, 536.0)
	footer.size = Vector2(panel_rect.size.x - 32.0, 26.0)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override("font_size", 14)
	footer.add_theme_color_override("font_color", Color("b8c1b8"))
	parent.add_child(footer)


func _load_used_square_texture(path: String) -> Texture2D:
	var source := Image.load_from_file(ProjectSettings.globalize_path(path))
	if source.is_empty():
		return null
	source.convert(Image.FORMAT_RGBA8)
	var used_rect := source.get_used_rect()
	if not used_rect.has_area():
		return null
	var side := maxi(used_rect.size.x, used_rect.size.y)
	var source_size := source.get_size()
	var square_position := Vector2i(
		used_rect.position.x - (side - used_rect.size.x) / 2,
		used_rect.position.y - (side - used_rect.size.y) / 2
	)
	square_position.x = clampi(square_position.x, 0, source_size.x - side)
	square_position.y = clampi(square_position.y, 0, source_size.y - side)
	var square := source.get_region(
		Rect2i(square_position, Vector2i(side, side))
	)
	return ImageTexture.create_from_image(square)


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)


func _finish() -> void:
	if failures.is_empty():
		print("PLAINS_ROCK_CROSS_CONTINUOUS_TEXTURE_VISUAL_QA: PASS")
		quit(0)
		return
	print(
		"PLAINS_ROCK_CROSS_CONTINUOUS_TEXTURE_VISUAL_QA: FAIL (%d)"
		% failures.size()
	)
	quit(1)
