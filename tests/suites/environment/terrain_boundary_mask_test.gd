extends GutTest

## Unit test CPU-only per la classificazione delle superfici e il raster RGBA
## usato dal renderer del terreno. Non crea CanvasItem, texture GPU o scene.

const SURFACE_CLASSIFIER = preload(
	"res://game/modes/zombie/terrain/terrain_surface_classifier.gd"
)
const BOUNDARY_MASK_BUILDER = preload(
	"res://game/modes/zombie/terrain/terrain_boundary_mask_builder.gd"
)

var _resolver: BiomeTileResolver


func before_all() -> void:
	_resolver = BiomeTileResolver.new(EnvironmentAssetManifest.get_shared())


func after_all() -> void:
	_resolver = null


func test_uniform_surface_has_empty_divider_alpha() -> void:
	var layout := _new_floor_layout(Vector2i(4, 3), 41001)
	layout.rebuild_terrain_classification()

	var mask_data := BOUNDARY_MASK_BUILDER.build(layout, _resolver)
	var image := mask_data.get("image") as Image

	assert_not_null(image, "uniform terrain builds a CPU image")
	assert_eq(
		int(mask_data.get("boundary_segment_count", -1)),
		0,
		"uniform terrain has no internal boundary segments"
	)
	assert_eq(
		int(mask_data.get("divider_pixel_count", -1)),
		0,
		"uniform terrain has no divider pixels"
	)
	assert_true(
		_all_alpha_is_zero(image),
		"uniform terrain leaves the complete divider alpha channel empty"
	)
	for y in range(layout.zone_size.y):
		for x in range(layout.zone_size.x):
			assert_eq(
				BOUNDARY_MASK_BUILDER.surface_kind_at_cell(
					mask_data,
					layout.zone_size,
					Vector2i(x, y)
				),
				SURFACE_CLASSIFIER.SURFACE_GRASS,
				"every uniform floor cell remains grass"
			)


func test_grass_asphalt_split_builds_segments_and_alpha() -> void:
	var layout := _new_floor_layout(Vector2i(4, 3), 41002)
	layout.road_rects.append(Rect2i(Vector2i(2, 0), Vector2i(2, 3)))
	layout.road_rect_tags.append(&"main_road")
	layout.rebuild_terrain_classification()

	var mask_data := BOUNDARY_MASK_BUILDER.build(layout, _resolver)
	var image := mask_data.get("image") as Image

	assert_eq(
		int(mask_data.get("boundary_segment_count", -1)),
		3,
		"the straight split emits one cardinal segment per row"
	)
	assert_gt(
		int(mask_data.get("divider_pixel_count", 0)),
		0,
		"the grass/asphalt split rasterizes divider alpha"
	)
	assert_eq(
		BOUNDARY_MASK_BUILDER.surface_kind_at_cell(
			mask_data,
			layout.zone_size,
			Vector2i(1, 1)
		),
		SURFACE_CLASSIFIER.SURFACE_GRASS,
		"the left side is grass"
	)
	assert_eq(
		BOUNDARY_MASK_BUILDER.surface_kind_at_cell(
			mask_data,
			layout.zone_size,
			Vector2i(2, 1)
		),
		SURFACE_CLASSIFIER.SURFACE_ASPHALT,
		"the right side is asphalt"
	)
	var split_pixel_x := 2 * BOUNDARY_MASK_BUILDER.MASK_PIXELS_PER_TILE
	assert_gt(
		image.get_pixel(split_pixel_x - 1, 4).a,
		0.0,
		"alpha covers the grass side of the split"
	)
	assert_gt(
		image.get_pixel(split_pixel_x, 4).a,
		0.0,
		"alpha covers the asphalt side of the split"
	)
	assert_eq(
		image.get_pixel(4, 4).a,
		0.0,
		"alpha does not spill into the grass interior"
	)
	assert_eq(
		image.get_pixel(28, 4).a,
		0.0,
		"alpha does not spill into the asphalt interior"
	)


func test_divider_uses_rounded_outer_corner_distance() -> void:
	var layout := _new_floor_layout(Vector2i(3, 3), 41021)
	layout.road_rects.append(Rect2i(Vector2i(1, 1), Vector2i(2, 2)))
	layout.road_rect_tags.append(&"main_road")
	layout.rebuild_terrain_classification()

	var mask_data := BOUNDARY_MASK_BUILDER.build(layout, _resolver)
	var image := mask_data.get("image") as Image
	assert_gt(
		image.get_pixel(6, 6).a,
		0.0,
		"diagonal texel inside the corner radius receives the dirt divider"
	)
	assert_eq(
		image.get_pixel(5, 5).a,
		0.0,
		"diagonal texel outside the corner radius is clipped to a round corner"
	)


func test_diagonal_route_cells_do_not_create_a_surface_bridge() -> void:
	var layout := _new_floor_layout(Vector2i(3, 3), 41003)
	layout.add_road_cell(Vector2i(0, 0), &"main_road")
	layout.add_road_cell(Vector2i(1, 1), &"main_road")
	layout.rebuild_terrain_classification()

	var mask_data := BOUNDARY_MASK_BUILDER.build(layout, _resolver)
	var image := mask_data.get("image") as Image

	assert_eq(
		int(mask_data.get("boundary_segment_count", -1)),
		6,
		"only the six cardinal asphalt/grass contacts become segments"
	)
	for grass_cell in [Vector2i(1, 0), Vector2i(0, 1)]:
		assert_eq(
			BOUNDARY_MASK_BUILDER.surface_kind_at_cell(
				mask_data,
				layout.zone_size,
				grass_cell
			),
			SURFACE_CLASSIFIER.SURFACE_GRASS,
			"diagonal asphalt cells do not promote the intervening cell"
		)
		assert_eq(
			image.get_pixelv(_tile_center_pixel(grass_cell)).a,
			0.0,
			"the divider does not bridge through the intervening cell center"
		)


func test_distinct_route_tags_with_same_surface_kind_have_no_divider() -> void:
	var layout := _new_floor_layout(Vector2i(2, 1), 41004)
	layout.add_road_cell(Vector2i(0, 0), &"broken_street")
	layout.add_road_cell(Vector2i(1, 0), &"service_lane")
	layout.rebuild_terrain_classification()

	var mask_data := BOUNDARY_MASK_BUILDER.build(layout, _resolver)
	var image := mask_data.get("image") as Image

	assert_eq(
		SURFACE_CLASSIFIER.classify_cell(layout, _resolver, Vector2i(0, 0)),
		SURFACE_CLASSIFIER.SURFACE_PATH,
		"broken_street is a path surface"
	)
	assert_eq(
		SURFACE_CLASSIFIER.classify_cell(layout, _resolver, Vector2i(1, 0)),
		SURFACE_CLASSIFIER.SURFACE_PATH,
		"service_lane is the same path surface kind"
	)
	assert_eq(
		int(mask_data.get("boundary_segment_count", -1)),
		0,
		"different semantic tags do not divide equal surface kinds"
	)
	assert_eq(
		int(mask_data.get("divider_pixel_count", -1)),
		0,
		"equal path kinds emit no divider alpha"
	)
	assert_true(_all_alpha_is_zero(image), "the equal-kind mask alpha is empty")


func test_seeded_boundary_mask_is_deterministic() -> void:
	var first_layout := _new_split_layout(41005)
	var repeated_layout := _new_split_layout(41005)
	var changed_seed_layout := _new_split_layout(41006)

	var first := BOUNDARY_MASK_BUILDER.build(first_layout, _resolver)
	var repeated := BOUNDARY_MASK_BUILDER.build(repeated_layout, _resolver)
	var changed_seed := BOUNDARY_MASK_BUILDER.build(changed_seed_layout, _resolver)
	var first_image := first.get("image") as Image
	var repeated_image := repeated.get("image") as Image
	var changed_seed_image := changed_seed.get("image") as Image

	assert_eq(
		first.get("surface_kinds"),
		repeated.get("surface_kinds"),
		"equal topology and seed produce equal classifications"
	)
	assert_eq(
		first_image.get_data(),
		repeated_image.get_data(),
		"equal topology and seed produce byte-identical RGBA masks"
	)
	assert_eq(
		first.get("surface_kinds"),
		changed_seed.get("surface_kinds"),
		"changing only the seed does not change terrain kinds"
	)
	assert_false(
		_alpha_bytes(first_image) == _alpha_bytes(changed_seed_image),
		"a different seed changes the stable divider-width variation"
	)


func test_mask_resolution_and_rgb_weights_include_void() -> void:
	var layout := _new_floor_layout(Vector2i(4, 1), 41007)
	layout.add_road_cell(Vector2i(1, 0), &"broken_street")
	layout.add_road_cell(Vector2i(2, 0), &"main_road")
	layout.add_fall_zone_rect(Rect2i(Vector2i(3, 0), Vector2i.ONE), &"internal")
	layout.rebuild_terrain_classification()

	var mask_data := BOUNDARY_MASK_BUILDER.build(layout, _resolver)
	var image := mask_data.get("image") as Image

	assert_eq(
		int(mask_data.get("pixels_per_tile", 0)),
		8,
		"the public mask contract uses eight pixels per tile"
	)
	assert_eq(
		mask_data.get("image_size"),
		Vector2i(32, 8),
		"image dimensions are zone size multiplied by eight"
	)
	assert_eq(image.get_size(), Vector2i(32, 8), "the Image matches its metadata")
	assert_eq(image.get_format(), Image.FORMAT_RGBA8, "surface weights use RGBA8")

	_assert_cell_rgb(image, Vector2i(0, 0), Vector3i(255, 0, 0), "grass encodes in red")
	_assert_cell_rgb(image, Vector2i(1, 0), Vector3i(0, 255, 0), "path encodes in green")
	_assert_cell_rgb(image, Vector2i(2, 0), Vector3i(0, 0, 255), "asphalt encodes in blue")
	_assert_cell_rgb(image, Vector2i(3, 0), Vector3i.ZERO, "void has no surface weight")
	assert_eq(
		BOUNDARY_MASK_BUILDER.surface_kind_at_cell(
			mask_data,
			layout.zone_size,
			Vector2i(3, 0)
		),
		SURFACE_CLASSIFIER.SURFACE_VOID,
		"fall-zone cells classify as visual void"
	)
	assert_eq(
		SURFACE_CLASSIFIER.encoded_weights(SURFACE_CLASSIFIER.SURFACE_VOID),
		Color(0.0, 0.0, 0.0, 0.0),
		"the classifier exposes zero RGBA weights for void"
	)


func test_fall_zone_technical_rim_uses_dirt_between_road_and_void() -> void:
	var layout := _new_floor_layout(Vector2i(3, 1), 41008)
	layout.initialize_parcel_map()
	layout.register_parcel(
		BiomeEnvironmentLayout.PARCEL_FALL_ZONE,
		[Vector2i(1, 0), Vector2i(2, 0)],
		Rect2i(Vector2i(1, 0), Vector2i(2, 1))
	)
	layout.add_road_cell(Vector2i(0, 0), &"main_road")
	layout.add_fall_zone_rect(Rect2i(Vector2i(2, 0), Vector2i.ONE), &"internal")
	layout.rebuild_terrain_classification()

	var mask_data := BOUNDARY_MASK_BUILDER.build(layout, _resolver)
	var image := mask_data.get("image") as Image
	assert_eq(
		BOUNDARY_MASK_BUILDER.surface_kind_at_cell(
			mask_data,
			layout.zone_size,
			Vector2i(0, 0)
		),
		SURFACE_CLASSIFIER.SURFACE_ASPHALT,
		"the road remains asphalt"
	)
	assert_eq(
		BOUNDARY_MASK_BUILDER.surface_kind_at_cell(
			mask_data,
			layout.zone_size,
			Vector2i(1, 0)
		),
		SURFACE_CLASSIFIER.SURFACE_PATH,
		"the walkable fall-zone rim uses the dirt/path material"
	)
	assert_eq(
		BOUNDARY_MASK_BUILDER.surface_kind_at_cell(
			mask_data,
			layout.zone_size,
			Vector2i(2, 0)
		),
		SURFACE_CLASSIFIER.SURFACE_VOID,
		"the fall-zone interior remains void"
	)
	_assert_cell_rgb(image, Vector2i(1, 0), Vector3i(0, 255, 0),
		"the rim encodes the dirt/path texture in the green channel")


func test_mesa_parcel_uses_dirt_without_overriding_routes() -> void:
	var layout := _new_floor_layout(Vector2i(4, 1), 41009)
	layout.initialize_parcel_map()
	layout.register_parcel(
		BiomeEnvironmentLayout.PARCEL_MESA,
		[Vector2i(1, 0), Vector2i(2, 0)],
		Rect2i(Vector2i(1, 0), Vector2i(2, 1))
	)
	layout.register_parcel(
		BiomeEnvironmentLayout.PARCEL_CLEARING,
		[Vector2i(3, 0)],
		Rect2i(Vector2i(3, 0), Vector2i.ONE)
	)
	layout.add_road_cell(Vector2i(0, 0), &"main_road")
	layout.add_road_cell(Vector2i(2, 0), &"main_road")
	layout.rebuild_terrain_classification()

	var mask_data := BOUNDARY_MASK_BUILDER.build(layout, _resolver)
	var expected_kinds: Array[int] = [
		SURFACE_CLASSIFIER.SURFACE_ASPHALT,
		SURFACE_CLASSIFIER.SURFACE_PATH,
		SURFACE_CLASSIFIER.SURFACE_ASPHALT,
		SURFACE_CLASSIFIER.SURFACE_GRASS,
	]
	for x in range(expected_kinds.size()):
		assert_eq(
			BOUNDARY_MASK_BUILDER.surface_kind_at_cell(
				mask_data,
				layout.zone_size,
				Vector2i(x, 0)
			),
			expected_kinds[x],
			"mesa dirt applies only outside route cells at x=%d" % x
		)
	var image := mask_data.get("image") as Image
	_assert_cell_rgb(
		image,
		Vector2i(1, 0),
		Vector3i(0, 255, 0),
		"the mesa parcel base encodes the dirt/path texture"
	)


func _new_floor_layout(size: Vector2i, seed: int) -> BiomeEnvironmentLayout:
	var layout := BiomeEnvironmentLayout.new()
	layout.zone_size = size
	layout.generation_seed = seed
	layout.add_floor_rect(Rect2i(Vector2i.ZERO, size), &"open_block")
	return layout


func _new_split_layout(seed: int) -> BiomeEnvironmentLayout:
	var layout := _new_floor_layout(Vector2i(8, 4), seed)
	layout.road_rects.append(Rect2i(Vector2i(4, 0), Vector2i(4, 4)))
	layout.road_rect_tags.append(&"main_road")
	layout.rebuild_terrain_classification()
	return layout


func _tile_center_pixel(cell: Vector2i) -> Vector2i:
	return (
		cell * BOUNDARY_MASK_BUILDER.MASK_PIXELS_PER_TILE
		+ Vector2i.ONE * (BOUNDARY_MASK_BUILDER.MASK_PIXELS_PER_TILE / 2)
	)


func _all_alpha_is_zero(image: Image) -> bool:
	if image == null or image.is_empty():
		return false
	var bytes := image.get_data()
	for index in range(3, bytes.size(), 4):
		if bytes[index] != 0:
			return false
	return true


func _alpha_bytes(image: Image) -> PackedByteArray:
	var result := PackedByteArray()
	if image == null or image.is_empty():
		return result
	var bytes := image.get_data()
	for index in range(3, bytes.size(), 4):
		result.append(bytes[index])
	return result


func _assert_cell_rgb(
	image: Image,
	cell: Vector2i,
	expected: Vector3i,
	message: String
) -> void:
	var color := image.get_pixelv(_tile_center_pixel(cell))
	var actual := Vector3i(
		roundi(color.r * 255.0),
		roundi(color.g * 255.0),
		roundi(color.b * 255.0)
	)
	assert_eq(actual, expected, message)
