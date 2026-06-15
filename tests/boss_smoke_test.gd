extends SceneTree

var failures: PackedStringArray = []
var completed_waves: Array[int] = []
var defeated_modes: Array[StringName] = []
var patterns: Array[StringName] = []
var spawned_projectiles: Array[Node] = []
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

	var wave_manager := get_first_node_in_group("wave_manager") as WaveManager
	var game_mode_manager := get_first_node_in_group("game_mode_manager") as GameModeManager
	var survival_mode := get_first_node_in_group("survival_mode") as SurvivalMode
	var local_multiplayer := get_first_node_in_group("local_multiplayer_manager") as LocalMultiplayerManager
	var player_manager := get_first_node_in_group("player_manager") as PlayerManager
	var health_system := get_first_node_in_group("health_system") as HealthSystem
	var boss_system := get_first_node_in_group("boss_system") as BossSystem
	var projectile_system := get_first_node_in_group("projectile_system") as ProjectileSystem
	var hud := get_first_node_in_group("hud_manager") as HUDManager
	var ammo_director := get_first_node_in_group(
		"survival_ammo_director"
	) as SurvivalAmmoDirector
	_expect(wave_manager != null, "wave manager is available")
	_expect(game_mode_manager != null, "game mode manager is available")
	_expect(survival_mode != null, "survival mode is available")
	_expect(local_multiplayer != null, "local multiplayer manager is available")
	_expect(player_manager != null, "player manager is available")
	_expect(health_system != null, "health system is available")
	_expect(boss_system != null, "boss system is available")
	_expect(projectile_system != null, "projectile system is available")
	_expect(hud != null, "HUD manager is available")
	_expect(ammo_director != null, "survival ammo director is available")
	if (
		wave_manager == null
		or game_mode_manager == null
		or survival_mode == null
		or local_multiplayer == null
		or player_manager == null
		or health_system == null
		or boss_system == null
		or projectile_system == null
		or hud == null
		or ammo_director == null
	):
		_finish()
		return

	survival_mode.stop_mode()
	await process_frame
	local_multiplayer.activate_slot(2)
	await process_frame

	var player_one := player_manager.players.get(1) as PlayerController
	var player_two := player_manager.players.get(2) as PlayerController
	_expect(player_one != null and player_two != null, "two local players are active")
	if player_one == null or player_two == null:
		_finish()
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
	projectile_system.projectile_spawned.connect(_on_projectile_spawned)

	game_mode_manager.set_mode(GameConstants.MODE_SURVIVAL)
	wave_manager.current_wave = 4
	wave_manager.state_timer = 0.0
	_expect(await _wait_for_boss_wave(wave_manager), "fifth wave starts as a boss wave")

	var boss := wave_manager.get_active_boss() as BasicBoss
	_expect(boss != null, "Wave Warden is registered in the wave")
	if boss == null:
		_finish()
		return

	boss.set_physics_process(false)
	boss.target = player_one
	boss.attack_pattern_started.connect(_on_attack_pattern_started)
	var boss_health := boss.get_node("HealthComponent") as HealthComponent
	_expect(wave_manager.current_wave_enemy_total == 1, "boss-only test wave counts one combatant")
	_expect(wave_manager.get_enemies_remaining() == 1, "boss keeps the wave active")
	_expect(boss_health.max_health == 504, "fifth wave scales boss health")
	_expect(boss.projectile_damage == 13, "fifth wave scales boss damage")
	_expect(
		not ammo_director.get_active_crates().is_empty(),
		"boss wave starts with a guaranteed ammo source"
	)

	await process_frame
	_expect(hud.boss_health_bar.visible, "boss health bar is visible")
	_expect("Wave Warden" in hud.boss_name_label.text, "boss HUD displays the boss name")
	_expect(int(hud.boss_health_bar.max_value) == boss_health.max_health, "boss bar uses boss max health")

	var boss_health_before_shot := boss_health.current_health
	var shot_direction := player_one.global_position.direction_to(boss.global_position)
	_expect(
		player_one_weapon.try_fire(
			player_one.global_position + shot_direction * 22.0,
			shot_direction,
			player_one
		),
		"player can fire at the boss"
	)
	for _frame in range(30):
		await physics_frame
	_expect(
		boss_health.current_health == boss_health_before_shot - 10,
		"player projectile damages the boss"
	)

	_clear_spawned_projectiles()
	var player_health_before_volley := player_one_health.current_health
	_expect(boss.perform_aimed_volley() == 3, "aimed volley spawns three projectiles")
	for _frame in range(50):
		await physics_frame
	_expect(
		player_one_health.current_health == player_health_before_volley - boss.projectile_damage,
		"aimed boss projectile damages a player"
	)
	_expect(patterns.has(&"aimed_volley"), "aimed volley emits its pattern signal")

	_clear_spawned_projectiles()
	player_one.global_position = Vector2(620.0, 275.0)
	_expect(boss.perform_radial_burst() == 12, "radial burst spawns twelve projectiles")
	_expect(patterns.has(&"radial_burst"), "radial burst emits its pattern signal")
	_expect(spawned_projectiles.size() == 12, "radial projectiles use ProjectileSystem")
	_clear_spawned_projectiles()

	var damage_to_phase_two := boss_health.current_health - boss_health.max_health / 2
	health_system.apply_damage(boss, damage_to_phase_two)
	_expect(boss.phase_index == 2, "boss enters phase two below half health")
	await process_frame
	await process_frame
	_expect("Phase 2" in hud.boss_name_label.text, "boss HUD displays phase two")
	_expect(
		int(hud.boss_health_bar.value) == boss_health.current_health,
		"boss health bar follows damage"
	)
	_expect(not completed_waves.has(5), "fifth wave waits for the living boss")

	health_system.apply_damage(boss, 9999)
	_expect(await _wait_for_completed_wave(5), "fifth wave completes after boss death")
	_expect(defeated_modes.has(GameConstants.MODE_SURVIVAL), "BossSystem reports survival boss defeat")
	_expect(boss_system.get_active_boss() == null, "BossSystem clears the active boss")
	await process_frame
	_expect(not hud.boss_health_bar.visible, "boss health bar hides after defeat")

	var weapon_pickup := _find_weapon_pickup(&"wave_cannon")
	_expect(weapon_pickup != null, "boss drops the guaranteed Wave Cannon")
	if weapon_pickup != null:
		player_one.global_position = weapon_pickup.global_position
		for _frame in range(3):
			await physics_frame
		_expect(
			player_one_weapon.weapon_data.weapon_id == &"wave_cannon",
			"collecting the special drop equips the Wave Cannon"
		)
	_expect(wave_manager.state == &"intermission", "survival continues after the boss reward")

	survival_mode.stop_mode()
	_finish()

func _wait_for_boss_wave(wave_manager: WaveManager) -> bool:
	for _frame in range(180):
		if (
			wave_manager.current_wave == 5
			and wave_manager.state == &"combat"
			and wave_manager.get_active_boss() != null
		):
			return true
		await physics_frame
	return false

func _wait_for_completed_wave(wave_index: int) -> bool:
	for _frame in range(180):
		if completed_waves.has(wave_index):
			return true
		await physics_frame
	return false

func _find_weapon_pickup(weapon_id: StringName) -> DropPickup:
	for pickup in get_nodes_in_group("drop_pickups"):
		if not pickup is DropPickup:
			continue
		if StringName(pickup.drop_data.get("weapon_id", &"")) == weapon_id:
			return pickup as DropPickup
	return null

func _clear_spawned_projectiles() -> void:
	for projectile in spawned_projectiles:
		if is_instance_valid(projectile):
			projectile.queue_free()
	spawned_projectiles.clear()

func _on_wave_completed(wave_index: int) -> void:
	completed_waves.append(wave_index)

func _on_boss_defeated(mode_id: StringName) -> void:
	defeated_modes.append(mode_id)

func _on_attack_pattern_started(pattern_id: StringName, _projectile_count: int) -> void:
	patterns.append(pattern_id)

func _on_projectile_spawned(projectile: Node) -> void:
	if projectile is Projectile and str(projectile.get("source_id")).begins_with("boss_"):
		spawned_projectiles.append(projectile)

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
		print("BOSS_SMOKE_TEST: PASS")
	else:
		print("BOSS_SMOKE_TEST: FAIL (%d)" % failures.size())
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
