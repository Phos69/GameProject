extends GutTest
## Enemies A6 — Nemici tematici, wave director, spawner, varianti, ranged, marker.
##
## Migra e accorpa (ognuno bootava main.tscn da solo):
##   tests/zombie_biome_enemy_smoke_test.gd
##   tests/zombie_biome_wave_director_smoke_test.gd
##   tests/zombie_spawner_edge_smoke_test.gd
##   tests/milestone_12_enemy_variants_smoke_test.gd
##   tests/milestone_15_ranged_enemy_smoke_test.gd
##   tests/offscreen_enemy_markers_smoke_test.gd

const MainSceneFixture = preload("res://tests/support/main_scene_fixture.gd")

var _shooter_projectiles: Array[Projectile] = []

# --- nemici tematici per biome + hazard runtime (zombie_biome_enemy) --------

func test_biome_themed_enemies() -> void:
	var scene := MainSceneFixture.new()
	assert_true(scene.boot(self), "main scene can be loaded")
	await wait_frames(2)
	var enemy_system := scene.node(&"enemy_system") as EnemySystem
	var health_system := scene.node(&"health_system") as HealthSystem
	var hazard_system := scene.node(&"hazard_system") as HazardSystem
	var transition_system := scene.node(&"biome_transition_system") as BiomeTransitionSystem
	var player := scene.node(&"players") as PlayerController
	if enemy_system == null or health_system == null or hazard_system == null or transition_system == null or player == null:
		assert_true(false, "biome enemy systems are available")
		scene.teardown()
		return
	assert_true(scene.start_survival(), "survival starts for thematic enemy validation")
	await wait_frames(1)

	var expected_profiles: Array[StringName] = [
		&"toxic_zombie", &"toxic_exploder", &"burned_zombie", &"fire_runner", &"fire_exploder",
		&"frozen_zombie", &"ice_armored_zombie", &"heavy_slow_zombie", &"drowned_zombie", &"marsh_zombie", &"water_emerging_zombie"
	]
	for enemy_id in expected_profiles:
		var profile := enemy_system.get_enemy_profile(enemy_id)
		assert_not_null(profile, "%s has a data-driven profile" % String(enemy_id))
		if profile == null:
			continue
		var enemy := enemy_system.spawn_enemy(enemy_id, Vector2(900.0, float(expected_profiles.find(enemy_id)) * 70.0)) as BasicEnemy
		assert_not_null(enemy, "%s can be spawned" % String(enemy_id))
		if enemy == null:
			continue
		assert_true(enemy.enemy_profile == profile and enemy.visual.biome_theme_id == profile.theme_id, "%s applies gameplay and visual profile" % String(enemy_id))
		enemy.queue_free()

	var fire_runner := enemy_system.get_enemy_profile(&"fire_runner")
	var ice_armored := enemy_system.get_enemy_profile(&"ice_armored_zombie")
	var water_emerging := enemy_system.get_enemy_profile(&"water_emerging_zombie")
	assert_true(fire_runner.move_speed > 150.0 and fire_runner.max_health < 30, "fire runner is fast and fragile")
	assert_true(ice_armored.max_health > 100 and ice_armored.incoming_damage_multiplier < 1.0, "ice armored zombie is resistant")
	assert_gte(water_emerging.emerge_duration, 1.0, "water zombie has a delayed emergence")

	transition_system.cooldown_timer = 0.0
	transition_system.transition_to(&"toxic_wastes", &"east")
	await wait_frames(1)
	player.global_position = Vector2.ZERO
	var toxic_enemy := enemy_system.spawn_enemy(&"toxic_zombie", Vector2(20.0, 0.0)) as BasicEnemy
	toxic_enemy.target = player
	toxic_enemy._attack_target()
	await wait_frames(1)
	assert_true(hazard_system.get_player_status_ids(player).has(&"poison"), "toxic zombie applies poison on hit")
	assert_lt(player.get_environment_speed_multiplier(), 1.0, "poison status modifies player movement")

	var hazard_count_before := hazard_system.get_active_hazards().size()
	var exploder := enemy_system.spawn_enemy(&"toxic_exploder", Vector2(110.0, 0.0)) as BasicEnemy
	health_system.apply_damage(exploder, 9999, player)
	await wait_frames(2)
	assert_gt(hazard_system.get_active_hazards().size(), hazard_count_before, "toxic exploder leaves a runtime hazard")
	assert_not_null(_find_hazard(hazard_system, &"toxic_cloud"), "toxic exploder creates a toxic cloud")

	var puddle := _find_hazard(hazard_system, &"toxic_puddle")
	if puddle != null:
		var health_before := player.health_component.current_health
		player.global_position = puddle.global_position
		for _frame in range(12):
			await wait_physics_frames(1)
		assert_lt(player.health_component.current_health, health_before, "toxic terrain applies damage over time")
		assert_lt(player.get_environment_speed_multiplier(), 1.0, "toxic terrain slows the player")

	scene.stop_survival()
	scene.teardown()
	await wait_frames(1)

# --- definizioni biome + wave director (zombie_biome_wave_director) ---------

func test_wave_director_biome_scaling() -> void:
	var scene := MainSceneFixture.new()
	assert_true(scene.boot(self), "main scene can be loaded")
	await wait_frames(2)
	var biome_manager = scene.node(&"biome_manager")
	var wave_director = scene.node(&"wave_director")
	var wave_manager := scene.node(&"wave_manager") as WaveManager
	if biome_manager == null or wave_director == null or wave_manager == null:
		assert_true(false, "biome/wave systems are available")
		scene.teardown()
		return

	for biome_id in [&"infected_plains", &"toxic_wastes", &"burning_fields", &"frozen_outskirts", &"drowned_marsh"]:
		var definition = biome_manager.get_biome_definition(StringName(biome_id))
		assert_not_null(definition, "%s biome definition exists" % String(biome_id))
		if definition == null:
			continue
		assert_false(String(definition.get("display_name")).is_empty(), "%s biome has a display name" % String(biome_id))
		assert_not_null(definition.get("palette") as Resource, "%s biome has a palette" % String(biome_id))
		assert_gt((definition.get("terrain_tags") as Array).size(), 0, "%s biome defines terrain tags" % String(biome_id))
		assert_gt((definition.get("obstacle_ids") as Array).size(), 0, "%s biome defines obstacles" % String(biome_id))
		assert_gt((definition.get("crate_ids") as Array).size(), 0, "%s biome defines crate types" % String(biome_id))
		assert_gt((definition.get("allowed_zombie_types") as Array).size(), 0, "%s biome defines allowed zombies" % String(biome_id))
		assert_gt((definition.get("resource_tags") as Array).size(), 0, "%s biome defines resources" % String(biome_id))
		assert_gt(float(definition.get("difficulty_rating")), 0.0, "%s biome defines difficulty" % String(biome_id))

	assert_eq(biome_manager.get_current_biome_id(), &"infected_plains", "run defaults to the starting biome")
	assert_eq(wave_director.get_enemy_id_for_spawn(1, 0, 3), &"survival_zombie", "starting biome first wave keeps base zombies")

	assert_true(biome_manager.set_current_biome(&"toxic_wastes"), "biome manager can switch to the toxic biome")
	var toxic_config: Dictionary = wave_director.configure_wave(2, false, 10)
	assert_gt(int(toxic_config.get("regular_total", 0)), 10, "toxic biome increases regular wave size")
	assert_gt(float(toxic_config.get("spawn_rate_multiplier", 1.0)), 1.0, "toxic biome changes spawn cadence")
	var toxic_scaling: Dictionary = wave_director.get_wave_scaling_multipliers()
	assert_true(float(toxic_scaling.get("health", 1.0)) > 1.0 and float(toxic_scaling.get("damage", 1.0)) > 1.0, "toxic biome changes enemy scaling")
	assert_eq(wave_director.get_enemy_id_for_spawn(2, 0, 10), &"toxic_zombie", "toxic biome can resolve a thematic zombie id")

	wave_manager.stop_run(true)
	wave_manager.initial_delay = 100.0
	wave_manager.base_enemy_count = 10
	wave_manager.enemy_count_growth = 0
	wave_manager.boss_wave_interval = 99
	wave_manager.start_run()
	wave_manager.start_next_wave()
	assert_eq(wave_manager.current_wave_biome_id, &"toxic_wastes", "wave manager records the current toxic biome")
	assert_gt(wave_manager.current_wave_regular_total, 10, "wave manager applies biome wave size")
	assert_eq(wave_manager.get_enemy_id_for_spawn(2, 0, 10), &"toxic_zombie", "wave manager delegates roster to the biome director")
	wave_manager.stop_run(true)

	scene.teardown()
	await wait_frames(1)

# --- spawner: bordi, rifiuti, fallback (zombie_spawner_edge) ----------------

func test_spawner_edges_and_rejection() -> void:
	var scene := MainSceneFixture.new()
	assert_true(scene.boot(self), "main scene can be loaded")
	await wait_frames(2)
	var spawner = scene.node(&"zombie_spawner")
	var player := scene.node(&"players") as Node2D
	if spawner == null or player == null:
		assert_true(false, "spawner and player are available")
		scene.teardown()
		return

	spawner.spawn_group_radius = 0.0
	spawner.spawn_margin = 160.0
	var visible_rect: Rect2 = spawner.get_visible_world_rect()
	assert_gt(visible_rect.size.x, 0.0, "camera visible rect is available")

	var edges: Array = [&"north", &"south", &"east", &"west"]
	for index in range(edges.size()):
		var edge := StringName(edges[index])
		spawner.spawn_edge_weights = _weights_for_edge(edge)
		var spawn_position: Vector2 = spawner.get_spawn_position(index)
		assert_true(_edge_match(edge, spawn_position, visible_rect) and spawner.get_last_spawn_edge() == edge, "%s edge spawns outside the camera" % String(edge))
		var attempt_report: Array = spawner.get_last_spawn_attempt_report()
		assert_true(not attempt_report.is_empty() and StringName(attempt_report.back().get("reason", &"missing")) == &"", "%s edge exposes successful spawn diagnostics" % String(edge))

	assert_false(spawner.is_spawn_position_valid(player.global_position), "spawner rejects positions on top of the player")

	spawner.spawn_edge_weights = _weights_for_edge(&"north")
	var blocked_position: Vector2 = spawner.get_spawn_position(7)
	var fall_zone := Node2D.new()
	fall_zone.name = "TestFallZone"
	fall_zone.global_position = blocked_position
	fall_zone.set_meta("zone_radius", 48.0)
	fall_zone.add_to_group("fall_zones")
	scene.main.add_child(fall_zone)
	await wait_frames(1)
	assert_false(spawner.is_spawn_position_valid(blocked_position), "spawner rejects fall zone positions")
	assert_eq(spawner.get_spawn_rejection_reason(blocked_position), &"hazard", "spawner reports fall zones as hazardous spawn rejection")
	fall_zone.queue_free()
	await wait_frames(1)

	var obstacle_position: Vector2 = spawner.get_spawn_position(8)
	var obstacle := Node2D.new()
	obstacle.name = "TestSpawnBlocker"
	obstacle.global_position = obstacle_position
	obstacle.set_meta("zone_radius", 48.0)
	obstacle.add_to_group("spawn_blockers")
	scene.main.add_child(obstacle)
	await wait_frames(1)
	assert_false(spawner.is_spawn_position_valid(obstacle_position), "spawner rejects spawn blocker positions")
	assert_eq(spawner.get_spawn_rejection_reason(obstacle_position), &"blocked", "spawner reports spawn blockers as blocked spawn rejection")
	obstacle.queue_free()
	await wait_frames(1)

	var old_attempts: int = spawner.max_spawn_attempts
	spawner.max_spawn_attempts = 0
	spawner.configure_fallback_spawn_points([Vector2(64.0, 0.0), Vector2(960.0, 0.0)] as Array[Vector2])
	assert_eq(spawner.get_spawn_position(9), Vector2(960.0, 0.0), "spawner uses the farthest configured fallback when attempts are exhausted")
	spawner.max_spawn_attempts = old_attempts

	scene.teardown()
	await wait_frames(1)

# --- varianti nemico runner/tank (milestone_12_enemy_variants) --------------

func test_enemy_variants() -> void:
	var scene := MainSceneFixture.new()
	assert_true(scene.boot(self), "main scene can be loaded")
	await wait_frames(3)
	var enemy_system := scene.node(&"enemy_system") as EnemySystem
	var wave_manager := scene.node(&"wave_manager") as WaveManager
	var player_manager := scene.node(&"player_manager") as PlayerManager
	var health_system := scene.node(&"health_system") as HealthSystem
	if enemy_system == null or wave_manager == null or player_manager == null or health_system == null:
		assert_true(false, "variant systems are available")
		scene.teardown()
		return

	assert_true(enemy_system.registered_enemy_scenes.has(&"survival_runner"), "runner scene is registered by enemy ID")
	assert_true(enemy_system.registered_enemy_scenes.has(&"survival_tank"), "tank scene is registered by enemy ID")
	var player := player_manager.players.get(1) as PlayerController
	if player == null:
		scene.teardown()
		return
	player.global_position = Vector2.ZERO
	var player_health := player.get_node("HealthComponent") as HealthComponent

	var basic := enemy_system.spawn_enemy(&"survival_zombie", Vector2(700.0, -180.0)) as BasicEnemy
	var runner := enemy_system.spawn_enemy(&"survival_runner", Vector2(700.0, 0.0)) as BasicEnemy
	var tank := enemy_system.spawn_enemy(&"survival_tank", Vector2(700.0, 180.0)) as BasicEnemy
	if basic == null or runner == null or tank == null:
		assert_true(false, "all variants spawn")
		scene.teardown()
		return
	basic.set_physics_process(false)
	runner.set_physics_process(false)
	tank.set_physics_process(false)
	var basic_health := basic.health_component.max_health
	assert_gt(runner.move_speed, basic.move_speed, "runner is faster than basic")
	assert_lt(runner.health_component.max_health, basic_health, "runner trades health for speed")
	assert_lt(runner.attack_cooldown, basic.attack_cooldown, "runner attacks more frequently")
	assert_lt(tank.move_speed, basic.move_speed, "tank is slower than basic")
	assert_gt(tank.health_component.max_health, basic_health, "tank has a larger health pool")
	assert_gt(tank.attack_damage, basic.attack_damage, "tank hits harder than basic")
	assert_eq(runner.visual.archetype_id, "runner", "runner uses its dedicated visual profile")
	assert_eq(tank.visual.archetype_id, "tank", "tank uses its dedicated visual profile")
	assert_lt(runner.visual.get_silhouette_size().x, basic.visual.get_silhouette_size().x, "runner silhouette is narrower than basic")
	assert_gt(tank.visual.get_silhouette_size().x, basic.visual.get_silhouette_size().x, "tank silhouette is wider than basic")
	assert_eq(runner.kill_experience, 7, "runner grants its configured XP reward")
	assert_eq(tank.kill_experience, 12, "tank grants its configured XP reward")

	basic.queue_free()
	await wait_frames(1)
	runner.set_physics_process(true)
	runner.global_position = Vector2(30.0, 0.0)
	player_health.reset_health()
	var runner_health_before := player_health.current_health
	for _frame in range(3):
		await wait_physics_frames(1)
	assert_eq(player_health.current_health, runner_health_before - runner.attack_damage, "runner attack uses shared HealthSystem damage")
	runner.set_physics_process(false)

	tank.set_physics_process(true)
	tank.global_position = Vector2(-45.0, 0.0)
	player_health.reset_health()
	var tank_health_before := player_health.current_health
	for _frame in range(3):
		await wait_physics_frames(1)
	assert_eq(player_health.current_health, tank_health_before - tank.attack_damage, "tank attack uses shared HealthSystem damage")
	tank.set_physics_process(false)

	var active_before_death := enemy_system.get_active_enemies().size()
	health_system.apply_damage(runner, 9999)
	health_system.apply_damage(tank, 9999)
	await wait_frames(1)
	assert_eq(enemy_system.get_active_enemies().size(), active_before_death - 2, "variant deaths use the shared enemy registry")
	assert_eq(_count_xp_pickups(scene, 7), 0, "runner death no longer creates XP pickups")
	assert_eq(_count_xp_pickups(scene, 12), 0, "tank death no longer creates XP pickups")

	assert_eq(wave_manager.get_enemy_id_for_spawn(1, 2, 5), &"survival_zombie", "wave one remains basic-only")
	assert_eq(wave_manager.get_enemy_id_for_spawn(2, 2, 5), &"survival_runner", "runner joins the composition from wave two")
	assert_eq(wave_manager.get_enemy_id_for_spawn(3, 6, 7), &"survival_tank", "tank occupies the final heavy slot from wave three")

	for pickup in scene.nodes(&"drop_pickups"):
		pickup.queue_free()
	await wave_frames_setup(wave_manager)
	assert_true(await _wait_for_wave_combat(wave_manager, 3), "wave three reaches combat with the mixed roster")
	var wave_ids := PackedStringArray()
	for enemy in wave_manager.get_active_wave_enemies():
		wave_ids.append(str(enemy.get("enemy_id")))
	assert_true(wave_ids.has("survival_zombie"), "mixed wave keeps basic zombies")
	assert_true(wave_ids.has("survival_runner"), "mixed wave contains runner zombies")
	assert_true(wave_ids.has("survival_tank"), "mixed wave contains a tank zombie")
	assert_eq(wave_manager.get_enemies_remaining(), wave_manager.current_wave_enemy_total, "variant composition preserves authoritative wave counting")

	wave_manager.stop_run(true)
	scene.teardown()
	await wait_frames(1)

func wave_frames_setup(wave_manager: WaveManager) -> void:
	await wait_frames(1)
	wave_manager.initial_delay = 100.0
	wave_manager.spawn_interval = 0.0
	wave_manager.base_enemy_count = 3
	wave_manager.enemy_count_growth = 2
	wave_manager.boss_wave_interval = 100
	wave_manager.spawn_points = [Vector2(900.0, 0.0), Vector2(-900.0, 0.0), Vector2(0.0, 620.0), Vector2(0.0, -620.0)]
	wave_manager.start_run()
	wave_manager.current_wave = 2
	wave_manager.start_next_wave()

# --- nemico ranged con telegraph (milestone_15_ranged_enemy) ----------------

func test_ranged_enemy() -> void:
	_shooter_projectiles = []
	var scene := MainSceneFixture.new()
	assert_true(scene.boot(self), "main scene can be loaded")
	await wait_frames(3)
	var enemy_system := scene.node(&"enemy_system") as EnemySystem
	var projectile_system := scene.node(&"projectile_system") as ProjectileSystem
	var player_manager := scene.node(&"player_manager") as PlayerManager
	var health_system := scene.node(&"health_system") as HealthSystem
	var wave_manager := scene.node(&"wave_manager") as WaveManager
	if enemy_system == null or projectile_system == null or player_manager == null or health_system == null or wave_manager == null:
		assert_true(false, "ranged systems are available")
		scene.teardown()
		return

	assert_true(enemy_system.registered_enemy_scenes.has(&"survival_shooter"), "shooter scene is registered by enemy ID")
	var player := player_manager.players.get(1) as PlayerController
	if player == null:
		scene.teardown()
		return
	player.global_position = Vector2(180.0, 0.0)
	var player_health := player.health_component

	var shooter: Node = enemy_system.spawn_enemy(&"survival_shooter", Vector2.ZERO)
	assert_not_null(shooter, "ranged zombie spawns through EnemySystem")
	if shooter == null:
		scene.teardown()
		return
	shooter.set_physics_process(false)
	shooter.target = player
	assert_eq(shooter.visual.archetype_id, "shooter", "shooter uses its dedicated visual profile")
	assert_gt(shooter.visual.get_silhouette_size().y, Vector2(46.0, 52.0).y, "shooter silhouette is taller than the basic zombie")
	assert_eq(shooter.kill_experience, 7, "shooter grants its configured XP reward")

	projectile_system.projectile_spawned.connect(_on_shooter_projectile_spawned)
	shooter.windup_duration = 1.0
	assert_true(shooter.start_windup(), "shooter starts a readable windup")
	var locked_direction: Vector2 = shooter.get("locked_shot_direction")
	assert_true(shooter.shot_telegraph.is_warning_active(), "windup activates the world-space lane warning")
	assert_true(_shooter_projectiles.is_empty(), "no projectile exists when the warning begins")
	player.global_position = Vector2(-180.0, 120.0)
	shooter._process_windup(0.5)
	assert_true(_shooter_projectiles.is_empty(), "no projectile is created during the warning")
	shooter._process_windup(0.6)
	await wait_frames(1)
	assert_eq(_shooter_projectiles.size(), 1, "one projectile is created after the warning")
	var projectile := _shooter_projectiles[0] if not _shooter_projectiles.is_empty() else null
	assert_true(projectile != null and projectile.source_id == &"enemy_shooter" and projectile.visual_data != null and projectile.visual_data.profile_id == &"enemy_shooter", "shooter projectile has a distinct hostile profile")
	assert_true(projectile != null and projectile.velocity.normalized().dot(locked_direction) > 0.999, "shot direction remains locked to the announced lane")

	for active_projectile in _shooter_projectiles:
		if is_instance_valid(active_projectile):
			active_projectile.queue_free()
	_shooter_projectiles.clear()
	player.global_position = Vector2(130.0, 0.0)
	player_health.reset_health()
	var health_before := player_health.current_health
	shooter.locked_shot_direction = Vector2.RIGHT
	shooter._fire_locked_shot()
	for _frame in range(90):
		if player_health.current_health < health_before:
			break
		await wait_physics_frames(1)
	assert_eq(player_health.current_health, health_before - shooter.attack_damage, "shooter projectile damages the player through HealthSystem")

	var active_before_death := enemy_system.get_active_enemies().size()
	health_system.apply_damage(shooter, 9999)
	await wait_frames(1)
	assert_eq(enemy_system.get_active_enemies().size(), active_before_death - 1, "shooter death uses the shared enemy registry")
	assert_eq(_count_xp_pickups(scene, 7), 0, "shooter death no longer creates XP pickups")

	assert_ne(wave_manager.get_enemy_id_for_spawn(3, 3, 7), &"survival_shooter", "shooter does not enter before wave four")
	assert_eq(wave_manager.get_enemy_id_for_spawn(4, 3, 9), &"survival_shooter", "every fourth regular slot becomes a shooter from wave four")
	assert_eq(wave_manager.get_enemy_id_for_spawn(4, 8, 9), &"survival_tank", "tank keeps priority in the final heavy slot")

	if projectile_system.projectile_spawned.is_connected(_on_shooter_projectile_spawned):
		projectile_system.projectile_spawned.disconnect(_on_shooter_projectile_spawned)
	scene.teardown()
	await wait_frames(1)

# --- marker direzionali off-screen (offscreen_enemy_markers) ----------------

func test_offscreen_enemy_markers() -> void:
	var scene := MainSceneFixture.new()
	assert_true(scene.boot(self), "main scene loads")
	for _frame in range(6):
		await wait_frames(1)
	var hud := scene.node(&"hud_manager") as HUDManager
	var enemy_system := scene.node(&"enemy_system") as EnemySystem
	if hud == null or enemy_system == null:
		assert_true(false, "hud and enemy system are available")
		scene.teardown()
		return
	var markers := hud.offscreen_enemy_markers
	assert_not_null(markers, "hud creates the offscreen enemy markers node")
	if markers == null:
		scene.teardown()
		return

	assert_true(markers.compute_markers().is_empty(), "no minion yields no marker")
	var canvas_xform := markers.get_viewport().get_canvas_transform()
	var view := markers.get_viewport_rect()
	var inverse := canvas_xform.affine_inverse()
	var on_screen_world := inverse * (view.size * 0.5)
	var off_screen_world := inverse * (view.size + Vector2(700.0, 700.0))
	enemy_system.spawn_enemy(&"toxic_zombie", on_screen_world)
	enemy_system.spawn_enemy(&"toxic_zombie", off_screen_world)

	var result := markers.compute_markers()
	assert_eq(result.size(), 1, "only the off-screen minion produces a marker")
	if result.size() == 1:
		var marker: Dictionary = result[0]
		var facing: Vector2 = marker["facing"]
		assert_true(facing.x > 0.0 and facing.y > 0.0, "marker points toward the off-screen minion (bottom-right)")
		var border: Vector2 = marker["border"]
		assert_true(border.x >= 0.0 and border.x <= view.size.x and border.y >= 0.0 and border.y <= view.size.y, "marker is anchored inside the viewport bounds")
		var margin := OffscreenEnemyMarkers.EDGE_MARGIN
		assert_true(border.x >= margin - 0.5 and border.x <= view.size.x - margin + 0.5 and border.y >= margin - 0.5 and border.y <= view.size.y - margin + 0.5, "marker stays within the inset edge band")
		var closeness: float = marker["closeness"]
		assert_true(closeness >= 0.0 and closeness <= 1.0, "closeness is normalized between 0 and 1")
		assert_true((marker["color"] as Color).is_equal_approx(OffscreenEnemyMarkers.THEME_COLORS[&"toxic"]), "marker inherits the toxic theme color")

	var cap := OffscreenEnemyMarkers.MAX_MARKERS
	for index in range(cap + 8):
		var offset := Vector2(900.0 + index * 12.0, 900.0 + index * 7.0)
		enemy_system.spawn_enemy(&"toxic_zombie", inverse * (view.size + offset))
	assert_lte(markers.compute_markers().size(), cap, "marker count is capped at MAX_MARKERS")

	markers.apply_visual_settings({"high_contrast": true, "reduced_motion": true})
	assert_true(markers.high_contrast and markers.reduced_motion, "visual settings toggle high contrast and reduced motion")

	scene.teardown()
	await wait_frames(1)

# --- helper -----------------------------------------------------------------

func _find_hazard(hazard_system: HazardSystem, hazard_id: StringName) -> Node2D:
	for hazard in hazard_system.get_active_hazards():
		if StringName(hazard.get("hazard_id")) == hazard_id:
			return hazard
	return null

func _weights_for_edge(edge: StringName) -> Dictionary:
	var weights := {&"north": 0.0, &"south": 0.0, &"east": 0.0, &"west": 0.0}
	weights[edge] = 1.0
	return weights

func _edge_match(edge: StringName, position: Vector2, visible_rect: Rect2) -> bool:
	if visible_rect.has_point(position):
		return false
	match edge:
		&"north":
			return position.y < visible_rect.position.y
		&"south":
			return position.y > visible_rect.end.y
		&"east":
			return position.x > visible_rect.end.x
		&"west":
			return position.x < visible_rect.position.x
	return false

func _count_xp_pickups(scene: MainSceneFixture, amount: int) -> int:
	var count := 0
	for pickup in scene.nodes(&"drop_pickups"):
		if pickup is DropPickup:
			var data := (pickup as DropPickup).drop_data
			if StringName(data.get("type", &"")) == GameConstants.DROP_EXPERIENCE and int(data.get("amount", 0)) == amount:
				count += 1
	return count

func _wait_for_wave_combat(wave_manager: WaveManager, wave_index: int) -> bool:
	for _frame in range(180):
		if wave_manager.current_wave == wave_index and wave_manager.state == WaveManager.State.COMBAT:
			return true
		await wait_physics_frames(1)
	return false

func _on_shooter_projectile_spawned(projectile: Node) -> void:
	if projectile is Projectile and projectile.get("source_id") == &"enemy_shooter":
		_shooter_projectiles.append(projectile as Projectile)
