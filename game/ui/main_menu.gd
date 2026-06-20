extends CanvasLayer
class_name MainMenu

signal mode_selected(mode_id: StringName)

const CHARACTER_SLOT_COLORS: Array[Color] = [
	Color(0.18, 0.74, 0.95, 1.0),
	Color(0.95, 0.42, 0.34, 1.0),
	Color(0.52, 0.86, 0.32, 1.0),
	Color(0.94, 0.78, 0.28, 1.0)
]
const CHARACTER_SELECT_CARD_SCRIPT := preload(
	"res://game/ui/character_select_card.gd"
)
const MENU_NAVIGATION_SCRIPT := preload(
	"res://game/ui/menu_navigation_controller.gd"
)

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
var character_card_by_id: Dictionary = {}
var character_start_button: Button
var character_back_button: Button
var character_slots_grid: GridContainer
var character_roster_grid: GridContainer
var character_roster_scroll: ScrollContainer
var character_detail_panel: CharacterDetailPanel
var main_menu_navigation
var character_navigation
var character_profiles: Array[Dictionary] = []
var character_profile_by_id: Dictionary = {}
var character_texture_cache: Dictionary = {}
var character_weapon_cache: Dictionary = {}
var character_slot_views: Dictionary = {}
var character_selection_by_slot: Dictionary = {}
# Each active slot browses the roster with its own cursor (a roster index). Slot
# 1 mirrors the keyboard/mouse focus; extra pads drive their own slot's cursor.
var character_cursor_by_slot: Dictionary = {}
# One MenuNavigationController per extra slot (2..max), so every pad navigates
# the roster independently without stealing player one's focus.
var character_navigation_by_slot: Dictionary = {}
# Slot driven by keyboard/mouse/pad-0. Stays at player one in local co-op.
var current_character_slot: int = 1
var focused_character_id: StringName = &""

var game_mode_manager: GameModeManager
var save_manager: SaveManager
var progression_manager: ProgressionManager
var visual_settings_manager: VisualSettingsManager
var local_multiplayer_manager: LocalMultiplayerManager

func _ready() -> void:
	add_to_group("main_menu")
	layer = 20
	_create_ui()
	var size_callback := Callable(self, "_refresh_character_select_layout")
	if not get_viewport().size_changed.is_connected(size_callback):
		get_viewport().size_changed.connect(size_callback)
	call_deferred("_initialize")

func _input(event: InputEvent) -> void:
	if character_select_panel == null or not character_select_panel.visible:
		return
	var player_slot := _player_slot_from_input_event(event)
	if player_slot <= 0:
		return
	if not _is_character_slot_active(player_slot):
		return
	# Any active player can launch once everyone is ready.
	if _is_character_start_event(event):
		if _all_active_character_slots_selected():
			_start_survival_with_selected_characters()
		else:
			_refresh_character_selection_ui()
		get_viewport().set_input_as_handled()
		return
	# Player one (keyboard / mouse / pad 0) keeps Godot's focus-driven flow:
	# directional navigation and confirm are handled by the focus system and the
	# card's pressed signal, so nothing extra is needed here.
	if player_slot == 1:
		return
	# Extra pads confirm their own slot directly. Directional moves are handled by
	# that slot's dedicated navigation controller. We consume the confirm so it can
	# never leak into player one's focused button.
	if _is_character_confirm_event(event):
		var character_id := _character_id_at_index(
			_character_cursor_index(player_slot)
		)
		if not character_id.is_empty():
			_assign_character_to_slot(player_slot, character_id)
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if (
		is_open()
		and event.is_action_pressed(&"ui_cancel")
		and character_select_panel != null
		and character_select_panel.visible
	):
		_close_character_select()
		get_viewport().set_input_as_handled()
		return
	if (
		is_open()
		and event.is_action_pressed(&"ui_cancel")
		and visual_settings_panel != null
		and visual_settings_panel.visible
	):
		_close_visual_settings()
		get_viewport().set_input_as_handled()
		return
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
	primary_panel.custom_minimum_size = Vector2(540.0, 700.0)
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
		"Infinite Arena",
		Callable(self, "_select_mode").bind(GameConstants.MODE_INFINITE_ARENA)
	)
	content.add_child(first_mode_button)
	content.add_child(_create_button(
		"Zombie Survival",
		Callable(self, "_select_mode").bind(GameConstants.MODE_SURVIVAL)
	))
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
	_create_main_menu_navigation()
	_create_settings_panel(center)
	_create_character_select_panel(backdrop)

func _create_main_menu_navigation() -> void:
	main_menu_navigation = MENU_NAVIGATION_SCRIPT.new()
	main_menu_navigation.name = "MainMenuNavigation"
	main_menu_navigation.owner_control = primary_panel
	main_menu_navigation.back_callback = Callable(self, "_handle_main_menu_back")
	main_menu_navigation.set_focus_controls(menu_buttons)
	add_child(main_menu_navigation)

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
	character_select_panel.custom_minimum_size = Vector2.ZERO
	character_select_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	character_select_panel.offset_left = 20.0
	character_select_panel.offset_top = 16.0
	character_select_panel.offset_right = -20.0
	character_select_panel.offset_bottom = -16.0
	character_select_panel.add_theme_stylebox_override(
		"panel",
		_make_character_select_panel_style()
	)
	parent.add_child(character_select_panel)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	character_select_panel.add_child(margin)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 6)
	margin.add_child(content)

	var title := Label.new()
	title.text = "CHARACTER SELECT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.modulate = Color(0.78, 0.94, 1.0, 1.0)
	content.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Pick a survivor for each active slot, then start the zombie run"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.modulate = Color(0.72, 0.80, 0.88, 1.0)
	content.add_child(subtitle)

	character_profiles = RpgCharacterRegistry.get_character_profiles()
	character_profile_by_id.clear()
	for profile in character_profiles:
		var character_id := StringName(profile.get("id", &""))
		if not character_id.is_empty():
			character_profile_by_id[character_id] = profile

	character_slots_grid = GridContainer.new()
	character_slots_grid.columns = 4
	character_slots_grid.add_theme_constant_override("h_separation", 8)
	character_slots_grid.add_theme_constant_override("v_separation", 6)
	content.add_child(character_slots_grid)
	for player_slot in range(1, 5):
		character_slots_grid.add_child(_create_character_slot_panel(player_slot))

	# The roster row (cards + dossier) lives in its own scroll region so it can
	# shrink at any resolution while the slot row above and the action buttons
	# below stay pinned and always visible.
	character_roster_scroll = ScrollContainer.new()
	character_roster_scroll.name = "CharacterRosterScroll"
	character_roster_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	character_roster_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	character_roster_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	character_roster_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	content.add_child(character_roster_scroll)

	var roster_content := VBoxContainer.new()
	roster_content.name = "CharacterRosterContent"
	roster_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roster_content.add_theme_constant_override("separation", 8)
	character_roster_scroll.add_child(roster_content)

	character_roster_grid = GridContainer.new()
	character_roster_grid.columns = 4
	character_roster_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	character_roster_grid.add_theme_constant_override("h_separation", 8)
	character_roster_grid.add_theme_constant_override("v_separation", 8)
	roster_content.add_child(character_roster_grid)

	for profile in character_profiles:
		var character_id := StringName(profile.get("id", &""))
		var button := CHARACTER_SELECT_CARD_SCRIPT.new() as Button
		button.name = "Character%sButton" % str(character_id).capitalize()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.call(
			"set_profile",
			profile,
			_load_character_texture(profile),
			_load_character_weapon_data(profile)
		)
		button.pressed.connect(_assign_character_to_current_slot.bind(character_id))
		button.focus_entered.connect(_on_character_card_focused.bind(character_id))
		button.mouse_entered.connect(_preview_character.bind(character_id))
		character_roster_grid.add_child(button)
		character_card_buttons.append(button)
		character_card_by_id[character_id] = button

	character_detail_panel = CharacterDetailPanel.new()
	character_detail_panel.name = "CharacterDetailPanel"
	character_detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roster_content.add_child(character_detail_panel)

	var action_row := HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.add_theme_constant_override("separation", 14)
	content.add_child(action_row)

	character_start_button = Button.new()
	character_start_button.text = "Start Zombie Survival"
	character_start_button.custom_minimum_size = Vector2(300.0, 46.0)
	character_start_button.add_theme_font_size_override("font_size", 17)
	character_start_button.disabled = true
	character_start_button.pressed.connect(_start_survival_with_selected_characters)
	character_start_button.focus_entered.connect(_play_focus)
	action_row.add_child(character_start_button)

	character_back_button = Button.new()
	character_back_button.text = "Back / Esc / B"
	character_back_button.custom_minimum_size = Vector2(240.0, 46.0)
	character_back_button.add_theme_font_size_override("font_size", 17)
	character_back_button.pressed.connect(_close_character_select)
	character_back_button.focus_entered.connect(_play_focus)
	action_row.add_child(character_back_button)
	_create_character_navigation()
	_refresh_character_select_layout()
	character_select_panel.hide()

func _create_character_navigation() -> void:
	character_navigation = MENU_NAVIGATION_SCRIPT.new()
	character_navigation.name = "CharacterSelectNavigation"
	character_navigation.owner_control = character_select_panel
	# Player one owns the keyboard/mouse and pad 0 (device <= 0); extra pads are
	# routed to their own per-slot controllers instead of moving this focus.
	character_navigation.device_filter = Callable(self, "_is_player_one_device")
	character_navigation.back_callback = Callable(
		self,
		"_handle_character_select_back"
	)
	character_navigation.move_callback = Callable(
		self,
		"_move_character_select_focus"
	)
	var controls: Array[Control] = []
	for button in character_card_buttons:
		controls.append(button)
	if character_start_button != null:
		controls.append(character_start_button)
	if character_back_button != null:
		controls.append(character_back_button)
	character_navigation.set_focus_controls(controls)
	add_child(character_navigation)
	_create_extra_slot_navigation()

func _create_extra_slot_navigation() -> void:
	var max_slots := 4
	if local_multiplayer_manager != null:
		max_slots = local_multiplayer_manager.max_players
	for player_slot in range(2, max_slots + 1):
		var navigation = MENU_NAVIGATION_SCRIPT.new()
		navigation.name = "CharacterSelectNavigationP%d" % player_slot
		navigation.owner_control = character_select_panel
		navigation.device_filter = Callable(
			self,
			"_is_slot_device"
		).bind(player_slot)
		navigation.move_callback = Callable(
			self,
			"_move_character_cursor"
		).bind(player_slot)
		add_child(navigation)
		character_navigation_by_slot[player_slot] = navigation

func _is_player_one_device(device: int) -> bool:
	return device <= 0

func _is_slot_device(device: int, player_slot: int) -> bool:
	return device == player_slot - 1

func _create_character_slot_panel(player_slot: int) -> Control:
	var panel := PanelContainer.new()
	panel.name = "Player%dSelectionSlot" % player_slot
	panel.custom_minimum_size = Vector2(240.0, 200.0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(_on_character_slot_gui_input.bind(player_slot))

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 2)
	panel.add_child(content)

	var player_label := Label.new()
	player_label.add_theme_font_size_override("font_size", 11)
	player_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(player_label)

	# The animated gameplay preview is the slot's main visual: it shows the
	# character the player is currently cycling through in the roster below.
	var preview := CharacterGameplayPreview.new()
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(preview)
	preview.custom_minimum_size = Vector2(0.0, 124.0)

	var name_label := Label.new()
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.max_lines_visible = 1
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	content.add_child(name_label)

	var class_label := Label.new()
	class_label.add_theme_font_size_override("font_size", 10)
	class_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	class_label.max_lines_visible = 1
	class_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	content.add_child(class_label)

	var stats_label := _create_character_detail_label(9, 1)
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(stats_label)

	character_slot_views[player_slot] = {
		"panel": panel,
		"preview": preview,
		"player": player_label,
		"name": name_label,
		"class": class_label,
		"stats": stats_label
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
		else GameConstants.MODE_INFINITE_ARENA
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
		else GameConstants.MODE_INFINITE_ARENA
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
		GameConstants.MODE_INFINITE_ARENA:
			return "Infinite Arena"
		GameConstants.MODE_SURVIVAL:
			return "Zombie Survival"
		GameConstants.MODE_DUNGEON:
			return "Procedural Dungeon"
		GameConstants.MODE_TOWER_DEFENSE:
			return "Tower Defense"
		_:
			return "Infinite Arena"

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
	if focused_character_id.is_empty() and not character_profiles.is_empty():
		focused_character_id = StringName(character_profiles[0].get("id", &""))
	_sync_character_cursors()
	_refresh_character_select_layout()
	_refresh_character_selection_ui()
	character_select_panel.show()
	if character_navigation != null:
		var preferred_focus: Control = null
		if not character_card_buttons.is_empty():
			preferred_focus = character_card_buttons[0]
		character_navigation.ensure_focus(preferred_focus)

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
	character_selection_by_slot[player_slot] = character_id
	character_cursor_by_slot[player_slot] = _roster_index_of(character_id)
	if player_slot == current_character_slot:
		focused_character_id = character_id
	_play_confirm()
	_refresh_character_selection_ui()

func _move_character_cursor(direction: Vector2i, player_slot: int) -> bool:
	if not _is_character_slot_active(player_slot):
		return false
	if character_card_buttons.is_empty():
		return false
	var current_index := _character_cursor_index(player_slot)
	var next_index := _resolve_character_grid_index(current_index, direction)
	next_index = clampi(next_index, 0, character_card_buttons.size() - 1)
	character_cursor_by_slot[player_slot] = next_index
	_play_focus()
	_refresh_character_selection_ui()
	return true

func _sync_character_cursors() -> void:
	# Give every active slot a valid starting cursor: its committed pick if any,
	# otherwise the first roster card. Player one stays aligned with its focus.
	for player_slot in _get_active_character_slots():
		if character_cursor_by_slot.has(player_slot):
			continue
		var committed := StringName(
			character_selection_by_slot.get(player_slot, &"")
		)
		character_cursor_by_slot[player_slot] = (
			_roster_index_of(committed)
			if RpgCharacterRegistry.is_character_available(committed)
			else 0
		)

func _character_cursor_index(player_slot: int) -> int:
	var index := int(character_cursor_by_slot.get(player_slot, 0))
	return clampi(index, 0, maxi(character_card_buttons.size() - 1, 0))

func _roster_index_of(character_id: StringName) -> int:
	var card := character_card_by_id.get(character_id) as Button
	var index := character_card_buttons.find(card)
	return index if index >= 0 else 0

func _character_id_at_index(index: int) -> StringName:
	if index < 0 or index >= character_profiles.size():
		return &""
	return StringName(character_profiles[index].get("id", &""))

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
	# Lets a solo keyboard/mouse player retarget which slot they are filling. Pad
	# players keep their own independent cursors regardless of this value.
	if current_character_slot == player_slot:
		return
	current_character_slot = player_slot
	var selected_id := StringName(
		character_selection_by_slot.get(current_character_slot, &"")
	)
	if RpgCharacterRegistry.is_character_available(selected_id):
		focused_character_id = selected_id
		var card := character_card_by_id.get(selected_id) as Button
		if card != null and card.is_inside_tree():
			card.grab_focus()
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
		_refresh_character_slot_view(
			player_slot,
			active,
			profile,
			_slot_preview_profile(player_slot, profile)
		)
	_refresh_character_card_states()
	_refresh_character_detail_panel()
	if character_start_button != null:
		character_start_button.disabled = not _all_active_character_slots_selected()
	_refresh_character_navigation_controls()

func _refresh_character_navigation_controls() -> void:
	if character_navigation == null:
		return
	var controls: Array[Control] = []
	for button in character_card_buttons:
		controls.append(button)
	if character_start_button != null:
		controls.append(character_start_button)
	if character_back_button != null:
		controls.append(character_back_button)
	character_navigation.set_focus_controls(controls)

func _refresh_character_select_layout() -> void:
	if character_select_panel == null:
		return
	var viewport_width := get_viewport().get_visible_rect().size.x
	if character_slots_grid != null:
		character_slots_grid.columns = 2 if viewport_width < 1120.0 else 4
	var card_width := 190.0 if viewport_width < 760.0 else 210.0
	for card in character_card_buttons:
		card.custom_minimum_size = Vector2(card_width, 162.0)
	if character_roster_grid != null:
		# The roster fills the whole row now that the dossier is gone: fit as many
		# columns as the width allows and let the cards expand to share the space.
		var available := maxf(viewport_width - 80.0, card_width)
		var card_count := maxi(character_card_buttons.size(), 1)
		var fit := int(available / (card_width + 8.0))
		character_roster_grid.columns = clampi(fit, 1, card_count)

func _move_character_select_focus(direction: Vector2i) -> bool:
	if character_select_panel == null or not character_select_panel.visible:
		return false
	if character_card_buttons.is_empty():
		return false
	var current_index := _current_character_card_focus_index()
	if current_index < 0:
		current_index = 0
	var next_index := _resolve_character_grid_index(current_index, direction)
	next_index = clampi(next_index, 0, character_card_buttons.size() - 1)
	var next_button := character_card_buttons[next_index]
	next_button.grab_focus()
	if character_roster_scroll != null:
		character_roster_scroll.ensure_control_visible(next_button)
	return true

func _current_character_card_focus_index() -> int:
	var current := get_viewport().gui_get_focus_owner()
	var current_index := character_card_buttons.find(current)
	if current_index >= 0:
		return current_index
	if RpgCharacterRegistry.is_character_available(focused_character_id):
		var focused_button := character_card_by_id.get(focused_character_id) as Button
		current_index = character_card_buttons.find(focused_button)
		if current_index >= 0:
			return current_index
	return 0

func _resolve_character_grid_index(
	current_index: int,
	direction: Vector2i
) -> int:
	var card_count := character_card_buttons.size()
	if card_count <= 1:
		return 0
	var columns := (
		character_roster_grid.columns
		if character_roster_grid != null
		else card_count
	)
	columns = clampi(columns, 1, card_count)
	var row := int(current_index / columns)
	var column := current_index % columns
	var row_count := ceili(float(card_count) / float(columns))
	if direction.x != 0:
		var row_start := row * columns
		var row_length := mini(columns, card_count - row_start)
		var row_offset := current_index - row_start
		return row_start + posmod(row_offset + direction.x, row_length)
	if direction.y != 0:
		var target_row := posmod(row + direction.y, row_count)
		var target_start := target_row * columns
		var target_length := mini(columns, card_count - target_start)
		return target_start + mini(column, target_length - 1)
	return current_index

func _handle_main_menu_back() -> bool:
	return false

func _handle_character_select_back() -> bool:
	_close_character_select()
	return true

func _refresh_character_slot_view(
	player_slot: int,
	active: bool,
	profile: Dictionary,
	preview_profile: Dictionary
) -> void:
	var view := character_slot_views.get(player_slot, {}) as Dictionary
	if view.is_empty():
		return
	var selected := active and not profile.is_empty()
	var panel := view.get("panel") as PanelContainer
	if panel != null:
		# Every active slot is independently in play, so the highlight comes from
		# the slot's own colour/commit state rather than a single "current" slot.
		panel.add_theme_stylebox_override(
			"panel",
			_make_character_slot_style(
				player_slot,
				active,
				selected,
				false
			)
		)
	var player_label := view.get("player") as Label
	if player_label != null:
		player_label.text = "P%d %s" % [
			player_slot,
			"READY" if selected else ("ACTIVE" if active else "INACTIVE")
		]
		player_label.modulate = _get_character_slot_color(player_slot)

	# The slot being chosen shows the live roster hover; others show their
	# committed pick. Inactive slots stay blank.
	var shown := preview_profile if active else {}
	var preview := view.get("preview") as Control
	if preview != null:
		if shown.is_empty():
			preview.call("set_profile", {}, null)
		else:
			preview.call(
				"set_profile",
				shown,
				_load_character_weapon_data(shown)
			)

	var name_label := view.get("name") as Label
	var class_label := view.get("class") as Label
	var stats_label := view.get("stats") as Label
	if not active:
		_set_character_slot_text(name_label, class_label, stats_label, "Slot empty", "", "")
		return
	if shown.is_empty():
		_set_character_slot_text(name_label, class_label, stats_label, "Choose a character", "", "")
		return
	_set_character_slot_text(
		name_label,
		class_label,
		stats_label,
		str(shown.get("hero_name", shown.get("display_name", "Survivor"))),
		"%s · %s" % [
			str(shown.get("class_name", "Survivor")),
			str(shown.get("base_weapon_name", "Starter Pistol"))
		],
		"HP %d  ATK %d  DEF %d  SPD %.2f  %s" % [
			int(shown.get("max_hp", 100)),
			int(shown.get("attack", 0)),
			int(shown.get("defense", 0)),
			float(shown.get("speed", 1.0)),
			str(shown.get("difficulty", "Media"))
		]
	)

func _refresh_character_card_states() -> void:
	var active_slots := _get_active_character_slots()
	for index in range(character_profiles.size()):
		var character_id := StringName(character_profiles[index].get("id", &""))
		var card := character_card_by_id.get(character_id) as Button
		if card == null:
			continue
		var committed_slots: Array[int] = []
		var hovering_slots: Array[int] = []
		for player_slot in active_slots:
			var selected_id := StringName(
				character_selection_by_slot.get(player_slot, &"")
			)
			if selected_id == character_id:
				committed_slots.append(player_slot)
			if _character_cursor_index(player_slot) == index:
				hovering_slots.append(player_slot)
		card.call("set_selection_state", committed_slots, hovering_slots)

func _on_character_card_focused(character_id: StringName) -> void:
	_play_focus()
	_preview_character(character_id)

func _preview_character(character_id: StringName) -> void:
	if not RpgCharacterRegistry.is_character_available(character_id):
		return
	focused_character_id = character_id
	# The focus owner is player one's cursor: keep its slot aligned with it.
	character_cursor_by_slot[current_character_slot] = _roster_index_of(character_id)
	# _refresh_character_selection_ui also refreshes the shared detail panel.
	_refresh_character_selection_ui()

func _refresh_character_detail_panel() -> void:
	if character_detail_panel == null or not character_detail_panel.is_node_ready():
		return
	var profile := _get_character_profile(focused_character_id)
	if profile.is_empty() and not character_profiles.is_empty():
		profile = character_profiles[0].duplicate(true)
	if profile.is_empty():
		character_detail_panel.set_profile({})
		return
	character_detail_panel.set_profile(
		profile,
		_load_character_weapon_data(profile)
	)

func _slot_preview_profile(
	player_slot: int,
	committed_profile: Dictionary
) -> Dictionary:
	# Each active slot previews the character its own cursor is browsing; the
	# committed pick is the fallback when the cursor has nowhere valid to point.
	var cursor_id := _character_id_at_index(_character_cursor_index(player_slot))
	if RpgCharacterRegistry.is_character_available(cursor_id):
		return _get_character_profile(cursor_id)
	return committed_profile

func _set_character_slot_text(
	name_label: Label,
	class_label: Label,
	stats_label: Label,
	name_text: String,
	class_text: String,
	stats_text: String
) -> void:
	if name_label != null:
		name_label.text = name_text
	if class_label != null:
		class_label.text = class_text
	if stats_label != null:
		stats_label.text = stats_text

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
	for path_key in [
		"portrait_full_path",
		"portrait_hud_path",
		"gameplay_sprite_path"
	]:
		var path := str(profile.get(path_key, ""))
		if path.is_empty():
			continue
		var cache_key := "%s:%s" % [str(character_id), path]
		if character_texture_cache.has(cache_key):
			return character_texture_cache[cache_key] as Texture2D
		var texture := _load_texture_resource(path)
		if texture != null:
			character_texture_cache[cache_key] = texture
			return texture
	var fallback_key := "%s:generated_menu_preview" % str(character_id)
	if character_texture_cache.has(fallback_key):
		return character_texture_cache[fallback_key] as Texture2D
	var fallback := _create_character_placeholder_texture(profile)
	character_texture_cache[fallback_key] = fallback
	return fallback

func _load_character_weapon_data(profile: Dictionary) -> WeaponData:
	if profile.is_empty():
		return null
	var weapon_id := StringName(profile.get("base_weapon_id", &""))
	if weapon_id.is_empty():
		return null
	if character_weapon_cache.has(weapon_id):
		return character_weapon_cache[weapon_id] as WeaponData
	var weapon_data := RpgCharacterRegistry.load_base_weapon(weapon_id)
	character_weapon_cache[weapon_id] = weapon_data
	return weapon_data

func _load_bitmap_texture(path: String) -> Texture2D:
	var image := Image.new()
	if image.load(path) != OK:
		return null
	return ImageTexture.create_from_image(image)

func _load_texture_resource(path: String) -> Texture2D:
	if path.is_empty() or not FileAccess.file_exists(path):
		return null
	if ResourceLoader.exists(path):
		var resource := ResourceLoader.load(path)
		if resource is Texture2D:
			return resource as Texture2D
	var extension := path.get_extension().to_lower()
	if ["png", "jpg", "jpeg", "webp"].has(extension):
		return _load_bitmap_texture(path)
	return null

func _create_character_placeholder_texture(profile: Dictionary) -> Texture2D:
	var size := 128
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var primary := Color(profile.get("palette_primary", Color(0.18, 0.74, 0.95, 1.0)))
	var secondary := Color(profile.get("palette_secondary", Color(0.08, 0.10, 0.14, 1.0)))
	var accent := Color(profile.get("palette_accent", Color(1.0, 0.80, 0.34, 1.0)))
	var character_id := StringName(profile.get("id", &""))
	var weapon_id := StringName(profile.get("base_weapon_id", &""))
	image.fill(secondary.darkened(0.35))
	var center := Vector2(size * 0.5, size * 0.52)
	for y in range(size):
		for x in range(size):
			var point := Vector2(float(x), float(y))
			var distance := point.distance_to(Vector2(size * 0.5, size * 0.5))
			var vignette := clampf(distance / 82.0, 0.0, 1.0)
			if (int(x / 12) + int(y / 12)) % 2 == 0:
				image.set_pixel(x, y, image.get_pixel(x, y).lightened(0.025))
			if vignette > 0.45:
				image.set_pixel(x, y, image.get_pixel(x, y).darkened((vignette - 0.45) * 0.55))
	_paint_ellipse(image, center + Vector2(0.0, 35.0), Vector2(38.0, 12.0), Color(0.0, 0.0, 0.0, 0.42))
	_paint_ellipse(image, center + Vector2(0.0, -4.0), Vector2(24.0, 34.0), Color(0.015, 0.018, 0.022, 1.0))
	_paint_ellipse(image, center + Vector2(0.0, -2.0), Vector2(18.0, 29.0), primary.darkened(0.05))
	_paint_disc(image, center + Vector2(0.0, -34.0), 14.0, Color(0.018, 0.020, 0.025, 1.0))
	_paint_disc(image, center + Vector2(0.0, -35.0), 10.0, secondary.lightened(0.16))
	_paint_line(image, center + Vector2(-15.0, -12.0), center + Vector2(19.0, 22.0), 5.0, accent.darkened(0.18))
	_paint_line(image, center + Vector2(15.0, -12.0), center + Vector2(-18.0, 22.0), 4.0, accent.darkened(0.30))
	match character_id:
		&"ranger":
			_paint_line(image, center + Vector2(-17.0, -37.0), center + Vector2(0.0, -55.0), 5.0, Color(0.012, 0.014, 0.018, 1.0))
			_paint_line(image, center + Vector2(17.0, -37.0), center + Vector2(0.0, -55.0), 5.0, Color(0.012, 0.014, 0.018, 1.0))
		&"pistoliere":
			_paint_rect(image, Rect2i(43, 31, 42, 8), accent)
		&"berserker":
			_paint_rect(image, Rect2i(35, 49, 58, 13), Color(0.015, 0.018, 0.022, 1.0))
			_paint_rect(image, Rect2i(38, 51, 52, 5), accent)
		&"spadaccino":
			_paint_line(image, center + Vector2(13.0, -50.0), center + Vector2(36.0, -40.0), 4.0, accent.lightened(0.1))
		&"mago":
			_paint_line(image, center + Vector2(26.0, -48.0), center + Vector2(27.0, 34.0), 5.0, Color(0.012, 0.014, 0.018, 1.0))
			_paint_disc(image, center + Vector2(26.0, -51.0), 7.0, accent)
		&"domatrice":
			_paint_rect(image, Rect2i(36, 50, 17, 42), secondary.lightened(0.12))
			_paint_disc(image, center + Vector2(-14.0, -47.0), 4.0, accent)
		&"licantropo":
			_paint_line(image, center + Vector2(-22.0, -7.0), center + Vector2(-39.0, 22.0), 6.0, accent)
			_paint_line(image, center + Vector2(22.0, -7.0), center + Vector2(39.0, 22.0), 6.0, accent)
	_paint_placeholder_weapon(image, center, weapon_id, primary, accent)
	return ImageTexture.create_from_image(image)

func _paint_placeholder_weapon(
	image: Image,
	center: Vector2,
	weapon_id: StringName,
	primary: Color,
	accent: Color
) -> void:
	match weapon_id:
		&"bow":
			_paint_line(image, center + Vector2(23.0, -18.0), center + Vector2(42.0, 18.0), 4.0, primary.darkened(0.32))
			_paint_line(image, center + Vector2(21.0, 0.0), center + Vector2(50.0, 0.0), 2.0, accent)
		&"axe":
			_paint_line(image, center + Vector2(20.0, -7.0), center + Vector2(53.0, 25.0), 7.0, primary.darkened(0.35))
			_paint_ellipse(image, center + Vector2(52.0, 22.0), Vector2(12.0, 17.0), accent)
		&"sword":
			_paint_line(image, center + Vector2(16.0, 2.0), center + Vector2(58.0, -24.0), 5.0, accent.lightened(0.1))
			_paint_line(image, center + Vector2(17.0, 3.0), center + Vector2(7.0, 14.0), 7.0, primary.darkened(0.36))
		&"staff":
			_paint_line(image, center + Vector2(26.0, -45.0), center + Vector2(34.0, 35.0), 5.0, primary.darkened(0.35))
			_paint_disc(image, center + Vector2(25.0, -47.0), 8.0, Color(accent, 0.72))
		&"slingshot":
			_paint_line(image, center + Vector2(20.0, 0.0), center + Vector2(45.0, -17.0), 5.0, primary.darkened(0.35))
			_paint_line(image, center + Vector2(45.0, -17.0), center + Vector2(56.0, -31.0), 4.0, primary.darkened(0.35))
			_paint_line(image, center + Vector2(45.0, -17.0), center + Vector2(61.0, -7.0), 4.0, primary.darkened(0.35))
			_paint_line(image, center + Vector2(56.0, -31.0), center + Vector2(61.0, -7.0), 2.0, accent)
		&"claws":
			for index in range(3):
				_paint_line(image, center + Vector2(24.0 + index * 6.0, -3.0), center + Vector2(42.0 + index * 6.0, 21.0), 3.0, accent)
		_:
			_paint_line(image, center + Vector2(20.0, -3.0), center + Vector2(55.0, -3.0), 7.0, primary.darkened(0.35))
			_paint_line(image, center + Vector2(27.0, -3.0), center + Vector2(52.0, -3.0), 3.0, accent)

func _paint_disc(image: Image, center: Vector2, radius: float, color: Color) -> void:
	var min_x := clampi(floori(center.x - radius), 0, image.get_width() - 1)
	var max_x := clampi(ceili(center.x + radius), 0, image.get_width() - 1)
	var min_y := clampi(floori(center.y - radius), 0, image.get_height() - 1)
	var max_y := clampi(ceili(center.y + radius), 0, image.get_height() - 1)
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			if Vector2(float(x), float(y)).distance_to(center) <= radius:
				image.set_pixel(x, y, color)

func _paint_ellipse(image: Image, center: Vector2, radius: Vector2, color: Color) -> void:
	var min_x := clampi(floori(center.x - radius.x), 0, image.get_width() - 1)
	var max_x := clampi(ceili(center.x + radius.x), 0, image.get_width() - 1)
	var min_y := clampi(floori(center.y - radius.y), 0, image.get_height() - 1)
	var max_y := clampi(ceili(center.y + radius.y), 0, image.get_height() - 1)
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var offset := Vector2(float(x), float(y)) - center
			var normalized := (
				(offset.x * offset.x) / maxf(radius.x * radius.x, 1.0)
				+ (offset.y * offset.y) / maxf(radius.y * radius.y, 1.0)
			)
			if normalized <= 1.0:
				image.set_pixel(x, y, color)

func _paint_rect(image: Image, rect: Rect2i, color: Color) -> void:
	var min_x := clampi(rect.position.x, 0, image.get_width() - 1)
	var max_x := clampi(rect.position.x + rect.size.x, 0, image.get_width() - 1)
	var min_y := clampi(rect.position.y, 0, image.get_height() - 1)
	var max_y := clampi(rect.position.y + rect.size.y, 0, image.get_height() - 1)
	for y in range(min_y, max_y):
		for x in range(min_x, max_x):
			image.set_pixel(x, y, color)

func _paint_line(
	image: Image,
	start: Vector2,
	end: Vector2,
	width: float,
	color: Color
) -> void:
	var direction := end - start
	var length := maxf(direction.length(), 1.0)
	var steps := ceili(length * 1.35)
	for step in range(steps + 1):
		var point := start.lerp(end, float(step) / float(steps))
		_paint_disc(image, point, width * 0.5, color)

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

func _make_character_select_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.026, 0.036, 0.98)
	style.border_color = Color(0.22, 0.32, 0.38, 1.0)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 0
	style.content_margin_top = 0
	style.content_margin_right = 0
	style.content_margin_bottom = 0
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

func _is_character_start_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return false
	return event.is_action_pressed(&"pause")

func _is_character_confirm_event(event: InputEvent) -> bool:
	if event is InputEventJoypadButton:
		var button_event := event as InputEventJoypadButton
		return button_event.pressed and button_event.button_index == JOY_BUTTON_A
	return false

func _on_active_slots_changed(_active_slots: Array[int]) -> void:
	# Newly joined slots need a starting cursor before they can browse.
	_sync_character_cursors()
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
