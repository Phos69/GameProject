extends Area2D
class_name BiomeHazardZone

var hazard_id: StringName = &"toxic_puddle"
var zone_size: Vector2 = Vector2(120.0, 72.0)
var hazard_color: Color = Color(0.28, 0.95, 0.32, 0.76)
var damage_per_tick: int = 0
var tick_interval: float = 1.0
var movement_multiplier: float = 1.0
var lifetime: float = 0.0
var age: float = 0.0

func configure(
	next_hazard_id: StringName,
	next_size: Vector2,
	rotation_radians: float,
	next_color: Color,
	config: Dictionary = {}
) -> void:
	hazard_id = next_hazard_id
	zone_size = Vector2(
		maxf(next_size.x, 24.0),
		maxf(next_size.y, 20.0)
	)
	rotation = rotation_radians
	hazard_color = next_color
	damage_per_tick = maxi(int(config.get("damage", 0)), 0)
	tick_interval = maxf(float(config.get("tick_interval", 1.0)), 0.1)
	movement_multiplier = clampf(
		float(config.get("movement_multiplier", 1.0)),
		0.25,
		1.25
	)
	lifetime = maxf(float(config.get("lifetime", 0.0)), 0.0)
	collision_layer = 0
	collision_mask = GameConstants.LAYER_BODIES
	monitoring = true
	monitorable = false
	z_index = -1
	set_meta("zone_radius", maxf(zone_size.x, zone_size.y) * 0.5)
	_rebuild_collision()
	queue_redraw()

func _ready() -> void:
	add_to_group("environment_hazards")
	add_to_group("biome_hazard_zones")
	if get_node_or_null("CollisionShape2D") == null:
		_rebuild_collision()

func _process(delta: float) -> void:
	if lifetime <= 0.0:
		return
	age += delta
	if age >= lifetime:
		queue_free()
		return
	queue_redraw()

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
	var pulse := 0.86 + sin(Time.get_ticks_msec() * 0.004) * 0.08
	var fill_color := Color(hazard_color, hazard_color.a * 0.24 * pulse)
	draw_colored_polygon(_ellipse_points(half_size, 28), fill_color)
	draw_polyline(
		_closed(_ellipse_points(half_size, 28)),
		Color(hazard_color, 0.78),
		3.0,
		true
	)
	for index in range(5):
		var ratio := float(index + 1) / 6.0
		var x_position := lerpf(-half_size.x * 0.72, half_size.x * 0.72, ratio)
		draw_circle(
			Vector2(x_position, sin(float(index) * 2.1) * half_size.y * 0.32),
			3.0 + float(index % 2) * 2.0,
			Color(hazard_color.lightened(0.22), 0.62)
		)

func _ellipse_points(
	half_size: Vector2,
	segments: int
) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(segments):
		var angle := TAU * float(index) / float(segments)
		points.append(Vector2(
			cos(angle) * half_size.x,
			sin(angle) * half_size.y
		))
	return points

func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var result := points.duplicate()
	if not result.is_empty():
		result.append(result[0])
	return result
