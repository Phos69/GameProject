extends SceneTree

const OUTPUT_DIR := "res://build/qa/plains_rock_cliffs"
const OUTPUT_FILE := "plains_mountain_void_contact.png"
const ZONE_SIZE := Vector2i(16, 12)
const LOGICAL_SCALE := WorldGridConfig.LOGICAL_TILE_SCALE
const MESA_RECT := Rect2i(Vector2i(4, 3), Vector2i(8, 5))
const FALL_RECT := Rect2i(Vector2i(4, 8), Vector2i(8, 2))

var failures := PackedStringArray()


class ContactBoard extends Node2D:
	var atlas_set: RockCliffAtlasSet
	var mesa_builder: ModularRockAreaMeshBuilder
	var face_builder: RectilinearCliffFaceMeshBuilder
	var void_color := Color.BLACK

	func _draw() -> void:
		var zone_offset := Vector2(ZONE_SIZE) * 0.5
		var zone_world_size := Vector2(ZONE_SIZE) * LOGICAL_SCALE
		draw_rect(Rect2(-zone_world_size * 0.5, zone_world_size), Color("9a7951"), true)
		var void_rect := Rect2(
			(Vector2(FALL_RECT.position) - zone_offset) * LOGICAL_SCALE,
			Vector2(FALL_RECT.size) * LOGICAL_SCALE
		)
		draw_rect(void_rect, void_color, true)
		var mesa_center := (
			Vector2(MESA_RECT.position) + Vector2(MESA_RECT.size) * 0.5 - zone_offset
		) * LOGICAL_SCALE
		var mesa_transform := Transform2D(0.0, mesa_center)
		# Match EnvironmentObject: opaque crown first, authored perimeter wall
		# second, then the unified mountain-to-void continuation.
		for role_value in mesa_builder.top_meshes_by_role:
			draw_mesh(
				mesa_builder.top_meshes_by_role[role_value] as ArrayMesh,
				atlas_set.top_atlas,
				mesa_transform
			)
		for role_value in mesa_builder.face_meshes_by_role:
			draw_mesh(
				mesa_builder.face_meshes_by_role[role_value] as ArrayMesh,
				atlas_set.wall_atlas,
				mesa_transform
			)
		for role_value in face_builder.face_meshes_by_role:
			draw_mesh(
				face_builder.face_meshes_by_role[role_value] as ArrayMesh,
				atlas_set.wall_atlas
			)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(960, 540)
	var output_absolute := ProjectSettings.globalize_path(OUTPUT_DIR)
	_expect(
		DirAccess.make_dir_recursive_absolute(output_absolute) == OK,
		"mountain contact QA output directory is available"
	)
	var board := ContactBoard.new()
	board.name = "PlainsMountainVoidContactVisualQa"
	board.position = Vector2(480.0, 290.0)
	board.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	var palette := load(
		"res://game/modes/zombie/biomes/plains_palette.tres"
	) as BiomePalette
	board.void_color = ZombieModeController.get_void_background_color(palette)
	_expect(
		board.void_color == ZombieModeController.PLAINS_VOID_BACKGROUND_COLOR,
		"the Plains chasm uses the dedicated cold-black fill"
	)
	board.atlas_set = RockCliffAtlasSet.new()
	_expect(
		board.atlas_set.configure(&"plains") and board.atlas_set.is_ready(),
		"Plains rock atlases load"
	)
	board.mesa_builder = ModularRockAreaMeshBuilder.new()
	board.mesa_builder.build_local_size(
		Vector2(MESA_RECT.size) * LOGICAL_SCALE,
		LOGICAL_SCALE,
		88117,
		true,
		board.atlas_set
	)
	board.face_builder = RectilinearCliffFaceMeshBuilder.new()
	var fall_rects: Array[Rect2i] = [FALL_RECT]
	var fall_sides: Array[StringName] = [&"internal"]
	var mesa_rects: Array[Rect2i] = [MESA_RECT]
	board.face_builder.build(
		fall_rects,
		fall_sides,
		ZONE_SIZE,
		LOGICAL_SCALE,
		mesa_rects,
		board.atlas_set
	)
	root.add_child(board)
	current_scene = board
	_add_labels(board)
	board.queue_redraw()
	await process_frame
	await process_frame
	_expect(
		board.face_builder.mountain_contact_count == 1,
		"the preview contains one continuous mountain-to-void contact"
	)
	_expect(
		board.face_builder.mountain_contact_stamp_count > 0,
		"the preview uses the doubled rocky contact stamps"
	)
	var image := root.get_texture().get_image()
	_expect(image != null and not image.is_empty(), "mountain contact capture is available")
	if image != null and not image.is_empty():
		_expect(
			image.save_png(output_absolute.path_join(OUTPUT_FILE)) == OK,
			"mountain contact screenshot is saved"
		)
	_finish()


func _add_labels(board: Node2D) -> void:
	var title := Label.new()
	title.text = "PLAINS — CONTATTO MONTAGNA / VOID, PARETE ROCCIOSA 2X"
	title.position = Vector2(-480.0, -275.0)
	title.size = Vector2(960.0, 38.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", Color("f1dda6"))
	board.add_child(title)


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)


func _finish() -> void:
	if failures.is_empty():
		print("PLAINS_MOUNTAIN_VOID_CONTACT_VISUAL_QA: PASS")
		quit(0)
		return
	print("PLAINS_MOUNTAIN_VOID_CONTACT_VISUAL_QA: FAIL (%d)" % failures.size())
	quit(1)
