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
		main_menu.character_detail_panel != null,
		"character select has a detail and gameplay preview panel"
	)
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

	main_menu._preview_character(&"ranger")
	await process_frame
	_expect(
		main_menu.focused_character_id == &"ranger",
		"focusing a card updates the preview profile"
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

	main_menu.queue_free()
	_finish()

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
