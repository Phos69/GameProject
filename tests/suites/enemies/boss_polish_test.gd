extends GutTest
## Enemies — Polish finale del boss: feedback world-space e annunci HUD.
##
## Migra:
##   tests/milestone_14_final_polish_smoke_test.gd  (boot main.tscn, boss + annunci)
##
## Copre gli annunci centrali dell'HUD (wave start/clear, boss spawn/phase/defeat),
## il visual modulare del Wave Warden, i profili dei proiettili boss e gli effetti
## di morte, piu il riavvio pulito di dungeon/tower dopo il flusso survival.

var _boss_projectiles: Array[Projectile] = []

func test_boss_feedback_and_announcements() -> void:
	_boss_projectiles = []
	var scene = _new_main_scene_fixture()
	assert_true(scene.boot(self), "main scene can be loaded")
	await wait_physics_frames(3)

	var game_mode_manager: GameModeManager = scene.node(&"game_mode_manager") as GameModeManager
	var wave_manager: WaveManager = scene.node(&"wave_manager") as WaveManager
	var boss_system: BossSystem = scene.node(&"boss_system") as BossSystem
	var player_manager: PlayerManager = scene.node(&"player_manager") as PlayerManager
	var projectile_system: ProjectileSystem = scene.node(&"projectile_system") as ProjectileSystem
	var health_system: HealthSystem = scene.node(&"health_system") as HealthSystem
	var gameplay_effects: GameplayEffects = scene.node(&"gameplay_effects") as GameplayEffects
	var hud: HUDManager = scene.node(&"hud_manager") as HUDManager
	assert_not_null(game_mode_manager, "game mode manager is available")
	assert_not_null(wave_manager, "wave manager is available")
	assert_not_null(boss_system, "boss system is available")
	assert_not_null(player_manager, "player manager is available")
	assert_not_null(projectile_system, "projectile system is available")
	assert_not_null(health_system, "health system is available")
	assert_not_null(gameplay_effects, "gameplay effects are available")
	assert_not_null(hud, "HUD manager is available")
	if (
		game_mode_manager == null or wave_manager == null or boss_system == null
		or player_manager == null or projectile_system == null or health_system == null
		or gameplay_effects == null or hud == null
	):
		scene.teardown()
		scene = null
		return

	wave_manager.initial_delay = 100.0
	game_mode_manager.set_mode(GameConstants.MODE_SURVIVAL)
	await wait_physics_frames(2)
	assert_not_null(hud.combat_announcement, "HUD creates a reusable combat announcement")
	wave_manager.start_next_wave()
	await wait_physics_frames(1)
	assert_eq(hud.combat_announcement.announcement_id, &"wave_started", "actual wave start drives the central announcement")
	assert_true(hud.combat_announcement.is_active(), "wave announcement is visible for couch readability")
	wave_manager.complete_current_wave()
	await wait_physics_frames(1)
	assert_eq(hud.combat_announcement.announcement_id, &"wave_clear", "actual wave reward drives the clear announcement")

	var player := player_manager.players.get(1) as PlayerController
	assert_not_null(player, "player one is available as boss target")
	if player == null:
		scene.teardown()
		scene = null
		return
	player.global_position = Vector2(300.0, 0.0)

	projectile_system.projectile_spawned.connect(_on_projectile_spawned)
	var boss := boss_system.request_boss(GameConstants.MODE_SURVIVAL, &"final_polish_smoke", Vector2.ZERO) as BasicBoss
	assert_not_null(boss, "Wave Warden can be spawned")
	if boss == null:
		_disconnect_projectiles(projectile_system)
		scene.teardown()
		scene = null
		return
	boss.set_physics_process(false)
	boss.target = player
	var boss_visual := boss.get_node_or_null("Visual") as WaveWardenVisual
	assert_not_null(boss_visual, "Wave Warden uses its modular animated visual")
	assert_true(boss_visual != null and boss_visual.get_profile_id() == &"wave_warden", "boss visual exposes its identity profile")
	assert_true(boss_visual != null and boss_visual.spawn_timer > 0.0, "boss spawn has world-space activation feedback")
	await wait_physics_frames(1)
	assert_true(hud.boss_panel.visible, "boss HUD uses a visible framed panel")
	assert_eq(hud.combat_announcement.announcement_id, &"boss_spawn", "boss spawn drives its introduction announcement")

	boss.aimed_telegraph_duration = 4.0
	assert_true(boss.start_attack_telegraph(&"aimed_volley"), "aimed attack can begin charging")
	assert_eq(boss_visual.active_pattern, &"aimed_volley", "boss body reflects aimed attack charge")
	boss.cancel_attack_telegraph()
	assert_true(boss_visual.active_pattern.is_empty(), "boss charge clears with the gameplay telegraph")

	boss.perform_aimed_volley()
	boss.perform_radial_burst()
	await wait_physics_frames(1)
	assert_true(_has_projectile_profile(&"boss_aimed"), "aimed boss projectiles receive a dedicated profile")
	assert_true(_has_projectile_profile(&"boss_radial"), "radial boss projectiles receive a dedicated profile")
	var aimed_projectile := _find_projectile_profile(&"boss_aimed")
	assert_true(
		aimed_projectile != null and aimed_projectile.glow != null and aimed_projectile.trail != null,
		"boss projectile profile includes glow and trail"
	)
	_clear_projectiles()

	var boss_health := boss.get_node("HealthComponent") as HealthComponent
	var phase_damage := boss_health.current_health - boss_health.max_health / 2
	health_system.apply_damage(boss, phase_damage)
	assert_true(boss_visual.is_phase_two_visual(), "phase two changes the boss body presentation")
	assert_gt(boss_visual.hurt_timer, 0.0, "boss damage produces a readable hit flash")
	assert_eq(hud.combat_announcement.announcement_id, &"boss_phase", "phase transition drives the overdrive announcement")

	health_system.apply_damage(boss, 99999)
	await wait_physics_frames(1)
	assert_true(_has_effect_kind(gameplay_effects, &"boss_death"), "boss defeat creates a dedicated world-space death effect")
	assert_eq(hud.combat_announcement.announcement_id, &"boss_defeated", "boss defeat drives the reward announcement")
	assert_false(hud.boss_panel.visible, "boss panel hides after defeat")

	game_mode_manager.set_mode(GameConstants.MODE_DUNGEON)
	await wait_physics_frames(1)
	assert_eq(game_mode_manager.active_mode_id, GameConstants.MODE_DUNGEON, "dungeon still starts after polished survival feedback")
	game_mode_manager.set_mode(GameConstants.MODE_TOWER_DEFENSE)
	await wait_physics_frames(1)
	assert_eq(game_mode_manager.active_mode_id, GameConstants.MODE_TOWER_DEFENSE, "tower defense still starts after polished survival feedback")

	_disconnect_projectiles(projectile_system)
	scene.teardown()
	scene = null
	await wait_physics_frames(1)

# --- helper -----------------------------------------------------------------

func _has_projectile_profile(profile_id: StringName) -> bool:
	return _find_projectile_profile(profile_id) != null

func _find_projectile_profile(profile_id: StringName) -> Projectile:
	for projectile in _boss_projectiles:
		if is_instance_valid(projectile) and projectile.visual_data != null and projectile.visual_data.profile_id == profile_id:
			return projectile
	return null

func _clear_projectiles() -> void:
	for projectile in _boss_projectiles:
		if is_instance_valid(projectile):
			projectile.queue_free()
	_boss_projectiles.clear()

func _has_effect_kind(gameplay_effects: GameplayEffects, effect_kind: StringName) -> bool:
	for effect in gameplay_effects.get_children():
		if effect is GameplayEffect and (effect as GameplayEffect).effect_kind == effect_kind:
			return true
	return false

func _on_projectile_spawned(projectile: Node) -> void:
	if projectile is Projectile and String(projectile.get("source_id")).begins_with("boss_"):
		_boss_projectiles.append(projectile as Projectile)

func _disconnect_projectiles(projectile_system: ProjectileSystem) -> void:
	if projectile_system != null and projectile_system.projectile_spawned.is_connected(_on_projectile_spawned):
		projectile_system.projectile_spawned.disconnect(_on_projectile_spawned)
func _new_main_scene_fixture():
	var script := ResourceLoader.load(
		"res://tests/support/main_scene_fixture.gd",
		"",
		ResourceLoader.CACHE_MODE_IGNORE
	) as Script
	assert_true(script != null, "main scene fixture script loads")
	return script.new() if script != null else null
