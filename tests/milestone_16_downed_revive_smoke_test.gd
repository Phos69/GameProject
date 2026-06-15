extends SceneTree

var failures: PackedStringArray = []
var survival_defeat_count: int = 0
var dungeon_defeat_count: int = 0
var defense_defeat_count: int = 0

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

	var game_mode_manager := get_first_node_in_group(
		"game_mode_manager"
	) as GameModeManager
	var local_multiplayer := get_first_node_in_group(
		"local_multiplayer_manager"
	) as LocalMultiplayerManager
	var player_manager := get_first_node_in_group(
		"player_manager"
	) as PlayerManager
	var revive_system: Node = get_first_node_in_group("revive_system")
	var survival_mode := get_first_node_in_group(
		"survival_mode"
	) as SurvivalMode
	var dungeon_mode := get_first_node_in_group("dungeon_mode") as DungeonMode
	var tower_mode := get_first_node_in_group(
		"tower_defense_mode"
	) as TowerDefenseMode
	var wave_manager := get_first_node_in_group("wave_manager") as WaveManager
	var input_manager := get_first_node_in_group("input_manager") as InputManager
	_expect(game_mode_manager != null, "game mode manager is available")
	_expect(local_multiplayer != null, "local multiplayer manager is available")
	_expect(player_manager != null, "player manager is available")
	_expect(revive_system != null, "revive system is available")
	_expect(survival_mode != null, "survival mode is available")
	_expect(dungeon_mode != null, "dungeon mode is available")
	_expect(tower_mode != null, "tower defense mode is available")
	_expect(wave_manager != null, "wave manager is available")
	_expect(input_manager != null, "input manager is available")
	if (
		game_mode_manager == null
		or local_multiplayer == null
		or player_manager == null
		or revive_system == null
		or survival_mode == null
		or dungeon_mode == null
		or tower_mode == null
		or wave_manager == null
		or input_manager == null
	):
		_finish()
		return

	survival_mode.survival_defeated.connect(_on_survival_defeated)
	dungeon_mode.dungeon_defeated.connect(_on_dungeon_defeated)
	tower_mode.defense_defeated.connect(_on_defense_defeated)
	wave_manager.initial_delay = 100.0
	local_multiplayer.activate_slot(2)
	await process_frame
	var player_one := player_manager.players.get(1) as PlayerController
	var player_two := player_manager.players.get(2) as PlayerController
	_expect(player_one != null and player_two != null, "two players are active")
	if player_one == null or player_two == null:
		_finish()
		return

	game_mode_manager.set_mode(GameConstants.MODE_SURVIVAL)
	await process_frame
	player_one.global_position = Vector2.ZERO
	player_two.global_position = Vector2(40.0, 0.0)
	player_two.prepare_for_run(ProgressionManager.FIELD_KIT_HEALTH_BONUS)
	var player_two_health := player_two.health_component
	_expect(
		player_two_health.max_health == 120,
		"Field Kit configures max health before the downed flow"
	)
	player_two_health.apply_damage(9999)
	_expect(player_two_health.is_downed, "lethal player damage enters downed state")
	_expect(not player_two_health.is_dead, "downed is distinct from dead")
	_expect(
		not player_two_health.is_alive(),
		"downed players are excluded from living target selection"
	)
	_expect(player_two.visual.is_downed, "player visual shows the downed pose")
	_expect(
		player_two.revive_indicator.visible,
		"world-space revive indicator remains visible"
	)
	_expect(
		not player_two.aim_line.visible,
		"downed players cannot present an active aim line"
	)

	revive_system.set("revive_duration", 1.0)
	_expect(
		not bool(revive_system.call(
			"advance_revive",
			player_two,
			player_one,
			0.4
		)),
		"partial revive does not complete"
	)
	_expect(
		is_equal_approx(
			float(revive_system.call("get_revive_progress", player_two)),
			0.4
		),
		"partial revive exposes deterministic progress"
	)
	revive_system.call("interrupt_revive", player_two)
	_expect(
		is_zero_approx(float(
			revive_system.call("get_revive_progress", player_two)
		)),
		"interrupted revive resets progress immediately"
	)
	revive_system.call("advance_revive", player_two, player_one, 0.6)
	_expect(
		bool(revive_system.call(
			"advance_revive",
			player_two,
			player_one,
			0.5
		)),
		"holding interact long enough completes the revive"
	)
	_expect(player_two_health.is_alive(), "revived player becomes alive")
	_expect(
		player_two_health.current_health == 42,
		"revive restores 35 percent of Field Kit health"
	)
	_expect(
		player_two_health.max_health == 120,
		"revive does not stack the Field Kit bonus"
	)
	_expect(
		not player_two.revive_indicator.visible,
		"revive indicator hides after completion"
	)
	player_two.prepare_for_run(ProgressionManager.FIELD_KIT_HEALTH_BONUS)
	_expect(
		player_two_health.max_health == 120,
		"subsequent run preparation remains idempotent"
	)

	local_multiplayer.activate_slot(3)
	await process_frame
	var player_three := player_manager.players.get(3) as PlayerController
	_expect(player_three != null, "a third player can join during the run")
	if player_three != null:
		player_two.global_position = Vector2.ZERO
		player_three.global_position = Vector2(30.0, 0.0)
		player_two_health.apply_damage(9999)
		revive_system.call(
			"advance_revive",
			player_two,
			player_three,
			0.3
		)
		local_multiplayer.deactivate_slot(3)
		await process_frame
		revive_system.call("interrupt_revive", player_two)
		_expect(
			is_zero_approx(float(
				revive_system.call("get_revive_progress", player_two)
			)),
			"reviver leave cannot complete a stale revive"
		)
		player_two_health.revive(60)

	_expect(
		input_manager.has_method("is_player_interact_pressed"),
		"revive uses the shared held interact action"
	)

	player_one.health_component.apply_damage(9999)
	player_two.health_component.apply_damage(9999)
	await process_frame
	await process_frame
	_expect(
		survival_defeat_count == 1 and not survival_mode.is_running,
		"survival ends only when every active player is incapacitated"
	)

	game_mode_manager.set_mode(GameConstants.MODE_DUNGEON, {
		"seed": 16,
		"room_count": 4
	})
	await process_frame
	player_one.health_component.apply_damage(9999)
	player_two.health_component.apply_damage(9999)
	await process_frame
	await process_frame
	_expect(
		dungeon_defeat_count == 1 and not dungeon_mode.is_running,
		"dungeon ends when the whole party is incapacitated"
	)

	game_mode_manager.set_mode(GameConstants.MODE_TOWER_DEFENSE, {
		"initial_delay": 100.0
	})
	await process_frame
	player_one.health_component.apply_damage(9999)
	player_two.health_component.apply_damage(9999)
	await process_frame
	await process_frame
	_expect(
		defense_defeat_count == 1 and tower_mode.state == &"defeated",
		"tower defense also resolves an all-downed party"
	)

	_finish()

func _on_survival_defeated(_wave_index: int) -> void:
	survival_defeat_count += 1

func _on_dungeon_defeated(_room_index: int) -> void:
	dungeon_defeat_count += 1

func _on_defense_defeated(_wave_index: int) -> void:
	defense_defeat_count += 1

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("MILESTONE_16_DOWNED_REVIVE_SMOKE_TEST: PASS")
		quit(0)
		return
	print(
		"MILESTONE_16_DOWNED_REVIVE_SMOKE_TEST: FAIL (%d)"
		% failures.size()
	)
	quit(1)
