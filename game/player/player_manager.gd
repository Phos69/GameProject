extends Node
class_name PlayerManager

signal player_spawned(player_slot: int, player: Node)

@export var player_scene: PackedScene = preload("res://game/player/player.tscn")
@export var player_container_path: NodePath = NodePath("../World/Players")
@export var spawn_points: Array[Vector2] = [
	Vector2(0.0, 0.0),
	Vector2(80.0, 20.0),
	Vector2(-80.0, 20.0),
	Vector2(0.0, -70.0)
]

var players: Dictionary = {}

func _ready() -> void:
	add_to_group("player_manager")
	call_deferred("spawn_initial_players")

func spawn_initial_players() -> void:
	if not players.is_empty():
		return

	var slots: Array = [1]
	var local_multiplayer = get_tree().get_first_node_in_group("local_multiplayer_manager")
	if local_multiplayer != null and local_multiplayer.has_method("get_active_slots"):
		slots = local_multiplayer.get_active_slots()

	for player_slot in slots:
		spawn_player(player_slot)

func spawn_player(player_slot: int) -> Node:
	if players.has(player_slot):
		return players[player_slot]

	var player := player_scene.instantiate()
	player.name = "Player%d" % player_slot
	player.set("player_slot", player_slot)
	if player is Node2D:
		(player as Node2D).position = _spawn_point_for_slot(player_slot)

	var container := get_node_or_null(player_container_path)
	if container == null:
		container = self
	container.add_child(player)

	players[player_slot] = player
	player_spawned.emit(player_slot, player)
	return player

func get_players() -> Array[Node]:
	var result: Array[Node] = []
	for value in players.values():
		if value is Node:
			result.append(value)
	return result

func _spawn_point_for_slot(player_slot: int) -> Vector2:
	var index := clampi(player_slot - 1, 0, spawn_points.size() - 1)
	return spawn_points[index]
