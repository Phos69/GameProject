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
	var wave_manager := get_first_node_in_group(
		"wave_manager"
	) as WaveManager
	var enemy_system := get_first_node_in_group(
		"enemy_system"
	) as EnemySystem
	var health_system := get_first_node_in_group(
		"health_system"
	) as HealthSystem
	var hazard_system := get_first_node_in_group(
		"hazard_system"
	) as HazardSystem
	var biome_manager := get_first_node_in_group(
		"biome_manager"
	) as BiomeManager
	var transition_system := get_first_node_in_group(
		"biome_transition_system"
	) as BiomeTransitionSystem
	var player := get_first_node_in_group("players") as PlayerController
	_expect(game_mode_manager != null, "game mode manager is available")
	_expect(wave_manager != null, "wave manager is available")
	_expect(enemy_system != null, "enemy system is available")
	_expect(health_system != null, "health system is available")
	_expect(hazard_system != null, "hazard system is available")
	_expect(biome_manager != null, "biome manager is available")
	_expect(transition_system != null, "transition system is available")
	_expect(player != null, "player one is available")
	if (
		game_mode_manager == null
		or wave_manager == null
		or enemy_system == null
		or health_system == null
		or hazard_system == null
		or biome_manager == null
		or transition_system == null
		or player == null
	):
		_finish()
		return

	wave_manager.initial_delay = 100.0
	_expect(
		game_mode_manager.set_mode(GameConstants.MODE_SURVIVAL),
		"survival starts for thematic enemy validation"
	)
	await process_frame

	var expected_profiles: Array[StringName] = [
		&"toxic_zombie",
		&"toxic_exploder",
		&"burned_zombie",
		&"fire_runner",
		&"fire_exploder",
		&"frozen_zombie",
		&"ice_armored_zombie",
		&"heavy_slow_zombie",
		&"drowned_zombie",
		&"marsh_zombie",
		&"water_emerging_zombie"
	]
	for enemy_id in expected_profiles:
		var profile := enemy_system.get_enemy_profile(enemy_id)
		_expect(
			profile != null,
			"%s has a data-driven profile" % String(enemy_id)
		)
		if profile == null:
			continue
		var enemy := enemy_system.spawn_enemy(
			enemy_id,
			Vector2(900.0, float(expected_profiles.find(enemy_id)) * 70.0)
		) as BasicEnemy
		_expect(enemy != null, "%s can be spawned" % String(enemy_id))
		if enemy == null:
			continue
		_expect(
			enemy.enemy_profile == profile
			and enemy.visual.biome_theme_id == profile.theme_id,
			"%s applies gameplay and visual profile" % String(enemy_id)
		)
		enemy.queue_free()

	var fire_runner := enemy_system.get_enemy_profile(&"fire_runner")
	var ice_armored := enemy_system.get_enemy_profile(&"ice_armored_zombie")
	var water_emerging := enemy_system.get_enemy_profile(
		&"water_emerging_zombie"
	)
	_expect(
		fire_runner.move_speed > 150.0 and fire_runner.max_health < 30,
		"fire runner is fast and fragile"
	)
	_expect(
		ice_armored.max_health > 100
		and ice_armored.incoming_damage_multiplier < 1.0,
		"ice armored zombie is resistant"
	)
	_expect(
		water_emerging.emerge_duration >= 1.0,
		"water zombie has a delayed emergence"
	)

	transition_system.cooldown_timer = 0.0
	transition_system.transition_to(&"toxic_wastes", &"east")
	await process_frame
	player.global_position = Vector2.ZERO
	var toxic_enemy := enemy_system.spawn_enemy(
		&"toxic_zombie",
		Vector2(20.0, 0.0)
	) as BasicEnemy
	toxic_enemy.target = player
	toxic_enemy._attack_target()
	await process_frame
	_expect(
		hazard_system.get_player_status_ids(player).has(&"poison"),
		"toxic zombie applies poison on hit"
	)
	_expect(
		player.get_environment_speed_multiplier() < 1.0,
		"poison status modifies player movement"
	)

	var hazard_count_before := hazard_system.get_active_hazards().size()
	var exploder := enemy_system.spawn_enemy(
		&"toxic_exploder",
		Vector2(110.0, 0.0)
	) as BasicEnemy
	health_system.apply_damage(exploder, 9999, player)
	await process_frame
	await process_frame
	_expect(
		hazard_system.get_active_hazards().size() > hazard_count_before,
		"toxic exploder leaves a runtime hazard"
	)
	_expect(
		_has_hazard(hazard_system, &"toxic_cloud"),
		"toxic exploder creates a toxic cloud"
	)

	var puddle := _find_hazard(hazard_system, &"toxic_puddle")
	if puddle != null:
		var health_before := player.health_component.current_health
		player.global_position = puddle.global_position
		for _frame in range(12):
			await physics_frame
		_expect(
			player.health_component.current_health < health_before,
			"toxic terrain applies damage over time"
		)
		_expect(
			player.get_environment_speed_multiplier() < 1.0,
			"toxic terrain slows the player"
		)

	var survival_mode := get_first_node_in_group(
		"survival_mode"
	) as SurvivalMode
	if survival_mode != null:
		survival_mode.stop_mode()
	_finish()

func _has_hazard(
	hazard_system: HazardSystem,
	hazard_id: StringName
) -> bool:
	return _find_hazard(hazard_system, hazard_id) != null

func _find_hazard(
	hazard_system: HazardSystem,
	hazard_id: StringName
) -> Node2D:
	for hazard in hazard_system.get_active_hazards():
		if StringName(hazard.get("hazard_id")) == hazard_id:
			return hazard
	return null

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("ZOMBIE_BIOME_ENEMY_SMOKE_TEST: PASS")
		quit(0)
		return
	print(
		"ZOMBIE_BIOME_ENEMY_SMOKE_TEST: FAIL (%d)"
		% failures.size()
	)
	quit(1)
