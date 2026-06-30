extends GutTest
## Combat A5 — Drop, progressione da kill, identità tower e status effect.
##
## Migra e accorpa:
##   tests/enemy_drop_smoke_test.gd  (boot main.tscn)
##   tests/milestone_11_weapon_drop_progression_smoke_test.gd  (boot + survival arena)
##   tests/milestone_13_weapon_tower_visual_smoke_test.gd  (boot + survival + tower)
##   tests/biome_status_effects_smoke_test.gd  (scena sintetica)

const MainSceneFixture = preload("res://tests/support/main_scene_fixture.gd")

var _feedback_events: Array[StringName] = []
var _spawned_projectiles: Array[Projectile] = []
var _tower_shots: Array[Projectile] = []
var _tower_shot_profiles: Array[StringName] = []

# --- loop drop nemico: targeting, kill, pickup, drop condivisi --------------

func test_enemy_drop_loop() -> void:
	_feedback_events = []
	var scene := MainSceneFixture.new()
	assert_true(scene.boot(self), "main scene can be loaded")
	await wait_physics_frames(2)

	var local_multiplayer := scene.node(&"local_multiplayer_manager") as LocalMultiplayerManager
	var player_manager := scene.node(&"player_manager") as PlayerManager
	var enemy_system := scene.node(&"enemy_system") as EnemySystem
	var drop_system := scene.node(&"drop_system") as DropSystem
	var health_system := scene.node(&"health_system") as HealthSystem
	var progression := scene.node(&"progression_manager") as ProgressionManager
	var audio_manager := scene.node(&"audio_manager") as AudioManager
	for n in [local_multiplayer, player_manager, enemy_system, drop_system, health_system, progression, audio_manager]:
		assert_not_null(n, "combat system is available")
	if local_multiplayer == null or player_manager == null or enemy_system == null or drop_system == null or health_system == null or progression == null or audio_manager == null:
		scene.teardown()
		return
	audio_manager.gameplay_feedback_generated.connect(_on_gameplay_feedback_generated)

	for initial_enemy in scene.nodes(&"enemies"):
		initial_enemy.queue_free()
	await wait_physics_frames(1)
	local_multiplayer.activate_slot(2)
	await wait_physics_frames(1)
	var player_one := player_manager.players.get(1) as PlayerController
	var player_two := player_manager.players.get(2) as PlayerController
	assert_true(player_one != null and player_two != null, "two local players are active")
	if player_one == null or player_two == null:
		_teardown_drops(audio_manager, local_multiplayer, scene)
		return

	player_one.global_position = Vector2.ZERO
	player_two.global_position = Vector2(80.0, 0.0)
	var enemy := enemy_system.spawn_enemy(&"test_zombie", Vector2(220.0, 0.0)) as BasicEnemy
	assert_not_null(enemy, "enemy system spawns a basic enemy")
	if enemy == null:
		_teardown_drops(audio_manager, local_multiplayer, scene)
		return
	enemy.loot_table = _make_loot(GameConstants.DROP_EXPERIENCE, 3)

	for _frame in range(4):
		await wait_physics_frames(1)
	assert_eq(enemy.target, player_two, "enemy targets the nearest living player")
	assert_eq(enemy.get_state_name(), &"chase", "enemy enters chase state")

	local_multiplayer.deactivate_slot(2)
	for _frame in range(18):
		await wait_physics_frames(1)
	assert_eq(enemy.target, player_one, "enemy retargets after player two leaves")

	var player_health := player_one.get_node("HealthComponent") as HealthComponent
	enemy.global_position = Vector2(35.0, 0.0)
	for _frame in range(3):
		await wait_physics_frames(1)
	assert_eq(player_health.current_health, 92, "enemy attack applies damage through HealthSystem")
	assert_eq(enemy.get_state_name(), &"attack", "enemy enters attack state in range")

	enemy.set_physics_process(false)
	enemy.global_position = Vector2(200.0, 0.0)
	var enemy_health := enemy.get_node("HealthComponent") as HealthComponent
	var weapon_one := player_one.get_node("WeaponSystem") as WeaponSystem
	var shot_direction := player_one.global_position.direction_to(enemy.global_position)
	assert_true(weapon_one.try_fire(player_one.global_position + shot_direction * 22.0, shot_direction, player_one), "player projectile can be fired at an enemy")
	for _frame in range(30):
		await wait_physics_frames(1)
	assert_eq(enemy_health.current_health, 20, "projectile damages the enemy")

	assert_eq(health_system.apply_damage(enemy, 20), 20, "lethal damage is applied to the enemy")
	await wait_physics_frames(1)
	assert_true(enemy_system.get_active_enemies().is_empty(), "dead enemy is removed from EnemySystem")

	var pickups := scene.nodes(&"drop_pickups")
	assert_eq(pickups.size(), 1, "enemy death spawns the guaranteed XP pickup")
	if pickups.size() == 1:
		var xp_pickup := pickups[0] as DropPickup
		player_one.global_position = xp_pickup.global_position
		for _frame in range(3):
			await wait_physics_frames(1)
		assert_eq(progression.experience, 3, "physical pickup grants shared party experience")
		assert_true(_feedback_events.has(&"pickup"), "physical pickup emits gameplay pickup audio")

	local_multiplayer.activate_slot(2)
	await wait_physics_frames(1)
	player_two = player_manager.players.get(2) as PlayerController
	assert_not_null(player_two, "player two can rejoin after enemy retargeting")
	if player_two == null:
		_teardown_drops(audio_manager, local_multiplayer, scene)
		return
	var weapon_two := player_two.get_node("WeaponSystem") as WeaponSystem
	var blaster := load("res://game/weapons/prototype_blaster.tres") as WeaponData
	weapon_one.equip_weapon(blaster)
	weapon_two.equip_weapon(blaster)
	var reserve_one_before := weapon_one.reserve_ammo
	var reserve_two_before := weapon_two.reserve_ammo
	assert_true(drop_system.collect_drop({"type": GameConstants.DROP_MONEY, "amount": 5}, player_one), "money drop can be collected")
	assert_eq(progression.money, 5, "money drop updates shared party money")
	assert_true(drop_system.collect_drop({"type": GameConstants.DROP_AMMO, "amount": 7}, player_one), "ammo drop can be collected")
	assert_eq(weapon_one.reserve_ammo, reserve_one_before + 7, "ammo applies to the collector special weapon")
	assert_eq(weapon_two.reserve_ammo, reserve_two_before + 7, "ammo is shared with another living player special weapon")
	await wait_physics_frames(1)
	var hud := scene.node(&"hud_manager") as HUDManager
	assert_true(hud != null and hud.pickup_feedback_text == "AMMO SHARED +7", "HUD queues shared ammo pickup feedback")
	assert_true(drop_system.collect_drop({"type": GameConstants.DROP_HEALTH, "amount": 5}, player_one), "health drop can be collected by a damaged player")
	assert_eq(player_health.current_health, 97, "health drop heals the collector")
	var wave_cannon := load("res://game/weapons/wave_cannon.tres") as WeaponData
	assert_true(drop_system.collect_drop({"type": GameConstants.DROP_WEAPON, "amount": 1, "weapon_data": wave_cannon}, player_one), "weapon drop can be collected")
	assert_eq(weapon_one.weapon_data.weapon_id, &"wave_cannon", "weapon drop equips the collector")
	assert_eq(weapon_two.weapon_data.weapon_id, &"prototype_blaster", "weapon drop leaves other players unchanged")

	_teardown_drops(audio_manager, local_multiplayer, scene)

# --- progressione da kill: pickup armi, ammo, XP/level-up, money ------------

func test_weapon_drop_progression() -> void:
	_feedback_events = []
	var scene := MainSceneFixture.new()
	assert_true(scene.boot(self), "main scene can be loaded")
	await wait_physics_frames(4)

	var player_manager := scene.node(&"player_manager") as PlayerManager
	var enemy_system := scene.node(&"enemy_system") as EnemySystem
	var drop_system := scene.node(&"drop_system") as DropSystem
	var health_system := scene.node(&"health_system") as HealthSystem
	var progression := scene.node(&"progression_manager") as ProgressionManager
	var audio_manager := scene.node(&"audio_manager") as AudioManager
	var gameplay_effects := scene.node(&"gameplay_effects") as GameplayEffects
	if player_manager == null or enemy_system == null or drop_system == null or health_system == null or progression == null or audio_manager == null or gameplay_effects == null:
		assert_true(false, "all combat/progression systems are available")
		scene.teardown()
		return
	audio_manager.gameplay_feedback_generated.connect(_on_gameplay_feedback_generated)
	assert_true(scene.start_survival({"character_id": &"ranger", "single_biome_arena": true, "arena_boundary_mode": "walled", "world_seed": 20260621}), "survival arena starts")
	await wait_physics_frames(6)
	for initial_enemy in scene.nodes(&"enemies"):
		initial_enemy.queue_free()
	await wait_physics_frames(2)

	var player := player_manager.players.get(1) as PlayerController
	assert_not_null(player, "player one is spawned for the run")
	if player == null:
		_teardown_drops(audio_manager, null, scene)
		return
	player.global_position = Vector2.ZERO
	var weapon_system := player.get_node("WeaponSystem") as WeaponSystem
	var rpg_component := player.get_node("RpgPlayerComponent") as RpgPlayerComponent
	var world_hud := player.get_node("WorldHud") as PlayerWorldHudVisual
	if weapon_system == null or rpg_component == null or world_hud == null:
		assert_true(false, "player weapon/rpg/hud are available")
		_teardown_drops(audio_manager, null, scene)
		return
	assert_eq(rpg_component.character_id, &"ranger", "survival run applies the selected RPG class")
	assert_true(weapon_system.has_base_weapon(&"rpg_bow"), "Ranger base weapon is separate and permanent")

	var blaster := load("res://game/weapons/prototype_blaster.tres") as WeaponData
	var revolver := WeaponCatalog.get_definition(&"heavy_revolver")
	assert_true(drop_system.collect_drop({"type": GameConstants.DROP_WEAPON, "amount": 1, "weapon_data": blaster}, player), "first weapon pickup is collected")
	assert_true(drop_system.collect_drop({"type": GameConstants.DROP_WEAPON, "amount": 1, "weapon_data": revolver}, player), "second weapon pickup is collected")
	assert_eq(weapon_system.get_weapon_count(), 2, "two picked weapons stay in the inventory")
	assert_eq(weapon_system.weapon_data.weapon_id, &"heavy_revolver", "latest pickup is auto-selected")
	assert_true(weapon_system.switch_weapon(1), "inventory slot switch succeeds with two weapons")
	assert_eq(weapon_system.weapon_data.weapon_id, &"prototype_blaster", "slot switch restores the previous weapon")
	assert_eq(world_hud.get_magazine_size(), blaster.magazine_size, "world HUD follows the equipped weapon magazine")

	weapon_system.current_ammo = 1
	weapon_system.reserve_ammo = 0
	weapon_system.cooldown = 0.0
	assert_true(weapon_system.try_fire_equipped(player.global_position, Vector2.RIGHT, player), "equipped weapon fires its last round")
	assert_eq(weapon_system.current_ammo, 0, "equipped weapon consumes ammo")
	weapon_system.cooldown = 0.0
	assert_false(weapon_system.try_fire_equipped(player.global_position, Vector2.RIGHT, player), "empty equipped weapon does not fire")
	assert_eq(weapon_system.weapon_data.weapon_id, &"prototype_blaster", "empty equipped weapon remains selected")
	assert_true(drop_system.collect_drop({"type": GameConstants.DROP_AMMO, "amount": 5}, player), "ammo pickup is collected")
	assert_true(weapon_system.is_reloading, "ammo pickup starts reload on the empty special")
	assert_true(world_hud.is_showing_reload(), "world HUD exposes reload feedback")

	rpg_component.add_experience(40)
	var effects_before_kill := gameplay_effects.effect_spawn_count
	var money_before := progression.money
	var enemy := enemy_system.spawn_enemy(&"survival_zombie", Vector2(650.0, 0.0)) as BasicEnemy
	assert_not_null(enemy, "survival zombie can be spawned for the loop")
	if enemy == null:
		_teardown_drops(audio_manager, null, scene)
		return
	enemy.set_physics_process(false)
	enemy.global_position = Vector2(650.0, 0.0)
	enemy.loot_table = _make_loot(GameConstants.DROP_MONEY, 9)
	assert_gt(health_system.apply_damage(enemy, 9999, player, &"milestone_11_kill", enemy.global_position), 0, "player damage kills the zombie through HealthSystem")
	await wait_physics_frames(6)

	assert_eq(rpg_component.level, 2, "killer XP levels up the RPG component")
	assert_eq(rpg_component.experience, 0, "level-up consumes the exact XP threshold")
	assert_true(rpg_component.get_active_passive_text().begins_with("OCCHIO"), "Ranger passive feedback is active after a distant hit")
	assert_eq(_count_xp_pickups(scene), 0, "survival zombie kill grants RPG XP directly without XP pickup")
	assert_true(_has_effect_kind(gameplay_effects, &"rpg_level_up"), "level-up visual feedback is spawned")
	assert_gt(gameplay_effects.effect_spawn_count, effects_before_kill, "kill and level-up produce gameplay effects")

	var money_pickup := _find_pickup(scene, GameConstants.DROP_MONEY)
	assert_not_null(money_pickup, "enemy death spawns a physical money drop")
	if money_pickup != null:
		assert_true(money_pickup.try_collect(player), "physical money drop can be collected")
		await wait_physics_frames(2)
		assert_eq(progression.money, money_before + 9, "physical drop updates party money")
	assert_true(_feedback_events.has(&"pickup"), "pickup loop emits gameplay audio feedback")
	assert_true(_feedback_events.has(&"shot"), "weapon loop emits gameplay shot audio feedback")

	scene.stop_survival()
	_teardown_drops(audio_manager, null, scene)

# --- identità visiva armi/tower attraverso le modalità ----------------------

func test_weapon_tower_visual_identity() -> void:
	_spawned_projectiles = []
	_tower_shots = []
	_tower_shot_profiles = []
	var scene := MainSceneFixture.new()
	assert_true(scene.boot(self), "main scene can be loaded")
	await wait_physics_frames(3)

	var local_multiplayer := scene.node(&"local_multiplayer_manager") as LocalMultiplayerManager
	var player_manager := scene.node(&"player_manager") as PlayerManager
	var game_mode_manager := scene.node(&"game_mode_manager") as GameModeManager
	var projectile_system := scene.node(&"projectile_system") as ProjectileSystem
	var tower_defense_mode := scene.node(&"tower_defense_mode") as TowerDefenseMode
	var hud := scene.node(&"hud_manager") as HUDManager
	if local_multiplayer == null or player_manager == null or game_mode_manager == null or projectile_system == null or tower_defense_mode == null or hud == null:
		assert_true(false, "tower/weapon systems are available")
		scene.teardown()
		return

	for player_slot in range(2, 5):
		local_multiplayer.activate_slot(player_slot)
	await wait_physics_frames(1)
	game_mode_manager.set_mode(GameConstants.MODE_SURVIVAL)
	await wait_physics_frames(2)

	var starter := load("res://game/weapons/starter_pistol.tres") as WeaponData
	var blaster := load("res://game/weapons/prototype_blaster.tres") as WeaponData
	var cannon := load("res://game/weapons/wave_cannon.tres") as WeaponData
	assert_true(starter != null and starter.visual_data != null, "starter pistol has visual data")
	assert_true(blaster != null and blaster.visual_data != null, "prototype blaster has visual data")
	assert_true(cannon != null and cannon.visual_data != null, "Wave Cannon has visual data")
	if starter == null or blaster == null or cannon == null:
		_teardown_tower(projectile_system, scene)
		return
	assert_eq(starter.visual_data.profile_id, &"starter_pistol", "starter pistol exposes its compact profile")
	assert_eq(blaster.visual_data.profile_id, &"prototype_blaster", "prototype blaster exposes its twin-prong profile")
	assert_eq(cannon.visual_data.profile_id, &"wave_cannon", "Wave Cannon exposes its heavy profile")
	assert_true(cannon.visual_data.weapon_length > blaster.visual_data.weapon_length and blaster.visual_data.weapon_length > starter.visual_data.weapon_length, "weapon dimensions communicate increasing power")
	assert_true(starter.visual_data.projectile_color != blaster.visual_data.projectile_color and blaster.visual_data.projectile_color != cannon.visual_data.projectile_color, "weapon projectiles use distinct color families")

	var player_one := player_manager.players.get(1) as PlayerController
	var player_two := player_manager.players.get(2) as PlayerController
	var player_three := player_manager.players.get(3) as PlayerController
	assert_true(player_one != null and player_two != null and player_three != null, "three players are available for weapon identity checks")
	if player_one == null or player_two == null or player_three == null:
		_teardown_tower(projectile_system, scene)
		return
	for player_slot in range(1, 5):
		var active_player := player_manager.players.get(player_slot) as PlayerController
		assert_true(active_player != null and active_player.get_node_or_null("WorldHud") != null, "player %d has a world-space HUD package" % player_slot)
	var weapon_one := player_one.get_node("WeaponSystem") as WeaponSystem
	var weapon_two := player_two.get_node("WeaponSystem") as WeaponSystem
	var weapon_three := player_three.get_node("WeaponSystem") as WeaponSystem
	weapon_two.equip_weapon(blaster)
	weapon_three.equip_weapon(cannon)
	await wait_physics_frames(8)
	assert_eq(player_one.visual.get_weapon_profile_id(), &"starter_pistol", "player visual shows the fallback pistol")
	assert_eq(player_two.visual.get_weapon_profile_id(), &"prototype_blaster", "player visual updates when the blaster is equipped")
	assert_eq(player_three.visual.get_weapon_profile_id(), &"wave_cannon", "player visual updates when the Wave Cannon is equipped")
	var card_one := hud.player_cards.get(1) as PlayerHudCard
	var card_two := hud.player_cards.get(2) as PlayerHudCard
	var card_three := hud.player_cards.get(3) as PlayerHudCard
	assert_true(card_one != null and card_one.weapon_icon.get_profile_id() == &"starter_pistol", "starter pistol HUD icon matches the world weapon")
	assert_true(card_two != null and card_two.weapon_icon.get_profile_id() == &"prototype_blaster", "blaster HUD icon matches the world weapon")
	assert_true(card_three != null and card_three.weapon_icon.get_profile_id() == &"wave_cannon", "Wave Cannon HUD icon matches the world weapon")

	projectile_system.projectile_spawned.connect(_on_projectile_spawned)
	player_one.global_position = Vector2(-300.0, 0.0)
	player_two.global_position = Vector2(-300.0, 100.0)
	player_three.global_position = Vector2(-300.0, 200.0)
	weapon_one.try_fire(player_one.global_position, Vector2.RIGHT, player_one)
	weapon_two.try_fire(player_two.global_position, Vector2.RIGHT, player_two)
	weapon_three.try_fire(player_three.global_position, Vector2.RIGHT, player_three)
	await wait_physics_frames(1)
	assert_gte(_spawned_projectiles.size(), 3, "all three weapon projectiles spawn")
	assert_true(_has_projectile_profile(&"starter_pistol"), "starter pistol projectile receives visual data")
	assert_true(_has_projectile_profile(&"prototype_blaster"), "blaster projectile receives visual data")
	assert_true(_has_projectile_profile(&"wave_cannon"), "Wave Cannon projectile receives visual data")
	var cannon_projectile := _find_projectile_profile(&"wave_cannon")
	var starter_projectile := _find_projectile_profile(&"starter_pistol")
	assert_true(cannon_projectile != null and starter_projectile != null and cannon_projectile.visual.scale.x > starter_projectile.visual.scale.x, "Wave Cannon projectile has a heavier silhouette")
	_clear_projectiles(_spawned_projectiles)

	game_mode_manager.set_mode(GameConstants.MODE_TOWER_DEFENSE, {"initial_delay": 100.0, "starting_credits": 75})
	await wait_physics_frames(2)
	var tower := tower_defense_mode.try_build_at_slot(&"slot_b") as DefenseTower
	assert_not_null(tower, "tower can still be built through the shared manager")
	if tower == null:
		_teardown_tower(projectile_system, scene)
		return
	assert_true(tower.visual is DefenseTowerVisual, "tower uses a modular animated visual")
	assert_eq(tower.visual_data.profile_id, &"defense_tower", "tower projectile identity is data-driven")
	assert_eq(tower.visual.visual_data, tower.visual_data, "tower body and projectile share the same visual profile")
	var target_scene := load("res://game/modes/tower_defense/tower_defense_enemy.tscn") as PackedScene
	var target := target_scene.instantiate() as TowerDefenseEnemy
	var path := PackedVector2Array([tower.global_position + Vector2(140.0, 0.0), tower.global_position + Vector2(300.0, 0.0)])
	target.configure_spawn({"path_points": path})
	scene.main.get_node("World/Enemies").add_child(target)
	target.global_position = path[0]
	target.set_physics_process(false)
	tower.attack_range = 400.0
	tower.fire_rate = 20.0
	tower.fired.connect(_on_tower_fired)
	for _frame in range(12):
		await wait_physics_frames(1)
	assert_eq(tower.target, target, "tower still acquires its gameplay target")
	assert_true(tower.visual.tracking_target, "tower barrel visual follows the acquired target")
	assert_false(_tower_shots.is_empty(), "tower still fires through ProjectileSystem")
	if not _tower_shots.is_empty():
		assert_true(not _tower_shot_profiles.is_empty() and _tower_shot_profiles[0] == &"defense_tower", "tower projectile uses the cyan defense profile")
		assert_true(tower.visual.is_fire_feedback_active(), "tower firing produces recoil or muzzle feedback")

	game_mode_manager.set_mode(GameConstants.MODE_SURVIVAL)
	await wait_physics_frames(1)
	_teardown_tower(projectile_system, scene)

# --- status effect ambientali (scena sintetica) -----------------------------

func test_biome_status_effects() -> void:
	var scene_root := Node2D.new()
	scene_root.add_to_group("players")
	add_child(scene_root)
	scene_root.add_child(HealthSystem.new())
	var player := Node2D.new()
	player.add_to_group("players")
	scene_root.add_child(player)
	var health := HealthComponent.new()
	health.name = "HealthComponent"
	health.max_health = 100
	health.current_health = 100
	player.add_child(health)
	var runtime := BiomeStatusRuntime.new()
	for id in [&"poison", &"burn", &"bleed", &"freeze", &"shock"]:
		assert_true(runtime.apply_status(player, id, 1.0, 1.0, null, []), "applies %s" % id)
		assert_true(runtime.has_status(player, id), "has %s" % id)
	runtime.process_runtime(1.2, get_tree(), [])
	for id in [&"poison", &"burn", &"bleed", &"freeze", &"shock"]:
		assert_false(runtime.has_status(player, id), "cleans %s" % id)
	scene_root.queue_free()
	await wait_physics_frames(1)

# --- helper -----------------------------------------------------------------

func _teardown_drops(audio_manager: AudioManager, local_multiplayer: LocalMultiplayerManager, scene: MainSceneFixture) -> void:
	if audio_manager != null and audio_manager.gameplay_feedback_generated.is_connected(_on_gameplay_feedback_generated):
		audio_manager.gameplay_feedback_generated.disconnect(_on_gameplay_feedback_generated)
	if local_multiplayer != null:
		local_multiplayer.deactivate_slot(2)
	scene.teardown()
	await wait_physics_frames(1)

func _teardown_tower(projectile_system: ProjectileSystem, scene: MainSceneFixture) -> void:
	if projectile_system != null and projectile_system.projectile_spawned.is_connected(_on_projectile_spawned):
		projectile_system.projectile_spawned.disconnect(_on_projectile_spawned)
	scene.teardown()
	await wait_physics_frames(1)

func _make_loot(drop_type: StringName, amount: int) -> LootTable:
	var entry := DropEntry.new()
	entry.drop_type = drop_type
	entry.chance = 1.0
	entry.min_amount = amount
	entry.max_amount = amount
	var loot := LootTable.new()
	loot.entries = [entry]
	return loot

func _count_xp_pickups(scene: MainSceneFixture) -> int:
	var count := 0
	for pickup in scene.nodes(&"drop_pickups"):
		if pickup is DropPickup and StringName((pickup as DropPickup).drop_data.get("type", &"")) == GameConstants.DROP_EXPERIENCE:
			count += 1
	return count

func _find_pickup(scene: MainSceneFixture, drop_type: StringName) -> DropPickup:
	for pickup in scene.nodes(&"drop_pickups"):
		if pickup is DropPickup and StringName((pickup as DropPickup).drop_data.get("type", &"")) == drop_type:
			return pickup
	return null

func _has_effect_kind(effects: GameplayEffects, effect_kind: StringName) -> bool:
	for child in effects.get_children():
		if child is GameplayEffect and (child as GameplayEffect).effect_kind == effect_kind:
			return true
	return false

func _has_projectile_profile(profile_id: StringName) -> bool:
	return _find_projectile_profile(profile_id) != null

func _find_projectile_profile(profile_id: StringName) -> Projectile:
	for projectile in _spawned_projectiles:
		if is_instance_valid(projectile) and projectile.visual_data != null and projectile.visual_data.profile_id == profile_id:
			return projectile
	return null

func _clear_projectiles(projectiles: Array[Projectile]) -> void:
	for projectile in projectiles:
		if is_instance_valid(projectile):
			projectile.queue_free()
	projectiles.clear()

func _on_gameplay_feedback_generated(feedback_type: StringName, _source_id: StringName, _frames_written: int) -> void:
	_feedback_events.append(feedback_type)

func _on_projectile_spawned(projectile: Node) -> void:
	if projectile is Projectile:
		_spawned_projectiles.append(projectile as Projectile)

func _on_tower_fired(_target: Node, projectile: Node) -> void:
	if projectile is Projectile:
		var shot := projectile as Projectile
		_tower_shots.append(shot)
		_tower_shot_profiles.append(shot.visual_data.profile_id if shot.visual_data != null else &"")
