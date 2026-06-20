extends SceneTree

var failures: PackedStringArray = []
var gameplay_feedback_events: Array[StringName] = []

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
	var audio_manager := get_first_node_in_group("audio_manager") as AudioManager
	_expect(local_multiplayer != null, "local multiplayer manager is available")
	_expect(player_manager != null, "player manager is available")
	_expect(audio_manager != null, "audio manager is available")
	if local_multiplayer == null or player_manager == null or audio_manager == null:
		_finish()
		return
	audio_manager.gameplay_feedback_generated.connect(
		_on_gameplay_feedback_generated
	)

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
	target.collision_layer = 2
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
	_expect(
		gameplay_feedback_events.has(&"shot"),
		"projectile spawn emits gameplay shot audio"
	)
	_expect(
		gameplay_feedback_events.has(&"impact"),
		"successful projectile damage emits gameplay impact audio"
	)
	_expect(weapon_one.current_ammo == 11, "firing consumes player one ammunition")
	_expect(weapon_two.current_ammo == 12, "player two ammunition remains independent")

	weapon_one.current_ammo = 0
	weapon_one.reserve_ammo = 0
	_expect(
		weapon_one.start_reload(),
		"infinite-reserve weapon reload starts with an empty magazine"
	)
	_expect("RELOAD" in weapon_one.get_ammo_text(), "HUD ammo text exposes reload state")
	_expect(
		gameplay_feedback_events.has(&"reload"),
		"reload starts with gameplay feedback"
	)
	for _frame in range(70):
		await physics_frame
	_expect(weapon_one.current_ammo == 12, "infinite reserve reload fills the magazine")
	_expect(weapon_one.reserve_ammo == 0, "infinite reserve reload consumes no reserve")

	var blaster := load("res://game/weapons/prototype_blaster.tres") as WeaponData
	_expect(weapon_one.equip_weapon(blaster), "a finite special weapon can be equipped")
	weapon_one.current_ammo = 1
	weapon_one.reserve_ammo = 0
	_expect(
		weapon_one.try_fire(player_one.global_position, Vector2.RIGHT, player_one),
		"the last special round can be fired"
	)
	_expect("LOW" in weapon_one.get_ammo_text(), "HUD ammo text exposes low special ammo")
	_expect(
		gameplay_feedback_events.has(&"low_ammo"),
		"low special ammo emits gameplay feedback"
	)
	weapon_one.cooldown = 0.0
	_expect(
		not weapon_one.try_fire_equipped(
			player_one.global_position,
			Vector2.RIGHT,
			player_one
		),
		"empty equipped weapon does not redirect its attack to the base weapon"
	)
	_expect(
		weapon_one.weapon_data.weapon_id == &"prototype_blaster",
		"empty equipped weapon remains selected"
	)
	var base_ammo_before := weapon_one.fallback_current_ammo
	_expect(
		weapon_one.try_fire_base(
			player_one.global_position,
			Vector2.RIGHT,
			player_one
		),
		"base weapon remains independently available"
	)
	_expect(
		weapon_one.fallback_current_ammo == base_ammo_before - 1,
		"base attack consumes only the base magazine"
	)
	_expect(
		weapon_one.weapon_data.weapon_id == &"prototype_blaster",
		"base attack does not change the equipped weapon"
	)
	_expect(
		weapon_one.add_reserve_ammo(5) == 5,
		"equipped weapon ammo can be restored while its magazine is empty"
	)
	_expect(
		weapon_one.weapon_data.weapon_id == &"prototype_blaster"
		and weapon_one.is_reloading,
		"restored ammo reloads the equipped weapon without switching slots"
	)

	_finish()

func _on_gameplay_feedback_generated(
	feedback_type: StringName,
	_source_id: StringName,
	_frames_written: int
) -> void:
	gameplay_feedback_events.append(feedback_type)

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
