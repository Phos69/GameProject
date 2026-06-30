extends SceneTree

const ASSET_ROOT := "res://assets/environment/isometric/generated_images"
const EXPECTED_PNG_COUNT := 191
const MATTE_MIN_CHANNEL := 220
const MATTE_MAX_CHROMA := 20
const CUTOUT_MATTE_MIN_CHANNEL := 228
const CUTOUT_MATTE_MAX_CHROMA := 14
const MIN_INTERNAL_GUTTER := 2

var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var write := args.has("--write")
	var check := args.has("--check")
	if not write and not check:
		print("Usage: --write or --check")
		quit(2)
		return
	var files := _collect_png_files(ASSET_ROOT)
	if files.size() != EXPECTED_PNG_COUNT:
		_fail("expected %d PNG files, found %d" % [EXPECTED_PNG_COUNT, files.size()])
	var changed := 0
	for asset_path in files:
		var image := Image.new()
		var error := image.load(ProjectSettings.globalize_path(asset_path))
		if error != OK:
			_fail("cannot load %s (error %d)" % [asset_path, error])
			continue
		image.convert(Image.FORMAT_RGBA8)
		if write:
			var prepared := _prepare_image(image, asset_path)
			if prepared == null:
				continue
			if not _images_equal(image, prepared):
				error = prepared.save_png(ProjectSettings.globalize_path(asset_path))
				if error != OK:
					_fail("cannot save %s (error %d)" % [asset_path, error])
					continue
				changed += 1
				image = prepared
		elif check:
			var prepared := _prepare_image(image, asset_path)
			if prepared == null:
				continue
			if not _images_equal(image, prepared):
				_fail("asset is not normalized: %s" % asset_path)
		_validate_image(image, asset_path)
	print(
		"GENERATED_BIOME_ASSET_PREP: files=%d changed=%d mode=%s"
		% [files.size(), changed, "write" if write else "check"]
	)
	_finish()

func _collect_png_files(root_path: String) -> PackedStringArray:
	var result := PackedStringArray()
	_collect_png_files_recursive(root_path, result)
	result.sort()
	return result

func _collect_png_files_recursive(
	root_path: String,
	result: PackedStringArray
) -> void:
	var directory := DirAccess.open(root_path)
	if directory == null:
		_fail("asset directory missing: %s" % root_path)
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if entry.begins_with("."):
			entry = directory.get_next()
			continue
		var entry_path := root_path.path_join(entry)
		if directory.current_is_dir():
			_collect_png_files_recursive(entry_path, result)
		elif entry.to_lower().ends_with(".png"):
			result.append(entry_path)
		entry = directory.get_next()
	directory.list_dir_end()

func _prepare_image(source: Image, asset_path: String) -> Image:
	var bounds := _content_bounds(source)
	if bounds.size.x <= 0 or bounds.size.y <= 0:
		_fail("no non-matte content found in %s" % asset_path)
		return null
	var cropped := source.get_region(bounds)
	var compacted := _compact_internal_gutters(cropped)
	if _is_cliff_cutout(asset_path):
		_clear_cliff_matte(compacted)
	elif not asset_path.contains("/cliff/"):
		_extend_terrain_edges(compacted)
	return compacted

func _content_bounds(image: Image) -> Rect2i:
	var min_x := image.get_width()
	var min_y := image.get_height()
	var max_x := -1
	var max_y := -1
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if _is_matte(image.get_pixel(x, y)):
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
	if max_x < min_x or max_y < min_y:
		return Rect2i()
	return Rect2i(
		Vector2i(min_x, min_y),
		Vector2i(max_x - min_x + 1, max_y - min_y + 1)
	)

func _compact_internal_gutters(image: Image) -> Image:
	var keep_x := _retained_axes(image, true)
	var keep_y := _retained_axes(image, false)
	if keep_x.size() == image.get_width() and keep_y.size() == image.get_height():
		return image
	var compacted := Image.create(
		keep_x.size(),
		keep_y.size(),
		false,
		Image.FORMAT_RGBA8
	)
	for target_y in range(keep_y.size()):
		for target_x in range(keep_x.size()):
			compacted.set_pixel(
				target_x,
				target_y,
				image.get_pixel(keep_x[target_x], keep_y[target_y])
			)
	return compacted

func _retained_axes(image: Image, vertical: bool) -> PackedInt32Array:
	var length := image.get_width() if vertical else image.get_height()
	var matte_axes := PackedByteArray()
	matte_axes.resize(length)
	for axis in range(length):
		var all_matte := true
		var cross_length := image.get_height() if vertical else image.get_width()
		for cross in range(cross_length):
			var x := axis if vertical else cross
			var y := cross if vertical else axis
			if not _is_matte(image.get_pixel(x, y)):
				all_matte = false
				break
		matte_axes[axis] = 1 if all_matte else 0
	var remove := PackedByteArray()
	remove.resize(length)
	var run_start := -1
	for axis in range(length + 1):
		var is_matte_axis := axis < length and matte_axes[axis] != 0
		if is_matte_axis and run_start < 0:
			run_start = axis
		elif not is_matte_axis and run_start >= 0:
			var run_length := axis - run_start
			if (
				run_length >= MIN_INTERNAL_GUTTER
				and run_start > 0
				and axis < length
			):
				for remove_axis in range(run_start, axis):
					remove[remove_axis] = 1
			run_start = -1
	var result := PackedInt32Array()
	for axis in range(length):
		if remove[axis] == 0:
			result.append(axis)
	return result

func _clear_cliff_matte(image: Image) -> void:
	var original_alpha := PackedByteArray()
	original_alpha.resize(image.get_width() * image.get_height())
	var visited := PackedByteArray()
	visited.resize(image.get_width() * image.get_height())
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a <= 0.01:
				original_alpha[y * image.get_width() + x] = 1
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var index := y * image.get_width() + x
			if visited[index] != 0:
				continue
			var color := image.get_pixel(x, y)
			if color.a <= 0.01 or not _is_cutout_matte(color):
				visited[index] = 1
				continue
			_clear_connected_cutout_matte(
				image,
				original_alpha,
				visited,
				Vector2i(x, y)
			)

func _clear_connected_cutout_matte(
	image: Image,
	original_alpha: PackedByteArray,
	visited: PackedByteArray,
	start: Vector2i
) -> void:
	var width := image.get_width()
	var height := image.get_height()
	var pending: Array[Vector2i] = [start]
	var pending_index := 0
	var component := PackedInt32Array()
	var touches_background := false
	while pending_index < pending.size():
		var position := pending[pending_index]
		pending_index += 1
		var index := position.y * width + position.x
		if visited[index] != 0:
			continue
		visited[index] = 1
		var color := image.get_pixelv(position)
		if color.a <= 0.01 or not _is_cutout_matte(color):
			continue
		component.append(index)
		if (
			position.x == 0
			or position.y == 0
			or position.x == width - 1
			or position.y == height - 1
		):
			touches_background = true
		for offset_value in [
			Vector2i.LEFT,
			Vector2i.RIGHT,
			Vector2i.UP,
			Vector2i.DOWN,
		]:
			var offset := offset_value as Vector2i
			var neighbor: Vector2i = position + offset
			if (
				neighbor.x < 0
				or neighbor.y < 0
				or neighbor.x >= width
				or neighbor.y >= height
			):
				continue
			var neighbor_index: int = neighbor.y * width + neighbor.x
			if original_alpha[neighbor_index] != 0:
				touches_background = true
			elif visited[neighbor_index] == 0:
				pending.append(neighbor)
	if not touches_background:
		return
	for index in component:
		var position := Vector2i(index % width, floori(float(index) / width))
		var color := image.get_pixelv(position)
		color.a = 0.0
		image.set_pixelv(position, color)

func _extend_terrain_edges(image: Image) -> void:
	for y in range(image.get_height()):
		var first_content := -1
		var last_content := -1
		for x in range(image.get_width()):
			if not _is_matte(image.get_pixel(x, y)):
				first_content = x
				break
		for x in range(image.get_width() - 1, -1, -1):
			if not _is_matte(image.get_pixel(x, y)):
				last_content = x
				break
		if first_content >= 0:
			var left_color := image.get_pixel(first_content, y)
			for x in range(first_content):
				image.set_pixel(x, y, left_color)
		if last_content >= 0:
			var right_color := image.get_pixel(last_content, y)
			for x in range(last_content + 1, image.get_width()):
				image.set_pixel(x, y, right_color)
	for x in range(image.get_width()):
		var first_content := -1
		var last_content := -1
		for y in range(image.get_height()):
			if not _is_matte(image.get_pixel(x, y)):
				first_content = y
				break
		for y in range(image.get_height() - 1, -1, -1):
			if not _is_matte(image.get_pixel(x, y)):
				last_content = y
				break
		if first_content >= 0:
			var top_color := image.get_pixel(x, first_content)
			for y in range(first_content):
				image.set_pixel(x, y, top_color)
		if last_content >= 0:
			var bottom_color := image.get_pixel(x, last_content)
			for y in range(last_content + 1, image.get_height()):
				image.set_pixel(x, y, bottom_color)
	_fill_remaining_terrain_edge(image, &"top")
	_fill_remaining_terrain_edge(image, &"bottom")
	_fill_remaining_terrain_edge(image, &"left")
	_fill_remaining_terrain_edge(image, &"right")

func _fill_remaining_terrain_edge(
	image: Image,
	side: StringName
) -> void:
	var length := (
		image.get_width()
		if side == &"top" or side == &"bottom"
		else image.get_height()
	)
	for offset in range(length):
		var position := _edge_position(image, side, offset)
		if not _is_matte(image.get_pixelv(position)):
			continue
		var replacement := Color.TRANSPARENT
		var found := false
		var inward := _edge_inward_offset(side)
		var probe := position
		while (
			probe.x >= 0
			and probe.y >= 0
			and probe.x < image.get_width()
			and probe.y < image.get_height()
		):
			var color := image.get_pixelv(probe)
			if not _is_matte(color):
				replacement = color
				found = true
				break
			probe += inward
		if not found:
			for radius in range(1, length):
				for neighbor_offset in [offset - radius, offset + radius]:
					if neighbor_offset < 0 or neighbor_offset >= length:
						continue
					var neighbor := _edge_position(
						image,
						side,
						neighbor_offset
					)
					var color := image.get_pixelv(neighbor)
					if not _is_matte(color):
						replacement = color
						found = true
						break
				if found:
					break
		if found:
			image.set_pixelv(position, replacement)

func _edge_position(
	image: Image,
	side: StringName,
	offset: int
) -> Vector2i:
	match side:
		&"top":
			return Vector2i(offset, 0)
		&"bottom":
			return Vector2i(offset, image.get_height() - 1)
		&"left":
			return Vector2i(0, offset)
		_:
			return Vector2i(image.get_width() - 1, offset)

func _edge_inward_offset(side: StringName) -> Vector2i:
	match side:
		&"top":
			return Vector2i.DOWN
		&"bottom":
			return Vector2i.UP
		&"left":
			return Vector2i.RIGHT
		_:
			return Vector2i.LEFT

func _validate_image(image: Image, asset_path: String) -> void:
	if image.is_empty():
		_fail("empty image: %s" % asset_path)
		return
	for side in [&"top", &"bottom", &"left", &"right"]:
		if _edge_is_entirely_matte(image, side):
			_fail("%s retains an opaque matte edge on %s" % [asset_path, String(side)])
		if (
			not asset_path.contains("/cliff/")
			and _edge_contains_matte(image, side)
		):
			_fail("%s retains matte pixels on %s" % [asset_path, String(side)])
	if _is_cliff_cutout(asset_path):
		var has_transparency := false
		for y in range(image.get_height()):
			for x in range(image.get_width()):
				if image.get_pixel(x, y).a < 0.98:
					has_transparency = true
					break
			if has_transparency:
				break
		if not has_transparency:
			_fail("cliff cutout has no transparent matte: %s" % asset_path)

func _edge_is_entirely_matte(
	image: Image,
	side: StringName
) -> bool:
	var length := (
		image.get_width()
		if side == &"top" or side == &"bottom"
		else image.get_height()
	)
	for offset in range(length):
		var x := offset
		var y := 0 if side == &"top" else image.get_height() - 1
		if side == &"left" or side == &"right":
			x = 0 if side == &"left" else image.get_width() - 1
			y = offset
		var color := image.get_pixel(x, y)
		if color.a < 0.98 or not _is_matte(color):
			return false
	return true

func _edge_contains_matte(
	image: Image,
	side: StringName
) -> bool:
	var length := (
		image.get_width()
		if side == &"top" or side == &"bottom"
		else image.get_height()
	)
	for offset in range(length):
		var x := offset
		var y := 0 if side == &"top" else image.get_height() - 1
		if side == &"left" or side == &"right":
			x = 0 if side == &"left" else image.get_width() - 1
			y = offset
		if _is_matte(image.get_pixel(x, y)):
			return true
	return false

func _is_matte(color: Color) -> bool:
	if color.a <= 0.01:
		return true
	var minimum := minf(color.r, minf(color.g, color.b))
	var maximum := maxf(color.r, maxf(color.g, color.b))
	return (
		minimum * 255.0 >= float(MATTE_MIN_CHANNEL)
		and (maximum - minimum) * 255.0 <= float(MATTE_MAX_CHROMA)
	)

func _is_cutout_matte(color: Color) -> bool:
	var minimum := minf(color.r, minf(color.g, color.b))
	var maximum := maxf(color.r, maxf(color.g, color.b))
	return (
		minimum * 255.0 >= float(CUTOUT_MATTE_MIN_CHANNEL)
		and (maximum - minimum) * 255.0
		<= float(CUTOUT_MATTE_MAX_CHROMA)
	)

func _is_cliff_cutout(asset_path: String) -> bool:
	return (
		asset_path.contains("/cliff/")
		and not asset_path.contains("_01_cliff_face_")
		and not asset_path.contains("_02_cliff_face_")
	)

func _images_equal(left: Image, right: Image) -> bool:
	return (
		left.get_width() == right.get_width()
		and left.get_height() == right.get_height()
		and left.get_data() == right.get_data()
	)

func _fail(message: String) -> void:
	failures.append(message)
	push_error(message)

func _finish() -> void:
	if failures.is_empty():
		print("GENERATED_BIOME_ASSET_PREP: PASS")
		quit(0)
		return
	print("GENERATED_BIOME_ASSET_PREP: FAIL (%d)" % failures.size())
	quit(1)
