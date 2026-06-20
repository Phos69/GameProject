extends SceneTree

const OUTPUT_DIRECTORY: String = "res://build/qa"

var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main_menu := MainMenu.new()
	root.add_child(main_menu)
	await process_frame
	await process_frame

	main_menu._open_character_select()
	await process_frame
	_expect(
		main_menu.character_select_panel.visible,
		"character select opens from the menu UI"
	)
	_expect(
		main_menu.character_card_buttons.size() >= 4,
		"character select has at least four cards"
	)
	_expect(
		main_menu.character_slot_views.get(1, {}).get("preview") != null,
		"player slots embed a gameplay preview control"
	)
	_expect(
		main_menu.character_detail_panel != null,
		"character select exposes a focused-character detail panel"
	)
	var viewport_rect := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	var panel_rect := main_menu.character_select_panel.get_global_rect()
	_expect(
		viewport_rect.encloses(panel_rect),
		"character select panel stays inside the viewport safe area"
	)
	for resolution in [
		Vector2i(1280, 720),
		Vector2i(1024, 768),
		Vector2i(960, 540)
	]:
		root.size = resolution
		await process_frame
		main_menu._open_character_select()
		await process_frame
		var resized_viewport := Rect2(Vector2.ZERO, root.get_visible_rect().size)
		var resized_panel := main_menu.character_select_panel.get_global_rect()
		_expect(
			resized_viewport.encloses(resized_panel),
			"character select safe-area fits %dx%d" % [
				resolution.x,
				resolution.y
			]
		)
		_expect(
			main_menu.character_roster_scroll != null,
			"character select keeps the roster scroll container at %dx%d" % [
				resolution.x,
				resolution.y
			]
		)
		_expect(
			resized_viewport.encloses(
				main_menu.character_back_button.get_global_rect()
			) and resized_viewport.encloses(
				main_menu.character_start_button.get_global_rect()
			),
			"character select action buttons stay visible at %dx%d" % [
				resolution.x,
				resolution.y
			]
		)
	root.size = Vector2i(1280, 720)
	await process_frame
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(OUTPUT_DIRECTORY)
	)
	if await _capture("character_select_ui_smoke.png"):
		print("PASS: character select screenshot is captured")
	else:
		print("SKIP: headless viewport screenshot is unavailable")
	if not main_menu.character_card_buttons.is_empty():
		_expect(
			main_menu.character_card_buttons[0].has_method("set_profile"),
			"roster cards use the custom visual card script"
		)
	for profile in main_menu.character_profiles:
		var character_id := StringName(profile.get("id", &""))
		_expect(
			main_menu._load_character_texture(profile) != null,
			"character %s resolves a menu preview texture or fallback" % [
				str(character_id)
			]
		)
		var hud_path := str(profile.get("portrait_hud_path", ""))
		_expect(
			main_menu._load_texture_resource(hud_path) != null,
			"character %s HUD portrait asset loads from its data path" % [
				str(character_id)
			]
		)

	main_menu._preview_character(&"ranger")
	await process_frame
	_expect(
		main_menu.focused_character_id == &"ranger",
		"focusing a card updates the preview profile"
	)
	_expect(
		main_menu.character_detail_panel != null
			and main_menu.character_detail_panel.current_profile.get("id", &"") == &"ranger",
		"focused card updates the detail panel profile"
	)
	var slot_preview: Control = main_menu.character_slot_views.get(1, {}).get("preview")
	_expect(
		slot_preview != null
			and slot_preview.has_method("has_asset_preview")
			and slot_preview.call("has_asset_preview"),
		"current slot preview uses gameplay_sprite_path when available"
	)
	main_menu._assign_character_to_slot(1, &"ranger")
	await process_frame
	_expect(
		StringName(main_menu.character_selection_by_slot.get(1, &""))
			== &"ranger",
		"assigning a card stores the selected character for slot 1"
	)
	_expect(
		not main_menu.character_start_button.disabled,
		"start becomes available once active slots have a character"
	)
	main_menu.character_card_buttons[0].grab_focus()
	await _press_joypad_button(JOY_BUTTON_DPAD_LEFT)
	await _wait_navigation_cooldown()
	var columns := clampi(
		main_menu.character_roster_grid.columns,
		1,
		main_menu.character_card_buttons.size()
	)
	var first_row_end := mini(columns, main_menu.character_card_buttons.size()) - 1
	_expect(
		root.gui_get_focus_owner() == main_menu.character_card_buttons[first_row_end],
		"character select wraps left within the visible roster row"
	)
	await _press_joypad_button(JOY_BUTTON_DPAD_RIGHT)
	await _wait_navigation_cooldown()
	_expect(
		root.gui_get_focus_owner() == main_menu.character_card_buttons[0],
		"character select wraps right within the visible roster row"
	)
	await _press_joypad_button(JOY_BUTTON_DPAD_UP)
	await _wait_navigation_cooldown()
	var row_count := ceili(
		float(main_menu.character_card_buttons.size()) / float(columns)
	)
	var last_row_first := (row_count - 1) * columns
	_expect(
		root.gui_get_focus_owner() == main_menu.character_card_buttons[last_row_first],
		"character select wraps up to the last valid row without empty slots"
	)
	await _press_joypad_button(JOY_BUTTON_DPAD_DOWN)
	await _wait_navigation_cooldown()
	_expect(
		root.gui_get_focus_owner() == main_menu.character_card_buttons[0],
		"character select wraps down to the first row in the same column"
	)
	await _press_joypad_button(JOY_BUTTON_BACK)
	await process_frame
	_expect(
		not main_menu.character_select_panel.visible
		and main_menu.primary_panel.visible,
		"Back closes character select and restores the main menu"
	)
	main_menu._open_character_select()
	await process_frame
	await _wait_navigation_cooldown()
	main_menu.character_card_buttons[0].grab_focus()
	await _press_key(KEY_RIGHT)
	await _wait_navigation_cooldown()
	_expect(
		root.gui_get_focus_owner() == main_menu.character_card_buttons[1],
		"keyboard right moves focus to the next roster card"
	)
	await _press_key(KEY_LEFT)
	await _wait_navigation_cooldown()
	_expect(
		root.gui_get_focus_owner() == main_menu.character_card_buttons[0],
		"keyboard left moves focus back to the previous roster card"
	)
	await _press_key(KEY_ESCAPE)
	await process_frame
	_expect(
		not main_menu.character_select_panel.visible
			and main_menu.primary_panel.visible,
		"keyboard Escape closes character select and restores the main menu"
	)
	main_menu.queue_free()
	_finish()

func _press_key(keycode: Key) -> void:
	var pressed := InputEventKey.new()
	pressed.keycode = keycode
	pressed.pressed = true
	Input.parse_input_event(pressed)
	await process_frame
	var released := pressed.duplicate() as InputEventKey
	released.pressed = false
	Input.parse_input_event(released)
	await process_frame

func _press_joypad_button(button_index: JoyButton) -> void:
	var pressed := InputEventJoypadButton.new()
	pressed.device = 0
	pressed.button_index = button_index
	pressed.pressed = true
	Input.parse_input_event(pressed)
	await process_frame
	var released := pressed.duplicate() as InputEventJoypadButton
	released.pressed = false
	Input.parse_input_event(released)
	await process_frame

func _wait_navigation_cooldown() -> void:
	await create_timer(0.22).timeout
	await process_frame

func _capture(file_name: String) -> bool:
	if DisplayServer.get_name().to_lower() == "headless":
		return false
	await process_frame
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		return false
	var output_path := "%s/%s" % [OUTPUT_DIRECTORY, file_name]
	return image.save_png(ProjectSettings.globalize_path(output_path)) == OK

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("CHARACTER_SELECT_UI_SMOKE_TEST: PASS")
		quit(0)
		return
	print("CHARACTER_SELECT_UI_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
