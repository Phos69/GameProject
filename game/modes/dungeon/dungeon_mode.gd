extends BaseGameMode
class_name DungeonMode

signal dungeon_started(seed_value: int, rooms: Array[Dictionary])
signal room_entered(room_index: int, room_data: Dictionary)
signal room_cleared(room_index: int, room_data: Dictionary)
signal dungeon_completed(seed_value: int, room_count: int)
signal dungeon_defeated(room_index: int)

@export var room_scene: PackedScene = preload("res://game/modes/dungeon/dungeon_room.tscn")
@export var room_container_path: NodePath = NodePath("../../World/DungeonRooms")
@export_range(4, 20) var default_room_count: int = 7
@export var default_seed: int = 1337
@export var combat_base_enemy_count: int = 2
@export var combat_enemy_growth: int = 1
@export var enemy_spawn_points: Array[Vector2] = [
	Vector2(80.0, -135.0),
	Vector2(180.0, 130.0),
	Vector2(-40.0, 145.0),
	Vector2(250.0, -70.0),
	Vector2(-30.0, -150.0)
]
@export var boss_spawn_position: Vector2 = Vector2(120.0, 0.0)
@export var room_loot_table: LootTable = preload("res://game/drops/dungeon_room_loot.tres")

var layout: Array[Dictionary] = []
var current_room_index: int = -1
var current_room_state: StringName = &"idle"
var run_seed: int = 0
var active_room: DungeonRoom
var room_enemies: Array[Node] = []
var active_boss: Node
var room_pickups: Array[Node] = []
var transition_pending: bool = false

var dungeon_generator: DungeonGenerator
var enemy_system: EnemySystem

func _ready() -> void:
	mode_id = GameConstants.MODE_DUNGEON
	add_to_group("dungeon_mode")
	var game_mode_manager = get_tree().get_first_node_in_group("game_mode_manager")
	if game_mode_manager != null:
		game_mode_manager.register_mode(self)

func _process(_delta: float) -> void:
	if not is_running or current_room_state == &"complete":
		return
	var players := get_tree().get_nodes_in_group("players")
	if players.is_empty():
		return
	for player in players:
		var health_component := player.get_node_or_null("HealthComponent") as HealthComponent
		if health_component != null and health_component.is_alive():
			return
	current_room_state = &"defeated"
	dungeon_defeated.emit(current_room_index)
	stop_mode()

func start_mode(context: Dictionary = {}) -> void:
	if is_running:
		return
	if not _resolve_systems():
		return
	super.start_mode(context)

	run_seed = int(context.get("seed", default_seed))
	var requested_room_count := int(context.get("room_count", default_room_count))
	layout = dungeon_generator.generate_layout(run_seed, requested_room_count)
	if layout.is_empty():
		stop_mode()
		return
	run_seed = int(layout[0].get("seed", run_seed))
	_set_prototype_arena_visible(false)
	dungeon_started.emit(run_seed, layout.duplicate(true))
	_enter_room(0)

func stop_mode() -> void:
	if not is_running:
		return
	current_room_state = &"idle"
	_clear_room_runtime()
	_set_prototype_arena_visible(true)
	super.stop_mode()

func request_next_room() -> bool:
	if (
		not is_running
		or transition_pending
		or active_room == null
		or active_room.is_locked
	):
		return false
	if current_room_index >= layout.size() - 1:
		_complete_dungeon()
		return true
	_enter_room(current_room_index + 1)
	return true

func get_current_room_data() -> Dictionary:
	if current_room_index < 0 or current_room_index >= layout.size():
		return {}
	return layout[current_room_index].duplicate(true)

func get_enemies_remaining() -> int:
	_prune_room_enemies()
	var boss_count := 1 if is_instance_valid(active_boss) else 0
	return room_enemies.size() + boss_count

func get_status_text() -> String:
	if current_room_state == &"complete":
		return "Dungeon complete"
	if current_room_index < 0 or current_room_index >= layout.size():
		return "Dungeon idle"
	var room_data := layout[current_room_index]
	var room_kind := str(room_data.get("kind", &"unknown")).to_upper()
	var lock_status := "LOCKED" if active_room != null and active_room.is_locked else "EXIT OPEN"
	return "Room %d/%d  %s  %s  Enemies %d" % [
		current_room_index + 1,
		layout.size(),
		room_kind,
		lock_status,
		get_enemies_remaining()
	]

func request_area_boss() -> void:
	if current_room_index < 0:
		return
	_spawn_boss()

func _enter_room(room_index: int) -> void:
	_clear_room_runtime()
	current_room_index = clampi(room_index, 0, layout.size() - 1)
	var room_data := layout[current_room_index]
	active_room = room_scene.instantiate() as DungeonRoom
	if active_room == null:
		stop_mode()
		return
	active_room.configure_room(room_data)
	active_room.exit_requested.connect(_on_room_exit_requested)

	var room_container := get_node_or_null(room_container_path)
	if room_container == null:
		room_container = get_tree().current_scene
	room_container.add_child(active_room)
	_move_players_to_room_spawn()

	var room_kind := StringName(room_data.get("kind", &"combat"))
	match room_kind:
		&"start":
			current_room_state = &"ready"
			active_room.set_locked(false)
		&"combat":
			current_room_state = &"combat"
			active_room.set_locked(true)
			_spawn_combat_room()
		&"loot":
			current_room_state = &"loot"
			active_room.set_locked(false)
			_spawn_loot_room()
		&"boss":
			current_room_state = &"boss"
			active_room.set_locked(true)
			_spawn_boss()
		_:
			current_room_state = &"ready"
			active_room.set_locked(false)
	room_entered.emit(current_room_index, room_data.duplicate(true))

func _spawn_combat_room() -> void:
	if enemy_spawn_points.is_empty():
		_clear_current_room()
		return
	var combat_depth := 0
	for index in range(current_room_index + 1):
		if StringName(layout[index].get("kind", &"")) == &"combat":
			combat_depth += 1
	var enemy_count := maxi(
		combat_base_enemy_count + maxi(combat_depth - 1, 0) * combat_enemy_growth,
		1
	)
	for index in range(enemy_count):
		var spawn_position := enemy_spawn_points[index % enemy_spawn_points.size()]
		var enemy := enemy_system.spawn_enemy(
			&"dungeon_zombie",
			spawn_position,
			null,
			{
				"wave_index": combat_depth,
				"health_multiplier": 1.0 + float(combat_depth - 1) * 0.16,
				"move_speed_multiplier": 1.0 + float(combat_depth - 1) * 0.04,
				"damage_multiplier": 1.0 + float(combat_depth - 1) * 0.10
			}
		)
		if enemy != null:
			room_enemies.append(enemy)
	if room_enemies.is_empty():
		_clear_current_room()

func _spawn_loot_room() -> void:
	var drop_system := get_tree().get_first_node_in_group("drop_system") as DropSystem
	if drop_system == null:
		return
	room_pickups = drop_system.spawn_drops(
		self,
		room_loot_table,
		Vector2(40.0, 0.0)
	)

func _spawn_boss() -> void:
	var game_mode_manager := get_tree().get_first_node_in_group("game_mode_manager") as GameModeManager
	if game_mode_manager == null:
		return
	active_boss = game_mode_manager.request_boss(
		&"dungeon_area_end",
		boss_spawn_position,
		null,
		{
			"boss_id": &"rift_architect",
			"health_multiplier": 1.20,
			"damage_multiplier": 1.10
		}
	)
	if active_boss == null:
		_clear_current_room()
		return
	if active_boss.has_signal("died"):
		var callback := Callable(self, "_on_boss_died")
		if not active_boss.is_connected("died", callback):
			active_boss.connect("died", callback)

func _on_enemy_died(enemy: Node) -> void:
	if not room_enemies.has(enemy):
		return
	room_enemies.erase(enemy)
	if room_enemies.is_empty():
		_clear_current_room()

func _on_boss_died(_boss: Node) -> void:
	active_boss = null
	_clear_current_room()

func _clear_current_room() -> void:
	if active_room == null or not active_room.is_locked:
		return
	current_room_state = &"cleared"
	active_room.set_locked(false)
	room_cleared.emit(current_room_index, get_current_room_data())

func _on_room_exit_requested(_player: Node) -> void:
	if transition_pending or active_room == null or active_room.is_locked:
		return
	transition_pending = true
	active_room.exit_area.set_deferred("monitoring", false)
	call_deferred("_advance_from_exit")

func _advance_from_exit() -> void:
	transition_pending = false
	request_next_room()

func _complete_dungeon() -> void:
	current_room_state = &"complete"
	if active_room != null:
		active_room.set_locked(true)
	dungeon_completed.emit(run_seed, layout.size())

func _resolve_systems() -> bool:
	if dungeon_generator == null:
		dungeon_generator = get_tree().get_first_node_in_group("dungeon_generator") as DungeonGenerator
	if enemy_system == null:
		enemy_system = get_tree().get_first_node_in_group("enemy_system") as EnemySystem
	if dungeon_generator == null or enemy_system == null or room_scene == null:
		return false
	var callback := Callable(self, "_on_enemy_died")
	if not enemy_system.enemy_died.is_connected(callback):
		enemy_system.enemy_died.connect(callback)
	return true

func _move_players_to_room_spawn() -> void:
	if active_room == null:
		return
	var players := get_tree().get_nodes_in_group("players")
	for index in range(players.size()):
		var player := players[index] as Node2D
		if player == null:
			continue
		var column := index % 2
		var row := index / 2
		player.global_position = active_room.player_spawn_position + Vector2(
			float(column) * 54.0,
			float(row) * 54.0 - 28.0
		)

func _clear_room_runtime() -> void:
	transition_pending = false
	for enemy in room_enemies.duplicate():
		if is_instance_valid(enemy):
			enemy.queue_free()
	room_enemies.clear()
	if is_instance_valid(active_boss):
		active_boss.queue_free()
	active_boss = null
	for pickup in get_tree().get_nodes_in_group("drop_pickups"):
		if is_instance_valid(pickup):
			pickup.queue_free()
	room_pickups.clear()
	if is_instance_valid(active_room):
		active_room.queue_free()
	active_room = null

func _prune_room_enemies() -> void:
	for enemy in room_enemies.duplicate():
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			room_enemies.erase(enemy)

func _set_prototype_arena_visible(value: bool) -> void:
	for node in get_tree().get_nodes_in_group("prototype_arena_content"):
		if node is CanvasItem:
			(node as CanvasItem).visible = value
