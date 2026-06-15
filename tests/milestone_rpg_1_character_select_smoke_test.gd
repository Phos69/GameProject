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

	var main_menu := get_first_node_in_group("main_menu") as MainMenu
	var game_mode_manager := get_first_node_in_group(
		"game_mode_manager"
	) as GameModeManager
	var player_manager := get_first_node_in_group(
		"player_manager"
	) as PlayerManager
	_expect(main_menu != null, "main menu is available")
	_expect(game_mode_manager != null, "game mode manager is available")
	_expect(player_manager != null, "player manager is available")
	if main_menu == null or game_mode_manager == null or player_manager == null:
		_finish()
		return

	main_menu._select_mode(GameConstants.MODE_SURVIVAL)
	await process_frame
	_expect(
		main_menu.character_select_panel.visible,
		"survival opens character select before gameplay"
	)
	_expect(
		game_mode_manager.active_mode_id == GameConstants.MODE_MENU,
		"survival gameplay does not start before character confirmation"
	)

	main_menu._select_survival_character(&"ranger")
	await process_frame
	await process_frame
	_expect(
		game_mode_manager.active_mode_id == GameConstants.MODE_SURVIVAL,
		"confirming a character starts survival"
	)
	var player_one := player_manager.players.get(1) as PlayerController
	_expect(player_one != null, "player one remains spawned")
	if player_one != null:
		var rpg_component := player_one.get_node_or_null(
			"RpgPlayerComponent"
		) as RpgPlayerComponent
		_expect(rpg_component != null, "player has RPG component")
		if rpg_component != null:
			_expect(
				rpg_component.character_id == &"ranger",
				"selected character is applied to the player"
			)
			_expect(
				rpg_component.get_base_weapon_name() == "Arco",
				"selected character exposes base weapon"
			)

	_finish()

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("MILESTONE_RPG_1_CHARACTER_SELECT_SMOKE_TEST: PASS")
		quit(0)
		return

	print(
		"MILESTONE_RPG_1_CHARACTER_SELECT_SMOKE_TEST: FAIL (%d)"
		% failures.size()
	)
	quit(1)
