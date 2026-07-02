extends PanelContainer
class_name SettingsPanel

signal settings_closed

const MENU_NAVIGATION_SCRIPT := preload(
	"res://game/ui/menu_navigation_controller.gd"
)

var tab_container: TabContainer
var back_button: Button
var rebind_status_label: Label
var navigation_controller
var volume_sliders: Dictionary = {}
var visual_controls: Dictionary = {}
var video_controls: Dictionary = {}
var control_rebind_buttons: Dictionary = {}
var control_rebind_sources: Dictionary = {}
var tab_indices: Dictionary = {}
var audio_focus_controls: Array[Control] = []
var video_focus_controls: Array[Control] = []
var controls_focus_controls: Array[Control] = []

var audio_manager: AudioManager
var visual_settings_manager: VisualSettingsManager
var video_settings_manager: VideoSettingsManager
var input_manager: InputManager
var local_multiplayer_manager: LocalMultiplayerManager
var pending_rebind_source: StringName = &""
var pending_rebind_id: StringName = &""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	custom_minimum_size = Vector2(620.0, 520.0)
	_create_ui()
	hide()
	call_deferred("_initialize")

func _input(event: InputEvent) -> void:
	if not visible or pending_rebind_id.is_empty():
		return
	if _consume_rebind_event(event):
		get_viewport().set_input_as_handled()

func open(initial_tab: StringName = &"audio") -> void:
	_resolve_managers()
	_refresh_all_controls()
	show()
	if tab_indices.has(initial_tab):
		tab_container.current_tab = int(tab_indices[initial_tab])
	_refresh_navigation_controls()
	call_deferred("_focus_current_tab")

func close(emit_signal_value: bool = true) -> void:
	_clear_pending_rebind()
	hide()
	if emit_signal_value:
		settings_closed.emit()

func is_rebinding() -> bool:
	return not pending_rebind_id.is_empty()

func refresh_all_controls() -> void:
	_resolve_managers()
	_refresh_all_controls()

func _initialize() -> void:
	_resolve_managers()
	_refresh_all_controls()

func _create_ui() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.045, 0.062, 0.98)
	style.border_color = Color(0.32, 0.74, 0.86, 0.90)
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(18.0)
	add_theme_stylebox_override("panel", style)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	add_child(content)

	var title := Label.new()
	title.text = "SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.modulate = Color(0.55, 0.88, 1.0, 1.0)
	content.add_child(title)

	tab_container = TabContainer.new()
	tab_container.custom_minimum_size = Vector2(560.0, 380.0)
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_container.tab_changed.connect(_on_tab_changed)
	content.add_child(tab_container)

	_create_audio_tab()
	_create_video_tab()
	_create_controls_tab()

	back_button = Button.new()
	back_button.text = "Back"
	back_button.custom_minimum_size = Vector2(440.0, 42.0)
	back_button.pressed.connect(close)
	back_button.focus_entered.connect(_play_focus)
	content.add_child(back_button)
	_create_navigation_controller()

func _create_navigation_controller() -> void:
	navigation_controller = MENU_NAVIGATION_SCRIPT.new()
	navigation_controller.name = "SettingsNavigation"
	navigation_controller.owner_control = self
	navigation_controller.back_callback = Callable(self, "_handle_back_navigation")
	navigation_controller.previous_tab_callback = Callable(self, "_select_previous_tab")
	navigation_controller.next_tab_callback = Callable(self, "_select_next_tab")
	navigation_controller.input_blocked_callback = Callable(self, "is_rebinding")
	add_child(navigation_controller)
	_refresh_navigation_controls()

func _create_audio_tab() -> void:
	var tab := VBoxContainer.new()
	tab.name = "Audio"
	tab.add_theme_constant_override("separation", 12)
	tab_container.add_child(tab)
	tab_indices[&"audio"] = tab_container.get_child_count() - 1

	tab.add_child(_create_volume_row("Master", &"Master"))
	tab.add_child(_create_volume_row("Music", &"Music"))
	tab.add_child(_create_volume_row("SFX", &"SFX"))

func _create_video_tab() -> void:
	var tab := VBoxContainer.new()
	tab.name = "Video"
	tab_container.add_child(tab)
	tab_indices[&"video"] = tab_container.get_child_count() - 1

	var list := _create_scroll_list(tab)
	list.add_theme_constant_override("separation", 8)

	var display_mode := _create_option_row("Display", &"display_mode")
	for spec in [
		["Windowed", &"windowed"],
		["Fullscreen", &"fullscreen"],
		["Exclusive", &"exclusive_fullscreen"]
	]:
		display_mode.add_item(spec[0])
		display_mode.set_item_metadata(
			display_mode.get_item_count() - 1,
			spec[1]
		)
	display_mode.item_selected.connect(_on_display_mode_selected)
	list.add_child(display_mode.get_parent())

	var resolution := _create_option_row("Resolution", &"resolution")
	for size in VideoSettingsManager.RESOLUTION_PRESETS:
		resolution.add_item("%dx%d" % [size.x, size.y])
		resolution.set_item_metadata(
			resolution.get_item_count() - 1,
			size
		)
	resolution.item_selected.connect(_on_resolution_selected)
	list.add_child(resolution.get_parent())

	var frame_limit := _create_option_row("Frame limit", &"max_fps")
	for limit in VideoSettingsManager.FPS_LIMITS:
		frame_limit.add_item("Unlimited" if limit == 0 else "%d FPS" % limit)
		frame_limit.set_item_metadata(
			frame_limit.get_item_count() - 1,
			limit
		)
	frame_limit.item_selected.connect(_on_frame_limit_selected)
	list.add_child(frame_limit.get_parent())

	list.add_child(_create_video_toggle("Borderless", &"borderless"))
	list.add_child(_create_video_toggle("VSync", &"vsync"))
	list.add_child(HSeparator.new())
	list.add_child(_create_visual_slider("Flash", &"flash_intensity", 0.0, 1.0, 0.05))
	list.add_child(_create_visual_slider("Glow", &"glow_intensity", 0.0, 1.0, 0.05))
	list.add_child(_create_visual_slider("Trails", &"trail_intensity", 0.0, 1.0, 0.05))
	list.add_child(_create_visual_slider("Camera shake", &"camera_shake_intensity", 0.0, 1.0, 0.05))
	list.add_child(_create_visual_slider("HUD text", &"hud_text_scale", 0.8, 1.2, 0.05))
	list.add_child(_create_visual_toggle("High contrast", &"high_contrast"))
	list.add_child(_create_visual_toggle("Reduced motion", &"reduced_motion"))

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
		button.custom_minimum_size.y = 40.0
		button.pressed.connect(_apply_visual_profile.bind(spec[1]))
		button.focus_entered.connect(_play_focus)
		presets.add_child(button)
		video_focus_controls.append(button)
	list.add_child(presets)

func _create_controls_tab() -> void:
	var tab := VBoxContainer.new()
	tab.name = "Controls"
	tab.add_theme_constant_override("separation", 8)
	tab_container.add_child(tab)
	tab_indices[&"controls"] = tab_container.get_child_count() - 1

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(540.0, 330.0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	tab.add_child(scroll)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 7)
	scroll.add_child(list)

	var reset_button := Button.new()
	reset_button.text = "Reset joystick bindings"
	reset_button.custom_minimum_size = Vector2(500.0, 38.0)
	reset_button.pressed.connect(_reset_control_bindings)
	reset_button.focus_entered.connect(_play_focus)
	list.add_child(reset_button)
	controls_focus_controls.append(reset_button)

	rebind_status_label = Label.new()
	rebind_status_label.text = ""
	rebind_status_label.custom_minimum_size = Vector2(500.0, 28.0)
	rebind_status_label.modulate = Color(0.78, 0.84, 0.92, 1.0)
	list.add_child(rebind_status_label)

	for action_id in InputManager.ALL_JOYSTICK_ACTIONS:
		list.add_child(_create_rebind_row(
			action_id,
			String(InputManager.ACTION_LABELS.get(action_id, String(action_id))),
			&"input"
		))
	for control_id in LocalMultiplayerManager.JOYSTICK_CONTROL_ORDER:
		list.add_child(_create_rebind_row(
			control_id,
			String(LocalMultiplayerManager.JOYSTICK_CONTROL_LABELS.get(
				control_id,
				String(control_id)
			)),
			&"local_multiplayer"
		))

func _create_scroll_list(parent: Control) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(540.0, 330.0)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.follow_focus = true
	parent.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	return list

func _create_volume_row(label_text: String, bus_name: StringName) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(130.0, 34.0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	var slider := HSlider.new()
	slider.custom_minimum_size = Vector2(360.0, 34.0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = 1.0
	slider.value_changed.connect(_on_volume_changed.bind(bus_name))
	slider.focus_entered.connect(_play_focus)
	row.add_child(slider)
	volume_sliders[bus_name] = slider
	audio_focus_controls.append(slider)
	return row

func _create_option_row(label_text: String, control_id: StringName) -> OptionButton:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(130.0, 36.0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	var option := OptionButton.new()
	option.custom_minimum_size = Vector2(360.0, 36.0)
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.focus_entered.connect(_play_focus)
	row.add_child(option)
	video_controls[control_id] = option
	video_focus_controls.append(option)
	return option

func _create_video_toggle(label_text: String, setting_id: StringName) -> Control:
	var toggle := CheckButton.new()
	toggle.text = label_text
	toggle.custom_minimum_size = Vector2(500.0, 36.0)
	toggle.toggled.connect(_on_video_toggle_changed.bind(setting_id))
	toggle.focus_entered.connect(_play_focus)
	video_controls[setting_id] = toggle
	video_focus_controls.append(toggle)
	return toggle

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
	label.custom_minimum_size = Vector2(130.0, 32.0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	var slider := HSlider.new()
	slider.custom_minimum_size = Vector2(360.0, 32.0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step_value
	slider.value_changed.connect(_on_visual_slider_changed.bind(setting_id))
	slider.focus_entered.connect(_play_focus)
	row.add_child(slider)
	visual_controls[setting_id] = slider
	video_focus_controls.append(slider)
	return row

func _create_visual_toggle(label_text: String, setting_id: StringName) -> Control:
	var toggle := CheckButton.new()
	toggle.text = label_text
	toggle.custom_minimum_size = Vector2(500.0, 36.0)
	toggle.toggled.connect(_on_visual_toggle_changed.bind(setting_id))
	toggle.focus_entered.connect(_play_focus)
	visual_controls[setting_id] = toggle
	video_focus_controls.append(toggle)
	return toggle

func _create_rebind_row(
	action_id: StringName,
	label_text: String,
	source: StringName
) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(185.0, 36.0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	var button := Button.new()
	button.text = "Unassigned"
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(300.0, 36.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(_start_rebind.bind(source, action_id))
	button.focus_entered.connect(_play_focus)
	row.add_child(button)
	var key := _control_key(source, action_id)
	control_rebind_buttons[key] = button
	control_rebind_sources[key] = source
	controls_focus_controls.append(button)
	return row

func _resolve_managers() -> void:
	if audio_manager == null:
		audio_manager = get_tree().get_first_node_in_group(
			"audio_manager"
		) as AudioManager
	if visual_settings_manager == null:
		visual_settings_manager = get_tree().get_first_node_in_group(
			"visual_settings_manager"
		) as VisualSettingsManager
	if video_settings_manager == null:
		video_settings_manager = get_tree().get_first_node_in_group(
			"video_settings_manager"
		) as VideoSettingsManager
	if input_manager == null:
		input_manager = get_tree().get_first_node_in_group(
			"input_manager"
		) as InputManager
	if local_multiplayer_manager == null:
		local_multiplayer_manager = get_tree().get_first_node_in_group(
			"local_multiplayer_manager"
		) as LocalMultiplayerManager

func _refresh_all_controls() -> void:
	_refresh_audio_controls()
	_refresh_video_controls()
	_refresh_visual_controls()
	_refresh_control_buttons()

func _refresh_audio_controls() -> void:
	if audio_manager == null:
		return
	for bus_name in volume_sliders:
		var slider := volume_sliders[bus_name] as HSlider
		if slider != null:
			slider.set_value_no_signal(
				audio_manager.get_bus_volume_linear(bus_name)
			)

func _refresh_video_controls() -> void:
	if video_settings_manager == null:
		return
	_select_option_by_metadata(
		video_controls.get(&"display_mode") as OptionButton,
		StringName(video_settings_manager.get_setting(
			&"display_mode",
			&"windowed"
		))
	)
	_select_option_by_metadata(
		video_controls.get(&"resolution") as OptionButton,
		Vector2i(
			int(video_settings_manager.get_setting(&"resolution_width", 1280)),
			int(video_settings_manager.get_setting(&"resolution_height", 720))
		)
	)
	_select_option_by_metadata(
		video_controls.get(&"max_fps") as OptionButton,
		int(video_settings_manager.get_setting(&"max_fps", 60))
	)
	for setting_id in [&"borderless", &"vsync"]:
		var toggle := video_controls.get(setting_id) as CheckButton
		if toggle != null:
			toggle.set_pressed_no_signal(bool(
				video_settings_manager.get_setting(setting_id, false)
			))

func _refresh_visual_controls() -> void:
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

func _refresh_control_buttons() -> void:
	if input_manager != null:
		for spec in input_manager.get_joystick_action_specs():
			var action_id := StringName(spec["id"])
			var button := control_rebind_buttons.get(
				_control_key(&"input", action_id)
			) as Button
			if button != null:
				button.text = input_manager.get_joystick_binding_label(
					action_id
				)
	if local_multiplayer_manager != null:
		for spec in local_multiplayer_manager.get_joystick_control_specs():
			var action_id := StringName(spec["id"])
			var button := control_rebind_buttons.get(
				_control_key(&"local_multiplayer", action_id)
			) as Button
			if button != null:
				button.text = local_multiplayer_manager.get_joystick_button_label(
					action_id
				)

func _on_volume_changed(value: float, bus_name: StringName) -> void:
	_resolve_managers()
	if audio_manager != null:
		audio_manager.set_bus_volume_linear(bus_name, value)

func _on_display_mode_selected(index: int) -> void:
	_resolve_managers()
	var option := video_controls.get(&"display_mode") as OptionButton
	if video_settings_manager == null or option == null:
		return
	video_settings_manager.set_display_mode(
		StringName(option.get_item_metadata(index))
	)
	_refresh_video_controls()

func _on_resolution_selected(index: int) -> void:
	_resolve_managers()
	var option := video_controls.get(&"resolution") as OptionButton
	if video_settings_manager == null or option == null:
		return
	var size: Vector2i = option.get_item_metadata(index)
	video_settings_manager.set_resolution(size)
	_refresh_video_controls()

func _on_frame_limit_selected(index: int) -> void:
	_resolve_managers()
	var option := video_controls.get(&"max_fps") as OptionButton
	if video_settings_manager == null or option == null:
		return
	video_settings_manager.set_max_fps(int(option.get_item_metadata(index)))
	_refresh_video_controls()

func _on_video_toggle_changed(value: bool, setting_id: StringName) -> void:
	_resolve_managers()
	if video_settings_manager == null:
		return
	match setting_id:
		&"borderless":
			video_settings_manager.set_borderless(value)
		&"vsync":
			video_settings_manager.set_vsync(value)

func _on_visual_slider_changed(value: float, setting_id: StringName) -> void:
	_resolve_managers()
	if visual_settings_manager != null:
		visual_settings_manager.set_setting(setting_id, value)

func _on_visual_toggle_changed(value: bool, setting_id: StringName) -> void:
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

func _start_rebind(source: StringName, action_id: StringName) -> void:
	pending_rebind_source = source
	pending_rebind_id = action_id
	if rebind_status_label != null:
		rebind_status_label.text = "Press a joystick button or move an axis"
	var key := _control_key(source, action_id)
	var button := control_rebind_buttons.get(key) as Button
	if button != null:
		button.text = "Listening..."

func _consume_rebind_event(event: InputEvent) -> bool:
	_resolve_managers()
	var applied := false
	match pending_rebind_source:
		&"input":
			if input_manager != null:
				applied = input_manager.rebind_joystick_action(
					pending_rebind_id,
					event
				)
		&"local_multiplayer":
			if local_multiplayer_manager != null:
				applied = local_multiplayer_manager.rebind_joystick_button(
					pending_rebind_id,
					event
				)
	if not applied:
		if event is InputEventJoypadButton or event is InputEventJoypadMotion:
			return true
		return false
	if rebind_status_label != null:
		rebind_status_label.text = "Binding updated"
	_clear_pending_rebind()
	_refresh_control_buttons()
	return true

func _reset_control_bindings() -> void:
	_resolve_managers()
	if input_manager != null:
		input_manager.reset_joystick_bindings()
	if local_multiplayer_manager != null:
		local_multiplayer_manager.reset_joystick_buttons()
	_clear_pending_rebind()
	if rebind_status_label != null:
		rebind_status_label.text = "Default bindings restored"
	_refresh_control_buttons()

func _clear_pending_rebind() -> void:
	pending_rebind_source = &""
	pending_rebind_id = &""

func _on_tab_changed(_tab: int) -> void:
	_clear_pending_rebind()
	_refresh_all_controls()
	_refresh_navigation_controls()
	call_deferred("_focus_current_tab")

func _focus_current_tab() -> void:
	if not visible or tab_container == null:
		return
	var tab_id := _current_tab_id()
	var focus_control: Control
	match tab_id:
		&"video":
			focus_control = video_controls.get(&"display_mode") as Control
		&"controls":
			focus_control = _first_control_rebind_button()
		_:
			focus_control = volume_sliders.get(&"Master") as Control
	if focus_control != null:
		focus_control.grab_focus()
	if navigation_controller != null:
		navigation_controller.ensure_focus(focus_control)

func _refresh_navigation_controls() -> void:
	if navigation_controller == null:
		return
	var controls: Array[Control] = []
	match _current_tab_id():
		&"video":
			controls.append_array(video_focus_controls)
		&"controls":
			controls.append_array(controls_focus_controls)
		_:
			controls.append_array(audio_focus_controls)
	if back_button != null:
		controls.append(back_button)
	navigation_controller.set_focus_controls(controls)

func _handle_back_navigation() -> bool:
	close()
	return true

func _select_previous_tab() -> bool:
	return _select_relative_tab(-1)

func _select_next_tab() -> bool:
	return _select_relative_tab(1)

func _select_relative_tab(offset: int) -> bool:
	if tab_container == null or tab_container.get_child_count() <= 0:
		return false
	var tab_count := tab_container.get_child_count()
	tab_container.current_tab = posmod(tab_container.current_tab + offset, tab_count)
	_clear_pending_rebind()
	_refresh_all_controls()
	_refresh_navigation_controls()
	call_deferred("_focus_current_tab")
	return true

func _current_tab_id() -> StringName:
	for key in tab_indices:
		if int(tab_indices[key]) == tab_container.current_tab:
			return StringName(key)
	return &"audio"

func _first_control_rebind_button() -> Control:
	if input_manager != null:
		for spec in input_manager.get_joystick_action_specs():
			var button := control_rebind_buttons.get(
				_control_key(&"input", StringName(spec["id"]))
			) as Button
			if button != null:
				return button
	return null

func _select_option_by_metadata(option: OptionButton, metadata: Variant) -> void:
	if option == null:
		return
	for index in range(option.get_item_count()):
		if option.get_item_metadata(index) == metadata:
			option.select(index)
			return

func _control_key(source: StringName, action_id: StringName) -> String:
	return "%s:%s" % [String(source), String(action_id)]

func _play_focus() -> void:
	_resolve_managers()
	if audio_manager != null:
		audio_manager.play_ui_focus()
