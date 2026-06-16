extends CanvasLayer
class_name MainMenu

signal mode_selected(mode_id: StringName)

var backdrop: ColorRect
var title_label: Label
var save_status_label: Label
var continue_button: Button
var first_mode_button: Button
var menu_buttons: Array[Button] = []
var volume_sliders: Dictionary = {}
var visual_settings_panel: PanelContainer
var visual_controls: Dictionary = {}
var primary_panel: PanelContainer
var character_select_panel: PanelContainer
var character_card_buttons: Array[Button] = []

var game_mode_manager: GameModeManager
var save_manager: SaveManager
var progression_manager: ProgressionManager
var visual_settings_manager: VisualSettingsManager

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
		and is_open()
		and character_select_panel != null
		and character_select_panel.visible
	):
		_close_character_select()
		get_viewport().set_input_as_handled()
		return
	if (
		key_event.pressed
		and not key_event.echo
		and key_event.keycode == KEY_ESCAPE
		and is_open()
		and visual_settings_panel != null
		and visual_settings_panel.visible
	):
		_close_visual_settings()
		get_viewport().set_input_as_handled()
		return
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
	if save_manager != null:
		save_manager.save_game()
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
		var unlock_callback := Callable(self, "_on_unlocks_changed")
		if not progression_manager.unlocks_changed.is_connected(unlock_callback):
			progression_manager.unlocks_changed.connect(unlock_callback)
	_refresh_save_status()
	_refresh_audio_controls()
	_refresh_visual_controls()
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

	primary_panel = PanelContainer.new()
	primary_panel.name = "MenuPanel"
	primary_panel.custom_minimum_size = Vector2(540.0, 640.0)
	center.add_child(primary_panel)

	var content := VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", 8)
	primary_panel.add_child(content)

	title_label = Label.new()
	title_label.text = "ISO LOCAL SANDBOX"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 30)
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

	var audio_title := Label.new()
	audio_title.text = "AUDIO MIX"
	audio_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	audio_title.add_theme_font_size_override("font_size", 17)
	audio_title.modulate = Color(0.55, 0.88, 1.0, 1.0)
	content.add_child(audio_title)
	content.add_child(_create_volume_row("Master", &"Master"))
	content.add_child(_create_volume_row("Music", &"Music"))
	content.add_child(_create_volume_row("SFX", &"SFX"))
	var visual_button := _create_button(
		"Visual & Accessibility",
		Callable(self, "_open_visual_settings")
	)
	visual_button.custom_minimum_size.y = 38.0
	content.add_child(visual_button)

	var controls := Label.new()
	controls.text = (
		"Keyboard: arrows/Enter, Esc for menu | Joypad: D-pad/stick + A"
	)
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.modulate = Color(0.68, 0.74, 0.82, 1.0)
	content.add_child(controls)
	_create_visual_settings_panel(center)
	_create_character_select_panel(center)

func _create_character_select_panel(parent: Control) -> void:
	character_select_panel = PanelContainer.new()
	character_select_panel.name = "CharacterSelectPanel"
	character_select_panel.custom_minimum_size = Vector2(760.0, 640.0)
	parent.add_child(character_select_panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 9)
	character_select_panel.add_child(content)

	var title := Label.new()
	title.text = "CHARACTER SELECT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.modulate = Color(0.55, 0.88, 1.0, 1.0)
	content.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Choose the survivor profile for the zombie run"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.modulate = Color(0.72, 0.80, 0.88, 1.0)
	content.add_child(subtitle)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	content.add_child(grid)

	for profile in RpgCharacterRegistry.get_character_profiles():
		var button := Button.new()
		button.text = _format_character_card(profile)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size = Vector2(360.0, 205.0)
		button.add_theme_font_size_override("font_size", 13)
		button.pressed.connect(
			_select_survival_character.bind(
				StringName(profile.get("id", &""))
			)
		)
		button.focus_entered.connect(_play_focus)
		grid.add_child(button)
		character_card_buttons.append(button)

	var back_button := Button.new()
	back_button.text = "Back"
	back_button.custom_minimum_size = Vector2(440.0, 44.0)
	back_button.pressed.connect(_close_character_select)
	back_button.focus_entered.connect(_play_focus)
	content.add_child(back_button)
	character_select_panel.hide()

func _create_visual_settings_panel(parent: Control) -> void:
	visual_settings_panel = PanelContainer.new()
	visual_settings_panel.name = "VisualSettingsPanel"
	visual_settings_panel.custom_minimum_size = Vector2(540.0, 640.0)
	parent.add_child(visual_settings_panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	visual_settings_panel.add_child(content)
	var title := Label.new()
	title.text = "VISUAL & ACCESSIBILITY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 25)
	title.modulate = Color(0.55, 0.88, 1.0, 1.0)
	content.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Presentation only: gameplay values never change"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.modulate = Color(0.72, 0.80, 0.88, 1.0)
	content.add_child(subtitle)
	content.add_child(_create_visual_slider(
		"Flash",
		&"flash_intensity",
		0.0,
		1.0,
		0.05
	))
	content.add_child(_create_visual_slider(
		"Glow",
		&"glow_intensity",
		0.0,
		1.0,
		0.05
	))
	content.add_child(_create_visual_slider(
		"Trails",
		&"trail_intensity",
		0.0,
		1.0,
		0.05
	))
	content.add_child(_create_visual_slider(
		"Camera shake",
		&"camera_shake_intensity",
		0.0,
		1.0,
		0.05
	))
	content.add_child(_create_visual_slider(
		"HUD text",
		&"hud_text_scale",
		0.8,
		1.2,
		0.05
	))
	content.add_child(_create_visual_toggle(
		"High contrast",
		&"high_contrast"
	))
	content.add_child(_create_visual_toggle(
		"Reduced motion",
		&"reduced_motion"
	))
	var presets := HBoxContainer.new()
	presets.add_theme_constant_override("separation", 8)
	for spec in [
		["Default", &"default"],
		["Comfort", &"reduced_motion"],
		["Contrast", &"high_contrast"]
	]:
		var button := Button.new()
		button.text = spec[0]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 42.0
		button.pressed.connect(_apply_visual_profile.bind(spec[1]))
		button.focus_entered.connect(_play_focus)
		presets.add_child(button)
	content.add_child(presets)
	var back_button := Button.new()
	back_button.text = "Back"
	back_button.custom_minimum_size = Vector2(440.0, 46.0)
	back_button.pressed.connect(_close_visual_settings)
	back_button.focus_entered.connect(_play_focus)
	content.add_child(back_button)
	visual_controls[&"back_button"] = back_button
	visual_settings_panel.hide()

func _create_visual_slider(
	label_text: String,
	setting_id: StringName,
	minimum: float,
	maximum: float,
	step_value: float
) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(145.0, 34.0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	var slider := HSlider.new()
	slider.custom_minimum_size = Vector2(275.0, 34.0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step_value
	slider.value_changed.connect(
		_on_visual_slider_changed.bind(setting_id)
	)
	slider.focus_entered.connect(_play_focus)
	row.add_child(slider)
	visual_controls[setting_id] = slider
	return row

func _create_visual_toggle(
	label_text: String,
	setting_id: StringName
) -> Control:
	var toggle := CheckButton.new()
	toggle.text = label_text
	toggle.custom_minimum_size = Vector2(440.0, 42.0)
	toggle.button_pressed = false
	toggle.toggled.connect(_on_visual_toggle_changed.bind(setting_id))
	toggle.focus_entered.connect(_play_focus)
	visual_controls[setting_id] = toggle
	return toggle

func _create_button(label_text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(440.0, 44.0)
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(callback)
	button.focus_entered.connect(_play_focus)
	menu_buttons.append(button)
	return button

func _create_volume_row(label_text: String, bus_name: StringName) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(90.0, 26.0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	var slider := HSlider.new()
	slider.custom_minimum_size = Vector2(330.0, 26.0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = 1.0
	slider.value_changed.connect(_on_volume_changed.bind(bus_name))
	slider.focus_entered.connect(_play_focus)
	row.add_child(slider)
	volume_sliders[bus_name] = slider
	return row

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
	if visual_settings_manager == null:
		visual_settings_manager = get_tree().get_first_node_in_group(
			"visual_settings_manager"
		) as VisualSettingsManager

func _continue_game() -> void:
	var mode_id := (
		save_manager.get_last_mode()
		if save_manager != null
		else GameConstants.MODE_SURVIVAL
	)
	if mode_id == GameConstants.MODE_SURVIVAL:
		_open_character_select()
	else:
		start_selected_mode(mode_id)

func _select_mode(mode_id: StringName) -> void:
	if mode_id == GameConstants.MODE_SURVIVAL:
		_open_character_select()
	else:
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
	_close_visual_settings(false)
	_close_character_select(false)
	_refresh_save_status()
	_refresh_audio_controls()
	_refresh_visual_controls()
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
	var unlock_status := (
		progression_manager.get_unlock_status_text()
		if progression_manager != null
		else "Next unlock: Field Kit at party Lv 2"
	)
	var last_mode := (
		save_manager.get_last_mode()
		if save_manager != null
		else GameConstants.MODE_SURVIVAL
	)
	save_status_label.text = (
		"Party Lv %d  XP %d  Money %d\n%s\nContinue: %s"
	) % [
		level,
		experience,
		money,
		unlock_status,
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

func _format_character_card(profile: Dictionary) -> String:
	return (
		"%s\n%s · %s  Palette: %s\nHP %d  ATK %d  DEF %d  SPD %.2f\n"
		+ "Passive: %s\n%s\nSuper: %s\n%s\nDifficulty: %s"
	) % [
		str(profile.get("hero_name", profile.get("display_name", "Survivor"))).to_upper(),
		str(profile.get("class_name", "Survivor")),
		str(profile.get("base_weapon_name", "Starter Pistol")),
		str(profile.get("gameplay_palette_id", "default")),
		int(profile.get("max_hp", 100)),
		int(profile.get("attack", 0)),
		int(profile.get("defense", 0)),
		float(profile.get("speed", 1.0)),
		str(profile.get("passive_name", "")),
		str(profile.get("passive_description", "")),
		str(profile.get("super_name", "")),
		str(profile.get("super_description", "")),
		str(profile.get("difficulty", "Media"))
	]

func _open_character_select() -> void:
	_resolve_managers()
	primary_panel.hide()
	if visual_settings_panel != null:
		visual_settings_panel.hide()
	character_select_panel.show()
	if not character_card_buttons.is_empty():
		character_card_buttons[0].grab_focus()

func _close_character_select(grab_focus: bool = true) -> void:
	if character_select_panel == null or primary_panel == null:
		return
	character_select_panel.hide()
	primary_panel.show()
	if grab_focus and first_mode_button != null:
		first_mode_button.grab_focus()

func _select_survival_character(character_id: StringName) -> void:
	_resolve_managers()
	if game_mode_manager == null:
		return
	if not game_mode_manager.has_mode(GameConstants.MODE_SURVIVAL):
		return
	_play_confirm()
	var context := {"character_id": character_id}
	if game_mode_manager.set_mode(GameConstants.MODE_SURVIVAL, context):
		mode_selected.emit(GameConstants.MODE_SURVIVAL)

func _on_progression_changed(_experience: int, _level: int) -> void:
	_refresh_save_status()

func _on_money_changed(_money: int) -> void:
	_refresh_save_status()

func _on_unlocks_changed(_unlock_ids: Array[StringName]) -> void:
	_refresh_save_status()

func _on_volume_changed(value: float, bus_name: StringName) -> void:
	var audio_manager := get_tree().get_first_node_in_group(
		"audio_manager"
	) as AudioManager
	if audio_manager != null:
		audio_manager.set_bus_volume_linear(bus_name, value)

func _refresh_audio_controls() -> void:
	var audio_manager := get_tree().get_first_node_in_group(
		"audio_manager"
	) as AudioManager
	if audio_manager == null:
		return
	for bus_name in volume_sliders:
		var slider := volume_sliders[bus_name] as HSlider
		slider.set_value_no_signal(
			audio_manager.get_bus_volume_linear(bus_name)
		)

func _open_visual_settings() -> void:
	_resolve_managers()
	_refresh_visual_controls()
	primary_panel.hide()
	visual_settings_panel.show()
	var first_control := visual_controls.get(
		&"flash_intensity"
	) as HSlider
	if first_control != null:
		first_control.grab_focus()

func _close_visual_settings(grab_focus: bool = true) -> void:
	if visual_settings_panel == null or primary_panel == null:
		return
	visual_settings_panel.hide()
	primary_panel.show()
	if grab_focus and continue_button != null:
		continue_button.grab_focus()

func _on_visual_slider_changed(
	value: float,
	setting_id: StringName
) -> void:
	_resolve_managers()
	if visual_settings_manager != null:
		visual_settings_manager.set_setting(setting_id, value)

func _on_visual_toggle_changed(
	value: bool,
	setting_id: StringName
) -> void:
	_resolve_managers()
	if visual_settings_manager != null:
		visual_settings_manager.set_setting(setting_id, value)

func _apply_visual_profile(profile_id: StringName) -> void:
	_resolve_managers()
	if (
		visual_settings_manager != null
		and visual_settings_manager.apply_profile(profile_id)
	):
		_refresh_visual_controls()

func _refresh_visual_controls() -> void:
	_resolve_managers()
	if visual_settings_manager == null:
		return
	for setting_id in [
		&"flash_intensity",
		&"glow_intensity",
		&"trail_intensity",
		&"camera_shake_intensity",
		&"hud_text_scale"
	]:
		var slider := visual_controls.get(setting_id) as HSlider
		if slider != null:
			slider.set_value_no_signal(float(
				visual_settings_manager.get_setting(setting_id, 1.0)
			))
	for setting_id in [&"high_contrast", &"reduced_motion"]:
		var toggle := visual_controls.get(setting_id) as CheckButton
		if toggle != null:
			toggle.set_pressed_no_signal(bool(
				visual_settings_manager.get_setting(setting_id, false)
			))

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
