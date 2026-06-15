extends Node
class_name ProjectileSystem

signal projectile_spawned(projectile: Node)
signal projectile_impacted(projectile: Node, target: Node, applied_damage: int)

@export var default_projectile_scene: PackedScene = preload("res://game/projectiles/projectile.tscn")

func _ready() -> void:
	add_to_group("projectile_system")

func spawn_projectile(
	origin: Vector2,
	direction: Vector2,
	speed: float,
	owner_ref: Node = null,
	projectile_scene: PackedScene = null,
	damage: int = 1,
	source_id: StringName = &"projectile"
) -> Node:
	var scene := projectile_scene if projectile_scene != null else default_projectile_scene
	if scene == null:
		return null

	var projectile := scene.instantiate()
	if projectile is Node2D:
		(projectile as Node2D).global_position = origin
	if projectile.has_method("launch"):
		projectile.launch(direction.normalized(), speed, owner_ref, damage, source_id)
	if projectile.has_signal("impacted"):
		projectile.connect(
			"impacted",
			Callable(self, "_on_projectile_impacted").bind(projectile)
		)

	var root := get_tree().current_scene
	if root != null:
		root.add_child(projectile)

	projectile_spawned.emit(projectile)
	return projectile

func _on_projectile_impacted(
	target: Node,
	applied_damage: int,
	projectile: Node
) -> void:
	projectile_impacted.emit(projectile, target, applied_damage)
