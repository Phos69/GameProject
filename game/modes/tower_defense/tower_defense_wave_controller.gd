extends Node
class_name TowerDefenseWaveController

signal run_defeated(wave_index: int)
signal wave_started(wave_index: int, enemy_count: int, is_boss_wave: bool)
signal wave_progress_changed(wave_index: int, enemies_remaining: int)
signal wave_completed(wave_index: int, reward_credits: int)

@export var initial_delay: float = 3.0
@export var intermission_duration: float = 4.0
@export var spawn_interval: float = 0.55
@export var base_enemy_count: int = 4
@export var enemy_count_growth: int = 2
@export var boss_wave_interval: int = 5
@export var enemy_health_scale_per_wave: float = 0.16
@export var enemy_speed_scale_per_wave: float = 0.04
@export var enemy_damage_scale_per_wave: float = 0.12
@export var enemy_base_damage: int = 12
@export var enemy_bounty_credits: int = 4
@export var boss_bounty_credits: int = 20
@export var wave_reward_base: int = 12
@export var wave_reward_growth: int = 4

enum State { IDLE, INTERMISSION, SPAWNING, COMBAT, DEFEATED }

var run_active: bool = false
var state: State = State.IDLE
var current_wave: int = 0
var current_wave_total: int = 0
var current_wave_is_boss: bool = false
var state_timer: float = 0.0
var spawn_timer: float = 0.0
var pending_spawn_count: int = 0
var wave_enemies: Array[Node] = []
var active_boss: Node
var last_wave_reward: int = 0

var active_arena: TowerDefenseArena
var tower_defense_manager: TowerDefenseManager
var enemy_system: EnemySystem
var game_mode_manager: GameModeManager

func _ready() -> void:
	add_to_group("tower_defense_wave_controller")

func _process(delta: float) -> void:
	if not run_active:
		return
	match state:
		State.INTERMISSION:
			state_timer = maxf(state_timer - delta, 0.0)
			if state_timer <= 0.0:
				_start_next_wave()
		State.SPAWNING:
			_process_spawning(delta)
		State.COMBAT:
			_check_wave_completion()

func start_run(
	arena: TowerDefenseArena,
	manager: TowerDefenseManager,
	enemy_spawner: EnemySystem,
	mode_manager: GameModeManager,
	path_enemy_scene: PackedScene,
	delay: float = -1.0
) -> void:
	stop_run(true)
	active_arena = arena
	tower_defense_manager = manager
	enemy_system = enemy_spawner
	game_mode_manager = mode_manager
	if (
		active_arena == null
		or tower_defense_manager == null
		or enemy_system == null
		or game_mode_manager == null
		or path_enemy_scene == null
	):
		return

	enemy_system.register_enemy_scene(&"tower_defense_raider", path_enemy_scene)
	var enemy_callback := Callable(self, "_on_enemy_died")
	if not enemy_system.enemy_died.is_connected(enemy_callback):
		enemy_system.enemy_died.connect(enemy_callback)
	var base_callback := Callable(self, "_on_base_destroyed")
	if not tower_defense_manager.base_destroyed.is_connected(base_callback):
		tower_defense_manager.base_destroyed.connect(base_callback)

	run_active = true
	state = State.IDLE
	current_wave = 0
	current_wave_total = 0
	current_wave_is_boss = false
	last_wave_reward = 0
	var start_delay := initial_delay if delay < 0.0 else delay
	_begin_intermission(start_delay)

func stop_run(clear_wave: bool = false) -> void:
	run_active = false
	state = State.IDLE
	state_timer = 0.0
	spawn_timer = 0.0
	pending_spawn_count = 0
	if clear_wave:
		_clear_wave_runtime()

func should_spawn_boss(wave_index: int) -> bool:
	return WaveCycle.should_spawn_boss(wave_index, boss_wave_interval)

func get_enemies_remaining() -> int:
	_prune_wave_enemies()
	_prune_boss()
	return pending_spawn_count + wave_enemies.size() + (1 if active_boss != null else 0)

func get_intermission_time_left() -> float:
	return state_timer if state == State.INTERMISSION else 0.0

func defeat_run() -> void:
	_on_base_destroyed()

func _begin_intermission(duration: float) -> void:
	state = State.INTERMISSION
	state_timer = maxf(duration, 0.0)

func _start_next_wave() -> void:
	if active_arena == null or state == State.DEFEATED:
		return
	current_wave += 1
	current_wave_is_boss = should_spawn_boss(current_wave)
	var regular_count := WaveCycle.get_regular_enemy_count(
		current_wave,
		base_enemy_count,
		enemy_count_growth
	)
	pending_spawn_count = maxi(regular_count, 0)
	current_wave_total = pending_spawn_count + (1 if current_wave_is_boss else 0)
	wave_enemies.clear()
	active_boss = null
	spawn_timer = 0.0
	state = State.SPAWNING
	if current_wave_is_boss:
		_spawn_boss()
	wave_started.emit(current_wave, current_wave_total, current_wave_is_boss)
	wave_progress_changed.emit(current_wave, get_enemies_remaining())
	if pending_spawn_count <= 0:
		state = State.COMBAT
		_check_wave_completion()

func _process_spawning(delta: float) -> void:
	spawn_timer = maxf(spawn_timer - delta, 0.0)
	if spawn_timer > 0.0 or pending_spawn_count <= 0:
		return
	_spawn_path_enemy()
	pending_spawn_count -= 1
	spawn_timer = maxf(spawn_interval, 0.0)
	wave_progress_changed.emit(current_wave, get_enemies_remaining())
	if pending_spawn_count <= 0:
		state = State.COMBAT
		_check_wave_completion()

func _spawn_path_enemy() -> void:
	var path_points := active_arena.get_world_path_points()
	if path_points.is_empty():
		return
	var wave_offset := maxi(current_wave - 1, 0)
	var enemy := enemy_system.spawn_enemy(
		&"tower_defense_raider",
		path_points[0],
		null,
		{
			"path_points": path_points,
			"health_multiplier": 1.0 + float(wave_offset) * enemy_health_scale_per_wave,
			"move_speed_multiplier": 1.0 + float(wave_offset) * enemy_speed_scale_per_wave,
			"damage_multiplier": 1.0 + float(wave_offset) * enemy_damage_scale_per_wave,
			"base_damage": enemy_base_damage
		}
	)
	if enemy == null:
		return
	wave_enemies.append(enemy)
	if enemy.has_signal("base_reached"):
		enemy.connect("base_reached", Callable(self, "_on_enemy_reached_base"))

func _spawn_boss() -> void:
	var path_points := active_arena.get_world_path_points()
	if path_points.is_empty():
		return
	var wave_offset := maxi(current_wave - 1, 0)
	active_boss = game_mode_manager.request_boss(
		StringName("tower_defense_wave_%d" % current_wave),
		path_points[0],
		null,
		{
			"boss_id": &"wave_warden",
			"wave_index": current_wave,
			"path_points": path_points,
			"base_damage": 55,
			"health_multiplier": 1.0 + float(wave_offset) * 0.08,
			"damage_multiplier": 1.0
		}
	)
	if active_boss == null:
		return
	if active_boss.has_signal("died"):
		active_boss.connect("died", Callable(self, "_on_boss_died"))
	if active_boss.has_signal("base_reached"):
		active_boss.connect("base_reached", Callable(self, "_on_boss_reached_base"))
	active_boss.tree_exited.connect(_on_boss_tree_exited.bind(active_boss))

func _on_enemy_died(enemy: Node) -> void:
	if not wave_enemies.has(enemy):
		return
	wave_enemies.erase(enemy)
	tower_defense_manager.add_credits(enemy_bounty_credits)
	wave_progress_changed.emit(current_wave, get_enemies_remaining())
	_check_wave_completion()

func _on_enemy_reached_base(enemy: Node, _damage: int) -> void:
	wave_enemies.erase(enemy)
	wave_progress_changed.emit(current_wave, get_enemies_remaining())
	_check_wave_completion()

func _on_boss_died(_boss: Node) -> void:
	active_boss = null
	tower_defense_manager.add_credits(boss_bounty_credits)
	wave_progress_changed.emit(current_wave, get_enemies_remaining())
	_check_wave_completion()

func _on_boss_reached_base(_boss: Node, _damage: int) -> void:
	active_boss = null
	wave_progress_changed.emit(current_wave, get_enemies_remaining())
	_check_wave_completion()

func _on_boss_tree_exited(boss: Node) -> void:
	if active_boss != boss:
		return
	active_boss = null
	_check_wave_completion()

func _check_wave_completion() -> void:
	if state != State.COMBAT or pending_spawn_count > 0:
		return
	_prune_wave_enemies()
	_prune_boss()
	if wave_enemies.is_empty() and active_boss == null:
		_complete_current_wave()

func _complete_current_wave() -> void:
	last_wave_reward = wave_reward_base + current_wave * wave_reward_growth
	tower_defense_manager.add_credits(last_wave_reward)
	wave_completed.emit(current_wave, last_wave_reward)
	_begin_intermission(intermission_duration)

func _on_base_destroyed() -> void:
	if not run_active or state == State.DEFEATED:
		return
	state = State.DEFEATED
	pending_spawn_count = 0
	_clear_wave_runtime()
	run_defeated.emit(current_wave)

func _clear_wave_runtime() -> void:
	pending_spawn_count = 0
	for enemy in wave_enemies.duplicate():
		if is_instance_valid(enemy):
			enemy.queue_free()
	wave_enemies.clear()
	if is_instance_valid(active_boss):
		active_boss.queue_free()
	active_boss = null

func _prune_wave_enemies() -> void:
	WaveCycle.prune_nodes(wave_enemies)

func _prune_boss() -> void:
	active_boss = WaveCycle.prune_node(active_boss)
