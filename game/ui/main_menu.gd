extends CanvasLayer
class_name MainMenu

signal mode_selected(mode_id: StringName)

var backdrop: ColorRect
var title_label: Label
var save_status_label: Label
var continue_button: Button
var first_mode_button: Button
var menu_buttons: Array[Button] = []

var game_mode_manager: GameModeManager
var save_manager: SaveManager
var progression_manager: ProgressionManager

func _ready() -> void:
	add_to_group("main_menu")
	layer = 20
	_create_ui()
	call_deferred("_initialize")

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if (
		key_event.pressed
		and not key_event.echo
		and key_event.keycode == KEY_ESCAPE
		and not is_open()
	):
		open_menu()
		get_viewport().set_input_as_handled()

func open_menu() -> void:
	_resolve_managers()
	if game_mode_manager != null:
		game_mode_manager.set_mode(GameConstants.MODE_MENU)
	_show_menu()

func start_selected_mode(mode_id: StringName) -> bool:
	_resolve_managers()
	if game_mode_manager == null or not game_mode_manager.has_mode(mode_id):
		return false
	_play_confirm()
	if not game_mode_manager.set_mode(mode_id):
		return false
	mode_selected.emit(mode_id)
	return true

func is_open() -> bool:
	return visible

func _initialize() -> void:
	_resolve_managers()
	if game_mode_manager != null:
		var mode_callback := Callable(self, "_on_game_mode_changed")
		if not game_mode_manager.game_mode_changed.is_connected(mode_callback):
			game_mode_manager.game_mode_changed.connect(mode_callback)
	if progression_manager != null:
		var experience_callback := Callable(self, "_on_progression_changed")
		if not progression_manager.experience_changed.is_connected(
			experience_callback
		):
			progression_manager.experience_changed.connect(experience_callback)
		var money_callback := Callable(self, "_on_money_changed")
		if not progression_manager.money_changed.is_connected(money_callback):
			progression_manager.money_changed.connect(money_callback)
	_refresh_save_status()
	if (
		game_mode_manager == null
		or game_mode_manager.active_mode_id == GameConstants.MODE_MENU
	):
		_show_menu()
	else:
		_hide_menu()

func _create_ui() -> void:
	backdrop = ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = Color(0.025, 0.04, 0.075, 0.97)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.add_child(center)

	var panel := PanelContainer.new()
	panel.name = "MenuPanel"
	panel.custom_minimum_size = Vector2(520.0, 560.0)
	center.add_child(panel)

	var content := VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", 14)
	panel.add_child(content)

	title_label = Label.new()
	title_label.text = "ISO LOCAL SANDBOX"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 34)
	title_label.modulate = Color(0.55, 0.88, 1.0, 1.0)
	content.add_child(title_label)

	var subtitle := Label.new()
	subtitle.text = "Choose a local multiplayer mode"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	content.add_child(subtitle)

	save_status_label = Label.new()
	save_status_label.name = "SaveStatusLabel"
	save_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	save_status_label.modulate = Color(0.78, 0.84, 0.92, 1.0)
	content.add_child(save_status_label)

	continue_button = _create_button("Continue", Callable(self, "_continue_game"))
	content.add_child(continue_button)

	first_mode_button = _create_button(
		"Zombie Survival",
		Callable(self, "_select_mode").bind(GameConstants.MODE_SURVIVAL)
	)
	content.add_child(first_mode_button)
	content.add_child(_create_button(
		"Procedural Dungeon",
		Callable(self, "_select_mode").bind(GameConstants.MODE_DUNGEON)
	))
	content.add_child(_create_button(
		"Tower Defense",
		Callable(self, "_select_mode").bind(GameConstants.MODE_TOWER_DEFENSE)
	))
	content.add_child(_create_button("Quit", Callable(self, "_quit_game")))

	var controls := Label.new()
	controls.text = (
		"Keyboard: arrows/Enter to navigate, Esc for menu\n"
		+ "Joypad: D-pad/stick and A to confirm"
	)
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.modulate = Color(0.68, 0.74, 0.82, 1.0)
	content.add_child(controls)

func _create_button(label_text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(440.0, 52.0)
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(callback)
	button.focus_entered.connect(_play_focus)
	menu_buttons.append(button)
	return button

func _resolve_managers() -> void:
	if game_mode_manager == null:
		game_mode_manager = get_tree().get_first_node_in_group(
			"game_mode_manager"
		) as GameModeManager
	if save_manager == null:
		save_manager = get_tree().get_first_node_in_group(
			"save_manager"
		) as SaveManager
	if progression_manager == null:
		progression_manager = get_tree().get_first_node_in_group(
			"progression_manager"
		) as ProgressionManager

func _continue_game() -> void:
	var mode_id := (
		save_manager.get_last_mode()
		if save_manager != null
		else GameConstants.MODE_SURVIVAL
	)
	start_selected_mode(mode_id)

func _select_mode(mode_id: StringName) -> void:
	start_selected_mode(mode_id)

func _quit_game() -> void:
	_play_confirm()
	get_tree().quit()

func _on_game_mode_changed(mode_id: StringName) -> void:
	if mode_id == GameConstants.MODE_MENU:
		_show_menu()
	else:
		_hide_menu()

func _show_menu() -> void:
	show()
	_refresh_save_status()
	if continue_button != null:
		continue_button.grab_focus()

func _hide_menu() -> void:
	hide()

func _refresh_save_status() -> void:
	if save_status_label == null:
		return
	_resolve_managers()
	var level := progression_manager.level if progression_manager != null else 1
	var experience := progression_manager.experience if progression_manager != null else 0
	var money := progression_manager.money if progression_manager != null else 0
	var last_mode := (
		save_manager.get_last_mode()
		if save_manager != null
		else GameConstants.MODE_SURVIVAL
	)
	save_status_label.text = "Party Lv %d  XP %d  Money %d\nContinue: %s" % [
		level,
		experience,
		money,
		_mode_label(last_mode)
	]

func _mode_label(mode_id: StringName) -> String:
	match mode_id:
		GameConstants.MODE_DUNGEON:
			return "Procedural Dungeon"
		GameConstants.MODE_TOWER_DEFENSE:
			return "Tower Defense"
		_:
			return "Zombie Survival"

func _on_progression_changed(_experience: int, _level: int) -> void:
	_refresh_save_status()

func _on_money_changed(_money: int) -> void:
	_refresh_save_status()

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
