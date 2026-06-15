extends PanelContainer
class_name PlayerHudCard

var player_slot: int = 1
var slot_color: Color = Color(0.18, 0.74, 0.95, 1.0)
var slot_label: Label
var weapon_icon: WeaponIcon
var weapon_label: Label
var health_bar: ProgressBar
var health_label: Label
var ammo_label: Label

func _ready() -> void:
	custom_minimum_size = Vector2(272.0, 92.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
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
	slot_label.text = "P%d" % player_slot
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
			if health_ratio <= 0.30
			else Color(0.90, 0.96, 0.98, 1.0)
		)
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

func _build_ui() -> void:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	add_child(content)

	var top_row := HBoxContainer.new()
	content.add_child(top_row)
	slot_label = Label.new()
	slot_label.custom_minimum_size = Vector2(42.0, 24.0)
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
	content.add_child(ammo_row)
	var ammo_icon := Label.new()
	ammo_icon.text = "||"
	ammo_icon.custom_minimum_size = Vector2(28.0, 20.0)
	ammo_icon.modulate = Color(1.0, 0.70, 0.24, 1.0)
	ammo_row.add_child(ammo_icon)
	ammo_label = Label.new()
	ammo_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ammo_label.add_theme_font_size_override("font_size", 17)
	ammo_row.add_child(ammo_label)

func _apply_style() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.025, 0.04, 0.05, 0.92)
	panel_style.border_color = slot_color
	panel_style.set_border_width_all(2)
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
		slot_label.modulate = slot_color.lightened(0.2)
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
