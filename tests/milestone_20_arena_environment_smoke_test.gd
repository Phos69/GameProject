extends SceneTree

var failures: PackedStringArray = []
var explosion_targets: Array[Node] = []

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
	await process_frame
	await process_frame
	await process_frame

	var game_mode_manager := get_first_node_in_group(
		"game_mode_manager"
	) as GameModeManager
	var arena_manager := get_first_node_in_group(
		"survival_arena_manager"
	) as SurvivalArenaManager
	var wave_manager := get_first_node_in_group(
		"wave_manager"
	) as WaveManager
	var local_multiplayer := get_first_node_in_group(
		"local_multiplayer_manager"
	) as LocalMultiplayerManager
	var player_manager := get_first_node_in_group(
		"player_manager"
	) as PlayerManager
	var enemy_system := get_first_node_in_group(
		"enemy_system"
	) as EnemySystem
	var projectile_system := get_first_node_in_group(
		"projectile_system"
	) as ProjectileSystem
	var playground := main.get_node_or_null(
		"World/Playground"
	) as IsometricPlayground
	var hud := get_first_node_in_group("hud_manager") as HUDManager
	_expect(game_mode_manager != null, "game mode manager is available")
	_expect(arena_manager != null, "survival arena manager is available")
	_expect(wave_manager != null, "wave manager is available")
	_expect(local_multiplayer != null, "local multiplayer manager is available")
	_expect(player_manager != null, "player manager is available")
	_expect(enemy_system != null, "enemy system is available")
	_expect(projectile_system != null, "projectile system is available")
	_expect(playground != null, "shared playground is available")
	_expect(hud != null, "HUD manager is available")
	if (
		game_mode_manager == null
		or arena_manager == null
		or wave_manager == null
		or local_multiplayer == null
		or player_manager == null
		or enemy_system == null
		or projectile_system == null
		or playground == null
		or hud == null
	):
		_finish()
		return

	var arena_ids := arena_manager.get_available_arena_ids()
	_expect(
		arena_ids.has(&"industrial_crossroads")
		and arena_ids.has(&"rift_foundry"),
		"two arena profiles are registered"
	)
	for player_slot in range(2, 5):
		local_multiplayer.activate_slot(player_slot)
	wave_manager.initial_delay = 100.0
	game_mode_manager.set_mode(
		GameConstants.MODE_SURVIVAL,
		{"arena_id": &"industrial_crossroads"}
	)
	await process_frame
	await process_frame

	_expect(
		arena_manager.get_active_arena_id() == &"industrial_crossroads",
		"survival context selects the industrial arena"
	)
	_expect(
		playground.layout_kind == &"crossroads",
		"industrial arena configures the shared playground"
	)
	_expect(
		wave_manager.spawn_points.size() == 8,
		"industrial profile configures all wave spawn points"
	)
	_expect(
		arena_manager.get_spawn_gates().size()
		== wave_manager.spawn_points.size(),
		"every enemy spawn has a visible gate"
	)
	_expect(
		arena_manager.get_interactive_props().size() == 2,
		"industrial profile creates its interactive props"
	)
	_expect(
		hud._get_mode_title() == "Industrial Crossroads",
		"HUD exposes the selected arena name"
	)
	_expect(
		_players_match_spawns(
			player_manager,
			arena_manager.active_profile.player_spawn_points
		),
		"four players are positioned from arena data"
	)

	var barrel := arena_manager.get_interactive_props()[0] as ExplosiveBarrel
	_expect(barrel != null, "explosive barrel is available")
	if barrel == null:
		_finish()
		return
	_expect(
		barrel.get_class() == "Area2D"
		and barrel.collision_mask == 0,
		"interactive prop is projectile-readable but never blocks pathing"
	)
	barrel.warning_duration = 5.0
	barrel.explosion_damage = 36
	barrel.exploded.connect(_on_barrel_exploded)
	var target_enemy := enemy_system.spawn_enemy(
		&"survival_zombie",
		barrel.global_position + Vector2(68.0, 0.0)
	) as BasicEnemy
	_expect(target_enemy != null, "damage target spawns near the barrel")
	if target_enemy == null:
		_finish()
		return
	target_enemy.set_physics_process(false)
	var enemy_health_before := target_enemy.health_component.current_health
	var player := player_manager.players.get(1) as PlayerController
	var projectile := projectile_system.spawn_projectile(
		barrel.global_position + Vector2(-70.0, 0.0),
		Vector2.RIGHT,
		720.0,
		player,
		null,
		barrel.health_component.max_health,
		&"arena_prop_test"
	)
	_expect(projectile != null, "player projectile is spawned for prop collision")
	for _frame in range(12):
		await physics_frame
		if barrel.is_armed:
			break
	_expect(barrel.is_armed, "projectile collision arms the explosive prop")
	_expect(
		target_enemy.health_component.current_health == enemy_health_before,
		"barrel deals no damage during its warning"
	)
	_expect(
		barrel.warning_time_left > 0.0,
		"explosion warning exposes reaction time"
	)
	barrel.advance_warning(barrel.warning_duration)
	_expect(barrel.has_exploded, "warning completion triggers the explosion")
	_expect(
		target_enemy.health_component.current_health < enemy_health_before,
		"explosion applies area damage through HealthSystem"
	)
	_expect(
		explosion_targets.has(target_enemy),
		"explosion reports every damaged target"
	)
	await process_frame

	_expect(
		arena_manager.activate_arena(&"rift_foundry"),
		"second arena can be selected without replacing SurvivalMode"
	)
	await process_frame
	_expect(
		arena_manager.get_active_arena_id() == &"rift_foundry"
		and playground.layout_kind == &"ring",
		"rift profile swaps layout data on the shared playground"
	)
	_expect(
		wave_manager.spawn_points.size() == 6
		and arena_manager.get_spawn_gates().size() == 6,
		"rift profile replaces wave spawns and gates"
	)
	_expect(
		arena_manager.get_interactive_props().size() == 3,
		"rift profile owns a distinct prop layout"
	)
	wave_manager.base_enemy_count = 1
	wave_manager.enemy_count_growth = 0
	wave_manager.spawn_interval = 0.0
	wave_manager.start_next_wave()
	await process_frame
	await process_frame
	var pulsing_gate_found := false
	for gate in arena_manager.get_spawn_gates():
		if gate.pulse_timer > 0.0:
			pulsing_gate_found = true
			break
	_expect(
		pulsing_gate_found,
		"the gate matching a wave spawn receives visual feedback"
	)
	_finish()

func _players_match_spawns(
	player_manager: PlayerManager,
	spawn_points: Array[Vector2]
) -> bool:
	for slot in range(1, 5):
		var player := player_manager.players.get(slot) as Node2D
		if player == null:
			return false
		if not player.global_position.is_equal_approx(spawn_points[slot - 1]):
			return false
	return true

func _on_barrel_exploded(
	_barrel: ExplosiveBarrel,
	damaged_targets: Array[Node]
) -> void:
	explosion_targets = damaged_targets.duplicate()

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("MILESTONE_20_ARENA_ENVIRONMENT_SMOKE_TEST: PASS")
		quit(0)
		return
	print(
		"MILESTONE_20_ARENA_ENVIRONMENT_SMOKE_TEST: FAIL (%d)"
		% failures.size()
	)
	quit(1)
