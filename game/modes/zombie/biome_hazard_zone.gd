extends BiomeZoneArea
class_name BiomeHazardZone

var hazard_id: StringName = &"toxic_puddle"
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
	# Environment hazards share the cardinal H/V contract with solid obstacles.
	# Keep stale/generated angles only as diagnostics; never rotate art or physics.
	rotation = 0.0
	set_meta("requested_rotation_radians", rotation_radians)
	set_meta("cardinal_rotation_locked", true)
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

func _draw() -> void:
	var half_size := zone_size * 0.5
	var pulse := 0.86 + sin(Time.get_ticks_msec() * 0.004) * 0.08
	var fill_color := Color(hazard_color, hazard_color.a * 0.24 * pulse)
	draw_colored_polygon(GeometryUtils.ellipse_points(Vector2.ZERO, half_size, 28), fill_color)
	draw_polyline(
		_closed(GeometryUtils.ellipse_points(Vector2.ZERO, half_size, 28)),
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

func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var result := points.duplicate()
	if not result.is_empty():
		result.append(result[0])
	return result
