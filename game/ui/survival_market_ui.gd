extends CanvasLayer
class_name SurvivalMarketUI

const SLOT_COLORS: Array[Color] = [
	Color(0.18, 0.74, 0.95, 1.0),
	Color(0.95, 0.42, 0.34, 1.0),
	Color(0.52, 0.86, 0.32, 1.0),
	Color(0.94, 0.78, 0.28, 1.0)
]

var market_controller: SurvivalMarketController
var input_manager: InputManager
var audio_manager: AudioManager
var options: Array[Dictionary] = []
var selection_by_slot: Dictionary = {}
var navigation_latched: Dictionary = {}
var feedback_by_slot: Dictionary = {}
var feedback_timer_by_slot: Dictionary = {}

var overlay: ColorRect
var wallet_label: Label
var subtitle_label: Label
var option_container: VBoxContainer
var option_labels: Array[Label] = []
var player_labels: Dictionary = {}

func _ready() -> void:
	add_to_group("survival_market_ui")
	layer = 50
	_create_interface()
	hide()
	call_deferred("_resolve_and_connect")

func _process(delta: float) -> void:
	if not visible or market_controller == null or not market_controller.is_market_open:
		return
	_update_feedback_timers(delta)
	_handle_player_input()
	_refresh_interface()

func _create_interface() -> void:
	overlay = ColorRect.new()
	overlay.name = "MarketOverlay"
	overlay.color = Color(0.008, 0.012, 0.018, 0.94)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	overlay.add_child(margin)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_panel_style())
	margin.add_child(panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	panel.add_child(content)

	var title_row := HBoxContainer.new()
	content.add_child(title_row)
	var title := Label.new()
	title.text = "MERCATO DEI SOPRAVVISSUTI"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.78, 0.28, 1.0))
	title_row.add_child(title)
	wallet_label = Label.new()
	wallet_label.add_theme_font_size_override("font_size", 26)
	wallet_label.add_theme_color_override("font_color", Color(0.42, 0.96, 0.62, 1.0))
	title_row.add_child(wallet_label)

	subtitle_label = Label.new()
	subtitle_label.add_theme_font_size_override("font_size", 16)
	subtitle_label.modulate = Color(0.78, 0.86, 0.92, 1.0)
	content.add_child(subtitle_label)

	var divider := HSeparator.new()
	content.add_child(divider)

	option_container = VBoxContainer.new()
	option_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	option_container.add_theme_constant_override("separation", 3)
	content.add_child(option_container)

	var player_row := HBoxContainer.new()
	player_row.add_theme_constant_override("separation", 8)
	content.add_child(player_row)
	for player_slot in range(1, 5):
		var player_panel := PanelContainer.new()
		player_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.025, 0.04, 0.055, 0.96)
		style.border_color = SLOT_COLORS[player_slot - 1]
		style.set_border_width_all(2)
		style.set_corner_radius_all(6)
		style.set_content_margin_all(8.0)
		player_panel.add_theme_stylebox_override("panel", style)
		player_row.add_child(player_panel)
		var label := Label.new()
		label.custom_minimum_size = Vector2(0.0, 72.0)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", SLOT_COLORS[player_slot - 1])
		player_panel.add_child(label)
		player_labels[player_slot] = label

func _resolve_and_connect() -> void:
	market_controller = get_tree().get_first_node_in_group(
		"survival_market_controller"
	) as SurvivalMarketController
	input_manager = get_tree().get_first_node_in_group("input_manager") as InputManager
	audio_manager = get_tree().get_first_node_in_group("audio_manager") as AudioManager
	if market_controller == null:
		return
	_connect_signal(market_controller.market_opened, _on_market_opened)
	_connect_signal(market_controller.market_closed, _on_market_closed)
	_connect_signal(market_controller.offers_changed, _on_offers_changed)
	_connect_signal(market_controller.wallet_changed, _on_wallet_changed)
	_connect_signal(market_controller.purchase_succeeded, _on_purchase_succeeded)
	_connect_signal(market_controller.purchase_denied, _on_purchase_denied)
	_connect_signal(market_controller.player_ready_changed, _on_player_ready_changed)

func _connect_signal(signal_value: Signal, callback: Callable) -> void:
	if not signal_value.is_connected(callback):
		signal_value.connect(callback)

func _on_market_opened(wave_index: int, _offers: Array[Dictionary]) -> void:
	options = market_controller.get_purchase_options()
	selection_by_slot.clear()
	navigation_latched.clear()
	feedback_by_slot.clear()
	feedback_timer_by_slot.clear()
	for player in PlayerQuery.alive(get_tree()):
		selection_by_slot[int(player.get("player_slot"))] = 0
	subtitle_label.text = (
		"Boss wave %d completata. WASD/stick o D-pad: seleziona  |  E/A: acquista  |  Shift/B: READY"
		% wave_index
	)
	_rebuild_option_labels()
	_refresh_interface()
	show()
	if audio_manager != null:
		audio_manager.play_cue(&"market_open", &"market", &"UI", 520.0)

func _on_market_closed(_wave_index: int) -> void:
	hide()
	options.clear()
	selection_by_slot.clear()
	if audio_manager != null:
		audio_manager.play_ui_confirm()

func _on_offers_changed(_offers: Array[Dictionary]) -> void:
	if market_controller == null:
		return
	options = market_controller.get_purchase_options()
	_rebuild_option_labels()
	_refresh_interface()

func _on_wallet_changed(_balance: int) -> void:
	_refresh_interface()

func _on_purchase_succeeded(player_slot: int, item_id: StringName, cost: int) -> void:
	feedback_by_slot[player_slot] = "ACQUISTO OK: %s (-%d)" % [
		_get_option_name(item_id),
		cost
	]
	feedback_timer_by_slot[player_slot] = 2.0
	if audio_manager != null:
		audio_manager.play_ui_confirm()

func _on_purchase_denied(player_slot: int, _item_id: StringName, reason: String) -> void:
	feedback_by_slot[player_slot] = "NEGATO: " + reason
	feedback_timer_by_slot[player_slot] = 2.4
	if audio_manager != null:
		audio_manager.play_cue(&"market_denied", &"market", &"UI", 170.0)

func _on_player_ready_changed(_player_slot: int, _ready: bool) -> void:
	_refresh_interface()

func _handle_player_input() -> void:
	if input_manager == null or options.is_empty():
		return
	for player in PlayerQuery.alive(get_tree()):
		if not market_controller.is_market_open:
			return
		var player_slot := int(player.get("player_slot"))
		if not selection_by_slot.has(player_slot):
			selection_by_slot[player_slot] = 0
		var move_vector := input_manager.get_player_move_vector(player_slot)
		var vertical_direction := 0
		if move_vector.y < -0.55:
			vertical_direction = -1
		elif move_vector.y > 0.55:
			vertical_direction = 1
		var latched := bool(navigation_latched.get(player_slot, false))
		if vertical_direction == 0:
			navigation_latched[player_slot] = false
		elif not latched:
			_move_selection(player_slot, vertical_direction)
			navigation_latched[player_slot] = true
		if input_manager.is_player_weapon_previous_just_pressed(player_slot):
			_move_selection(player_slot, -1)
		if input_manager.is_player_weapon_next_just_pressed(player_slot):
			_move_selection(player_slot, 1)
		if input_manager.is_player_interact_just_pressed(player_slot):
			var option := options[int(selection_by_slot[player_slot])]
			market_controller.try_purchase(
				player_slot,
				StringName(option.get("item_id", &""))
			)
		if input_manager.is_player_dodge_just_pressed(player_slot):
			market_controller.toggle_player_ready(player_slot)

func _move_selection(player_slot: int, direction: int) -> void:
	var current := int(selection_by_slot.get(player_slot, 0))
	selection_by_slot[player_slot] = posmod(
		current + (1 if direction >= 0 else -1),
		options.size()
	)
	if market_controller.is_player_ready(player_slot):
		market_controller.set_player_ready(player_slot, false)
	if audio_manager != null:
		audio_manager.play_ui_focus()

func _rebuild_option_labels() -> void:
	for child in option_container.get_children():
		child.queue_free()
	option_labels.clear()
	for _option in options:
		var label := Label.new()
		label.custom_minimum_size = Vector2(0.0, 31.0)
		label.add_theme_font_size_override("font_size", 17)
		label.add_theme_constant_override("outline_size", 3)
		label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
		option_container.add_child(label)
		option_labels.append(label)

func _refresh_interface() -> void:
	if market_controller == null or wallet_label == null:
		return
	var balance := market_controller.get_wallet_balance()
	wallet_label.text = "WALLET COMUNE  $%d" % balance
	for index in range(mini(options.size(), option_labels.size())):
		var option := options[index]
		var selectors := PackedStringArray()
		for raw_slot in selection_by_slot.keys():
			var player_slot := int(raw_slot)
			if int(selection_by_slot[raw_slot]) == index:
				selectors.append("P%d" % player_slot)
		var marker := "[%s]" % " ".join(selectors) if not selectors.is_empty() else "[  ]"
		var cost := int(option.get("cost", 0))
		var affordable := balance >= cost
		option_labels[index].text = "%s  %-28s  %-10s  %-9s  $%d  |  %s" % [
			marker,
			str(option.get("display_name", "Item")),
			String(option.get("category", &"service")).to_upper(),
			String(option.get("rarity", &"service")).to_upper(),
			cost,
			str(option.get("stats_text", ""))
		]
		option_labels[index].modulate = (
			Color(0.94, 0.98, 1.0, 1.0)
			if affordable
			else Color(1.0, 0.34, 0.28, 0.78)
		)
	_refresh_player_panels(balance)

func _refresh_player_panels(balance: int) -> void:
	var alive_slots: Array[int] = []
	for player in PlayerQuery.alive(get_tree()):
		alive_slots.append(int(player.get("player_slot")))
	for player_slot in range(1, 5):
		var label := player_labels.get(player_slot) as Label
		if label == null:
			continue
		if not alive_slots.has(player_slot):
			label.text = "P%d\nNON ATTIVO" % player_slot
			label.modulate = Color(0.45, 0.48, 0.52, 0.65)
			continue
		var feedback := str(feedback_by_slot.get(player_slot, ""))
		if feedback.begins_with("NEGATO"):
			label.modulate = Color(1.0, 0.42, 0.36, 1.0)
		elif feedback.begins_with("ACQUISTO OK"):
			label.modulate = Color(0.48, 1.0, 0.62, 1.0)
		else:
			label.modulate = Color.WHITE
		var selected_index := clampi(
			int(selection_by_slot.get(player_slot, 0)),
			0,
			maxi(options.size() - 1, 0)
		)
		var option := options[selected_index] if not options.is_empty() else {}
		var cost := int(option.get("cost", 0))
		var state := "READY" if market_controller.is_player_ready(player_slot) else "SHOPPING"
		label.text = "P%d  %s\n%s  $%d  %s\n%s" % [
			player_slot,
			state,
			str(option.get("display_name", "-")),
			cost,
			"OK" if balance >= cost else "NO FUNDS",
			feedback
		]

func _update_feedback_timers(delta: float) -> void:
	for raw_slot in feedback_timer_by_slot.keys():
		var player_slot := int(raw_slot)
		var time_left := maxf(float(feedback_timer_by_slot[raw_slot]) - delta, 0.0)
		feedback_timer_by_slot[player_slot] = time_left
		if time_left <= 0.0:
			feedback_by_slot.erase(player_slot)

func _get_option_name(item_id: StringName) -> String:
	for option in options:
		if StringName(option.get("item_id", &"")) == item_id:
			return str(option.get("display_name", String(item_id)))
	return String(item_id)

func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.03, 0.045, 0.98)
	style.border_color = Color(0.78, 0.58, 0.20, 0.92)
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(18.0)
	return style
