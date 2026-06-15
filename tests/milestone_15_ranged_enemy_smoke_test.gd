extends SceneTree

var failures: PackedStringArray = []
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

	var enemy_system := get_first_node_in_group("enemy_system") as EnemySystem
	var projectile_system := get_first_node_in_group(
		"projectile_system"
	) as ProjectileSystem
	var player_manager := get_first_node_in_group(
		"player_manager"
	) as PlayerManager
	var health_system := get_first_node_in_group(
		"health_system"
	) as HealthSystem
	var wave_manager := get_first_node_in_group("wave_manager") as WaveManager
	_expect(enemy_system != null, "enemy system is available")
	_expect(projectile_system != null, "projectile system is available")
	_expect(player_manager != null, "player manager is available")
	_expect(health_system != null, "health system is available")
	_expect(wave_manager != null, "wave manager is available")
	if (
		enemy_system == null
		or projectile_system == null
		or player_manager == null
		or health_system == null
		or wave_manager == null
	):
		_finish()
		return

	_expect(
		enemy_system.registered_enemy_scenes.has(&"survival_shooter"),
		"shooter scene is registered by enemy ID"
	)
	var player := player_manager.players.get(1) as PlayerController
	_expect(player != null, "player one is available")
	if player == null:
		_finish()
		return
	player.global_position = Vector2(180.0, 0.0)
	var player_health := player.health_component

	var shooter: Node = enemy_system.spawn_enemy(
		&"survival_shooter",
		Vector2.ZERO
	)
	_expect(shooter != null, "ranged zombie spawns through EnemySystem")
	if shooter == null:
		_finish()
		return
	shooter.set_physics_process(false)
	shooter.target = player
	_expect(
		shooter.visual.archetype_id == "shooter",
		"shooter uses its dedicated visual profile"
	)
	_expect(
		shooter.visual.get_silhouette_size().y
		> Vector2(46.0, 52.0).y,
		"shooter silhouette is taller than the basic zombie"
	)
	_expect(
		_get_guaranteed_xp(shooter.loot_table) == 6,
		"shooter grants its configured XP reward"
	)

	projectile_system.projectile_spawned.connect(_on_projectile_spawned)
	shooter.windup_duration = 1.0
	_expect(shooter.start_windup(), "shooter starts a readable windup")
	var locked_direction: Vector2 = shooter.get("locked_shot_direction")
	_expect(
		shooter.shot_telegraph.is_warning_active(),
		"windup activates the world-space lane warning"
	)
	_expect(
		spawned_projectiles.is_empty(),
		"no projectile exists when the warning begins"
	)
	player.global_position = Vector2(-180.0, 120.0)
	shooter._process_windup(0.5)
	_expect(
		spawned_projectiles.is_empty(),
		"no projectile is created during the warning"
	)
	shooter._process_windup(0.6)
	await process_frame
	_expect(
		spawned_projectiles.size() == 1,
		"one projectile is created after the warning"
	)
	var projectile := (
		spawned_projectiles[0]
		if not spawned_projectiles.is_empty()
		else null
	)
	_expect(
		projectile != null
		and projectile.source_id == &"enemy_shooter"
		and projectile.visual_data != null
		and projectile.visual_data.profile_id == &"enemy_shooter",
		"shooter projectile has a distinct hostile profile"
	)
	_expect(
		projectile != null
		and projectile.velocity.normalized().dot(locked_direction) > 0.999,
		"shot direction remains locked to the announced lane"
	)

	for active_projectile in spawned_projectiles:
		if is_instance_valid(active_projectile):
			active_projectile.queue_free()
	spawned_projectiles.clear()
	player.global_position = Vector2(130.0, 0.0)
	player_health.reset_health()
	var health_before := player_health.current_health
	shooter.locked_shot_direction = Vector2.RIGHT
	shooter._fire_locked_shot()
	for _frame in range(90):
		if player_health.current_health < health_before:
			break
		await physics_frame
	_expect(
		player_health.current_health == health_before - shooter.attack_damage,
		"shooter projectile damages the player through HealthSystem"
	)

	var active_before_death := enemy_system.get_active_enemies().size()
	health_system.apply_damage(shooter, 9999)
	await process_frame
	_expect(
		enemy_system.get_active_enemies().size() == active_before_death - 1,
		"shooter death uses the shared enemy registry"
	)
	_expect(
		_count_xp_pickups(6) >= 1,
		"shooter death creates its guaranteed XP pickup"
	)

	_expect(
		wave_manager.get_enemy_id_for_spawn(3, 3, 7)
		!= &"survival_shooter",
		"shooter does not enter before wave four"
	)
	_expect(
		wave_manager.get_enemy_id_for_spawn(4, 3, 9)
		== &"survival_shooter",
		"every fourth regular slot becomes a shooter from wave four"
	)
	_expect(
		wave_manager.get_enemy_id_for_spawn(4, 8, 9)
		== &"survival_tank",
		"tank keeps priority in the final heavy slot"
	)

	_finish()

func _get_guaranteed_xp(loot_table: LootTable) -> int:
	if loot_table == null:
		return 0
	for entry in loot_table.entries:
		if (
			entry != null
			and entry.drop_type == GameConstants.DROP_EXPERIENCE
			and entry.chance >= 1.0
		):
			return entry.min_amount
	return 0

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

func _on_projectile_spawned(projectile: Node) -> void:
	if projectile is Projectile and projectile.get("source_id") == &"enemy_shooter":
		spawned_projectiles.append(projectile as Projectile)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("MILESTONE_15_RANGED_ENEMY_SMOKE_TEST: PASS")
		quit(0)
		return
	print(
		"MILESTONE_15_RANGED_ENEMY_SMOKE_TEST: FAIL (%d)"
		% failures.size()
	)
	quit(1)
