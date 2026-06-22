extends SceneTree

const EXPECTED_THEMATIC_IDS := {
	&"toxic_wastes": ["toxic_zombie", "toxic_exploder"],
	&"burning_fields": ["burned_zombie", "fire_runner", "fire_exploder"],
	&"frozen_outskirts": [
		"frozen_zombie",
		"ice_armored_zombie",
		"heavy_slow_zombie"
	],
	&"drowned_marsh": [
		"drowned_zombie",
		"marsh_zombie",
		"water_emerging_zombie"
	]
}

var failures: PackedStringArray = []
var metrics: Dictionary = {}
var wave_start_frames: Dictionary = {}
var wave_manager: WaveManager
var zombie_spawner: ZombieSpawner
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
	wave_manager = get_first_node_in_group("wave_manager") as WaveManager
	var health_system := get_first_node_in_group("health_system") as HealthSystem
	var drop_system := get_first_node_in_group("drop_system") as DropSystem
	var player_manager := get_first_node_in_group(
		"player_manager"
	) as PlayerManager
	var biome_manager := get_first_node_in_group("biome_manager") as BiomeManager
	zombie_spawner = get_first_node_in_group("zombie_spawner") as ZombieSpawner
	var zombie_mode_controller := get_first_node_in_group(
		"zombie_mode_controller"
	) as ZombieModeController
	var world_runtime := get_first_node_in_group("world_runtime") as WorldRuntime

	_expect(game_mode_manager != null, "game mode manager is available")
	_expect(survival_mode != null, "survival mode is available")
	_expect(wave_manager != null, "wave manager is available")
	_expect(health_system != null, "health system is available")
	_expect(drop_system != null, "drop system is available")
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
		or player_manager == null
		or biome_manager == null
		or zombie_spawner == null
		or zombie_mode_controller == null
		or world_runtime == null
	):
		_finish()
		return

	guaranteed_money_loot = _make_guaranteed_money_loot(1)
	_connect_metric_signals(drop_system, health_system)
	_configure_fast_waves(survival_mode)
	_reset_metrics()
	_expect(
		game_mode_manager.set_mode(
			GameConstants.MODE_SURVIVAL,
			{
				"world_seed": 20260622,
				"biome_map_width": 3,
				"biome_map_height": 3
			}
		),
		"zombie survival starts through the game mode manager"
	)
	await _wait_process_frames(10)

	var player := player_manager.players.get(1) as PlayerController
	_expect(player != null, "zombie survival has player one")
	if player == null:
		_finish()
		return
	player.global_position = Vector2.ZERO

	_expect(
		game_mode_manager.active_mode_id == GameConstants.MODE_SURVIVAL,
		"zombie survival is the active gameplay mode"
	)
	_expect(
		zombie_mode_controller.world_runtime_enabled_for_run,
		"zombie survival keeps world runtime enabled"
	)
	_expect(world_runtime.is_active, "zombie survival activates world runtime")
	_expect(
		biome_manager.get_generated_biome_map().size() >= 9,
		"zombie survival generates the multi-biome map"
	)
	_expect(
		not world_runtime.get_active_region_ids().is_empty(),
		"zombie survival keeps streamed regions active"
	)
	for biome_id in EXPECTED_THEMATIC_IDS.keys():
		_expect_biome_definition_variant_window(
			biome_manager,
			StringName(biome_id),
			4
		)

	_expect(
		await _wait_for_wave_combat(1),
		"zombie survival wave 1 reaches combat"
	)
	_expect(
		wave_manager.current_wave_biome_id == &"infected_plains",
		"wave 1 records infected plains"
	)
	await _damage_and_clear_wave(health_system, player)
	_expect(
		await _wait_for_wave_completed(1),
		"zombie survival wave 1 completes cleanly"
	)
	await _wait_process_frames(2)

	_expect(
		await _wait_for_wave_combat(2),
		"zombie survival wave 2 reaches combat"
	)
	_expect(
		wave_manager.current_wave_biome_id == &"infected_plains",
		"wave 2 records infected plains"
	)
	await _damage_and_clear_wave(health_system, player)
	_expect(
		await _wait_for_wave_completed(2),
		"zombie survival wave 2 completes cleanly"
	)
	await _wait_process_frames(4)

	_validate_metrics()
	_finish()

func _connect_metric_signals(
	drop_system: DropSystem,
	health_system: HealthSystem
) -> void:
	wave_manager.wave_started.connect(_on_wave_started)
	wave_manager.wave_configured.connect(_on_wave_configured)
	wave_manager.enemy_spawned.connect(_on_enemy_spawned)
	wave_manager.wave_completed.connect(_on_wave_completed)
	drop_system.drop_spawned.connect(_on_drop_spawned)
	health_system.damage_requested.connect(_on_damage_requested)

func _configure_fast_waves(survival_mode: SurvivalMode) -> void:
	survival_mode.boss_wave_interval = 99
	wave_manager.boss_wave_interval = 99
	wave_manager.initial_delay = 0.0
	wave_manager.intermission_duration = 0.12
	wave_manager.spawn_interval = 0.0
	wave_manager.base_enemy_count = 6
	wave_manager.enemy_count_growth = 2

func _reset_metrics() -> void:
	wave_start_frames.clear()
	metrics = {
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
		"damage_total": 0
	}

func _damage_and_clear_wave(
	health_system: HealthSystem,
	player: PlayerController
) -> void:
	health_system.apply_damage(
		player,
		1,
		null,
		&"milestone_12_damage_probe",
		player.global_position
	)
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
			&"milestone_12_zombie_wave_clear",
			hit_position
		)
	await _wait_process_frames(2)

func _on_wave_started(wave_index: int) -> void:
	wave_start_frames[wave_index] = Engine.get_physics_frames()
	_update_live_peak(wave_index)

func _on_wave_configured(
	wave_index: int,
	enemy_count: int,
	_is_boss_wave: bool
) -> void:
	var configured := metrics["waves_configured"] as Array
	configured.append(wave_index)
	metrics["waves_configured"] = configured
	(metrics["wave_enemy_totals"] as Dictionary)[wave_index] = enemy_count
	(metrics["biome_ids"] as Dictionary)[wave_index] = (
		wave_manager.current_wave_biome_id
	)
	_update_live_peak(wave_index)

func _on_enemy_spawned(enemy: Node, spawn_position: Vector2, _spawn_index: int) -> void:
	if enemy is BasicEnemy:
		(enemy as BasicEnemy).loot_table = guaranteed_money_loot
	enemy.set_physics_process(false)
	var wave_index := wave_manager.current_wave
	var enemy_ids := metrics["enemy_ids"] as Dictionary
	if not enemy_ids.has(wave_index):
		enemy_ids[wave_index] = PackedStringArray()
	var ids := enemy_ids[wave_index] as PackedStringArray
	ids.append(str(enemy.get("enemy_id")))
	enemy_ids[wave_index] = ids
	if zombie_spawner != null:
		var spawn_edges := metrics["spawn_edges"] as Array
		spawn_edges.append(String(zombie_spawner.get_last_spawn_edge()))
		metrics["spawn_edges"] = spawn_edges
		if not zombie_spawner.is_position_outside_camera_view(spawn_position):
			metrics["inside_camera_spawns"] = (
				int(metrics.get("inside_camera_spawns", 0)) + 1
			)
		if not zombie_spawner.get_last_spawn_rejection_reason().is_empty():
			metrics["spawn_rejections"] = (
				int(metrics.get("spawn_rejections", 0)) + 1
			)
	_update_live_peak(wave_index)

func _on_wave_completed(wave_index: int) -> void:
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
	metrics["drops"] = int(metrics.get("drops", 0)) + 1

func _on_damage_requested(_target: Node, amount: int) -> void:
	metrics["damage_events"] = int(metrics.get("damage_events", 0)) + 1
	metrics["damage_total"] = int(metrics.get("damage_total", 0)) + amount

func _update_live_peak(wave_index: int) -> void:
	var live_peaks := metrics["live_peaks"] as Dictionary
	live_peaks[wave_index] = maxi(
		int(live_peaks.get(wave_index, 0)),
		wave_manager.get_active_wave_enemies().size()
	)

func _validate_metrics() -> void:
	var configured := metrics.get("waves_configured", []) as Array
	var completed := metrics.get("waves_completed", []) as Array
	var durations := metrics.get("wave_durations", {}) as Dictionary
	var live_peaks := metrics.get("live_peaks", {}) as Dictionary
	var enemy_totals := metrics.get("wave_enemy_totals", {}) as Dictionary
	for wave_index in range(1, 3):
		_expect(configured.has(wave_index), "zombie survival configures wave %d" % wave_index)
		_expect(completed.has(wave_index), "zombie survival completes wave %d" % wave_index)
		_expect(durations.has(wave_index), "zombie survival records wave %d duration" % wave_index)
		_expect(
			int(live_peaks.get(wave_index, 0)) > 0,
			"zombie survival records live enemies for wave %d" % wave_index
		)
		_expect(
			int(enemy_totals.get(wave_index, 0)) >= 1,
			"zombie survival records enemy total for wave %d" % wave_index
		)
	_expect(
		int(metrics.get("drops", 0)) >= 2,
		"zombie survival records deterministic enemy drops"
	)
	_expect(
		int(metrics.get("damage_events", 0)) >= 2,
		"zombie survival records damage events"
	)
	_expect(
		int(metrics.get("damage_total", 0)) > 0,
		"zombie survival records positive damage total"
	)
	_expect(
		not (metrics.get("spawn_edges", []) as Array).is_empty(),
		"zombie survival records spawn edge metrics"
	)
	_expect(
		int(metrics.get("inside_camera_spawns", 0)) == 0,
		"zombie survival metric spawns stay outside the camera"
	)
	_expect(
		int(metrics.get("spawn_rejections", 0)) == 0,
		"zombie survival metric spawns are accepted by spawn validation"
	)
	_expect(
		_seen_biome_count() >= 1,
		"zombie survival metric run records the active biome"
	)
	_expect(
		_flatten_enemy_ids().has("survival_runner"),
		"zombie survival metric run encounters base wave enemy variety"
	)
	_expect(
		wave_manager.get_enemies_remaining() == 0,
		"zombie survival has no leftover wave enemies after the metric run"
	)

func _expect_biome_definition_variant_window(
	biome_manager: BiomeManager,
	biome_id: StringName,
	wave_index: int
) -> void:
	var biome := biome_manager.get_biome_definition(biome_id) as BiomeDefinition
	_expect(biome != null, "%s biome definition is registered" % String(biome_id))
	if biome == null:
		return
	_expect_variant_window(biome, biome_id, wave_index, "registered")

func _expect_variant_window(
	biome: BiomeDefinition,
	biome_id: StringName,
	wave_index: int,
	label: String
) -> void:
	var expected_ids: Array = EXPECTED_THEMATIC_IDS.get(biome_id, [])
	var found := false
	for spawn_index in range(32):
		var enemy_id := String(
			biome.resolve_enemy_id(wave_index, spawn_index, 32)
		)
		if expected_ids.has(enemy_id):
			found = true
			break
	_expect(
		found,
		"%s %s wave table can produce thematic enemy variants"
		% [String(biome_id), label]
	)

func _flatten_enemy_ids() -> PackedStringArray:
	var result := PackedStringArray()
	var ids_by_wave := metrics.get("enemy_ids", {}) as Dictionary
	for value in ids_by_wave.values():
		var ids := value as PackedStringArray
		for enemy_id in ids:
			result.append(enemy_id)
	return result

func _seen_biome_count() -> int:
	var seen := {}
	var biome_ids := metrics.get("biome_ids", {}) as Dictionary
	for value in biome_ids.values():
		var biome_id := StringName(value)
		if not biome_id.is_empty():
			seen[biome_id] = true
	return seen.size()

func _make_guaranteed_money_loot(amount: int) -> LootTable:
	var money_entry := DropEntry.new()
	money_entry.drop_type = GameConstants.DROP_MONEY
	money_entry.chance = 1.0
	money_entry.min_amount = amount
	money_entry.max_amount = amount
	var loot := LootTable.new()
	loot.entries = [money_entry]
	return loot

func _wait_for_wave_combat(wave_index: int) -> bool:
	for _frame in range(900):
		if (
			wave_manager.current_wave == wave_index
			and wave_manager.state == WaveManager.State.COMBAT
		):
			return true
		await physics_frame
	return false

func _wait_for_wave_completed(wave_index: int) -> bool:
	for _frame in range(300):
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
		print("MILESTONE_12_ZOMBIE_BALANCE_METRICS_SMOKE_TEST: PASS")
		quit(0)
		return
	print(
		"MILESTONE_12_ZOMBIE_BALANCE_METRICS_SMOKE_TEST: FAIL (%d)"
		% failures.size()
	)
	quit(1)
