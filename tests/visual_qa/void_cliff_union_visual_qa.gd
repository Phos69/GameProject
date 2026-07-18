extends SceneTree

const OUTPUT_DIR := "res://build/qa/void_cliffs"
const OUTPUT_FILE := "void_cliff_union_concave.png"
const ZONE_SIZE := Vector2i(20, 14)
const LOGICAL_SCALE := 32.0
const FALL_RECTS: Array[Rect2i] = [
	Rect2i(Vector2i(9, 1), Vector2i(4, 12)),
	Rect2i(Vector2i(3, 5), Vector2i(14, 4)),
]
const FALL_SIDES: Array[StringName] = [&"internal", &"internal"]
const TEXTURE_LOADER = preload(
	"res://game/modes/zombie/environment_texture_loader.gd"
)

var failures := PackedStringArray()

class CliffUnionBoard extends Node2D:
	var face_builder: RectilinearCliffFaceMeshBuilder
	var border_builder: TopDownCliffBorderMeshBuilder
	var face_texture: Texture2D
	var horizontal_texture: Texture2D
	var vertical_texture: Texture2D

	func _draw() -> void:
		var zone_size_world := Vector2(ZONE_SIZE) * LOGICAL_SCALE
		var zone_rect := Rect2(-zone_size_world * 0.5, zone_size_world)
		draw_rect(zone_rect, Color("334d2e"), true)
		for y in range(ZONE_SIZE.y):
			for x in range(ZONE_SIZE.x):
				var cell_rect := Rect2(
					(Vector2(x, y) - Vector2(ZONE_SIZE) * 0.5) * LOGICAL_SCALE,
					Vector2.ONE * LOGICAL_SCALE
				)
				draw_rect(cell_rect, Color(0.48, 0.62, 0.39, 0.16), false, 1.0)
		for rect in FALL_RECTS:
			var void_rect := Rect2(
				(Vector2(rect.position) - Vector2(ZONE_SIZE) * 0.5) * LOGICAL_SCALE,
				Vector2(rect.size) * LOGICAL_SCALE
			)
			draw_rect(void_rect, Color("050706"), true)
		if border_builder != null and border_builder.vertical_mesh != null:
			draw_mesh(border_builder.vertical_mesh, vertical_texture)
		if face_builder != null and face_builder.face_mesh != null:
			draw_mesh(face_builder.face_mesh, face_texture)
		if border_builder != null and border_builder.horizontal_mesh != null:
			draw_mesh(border_builder.horizontal_mesh, horizontal_texture)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var output_absolute := ProjectSettings.globalize_path(OUTPUT_DIR)
	_expect(
		DirAccess.make_dir_recursive_absolute(output_absolute) == OK,
		"void union QA output directory is available"
	)
	var manifest := EnvironmentAssetManifest.reload_shared()
	var palette := load(
		"res://game/modes/zombie/biomes/plains_palette.tres"
	) as BiomePalette
	var board := CliffUnionBoard.new()
	board.name = "VoidCliffUnionVisualQa"
	board.position = Vector2(640.0, 375.0)
	board.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	board.face_builder = RectilinearCliffFaceMeshBuilder.new()
	board.face_builder.build(FALL_RECTS, FALL_SIDES, ZONE_SIZE, LOGICAL_SCALE)
	board.border_builder = TopDownCliffBorderMeshBuilder.new()
	board.border_builder.build(FALL_RECTS, FALL_SIDES, ZONE_SIZE, LOGICAL_SCALE)
	board.face_texture = _load_texture(manifest, &"cliff_face_texture", palette)
	board.horizontal_texture = _load_texture(manifest, &"cliff_lip_texture", palette)
	board.vertical_texture = _load_texture(
		manifest,
		&"cliff_lip_vertical_texture",
		palette
	)
	root.add_child(board)
	current_scene = board
	_add_labels(board)
	board.queue_redraw()
	await process_frame
	await process_frame
	_expect(
		board.border_builder.concave_corner_count == 4,
		"cross union builds all four concave lip joins"
	)
	_expect(
		board.face_builder.concave_join_count == 4,
		"cross union shares all four concave wall seams"
	)
	var image := root.get_texture().get_image()
	_expect(image != null and not image.is_empty(), "void union QA capture is available")
	if image != null and not image.is_empty():
		_expect(
			image.save_png(output_absolute.path_join(OUTPUT_FILE)) == OK,
			"void union QA screenshot is saved"
		)
	_finish()

func _load_texture(
	manifest: EnvironmentAssetManifest,
	asset_id: StringName,
	palette: BiomePalette
) -> Texture2D:
	var contract := manifest.get_void_asset_contract(asset_id)
	return TEXTURE_LOADER.load_texture(
		String(contract.get("asset_path", "")),
		palette.prop_color,
		palette.floor_color,
		Vector2i(512, 512)
	)

func _add_labels(board: Node2D) -> void:
	var title := Label.new()
	title.text = "VOID CLIFF - PROFONDITA UNIFORME E ANGOLI CONCAVI"
	title.position = Vector2(-640.0, -345.0)
	title.size = Vector2(1280.0, 42.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("f1dda6"))
	board.add_child(title)
	var note := Label.new()
	note.text = "Creste walkable; quattro seam condividono geometria, gradiente e fase UV senza stacchi."
	note.position = Vector2(-640.0, 295.0)
	note.size = Vector2(1280.0, 30.0)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 15)
	note.add_theme_color_override("font_color", Color("a8bca0"))
	board.add_child(note)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("VOID_CLIFF_UNION_VISUAL_QA: PASS")
		quit(0)
		return
	print("VOID_CLIFF_UNION_VISUAL_QA: FAIL (%d)" % failures.size())
	quit(1)
