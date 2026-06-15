extends Area2D
class_name BiomeTransitionGate

var target_biome_id: StringName = &""
var direction_id: StringName = &"east"
var gate_size: Vector2 = Vector2(76.0, 190.0)
var gate_color: Color = Color(0.42, 0.90, 0.58, 1.0)

func configure(
	next_target_biome_id: StringName,
	next_direction_id: StringName,
	next_position: Vector2,
	next_color: Color
) -> void:
	target_biome_id = next_target_biome_id
	direction_id = next_direction_id
	position = next_position
	gate_color = next_color
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	monitorable = false
	z_index = -1
	_rebuild_collision()
	queue_redraw()

func _ready() -> void:
	add_to_group("biome_transition_gates")
	if get_node_or_null("CollisionShape2D") == null:
		_rebuild_collision()

func contains_global_position(world_position: Vector2) -> bool:
	var local_position := to_local(world_position)
	var half_size := gate_size * 0.5
	return (
		absf(local_position.x) <= half_size.x
		and absf(local_position.y) <= half_size.y
	)

func _rebuild_collision() -> void:
	var collision_shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null:
		collision_shape = CollisionShape2D.new()
		collision_shape.name = "CollisionShape2D"
		add_child(collision_shape)
	var rectangle := RectangleShape2D.new()
	rectangle.size = gate_size
	collision_shape.shape = rectangle

func _draw() -> void:
	var half_size := gate_size * 0.5
	var side := -1.0 if direction_id == &"west" else 1.0
	draw_rect(
		Rect2(-half_size, gate_size),
		Color(gate_color.darkened(0.65), 0.18),
		true
	)
	for index in range(4):
		var ratio := float(index + 1) / 5.0
		var y_position := lerpf(-half_size.y, half_size.y, ratio)
		draw_line(
			Vector2(-half_size.x * 0.72, y_position),
			Vector2(half_size.x * 0.72, y_position),
			Color(gate_color, 0.32 + ratio * 0.12),
			2.0,
			true
		)
	var arrow_origin := Vector2(-side * 12.0, 0.0)
	draw_line(
		arrow_origin,
		arrow_origin + Vector2(side * 28.0, 0.0),
		gate_color,
		5.0,
		true
	)
	draw_colored_polygon(
		PackedVector2Array([
			arrow_origin + Vector2(side * 34.0, 0.0),
			arrow_origin + Vector2(side * 20.0, -11.0),
			arrow_origin + Vector2(side * 20.0, 11.0)
		]),
		gate_color
	)
