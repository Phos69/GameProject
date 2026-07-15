extends SceneTree

const OUTPUT_DIR := "res://build/qa/obstacle_3x3"
const GAMEPLAY_FILE := "obstacle_3x3_gameplay.png"
const FOOTPRINT_FILE := "obstacle_3x3_footprints.png"
const FEATURE_IDS: Array[StringName] = [&"forest_tree", &"dead_tree"]
const FEATURE_LABELS: Array[String] = ["FOREST TREE", "DEAD TREE"]
const FEATURE_NOTES: Array[String] = [
	"placement 2x2 | radici diametro 48 | Y-sort radici",
	"placement 1x2 | radici diametro 24 | Y-sort radici",
]
const FEATURE_CENTERS: Array[Vector2] = [Vector2(350.0, 455.0), Vector2(930.0, 455.0)]
const FEATURE_WORLD_SIZES: Array[Vector2] = [Vector2(96.0, 96.0), Vector2(48.0, 96.0)]
const PANEL_RECTS: Array[Rect2] = [
	Rect2(60.0, 92.0, 560.0, 552.0),
	Rect2(660.0, 92.0, 560.0, 552.0),
]

var failures := PackedStringArray()

class QaBackdrop extends Node2D:
	var debug_footprints := false
	var feature_centers: Array[Vector2] = []
	var feature_sizes: Array[Vector2] = []
	var panel_rects: Array[Rect2] = []

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(1280.0, 720.0)), Color("10171c"))
		for index in range(feature_centers.size()):
			_draw_panel(panel_rects[index])
			_draw_grid(feature_centers[index], feature_sizes[index])

	func _draw_panel(rect: Rect2) -> void:
		draw_rect(rect, Color("18242a"), true)
		draw_rect(rect, Color("61735e"), false, 2.0)

	func _draw_grid(center: Vector2, world_size: Vector2) -> void:
		var cell_size := 48.0
		var footprint_cells := Vector2i(
			roundi(world_size.x / cell_size),
			roundi(world_size.y / cell_size)
		)
		var grid_origin := center - Vector2(
			(3.0 if footprint_cells.x % 2 == 0 else 2.5) * cell_size,
			(3.0 if footprint_cells.y % 2 == 0 else 2.5) * cell_size
		)
		var placement_rect := Rect2(center - world_size * 0.5, world_size)
		for row in range(6):
			for column in range(6):
				var cell_position := grid_origin + Vector2(column, row) * cell_size
				var cell_rect := Rect2(cell_position, Vector2.ONE * cell_size)
				var in_footprint := placement_rect.has_point(cell_rect.get_center())
				var fill: Color = Color("344b38") if not in_footprint else Color("485a36")
				if debug_footprints and in_footprint:
					fill = Color(0.78, 0.48, 0.13, 0.28)
				draw_rect(cell_rect, fill, true)
				draw_rect(cell_rect, Color(0.58, 0.69, 0.49, 0.72), false, 1.0)
		draw_line(center + Vector2(-150.0, 0.0), center + Vector2(150.0, 0.0), Color("a8c59a"), 1.5)
		draw_line(center + Vector2(0.0, -150.0), center + Vector2(0.0, 150.0), Color("a8c59a"), 1.5)

class QaActor extends Node2D:
	var body_color := Color.WHITE

	func _draw() -> void:
		draw_circle(Vector2(0.0, -30.0), 13.0, body_color.lightened(0.12))
		draw_rect(Rect2(-12.0, -29.0, 24.0, 29.0), body_color, true)
		draw_ellipse_shadow()

	func draw_ellipse_shadow() -> void:
		var points := PackedVector2Array()
		for index in range(16):
			var angle := TAU * float(index) / 16.0
			points.append(Vector2(cos(angle) * 15.0, sin(angle) * 5.0))
		draw_colored_polygon(points, Color(0.0, 0.0, 0.0, 0.35))

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
	backdrop.feature_centers.assign(FEATURE_CENTERS)
	backdrop.feature_sizes.assign(FEATURE_WORLD_SIZES)
	backdrop.panel_rects.assign(PANEL_RECTS)
	scene_root.add_child(backdrop)
	_add_labels(scene_root)
	var world := Node2D.new()
	world.name = "YSortedWorld"
	world.y_sort_enabled = true
	scene_root.add_child(world)

	var system := ObstacleSystem.new()
	system.name = "ObstacleSystem"
	scene_root.add_child(system)
	await process_frame

	var obstacles: Array[BiomeObstacle] = []
	for index in range(FEATURE_IDS.size()):
		var obstacle_id := FEATURE_IDS[index]
		var obstacle := system.create_obstacle_instance(
			obstacle_id,
			FEATURE_WORLD_SIZES[index],
			&"rectangle",
			0.0,
			Color("3f512f"),
			Color("c7a65d")
		)
		_expect(obstacle != null, "%s QA object is created" % String(obstacle_id))
		if obstacle == null:
			continue
		obstacle.name = String(obstacle_id).to_pascal_case()
		ObstacleSystem.attach_obstacle_at_layout_center(
			world,
			obstacle,
			FEATURE_CENTERS[index]
		)
		obstacles.append(obstacle)

	for index in range(FEATURE_CENTERS.size()):
		var center := FEATURE_CENTERS[index]
		_add_actor(
			world,
			center + Vector2(0.0, 15.0),
			Color("4e8cc9"),
			"BehindActor%d" % index
		)
		_add_actor(
			world,
			center + Vector2(0.0, 55.0),
			Color("e39b47"),
			"FrontActor%d" % index
		)

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

func _add_actor(parent: Node2D, world_position: Vector2, color: Color, actor_name: String) -> void:
	var actor := QaActor.new()
	actor.name = actor_name
	actor.position = world_position
	actor.body_color = color
	parent.add_child(actor)

func _add_labels(scene_root: Node2D) -> void:
	var title := _make_label(
		"OSTACOLI TOP-DOWN - VALIDAZIONE 3x3",
		Vector2(0.0, 24.0),
		Vector2(1280.0, 48.0),
		26,
		Color("f2dfad")
	)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scene_root.add_child(title)
	for index in range(FEATURE_LABELS.size()):
		var panel := PANEL_RECTS[index]
		var label := _make_label(
			FEATURE_LABELS[index],
			panel.position + Vector2(0.0, 18.0),
			Vector2(panel.size.x, 34.0),
			20,
			Color("e8f0d2")
		)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		scene_root.add_child(label)
		var note := _make_label(
			FEATURE_NOTES[index],
			Vector2(panel.position.x, panel.end.y - 48.0),
			Vector2(panel.size.x, 28.0),
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
