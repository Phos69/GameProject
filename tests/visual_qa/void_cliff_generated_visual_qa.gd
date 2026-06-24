extends SceneTree

const OUTPUT_DIR := "res://build/qa/void_cliffs"
const OUTPUT_FILE := "void_cliff_generated_variants.png"
const TEXTURE_LOADER = preload(
	"res://game/modes/zombie/isometric_svg_texture_loader.gd"
)
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
const LABELS: Array[String] = [
	"EDGE N", "EDGE E", "EDGE S", "EDGE W",
	"INNER NE", "INNER SE", "INNER SW", "INNER NW",
	"OUTER NE", "OUTER SE", "OUTER SW", "OUTER NW",
	"DIAG NE-SW", "DIAG NW-SE"
]

var failures := PackedStringArray()

class CliffQaBoard extends Node2D:
	var builder: IsometricCliffMeshBuilder
	var face_texture: Texture2D
	var lip_texture: Texture2D
	var centers: Array[Vector2] = []

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(1280.0, 720.0)), Color("0b1115"))
		for center in centers:
			_draw_sample_backdrop(center)
		if builder != null and builder.face_mesh != null:
			draw_mesh(builder.face_mesh, face_texture)
		if builder != null and builder.lip_mesh != null and lip_texture != null:
			draw_mesh(builder.lip_mesh, lip_texture)
		if builder != null and builder.fissure_lines.size() >= 2:
			draw_multiline(builder.fissure_lines, Color(0.08, 0.07, 0.06, 0.72), 1.3)
		if builder != null and builder.lip_lines.size() >= 2:
			draw_multiline(builder.lip_lines, Color("d7c48c"), 2.2)

	func _draw_sample_backdrop(center: Vector2) -> void:
		var panel := Rect2(center - Vector2(72.0, 64.0), Vector2(144.0, 190.0))
		draw_rect(panel, Color("111c21"), true)
		draw_rect(panel, Color("43534a"), false, 1.0)
		var diamond := PackedVector2Array([
			center + Vector2(0.0, -20.0),
			center + Vector2(44.0, 0.0),
			center + Vector2(0.0, 20.0),
			center + Vector2(-44.0, 0.0)
		])
		draw_colored_polygon(diamond, Color("26352a"))

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var output_absolute := ProjectSettings.globalize_path(OUTPUT_DIR)
	_expect(
		DirAccess.make_dir_recursive_absolute(output_absolute) == OK,
		"void cliff QA output directory is available"
	)
	var palette := load(
		"res://game/modes/zombie/biomes/infected_plains_palette.tres"
	) as BiomePalette
	var manifest := IsometricEnvironmentManifest.reload_shared()
	var board := CliffQaBoard.new()
	board.name = "VoidCliffGeneratedQa"
	board.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	root.add_child(board)
	current_scene = board
	board.builder = IsometricCliffMeshBuilder.new()
	board.builder.configure(palette, 737373, true)
	for index in range(TRANSITION_IDS.size()):
		var center := Vector2(
			110.0 + float(index % 7) * 176.0,
			235.0 + float(index / 7) * 290.0
		)
		board.centers.append(center)
		board.builder.append_transition(
			TRANSITION_IDS[index],
			center,
			44.0,
			20.0
		)
	board.builder.build_meshes()
	board.face_texture = _load_texture(manifest, &"cliff_face_texture", palette)
	board.lip_texture = _load_texture(manifest, &"cliff_lip_texture", palette)
	_add_labels(board)
	board.queue_redraw()
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	_expect(image != null and not image.is_empty(), "void cliff QA capture is available")
	if image != null and not image.is_empty():
		_expect(
			image.save_png(output_absolute.path_join(OUTPUT_FILE)) == OK,
			"void cliff variants screenshot is saved"
		)
	_expect(board.builder.transition_count == TRANSITION_IDS.size(), "QA renders all 14 variants")
	_finish()

func _load_texture(
	manifest: IsometricEnvironmentManifest,
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
	var title := _make_label(
		"CLIFF VOID - KIT RASTER MODULARE",
		Vector2(0.0, 22.0),
		Vector2(1280.0, 42.0),
		26,
		Color("f1dda6")
	)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	board.add_child(title)
	var subtitle := _make_label(
		"Faccia rocciosa + lip terreno | geometria runtime N/S/E/W, angoli e diagonali",
		Vector2(0.0, 62.0),
		Vector2(1280.0, 30.0),
		15,
		Color("9fb39f")
	)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	board.add_child(subtitle)
	for index in range(LABELS.size()):
		var center: Vector2 = board.centers[index]
		var label := _make_label(
			LABELS[index],
			center + Vector2(-72.0, -55.0),
			Vector2(144.0, 24.0),
			13,
			Color("dbe8cf")
		)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		board.add_child(label)

func _make_label(
	text_value: String,
	position_value: Vector2,
	size_value: Vector2,
	font_size: int,
	color: Color
) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = position_value
	label.size = size_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("VOID_CLIFF_GENERATED_VISUAL_QA: PASS")
		quit(0)
		return
	print("VOID_CLIFF_GENERATED_VISUAL_QA: FAIL (%d)" % failures.size())
	quit(1)
