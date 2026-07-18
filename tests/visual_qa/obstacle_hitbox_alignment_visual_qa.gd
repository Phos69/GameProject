extends SceneTree

const OUTPUT_DIR := "res://build/qa/obstacle_hitbox_alignment"
const OUTPUT_FILE := "obstacle_hitbox_alignment.png"
const CANVAS_SIZE := Vector2i(1920, 900)
const WorldGridConfig = preload("res://game/core/world_grid_config.gd")
const OBSTACLE_IDS: Array[StringName] = [
	&"small_rock", &"broken_fence", &"wood_barrier", &"fallen_log",
	&"abandoned_car", &"ruined_house", &"abandoned_house", &"dense_vegetation"
]
const CRATE_TYPES: Array[StringName] = [&"common", &"medical"]
const CENTERS: Array[Vector2] = [
	Vector2(210.0, 270.0), Vector2(585.0, 270.0), Vector2(960.0, 270.0),
	Vector2(1335.0, 270.0), Vector2(1710.0, 270.0),
	Vector2(210.0, 650.0), Vector2(585.0, 650.0), Vector2(960.0, 650.0),
	Vector2(1335.0, 650.0), Vector2(1710.0, 650.0)
]

var failures := PackedStringArray()

class QaBackdrop extends Node2D:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(CANVAS_SIZE)), Color("10171c"))
		for center in CENTERS:
			var panel := Rect2(center - Vector2(165.0, 155.0), Vector2(330.0, 310.0))
			draw_rect(panel, Color("223128"), true)
			draw_rect(panel, Color("78926f"), false, 2.0)
			for offset in range(-3, 4):
				var delta := float(offset) * 48.0
				draw_line(
					Vector2(center.x + delta, panel.position.y),
					Vector2(center.x + delta, panel.end.y),
					Color(0.54, 0.66, 0.49, 0.24),
					1.0
				)
				draw_line(
					Vector2(panel.position.x, center.y + delta),
					Vector2(panel.end.x, center.y + delta),
					Color(0.54, 0.66, 0.49, 0.24),
					1.0
				)

class CrateHitboxOverlay extends Node2D:
	func _draw() -> void:
		var rect := Rect2(Vector2(-21.0, -17.0), Vector2(42.0, 34.0))
		draw_rect(rect, Color(0.15, 0.60, 0.95, 0.16), true)
		draw_rect(rect, Color(0.30, 0.80, 1.0, 0.92), false, 2.5)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = CANVAS_SIZE
	root.content_scale_size = CANVAS_SIZE
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

	var manifest := EnvironmentAssetManifest.reload_shared()
	var factory := EnvironmentObjectFactory.new(manifest)
	for index in range(OBSTACLE_IDS.size()):
		var obstacle_id := OBSTACLE_IDS[index]
		var logical_footprint := WorldGridConfig.legacy_size_to_new_tiles(
			manifest.get_footprint_tiles(obstacle_id)
		)
		var world_size := Vector2(logical_footprint) * WorldGridConfig.LOGICAL_TILE_SCALE
		var obstacle := factory.create_obstacle(
			obstacle_id,
			world_size,
			manifest.get_collision_shape(obstacle_id),
			0.0,
			Color("46513d"),
			Color("c6b36d"),
			manifest.get_sort_offset(obstacle_id),
			&"plains"
		) as EnvironmentObject
		_expect(obstacle != null, "%s QA object is created" % String(obstacle_id))
		if obstacle == null:
			continue
		obstacle.name = String(obstacle_id).to_pascal_case()
		ObstacleSystem.attach_obstacle_at_layout_center(world, obstacle, CENTERS[index])
		obstacle.set_debug_footprint_visible(true)
		_add_label(scene_root, String(obstacle_id), CENTERS[index])
		await process_frame
		_expect_visual_covers_hitbox(
			String(obstacle_id),
			obstacle.get_asset_visual_bounds(),
			Rect2(
				obstacle.get_collision_offset() - obstacle.get_collision_size() * 0.5,
				obstacle.get_collision_size()
			),
			obstacle.asset_sprite.scale
		)
		_expect_expected_raster_collider_alignment(
			obstacle_id,
			obstacle.get_asset_visual_bounds(),
			obstacle.get_collision_size(),
			world_size
		)
		_expect(
			not obstacle.has_ground_shadow(),
			"%s has no runtime floor shadow" % String(obstacle_id)
		)

	var crate_scene := load("res://game/drops/supply_crate.tscn") as PackedScene
	_expect(crate_scene != null, "supply crate scene is available")
	if crate_scene != null:
		for crate_index in range(CRATE_TYPES.size()):
			var crate_type := CRATE_TYPES[crate_index]
			var center := CENTERS[OBSTACLE_IDS.size() + crate_index]
			var crate := crate_scene.instantiate() as SupplyCrate
			world.add_child(crate)
			crate.position = center
			var crate_visual := crate.get_node("Visual") as SupplyCrateVisual
			crate_visual.configure_crate_type(crate_type)
			var overlay := CrateHitboxOverlay.new()
			crate.add_child(overlay)
			_add_label(scene_root, "crate_%s" % String(crate_type), center)
			await process_frame
			var shape_node := crate.get_node("CollisionShape2D") as CollisionShape2D
			var rectangle := shape_node.shape as RectangleShape2D
			_expect(
				rectangle.size.is_equal_approx(Vector2(84.0, 68.0)),
				"crate_%s hitbox is doubled" % String(crate_type)
			)
			_expect(
				not crate_visual.has_floor_decoration(),
				"crate_%s has no floor circle or shadow" % String(crate_type)
			)
			_expect_visual_covers_hitbox(
				"crate_%s" % String(crate_type),
				crate_visual.get_asset_visual_bounds(),
				Rect2(-rectangle.size * 0.5, rectangle.size),
				crate_visual.asset_sprite.scale
			)

	await process_frame
	await process_frame
	var ruined := _find_environment_object(world, "RuinedHouse")
	_expect(ruined != null, "floor-centered runtime house is available")
	if ruined != null:
		_expect(
			absf(
				ruined.get_asset_visual_bounds().get_center().y
					- ruined.get_collision_offset().y
			) <= 1.0,
			"floor-centered art and collider share their vertical center"
		)
	await _capture(output_absolute.path_join(OUTPUT_FILE))
	_finish()

func _expect_visual_covers_hitbox(
	label: String,
	visual_bounds: Rect2,
	collision_bounds: Rect2,
	sprite_scale: Vector2
) -> void:
	_expect(
		visual_bounds.position.x <= collision_bounds.position.x + 0.05,
		"%s art reaches hitbox left edge" % label
	)
	_expect(
		visual_bounds.position.y <= collision_bounds.position.y + 0.05,
		"%s art reaches hitbox top edge" % label
	)
	_expect(
		visual_bounds.end.x >= collision_bounds.end.x - 0.05,
		"%s art reaches hitbox right edge" % label
	)
	_expect(
		visual_bounds.end.y >= collision_bounds.end.y - 0.05,
		"%s art reaches hitbox bottom edge" % label
	)
	_expect(
		is_equal_approx(sprite_scale.x, sprite_scale.y),
		"%s keeps uniform scale" % label
	)

func _expect_expected_raster_collider_alignment(
	obstacle_id: StringName,
	visual_bounds: Rect2,
	collision_size: Vector2,
	world_size: Vector2
) -> void:
	const EDGE_TOLERANCE := 1.25
	match obstacle_id:
		&"broken_fence", &"wood_barrier", &"fallen_log":
			_expect(
				collision_size.x > world_size.x,
				"%s hitbox expands horizontally to the raster silhouette" % String(obstacle_id)
			)
			_expect(
				absf(visual_bounds.size.x - collision_size.x) <= EDGE_TOLERANCE,
				"%s horizontal hitbox tracks the raster width" % String(obstacle_id)
			)
			_expect(
				is_equal_approx(collision_size.y, world_size.y),
				"%s keeps its original vertical hitbox" % String(obstacle_id)
			)
		&"abandoned_car":
			_expect(
				collision_size.y > world_size.y,
				"abandoned_car hitbox expands vertically to the raster silhouette"
			)
			_expect(
				absf(visual_bounds.size.y - collision_size.y) <= EDGE_TOLERANCE,
				"abandoned_car vertical hitbox tracks the raster height"
			)
			_expect(
				is_equal_approx(collision_size.x, world_size.x),
				"abandoned_car keeps its original horizontal hitbox"
			)

func _find_environment_object(parent: Node, object_name: String) -> EnvironmentObject:
	for child in parent.get_children():
		var found := child.find_child(object_name, true, false)
		if found is EnvironmentObject:
			return found as EnvironmentObject
	return null

func _add_title(parent: Node2D) -> void:
	var title := Label.new()
	title.text = "PIANURA INFETTA - COPERTURA SPRITE / HITBOX (F9)"
	title.position = Vector2(0.0, 22.0)
	title.size = Vector2(float(CANVAS_SIZE.x), 48.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", Color("f2dfad"))
	parent.add_child(title)

func _add_label(parent: Node2D, text_value: String, center: Vector2) -> void:
	var label := Label.new()
	label.text = text_value.to_upper().replace("_", " ")
	label.position = Vector2(center.x - 160.0, center.y + 125.0)
	label.size = Vector2(320.0, 28.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
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
