extends SceneTree

const GRID_SIZE := 4
const BORDER_SAMPLE_TARGET := 64
const TRANSPARENT_DISTANCE := 0.08
const OPAQUE_DISTANCE := 0.38
const EDGE_CONTRACT_PIXELS := 1
const CELL_PADDING := 18
const OCCUPIED_LINE_PIXELS := 8


func _init() -> void:
	var arguments := _parse_arguments(OS.get_cmdline_user_args())
	var input_path := str(arguments.get("input", ""))
	var output_path := str(arguments.get("output", ""))
	var preserve_alpha := str(arguments.get("preserve-alpha", "false")).to_lower() == "true"
	var skip_repack := str(arguments.get("skip-repack", "false")).to_lower() == "true"
	var fixed_grid := str(arguments.get("fixed-grid", "false")).to_lower() == "true"
	if input_path.is_empty() or output_path.is_empty():
		printerr(
			"Usage: godot --headless --path . --script "
			+ "res://tools/remove_sprite_chroma_key.gd -- "
			+ "--input=<path> --output=<path>"
		)
		quit(2)
		return

	var source_path := ProjectSettings.globalize_path(input_path)
	var target_path := ProjectSettings.globalize_path(output_path)
	var image := Image.load_from_file(source_path)
	if image.is_empty():
		printerr("Unable to load chroma source: %s" % input_path)
		quit(3)
		return

	image.convert(Image.FORMAT_RGBA8)
	var key_color := Color.TRANSPARENT
	if preserve_alpha:
		_clear_transparent_rgb(image)
	else:
		key_color = _sample_border_key(image)
		_remove_key(image, key_color)
		_contract_alpha(image, EDGE_CONTRACT_PIXELS)
	var padded: Image
	if skip_repack:
		padded = _pad_to_grid(image)
	elif fixed_grid:
		padded = _repack_fixed_grid(image)
	else:
		padded = _repack_grid(image)
	_clear_transparent_rgb(padded)
	var output_directory := target_path.get_base_dir()
	var directory_error := DirAccess.make_dir_recursive_absolute(output_directory)
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		printerr("Unable to create output directory: %s" % output_directory)
		quit(4)
		return
	var save_error := padded.save_png(target_path)
	if save_error != OK:
		printerr("Unable to save alpha atlas: %s (error %d)" % [output_path, save_error])
		quit(5)
		return

	print(
		"Prepared %s -> %s | mode=%s | key=%s | size=%dx%d"
		% [
			input_path,
			output_path,
			"preserve-alpha" if preserve_alpha else "chroma-key",
			key_color.to_html(false),
			padded.get_width(),
			padded.get_height()
		]
	)
	quit(0)


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


func _sample_border_key(image: Image) -> Color:
	var width := image.get_width()
	var height := image.get_height()
	var step_x := maxi(width / BORDER_SAMPLE_TARGET, 1)
	var step_y := maxi(height / BORDER_SAMPLE_TARGET, 1)
	var total := Vector3.ZERO
	var sample_count := 0
	for x in range(0, width, step_x):
		for y in [0, height - 1]:
			var pixel := image.get_pixel(x, y)
			total += Vector3(pixel.r, pixel.g, pixel.b)
			sample_count += 1
	for y in range(0, height, step_y):
		for x in [0, width - 1]:
			var pixel := image.get_pixel(x, y)
			total += Vector3(pixel.r, pixel.g, pixel.b)
			sample_count += 1
	var average := total / float(maxi(sample_count, 1))
	return Color(average.x, average.y, average.z, 1.0)


func _remove_key(image: Image, key_color: Color) -> void:
	var key := Vector3(key_color.r, key_color.g, key_color.b)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var pixel := image.get_pixel(x, y)
			var source := Vector3(pixel.r, pixel.g, pixel.b)
			var distance := source.distance_to(key) / sqrt(3.0)
			var alpha := smoothstep(
				TRANSPARENT_DISTANCE,
				OPAQUE_DISTANCE,
				distance
			)
			if alpha <= 0.001:
				image.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
				continue
			var reconstructed := source
			if alpha < 0.999:
				reconstructed = (source - key * (1.0 - alpha)) / alpha
				reconstructed = reconstructed.clamp(Vector3.ZERO, Vector3.ONE)
			var magenta_excess := minf(source.x, source.z) - source.y
			var magenta_like := (
				magenta_excess > 0.05
				and absf(source.x - source.z) < 0.22
				and source.x > source.y * 1.35
				and source.z > source.y * 1.35
			)
			if magenta_like:
				var despill_strength := clampf(
					(magenta_excess - 0.05) / 0.45,
					0.0,
					1.0
				)
				var neutral_edge := minf(
					maxf(reconstructed.y + 0.08, 0.06),
					maxf(reconstructed.x, reconstructed.z)
				)
				reconstructed.x = lerpf(reconstructed.x, neutral_edge, despill_strength)
				reconstructed.z = lerpf(reconstructed.z, neutral_edge, despill_strength)
				alpha *= 1.0 - despill_strength * 0.55
			image.set_pixel(
				x,
				y,
				Color(reconstructed.x, reconstructed.y, reconstructed.z, alpha)
			)


func _contract_alpha(image: Image, pixels: int) -> void:
	for _pass in range(maxi(pixels, 0)):
		var source := image.duplicate()
		for y in range(image.get_height()):
			for x in range(image.get_width()):
				var contracted_alpha: float = source.get_pixel(x, y).a
				for neighbor_y in range(maxi(y - 1, 0), mini(y + 2, image.get_height())):
					for neighbor_x in range(maxi(x - 1, 0), mini(x + 2, image.get_width())):
						contracted_alpha = minf(
							contracted_alpha,
							source.get_pixel(neighbor_x, neighbor_y).a
						)
				var pixel := image.get_pixel(x, y)
				pixel.a = contracted_alpha
				image.set_pixel(x, y, pixel)


func _pad_to_grid(source: Image) -> Image:
	var target_width := ceili(float(source.get_width()) / float(GRID_SIZE)) * GRID_SIZE
	var target_height := ceili(float(source.get_height()) / float(GRID_SIZE)) * GRID_SIZE
	if target_width == source.get_width() and target_height == source.get_height():
		return source
	var padded := Image.create(target_width, target_height, false, Image.FORMAT_RGBA8)
	padded.fill(Color(0.0, 0.0, 0.0, 0.0))
	var offset := Vector2i(
		(target_width - source.get_width()) / 2,
		(target_height - source.get_height()) / 2
	)
	padded.blit_rect(
		source,
		Rect2i(Vector2i.ZERO, source.get_size()),
		offset
	)
	return padded


func _repack_grid(source: Image) -> Image:
	var column_bands := _find_occupied_bands(source, true)
	var row_bands := _find_occupied_bands(source, false)
	if column_bands.size() != GRID_SIZE or row_bands.size() != GRID_SIZE:
		push_warning(
			(
				"Expected four occupied row/column bands, found %d columns and %d rows; "
				+ "falling back to transparent padding."
			)
			% [column_bands.size(), row_bands.size()]
		)
		return _pad_to_grid(source)

	var bounds: Array[Rect2i] = []
	for row in range(GRID_SIZE):
		for column in range(GRID_SIZE):
			var column_band: Vector2i = column_bands[column]
			var row_band: Vector2i = row_bands[row]
			var search_rect := Rect2i(
				column_band.x,
				row_band.x,
				column_band.y - column_band.x,
				row_band.y - row_band.x
			)
			var content_bounds := _find_content_bounds(source, search_rect)
			if content_bounds.size == Vector2i.ZERO:
				push_warning("Directional atlas cell %d,%d is empty." % [column, row])
				return _pad_to_grid(source)
			bounds.append(content_bounds)
	return _pack_bounds(source, bounds)


func _repack_fixed_grid(source: Image) -> Image:
	var padded_source := _pad_to_grid(source)
	var source_cell_size := padded_source.get_size() / GRID_SIZE
	var bounds: Array[Rect2i] = []
	for row in range(GRID_SIZE):
		for column in range(GRID_SIZE):
			var search_rect := Rect2i(
				Vector2i(column, row) * source_cell_size,
				source_cell_size
			)
			var content_bounds := _find_content_bounds(padded_source, search_rect)
			if content_bounds.size == Vector2i.ZERO:
				push_warning("Directional atlas cell %d,%d is empty." % [column, row])
				return padded_source
			bounds.append(content_bounds)
	return _pack_bounds(padded_source, bounds)


func _pack_bounds(source: Image, bounds: Array[Rect2i]) -> Image:
	var maximum_size := Vector2i.ZERO
	for content_bounds in bounds:
		maximum_size.x = maxi(maximum_size.x, content_bounds.size.x)
		maximum_size.y = maxi(maximum_size.y, content_bounds.size.y)

	var cell_size := ceili(
		float(maxi(source.get_width(), source.get_height())) / float(GRID_SIZE)
	)
	var target_extent := cell_size - CELL_PADDING * 2
	var uniform_scale := minf(
		float(target_extent) / float(maxi(maximum_size.x, 1)),
		float(target_extent) / float(maxi(maximum_size.y, 1))
	)
	var result := Image.create(
		cell_size * GRID_SIZE,
		cell_size * GRID_SIZE,
		false,
		Image.FORMAT_RGBA8
	)
	result.fill(Color(0.0, 0.0, 0.0, 0.0))
	for index in range(bounds.size()):
		var row := floori(float(index) / float(GRID_SIZE))
		var column := index % GRID_SIZE
		var frame := source.get_region(bounds[index])
		var scaled_size := Vector2i(
			maxi(roundi(float(frame.get_width()) * uniform_scale), 1),
			maxi(roundi(float(frame.get_height()) * uniform_scale), 1)
		)
		if scaled_size != frame.get_size():
			frame.resize(scaled_size.x, scaled_size.y, Image.INTERPOLATE_LANCZOS)
		var target_position := Vector2i(
			column * cell_size + floori(float(cell_size - scaled_size.x) / 2.0),
			row * cell_size + cell_size - CELL_PADDING - scaled_size.y
		)
		result.blit_rect(
			frame,
			Rect2i(Vector2i.ZERO, frame.get_size()),
			target_position
		)
	return result


func _find_occupied_bands(image: Image, vertical_lines: bool) -> Array[Vector2i]:
	var line_count := image.get_width() if vertical_lines else image.get_height()
	var cross_count := image.get_height() if vertical_lines else image.get_width()
	var bands: Array[Vector2i] = []
	var band_start := -1
	for line in range(line_count):
		var occupied_pixels := 0
		for cross in range(cross_count):
			var x := line if vertical_lines else cross
			var y := cross if vertical_lines else line
			if image.get_pixel(x, y).a > 0.02:
				occupied_pixels += 1
				if occupied_pixels >= OCCUPIED_LINE_PIXELS:
					break
		var occupied := occupied_pixels >= OCCUPIED_LINE_PIXELS
		if occupied and band_start < 0:
			band_start = line
		elif not occupied and band_start >= 0:
			bands.append(Vector2i(band_start, line))
			band_start = -1
	if band_start >= 0:
		bands.append(Vector2i(band_start, line_count))
	return bands


func _find_content_bounds(image: Image, search_rect: Rect2i) -> Rect2i:
	var minimum := search_rect.end
	var maximum := search_rect.position - Vector2i.ONE
	for y in range(search_rect.position.y, search_rect.end.y):
		for x in range(search_rect.position.x, search_rect.end.x):
			if image.get_pixel(x, y).a <= 0.02:
				continue
			minimum.x = mini(minimum.x, x)
			minimum.y = mini(minimum.y, y)
			maximum.x = maxi(maximum.x, x)
			maximum.y = maxi(maximum.y, y)
	if maximum.x < minimum.x or maximum.y < minimum.y:
		return Rect2i()
	return Rect2i(minimum, maximum - minimum + Vector2i.ONE)
