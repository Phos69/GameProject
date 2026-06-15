extends SceneTree

var failures: PackedStringArray = []
var gameplay_feedback_events: Array[StringName] = []

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

	var local_multiplayer := get_first_node_in_group("local_multiplayer_manager") as LocalMultiplayerManager
	var player_manager := get_first_node_in_group("player_manager") as PlayerManager
	var enemy_system := get_first_node_in_group("enemy_system") as EnemySystem
	var drop_system := get_first_node_in_group("drop_system") as DropSystem
	var health_system := get_first_node_in_group("health_system") as HealthSystem
	var progression := get_first_node_in_group("progression_manager") as ProgressionManager
	var audio_manager := get_first_node_in_group("audio_manager") as AudioManager
	_expect(local_multiplayer != null, "local multiplayer manager is available")
	_expect(player_manager != null, "player manager is available")
	_expect(enemy_system != null, "enemy system is available")
	_expect(drop_system != null, "drop system is available")
	_expect(health_system != null, "health system is available")
	_expect(progression != null, "progression manager is available")
	_expect(audio_manager != null, "audio manager is available")
	if (
		local_multiplayer == null
		or player_manager == null
		or enemy_system == null
		or drop_system == null
		or health_system == null
		or progression == null
		or audio_manager == null
	):
		_finish()
		return
	audio_manager.gameplay_feedback_generated.connect(
		_on_gameplay_feedback_generated
	)

	for initial_enemy in get_nodes_in_group("enemies"):
		initial_enemy.queue_free()
	await process_frame

	local_multiplayer.activate_slot(2)
	await process_frame
	var player_one := player_manager.players.get(1) as PlayerController
	var player_two := player_manager.players.get(2) as PlayerController
	_expect(player_one != null and player_two != null, "two local players are active")
	if player_one == null or player_two == null:
		_finish()
		return

	player_one.global_position = Vector2.ZERO
	player_two.global_position = Vector2(80.0, 0.0)

	var enemy := enemy_system.spawn_enemy(&"test_zombie", Vector2(220.0, 0.0)) as BasicEnemy
	_expect(enemy != null, "enemy system spawns a basic enemy")
	if enemy == null:
		_finish()
		return

	var xp_entry := DropEntry.new()
	xp_entry.drop_type = GameConstants.DROP_EXPERIENCE
	xp_entry.chance = 1.0
	xp_entry.min_amount = 3
	xp_entry.max_amount = 3
	var test_loot_table := LootTable.new()
	test_loot_table.entries = [xp_entry]
	enemy.loot_table = test_loot_table

	for _frame in range(4):
		await physics_frame
	_expect(enemy.target == player_two, "enemy targets the nearest living player")
	_expect(enemy.get_state_name() == &"chase", "enemy enters chase state")

	local_multiplayer.deactivate_slot(2)
	for _frame in range(18):
		await physics_frame
	_expect(enemy.target == player_one, "enemy retargets after player two leaves")

	var player_health := player_one.get_node("HealthComponent") as HealthComponent
	enemy.global_position = Vector2(35.0, 0.0)
	for _frame in range(3):
		await physics_frame
	_expect(player_health.current_health == 92, "enemy attack applies damage through HealthSystem")
	_expect(enemy.get_state_name() == &"attack", "enemy enters attack state in range")

	enemy.set_physics_process(false)
	enemy.global_position = Vector2(200.0, 0.0)
	var enemy_health := enemy.get_node("HealthComponent") as HealthComponent
	var weapon_one := player_one.get_node("WeaponSystem") as WeaponSystem
	var shot_direction := player_one.global_position.direction_to(enemy.global_position)
	_expect(
		weapon_one.try_fire(
			player_one.global_position + shot_direction * 22.0,
			shot_direction,
			player_one
		),
		"player projectile can be fired at an enemy"
	)
	for _frame in range(30):
		await physics_frame
	_expect(enemy_health.current_health == 20, "projectile damages the enemy")

	_expect(health_system.apply_damage(enemy, 20) == 20, "lethal damage is applied to the enemy")
	await process_frame
	_expect(enemy_system.get_active_enemies().is_empty(), "dead enemy is removed from EnemySystem")

	var pickups := get_nodes_in_group("drop_pickups")
	_expect(pickups.size() == 1, "enemy death spawns the guaranteed XP pickup")
	if pickups.size() == 1:
		var xp_pickup := pickups[0] as DropPickup
		player_one.global_position = xp_pickup.global_position
		for _frame in range(3):
			await physics_frame
		_expect(progression.experience == 3, "physical pickup grants shared party experience")
		_expect(
			gameplay_feedback_events.has(&"pickup"),
			"physical pickup emits gameplay pickup audio"
		)

	local_multiplayer.activate_slot(2)
	await process_frame
	player_two = player_manager.players.get(2) as PlayerController
	_expect(player_two != null, "player two can rejoin after enemy retargeting")
	if player_two == null:
		_finish()
		return

	var weapon_two := player_two.get_node("WeaponSystem") as WeaponSystem
	var reserve_one_before := weapon_one.reserve_ammo
	var reserve_two_before := weapon_two.reserve_ammo
	_expect(
		drop_system.collect_drop(
			{"type": GameConstants.DROP_MONEY, "amount": 5},
			player_one
		),
		"money drop can be collected"
	)
	_expect(progression.money == 5, "money drop updates shared party money")
	_expect(
		drop_system.collect_drop(
			{"type": GameConstants.DROP_AMMO, "amount": 7},
			player_one
		),
		"ammo drop can be collected"
	)
	_expect(weapon_one.reserve_ammo == reserve_one_before + 7, "ammo applies to the collector")
	_expect(weapon_two.reserve_ammo == reserve_two_before, "ammo does not affect another player")

	_expect(
		drop_system.collect_drop(
			{"type": GameConstants.DROP_HEALTH, "amount": 5},
			player_one
		),
		"health drop can be collected by a damaged player"
	)
	_expect(player_health.current_health == 97, "health drop heals the collector")

	var blaster := load("res://game/weapons/prototype_blaster.tres") as WeaponData
	_expect(
		drop_system.collect_drop(
			{
				"type": GameConstants.DROP_WEAPON,
				"amount": 1,
				"weapon_data": blaster
			},
			player_one
		),
		"weapon drop can be collected"
	)
	_expect(weapon_one.weapon_data.weapon_id == &"prototype_blaster", "weapon drop equips the collector")
	_expect(weapon_two.weapon_data.weapon_id == &"starter_pistol", "weapon drop leaves other players unchanged")

	_finish()

func _on_gameplay_feedback_generated(
	feedback_type: StringName,
	_source_id: StringName,
	_frames_written: int
) -> void:
	gameplay_feedback_events.append(feedback_type)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("ENEMY_DROP_SMOKE_TEST: PASS")
		quit(0)
		return

	print("ENEMY_DROP_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
