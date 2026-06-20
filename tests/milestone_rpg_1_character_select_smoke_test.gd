extends SceneTree

const TEST_TIMEOUT_SECONDS: float = 120.0

var failures: PackedStringArray = []
var finished: bool = false

func _initialize() -> void:
	var timeout := create_timer(TEST_TIMEOUT_SECONDS)
	timeout.timeout.connect(_on_timeout)
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
	var local_multiplayer := get_first_node_in_group(
		"local_multiplayer_manager"
	) as LocalMultiplayerManager
	_expect(main_menu != null, "main menu is available")
	_expect(game_mode_manager != null, "game mode manager is available")
	_expect(player_manager != null, "player manager is available")
	_expect(local_multiplayer != null, "local multiplayer manager is available")
	if (
		main_menu == null
		or game_mode_manager == null
		or player_manager == null
		or local_multiplayer == null
	):
		_finish()
		return

	local_multiplayer.activate_slot(2)
	await process_frame

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
	_expect(
		main_menu.character_start_button.disabled,
		"survival start remains disabled until active slots choose characters"
	)
	_expect(
		main_menu.character_card_buttons.size() >= 4,
		"character select exposes at least four selectable cards"
	)
	if not main_menu.character_card_buttons.is_empty():
		_expect(
			main_menu.character_card_buttons[0].has_method("set_selection_state"),
			"character cards use the RPG visual card control"
		)
	_expect(
		main_menu.character_detail_panel != null,
		"character select exposes the gameplay preview detail panel"
	)
	main_menu._preview_character(&"ranger")
	await process_frame
	if main_menu.character_detail_panel != null:
		_expect(
			main_menu.character_detail_panel.current_profile.get("id", &"") == &"ranger",
			"character detail panel follows focused character data"
		)

	main_menu._assign_character_to_slot(1, &"ranger")
	main_menu._assign_character_to_slot(2, &"berserker")
	await process_frame
	_expect(
		not main_menu.character_start_button.disabled,
		"survival start enables when every active slot has a character"
	)
	_expect(
		StringName(main_menu.character_selection_by_slot.get(1, &"")) == &"ranger",
		"player one slot stores Ranger"
	)
	_expect(
		StringName(main_menu.character_selection_by_slot.get(2, &"")) == &"berserker",
		"player two slot stores Berserker"
	)
	main_menu._start_survival_with_selected_characters()
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

	var player_two := player_manager.players.get(2) as PlayerController
	_expect(player_two != null, "player two remains spawned")
	if player_two != null:
		var rpg_component_two := player_two.get_node_or_null(
			"RpgPlayerComponent"
		) as RpgPlayerComponent
		_expect(rpg_component_two != null, "player two has RPG component")
		if rpg_component_two != null:
			_expect(
				rpg_component_two.character_id == &"berserker",
				"second selected character is applied to player two"
			)
			_expect(
				rpg_component_two.get_base_weapon_name() == "Ascia",
				"second selected character exposes base weapon"
			)

	_finish()

func _on_timeout() -> void:
	if finished:
		return
	failures.append("test timed out before cleanup")
	push_error("FAIL: test timed out before cleanup")
	_finish()

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if finished:
		return
	finished = true
	if failures.is_empty():
		print("MILESTONE_RPG_1_CHARACTER_SELECT_SMOKE_TEST: PASS")
		quit(0)
		return

	print(
		"MILESTONE_RPG_1_CHARACTER_SELECT_SMOKE_TEST: FAIL (%d)"
		% failures.size()
	)
	quit(1)
