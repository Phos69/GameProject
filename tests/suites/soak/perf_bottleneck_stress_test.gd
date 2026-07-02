extends GutTest
## Soak/Diagnostica — Stress mirato per isolare il collo di bottiglia "molti mob".
##
## NON è un gate anti-regressione: stampa misure (righe PERF_*) da confrontare
## fra loro; le assert sono solo sanity-check larghissimi contro blocchi totali.
##
## Ipotesi sotto misura:
##   H1 costo unitario delle query spaziali (ObstacleSystem/HazardSystem/seam)
##      che A* e i probe LOS moltiplicano per centinaia di celle
##   H2 scan void per-frame su TUTTI i nemici (HazardSystem._check_void_entities)
##   H3 costo script per-frame dei visual (ZombieVisual._process + queue_redraw)
##   H4 spike allo spawn: instantiate+configure vs ricerca posizione spawner
##   H5 scaling del frame con N nemici e decomposizione AI / visual / resto
##
## Esecuzione (solo questa suite):
##   tools/run_gut.ps1 -Config res://.gutconfig.soak.json -Select perf_bottleneck

const ENEMY_IDS: Array[StringName] = [
	&"survival_zombie", &"survival_runner", &"survival_tank", &"survival_shooter"
]
const WORLD_CONTEXT := {
	"world_seed": 641004,
	"biome_map_width": 3,
	"biome_map_height": 3,
	"extra_edge_chance": 0.5
}
const MEASURE_FRAMES := 45
const SETTLE_FRAMES := 6

var _scene

func before_all() -> void:
	_scene = _new_main_scene_fixture()
	assert_true(_scene.boot(self), "main scene can be loaded for perf diagnostics")
	await wait_physics_frames(3)

func after_each() -> void:
	_scene.stop_survival()
	await wait_physics_frames(1)

func after_all() -> void:
	if _scene != null:
		_scene.stop_survival()
		await wait_physics_frames(1)
		_scene.teardown()
	_scene = null
	WorldDataCache.clear()
	IsometricEnvironmentManifest.clear_shared()
	IsometricEnvironmentObject.clear_content_metrics_cache()
	await wait_physics_frames(3)

# --- H1: costo unitario delle query spaziali ---------------------------------

func test_a_query_unit_costs() -> void:
	await _start_world()
	var obstacle_system: ObstacleSystem = _scene.node(&"obstacle_system") as ObstacleSystem
	var hazard_system: HazardSystem = _scene.node(&"hazard_system") as HazardSystem
	var seam_system = _scene.node(&"region_seam_system")
	assert_not_null(obstacle_system, "obstacle system is available")
	assert_not_null(hazard_system, "hazard system is available")
	if obstacle_system == null or hazard_system == null or seam_system == null:
		return

	# Dimensioni dei gruppi che _is_position_blocked scandisce A OGNI chiamata:
	# è il moltiplicatore nascosto del costo A*.
	var blocker_count := get_tree().get_nodes_in_group("spawn_blockers").size()
	var obstacle_count := get_tree().get_nodes_in_group("environment_obstacles").size()
	var hazard_count := get_tree().get_nodes_in_group("environment_hazards").size()
	gut.p("PERF_GROUPS: spawn_blockers=%d environment_obstacles=%d environment_hazards=%d nodes=%d" % [
		blocker_count, obstacle_count, hazard_count,
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	])

	var center := _player_position()
	var samples := PackedVector2Array()
	for gy in range(-4, 4):
		for gx in range(-4, 4):
			samples.append(center + Vector2(float(gx) * 150.0 + 75.0, float(gy) * 150.0 + 75.0))

	var obstacle_usec := _time_position_calls(
		func(p: Vector2) -> void: obstacle_system.is_position_blocked(p),
		samples, 2000
	)
	var void_usec := _time_position_calls(
		func(p: Vector2) -> void: hazard_system.is_void_at_world_position(p),
		samples, 2000
	)
	var seam_usec := _time_position_calls(
		func(p: Vector2) -> void: seam_system.get_region_id_for_world_position(p),
		samples, 2000
	)
	var env_hazard_usec := _time_position_calls(
		func(p: Vector2) -> void: hazard_system.is_position_environment_hazard(p),
		samples, 500
	)
	gut.p("PERF_QUERY: obstacle_blocked=%.2f us/call void_at=%.2f us/call seam_region=%.2f us/call env_hazard=%.2f us/call" % [
		obstacle_usec, void_usec, seam_usec, env_hazard_usec
	])
	# Proiezione: costo di UNA ricompute A* al budget massimo (~400 celle uniche
	# interrogate) e dello scan void con 100 nemici, derivati dal costo unitario.
	gut.p("PERF_QUERY_PROJECTION: astar_full_recompute~%.2f ms void_scan_100_enemies~%.2f ms/frame" % [
		obstacle_usec * 400.0 / 1000.0, void_usec * 100.0 / 1000.0
	])
	assert_lt(obstacle_usec, 5000.0, "obstacle query stays below 5 ms/call (sanity)")

# --- H1: costo reale del pathfinder (tick LOS vs ricompute A*) ----------------

func test_b_pathfinder_tick_costs() -> void:
	await _start_world()
	var obstacle_system: ObstacleSystem = _scene.node(&"obstacle_system") as ObstacleSystem
	var hazard_system: HazardSystem = _scene.node(&"hazard_system") as HazardSystem
	if obstacle_system == null or hazard_system == null:
		assert_not_null(obstacle_system, "obstacle system is available")
		return

	# Caso 1 — campo aperto: il tick 10Hz fa solo il probe LOS (~6 celle).
	var open_from := _player_position() + Vector2(0.0, -180.0)
	var open_to := _player_position() + Vector2(0.0, 180.0)
	var open_usec := _time_pathfinder_calls(open_from, open_to, obstacle_system, hazard_system, 400)

	# Caso 2 — LOS bloccata, goal oltre il budget: A* brucia MAX_EXPANSIONS
	# intere e ritorna un path parziale. È il worst-case del "calcolo percorso".
	var anchor := _find_blocked_anchor(obstacle_system)
	if anchor == Vector2.INF:
		gut.p("PERF_PATHFINDER: nessun ostacolo utilizzabile trovato, caso worst-case saltato")
		pass_test("open-field cost measured; no blocked anchor available")
		return
	var blocked_from := anchor + Vector2(-100.0, 0.0)
	var far_goal := anchor + Vector2(48.0 * 400.0, 0.0)
	var capped_usec := _time_pathfinder_calls(blocked_from, far_goal, obstacle_system, hazard_system, 40)

	# Caso 3 — detour tipico: goal raggiungibile subito oltre l'ostacolo.
	var near_goal := anchor + Vector2(220.0, 0.0)
	var detour_usec := _time_pathfinder_calls(blocked_from, near_goal, obstacle_system, hazard_system, 40)

	gut.p("PERF_PATHFINDER: open_tick=%.1f us capped_recompute=%.1f us (%.2f ms) detour_recompute=%.1f us" % [
		open_usec, capped_usec, capped_usec / 1000.0, detour_usec
	])
	# Con M nemici che ricomputano insieme allo stesso tick 10Hz (nessun jitter di
	# fase): spike stimato = M * ricompute. Stampiamo la proiezione per 24 mob.
	gut.p("PERF_PATHFINDER_PROJECTION: 24_mob_synced_spike~%.2f ms" % (capped_usec * 24.0 / 1000.0))
	# Sanity larghissimo: misurato ~246 ms/call con 387 ostacoli streamed (vedi
	# report perf); il tetto serve solo a intercettare blocchi totali.
	assert_lt(capped_usec, 2000000.0, "capped A* recompute stays below 2 s/call (sanity)")

# --- H4: spike allo spawn (burst singolo frame + ricerca posizione) -----------

func test_c_spawn_burst_costs() -> void:
	await _start_world()
	var enemy_system: EnemySystem = _scene.node(&"enemy_system") as EnemySystem
	var zombie_spawner: ZombieSpawner = _scene.node(&"zombie_spawner") as ZombieSpawner
	assert_not_null(enemy_system, "enemy system is available")
	if enemy_system == null:
		return
	var center := _player_position()

	# 1) Ricerca posizione dello spawner reale (validazioni + retry cascade).
	if zombie_spawner != null:
		var biome = null
		var wave_director = _scene.node(&"wave_director")
		if wave_director != null:
			biome = wave_director.get_current_biome()
		var search_total_usec := 0
		var search_worst_usec := 0
		var attempts_total := 0
		var attempts_worst := 0
		for index in range(24):
			var t0 := Time.get_ticks_usec()
			zombie_spawner.get_spawn_position(index, &"survival_zombie", biome)
			var call_usec := int(Time.get_ticks_usec() - t0)
			search_total_usec += call_usec
			search_worst_usec = maxi(search_worst_usec, call_usec)
			var report := zombie_spawner.get_last_spawn_attempt_report()
			attempts_total += report.size()
			attempts_worst = maxi(attempts_worst, report.size())
		gut.p("PERF_SPAWNER_SEARCH: avg=%.2f ms worst=%.2f ms attempts_avg=%.1f attempts_worst=%d last_edge=%s last_reason=%s" % [
			float(search_total_usec) / 24.0 / 1000.0,
			float(search_worst_usec) / 1000.0,
			float(attempts_total) / 24.0,
			attempts_worst,
			String(zombie_spawner.get_last_spawn_edge()),
			String(zombie_spawner.get_last_spawn_rejection_reason())
		])

	# 2) Burst di 24 istanze nello STESSO frame: instantiate+configure+add_child.
	var burst: Array[Node] = []
	var burst_t0 := Time.get_ticks_usec()
	for index in range(24):
		var angle := TAU * float(index) / 24.0
		var enemy := enemy_system.spawn_enemy(
			ENEMY_IDS[index % ENEMY_IDS.size()],
			center + Vector2.RIGHT.rotated(angle) * (260.0 + float(index % 4) * 30.0),
			null,
			{"wave_index": 4}
		)
		if enemy != null:
			burst.append(enemy)
	var burst_usec := int(Time.get_ticks_usec() - burst_t0)
	assert_eq(burst.size(), 24, "burst spawns the full pack")
	gut.p("PERF_SPAWN_BURST: total=%.2f ms per_enemy=%.2f ms (24 nello stesso frame)" % [
		float(burst_usec) / 1000.0, float(burst_usec) / 24.0 / 1000.0
	])

	# 3) I 12 frame successivi, singolarmente: il primo physics frame paga il
	# primo tick AI di TUTTI i nemici insieme; i tick 10Hz restano in fase, quindi
	# ci aspettiamo uno spike ogni ~6 frame se l'AI domina.
	var frame_log := PackedFloat32Array()
	for _frame in range(12):
		var f0 := Time.get_ticks_usec()
		await get_tree().physics_frame
		frame_log.append(float(Time.get_ticks_usec() - f0) / 1000.0)
	var frame_text := ""
	for value in frame_log:
		frame_text += "%.1f " % value
	gut.p("PERF_POST_BURST_FRAMES_MS: %s" % frame_text.strip_edges())
	assert_lt(float(burst_usec) / 1000.0, 2000.0, "burst spawn stays below 2 s (sanity)")
	_free_enemies(burst)
	await wait_physics_frames(2)

# --- H2/H3/H5: scaling con N nemici e decomposizione --------------------------

func test_d_frame_scaling_and_decomposition() -> void:
	await _start_world()
	var enemy_system: EnemySystem = _scene.node(&"enemy_system") as EnemySystem
	var hazard_system: HazardSystem = _scene.node(&"hazard_system") as HazardSystem
	assert_not_null(enemy_system, "enemy system is available")
	if enemy_system == null:
		return

	var baseline := await _measure_frames(MEASURE_FRAMES)
	gut.p("PERF_SCALING: n=0 wall_avg=%.2f ms wall_worst=%.2f ms physics_avg=%.2f ms process_avg=%.2f ms" % [
		baseline.wall_avg, baseline.wall_worst, baseline.physics_avg, baseline.process_avg
	])

	for enemy_count in [24, 96, 192]:
		var enemies := await _spawn_ring(enemy_system, enemy_count)
		await wait_physics_frames(SETTLE_FRAMES)
		var full := await _measure_frames(MEASURE_FRAMES)
		gut.p("PERF_SCALING: n=%d wall_avg=%.2f ms wall_worst=%.2f ms physics_avg=%.2f ms process_avg=%.2f ms" % [
			enemy_count, full.wall_avg, full.wall_worst, full.physics_avg, full.process_avg
		])

		if enemy_count == 96:
			# Decomposizione: spegni l'AI (physics_process) → resta visual+sistemi;
			# poi spegni anche il _process dei visual → resta lo scan dei sistemi.
			for enemy in enemies:
				if is_instance_valid(enemy):
					enemy.set_physics_process(false)
			await wait_physics_frames(2)
			var no_ai := await _measure_frames(30)
			for enemy in enemies:
				if is_instance_valid(enemy) and enemy.get("visual") != null:
					(enemy.get("visual") as Node).set_process(false)
			await wait_physics_frames(2)
			var no_ai_no_visual := await _measure_frames(30)
			gut.p("PERF_DECOMPOSITION_96: full_wall=%.2f ms no_ai_wall=%.2f ms no_ai_no_visual_wall=%.2f ms (ai~%.2f visual~%.2f resto~%.2f)" % [
				full.wall_avg, no_ai.wall_avg, no_ai_no_visual.wall_avg,
				full.wall_avg - no_ai.wall_avg,
				no_ai.wall_avg - no_ai_no_visual.wall_avg,
				no_ai_no_visual.wall_avg - baseline.wall_avg
			])

		if enemy_count == 192 and hazard_system != null:
			# H2 isolata: costo per-frame dello scan void (ogni chiamata copre
			# una fetta 1/VOID_CHECK_ENEMY_SLICES dei nemici, come in _process).
			var t0 := Time.get_ticks_usec()
			for _index in range(60):
				hazard_system._check_void_entities()
			var scan_ms := float(Time.get_ticks_usec() - t0) / 60.0 / 1000.0
			gut.p("PERF_VOID_SCAN_192: %.3f ms/frame (scan a fette, chiamato ogni frame in HazardSystem._process)" % scan_ms)

		_free_enemies(enemies)
		await wait_physics_frames(3)

	assert_lt(baseline.wall_avg, 250.0, "empty world frame stays below 250 ms (sanity)")

# --- helper -------------------------------------------------------------------

func _start_world() -> void:
	assert_true(_scene.start_survival(WORLD_CONTEXT.duplicate()), "survival starts for perf diagnostics")
	await wait_physics_frames(3)
	# Riproducibilita': se il player muore sotto la massa, i nemici tornano IDLE
	# (niente target -> niente pathfinding) e la scala misurerebbe il nulla.
	for player in get_tree().get_nodes_in_group("players"):
		var health_component := player.get_node_or_null("HealthComponent") as HealthComponent
		if health_component != null:
			health_component.add_invulnerability_source(&"perf_stress_suite")

func _player_position() -> Vector2:
	var player_manager: PlayerManager = _scene.node(&"player_manager") as PlayerManager
	if player_manager != null:
		var player_one := player_manager.players.get(1) as Node2D
		if player_one != null:
			return player_one.global_position
	return Vector2.ZERO

func _time_position_calls(callable: Callable, samples: PackedVector2Array, iterations: int) -> float:
	if samples.is_empty():
		return 0.0
	# warm-up (cache dei riferimenti interni ai sistemi)
	for index in range(mini(64, iterations)):
		callable.call(samples[index % samples.size()])
	var t0 := Time.get_ticks_usec()
	for index in range(iterations):
		callable.call(samples[index % samples.size()])
	return float(Time.get_ticks_usec() - t0) / float(iterations)

## Ogni iterazione usa un pathfinder NUOVO con delta >= AI_TICK_INTERVAL: il
## primo tick e' defasato per-istanza (P2), quindi serve un delta che azzeri il
## cooldown iniziale per far scattare subito _evaluate_aim (probe LOS +
## eventuale A*) e misurare il costo pieno del tick decisionale.
func _time_pathfinder_calls(
	from: Vector2,
	to: Vector2,
	obstacle_system: Object,
	hazard_system: Object,
	iterations: int
) -> float:
	var t0 := Time.get_ticks_usec()
	for _index in range(iterations):
		var pathfinder := EnemyPathfinder.new()
		pathfinder.desired_direction(from, to, 0, 1.0, obstacle_system, hazard_system)
	return float(Time.get_ticks_usec() - t0) / float(iterations)

func _find_blocked_anchor(obstacle_system: ObstacleSystem) -> Vector2:
	for obstacle in obstacle_system.get_active_obstacles():
		if obstacle == null or not is_instance_valid(obstacle):
			continue
		var position := (obstacle as Node2D).global_position
		if (
			obstacle_system.is_position_blocked(position)
			and not obstacle_system.is_position_blocked(position + Vector2(-100.0, 0.0))
		):
			return position
	return Vector2.INF

func _spawn_ring(enemy_system: EnemySystem, count: int) -> Array[Node]:
	var center := _player_position()
	var enemies: Array[Node] = []
	for index in range(count):
		var angle := TAU * float(index) / float(count)
		var radius := 240.0 + float(index % 8) * 36.0
		var enemy := enemy_system.spawn_enemy(
			ENEMY_IDS[index % ENEMY_IDS.size()],
			center + Vector2.RIGHT.rotated(angle) * radius,
			null,
			{"wave_index": 4}
		)
		if enemy != null:
			enemies.append(enemy)
		# Batch da 24 per frame: il costo del burst è già misurato altrove.
		if index % 24 == 23:
			await get_tree().physics_frame
	return enemies

func _free_enemies(enemies: Array[Node]) -> void:
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()

class FrameStats:
	var wall_avg: float = 0.0
	var wall_worst: float = 0.0
	var physics_avg: float = 0.0
	var process_avg: float = 0.0

## Misura frames physics consecutivi: wall time per frame (include l'eventuale
## sleep di pacing) + monitor engine (solo lavoro: physics step e process step).
func _measure_frames(frames: int) -> FrameStats:
	var stats := FrameStats.new()
	var wall_sum := 0.0
	var physics_sum := 0.0
	var process_sum := 0.0
	for _frame in range(frames):
		var t0 := Time.get_ticks_usec()
		await get_tree().physics_frame
		var frame_ms := float(Time.get_ticks_usec() - t0) / 1000.0
		wall_sum += frame_ms
		stats.wall_worst = maxf(stats.wall_worst, frame_ms)
		physics_sum += float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0
		process_sum += float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0
	stats.wall_avg = wall_sum / float(frames)
	stats.physics_avg = physics_sum / float(frames)
	stats.process_avg = process_sum / float(frames)
	return stats

func _new_main_scene_fixture():
	var script := ResourceLoader.load(
		"res://tests/support/main_scene_fixture.gd",
		"",
		ResourceLoader.CACHE_MODE_IGNORE
	) as Script
	assert_true(script != null, "main scene fixture script loads")
	return script.new() if script != null else null
