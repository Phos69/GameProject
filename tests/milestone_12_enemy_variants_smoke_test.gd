extends SceneTree

var failures: PackedStringArray = []

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

	var enemy_system := get_first_node_in_group("enemy_system") as EnemySystem
	var wave_manager := get_first_node_in_group("wave_manager") as WaveManager
	var player_manager := get_first_node_in_group(
		"player_manager"
	) as PlayerManager
	var health_system := get_first_node_in_group(
		"health_system"
	) as HealthSystem
	_expect(enemy_system != null, "enemy system is available")
	_expect(wave_manager != null, "wave manager is available")
	_expect(player_manager != null, "player manager is available")
	_expect(health_system != null, "health system is available")
	if (
		enemy_system == null
		or wave_manager == null
		or player_manager == null
		or health_system == null
	):
		_finish()
		return

	_expect(
		enemy_system.registered_enemy_scenes.has(&"survival_runner"),
		"runner scene is registered by enemy ID"
	)
	_expect(
		enemy_system.registered_enemy_scenes.has(&"survival_tank"),
		"tank scene is registered by enemy ID"
	)

	var player := player_manager.players.get(1) as PlayerController
	_expect(player != null, "player one is available")
	if player == null:
		_finish()
		return
	player.global_position = Vector2.ZERO
	var player_health := player.get_node("HealthComponent") as HealthComponent

	var basic := enemy_system.spawn_enemy(
		&"survival_zombie",
		Vector2(700.0, -180.0)
	) as BasicEnemy
	var runner := enemy_system.spawn_enemy(
		&"survival_runner",
		Vector2(700.0, 0.0)
	) as BasicEnemy
	var tank := enemy_system.spawn_enemy(
		&"survival_tank",
		Vector2(700.0, 180.0)
	) as BasicEnemy
	_expect(basic != null, "basic zombie still spawns")
	_expect(runner != null, "runner zombie spawns through EnemySystem")
	_expect(tank != null, "tank zombie spawns through EnemySystem")
	if basic == null or runner == null or tank == null:
		_finish()
		return

	basic.set_physics_process(false)
	runner.set_physics_process(false)
	tank.set_physics_process(false)
	var basic_health := basic.health_component.max_health
	var runner_health := runner.health_component.max_health
	var tank_health := tank.health_component.max_health
	_expect(runner.move_speed > basic.move_speed, "runner is faster than basic")
	_expect(runner_health < basic_health, "runner trades health for speed")
	_expect(runner.attack_cooldown < basic.attack_cooldown, "runner attacks more frequently")
	_expect(tank.move_speed < basic.move_speed, "tank is slower than basic")
	_expect(tank_health > basic_health, "tank has a larger health pool")
	_expect(tank.attack_damage > basic.attack_damage, "tank hits harder than basic")
	_expect(
		runner.visual.archetype_id == "runner",
		"runner uses its dedicated visual profile"
	)
	_expect(
		tank.visual.archetype_id == "tank",
		"tank uses its dedicated visual profile"
	)
	_expect(
		runner.visual.get_silhouette_size().x
		< basic.visual.get_silhouette_size().x,
		"runner silhouette is narrower than basic"
	)
	_expect(
		tank.visual.get_silhouette_size().x
		> basic.visual.get_silhouette_size().x,
		"tank silhouette is wider than basic"
	)
	_expect(
		runner.kill_experience == 7,
		"runner grants its configured XP reward"
	)
	_expect(
		tank.kill_experience == 12,
		"tank grants its configured XP reward"
	)

	basic.queue_free()
	await process_frame
	runner.set_physics_process(true)
	runner.global_position = Vector2(30.0, 0.0)
	player_health.reset_health()
	var runner_health_before := player_health.current_health
	for _frame in range(3):
		await physics_frame
	_expect(
		player_health.current_health == runner_health_before - runner.attack_damage,
		"runner attack uses shared HealthSystem damage"
	)
	runner.set_physics_process(false)

	tank.set_physics_process(true)
	tank.global_position = Vector2(-45.0, 0.0)
	player_health.reset_health()
	var tank_health_before := player_health.current_health
	for _frame in range(3):
		await physics_frame
	_expect(
		player_health.current_health == tank_health_before - tank.attack_damage,
		"tank attack uses shared HealthSystem damage"
	)
	tank.set_physics_process(false)

	var active_before_death := enemy_system.get_active_enemies().size()
	health_system.apply_damage(runner, 9999)
	health_system.apply_damage(tank, 9999)
	await process_frame
	_expect(
		enemy_system.get_active_enemies().size() == active_before_death - 2,
		"variant deaths use the shared enemy registry"
	)
	_expect(
		_count_xp_pickups(7) == 0,
		"runner death no longer creates XP pickups"
	)
	_expect(
		_count_xp_pickups(12) == 0,
		"tank death no longer creates XP pickups"
	)

	_expect(
		wave_manager.get_enemy_id_for_spawn(1, 2, 5)
		== &"survival_zombie",
		"wave one remains basic-only"
	)
	_expect(
		wave_manager.get_enemy_id_for_spawn(2, 2, 5)
		== &"survival_runner",
		"runner joins the composition from wave two"
	)
	_expect(
		wave_manager.get_enemy_id_for_spawn(3, 6, 7)
		== &"survival_tank",
		"tank occupies the final heavy slot from wave three"
	)

	for pickup in get_nodes_in_group("drop_pickups"):
		pickup.queue_free()
	await process_frame
	wave_manager.initial_delay = 100.0
	wave_manager.spawn_interval = 0.0
	wave_manager.base_enemy_count = 3
	wave_manager.enemy_count_growth = 2
	wave_manager.boss_wave_interval = 100
	wave_manager.spawn_points = [
		Vector2(900.0, 0.0),
		Vector2(-900.0, 0.0),
		Vector2(0.0, 620.0),
		Vector2(0.0, -620.0)
	]
	wave_manager.start_run()
	wave_manager.current_wave = 2
	wave_manager.start_next_wave()
	_expect(
		await _wait_for_wave_combat(wave_manager, 3),
		"wave three reaches combat with the mixed roster"
	)
	var wave_ids := PackedStringArray()
	for enemy in wave_manager.get_active_wave_enemies():
		wave_ids.append(str(enemy.get("enemy_id")))
	_expect(
		wave_ids.has("survival_zombie"),
		"mixed wave keeps basic zombies"
	)
	_expect(
		wave_ids.has("survival_runner"),
		"mixed wave contains runner zombies"
	)
	_expect(
		wave_ids.has("survival_tank"),
		"mixed wave contains a tank zombie"
	)
	_expect(
		wave_manager.get_enemies_remaining()
		== wave_manager.current_wave_enemy_total,
		"variant composition preserves authoritative wave counting"
	)

	wave_manager.stop_run(true)
	await process_frame
	_finish()

func _wait_for_wave_combat(
	wave_manager: WaveManager,
	wave_index: int
) -> bool:
	for _frame in range(180):
		if (
			wave_manager.current_wave == wave_index
			and wave_manager.state == WaveManager.State.COMBAT
		):
			return true
		await physics_frame
	return false

func _count_xp_pickups(amount: int) -> int:
	var count := 0
	for pickup in get_nodes_in_group("drop_pickups"):
		if not pickup is DropPickup:
			continue
		var data := (pickup as DropPickup).drop_data
		if (
			StringName(data.get("type", &""))
			== GameConstants.DROP_EXPERIENCE
			and int(data.get("amount", 0)) == amount
		):
			count += 1
	return count

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("MILESTONE_12_ENEMY_VARIANTS_SMOKE_TEST: PASS")
		quit(0)
		return
	print(
		"MILESTONE_12_ENEMY_VARIANTS_SMOKE_TEST: FAIL (%d)"
		% failures.size()
	)
	quit(1)
