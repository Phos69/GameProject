extends SceneTree

var failures: PackedStringArray = []
var boss_projectiles: Array[Projectile] = []
var finishing: bool = false

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
	var wave_manager := get_first_node_in_group(
		"wave_manager"
	) as WaveManager
	var boss_system := get_first_node_in_group(
		"boss_system"
	) as BossSystem
	var player_manager := get_first_node_in_group(
		"player_manager"
	) as PlayerManager
	var projectile_system := get_first_node_in_group(
		"projectile_system"
	) as ProjectileSystem
	var health_system := get_first_node_in_group(
		"health_system"
	) as HealthSystem
	var gameplay_effects := get_first_node_in_group(
		"gameplay_effects"
	) as GameplayEffects
	var hud := get_first_node_in_group("hud_manager") as HUDManager
	_expect(game_mode_manager != null, "game mode manager is available")
	_expect(wave_manager != null, "wave manager is available")
	_expect(boss_system != null, "boss system is available")
	_expect(player_manager != null, "player manager is available")
	_expect(projectile_system != null, "projectile system is available")
	_expect(health_system != null, "health system is available")
	_expect(gameplay_effects != null, "gameplay effects are available")
	_expect(hud != null, "HUD manager is available")
	if (
		game_mode_manager == null
		or wave_manager == null
		or boss_system == null
		or player_manager == null
		or projectile_system == null
		or health_system == null
		or gameplay_effects == null
		or hud == null
	):
		_finish()
		return

	wave_manager.initial_delay = 100.0
	game_mode_manager.set_mode(GameConstants.MODE_SURVIVAL)
	await process_frame
	await process_frame
	_expect(
		hud.combat_announcement != null,
		"HUD creates a reusable combat announcement"
	)
	wave_manager.start_next_wave()
	await process_frame
	_expect(
		hud.combat_announcement.announcement_id == &"wave_started",
		"actual wave start drives the central announcement"
	)
	_expect(
		hud.combat_announcement.is_active(),
		"wave announcement is visible for couch readability"
	)
	wave_manager.complete_current_wave()
	await process_frame
	_expect(
		hud.combat_announcement.announcement_id == &"wave_clear",
		"actual wave reward drives the clear announcement"
	)

	var player := player_manager.players.get(1) as PlayerController
	_expect(player != null, "player one is available as boss target")
	if player == null:
		_finish()
		return
	player.global_position = Vector2(300.0, 0.0)

	projectile_system.projectile_spawned.connect(_on_projectile_spawned)
	var boss := boss_system.request_boss(
		GameConstants.MODE_SURVIVAL,
		&"final_polish_smoke",
		Vector2.ZERO
	) as BasicBoss
	_expect(boss != null, "Wave Warden can be spawned")
	if boss == null:
		_finish()
		return
	boss.set_physics_process(false)
	boss.target = player
	var boss_visual := boss.get_node_or_null("Visual") as WaveWardenVisual
	_expect(
		boss_visual != null,
		"Wave Warden uses its modular animated visual"
	)
	_expect(
		boss_visual != null
		and boss_visual.get_profile_id() == &"wave_warden",
		"boss visual exposes its identity profile"
	)
	_expect(
		boss_visual != null and boss_visual.spawn_timer > 0.0,
		"boss spawn has world-space activation feedback"
	)
	await process_frame
	_expect(hud.boss_panel.visible, "boss HUD uses a visible framed panel")
	_expect(
		hud.combat_announcement.announcement_id == &"boss_spawn",
		"boss spawn drives its introduction announcement"
	)

	boss.aimed_telegraph_duration = 4.0
	_expect(
		boss.start_attack_telegraph(&"aimed_volley"),
		"aimed attack can begin charging"
	)
	_expect(
		boss_visual.active_pattern == &"aimed_volley",
		"boss body reflects aimed attack charge"
	)
	boss.cancel_attack_telegraph()
	_expect(
		boss_visual.active_pattern.is_empty(),
		"boss charge clears with the gameplay telegraph"
	)

	boss.perform_aimed_volley()
	boss.perform_radial_burst()
	await process_frame
	_expect(
		_has_projectile_profile(&"boss_aimed"),
		"aimed boss projectiles receive a dedicated profile"
	)
	_expect(
		_has_projectile_profile(&"boss_radial"),
		"radial boss projectiles receive a dedicated profile"
	)
	var aimed_projectile := _find_projectile_profile(&"boss_aimed")
	_expect(
		aimed_projectile != null
		and aimed_projectile.glow != null
		and aimed_projectile.trail != null,
		"boss projectile profile includes glow and trail"
	)
	_clear_projectiles()

	var boss_health := boss.get_node("HealthComponent") as HealthComponent
	var phase_damage := (
		boss_health.current_health
		- boss_health.max_health / 2
	)
	health_system.apply_damage(boss, phase_damage)
	_expect(
		boss_visual.is_phase_two_visual(),
		"phase two changes the boss body presentation"
	)
	_expect(
		boss_visual.hurt_timer > 0.0,
		"boss damage produces a readable hit flash"
	)
	_expect(
		hud.combat_announcement.announcement_id == &"boss_phase",
		"phase transition drives the overdrive announcement"
	)

	health_system.apply_damage(boss, 99999)
	await process_frame
	_expect(
		_has_effect_kind(gameplay_effects, &"boss_death"),
		"boss defeat creates a dedicated world-space death effect"
	)
	_expect(
		hud.combat_announcement.announcement_id == &"boss_defeated",
		"boss defeat drives the reward announcement"
	)
	_expect(
		not hud.boss_panel.visible,
		"boss panel hides after defeat"
	)

	game_mode_manager.set_mode(GameConstants.MODE_DUNGEON)
	await process_frame
	_expect(
		game_mode_manager.active_mode_id == GameConstants.MODE_DUNGEON,
		"dungeon still starts after polished survival feedback"
	)
	game_mode_manager.set_mode(GameConstants.MODE_TOWER_DEFENSE)
	await process_frame
	_expect(
		game_mode_manager.active_mode_id == GameConstants.MODE_TOWER_DEFENSE,
		"tower defense still starts after polished survival feedback"
	)
	_finish()

func _has_projectile_profile(profile_id: StringName) -> bool:
	return _find_projectile_profile(profile_id) != null

func _find_projectile_profile(profile_id: StringName) -> Projectile:
	for projectile in boss_projectiles:
		if (
			is_instance_valid(projectile)
			and projectile.visual_data != null
			and projectile.visual_data.profile_id == profile_id
		):
			return projectile
	return null

func _clear_projectiles() -> void:
	for projectile in boss_projectiles:
		if is_instance_valid(projectile):
			projectile.queue_free()
	boss_projectiles.clear()

func _has_effect_kind(
	gameplay_effects: GameplayEffects,
	effect_kind: StringName
) -> bool:
	for effect in gameplay_effects.get_children():
		if (
			effect is GameplayEffect
			and (effect as GameplayEffect).effect_kind == effect_kind
		):
			return true
	return false

func _on_projectile_spawned(projectile: Node) -> void:
	if (
		projectile is Projectile
		and String(projectile.get("source_id")).begins_with("boss_")
	):
		boss_projectiles.append(projectile as Projectile)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if finishing:
		return
	finishing = true
	var exit_code := 0
	if failures.is_empty():
		print("MILESTONE_14_FINAL_POLISH_SMOKE_TEST: PASS")
	else:
		print(
			"MILESTONE_14_FINAL_POLISH_SMOKE_TEST: FAIL (%d)"
			% failures.size()
		)
		exit_code = 1
	call_deferred("_shutdown", exit_code)

func _shutdown(exit_code: int) -> void:
	for _frame in range(5):
		await process_frame
	if current_scene != null:
		current_scene.queue_free()
		current_scene = null
	for _frame in range(5):
		await process_frame
	quit(exit_code)
