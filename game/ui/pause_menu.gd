extends CanvasLayer
class_name PauseMenu

var backdrop: ColorRect
var pause_panel: PanelContainer
var resume_button: Button
var settings_button: Button
var main_menu_button: Button
var quit_button: Button
var settings_panel: SettingsPanel
var game_mode_manager: GameModeManager

func _ready() -> void:
	add_to_group("pause_menu")
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 25
	_create_ui()
	hide()
	call_deferred("_initialize")

func _input(event: InputEvent) -> void:
	if (
		settings_panel != null
		and settings_panel.visible
		and settings_panel.is_rebinding()
	):
		return
	if not _is_pause_event(event):
		return
	if visible:
		_resume_game()
		get_viewport().set_input_as_handled()
	elif _can_open_pause():
		_open_pause()
		get_viewport().set_input_as_handled()

func is_open() -> bool:
	return visible

func _initialize() -> void:
	_resolve_game_mode_manager()
	if game_mode_manager == null:
		return
	var mode_callback := Callable(self, "_on_game_mode_changed")
	if not game_mode_manager.game_mode_changed.is_connected(mode_callback):
		game_mode_manager.game_mode_changed.connect(mode_callback)
	var finish_callback := Callable(self, "_on_run_finished")
	if not game_mode_manager.run_finished.is_connected(finish_callback):
		game_mode_manager.run_finished.connect(finish_callback)

func _create_ui() -> void:
	backdrop = ColorRect.new()
	backdrop.color = Color(0.015, 0.025, 0.040, 0.88)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.add_child(center)

	pause_panel = PanelContainer.new()
	pause_panel.custom_minimum_size = Vector2(500.0, 420.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.045, 0.062, 0.98)
	style.border_color = Color(0.32, 0.74, 0.86, 0.90)
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(26.0)
	pause_panel.add_theme_stylebox_override("panel", style)
	center.add_child(pause_panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	pause_panel.add_child(content)

	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.modulate = Color(0.55, 0.88, 1.0, 1.0)
	content.add_child(title)

	resume_button = _create_button("Resume", Callable(self, "_resume_game"))
	content.add_child(resume_button)
	settings_button = _create_button("Settings", Callable(self, "_open_settings"))
	content.add_child(settings_button)
	main_menu_button = _create_button(
		"Main Menu",
		Callable(self, "_return_to_main_menu")
	)
	content.add_child(main_menu_button)
	quit_button = _create_button("Quit", Callable(self, "_quit_game"))
	content.add_child(quit_button)

	settings_panel = SettingsPanel.new()
	settings_panel.name = "SettingsPanel"
	center.add_child(settings_panel)
	settings_panel.settings_closed.connect(_on_settings_closed)

func _create_button(label_text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(420.0, 50.0)
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(callback)
	button.focus_entered.connect(_play_focus)
	return button

func _open_pause() -> void:
	_resolve_game_mode_manager()
	if not _can_open_pause():
		return
	get_tree().paused = true
	show()
	pause_panel.show()
	if settings_panel != null:
		settings_panel.close(false)
	resume_button.grab_focus()
	_play_confirm()

func _resume_game() -> void:
	if settings_panel != null:
		settings_panel.close(false)
	hide()
	get_tree().paused = false
	_play_confirm()

func _open_settings() -> void:
	if settings_panel == null:
		return
	pause_panel.hide()
	settings_panel.open(&"audio")
	_play_confirm()

func _return_to_main_menu() -> void:
	_resolve_game_mode_manager()
	if settings_panel != null:
		settings_panel.close(false)
	hide()
	get_tree().paused = false
	_play_confirm()
	if game_mode_manager != null:
		game_mode_manager.return_to_menu()

func _quit_game() -> void:
	get_tree().paused = false
	var save_manager := get_tree().get_first_node_in_group(
		"save_manager"
	) as SaveManager
	if save_manager != null:
		save_manager.save_game()
	_play_confirm()
	get_tree().quit()

func _on_settings_closed() -> void:
	if not visible:
		return
	pause_panel.show()
	settings_button.grab_focus()

func _on_game_mode_changed(mode_id: StringName) -> void:
	if mode_id == GameConstants.MODE_MENU and visible:
		hide()
		get_tree().paused = false

func _on_run_finished(_result: Dictionary) -> void:
	if visible:
		hide()
		get_tree().paused = false

func _can_open_pause() -> bool:
	_resolve_game_mode_manager()
	if game_mode_manager == null or not game_mode_manager.is_gameplay_active():
		return false
	var main_menu := get_tree().get_first_node_in_group("main_menu") as MainMenu
	if main_menu != null and main_menu.is_open():
		return false
	var run_results := get_tree().get_first_node_in_group(
		"run_results_screen"
	) as RunResultsScreen
	if run_results != null and run_results.is_open():
		return false
	return true

func _is_pause_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.echo:
			return false
	return event.is_action_pressed(&"pause")

func _resolve_game_mode_manager() -> void:
	if game_mode_manager == null:
		game_mode_manager = get_tree().get_first_node_in_group(
			"game_mode_manager"
		) as GameModeManager

func _play_focus() -> void:
	var audio_manager := get_tree().get_first_node_in_group(
		"audio_manager"
	) as AudioManager
	if audio_manager != null:
		audio_manager.play_ui_focus()

func _play_confirm() -> void:
	var audio_manager := get_tree().get_first_node_in_group(
		"audio_manager"
	) as AudioManager
	if audio_manager != null:
		audio_manager.play_ui_confirm()
