extends GutTest
## Progression A7 — Stat di classe, XP/livelli, passive, adrenalina/super, classi.
##
## Migra e accorpa:
##   tests/milestone_rpg_2_stats_smoke_test.gd        (main.tscn + survival)
##   tests/milestone_rpg_6_xp_level_smoke_test.gd     (main.tscn + survival)
##   tests/milestone_rpg_7_passives_smoke_test.gd     (player sintetico)
##   tests/milestone_rpg_8_adrenaline_super_smoke_test.gd (scena sintetica)
##   tests/milestone_rpg_11_data_driven_smoke_test.gd (solo dati registry)
##   tests/milestone_rpg_13_new_classes_smoke_test.gd (scena sintetica)

const MainSceneFixture = preload("res://tests/support/main_scene_fixture.gd")

var _projectile_spawn_count: int = 0

# --- stat di classe e formule di danno (milestone_rpg_2_stats) --------------

func test_class_stats_and_damage() -> void:
	var scene := MainSceneFixture.new()
	assert_true(scene.boot(self), "main scene can be loaded")
	await wait_frames(2)
	var player_manager := scene.node(&"player_manager") as PlayerManager
	var health_system := scene.node(&"health_system") as HealthSystem
	if player_manager == null or health_system == null:
		assert_true(false, "stats systems are available")
		scene.teardown()
		return
	assert_true(scene.start_survival({"character_id": &"berserker"}), "survival starts as berserker")
	await wait_frames(2)

	var player_one := player_manager.players.get(1) as PlayerController
	if player_one == null:
		scene.teardown()
		return
	var rpg_component := player_one.get_node("RpgPlayerComponent") as RpgPlayerComponent
	var health_component := player_one.get_node("HealthComponent") as HealthComponent
	assert_eq(rpg_component.character_id, &"berserker", "berserker profile is applied")
	assert_eq(health_component.max_health, 125, "class max HP is applied")
	assert_true(is_equal_approx(player_one.move_speed, 260.0 * 0.90), "class speed multiplier is applied")
	assert_eq(rpg_component.get_attack(), 12, "class attack is exposed")
	assert_eq(rpg_component.get_defense(), 1, "class defense is exposed")

	rpg_component.add_experience(45)
	await wait_frames(1)
	assert_eq(rpg_component.level, 2, "run XP levels up the character")
	assert_eq(rpg_component.get_max_hp(), 135, "level up increases max HP")
	assert_eq(rpg_component.get_attack(), 14, "level up increases attack")
	assert_eq(rpg_component.get_defense(), 2, "level up increases defense")
	assert_eq(health_component.max_health, 135, "player health max follows RPG level")

	var enemy := BasicEnemy.new()
	enemy.defense = 4
	assert_eq(rpg_component.resolve_outgoing_damage(10, enemy, Vector2.ZERO, &"test"), 20, "outgoing formula adds attack and subtracts target defense")
	assert_eq(health_system.apply_damage(player_one, 8, enemy, &"test"), 6, "incoming formula subtracts player defense")
	enemy.free()

	scene.stop_survival()
	scene.teardown()
	await wait_frames(1)

# --- XP da kill e wave reward (milestone_rpg_6_xp_level) --------------------

func test_xp_from_kills_and_waves() -> void:
	var scene := MainSceneFixture.new()
	assert_true(scene.boot(self), "main scene can be loaded")
	await wait_frames(2)
	var player_manager := scene.node(&"player_manager") as PlayerManager
	var enemy_system := scene.node(&"enemy_system") as EnemySystem
	var health_system := scene.node(&"health_system") as HealthSystem
	var wave_manager := scene.node(&"wave_manager") as WaveManager
	if player_manager == null or enemy_system == null or health_system == null or wave_manager == null:
		assert_true(false, "xp systems are available")
		scene.teardown()
		return
	assert_true(scene.start_survival({"character_id": &"ranger"}), "survival starts as ranger")
	await wait_frames(2)

	var player := player_manager.players.get(1) as PlayerController
	if player == null:
		scene.teardown()
		return
	var rpg_component := player.get_node("RpgPlayerComponent") as RpgPlayerComponent
	assert_eq(rpg_component.experience, 0, "RPG XP starts at zero")

	var enemy := enemy_system.spawn_enemy(&"survival_zombie", Vector2(160.0, 0.0)) as BasicEnemy
	assert_not_null(enemy, "survival zombie can be spawned")
	if enemy == null:
		scene.teardown()
		return
	health_system.apply_damage(enemy, 9999, player, &"test_kill")
	await wait_frames(1)
	assert_eq(rpg_component.experience, 5, "killer receives zombie kill XP")
	assert_eq(_count_xp_pickups(scene), 0, "zombie death does not create XP pickups")

	wave_manager.current_wave = 2
	var reward := wave_manager._grant_wave_reward()
	assert_eq(int(reward.get("experience", 0)), 20, "wave reward exposes wave XP")
	assert_eq(rpg_component.experience, 25, "wave XP is granted to the player")

	scene.stop_survival()
	scene.teardown()
	await wait_frames(1)

# --- registry data-driven dei personaggi (milestone_rpg_11_data_driven) -----

func test_character_registry_data() -> void:
	var ids := RpgCharacterRegistry.get_character_ids()
	assert_eq(ids.size(), 7, "registry exposes four starters plus three advanced characters")
	for required in [&"ranger", &"pistoliere", &"berserker", &"spadaccino", &"mago", &"domatrice", &"licantropo"]:
		assert_true(ids.has(required), "registry exposes %s" % String(required))

	for character_id in ids:
		var data := load(str(RpgCharacterRegistry.CHARACTER_RESOURCE_PATHS[character_id])) as RpgCharacterData
		assert_not_null(data, "%s resource loads" % str(character_id))
		if data == null:
			continue
		var profile := RpgCharacterRegistry.get_character_profile(character_id)
		assert_eq(profile.get("id", &""), character_id, "%s profile id matches" % str(character_id))
		assert_eq(profile.get("base_weapon_id", &""), data.base_weapon_id, "%s profile comes from resource weapon id" % str(character_id))
		assert_eq(profile.get("super_id", &""), data.super_id, "%s profile comes from resource super id" % str(character_id))
		assert_false(str(profile.get("style_description", "")).is_empty(), "%s profile exposes a style description" % str(character_id))
		assert_false(str(profile.get("gameplay_sprite_path", "")).is_empty(), "%s profile exposes a future gameplay sprite path" % str(character_id))
		var weapon := RpgCharacterRegistry.load_base_weapon(StringName(profile.get("base_weapon_id", &"")))
		assert_not_null(weapon, "%s base weapon loads" % str(character_id))
		if weapon != null:
			assert_gt(weapon.max_range, 0.0, "%s base weapon exposes a readable range stat" % str(character_id))

	assert_eq(RpgCharacterRegistry.get_character_profile(&"missing_class").get("id", &""), RpgCharacterRegistry.DEFAULT_CHARACTER_ID, "unknown character falls back to default profile")

# --- passive di classe (milestone_rpg_7_passives) ---------------------------

func test_class_passives() -> void:
	var player := _spawn_player()
	await wait_frames(2)
	var rpg_component := player.get_node("RpgPlayerComponent") as RpgPlayerComponent
	var health_component := player.get_node("HealthComponent") as HealthComponent
	var weapon_system := player.get_node("WeaponSystem") as WeaponSystem
	if rpg_component == null or health_component == null or weapon_system == null:
		assert_true(false, "player components are available")
		player.queue_free()
		return

	var target := BasicEnemy.new()
	target.defense = 0
	player.global_position = Vector2.ZERO
	target.global_position = Vector2(650.0, 0.0)

	player.apply_rpg_character(&"ranger")
	var ranger_base_damage := 10 + rpg_component.get_attack()
	assert_gt(rpg_component.resolve_outgoing_damage(10, target, target.global_position, &"test"), ranger_base_damage, "ranger gains distance damage")
	assert_true(rpg_component.get_active_passive_text().begins_with("OCCHIO"), "ranger passive is visible after a distant hit")

	player.apply_rpg_character(&"berserker")
	health_component.current_health = roundi(float(health_component.max_health) * 0.35)
	var berserker_base_damage := 10 + rpg_component.get_attack()
	assert_gt(rpg_component.resolve_outgoing_damage(10, target, target.global_position, &"test"), berserker_base_damage, "berserker gains low HP damage")
	assert_eq(rpg_component.get_active_passive_text(), "FURIA +25%", "berserker passive is visible below threshold")

	player.apply_rpg_character(&"pistoliere")
	rpg_component.notify_reload_finished()
	assert_true(is_equal_approx(rpg_component.get_fire_rate_multiplier(), 1.20), "pistoliere reload grants fire rate")
	assert_true(is_equal_approx(weapon_system._get_modified_fire_rate_multiplier(), 1.20), "weapon system reads quick hand fire rate")
	assert_eq(rpg_component.get_active_passive_text(), "MANO VELOCE +20%", "pistoliere passive is visible after reload")

	player.apply_rpg_character(&"spadaccino")
	var guard_target := BasicEnemy.new()
	guard_target.defense = 0
	var guard_health := HealthComponent.new()
	guard_health.name = "HealthComponent"
	guard_target.add_child(guard_health)
	rpg_component.resolve_outgoing_damage(10, guard_target, Vector2.ZERO, &"test")
	assert_eq(rpg_component.resolve_incoming_damage(20, guard_target), 11, "spadaccino guard reduces incoming damage")
	assert_eq(rpg_component.get_active_passive_text(), "GUARDIA -20%", "spadaccino passive is visible after a hit")

	guard_target.free()
	target.free()
	player.queue_free()
	await wait_frames(1)

# --- adrenalina e super (milestone_rpg_8_adrenaline_super) ------------------

func test_adrenaline_and_supers() -> void:
	_projectile_spawn_count = 0
	var scene_root := Node2D.new()
	add_child(scene_root)
	var health_system := HealthSystem.new()
	scene_root.add_child(health_system)
	var projectile_system := ProjectileSystem.new()
	scene_root.add_child(projectile_system)
	projectile_system.projectile_spawned.connect(_on_projectile_spawned)

	var player_scene := load("res://game/player/player.tscn") as PackedScene
	var enemy_scene := load("res://game/enemies/basic_enemy.tscn") as PackedScene
	if player_scene == null or enemy_scene == null:
		assert_true(false, "player and enemy scenes load")
		scene_root.queue_free()
		return
	var player := player_scene.instantiate() as PlayerController
	player.global_position = Vector2.ZERO
	scene_root.add_child(player)
	await wait_frames(2)
	var rpg_component := player.get_node("RpgPlayerComponent") as RpgPlayerComponent
	var player_health := player.get_node("HealthComponent") as HealthComponent
	if rpg_component == null or player_health == null:
		scene_root.queue_free()
		return

	player.apply_rpg_character(&"ranger")
	var hit_enemy := _spawn_enemy(scene_root, enemy_scene, Vector2(140.0, 0.0))
	await wait_frames(1)
	var start_adrenaline := rpg_component.adrenaline
	health_system.apply_damage(hit_enemy, 3, player, &"test_hit")
	assert_gt(rpg_component.adrenaline, start_adrenaline, "damage dealt grants adrenaline")
	var after_dealt := rpg_component.adrenaline
	health_system.apply_damage(player, 3, hit_enemy, &"test_taken")
	assert_gt(rpg_component.adrenaline, after_dealt, "damage taken grants adrenaline")

	player.apply_rpg_character(&"ranger")
	var kill_enemy := _spawn_enemy(scene_root, enemy_scene, Vector2(180.0, 0.0))
	await wait_frames(1)
	health_system.apply_damage(kill_enemy, 9999, player, &"test_kill")
	assert_gte(rpg_component.adrenaline, 6, "kill grants hit and kill adrenaline")

	player.apply_rpg_character(&"pistoliere")
	rpg_component.add_adrenaline(90)
	rpg_component.notify_wave_completed()
	assert_true(rpg_component.is_super_ready(), "wave adrenaline can ready the super")

	player.apply_rpg_character(&"ranger")
	rpg_component.add_adrenaline(100)
	_projectile_spawn_count = 0
	assert_true(rpg_component.try_activate_super(Vector2.RIGHT), "ranger super activates")
	assert_eq(rpg_component.adrenaline, 0, "super activation spends adrenaline")
	assert_eq(_projectile_spawn_count, 12, "arrow rain spawns twelve projectiles")

	player.apply_rpg_character(&"pistoliere")
	_spawn_enemy(scene_root, enemy_scene, Vector2(220.0, 0.0))
	await wait_frames(1)
	_projectile_spawn_count = 0
	rpg_component.add_adrenaline(100)
	assert_true(rpg_component.try_activate_super(Vector2.RIGHT), "pistoliere super activates")
	assert_gt(rpg_component.final_barrage_timer, 0.0, "final barrage keeps an active timer")
	assert_gte(_projectile_spawn_count, 1, "final barrage fires immediately")

	player.apply_rpg_character(&"berserker")
	player.global_position = Vector2.ZERO
	var quake_enemy := _spawn_enemy(scene_root, enemy_scene, Vector2(70.0, 0.0))
	await wait_frames(1)
	var quake_health := quake_enemy.health_component.current_health
	rpg_component.add_adrenaline(100)
	assert_true(rpg_component.try_activate_super(Vector2.RIGHT), "berserker super activates")
	assert_lt(quake_enemy.health_component.current_health, quake_health, "blood quake damages nearby enemies")

	player.apply_rpg_character(&"spadaccino")
	player.global_position = Vector2.ZERO
	var blade_enemy := _spawn_enemy(scene_root, enemy_scene, Vector2(110.0, 0.0))
	await wait_frames(1)
	var blade_health := blade_enemy.health_component.current_health
	var start_position := player.global_position
	player_health.invulnerable = false
	rpg_component.add_adrenaline(100)
	assert_true(rpg_component.try_activate_super(Vector2.RIGHT), "spadaccino super activates")
	assert_gt(player.global_position.distance_to(start_position), 120.0, "phantom blade moves the player forward")
	assert_true(player_health.invulnerable, "phantom blade grants brief invulnerability")
	assert_lt(blade_enemy.health_component.current_health, blade_health, "phantom blade damages enemies in the dash path")
	rpg_component.super_invulnerable_timer = 0.02
	for _frame in range(60):
		if not player_health.invulnerable:
			break
		await wait_frames(1)
	assert_false(player_health.invulnerable, "phantom blade invulnerability recovers")

	scene_root.queue_free()
	await wait_frames(1)

# --- classi avanzate mago/domatrice/licantropo (milestone_rpg_13_new_classes)

func test_advanced_classes() -> void:
	var scene_root := Node2D.new()
	add_child(scene_root)
	scene_root.add_child(HealthSystem.new())
	var player := _spawn_player(scene_root)
	await wait_frames(2)
	var rpg_component := player.get_node("RpgPlayerComponent") as RpgPlayerComponent
	var weapon_system := player.get_node("WeaponSystem") as WeaponSystem
	if rpg_component == null or weapon_system == null:
		scene_root.queue_free()
		return

	var expected := {
		&"mago": [&"rpg_staff", &"arcane_resonance", &"falling_star"],
		&"domatrice": [&"rpg_slingshot", &"briciola_attack", &"scrap_pack"],
		&"licantropo": [&"rpg_claws", &"blood_scent", &"beast_night"]
	}
	for character_id in expected.keys():
		assert_true(player.apply_rpg_character(character_id), "%s can be applied" % str(character_id))
		assert_eq(weapon_system.weapon_data.weapon_id, expected[character_id][0], "%s equips expected weapon" % str(character_id))
		assert_eq(rpg_component.get_passive_id(), expected[character_id][1], "%s exposes expected passive" % str(character_id))
		assert_eq(rpg_component.get_super_id(), expected[character_id][2], "%s exposes expected super" % str(character_id))
		assert_false(str(rpg_component.get_hero_name()).is_empty(), "%s exposes hero name" % str(character_id))

	player.apply_rpg_character(&"domatrice")
	await wait_frames(1)
	assert_true(rpg_component.briciola_companion != null and is_instance_valid(rpg_component.briciola_companion), "domatrice spawns Briciola companion")
	if rpg_component.briciola_companion != null:
		var briciola := rpg_component.briciola_companion
		var briciola_node: Node = briciola
		assert_false(briciola_node is CollisionObject2D, "Briciola does not block Nina")
		assert_lte(briciola.attack_damage, 5, "Briciola base damage stays assistive")
		assert_gte(briciola.attack_cooldown, 0.85, "Briciola base cadence cannot solo waves")
		briciola.start_frenzy(1.0)
		assert_true(briciola.is_frenzy_active(), "scrap pack puts Briciola in frenzy")
		assert_lte(briciola.get_effective_attack_damage(), 8, "frenzy damage stays bounded")
		assert_gte(briciola.get_effective_attack_cooldown(), 0.45, "frenzy cadence stays bounded")
	player.apply_rpg_character(&"mago")
	await wait_frames(1)
	assert_true(rpg_component.briciola_companion == null or not is_instance_valid(rpg_component.briciola_companion), "changing away from domatrice removes Briciola")

	player.apply_rpg_character(&"licantropo")
	rpg_component.add_adrenaline(100)
	assert_true(rpg_component.try_activate_super(Vector2.RIGHT), "licantropo super activates")
	assert_true(rpg_component.is_beast_transformed(), "licantropo enters transformed state")
	rpg_component.beast_night_timer = 0.02
	for _frame in range(60):
		if not rpg_component.is_beast_transformed():
			break
		await wait_frames(1)
	assert_false(rpg_component.is_beast_transformed(), "beast night transformation ends")
	assert_true(rpg_component.is_beast_recovering(), "beast night enters readable recovery")
	rpg_component.super_notice_timer = 0.0
	assert_eq(rpg_component.get_super_status_text(), "RECUPERO", "beast recovery status is explicit")
	rpg_component.beast_recovery_timer = 0.02
	for _frame in range(60):
		if not rpg_component.is_beast_recovering():
			break
		await wait_frames(1)
	assert_false(rpg_component.is_beast_recovering(), "beast recovery expires")

	scene_root.queue_free()
	await wait_frames(1)

# --- helper -----------------------------------------------------------------

func _spawn_player(parent: Node = null) -> PlayerController:
	var player := (load("res://game/player/player.tscn") as PackedScene).instantiate() as PlayerController
	if parent != null:
		parent.add_child(player)
	else:
		add_child(player)
	return player

func _spawn_enemy(parent: Node, enemy_scene: PackedScene, position: Vector2) -> BasicEnemy:
	var enemy := enemy_scene.instantiate() as BasicEnemy
	enemy.global_position = position
	parent.add_child(enemy)
	return enemy

func _count_xp_pickups(scene: MainSceneFixture) -> int:
	var count := 0
	for pickup in scene.nodes(&"drop_pickups"):
		if pickup is DropPickup and StringName((pickup as DropPickup).drop_data.get("type", &"")) == GameConstants.DROP_EXPERIENCE:
			count += 1
	return count

func _on_projectile_spawned(_projectile: Node) -> void:
	_projectile_spawn_count += 1
