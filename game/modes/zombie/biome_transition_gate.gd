extends Area2D
class_name BiomeTransitionGate

# Band depth across the boundary and the readable opening span when a passage
# width is not provided (legacy next/previous gates keep the historical size).
const GATE_DEPTH := 76.0
const DEFAULT_SPAN := 190.0
const MIN_SPAN := 64.0

var target_biome_id: StringName = &""
var target_region_id: StringName = &""
var direction_id: StringName = &"east"
var gate_size: Vector2 = Vector2(GATE_DEPTH, DEFAULT_SPAN)
var gate_color: Color = Color(0.42, 0.90, 0.58, 1.0)
var passage_kind: StringName = &"open_passage"
@export var show_debug_visual: bool = false

func configure(
	next_target_biome_id: StringName,
	next_direction_id: StringName,
	next_position: Vector2,
	next_color: Color,
	next_target_region_id: StringName = &"",
	next_passage_type: StringName = &"open_passage",
	next_span: float = 0.0
) -> void:
	target_biome_id = next_target_biome_id
	target_region_id = next_target_region_id
	direction_id = next_direction_id
	passage_kind = next_passage_type
	position = next_position
	gate_color = next_color
	gate_size = _resolve_gate_size(next_direction_id, next_span)
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	monitorable = false
	z_index = -1
	_rebuild_collision()
	queue_redraw()

# The opening span follows the passage width; the band keeps a fixed depth so
# the trigger never grows into the border walls flanking the passage.
func _resolve_gate_size(next_direction_id: StringName, next_span: float) -> Vector2:
	var span := DEFAULT_SPAN if next_span <= 0.0 else maxf(next_span, MIN_SPAN)
	if next_direction_id == &"north" or next_direction_id == &"south":
		return Vector2(span, GATE_DEPTH)
	return Vector2(GATE_DEPTH, span)

func _ready() -> void:
	add_to_group("biome_transition_gates")
	add_to_group("open_region_passages")
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

func get_direction_vector() -> Vector2:
	match direction_id:
		&"west":
			return Vector2.LEFT
		&"north":
			return Vector2.UP
		&"south":
			return Vector2.DOWN
		_:
			return Vector2.RIGHT

func _draw() -> void:
	if not show_debug_visual:
		return
	var half_size := gate_size * 0.5
	draw_rect(
		Rect2(-half_size, gate_size),
		Color(gate_color, 0.18),
		false,
		2.0
	)
