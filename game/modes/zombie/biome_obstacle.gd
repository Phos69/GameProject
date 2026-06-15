extends StaticBody2D
class_name BiomeObstacle

var obstacle_id: StringName = &"small_rock"
var obstacle_size: Vector2 = Vector2(48.0, 40.0)
var shape_id: StringName = &"rectangle"
var primary_color: Color = Color(0.38, 0.30, 0.16, 1.0)
var accent_color: Color = Color(0.74, 0.58, 0.16, 0.82)

func configure(
	next_obstacle_id: StringName,
	next_size: Vector2,
	next_shape_id: StringName,
	rotation_radians: float,
	base_color: Color,
	detail_color: Color
) -> void:
	obstacle_id = next_obstacle_id
	obstacle_size = Vector2(
		maxf(next_size.x, 12.0),
		maxf(next_size.y, 12.0)
	)
	shape_id = next_shape_id
	rotation = rotation_radians
	primary_color = base_color
	accent_color = detail_color
	collision_layer = 1
	collision_mask = 0
	z_index = 1
	set_meta("zone_radius", get_clearance_radius())
	_rebuild_collision()
	queue_redraw()

func _ready() -> void:
	add_to_group("environment_obstacles")
	add_to_group("spawn_blockers")
	if get_node_or_null("CollisionShape2D") == null:
		_rebuild_collision()

func contains_global_position(world_position: Vector2) -> bool:
	var local_position := to_local(world_position)
	if shape_id == &"circle":
		var radius := obstacle_size.x * 0.5
		return local_position.length_squared() <= radius * radius
	var half_size := obstacle_size * 0.5
	return (
		absf(local_position.x) <= half_size.x
		and absf(local_position.y) <= half_size.y
	)

func get_clearance_radius() -> float:
	return maxf(obstacle_size.x, obstacle_size.y) * 0.58

func _rebuild_collision() -> void:
	var collision_shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null:
		collision_shape = CollisionShape2D.new()
		collision_shape.name = "CollisionShape2D"
		add_child(collision_shape)
	if shape_id == &"circle":
		var circle := CircleShape2D.new()
		circle.radius = obstacle_size.x * 0.5
		collision_shape.shape = circle
		return
	var rectangle := RectangleShape2D.new()
	rectangle.size = obstacle_size
	collision_shape.shape = rectangle

func _draw() -> void:
	match obstacle_id:
		&"small_rock", &"ice_rock":
			_draw_rock()
		&"broken_fence", &"boundary_fence", &"reed_wall":
			_draw_fence()
		&"ruined_house", &"lab_ruin", &"burned_house", &"abandoned_house":
			_draw_ruined_house()
		&"chemical_barrel":
			_draw_barrel()
		&"sunken_wreck", &"metal_wreck":
			_draw_wreck()
		&"toxic_boundary_wall", &"lava_boundary", &"ice_boundary", &"deep_water_boundary":
			_draw_boundary()
		_:
			_draw_barrier()

func _draw_rock() -> void:
	var half_size := obstacle_size * 0.5
	var points := PackedVector2Array([
		Vector2(-half_size.x * 0.86, half_size.y * 0.18),
		Vector2(-half_size.x * 0.54, -half_size.y * 0.76),
		Vector2(half_size.x * 0.18, -half_size.y),
		Vector2(half_size.x, -half_size.y * 0.16),
		Vector2(half_size.x * 0.56, half_size.y * 0.82),
		Vector2(-half_size.x * 0.42, half_size.y)
	])
	draw_colored_polygon(points, primary_color.darkened(0.12))
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, accent_color, 2.0, true)
	draw_line(
		Vector2(-half_size.x * 0.35, -half_size.y * 0.28),
		Vector2(half_size.x * 0.22, half_size.y * 0.18),
		primary_color.lightened(0.18),
		2.0,
		true
	)

func _draw_fence() -> void:
	var half_size := obstacle_size * 0.5
	draw_rect(
		Rect2(Vector2(-half_size.x, -4.0), Vector2(obstacle_size.x, 8.0)),
		primary_color.darkened(0.10),
		true
	)
	for x_position in [-half_size.x + 8.0, 0.0, half_size.x - 8.0]:
		draw_line(
			Vector2(x_position, -half_size.y),
			Vector2(x_position, half_size.y),
			accent_color.darkened(0.20),
			6.0,
			true
		)
	draw_line(
		Vector2(-half_size.x, -half_size.y * 0.38),
		Vector2(half_size.x, half_size.y * 0.30),
		accent_color,
		2.0,
		true
	)

func _draw_barrier() -> void:
	var half_size := obstacle_size * 0.5
	draw_rect(
		Rect2(-half_size, obstacle_size),
		primary_color.darkened(0.18),
		true
	)
	draw_rect(
		Rect2(
			Vector2(-half_size.x + 5.0, -half_size.y + 4.0),
			Vector2(obstacle_size.x - 10.0, obstacle_size.y - 8.0)
		),
		primary_color,
		true
	)
	draw_line(
		Vector2(-half_size.x + 8.0, 0.0),
		Vector2(half_size.x - 8.0, 0.0),
		accent_color,
		3.0,
		true
	)

func _draw_ruined_house() -> void:
	var half_size := obstacle_size * 0.5
	draw_rect(
		Rect2(-half_size, obstacle_size),
		primary_color.darkened(0.28),
		true
	)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(-half_size.x - 6.0, -half_size.y + 8.0),
			Vector2(-half_size.x * 0.25, -half_size.y - 24.0),
			Vector2(half_size.x + 8.0, -half_size.y + 5.0),
			Vector2(half_size.x * 0.72, -half_size.y + 18.0),
			Vector2(-half_size.x * 0.72, -half_size.y + 18.0)
		]),
		primary_color.darkened(0.05)
	)
	draw_rect(
		Rect2(Vector2(-14.0, 4.0), Vector2(28.0, half_size.y - 4.0)),
		Color(0.055, 0.06, 0.045, 1.0),
		true
	)
	draw_line(
		Vector2(-half_size.x * 0.7, -half_size.y + 16.0),
		Vector2(half_size.x * 0.68, half_size.y - 8.0),
		accent_color.darkened(0.30),
		4.0,
		true
	)

func _draw_barrel() -> void:
	var radius := minf(obstacle_size.x, obstacle_size.y) * 0.42
	draw_circle(Vector2.ZERO, radius + 4.0, primary_color.darkened(0.28))
	draw_circle(Vector2.ZERO, radius, primary_color)
	draw_line(
		Vector2(-radius, -radius * 0.32),
		Vector2(radius, -radius * 0.32),
		accent_color,
		4.0,
		true
	)
	draw_line(
		Vector2(-radius, radius * 0.32),
		Vector2(radius, radius * 0.32),
		accent_color.darkened(0.18),
		4.0,
		true
	)

func _draw_wreck() -> void:
	var half_size := obstacle_size * 0.5
	var points := PackedVector2Array([
		Vector2(-half_size.x, half_size.y * 0.45),
		Vector2(-half_size.x * 0.62, -half_size.y),
		Vector2(half_size.x * 0.72, -half_size.y * 0.64),
		Vector2(half_size.x, half_size.y * 0.62),
		Vector2(0.0, half_size.y)
	])
	draw_colored_polygon(points, primary_color.darkened(0.22))
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, accent_color, 3.0, true)
	draw_line(
		Vector2(-half_size.x * 0.55, 0.0),
		Vector2(half_size.x * 0.62, -half_size.y * 0.20),
		primary_color.lightened(0.20),
		4.0,
		true
	)

func _draw_boundary() -> void:
	var half_size := obstacle_size * 0.5
	draw_rect(Rect2(-half_size, obstacle_size), primary_color.darkened(0.38), true)
	for index in range(7):
		var ratio := float(index) / 6.0
		var x_position := lerpf(-half_size.x, half_size.x, ratio)
		draw_line(
			Vector2(x_position, -half_size.y),
			Vector2(x_position, half_size.y),
			Color(accent_color, 0.52),
			3.0,
			true
		)
	draw_line(
		Vector2(-half_size.x, 0.0),
		Vector2(half_size.x, 0.0),
		accent_color,
		5.0,
		true
	)
