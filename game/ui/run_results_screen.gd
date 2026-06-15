extends CanvasLayer
class_name RunResultsScreen

var backdrop: ColorRect
var title_label: Label
var outcome_label: Label
var stats_label: Label
var retry_button: Button
var change_mode_button: Button
var menu_button: Button
var game_mode_manager: GameModeManager
var current_result: Dictionary = {}
var hud_text_scale: float = 1.0
var high_contrast: bool = false

func _ready() -> void:
	add_to_group("run_results_screen")
	add_to_group("visual_settings_consumers")
	layer = 30
	_create_ui()
	hide()
	VisualSettingsManager.sync_consumer(self)
	call_deferred("_initialize")

func apply_visual_settings(settings: Dictionary) -> void:
	hud_text_scale = clampf(
		float(settings.get("hud_text_scale", 1.0)),
		0.80,
		1.20
	)
	high_contrast = bool(settings.get("high_contrast", false))
	if title_label != null:
		title_label.add_theme_font_size_override(
			"font_size",
			roundi(36.0 * hud_text_scale)
		)
		title_label.modulate = (
			Color.WHITE
			if high_contrast
			else Color(0.62, 0.92, 1.0, 1.0)
		)
	if outcome_label != null:
		outcome_label.add_theme_font_size_override(
			"font_size",
			roundi(22.0 * hud_text_scale)
		)
	if stats_label != null:
		stats_label.add_theme_font_size_override(
			"font_size",
			roundi(19.0 * hud_text_scale)
		)
	for button in [retry_button, change_mode_button, menu_button]:
		if button != null:
			button.add_theme_font_size_override(
				"font_size",
				roundi(21.0 * hud_text_scale)
			)

func _initialize() -> void:
	game_mode_manager = get_tree().get_first_node_in_group(
		"game_mode_manager"
	) as GameModeManager
	if game_mode_manager == null:
		return
	var finish_callback := Callable(self, "_on_run_finished")
	if not game_mode_manager.run_finished.is_connected(finish_callback):
		game_mode_manager.run_finished.connect(finish_callback)
	var start_callback := Callable(self, "_on_game_mode_started")
	if not game_mode_manager.game_mode_started.is_connected(start_callback):
		game_mode_manager.game_mode_started.connect(start_callback)
	var mode_callback := Callable(self, "_on_game_mode_changed")
	if not game_mode_manager.game_mode_changed.is_connected(mode_callback):
		game_mode_manager.game_mode_changed.connect(mode_callback)

func _create_ui() -> void:
	backdrop = ColorRect.new()
	backdrop.color = Color(0.012, 0.022, 0.034, 0.96)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620.0, 560.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.045, 0.058, 0.98)
	style.border_color = Color(0.30, 0.78, 0.88, 0.92)
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(28.0)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	panel.add_child(content)
	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 36)
	title_label.modulate = Color(0.62, 0.92, 1.0, 1.0)
	content.add_child(title_label)
	outcome_label = Label.new()
	outcome_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outcome_label.add_theme_font_size_override("font_size", 22)
	content.add_child(outcome_label)
	stats_label = Label.new()
	stats_label.custom_minimum_size = Vector2(560.0, 180.0)
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stats_label.add_theme_font_size_override("font_size", 19)
	stats_label.modulate = Color(0.86, 0.92, 0.95, 1.0)
	content.add_child(stats_label)
	retry_button = _create_button("RETRY", Callable(self, "_on_retry_pressed"))
	content.add_child(retry_button)
	change_mode_button = _create_button(
		"CHANGE MODE",
		Callable(self, "_on_change_mode_pressed")
	)
	content.add_child(change_mode_button)
	menu_button = _create_button(
		"MAIN MENU",
		Callable(self, "_on_menu_pressed")
	)
	content.add_child(menu_button)

func _create_button(text_value: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(520.0, 54.0)
	button.add_theme_font_size_override("font_size", 21)
	button.pressed.connect(callback)
	button.focus_entered.connect(_play_focus)
	return button

func show_result(result: Dictionary) -> void:
	current_result = result.duplicate(true)
	title_label.text = str(result.get("title", "RUN COMPLETE"))
	outcome_label.text = str(result.get("summary", ""))
	var unlocks: Array = result.get("unlocks", [])
	var unlock_text := (
		"New unlock: %s" % ", ".join(PackedStringArray(unlocks))
		if not unlocks.is_empty()
		else "No new unlocks"
	)
	stats_label.text = (
		"Time  %s\nXP gained  +%d\nMoney gained  +%d\n%s"
	) % [
		_format_duration(float(result.get("elapsed_seconds", 0.0))),
		int(result.get("experience_gained", 0)),
		int(result.get("money_gained", 0)),
		unlock_text
	]
	var next_mode := (
		game_mode_manager.get_next_mode_id()
		if game_mode_manager != null
		else GameConstants.MODE_SURVIVAL
	)
	change_mode_button.text = "CHANGE MODE: %s" % _mode_label(next_mode)
	show()
	retry_button.grab_focus()

func is_open() -> bool:
	return visible

func _on_run_finished(result: Dictionary) -> void:
	show_result(result)

func _on_retry_pressed() -> void:
	_play_confirm()
	if game_mode_manager != null and game_mode_manager.retry_active_mode():
		hide()

func _on_change_mode_pressed() -> void:
	_play_confirm()
	if game_mode_manager != null and game_mode_manager.change_to_next_mode():
		hide()

func _on_menu_pressed() -> void:
	_play_confirm()
	if game_mode_manager != null and game_mode_manager.return_to_menu():
		hide()

func _on_game_mode_started(_mode_id: StringName) -> void:
	hide()

func _on_game_mode_changed(mode_id: StringName) -> void:
	if mode_id == GameConstants.MODE_MENU:
		hide()

func _format_duration(seconds: float) -> String:
	var total_seconds := maxi(roundi(seconds), 0)
	return "%02d:%02d" % [total_seconds / 60, total_seconds % 60]

func _mode_label(mode_id: StringName) -> String:
	match mode_id:
		GameConstants.MODE_DUNGEON:
			return "DUNGEON"
		GameConstants.MODE_TOWER_DEFENSE:
			return "DEFENSE"
		_:
			return "SURVIVAL"

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
