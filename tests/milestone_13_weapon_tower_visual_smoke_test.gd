extends SceneTree

var failures: PackedStringArray = []
var spawned_projectiles: Array[Projectile] = []
var tower_shots: Array[Projectile] = []
var tower_shot_profiles: Array[StringName] = []

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

	var local_multiplayer := get_first_node_in_group(
		"local_multiplayer_manager"
	) as LocalMultiplayerManager
	var player_manager := get_first_node_in_group(
		"player_manager"
	) as PlayerManager
	var game_mode_manager := get_first_node_in_group(
		"game_mode_manager"
	) as GameModeManager
	var projectile_system := get_first_node_in_group(
		"projectile_system"
	) as ProjectileSystem
	var tower_defense_mode := get_first_node_in_group(
		"tower_defense_mode"
	) as TowerDefenseMode
	var hud := get_first_node_in_group("hud_manager") as HUDManager
	_expect(local_multiplayer != null, "local multiplayer manager is available")
	_expect(player_manager != null, "player manager is available")
	_expect(game_mode_manager != null, "game mode manager is available")
	_expect(projectile_system != null, "projectile system is available")
	_expect(tower_defense_mode != null, "tower defense mode is available")
	_expect(hud != null, "HUD manager is available")
	if (
		local_multiplayer == null
		or player_manager == null
		or game_mode_manager == null
		or projectile_system == null
		or tower_defense_mode == null
		or hud == null
	):
		_finish()
		return

	for player_slot in range(2, 5):
		local_multiplayer.activate_slot(player_slot)
	await process_frame
	game_mode_manager.set_mode(GameConstants.MODE_SURVIVAL)
	await process_frame
	await process_frame

	var starter := load(
		"res://game/weapons/starter_pistol.tres"
	) as WeaponData
	var blaster := load(
		"res://game/weapons/prototype_blaster.tres"
	) as WeaponData
	var cannon := load(
		"res://game/weapons/wave_cannon.tres"
	) as WeaponData
	_expect(starter != null and starter.visual_data != null, "starter pistol has visual data")
	_expect(blaster != null and blaster.visual_data != null, "prototype blaster has visual data")
	_expect(cannon != null and cannon.visual_data != null, "Wave Cannon has visual data")
	if starter == null or blaster == null or cannon == null:
		_finish()
		return
	_expect(
		starter.visual_data.profile_id == &"starter_pistol",
		"starter pistol exposes its compact profile"
	)
	_expect(
		blaster.visual_data.profile_id == &"prototype_blaster",
		"prototype blaster exposes its twin-prong profile"
	)
	_expect(
		cannon.visual_data.profile_id == &"wave_cannon",
		"Wave Cannon exposes its heavy profile"
	)
	_expect(
		cannon.visual_data.weapon_length > blaster.visual_data.weapon_length
		and blaster.visual_data.weapon_length > starter.visual_data.weapon_length,
		"weapon dimensions communicate increasing power"
	)
	_expect(
		starter.visual_data.projectile_color
		!= blaster.visual_data.projectile_color
		and blaster.visual_data.projectile_color
		!= cannon.visual_data.projectile_color,
		"weapon projectiles use distinct color families"
	)

	var player_one := player_manager.players.get(1) as PlayerController
	var player_two := player_manager.players.get(2) as PlayerController
	var player_three := player_manager.players.get(3) as PlayerController
	_expect(
		player_one != null and player_two != null and player_three != null,
		"three players are available for weapon identity checks"
	)
	if player_one == null or player_two == null or player_three == null:
		_finish()
		return
	for player_slot in range(1, 5):
		var active_player := player_manager.players.get(player_slot) as PlayerController
		_expect(
			active_player != null
			and active_player.get_node_or_null("WorldHud") != null,
			"player %d has a world-space HUD package" % player_slot
		)
	var weapon_one := player_one.get_node("WeaponSystem") as WeaponSystem
	var weapon_two := player_two.get_node("WeaponSystem") as WeaponSystem
	var weapon_three := player_three.get_node("WeaponSystem") as WeaponSystem
	weapon_two.equip_weapon(blaster)
	weapon_three.equip_weapon(cannon)
	await process_frame
	await process_frame
	_expect(
		player_one.visual.get_weapon_profile_id() == &"starter_pistol",
		"player visual shows the fallback pistol"
	)
	_expect(
		player_two.visual.get_weapon_profile_id() == &"prototype_blaster",
		"player visual updates when the blaster is equipped"
	)
	_expect(
		player_three.visual.get_weapon_profile_id() == &"wave_cannon",
		"player visual updates when the Wave Cannon is equipped"
	)
	var card_one := hud.player_cards.get(1) as PlayerHudCard
	var card_two := hud.player_cards.get(2) as PlayerHudCard
	var card_three := hud.player_cards.get(3) as PlayerHudCard
	_expect(
		card_one != null
		and card_one.weapon_icon.get_profile_id() == &"starter_pistol",
		"starter pistol HUD icon matches the world weapon"
	)
	_expect(
		card_two != null
		and card_two.weapon_icon.get_profile_id() == &"prototype_blaster",
		"blaster HUD icon matches the world weapon"
	)
	_expect(
		card_three != null
		and card_three.weapon_icon.get_profile_id() == &"wave_cannon",
		"Wave Cannon HUD icon matches the world weapon"
	)

	projectile_system.projectile_spawned.connect(_on_projectile_spawned)
	player_one.global_position = Vector2(-300.0, 0.0)
	player_two.global_position = Vector2(-300.0, 100.0)
	player_three.global_position = Vector2(-300.0, 200.0)
	weapon_one.try_fire(player_one.global_position, Vector2.RIGHT, player_one)
	weapon_two.try_fire(player_two.global_position, Vector2.RIGHT, player_two)
	weapon_three.try_fire(player_three.global_position, Vector2.RIGHT, player_three)
	await process_frame
	_expect(spawned_projectiles.size() >= 3, "all three weapon projectiles spawn")
	_expect(
		_has_projectile_profile(&"starter_pistol"),
		"starter pistol projectile receives visual data"
	)
	_expect(
		_has_projectile_profile(&"prototype_blaster"),
		"blaster projectile receives visual data"
	)
	_expect(
		_has_projectile_profile(&"wave_cannon"),
		"Wave Cannon projectile receives visual data"
	)
	var cannon_projectile := _find_projectile_profile(&"wave_cannon")
	var starter_projectile := _find_projectile_profile(&"starter_pistol")
	_expect(
		cannon_projectile != null
		and starter_projectile != null
		and cannon_projectile.visual.scale.x > starter_projectile.visual.scale.x,
		"Wave Cannon projectile has a heavier silhouette"
	)
	_clear_projectiles(spawned_projectiles)

	game_mode_manager.set_mode(
		GameConstants.MODE_TOWER_DEFENSE,
		{"initial_delay": 100.0, "starting_credits": 75}
	)
	await process_frame
	await process_frame
	var tower := tower_defense_mode.try_build_at_slot(
		&"slot_b"
	) as DefenseTower
	_expect(tower != null, "tower can still be built through the shared manager")
	if tower == null:
		_finish()
		return
	_expect(
		tower.visual is DefenseTowerVisual,
		"tower uses a modular animated visual"
	)
	_expect(
		tower.visual_data.profile_id == &"defense_tower",
		"tower projectile identity is data-driven"
	)
	_expect(
		tower.visual.visual_data == tower.visual_data,
		"tower body and projectile share the same visual profile"
	)
	var target_scene := load(
		"res://game/modes/tower_defense/tower_defense_enemy.tscn"
	) as PackedScene
	var target := target_scene.instantiate() as TowerDefenseEnemy
	var path := PackedVector2Array([
		tower.global_position + Vector2(140.0, 0.0),
		tower.global_position + Vector2(300.0, 0.0)
	])
	target.configure_spawn({"path_points": path})
	main.get_node("World/Enemies").add_child(target)
	target.global_position = path[0]
	target.set_physics_process(false)
	tower.attack_range = 400.0
	tower.fire_rate = 20.0
	tower.fired.connect(_on_tower_fired)
	for _frame in range(12):
		await process_frame
	_expect(tower.target == target, "tower still acquires its gameplay target")
	_expect(
		tower.visual.tracking_target,
		"tower barrel visual follows the acquired target"
	)
	_expect(not tower_shots.is_empty(), "tower still fires through ProjectileSystem")
	if not tower_shots.is_empty():
		_expect(
			not tower_shot_profiles.is_empty()
			and tower_shot_profiles[0] == &"defense_tower",
			"tower projectile uses the cyan defense profile"
		)
		_expect(
			tower.visual.is_fire_feedback_active(),
			"tower firing produces recoil or muzzle feedback"
		)

	game_mode_manager.set_mode(GameConstants.MODE_SURVIVAL)
	await process_frame
	_finish()

func _has_projectile_profile(profile_id: StringName) -> bool:
	return _find_projectile_profile(profile_id) != null

func _find_projectile_profile(profile_id: StringName) -> Projectile:
	for projectile in spawned_projectiles:
		if (
			is_instance_valid(projectile)
			and projectile.visual_data != null
			and projectile.visual_data.profile_id == profile_id
		):
			return projectile
	return null

func _clear_projectiles(projectiles: Array[Projectile]) -> void:
	for projectile in projectiles:
		if is_instance_valid(projectile):
			projectile.queue_free()
	projectiles.clear()

func _on_projectile_spawned(projectile: Node) -> void:
	if projectile is Projectile:
		spawned_projectiles.append(projectile as Projectile)

func _on_tower_fired(_target: Node, projectile: Node) -> void:
	if projectile is Projectile:
		var shot := projectile as Projectile
		tower_shots.append(shot)
		tower_shot_profiles.append(
			shot.visual_data.profile_id if shot.visual_data != null else &""
		)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("MILESTONE_13_WEAPON_TOWER_VISUAL_SMOKE_TEST: PASS")
		quit(0)
		return
	print(
		"MILESTONE_13_WEAPON_TOWER_VISUAL_SMOKE_TEST: FAIL (%d)"
		% failures.size()
	)
	quit(1)
