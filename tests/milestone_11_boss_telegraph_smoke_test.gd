extends SceneTree

var failures: PackedStringArray = []
var telegraphs: Array[StringName] = []
var patterns: Array[StringName] = []
var audio_feedback: Array[StringName] = []
var spawned_projectiles: Array[Projectile] = []

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
	var wave_manager := get_first_node_in_group("wave_manager") as WaveManager
	var boss_system := get_first_node_in_group("boss_system") as BossSystem
	var projectile_system := get_first_node_in_group(
		"projectile_system"
	) as ProjectileSystem
	var player_manager := get_first_node_in_group(
		"player_manager"
	) as PlayerManager
	var health_system := get_first_node_in_group(
		"health_system"
	) as HealthSystem
	var audio_manager := get_first_node_in_group(
		"audio_manager"
	) as AudioManager
	var hud := get_first_node_in_group("hud_manager") as HUDManager
	_expect(game_mode_manager != null, "game mode manager is available")
	_expect(wave_manager != null, "wave manager is available")
	_expect(boss_system != null, "boss system is available")
	_expect(projectile_system != null, "projectile system is available")
	_expect(player_manager != null, "player manager is available")
	_expect(health_system != null, "health system is available")
	_expect(audio_manager != null, "audio manager is available")
	_expect(hud != null, "HUD manager is available")
	if (
		game_mode_manager == null
		or wave_manager == null
		or boss_system == null
		or projectile_system == null
		or player_manager == null
		or health_system == null
		or audio_manager == null
		or hud == null
	):
		_finish()
		return

	wave_manager.initial_delay = 100.0
	game_mode_manager.set_mode(GameConstants.MODE_SURVIVAL)
	var player := player_manager.players.get(1) as PlayerController
	_expect(player != null, "player one is available as a boss target")
	if player == null:
		_finish()
		return

	audio_manager.gameplay_feedback_generated.connect(_on_audio_feedback)
	projectile_system.projectile_spawned.connect(_on_projectile_spawned)
	player.global_position = Vector2(300.0, 0.0)
	var boss := boss_system.request_boss(
		GameConstants.MODE_SURVIVAL,
		&"telegraph_smoke",
		Vector2.ZERO
	) as BasicBoss
	_expect(boss != null, "Wave Warden can be spawned")
	if boss == null:
		_finish()
		return

	boss.move_speed = 0.0
	boss.attack_cooldown = 100.0
	boss.attack_timer = 100.0
	boss.aimed_telegraph_duration = 0.20
	boss.radial_telegraph_duration = 0.22
	boss.target = player
	boss.attack_telegraph_started.connect(_on_telegraph_started)
	boss.attack_pattern_started.connect(_on_pattern_started)
	var telegraph_visual := boss.get_node_or_null(
		"TelegraphVisual"
	) as BossTelegraphVisual
	_expect(
		telegraph_visual != null,
		"boss uses a modular world-space telegraph visual"
	)

	var announced_direction := boss.global_position.direction_to(
		player.global_position
	)
	_expect(
		boss.start_attack_telegraph(&"aimed_volley"),
		"aimed volley can enter its telegraph state"
	)
	_expect(
		spawned_projectiles.is_empty(),
		"aimed warning appears before any damaging projectile"
	)
	_expect(
		telegraph_visual != null
		and telegraph_visual.is_telegraph_active()
		and telegraph_visual.active_pattern == &"aimed_volley",
		"aimed telegraph exposes direction and countdown state"
	)
	_expect(
		telegraphs.has(&"aimed_volley"),
		"aimed telegraph emits its public signal"
	)
	_expect(
		"AIMED VOLLEY" in hud.boss_warning_label.text,
		"HUD explains the aimed danger"
	)
	_expect(
		audio_feedback.has(&"boss_telegraph"),
		"aimed warning emits an audio cue"
	)

	player.global_position = Vector2(0.0, 300.0)
	for _frame in range(5):
		await physics_frame
	_expect(
		spawned_projectiles.is_empty(),
		"aimed volley remains harmless during its warning window"
	)
	_expect(
		await _wait_for_pattern(&"aimed_volley"),
		"aimed volley fires after the warning window"
	)
	_expect(
		spawned_projectiles.size() == boss.aimed_projectile_count,
		"aimed volley spawns its configured projectile count"
	)
	if not spawned_projectiles.is_empty():
		_expect(
			spawned_projectiles[0].velocity.normalized().dot(
				announced_direction
			) > 0.95,
			"aimed volley commits to the announced direction"
		)
	_clear_projectiles()

	var pattern_count_before_radial := patterns.size()
	_expect(
		boss.start_attack_telegraph(&"radial_burst"),
		"radial burst can enter its telegraph state"
	)
	_expect(
		spawned_projectiles.is_empty(),
		"radial warning appears before any damaging projectile"
	)
	_expect(
		telegraph_visual != null
		and telegraph_visual.active_pattern == &"radial_burst",
		"radial telegraph exposes every outgoing lane"
	)
	_expect(
		"RADIAL BURST" in hud.boss_warning_label.text,
		"HUD explains the radial danger"
	)
	for _frame in range(5):
		await physics_frame
	_expect(
		spawned_projectiles.is_empty(),
		"radial burst remains harmless during its warning window"
	)
	_expect(
		await _wait_for_pattern_count(pattern_count_before_radial + 1),
		"radial burst fires after the warning window"
	)
	_expect(
		spawned_projectiles.size() == boss.radial_projectile_count,
		"radial burst spawns its configured projectile count"
	)
	_clear_projectiles()

	var boss_health := boss.get_node("HealthComponent") as HealthComponent
	var phase_damage := (
		boss_health.current_health
		- boss_health.max_health / 2
	)
	health_system.apply_damage(boss, phase_damage)
	_expect(boss.phase_index == 2, "boss still enters phase two at half health")
	_expect(
		telegraph_visual != null
		and telegraph_visual.phase_pulse_remaining > 0.0,
		"phase change creates a world-space pulse"
	)
	_expect(
		"PHASE 2" in hud.boss_warning_label.text,
		"HUD announces the phase transition"
	)
	_expect(
		audio_feedback.has(&"boss_phase"),
		"phase transition emits a distinct audio cue"
	)

	boss.queue_free()
	await process_frame
	_finish()

func _wait_for_pattern(pattern_id: StringName) -> bool:
	for _frame in range(45):
		if patterns.has(pattern_id):
			return true
		await physics_frame
	return false

func _wait_for_pattern_count(expected_count: int) -> bool:
	for _frame in range(45):
		if patterns.size() >= expected_count:
			return true
		await physics_frame
	return false

func _clear_projectiles() -> void:
	for projectile in spawned_projectiles:
		if is_instance_valid(projectile):
			projectile.queue_free()
	spawned_projectiles.clear()

func _on_telegraph_started(
	pattern_id: StringName,
	_duration: float,
	_direction: Vector2
) -> void:
	telegraphs.append(pattern_id)

func _on_pattern_started(
	pattern_id: StringName,
	_projectile_count: int
) -> void:
	patterns.append(pattern_id)

func _on_audio_feedback(
	feedback_type: StringName,
	_source_id: StringName,
	_frames_written: int
) -> void:
	audio_feedback.append(feedback_type)

func _on_projectile_spawned(projectile: Node) -> void:
	if (
		projectile is Projectile
		and String(projectile.get("source_id")).begins_with("boss_")
	):
		spawned_projectiles.append(projectile as Projectile)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("MILESTONE_11_BOSS_TELEGRAPH_SMOKE_TEST: PASS")
		quit(0)
		return
	print(
		"MILESTONE_11_BOSS_TELEGRAPH_SMOKE_TEST: FAIL (%d)"
		% failures.size()
	)
	quit(1)
