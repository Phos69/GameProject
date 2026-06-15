extends Area2D
class_name Projectile

signal impacted(target: Node, applied_damage: int)

@export var damage: int = 10
@export var lifetime: float = 1.25

var velocity: Vector2 = Vector2.ZERO
var owner_node: Node
var source_id: StringName = &"projectile"
var has_hit: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func launch(
	direction: Vector2,
	speed: float,
	owner_ref: Node = null,
	damage_amount: int = 10,
	damage_source_id: StringName = &"projectile"
) -> void:
	velocity = direction.normalized() * speed
	owner_node = owner_ref
	damage = damage_amount
	source_id = damage_source_id
	rotation = direction.angle()

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
