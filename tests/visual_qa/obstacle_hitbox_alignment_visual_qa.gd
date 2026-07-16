extends SceneTree

const OUTPUT_DIR := "res://build/qa/obstacle_hitbox_alignment"
const OUTPUT_FILE := "obstacle_hitbox_alignment.png"
const WorldGridConfig = preload("res://game/core/world_grid_config.gd")
const OBSTACLE_IDS: Array[StringName] = [&"ruined_house", &"abandoned_house"]
const CENTERS: Array[Vector2] = [Vector2(350.0, 390.0), Vector2(930.0, 390.0)]

var failures := PackedStringArray()

class QaBackdrop extends Node2D:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(1280.0, 720.0)), Color("10171c"))
		for center in CENTERS:
			var panel := Rect2(center - Vector2(270.0, 245.0), Vector2(540.0, 490.0))
			draw_rect(panel, Color("223128"), true)
			draw_rect(panel, Color("78926f"), false, 2.0)
			for offset in range(-4, 5):
				var delta := float(offset) * 48.0
				draw_line(
					Vector2(center.x + delta, panel.position.y),
					Vector2(center.x + delta, panel.end.y),
					Color(0.54, 0.66, 0.49, 0.28),
					1.0
				)
				draw_line(
					Vector2(panel.position.x, center.y + delta),
					Vector2(panel.end.x, center.y + delta),
					Color(0.54, 0.66, 0.49, 0.28),
					1.0
				)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var output_absolute := ProjectSettings.globalize_path(OUTPUT_DIR)
	_expect(
		DirAccess.make_dir_recursive_absolute(output_absolute) == OK,
		"hitbox alignment QA output directory is available"
	)
	var scene_root := Node2D.new()
	scene_root.name = "ObstacleHitboxAlignmentVisualQa"
	root.add_child(scene_root)
	current_scene = scene_root

	var backdrop := QaBackdrop.new()
	backdrop.z_index = -10
	scene_root.add_child(backdrop)
	_add_title(scene_root)

	var world := Node2D.new()
	world.name = "YSortedWorld"
	world.y_sort_enabled = true
	scene_root.add_child(world)
	var system := ObstacleSystem.new()
	system.name = "ObstacleSystem"
	scene_root.add_child(system)
	await process_frame

	var manifest := EnvironmentAssetManifest.reload_shared()
	for index in range(OBSTACLE_IDS.size()):
		var obstacle_id := OBSTACLE_IDS[index]
		var logical_footprint := WorldGridConfig.legacy_size_to_new_tiles(
			manifest.get_footprint_tiles(obstacle_id)
		)
		var world_size := Vector2(logical_footprint) * WorldGridConfig.LOGICAL_TILE_SCALE
		var obstacle := system.create_obstacle_instance(
			obstacle_id,
			world_size,
			&"rectangle",
			0.0,
			Color("46513d"),
			Color("c6b36d")
		) as EnvironmentObject
		_expect(obstacle != null, "%s QA object is created" % String(obstacle_id))
		if obstacle == null:
			continue
		obstacle.name = String(obstacle_id).to_pascal_case()
		ObstacleSystem.attach_obstacle_at_layout_center(world, obstacle, CENTERS[index])
		obstacle.set_debug_footprint_visible(true)
		_add_label(
			scene_root,
			String(obstacle_id).to_upper().replace("_", " "),
			Vector2(CENTERS[index].x - 250.0, 615.0)
		)

	await process_frame
	await process_frame
	var floor_centered := world.get_node_or_null("RuinedHouseSortAnchor/RuinedHouse") as EnvironmentObject
	_expect(floor_centered != null, "floor-centered runtime house is available")
	if floor_centered != null:
		_expect(
			absf(
				floor_centered.get_asset_visual_bounds().get_center().y
				- floor_centered.get_collision_offset().y
			) <= 1.0,
			"floor-centered art and collider share their vertical center"
		)
	await _capture(output_absolute.path_join(OUTPUT_FILE))
	_finish()

func _add_title(parent: Node2D) -> void:
	var title := Label.new()
	title.text = "OSTACOLI - ALLINEAMENTO SPRITE / HITBOX (F9)"
	title.position = Vector2(0.0, 28.0)
	title.size = Vector2(1280.0, 48.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", Color("f2dfad"))
	parent.add_child(title)

func _add_label(parent: Node2D, text_value: String, position_value: Vector2) -> void:
	var label := Label.new()
	label.text = text_value
	label.position = position_value
	label.size = Vector2(500.0, 32.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color("dce9d2"))
	parent.add_child(label)

func _capture(path: String) -> void:
	var image := root.get_texture().get_image()
	_expect(image != null and not image.is_empty(), "hitbox alignment capture is available")
	if image == null or image.is_empty():
		return
	_expect(image.save_png(path) == OK, "hitbox alignment screenshot is saved")

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("OBSTACLE_HITBOX_ALIGNMENT_VISUAL_QA: PASS")
		quit(0)
		return
	print("OBSTACLE_HITBOX_ALIGNMENT_VISUAL_QA: FAIL (%d)" % failures.size())
	quit(1)
