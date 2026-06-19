extends Node2D
class_name DungeonRoom

signal exit_requested(player: Node, target_index: int)

@export var room_size: Vector2 = Vector2(920.0, 540.0)
@export var player_spawn_position: Vector2 = Vector2(-320.0, 0.0)

@onready var exit_area := $ExitArea as Area2D
@onready var exit_visual := $ExitPortal as Polygon2D
@onready var room_label := $RoomLabel as Label

var room_data: Dictionary = {}
var room_kind: StringName = &"start"
var is_locked: bool = true
var depth: int = 0
var forward_targets: Array[int] = []
var exit_labels: Array[String] = []
# exit entries: {"area": Area2D, "visual": Polygon2D, "label": Label, "target": int}
var exits: Array[Dictionary] = []
var area_targets: Dictionary = {}

func _ready() -> void:
	z_index = -5
	exit_area.body_entered.connect(_on_exit_body_entered.bind(exit_area))
	_rebuild_exits()
	_apply_room_data()
	queue_redraw()

func configure_room(data: Dictionary) -> void:
	room_data = data.duplicate(true)
	room_kind = StringName(room_data.get("kind", &"start"))
	depth = int(room_data.get("depth", room_data.get("sequence_index", 0)))
	if is_node_ready():
		_apply_room_data()
		queue_redraw()

func configure_forward_targets(targets: Array[int], labels: Array[String] = []) -> void:
	forward_targets = targets.duplicate()
	exit_labels = labels.duplicate()
	if is_node_ready():
		_rebuild_exits()

func set_locked(value: bool) -> void:
	is_locked = value
	if is_node_ready():
		_apply_exit_state()
		queue_redraw()

func get_exit_position() -> Vector2:
	return exits[0]["area"].position if not exits.is_empty() else Vector2(390.0, 0.0)

func get_exit_position_for_target(target_index: int) -> Vector2:
	for entry in exits:
		if int(entry["target"]) == target_index:
			return (entry["area"] as Area2D).position
	return get_exit_position()

func _rebuild_exits() -> void:
	for index in range(exits.size() - 1, -1, -1):
		var area := exits[index]["area"] as Area2D
		if area != exit_area:
			area.queue_free()
		var extra_label := exits[index].get("label", null) as Label
		if extra_label != null and extra_label != room_label:
			extra_label.queue_free()
	exits.clear()
	area_targets.clear()

	var positions := _exit_positions(forward_targets.size())
	if forward_targets.is_empty():
		exit_area.position = Vector2(390.0, 0.0)
		exit_visual.position = exit_area.position
		exits.append({"area": exit_area, "visual": exit_visual, "label": null, "target": -1})
	else:
		exit_area.position = positions[0]
		exit_visual.position = positions[0]
		exits.append({"area": exit_area, "visual": exit_visual, "label": null, "target": forward_targets[0]})
		area_targets[exit_area.get_instance_id()] = forward_targets[0]
		for index in range(1, forward_targets.size()):
			exits.append(_create_exit(positions[index], forward_targets[index]))
	_apply_exit_labels()
	_apply_exit_state()
	queue_redraw()

func _create_exit(at_position: Vector2, target_index: int) -> Dictionary:
	var area := Area2D.new()
	area.name = "ExitArea%d" % target_index
	area.position = at_position
	area.collision_layer = 0
	area.collision_mask = GameConstants.LAYER_BODIES
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 34.0
	shape.shape = circle
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(_on_exit_body_entered.bind(area))
	area_targets[area.get_instance_id()] = target_index

	var visual := Polygon2D.new()
	visual.name = "ExitPortal%d" % target_index
	visual.position = at_position
	visual.polygon = PackedVector2Array([
		Vector2(-17.0, -44.0),
		Vector2(17.0, -44.0),
		Vector2(17.0, 44.0),
		Vector2(-17.0, 44.0)
	])
	add_child(visual)
	return {"area": area, "visual": visual, "label": null, "target": target_index}

func _exit_positions(count: int) -> Array[Vector2]:
	if count >= 2:
		return [Vector2(390.0, -130.0), Vector2(390.0, 130.0)]
	return [Vector2(390.0, 0.0)]

func _apply_exit_labels() -> void:
	if exit_labels.size() < 2 or exits.size() < 2:
		return
	for index in range(exits.size()):
		if index >= exit_labels.size():
			break
		var label := Label.new()
		label.text = exit_labels[index].to_upper()
		label.position = (exits[index]["area"] as Area2D).position + Vector2(-60.0, -78.0)
		label.add_theme_color_override("font_color", Color(0.84, 0.93, 1.0, 0.95))
		label.add_theme_font_size_override("font_size", 16)
		add_child(label)
		exits[index]["label"] = label

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
	var locked_color := Color(0.92, 0.28, 0.30, 0.90)
	var open_color := Color(0.30, 0.96, 0.62, 0.95)
	var choice_color := Color(0.36, 0.78, 1.0, 0.95)
	for index in range(exits.size()):
		var visual := exits[index]["visual"] as Polygon2D
		var area := exits[index]["area"] as Area2D
		if visual != null:
			if is_locked:
				visual.color = locked_color
			elif exits.size() >= 2:
				visual.color = choice_color if index > 0 else open_color
			else:
				visual.color = open_color
		if area != null:
			area.set_deferred("monitoring", not is_locked)

func _floor_color() -> Color:
	var base := _kind_floor_color()
	# Light depth tint so deeper rooms read as a distinct dungeon biome band.
	var tint := clampf(float(depth) * 0.018, 0.0, 0.16)
	return base.lightened(tint)

func _kind_floor_color() -> Color:
	match room_kind:
		&"combat":
			return Color(0.10, 0.13, 0.16, 1.0)
		&"loot":
			return Color(0.15, 0.13, 0.08, 1.0)
		&"shop":
			return Color(0.09, 0.16, 0.18, 1.0)
		&"rest":
			return Color(0.10, 0.16, 0.12, 1.0)
		&"boss":
			return Color(0.16, 0.08, 0.15, 1.0)
		_:
			return Color(0.08, 0.14, 0.16, 1.0)

func _on_exit_body_entered(body: Node2D, area: Area2D) -> void:
	if is_locked or not body.is_in_group("players"):
		return
	var target_index := int(area_targets.get(area.get_instance_id(), -1))
	exit_requested.emit(body, target_index)
