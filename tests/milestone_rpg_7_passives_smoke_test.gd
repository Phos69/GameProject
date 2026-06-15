extends SceneTree

var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var player_scene := load("res://game/player/player.tscn") as PackedScene
	_expect(player_scene != null, "player scene can be loaded")
	if player_scene == null:
		_finish()
		return

	var player := player_scene.instantiate() as PlayerController
	root.add_child(player)
	await process_frame
	await process_frame

	var rpg_component := player.get_node(
		"RpgPlayerComponent"
	) as RpgPlayerComponent
	var health_component := player.get_node(
		"HealthComponent"
	) as HealthComponent
	var weapon_system := player.get_node("WeaponSystem") as WeaponSystem
	_expect(rpg_component != null, "rpg component is available")
	_expect(health_component != null, "health component is available")
	_expect(weapon_system != null, "weapon system is available")
	if rpg_component == null or health_component == null or weapon_system == null:
		_finish()
		return

	var target := BasicEnemy.new()
	target.defense = 0
	player.global_position = Vector2.ZERO
	target.global_position = Vector2(650.0, 0.0)

	player.apply_rpg_character(&"ranger")
	var ranger_base_damage := 10 + rpg_component.get_attack()
	var ranger_damage := rpg_component.resolve_outgoing_damage(
		10,
		target,
		target.global_position,
		&"test"
	)
	_expect(ranger_damage > ranger_base_damage, "ranger gains distance damage")
	_expect(
		rpg_component.get_active_passive_text().begins_with("OCCHIO"),
		"ranger passive is visible after a distant hit"
	)

	player.apply_rpg_character(&"berserker")
	health_component.current_health = roundi(
		float(health_component.max_health) * 0.35
	)
	var berserker_base_damage := 10 + rpg_component.get_attack()
	var berserker_damage := rpg_component.resolve_outgoing_damage(
		10,
		target,
		target.global_position,
		&"test"
	)
	_expect(berserker_damage > berserker_base_damage, "berserker gains low HP damage")
	_expect(
		rpg_component.get_active_passive_text() == "FURIA +25%",
		"berserker passive is visible below threshold"
	)

	player.apply_rpg_character(&"pistoliere")
	rpg_component.notify_reload_finished()
	_expect(
		is_equal_approx(rpg_component.get_fire_rate_multiplier(), 1.20),
		"pistoliere reload grants fire rate"
	)
	_expect(
		is_equal_approx(weapon_system._get_modified_fire_rate_multiplier(), 1.20),
		"weapon system reads quick hand fire rate"
	)
	_expect(
		rpg_component.get_active_passive_text() == "MANO VELOCE +20%",
		"pistoliere passive is visible after reload"
	)

	player.apply_rpg_character(&"spadaccino")
	var guard_target := BasicEnemy.new()
	guard_target.defense = 0
	var guard_health := HealthComponent.new()
	guard_health.name = "HealthComponent"
	guard_target.add_child(guard_health)
	rpg_component.resolve_outgoing_damage(10, guard_target, Vector2.ZERO, &"test")
	var guarded_damage := rpg_component.resolve_incoming_damage(
		20,
		guard_target
	)
	_expect(guarded_damage == 11, "spadaccino guard reduces incoming damage")
	_expect(
		rpg_component.get_active_passive_text() == "GUARDIA -20%",
		"spadaccino passive is visible after a hit"
	)

	guard_target.free()
	target.free()
	player.queue_free()
	_finish()

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("MILESTONE_RPG_7_PASSIVES_SMOKE_TEST: PASS")
		quit(0)
		return

	print("MILESTONE_RPG_7_PASSIVES_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
