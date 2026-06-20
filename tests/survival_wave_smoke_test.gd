extends SceneTree

var failures: PackedStringArray = []
var configured_waves: Dictionary = {}
var completed_waves: Array[int] = []
var boss_waves: Array[int] = []
var boss_requests: Array[StringName] = []

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
	var progression := get_first_node_in_group("progression_manager") as ProgressionManager
	var hud := get_first_node_in_group("hud_manager") as HUDManager
	var boss_system := get_first_node_in_group("boss_system") as BossSystem
	var ammo_director := get_first_node_in_group(
		"survival_ammo_director"
	) as SurvivalAmmoDirector
	_expect(wave_manager != null, "wave manager is available")
	_expect(game_mode_manager != null, "game mode manager is available")
	_expect(survival_mode != null, "survival mode is registered")
	_expect(local_multiplayer != null, "local multiplayer manager is available")
	_expect(player_manager != null, "player manager is available")
	_expect(health_system != null, "health system is available")
	_expect(progression != null, "progression manager is available")
	_expect(hud != null, "HUD manager is available")
	_expect(boss_system != null, "boss system hook is available")
	_expect(ammo_director != null, "survival ammo director is available")
	if (
		wave_manager == null
		or game_mode_manager == null
		or survival_mode == null
		or local_multiplayer == null
		or player_manager == null
		or health_system == null
		or progression == null
		or hud == null
		or boss_system == null
		or ammo_director == null
	):
		_finish()
		return

	survival_mode.stop_mode()
	await process_frame
	wave_manager.initial_delay = 0.0
	wave_manager.intermission_duration = 0.08
	wave_manager.spawn_interval = 0.05
	wave_manager.base_enemy_count = 2
	wave_manager.enemy_count_growth = 1
	wave_manager.boss_wave_interval = 3
	survival_mode.boss_wave_interval = 3
	wave_manager.boss_wave_escort_count = 4
	wave_manager.spawn_points = [
		Vector2(1100.0, 0.0),
		Vector2(-1100.0, 0.0),
		Vector2(0.0, 700.0),
		Vector2(0.0, -700.0),
		Vector2(900.0, 500.0)
	]
	wave_manager.wave_configured.connect(_on_wave_configured)
	wave_manager.wave_completed.connect(_on_wave_completed)
	wave_manager.boss_wave_requested.connect(_on_boss_wave_requested)
	boss_system.boss_requested.connect(_on_boss_requested)

	var player_one := player_manager.players.get(1) as PlayerController
	_expect(player_one != null, "player one is spawned")
	if player_one == null:
		_finish()
		return

	var player_one_health := player_one.get_node("HealthComponent") as HealthComponent
	var player_one_weapon := player_one.get_node("WeaponSystem") as WeaponSystem
	var blaster := load("res://game/weapons/prototype_blaster.tres") as WeaponData
	player_one_weapon.equip_weapon(blaster)
	var player_one_starting_reserve := player_one_weapon.reserve_ammo

	game_mode_manager.set_mode(GameConstants.MODE_SURVIVAL)
	_expect(survival_mode.is_running, "survival mode starts the wave run")
	health_system.apply_damage(player_one, 30)

	_expect(await _wait_for_wave_spawning(wave_manager, 1), "wave one enters spawning state")
	_expect(
		await _wait_for_spawn_progress(wave_manager, 1, 1),
		"wave one spawns enemies progressively"
	)
	_expect(await _wait_for_wave_combat(wave_manager, 1), "wave one reaches combat state")
	var wave_one_enemies := wave_manager.get_active_wave_enemies()
	_expect(wave_one_enemies.size() == 2, "wave one contains two enemies")
	var wave_one_enemy := wave_one_enemies[0] as BasicEnemy
	var wave_one_health := wave_one_enemy.health_component.max_health
	var wave_one_speed := wave_one_enemy.move_speed
	var wave_one_damage := wave_one_enemy.attack_damage
	_freeze_and_kill_wave(wave_manager, health_system)
	_expect(await _wait_for_completed_wave(1), "wave one completes when all enemies die")
	_expect(progression.money == 4, "wave one grants party money")
	_expect(player_one_health.current_health == 76, "wave one reward heals player one")
	_expect(
		player_one_weapon.reserve_ammo == player_one_starting_reserve + 4,
		"wave one reward grants ammunition"
	)

	local_multiplayer.activate_slot(2)
	await process_frame
	var player_two := player_manager.players.get(2) as PlayerController
	_expect(player_two != null, "player two can join during intermission")
	if player_two == null:
		_finish()
		return
	var player_two_weapon := player_two.get_node("WeaponSystem") as WeaponSystem
	player_two_weapon.equip_weapon(blaster)
	var player_two_starting_reserve := player_two_weapon.reserve_ammo

	_expect(await _wait_for_wave_combat(wave_manager, 2), "wave two reaches combat state")
	var wave_two_enemies := wave_manager.get_active_wave_enemies()
	_expect(wave_two_enemies.size() == 3, "wave two increases enemy count to three")
	var wave_two_enemy := wave_two_enemies[0] as BasicEnemy
	var wave_two_health := wave_two_enemy.health_component.max_health
	_expect(
		wave_two_health > wave_one_health,
		"wave two increases enemy health"
	)
	_expect(wave_two_enemy.move_speed > wave_one_speed, "wave two increases enemy speed")
	_expect(wave_two_enemy.attack_damage > wave_one_damage, "wave two increases enemy damage")
	await process_frame
	_expect(
		not hud.status_label.text.contains("Wave 2"),
		"survival HUD omits the persistent wave info panel"
	)
	_expect(
		not hud.status_label.text.contains("Enemies 3/3"),
		"survival HUD omits the persistent enemy count panel"
	)
	var saved_current_ammo := player_one_weapon.current_ammo
	var saved_reserve_ammo := player_one_weapon.reserve_ammo
	player_one_weapon.current_ammo = 0
	player_one_weapon.reserve_ammo = 0
	_expect(
		ammo_director.evaluate_ammo_pressure(),
		"ammo director spawns support when a living player has low special ammo"
	)
	player_one_weapon.current_ammo = saved_current_ammo
	player_one_weapon.reserve_ammo = saved_reserve_ammo
	_freeze_and_kill_wave(wave_manager, health_system)
	_expect(await _wait_for_completed_wave(2), "wave two completes")
	_expect(progression.money == 10, "wave two adds its party reward")
	_expect(
		player_two_weapon.reserve_ammo == player_two_starting_reserve + 5,
		"joined player receives wave two ammunition reward"
	)

	_expect(await _wait_for_wave_combat(wave_manager, 3), "wave three reaches combat state")
	var wave_three_enemies := wave_manager.get_active_wave_enemies()
	_expect(wave_three_enemies.size() == 4, "boss-marked wave spawns four escorts")
	_expect(wave_manager.current_wave_enemy_total == 5, "boss counts toward the wave total")
	_expect(wave_manager.get_active_boss() is BasicBoss, "boss-marked wave spawns a real boss")
	var wave_three_enemy := wave_three_enemies[0] as BasicEnemy
	_expect(
		wave_three_enemy.health_component.max_health > wave_two_health,
		"boss-marked wave applies additional health scaling"
	)
	_expect(boss_waves.has(3), "wave manager marks wave three as a boss wave")
	_expect(
		boss_requests.has(&"survival_wave_3"),
		"survival mode forwards the boss request to BossSystem"
	)
	var boss_supply_crates := ammo_director.get_active_crates()
	_expect(
		not boss_supply_crates.is_empty(),
		"boss wave has a guaranteed supply crate"
	)
	if not boss_supply_crates.is_empty():
		var supply_crate := boss_supply_crates[0]
		_expect(
			supply_crate.try_open(player_one),
			"supply crate opens and rolls its configured ammo and health loot"
		)
		await process_frame
		_expect(
			_has_pickup_type(GameConstants.DROP_AMMO)
			and _has_pickup_type(GameConstants.DROP_HEALTH),
			"supply crate produces ammo and health pickups"
		)
	_freeze_and_kill_wave(wave_manager, health_system)
	_expect(await _wait_for_completed_wave(3), "wave three completes")
	_expect(progression.money == 18, "three wave rewards accumulate correctly")
	_expect(
		player_one_weapon.reserve_ammo == player_one_starting_reserve + 15,
		"player one receives ammunition after all three waves"
	)
	_expect(
		player_two_weapon.reserve_ammo == player_two_starting_reserve + 11,
		"player two receives rewards only after joining"
	)
	_expect(
		int(wave_manager.last_reward.get("money", 0)) == 8,
		"wave manager exposes the latest reward to the HUD"
	)

	player_one_weapon.current_ammo = 0
	player_one_weapon.reserve_ammo = 0
	player_two_weapon.current_ammo = 0
	player_two_weapon.reserve_ammo = 0
	_expect(
		player_one_weapon.try_fire_base(
			player_one.global_position,
			Vector2.RIGHT,
			player_one
		),
		"player one can still use the separate base weapon at zero equipped ammo"
	)
	_expect(
		player_two_weapon.try_fire_base(
			player_two.global_position,
			Vector2.LEFT,
			player_two
		),
		"player two can still use the separate base weapon at zero equipped ammo"
	)
	_expect(
		player_one_weapon.get_base_weapon_data() != null
		and player_two_weapon.get_base_weapon_data() != null
		and not player_one_weapon.is_base_weapon_active()
		and not player_two_weapon.is_base_weapon_active(),
		"base attacks do not replace the equipped weapon selection"
	)

	survival_mode.stop_mode()
	_expect(not wave_manager.run_active, "stopping survival stops the wave loop")
	_finish()

func _wait_for_wave_spawning(wave_manager: WaveManager, wave_index: int) -> bool:
	for _frame in range(180):
		if wave_manager.current_wave == wave_index and wave_manager.state == WaveManager.State.SPAWNING:
			return true
		await physics_frame
	return false

func _wait_for_spawn_progress(
	wave_manager: WaveManager,
	active_count: int,
	pending_count: int
) -> bool:
	for _frame in range(180):
		if (
			wave_manager.get_active_wave_enemies().size() == active_count
			and wave_manager.pending_spawn_count == pending_count
		):
			return true
		await physics_frame
	return false

func _wait_for_wave_combat(wave_manager: WaveManager, wave_index: int) -> bool:
	for _frame in range(300):
		if wave_manager.current_wave == wave_index and wave_manager.state == WaveManager.State.COMBAT:
			return true
		await physics_frame
	return false

func _wait_for_completed_wave(wave_index: int) -> bool:
	for _frame in range(180):
		if completed_waves.has(wave_index):
			return true
		await physics_frame
	return false

func _freeze_and_kill_wave(
	wave_manager: WaveManager,
	health_system: HealthSystem
) -> void:
	for enemy in wave_manager.get_active_wave_enemies():
		enemy.set_physics_process(false)
		health_system.apply_damage(enemy, 9999)
	var boss := wave_manager.get_active_boss()
	if boss != null:
		boss.set_physics_process(false)
		health_system.apply_damage(boss, 9999)

func _on_wave_configured(wave_index: int, enemy_count: int, is_boss_wave: bool) -> void:
	configured_waves[wave_index] = {
		"enemy_count": enemy_count,
		"is_boss_wave": is_boss_wave
	}

func _on_wave_completed(wave_index: int) -> void:
	completed_waves.append(wave_index)

func _on_boss_wave_requested(wave_index: int) -> void:
	boss_waves.append(wave_index)

func _on_boss_requested(_mode_id: StringName, reason: StringName) -> void:
	boss_requests.append(reason)

func _has_pickup_type(drop_type: StringName) -> bool:
	for pickup in get_nodes_in_group("drop_pickups"):
		if (
			pickup is DropPickup
			and StringName((pickup as DropPickup).drop_data.get("type", &"")) == drop_type
		):
			return true
	return false

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("SURVIVAL_WAVE_SMOKE_TEST: PASS")
		quit(0)
		return

	print("SURVIVAL_WAVE_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
