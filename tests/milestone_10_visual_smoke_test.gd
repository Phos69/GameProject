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

	var player_manager := get_first_node_in_group("player_manager") as PlayerManager
	var enemy_system := get_first_node_in_group("enemy_system") as EnemySystem
	var projectile_system := get_first_node_in_group(
		"projectile_system"
	) as ProjectileSystem
	var drop_system := get_first_node_in_group("drop_system") as DropSystem
	var health_system := get_first_node_in_group("health_system") as HealthSystem
	var game_mode_manager := get_first_node_in_group(
		"game_mode_manager"
	) as GameModeManager
	var hud := get_first_node_in_group("hud_manager") as HUDManager
	var effects := get_first_node_in_group("gameplay_effects") as GameplayEffects
	var playground := main.get_node_or_null("World/Playground") as IsometricPlayground
	var debug_target := main.get_node_or_null(
		"World/CombatTargets/TargetEast"
	) as CombatTarget
	_expect(player_manager != null, "player manager is available")
	_expect(enemy_system != null, "enemy system is available")
	_expect(projectile_system != null, "projectile system is available")
	_expect(drop_system != null, "drop system is available")
	_expect(health_system != null, "health system is available")
	_expect(game_mode_manager != null, "game mode manager is available")
	_expect(hud != null, "HUD manager is available")
	_expect(effects != null, "gameplay effects system is available")
	_expect(playground != null, "survival arena visual is available")
	_expect(
		debug_target != null and debug_target.collision_layer == 0,
		"hidden combat fixtures cannot intercept survival projectiles"
	)
	if (
		player_manager == null
		or enemy_system == null
		or projectile_system == null
		or drop_system == null
		or health_system == null
		or game_mode_manager == null
		or hud == null
		or effects == null
		or playground == null
	):
		_finish()
		return

	var player := player_manager.players.get(1) as PlayerController
	_expect(player != null, "player one is spawned")
	if player == null:
		_finish()
		return
	var player_visual := player.get_node_or_null("Visual") as PlayerVisual
	_expect(player_visual != null, "player uses the modular survivor visual")
	_expect(
		playground.concrete_color.get_luminance() < 0.30,
		"arena background remains muted behind actors"
	)

	game_mode_manager.set_mode(GameConstants.MODE_SURVIVAL)
	await process_frame
	await process_frame
	var player_card := hud.player_cards.get(1) as PlayerHudCard
	_expect(player_card != null and player_card.visible, "HUD shows player one card")
	if player_card != null:
		_expect(
			player_card.health_bar.value == 100.0,
			"player card exposes the current health bar"
		)
		_expect(
			"Starter Pistol" in player_card.weapon_label.text,
			"player card shows weapon identity"
		)

	if player_visual != null:
		player_visual.play_reload(1.0)
		_expect(player_visual.reload_timer > 0.0, "survivor visual exposes reload feedback")
		player_visual.play_fire()
		_expect(player_visual.fire_flash_timer > 0.0, "survivor visual exposes fire feedback")

	var enemy := enemy_system.spawn_enemy(&"survival_zombie", Vector2(180.0, 0.0))
	_expect(enemy is BasicEnemy, "survival zombie can still spawn")
	if enemy is BasicEnemy:
		var zombie_visual := enemy.get_node_or_null("Visual") as ZombieVisual
		_expect(zombie_visual != null, "zombie uses the modular recognizable visual")
		health_system.apply_damage(enemy, 1)
		_expect(
			zombie_visual != null and zombie_visual.hit_flash_timer > 0.0,
			"zombie visual reacts to damage"
		)

	var pickup_scene := load("res://game/drops/drop_pickup.tscn") as PackedScene
	var pickup := pickup_scene.instantiate() as DropPickup
	pickup.setup({"type": GameConstants.DROP_HEALTH, "amount": 10})
	main.get_node("World/Pickups").add_child(pickup)
	await process_frame
	var pickup_visual := pickup.get_node_or_null("Visual") as DropPickupVisual
	_expect(pickup_visual != null, "pickup uses an icon visual component")
	_expect(pickup.get_node_or_null("Label") == null, "pickup no longer relies on text labels")
	if pickup_visual != null:
		_expect(
			pickup_visual.drop_type == GameConstants.DROP_HEALTH,
			"pickup icon is configured from drop type"
		)

	var crate_scene := load("res://game/drops/supply_crate.tscn") as PackedScene
	var crate := crate_scene.instantiate() as SupplyCrate
	main.get_node("World/Pickups").add_child(crate)
	await process_frame
	_expect(
		crate.get_node_or_null("Visual") is SupplyCrateVisual,
		"supply crate uses a graphic visual without a label"
	)
	_expect(crate.get_node_or_null("Label") == null, "supply crate has no text marker")

	var effects_before := effects.effect_spawn_count
	var projectile := projectile_system.spawn_projectile(
		player.global_position,
		Vector2.RIGHT,
		300.0,
		player,
		null,
		10,
		&"starter_pistol"
	) as Projectile
	_expect(projectile != null, "projectile still spawns with the visual pass")
	_expect(
		effects.effect_spawn_count > effects_before,
		"projectile spawn creates a muzzle effect"
	)
	if projectile != null and enemy != null:
		var impact_effects_before := effects.effect_spawn_count
		projectile.impacted.emit(enemy, 10)
		_expect(
			effects.effect_spawn_count > impact_effects_before,
			"valid projectile impact creates a hit effect"
		)

	if enemy != null and is_instance_valid(enemy):
		var death_effects_before := effects.effect_spawn_count
		health_system.apply_damage(enemy, 9999)
		_expect(
			effects.effect_spawn_count > death_effects_before,
			"enemy death creates a readable death effect"
		)

	var pickup_effects_before := effects.effect_spawn_count
	drop_system.drop_collected.emit(
		{"type": GameConstants.DROP_MONEY, "amount": 1},
		player
	)
	_expect(
		effects.effect_spawn_count > pickup_effects_before,
		"drop collection creates a pickup effect"
	)

	_finish()

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("MILESTONE_10_VISUAL_SMOKE_TEST: PASS")
		quit(0)
		return
	print("MILESTONE_10_VISUAL_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
