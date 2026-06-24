extends GutTest
## UI/Audio — Smoke dei contratti di presentazione (HUD, visual, effetti).
##
## Migra:
##   tests/milestone_10_visual_smoke_test.gd  (boot main.tscn, contratti visivi)
##
## Verifica i contratti di presentazione headless (nodi/stato, niente confronto di
## pixel: quello resta nei Visual QA): HUD card e world HUD, visual modulari di
## player/zombie/pickup/crate, e gli effetti di gameplay su sparo/impatto/morte/drop.

const MainSceneFixture = preload("res://tests/support/main_scene_fixture.gd")

func test_presentation_contracts() -> void:
	var scene := MainSceneFixture.new()
	assert_true(scene.boot(self), "main scene can be loaded")
	await wait_frames(3)

	var player_manager := scene.node(&"player_manager") as PlayerManager
	var enemy_system := scene.node(&"enemy_system") as EnemySystem
	var projectile_system := scene.node(&"projectile_system") as ProjectileSystem
	var drop_system := scene.node(&"drop_system") as DropSystem
	var health_system := scene.node(&"health_system") as HealthSystem
	var game_mode_manager := scene.node(&"game_mode_manager") as GameModeManager
	var hud := scene.node(&"hud_manager") as HUDManager
	var effects := scene.node(&"gameplay_effects") as GameplayEffects
	var playground := scene.main.get_node_or_null("World/Playground") as IsometricPlayground
	var debug_target := scene.main.get_node_or_null("World/CombatTargets/TargetEast") as CombatTarget
	assert_not_null(player_manager, "player manager is available")
	assert_not_null(enemy_system, "enemy system is available")
	assert_not_null(projectile_system, "projectile system is available")
	assert_not_null(drop_system, "drop system is available")
	assert_not_null(health_system, "health system is available")
	assert_not_null(game_mode_manager, "game mode manager is available")
	assert_not_null(hud, "HUD manager is available")
	assert_not_null(effects, "gameplay effects system is available")
	assert_not_null(playground, "survival arena visual is available")
	assert_true(
		debug_target != null and debug_target.collision_layer == 0,
		"hidden combat fixtures cannot intercept survival projectiles"
	)
	if (
		player_manager == null or enemy_system == null or projectile_system == null
		or drop_system == null or health_system == null or game_mode_manager == null
		or hud == null or effects == null or playground == null
	):
		scene.teardown()
		return

	var player := player_manager.players.get(1) as PlayerController
	assert_not_null(player, "player one is spawned")
	if player == null:
		scene.teardown()
		return
	var player_visual := player.get_node_or_null("Visual") as PlayerVisual
	assert_not_null(player_visual, "player uses the modular survivor visual")
	var player_world_hud := player.get_node_or_null("WorldHud")
	assert_not_null(player_world_hud, "player uses the world-space HUD package")
	assert_lt(playground.concrete_color.get_luminance(), 0.30, "arena background remains muted behind actors")

	game_mode_manager.set_mode(GameConstants.MODE_SURVIVAL)
	await wait_frames(2)
	var player_card := hud.player_cards.get(1) as PlayerHudCard
	assert_true(player_card != null and player_card.visible, "HUD shows player one card")
	assert_true(
		hud.status_panel != null and not hud.status_panel.is_visible_in_tree(),
		"gameplay HUD hides the persistent status info panel"
	)
	assert_false(hud.status_label.text.contains("Party Lv"), "gameplay HUD omits the persistent party level panel")
	assert_true(
		not hud.status_label.text.contains("Wave ")
		and not hud.status_label.text.contains("Next Wave")
		and not hud.status_label.text.contains("Enemies"),
		"survival HUD omits the persistent wave info panel"
	)
	if player_card != null:
		assert_eq(player_card.health_bar.value, 100.0, "player card still tracks current health data")
		assert_true(
			not player_card.health_bar.is_visible_in_tree()
			and player_card.reload_bar == null
			and player_card.ammo_pips.is_empty(),
			"HP, reload and magazine ammo are no longer duplicated in the corner card"
		)
		assert_true(
			player_card.get_global_rect().position.x <= 24.0
			and player_card.get_global_rect().position.y <= 24.0,
			"player one card is anchored in the top-left corner"
		)
		assert_true("Starter Pistol" in player_card.weapon_label.text, "player card shows weapon identity")

	if player_world_hud != null:
		assert_almost_eq(player_world_hud.get_health_ratio(), 1.0, 0.0001, "world HUD exposes full player health")
		var player_weapon := player.get_node("WeaponSystem") as WeaponSystem
		player_weapon.current_ammo = 0
		assert_true(player_weapon.start_reload(), "weapon reload can be started for world HUD")
		assert_true(player_world_hud.is_showing_reload(), "world HUD switches to reload bar")
		assert_gte(player_world_hud.get_reload_ratio(), 0.0, "world HUD exposes reload progress")

	if player_visual != null:
		assert_false(
			player_visual.has_method("_draw_slot_marker"),
			"survivor visual no longer exposes the standalone overhead marker"
		)
		player_visual.play_fire()
		assert_gt(player_visual.fire_flash_timer, 0.0, "survivor visual exposes fire feedback")

	var enemy := enemy_system.spawn_enemy(&"survival_zombie", Vector2(180.0, 0.0))
	assert_true(enemy is BasicEnemy, "survival zombie can still spawn")
	if enemy is BasicEnemy:
		var zombie_visual := enemy.get_node_or_null("Visual") as ZombieVisual
		assert_not_null(zombie_visual, "zombie uses the modular recognizable visual")
		health_system.apply_damage(enemy, 1)
		assert_true(zombie_visual != null and zombie_visual.hit_flash_timer > 0.0, "zombie visual reacts to damage")

	var pickup_scene := load("res://game/drops/drop_pickup.tscn") as PackedScene
	var pickup := pickup_scene.instantiate() as DropPickup
	pickup.setup({"type": GameConstants.DROP_HEALTH, "amount": 10})
	scene.main.get_node("World/Pickups").add_child(pickup)
	await wait_frames(1)
	var pickup_visual := pickup.get_node_or_null("Visual") as DropPickupVisual
	assert_not_null(pickup_visual, "pickup uses an icon visual component")
	assert_null(pickup.get_node_or_null("Label"), "pickup no longer relies on text labels")
	if pickup_visual != null:
		assert_eq(pickup_visual.drop_type, GameConstants.DROP_HEALTH, "pickup icon is configured from drop type")

	var crate_scene := load("res://game/drops/supply_crate.tscn") as PackedScene
	var crate := crate_scene.instantiate() as SupplyCrate
	scene.main.get_node("World/Pickups").add_child(crate)
	await wait_frames(1)
	assert_true(crate.get_node_or_null("Visual") is SupplyCrateVisual, "supply crate uses a graphic visual without a label")
	assert_null(crate.get_node_or_null("Label"), "supply crate has no text marker")

	var effects_before := effects.effect_spawn_count
	var projectile := projectile_system.spawn_projectile(
		player.global_position, Vector2.RIGHT, 300.0, player, null, 10, &"starter_pistol"
	) as Projectile
	assert_not_null(projectile, "projectile still spawns with the visual pass")
	assert_gt(effects.effect_spawn_count, effects_before, "projectile spawn creates a muzzle effect")
	if projectile != null and enemy != null:
		var impact_effects_before := effects.effect_spawn_count
		projectile.impacted.emit(enemy, 10)
		assert_gt(effects.effect_spawn_count, impact_effects_before, "valid projectile impact creates a hit effect")

	if enemy != null and is_instance_valid(enemy):
		var death_effects_before := effects.effect_spawn_count
		health_system.apply_damage(enemy, 9999)
		assert_gt(effects.effect_spawn_count, death_effects_before, "enemy death creates a readable death effect")

	var pickup_effects_before := effects.effect_spawn_count
	drop_system.drop_collected.emit({"type": GameConstants.DROP_MONEY, "amount": 1}, player)
	assert_gt(effects.effect_spawn_count, pickup_effects_before, "drop collection creates a pickup effect")

	scene.teardown()
	await wait_frames(1)
