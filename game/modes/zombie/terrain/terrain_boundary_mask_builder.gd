extends RefCounted
class_name TerrainBoundaryMaskBuilder

const SURFACE_CLASSIFIER = preload(
	"res://game/modes/zombie/terrain/terrain_surface_classifier.gd"
)

## Otto texel per tile mantengono il raster regionale leggero (600x600 su una
## regione 75x75) ma lasciano abbastanza risoluzione per feather e giunzioni.
const MASK_PIXELS_PER_TILE: int = 8
const DIVIDER_HALF_WIDTH_TILES: float = 0.22
const DIVIDER_FEATHER_TILES: float = 0.10
const DIVIDER_WIDTH_VARIATION_TILES: float = 0.035


static func build(
	layout: BiomeEnvironmentLayout,
	resolver: BiomeTileResolver
) -> Dictionary:
	if layout == null or layout.zone_size.x <= 0 or layout.zone_size.y <= 0:
		return {}
	var surface_kinds := _build_surface_kinds(layout, resolver)
	var image_size := layout.zone_size * MASK_PIXELS_PER_TILE
	var boundary_segments := _build_boundary_segments(
		surface_kinds,
		layout.zone_size
	)
	var segment_buckets := _build_segment_buckets(
		boundary_segments,
		layout.zone_size
	)
	var byte_data := PackedByteArray()
	byte_data.resize(image_size.x * image_size.y * 4)
	var divider_pixel_count := 0
	var generation_seed := layout.generation_seed
	for pixel_y in range(image_size.y):
		var cell_y := pixel_y / MASK_PIXELS_PER_TILE
		for pixel_x in range(image_size.x):
			var cell_x := pixel_x / MASK_PIXELS_PER_TILE
			var cell := Vector2i(cell_x, cell_y)
			var surface_kind := _kind_at(surface_kinds, layout.zone_size, cell)
			var divider_alpha := _divider_alpha_at_pixel(
				boundary_segments,
				segment_buckets,
				layout.zone_size,
				cell,
				Vector2i(pixel_x, pixel_y),
				generation_seed
			)
			if divider_alpha > 0.0:
				divider_pixel_count += 1
			var byte_index := (pixel_y * image_size.x + pixel_x) * 4
			byte_data[byte_index] = 255 if surface_kind == SURFACE_CLASSIFIER.SURFACE_GRASS else 0
			byte_data[byte_index + 1] = 255 if surface_kind == SURFACE_CLASSIFIER.SURFACE_PATH else 0
			byte_data[byte_index + 2] = 255 if surface_kind == SURFACE_CLASSIFIER.SURFACE_ASPHALT else 0
			byte_data[byte_index + 3] = roundi(clampf(divider_alpha, 0.0, 1.0) * 255.0)
	var image := Image.create_from_data(
		image_size.x,
		image_size.y,
		false,
		Image.FORMAT_RGBA8,
		byte_data
	)
	return {
		"image": image,
		"image_size": image_size,
		"surface_kinds": surface_kinds,
		"divider_pixel_count": divider_pixel_count,
		"boundary_segment_count": _count_boundary_segments(
			surface_kinds,
			layout.zone_size
		),
		"pixels_per_tile": MASK_PIXELS_PER_TILE,
	}


static func surface_kind_at_cell(
	mask_data: Dictionary,
	zone_size: Vector2i,
	cell: Vector2i
) -> int:
	var surface_kinds := mask_data.get("surface_kinds", PackedByteArray()) as PackedByteArray
	return _kind_at(surface_kinds, zone_size, cell)


static func _build_surface_kinds(
	layout: BiomeEnvironmentLayout,
	resolver: BiomeTileResolver
) -> PackedByteArray:
	var result := PackedByteArray()
	result.resize(layout.zone_size.x * layout.zone_size.y)
	for y in range(layout.zone_size.y):
		for x in range(layout.zone_size.x):
			var cell := Vector2i(x, y)
			result[y * layout.zone_size.x + x] = SURFACE_CLASSIFIER.classify_cell(
				layout,
				resolver,
				cell
			)
	return result


static func _divider_alpha_at_pixel(
	boundary_segments: Array[Dictionary],
	segment_buckets: Dictionary,
	zone_size: Vector2i,
	cell: Vector2i,
	pixel: Vector2i,
	generation_seed: int
) -> float:
	var bucket_key := cell.y * zone_size.x + cell.x
	var segment_indices := (
		segment_buckets.get(bucket_key, PackedInt32Array()) as PackedInt32Array
	)
	if segment_indices.is_empty():
		return 0.0
	var sample_position := Vector2(pixel) + Vector2(0.5, 0.5)
	var result := 0.0
	for segment_index in segment_indices:
		var segment := boundary_segments[segment_index]
		var start := segment.get("start", Vector2.ZERO) as Vector2
		var end := segment.get("end", Vector2.ZERO) as Vector2
		var vertical := bool(segment.get("vertical", false))
		var closest := _closest_point_on_segment(sample_position, start, end)
		var long_axis_pixel := roundi(closest.y if vertical else closest.x)
		result = maxf(
			result,
			_edge_alpha(
				sample_position.distance_to(closest),
				vertical,
				int(segment.get("edge_coordinate", 0)),
				long_axis_pixel,
				generation_seed
			)
		)
	return result


static func _build_boundary_segments(
	surface_kinds: PackedByteArray,
	zone_size: Vector2i
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var pixels_per_tile := float(MASK_PIXELS_PER_TILE)
	for y in range(zone_size.y):
		for x in range(zone_size.x):
			var cell := Vector2i(x, y)
			var surface_kind := _kind_at(surface_kinds, zone_size, cell)
			if (
				x + 1 < zone_size.x
				and _kind_at(surface_kinds, zone_size, cell + Vector2i.RIGHT)
				!= surface_kind
			):
				result.append({
					"vertical": true,
					"edge_coordinate": x + 1,
					"axis_cell": y,
					"start": Vector2((x + 1) * pixels_per_tile, y * pixels_per_tile),
					"end": Vector2((x + 1) * pixels_per_tile, (y + 1) * pixels_per_tile),
				})
			if (
				y + 1 < zone_size.y
				and _kind_at(surface_kinds, zone_size, cell + Vector2i.DOWN)
				!= surface_kind
			):
				result.append({
					"vertical": false,
					"edge_coordinate": y + 1,
					"axis_cell": x,
					"start": Vector2(x * pixels_per_tile, (y + 1) * pixels_per_tile),
					"end": Vector2((x + 1) * pixels_per_tile, (y + 1) * pixels_per_tile),
				})
	return result


static func _build_segment_buckets(
	segments: Array[Dictionary],
	zone_size: Vector2i
) -> Dictionary:
	var result := {}
	for segment_index in range(segments.size()):
		var segment := segments[segment_index]
		var vertical := bool(segment.get("vertical", false))
		var edge_coordinate := int(segment.get("edge_coordinate", 0))
		var axis_cell := int(segment.get("axis_cell", 0))
		var min_x := edge_coordinate - 1 if vertical else axis_cell - 1
		var max_x := edge_coordinate if vertical else axis_cell + 1
		var min_y := axis_cell - 1 if vertical else edge_coordinate - 1
		var max_y := axis_cell + 1 if vertical else edge_coordinate
		for y in range(maxi(min_y, 0), mini(max_y, zone_size.y - 1) + 1):
			for x in range(maxi(min_x, 0), mini(max_x, zone_size.x - 1) + 1):
				var key := y * zone_size.x + x
				var indices := (
					result.get(key, PackedInt32Array()) as PackedInt32Array
				)
				indices.append(segment_index)
				result[key] = indices
	return result


static func _closest_point_on_segment(
	point: Vector2,
	start: Vector2,
	end: Vector2
) -> Vector2:
	var delta := end - start
	var length_squared := delta.length_squared()
	if length_squared <= 0.0001:
		return start
	var amount := clampf((point - start).dot(delta) / length_squared, 0.0, 1.0)
	return start + delta * amount


static func _edge_alpha(
	distance_pixels: float,
	vertical_edge: bool,
	edge_coordinate: int,
	long_axis_pixel: int,
	generation_seed: int
) -> float:
	var pixels_per_tile := float(MASK_PIXELS_PER_TILE)
	var variation := (
		_stable_edge_noise(
			vertical_edge,
			edge_coordinate,
			long_axis_pixel / 2,
			generation_seed
		) * 2.0 - 1.0
	) * DIVIDER_WIDTH_VARIATION_TILES * pixels_per_tile
	var half_width := DIVIDER_HALF_WIDTH_TILES * pixels_per_tile + variation
	var feather := maxf(DIVIDER_FEATHER_TILES * pixels_per_tile, 0.001)
	var alpha := 1.0 - smoothstep(half_width - feather, half_width + feather, distance_pixels)
	return clampf(alpha, 0.0, 1.0)


static func _stable_edge_noise(
	vertical_edge: bool,
	edge_coordinate: int,
	long_axis_sample: int,
	generation_seed: int
) -> float:
	var key := "%d|%d|%d|%d" % [
		generation_seed,
		int(vertical_edge),
		edge_coordinate,
		long_axis_sample,
	]
	return float(posmod(key.hash(), 1009)) / 1008.0


static func _count_boundary_segments(
	surface_kinds: PackedByteArray,
	zone_size: Vector2i
) -> int:
	var count := 0
	for y in range(zone_size.y):
		for x in range(zone_size.x):
			var cell := Vector2i(x, y)
			var surface_kind := _kind_at(surface_kinds, zone_size, cell)
			if (
				x + 1 < zone_size.x
				and _kind_at(surface_kinds, zone_size, cell + Vector2i.RIGHT) != surface_kind
			):
				count += 1
			if (
				y + 1 < zone_size.y
				and _kind_at(surface_kinds, zone_size, cell + Vector2i.DOWN) != surface_kind
			):
				count += 1
	return count


static func _kind_at(
	surface_kinds: PackedByteArray,
	zone_size: Vector2i,
	cell: Vector2i
) -> int:
	if (
		cell.x < 0
		or cell.y < 0
		or cell.x >= zone_size.x
		or cell.y >= zone_size.y
	):
		return SURFACE_CLASSIFIER.SURFACE_VOID
	var index := cell.y * zone_size.x + cell.x
	if index < 0 or index >= surface_kinds.size():
		return SURFACE_CLASSIFIER.SURFACE_VOID
	return int(surface_kinds[index])
