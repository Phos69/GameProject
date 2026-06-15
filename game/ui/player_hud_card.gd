extends PanelContainer
class_name PlayerHudCard

var player_slot: int = 1
var slot_color: Color = Color(0.18, 0.74, 0.95, 1.0)
var slot_label: Label
var weapon_icon: WeaponIcon
var weapon_label: Label
var class_label: Label
var health_bar: ProgressBar
var health_label: Label
var ammo_label: Label
var ammo_pips_container: HBoxContainer
var reload_bar: ProgressBar
var xp_bar: ProgressBar
var stats_label: Label
var passive_label: Label
var ammo_pips: Array[ColorRect] = []
var hud_text_scale: float = 1.0
var high_contrast: bool = false

func _ready() -> void:
	add_to_group("visual_settings_consumers")
	custom_minimum_size = Vector2(292.0, 158.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	_apply_style()
	VisualSettingsManager.sync_consumer(self)

func apply_visual_settings(settings: Dictionary) -> void:
	hud_text_scale = clampf(
		float(settings.get("hud_text_scale", 1.0)),
		0.80,
		1.20
	)
	high_contrast = bool(settings.get("high_contrast", false))
	if slot_label != null:
		slot_label.add_theme_font_size_override(
			"font_size",
			roundi(18.0 * hud_text_scale)
		)
	if weapon_label != null:
		weapon_label.add_theme_font_size_override(
			"font_size",
			roundi(14.0 * hud_text_scale)
		)
	if class_label != null:
		class_label.add_theme_font_size_override(
			"font_size",
			roundi(12.0 * hud_text_scale)
		)
	if ammo_label != null:
		ammo_label.add_theme_font_size_override(
			"font_size",
			roundi(17.0 * hud_text_scale)
		)
	if stats_label != null:
		stats_label.add_theme_font_size_override(
			"font_size",
			roundi(12.0 * hud_text_scale)
		)
	if passive_label != null:
		passive_label.add_theme_font_size_override(
			"font_size",
			roundi(12.0 * hud_text_scale)
		)
	_apply_style()

func configure(slot: int, color: Color) -> void:
	player_slot = slot
	slot_color = color
	if is_node_ready():
		_apply_style()
		slot_label.text = "P%d" % player_slot

func refresh(player: Node) -> void:
	if player == null:
		hide()
		return
	show()

	var health_component := player.get_node_or_null("HealthComponent") as HealthComponent
	var weapon_system := player.get_node_or_null("WeaponSystem") as WeaponSystem
	var rpg_component := player.get_node_or_null(
		"RpgPlayerComponent"
	) as RpgPlayerComponent
	slot_label.text = "P%d" % player_slot
	class_label.text = "Survivor"
	stats_label.text = "ATK 0  DEF 0  SPD 1.00"
	passive_label.text = ""
	passive_label.hide()
	xp_bar.max_value = 1.0
	xp_bar.value = 0.0
	if rpg_component != null and rpg_component.has_character():
		slot_label.text = "P%d  LV %d" % [player_slot, rpg_component.level]
		class_label.text = "%s  %s" % [
			rpg_component.get_display_name(),
			rpg_component.get_class_name()
		]
		stats_label.text = rpg_component.get_stats_text()
		var passive_text := rpg_component.get_active_passive_text()
		if not passive_text.is_empty():
			passive_label.text = passive_text
			passive_label.show()
		xp_bar.max_value = float(rpg_component.experience_to_next_level)
		xp_bar.value = float(rpg_component.experience)
	if health_component != null:
		health_bar.max_value = float(health_component.max_health)
		health_bar.value = float(health_component.current_health)
		health_label.text = "%d / %d" % [
			health_component.current_health,
			health_component.max_health
		]
		var health_ratio := health_component.get_health_ratio()
		health_label.modulate = (
			Color(1.0, 0.48, 0.38, 1.0)
			if health_ratio <= 0.30 or health_component.is_downed
			else Color(0.90, 0.96, 0.98, 1.0)
		)
		if health_component.is_downed:
			health_label.text = "DOWNED"
	if weapon_system != null:
		ammo_label.text = weapon_system.get_ammo_text()
		weapon_icon.set_visual_data(
			weapon_system.weapon_data.visual_data
			if weapon_system.weapon_data != null
			else null
		)
		weapon_label.text = (
			weapon_system.weapon_data.display_name
			if weapon_system.weapon_data != null
			else "UNARMED"
		)
		ammo_label.modulate = (
			Color(1.0, 0.46, 0.24, 1.0)
			if weapon_system.low_ammo_active
			else Color(1.0, 0.80, 0.34, 1.0)
		)
		_refresh_ammo_widgets(weapon_system)
		if health_component != null and health_component.is_downed:
			weapon_label.text = "NEEDS REVIVE"
			ammo_label.text = "HOLD INTERACT"
			ammo_label.modulate = slot_color.lightened(0.2)
	else:
		_refresh_ammo_widgets(null)

func _build_ui() -> void:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	add_child(content)

	var top_row := HBoxContainer.new()
	content.add_child(top_row)
	slot_label = Label.new()
	slot_label.custom_minimum_size = Vector2(76.0, 24.0)
	slot_label.add_theme_font_size_override("font_size", 18)
	top_row.add_child(slot_label)
	weapon_icon = WeaponIcon.new()
	top_row.add_child(weapon_icon)
	weapon_label = Label.new()
	weapon_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	weapon_label.add_theme_font_size_override("font_size", 14)
	weapon_label.modulate = Color(0.76, 0.82, 0.86, 1.0)
	top_row.add_child(weapon_label)

	class_label = Label.new()
	class_label.add_theme_font_size_override("font_size", 12)
	class_label.modulate = Color(0.68, 0.76, 0.82, 1.0)
	content.add_child(class_label)

	var health_row := HBoxContainer.new()
	health_row.add_theme_constant_override("separation", 8)
	content.add_child(health_row)
	var health_icon := Label.new()
	health_icon.text = "+"
	health_icon.custom_minimum_size = Vector2(18.0, 20.0)
	health_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	health_icon.add_theme_font_size_override("font_size", 18)
	health_icon.modulate = Color(0.38, 0.92, 0.52, 1.0)
	health_row.add_child(health_icon)
	health_bar = ProgressBar.new()
	health_bar.custom_minimum_size = Vector2(142.0, 17.0)
	health_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	health_bar.show_percentage = false
	health_row.add_child(health_bar)
	health_label = Label.new()
	health_label.custom_minimum_size = Vector2(66.0, 20.0)
	health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	health_row.add_child(health_label)

	var ammo_row := HBoxContainer.new()
	ammo_row.add_theme_constant_override("separation", 7)
	content.add_child(ammo_row)
	var ammo_icon := Label.new()
	ammo_icon.text = "||"
	ammo_icon.custom_minimum_size = Vector2(28.0, 20.0)
	ammo_icon.modulate = Color(1.0, 0.70, 0.24, 1.0)
	ammo_row.add_child(ammo_icon)
	ammo_pips_container = HBoxContainer.new()
	ammo_pips_container.add_theme_constant_override("separation", 3)
	ammo_pips_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ammo_row.add_child(ammo_pips_container)
	ammo_label = Label.new()
	ammo_label.custom_minimum_size = Vector2(64.0, 20.0)
	ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ammo_label.add_theme_font_size_override("font_size", 17)
	ammo_row.add_child(ammo_label)

	reload_bar = ProgressBar.new()
	reload_bar.custom_minimum_size = Vector2(250.0, 8.0)
	reload_bar.max_value = 1.0
	reload_bar.show_percentage = false
	content.add_child(reload_bar)

	var xp_row := HBoxContainer.new()
	xp_row.add_theme_constant_override("separation", 8)
	content.add_child(xp_row)
	var xp_icon := Label.new()
	xp_icon.text = "*"
	xp_icon.custom_minimum_size = Vector2(28.0, 16.0)
	xp_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xp_icon.modulate = Color(0.54, 0.78, 1.0, 1.0)
	xp_row.add_child(xp_icon)
	xp_bar = ProgressBar.new()
	xp_bar.custom_minimum_size = Vector2(126.0, 12.0)
	xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp_bar.show_percentage = false
	xp_row.add_child(xp_bar)
	stats_label = Label.new()
	stats_label.custom_minimum_size = Vector2(120.0, 17.0)
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stats_label.add_theme_font_size_override("font_size", 12)
	stats_label.modulate = Color(0.74, 0.84, 0.92, 1.0)
	xp_row.add_child(stats_label)

	passive_label = Label.new()
	passive_label.custom_minimum_size = Vector2(250.0, 16.0)
	passive_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	passive_label.add_theme_font_size_override("font_size", 12)
	passive_label.add_theme_constant_override("outline_size", 2)
	passive_label.add_theme_color_override(
		"font_outline_color",
		Color(0.01, 0.01, 0.02, 0.95)
	)
	passive_label.modulate = Color(1.0, 0.76, 0.30, 1.0)
	passive_label.hide()
	content.add_child(passive_label)

func _apply_style() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.025, 0.04, 0.05, 0.92)
	panel_style.border_color = Color.WHITE if high_contrast else slot_color
	panel_style.set_border_width_all(3 if high_contrast else 2)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.content_margin_left = 12.0
	panel_style.content_margin_right = 12.0
	panel_style.content_margin_top = 8.0
	panel_style.content_margin_bottom = 8.0
	add_theme_stylebox_override("panel", panel_style)

	if slot_label != null:
		slot_label.modulate = (
			Color.WHITE if high_contrast else slot_color.lightened(0.2)
		)
	if health_bar != null:
		var background_style := StyleBoxFlat.new()
		background_style.bg_color = Color(0.08, 0.10, 0.11, 1.0)
		background_style.corner_radius_top_left = 4
		background_style.corner_radius_top_right = 4
		background_style.corner_radius_bottom_left = 4
		background_style.corner_radius_bottom_right = 4
		health_bar.add_theme_stylebox_override("background", background_style)
		var fill_style := StyleBoxFlat.new()
		fill_style.bg_color = Color(0.28, 0.82, 0.42, 1.0)
		fill_style.corner_radius_top_left = 4
		fill_style.corner_radius_top_right = 4
		fill_style.corner_radius_bottom_left = 4
		fill_style.corner_radius_bottom_right = 4
		health_bar.add_theme_stylebox_override("fill", fill_style)
	if xp_bar != null:
		var xp_background_style := StyleBoxFlat.new()
		xp_background_style.bg_color = Color(0.06, 0.08, 0.13, 1.0)
		xp_background_style.corner_radius_top_left = 4
		xp_background_style.corner_radius_top_right = 4
		xp_background_style.corner_radius_bottom_left = 4
		xp_background_style.corner_radius_bottom_right = 4
		xp_bar.add_theme_stylebox_override("background", xp_background_style)
		var xp_fill_style := StyleBoxFlat.new()
		xp_fill_style.bg_color = Color(0.24, 0.58, 0.96, 1.0)
		xp_fill_style.corner_radius_top_left = 4
		xp_fill_style.corner_radius_top_right = 4
		xp_fill_style.corner_radius_bottom_left = 4
		xp_fill_style.corner_radius_bottom_right = 4
		xp_bar.add_theme_stylebox_override("fill", xp_fill_style)
	if reload_bar != null:
		var reload_background_style := StyleBoxFlat.new()
		reload_background_style.bg_color = Color(0.07, 0.065, 0.04, 1.0)
		reload_background_style.corner_radius_top_left = 4
		reload_background_style.corner_radius_top_right = 4
		reload_background_style.corner_radius_bottom_left = 4
		reload_background_style.corner_radius_bottom_right = 4
		reload_bar.add_theme_stylebox_override(
			"background",
			reload_background_style
		)
		var reload_fill_style := StyleBoxFlat.new()
		reload_fill_style.bg_color = Color(1.0, 0.70, 0.24, 1.0)
		reload_fill_style.corner_radius_top_left = 4
		reload_fill_style.corner_radius_top_right = 4
		reload_fill_style.corner_radius_bottom_left = 4
		reload_fill_style.corner_radius_bottom_right = 4
		reload_bar.add_theme_stylebox_override("fill", reload_fill_style)

func _refresh_ammo_widgets(weapon_system: WeaponSystem) -> void:
	if weapon_system == null or weapon_system.weapon_data == null:
		_ensure_ammo_pips(0)
		if reload_bar != null:
			reload_bar.value = 0.0
		return

	var magazine_size := clampi(weapon_system.weapon_data.magazine_size, 1, 12)
	_ensure_ammo_pips(magazine_size)
	var active_color := Color(1.0, 0.70, 0.24, 1.0)
	if weapon_system.weapon_data.visual_data != null:
		active_color = weapon_system.weapon_data.visual_data.projectile_color
	var inactive_color := Color(0.13, 0.15, 0.17, 1.0)
	for index in range(ammo_pips.size()):
		ammo_pips[index].color = (
			active_color
			if index < weapon_system.current_ammo
			else inactive_color
		)
	if weapon_system.weapon_data.infinite_reserve_ammo:
		ammo_label.text = (
			"RELOAD"
			if weapon_system.is_reloading
			else "%d/%d" % [
				weapon_system.current_ammo,
				weapon_system.weapon_data.magazine_size
			]
		)
	if reload_bar != null:
		reload_bar.value = weapon_system.get_reload_ratio()
		reload_bar.modulate = (
			Color(1.0, 1.0, 1.0, 1.0)
			if weapon_system.is_reloading
			else Color(1.0, 1.0, 1.0, 0.22)
		)

func _ensure_ammo_pips(target_count: int) -> void:
	target_count = clampi(target_count, 0, 12)
	while ammo_pips.size() < target_count:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(9.0, 15.0)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ammo_pips_container.add_child(pip)
		ammo_pips.append(pip)
	while ammo_pips.size() > target_count:
		var pip := ammo_pips.pop_back() as ColorRect
		ammo_pips_container.remove_child(pip)
		pip.queue_free()
