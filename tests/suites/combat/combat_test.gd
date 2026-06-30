extends GutTest
## Combat A5 — Risoluzione del combattimento: fuoco, danno, ammo/reload, equip,
## melee e contratti di hitbox.
##
## Migra e accorpa:
##   tests/combat_smoke_test.gd  (boota main.tscn per i CombatTargets del World)
##   tests/rpg_melee_attack_resolution_smoke_test.gd  (scena sintetica)
##   tests/milestone_rpg_4_hitbox_smoke_test.gd  (dati arma + proiettile)

const MainSceneFixture = preload("res://tests/support/main_scene_fixture.gd")

var _feedback_events: Array[StringName] = []
var _projectile_spawn_count: int = 0
var _last_melee_attack: Node

# --- combat su main.tscn: fuoco, danno, ammo, reload, equip -----------------

func test_combat_targets_and_ammo() -> void:
	_feedback_events = []
	var scene := MainSceneFixture.new()
	assert_true(scene.boot(self), "main scene can be loaded")
	await wait_physics_frames(2)

	var local_multiplayer := scene.node(&"local_multiplayer_manager") as LocalMultiplayerManager
	var player_manager := scene.node(&"player_manager") as PlayerManager
	var audio_manager := scene.node(&"audio_manager") as AudioManager
	assert_not_null(local_multiplayer, "local multiplayer manager is available")
	assert_not_null(player_manager, "player manager is available")
	assert_not_null(audio_manager, "audio manager is available")
	if local_multiplayer == null or player_manager == null or audio_manager == null:
		scene.teardown()
		return
	audio_manager.gameplay_feedback_generated.connect(_on_gameplay_feedback_generated)

	local_multiplayer.activate_slot(2)
	await wait_physics_frames(1)
	assert_eq(player_manager.get_players().size(), 2, "two local players can coexist during combat")

	var player_one := player_manager.players.get(1) as PlayerController
	var player_two := player_manager.players.get(2) as PlayerController
	var target := scene.main.get_node_or_null("World/CombatTargets/TargetEast") as CombatTarget
	assert_not_null(player_one, "player one is spawned")
	assert_not_null(player_two, "player two is spawned")
	assert_not_null(target, "combat target is spawned")
	if player_one == null or player_two == null or target == null:
		_teardown_combat(audio_manager, local_multiplayer, scene)
		return

	var weapon_one := player_one.get_node("WeaponSystem") as WeaponSystem
	var weapon_two := player_two.get_node("WeaponSystem") as WeaponSystem
	var target_health := target.get_node("HealthComponent") as HealthComponent
	target.collision_layer = 2
	var direction := player_one.global_position.direction_to(target.global_position)
	assert_true(weapon_one.try_fire(player_one.global_position + direction * 22.0, direction, player_one), "starter pistol fires")
	for _frame in range(40):
		await wait_physics_frames(1)

	assert_eq(target_health.current_health, 30, "projectile collision applies 10 damage")
	assert_true(_feedback_events.has(&"shot"), "projectile spawn emits gameplay shot audio")
	assert_true(_feedback_events.has(&"impact"), "successful projectile damage emits gameplay impact audio")
	assert_eq(weapon_one.current_ammo, 11, "firing consumes player one ammunition")
	assert_eq(weapon_two.current_ammo, 12, "player two ammunition remains independent")

	weapon_one.current_ammo = 0
	weapon_one.reserve_ammo = 0
	assert_true(weapon_one.start_reload(), "infinite-reserve weapon reload starts with an empty magazine")
	assert_true("RELOAD" in weapon_one.get_ammo_text(), "HUD ammo text exposes reload state")
	assert_true(_feedback_events.has(&"reload"), "reload starts with gameplay feedback")
	for _frame in range(70):
		await wait_physics_frames(1)
	assert_eq(weapon_one.current_ammo, 12, "infinite reserve reload fills the magazine")
	assert_eq(weapon_one.reserve_ammo, 0, "infinite reserve reload consumes no reserve")

	var blaster := load("res://game/weapons/prototype_blaster.tres") as WeaponData
	assert_true(weapon_one.equip_weapon(blaster), "a finite special weapon can be equipped")
	weapon_one.current_ammo = 1
	weapon_one.reserve_ammo = 0
	assert_true(weapon_one.try_fire(player_one.global_position, Vector2.RIGHT, player_one), "the last special round can be fired")
	assert_true("LOW" in weapon_one.get_ammo_text(), "HUD ammo text exposes low special ammo")
	assert_true(_feedback_events.has(&"low_ammo"), "low special ammo emits gameplay feedback")
	weapon_one.cooldown = 0.0
	assert_false(weapon_one.try_fire_equipped(player_one.global_position, Vector2.RIGHT, player_one), "empty equipped weapon does not redirect its attack to the base weapon")
	assert_eq(weapon_one.weapon_data.weapon_id, &"prototype_blaster", "empty equipped weapon remains selected")
	var base_ammo_before := weapon_one.fallback_current_ammo
	assert_true(weapon_one.try_fire_base(player_one.global_position, Vector2.RIGHT, player_one), "base weapon remains independently available")
	assert_eq(weapon_one.fallback_current_ammo, base_ammo_before - 1, "base attack consumes only the base magazine")
	assert_eq(weapon_one.weapon_data.weapon_id, &"prototype_blaster", "base attack does not change the equipped weapon")
	assert_eq(weapon_one.add_reserve_ammo(5), 5, "equipped weapon ammo can be restored while its magazine is empty")
	assert_true(weapon_one.weapon_data.weapon_id == &"prototype_blaster" and weapon_one.is_reloading, "restored ammo reloads the equipped weapon without switching slots")

	_teardown_combat(audio_manager, local_multiplayer, scene)

func _teardown_combat(audio_manager: AudioManager, local_multiplayer: LocalMultiplayerManager, scene: MainSceneFixture) -> void:
	if audio_manager != null and audio_manager.gameplay_feedback_generated.is_connected(_on_gameplay_feedback_generated):
		audio_manager.gameplay_feedback_generated.disconnect(_on_gameplay_feedback_generated)
	if local_multiplayer != null:
		local_multiplayer.deactivate_slot(2)
	scene.teardown()
	await wait_physics_frames(1)

# --- risoluzione melee vs proiettile (scena sintetica) ----------------------

func test_melee_attack_resolution() -> void:
	_projectile_spawn_count = 0
	_last_melee_attack = null
	var scene_root := Node2D.new()
	add_child(scene_root)
	var health_system := HealthSystem.new()
	scene_root.add_child(health_system)
	var projectile_system := ProjectileSystem.new()
	scene_root.add_child(projectile_system)
	projectile_system.projectile_spawned.connect(_on_projectile_spawned)

	var player_scene := load("res://game/player/player.tscn") as PackedScene
	var target_scene := load("res://game/debug/combat_target.tscn") as PackedScene
	assert_not_null(player_scene, "player scene can be loaded")
	assert_not_null(target_scene, "combat target scene can be loaded")
	if player_scene == null or target_scene == null:
		scene_root.queue_free()
		return

	var player := player_scene.instantiate() as PlayerController
	player.global_position = Vector2.ZERO
	scene_root.add_child(player)
	await wait_physics_frames(2)
	var weapon_system := player.get_node("WeaponSystem") as WeaponSystem
	assert_not_null(weapon_system, "weapon system is available")
	if weapon_system == null:
		scene_root.queue_free()
		return
	weapon_system.melee_attack_started.connect(_on_melee_attack_started)

	var bow := load("res://game/weapons/rpg_bow.tres") as WeaponData
	var pistol := load("res://game/weapons/rpg_pistol.tres") as WeaponData
	var axe := load("res://game/weapons/rpg_axe.tres") as WeaponData
	var sword := load("res://game/weapons/rpg_sword.tres") as WeaponData
	var claws := load("res://game/weapons/rpg_claws.tres") as WeaponData
	assert_true(bow != null and bow.uses_projectile_attack(), "bow remains projectile")
	assert_true(pistol != null and pistol.uses_projectile_attack(), "pistol remains projectile")
	assert_true(axe != null and axe.uses_melee_attack(), "axe resolves as melee")
	assert_true(sword != null and sword.uses_melee_attack(), "sword resolves as melee")
	assert_true(claws != null and claws.uses_melee_attack(), "claws resolve as melee")
	if bow == null or pistol == null or axe == null or sword == null or claws == null:
		scene_root.queue_free()
		return
	assert_true(axe.damage > sword.damage and axe.knockback > sword.knockback, "axe keeps heavier damage and knockback than sword")
	assert_true(axe.windup_time + axe.recovery_time > sword.windup_time + sword.recovery_time, "axe keeps a larger commitment window than sword")
	assert_gt(axe.hitstop, sword.hitstop, "axe hitstop is heavier than sword")
	assert_true(sword.melee_range > axe.melee_range and sword.recovery_time < axe.recovery_time, "sword keeps safer range and faster recovery than axe")
	assert_true(bow.max_range > pistol.max_range and bow.scatter_degrees < pistol.scatter_degrees, "bow and pistol keep distinct ranged readability")

	weapon_system.equip_weapon(bow)
	_projectile_spawn_count = 0
	assert_true(weapon_system.try_fire(player.global_position + Vector2.RIGHT * 22.0, Vector2.RIGHT, player), "bow fires")
	assert_eq(_projectile_spawn_count, 1, "bow creates a projectile")
	_clear_projectiles(scene_root)
	await wait_physics_frames(1)

	await _assert_melee_damages(scene_root, target_scene, weapon_system, player, axe, Vector2(82.0, 0.0), 24, "axe")
	await _assert_melee_damages(scene_root, target_scene, weapon_system, player, sword, Vector2(104.0, 0.0), 16, "sword")

	scene_root.queue_free()
	await wait_physics_frames(1)

func _assert_melee_damages(scene_root: Node, target_scene: PackedScene, weapon_system: WeaponSystem,
		player: PlayerController, weapon: WeaponData, position: Vector2, frames: int, label: String) -> void:
	weapon_system.cooldown = 0.0
	weapon_system.equip_weapon(weapon)
	_last_melee_attack = null
	var target := target_scene.instantiate() as CombatTarget
	target.global_position = position
	scene_root.add_child(target)
	var health := target.get_node("HealthComponent") as HealthComponent
	var start_health := health.current_health
	_projectile_spawn_count = 0
	assert_true(weapon_system.try_fire(player.global_position + Vector2.RIGHT * 22.0, Vector2.RIGHT, player), "%s swing starts" % label)
	assert_eq(_projectile_spawn_count, 0, "%s swing does not create a projectile" % label)
	assert_not_null(_last_melee_attack, "%s creates a melee attack node" % label)
	if _last_melee_attack != null:
		assert_true(is_equal_approx(float(_last_melee_attack.get("hitstop_time")), weapon.hitstop), "%s passes hitstop value to melee runtime" % label)
	for _frame in range(frames):
		await wait_physics_frames(1)
	assert_lt(health.current_health, start_health, "%s melee hitbox damages target" % label)
	target.queue_free()
	await wait_physics_frames(1)

# --- contratti di hitbox e proiettile arc -----------------------------------

func test_weapon_hitbox_contracts() -> void:
	_assert_weapon_hitbox("res://game/weapons/rpg_pistol.tres", &"circle", Vector2(8.0, 8.0), 1)
	_assert_weapon_hitbox("res://game/weapons/rpg_bow.tres", &"capsule", Vector2(10.0, 28.0), 1)
	_assert_weapon_hitbox("res://game/weapons/rpg_axe.tres", &"arc", Vector2(90.0, 70.0), 4)
	_assert_weapon_hitbox("res://game/weapons/rpg_sword.tres", &"rectangle", Vector2(110.0, 45.0), 3)

	var projectile_scene := load("res://game/projectiles/projectile.tscn") as PackedScene
	assert_not_null(projectile_scene, "projectile scene can be loaded")
	if projectile_scene == null:
		return
	var projectile := projectile_scene.instantiate() as Projectile
	add_child(projectile)
	projectile.launch(Vector2.RIGHT, 1.0, null, 1, &"test_arc", null, 80.0, &"arc", Vector2(90.0, 70.0), 4)
	await wait_physics_frames(1)
	var collision_shape := projectile.get_node("CollisionShape2D") as CollisionShape2D
	assert_true(collision_shape.shape is ConvexPolygonShape2D, "arc hitbox creates a convex polygon shape")
	assert_eq(projectile.max_hit_count, 4, "projectile keeps configured multi-hit count")
	projectile.queue_free()
	await wait_physics_frames(1)

func _assert_weapon_hitbox(path: String, expected_type: StringName, expected_size: Vector2, expected_hits: int) -> void:
	var weapon := load(path) as WeaponData
	assert_not_null(weapon, "%s can be loaded" % path)
	if weapon == null:
		return
	assert_eq(weapon.hitbox_type, expected_type, "%s hitbox type matches" % weapon.display_name)
	assert_eq(weapon.hitbox_size, expected_size, "%s hitbox size matches" % weapon.display_name)
	assert_eq(weapon.max_hit_count, expected_hits, "%s hit count matches" % weapon.display_name)
	if expected_type == &"arc" or expected_type == &"rectangle":
		assert_true(weapon.uses_melee_attack(), "%s resolves through melee attack runtime" % weapon.display_name)
		assert_null(weapon.projectile_scene, "%s no longer carries a projectile scene" % weapon.display_name)
	else:
		assert_true(weapon.uses_projectile_attack(), "%s resolves through projectile runtime" % weapon.display_name)

# --- signal handler / helper ------------------------------------------------

func _on_gameplay_feedback_generated(feedback_type: StringName, _source_id: StringName, _frames_written: int) -> void:
	_feedback_events.append(feedback_type)

func _on_projectile_spawned(_projectile: Node) -> void:
	_projectile_spawn_count += 1

func _on_melee_attack_started(attack: Node, _weapon_data: WeaponData) -> void:
	_last_melee_attack = attack

func _clear_projectiles(parent: Node) -> void:
	for child in parent.get_children():
		if child is Projectile:
			child.queue_free()
