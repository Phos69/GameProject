extends SceneTree

const OUTPUT_DIR := "res://build/qa/obstacle_3x3"
const GAMEPLAY_FILE := "obstacle_3x3_gameplay.png"
const FOOTPRINT_FILE := "obstacle_3x3_footprints.png"
const FEATURE_IDS: Array[StringName] = [&"forest_tree", &"large_rock"]
const FEATURE_LABELS: Array[String] = ["ALBERO 3x3", "ROCCIA 3x3"]
const FEATURE_CENTERS: Array[Vector2] = [Vector2(350.0, 455.0), Vector2(930.0, 455.0)]
const WORLD_SIZE := Vector2(96.0, 96.0)

var failures := PackedStringArray()

class QaBackdrop extends Node2D:
	var debug_footprints := false

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(1280.0, 720.0)), Color("10171c"))
		_draw_panel(Rect2(54.0, 92.0, 592.0, 552.0))
		_draw_panel(Rect2(634.0, 92.0, 592.0, 552.0))
		_draw_grid(Vector2(350.0, 455.0))
		_draw_grid(Vector2(930.0, 455.0))

	func _draw_panel(rect: Rect2) -> void:
		draw_rect(rect, Color("18242a"), true)
		draw_rect(rect, Color("61735e"), false, 2.0)

	func _draw_grid(center: Vector2) -> void:
		for row in range(-2, 3):
			for column in range(-2, 3):
				var tile_center := center + Vector2(
					float(column - row) * 16.0,
					float(column + row) * 8.0
				)
				var in_footprint: bool = abs(column) <= 1 and abs(row) <= 1
				var fill: Color = Color("344b38") if not in_footprint else Color("485a36")
				if debug_footprints and in_footprint:
					fill = Color(0.78, 0.18, 0.13, 0.42)
				var points := PackedVector2Array([
					tile_center + Vector2(0.0, -8.0),
					tile_center + Vector2(16.0, 0.0),
					tile_center + Vector2(0.0, 8.0),
					tile_center + Vector2(-16.0, 0.0)
				])
				draw_colored_polygon(points, fill)
				var outline := points.duplicate()
				outline.append(points[0])
				draw_polyline(outline, Color(0.58, 0.69, 0.49, 0.72), 1.0, true)
				if debug_footprints and in_footprint:
					draw_line(tile_center + Vector2(-4.0, -4.0), tile_center + Vector2(4.0, 4.0), Color("ffb15c"), 1.5)
					draw_line(tile_center + Vector2(4.0, -4.0), tile_center + Vector2(-4.0, 4.0), Color("ffb15c"), 1.5)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var output_absolute := ProjectSettings.globalize_path(OUTPUT_DIR)
	_expect(
		DirAccess.make_dir_recursive_absolute(output_absolute) == OK,
		"3x3 QA output directory is available"
	)
	var scene_root := Node2D.new()
	scene_root.name = "Obstacle3x3VisualQa"
	root.add_child(scene_root)
	current_scene = scene_root

	var backdrop := QaBackdrop.new()
	backdrop.name = "Backdrop"
	backdrop.z_index = -10
	scene_root.add_child(backdrop)
	_add_labels(scene_root)

	var system := ObstacleSystem.new()
	system.name = "ObstacleSystem"
	scene_root.add_child(system)
	await process_frame

	var obstacles: Array[BiomeObstacle] = []
	for index in range(FEATURE_IDS.size()):
		var obstacle_id := FEATURE_IDS[index]
		var obstacle := system.create_obstacle_instance(
			obstacle_id,
			WORLD_SIZE,
			&"rectangle",
			0.0,
			Color("3f512f"),
			Color("c7a65d")
		)
		_expect(obstacle != null, "%s QA object is created" % String(obstacle_id))
		if obstacle == null:
			continue
		obstacle.name = String(obstacle_id).to_pascal_case()
		obstacle.position = FEATURE_CENTERS[index]
		scene_root.add_child(obstacle)
		obstacles.append(obstacle)

	await process_frame
	await process_frame
	await _capture(output_absolute.path_join(GAMEPLAY_FILE))

	backdrop.debug_footprints = true
	backdrop.queue_redraw()
	for obstacle in obstacles:
		obstacle.set_debug_footprint_visible(true)
	await process_frame
	await process_frame
	await _capture(output_absolute.path_join(FOOTPRINT_FILE))

	for obstacle in obstacles:
		_expect(obstacle.has_debug_footprint(), "%s exposes its collision overlay" % obstacle.name)
	_finish()

func _add_labels(scene_root: Node2D) -> void:
	var title := _make_label(
		"OSTACOLI ISOMETRICI - VALIDAZIONE 3x3",
		Vector2(0.0, 24.0),
		Vector2(1280.0, 48.0),
		26,
		Color("f2dfad")
	)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scene_root.add_child(title)
	for index in range(FEATURE_LABELS.size()):
		var label := _make_label(
			FEATURE_LABELS[index],
			Vector2(54.0 + float(index) * 580.0, 110.0),
			Vector2(592.0, 34.0),
			20,
			Color("e8f0d2")
		)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		scene_root.add_child(label)
		var note := _make_label(
			"9 slot bloccanti | movimento + proiettili",
			Vector2(54.0 + float(index) * 580.0, 596.0),
			Vector2(592.0, 28.0),
			15,
			Color("9fb398")
		)
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		scene_root.add_child(note)

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

func _capture(path: String) -> void:
	var image := root.get_texture().get_image()
	_expect(image != null and not image.is_empty(), "%s capture is available" % path.get_file())
	if image == null or image.is_empty():
		return
	_expect(image.save_png(path) == OK, "%s screenshot is saved" % path.get_file())

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("OBSTACLE_3X3_VISUAL_QA: PASS")
		quit(0)
		return
	print("OBSTACLE_3X3_VISUAL_QA: FAIL (%d)" % failures.size())
	quit(1)
