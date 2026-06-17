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
	var dir := get_direction_vector()
	var cross := Vector2(-dir.y, dir.x)
	var half_size := gate_size * 0.5
	# Extents along the travel axis (depth) and the opening axis (span).
	var depth := absf(dir.x) * half_size.x + absf(dir.y) * half_size.y
	var span := absf(cross.x) * half_size.x + absf(cross.y) * half_size.y
	var surface := _surface_color()
	draw_rect(
		Rect2(-half_size, gate_size),
		Color(surface.darkened(0.65), 0.10),
		true
	)
	_draw_opening_edges(dir, cross, depth, span, surface)
	_draw_passage_marks(dir, cross, depth, span, surface)
	_draw_direction_arrow(dir, depth)

# Bright edges parallel to the travel direction frame the opening on both sides.
func _draw_opening_edges(
	dir: Vector2,
	cross: Vector2,
	depth: float,
	span: float,
	surface: Color
) -> void:
	for sign_value in [-1.0, 1.0]:
		var edge: Vector2 = cross * (span * 0.86 * float(sign_value))
		draw_line(
			edge - dir * (depth * 0.82),
			edge + dir * (depth * 0.82),
			Color(surface.lightened(0.2), 0.72),
			4.0,
			true
		)

# Passage-kind themed strokes across the opening so the connection reads as a
# road, bridge, snow pass, broken gate or burned road without text labels.
func _draw_passage_marks(
	dir: Vector2,
	cross: Vector2,
	depth: float,
	span: float,
	surface: Color
) -> void:
	match passage_kind:
		&"bridge":
			for index in range(5):
				var t := lerpf(-span * 0.8, span * 0.8, float(index) / 4.0)
				var base := cross * t
				draw_line(
					base - dir * (depth * 0.6),
					base + dir * (depth * 0.6),
					Color(surface.lightened(0.12), 0.6),
					3.0,
					true
				)
		&"broken_gate":
			for sign_value in [-1.0, 1.0]:
				var post: Vector2 = cross * (span * 0.5 * float(sign_value))
				draw_line(
					post - dir * (depth * 0.5),
					post + dir * (depth * 0.2),
					Color(surface.darkened(0.1), 0.7),
					4.0,
					true
				)
		&"burned_road":
			for index in range(3):
				var ratio := float(index + 1) / 4.0
				var across := cross * lerpf(-span * 0.7, span * 0.7, ratio)
				draw_line(
					across - dir * (depth * 0.5),
					across + dir * (depth * 0.5),
					Color(0.12, 0.10, 0.10, 0.55),
					3.0,
					true
				)
		_:
			# road / snow_pass / open_passage: stacked lane lines along travel.
			for index in range(4):
				var lane_ratio := float(index + 1) / 5.0
				var lane := cross * lerpf(-span, span, lane_ratio)
				draw_line(
					lane - dir * (depth * 0.7),
					lane + dir * (depth * 0.7),
					Color(surface, 0.32 + lane_ratio * 0.12),
					2.0,
					true
				)

func _draw_direction_arrow(dir: Vector2, depth: float) -> void:
	var tail := -dir * (depth * 0.18)
	var head := dir * (depth * 0.5)
	var cross := Vector2(-dir.y, dir.x)
	draw_line(tail, head - dir * 6.0, gate_color, 5.0, true)
	draw_colored_polygon(
		PackedVector2Array([
			head,
			head - dir * 14.0 + cross * 11.0,
			head - dir * 14.0 - cross * 11.0
		]),
		gate_color
	)

func _surface_color() -> Color:
	match passage_kind:
		&"snow_pass":
			return gate_color.lightened(0.30)
		&"burned_road":
			return gate_color.darkened(0.35)
		&"broken_gate":
			return gate_color.darkened(0.12)
		_:
			return gate_color
