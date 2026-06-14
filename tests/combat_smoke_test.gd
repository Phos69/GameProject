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

	var local_multiplayer := get_first_node_in_group("local_multiplayer_manager") as LocalMultiplayerManager
	var player_manager := get_first_node_in_group("player_manager") as PlayerManager
	_expect(local_multiplayer != null, "local multiplayer manager is available")
	_expect(player_manager != null, "player manager is available")
	if local_multiplayer == null or player_manager == null:
		_finish()
		return

	local_multiplayer.activate_slot(2)
	await process_frame
	_expect(player_manager.get_players().size() == 2, "two local players can coexist during combat")

	var player_one := player_manager.players.get(1) as PlayerController
	var player_two := player_manager.players.get(2) as PlayerController
	var target := main.get_node_or_null("World/CombatTargets/TargetEast") as CombatTarget
	_expect(player_one != null, "player one is spawned")
	_expect(player_two != null, "player two is spawned")
	_expect(target != null, "combat target is spawned")
	if player_one == null or player_two == null or target == null:
		_finish()
		return

	var weapon_one := player_one.get_node("WeaponSystem") as WeaponSystem
	var weapon_two := player_two.get_node("WeaponSystem") as WeaponSystem
	var target_health := target.get_node("HealthComponent") as HealthComponent
	var direction := player_one.global_position.direction_to(target.global_position)
	var fired := weapon_one.try_fire(
		player_one.global_position + direction * 22.0,
		direction,
		player_one
	)
	_expect(fired, "starter pistol fires")

	for _frame in range(40):
		await physics_frame

	_expect(target_health.current_health == 30, "projectile collision applies 10 damage")
	_expect(weapon_one.current_ammo == 11, "firing consumes player one ammunition")
	_expect(weapon_two.current_ammo == 12, "player two ammunition remains independent")

	weapon_one.current_ammo = 0
	weapon_one.reserve_ammo = 36
	_expect(weapon_one.start_reload(), "reload starts with an empty magazine")
	for _frame in range(70):
		await physics_frame
	_expect(weapon_one.current_ammo == 12, "reload fills the magazine")
	_expect(weapon_one.reserve_ammo == 24, "reload consumes reserve ammunition")

	_finish()

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("COMBAT_SMOKE_TEST: PASS")
		quit(0)
		return

	print("COMBAT_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
