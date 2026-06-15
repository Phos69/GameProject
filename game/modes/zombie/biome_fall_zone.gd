extends Area2D
class_name BiomeFallZone

var hazard_id: StringName = &"fall_zone"
var zone_size: Vector2 = Vector2(150.0, 72.0)
var edge_color: Color = Color(0.82, 0.58, 0.16, 0.92)
var depth_color: Color = Color(0.025, 0.028, 0.022, 1.0)

func configure(
	next_hazard_id: StringName,
	next_size: Vector2,
	rotation_radians: float,
	warning_color: Color
) -> void:
	hazard_id = next_hazard_id
	zone_size = Vector2(
		maxf(next_size.x, 32.0),
		maxf(next_size.y, 24.0)
	)
	rotation = rotation_radians
	edge_color = warning_color
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	monitorable = false
	z_index = -1
	set_meta("zone_radius", maxf(zone_size.x, zone_size.y) * 0.5)
	_rebuild_collision()
	queue_redraw()

func _ready() -> void:
	add_to_group("fall_zones")
	add_to_group("environment_hazards")
	if get_node_or_null("CollisionShape2D") == null:
		_rebuild_collision()

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
	var half_size := zone_size * 0.5
	var outline := _jagged_outline(half_size)
	draw_colored_polygon(outline, depth_color)
	var closed_outline := outline.duplicate()
	closed_outline.append(outline[0])
	draw_polyline(closed_outline, edge_color, 4.0, true)
	draw_polyline(
		closed_outline,
		Color(0.96, 0.28, 0.18, 0.48),
		1.5,
		true
	)
	for index in range(5):
		var ratio := float(index + 1) / 6.0
		var x_position := lerpf(-half_size.x * 0.72, half_size.x * 0.72, ratio)
		draw_line(
			Vector2(x_position - 12.0, -half_size.y * 0.36),
			Vector2(x_position + 7.0, half_size.y * 0.34),
			Color(0.38, 0.10, 0.08, 0.72),
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
