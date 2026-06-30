extends GutTest
## Progression A7 — Selezione personaggio: flusso survival, multi-modalità, UI,
## selezione indipendente per-player.
##
## Migra e accorpa:
##   tests/milestone_rpg_1_character_select_smoke_test.gd  (main.tscn)
##   tests/all_modes_character_system_smoke_test.gd        (main.tscn)
##   tests/character_select_ui_smoke_test.gd               (MainMenu standalone)
##   tests/character_select_independent_smoke_test.gd      (MainMenu standalone)

const MainSceneFixture = preload("res://tests/support/main_scene_fixture.gd")

# --- flusso survival: scelta -> conferma -> applicazione (milestone_rpg_1) ---

func test_character_select_flow() -> void:
	var scene := MainSceneFixture.new()
	assert_true(scene.boot(self), "main scene can be loaded")
	await wait_physics_frames(2)
	var main_menu := scene.node(&"main_menu") as MainMenu
	var game_mode_manager := scene.node(&"game_mode_manager") as GameModeManager
	var player_manager := scene.node(&"player_manager") as PlayerManager
	var local_multiplayer := scene.node(&"local_multiplayer_manager") as LocalMultiplayerManager
	if main_menu == null or game_mode_manager == null or player_manager == null or local_multiplayer == null:
		assert_true(false, "character select systems are available")
		scene.teardown()
		return

	local_multiplayer.activate_slot(2)
	await wait_physics_frames(1)
	main_menu._select_mode(GameConstants.MODE_SURVIVAL)
	await wait_physics_frames(1)
	assert_true(main_menu.character_select_panel.visible, "survival opens character select before gameplay")
	assert_eq(game_mode_manager.active_mode_id, GameConstants.MODE_MENU, "survival gameplay does not start before character confirmation")
	assert_true(main_menu.character_start_button.disabled, "survival start remains disabled until active slots choose characters")
	assert_gte(main_menu.character_card_buttons.size(), 4, "character select exposes at least four selectable cards")
	if not main_menu.character_card_buttons.is_empty():
		assert_true(main_menu.character_card_buttons[0].has_method("set_selection_state"), "character cards use the RPG visual card control")
	assert_true(main_menu.character_slot_views.get(1, {}).get("preview") != null and main_menu.character_slot_views.get(2, {}).get("preview") != null, "each active slot embeds its own gameplay preview")
	main_menu._preview_character(&"ranger")
	await wait_physics_frames(1)
	if main_menu.character_detail_panel != null:
		assert_eq(main_menu.character_detail_panel.current_profile.get("id", &""), &"ranger", "character detail panel follows focused character data")

	main_menu._assign_character_to_slot(1, &"ranger")
	main_menu._assign_character_to_slot(2, &"berserker")
	await wait_physics_frames(1)
	assert_false(main_menu.character_start_button.disabled, "survival start enables when every active slot has a character")
	assert_eq(StringName(main_menu.character_selection_by_slot.get(1, &"")), &"ranger", "player one slot stores Ranger")
	assert_eq(StringName(main_menu.character_selection_by_slot.get(2, &"")), &"berserker", "player two slot stores Berserker")
	main_menu._start_selected_mode_with_characters()
	await wait_physics_frames(2)
	assert_eq(game_mode_manager.active_mode_id, GameConstants.MODE_SURVIVAL, "confirming a character starts survival")

	var player_one := player_manager.players.get(1) as PlayerController
	assert_not_null(player_one, "player one remains spawned")
	if player_one != null:
		var rpg_one := player_one.get_node_or_null("RpgPlayerComponent") as RpgPlayerComponent
		assert_not_null(rpg_one, "player has RPG component")
		if rpg_one != null:
			assert_eq(rpg_one.character_id, &"ranger", "selected character is applied to the player")
			assert_eq(rpg_one.get_base_weapon_name(), "Arco", "selected character exposes base weapon")
	var player_two := player_manager.players.get(2) as PlayerController
	assert_not_null(player_two, "player two remains spawned")
	if player_two != null:
		var rpg_two := player_two.get_node_or_null("RpgPlayerComponent") as RpgPlayerComponent
		assert_not_null(rpg_two, "player two has RPG component")
		if rpg_two != null:
			assert_eq(rpg_two.character_id, &"berserker", "second selected character is applied to player two")
			assert_eq(rpg_two.get_base_weapon_name(), "Ascia", "second selected character exposes base weapon")

	local_multiplayer.deactivate_slot(2)
	scene.teardown()
	await wait_physics_frames(1)

# --- il personaggio è condiviso da tutte le modalità (all_modes_character) ---

func test_all_modes_apply_character() -> void:
	var scene := MainSceneFixture.new()
	assert_true(scene.boot(self), "main scene can be loaded")
	await wait_physics_frames(2)
	await wait_physics_frames(1)
	var game_mode_manager := scene.node(&"game_mode_manager") as GameModeManager
	var player_manager := scene.node(&"player_manager") as PlayerManager
	if game_mode_manager == null or player_manager == null:
		assert_true(false, "mode/player systems are available")
		scene.teardown()
		return

	await _verify_mode_applies_character(game_mode_manager, player_manager, GameConstants.MODE_DUNGEON, &"berserker", {"character_id": &"berserker", "seed": 4242, "room_count": 6})
	await _verify_mode_applies_character(game_mode_manager, player_manager, GameConstants.MODE_TOWER_DEFENSE, &"mago", {"character_id": &"mago", "initial_delay": 0.0, "starting_credits": 75})
	await _verify_mode_clears_character(game_mode_manager, player_manager, GameConstants.MODE_DUNGEON, {"seed": 4242, "room_count": 6})

	game_mode_manager.set_mode(GameConstants.MODE_MENU)
	await wait_physics_frames(1)
	scene.teardown()
	await wait_physics_frames(1)

func _verify_mode_applies_character(game_mode_manager: GameModeManager, player_manager: PlayerManager, mode_id: StringName, character_id: StringName, context: Dictionary) -> void:
	assert_true(game_mode_manager.set_mode(mode_id, context), "%s starts from a character context" % String(mode_id))
	await wait_physics_frames(1)
	await wait_physics_frames(1)
	var rpg := _player_rpg_component(player_manager)
	assert_not_null(rpg, "%s keeps player one with an RPG component" % String(mode_id))
	if rpg == null:
		return
	assert_true(rpg.has_character(), "%s applies a character to the player" % String(mode_id))
	assert_eq(rpg.character_id, character_id, "%s applies the selected character (%s)" % [String(mode_id), String(character_id)])

func _verify_mode_clears_character(game_mode_manager: GameModeManager, player_manager: PlayerManager, mode_id: StringName, context: Dictionary) -> void:
	assert_true(game_mode_manager.set_mode(mode_id, context), "%s restarts without a character context" % String(mode_id))
	await wait_physics_frames(1)
	await wait_physics_frames(1)
	var rpg := _player_rpg_component(player_manager)
	assert_not_null(rpg, "%s keeps player one with an RPG component" % String(mode_id))
	if rpg == null:
		return
	assert_false(rpg.has_character(), "%s without a roster falls back to the generic survivor" % String(mode_id))

func _player_rpg_component(player_manager: PlayerManager) -> RpgPlayerComponent:
	var player_one := player_manager.players.get(1) as PlayerController
	if player_one == null:
		return null
	return player_one.get_node_or_null("RpgPlayerComponent") as RpgPlayerComponent

# --- UI: safe-area multi-risoluzione, navigazione, detail panel (ui) ---------

func test_character_select_ui() -> void:
	var root := get_tree().root
	var main_menu := MainMenu.new()
	add_child(main_menu)
	await wait_physics_frames(2)

	main_menu._open_character_select()
	await wait_physics_frames(1)
	assert_true(main_menu.character_select_panel.visible, "character select opens from the menu UI")
	assert_gte(main_menu.character_card_buttons.size(), 4, "character select has at least four cards")
	assert_not_null(main_menu.character_slot_views.get(1, {}).get("preview"), "player slots embed a gameplay preview control")
	assert_not_null(main_menu.character_detail_panel, "character select exposes a focused-character detail panel")
	var viewport_rect := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	assert_true(viewport_rect.encloses(main_menu.character_select_panel.get_global_rect()), "character select panel stays inside the viewport safe area")
	for resolution in [Vector2i(1280, 720), Vector2i(1024, 768), Vector2i(960, 540)]:
		root.size = resolution
		await wait_physics_frames(1)
		main_menu._open_character_select()
		await wait_physics_frames(1)
		var resized_viewport := Rect2(Vector2.ZERO, root.get_visible_rect().size)
		assert_true(resized_viewport.encloses(main_menu.character_select_panel.get_global_rect()), "character select safe-area fits %dx%d" % [resolution.x, resolution.y])
		assert_not_null(main_menu.character_roster_scroll, "character select keeps the roster scroll container at %dx%d" % [resolution.x, resolution.y])
		assert_true(resized_viewport.encloses(main_menu.character_back_button.get_global_rect()) and resized_viewport.encloses(main_menu.character_start_button.get_global_rect()), "character select action buttons stay visible at %dx%d" % [resolution.x, resolution.y])
	root.size = Vector2i(1280, 720)
	await wait_physics_frames(1)

	if not main_menu.character_card_buttons.is_empty():
		assert_true(main_menu.character_card_buttons[0].has_method("set_profile"), "roster cards use the custom visual card script")
	for profile in main_menu.character_profiles:
		var character_id := StringName(profile.get("id", &""))
		assert_not_null(main_menu._load_character_texture(profile), "character %s resolves a menu preview texture or fallback" % str(character_id))
		assert_not_null(main_menu._load_texture_resource(str(profile.get("portrait_hud_path", ""))), "character %s HUD portrait asset loads from its data path" % str(character_id))

	main_menu._preview_character(&"ranger")
	await wait_physics_frames(1)
	assert_eq(main_menu.focused_character_id, &"ranger", "focusing a card updates the preview profile")
	assert_true(main_menu.character_detail_panel != null and main_menu.character_detail_panel.current_profile.get("id", &"") == &"ranger", "focused card updates the detail panel profile")
	var slot_preview: Control = main_menu.character_slot_views.get(1, {}).get("preview")
	assert_true(slot_preview != null and slot_preview.has_method("has_asset_preview") and slot_preview.call("has_asset_preview"), "current slot preview uses gameplay_sprite_path when available")
	main_menu._assign_character_to_slot(1, &"ranger")
	await wait_physics_frames(1)
	assert_eq(StringName(main_menu.character_selection_by_slot.get(1, &"")), &"ranger", "assigning a card stores the selected character for slot 1")
	assert_false(main_menu.character_start_button.disabled, "start becomes available once active slots have a character")

	main_menu.character_card_buttons[0].grab_focus()
	await _press_joypad_button(0, JOY_BUTTON_DPAD_LEFT)
	await _wait_navigation_cooldown()
	var columns := clampi(main_menu.character_roster_grid.columns, 1, main_menu.character_card_buttons.size())
	var first_row_end := mini(columns, main_menu.character_card_buttons.size()) - 1
	assert_eq(root.gui_get_focus_owner(), main_menu.character_card_buttons[first_row_end], "character select wraps left within the visible roster row")
	await _press_joypad_button(0, JOY_BUTTON_DPAD_RIGHT)
	await _wait_navigation_cooldown()
	assert_eq(root.gui_get_focus_owner(), main_menu.character_card_buttons[0], "character select wraps right within the visible roster row")
	await _press_joypad_button(0, JOY_BUTTON_DPAD_UP)
	await _wait_navigation_cooldown()
	var row_count := ceili(float(main_menu.character_card_buttons.size()) / float(columns))
	assert_eq(root.gui_get_focus_owner(), main_menu.character_card_buttons[(row_count - 1) * columns], "character select wraps up to the last valid row without empty slots")
	await _press_joypad_button(0, JOY_BUTTON_DPAD_DOWN)
	await _wait_navigation_cooldown()
	assert_eq(root.gui_get_focus_owner(), main_menu.character_card_buttons[0], "character select wraps down to the first row in the same column")
	await _press_joypad_button(0, JOY_BUTTON_BACK)
	await wait_physics_frames(1)
	assert_true(not main_menu.character_select_panel.visible and main_menu.primary_panel.visible, "Back closes character select and restores the main menu")

	main_menu._open_character_select()
	await wait_physics_frames(1)
	await _wait_navigation_cooldown()
	main_menu.character_card_buttons[0].grab_focus()
	await _press_key(KEY_RIGHT)
	await _wait_navigation_cooldown()
	assert_eq(root.gui_get_focus_owner(), main_menu.character_card_buttons[1], "keyboard right moves focus to the next roster card")
	await _press_key(KEY_LEFT)
	await _wait_navigation_cooldown()
	assert_eq(root.gui_get_focus_owner(), main_menu.character_card_buttons[0], "keyboard left moves focus back to the previous roster card")
	await _press_key(KEY_ESCAPE)
	await wait_physics_frames(1)
	assert_true(not main_menu.character_select_panel.visible and main_menu.primary_panel.visible, "keyboard Escape closes character select and restores the main menu")

	root.gui_release_focus()
	_free_test_node(main_menu)
	await wait_physics_frames(1)

# --- selezione indipendente per-player (character_select_independent) --------

func test_character_select_independent() -> void:
	var root := get_tree().root
	var main_menu := MainMenu.new()
	add_child(main_menu)
	await wait_physics_frames(2)
	var local_multiplayer := get_tree().get_first_node_in_group("local_multiplayer_manager") as LocalMultiplayerManager
	var created_local_multiplayer := false
	if local_multiplayer == null:
		local_multiplayer = LocalMultiplayerManager.new()
		add_child(local_multiplayer)
		created_local_multiplayer = true
		await wait_physics_frames(1)
	local_multiplayer.activate_slot(2)
	await wait_physics_frames(1)

	main_menu._open_character_select()
	await wait_physics_frames(1)
	assert_true(main_menu.character_select_panel.visible, "character select opens")
	assert_gte(main_menu.character_card_buttons.size(), 4, "roster exposes at least four cards")
	assert_true(main_menu._is_character_slot_active(2), "slot two is active for independent selection")

	main_menu.character_card_buttons[0].grab_focus()
	await wait_physics_frames(1)
	var p1_focus_before := root.gui_get_focus_owner()
	var p1_cursor_before := main_menu._character_cursor_index(1)
	var p2_cursor_before := main_menu._character_cursor_index(2)

	await _press_joypad_button(1, JOY_BUTTON_DPAD_RIGHT)
	await _wait_navigation_cooldown()
	var p2_cursor_after := main_menu._character_cursor_index(2)
	assert_ne(p2_cursor_after, p2_cursor_before, "player two pad moves player two's cursor")
	assert_eq(root.gui_get_focus_owner(), p1_focus_before, "player two navigation leaves player one's focus untouched")
	assert_eq(main_menu._character_cursor_index(1), p1_cursor_before, "player two navigation leaves player one's cursor untouched")

	var p2_pick := main_menu._character_id_at_index(p2_cursor_after)
	await _press_joypad_button(1, JOY_BUTTON_A)
	await wait_physics_frames(1)
	assert_eq(StringName(main_menu.character_selection_by_slot.get(2, &"")), p2_pick, "player two pad confirms its own slot independently")
	assert_true(StringName(main_menu.character_selection_by_slot.get(1, &"")).is_empty(), "player two confirmation does not assign player one's slot")

	var p1_pick := main_menu._character_id_at_index(p1_cursor_before)
	main_menu._assign_character_to_slot(1, p1_pick)
	await wait_physics_frames(1)
	assert_eq(StringName(main_menu.character_selection_by_slot.get(1, &"")), p1_pick, "player one keeps its own independent selection")
	assert_eq(StringName(main_menu.character_selection_by_slot.get(2, &"")), p2_pick, "player two selection survives player one choosing")
	assert_false(main_menu.character_start_button.disabled, "start unlocks once both players have independently chosen")

	local_multiplayer.deactivate_slot(2)
	root.gui_release_focus()
	_free_test_node(main_menu)
	if created_local_multiplayer:
		_free_test_node(local_multiplayer)
	await wait_physics_frames(1)

# --- helper -----------------------------------------------------------------

func _press_key(keycode: Key) -> void:
	var pressed := InputEventKey.new()
	pressed.keycode = keycode
	pressed.pressed = true
	Input.parse_input_event(pressed)
	await wait_physics_frames(1)
	var released := pressed.duplicate() as InputEventKey
	released.pressed = false
	Input.parse_input_event(released)
	await wait_physics_frames(1)

func _press_joypad_button(device: int, button_index: int) -> void:
	var pressed := InputEventJoypadButton.new()
	pressed.device = device
	pressed.button_index = button_index
	pressed.pressed = true
	Input.parse_input_event(pressed)
	await wait_physics_frames(1)
	var released := pressed.duplicate() as InputEventJoypadButton
	released.pressed = false
	Input.parse_input_event(released)
	await wait_physics_frames(1)

func _wait_navigation_cooldown() -> void:
	await get_tree().create_timer(0.22).timeout
	await wait_physics_frames(1)

func _free_test_node(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	var parent := node.get_parent()
	if parent != null:
		parent.remove_child(node)
	node.free()
