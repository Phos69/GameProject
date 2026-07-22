extends SceneTree

const OUTPUT_DIR := "res://build/qa/plains_rock_cliffs"
const OUTPUT_FILE := "plains_rock_cross_source_derived_preview.png"
const GRID_SIZE := Vector2i(9, 9)
const TILE_SIZE := 48.0
const CROSS_ARM_WIDTH := 3
const CROSS_ORIGIN := Vector2(132.0, 138.0)
const SOURCE_ALPHA_PATH := (
	"res://assets/environment/top_down/rock_cliffs/plains/"
	+ "plains_dark_fantasy_wall_cross_source_v3_alpha.png"
)
const TOP_SAMPLE_RECTS: Array[Rect2i] = [
	Rect2i(554, 480, 148, 148),
	Rect2i(554, 200, 148, 148),
	Rect2i(260, 480, 148, 148),
	Rect2i(850, 480, 148, 148),
]

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var output_absolute := ProjectSettings.globalize_path(OUTPUT_DIR)
	_expect(
		DirAccess.make_dir_recursive_absolute(output_absolute) == OK,
		"cross preview output directory is available"
	)
	var manifest := EnvironmentAssetManifest.reload_shared()
	var atlas_set := RockCliffAtlasSet.new()
	_expect(
		atlas_set.configure(&"plains", manifest) and atlas_set.is_wall_ready(),
		"approved wall atlas loads for the preview"
	)
	var source := Image.load_from_file(
		ProjectSettings.globalize_path(SOURCE_ALPHA_PATH)
	)
	_expect(not source.is_empty(), "alpha cross source loads")
	if source.is_empty() or not atlas_set.is_wall_ready():
		_finish()
		return

	var scene_root := Control.new()
	scene_root.name = "PlainsRockCrossSourceDerivedPreview"
	scene_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(scene_root)
	current_scene = scene_root
	_add_background(scene_root)
	var top_textures := _build_top_preview_textures(source)
	var occupied := _build_cross_cells()
	_add_cross_top(scene_root, occupied, top_textures)
	_add_cross_walls(scene_root, occupied, atlas_set)
	_add_grid(scene_root, occupied)
	_add_legend(scene_root, top_textures)
	await process_frame
	await process_frame

	var image := root.get_texture().get_image()
	_expect(image != null and not image.is_empty(), "cross preview capture is available")
	if image != null and not image.is_empty():
		_expect(
			image.save_png(output_absolute.path_join(OUTPUT_FILE)) == OK,
			"cross preview screenshot is saved"
		)
	_finish()


func _add_background(parent: Control) -> void:
	var background := ColorRect.new()
	background.color = Color("111713")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.z_index = -20
	parent.add_child(background)
	var field := ColorRect.new()
	field.position = Vector2(54.0, 84.0)
	field.size = Vector2(600.0, 574.0)
	field.color = Color("263524")
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.z_index = -10
	parent.add_child(field)
	var void_strip := ColorRect.new()
	void_strip.position = Vector2(54.0, 570.0)
	void_strip.size = Vector2(600.0, 88.0)
	void_strip.color = Color("08090b")
	void_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	void_strip.z_index = -9
	parent.add_child(void_strip)


func _build_cross_cells() -> Dictionary:
	var occupied: Dictionary = {}
	var arm_start := (GRID_SIZE.x - CROSS_ARM_WIDTH) / 2
	var arm_end := arm_start + CROSS_ARM_WIDTH
	for y in range(GRID_SIZE.y):
		for x in range(GRID_SIZE.x):
			if (
				(x >= arm_start and x < arm_end)
				or (y >= arm_start and y < arm_end)
			):
				occupied[Vector2i(x, y)] = true
	return occupied


func _build_top_preview_textures(source: Image) -> Array[Texture2D]:
	var textures: Array[Texture2D] = []
	for sample_rect in TOP_SAMPLE_RECTS:
		var sample := source.get_region(sample_rect)
		sample.resize(512, 512, Image.INTERPOLATE_LANCZOS)
		_harmonize_top_edges(sample, 22)
		textures.append(ImageTexture.create_from_image(sample))
	return textures


func _harmonize_top_edges(image: Image, blend_pixels: int) -> void:
	for offset in range(blend_pixels):
		var weight := float(offset + 1) / float(blend_pixels + 1)
		for cross in range(image.get_height()):
			var left := image.get_pixel(offset, cross)
			var right := image.get_pixel(image.get_width() - 1 - offset, cross)
			var seam := left.lerp(right, 0.5)
			image.set_pixel(offset, cross, left.lerp(seam, 1.0 - weight))
			image.set_pixel(
				image.get_width() - 1 - offset,
				cross,
				right.lerp(seam, 1.0 - weight)
			)
		for cross in range(image.get_width()):
			var top := image.get_pixel(cross, offset)
			var bottom := image.get_pixel(cross, image.get_height() - 1 - offset)
			var seam := top.lerp(bottom, 0.5)
			image.set_pixel(cross, offset, top.lerp(seam, 1.0 - weight))
			image.set_pixel(
				cross,
				image.get_height() - 1 - offset,
				bottom.lerp(seam, 1.0 - weight)
			)


func _add_cross_top(
	parent: Control,
	occupied: Dictionary,
	textures: Array[Texture2D]
) -> void:
	for cell_value in occupied:
		var cell := cell_value as Vector2i
		var variant := posmod(cell.x * 13 + cell.y * 7, textures.size())
		var tile := TextureRect.new()
		tile.name = "Top_%d_%d" % [cell.x, cell.y]
		tile.position = CROSS_ORIGIN + Vector2(cell) * TILE_SIZE
		tile.size = Vector2.ONE * TILE_SIZE
		tile.texture = textures[variant]
		tile.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tile.stretch_mode = TextureRect.STRETCH_SCALE
		tile.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(tile)


func _add_cross_walls(
	parent: Control,
	occupied: Dictionary,
	atlas_set: RockCliffAtlasSet
) -> void:
	var role_count := 0
	for vertex_y in range(GRID_SIZE.y + 1):
		for vertex_x in range(GRID_SIZE.x + 1):
			var vertex := Vector2i(vertex_x, vertex_y)
			var mask := RockCliffTopologyResolver.vertex_mask_for_cells(
				occupied,
				vertex
			)
			var role := RockCliffTopologyResolver.wall_role_for_vertex_mask(mask)
			if role.is_empty():
				continue
			var texture := atlas_set.get_wall_texture(role)
			_expect(texture != null, "wall role %s resolves" % String(role))
			if texture == null:
				continue
			var stamp := TextureRect.new()
			stamp.name = "Wall_%d_%d_%s" % [vertex.x, vertex.y, String(role)]
			stamp.position = (
				CROSS_ORIGIN
				+ (Vector2(vertex) - Vector2.ONE) * TILE_SIZE
			)
			stamp.size = Vector2.ONE * TILE_SIZE * 2.0
			stamp.texture = texture
			stamp.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			stamp.stretch_mode = TextureRect.STRETCH_SCALE
			stamp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
			stamp.z_index = 2
			parent.add_child(stamp)
			role_count += 1
	_expect(role_count > 0, "cross emits modular wall roles")


func _add_grid(parent: Control, occupied: Dictionary) -> void:
	for cell_value in occupied:
		var cell := cell_value as Vector2i
		var outline := ReferenceRect.new()
		outline.position = CROSS_ORIGIN + Vector2(cell) * TILE_SIZE
		outline.size = Vector2.ONE * TILE_SIZE
		outline.border_color = Color(0.82, 0.88, 0.76, 0.12)
		outline.border_width = 1.0
		outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		outline.z_index = 5
		parent.add_child(outline)


func _add_legend(parent: Control, top_textures: Array[Texture2D]) -> void:
	var title := Label.new()
	title.text = "PLAINS ROCK KIT - CROCE MODULARE"
	title.position = Vector2(54.0, 22.0)
	title.size = Vector2(1172.0, 42.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color("ead9af"))
	title.z_index = 20
	parent.add_child(title)

	var panel := ColorRect.new()
	panel.position = Vector2(690.0, 84.0)
	panel.size = Vector2(536.0, 574.0)
	panel.color = Color("1b201e")
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(panel)

	var heading := Label.new()
	heading.text = "TOP PROVVISORIO DALLA CROCE"
	heading.position = Vector2(722.0, 112.0)
	heading.size = Vector2(472.0, 34.0)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 20)
	heading.add_theme_color_override("font_color", Color("d7c595"))
	heading.z_index = 20
	parent.add_child(heading)

	for index in range(top_textures.size()):
		var preview := TextureRect.new()
		preview.position = Vector2(
			744.0 + float(index % 2) * 218.0,
			166.0 + float(index / 2) * 170.0
		)
		preview.size = Vector2(176.0, 128.0)
		preview.texture = top_textures[index]
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode = TextureRect.STRETCH_SCALE
		preview.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(preview)

	var note := Label.new()
	note.text = (
		"Pareti: 16 moduli AtlasTexture\n"
		+ "Top: 4 crop interni armonizzati\n"
		+ "Scala preview: 48 px per tile\n\n"
		+ "Nessun picco e stato inventato:\n"
		+ "questa versione mostra il massimo\n"
		+ "ottenibile solo dalla croce sorgente."
	)
	note.position = Vector2(742.0, 518.0)
	note.size = Vector2(430.0, 124.0)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 16)
	note.add_theme_color_override("font_color", Color("b7c0b6"))
	note.z_index = 20
	parent.add_child(note)


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)


func _finish() -> void:
	if failures.is_empty():
		print("PLAINS_ROCK_CROSS_PREVIEW_VISUAL_QA: PASS")
		quit(0)
		return
	print("PLAINS_ROCK_CROSS_PREVIEW_VISUAL_QA: FAIL (%d)" % failures.size())
	quit(1)
