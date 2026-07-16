extends SceneTree

const OUTPUT_DIR := "res://build/qa/void_cliffs"
const OUTPUT_FILE := "void_cliff_convex_dirt_corner.png"
const ZONE_SIZE := Vector2i(12, 12)
const LOGICAL_SCALE := 42.0

var failures := PackedStringArray()

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(720, 720)
	var output_absolute := ProjectSettings.globalize_path(OUTPUT_DIR)
	_expect(
		DirAccess.make_dir_recursive_absolute(output_absolute) == OK,
		"convex dirt corner QA output directory is available"
	)
	var background := ColorRect.new()
	background.color = Color("101713")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.z_index = -20
	root.add_child(background)

	var palette := load(
		"res://game/modes/zombie/biomes/infected_plains_palette.tres"
	) as BiomePalette
	var layout := BiomeEnvironmentLayout.new()
	layout.zone_size = ZONE_SIZE
	layout.logical_tile_scale = LOGICAL_SCALE
	layout.generation_seed = 641005
	layout.add_floor_rect(Rect2i(Vector2i.ZERO, ZONE_SIZE), &"forest_grass")
	layout.add_fall_zone_rect(
		Rect2i(Vector2i(6, 2), Vector2i(4, 4)),
		&"internal"
	)
	layout.add_fall_zone_rect(
		Rect2i(Vector2i(2, 6), Vector2i(4, 4)),
		&"internal"
	)
	layout.add_fall_zone_rect(
		Rect2i(Vector2i(6, 6), Vector2i(4, 4)),
		&"internal"
	)
	layout.rebuild_terrain_classification()

	var layer := BiomeTileLayer.new()
	layer.position = Vector2(360.0, 360.0)
	root.add_child(layer)
	current_scene = layer
	layer.configure(
		layout,
		palette,
		&"infected_plains",
		&"quality",
		16
	)
	for _frame in range(4):
		await process_frame
	var counts := layer.get_forest_cliff_border_counts()
	_expect(
		int(counts.get("concave_corners", 0)) == 1,
		"the single terrain quadrant builds one shared concave join"
	)
	_expect(
		int(counts.get("terrain_transition_corners", 0)) == 6,
		"the dirt outline contains five outer corners and one unforked inner quarter"
	)
	var image := root.get_texture().get_image()
	_expect(
		image != null and not image.is_empty(),
		"convex dirt corner QA capture is available"
	)
	if image != null and not image.is_empty():
		_expect(
			image.save_png(output_absolute.path_join(OUTPUT_FILE)) == OK,
			"convex dirt corner QA screenshot is saved"
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
		print("VOID_CLIFF_CONVEX_DIRT_CORNER_VISUAL_QA: PASS")
		quit(0)
		return
	print("VOID_CLIFF_CONVEX_DIRT_CORNER_VISUAL_QA: FAIL (%d)" % failures.size())
	quit(1)
