extends Area2D
class_name BiomeFallZone

const CLIFF_RENDERER_SCRIPT = preload(
	"res://game/modes/zombie/isometric_cliff_renderer.gd"
)
const VALID_FALL_SIDES: Array[StringName] = [&"north", &"south", &"east", &"west"]

var hazard_id: StringName = &"fall_zone"
var fall_style: StringName = &"cliff"
var fall_side: StringName = &"north"
var visual_seed: int = 0
var zone_size: Vector2 = Vector2(150.0, 72.0)
var edge_color: Color = Color(0.82, 0.58, 0.16, 0.92)
var depth_color: Color = Color(0.025, 0.028, 0.022, 1.0)
var show_debug_visual: bool = false
var cliff_renderer: Node2D

func configure(
	next_hazard_id: StringName,
	next_size: Vector2,
	rotation_radians: float,
	warning_color: Color,
	next_fall_style: StringName = &"cliff",
	next_fall_side: StringName = &"",
	next_visual_seed: int = 0
) -> void:
	hazard_id = next_hazard_id
	fall_style = next_fall_style
	zone_size = Vector2(
		maxf(next_size.x, 32.0),
		maxf(next_size.y, 24.0)
	)
	fall_side = _normalize_fall_side(next_fall_side)
	visual_seed = next_visual_seed
	rotation = rotation_radians
	edge_color = warning_color
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	monitorable = false
	z_index = -1
	set_meta("zone_radius", maxf(zone_size.x, zone_size.y) * 0.5)
	_rebuild_collision()
	_ensure_cliff_renderer()
	_configure_cliff_renderer()
	queue_redraw()

func _ready() -> void:
	add_to_group("fall_zones")
	add_to_group("environment_hazards")
	if get_node_or_null("CollisionShape2D") == null:
		_rebuild_collision()
	_ensure_cliff_renderer()
	_configure_cliff_renderer()

func contains_global_position(world_position: Vector2) -> bool:
	var local_position := to_local(world_position)
	var half_size := zone_size * 0.5
	return (
		absf(local_position.x) <= half_size.x
		and absf(local_position.y) <= half_size.y
	)

func distance_to_zone(world_position: Vector2) -> float:
	var local_position := to_local(world_position)
	var half_size := zone_size * 0.5
	var outside := Vector2(
		maxf(absf(local_position.x) - half_size.x, 0.0),
		maxf(absf(local_position.y) - half_size.y, 0.0)
	)
	return outside.length()

func get_fall_style() -> StringName:
	return fall_style

func get_fall_side() -> StringName:
	return fall_side

func get_visual_seed() -> int:
	return visual_seed

func has_asset_renderer() -> bool:
	return (
		cliff_renderer != null
		and is_instance_valid(cliff_renderer)
		and cliff_renderer.has_method("has_assets")
		and bool(cliff_renderer.call("has_assets"))
	)

func uses_procedural_fallback() -> bool:
	if cliff_renderer == null or not is_instance_valid(cliff_renderer):
		return true
	if not cliff_renderer.has_method("uses_procedural_fallback"):
		return true
	return bool(cliff_renderer.call("uses_procedural_fallback"))

func get_void_asset_ids() -> Array[StringName]:
	if (
		cliff_renderer != null
		and is_instance_valid(cliff_renderer)
		and cliff_renderer.has_method("get_asset_ids")
	):
		return cliff_renderer.call("get_asset_ids") as Array[StringName]
	return [
		&"fall_zone",
		&"void_edge_near",
		&"void_depth",
		&"void_vertical_lines",
		get_cliff_lip_asset_id()
	]

func get_loaded_void_asset_ids() -> Array[StringName]:
	if (
		cliff_renderer != null
		and is_instance_valid(cliff_renderer)
		and cliff_renderer.has_method("get_loaded_asset_ids")
	):
		return cliff_renderer.call("get_loaded_asset_ids") as Array[StringName]
	return []

func get_void_asset_paths() -> Dictionary:
	if (
		cliff_renderer != null
		and is_instance_valid(cliff_renderer)
		and cliff_renderer.has_method("get_asset_paths")
	):
		return cliff_renderer.call("get_asset_paths") as Dictionary
	return {}

func get_cliff_lip_asset_id() -> StringName:
	if (
		cliff_renderer != null
		and is_instance_valid(cliff_renderer)
		and cliff_renderer.has_method("get_cliff_lip_id")
	):
		return StringName(str(cliff_renderer.call("get_cliff_lip_id")))
	return StringName("cliff_lip_%s" % String(fall_side))

func get_vertical_line_count() -> int:
	if (
		cliff_renderer != null
		and is_instance_valid(cliff_renderer)
		and cliff_renderer.has_method("get_vertical_line_count")
	):
		return int(cliff_renderer.call("get_vertical_line_count"))
	return 0

func set_debug_visual_visible(enabled: bool) -> void:
	show_debug_visual = enabled
	if (
		cliff_renderer != null
		and is_instance_valid(cliff_renderer)
		and cliff_renderer.has_method("set_debug_visual_visible")
	):
		cliff_renderer.call("set_debug_visual_visible", enabled)
	queue_redraw()

func _rebuild_collision() -> void:
	var collision_shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null:
		collision_shape = CollisionShape2D.new()
		collision_shape.name = "CollisionShape2D"
		add_child(collision_shape)
	var rectangle := RectangleShape2D.new()
	rectangle.size = zone_size
	collision_shape.shape = rectangle

func _draw() -> void:
	if has_asset_renderer() and not uses_procedural_fallback():
		return
	_draw_procedural_cliff()

func _draw_procedural_cliff() -> void:
	var half_size := zone_size * 0.5
	var outline := _jagged_outline(half_size)
	var resolved_depth_color := _depth_color_for_style()
	var resolved_edge_color := _edge_color_for_style()
	draw_colored_polygon(outline, resolved_depth_color)
	for band_index in range(4):
		var inset := float(band_index + 1) * 0.10
		draw_colored_polygon(
			_scaled_points(outline, 1.0 - inset, 1.0 - inset * 0.55),
			Color(resolved_depth_color.lightened(0.035 * float(band_index + 1)), 0.22)
		)
	var closed_outline := outline.duplicate()
	closed_outline.append(outline[0])
	draw_polyline(closed_outline, resolved_edge_color, 4.0, true)
	draw_polyline(
		closed_outline,
		Color(resolved_edge_color.lightened(0.22), 0.52),
		1.5,
		true
	)
	_draw_cliff_lip(half_size, resolved_edge_color)
	_draw_depth_streaks(half_size, resolved_edge_color)

func _ensure_cliff_renderer() -> void:
	if cliff_renderer != null and is_instance_valid(cliff_renderer):
		return
	cliff_renderer = get_node_or_null("IsometricCliffRenderer") as Node2D
	if cliff_renderer == null:
		cliff_renderer = CLIFF_RENDERER_SCRIPT.new() as Node2D
		cliff_renderer.name = "IsometricCliffRenderer"
		add_child(cliff_renderer)
		cliff_renderer.owner = owner

func _configure_cliff_renderer() -> void:
	if cliff_renderer == null or not is_instance_valid(cliff_renderer):
		return
	if not cliff_renderer.has_method("configure"):
		return
	cliff_renderer.call(
		"configure",
		zone_size,
		fall_side,
		fall_style,
		edge_color,
		depth_color,
		visual_seed,
		show_debug_visual
	)

func _normalize_fall_side(value: StringName) -> StringName:
	if VALID_FALL_SIDES.has(value):
		return value
	if zone_size.x >= zone_size.y:
		return &"north"
	return &"west"

func _draw_cliff_lip(half_size: Vector2, color: Color) -> void:
	var lip_points := PackedVector2Array([
		Vector2(-half_size.x, -half_size.y * 0.62),
		Vector2(-half_size.x * 0.70, -half_size.y),
		Vector2(-half_size.x * 0.28, -half_size.y * 0.78),
		Vector2(half_size.x * 0.14, -half_size.y),
		Vector2(half_size.x * 0.62, -half_size.y * 0.72),
		Vector2(half_size.x, -half_size.y * 0.34)
	])
	draw_polyline(lip_points, color.lightened(0.16), 6.0, true)
	draw_polyline(lip_points, Color(0.02, 0.025, 0.028, 0.58), 2.0, true)

func _draw_depth_streaks(half_size: Vector2, color: Color) -> void:
	for index in range(5):
		var ratio := float(index + 1) / 6.0
		var x_position := lerpf(-half_size.x * 0.72, half_size.x * 0.72, ratio)
		draw_line(
			Vector2(x_position - 12.0, -half_size.y * 0.36),
			Vector2(x_position + 7.0, half_size.y * 0.34),
			Color(color.darkened(0.38), 0.64),
			2.0,
			true
		)

func _jagged_outline(half_size: Vector2) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-half_size.x, -half_size.y * 0.62),
		Vector2(-half_size.x * 0.70, -half_size.y),
		Vector2(-half_size.x * 0.28, -half_size.y * 0.78),
		Vector2(half_size.x * 0.14, -half_size.y),
		Vector2(half_size.x * 0.62, -half_size.y * 0.72),
		Vector2(half_size.x, -half_size.y * 0.34),
		Vector2(half_size.x * 0.82, half_size.y * 0.58),
		Vector2(half_size.x * 0.35, half_size.y),
		Vector2(-half_size.x * 0.10, half_size.y * 0.76),
		Vector2(-half_size.x * 0.58, half_size.y),
		Vector2(-half_size.x, half_size.y * 0.42)
	])

func _scaled_points(
	points: PackedVector2Array,
	scale_x: float,
	scale_y: float
) -> PackedVector2Array:
	var scaled := PackedVector2Array()
	for point in points:
		scaled.append(Vector2(point.x * scale_x, point.y * scale_y))
	return scaled

func _depth_color_for_style() -> Color:
	match fall_style:
		&"toxic_cliff":
			return Color(0.018, 0.035, 0.024, 1.0)
		&"lava_cliff":
			return Color(0.055, 0.018, 0.012, 1.0)
		&"ice_cliff":
			return Color(0.018, 0.030, 0.042, 1.0)
		&"marsh_cliff":
			return Color(0.014, 0.026, 0.030, 1.0)
		_:
			return depth_color

func _edge_color_for_style() -> Color:
	match fall_style:
		&"toxic_cliff":
			return Color(edge_color.lightened(0.10), 0.92)
		&"lava_cliff":
			return Color(0.98, 0.30, 0.10, 0.92)
		&"ice_cliff":
			return Color(0.54, 0.82, 0.96, 0.92)
		&"marsh_cliff":
			return Color(0.22, 0.56, 0.50, 0.92)
		_:
			return edge_color
