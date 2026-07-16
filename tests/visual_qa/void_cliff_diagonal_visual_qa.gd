extends SceneTree

const OUTPUT_DIR := "res://build/qa/void_cliffs"
const OUTPUT_FILE := "void_cliff_diagonal_join.png"
const ZONE_SIZE := Vector2i(16, 16)
const LOGICAL_SCALE := 32.0

var failures := PackedStringArray()

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(720, 720)
	var output_absolute := ProjectSettings.globalize_path(OUTPUT_DIR)
	_expect(
		DirAccess.make_dir_recursive_absolute(output_absolute) == OK,
		"diagonal cliff QA output directory is available"
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
	layout.generation_seed = 641004
	layout.add_floor_rect(Rect2i(Vector2i.ZERO, ZONE_SIZE), &"forest_grass")
	layout.add_fall_zone_rect(
		Rect2i(Vector2i(2, 2), Vector2i(6, 6)),
		&"internal"
	)
	layout.add_fall_zone_rect(
		Rect2i(Vector2i(8, 8), Vector2i(6, 6)),
		&"internal"
	)
	layout.rebuild_terrain_classification()

	var layer := BiomeTileLayer.new()
	layer.position = Vector2(360.0, 370.0)
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
		int(counts.get("terrain_transition_corners", 0)) == 8,
		"six external corners and two recessed diagonal sectors build rounded joins"
	)
	var image := root.get_texture().get_image()
	_expect(
		image != null and not image.is_empty(),
		"diagonal cliff QA capture is available"
	)
	if image != null and not image.is_empty():
		_expect(
			image.save_png(output_absolute.path_join(OUTPUT_FILE)) == OK,
			"diagonal cliff QA screenshot is saved"
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
		print("VOID_CLIFF_DIAGONAL_VISUAL_QA: PASS")
		quit(0)
		return
	print("VOID_CLIFF_DIAGONAL_VISUAL_QA: FAIL (%d)" % failures.size())
	quit(1)
