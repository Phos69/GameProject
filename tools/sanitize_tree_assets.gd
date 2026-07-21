extends SceneTree
## Ripulisce alpha e matte degli alberi raster senza ridisegnare gli asset.
##
## Check non distruttivo:
##   godot --headless --path . --script res://tools/sanitize_tree_assets.gd
## Pulizia dei PNG runtime (i source sheet restano invariati):
##   godot --headless --path . --script res://tools/sanitize_tree_assets.gd -- --write

const TREE_ROOT := "res://assets/environment/top_down/objects/trees"
const TREE_RUNTIME_SIZE := Vector2i(298, 298)
const FROZEN_MIN_CHANNEL := 0.94
const FROZEN_MAX_CHANNEL_SPREAD := 0.035
const FROZEN_MIN_SOURCE_COMPONENT_AREA := 12
const FROZEN_MIN_RUNTIME_COMPONENT_AREA := 4
const BURNING_VISIBLE_NEUTRAL_LIMIT := 0.30
const BURNING_MAX_CHANNEL_SPREAD := 0.18
const BURNING_DARKEN_TARGET := 0.28
const BURNING_MIN_SOURCE_COMPONENT_AREA := 12
const BURNING_MIN_RUNTIME_COMPONENT_AREA := 4
const NEIGHBOR_OFFSETS: Array[Vector2i] = [
	Vector2i.LEFT,
	Vector2i.RIGHT,
	Vector2i.UP,
	Vector2i.DOWN,
	Vector2i(-1, -1),
	Vector2i(1, -1),
	Vector2i(-1, 1),
	Vector2i(1, 1),
]


func _init() -> void:
	var write_changes := OS.get_cmdline_user_args().has("--write")
	var dirty_paths := PackedStringArray()
	var failed_paths := PackedStringArray()
	for path in _tree_png_paths():
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		if image.is_empty():
			printerr("TREE_SANITIZE load_failed path=%s" % path)
			dirty_paths.append(path)
			failed_paths.append(path)
			continue
		image.convert(Image.FORMAT_RGBA8)
		var frozen := "/frozen_tundra/" in path
		var burning := "/burning_plains/" in path
		if _is_clean(image, frozen, burning):
			continue
		dirty_paths.append(path)
		var removed_pixels := 0
		if write_changes:
			if frozen:
				removed_pixels += _remove_bright_neutral_pixels(image)
				removed_pixels += _remove_small_source_components(
					image,
					FROZEN_MIN_SOURCE_COMPONENT_AREA
				)
				removed_pixels += _remove_small_runtime_components(
					image,
					FROZEN_MIN_RUNTIME_COMPONENT_AREA
				)
				removed_pixels += _remove_small_source_components(
					image,
					FROZEN_MIN_SOURCE_COMPONENT_AREA
				)
			elif burning:
				_darken_burning_neutral_pixels(image)
				removed_pixels += _remove_small_source_components(
					image,
					BURNING_MIN_SOURCE_COMPONENT_AREA
				)
				removed_pixels += _remove_small_runtime_components(
					image,
					BURNING_MIN_RUNTIME_COMPONENT_AREA
				)
				removed_pixels += _remove_small_source_components(
					image,
					BURNING_MIN_SOURCE_COMPONENT_AREA
				)
			else:
				removed_pixels += _keep_only_largest_source_component(image)
				removed_pixels += _remove_all_detached_runtime_components(image)
			image.fix_alpha_edges()
			var save_error := image.save_png(ProjectSettings.globalize_path(path))
			if save_error != OK or not _is_clean(image, frozen, burning):
				failed_paths.append(path)
		print("TREE_SANITIZE path=%s frozen=%s removed_pixels=%d" % [
			path,
			str(frozen),
			removed_pixels,
		])
	if not failed_paths.is_empty():
		printerr("TREE_SANITIZE: FAIL (%d files could not be sanitized)" % failed_paths.size())
		quit(1)
		return
	if dirty_paths.is_empty():
		print("TREE_SANITIZE: PASS")
		quit(0)
		return
	if write_changes:
		print("TREE_SANITIZE: CLEANED (%d files)" % dirty_paths.size())
		quit(0)
		return
	printerr("TREE_SANITIZE: FAIL (%d files require --write)" % dirty_paths.size())
	quit(1)


func _is_clean(image: Image, frozen: bool, burning: bool) -> bool:
	var source_components := _component_pixel_indices(image)
	var runtime_components := _runtime_components(image)
	if burning:
		return (
			_count_burning_neutral_pixels(image) == 0
			and not _has_small_detached_component(
				source_components,
				BURNING_MIN_SOURCE_COMPONENT_AREA
			)
			and not _has_small_detached_component(
				runtime_components,
				BURNING_MIN_RUNTIME_COMPONENT_AREA
			)
		)
	if not frozen:
		return source_components.size() <= 1 and runtime_components.size() <= 1
	return (
		_count_bright_neutral_pixels(image) == 0
		and not _has_small_detached_component(
			source_components,
			FROZEN_MIN_SOURCE_COMPONENT_AREA
		)
		and not _has_small_detached_component(
			runtime_components,
			FROZEN_MIN_RUNTIME_COMPONENT_AREA
		)
	)


func _tree_png_paths() -> Array[String]:
	var result: Array[String] = []
	var pending: Array[String] = [TREE_ROOT]
	while not pending.is_empty():
		var directory_path: String = pending.pop_back()
		var directory := DirAccess.open(directory_path)
		if directory == null:
			continue
		directory.list_dir_begin()
		var entry := directory.get_next()
		while not entry.is_empty():
			if entry != "." and entry != "..":
				var entry_path: String = directory_path.path_join(entry)
				if directory.current_is_dir():
					pending.append(entry_path)
				elif entry.ends_with(".png"):
					result.append(entry_path)
			entry = directory.get_next()
		directory.list_dir_end()
	result.sort()
	return result


func _remove_bright_neutral_pixels(image: Image) -> int:
	var removed := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var pixel := image.get_pixel(x, y)
			if pixel.a <= 0.0:
				continue
			var maximum := maxf(pixel.r, maxf(pixel.g, pixel.b))
			var minimum := minf(pixel.r, minf(pixel.g, pixel.b))
			if (
				minimum < FROZEN_MIN_CHANNEL
				or maximum - minimum > FROZEN_MAX_CHANNEL_SPREAD
			):
				continue
			image.set_pixel(x, y, Color.TRANSPARENT)
			removed += 1
	return removed


func _count_bright_neutral_pixels(image: Image) -> int:
	var count := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var pixel := image.get_pixel(x, y)
			if pixel.a <= 0.0:
				continue
			var maximum := maxf(pixel.r, maxf(pixel.g, pixel.b))
			var minimum := minf(pixel.r, minf(pixel.g, pixel.b))
			if (
				minimum >= FROZEN_MIN_CHANNEL
				and maximum - minimum <= FROZEN_MAX_CHANNEL_SPREAD
			):
				count += 1
	return count


func _count_burning_neutral_pixels(image: Image) -> int:
	var count := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var pixel := image.get_pixel(x, y)
			if pixel.a <= 0.0:
				continue
			var maximum := maxf(pixel.r, maxf(pixel.g, pixel.b))
			var minimum := minf(pixel.r, minf(pixel.g, pixel.b))
			if (
				maximum - minimum <= BURNING_MAX_CHANNEL_SPREAD
				and maximum * pixel.a > BURNING_VISIBLE_NEUTRAL_LIMIT
			):
				count += 1
	return count


func _darken_burning_neutral_pixels(image: Image) -> int:
	var changed := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var pixel := image.get_pixel(x, y)
			if pixel.a <= 0.0:
				continue
			var maximum := maxf(pixel.r, maxf(pixel.g, pixel.b))
			var minimum := minf(pixel.r, minf(pixel.g, pixel.b))
			if (
				maximum <= 0.0
				or maximum - minimum > BURNING_MAX_CHANNEL_SPREAD
				or maximum * pixel.a <= BURNING_VISIBLE_NEUTRAL_LIMIT
			):
				continue
			var scale := BURNING_DARKEN_TARGET / (maximum * pixel.a)
			image.set_pixel(
				x,
				y,
				Color(pixel.r * scale, pixel.g * scale, pixel.b * scale, pixel.a)
			)
			changed += 1
	return changed


func _component_pixel_indices(image: Image) -> Array[PackedInt32Array]:
	var width := image.get_width()
	var height := image.get_height()
	var visited := PackedByteArray()
	visited.resize(width * height)
	var result: Array[PackedInt32Array] = []
	for y in range(height):
		for x in range(width):
			var index := y * width + x
			if visited[index] != 0 or image.get_pixel(x, y).a <= 0.0:
				continue
			var component := PackedInt32Array()
			var open := PackedInt32Array([index])
			visited[index] = 1
			while not open.is_empty():
				var current: int = open[open.size() - 1]
				open.resize(open.size() - 1)
				component.append(current)
				var current_x := current % width
				var current_y := int(current / width)
				for offset in NEIGHBOR_OFFSETS:
					var neighbor_x := current_x + offset.x
					var neighbor_y := current_y + offset.y
					if (
						neighbor_x < 0
						or neighbor_x >= width
						or neighbor_y < 0
						or neighbor_y >= height
					):
						continue
					var neighbor := neighbor_y * width + neighbor_x
					if visited[neighbor] != 0 or image.get_pixel(neighbor_x, neighbor_y).a <= 0.0:
						continue
					visited[neighbor] = 1
					open.append(neighbor)
			result.append(component)
	return result


func _runtime_components(image: Image) -> Array[PackedInt32Array]:
	var runtime_image := image.duplicate()
	runtime_image.resize(
		TREE_RUNTIME_SIZE.x,
		TREE_RUNTIME_SIZE.y,
		Image.INTERPOLATE_NEAREST
	)
	return _component_pixel_indices(runtime_image)


func _remove_small_source_components(image: Image, minimum_area: int) -> int:
	var components := _component_pixel_indices(image)
	_sort_components_by_size(components)
	return _erase_components_below_area(
		image,
		components,
		minimum_area
	)


func _remove_small_runtime_components(image: Image, minimum_area: int) -> int:
	var total_removed := 0
	for _iteration in range(4):
		var runtime_image := image.duplicate()
		runtime_image.resize(
			TREE_RUNTIME_SIZE.x,
			TREE_RUNTIME_SIZE.y,
			Image.INTERPOLATE_NEAREST
		)
		var components := _component_pixel_indices(runtime_image)
		_sort_components_by_size(components)
		var removal_mask := _component_removal_mask(
			components,
			TREE_RUNTIME_SIZE,
			minimum_area,
			false
		)
		if removal_mask == null:
			break
		removal_mask.resize(
			image.get_width(),
			image.get_height(),
			Image.INTERPOLATE_NEAREST
		)
		total_removed += _erase_masked_pixels(image, removal_mask)
	return total_removed


func _keep_only_largest_source_component(image: Image) -> int:
	var components := _component_pixel_indices(image)
	_sort_components_by_size(components)
	return _erase_components_below_area(image, components, 2147483647)


func _remove_all_detached_runtime_components(image: Image) -> int:
	var total_removed := 0
	for _iteration in range(4):
		var runtime_image := image.duplicate()
		runtime_image.resize(
			TREE_RUNTIME_SIZE.x,
			TREE_RUNTIME_SIZE.y,
			Image.INTERPOLATE_NEAREST
		)
		var components := _component_pixel_indices(runtime_image)
		_sort_components_by_size(components)
		var removal_mask := _component_removal_mask(
			components,
			TREE_RUNTIME_SIZE,
			2147483647,
			false
		)
		if removal_mask == null:
			break
		removal_mask.resize(
			image.get_width(),
			image.get_height(),
			Image.INTERPOLATE_NEAREST
		)
		total_removed += _erase_masked_pixels(image, removal_mask)
		var source_components := _component_pixel_indices(image)
		_sort_components_by_size(source_components)
		total_removed += _erase_components_below_area(
			image,
			source_components,
			2147483647
		)
	return total_removed


func _component_removal_mask(
	components: Array[PackedInt32Array],
	size: Vector2i,
	area_threshold: int,
	include_largest: bool
) -> Image:
	if components.size() <= 1 and not include_largest:
		return null
	var mask := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	mask.fill(Color.TRANSPARENT)
	var marked := false
	var first_index := 0 if include_largest else 1
	for component_index in range(first_index, components.size()):
		var component := components[component_index]
		if component.size() >= area_threshold:
			continue
		for pixel_index in component:
			mask.set_pixel(
				pixel_index % size.x,
				int(pixel_index / size.x),
				Color.WHITE
			)
		marked = true
	return mask if marked else null


func _erase_components_below_area(
	image: Image,
	components: Array[PackedInt32Array],
	area_threshold: int
) -> int:
	var removed := 0
	var width := image.get_width()
	for component_index in range(1, components.size()):
		var component := components[component_index]
		if component.size() >= area_threshold:
			continue
		for pixel_index in component:
			image.set_pixel(
				pixel_index % width,
				int(pixel_index / width),
				Color.TRANSPARENT
			)
			removed += 1
	return removed


func _erase_masked_pixels(image: Image, mask: Image) -> int:
	var removed := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a <= 0.0 or mask.get_pixel(x, y).a <= 0.0:
				continue
			image.set_pixel(x, y, Color.TRANSPARENT)
			removed += 1
	return removed


func _has_small_detached_component(
	components: Array[PackedInt32Array],
	area_threshold: int
) -> bool:
	if components.size() <= 1:
		return false
	_sort_components_by_size(components)
	for component_index in range(1, components.size()):
		if components[component_index].size() < area_threshold:
			return true
	return false


func _sort_components_by_size(components: Array[PackedInt32Array]) -> void:
	components.sort_custom(
		func(left: PackedInt32Array, right: PackedInt32Array) -> bool:
			return left.size() > right.size()
	)
