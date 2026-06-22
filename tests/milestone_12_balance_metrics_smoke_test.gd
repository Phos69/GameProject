extends SceneTree

var failures: PackedStringArray = []
var active_metric_key: StringName = &""
var metrics_by_key: Dictionary = {}
var wave_start_frames: Dictionary = {}
var tracked_wave_manager: WaveManager
var tracked_zombie_spawner: ZombieSpawner
var guaranteed_money_loot: LootTable

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main_scene := load("res://game/main/main.tscn") as PackedScene
	_expect(main_scene != null, "main scene can be loaded")
	if main_scene == null:
		_finish()
		return

	var main := main_scene.instantiate()
	root.add_child(main)
	current_scene = main
	await _wait_process_frames(4)

	var game_mode_manager := get_first_node_in_group(
		"game_mode_manager"
	) as GameModeManager
	var survival_mode := get_first_node_in_group("survival_mode") as SurvivalMode
	var wave_manager := get_first_node_in_group("wave_manager") as WaveManager
	var health_system := get_first_node_in_group("health_system") as HealthSystem
	var drop_system := get_first_node_in_group("drop_system") as DropSystem
	var boss_system := get_first_node_in_group("boss_system") as BossSystem
	var player_manager := get_first_node_in_group(
		"player_manager"
	) as PlayerManager
	var biome_manager := get_first_node_in_group("biome_manager") as BiomeManager
	var zombie_spawner := get_first_node_in_group(
		"zombie_spawner"
	) as ZombieSpawner
	var zombie_mode_controller := get_first_node_in_group(
		"zombie_mode_controller"
	) as ZombieModeController
	var world_runtime := get_first_node_in_group("world_runtime") as WorldRuntime

	_expect(game_mode_manager != null, "game mode manager is available")
	_expect(survival_mode != null, "survival mode is available")
	_expect(wave_manager != null, "wave manager is available")
	_expect(health_system != null, "health system is available")
	_expect(drop_system != null, "drop system is available")
	_expect(boss_system != null, "boss system is available")
	_expect(player_manager != null, "player manager is available")
	_expect(biome_manager != null, "biome manager is available")
	_expect(zombie_spawner != null, "zombie spawner is available")
	_expect(zombie_mode_controller != null, "zombie controller is available")
	_expect(world_runtime != null, "world runtime is available")
	if (
		game_mode_manager == null
		or survival_mode == null
		or wave_manager == null
		or health_system == null
		or drop_system == null
		or boss_system == null
		or player_manager == null
		or biome_manager == null
		or zombie_spawner == null
		or zombie_mode_controller == null
		or world_runtime == null
	):
		_finish()
		return

	tracked_wave_manager = wave_manager
	tracked_zombie_spawner = zombie_spawner
	guaranteed_money_loot = _make_guaranteed_money_loot(1)
	_connect_metric_signals(
		wave_manager,
		drop_system,
		health_system,
		boss_system
	)
	_expect(
		boss_system.get_registered_boss_ids().has(&"wave_warden"),
		"boss registry exposes the survival wave boss"
	)

	await _run_infinite_arena_metrics(
		game_mode_manager,
		survival_mode,
		wave_manager,
		health_system,
		player_manager,
		biome_manager,
		zombie_mode_controller,
		world_runtime
	)

	_finish()

func _run_infinite_arena_metrics(
	game_mode_manager: GameModeManager,
	survival_mode: SurvivalMode,
	wave_manager: WaveManager,
	health_system: HealthSystem,
	player_manager: PlayerManager,
	biome_manager: BiomeManager,
	zombie_mode_controller: ZombieModeController,
	world_runtime: WorldRuntime
) -> void:
	_configure_fast_waves(wave_manager, survival_mode, 5, 3, 1, 5, 0.02)
	_reset_metrics(&"infinite_arena")
	_expect(
		game_mode_manager.set_mode(
			GameConstants.MODE_INFINITE_ARENA,
			{"world_seed": 20260622}
		),
		"infinite arena starts through the game mode manager"
	)
	await _wait_process_frames(8)

	var player := player_manager.players.get(1) as PlayerController
	_expect(player != null, "infinite arena has player one")
	if player == null:
		return
	player.global_position = Vector2.ZERO

	_expect(
		game_mode_manager.active_mode_id == GameConstants.MODE_INFINITE_ARENA,
		"infinite arena is the active gameplay mode"
	)
	_expect(
		not zombie_mode_controller.world_runtime_enabled_for_run,
		"infinite arena disables world runtime"
	)
	_expect(not world_runtime.is_active, "infinite arena keeps world runtime inactive")
	_expect(
		biome_manager.get_generated_biome_map().size() == 1,
		"infinite arena uses a single compact biome cell"
	)

	await _complete_metric_waves(wave_manager, health_system, player, 5)
	var metrics := metrics_by_key.get(&"infinite_arena", {}) as Dictionary
	_validate_common_metrics(metrics, 5, "infinite arena")
	_expect(
		int(metrics.get("boss_requests", 0)) >= 1,
		"infinite arena reaches a boss wave request"
	)
	_expect(
		int(metrics.get("boss_spawns", 0)) >= 1,
		"infinite arena boss spawns through the registry"
	)
	var enemy_ids := _flatten_enemy_ids(metrics)
	_expect(enemy_ids.has("survival_runner"), "infinite arena wave mix includes runners")
	_expect(enemy_ids.has("survival_tank"), "infinite arena wave mix includes tanks")
	_expect(enemy_ids.has("survival_shooter"), "infinite arena wave mix includes shooters")
	_expect(
		wave_manager.get_enemies_remaining() == 0,
		"infinite arena has no leftover wave enemies after the metric run"
	)

	active_metric_key = &""

func _connect_metric_signals(
	wave_manager: WaveManager,
	drop_system: DropSystem,
	health_system: HealthSystem,
	boss_system: BossSystem
) -> void:
	wave_manager.wave_started.connect(_on_wave_started)
	wave_manager.wave_configured.connect(_on_wave_configured)
	wave_manager.enemy_spawned.connect(_on_enemy_spawned)
	wave_manager.wave_completed.connect(_on_wave_completed)
	drop_system.drop_spawned.connect(_on_drop_spawned)
	health_system.damage_requested.connect(_on_damage_requested)
	boss_system.boss_requested.connect(_on_boss_requested)
	boss_system.boss_spawned.connect(_on_boss_spawned)

func _configure_fast_waves(
	wave_manager: WaveManager,
	survival_mode: SurvivalMode,
	boss_interval: int,
	base_count: int,
	growth: int,
	boss_escort_count: int,
	intermission: float
) -> void:
	survival_mode.boss_wave_interval = boss_interval
	wave_manager.boss_wave_interval = boss_interval
	wave_manager.initial_delay = 0.0
	wave_manager.intermission_duration = intermission
	wave_manager.spawn_interval = 0.0
	wave_manager.base_enemy_count = base_count
	wave_manager.enemy_count_growth = growth
	wave_manager.boss_wave_escort_count = boss_escort_count

func _reset_metrics(metric_key: StringName) -> void:
	active_metric_key = metric_key
	wave_start_frames.clear()
	metrics_by_key[metric_key] = {
		"waves_configured": [],
		"waves_completed": [],
		"wave_durations": {},
		"wave_enemy_totals": {},
		"live_peaks": {},
		"enemy_ids": {},
		"biome_ids": {},
		"spawn_edges": [],
		"inside_camera_spawns": 0,
		"spawn_rejections": 0,
		"drops": 0,
		"damage_events": 0,
		"damage_total": 0,
		"boss_requests": 0,
		"boss_spawns": 0
	}

func _complete_metric_waves(
	wave_manager: WaveManager,
	health_system: HealthSystem,
	player: PlayerController,
	wave_count: int
) -> void:
	for wave_index in range(1, wave_count + 1):
		_expect(
			await _wait_for_wave_combat(wave_manager, wave_index),
			"wave %d reaches combat during metric run" % wave_index
		)
		health_system.apply_damage(
			player,
			1,
			null,
			&"milestone_12_damage_probe",
			player.global_position
		)
		await _kill_active_wave(wave_manager, health_system, player)
		_expect(
			await _wait_for_wave_completed(wave_manager, wave_index),
			"wave %d completes during metric run" % wave_index
		)
		await _wait_process_frames(4)

func _kill_active_wave(
	wave_manager: WaveManager,
	health_system: HealthSystem,
	player: PlayerController
) -> void:
	for enemy in wave_manager.get_active_wave_enemies():
		var hit_position := (
			(enemy as Node2D).global_position
			if enemy is Node2D
			else Vector2.ZERO
		)
		health_system.apply_damage(
			enemy,
			999999,
			player,
			&"milestone_12_wave_clear",
			hit_position
		)
	var boss := wave_manager.get_active_boss()
	if boss != null:
		var boss_position := (
			(boss as Node2D).global_position
			if boss is Node2D
			else Vector2.ZERO
		)
		health_system.apply_damage(
			boss,
			999999,
			player,
			&"milestone_12_boss_clear",
			boss_position
		)
	await _wait_process_frames(2)

func _on_wave_started(wave_index: int) -> void:
	if active_metric_key.is_empty():
		return
	wave_start_frames[wave_index] = Engine.get_physics_frames()
	_update_live_peak(wave_index)

func _on_wave_configured(
	wave_index: int,
	enemy_count: int,
	_is_boss_wave: bool
) -> void:
	if active_metric_key.is_empty():
		return
	var metrics := _active_metrics()
	var configured := metrics["waves_configured"] as Array
	configured.append(wave_index)
	metrics["waves_configured"] = configured
	(metrics["wave_enemy_totals"] as Dictionary)[wave_index] = enemy_count
	(metrics["biome_ids"] as Dictionary)[wave_index] = (
		tracked_wave_manager.current_wave_biome_id
		if tracked_wave_manager != null
		else &""
	)
	_update_live_peak(wave_index)

func _on_enemy_spawned(enemy: Node, spawn_position: Vector2, _spawn_index: int) -> void:
	if active_metric_key.is_empty():
		return
	if enemy is BasicEnemy:
		(enemy as BasicEnemy).loot_table = guaranteed_money_loot
	enemy.set_physics_process(false)
	var wave_index := (
		tracked_wave_manager.current_wave
		if tracked_wave_manager != null
		else 0
	)
	var metrics := _active_metrics()
	var enemy_ids := metrics["enemy_ids"] as Dictionary
	if not enemy_ids.has(wave_index):
		enemy_ids[wave_index] = PackedStringArray()
	var ids := enemy_ids[wave_index] as PackedStringArray
	ids.append(str(enemy.get("enemy_id")))
	enemy_ids[wave_index] = ids
	if tracked_zombie_spawner != null:
		var edge := tracked_zombie_spawner.get_last_spawn_edge()
		var spawn_edges := metrics["spawn_edges"] as Array
		spawn_edges.append(String(edge))
		metrics["spawn_edges"] = spawn_edges
		if not tracked_zombie_spawner.is_position_outside_camera_view(
			spawn_position
		):
			metrics["inside_camera_spawns"] = (
				int(metrics.get("inside_camera_spawns", 0)) + 1
			)
		if not tracked_zombie_spawner.get_last_spawn_rejection_reason().is_empty():
			metrics["spawn_rejections"] = (
				int(metrics.get("spawn_rejections", 0)) + 1
			)
	_update_live_peak(wave_index)

func _on_wave_completed(wave_index: int) -> void:
	if active_metric_key.is_empty():
		return
	var metrics := _active_metrics()
	var completed := metrics["waves_completed"] as Array
	completed.append(wave_index)
	metrics["waves_completed"] = completed
	var start_frame := int(
		wave_start_frames.get(wave_index, Engine.get_physics_frames())
	)
	(metrics["wave_durations"] as Dictionary)[wave_index] = (
		Engine.get_physics_frames() - start_frame
	)
	_update_live_peak(wave_index)

func _on_drop_spawned(_pickup: Node, _drop_data: Dictionary) -> void:
	if active_metric_key.is_empty():
		return
	var metrics := _active_metrics()
	metrics["drops"] = int(metrics.get("drops", 0)) + 1

func _on_damage_requested(_target: Node, amount: int) -> void:
	if active_metric_key.is_empty():
		return
	var metrics := _active_metrics()
	metrics["damage_events"] = int(metrics.get("damage_events", 0)) + 1
	metrics["damage_total"] = int(metrics.get("damage_total", 0)) + amount

func _on_boss_requested(_mode_id: StringName, _reason: StringName) -> void:
	if active_metric_key.is_empty():
		return
	var metrics := _active_metrics()
	metrics["boss_requests"] = int(metrics.get("boss_requests", 0)) + 1

func _on_boss_spawned(boss: Node) -> void:
	if active_metric_key.is_empty():
		return
	boss.set_physics_process(false)
	var metrics := _active_metrics()
	metrics["boss_spawns"] = int(metrics.get("boss_spawns", 0)) + 1
	if tracked_wave_manager != null:
		_update_live_peak(tracked_wave_manager.current_wave)

func _active_metrics() -> Dictionary:
	return metrics_by_key.get(active_metric_key, {}) as Dictionary

func _update_live_peak(wave_index: int) -> void:
	if active_metric_key.is_empty() or tracked_wave_manager == null:
		return
	var metrics := _active_metrics()
	var live_peaks := metrics["live_peaks"] as Dictionary
	live_peaks[wave_index] = maxi(
		int(live_peaks.get(wave_index, 0)),
		_current_live_count()
	)

func _current_live_count() -> int:
	if tracked_wave_manager == null:
		return 0
	var count := tracked_wave_manager.get_active_wave_enemies().size()
	if tracked_wave_manager.get_active_boss() != null:
		count += 1
	return count

func _validate_common_metrics(
	metrics: Dictionary,
	expected_wave_count: int,
	label: String
) -> void:
	var configured := metrics.get("waves_configured", []) as Array
	var completed := metrics.get("waves_completed", []) as Array
	var durations := metrics.get("wave_durations", {}) as Dictionary
	var live_peaks := metrics.get("live_peaks", {}) as Dictionary
	var enemy_totals := metrics.get("wave_enemy_totals", {}) as Dictionary
	for wave_index in range(1, expected_wave_count + 1):
		_expect(configured.has(wave_index), "%s configures wave %d" % [label, wave_index])
		_expect(completed.has(wave_index), "%s completes wave %d" % [label, wave_index])
		_expect(durations.has(wave_index), "%s records wave %d duration" % [label, wave_index])
		_expect(
			int(durations.get(wave_index, -1)) >= 0,
			"%s wave %d duration metric is non-negative" % [label, wave_index]
		)
		_expect(
			int(live_peaks.get(wave_index, 0)) > 0,
			"%s records live enemies for wave %d" % [label, wave_index]
		)
		_expect(
			int(enemy_totals.get(wave_index, 0)) >= 1,
			"%s records configured enemy total for wave %d"
			% [label, wave_index]
		)
	_expect(
		int(metrics.get("drops", 0)) >= expected_wave_count,
		"%s records deterministic enemy drops" % label
	)
	_expect(
		int(metrics.get("damage_events", 0)) >= expected_wave_count,
		"%s records damage events" % label
	)
	_expect(
		int(metrics.get("damage_total", 0)) > 0,
		"%s records positive damage total" % label
	)
	_expect(
		not (metrics.get("spawn_edges", []) as Array).is_empty(),
		"%s records spawn edge metrics" % label
	)

func _flatten_enemy_ids(metrics: Dictionary) -> PackedStringArray:
	var result := PackedStringArray()
	var ids_by_wave := metrics.get("enemy_ids", {}) as Dictionary
	for value in ids_by_wave.values():
		var ids := value as PackedStringArray
		for enemy_id in ids:
			result.append(enemy_id)
	return result

func _make_guaranteed_money_loot(amount: int) -> LootTable:
	var money_entry := DropEntry.new()
	money_entry.drop_type = GameConstants.DROP_MONEY
	money_entry.chance = 1.0
	money_entry.min_amount = amount
	money_entry.max_amount = amount
	var loot := LootTable.new()
	loot.entries = [money_entry]
	return loot

func _wait_for_wave_combat(
	wave_manager: WaveManager,
	wave_index: int
) -> bool:
	for _frame in range(1200):
		if (
			wave_manager.current_wave == wave_index
			and wave_manager.state == WaveManager.State.COMBAT
		):
			return true
		await physics_frame
	return false

func _wait_for_wave_completed(
	wave_manager: WaveManager,
	wave_index: int
) -> bool:
	for _frame in range(360):
		if (
			wave_manager.current_wave == wave_index
			and not wave_manager.wave_running
		):
			return true
		await physics_frame
	return false

func _wait_process_frames(count: int) -> void:
	for _index in range(count):
		await process_frame

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("MILESTONE_12_BALANCE_METRICS_SMOKE_TEST: PASS")
		quit(0)
		return
	print(
		"MILESTONE_12_BALANCE_METRICS_SMOKE_TEST: FAIL (%d)"
		% failures.size()
	)
	quit(1)
