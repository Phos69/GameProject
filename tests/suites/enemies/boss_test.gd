extends GutTest
## Enemies A6 — Boss: flusso della boss wave, telegraph degli attacchi, registry.
##
## Migra e accorpa (ognuno bootava main.tscn da solo):
##   tests/boss_smoke_test.gd
##   tests/milestone_11_boss_telegraph_smoke_test.gd
##   tests/milestone_19_boss_registry_smoke_test.gd

const MainSceneFixture = preload("res://tests/support/main_scene_fixture.gd")

var _completed_waves: Array[int] = []
var _defeated_modes: Array[StringName] = []
var _patterns: Array[StringName] = []
var _telegraphs: Array[StringName] = []
var _audio_feedback: Array[StringName] = []
var _boss_projectiles: Array[Node] = []
var _rift_projectiles: Array[Projectile] = []
var _rejected_requests: Array[Dictionary] = []
var _defeated_details: Array[Dictionary] = []

# --- flusso della boss wave (boss) ------------------------------------------

func test_boss_wave_flow() -> void:
	_completed_waves = []
	_defeated_modes = []
	_patterns = []
	_boss_projectiles = []
	var scene := MainSceneFixture.new()
	assert_true(scene.boot(self), "main scene can be loaded")
	await wait_physics_frames(2)

	var wave_manager := scene.node(&"wave_manager") as WaveManager
	var game_mode_manager := scene.node(&"game_mode_manager") as GameModeManager
	var survival_mode := scene.node(&"survival_mode") as SurvivalMode
	var local_multiplayer := scene.node(&"local_multiplayer_manager") as LocalMultiplayerManager
	var player_manager := scene.node(&"player_manager") as PlayerManager
	var health_system := scene.node(&"health_system") as HealthSystem
	var boss_system := scene.node(&"boss_system") as BossSystem
	var projectile_system := scene.node(&"projectile_system") as ProjectileSystem
	var hud := scene.node(&"hud_manager") as HUDManager
	var ammo_director := scene.node(&"survival_ammo_director") as SurvivalAmmoDirector
	var market := scene.node(&"survival_market_controller") as SurvivalMarketController
	if wave_manager == null or game_mode_manager == null or survival_mode == null or local_multiplayer == null or player_manager == null or health_system == null or boss_system == null or projectile_system == null or hud == null or ammo_director == null or market == null:
		assert_true(false, "boss-flow systems are available")
		scene.teardown()
		return

	survival_mode.stop_mode()
	await wait_physics_frames(1)
	local_multiplayer.activate_slot(2)
	await wait_physics_frames(1)
	var player_one := player_manager.players.get(1) as PlayerController
	var player_two := player_manager.players.get(2) as PlayerController
	if player_one == null or player_two == null:
		assert_true(false, "two local players are active")
		_teardown_boss(scene, local_multiplayer)
		return
	player_one.global_position = Vector2(180.0, 0.0)
	player_two.global_position = Vector2(-700.0, 300.0)
	var player_one_health := player_one.get_node("HealthComponent") as HealthComponent
	var player_one_weapon := player_one.get_node("WeaponSystem") as WeaponSystem

	wave_manager.initial_delay = 100.0
	wave_manager.intermission_duration = 0.20
	wave_manager.spawn_interval = 0.0
	wave_manager.boss_wave_interval = 5
	wave_manager.boss_wave_escort_count = 0
	survival_mode.boss_wave_interval = 5
	survival_mode.boss_spawn_position = Vector2.ZERO
	wave_manager.wave_completed.connect(_on_wave_completed)
	boss_system.boss_defeated.connect(_on_boss_defeated)
	projectile_system.projectile_spawned.connect(_on_boss_projectile_spawned)

	game_mode_manager.set_mode(GameConstants.MODE_SURVIVAL)
	wave_manager.current_wave = 4
	wave_manager.state_timer = 0.0
	assert_true(await _wait_for_boss_wave(wave_manager), "fifth wave starts as a boss wave")
	var boss := wave_manager.get_active_boss() as BasicBoss
	assert_not_null(boss, "Wave Warden is registered in the wave")
	if boss == null:
		_teardown_boss(scene, local_multiplayer)
		return
	boss.set_physics_process(false)
	boss.target = player_one
	boss.attack_pattern_started.connect(_on_attack_pattern_started)
	var boss_health := boss.get_node("HealthComponent") as HealthComponent
	assert_eq(wave_manager.current_wave_enemy_total, 1, "boss-only test wave counts one combatant")
	assert_eq(wave_manager.get_enemies_remaining(), 1, "boss keeps the wave active")
	assert_eq(boss_health.max_health, 504, "fifth wave scales boss health")
	assert_eq(boss.projectile_damage, 13, "fifth wave scales boss damage")
	assert_false(ammo_director.get_active_crates().is_empty(), "boss wave starts with a guaranteed ammo source")

	await wait_physics_frames(1)
	assert_true(hud.boss_health_bar.visible, "boss health bar is visible")
	assert_true("Wave Warden" in hud.boss_name_label.text, "boss HUD displays the boss name")
	assert_eq(int(hud.boss_health_bar.max_value), boss_health.max_health, "boss bar uses boss max health")

	var boss_health_before_shot := boss_health.current_health
	var shot_direction := player_one.global_position.direction_to(boss.global_position)
	assert_true(player_one_weapon.try_fire(player_one.global_position + shot_direction * 22.0, shot_direction, player_one), "player can fire at the boss")
	for _frame in range(30):
		await wait_physics_frames(1)
	assert_eq(boss_health.current_health, boss_health_before_shot - 10, "player projectile damages the boss")

	_clear_boss_projectiles()
	var player_health_before_volley := player_one_health.current_health
	assert_eq(boss.perform_aimed_volley(), 3, "aimed volley spawns three projectiles")
	for _frame in range(50):
		await wait_physics_frames(1)
	var aimed_damage_taken := player_health_before_volley - player_one_health.current_health
	assert_gte(aimed_damage_taken, boss.projectile_damage, "aimed boss projectile damages a player")
	assert_lte(aimed_damage_taken, boss.projectile_damage * boss.aimed_projectile_count, "aimed volley damage stays bounded by spawned projectiles")
	assert_true(_patterns.has(&"aimed_volley"), "aimed volley emits its pattern signal")

	_clear_boss_projectiles()
	player_one.global_position = Vector2(620.0, 275.0)
	assert_eq(boss.perform_radial_burst(), 12, "radial burst spawns twelve projectiles")
	assert_true(_patterns.has(&"radial_burst"), "radial burst emits its pattern signal")
	assert_eq(_boss_projectiles.size(), 12, "radial projectiles use ProjectileSystem")
	_clear_boss_projectiles()

	health_system.apply_damage(boss, boss_health.current_health - boss_health.max_health / 2)
	assert_eq(boss.phase_index, 2, "boss enters phase two below half health")
	await wait_physics_frames(2)
	assert_true("Phase 2" in hud.boss_name_label.text, "boss HUD displays phase two")
	assert_eq(int(hud.boss_health_bar.value), boss_health.current_health, "boss health bar follows damage")
	assert_false(_completed_waves.has(5), "fifth wave waits for the living boss")

	health_system.apply_damage(boss, 9999)
	assert_true(await _wait_for_completed_wave(5), "fifth wave completes after boss death")
	assert_true(_defeated_modes.has(GameConstants.MODE_SURVIVAL), "BossSystem reports survival boss defeat")
	assert_null(boss_system.get_active_boss(), "BossSystem clears the active boss")
	await wait_physics_frames(1)
	assert_false(hud.boss_health_bar.visible, "boss health bar hides after defeat")

	var weapon_pickup := _find_weapon_pickup(scene, &"wave_cannon")
	assert_not_null(weapon_pickup, "boss drops the guaranteed Wave Cannon")
	if weapon_pickup != null:
		player_one.global_position = weapon_pickup.global_position
		for _frame in range(3):
			await wait_physics_frames(1)
		assert_eq(player_one_weapon.weapon_data.weapon_id, &"wave_cannon", "collecting the special drop equips the Wave Cannon")
	assert_true(market.is_market_open and wave_manager.state == WaveManager.State.REWARD and wave_manager.is_next_wave_blocked(), "boss reward opens the market before survival continues")
	market.set_player_ready(1, true)
	market.set_player_ready(2, true)
	assert_true(not market.is_market_open and wave_manager.state == WaveManager.State.INTERMISSION, "all living players ready resume survival after the boss reward")

	survival_mode.stop_mode()
	_teardown_boss(scene, local_multiplayer)

# --- telegraph degli attacchi (milestone_11_boss_telegraph) -----------------

func test_boss_telegraph() -> void:
	_telegraphs = []
	_patterns = []
	_audio_feedback = []
	_boss_projectiles = []
	var scene := MainSceneFixture.new()
	assert_true(scene.boot(self), "main scene can be loaded")
	await wait_physics_frames(3)
	var game_mode_manager := scene.node(&"game_mode_manager") as GameModeManager
	var boss_system := scene.node(&"boss_system") as BossSystem
	var projectile_system := scene.node(&"projectile_system") as ProjectileSystem
	var player_manager := scene.node(&"player_manager") as PlayerManager
	var health_system := scene.node(&"health_system") as HealthSystem
	var audio_manager := scene.node(&"audio_manager") as AudioManager
	var hud := scene.node(&"hud_manager") as HUDManager
	if game_mode_manager == null or boss_system == null or projectile_system == null or player_manager == null or health_system == null or audio_manager == null or hud == null:
		assert_true(false, "boss telegraph systems are available")
		scene.teardown()
		return

	game_mode_manager.set_mode(GameConstants.MODE_SURVIVAL)
	var wave_manager := scene.node(&"wave_manager") as WaveManager
	if wave_manager != null:
		wave_manager.initial_delay = 100.0
	var player := player_manager.players.get(1) as PlayerController
	if player == null:
		scene.teardown()
		return
	audio_manager.gameplay_feedback_generated.connect(_on_audio_feedback)
	projectile_system.projectile_spawned.connect(_on_boss_projectile_spawned)
	player.global_position = Vector2(300.0, 0.0)
	var boss := boss_system.request_boss(GameConstants.MODE_SURVIVAL, &"telegraph_smoke", Vector2.ZERO) as BasicBoss
	assert_not_null(boss, "Wave Warden can be spawned")
	if boss == null:
		_teardown_boss(scene, null)
		return
	boss.move_speed = 0.0
	boss.attack_cooldown = 100.0
	boss.attack_timer = 100.0
	boss.aimed_telegraph_duration = 0.20
	boss.radial_telegraph_duration = 0.22
	boss.target = player
	boss.attack_telegraph_started.connect(_on_telegraph_started)
	boss.attack_pattern_started.connect(_on_attack_pattern_started)
	var telegraph_visual := boss.get_node_or_null("TelegraphVisual") as BossTelegraphVisual
	assert_not_null(telegraph_visual, "boss uses a modular world-space telegraph visual")

	var announced_direction := boss.global_position.direction_to(player.global_position)
	assert_true(boss.start_attack_telegraph(&"aimed_volley"), "aimed volley can enter its telegraph state")
	assert_true(_boss_projectiles.is_empty(), "aimed warning appears before any damaging projectile")
	assert_true(telegraph_visual != null and telegraph_visual.is_telegraph_active() and telegraph_visual.active_pattern == &"aimed_volley", "aimed telegraph exposes direction and countdown state")
	assert_true(_telegraphs.has(&"aimed_volley"), "aimed telegraph emits its public signal")
	assert_true("AIMED VOLLEY" in hud.boss_warning_label.text, "HUD explains the aimed danger")
	assert_true(_audio_feedback.has(&"boss_telegraph"), "aimed warning emits an audio cue")

	player.global_position = Vector2(0.0, 300.0)
	for _frame in range(5):
		await wait_physics_frames(1)
	assert_true(_boss_projectiles.is_empty(), "aimed volley remains harmless during its warning window")
	assert_true(await _wait_for_pattern(&"aimed_volley"), "aimed volley fires after the warning window")
	assert_eq(_boss_projectiles.size(), boss.aimed_projectile_count, "aimed volley spawns its configured projectile count")
	if not _boss_projectiles.is_empty():
		assert_gt((_boss_projectiles[0] as Projectile).velocity.normalized().dot(announced_direction), 0.95, "aimed volley commits to the announced direction")
	_clear_boss_projectiles()

	var pattern_count_before_radial := _patterns.size()
	assert_true(boss.start_attack_telegraph(&"radial_burst"), "radial burst can enter its telegraph state")
	assert_true(_boss_projectiles.is_empty(), "radial warning appears before any damaging projectile")
	assert_true(telegraph_visual != null and telegraph_visual.active_pattern == &"radial_burst", "radial telegraph exposes every outgoing lane")
	assert_true("RADIAL BURST" in hud.boss_warning_label.text, "HUD explains the radial danger")
	for _frame in range(5):
		await wait_physics_frames(1)
	assert_true(_boss_projectiles.is_empty(), "radial burst remains harmless during its warning window")
	assert_true(await _wait_for_pattern_count(pattern_count_before_radial + 1), "radial burst fires after the warning window")
	assert_eq(_boss_projectiles.size(), boss.radial_projectile_count, "radial burst spawns its configured projectile count")
	_clear_boss_projectiles()

	var boss_health := boss.get_node("HealthComponent") as HealthComponent
	health_system.apply_damage(boss, boss_health.current_health - boss_health.max_health / 2)
	assert_eq(boss.phase_index, 2, "boss still enters phase two at half health")
	assert_true(telegraph_visual != null and telegraph_visual.phase_pulse_remaining > 0.0, "phase change creates a world-space pulse")
	assert_true("PHASE 2" in hud.boss_warning_label.text, "HUD announces the phase transition")
	assert_true(_audio_feedback.has(&"boss_phase"), "phase transition emits a distinct audio cue")

	boss.queue_free()
	await wait_physics_frames(1)
	_teardown_boss(scene, null)

# --- registry e secondo boss (milestone_19_boss_registry) -------------------

func test_boss_registry() -> void:
	_rift_projectiles = []
	_rejected_requests = []
	_defeated_details = []
	var scene := MainSceneFixture.new()
	assert_true(scene.boot(self), "main scene can be loaded")
	await wait_physics_frames(3)
	var boss_system := scene.node(&"boss_system") as BossSystem
	var player_manager := scene.node(&"player_manager") as PlayerManager
	var projectile_system := scene.node(&"projectile_system") as ProjectileSystem
	var health_system := scene.node(&"health_system") as HealthSystem
	var hud := scene.node(&"hud_manager") as HUDManager
	if boss_system == null or player_manager == null or projectile_system == null or health_system == null or hud == null:
		assert_true(false, "boss registry systems are available")
		scene.teardown()
		return

	boss_system.boss_request_rejected.connect(_on_boss_request_rejected)
	boss_system.boss_defeated_detailed.connect(_on_boss_defeated_detailed)
	projectile_system.projectile_spawned.connect(_on_rift_projectile_spawned)
	var registered_ids := boss_system.get_registered_boss_ids()
	assert_true(registered_ids.has(&"wave_warden") and registered_ids.has(&"rift_architect"), "boss registry exposes both configured bosses")
	assert_true(boss_system.is_boss_compatible(&"rift_architect", GameConstants.MODE_DUNGEON), "Rift Architect is compatible with dungeon")
	assert_false(boss_system.is_boss_compatible(&"rift_architect", GameConstants.MODE_TOWER_DEFENSE), "Rift Architect explicitly rejects tower defense")
	assert_null(boss_system.request_boss_by_id(&"rift_architect", GameConstants.MODE_TOWER_DEFENSE, &"compatibility_test"), "incompatible boss request returns null")
	assert_true(not _rejected_requests.is_empty() and _rejected_requests[-1].get("reason") == &"incompatible_mode", "incompatible request emits a typed rejection")

	var player := player_manager.players.get(1) as PlayerController
	if player == null:
		_teardown_boss(scene, null)
		return
	player.global_position = Vector2(280.0, 0.0)
	var warden := boss_system.request_boss_by_id(&"wave_warden", GameConstants.MODE_SURVIVAL, &"registry_test", Vector2.ZERO) as BasicBoss
	assert_true(warden != null and warden.boss_id == &"wave_warden", "Wave Warden can still be requested by ID")
	if warden == null:
		_teardown_boss(scene, null)
		return
	health_system.apply_damage(warden, 99999)
	await wait_physics_frames(1)

	var rift := boss_system.request_boss_by_id(&"rift_architect", GameConstants.MODE_DUNGEON, &"registry_test", Vector2.ZERO) as RiftArchitect
	assert_not_null(rift, "Rift Architect spawns through the registry")
	if rift == null:
		_teardown_boss(scene, null)
		return
	rift.set_physics_process(false)
	rift.target = player
	assert_true(rift.boss_id == &"rift_architect" and rift.display_name == "Rift Architect", "second boss exposes its own identity")
	assert_eq(rift.visual.get_profile_id(), &"rift_architect", "second boss uses a distinct modular visual")
	await wait_physics_frames(1)
	assert_true(hud.boss_name_label.text.contains("Rift Architect"), "shared boss HUD displays the registered boss name")

	rift.lane_telegraph_duration = 5.0
	assert_true(rift.start_attack_telegraph(&"lane_sweep"), "lane sweep enters its telegraph state")
	assert_eq(rift.telegraph_visual.active_pattern, &"lane_sweep", "lane sweep uses a distinct world-space telegraph")
	assert_true(_rift_projectiles.is_empty(), "lane sweep creates no projectile during warning")
	assert_eq(hud.boss_warning_label.text, "LANE SWEEP - FIND THE GAP", "HUD explains the lane gap")
	rift._finish_attack_telegraph()
	await wait_physics_frames(1)
	assert_eq(_count_rift_projectiles(&"rift_lane"), rift.lane_projectile_count - 1, "lane sweep fires every warned lane except the safe gap")
	_clear_rift_projectiles()

	var rift_health := rift.health_component
	health_system.apply_damage(rift, rift_health.current_health - roundi(float(rift_health.max_health) * 0.50))
	assert_eq(rift.phase_index, 2, "Rift Architect enters phase two")
	assert_true(rift.visual.is_phase_two_visual(), "phase two changes the second boss presentation")
	rift.cross_telegraph_duration = 5.0
	assert_true(rift.start_attack_telegraph(&"cross_burst"), "cross burst enters its telegraph state")
	assert_true(_rift_projectiles.is_empty(), "cross burst creates no projectile during warning")
	assert_eq(hud.boss_warning_label.text, "CROSS BURST - ROTATE", "HUD explains the cross burst")
	rift._finish_attack_telegraph()
	await wait_physics_frames(1)
	assert_eq(_count_rift_projectiles(&"rift_cross"), rift.cross_projectile_count, "cross burst fires its configured rotating cross")
	_clear_rift_projectiles()

	health_system.apply_damage(rift, 99999)
	await wait_physics_frames(1)
	assert_true(not _defeated_details.is_empty() and _defeated_details[-1].get("boss_id") == &"rift_architect", "detailed defeat event preserves boss identity")
	assert_gte(_count_weapon_pickups(scene, &"rift_repeater"), 1, "Rift Architect drops its dedicated special weapon")

	_teardown_boss(scene, null)

# --- helper -----------------------------------------------------------------

func _teardown_boss(scene: MainSceneFixture, local_multiplayer: LocalMultiplayerManager) -> void:
	if local_multiplayer != null:
		local_multiplayer.deactivate_slot(2)
	scene.teardown()
	await wait_physics_frames(1)

func _wait_for_boss_wave(wave_manager: WaveManager) -> bool:
	for _frame in range(180):
		if wave_manager.current_wave == 5 and wave_manager.state == WaveManager.State.COMBAT and wave_manager.get_active_boss() != null:
			return true
		await wait_physics_frames(1)
	return false

func _wait_for_completed_wave(wave_index: int) -> bool:
	for _frame in range(180):
		if _completed_waves.has(wave_index):
			return true
		await wait_physics_frames(1)
	return false

func _wait_for_pattern(pattern_id: StringName) -> bool:
	for _frame in range(45):
		if _patterns.has(pattern_id):
			return true
		await wait_physics_frames(1)
	return false

func _wait_for_pattern_count(expected_count: int) -> bool:
	for _frame in range(45):
		if _patterns.size() >= expected_count:
			return true
		await wait_physics_frames(1)
	return false

func _find_weapon_pickup(scene: MainSceneFixture, weapon_id: StringName) -> DropPickup:
	for pickup in scene.nodes(&"drop_pickups"):
		if pickup is DropPickup and StringName((pickup as DropPickup).drop_data.get("weapon_id", &"")) == weapon_id:
			return pickup
	return null

func _count_weapon_pickups(scene: MainSceneFixture, weapon_id: StringName) -> int:
	var count := 0
	for pickup in scene.nodes(&"drop_pickups"):
		if pickup is DropPickup and StringName((pickup as DropPickup).drop_data.get("weapon_id", &"")) == weapon_id:
			count += 1
	return count

func _count_rift_projectiles(source_id: StringName) -> int:
	var count := 0
	for projectile in _rift_projectiles:
		if is_instance_valid(projectile) and projectile.source_id == source_id:
			count += 1
	return count

func _clear_boss_projectiles() -> void:
	for projectile in _boss_projectiles:
		if is_instance_valid(projectile):
			projectile.queue_free()
	_boss_projectiles.clear()

func _clear_rift_projectiles() -> void:
	for projectile in _rift_projectiles:
		if is_instance_valid(projectile):
			projectile.queue_free()
	_rift_projectiles.clear()

func _on_wave_completed(wave_index: int) -> void:
	_completed_waves.append(wave_index)

func _on_boss_defeated(mode_id: StringName) -> void:
	_defeated_modes.append(mode_id)

func _on_attack_pattern_started(pattern_id: StringName, _projectile_count: int) -> void:
	_patterns.append(pattern_id)

func _on_telegraph_started(pattern_id: StringName, _duration: float, _direction: Vector2) -> void:
	_telegraphs.append(pattern_id)

func _on_audio_feedback(feedback_type: StringName, _source_id: StringName, _frames_written: int) -> void:
	_audio_feedback.append(feedback_type)

func _on_boss_projectile_spawned(projectile: Node) -> void:
	if projectile is Projectile and String(projectile.get("source_id")).begins_with("boss_"):
		_boss_projectiles.append(projectile)

func _on_rift_projectile_spawned(projectile: Node) -> void:
	if projectile is Projectile and String(projectile.get("source_id")).begins_with("rift_"):
		_rift_projectiles.append(projectile as Projectile)

func _on_boss_request_rejected(mode_id: StringName, boss_id: StringName, reason: StringName) -> void:
	_rejected_requests.append({"mode_id": mode_id, "boss_id": boss_id, "reason": reason})

func _on_boss_defeated_detailed(mode_id: StringName, boss_id: StringName, display_name: String) -> void:
	_defeated_details.append({"mode_id": mode_id, "boss_id": boss_id, "display_name": display_name})
