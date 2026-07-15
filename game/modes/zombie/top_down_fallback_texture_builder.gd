extends RefCounted
class_name TopDownFallbackTextureBuilder

const MIN_TEXTURE_SIZE := 32

static func build_texture(
	content: String,
	asset_path: String,
	texture_size: Vector2i,
	primary: Color,
	secondary: Color,
	accent: Color
) -> Texture2D:
	return _build_svg_fallback_texture(
		content,
		asset_path,
		texture_size,
		primary,
		secondary,
		accent
	)

static func _extract_data_attribute(content: String, attribute_name: String) -> String:
	var double_quote_token := attribute_name + "=\""
	var start := content.find(double_quote_token)
	var quote := "\""
	if start >= 0:
		start += double_quote_token.length()
	else:
		var single_quote_token := attribute_name + "='"
		start = content.find(single_quote_token)
		quote = "'"
		if start < 0:
			return ""
		start += single_quote_token.length()
	var end := content.find(quote, start)
	if end < 0:
		return ""
	return content.substr(start, end - start)

static func _build_svg_fallback_texture(
	content: String,
	asset_path: String,
	texture_size: Vector2i,
	primary: Color,
	secondary: Color,
	accent: Color
) -> Texture2D:
	var section := StringName(_extract_data_attribute(content, "data-section"))
	var asset_id := StringName(_extract_data_attribute(content, "data-id"))
	if section == &"object_scenes":
		return _build_object_texture(
			asset_path,
			asset_id,
			texture_size,
			primary,
			secondary,
			accent
		)
	if section == &"void_tiles":
		return _build_void_texture(texture_size, primary, secondary, accent)
	return _build_slot_texture(texture_size, primary, secondary, accent)

static func _build_object_texture(
	asset_path: String,
	asset_id: StringName,
	texture_size: Vector2i,
	primary: Color,
	secondary: Color,
	accent: Color
) -> Texture2D:
	var width := maxi(texture_size.x, MIN_TEXTURE_SIZE)
	var height := maxi(texture_size.y, MIN_TEXTURE_SIZE)
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	_draw_ellipse(
		image,
		Vector2(width * 0.50, height * 0.77),
		Vector2(width * 0.36, height * 0.13),
		Color(0.01, 0.012, 0.016, 0.32)
	)
	match _object_category(asset_path, asset_id):
		&"building":
			_draw_building_object(image, asset_id, primary, secondary, accent)
		&"barrel":
			_draw_barrel_object(image, asset_id, primary, secondary, accent)
		&"wreck":
			_draw_wreck_object(image, asset_id, primary, secondary, accent)
		&"dense_vegetation":
			_draw_dense_vegetation_object(image, asset_id, primary, secondary, accent)
		&"tree":
			_draw_tree_object(image, asset_id, primary, secondary, accent)
		&"log":
			_draw_log_object(image, asset_id, primary, secondary, accent)
		&"bridge":
			_draw_bridge_object(image, asset_id, primary, secondary, accent)
		&"rock":
			_draw_rock_object(image, asset_id, primary, secondary, accent)
		&"crate":
			_draw_crate_object(image, asset_id, primary, secondary, accent)
		&"barrier":
			_draw_barrier_object(image, asset_id, primary, secondary, accent)
		_:
			_draw_crate_object(image, asset_id, primary, secondary, accent)
	return ImageTexture.create_from_image(image)

static func _build_void_texture(
	texture_size: Vector2i,
	primary: Color,
	secondary: Color,
	accent: Color
) -> Texture2D:
	var width := maxi(texture_size.x, MIN_TEXTURE_SIZE)
	var height := maxi(texture_size.y, MIN_TEXTURE_SIZE)
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	_draw_cardinal_rect(
		image,
		Vector2(width * 0.50, height * 0.45),
		Vector2(width * 0.42, height * 0.18),
		primary,
		accent
	)
	for index in range(6):
		var x := lerpf(width * 0.25, width * 0.75, float(index) / 5.0)
		_draw_line(
			image,
			Vector2(x, height * 0.42),
			Vector2(x, height * 0.90),
			2.0,
			secondary
		)
	return ImageTexture.create_from_image(image)

static func _object_category(asset_path: String, asset_id: StringName) -> StringName:
	var key := String(asset_id)
	var normalized_path := asset_path.to_lower()
	if key.contains("barrel") or normalized_path.contains("/barrels/"):
		return &"barrel"
	if key.contains("wreck") or key.contains("car") or normalized_path.contains("/wrecks/"):
		return &"wreck"
	if key.contains("vegetation") or normalized_path.contains("/vegetation/"):
		return &"dense_vegetation"
	if key.contains("bridge") or key.contains("walkway") or normalized_path.contains("/bridges/"):
		return &"bridge"
	if key.contains("tree"):
		return &"tree"
	if key.contains("log"):
		return &"log"
	if key.contains("rock") or key.contains("ice_block") or normalized_path.contains("/rocks/"):
		return &"rock"
	if key.contains("crate") or normalized_path.contains("/crates/"):
		return &"crate"
	if (
		key.contains("fence")
		or key.contains("wall")
		or key.contains("barrier")
		or key.contains("boundary")
		or key.contains("pipe")
		or key.contains("reed")
		or normalized_path.contains("/barriers/")
	):
		return &"barrier"
	if (
		key.contains("house")
		or key.contains("cabin")
		or key.contains("lab")
		or normalized_path.contains("/buildings/")
	):
		return &"building"
	return &"crate"

static func _draw_building_object(
	image: Image,
	asset_id: StringName,
	primary: Color,
	secondary: Color,
	accent: Color
) -> void:
	var width := image.get_width()
	var height := image.get_height()
	var key := String(asset_id)
	_draw_cardinal_volume(
		image,
		Vector2(width * 0.50, height * 0.45),
		Vector2(width * 0.24, height * 0.11),
		height * 0.25,
		primary.lightened(0.08),
		primary.darkened(0.18),
		primary.darkened(0.28),
		accent
	)
	_draw_cardinal_rect(
		image,
		Vector2(width * 0.50, height * 0.34),
		Vector2(width * 0.30, height * 0.16),
		secondary.lightened(0.06),
		accent
	)
	_draw_line(
		image,
		Vector2(width * 0.50, height * 0.18),
		Vector2(width * 0.50, height * 0.49),
		2.0,
		accent
	)
	var window_color := Color(accent.lightened(0.28), 0.78)
	_draw_block(
		image,
		Rect2i(
			Vector2i(int(width * 0.39), int(height * 0.49)),
			Vector2i(int(width * 0.07), int(height * 0.07))
		),
		window_color,
		accent.darkened(0.32)
	)
	_draw_block(
		image,
		Rect2i(
			Vector2i(int(width * 0.55), int(height * 0.50)),
			Vector2i(int(width * 0.07), int(height * 0.07))
		),
		window_color,
		accent.darkened(0.32)
	)
	_draw_block(
		image,
		Rect2i(
			Vector2i(int(width * 0.47), int(height * 0.60)),
			Vector2i(int(width * 0.08), int(height * 0.13))
		),
		secondary.darkened(0.36),
		accent.darkened(0.22)
	)
	if (
		key.contains("ruined")
		or key.contains("burned")
		or key.contains("sunken")
		or key.contains("ruin")
	):
		var damage_color := Color(0.035, 0.035, 0.032, 0.86)
		_draw_line(
			image,
			Vector2(width * 0.34, height * 0.42),
			Vector2(width * 0.26, height * 0.55),
			4.0,
			damage_color
		)
		_draw_line(
			image,
			Vector2(width * 0.64, height * 0.42),
			Vector2(width * 0.70, height * 0.58),
			4.0,
			damage_color
		)
		_draw_line(
			image,
			Vector2(width * 0.43, height * 0.37),
			Vector2(width * 0.52, height * 0.48),
			3.0,
			damage_color
		)

static func _draw_barrier_object(
	image: Image,
	asset_id: StringName,
	primary: Color,
	secondary: Color,
	accent: Color
) -> void:
	var width := image.get_width()
	var height := image.get_height()
	var key := String(asset_id)
	if key.contains("pipe"):
		for index in range(3):
			var offset := Vector2(0.0, float(index) * height * 0.055)
			var start := Vector2(width * 0.28, height * 0.47) + offset
			var end := Vector2(width * 0.72, height * 0.47) + offset
			_draw_line(image, start, end, 8.0, primary.darkened(0.08 * float(index)))
			_draw_ellipse(image, start, Vector2(width * 0.045, height * 0.026), accent)
			_draw_ellipse(image, end, Vector2(width * 0.045, height * 0.026), accent.darkened(0.22))
		return
	if key.contains("wall") or key.contains("boundary"):
		_draw_cardinal_volume(
			image,
			Vector2(width * 0.50, height * 0.55),
			Vector2(width * 0.35, height * 0.08),
			height * 0.13,
			primary.lightened(0.04),
			primary.darkened(0.18),
			primary.darkened(0.26),
			accent
		)
		for index in range(4):
			var x := lerpf(width * 0.27, width * 0.73, float(index) / 3.0)
			_draw_line(
				image,
				Vector2(x, height * 0.53),
				Vector2(x + width * 0.05, height * 0.68),
				2.0,
				accent.darkened(0.20)
			)
		return
	var rail_a := Vector2(width * 0.22, height * 0.50)
	var rail_b := Vector2(width * 0.78, height * 0.50)
	_draw_line(image, rail_a, rail_b, 5.0, primary)
	_draw_line(
		image,
		rail_a + Vector2(0.0, height * 0.11),
		rail_b + Vector2(0.0, height * 0.11),
		5.0,
		primary.darkened(0.18)
	)
	for index in range(5):
		var ratio := float(index) / 4.0
		var post := rail_a.lerp(rail_b, ratio)
		_draw_line(
			image,
			post + Vector2(0.0, -height * 0.13),
			post + Vector2(0.0, height * 0.18),
			6.0,
			secondary.darkened(0.10)
		)
	_draw_line(
		image,
		Vector2(width * 0.34, height * 0.43),
		Vector2(width * 0.48, height * 0.66),
		3.0,
		accent
	)

static func _draw_barrel_object(
	image: Image,
	asset_id: StringName,
	primary: Color,
	secondary: Color,
	accent: Color
) -> void:
	var width := image.get_width()
	var height := image.get_height()
	var center_x := width * 0.50
	var body_rect := Rect2i(
		Vector2i(int(width * 0.41), int(height * 0.39)),
		Vector2i(int(width * 0.18), int(height * 0.31))
	)
	_draw_block(image, body_rect, primary, accent.darkened(0.22))
	_draw_ellipse(
		image,
		Vector2(center_x, height * 0.39),
		Vector2(width * 0.10, height * 0.045),
		secondary.lightened(0.08)
	)
	_draw_ellipse(
		image,
		Vector2(center_x, height * 0.70),
		Vector2(width * 0.10, height * 0.045),
		primary.darkened(0.20)
	)
	for index in range(3):
		var y := height * (0.47 + 0.08 * float(index))
		_draw_line(
			image,
			Vector2(width * 0.42, y),
			Vector2(width * 0.58, y),
			3.0,
			secondary
		)
	_draw_ellipse(
		image,
		Vector2(width * 0.50, height * 0.50),
		Vector2(width * 0.035, height * 0.028),
		Color(accent.lightened(0.32), 0.88)
	)

static func _draw_wreck_object(
	image: Image,
	asset_id: StringName,
	primary: Color,
	secondary: Color,
	accent: Color
) -> void:
	var width := image.get_width()
	var height := image.get_height()
	_draw_cardinal_volume(
		image,
		Vector2(width * 0.50, height * 0.55),
		Vector2(width * 0.30, height * 0.10),
		height * 0.11,
		primary.lightened(0.05),
		primary.darkened(0.18),
		primary.darkened(0.30),
		accent
	)
	_draw_polygon(
		image,
		PackedVector2Array([
			Vector2(width * 0.39, height * 0.45),
			Vector2(width * 0.52, height * 0.38),
			Vector2(width * 0.64, height * 0.48),
			Vector2(width * 0.50, height * 0.55)
		]),
		secondary.darkened(0.10),
		accent
	)
	_draw_ellipse(
		image,
		Vector2(width * 0.36, height * 0.69),
		Vector2(width * 0.055, height * 0.035),
		Color(0.025, 0.025, 0.024, 0.92)
	)
	_draw_ellipse(
		image,
		Vector2(width * 0.65, height * 0.70),
		Vector2(width * 0.055, height * 0.035),
		Color(0.025, 0.025, 0.024, 0.92)
	)
	_draw_line(
		image,
		Vector2(width * 0.30, height * 0.52),
		Vector2(width * 0.42, height * 0.62),
		4.0,
		accent.lightened(0.10)
	)
	_draw_line(
		image,
		Vector2(width * 0.61, height * 0.47),
		Vector2(width * 0.72, height * 0.58),
		4.0,
		accent.darkened(0.24)
	)

static func _draw_dense_vegetation_object(
	image: Image,
	asset_id: StringName,
	primary: Color,
	secondary: Color,
	accent: Color
) -> void:
	var width := image.get_width()
	var height := image.get_height()
	var clumps: Array[Vector3] = [
		Vector3(0.32, 0.60, 0.16),
		Vector3(0.50, 0.51, 0.20),
		Vector3(0.68, 0.60, 0.17),
		Vector3(0.45, 0.70, 0.21),
		Vector3(0.62, 0.71, 0.17)
	]
	for index in range(clumps.size()):
		var clump := clumps[index]
		_draw_ellipse(
			image,
			Vector2(width * clump.x, height * clump.y),
			Vector2(width * clump.z, height * clump.z * 0.70),
			primary.darkened(0.08 + float(index % 2) * 0.08)
		)
	for index in range(5):
		var ratio := float(index) / 4.0
		var start := Vector2(lerpf(width * 0.28, width * 0.72, ratio), height * 0.74)
		var end := Vector2(
			start.x + sin(float(index)) * width * 0.05,
			height * lerpf(0.43, 0.58, float(index % 3) / 2.0)
		)
		_draw_line(image, start, end, 4.0, accent.darkened(0.12))
	_draw_cardinal_rect(
		image,
		Vector2(width * 0.50, height * 0.78),
		Vector2(width * 0.30, height * 0.08),
		Color(secondary.darkened(0.10), 0.75),
		accent.darkened(0.28)
	)

static func _draw_tree_object(
	image: Image,
	asset_id: StringName,
	primary: Color,
	secondary: Color,
	accent: Color
) -> void:
	var width := image.get_width()
	var height := image.get_height()
	var trunk_start := Vector2(width * 0.50, height * 0.76)
	var trunk_end := Vector2(width * 0.52, height * 0.31)
	_draw_line(image, trunk_start, trunk_end, 9.0, secondary.darkened(0.08))
	_draw_line(
		image,
		Vector2(width * 0.51, height * 0.48),
		Vector2(width * 0.31, height * 0.38),
		5.0,
		secondary.darkened(0.02)
	)
	_draw_line(
		image,
		Vector2(width * 0.52, height * 0.42),
		Vector2(width * 0.70, height * 0.30),
		5.0,
		secondary.darkened(0.16)
	)
	_draw_line(
		image,
		Vector2(width * 0.52, height * 0.57),
		Vector2(width * 0.68, height * 0.52),
		4.0,
		secondary.darkened(0.10)
	)
	if not String(asset_id).contains("dead"):
		_draw_ellipse(
			image,
			Vector2(width * 0.50, height * 0.33),
			Vector2(width * 0.19, height * 0.11),
			Color(primary, 0.82)
		)
	_draw_cardinal_rect(
		image,
		Vector2(width * 0.50, height * 0.77),
		Vector2(width * 0.14, height * 0.05),
		primary.darkened(0.25),
		accent.darkened(0.30)
	)

static func _draw_log_object(
	image: Image,
	asset_id: StringName,
	primary: Color,
	secondary: Color,
	accent: Color
) -> void:
	var width := image.get_width()
	var height := image.get_height()
	var start := Vector2(width * 0.27, height * 0.57)
	var end := Vector2(width * 0.73, height * 0.57)
	_draw_line(image, start, end, 15.0, primary)
	_draw_line(
		image,
		start + Vector2(0.0, height * 0.08),
		end + Vector2(0.0, height * 0.08),
		9.0,
		primary.darkened(0.20)
	)
	_draw_ellipse(image, start, Vector2(width * 0.060, height * 0.040), secondary)
	_draw_ellipse(image, end, Vector2(width * 0.060, height * 0.040), secondary.darkened(0.16))
	for index in range(4):
		var ratio := float(index + 1) / 5.0
		var center := start.lerp(end, ratio)
		_draw_line(
			image,
			center + Vector2(-width * 0.02, -height * 0.04),
			center + Vector2(width * 0.02, height * 0.07),
			2.0,
			accent.darkened(0.18)
		)

static func _draw_bridge_object(
	image: Image,
	asset_id: StringName,
	primary: Color,
	secondary: Color,
	accent: Color
) -> void:
	var width := image.get_width()
	var height := image.get_height()
	_draw_cardinal_rect(
		image,
		Vector2(width * 0.50, height * 0.62),
		Vector2(width * 0.39, height * 0.15),
		primary.darkened(0.06),
		accent
	)
	for index in range(7):
		var ratio := float(index) / 6.0
		var x := lerpf(width * 0.26, width * 0.74, ratio)
		_draw_line(
			image,
			Vector2(x, height * 0.47),
			Vector2(x, height * 0.77),
			2.0,
			secondary.darkened(0.10)
		)
	_draw_line(
		image,
		Vector2(width * 0.24, height * 0.46),
		Vector2(width * 0.76, height * 0.46),
		4.0,
		accent.darkened(0.16)
	)
	_draw_line(
		image,
		Vector2(width * 0.25, height * 0.78),
		Vector2(width * 0.76, height * 0.78),
		4.0,
		accent.darkened(0.22)
	)
	if String(asset_id).contains("broken"):
		_draw_line(
			image,
			Vector2(width * 0.48, height * 0.51),
			Vector2(width * 0.55, height * 0.72),
			5.0,
			Color(0.02, 0.018, 0.014, 0.80)
		)

static func _draw_rock_object(
	image: Image,
	asset_id: StringName,
	primary: Color,
	secondary: Color,
	accent: Color
) -> void:
	var width := image.get_width()
	var height := image.get_height()
	_draw_polygon(
		image,
		PackedVector2Array([
			Vector2(width * 0.31, height * 0.64),
			Vector2(width * 0.43, height * 0.43),
			Vector2(width * 0.62, height * 0.42),
			Vector2(width * 0.74, height * 0.63),
			Vector2(width * 0.56, height * 0.76),
			Vector2(width * 0.39, height * 0.74)
		]),
		primary,
		accent
	)
	_draw_polygon(
		image,
		PackedVector2Array([
			Vector2(width * 0.43, height * 0.43),
			Vector2(width * 0.52, height * 0.34),
			Vector2(width * 0.62, height * 0.42),
			Vector2(width * 0.52, height * 0.56)
		]),
		secondary.lightened(0.06),
		accent.darkened(0.20)
	)
	_draw_line(
		image,
		Vector2(width * 0.47, height * 0.55),
		Vector2(width * 0.38, height * 0.72),
		2.0,
		accent.darkened(0.18)
	)
	_draw_line(
		image,
		Vector2(width * 0.56, height * 0.54),
		Vector2(width * 0.70, height * 0.64),
		2.0,
		accent.darkened(0.18)
	)

static func _draw_crate_object(
	image: Image,
	asset_id: StringName,
	primary: Color,
	secondary: Color,
	accent: Color
) -> void:
	var width := image.get_width()
	var height := image.get_height()
	_draw_cardinal_volume(
		image,
		Vector2(width * 0.50, height * 0.50),
		Vector2(width * 0.23, height * 0.12),
		height * 0.18,
		primary.lightened(0.05),
		primary.darkened(0.14),
		primary.darkened(0.24),
		accent
	)
	_draw_line(
		image,
		Vector2(width * 0.34, height * 0.55),
		Vector2(width * 0.50, height * 0.80),
		3.0,
		secondary.darkened(0.12)
	)
	_draw_line(
		image,
		Vector2(width * 0.66, height * 0.55),
		Vector2(width * 0.50, height * 0.80),
		3.0,
		secondary.darkened(0.18)
	)
	_draw_line(
		image,
		Vector2(width * 0.30, height * 0.64),
		Vector2(width * 0.70, height * 0.64),
		3.0,
		accent.darkened(0.20)
	)

static func _build_slot_texture(
	texture_size: Vector2i,
	primary: Color,
	secondary: Color,
	accent: Color
) -> Texture2D:
	var width := maxi(texture_size.x, MIN_TEXTURE_SIZE)
	var height := maxi(texture_size.y, MIN_TEXTURE_SIZE)
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	_draw_ellipse(
		image,
		Vector2(width * 0.5, height * 0.70),
		Vector2(width * 0.36, height * 0.15),
		Color(0.01, 0.012, 0.016, 0.38)
	)
	_draw_cardinal_rect(
		image,
		Vector2(width * 0.5, height * 0.66),
		Vector2(width * 0.28, height * 0.17),
		secondary,
		accent
	)
	_draw_block(
		image,
		Rect2i(
			Vector2i(int(width * 0.34), int(height * 0.35)),
			Vector2i(int(width * 0.32), int(height * 0.27))
		),
		primary,
		accent
	)
	_draw_roof(
		image,
		Vector2(width * 0.5, height * 0.22),
		Vector2(width * 0.24, height * 0.15),
		primary.lightened(0.12),
		accent
	)
	return ImageTexture.create_from_image(image)

static func _draw_cardinal_volume(
	image: Image,
	center: Vector2,
	radius: Vector2,
	side_height: float,
	top_fill: Color,
	west_fill: Color,
	east_fill: Color,
	stroke: Color
) -> void:
	# Both the top and ground footprint are screen-aligned rectangles. Expanding
	# the lower rectangle symmetrically exposes controlled west/east faces while
	# the south face carries the visual height. This keeps perspective cosmetic:
	# no rotated base or sheared gameplay footprint can leak through the fallback.
	var spread := minf(side_height * 0.22, radius.x * 0.12)
	var top_north_west := center + Vector2(-radius.x, -radius.y)
	var top_north_east := center + Vector2(radius.x, -radius.y)
	var top_south_east := center + Vector2(radius.x, radius.y)
	var top_south_west := center + Vector2(-radius.x, radius.y)
	var drop := Vector2(0.0, side_height)
	var base_north_west := top_north_west + drop + Vector2(-spread, 0.0)
	var base_north_east := top_north_east + drop + Vector2(spread, 0.0)
	var base_south_east := top_south_east + drop + Vector2(spread, 0.0)
	var base_south_west := top_south_west + drop + Vector2(-spread, 0.0)
	_draw_polygon(
		image,
		PackedVector2Array([
			top_north_west,
			top_south_west,
			base_south_west,
			base_north_west
		]),
		west_fill,
		stroke.darkened(0.12)
	)
	_draw_polygon(
		image,
		PackedVector2Array([
			top_south_east,
			top_north_east,
			base_north_east,
			base_south_east
		]),
		east_fill,
		stroke.darkened(0.20)
	)
	_draw_polygon(
		image,
		PackedVector2Array([
			top_south_west,
			top_south_east,
			base_south_east,
			base_south_west
		]),
		west_fill.lerp(east_fill, 0.5),
		stroke.darkened(0.16)
	)
	_draw_polygon(
		image,
		PackedVector2Array([
			top_north_west,
			top_north_east,
			top_south_east,
			top_south_west
		]),
		top_fill,
		stroke
	)

static func _draw_polygon(
	image: Image,
	points: PackedVector2Array,
	fill: Color,
	stroke: Color
) -> void:
	if points.size() < 3:
		return
	var min_x := image.get_width() - 1
	var max_x := 0
	var min_y := image.get_height() - 1
	var max_y := 0
	for point in points:
		min_x = mini(min_x, clampi(int(floorf(point.x)), 0, image.get_width() - 1))
		max_x = maxi(max_x, clampi(int(ceilf(point.x)), 0, image.get_width() - 1))
		min_y = mini(min_y, clampi(int(floorf(point.y)), 0, image.get_height() - 1))
		max_y = maxi(max_y, clampi(int(ceilf(point.y)), 0, image.get_height() - 1))
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			if _point_in_polygon(Vector2(float(x) + 0.5, float(y) + 0.5), points):
				_blend_pixel(image, x, y, fill)
	if stroke.a <= 0.0:
		return
	for index in range(points.size()):
		var next_index := (index + 1) % points.size()
		_draw_line(image, points[index], points[next_index], 2.0, stroke)

static func _point_in_polygon(point: Vector2, points: PackedVector2Array) -> bool:
	var inside := false
	var previous_index := points.size() - 1
	for index in range(points.size()):
		var current := points[index]
		var previous := points[previous_index]
		var crosses_y := (current.y > point.y) != (previous.y > point.y)
		var denominator := previous.y - current.y
		if crosses_y and absf(denominator) > 0.001:
			var intersection_x := (
				(previous.x - current.x)
				* (point.y - current.y)
				/ denominator
				+ current.x
			)
			if point.x < intersection_x:
				inside = not inside
		previous_index = index
	return inside

static func _draw_line(
	image: Image,
	start: Vector2,
	end: Vector2,
	width: float,
	color: Color
) -> void:
	var radius := maxf(width * 0.5, 0.5)
	var min_x := maxi(int(floorf(minf(start.x, end.x) - radius)), 0)
	var max_x := mini(int(ceilf(maxf(start.x, end.x) + radius)), image.get_width() - 1)
	var min_y := maxi(int(floorf(minf(start.y, end.y) - radius)), 0)
	var max_y := mini(int(ceilf(maxf(start.y, end.y) + radius)), image.get_height() - 1)
	var segment := end - start
	var length_squared := segment.length_squared()
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var point := Vector2(float(x) + 0.5, float(y) + 0.5)
			var closest := start
			if length_squared > 0.001:
				var ratio := clampf(
					(point - start).dot(segment) / length_squared,
					0.0,
					1.0
				)
				closest = start + segment * ratio
			if point.distance_to(closest) <= radius:
				_blend_pixel(image, x, y, color)

static func _draw_ellipse(
	image: Image,
	center: Vector2,
	radius: Vector2,
	color: Color
) -> void:
	var min_x := maxi(int(center.x - radius.x), 0)
	var max_x := mini(int(center.x + radius.x), image.get_width() - 1)
	var min_y := maxi(int(center.y - radius.y), 0)
	var max_y := mini(int(center.y + radius.y), image.get_height() - 1)
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var offset := Vector2(
				(float(x) - center.x) / radius.x,
				(float(y) - center.y) / radius.y
			)
			if offset.length_squared() <= 1.0:
				_blend_pixel(image, x, y, color)

static func _draw_cardinal_rect(
	image: Image,
	center: Vector2,
	radius: Vector2,
	fill: Color,
	stroke: Color
) -> void:
	var safe_radius := Vector2(maxf(radius.x, 1.0), maxf(radius.y, 1.0))
	var rect := Rect2i(
		Vector2i(
			floori(center.x - safe_radius.x),
			floori(center.y - safe_radius.y)
		),
		Vector2i(
			ceili(safe_radius.x * 2.0),
			ceili(safe_radius.y * 2.0)
		)
	)
	_draw_block(image, rect, fill, stroke)

static func _draw_block(
	image: Image,
	rect: Rect2i,
	fill: Color,
	stroke: Color
) -> void:
	var left := clampi(rect.position.x, 0, image.get_width() - 1)
	var top := clampi(rect.position.y, 0, image.get_height() - 1)
	var right := clampi(rect.position.x + rect.size.x, 0, image.get_width() - 1)
	var bottom := clampi(rect.position.y + rect.size.y, 0, image.get_height() - 1)
	for y in range(top, bottom + 1):
		for x in range(left, right + 1):
			var is_border := (
				x <= left + 2
				or x >= right - 2
				or y <= top + 2
				or y >= bottom - 2
			)
			var shade := 0.12 * clampf(float(y - top) / maxf(float(bottom - top), 1.0), 0.0, 1.0)
			var color := stroke if is_border else fill.darkened(shade)
			_blend_pixel(image, x, y, color)

static func _draw_roof(
	image: Image,
	apex: Vector2,
	radius: Vector2,
	fill: Color,
	stroke: Color
) -> void:
	var min_x := maxi(int(apex.x - radius.x), 0)
	var max_x := mini(int(apex.x + radius.x), image.get_width() - 1)
	var min_y := maxi(int(apex.y), 0)
	var max_y := mini(int(apex.y + radius.y), image.get_height() - 1)
	for y in range(min_y, max_y + 1):
		var progress := clampf((float(y) - apex.y) / radius.y, 0.0, 1.0)
		var half_width := lerpf(0.0, radius.x, progress)
		for x in range(maxi(int(apex.x - half_width), min_x), mini(int(apex.x + half_width), max_x) + 1):
			var border := (
				absf(float(x) - apex.x) >= half_width - 2.0
				or y >= max_y - 2
			)
			_blend_pixel(image, x, y, stroke if border else fill)

static func _blend_pixel(image: Image, x: int, y: int, color: Color) -> void:
	var existing := image.get_pixel(x, y)
	var alpha := color.a + existing.a * (1.0 - color.a)
	if alpha <= 0.0:
		image.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
		return
	var blended := Color(
		(color.r * color.a + existing.r * existing.a * (1.0 - color.a)) / alpha,
		(color.g * color.a + existing.g * existing.a * (1.0 - color.a)) / alpha,
		(color.b * color.a + existing.b * existing.a * (1.0 - color.a)) / alpha,
		alpha
	)
	image.set_pixel(x, y, blended)
