extends Area2D
class_name BiomeZoneArea

# Base condivisa per le aree rettangolari cardinali dei biomi (fall zone e
# hazard zone): dimensione, test punto/distanza e collisione rettangolare
# erano duplicati identici nelle due classi (gruppo 4.3 del report repo
# health). Le sottoclassi impostano zone_size in configure()/_init().

var zone_size: Vector2 = Vector2(120.0, 72.0)

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
