extends SceneTree

## Offline, deterministic top-atlas builder for the approved Plains cross.
## Boundary modules reuse the matching authored wall crops; the four center
## variants are seamless surface crops from opaque areas of the same source.

const GRID_SIZE := Vector2i(4, 4)
const MODULE_SIZE := Vector2i(512, 512)
const EXPECTED_SOURCE_SIZE := Vector2i(1256, 1256)
const EXPECTED_WALL_ATLAS_SIZE := Vector2i(2048, 2048)
const EDGE_BLEND_PIXELS := 22
const CENTER_SAMPLE_RECTS: Array[Rect2i] = [
	Rect2i(554, 480, 148, 148),
	Rect2i(554, 200, 148, 148),
	Rect2i(260, 480, 148, 148),
	Rect2i(850, 480, 148, 148),
]

# Target rows are convex, edge, concave, center. Boundary cells point to the
# already validated semantic crops in the wall atlas.
const WALL_SOURCE_CELLS: Array[Vector2i] = [
	Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1),
	Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0),
	Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2),
]


func _init() -> void:
	var arguments := _parse_arguments(OS.get_cmdline_user_args())
	var source_path := str(arguments.get("source", ""))
	var wall_atlas_path := str(arguments.get("wall-atlas", ""))
	var output_path := str(arguments.get("output", ""))
	if source_path.is_empty() or wall_atlas_path.is_empty() or output_path.is_empty():
		printerr(
			"Usage: godot --headless --path . --script "
			+ "res://tools/build_plains_rock_top_atlas.gd -- "
			+ "--source=<alpha-cross> --wall-atlas=<wall-atlas> --output=<top-atlas>"
		)
		quit(2)
		return

	var source := Image.load_from_file(ProjectSettings.globalize_path(source_path))
	var wall_atlas := Image.load_from_file(
		ProjectSettings.globalize_path(wall_atlas_path)
	)
	if source.is_empty() or source.get_size() != EXPECTED_SOURCE_SIZE:
		printerr("Approved alpha cross must be %s" % EXPECTED_SOURCE_SIZE)
		quit(3)
		return
	if wall_atlas.is_empty() or wall_atlas.get_size() != EXPECTED_WALL_ATLAS_SIZE:
		printerr("Approved wall atlas must be %s" % EXPECTED_WALL_ATLAS_SIZE)
		quit(4)
		return
	source.convert(Image.FORMAT_RGBA8)
	wall_atlas.convert(Image.FORMAT_RGBA8)

	var modules: Array[Image] = []
	for cell in WALL_SOURCE_CELLS:
		modules.append(wall_atlas.get_region(Rect2i(cell * MODULE_SIZE, MODULE_SIZE)))
	for sample_rect in CENTER_SAMPLE_RECTS:
		var center := source.get_region(sample_rect)
		_force_opaque_alpha(center)
		center.resize(MODULE_SIZE.x, MODULE_SIZE.y, Image.INTERPOLATE_LANCZOS)
		_harmonize_edges(center)
		modules.append(center)

	var validation_error := _validate_modules(modules)
	if not validation_error.is_empty():
		printerr(validation_error)
		quit(5)
		return
	var atlas := Image.create(
		MODULE_SIZE.x * GRID_SIZE.x,
		MODULE_SIZE.y * GRID_SIZE.y,
		false,
		Image.FORMAT_RGBA8
	)
	atlas.fill(Color.TRANSPARENT)
	for index in range(modules.size()):
		var target_cell := Vector2i(index % GRID_SIZE.x, index / GRID_SIZE.x)
		atlas.blit_rect(
			modules[index],
			Rect2i(Vector2i.ZERO, MODULE_SIZE),
			target_cell * MODULE_SIZE
		)
	_clear_transparent_rgb(atlas)

	var absolute_output := ProjectSettings.globalize_path(output_path)
	var directory_error := DirAccess.make_dir_recursive_absolute(
		absolute_output.get_base_dir()
	)
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		printerr("Unable to create top atlas directory")
		quit(6)
		return
	var save_error := atlas.save_png(absolute_output)
	if save_error != OK:
		printerr("Unable to save top atlas: error %d" % save_error)
		quit(7)
		return
	print(
		"Built Plains top atlas %s + %s -> %s | modules=%d | size=%s"
		% [source_path, wall_atlas_path, output_path, modules.size(), atlas.get_size()]
	)
	quit(0)


func _harmonize_edges(image: Image) -> void:
	for offset in range(EDGE_BLEND_PIXELS):
		var weight := float(offset + 1) / float(EDGE_BLEND_PIXELS + 1)
		for cross in range(image.get_height()):
			var left := image.get_pixel(offset, cross)
			var right := image.get_pixel(image.get_width() - 1 - offset, cross)
			var seam := left.lerp(right, 0.5)
			image.set_pixel(offset, cross, left.lerp(seam, 1.0 - weight))
			image.set_pixel(
				image.get_width() - 1 - offset,
				cross,
				right.lerp(seam, 1.0 - weight)
			)
		for cross in range(image.get_width()):
			var top := image.get_pixel(cross, offset)
			var bottom := image.get_pixel(cross, image.get_height() - 1 - offset)
			var seam := top.lerp(bottom, 0.5)
			image.set_pixel(cross, offset, top.lerp(seam, 1.0 - weight))
			image.set_pixel(
				cross,
				image.get_height() - 1 - offset,
				bottom.lerp(seam, 1.0 - weight)
			)


func _validate_modules(modules: Array[Image]) -> String:
	if modules.size() != 16:
		return "Expected 16 top modules, built %d" % modules.size()
	var fingerprints: Dictionary = {}
	for index in range(modules.size()):
		var module := modules[index]
		if module.get_size() != MODULE_SIZE:
			return "Top module %d is not 512x512" % index
		var fingerprint := _fingerprint(module)
		if fingerprints.has(fingerprint):
			return "Top modules %d and %d are pixel-identical" % [
				int(fingerprints[fingerprint]),
				index,
			]
		fingerprints[fingerprint] = index
		if index >= 12 and _opaque_coverage(module) < 0.98:
			return "Top center module %d is not an opaque seamless surface" % index
	return ""


func _opaque_coverage(image: Image) -> float:
	var opaque := 0
	var samples := 0
	for y in range(0, image.get_height(), 8):
		for x in range(0, image.get_width(), 8):
			samples += 1
			if image.get_pixel(x, y).a > 0.98:
				opaque += 1
	return float(opaque) / float(maxi(samples, 1))


func _force_opaque_alpha(image: Image) -> void:
	# All declared center rectangles lie strictly inside the authored rocky top.
	# Violet cracks can resemble the magenta key chromatically, but they are rock
	# detail rather than holes. Restore only alpha; RGB remains source-authored.
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var pixel := image.get_pixel(x, y)
			pixel.a = 1.0
			image.set_pixel(x, y, pixel)


func _fingerprint(image: Image) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(image.get_data())
	return context.finish().hex_encode()


func _clear_transparent_rgb(image: Image) -> void:
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var pixel := image.get_pixel(x, y)
			if pixel.a <= 0.001:
				image.set_pixel(x, y, Color.TRANSPARENT)


func _parse_arguments(raw_arguments: PackedStringArray) -> Dictionary:
	var parsed: Dictionary = {}
	for argument in raw_arguments:
		if not argument.begins_with("--") or not argument.contains("="):
			continue
		var separator := argument.find("=")
		var key := argument.substr(2, separator - 2)
		parsed[key] = argument.substr(separator + 1)
	return parsed
