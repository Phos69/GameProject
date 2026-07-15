extends SceneTree

const OUTPUT_DIR := "res://build/qa/obstacle_assets"
const ASSET_IDS: Array[StringName] = [
	&"small_rock", &"large_rock", &"metal_wreck", &"fallen_log", &"reed_wall",
	&"forest_tree", &"dense_vegetation", &"abandoned_house",
	&"ruined_house", &"abandoned_car", &"broken_fence", &"wood_barrier",
	&"lab_block", &"lab_ruin", &"pipe_stack", &"toxic_barrel",
	&"chemical_barrel", &"industrial_fence", &"corroded_barrier",
	&"burned_house", &"burned_car", &"charred_wall", &"scorched_barricade",
	&"snow_cabin", &"ice_rock", &"ice_block", &"snow_wall",
	&"sunken_house", &"sunken_wreck", &"dead_tree", &"marsh_log"
]

var failures := PackedStringArray()

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var manifest := EnvironmentAssetManifest.reload_shared()
	var output_absolute := ProjectSettings.globalize_path(OUTPUT_DIR)
	var directory_error := DirAccess.make_dir_recursive_absolute(output_absolute)
	_expect(directory_error == OK, "visual QA output directory is available")
	for obstacle_id in ASSET_IDS:
		_validate_asset(manifest, obstacle_id, output_absolute)
	_finish()

func _validate_asset(
	manifest: EnvironmentAssetManifest,
	obstacle_id: StringName,
	output_absolute: String
) -> void:
	var contract := manifest.get_object_asset_contract(obstacle_id)
	var asset_path := String(contract.get("asset_path", ""))
	_expect(FileAccess.file_exists(asset_path), "%s asset exists" % String(obstacle_id))
	if not FileAccess.file_exists(asset_path):
		return
	var image := Image.new()
	var load_error := ERR_FILE_UNRECOGNIZED
	if asset_path.ends_with(".svg"):
		var file := FileAccess.open(asset_path, FileAccess.READ)
		_expect(file != null, "%s SVG opens" % String(obstacle_id))
		if file == null:
			return
		var source := file.get_as_text()
		file.close()
		load_error = int(image.call("load_svg_from_string", source, 1.0))
	elif asset_path.ends_with(".tres"):
		var texture := ResourceLoader.load(asset_path) as Texture2D
		_expect(texture != null, "%s Texture2D resource loads" % String(obstacle_id))
		if texture == null:
			return
		image = texture.get_image()
		load_error = OK if image != null and not image.is_empty() else ERR_CANT_CREATE
	else:
		load_error = image.load(ProjectSettings.globalize_path(asset_path))
	_expect(load_error == OK, "%s asset rasterizes" % String(obstacle_id))
	if load_error != OK:
		return
	var native_size := manifest.get_native_visual_size(obstacle_id)
	var expected_size := Vector2i(roundi(native_size.x), roundi(native_size.y))
	var render_mode := StringName(str(contract.get("render_mode", "sprite")))
	if render_mode == &"tile_layer_rock_area":
		_expect(
			asset_path.ends_with("rock_plateau_top_generated.png"),
			"%s uses the dedicated repeated rock top material" % String(obstacle_id)
		)
		_expect(image.get_width() >= 512 and image.get_height() >= 512, "%s top texture supports tiled rendering" % String(obstacle_id))
		var output_path := output_absolute.path_join("%s.png" % String(obstacle_id))
		_expect(image.save_png(output_path) == OK, "%s visual QA PNG is saved" % String(obstacle_id))
		return
	if asset_path.ends_with(".svg"):
		_expect(
			image.get_size() == expected_size,
			"%s native SVG dimensions match footprint and visual height" % String(obstacle_id)
		)
	else:
		_expect(
			image.get_width() >= expected_size.x and image.get_height() >= expected_size.y,
			"%s source texture supports deterministic runtime downscaling" % String(obstacle_id)
		)
	_expect(_has_transparent_corners(image), "%s keeps a transparent canvas" % String(obstacle_id))
	_expect(_opaque_coverage(image) >= 0.06, "%s has a substantial finished silhouette" % String(obstacle_id))
	var output_path := output_absolute.path_join("%s.png" % String(obstacle_id))
	_expect(image.save_png(output_path) == OK, "%s visual QA PNG is saved" % String(obstacle_id))

func _has_transparent_corners(image: Image) -> bool:
	var last := image.get_size() - Vector2i.ONE
	return (
		image.get_pixel(0, 0).a < 0.05
		and image.get_pixel(last.x, 0).a < 0.05
		and image.get_pixel(0, last.y).a < 0.05
		and image.get_pixel(last.x, last.y).a < 0.05
	)

func _opaque_coverage(image: Image) -> float:
	var opaque := 0
	var samples := 0
	var step_x := maxi(image.get_width() / 64, 1)
	var step_y := maxi(image.get_height() / 64, 1)
	for y in range(0, image.get_height(), step_y):
		for x in range(0, image.get_width(), step_x):
			if image.get_pixel(x, y).a >= 0.20:
				opaque += 1
			samples += 1
	return float(opaque) / float(maxi(samples, 1))

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("OBSTACLE_ASSET_VISUAL_QA: PASS")
		quit(0)
		return
	print("OBSTACLE_ASSET_VISUAL_QA: FAIL (%d)" % failures.size())
	quit(1)
