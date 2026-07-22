extends SceneTree

## Offline, deterministic repacker for the approved Plains wall-cross source.
## It only crops, rescales, edge-harmonizes and composites authored pixels.
## Runtime code never invokes this tool and no rock detail is painted here.

const ATLAS_GRID := Vector2i(4, 4)
const MODULE_SIZE := Vector2i(512, 512)
const EXPECTED_SOURCE_SIZE := Vector2i(1256, 1256)
const SAMPLE_SIZE := Vector2i(384, 384)
const EDGE_BLEND_PIXELS := 18
const LATERAL_INSET_PIXELS := 256
const EAST_SOURCE_CREST_X := 210
const WEST_SOURCE_CREST_X := 300

const ROLE_LAYOUT: Array[StringName] = [
	&"edge_north", &"edge_east", &"edge_south", &"edge_west",
	&"convex_north_east", &"convex_south_east",
	&"convex_south_west", &"convex_north_west",
	&"concave_north_east", &"concave_south_east",
	&"concave_south_west", &"concave_north_west",
	&"diagonal_north_east_south_west",
	&"diagonal_north_west_south_east",
	&"cap_horizontal", &"cap_vertical",
]

# Pixel-space topology landmarks validated on the approved v3 1256x1256 alpha
# source. Every landmark is a real straight edge or concave/convex vertex in
# the connected cross; no directional variant is synthesized by rotation.
const SAMPLE_CENTERS: Dictionary = {
	&"edge_north": Vector2i(628, 79),
	&"edge_east": Vector2i(1188, 628),
	&"edge_south": Vector2i(628, 1172),
	&"edge_west": Vector2i(66, 628),
	&"convex_north_east": Vector2i(66, 838),
	&"convex_south_east": Vector2i(66, 385),
	&"convex_south_west": Vector2i(1188, 385),
	&"convex_north_west": Vector2i(1188, 838),
	&"concave_north_east": Vector2i(857, 385),
	&"concave_south_east": Vector2i(857, 838),
	&"concave_south_west": Vector2i(398, 838),
	&"concave_north_west": Vector2i(398, 385),
}

const EXPECTED_QUADRANT_MASKS: Dictionary = {
	&"edge_north": 12,
	&"edge_east": 9,
	&"edge_south": 3,
	&"edge_west": 6,
	&"convex_north_east": 2,
	&"convex_south_east": 4,
	&"convex_south_west": 8,
	&"convex_north_west": 1,
	&"concave_north_east": 13,
	&"concave_south_east": 11,
	&"concave_south_west": 7,
	&"concave_north_west": 14,
	&"diagonal_north_east_south_west": 10,
	&"diagonal_north_west_south_east": 5,
}
const LATERAL_FORBIDDEN_RECTS: Dictionary = {
	&"edge_east": Rect2i(256, 0, 256, 512),
	&"edge_west": Rect2i(0, 0, 256, 512),
	&"convex_north_east": Rect2i(0, 0, 256, 512),
	&"convex_south_east": Rect2i(0, 0, 256, 512),
	&"convex_south_west": Rect2i(256, 0, 256, 512),
	&"convex_north_west": Rect2i(256, 0, 256, 512),
	&"concave_north_east": Rect2i(256, 0, 256, 256),
	&"concave_south_east": Rect2i(256, 256, 256, 256),
	&"concave_south_west": Rect2i(0, 256, 256, 256),
	&"concave_north_west": Rect2i(0, 0, 256, 256),
}
const LATERAL_INSET_BAND_RECTS: Dictionary = {
	&"edge_east": Rect2i(256 - LATERAL_INSET_PIXELS, 0, LATERAL_INSET_PIXELS, 512),
	&"edge_west": Rect2i(256, 0, LATERAL_INSET_PIXELS, 512),
}


func _init() -> void:
	var arguments := _parse_arguments(OS.get_cmdline_user_args())
	var input_path := str(arguments.get("input", ""))
	var output_path := str(arguments.get("output", ""))
	if input_path.is_empty() or output_path.is_empty():
		printerr(
			"Usage: godot --headless --path . --script "
			+ "res://tools/build_plains_rock_wall_atlas.gd -- "
			+ "--input=<alpha-source> --output=<2048-atlas>"
		)
		quit(2)
		return

	var source := Image.load_from_file(ProjectSettings.globalize_path(input_path))
	if source.is_empty():
		printerr("Unable to load Plains wall source: %s" % input_path)
		quit(3)
		return
	source.convert(Image.FORMAT_RGBA8)
	if source.get_size() != EXPECTED_SOURCE_SIZE:
		printerr(
			"Approved wall source must be %s, got %s"
			% [EXPECTED_SOURCE_SIZE, source.get_size()]
		)
		quit(4)
		return
	if not _has_transparent_border(source):
		printerr("Approved wall source must have a transparent outer border")
		quit(5)
		return

	var modules := _build_modules(source)
	var validation_error := _validate_modules(modules)
	if not validation_error.is_empty():
		printerr(validation_error)
		quit(6)
		return

	var atlas := Image.create(
		MODULE_SIZE.x * ATLAS_GRID.x,
		MODULE_SIZE.y * ATLAS_GRID.y,
		false,
		Image.FORMAT_RGBA8
	)
	atlas.fill(Color.TRANSPARENT)
	for index in range(ROLE_LAYOUT.size()):
		var role := ROLE_LAYOUT[index]
		var cell := Vector2i(index % ATLAS_GRID.x, index / ATLAS_GRID.x)
		atlas.blit_rect(
			modules[role] as Image,
			Rect2i(Vector2i.ZERO, MODULE_SIZE),
			cell * MODULE_SIZE
		)
	_clear_transparent_rgb(atlas)

	var absolute_output := ProjectSettings.globalize_path(output_path)
	var directory_error := DirAccess.make_dir_recursive_absolute(
		absolute_output.get_base_dir()
	)
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		printerr("Unable to create atlas directory: %s" % absolute_output.get_base_dir())
		quit(7)
		return
	var save_error := atlas.save_png(absolute_output)
	if save_error != OK:
		printerr("Unable to save Plains wall atlas: error %d" % save_error)
		quit(8)
		return

	print(
		"Built Plains wall atlas %s -> %s | modules=%d | size=%s"
		% [input_path, output_path, modules.size(), atlas.get_size()]
	)
	quit(0)


func _build_modules(source: Image) -> Dictionary:
	var modules: Dictionary = {}
	for role_value in SAMPLE_CENTERS:
		var role := StringName(role_value)
		modules[role] = _extract_module(
			source,
			SAMPLE_CENTERS[role] as Vector2i,
			SAMPLE_SIZE
		)

	# A vertex stamp spans one occupied tile and one outside tile. Keep the
	# lower base on the center boundary, move the authored crest one tile into
	# the occupied half, and reuse the source face in the freed internal band.
	# Geometry and collision remain unchanged; no alpha is emitted outside the
	# occupied half of east/west edges.
	modules[&"edge_east"] = _remap_lateral_inset(
		modules[&"edge_east"] as Image, true, Rect2i(0, 0, 512, 512)
	)
	modules[&"edge_west"] = _remap_lateral_inset(
		modules[&"edge_west"] as Image, false, Rect2i(0, 0, 512, 512)
	)
	for role in [&"convex_south_west", &"convex_north_west"]:
		modules[role] = _remap_lateral_inset(
			modules[role] as Image, true, Rect2i(0, 0, 512, 512)
		)
	for role in [&"convex_north_east", &"convex_south_east"]:
		modules[role] = _remap_lateral_inset(
			modules[role] as Image, false, Rect2i(0, 0, 512, 512)
		)
	modules[&"concave_north_east"] = _remap_lateral_inset(
		modules[&"concave_north_east"] as Image,
		true,
		Rect2i(0, 0, 512, 256)
	)
	modules[&"concave_south_east"] = _remap_lateral_inset(
		modules[&"concave_south_east"] as Image,
		true,
		Rect2i(0, 256, 512, 256)
	)
	modules[&"concave_south_west"] = _remap_lateral_inset(
		modules[&"concave_south_west"] as Image,
		false,
		Rect2i(0, 256, 512, 256)
	)
	modules[&"concave_north_west"] = _remap_lateral_inset(
		modules[&"concave_north_west"] as Image,
		false,
		Rect2i(0, 0, 512, 256)
	)

	_harmonize_axis_edges(modules[&"edge_north"] as Image, true)
	_harmonize_axis_edges(modules[&"edge_south"] as Image, true)
	_harmonize_axis_edges(modules[&"edge_east"] as Image, false)
	_harmonize_axis_edges(modules[&"edge_west"] as Image, false)

	modules[&"diagonal_north_east_south_west"] = _compose_modules(
		modules[&"convex_north_east"] as Image,
		modules[&"convex_south_west"] as Image
	)
	modules[&"diagonal_north_west_south_east"] = _compose_modules(
		modules[&"convex_north_west"] as Image,
		modules[&"convex_south_east"] as Image
	)
	modules[&"cap_horizontal"] = _extract_module(
		source,
		Vector2i(1156, 628),
		Vector2i(512, 512)
	)
	modules[&"cap_vertical"] = _extract_module(
		source,
		Vector2i(628, 1172),
		Vector2i(512, 512)
	)
	return modules


func _remap_lateral_inset(
	source: Image,
	east_facing: bool,
	rows: Rect2i
) -> Image:
	var result := source.duplicate()
	result.fill_rect(rows, Color.TRANSPARENT)
	var row_height := rows.size.y
	if east_facing:
		var face := source.get_region(
			Rect2i(
				EAST_SOURCE_CREST_X,
				rows.position.y,
				256 - EAST_SOURCE_CREST_X,
				row_height
			)
		)
		face.resize(LATERAL_INSET_PIXELS, row_height, Image.INTERPOLATE_LANCZOS)
		var top_width := 256 - LATERAL_INSET_PIXELS
		if top_width > 0:
			var top := source.get_region(
				Rect2i(0, rows.position.y, EAST_SOURCE_CREST_X, row_height)
			)
			top.resize(top_width, row_height, Image.INTERPOLATE_LANCZOS)
			result.blit_rect(
				top,
				Rect2i(Vector2i.ZERO, top.get_size()),
				Vector2i(0, rows.position.y)
			)
		result.blit_rect(
			face,
			Rect2i(Vector2i.ZERO, face.get_size()),
			Vector2i(256 - LATERAL_INSET_PIXELS, rows.position.y)
		)
	else:
		var face := source.get_region(
			Rect2i(
				256,
				rows.position.y,
				WEST_SOURCE_CREST_X - 256,
				row_height
			)
		)
		face.resize(LATERAL_INSET_PIXELS, row_height, Image.INTERPOLATE_LANCZOS)
		result.blit_rect(
			face,
			Rect2i(Vector2i.ZERO, face.get_size()),
			Vector2i(256, rows.position.y)
		)
		var top_width := 256 - LATERAL_INSET_PIXELS
		if top_width > 0:
			var top := source.get_region(
				Rect2i(
					WEST_SOURCE_CREST_X,
					rows.position.y,
					512 - WEST_SOURCE_CREST_X,
					row_height
				)
			)
			top.resize(top_width, row_height, Image.INTERPOLATE_LANCZOS)
			result.blit_rect(
				top,
				Rect2i(Vector2i.ZERO, top.get_size()),
				Vector2i(256 + LATERAL_INSET_PIXELS, rows.position.y)
			)
	_clear_transparent_rgb(result)
	return result


func _extract_module(
	source: Image,
	center: Vector2i,
	sample_size: Vector2i
) -> Image:
	var sample := Image.create(
		sample_size.x,
		sample_size.y,
		false,
		Image.FORMAT_RGBA8
	)
	sample.fill(Color.TRANSPARENT)
	var requested := Rect2i(center - sample_size / 2, sample_size)
	var source_bounds := Rect2i(Vector2i.ZERO, source.get_size())
	var clipped := requested.intersection(source_bounds)
	if clipped.has_area():
		sample.blit_rect(
			source,
			clipped,
			clipped.position - requested.position
		)
	if sample.get_size() != MODULE_SIZE:
		sample.resize(MODULE_SIZE.x, MODULE_SIZE.y, Image.INTERPOLATE_LANCZOS)
	_clear_transparent_rgb(sample)
	return sample


func _compose_modules(first: Image, second: Image) -> Image:
	var result := first.duplicate()
	result.blend_rect(
		second,
		Rect2i(Vector2i.ZERO, MODULE_SIZE),
		Vector2i.ZERO
	)
	_clear_transparent_rgb(result)
	return result


func _harmonize_axis_edges(image: Image, longitudinal_x: bool) -> void:
	var line_length := image.get_height() if longitudinal_x else image.get_width()
	for cross in range(line_length):
		for offset in range(EDGE_BLEND_PIXELS):
			var weight := float(offset + 1) / float(EDGE_BLEND_PIXELS + 1)
			var first_position := (
				Vector2i(offset, cross)
				if longitudinal_x
				else Vector2i(cross, offset)
			)
			var second_position := (
				Vector2i(image.get_width() - 1 - offset, cross)
				if longitudinal_x
				else Vector2i(cross, image.get_height() - 1 - offset)
			)
			var first := image.get_pixelv(first_position)
			var second := image.get_pixelv(second_position)
			var seam := first.lerp(second, 0.5)
			image.set_pixelv(first_position, first.lerp(seam, 1.0 - weight))
			image.set_pixelv(second_position, second.lerp(seam, 1.0 - weight))
	_clear_transparent_rgb(image)


func _validate_modules(modules: Dictionary) -> String:
	if modules.size() != ROLE_LAYOUT.size():
		return "Expected %d modules, built %d" % [ROLE_LAYOUT.size(), modules.size()]
	var fingerprints: Dictionary = {}
	for role in ROLE_LAYOUT:
		if not modules.has(role):
			return "Missing wall role: %s" % String(role)
		var module := modules[role] as Image
		if module == null or module.get_size() != MODULE_SIZE:
			return "Wall role %s is not a 512x512 image" % String(role)
		var opaque_pixels := _count_opaque_pixels(module)
		if opaque_pixels < 2048:
			return "Wall role %s has insufficient authored coverage" % String(role)
		if EXPECTED_QUADRANT_MASKS.has(role):
			var actual_mask := _sample_quadrant_mask(module)
			var expected_mask := int(EXPECTED_QUADRANT_MASKS[role])
			if actual_mask != expected_mask:
				return "Wall role %s has quadrant mask %d, expected %d" % [
					String(role),
					actual_mask,
					expected_mask,
				]
		if LATERAL_FORBIDDEN_RECTS.has(role):
			var forbidden_coverage := _rect_alpha_coverage(
				module,
				LATERAL_FORBIDDEN_RECTS[role] as Rect2i
			)
			if forbidden_coverage > 0.001:
				return "Wall role %s leaks alpha outside its footprint: %.4f" % [
					String(role),
					forbidden_coverage,
				]
		if LATERAL_INSET_BAND_RECTS.has(role):
			var inset_coverage := _rect_alpha_coverage(
				module,
				LATERAL_INSET_BAND_RECTS[role] as Rect2i
			)
			if inset_coverage < 0.55:
				return "Wall role %s has no readable internal cliff band: %.4f" % [
					String(role),
					inset_coverage,
				]
		var fingerprint := _fingerprint(module)
		if fingerprints.has(fingerprint):
			return "Wall roles %s and %s are pixel-identical" % [
				String(fingerprints[fingerprint]),
				String(role),
			]
		fingerprints[fingerprint] = role
	return ""


func _rect_alpha_coverage(image: Image, rect: Rect2i) -> float:
	var occupied := 0
	var samples := 0
	for y in range(rect.position.y, rect.end.y, 8):
		for x in range(rect.position.x, rect.end.x, 8):
			samples += 1
			if image.get_pixel(x, y).a > 0.10:
				occupied += 1
	return float(occupied) / float(maxi(samples, 1))
func _count_opaque_pixels(image: Image) -> int:
	var count := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.10:
				count += 1
	return count


func _sample_quadrant_mask(image: Image) -> int:
	var mask := 0
	var quadrant_size := MODULE_SIZE / 2
	var quadrant_bits: Array[int] = [1, 2, 8, 4]
	for quadrant in range(4):
		var origin := Vector2i(
			quadrant_size.x if quadrant % 2 == 1 else 0,
			quadrant_size.y if quadrant >= 2 else 0
		)
		var occupied := 0
		var samples := 0
		for y in range(origin.y, origin.y + quadrant_size.y, 8):
			for x in range(origin.x, origin.x + quadrant_size.x, 8):
				samples += 1
				if image.get_pixel(x, y).a > 0.10:
					occupied += 1
		if float(occupied) / float(maxi(samples, 1)) >= 0.25:
			mask |= quadrant_bits[quadrant]
	return mask


func _fingerprint(image: Image) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(image.get_data())
	return context.finish().hex_encode()


func _has_transparent_border(image: Image) -> bool:
	for x in range(image.get_width()):
		if image.get_pixel(x, 0).a > 0.01:
			return false
		if image.get_pixel(x, image.get_height() - 1).a > 0.01:
			return false
	for y in range(image.get_height()):
		if image.get_pixel(0, y).a > 0.01:
			return false
		if image.get_pixel(image.get_width() - 1, y).a > 0.01:
			return false
	return true


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
