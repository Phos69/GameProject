extends Node
class_name WaveManager

signal run_started()
signal run_stopped(wave_index: int)
signal intermission_started(next_wave_index: int, duration: float)
signal wave_started(wave_index: int)
signal wave_configured(wave_index: int, enemy_count: int, is_boss_wave: bool)
signal wave_progress_changed(wave_index: int, enemies_remaining: int)
signal wave_completed(wave_index: int)
signal wave_reward_granted(wave_index: int, reward: Dictionary)
signal boss_wave_requested(wave_index: int)
signal enemy_spawned(enemy: Node, spawn_position: Vector2, spawn_index: int)
signal next_wave_block_changed(blocked: bool)

@export var boss_wave_interval: int = GameConstants.DEFAULT_BOSS_WAVE_INTERVAL
@export var initial_delay: float = 3.0
@export var intermission_duration: float = 4.0
@export var spawn_interval: float = 0.45
@export var base_enemy_count: int = 3
@export var enemy_count_growth: int = 2
@export var health_scale_per_wave: float = 0.18
@export var move_speed_scale_per_wave: float = 0.05
@export var damage_scale_per_wave: float = 0.12
@export var base_money_reward: int = 2
@export var money_reward_per_wave: int = 2
@export var base_ammo_reward: int = 3
@export var ammo_reward_per_wave: int = 1
@export var base_health_reward: int = 4
@export var health_reward_per_wave: int = 2
@export var spawn_points: Array[Vector2] = [
	Vector2(520.0, 0.0),
	Vector2(-520.0, 0.0),
	Vector2(0.0, 310.0),
	Vector2(0.0, -310.0),
	Vector2(390.0, 230.0),
	Vector2(-390.0, 230.0),
	Vector2(390.0, -230.0),
	Vector2(-390.0, -230.0)
]

enum State { IDLE, INTERMISSION, SPAWNING, COMBAT, REWARD }

var current_wave: int = 0
var wave_running: bool = false
var run_active: bool = false
var state: State = State.IDLE
var state_timer: float = 0.0
var spawn_timer: float = 0.0
var pending_spawn_count: int = 0
var current_wave_enemy_total: int = 0
var current_wave_regular_total: int = 0
var current_wave_is_boss: bool = false
var wave_enemies: Array[Node] = []
var wave_boss: Node
var boss_spawn_pending: bool = false
var last_reward: Dictionary = {}
var current_wave_biome_id: StringName = &""
var active_spawn_rate_multiplier: float = 1.0
var next_wave_blocked: bool = false

var enemy_system: EnemySystem
var wave_director
var zombie_spawner

func _ready() -> void:
	add_to_group("wave_manager")

func _process(delta: float) -> void:
	state_timer = WaveCycle.process_state(
		run_active, state, state_timer, delta,
		_start_next_wave, _process_spawning, _check_wave_completion
	)

func start_run() -> void:
	if run_active:
		return
	if not _resolve_enemy_system():
		return
	_resolve_wave_director()
	_resolve_zombie_spawner()

	current_wave = 0
	wave_running = false
	run_active = true
	state = State.IDLE
	last_reward = {}
	wave_enemies.clear()
	wave_boss = null
	boss_spawn_pending = false
	pending_spawn_count = 0
	current_wave_biome_id = &""
	active_spawn_rate_multiplier = 1.0
	next_wave_blocked = false
	run_started.emit()
	_begin_intermission(initial_delay)

func stop_run(clear_wave_enemies: bool = false) -> void:
	if not run_active and state == State.IDLE:
		return

	run_active = false
	wave_running = false
	state = State.IDLE
	state_timer = 0.0
	spawn_timer = 0.0
	pending_spawn_count = 0
	if clear_wave_enemies:
		for enemy in wave_enemies.duplicate():
			if is_instance_valid(enemy):
				enemy.queue_free()
		if is_instance_valid(wave_boss):
			wave_boss.queue_free()
	wave_enemies.clear()
	wave_boss = null
	boss_spawn_pending = false
	next_wave_blocked = false
	run_stopped.emit(current_wave)

func start_next_wave() -> void:
	if not run_active:
		if not _resolve_enemy_system():
			return
		run_active = true
	_start_next_wave()

func complete_current_wave() -> void:
	if wave_running:
		_complete_current_wave()

func set_next_wave_blocked(blocked: bool) -> void:
	if next_wave_blocked == blocked:
		return
	next_wave_blocked = blocked
	next_wave_block_changed.emit(next_wave_blocked)
	if not next_wave_blocked and run_active and state == State.REWARD:
		_begin_intermission(intermission_duration)

func is_next_wave_blocked() -> bool:
	return next_wave_blocked

func should_spawn_boss(wave_index: int) -> bool:
	return WaveCycle.should_spawn_boss(wave_index, boss_wave_interval)

func get_enemies_remaining() -> int:
	_prune_wave_enemies()
	_prune_wave_boss()
	var boss_count := 1 if boss_spawn_pending or is_instance_valid(wave_boss) else 0
	return pending_spawn_count + wave_enemies.size() + boss_count

func get_active_wave_enemies() -> Array[Node]:
	_prune_wave_enemies()
	return wave_enemies.duplicate()

func get_active_boss() -> Node:
	_prune_wave_boss()
	return wave_boss

func configure_spawn_points(points: Array[Vector2]) -> void:
	if points.is_empty():
		return
	spawn_points = points.duplicate()
	_resolve_zombie_spawner()
	if zombie_spawner != null:
		zombie_spawner.configure_fallback_spawn_points(spawn_points)

func get_enemy_id_for_spawn(
	wave_index: int,
	spawn_index: int,
	regular_total: int
) -> StringName:
	_resolve_wave_director()
	if wave_director != null:
		return wave_director.get_enemy_id_for_spawn(
			wave_index,
			spawn_index,
			regular_total
		)
	if (
		wave_index >= 3
		and regular_total >= 5
		and spawn_index == regular_total - 1
	):
		return &"survival_tank"
	if wave_index >= 4 and (spawn_index + 1) % 4 == 0:
		return &"survival_shooter"
	if wave_index >= 2 and (spawn_index + 1) % 3 == 0:
		return &"survival_runner"
	return &"survival_zombie"

func register_wave_boss(boss: Node) -> void:
	boss_spawn_pending = false
	wave_boss = boss
	if boss != null and boss.has_signal("died"):
		var callback := Callable(self, "_on_wave_boss_died")
		if not boss.is_connected("died", callback):
			boss.connect("died", callback)
	wave_progress_changed.emit(current_wave, get_enemies_remaining())
	_check_wave_completion()

func get_intermission_time_left() -> float:
	return state_timer if state == State.INTERMISSION else 0.0

func _resolve_enemy_system() -> bool:
	if enemy_system == null:
		enemy_system = get_tree().get_first_node_in_group("enemy_system") as EnemySystem
	if enemy_system == null:
		return false

	var callback := Callable(self, "_on_enemy_died")
	if not enemy_system.enemy_died.is_connected(callback):
		enemy_system.enemy_died.connect(callback)
	return true

func _resolve_wave_director() -> void:
	if wave_director == null:
		wave_director = get_tree().get_first_node_in_group(
			"wave_director"
		)

func _resolve_zombie_spawner() -> void:
	if zombie_spawner == null:
		zombie_spawner = get_tree().get_first_node_in_group(
			"zombie_spawner"
		)

func _begin_intermission(duration: float) -> void:
	state = State.INTERMISSION
	state_timer = maxf(duration, 0.0)
	intermission_started.emit(current_wave + 1, state_timer)

func _start_next_wave() -> void:
	if next_wave_blocked or not run_active or not _resolve_enemy_system():
		return
	_resolve_wave_director()
	_resolve_zombie_spawner()

	current_wave += 1
	wave_running = true
	current_wave_is_boss = should_spawn_boss(current_wave)
	var base_regular_total := WaveCycle.get_regular_enemy_count(
		current_wave,
		base_enemy_count,
		enemy_count_growth
	)
	var wave_config := _configure_current_wave(base_regular_total)
	current_wave_regular_total = int(
		wave_config.get("regular_total", base_regular_total)
	)
	current_wave_regular_total = maxi(current_wave_regular_total, 0)
	current_wave_biome_id = StringName(wave_config.get("biome_id", &""))
	active_spawn_rate_multiplier = maxf(
		float(wave_config.get("spawn_rate_multiplier", 1.0)),
		0.05
	)
	current_wave_enemy_total = current_wave_regular_total + (1 if current_wave_is_boss else 0)
	current_wave_enemy_total = maxi(current_wave_enemy_total, 1)
	pending_spawn_count = current_wave_regular_total
	wave_enemies.clear()
	wave_boss = null
	boss_spawn_pending = current_wave_is_boss
	state = State.SPAWNING
	spawn_timer = 0.0
	wave_started.emit(current_wave)
	wave_configured.emit(current_wave, current_wave_enemy_total, current_wave_is_boss)
	if current_wave_is_boss:
		boss_wave_requested.emit(current_wave)
		if boss_spawn_pending:
			boss_spawn_pending = false
	wave_progress_changed.emit(current_wave, get_enemies_remaining())
	if pending_spawn_count <= 0:
		state = State.COMBAT
		_check_wave_completion()

func _process_spawning(delta: float) -> void:
	spawn_timer = maxf(spawn_timer - delta, 0.0)
	if spawn_timer > 0.0 or pending_spawn_count <= 0:
		return

	_spawn_wave_enemy(current_wave_regular_total - pending_spawn_count)
	pending_spawn_count -= 1
	spawn_timer = maxf(spawn_interval / active_spawn_rate_multiplier, 0.0)
	wave_progress_changed.emit(current_wave, get_enemies_remaining())
	if pending_spawn_count <= 0:
		state = State.COMBAT
		_check_wave_completion()

func _spawn_wave_enemy(spawn_index: int) -> void:
	if spawn_points.is_empty() and zombie_spawner == null:
		return

	var wave_offset := maxi(current_wave - 1, 0)
	var health_multiplier := 1.0 + float(wave_offset) * health_scale_per_wave
	var move_multiplier := 1.0 + float(wave_offset) * move_speed_scale_per_wave
	var damage_multiplier := 1.0 + float(wave_offset) * damage_scale_per_wave
	var biome_scaling := _get_wave_director_scaling()
	health_multiplier *= float(biome_scaling.get("health", 1.0))
	move_multiplier *= float(biome_scaling.get("move_speed", 1.0))
	damage_multiplier *= float(biome_scaling.get("damage", 1.0))

	var spawn_config := {
		"wave_index": current_wave,
		"health_multiplier": health_multiplier,
		"move_speed_multiplier": move_multiplier,
		"damage_multiplier": damage_multiplier,
		"resource_drop_modifier": _get_resource_drop_modifier()
	}
	var enemy_id := get_enemy_id_for_spawn(
		current_wave,
		spawn_index,
		current_wave_regular_total
	)
	var spawn_position := _get_spawn_position(spawn_index, enemy_id)
	var enemy := enemy_system.spawn_enemy(
		enemy_id,
		spawn_position,
		null,
		spawn_config
	)
	if enemy != null:
		wave_enemies.append(enemy)
		enemy_spawned.emit(enemy, spawn_position, spawn_index)

func _configure_current_wave(base_regular_total: int) -> Dictionary:
	if wave_director == null:
		return {
			"regular_total": base_regular_total,
			"biome_id": &"",
			"spawn_rate_multiplier": 1.0
		}
	return wave_director.configure_wave(
		current_wave,
		current_wave_is_boss,
		base_regular_total
	)

func _get_spawn_position(spawn_index: int, enemy_id: StringName) -> Vector2:
	_resolve_zombie_spawner()
	if zombie_spawner != null:
		var biome = (
			wave_director.get_current_biome()
			if wave_director != null
			else null
		)
		return zombie_spawner.get_spawn_position(spawn_index, enemy_id, biome)
	if spawn_points.is_empty():
		return Vector2.ZERO
	return spawn_points[spawn_index % spawn_points.size()]

func _get_wave_director_scaling() -> Dictionary:
	_resolve_wave_director()
	if wave_director == null:
		return {
			"health": 1.0,
			"move_speed": 1.0,
			"damage": 1.0
		}
	return wave_director.get_wave_scaling_multipliers()

func _get_resource_drop_modifier() -> float:
	_resolve_wave_director()
	if (
		wave_director != null
		and wave_director.has_method("get_resource_drop_modifier")
	):
		return float(wave_director.get_resource_drop_modifier())
	return 1.0

func _on_enemy_died(enemy: Node) -> void:
	if not wave_enemies.has(enemy):
		return
	wave_enemies.erase(enemy)
	wave_progress_changed.emit(current_wave, get_enemies_remaining())
	_check_wave_completion()

func _on_wave_boss_died(_boss: Node) -> void:
	wave_boss = null
	boss_spawn_pending = false
	wave_progress_changed.emit(current_wave, get_enemies_remaining())
	_check_wave_completion()

func _check_wave_completion() -> void:
	if not wave_running or pending_spawn_count > 0 or boss_spawn_pending:
		return
	_prune_wave_enemies()
	_prune_wave_boss()
	if wave_enemies.is_empty() and wave_boss == null:
		_complete_current_wave()

func _complete_current_wave() -> void:
	if not wave_running:
		return

	wave_running = false
	state = State.REWARD
	last_reward = _grant_wave_reward()
	wave_reward_granted.emit(current_wave, last_reward.duplicate(true))
	wave_completed.emit(current_wave)
	if run_active and not next_wave_blocked:
		_begin_intermission(intermission_duration)

func _grant_wave_reward() -> Dictionary:
	var reward := {
		"money": base_money_reward + current_wave * money_reward_per_wave,
		"ammo": base_ammo_reward + current_wave * ammo_reward_per_wave,
		"health": base_health_reward + current_wave * health_reward_per_wave,
		"experience": current_wave * 10
	}

	var progression = get_tree().get_first_node_in_group("progression_manager")
	if progression != null:
		progression.add_money(int(reward["money"]))

	var health_system = get_tree().get_first_node_in_group("health_system")
	for player in PlayerQuery.alive(get_tree()):
		var weapon_system := player.get_node_or_null("WeaponSystem") as WeaponSystem
		if weapon_system != null:
			weapon_system.add_reserve_ammo(int(reward["ammo"]))
		var rpg_component := player.get_node_or_null(
			"RpgPlayerComponent"
		) as RpgPlayerComponent
		if rpg_component != null:
			rpg_component.add_experience(int(reward["experience"]))
			rpg_component.notify_wave_completed()
		if health_system != null:
			health_system.heal(player, int(reward["health"]))
	return reward

func _prune_wave_enemies() -> void:
	WaveCycle.prune_nodes(wave_enemies)

func _prune_wave_boss() -> void:
	wave_boss = WaveCycle.prune_node(wave_boss)
