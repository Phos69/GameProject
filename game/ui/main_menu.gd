extends CanvasLayer
class_name MainMenu

signal mode_selected(mode_id: StringName)

const CHARACTER_SLOT_COLORS: Array[Color] = [
	Color(0.18, 0.74, 0.95, 1.0),
	Color(0.95, 0.42, 0.34, 1.0),
	Color(0.52, 0.86, 0.32, 1.0),
	Color(0.94, 0.78, 0.28, 1.0)
]

var backdrop: ColorRect
var title_label: Label
var save_status_label: Label
var continue_button: Button
var first_mode_button: Button
var menu_buttons: Array[Button] = []
var volume_sliders: Dictionary = {}
var visual_settings_panel: PanelContainer
var settings_panel: SettingsPanel
var visual_controls: Dictionary = {}
var primary_panel: PanelContainer
var character_select_panel: PanelContainer
var character_card_buttons: Array[Button] = []
var character_start_button: Button
var character_profiles: Array[Dictionary] = []
var character_profile_by_id: Dictionary = {}
var character_texture_cache: Dictionary = {}
var character_slot_views: Dictionary = {}
var character_selection_by_slot: Dictionary = {}
var current_character_slot: int = 1

var game_mode_manager: GameModeManager
var save_manager: SaveManager
var progression_manager: ProgressionManager
var visual_settings_manager: VisualSettingsManager
var local_multiplayer_manager: LocalMultiplayerManager

func _ready() -> void:
	add_to_group("main_menu")
	layer = 20
	_create_ui()
	call_deferred("_initialize")

func _input(event: InputEvent) -> void:
	if character_select_panel == null or not character_select_panel.visible:
		return
	var player_slot := _player_slot_from_input_event(event)
	if player_slot <= 0 or not _is_character_slot_active(player_slot):
		return
	_set_current_character_slot(player_slot)

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
	if local_multiplayer_manager != null:
		var slots_callback := Callable(self, "_on_active_slots_changed")
		if not local_multiplayer_manager.active_slots_changed.is_connected(
			slots_callback
		):
			local_multiplayer_manager.active_slots_changed.connect(slots_callback)
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
	_refresh_settings_controls()
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
	var settings_button := _create_button("Settings", Callable(self, "_open_settings"))
	content.add_child(settings_button)
	content.add_child(_create_button("Quit", Callable(self, "_quit_game")))

	var controls := Label.new()
	controls.text = (
		"Keyboard: arrows/Enter, Esc for menu | Joypad: D-pad/stick + A"
	)
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.modulate = Color(0.68, 0.74, 0.82, 1.0)
	content.add_child(controls)
	_create_settings_panel(center)
	_create_character_select_panel(center)

func _create_settings_panel(parent: Control) -> void:
	settings_panel = SettingsPanel.new()
	settings_panel.name = "SettingsPanel"
	parent.add_child(settings_panel)
	visual_settings_panel = settings_panel
	volume_sliders = settings_panel.volume_sliders
	visual_controls = settings_panel.visual_controls
	settings_panel.settings_closed.connect(_on_settings_panel_closed)

func _create_character_select_panel(parent: Control) -> void:
	character_select_panel = PanelContainer.new()
	character_select_panel.name = "CharacterSelectPanel"
	character_select_panel.custom_minimum_size = Vector2(1080.0, 680.0)
	parent.add_child(character_select_panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
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

	character_profiles = RpgCharacterRegistry.get_character_profiles()
	character_profile_by_id.clear()
	for profile in character_profiles:
		var character_id := StringName(profile.get("id", &""))
		if not character_id.is_empty():
			character_profile_by_id[character_id] = profile

	var slots_grid := GridContainer.new()
	slots_grid.columns = 4
	slots_grid.add_theme_constant_override("h_separation", 8)
	slots_grid.add_theme_constant_override("v_separation", 8)
	content.add_child(slots_grid)
	for player_slot in range(1, 5):
		slots_grid.add_child(_create_character_slot_panel(player_slot))

	var roster_grid := GridContainer.new()
	roster_grid.columns = 4
	roster_grid.add_theme_constant_override("h_separation", 8)
	roster_grid.add_theme_constant_override("v_separation", 8)
	content.add_child(roster_grid)

	for profile in character_profiles:
		var character_id := StringName(profile.get("id", &""))
		var button := Button.new()
		button.name = "Character%sButton" % str(character_id).capitalize()
		button.text = _format_character_icon_label(profile)
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size = Vector2(258.0, 112.0)
		button.add_theme_font_size_override("font_size", 12)
		button.icon = _load_character_texture(profile)
		button.expand_icon = true
		button.pressed.connect(_assign_character_to_current_slot.bind(character_id))
		button.focus_entered.connect(_play_focus)
		roster_grid.add_child(button)
		character_card_buttons.append(button)

	var action_row := HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.add_theme_constant_override("separation", 12)
	content.add_child(action_row)

	character_start_button = Button.new()
	character_start_button.text = "Start Survival"
	character_start_button.custom_minimum_size = Vector2(260.0, 44.0)
	character_start_button.disabled = true
	character_start_button.pressed.connect(_start_survival_with_selected_characters)
	character_start_button.focus_entered.connect(_play_focus)
	action_row.add_child(character_start_button)

	var back_button := Button.new()
	back_button.text = "Back"
	back_button.custom_minimum_size = Vector2(260.0, 44.0)
	back_button.pressed.connect(_close_character_select)
	back_button.focus_entered.connect(_play_focus)
	action_row.add_child(back_button)
	character_select_panel.hide()

func _create_character_slot_panel(player_slot: int) -> Control:
	var panel := PanelContainer.new()
	panel.name = "Player%dSelectionSlot" % player_slot
	panel.custom_minimum_size = Vector2(258.0, 204.0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(_on_character_slot_gui_input.bind(player_slot))

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 3)
	panel.add_child(content)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 6)
	content.add_child(top_row)

	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(70.0, 70.0)
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	top_row.add_child(portrait)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 1)
	top_row.add_child(title_box)

	var player_label := Label.new()
	player_label.add_theme_font_size_override("font_size", 13)
	title_box.add_child(player_label)

	var name_label := Label.new()
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.max_lines_visible = 2
	title_box.add_child(name_label)

	var class_label := Label.new()
	class_label.add_theme_font_size_override("font_size", 11)
	class_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	class_label.max_lines_visible = 2
	title_box.add_child(class_label)

	var stats_label := _create_character_detail_label(10, 1)
	content.add_child(stats_label)

	var passive_label := _create_character_detail_label(9, 2)
	content.add_child(passive_label)

	var super_label := _create_character_detail_label(9, 2)
	content.add_child(super_label)

	character_slot_views[player_slot] = {
		"panel": panel,
		"portrait": portrait,
		"player": player_label,
		"name": name_label,
		"class": class_label,
		"stats": stats_label,
		"passive": passive_label,
		"super": super_label
	}
	return panel

func _create_character_detail_label(
	font_size: int,
	max_lines: int
) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.max_lines_visible = max_lines
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.modulate = Color(0.78, 0.84, 0.90, 1.0)
	return label

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
	if local_multiplayer_manager == null:
		local_multiplayer_manager = get_tree().get_first_node_in_group(
			"local_multiplayer_manager"
		) as LocalMultiplayerManager

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
	_refresh_settings_controls()
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

func _format_character_icon_label(profile: Dictionary) -> String:
	return "%s\n%s" % [
		str(profile.get("hero_name", profile.get("display_name", "Survivor"))),
		str(profile.get("class_name", "Survivor"))
	]

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
	if settings_panel != null:
		settings_panel.close(false)
	_ensure_current_character_slot()
	_refresh_character_selection_ui()
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
	for player_slot in _get_active_character_slots():
		character_selection_by_slot[player_slot] = character_id
	_start_survival_with_selected_characters()

func _assign_character_to_current_slot(character_id: StringName) -> void:
	_assign_character_to_slot(current_character_slot, character_id)

func _assign_character_to_slot(
	player_slot: int,
	character_id: StringName
) -> void:
	if not _is_character_slot_active(player_slot):
		return
	if not RpgCharacterRegistry.is_character_available(character_id):
		return
	current_character_slot = player_slot
	character_selection_by_slot[player_slot] = character_id
	_play_confirm()
	_refresh_character_selection_ui()
	if (
		character_start_button != null
		and not character_start_button.disabled
	):
		character_start_button.grab_focus()

func _start_survival_with_selected_characters() -> void:
	_resolve_managers()
	if game_mode_manager == null:
		return
	if not game_mode_manager.has_mode(GameConstants.MODE_SURVIVAL):
		return
	if not _all_active_character_slots_selected():
		_refresh_character_selection_ui()
		return
	_play_confirm()
	var context := _build_survival_character_context()
	if game_mode_manager.set_mode(GameConstants.MODE_SURVIVAL, context):
		mode_selected.emit(GameConstants.MODE_SURVIVAL)

func _build_survival_character_context() -> Dictionary:
	var by_slot: Dictionary = {}
	var active_slots := _get_active_character_slots()
	for player_slot in active_slots:
		var character_id := StringName(
			character_selection_by_slot.get(player_slot, &"")
		)
		if character_id.is_empty():
			continue
		by_slot[str(player_slot)] = character_id

	var primary_id := StringName(by_slot.get("1", &""))
	if primary_id.is_empty() and not active_slots.is_empty():
		primary_id = StringName(by_slot.get(str(active_slots[0]), &""))
	return {
		"character_id": primary_id,
		"character_ids_by_slot": by_slot
	}

func _get_active_character_slots() -> Array[int]:
	_resolve_managers()
	if local_multiplayer_manager != null:
		return local_multiplayer_manager.get_active_slots()
	return [1]

func _is_character_slot_active(player_slot: int) -> bool:
	return _get_active_character_slots().has(player_slot)

func _ensure_current_character_slot() -> void:
	var active_slots := _get_active_character_slots()
	if active_slots.is_empty():
		current_character_slot = 1
		return
	if not active_slots.has(current_character_slot):
		current_character_slot = int(active_slots[0])

func _set_current_character_slot(player_slot: int) -> void:
	if current_character_slot == player_slot:
		return
	current_character_slot = player_slot
	_refresh_character_selection_ui()

func _all_active_character_slots_selected() -> bool:
	for player_slot in _get_active_character_slots():
		var character_id := StringName(
			character_selection_by_slot.get(player_slot, &"")
		)
		if not RpgCharacterRegistry.is_character_available(character_id):
			return false
	return true

func _refresh_character_selection_ui() -> void:
	_ensure_current_character_slot()
	var active_slots := _get_active_character_slots()
	for player_slot in range(1, 5):
		var active := active_slots.has(player_slot)
		var selected_id := StringName(
			character_selection_by_slot.get(player_slot, &"")
		)
		var profile := _get_character_profile(selected_id)
		_refresh_character_slot_view(player_slot, active, profile)
	if character_start_button != null:
		character_start_button.disabled = not _all_active_character_slots_selected()

func _refresh_character_slot_view(
	player_slot: int,
	active: bool,
	profile: Dictionary
) -> void:
	var view := character_slot_views.get(player_slot, {}) as Dictionary
	if view.is_empty():
		return
	var selected := active and not profile.is_empty()
	var panel := view.get("panel") as PanelContainer
	if panel != null:
		panel.add_theme_stylebox_override(
			"panel",
			_make_character_slot_style(
				player_slot,
				active,
				selected,
				current_character_slot == player_slot
			)
		)
	var player_label := view.get("player") as Label
	if player_label != null:
		player_label.text = "P%d %s" % [
			player_slot,
			"READY" if selected else ("ACTIVE" if active else "INACTIVE")
		]
		player_label.modulate = _get_character_slot_color(player_slot)

	var portrait := view.get("portrait") as TextureRect
	if portrait != null:
		portrait.texture = _load_character_texture(profile) if selected else null

	var name_label := view.get("name") as Label
	var class_label := view.get("class") as Label
	var stats_label := view.get("stats") as Label
	var passive_label := view.get("passive") as Label
	var super_label := view.get("super") as Label
	if not active:
		_set_character_slot_text(
			name_label,
			class_label,
			stats_label,
			passive_label,
			super_label,
			"Slot empty",
			"",
			"",
			"",
			""
		)
		return
	if not selected:
		_set_character_slot_text(
			name_label,
			class_label,
			stats_label,
			passive_label,
			super_label,
			"Choose a character",
			"",
			"",
			"",
			""
		)
		return
	_set_character_slot_text(
		name_label,
		class_label,
		stats_label,
		passive_label,
		super_label,
		str(profile.get("hero_name", profile.get("display_name", "Survivor"))),
		"%s · %s" % [
			str(profile.get("class_name", "Survivor")),
			str(profile.get("base_weapon_name", "Starter Pistol"))
		],
		"HP %d  ATK %d  DEF %d  SPD %.2f  %s" % [
			int(profile.get("max_hp", 100)),
			int(profile.get("attack", 0)),
			int(profile.get("defense", 0)),
			float(profile.get("speed", 1.0)),
			str(profile.get("difficulty", "Media"))
		],
		"Passive: %s - %s" % [
			str(profile.get("passive_name", "")),
			str(profile.get("passive_description", ""))
		],
		"Super: %s - %s" % [
			str(profile.get("super_name", "")),
			str(profile.get("super_description", ""))
		]
	)

func _set_character_slot_text(
	name_label: Label,
	class_label: Label,
	stats_label: Label,
	passive_label: Label,
	super_label: Label,
	name_text: String,
	class_text: String,
	stats_text: String,
	passive_text: String,
	super_text: String
) -> void:
	if name_label != null:
		name_label.text = name_text
	if class_label != null:
		class_label.text = class_text
	if stats_label != null:
		stats_label.text = stats_text
	if passive_label != null:
		passive_label.text = passive_text
	if super_label != null:
		super_label.text = super_text

func _get_character_profile(character_id: StringName) -> Dictionary:
	if character_id.is_empty():
		return {}
	if character_profile_by_id.has(character_id):
		return (character_profile_by_id[character_id] as Dictionary).duplicate(true)
	if RpgCharacterRegistry.is_character_available(character_id):
		return RpgCharacterRegistry.get_character_profile(character_id)
	return {}

func _load_character_texture(profile: Dictionary) -> Texture2D:
	if profile.is_empty():
		return null
	var character_id := StringName(profile.get("id", &""))
	var path := str(profile.get("portrait_hud_path", ""))
	if path.is_empty():
		path = str(profile.get("portrait_full_path", ""))
	if path.is_empty():
		return _create_character_placeholder_texture(profile)
	var cache_key := "%s:%s" % [str(character_id), path]
	if character_texture_cache.has(cache_key):
		return character_texture_cache[cache_key] as Texture2D
	var extension := path.get_extension().to_lower()
	var texture: Texture2D = null
	if ["png", "jpg", "jpeg", "webp"].has(extension):
		texture = _load_bitmap_texture(path)
	if texture == null:
		texture = _create_character_placeholder_texture(profile)
	character_texture_cache[cache_key] = texture
	return texture

func _load_bitmap_texture(path: String) -> Texture2D:
	var image := Image.new()
	if image.load(path) != OK:
		return null
	return ImageTexture.create_from_image(image)

func _create_character_placeholder_texture(profile: Dictionary) -> Texture2D:
	var size := 96
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var primary := Color(profile.get("palette_primary", Color(0.18, 0.74, 0.95, 1.0)))
	var secondary := Color(profile.get("palette_secondary", Color(0.08, 0.10, 0.14, 1.0)))
	var accent := Color(profile.get("palette_accent", Color(1.0, 0.80, 0.34, 1.0)))
	image.fill(secondary.darkened(0.28))
	var center := Vector2(size * 0.5, size * 0.48)
	for y in range(size):
		for x in range(size):
			var point := Vector2(float(x), float(y))
			var distance := point.distance_to(center)
			if distance <= 34.0:
				image.set_pixel(x, y, primary)
			if distance <= 22.0 and y < 50:
				image.set_pixel(x, y, primary.lightened(0.16))
			if absf(point.x - center.x) + absf(point.y - 68.0) <= 24.0:
				image.set_pixel(x, y, primary.darkened(0.16))
			if distance >= 32.0 and distance <= 35.0:
				image.set_pixel(x, y, Color(0.04, 0.05, 0.06, 1.0))
	for x in range(18, 78):
		for y in range(78, 84):
			image.set_pixel(x, y, accent)
	return ImageTexture.create_from_image(image)

func _make_character_slot_style(
	player_slot: int,
	active: bool,
	selected: bool,
	current: bool
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = (
		Color(0.055, 0.075, 0.105, 0.96)
		if active
		else Color(0.035, 0.040, 0.052, 0.82)
	)
	var border_color := Color(0.18, 0.23, 0.30, 1.0)
	if active:
		border_color = _get_character_slot_color(player_slot).darkened(0.10)
	if selected:
		border_color = _get_character_slot_color(player_slot).lightened(0.12)
	if current:
		border_color = Color.WHITE
	style.border_color = border_color
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 8
	style.content_margin_top = 6
	style.content_margin_right = 8
	style.content_margin_bottom = 6
	return style

func _get_character_slot_color(player_slot: int) -> Color:
	var index := clampi(player_slot - 1, 0, CHARACTER_SLOT_COLORS.size() - 1)
	return CHARACTER_SLOT_COLORS[index]

func _on_character_slot_gui_input(
	event: InputEvent,
	player_slot: int
) -> void:
	if not event is InputEventMouseButton:
		return
	var button_event := event as InputEventMouseButton
	if not button_event.pressed or button_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if _is_character_slot_active(player_slot):
		_set_current_character_slot(player_slot)
		_play_focus()

func _player_slot_from_input_event(event: InputEvent) -> int:
	if event is InputEventJoypadButton:
		var button_event := event as InputEventJoypadButton
		if button_event.pressed:
			return button_event.device + 1
	if event is InputEventJoypadMotion:
		var motion_event := event as InputEventJoypadMotion
		if absf(motion_event.axis_value) > 0.50:
			return motion_event.device + 1
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo:
			return 1
	return 0

func _on_active_slots_changed(_active_slots: Array[int]) -> void:
	if character_select_panel != null and character_select_panel.visible:
		_refresh_character_selection_ui()

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
	if settings_panel != null:
		settings_panel.refresh_all_controls()

func _refresh_settings_controls() -> void:
	if settings_panel != null:
		volume_sliders = settings_panel.volume_sliders
		visual_controls = settings_panel.visual_controls
		settings_panel.refresh_all_controls()

func _open_settings(initial_tab: StringName = &"audio") -> void:
	_resolve_managers()
	_refresh_settings_controls()
	if primary_panel != null:
		primary_panel.hide()
	if character_select_panel != null:
		character_select_panel.hide()
	if settings_panel != null:
		settings_panel.open(initial_tab)

func _open_visual_settings() -> void:
	_open_settings(&"video")

func _close_visual_settings(grab_focus: bool = true) -> void:
	if settings_panel == null or primary_panel == null:
		return
	settings_panel.close(false)
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
	if settings_panel != null:
		settings_panel.refresh_all_controls()

func _on_settings_panel_closed() -> void:
	if primary_panel == null:
		return
	primary_panel.show()
	if visible and continue_button != null:
		continue_button.grab_focus()

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
