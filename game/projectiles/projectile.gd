extends Area2D
class_name Projectile

signal impacted(target: Node, applied_damage: int)

@export var damage: int = 10
@export var lifetime: float = 1.25

@onready var visual := get_node_or_null("Visual") as Polygon2D
@onready var glow := get_node_or_null("Glow") as Polygon2D
@onready var trail := get_node_or_null("Trail") as Line2D
@onready var collision_shape := get_node_or_null("CollisionShape2D") as CollisionShape2D

var velocity: Vector2 = Vector2.ZERO
var owner_node: Node
var source_id: StringName = &"projectile"
var visual_data: WeaponVisualData
var hitbox_type: StringName = &"circle"
var hitbox_size: Vector2 = Vector2(8.0, 8.0)
var max_hit_count: int = 1
var hit_targets: Dictionary = {}
var glow_intensity: float = 1.0
var trail_intensity: float = 1.0
var default_glow_color: Color
var default_trail_color: Color
var default_trail_width: float = 4.0
var arc_height: float = 0.0
var arc_elapsed: float = 0.0
var arc_total_duration: float = 0.0

func _ready() -> void:
	add_to_group("visual_settings_consumers")
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	if glow != null:
		default_glow_color = glow.color
	if trail != null:
		default_trail_color = trail.default_color
		default_trail_width = trail.width
	VisualSettingsManager.sync_consumer(self)
	_apply_visual_data()
	_apply_hitbox_data()

func apply_visual_settings(settings: Dictionary) -> void:
	glow_intensity = clampf(
		float(settings.get("glow_intensity", 1.0)),
		0.0,
		1.0
	)
	trail_intensity = clampf(
		float(settings.get("trail_intensity", 1.0)),
		0.0,
		1.0
	)
	if is_node_ready():
		_apply_visual_data()

func launch(
	direction: Vector2,
	speed: float,
	owner_ref: Node = null,
	damage_amount: int = 10,
	damage_source_id: StringName = &"projectile",
	projectile_visual_data: WeaponVisualData = null,
	max_range: float = 0.0,
	projectile_hitbox_type: StringName = &"circle",
	projectile_hitbox_size: Vector2 = Vector2(8.0, 8.0),
	projectile_max_hit_count: int = 1
) -> void:
	velocity = direction.normalized() * speed
	owner_node = owner_ref
	damage = damage_amount
	source_id = damage_source_id
	visual_data = projectile_visual_data
	hitbox_type = projectile_hitbox_type
	hitbox_size = projectile_hitbox_size
	max_hit_count = maxi(projectile_max_hit_count, 1)
	if max_range > 0.0:
		lifetime = (
			max_range / maxf(speed, 1.0)
			if speed > 0.0
			else minf(lifetime, 0.15)
		)
	rotation = direction.angle()
	if is_node_ready():
		_apply_visual_data()
		_apply_hitbox_data()

func get_muzzle_color() -> Color:
	if visual_data != null:
		return visual_data.muzzle_color
	if String(source_id).begins_with("boss"):
		return Color(0.92, 0.30, 0.92, 1.0)
	return Color(1.0, 0.72, 0.20, 1.0)

func get_muzzle_size() -> float:
	return visual_data.muzzle_size if visual_data != null else 7.0

func set_arc_height(value: float) -> void:
	arc_height = maxf(value, 0.0)
	arc_elapsed = 0.0
	arc_total_duration = maxf(lifetime, 0.01)

func _physics_process(delta: float) -> void:
	global_position += velocity * delta
	arc_elapsed += delta
	_apply_arc_visual_offset()
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _apply_arc_visual_offset() -> void:
	if arc_height <= 0.0:
		return
	var ratio := clampf(arc_elapsed / maxf(arc_total_duration, 0.01), 0.0, 1.0)
	var offset := Vector2(0.0, -sin(ratio * PI) * arc_height)
	if visual != null:
		visual.position = offset
	if glow != null:
		glow.position = offset
	if trail != null:
		trail.position = offset

func _on_body_entered(body: Node2D) -> void:
	_try_hit_target(body)

func _on_area_entered(area: Area2D) -> void:
	_try_hit_target(area)

func _try_hit_target(target: Node) -> void:
	if target == owner_node:
		return
	# A solid environment obstacle (manifest blocks_projectiles) absorbs the
	# shot regardless of remaining pierce: walls stop projectiles dead.
	if _is_projectile_blocking_obstacle(target):
		set_deferred("monitoring", false)
		queue_free()
		return
	var target_id := target.get_instance_id()
	if hit_targets.has(target_id):
		return

	var applied_damage := 0
	var health_system = get_tree().get_first_node_in_group("health_system")
	if health_system != null and health_system.has_method("apply_damage"):
		applied_damage = health_system.apply_damage(
			target,
			damage,
			owner_node,
			source_id,
			global_position
		)
	else:
		var health_component := target.get_node_or_null("HealthComponent")
		if health_component != null and health_component.has_method("apply_damage"):
			applied_damage = health_component.apply_damage(damage)
	impacted.emit(target, applied_damage)
	hit_targets[target_id] = true
	if hit_targets.size() >= max_hit_count:
		set_deferred("monitoring", false)
		queue_free()

func _is_projectile_blocking_obstacle(target: Node) -> bool:
	return (
		target != null
		and target.is_in_group("environment_obstacles")
		and target.has_method("is_projectile_blocker")
		and bool(target.is_projectile_blocker())
	)

func _apply_visual_data() -> void:
	var base_glow_color := default_glow_color
	var base_trail_color := default_trail_color
	var base_trail_width_value := default_trail_width
	var base_trail_length := 16.0
	if visual != null:
		if visual_data != null:
			visual.color = visual_data.projectile_color
			visual.scale = visual_data.projectile_scale
			visual.polygon = _projectile_polygon(visual_data.profile_id)
	if glow != null:
		if visual_data != null:
			base_glow_color = visual_data.projectile_glow_color
			glow.scale = visual_data.projectile_scale
			glow.polygon = _glow_polygon(visual_data.profile_id)
		glow.color = Color(
			base_glow_color,
			base_glow_color.a * glow_intensity
		)
		glow.visible = glow_intensity > 0.01
	if trail != null:
		if visual_data != null:
			base_trail_color = visual_data.projectile_glow_color
			base_trail_width_value = visual_data.trail_width
			base_trail_length = visual_data.trail_length
		trail.points = PackedVector2Array([
			Vector2(-base_trail_length, 0.0),
			Vector2(-3.0, 0.0)
		])
		trail.width = base_trail_width_value * maxf(trail_intensity, 0.05)
		trail.default_color = Color(
			base_trail_color,
			base_trail_color.a * trail_intensity
		)
		trail.visible = trail_intensity > 0.01

func _projectile_polygon(profile_id: StringName) -> PackedVector2Array:
	match profile_id:
		&"prototype_blaster":
			return PackedVector2Array([
				Vector2(-8.0, 0.0),
				Vector2(-2.0, -5.0),
				Vector2(10.0, 0.0),
				Vector2(-2.0, 5.0)
			])
		&"wave_cannon":
			return PackedVector2Array([
				Vector2(-10.0, -5.5),
				Vector2(4.0, -4.0),
				Vector2(12.0, 0.0),
				Vector2(4.0, 4.0),
				Vector2(-10.0, 5.5),
				Vector2(-5.0, 0.0)
			])
		&"defense_tower":
			return PackedVector2Array([
				Vector2(-7.0, -4.0),
				Vector2(9.0, -2.5),
				Vector2(12.0, 0.0),
				Vector2(9.0, 2.5),
				Vector2(-7.0, 4.0)
			])
		&"boss_aimed":
			return PackedVector2Array([
				Vector2(-10.0, -5.0),
				Vector2(2.0, -5.0),
				Vector2(12.0, 0.0),
				Vector2(2.0, 5.0),
				Vector2(-10.0, 5.0),
				Vector2(-5.0, 0.0)
			])
		&"boss_radial":
			return PackedVector2Array([
				Vector2(-8.0, 0.0),
				Vector2(-3.0, -6.0),
				Vector2(5.0, -5.0),
				Vector2(10.0, 0.0),
				Vector2(5.0, 5.0),
				Vector2(-3.0, 6.0)
			])
		&"enemy_shooter":
			return PackedVector2Array([
				Vector2(-8.0, -3.0),
				Vector2(-2.0, -5.0),
				Vector2(9.0, 0.0),
				Vector2(-2.0, 5.0),
				Vector2(-8.0, 3.0)
			])
		&"rpg_bow":
			return PackedVector2Array([
				Vector2(-13.0, -2.0),
				Vector2(12.0, 0.0),
				Vector2(-13.0, 2.0),
				Vector2(-8.0, 0.0)
			])
		&"rpg_pistol":
			return PackedVector2Array([
				Vector2(-4.5, -3.5),
				Vector2(5.5, -3.5),
				Vector2(7.0, 0.0),
				Vector2(5.5, 3.5),
				Vector2(-4.5, 3.5)
			])
		&"rpg_axe":
			return PackedVector2Array([
				Vector2(-10.0, -8.0),
				Vector2(8.0, -10.0),
				Vector2(13.0, 0.0),
				Vector2(8.0, 10.0),
				Vector2(-10.0, 8.0),
				Vector2(-4.0, 0.0)
			])
		&"rpg_sword":
			return PackedVector2Array([
				Vector2(-8.0, -5.0),
				Vector2(10.0, -4.0),
				Vector2(15.0, 0.0),
				Vector2(10.0, 4.0),
				Vector2(-8.0, 5.0)
			])
		&"rift_lane", &"rift_repeater":
			return PackedVector2Array([
				Vector2(-9.0, -3.5),
				Vector2(4.0, -3.0),
				Vector2(11.0, 0.0),
				Vector2(4.0, 3.0),
				Vector2(-9.0, 3.5),
				Vector2(-4.0, 0.0)
			])
		&"rift_cross":
			return PackedVector2Array([
				Vector2(-7.0, -5.0),
				Vector2(0.0, -3.0),
				Vector2(9.0, 0.0),
				Vector2(0.0, 3.0),
				Vector2(-7.0, 5.0),
				Vector2(-3.0, 0.0)
			])
		_:
			return PackedVector2Array([
				Vector2(-6.0, -3.0),
				Vector2(8.0, 0.0),
				Vector2(-6.0, 3.0)
			])

func _glow_polygon(profile_id: StringName) -> PackedVector2Array:
	var points := _projectile_polygon(profile_id)
	for index in range(points.size()):
		points[index] *= 1.65
	return points

func _apply_hitbox_data() -> void:
	if collision_shape == null:
		return
	collision_shape.rotation = 0.0
	match hitbox_type:
		&"rectangle":
			var rectangle := RectangleShape2D.new()
			rectangle.size = Vector2(
				maxf(hitbox_size.x, 1.0),
				maxf(hitbox_size.y, 1.0)
			)
			collision_shape.shape = rectangle
		&"capsule":
			var capsule := CapsuleShape2D.new()
			capsule.radius = maxf(hitbox_size.x * 0.5, 1.0)
			capsule.height = maxf(hitbox_size.y, hitbox_size.x)
			collision_shape.rotation = PI * 0.5
			collision_shape.shape = capsule
		&"arc":
			var arc := ConvexPolygonShape2D.new()
			arc.points = _arc_hitbox_points(
				maxf(hitbox_size.x, 1.0),
				maxf(hitbox_size.y, 1.0)
			)
			collision_shape.shape = arc
		_:
			var circle := CircleShape2D.new()
			circle.radius = maxf(hitbox_size.x * 0.5, 1.0)
			collision_shape.shape = circle

func _arc_hitbox_points(range_value: float, width_value: float) -> PackedVector2Array:
	var points := PackedVector2Array([Vector2.ZERO])
	var half_angle := atan2(width_value * 0.5, maxf(range_value, 1.0))
	for index in range(7):
		var ratio := float(index) / 6.0
		var angle := lerpf(-half_angle, half_angle, ratio)
		points.append(Vector2(cos(angle), sin(angle)) * range_value)
	return points
