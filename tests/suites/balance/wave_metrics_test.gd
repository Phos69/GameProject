extends GutTest
## Balance A10 — Metriche d'ondata su infinite arena e zombie survival.
##
## Migra e accorpa (entrambi bootano main.tscn, uno per test via fixture):
##   tests/milestone_12_balance_metrics_smoke_test.gd         (infinite arena)
##   tests/milestone_12_zombie_balance_metrics_smoke_test.gd  (zombie survival)
##
## La raccolta metriche via segnali (wave/drop/damage/boss) e identica fra i due
## scenari: e centralizzata negli handler condivisi qui sotto. Ogni test resetta
## lo stato e (ri)connette i segnali sulla propria istanza fresca di main.tscn.

const MainSceneFixture = preload("res://tests/support/main_scene_fixture.gd")

const EXPECTED_THEMATIC_IDS := {
	&"toxic_wastes": ["toxic_zombie", "toxic_exploder"],
	&"burning_fields": ["burned_zombie", "fire_runner", "fire_exploder"],
	&"frozen_outskirts": ["frozen_zombie", "ice_armored_zombie", "heavy_slow_zombie"],
	&"drowned_marsh": ["drowned_zombie", "marsh_zombie", "water_emerging_zombie"]
}

var _metrics: Dictionary = {}
var _wave_start_frames: Dictionary = {}
var _wave_manager: WaveManager
var _zombie_spawner: ZombieSpawner
var _guaranteed_money_loot: LootTable
var _metrics_active: bool = false
var _track_boss: bool = false

# --- infinite arena (milestone_12_balance_metrics) --------------------------

func test_infinite_arena_metrics() -> void:
	var scene := MainSceneFixture.new()
	assert_true(scene.boot(self), "main scene can be loaded")
	await wait_frames(4)

	var game_mode_manager := scene.node(&"game_mode_manager") as GameModeManager
	var survival_mode := scene.node(&"survival_mode") as SurvivalMode
	var wave_manager := scene.node(&"wave_manager") as WaveManager
	var health_system := scene.node(&"health_system") as HealthSystem
	var drop_system := scene.node(&"drop_system") as DropSystem
	var boss_system := scene.node(&"boss_system") as BossSystem
	var player_manager := scene.node(&"player_manager") as PlayerManager
	var biome_manager := scene.node(&"biome_manager") as BiomeManager
	var zombie_spawner := scene.node(&"zombie_spawner") as ZombieSpawner
	var zombie_mode_controller := scene.node(&"zombie_mode_controller") as ZombieModeController
	var world_runtime := scene.node(&"world_runtime") as WorldRuntime
	assert_not_null(game_mode_manager, "game mode manager is available")
	assert_not_null(survival_mode, "survival mode is available")
	assert_not_null(wave_manager, "wave manager is available")
	assert_not_null(health_system, "health system is available")
	assert_not_null(drop_system, "drop system is available")
	assert_not_null(boss_system, "boss system is available")
	assert_not_null(player_manager, "player manager is available")
	assert_not_null(biome_manager, "biome manager is available")
	assert_not_null(zombie_spawner, "zombie spawner is available")
	assert_not_null(zombie_mode_controller, "zombie controller is available")
	assert_not_null(world_runtime, "world runtime is available")
	if (
		game_mode_manager == null or survival_mode == null or wave_manager == null
		or health_system == null or drop_system == null or boss_system == null
		or player_manager == null or biome_manager == null or zombie_spawner == null
		or zombie_mode_controller == null or world_runtime == null
	):
		scene.teardown()
		return

	_wave_manager = wave_manager
	_zombie_spawner = zombie_spawner
	_guaranteed_money_loot = _make_guaranteed_money_loot(1)
	_track_boss = true
	_connect_metric_signals(wave_manager, drop_system, health_system, boss_system)
	assert_true(
		boss_system.get_registered_boss_ids().has(&"wave_warden"),
		"boss registry exposes the survival wave boss"
	)

	_configure_fast_waves(wave_manager, survival_mode, 5, 3, 1, 5, 0.02)
	_reset_metrics()
	assert_true(
		game_mode_manager.set_mode(GameConstants.MODE_INFINITE_ARENA, {"world_seed": 20260622}),
		"infinite arena starts through the game mode manager"
	)
	# La generazione del mondo arena puo completare in modo asincrono: si attende
	# che la biome map sia pronta invece di un numero fisso di frame.
	await _poll_idle(func() -> bool: return biome_manager.get_generated_biome_map().size() >= 1, 600)

	var player := player_manager.players.get(1) as PlayerController
	assert_not_null(player, "infinite arena has player one")
	if player == null:
		_finish_metrics()
		scene.teardown()
		return
	player.global_position = Vector2.ZERO

	assert_eq(
		game_mode_manager.active_mode_id, GameConstants.MODE_INFINITE_ARENA,
		"infinite arena is the active gameplay mode"
	)
	assert_false(
		zombie_mode_controller.world_runtime_enabled_for_run,
		"infinite arena disables world runtime"
	)
	assert_false(world_runtime.is_active, "infinite arena keeps world runtime inactive")
	assert_eq(
		biome_manager.get_generated_biome_map().size(), 1,
		"infinite arena uses a single compact biome cell"
	)

	await _complete_metric_waves(wave_manager, health_system, player, 5)
	_validate_common_metrics(_metrics, 5, "infinite arena")
	assert_gte(int(_metrics.get("boss_requests", 0)), 1, "infinite arena reaches a boss wave request")
	assert_gte(int(_metrics.get("boss_spawns", 0)), 1, "infinite arena boss spawns through the registry")
	var enemy_ids := _flatten_enemy_ids(_metrics)
	assert_true(enemy_ids.has("survival_runner"), "infinite arena wave mix includes runners")
	assert_true(enemy_ids.has("survival_tank"), "infinite arena wave mix includes tanks")
	assert_true(enemy_ids.has("survival_shooter"), "infinite arena wave mix includes shooters")
	# Ferma lo spawn delle ondate successive prima di contare i residui: con
	# intermission corta una nuova ondata puo partire durante l'attesa.
	game_mode_manager.set_mode(GameConstants.MODE_MENU)
	await _poll_idle(func() -> bool: return wave_manager.get_enemies_remaining() == 0, 180)
	assert_eq(
		wave_manager.get_enemies_remaining(), 0,
		"infinite arena has no leftover wave enemies after the metric run"
	)

	_finish_metrics()
	scene.teardown()
	await wait_frames(1)

# --- zombie survival (milestone_12_zombie_balance_metrics) -------------------

func test_zombie_survival_metrics() -> void:
	var scene := MainSceneFixture.new()
	assert_true(scene.boot(self), "main scene can be loaded")
	await wait_frames(4)

	var game_mode_manager := scene.node(&"game_mode_manager") as GameModeManager
	var survival_mode := scene.node(&"survival_mode") as SurvivalMode
	var wave_manager := scene.node(&"wave_manager") as WaveManager
	var health_system := scene.node(&"health_system") as HealthSystem
	var drop_system := scene.node(&"drop_system") as DropSystem
	var player_manager := scene.node(&"player_manager") as PlayerManager
	var biome_manager := scene.node(&"biome_manager") as BiomeManager
	var zombie_spawner := scene.node(&"zombie_spawner") as ZombieSpawner
	var zombie_mode_controller := scene.node(&"zombie_mode_controller") as ZombieModeController
	var world_runtime := scene.node(&"world_runtime") as WorldRuntime
	assert_not_null(game_mode_manager, "game mode manager is available")
	assert_not_null(survival_mode, "survival mode is available")
	assert_not_null(wave_manager, "wave manager is available")
	assert_not_null(health_system, "health system is available")
	assert_not_null(drop_system, "drop system is available")
	assert_not_null(player_manager, "player manager is available")
	assert_not_null(biome_manager, "biome manager is available")
	assert_not_null(zombie_spawner, "zombie spawner is available")
	assert_not_null(zombie_mode_controller, "zombie controller is available")
	assert_not_null(world_runtime, "world runtime is available")
	if (
		game_mode_manager == null or survival_mode == null or wave_manager == null
		or health_system == null or drop_system == null or player_manager == null
		or biome_manager == null or zombie_spawner == null
		or zombie_mode_controller == null or world_runtime == null
	):
		scene.teardown()
		return

	_wave_manager = wave_manager
	_zombie_spawner = zombie_spawner
	_guaranteed_money_loot = _make_guaranteed_money_loot(1)
	_track_boss = false
	_connect_metric_signals(wave_manager, drop_system, health_system, null)
	_configure_fast_waves(wave_manager, survival_mode, 99, 6, 2, 0, 0.12)
	_reset_metrics()
	assert_true(
		game_mode_manager.set_mode(
			GameConstants.MODE_SURVIVAL,
			{"world_seed": 20260622, "biome_map_width": 3, "biome_map_height": 3}
		),
		"zombie survival starts through the game mode manager"
	)
	# Attende la generazione della mappa multi-bioma invece di un numero fisso di frame.
	await _poll_idle(func() -> bool: return biome_manager.get_generated_biome_map().size() >= 9, 600)

	var player := player_manager.players.get(1) as PlayerController
	assert_not_null(player, "zombie survival has player one")
	if player == null:
		_finish_metrics()
		scene.teardown()
		return
	player.global_position = Vector2.ZERO

	assert_eq(
		game_mode_manager.active_mode_id, GameConstants.MODE_SURVIVAL,
		"zombie survival is the active gameplay mode"
	)
	assert_true(
		zombie_mode_controller.world_runtime_enabled_for_run,
		"zombie survival keeps world runtime enabled"
	)
	assert_true(world_runtime.is_active, "zombie survival activates world runtime")
	assert_gte(
		biome_manager.get_generated_biome_map().size(), 9,
		"zombie survival generates the multi-biome map"
	)
	assert_false(
		world_runtime.get_active_region_ids().is_empty(),
		"zombie survival keeps streamed regions active"
	)
	for biome_id in EXPECTED_THEMATIC_IDS.keys():
		_expect_biome_definition_variant_window(biome_manager, StringName(biome_id), 4)

	assert_true(await _wait_for_wave_combat(wave_manager, 1, 900), "zombie survival wave 1 reaches combat")
	assert_eq(wave_manager.current_wave_biome_id, &"infected_plains", "wave 1 records infected plains")
	await _damage_and_clear_wave(health_system, player)
	assert_true(await _wait_for_wave_completed(wave_manager, 1, 300), "zombie survival wave 1 completes cleanly")
	await wait_frames(2)

	assert_true(await _wait_for_wave_combat(wave_manager, 2, 900), "zombie survival wave 2 reaches combat")
	assert_eq(wave_manager.current_wave_biome_id, &"infected_plains", "wave 2 records infected plains")
	await _damage_and_clear_wave(health_system, player)
	assert_true(await _wait_for_wave_completed(wave_manager, 2, 300), "zombie survival wave 2 completes cleanly")
	await wait_frames(4)

	# Ferma lo spawn prima di contare i residui (vedi infinite arena).
	game_mode_manager.set_mode(GameConstants.MODE_MENU)
	await _poll_idle(func() -> bool: return wave_manager.get_enemies_remaining() == 0, 180)
	_validate_zombie_metrics(wave_manager)
	_finish_metrics()
	scene.teardown()
	await wait_frames(1)

# --- raccolta metriche condivisa --------------------------------------------

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
	if boss_system != null:
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

func _reset_metrics() -> void:
	_wave_start_frames.clear()
	_metrics = {
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
	_metrics_active = true

func _finish_metrics() -> void:
	_metrics_active = false

func _complete_metric_waves(
	wave_manager: WaveManager,
	health_system: HealthSystem,
	player: PlayerController,
	wave_count: int
) -> void:
	for wave_index in range(1, wave_count + 1):
		assert_true(
			await _wait_for_wave_combat(wave_manager, wave_index, 1200),
			"wave %d reaches combat during metric run" % wave_index
		)
		health_system.apply_damage(player, 1, null, &"milestone_12_damage_probe", player.global_position)
		await _kill_active_wave(wave_manager, health_system, player)
		assert_true(
			await _wait_for_wave_completed(wave_manager, wave_index, 360),
			"wave %d completes during metric run" % wave_index
		)
		await wait_frames(4)

func _kill_active_wave(
	wave_manager: WaveManager,
	health_system: HealthSystem,
	player: PlayerController
) -> void:
	for enemy in wave_manager.get_active_wave_enemies():
		var hit_position := (enemy as Node2D).global_position if enemy is Node2D else Vector2.ZERO
		health_system.apply_damage(enemy, 999999, player, &"milestone_12_wave_clear", hit_position)
	var boss := wave_manager.get_active_boss()
	if boss != null:
		var boss_position := (boss as Node2D).global_position if boss is Node2D else Vector2.ZERO
		health_system.apply_damage(boss, 999999, player, &"milestone_12_boss_clear", boss_position)
	await wait_frames(2)

func _damage_and_clear_wave(health_system: HealthSystem, player: PlayerController) -> void:
	health_system.apply_damage(player, 1, null, &"milestone_12_damage_probe", player.global_position)
	for enemy in _wave_manager.get_active_wave_enemies():
		var hit_position := (enemy as Node2D).global_position if enemy is Node2D else Vector2.ZERO
		health_system.apply_damage(enemy, 999999, player, &"milestone_12_zombie_wave_clear", hit_position)
	await wait_frames(2)

func _on_wave_started(wave_index: int) -> void:
	if not _metrics_active:
		return
	_wave_start_frames[wave_index] = Engine.get_physics_frames()
	_update_live_peak(wave_index)

func _on_wave_configured(wave_index: int, enemy_count: int, _is_boss_wave: bool) -> void:
	if not _metrics_active:
		return
	var configured := _metrics["waves_configured"] as Array
	configured.append(wave_index)
	_metrics["waves_configured"] = configured
	(_metrics["wave_enemy_totals"] as Dictionary)[wave_index] = enemy_count
	(_metrics["biome_ids"] as Dictionary)[wave_index] = (
		_wave_manager.current_wave_biome_id if _wave_manager != null else &""
	)
	_update_live_peak(wave_index)

func _on_enemy_spawned(enemy: Node, spawn_position: Vector2, _spawn_index: int) -> void:
	if not _metrics_active:
		return
	if enemy is BasicEnemy:
		(enemy as BasicEnemy).loot_table = _guaranteed_money_loot
	enemy.set_physics_process(false)
	var wave_index := _wave_manager.current_wave if _wave_manager != null else 0
	var enemy_ids := _metrics["enemy_ids"] as Dictionary
	if not enemy_ids.has(wave_index):
		enemy_ids[wave_index] = PackedStringArray()
	var ids := enemy_ids[wave_index] as PackedStringArray
	ids.append(str(enemy.get("enemy_id")))
	enemy_ids[wave_index] = ids
	if _zombie_spawner != null:
		var spawn_edges := _metrics["spawn_edges"] as Array
		spawn_edges.append(String(_zombie_spawner.get_last_spawn_edge()))
		_metrics["spawn_edges"] = spawn_edges
		if not _zombie_spawner.is_position_outside_camera_view(spawn_position):
			_metrics["inside_camera_spawns"] = int(_metrics.get("inside_camera_spawns", 0)) + 1
		if not _zombie_spawner.get_last_spawn_rejection_reason().is_empty():
			_metrics["spawn_rejections"] = int(_metrics.get("spawn_rejections", 0)) + 1
	_update_live_peak(wave_index)

func _on_wave_completed(wave_index: int) -> void:
	if not _metrics_active:
		return
	var completed := _metrics["waves_completed"] as Array
	completed.append(wave_index)
	_metrics["waves_completed"] = completed
	var start_frame := int(_wave_start_frames.get(wave_index, Engine.get_physics_frames()))
	(_metrics["wave_durations"] as Dictionary)[wave_index] = Engine.get_physics_frames() - start_frame
	_update_live_peak(wave_index)

func _on_drop_spawned(_pickup: Node, _drop_data: Dictionary) -> void:
	if not _metrics_active:
		return
	_metrics["drops"] = int(_metrics.get("drops", 0)) + 1

func _on_damage_requested(_target: Node, amount: int) -> void:
	if not _metrics_active:
		return
	_metrics["damage_events"] = int(_metrics.get("damage_events", 0)) + 1
	_metrics["damage_total"] = int(_metrics.get("damage_total", 0)) + amount

func _on_boss_requested(_mode_id: StringName, _reason: StringName) -> void:
	if not _metrics_active:
		return
	_metrics["boss_requests"] = int(_metrics.get("boss_requests", 0)) + 1

func _on_boss_spawned(boss: Node) -> void:
	if not _metrics_active:
		return
	boss.set_physics_process(false)
	_metrics["boss_spawns"] = int(_metrics.get("boss_spawns", 0)) + 1
	if _wave_manager != null:
		_update_live_peak(_wave_manager.current_wave)

func _update_live_peak(wave_index: int) -> void:
	if not _metrics_active or _wave_manager == null:
		return
	var live_peaks := _metrics["live_peaks"] as Dictionary
	live_peaks[wave_index] = maxi(int(live_peaks.get(wave_index, 0)), _current_live_count())

func _current_live_count() -> int:
	if _wave_manager == null:
		return 0
	var count := _wave_manager.get_active_wave_enemies().size()
	if _track_boss and _wave_manager.get_active_boss() != null:
		count += 1
	return count

# --- validazione ------------------------------------------------------------

func _validate_common_metrics(metrics: Dictionary, expected_wave_count: int, label: String) -> void:
	var configured := metrics.get("waves_configured", []) as Array
	var completed := metrics.get("waves_completed", []) as Array
	var durations := metrics.get("wave_durations", {}) as Dictionary
	var live_peaks := metrics.get("live_peaks", {}) as Dictionary
	var enemy_totals := metrics.get("wave_enemy_totals", {}) as Dictionary
	for wave_index in range(1, expected_wave_count + 1):
		assert_true(configured.has(wave_index), "%s configures wave %d" % [label, wave_index])
		assert_true(completed.has(wave_index), "%s completes wave %d" % [label, wave_index])
		assert_true(durations.has(wave_index), "%s records wave %d duration" % [label, wave_index])
		assert_gte(int(durations.get(wave_index, -1)), 0, "%s wave %d duration metric is non-negative" % [label, wave_index])
		assert_gt(int(live_peaks.get(wave_index, 0)), 0, "%s records live enemies for wave %d" % [label, wave_index])
		assert_gte(int(enemy_totals.get(wave_index, 0)), 1, "%s records configured enemy total for wave %d" % [label, wave_index])
	assert_gte(int(metrics.get("drops", 0)), expected_wave_count, "%s records deterministic enemy drops" % label)
	assert_gte(int(metrics.get("damage_events", 0)), expected_wave_count, "%s records damage events" % label)
	assert_gt(int(metrics.get("damage_total", 0)), 0, "%s records positive damage total" % label)
	assert_false((metrics.get("spawn_edges", []) as Array).is_empty(), "%s records spawn edge metrics" % label)

func _validate_zombie_metrics(wave_manager: WaveManager) -> void:
	var configured := _metrics.get("waves_configured", []) as Array
	var completed := _metrics.get("waves_completed", []) as Array
	var durations := _metrics.get("wave_durations", {}) as Dictionary
	var live_peaks := _metrics.get("live_peaks", {}) as Dictionary
	var enemy_totals := _metrics.get("wave_enemy_totals", {}) as Dictionary
	for wave_index in range(1, 3):
		assert_true(configured.has(wave_index), "zombie survival configures wave %d" % wave_index)
		assert_true(completed.has(wave_index), "zombie survival completes wave %d" % wave_index)
		assert_true(durations.has(wave_index), "zombie survival records wave %d duration" % wave_index)
		assert_gt(int(live_peaks.get(wave_index, 0)), 0, "zombie survival records live enemies for wave %d" % wave_index)
		assert_gte(int(enemy_totals.get(wave_index, 0)), 1, "zombie survival records enemy total for wave %d" % wave_index)
	assert_gte(int(_metrics.get("drops", 0)), 2, "zombie survival records deterministic enemy drops")
	assert_gte(int(_metrics.get("damage_events", 0)), 2, "zombie survival records damage events")
	assert_gt(int(_metrics.get("damage_total", 0)), 0, "zombie survival records positive damage total")
	assert_false((_metrics.get("spawn_edges", []) as Array).is_empty(), "zombie survival records spawn edge metrics")
	assert_eq(int(_metrics.get("inside_camera_spawns", 0)), 0, "zombie survival metric spawns stay outside the camera")
	assert_eq(int(_metrics.get("spawn_rejections", 0)), 0, "zombie survival metric spawns are accepted by spawn validation")
	assert_gte(_seen_biome_count(), 1, "zombie survival metric run records the active biome")
	assert_true(_flatten_enemy_ids(_metrics).has("survival_runner"), "zombie survival metric run encounters base wave enemy variety")
	assert_eq(wave_manager.get_enemies_remaining(), 0, "zombie survival has no leftover wave enemies after the metric run")

func _expect_biome_definition_variant_window(biome_manager: BiomeManager, biome_id: StringName, wave_index: int) -> void:
	var biome := biome_manager.get_biome_definition(biome_id) as BiomeDefinition
	assert_not_null(biome, "%s biome definition is registered" % String(biome_id))
	if biome == null:
		return
	var expected_ids: Array = EXPECTED_THEMATIC_IDS.get(biome_id, [])
	var found := false
	for spawn_index in range(32):
		var enemy_id := String(biome.resolve_enemy_id(wave_index, spawn_index, 32))
		if expected_ids.has(enemy_id):
			found = true
			break
	assert_true(found, "%s registered wave table can produce thematic enemy variants" % String(biome_id))

# --- helper -----------------------------------------------------------------

func _flatten_enemy_ids(metrics: Dictionary) -> PackedStringArray:
	var result := PackedStringArray()
	var ids_by_wave := metrics.get("enemy_ids", {}) as Dictionary
	for value in ids_by_wave.values():
		var ids := value as PackedStringArray
		for enemy_id in ids:
			result.append(enemy_id)
	return result

func _seen_biome_count() -> int:
	var seen := {}
	var biome_ids := _metrics.get("biome_ids", {}) as Dictionary
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

func _wait_for_wave_combat(wave_manager: WaveManager, wave_index: int, max_frames: int) -> bool:
	for _frame in range(max_frames):
		if wave_manager.current_wave == wave_index and wave_manager.state == WaveManager.State.COMBAT:
			return true
		await get_tree().physics_frame
	return false

func _wait_for_wave_completed(wave_manager: WaveManager, wave_index: int, max_frames: int) -> bool:
	for _frame in range(max_frames):
		if wave_manager.current_wave == wave_index and not wave_manager.wave_running:
			return true
		await get_tree().physics_frame
	return false

# Attesa su frame idle (_process) finche la condizione e vera o si esaurisce il
# budget: la generazione del mondo e gli aggiornamenti di stato girano in _process.
func _poll_idle(cond: Callable, max_frames: int) -> void:
	for _i in range(max_frames):
		if bool(cond.call()):
			return
		await get_tree().process_frame
