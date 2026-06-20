extends PanelContainer
class_name PlayerHudCard

var player_slot: int = 1
var slot_color: Color = Color(0.18, 0.74, 0.95, 1.0)
var portrait_icon: RpgHudIcon
var slot_label: Label
var weapon_icon: WeaponIcon
var weapon_label: Label
var class_label: Label
var health_row: HBoxContainer
var health_bar: ProgressBar
var health_label: Label
var ammo_label: Label
var ammo_pips_container: HBoxContainer
var reload_bar: ProgressBar
var xp_bar: ProgressBar
var stats_label: Label
var adrenaline_bar: ProgressBar
var super_icon: RpgHudIcon
var super_label: Label
var passive_label: Label
var status_label: Label
var inventory_label: Label
var ammo_pips: Array[ColorRect] = []
var hud_text_scale: float = 1.0
var high_contrast: bool = false

func _ready() -> void:
	add_to_group("visual_settings_consumers")
	custom_minimum_size = Vector2(276.0, 184.0)
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
	if super_label != null:
		super_label.add_theme_font_size_override(
			"font_size",
			roundi(12.0 * hud_text_scale)
		)
	if passive_label != null:
		passive_label.add_theme_font_size_override(
			"font_size",
			roundi(12.0 * hud_text_scale)
		)
	if status_label != null:
		status_label.add_theme_font_size_override("font_size", roundi(12.0 * hud_text_scale))
	if inventory_label != null:
		inventory_label.add_theme_font_size_override("font_size", roundi(11.0 * hud_text_scale))
	_apply_style()

func configure(slot: int, color: Color) -> void:
	player_slot = slot
	slot_color = color
	if is_node_ready():
		_apply_style()
		portrait_icon.set_icon(&"survivor", slot_color)
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
	portrait_icon.set_icon(&"survivor", slot_color)
	if super_icon != null:
		super_icon.set_icon(&"super", Color(0.38, 1.0, 0.72, 1.0))
	slot_label.text = "P%d" % player_slot
	class_label.text = "Survivor"
	stats_label.text = "ATK 0  DEF 0  SPD 1.00"
	if super_label != null:
		super_label.text = "SUPER"
	if adrenaline_bar != null:
		adrenaline_bar.max_value = 1.0
		adrenaline_bar.value = 0.0
	passive_label.text = ""
	passive_label.hide()
	_refresh_status_widgets(player)
	if rpg_component != null and rpg_component.has_character():
		slot_label.text = "P%d" % player_slot
		class_label.text = "%s  %s · %s" % [
			rpg_component.get_hero_name(),
			rpg_component.get_class_name(),
			rpg_component.get_base_weapon_name()
		]
		stats_label.text = rpg_component.get_stats_text()
		portrait_icon.set_icon(
			rpg_component.character_id,
			Color(rpg_component.character_profile.get("palette_accent", slot_color))
		)
		if adrenaline_bar != null:
			adrenaline_bar.max_value = float(RpgPlayerComponent.ADRENALINE_MAX)
			adrenaline_bar.value = float(rpg_component.adrenaline)
		if super_icon != null:
			super_icon.set_icon(
				rpg_component.get_super_id(),
				Color(rpg_component.character_profile.get("palette_accent", Color(0.38, 1.0, 0.72, 1.0))),
				rpg_component.is_super_ready()
			)
		if super_label != null:
			super_label.text = rpg_component.get_super_status_text()
			super_label.modulate = (
				Color(0.54, 1.0, 0.74, 1.0)
				if rpg_component.is_super_ready()
				else Color(0.70, 0.88, 0.96, 1.0)
			)
		var passive_text := rpg_component.get_active_passive_text()
		if not passive_text.is_empty():
			passive_label.text = passive_text
			passive_label.show()
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
		ammo_label.text = _format_corner_ammo_text(weapon_system)
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
		if weapon_system.weapon_data != null and not weapon_system.weapon_data.effect_tags.is_empty():
			weapon_label.text += "  [%s]" % String(weapon_system.weapon_data.effect_tags[0]).to_upper()
		inventory_label.text = _format_inventory_text(weapon_system)
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
		inventory_label.text = ""

func _build_ui() -> void:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 3)
	add_child(content)

	var top_row := HBoxContainer.new()
	content.add_child(top_row)
	portrait_icon = RpgHudIcon.new()
	top_row.add_child(portrait_icon)
	slot_label = Label.new()
	slot_label.custom_minimum_size = Vector2(62.0, 24.0)
	slot_label.add_theme_font_size_override("font_size", 18)
	top_row.add_child(slot_label)
	weapon_icon = WeaponIcon.new()
	top_row.add_child(weapon_icon)
	weapon_label = Label.new()
	weapon_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	weapon_label.add_theme_font_size_override("font_size", 14)
	weapon_label.modulate = Color(0.76, 0.82, 0.86, 1.0)
	weapon_label.max_lines_visible = 1
	weapon_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top_row.add_child(weapon_label)

	class_label = Label.new()
	class_label.add_theme_font_size_override("font_size", 12)
	class_label.modulate = Color(0.68, 0.76, 0.82, 1.0)
	class_label.max_lines_visible = 1
	class_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	content.add_child(class_label)

	health_row = HBoxContainer.new()
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
	health_row.hide()

	var ammo_row := HBoxContainer.new()
	ammo_row.add_theme_constant_override("separation", 7)
	content.add_child(ammo_row)
	var ammo_icon := Label.new()
	ammo_icon.text = "RES"
	ammo_icon.custom_minimum_size = Vector2(34.0, 20.0)
	ammo_icon.modulate = Color(1.0, 0.70, 0.24, 1.0)
	ammo_row.add_child(ammo_icon)
	ammo_label = Label.new()
	ammo_label.custom_minimum_size = Vector2(190.0, 20.0)
	ammo_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ammo_label.add_theme_font_size_override("font_size", 17)
	ammo_row.add_child(ammo_label)

	inventory_label = Label.new()
	inventory_label.custom_minimum_size = Vector2(250.0, 16.0)
	inventory_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inventory_label.add_theme_font_size_override("font_size", 11)
	inventory_label.modulate = Color(0.66, 0.78, 0.86, 1.0)
	inventory_label.max_lines_visible = 1
	inventory_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	content.add_child(inventory_label)

	stats_label = Label.new()
	stats_label.custom_minimum_size = Vector2(250.0, 17.0)
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.add_theme_font_size_override("font_size", 12)
	stats_label.modulate = Color(0.74, 0.84, 0.92, 1.0)
	content.add_child(stats_label)

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

	status_label = Label.new()
	status_label.custom_minimum_size = Vector2(250.0, 16.0)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.add_theme_constant_override("outline_size", 2)
	status_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	status_label.hide()
	content.add_child(status_label)

func _refresh_status_widgets(player: Node) -> void:
	if status_label == null:
		return
	var dodge_component := player.get_node_or_null(
		"PlayerDodgeComponent"
	) as PlayerDodgeComponent
	var dodge_text := ""
	if dodge_component != null and dodge_component.get_cooldown_ratio() > 0.0:
		dodge_text = "ROLL %.0f%%" % [
			(1.0 - dodge_component.get_cooldown_ratio()) * 100.0
		]
	var hazard_system := get_tree().get_first_node_in_group("hazard_system") as HazardSystem
	if hazard_system == null:
		if dodge_text.is_empty():
			status_label.hide()
		else:
			status_label.text = dodge_text
			status_label.modulate = Color(0.72, 0.92, 1.0, 1.0)
			status_label.show()
		return
	var snapshots := hazard_system.get_player_status_snapshots(player)
	if snapshots.is_empty() and dodge_text.is_empty():
		status_label.hide()
		return
	var parts := PackedStringArray()
	var color := Color(0.9, 0.96, 1.0, 1.0)
	for snapshot in snapshots:
		var id := StringName(snapshot.get("id", &""))
		parts.append("%s %.0fs" % [_status_short_label(id), ceilf(float(snapshot.get("time_left", 0.0)))])
		color = _status_color(id)
	if not dodge_text.is_empty():
		parts.append(dodge_text)
		if snapshots.is_empty():
			color = Color(0.72, 0.92, 1.0, 1.0)
	status_label.text = " ".join(parts)
	status_label.modulate = Color.WHITE if high_contrast else color
	status_label.show()

func _status_short_label(status_id: StringName) -> String:
	match BiomeStatusRuntime.canonical_status_id(status_id):
		&"poison": return "POI"
		&"burn": return "BRN"
		&"bleed": return "BLD"
		&"freeze": return "FRZ"
		&"shock": return "SHK"
		_: return String(status_id).to_upper()

func _status_color(status_id: StringName) -> Color:
	match BiomeStatusRuntime.canonical_status_id(status_id):
		&"poison": return Color(0.44, 1.0, 0.34, 1.0)
		&"burn": return Color(1.0, 0.36, 0.12, 1.0)
		&"bleed": return Color(0.85, 0.08, 0.10, 1.0)
		&"freeze": return Color(0.58, 0.90, 1.0, 1.0)
		&"shock": return Color(1.0, 0.94, 0.18, 1.0)
		_: return Color(0.9, 0.96, 1.0, 1.0)

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
	if adrenaline_bar != null:
		var adrenaline_background_style := StyleBoxFlat.new()
		adrenaline_background_style.bg_color = Color(0.04, 0.10, 0.09, 1.0)
		adrenaline_background_style.corner_radius_top_left = 4
		adrenaline_background_style.corner_radius_top_right = 4
		adrenaline_background_style.corner_radius_bottom_left = 4
		adrenaline_background_style.corner_radius_bottom_right = 4
		adrenaline_bar.add_theme_stylebox_override(
			"background",
			adrenaline_background_style
		)
		var adrenaline_fill_style := StyleBoxFlat.new()
		adrenaline_fill_style.bg_color = Color(0.28, 0.92, 0.62, 1.0)
		adrenaline_fill_style.corner_radius_top_left = 4
		adrenaline_fill_style.corner_radius_top_right = 4
		adrenaline_fill_style.corner_radius_bottom_left = 4
		adrenaline_fill_style.corner_radius_bottom_right = 4
		adrenaline_bar.add_theme_stylebox_override("fill", adrenaline_fill_style)

func _refresh_ammo_widgets(weapon_system: WeaponSystem) -> void:
	if weapon_system == null or weapon_system.weapon_data == null:
		_clear_ammo_pips()
		return
	_clear_ammo_pips()
	if weapon_system.weapon_data.infinite_reserve_ammo:
		ammo_label.text = _format_corner_ammo_text(weapon_system)

func _format_inventory_text(weapon_system: WeaponSystem) -> String:
	if weapon_system == null:
		return ""
	var names := weapon_system.get_inventory_display_names()
	var parts := PackedStringArray()
	for name in names:
		parts.append("[%s]" % name if weapon_system.weapon_data != null and name == weapon_system.weapon_data.display_name else name)
	return "  <  %s  >" % " | ".join(parts)

func _format_corner_ammo_text(weapon_system: WeaponSystem) -> String:
	if weapon_system == null or weapon_system.weapon_data == null:
		return "-"
	if weapon_system.weapon_data.infinite_reserve_ammo:
		if weapon_system.has_special_weapon() and weapon_system.is_fallback_active():
			var special_total := maxi(weapon_system.get_special_ammo_total(), 0)
			return "SP %d" % special_total
		return "RES INF"
	var suffix := " LOW" if weapon_system.low_ammo_active else ""
	return "RES %d%s" % [weapon_system.reserve_ammo, suffix]

func _ensure_ammo_pips(target_count: int) -> void:
	if ammo_pips_container == null:
		ammo_pips.clear()
		return
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

func _clear_ammo_pips() -> void:
	_ensure_ammo_pips(0)
