extends SceneTree

var failures: PackedStringArray = []
var projectile_spawn_count: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene_root := Node2D.new()
	root.add_child(scene_root)
	current_scene = scene_root

	var health_system := HealthSystem.new()
	scene_root.add_child(health_system)
	var projectile_system := ProjectileSystem.new()
	scene_root.add_child(projectile_system)
	projectile_system.projectile_spawned.connect(_on_projectile_spawned)

	var player_scene := load("res://game/player/player.tscn") as PackedScene
	var target_scene := load("res://game/debug/combat_target.tscn") as PackedScene
	_expect(player_scene != null, "player scene can be loaded")
	_expect(target_scene != null, "combat target scene can be loaded")
	if player_scene == null or target_scene == null:
		_finish()
		return

	var player := player_scene.instantiate() as PlayerController
	player.global_position = Vector2.ZERO
	scene_root.add_child(player)
	await process_frame
	await process_frame

	var weapon_system := player.get_node("WeaponSystem") as WeaponSystem
	_expect(weapon_system != null, "weapon system is available")
	if weapon_system == null:
		_finish()
		return

	var bow := load("res://game/weapons/rpg_bow.tres") as WeaponData
	var axe := load("res://game/weapons/rpg_axe.tres") as WeaponData
	var sword := load("res://game/weapons/rpg_sword.tres") as WeaponData
	_expect(bow != null and bow.uses_projectile_attack(), "bow remains projectile")
	_expect(axe != null and axe.uses_melee_attack(), "axe resolves as melee")
	_expect(sword != null and sword.uses_melee_attack(), "sword resolves as melee")
	if bow == null or axe == null or sword == null:
		_finish()
		return

	weapon_system.equip_weapon(bow)
	projectile_spawn_count = 0
	_expect(
		weapon_system.try_fire(
			player.global_position + Vector2.RIGHT * 22.0,
			Vector2.RIGHT,
			player
		),
		"bow fires"
	)
	_expect(projectile_spawn_count == 1, "bow creates a projectile")
	_clear_projectiles(scene_root)
	await process_frame

	weapon_system.cooldown = 0.0
	weapon_system.equip_weapon(axe)
	var axe_target := _spawn_target(scene_root, target_scene, Vector2(82.0, 0.0))
	var axe_health := axe_target.get_node("HealthComponent") as HealthComponent
	var axe_start_health := axe_health.current_health
	projectile_spawn_count = 0
	_expect(
		weapon_system.try_fire(
			player.global_position + Vector2.RIGHT * 22.0,
			Vector2.RIGHT,
			player
		),
		"axe swing starts"
	)
	_expect(projectile_spawn_count == 0, "axe swing does not create a projectile")
	for _frame in range(24):
		await physics_frame
	_expect(axe_health.current_health < axe_start_health, "axe melee hitbox damages target")
	axe_target.queue_free()
	await process_frame

	weapon_system.cooldown = 0.0
	weapon_system.equip_weapon(sword)
	var sword_target := _spawn_target(scene_root, target_scene, Vector2(104.0, 0.0))
	var sword_health := sword_target.get_node("HealthComponent") as HealthComponent
	var sword_start_health := sword_health.current_health
	projectile_spawn_count = 0
	_expect(
		weapon_system.try_fire(
			player.global_position + Vector2.RIGHT * 22.0,
			Vector2.RIGHT,
			player
		),
		"sword sweep starts"
	)
	_expect(projectile_spawn_count == 0, "sword sweep does not create a projectile")
	for _frame in range(16):
		await physics_frame
	_expect(
		sword_health.current_health < sword_start_health,
		"sword melee hitbox damages target"
	)

	scene_root.queue_free()
	_finish()

func _spawn_target(
	parent: Node,
	target_scene: PackedScene,
	position: Vector2
) -> CombatTarget:
	var target := target_scene.instantiate() as CombatTarget
	target.global_position = position
	parent.add_child(target)
	return target

func _clear_projectiles(parent: Node) -> void:
	for child in parent.get_children():
		if child is Projectile:
			child.queue_free()

func _on_projectile_spawned(_projectile: Node) -> void:
	projectile_spawn_count += 1

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("RPG_MELEE_ATTACK_RESOLUTION_SMOKE_TEST: PASS")
		quit(0)
		return

	print("RPG_MELEE_ATTACK_RESOLUTION_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
