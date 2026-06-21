extends Node
class_name PlayerManager

signal player_spawned(player_slot: int, player: Node)
signal player_despawned(player_slot: int, player: Node)

@export var player_scene: PackedScene = preload("res://game/player/player.tscn")
@export var player_container_path: NodePath = NodePath("../World/Players")
@export var local_multiplayer_manager_path: NodePath = NodePath(
	"../LocalMultiplayerManager"
)
@export var input_manager_path: NodePath = NodePath("../InputManager")
@export var game_mode_manager_path: NodePath = NodePath("../GameModeManager")
@export var hazard_system_path: NodePath = NodePath(
	"../Modes/SurvivalMode/ZombieModeController/HazardSystem"
)
@export var spawn_points: Array[Vector2] = [
	Vector2(0.0, 0.0),
	Vector2(80.0, 20.0),
	Vector2(-80.0, 20.0),
	Vector2(0.0, -70.0)
]

var players: Dictionary = {}
var local_multiplayer_manager: LocalMultiplayerManager
var input_manager: InputManager
var game_mode_manager: GameModeManager
var hazard_system: HazardSystem

func _ready() -> void:
	add_to_group("player_manager")
	_resolve_runtime_dependencies()
	call_deferred("spawn_initial_players")

func spawn_initial_players() -> void:
	_resolve_runtime_dependencies()
	var slots: Array = [1]
	var local_multiplayer := local_multiplayer_manager
	if local_multiplayer != null and local_multiplayer.has_method("get_active_slots"):
		slots = local_multiplayer.get_active_slots()
		_connect_local_multiplayer(local_multiplayer)

	_sync_active_slots(slots)

func _connect_local_multiplayer(local_multiplayer: Node) -> void:
	var callback := Callable(self, "_sync_active_slots")
	if not local_multiplayer.is_connected(&"active_slots_changed", callback):
		local_multiplayer.connect(&"active_slots_changed", callback)

func _sync_active_slots(active_slots: Array) -> void:
	for player_slot in active_slots:
		spawn_player(int(player_slot))

	for player_slot in players.keys():
		var slot := int(player_slot)
		if not active_slots.has(slot):
			despawn_player(slot)

func spawn_player(player_slot: int) -> Node:
	if players.has(player_slot):
		return players[player_slot]

	var player := player_scene.instantiate()
	player.name = "Player%d" % player_slot
	player.set("player_slot", player_slot)
	if player.has_method("configure_runtime_dependencies"):
		player.configure_runtime_dependencies(
			input_manager,
			game_mode_manager,
			hazard_system
		)
	if player is Node2D:
		(player as Node2D).position = _spawn_point_for_slot(player_slot)

	var container := get_node_or_null(player_container_path)
	if container == null:
		container = self
	container.add_child(player)

	players[player_slot] = player
	player_spawned.emit(player_slot, player)
	return player

func despawn_player(player_slot: int) -> void:
	if not players.has(player_slot):
		return

	var player: Node = players[player_slot]
	players.erase(player_slot)
	player_despawned.emit(player_slot, player)
	player.queue_free()

func get_players() -> Array[Node]:
	var result: Array[Node] = []
	for value in players.values():
		if value is Node:
			result.append(value)
	return result

func _spawn_point_for_slot(player_slot: int) -> Vector2:
	var index := clampi(player_slot - 1, 0, spawn_points.size() - 1)
	return spawn_points[index]

func _resolve_runtime_dependencies() -> void:
	if local_multiplayer_manager == null:
		local_multiplayer_manager = _resolve_node(
			local_multiplayer_manager_path,
			&"local_multiplayer_manager"
		) as LocalMultiplayerManager
	if input_manager == null:
		input_manager = _resolve_node(input_manager_path, &"input_manager") as InputManager
	if game_mode_manager == null:
		game_mode_manager = _resolve_node(
			game_mode_manager_path,
			&"game_mode_manager"
		) as GameModeManager
	if hazard_system == null:
		hazard_system = _resolve_node(
			hazard_system_path,
			&"hazard_system"
		) as HazardSystem

func _resolve_node(path: NodePath, group_name: StringName) -> Node:
	if not path.is_empty():
		var node := get_node_or_null(path)
		if node != null:
			return node
	return get_tree().get_first_node_in_group(group_name)
