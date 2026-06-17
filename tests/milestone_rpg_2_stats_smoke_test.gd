extends SceneTree

const TEST_SCENE_LIFECYCLE := preload("res://tests/test_scene_lifecycle.gd")

var failures: PackedStringArray = []
var finish_requested: bool = false

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

	var game_mode_manager := get_first_node_in_group(
		"game_mode_manager"
	) as GameModeManager
	var player_manager := get_first_node_in_group(
		"player_manager"
	) as PlayerManager
	var health_system := get_first_node_in_group(
		"health_system"
	) as HealthSystem
	_expect(game_mode_manager != null, "game mode manager is available")
	_expect(player_manager != null, "player manager is available")
	_expect(health_system != null, "health system is available")
	if game_mode_manager == null or player_manager == null or health_system == null:
		_finish()
		return

	game_mode_manager.set_mode(
		GameConstants.MODE_SURVIVAL,
		{"character_id": &"berserker"}
	)
	await process_frame
	await process_frame

	var player_one := player_manager.players.get(1) as PlayerController
	_expect(player_one != null, "player one is spawned")
	if player_one == null:
		_finish()
		return
	var rpg_component := player_one.get_node(
		"RpgPlayerComponent"
	) as RpgPlayerComponent
	var health_component := player_one.get_node(
		"HealthComponent"
	) as HealthComponent
	_expect(rpg_component.character_id == &"berserker", "berserker profile is applied")
	_expect(health_component.max_health == 125, "class max HP is applied")
	_expect(is_equal_approx(player_one.move_speed, 260.0 * 0.90), "class speed multiplier is applied")
	_expect(rpg_component.get_attack() == 12, "class attack is exposed")
	_expect(rpg_component.get_defense() == 1, "class defense is exposed")

	rpg_component.add_experience(45)
	await process_frame
	_expect(rpg_component.level == 2, "run XP levels up the character")
	_expect(rpg_component.get_max_hp() == 135, "level up increases max HP")
	_expect(rpg_component.get_attack() == 14, "level up increases attack")
	_expect(rpg_component.get_defense() == 2, "level up increases defense")
	_expect(health_component.max_health == 135, "player health max follows RPG level")

	var enemy := BasicEnemy.new()
	enemy.defense = 4
	var resolved_damage := rpg_component.resolve_outgoing_damage(
		10,
		enemy,
		Vector2.ZERO,
		&"test"
	)
	_expect(resolved_damage == 20, "outgoing formula adds attack and subtracts target defense")

	var applied_damage := health_system.apply_damage(
		player_one,
		8,
		enemy,
		&"test"
	)
	_expect(applied_damage == 6, "incoming formula subtracts player defense")
	enemy.free()

	_finish()

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if finish_requested:
		return
	finish_requested = true
	call_deferred("_finish_after_teardown")

func _finish_after_teardown() -> void:
	await TEST_SCENE_LIFECYCLE.teardown_current_scene(self, 5)
	if failures.is_empty():
		print("MILESTONE_RPG_2_STATS_SMOKE_TEST: PASS")
		quit(0)
		return

	print("MILESTONE_RPG_2_STATS_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
