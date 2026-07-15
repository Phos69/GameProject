extends SceneTree

## Rebuilds the generated cliff library from projection-neutral source material.
##
## The logical cliff volume is authored by the runtime mesh builders. These PNGs
## therefore provide material only: a front-facing wall crop for vertical faces
## and the matching overhead terrain for lips/corners. No source silhouette or
## diamond/axonometric geometry is allowed to leak into the mesh.

const GENERATED_ROOT := "res://assets/environment/top_down/generated_images"
const THEMES: Array[StringName] = [
	&"desert",
	&"forest",
	&"frozen_tundra",
	&"swamp",
	&"urban_ruins",
	&"volcanic",
]
const OUTPUT_SIZE := Vector2i(512, 512)

var failures := PackedStringArray()

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var check_only := args.has("--check")
	var rebuilt := 0
	for theme_id in THEMES:
		rebuilt += _process_theme(theme_id, check_only)
	if failures.is_empty():
		print(
			"TOP_DOWN_CLIFF_TEXTURES: %s files=%d"
			% ["CHECK" if check_only else "WRITE", rebuilt]
		)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _process_theme(theme_id: StringName, check_only: bool) -> int:
	var theme := String(theme_id)
	var terrain_dir := GENERATED_ROOT.path_join("terrain").path_join(theme)
	var cliff_dir := GENERATED_ROOT.path_join("cliff").path_join(theme)
	var terrain_path := _find_base_ground(terrain_dir)
	if terrain_path.is_empty():
		failures.append("%s: base ground texture missing" % theme)
		return 0
	var terrain := _load_image(terrain_path)
	if terrain == null:
		return 0
	var overhead_material := _square_center_crop(terrain)
	if overhead_material == null:
		failures.append("%s: cannot build overhead material" % theme)
		return 0
	var directory := DirAccess.open(cliff_dir)
	if directory == null:
		failures.append("%s: cliff directory missing" % theme)
		return 0
	var file_names := PackedStringArray()
	for file_name in directory.get_files():
		if file_name.to_lower().ends_with(".png"):
			file_names.append(file_name)
	file_names.sort()
	if file_names.size() != 11:
		failures.append(
			"%s: expected 11 cliff textures, found %d"
			% [theme, file_names.size()]
		)
	var processed := 0
	for file_name in file_names:
		var output_path := cliff_dir.path_join(file_name)
		if check_only:
			_validate_output(output_path)
			processed += 1
			continue
		var output := overhead_material.duplicate()
		if file_name.contains("cliff_face"):
			var source := _load_image(output_path)
			if source == null:
				continue
			output = _front_wall_crop(source)
		if output == null:
			failures.append("%s: failed to build %s" % [theme, file_name])
			continue
		var error: Error = output.save_png(ProjectSettings.globalize_path(output_path))
		if error != OK:
			failures.append("%s: cannot write %s (%s)" % [theme, file_name, error_string(error)])
			continue
		processed += 1
	return processed

func _find_base_ground(directory_path: String) -> String:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return ""
	var candidates := PackedStringArray()
	for file_name in directory.get_files():
		if (
			file_name.to_lower().ends_with(".png")
			and file_name.contains("base_ground_variation")
		):
			candidates.append(file_name)
	candidates.sort()
	if candidates.is_empty():
		return ""
	return directory_path.path_join(candidates[0])

func _load_image(resource_path: String) -> Image:
	var image := Image.new()
	var error := image.load(ProjectSettings.globalize_path(resource_path))
	if error != OK:
		failures.append("cannot load %s (%s)" % [resource_path, error_string(error)])
		return null
	image.convert(Image.FORMAT_RGBA8)
	return image

func _square_center_crop(source: Image) -> Image:
	var side := mini(source.get_width(), source.get_height())
	if side <= 0:
		return null
	var region := source.get_region(Rect2i(
		(source.get_width() - side) / 2,
		(source.get_height() - side) / 2,
		side,
		side
	))
	region.resize(OUTPUT_SIZE.x, OUTPUT_SIZE.y, Image.INTERPOLATE_LANCZOS)
	return region

func _front_wall_crop(source: Image) -> Image:
	var width := source.get_width()
	var height := source.get_height()
	if width <= 0 or height <= 0:
		return null
	# Discard the embedded top plane and loose base from the old source. The
	# remaining central band is projection-neutral wall material.
	var crop := Rect2i(
		floori(float(width) * 0.18),
		floori(float(height) * 0.30),
		maxi(floori(float(width) * 0.64), 1),
		maxi(floori(float(height) * 0.52), 1)
	)
	var region := source.get_region(crop)
	region.resize(OUTPUT_SIZE.x, OUTPUT_SIZE.y, Image.INTERPOLATE_LANCZOS)
	return region

func _validate_output(resource_path: String) -> void:
	var image := _load_image(resource_path)
	if image == null:
		return
	if image.get_size() != OUTPUT_SIZE:
		failures.append(
			"%s: expected %s, got %s"
			% [resource_path, OUTPUT_SIZE, image.get_size()]
		)
