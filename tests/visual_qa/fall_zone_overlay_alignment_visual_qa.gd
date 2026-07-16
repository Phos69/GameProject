extends SceneTree

const OUTPUT_DIR := "res://build/qa/void_cliffs"
const OUTPUT_FILE := "fall_zone_f9_overlay_alignment.png"
const ZONE_SIZE := Vector2i(15, 15)
const LOGICAL_SCALE := 32.0

var failures := PackedStringArray()

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(720, 720)
	var output_absolute := ProjectSettings.globalize_path(OUTPUT_DIR)
	_expect(
		DirAccess.make_dir_recursive_absolute(output_absolute) == OK,
		"fall-zone overlay QA output directory is available"
	)
	var background := ColorRect.new()
	background.color = Color("101713")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.z_index = -20
	root.add_child(background)
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene

	var palette := load(
		"res://game/modes/zombie/biomes/infected_plains_palette.tres"
	) as BiomePalette
	var layout := BiomeEnvironmentLayout.new()
	layout.zone_size = ZONE_SIZE
	layout.logical_tile_scale = LOGICAL_SCALE
	layout.generation_seed = 641006
	layout.add_floor_rect(Rect2i(Vector2i.ZERO, ZONE_SIZE), &"forest_grass")
	layout.add_fall_zone_rect(
		Rect2i(Vector2i(7, 3), Vector2i(2, 9)),
		&"internal"
	)
	layout.add_fall_zone_rect(
		Rect2i(Vector2i(3, 7), Vector2i(9, 2)),
		&"internal"
	)
	layout.rebuild_terrain_classification()

	var world_center := Vector2(360.0, 360.0)
	var layer := BiomeTileLayer.new()
	layer.position = world_center
	scene.add_child(layer)
	layer.configure(
		layout,
		palette,
		&"infected_plains",
		&"quality",
		16
	)
	for index in range(layout.hazard_ids.size()):
		var fall_zone := BiomeFallZone.new()
		scene.add_child(fall_zone)
		fall_zone.configure(
			&"fall_zone",
			layout.hazard_sizes[index],
			0.0,
			palette.hazard_color,
			&"cliff",
			&"internal",
			layout.generation_seed + index * 97
		)
		fall_zone.position = world_center + layout.get_hazard_position(index)
		fall_zone.set_debug_visual_visible(true)
		_expect(
			fall_zone.has_debug_visual(),
			"F9 overlay is enabled for fall zone %d" % index
		)
	for _frame in range(4):
		await process_frame
	var image := root.get_texture().get_image()
	_expect(
		image != null and not image.is_empty(),
		"fall-zone overlay QA capture is available"
	)
	if image != null and not image.is_empty():
		_expect(
			image.save_png(output_absolute.path_join(OUTPUT_FILE)) == OK,
			"fall-zone overlay QA screenshot is saved"
		)
	_finish()

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("FALL_ZONE_OVERLAY_ALIGNMENT_VISUAL_QA: PASS")
		quit(0)
		return
	print("FALL_ZONE_OVERLAY_ALIGNMENT_VISUAL_QA: FAIL (%d)" % failures.size())
	quit(1)
