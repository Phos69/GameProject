extends SceneTree

# Verifies that, on the character select screen, each active player browses and
# confirms with its own controller independently: player two's pad must move and
# lock its own slot without disturbing player one's focus or selection.

var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main_menu := MainMenu.new()
	root.add_child(main_menu)
	await process_frame
	await process_frame

	var local_multiplayer := get_first_node_in_group(
		"local_multiplayer_manager"
	) as LocalMultiplayerManager
	if local_multiplayer == null:
		# MainMenu created standalone resolves no manager; drive activation via the
		# manager it would normally talk to by faking the active slots through the
		# debug join path instead.
		local_multiplayer = LocalMultiplayerManager.new()
		root.add_child(local_multiplayer)
		await process_frame

	local_multiplayer.activate_slot(2)
	await process_frame

	main_menu._open_character_select()
	await process_frame
	_expect(
		main_menu.character_select_panel.visible,
		"character select opens"
	)
	_expect(
		main_menu.character_card_buttons.size() >= 4,
		"roster exposes at least four cards"
	)
	_expect(
		main_menu._is_character_slot_active(2),
		"slot two is active for independent selection"
	)

	# Player one (keyboard/pad 0) drives the focus-based cursor.
	main_menu.character_card_buttons[0].grab_focus()
	await process_frame
	var p1_focus_before := root.gui_get_focus_owner()
	var p1_cursor_before := main_menu._character_cursor_index(1)
	var p2_cursor_before := main_menu._character_cursor_index(2)

	# Player two moves its own cursor with pad device 1: this must NOT move player
	# one's focus owner nor player one's cursor.
	await _press_joypad_dpad(1, JOY_BUTTON_DPAD_RIGHT)
	await _wait_cooldown()
	var p2_cursor_after := main_menu._character_cursor_index(2)
	_expect(
		p2_cursor_after != p2_cursor_before,
		"player two pad moves player two's cursor"
	)
	_expect(
		root.gui_get_focus_owner() == p1_focus_before,
		"player two navigation leaves player one's focus untouched"
	)
	_expect(
		main_menu._character_cursor_index(1) == p1_cursor_before,
		"player two navigation leaves player one's cursor untouched"
	)

	# Player two confirms its own slot with its own pad (face button A).
	var p2_pick := main_menu._character_id_at_index(p2_cursor_after)
	await _press_joypad_button(1, JOY_BUTTON_A)
	await process_frame
	_expect(
		StringName(main_menu.character_selection_by_slot.get(2, &"")) == p2_pick,
		"player two pad confirms its own slot independently"
	)
	_expect(
		StringName(main_menu.character_selection_by_slot.get(1, &"")).is_empty(),
		"player two confirmation does not assign player one's slot"
	)

	# Player one then locks its own different character through the normal path.
	var p1_pick := main_menu._character_id_at_index(p1_cursor_before)
	main_menu._assign_character_to_slot(1, p1_pick)
	await process_frame
	_expect(
		StringName(main_menu.character_selection_by_slot.get(1, &"")) == p1_pick,
		"player one keeps its own independent selection"
	)
	_expect(
		StringName(main_menu.character_selection_by_slot.get(2, &"")) == p2_pick,
		"player two selection survives player one choosing"
	)
	_expect(
		not main_menu.character_start_button.disabled,
		"start unlocks once both players have independently chosen"
	)

	main_menu.queue_free()
	_finish()

func _press_joypad_dpad(device: int, button_index: JoyButton) -> void:
	await _press_joypad_button(device, button_index)

func _press_joypad_button(device: int, button_index: JoyButton) -> void:
	var pressed := InputEventJoypadButton.new()
	pressed.device = device
	pressed.button_index = button_index
	pressed.pressed = true
	Input.parse_input_event(pressed)
	await process_frame
	var released := pressed.duplicate() as InputEventJoypadButton
	released.pressed = false
	Input.parse_input_event(released)
	await process_frame

func _wait_cooldown() -> void:
	await create_timer(0.22).timeout
	await process_frame

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("CHARACTER_SELECT_INDEPENDENT_SMOKE_TEST: PASS")
		quit(0)
		return
	print(
		"CHARACTER_SELECT_INDEPENDENT_SMOKE_TEST: FAIL (%d)"
		% failures.size()
	)
	quit(1)
