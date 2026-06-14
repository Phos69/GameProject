extends Area2D
class_name Projectile

@export var damage: int = 10
@export var lifetime: float = 1.25

var velocity: Vector2 = Vector2.ZERO
var owner_node: Node

func launch(direction: Vector2, speed: float, owner_ref: Node = null) -> void:
	velocity = direction.normalized() * speed
	owner_node = owner_ref
	rotation = direction.angle()

func _physics_process(delta: float) -> void:
	global_position += velocity * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
