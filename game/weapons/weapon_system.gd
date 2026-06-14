extends Node2D
class_name WeaponSystem

signal fired(origin: Vector2, direction: Vector2)
signal fire_blocked(reason: StringName)

@export var fire_rate: float = 7.0
@export var projectile_speed: float = 620.0
@export var projectile_scene: PackedScene = preload("res://game/projectiles/projectile.tscn")

var cooldown: float = 0.0

func _process(delta: float) -> void:
	cooldown = maxf(cooldown - delta, 0.0)

func try_fire(origin: Vector2, direction: Vector2, owner_ref: Node = null) -> bool:
	if direction.length_squared() <= 0.01:
		fire_blocked.emit(&"no_direction")
		return false
	if cooldown > 0.0:
		fire_blocked.emit(&"cooldown")
		return false

	cooldown = 1.0 / maxf(fire_rate, 0.01)
	var normalized_direction := direction.normalized()
	fired.emit(origin, normalized_direction)

	if projectile_scene != null:
		var projectile_system = get_tree().get_first_node_in_group("projectile_system")
		if projectile_system != null and projectile_system.has_method("spawn_projectile"):
			projectile_system.spawn_projectile(origin, normalized_direction, projectile_speed, owner_ref, projectile_scene)
		else:
			var projectile := projectile_scene.instantiate()
			if projectile is Node2D:
				(projectile as Node2D).global_position = origin
			if projectile.has_method("launch"):
				projectile.launch(normalized_direction, projectile_speed, owner_ref)
			var root := get_tree().current_scene
			if root != null:
				root.add_child(projectile)

	return true
