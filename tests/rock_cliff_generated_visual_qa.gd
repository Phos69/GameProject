extends SceneTree

const OUTPUT_DIR := "res://build/qa/rock_cliffs"
const OUTPUT_FILE := "rock_cliff_generated_variants.png"
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

class RaisedCliffQaBoard extends Node2D:
	var builder: IsometricCliffMeshBuilder
	var face_texture: Texture2D
	var top_texture: Texture2D
	var centers: Array[Vector2] = []

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(1280.0, 720.0)), Color("0b1115"))
		for center in centers:
			_draw_sample_backdrop(center)
		if builder != null and builder.face_mesh != null:
			draw_mesh(builder.face_mesh, face_texture)
		if builder != null and builder.lip_mesh != null:
			draw_mesh(builder.lip_mesh, top_texture)
		if builder != null and builder.fissure_lines.size() >= 2:
			draw_multiline(
				builder.fissure_lines,
				Color(0.07, 0.06, 0.05, 0.76),
				1.35,
				true
			)
		if builder != null and builder.lip_lines.size() >= 2:
			draw_multiline(builder.lip_lines, Color("d6c49c"), 1.8, true)

	func _draw_sample_backdrop(center: Vector2) -> void:
		var panel := Rect2(center - Vector2(72.0, 188.0), Vector2(144.0, 222.0))
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
		"raised cliff QA output directory is available"
	)
	var palette := load(
		"res://game/modes/zombie/biomes/infected_plains_palette.tres"
	) as BiomePalette
	var manifest := IsometricEnvironmentManifest.reload_shared()
	var board := RaisedCliffQaBoard.new()
	board.name = "RaisedRockCliffGeneratedQa"
	board.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	root.add_child(board)
	current_scene = board
	board.builder = IsometricCliffMeshBuilder.new()
	board.builder.configure(palette, 858585, true, &"raise")
	for index in range(TRANSITION_IDS.size()):
		var center := Vector2(
			110.0 + float(index % 7) * 176.0,
			330.0 + float(index / 7) * 310.0
		)
		board.centers.append(center)
		board.builder.append_transition(
			TRANSITION_IDS[index],
			center,
			44.0,
			20.0
		)
	board.builder.build_meshes()
	board.face_texture = _load_void_texture(
		manifest,
		&"rock_cliff_face_texture",
		palette
	)
	board.top_texture = _load_object_texture(manifest, &"large_rock", palette)
	_expect(board.face_texture != null, "upward rock face material loads")
	_expect(board.top_texture != null, "rock plateau top material loads")
	_expect(
		board.builder.transition_count == TRANSITION_IDS.size(),
		"raised QA renders all 14 void-equivalent variants"
	)
	var all_lines_rise := true
	for index in range(0, board.builder.fissure_lines.size(), 2):
		if board.builder.fissure_lines[index].y <= board.builder.fissure_lines[index + 1].y:
			all_lines_rise = false
			break
	_expect(all_lines_rise, "every generated cliff line runs upward")
	_add_labels(board)
	board.queue_redraw()
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	_expect(image != null and not image.is_empty(), "raised cliff QA capture is available")
	if image != null and not image.is_empty():
		_expect(
			image.save_png(output_absolute.path_join(OUTPUT_FILE)) == OK,
			"raised cliff variants screenshot is saved"
		)
	_finish()

func _load_void_texture(
	manifest: IsometricEnvironmentManifest,
	asset_id: StringName,
	palette: BiomePalette
) -> Texture2D:
	var contract := manifest.get_void_asset_contract(asset_id)
	return _load_contract_texture(contract, palette)

func _load_object_texture(
	manifest: IsometricEnvironmentManifest,
	asset_id: StringName,
	palette: BiomePalette
) -> Texture2D:
	var contract := manifest.get_object_asset_contract(asset_id)
	return _load_contract_texture(contract, palette)

func _load_contract_texture(contract: Dictionary, palette: BiomePalette) -> Texture2D:
	return TEXTURE_LOADER.load_texture(
		String(contract.get("asset_path", "")),
		palette.prop_color,
		palette.floor_color,
		Vector2i(512, 512)
	)

func _add_labels(board: Node2D) -> void:
	var title := _make_label(
		"CLIFF ROCCIA - KIT 3D ASCENDENTE",
		Vector2(0.0, 18.0),
		Vector2(1280.0, 42.0),
		26,
		Color("f1dda6")
	)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	board.add_child(title)
	var subtitle := _make_label(
		"Stesse 14 geometrie del void | faccia e fenditure estruse verso l'alto",
		Vector2(0.0, 56.0),
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
			center + Vector2(-72.0, -180.0),
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
		print("ROCK_CLIFF_GENERATED_VISUAL_QA: PASS")
		quit(0)
		return
	print("ROCK_CLIFF_GENERATED_VISUAL_QA: FAIL (%d)" % failures.size())
	quit(1)
