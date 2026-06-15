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

	var game_mode_manager := get_first_node_in_group(
		"game_mode_manager"
	) as GameModeManager
	var player_manager := get_first_node_in_group(
		"player_manager"
	) as PlayerManager
	var enemy_system := get_first_node_in_group("enemy_system") as EnemySystem
	var health_system := get_first_node_in_group("health_system") as HealthSystem
	var wave_manager := get_first_node_in_group("wave_manager") as WaveManager
	_expect(game_mode_manager != null, "game mode manager is available")
	_expect(player_manager != null, "player manager is available")
	_expect(enemy_system != null, "enemy system is available")
	_expect(health_system != null, "health system is available")
	_expect(wave_manager != null, "wave manager is available")
	if (
		game_mode_manager == null
		or player_manager == null
		or enemy_system == null
		or health_system == null
		or wave_manager == null
	):
		_finish()
		return

	game_mode_manager.set_mode(
		GameConstants.MODE_SURVIVAL,
		{"character_id": &"ranger"}
	)
	await process_frame
	await process_frame
	var player := player_manager.players.get(1) as PlayerController
	_expect(player != null, "player one is spawned")
	if player == null:
		_finish()
		return
	var rpg_component := player.get_node(
		"RpgPlayerComponent"
	) as RpgPlayerComponent
	_expect(rpg_component.experience == 0, "RPG XP starts at zero")

	var enemy := enemy_system.spawn_enemy(
		&"survival_zombie",
		Vector2(160.0, 0.0)
	) as BasicEnemy
	_expect(enemy != null, "survival zombie can be spawned")
	if enemy == null:
		_finish()
		return
	health_system.apply_damage(enemy, 9999, player, &"test_kill")
	await process_frame
	_expect(rpg_component.experience == 5, "killer receives zombie kill XP")
	_expect(_count_xp_pickups() == 0, "zombie death does not create XP pickups")

	wave_manager.current_wave = 2
	var reward := wave_manager._grant_wave_reward()
	_expect(int(reward.get("experience", 0)) == 20, "wave reward exposes wave XP")
	_expect(rpg_component.experience == 25, "wave XP is granted to the player")

	_finish()

func _count_xp_pickups() -> int:
	var count := 0
	for pickup in get_nodes_in_group("drop_pickups"):
		if not pickup is DropPickup:
			continue
		var data := (pickup as DropPickup).drop_data
		if StringName(data.get("type", &"")) == GameConstants.DROP_EXPERIENCE:
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
		print("MILESTONE_RPG_6_XP_LEVEL_SMOKE_TEST: PASS")
		quit(0)
		return

	print("MILESTONE_RPG_6_XP_LEVEL_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
