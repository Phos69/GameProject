extends StaticBody2D
class_name BiomeObstacle

# Collision layer bits, aligned with the combat contract in ARCHITECTURE.md.
# Bit 1 keeps obstacles physical blockers for player/zombie movement; bit 6
# (value 32) is the dedicated environment layer that projectiles read to stop
# at solid walls without colliding with the player (layer 1) directly.
const MOVEMENT_BLOCK_LAYER_BIT := 1
const PROJECTILE_BLOCK_LAYER_BIT := 32

var obstacle_id: StringName = &"small_rock"
var obstacle_category: StringName = &"rock"
var draw_mode: StringName = &"rock"
var dedicated_draw: bool = true
var obstacle_size: Vector2 = Vector2(48.0, 40.0)
var shape_id: StringName = &"rectangle"
var collision_shape_id: StringName = &"rectangle"
var blocks_movement: bool = true
var projectile_blocking: bool = true
var jumpable: bool = false
# Stable identity for the regeneration-deterministic layout; future destructible
# ledgers (PersistentWorldState.destroyed_obstacles) can key persistence on it.
var obstacle_key: StringName = &""
var primary_color: Color = Color(0.38, 0.30, 0.16, 1.0)
var accent_color: Color = Color(0.74, 0.58, 0.16, 0.82)
var sort_offset: float = 0.0

func configure(
	next_obstacle_id: StringName,
	next_size: Vector2,
	next_shape_id: StringName,
	rotation_radians: float,
	base_color: Color,
	detail_color: Color,
	next_sort_offset: float = 0.0
) -> void:
	obstacle_id = next_obstacle_id
	var manifest := IsometricEnvironmentManifest.get_shared()
	obstacle_category = manifest.get_category(obstacle_id)
	draw_mode = manifest.get_object_draw_mode(obstacle_id)
	dedicated_draw = manifest.object_has_dedicated_draw(obstacle_id)
	blocks_movement = manifest.blocks_movement(obstacle_id)
	projectile_blocking = manifest.blocks_projectiles(obstacle_id)
	jumpable = manifest.is_jumpable_gap_anchor(obstacle_id)
	obstacle_size = Vector2(
		maxf(next_size.x, 12.0),
		maxf(next_size.y, 12.0)
	)
	# The manifest collision_shape is authoritative; the layout shape only acts
	# as a fallback for shapes the runtime does not build directly.
	collision_shape_id = _resolve_collision_shape(
		manifest.get_collision_shape(obstacle_id),
		next_shape_id
	)
	shape_id = collision_shape_id
	rotation = rotation_radians
	primary_color = base_color
	accent_color = detail_color
	sort_offset = next_sort_offset
	collision_layer = 0
	if blocks_movement:
		collision_layer |= MOVEMENT_BLOCK_LAYER_BIT
	if projectile_blocking:
		collision_layer |= PROJECTILE_BLOCK_LAYER_BIT
	collision_mask = 0
	# z_index 0 so obstacles take part in the World Y-sort together with zombies
	# and pickups instead of flatly covering them.
	z_index = 0
	set_meta("zone_radius", get_clearance_radius())
	_rebuild_collision()
	queue_redraw()

func _ready() -> void:
	add_to_group("environment_obstacles")
	add_to_group("spawn_blockers")
	if get_node_or_null("CollisionShape2D") == null:
		_rebuild_collision()

func contains_global_position(world_position: Vector2) -> bool:
	if collision_shape_id == &"open":
		return false
	var local_position := to_local(world_position)
	if collision_shape_id == &"circle":
		var radius := obstacle_size.x * 0.5
		return local_position.length_squared() <= radius * radius
	var half_size := obstacle_size * 0.5
	return (
		absf(local_position.x) <= half_size.x
		and absf(local_position.y) <= half_size.y
	)

func get_clearance_radius() -> float:
	return maxf(obstacle_size.x, obstacle_size.y) * 0.58

func get_obstacle_category() -> StringName:
	return obstacle_category

func get_draw_mode() -> StringName:
	return draw_mode

func has_dedicated_draw() -> bool:
	return dedicated_draw

func uses_generic_fallback() -> bool:
	return draw_mode == &"generic_barrier" and not dedicated_draw

func has_ground_shadow() -> bool:
	return true

func is_projectile_blocker() -> bool:
	return projectile_blocking

func is_jumpable_obstacle() -> bool:
	return jumpable

func get_obstacle_key() -> StringName:
	return obstacle_key

func _resolve_collision_shape(
	manifest_shape: StringName,
	layout_shape: StringName
) -> StringName:
	match manifest_shape:
		&"circle":
			return &"circle"
		&"rectangle":
			return &"rectangle"
		&"open":
			return &"open"
		_:
			# rectangle_area / circle_or_rectangle / unknown: keep the layout
			# choice so existing area/crate-style entries stay unchanged.
			return &"circle" if layout_shape == &"circle" else &"rectangle"

func _rebuild_collision() -> void:
	var collision_shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null:
		collision_shape = CollisionShape2D.new()
		collision_shape.name = "CollisionShape2D"
		add_child(collision_shape)
	if collision_shape_id == &"open":
		collision_shape.disabled = true
		return
	collision_shape.disabled = false
	if collision_shape_id == &"circle":
		var circle := CircleShape2D.new()
		circle.radius = obstacle_size.x * 0.5
		collision_shape.shape = circle
		return
	var rectangle := RectangleShape2D.new()
	rectangle.size = obstacle_size
	collision_shape.shape = rectangle

func _draw() -> void:
	_draw_ground_shadow()
	match draw_mode:
		&"rock":
			_draw_rock()
		&"fence":
			_draw_fence()
		&"reed_wall":
			_draw_reed_wall()
		&"wood_barrier":
			_draw_wood_barrier()
		&"scorched_barricade":
			_draw_scorched_barricade()
		&"ash_barrier":
			_draw_ash_barrier()
		&"lab_wall":
			_draw_lab_wall()
		&"charred_wall":
			_draw_charred_wall()
		&"snow_wall":
			_draw_snow_wall()
		&"ruined_house":
			_draw_ruined_house()
		&"burned_house":
			_draw_burned_house()
		&"lab_block":
			_draw_lab_block()
		&"snow_cabin":
			_draw_snow_cabin()
		&"sunken_house":
			_draw_sunken_house()
		&"barrel":
			_draw_barrel()
		&"toxic_barrel":
			_draw_toxic_barrel()
		&"wreck":
			_draw_wreck()
		&"burned_car":
			_draw_burned_car()
		&"pipe_stack":
			_draw_pipe_stack()
		&"ice_block":
			_draw_ice_block()
		&"dead_tree":
			_draw_dead_tree()
		&"log":
			_draw_log()
		&"marsh_log":
			_draw_marsh_log()
		&"bridge":
			_draw_bridge()
		&"broken_walkway":
			_draw_broken_walkway()
		&"boundary":
			_draw_boundary()
		&"toxic_boundary_wall":
			_draw_toxic_boundary_wall()
		&"lava_boundary":
			_draw_lava_boundary()
		&"ice_boundary":
			_draw_ice_boundary()
		&"deep_water_boundary":
			_draw_deep_water_boundary()
		_:
			_draw_barrier()

func _draw_ground_shadow() -> void:
	var shadow_y := clampf(sort_offset, 0.0, obstacle_size.y * 0.5 + 8.0)
	var radius := Vector2(
		maxf(obstacle_size.x * 0.52, 10.0),
		maxf(obstacle_size.x * 0.16, 5.0)
	)
	draw_colored_polygon(
		_ellipse_points(Vector2(0.0, shadow_y), radius, 18),
		Color(0.02, 0.03, 0.04, 0.34)
	)

func _ellipse_points(center: Vector2, radius: Vector2, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(segments):
		var angle := TAU * float(index) / float(segments)
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	return points

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

func _draw_reed_wall() -> void:
	var half_size := obstacle_size * 0.5
	draw_rect(
		Rect2(Vector2(-half_size.x, half_size.y * 0.18), Vector2(obstacle_size.x, 7.0)),
		primary_color.darkened(0.18),
		true
	)
	var reed_count := maxi(5, int(obstacle_size.x / 10.0))
	for index in range(reed_count):
		var ratio := float(index) / maxf(float(reed_count - 1), 1.0)
		var x_position := lerpf(-half_size.x + 4.0, half_size.x - 4.0, ratio)
		var height := half_size.y * (1.35 if index % 2 == 0 else 1.05)
		draw_line(
			Vector2(x_position, half_size.y * 0.34),
			Vector2(x_position + sin(float(index)) * 2.0, -height),
			primary_color.lightened(0.08),
			4.0,
			true
		)
	draw_line(
		Vector2(-half_size.x, -half_size.y * 0.18),
		Vector2(half_size.x, half_size.y * 0.10),
		accent_color.darkened(0.16),
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

func _draw_wood_barrier() -> void:
	_draw_barrier()
	var half_size := obstacle_size * 0.5
	for offset in [-half_size.y * 0.28, half_size.y * 0.22]:
		draw_line(
			Vector2(-half_size.x + 8.0, offset),
			Vector2(half_size.x - 8.0, offset + 4.0),
			accent_color.darkened(0.18),
			3.0,
			true
		)

func _draw_scorched_barricade() -> void:
	var half_size := obstacle_size * 0.5
	draw_rect(
		Rect2(Vector2(-half_size.x, -half_size.y * 0.35), Vector2(obstacle_size.x, half_size.y * 0.7)),
		primary_color.darkened(0.36),
		true
	)
	for index in range(5):
		var ratio := float(index) / 4.0
		var x_position := lerpf(-half_size.x, half_size.x, ratio)
		draw_colored_polygon(
			PackedVector2Array([
				Vector2(x_position - 5.0, -half_size.y * 0.35),
				Vector2(x_position + 5.0, -half_size.y * 0.35),
				Vector2(x_position, -half_size.y)
			]),
			primary_color.darkened(0.18)
		)
	draw_line(
		Vector2(-half_size.x + 7.0, half_size.y * 0.12),
		Vector2(half_size.x - 7.0, -half_size.y * 0.12),
		accent_color,
		3.0,
		true
	)

func _draw_ash_barrier() -> void:
	var half_size := obstacle_size * 0.5
	var segment_width := obstacle_size.x / 4.0
	for index in range(4):
		var center_x := -half_size.x + segment_width * (float(index) + 0.5)
		var radius := Vector2(segment_width * 0.48, half_size.y * 0.62)
		draw_colored_polygon(
			_ellipse_points(Vector2(center_x, 0.0), radius, 14),
			primary_color.darkened(0.18 + float(index % 2) * 0.08)
		)
	draw_line(
		Vector2(-half_size.x + 6.0, half_size.y * 0.18),
		Vector2(half_size.x - 6.0, half_size.y * 0.05),
		accent_color.darkened(0.25),
		3.0,
		true
	)

func _draw_lab_wall() -> void:
	var half_size := obstacle_size * 0.5
	draw_rect(Rect2(-half_size, obstacle_size), primary_color.darkened(0.22), true)
	draw_rect(
		Rect2(Vector2(-half_size.x + 4.0, -half_size.y + 4.0), Vector2(obstacle_size.x - 8.0, obstacle_size.y - 8.0)),
		primary_color.darkened(0.04),
		true
	)
	for index in range(1, 4):
		var x_position := lerpf(-half_size.x + 8.0, half_size.x - 8.0, float(index) / 4.0)
		draw_line(
			Vector2(x_position, -half_size.y + 5.0),
			Vector2(x_position, half_size.y - 5.0),
			primary_color.darkened(0.28),
			2.0,
			true
		)
	draw_line(
		Vector2(-half_size.x + 8.0, 0.0),
		Vector2(half_size.x - 8.0, 0.0),
		accent_color,
		3.0,
		true
	)

func _draw_charred_wall() -> void:
	var half_size := obstacle_size * 0.5
	draw_rect(Rect2(-half_size, obstacle_size), primary_color.darkened(0.42), true)
	for index in range(4):
		var ratio := float(index) / 3.0
		var x_position := lerpf(-half_size.x + 6.0, half_size.x - 6.0, ratio)
		draw_line(
			Vector2(x_position, -half_size.y + 3.0),
			Vector2(x_position + 8.0, half_size.y - 3.0),
			accent_color.darkened(0.08),
			2.0,
			true
		)
	draw_line(
		Vector2(-half_size.x, half_size.y * 0.32),
		Vector2(half_size.x, half_size.y * 0.20),
		primary_color.lightened(0.12),
		2.0,
		true
	)

func _draw_snow_wall() -> void:
	var half_size := obstacle_size * 0.5
	draw_rect(Rect2(-half_size, obstacle_size), primary_color.darkened(0.08), true)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(-half_size.x, -half_size.y * 0.35),
			Vector2(-half_size.x * 0.45, -half_size.y),
			Vector2(half_size.x * 0.15, -half_size.y * 0.62),
			Vector2(half_size.x, -half_size.y * 0.88),
			Vector2(half_size.x, -half_size.y * 0.15),
			Vector2(-half_size.x, half_size.y * 0.12)
		]),
		primary_color.lightened(0.24)
	)
	draw_line(
		Vector2(-half_size.x + 8.0, half_size.y * 0.10),
		Vector2(half_size.x - 8.0, half_size.y * 0.30),
		accent_color,
		2.0,
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

func _draw_burned_house() -> void:
	_draw_ruined_house()
	var half_size := obstacle_size * 0.5
	for index in range(4):
		var x_position := lerpf(-half_size.x * 0.62, half_size.x * 0.62, float(index) / 3.0)
		draw_line(
			Vector2(x_position, -half_size.y + 6.0),
			Vector2(x_position + 8.0, half_size.y - 8.0),
			Color(0.06, 0.045, 0.035, 1.0),
			3.0,
			true
		)

func _draw_lab_block() -> void:
	var half_size := obstacle_size * 0.5
	draw_rect(Rect2(-half_size, obstacle_size), primary_color.darkened(0.24), true)
	draw_rect(
		Rect2(Vector2(-half_size.x + 8.0, -half_size.y + 8.0), Vector2(obstacle_size.x - 16.0, obstacle_size.y - 16.0)),
		primary_color.darkened(0.02),
		true
	)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(-half_size.x + 8.0, -half_size.y + 8.0),
			Vector2(-half_size.x * 0.08, -half_size.y - 14.0),
			Vector2(half_size.x - 6.0, -half_size.y + 8.0),
			Vector2(half_size.x - 14.0, -half_size.y + 22.0),
			Vector2(-half_size.x + 16.0, -half_size.y + 22.0)
		]),
		primary_color.lightened(0.08)
	)
	for index in range(3):
		var x_position := lerpf(-half_size.x + 14.0, half_size.x - 14.0, float(index) / 2.0)
		draw_rect(
			Rect2(Vector2(x_position - 5.0, -half_size.y + 28.0), Vector2(10.0, 12.0)),
			accent_color.darkened(0.24),
			true
		)
	draw_line(
		Vector2(-half_size.x + 12.0, half_size.y - 12.0),
		Vector2(half_size.x - 12.0, half_size.y - 12.0),
		accent_color,
		3.0,
		true
	)

func _draw_snow_cabin() -> void:
	var half_size := obstacle_size * 0.5
	draw_rect(Rect2(-half_size, obstacle_size), primary_color.darkened(0.18), true)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(-half_size.x - 8.0, -half_size.y + 12.0),
			Vector2(0.0, -half_size.y - 24.0),
			Vector2(half_size.x + 8.0, -half_size.y + 12.0),
			Vector2(half_size.x * 0.72, -half_size.y + 24.0),
			Vector2(-half_size.x * 0.72, -half_size.y + 24.0)
		]),
		primary_color.lightened(0.26)
	)
	draw_rect(
		Rect2(Vector2(-10.0, half_size.y * 0.05), Vector2(20.0, half_size.y * 0.76)),
		primary_color.darkened(0.36),
		true
	)
	draw_line(
		Vector2(-half_size.x + 12.0, -half_size.y + 4.0),
		Vector2(half_size.x - 12.0, -half_size.y + 28.0),
		accent_color,
		2.0,
		true
	)

func _draw_sunken_house() -> void:
	var half_size := obstacle_size * 0.5
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(-half_size.x, -half_size.y * 0.55),
			Vector2(half_size.x * 0.82, -half_size.y * 0.42),
			Vector2(half_size.x, half_size.y * 0.62),
			Vector2(-half_size.x * 0.72, half_size.y)
		]),
		primary_color.darkened(0.24)
	)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(-half_size.x - 4.0, -half_size.y * 0.55),
			Vector2(-half_size.x * 0.18, -half_size.y - 18.0),
			Vector2(half_size.x * 0.92, -half_size.y * 0.42),
			Vector2(half_size.x * 0.62, -half_size.y * 0.02),
			Vector2(-half_size.x * 0.70, -half_size.y * 0.14)
		]),
		primary_color.darkened(0.04)
	)
	draw_line(
		Vector2(-half_size.x + 4.0, half_size.y * 0.34),
		Vector2(half_size.x - 4.0, half_size.y * 0.20),
		accent_color,
		3.0,
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

func _draw_toxic_barrel() -> void:
	_draw_barrel()
	var radius := minf(obstacle_size.x, obstacle_size.y) * 0.34
	for index in range(3):
		var angle := TAU * float(index) / 3.0 - PI * 0.5
		draw_line(
			Vector2.ZERO,
			Vector2(cos(angle), sin(angle)) * radius,
			accent_color.lightened(0.18),
			3.0,
			true
		)
	draw_circle(Vector2.ZERO, radius * 0.28, primary_color.darkened(0.30))

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

func _draw_burned_car() -> void:
	var half_size := obstacle_size * 0.5
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(-half_size.x, half_size.y * 0.30),
			Vector2(-half_size.x * 0.74, -half_size.y * 0.36),
			Vector2(-half_size.x * 0.18, -half_size.y * 0.55),
			Vector2(half_size.x * 0.56, -half_size.y * 0.28),
			Vector2(half_size.x, half_size.y * 0.24),
			Vector2(half_size.x * 0.62, half_size.y * 0.62),
			Vector2(-half_size.x * 0.72, half_size.y * 0.62)
		]),
		primary_color.darkened(0.34)
	)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(-half_size.x * 0.26, -half_size.y * 0.52),
			Vector2(half_size.x * 0.16, -half_size.y * 0.72),
			Vector2(half_size.x * 0.46, -half_size.y * 0.22),
			Vector2(-half_size.x * 0.06, -half_size.y * 0.10)
		]),
		Color(0.06, 0.065, 0.055, 1.0)
	)
	for x_position in [-half_size.x * 0.54, half_size.x * 0.54]:
		draw_circle(Vector2(x_position, half_size.y * 0.56), half_size.y * 0.18, Color(0.025, 0.025, 0.025, 1.0))
	draw_line(
		Vector2(-half_size.x * 0.62, half_size.y * 0.06),
		Vector2(half_size.x * 0.58, -half_size.y * 0.06),
		accent_color.darkened(0.28),
		3.0,
		true
	)

func _draw_pipe_stack() -> void:
	var half_size := obstacle_size * 0.5
	var pipe_height := maxf(obstacle_size.y * 0.22, 6.0)
	var cap_radius := Vector2(maxf(pipe_height * 0.72, 4.0), pipe_height * 0.5)
	var offsets: Array[float] = [-pipe_height, 0.0, pipe_height]
	for index in range(offsets.size()):
		var y_position := offsets[index]
		var shade := 0.08 * float(index)
		draw_rect(
			Rect2(
				Vector2(-half_size.x + cap_radius.x, y_position - pipe_height * 0.5),
				Vector2(obstacle_size.x - cap_radius.x * 2.0, pipe_height)
			),
			primary_color.darkened(0.18 + shade),
			true
		)
		draw_colored_polygon(
			_ellipse_points(Vector2(-half_size.x + cap_radius.x, y_position), cap_radius, 16),
			primary_color.darkened(0.28 + shade)
		)
		draw_colored_polygon(
			_ellipse_points(Vector2(half_size.x - cap_radius.x, y_position), cap_radius, 16),
			primary_color.lightened(0.05 - shade * 0.3)
		)
	draw_line(
		Vector2(-half_size.x + 6.0, -pipe_height * 1.5),
		Vector2(half_size.x - 6.0, pipe_height * 1.5),
		accent_color,
		2.0,
		true
	)

func _draw_ice_block() -> void:
	var half_size := obstacle_size * 0.5
	var points := PackedVector2Array([
		Vector2(-half_size.x * 0.82, half_size.y * 0.55),
		Vector2(-half_size.x * 0.62, -half_size.y * 0.45),
		Vector2(-half_size.x * 0.05, -half_size.y),
		Vector2(half_size.x * 0.70, -half_size.y * 0.58),
		Vector2(half_size.x, half_size.y * 0.22),
		Vector2(half_size.x * 0.20, half_size.y)
	])
	draw_colored_polygon(points, primary_color.lightened(0.16))
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, accent_color.lightened(0.18), 2.0, true)
	draw_line(
		Vector2(-half_size.x * 0.26, -half_size.y * 0.62),
		Vector2(half_size.x * 0.20, half_size.y * 0.62),
		primary_color.lightened(0.38),
		2.0,
		true
	)
	draw_line(
		Vector2(half_size.x * 0.34, -half_size.y * 0.36),
		Vector2(-half_size.x * 0.40, half_size.y * 0.18),
		accent_color,
		2.0,
		true
	)

func _draw_dead_tree() -> void:
	var half_size := obstacle_size * 0.5
	var trunk_bottom := Vector2(0.0, half_size.y * 0.88)
	var trunk_top := Vector2(-half_size.x * 0.12, -half_size.y)
	draw_line(trunk_bottom, trunk_top, primary_color.darkened(0.32), maxf(obstacle_size.x * 0.18, 6.0), true)
	draw_line(
		Vector2(-half_size.x * 0.60, -half_size.y * 0.12),
		Vector2(half_size.x * 0.46, -half_size.y * 0.44),
		primary_color.darkened(0.20),
		5.0,
		true
	)
	draw_line(
		Vector2(-half_size.x * 0.10, -half_size.y * 0.46),
		Vector2(-half_size.x * 0.62, -half_size.y * 0.82),
		primary_color.darkened(0.24),
		4.0,
		true
	)
	draw_line(
		Vector2(half_size.x * 0.08, -half_size.y * 0.34),
		Vector2(half_size.x * 0.54, -half_size.y * 0.76),
		accent_color.darkened(0.22),
		3.0,
		true
	)
	draw_circle(trunk_bottom, maxf(obstacle_size.x * 0.18, 6.0), primary_color.darkened(0.42))

func _draw_log() -> void:
	var half_size := obstacle_size * 0.5
	var radius := Vector2(maxf(half_size.x, 10.0), maxf(half_size.y * 0.65, 5.0))
	draw_colored_polygon(_ellipse_points(Vector2.ZERO, radius, 18), primary_color.darkened(0.12))
	for x_position in [-half_size.x * 0.58, 0.0, half_size.x * 0.58]:
		draw_line(
			Vector2(x_position, -half_size.y * 0.48),
			Vector2(x_position + 5.0, half_size.y * 0.48),
			accent_color.darkened(0.16),
			3.0,
			true
		)
	draw_line(
		Vector2(-half_size.x + 6.0, 0.0),
		Vector2(half_size.x - 6.0, 0.0),
		primary_color.lightened(0.16),
		2.0,
		true
	)

func _draw_marsh_log() -> void:
	_draw_log()
	var half_size := obstacle_size * 0.5
	for index in range(3):
		var x_position := lerpf(-half_size.x * 0.55, half_size.x * 0.55, float(index) / 2.0)
		draw_circle(
			Vector2(x_position, -half_size.y * 0.16),
			maxf(half_size.y * 0.22, 3.0),
			accent_color.darkened(0.25)
		)

func _draw_bridge() -> void:
	var half_size := obstacle_size * 0.5
	draw_rect(Rect2(-half_size, obstacle_size), primary_color.darkened(0.28), true)
	var plank_count := maxi(4, int(obstacle_size.x / 18.0))
	for index in range(plank_count):
		var ratio := float(index) / float(plank_count)
		var x_position := lerpf(-half_size.x, half_size.x, ratio)
		draw_line(
			Vector2(x_position, -half_size.y),
			Vector2(x_position + 4.0, half_size.y),
			primary_color.lightened(0.08),
			2.0,
			true
		)
	draw_line(
		Vector2(-half_size.x + 4.0, -half_size.y * 0.55),
		Vector2(half_size.x - 4.0, -half_size.y * 0.36),
		accent_color.darkened(0.20),
		3.0,
		true
	)
	draw_line(
		Vector2(-half_size.x + 4.0, half_size.y * 0.48),
		Vector2(half_size.x - 4.0, half_size.y * 0.34),
		accent_color.darkened(0.20),
		3.0,
		true
	)

func _draw_broken_walkway() -> void:
	var half_size := obstacle_size * 0.5
	var plank_count := 6
	for index in range(plank_count):
		if index == 2:
			continue
		var ratio := float(index) / float(plank_count)
		var x_position := lerpf(-half_size.x, half_size.x, ratio)
		draw_rect(
			Rect2(Vector2(x_position, -half_size.y * 0.72), Vector2(obstacle_size.x / 8.0, obstacle_size.y * 1.28)),
			primary_color.darkened(0.12 + float(index % 2) * 0.07),
			true
		)
	draw_line(
		Vector2(-half_size.x + 4.0, -half_size.y * 0.50),
		Vector2(half_size.x - 4.0, -half_size.y * 0.30),
		accent_color.darkened(0.25),
		3.0,
		true
	)
	draw_line(
		Vector2(-half_size.x + 4.0, half_size.y * 0.42),
		Vector2(half_size.x - 14.0, half_size.y * 0.22),
		accent_color.darkened(0.25),
		3.0,
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

func _draw_toxic_boundary_wall() -> void:
	var half_size := obstacle_size * 0.5
	draw_rect(Rect2(-half_size, obstacle_size), primary_color.darkened(0.42), true)
	for index in range(8):
		var ratio := float(index) / 7.0
		var x_position := lerpf(-half_size.x, half_size.x, ratio)
		var stripe_color := accent_color if index % 2 == 0 else primary_color.lightened(0.18)
		draw_line(
			Vector2(x_position - 10.0, half_size.y),
			Vector2(x_position + 10.0, -half_size.y),
			Color(stripe_color, 0.62),
			4.0,
			true
		)
	draw_line(
		Vector2(-half_size.x, -half_size.y * 0.42),
		Vector2(half_size.x, -half_size.y * 0.18),
		accent_color.lightened(0.12),
		4.0,
		true
	)
	for index in range(4):
		var x_position := lerpf(-half_size.x * 0.68, half_size.x * 0.68, float(index) / 3.0)
		draw_circle(
			Vector2(x_position, half_size.y * 0.18),
			maxf(half_size.y * 0.18, 3.0),
			Color(accent_color.lightened(0.20), 0.58)
		)

func _draw_lava_boundary() -> void:
	var half_size := obstacle_size * 0.5
	draw_rect(Rect2(-half_size, obstacle_size), primary_color.darkened(0.50), true)
	var crack_points := PackedVector2Array()
	for index in range(7):
		var ratio := float(index) / 6.0
		crack_points.append(Vector2(
			lerpf(-half_size.x + 4.0, half_size.x - 4.0, ratio),
			sin(float(index) * 1.7) * half_size.y * 0.34
		))
	draw_polyline(crack_points, accent_color.lightened(0.20), 5.0, true)
	draw_polyline(crack_points, Color(1.0, 0.18, 0.04, 0.78), 2.0, true)
	for index in range(5):
		var x_position := lerpf(-half_size.x * 0.78, half_size.x * 0.78, float(index) / 4.0)
		draw_colored_polygon(
			PackedVector2Array([
				Vector2(x_position - 5.0, half_size.y * 0.36),
				Vector2(x_position + 5.0, half_size.y * 0.36),
				Vector2(x_position, -half_size.y * 0.52)
			]),
			primary_color.darkened(0.18)
		)

func _draw_ice_boundary() -> void:
	var half_size := obstacle_size * 0.5
	draw_rect(Rect2(-half_size, obstacle_size), primary_color.darkened(0.16), true)
	for index in range(6):
		var ratio := float(index) / 5.0
		var x_position := lerpf(-half_size.x, half_size.x, ratio)
		draw_colored_polygon(
			PackedVector2Array([
				Vector2(x_position - 8.0, half_size.y * 0.44),
				Vector2(x_position + 8.0, half_size.y * 0.38),
				Vector2(x_position + 3.0, -half_size.y),
				Vector2(x_position - 5.0, -half_size.y * 0.54)
			]),
			primary_color.lightened(0.24)
		)
	draw_line(
		Vector2(-half_size.x + 6.0, -half_size.y * 0.36),
		Vector2(half_size.x - 6.0, half_size.y * 0.10),
		accent_color.lightened(0.16),
		3.0,
		true
	)

func _draw_deep_water_boundary() -> void:
	var half_size := obstacle_size * 0.5
	draw_rect(Rect2(-half_size, obstacle_size), primary_color.darkened(0.34), true)
	for index in range(4):
		var y_position := lerpf(-half_size.y * 0.42, half_size.y * 0.42, float(index) / 3.0)
		var wave_points := PackedVector2Array()
		for point_index in range(9):
			var ratio := float(point_index) / 8.0
			var x_position := lerpf(-half_size.x + 4.0, half_size.x - 4.0, ratio)
			wave_points.append(Vector2(
				x_position,
				y_position + sin(ratio * TAU * 2.0 + float(index)) * 3.0
			))
		draw_polyline(wave_points, Color(accent_color.lightened(0.10), 0.72), 2.0, true)
	for index in range(5):
		var x_position := lerpf(-half_size.x * 0.78, half_size.x * 0.78, float(index) / 4.0)
		draw_line(
			Vector2(x_position, half_size.y * 0.48),
			Vector2(x_position + sin(float(index)) * 3.0, -half_size.y * 0.65),
			primary_color.lightened(0.16),
			3.0,
			true
		)
