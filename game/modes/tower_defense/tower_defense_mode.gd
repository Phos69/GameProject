extends BaseGameMode
class_name TowerDefenseMode

signal defense_started()
signal defense_defeated(wave_index: int)
signal defense_wave_started(wave_index: int, enemy_count: int, is_boss_wave: bool)
signal defense_wave_progress_changed(wave_index: int, enemies_remaining: int)
signal defense_wave_completed(wave_index: int, reward_credits: int)

@export var arena_scene: PackedScene = preload(
	"res://game/modes/tower_defense/tower_defense_arena.tscn"
)
@export var path_enemy_scene: PackedScene = preload(
	"res://game/modes/tower_defense/tower_defense_enemy.tscn"
)
@export var arena_container_path: NodePath = NodePath("../../World/TowerDefenseArenas")
@export var tower_container_path: NodePath = NodePath("../../World/Towers")
@export var starting_credits: int = 75

@onready var wave_controller: TowerDefenseWaveController = (
	$WaveController as TowerDefenseWaveController
)

var active_arena: TowerDefenseArena
var tower_defense_manager: TowerDefenseManager
var enemy_system: EnemySystem
var game_mode_manager: GameModeManager

var state: StringName:
	get:
		return wave_controller.state if wave_controller != null else &"idle"

var current_wave: int:
	get:
		return wave_controller.current_wave if wave_controller != null else 0

var current_wave_is_boss: bool:
	get:
		return wave_controller.current_wave_is_boss if wave_controller != null else false

var wave_enemies: Array[Node]:
	get:
		return wave_controller.wave_enemies if wave_controller != null else []

var active_boss: Node:
	get:
		return wave_controller.active_boss if wave_controller != null else null

func _ready() -> void:
	mode_id = GameConstants.MODE_TOWER_DEFENSE
	add_to_group("tower_defense_mode")
	_connect_wave_controller()
	var mode_manager := get_tree().get_first_node_in_group("game_mode_manager")
	if mode_manager != null:
		mode_manager.register_mode(self)

func _process(_delta: float) -> void:
	if not is_running or state == &"defeated":
		return
	var players := get_tree().get_nodes_in_group("players")
	if players.is_empty():
		return
	for player in players:
		var health_component := player.get_node_or_null(
			"HealthComponent"
		) as HealthComponent
		if health_component != null and health_component.is_alive():
			return
	wave_controller.defeat_run()

func start_mode(context: Dictionary = {}) -> void:
	if is_running or not _resolve_systems():
		return
	super.start_mode(context)
	_clear_runtime()
	_set_prototype_arena_visible(false)

	active_arena = arena_scene.instantiate() as TowerDefenseArena
	if active_arena == null:
		stop_mode()
		return
	var arena_parent := get_node_or_null(arena_container_path)
	if arena_parent == null:
		arena_parent = get_tree().current_scene
	arena_parent.add_child(active_arena)
	active_arena.configure(tower_defense_manager)
	_connect_build_slots()
	tower_defense_manager.reset_run(int(context.get("starting_credits", starting_credits)))
	_move_players_to_spawn()

	var delay_override := float(context.get("initial_delay", wave_controller.initial_delay))
	wave_controller.start_run(
		active_arena,
		tower_defense_manager,
		enemy_system,
		game_mode_manager,
		path_enemy_scene,
		delay_override
	)
	defense_started.emit()

func stop_mode() -> void:
	if not is_running:
		return
	wave_controller.stop_run(true)
	_clear_runtime()
	_set_prototype_arena_visible(true)
	super.stop_mode()

func should_spawn_boss_for_wave(wave_index: int) -> bool:
	return wave_controller.should_spawn_boss(wave_index)

func get_enemies_remaining() -> int:
	return wave_controller.get_enemies_remaining()

func get_intermission_time_left() -> float:
	return wave_controller.get_intermission_time_left()

func get_status_text() -> String:
	if tower_defense_manager == null:
		return "Defense idle"
	var base_text := "Core %d/%d  Credits %d" % [
		tower_defense_manager.base_health,
		tower_defense_manager.base_max_health,
		tower_defense_manager.credits
	]
	match state:
		&"intermission":
			var reward_text := (
				"  Last +%d C" % wave_controller.last_wave_reward
				if wave_controller.last_wave_reward > 0
				else ""
			)
			return "%s  Wave %d in %.1fs%s" % [
				base_text,
				current_wave + 1,
				get_intermission_time_left(),
				reward_text
			]
		&"spawning":
			return "%s  Wave %d%s  Spawning %d/%d" % [
				base_text,
				current_wave,
				" BOSS" if current_wave_is_boss else "",
				get_enemies_remaining(),
				wave_controller.current_wave_total
			]
		&"combat":
			return "%s  Wave %d%s  Enemies %d/%d" % [
				base_text,
				current_wave,
				" BOSS" if current_wave_is_boss else "",
				get_enemies_remaining(),
				wave_controller.current_wave_total
			]
		&"defeated":
			return "%s  DEFENSE FAILED at wave %d" % [base_text, current_wave]
		_:
			return base_text

func try_build_at_slot(slot_id: StringName) -> Node:
	if (
		active_arena == null
		or tower_defense_manager == null
		or state == &"defeated"
	):
		return null
	for build_slot in active_arena.get_build_slots():
		if build_slot.slot_id == slot_id:
			return tower_defense_manager.try_build_tower(
				build_slot,
				_get_tower_container()
			)
	return null

func _resolve_systems() -> bool:
	tower_defense_manager = get_tree().get_first_node_in_group(
		"tower_defense_manager"
	) as TowerDefenseManager
	enemy_system = get_tree().get_first_node_in_group("enemy_system") as EnemySystem
	game_mode_manager = get_tree().get_first_node_in_group(
		"game_mode_manager"
	) as GameModeManager
	return (
		tower_defense_manager != null
		and enemy_system != null
		and game_mode_manager != null
		and wave_controller != null
		and arena_scene != null
		and path_enemy_scene != null
	)

func _connect_wave_controller() -> void:
	if wave_controller == null:
		return
	wave_controller.run_defeated.connect(_on_run_defeated)
	wave_controller.wave_started.connect(_on_wave_started)
	wave_controller.wave_progress_changed.connect(_on_wave_progress_changed)
	wave_controller.wave_completed.connect(_on_wave_completed)

func _on_run_defeated(wave_index: int) -> void:
	defense_defeated.emit(wave_index)

func _on_wave_started(
	wave_index: int,
	enemy_count: int,
	is_boss_wave: bool
) -> void:
	defense_wave_started.emit(wave_index, enemy_count, is_boss_wave)

func _on_wave_progress_changed(wave_index: int, enemies_remaining: int) -> void:
	defense_wave_progress_changed.emit(wave_index, enemies_remaining)

func _on_wave_completed(wave_index: int, reward_credits: int) -> void:
	defense_wave_completed.emit(wave_index, reward_credits)

func _on_build_requested(build_slot: TowerBuildSlot, _player: Node) -> void:
	if state != &"defeated":
		tower_defense_manager.try_build_tower(build_slot, _get_tower_container())

func _connect_build_slots() -> void:
	for build_slot in active_arena.get_build_slots():
		var callback := Callable(self, "_on_build_requested")
		if not build_slot.build_requested.is_connected(callback):
			build_slot.build_requested.connect(callback)

func _move_players_to_spawn() -> void:
	if active_arena == null:
		return
	var players := get_tree().get_nodes_in_group("players")
	for index in range(players.size()):
		var player := players[index] as Node2D
		if player == null:
			continue
		var column := index % 2
		var row := index / 2
		player.global_position = active_arena.to_global(
			active_arena.player_spawn_position
			+ Vector2(float(column) * 54.0, float(row) * 54.0)
		)

func _get_tower_container() -> Node:
	var container := get_node_or_null(tower_container_path)
	return container if container != null else get_tree().current_scene

func _clear_runtime() -> void:
	for tower in get_tree().get_nodes_in_group("defense_towers"):
		if is_instance_valid(tower):
			tower.queue_free()
	_clear_defense_projectiles()
	if is_instance_valid(active_arena):
		active_arena.queue_free()
	active_arena = null

func _clear_defense_projectiles() -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	for child in scene_root.get_children():
		if child is Projectile and child.source_id == &"defense_tower":
			child.queue_free()

func _set_prototype_arena_visible(value: bool) -> void:
	for node in get_tree().get_nodes_in_group("prototype_arena_content"):
		if node is CanvasItem:
			(node as CanvasItem).visible = value
