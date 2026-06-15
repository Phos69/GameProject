extends Node2D
class_name DungeonRoom

signal exit_requested(player: Node)

@export var room_size: Vector2 = Vector2(920.0, 540.0)
@export var player_spawn_position: Vector2 = Vector2(-320.0, 0.0)

@onready var exit_area := $ExitArea as Area2D
@onready var exit_visual := $ExitPortal as Polygon2D
@onready var room_label := $RoomLabel as Label

var room_data: Dictionary = {}
var room_kind: StringName = &"start"
var is_locked: bool = true

func _ready() -> void:
	z_index = -5
	exit_area.body_entered.connect(_on_exit_body_entered)
	_apply_room_data()
	_apply_exit_state()
	queue_redraw()

func configure_room(data: Dictionary) -> void:
	room_data = data.duplicate(true)
	room_kind = StringName(room_data.get("kind", &"start"))
	if is_node_ready():
		_apply_room_data()
		queue_redraw()

func set_locked(value: bool) -> void:
	is_locked = value
	if is_node_ready():
		_apply_exit_state()
		queue_redraw()

func get_exit_position() -> Vector2:
	return $ExitArea.position

func _draw() -> void:
	var floor_rect := Rect2(-room_size * 0.5, room_size)
	draw_rect(floor_rect, _floor_color(), true)
	draw_rect(floor_rect, Color(0.48, 0.68, 0.78, 0.95), false, 5.0)

	for x in range(-4, 5):
		draw_line(
			Vector2(float(x) * 92.0, -room_size.y * 0.5),
			Vector2(float(x) * 92.0, room_size.y * 0.5),
			Color(0.25, 0.34, 0.40, 0.28),
			1.0
		)
	for y in range(-2, 3):
		draw_line(
			Vector2(-room_size.x * 0.5, float(y) * 90.0),
			Vector2(room_size.x * 0.5, float(y) * 90.0),
			Color(0.25, 0.34, 0.40, 0.28),
			1.0
		)

func _apply_room_data() -> void:
	var room_number := int(room_data.get("sequence_index", 0)) + 1
	room_label.text = "ROOM %02d  %s" % [room_number, str(room_kind).to_upper()]

func _apply_exit_state() -> void:
	exit_visual.color = (
		Color(0.92, 0.28, 0.30, 0.90)
		if is_locked
		else Color(0.30, 0.96, 0.62, 0.95)
	)
	exit_area.set_deferred("monitoring", not is_locked)

func _floor_color() -> Color:
	match room_kind:
		&"combat":
			return Color(0.10, 0.13, 0.16, 1.0)
		&"loot":
			return Color(0.15, 0.13, 0.08, 1.0)
		&"boss":
			return Color(0.16, 0.08, 0.15, 1.0)
		_:
			return Color(0.08, 0.14, 0.16, 1.0)

func _on_exit_body_entered(body: Node2D) -> void:
	if is_locked or not body.is_in_group("players"):
		return
	exit_requested.emit(body)
