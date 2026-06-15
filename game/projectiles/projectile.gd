extends Area2D
class_name Projectile

signal impacted(target: Node, applied_damage: int)

@export var damage: int = 10
@export var lifetime: float = 1.25

@onready var visual := get_node_or_null("Visual") as Polygon2D
@onready var glow := get_node_or_null("Glow") as Polygon2D
@onready var trail := get_node_or_null("Trail") as Line2D

var velocity: Vector2 = Vector2.ZERO
var owner_node: Node
var source_id: StringName = &"projectile"
var visual_data: WeaponVisualData
var has_hit: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_apply_visual_data()

func launch(
	direction: Vector2,
	speed: float,
	owner_ref: Node = null,
	damage_amount: int = 10,
	damage_source_id: StringName = &"projectile",
	projectile_visual_data: WeaponVisualData = null
) -> void:
	velocity = direction.normalized() * speed
	owner_node = owner_ref
	damage = damage_amount
	source_id = damage_source_id
	visual_data = projectile_visual_data
	rotation = direction.angle()
	if is_node_ready():
		_apply_visual_data()

func get_muzzle_color() -> Color:
	if visual_data != null:
		return visual_data.muzzle_color
	if String(source_id).begins_with("boss"):
		return Color(0.92, 0.30, 0.92, 1.0)
	return Color(1.0, 0.72, 0.20, 1.0)

func get_muzzle_size() -> float:
	return visual_data.muzzle_size if visual_data != null else 7.0

func _physics_process(delta: float) -> void:
	global_position += velocity * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if has_hit or body == owner_node:
		return

	has_hit = true
	set_deferred("monitoring", false)
	var applied_damage := 0
	var health_system = get_tree().get_first_node_in_group("health_system")
	if health_system != null and health_system.has_method("apply_damage"):
		applied_damage = health_system.apply_damage(body, damage)
	else:
		var health_component := body.get_node_or_null("HealthComponent")
		if health_component != null and health_component.has_method("apply_damage"):
			applied_damage = health_component.apply_damage(damage)
	impacted.emit(body, applied_damage)
	queue_free()

func _apply_visual_data() -> void:
	if visual_data == null:
		return
	if visual != null:
		visual.color = visual_data.projectile_color
		visual.scale = visual_data.projectile_scale
		visual.polygon = _projectile_polygon(visual_data.profile_id)
	if glow != null:
		glow.color = visual_data.projectile_glow_color
		glow.scale = visual_data.projectile_scale
		glow.polygon = _glow_polygon(visual_data.profile_id)
	if trail != null:
		trail.points = PackedVector2Array([
			Vector2(-visual_data.trail_length, 0.0),
			Vector2(-3.0, 0.0)
		])
		trail.width = visual_data.trail_width
		trail.default_color = visual_data.projectile_glow_color

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
