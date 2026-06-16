extends Button
class_name CharacterSelectCard

var character_profile: Dictionary = {}
var portrait_texture: Texture2D
var weapon_data: WeaponData
var class_icon: RpgHudIcon
var weapon_icon: WeaponIcon
var portrait: TextureRect
var hero_label: Label
var class_label: Label
var weapon_label: Label
var passive_label: Label
var super_label: Label
var selected_for_current_slot: bool = false
var assigned_slots: Array[int] = []
var current_slot: int = 1
var animation_time: float = 0.0
var ui_built: bool = false

func _ready() -> void:
	custom_minimum_size = Vector2(254.0, 184.0)
	focus_mode = Control.FOCUS_ALL
	clip_contents = true
	flat = true
	_add_transparent_button_styles()
	_ensure_ui()
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	animation_time += delta
	if has_focus() or is_hovered() or selected_for_current_slot:
		queue_redraw()

func set_profile(
	profile: Dictionary,
	next_portrait_texture: Texture2D,
	next_weapon_data: WeaponData
) -> void:
	_ensure_ui()
	character_profile = profile.duplicate(true)
	portrait_texture = next_portrait_texture
	weapon_data = next_weapon_data
	_refresh_content()
	queue_redraw()

func set_selection_state(
	is_selected_for_current_slot: bool,
	next_assigned_slots: Array[int],
	next_current_slot: int
) -> void:
	selected_for_current_slot = is_selected_for_current_slot
	assigned_slots = next_assigned_slots.duplicate()
	current_slot = next_current_slot
	queue_redraw()

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 50)
	add_child(margin)

	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 5)
	margin.add_child(content)

	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override("separation", 7)
	content.add_child(header)

	class_icon = RpgHudIcon.new()
	class_icon.custom_minimum_size = Vector2(34.0, 32.0)
	header.add_child(class_icon)

	var title_box := VBoxContainer.new()
	title_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 0)
	header.add_child(title_box)

	hero_label = Label.new()
	hero_label.add_theme_font_size_override("font_size", 15)
	hero_label.max_lines_visible = 1
	hero_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hero_label.modulate = Color(0.95, 0.98, 1.0, 1.0)
	title_box.add_child(hero_label)

	class_label = Label.new()
	class_label.add_theme_font_size_override("font_size", 11)
	class_label.max_lines_visible = 1
	class_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	class_label.modulate = Color(0.68, 0.78, 0.86, 1.0)
	title_box.add_child(class_label)

	var body := HBoxContainer.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_constant_override("separation", 8)
	content.add_child(body)

	portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(76.0, 74.0)
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(portrait)

	var info := VBoxContainer.new()
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	body.add_child(info)

	var weapon_row := HBoxContainer.new()
	weapon_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	weapon_row.add_theme_constant_override("separation", 4)
	info.add_child(weapon_row)

	weapon_icon = WeaponIcon.new()
	weapon_icon.custom_minimum_size = Vector2(34.0, 22.0)
	weapon_row.add_child(weapon_icon)

	weapon_label = Label.new()
	weapon_label.add_theme_font_size_override("font_size", 11)
	weapon_label.max_lines_visible = 1
	weapon_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	weapon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	weapon_row.add_child(weapon_label)

	passive_label = _make_small_line()
	info.add_child(passive_label)
	super_label = _make_small_line()
	info.add_child(super_label)

func _ensure_ui() -> void:
	if ui_built:
		return
	ui_built = true
	_build_ui()

func _make_small_line() -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 10)
	label.max_lines_visible = 1
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.modulate = Color(0.80, 0.86, 0.91, 1.0)
	return label

func _refresh_content() -> void:
	var character_id := StringName(character_profile.get("id", &""))
	var primary := Color(character_profile.get("palette_primary", Color(0.22, 0.58, 0.82, 1.0)))
	var accent := Color(character_profile.get("palette_accent", Color(1.0, 0.78, 0.28, 1.0)))
	hero_label.text = str(character_profile.get("hero_name", character_profile.get("display_name", "Survivor")))
	class_label.text = "%s / %s" % [
		str(character_profile.get("class_name", "Survivor")),
		str(character_profile.get("base_weapon_name", "Weapon"))
	]
	weapon_label.text = "%s  %dm" % [
		str(character_profile.get("base_weapon_name", "Weapon")),
		int(_weapon_range())
	]
	passive_label.text = "P: %s" % str(character_profile.get("passive_name", ""))
	super_label.text = "S: %s" % str(character_profile.get("super_name", ""))
	portrait.texture = portrait_texture
	class_icon.set_icon(character_id, accent)
	weapon_icon.set_visual_data(weapon_data.visual_data if weapon_data != null else null)
	tooltip_text = "%s\n%s\n%s\n%s" % [
		hero_label.text,
		str(character_profile.get("style_description", "")),
		str(character_profile.get("passive_description", "")),
		str(character_profile.get("super_description", ""))
	]
	modulate = Color.WHITE if not character_profile.is_empty() else Color(0.65, 0.70, 0.75, 1.0)
	if primary.get_luminance() > 0.64:
		hero_label.modulate = Color(0.10, 0.13, 0.16, 1.0)

func _draw() -> void:
	var primary := Color(character_profile.get("palette_primary", Color(0.22, 0.58, 0.82, 1.0)))
	var secondary := Color(character_profile.get("palette_secondary", Color(0.12, 0.16, 0.20, 1.0)))
	var accent := Color(character_profile.get("palette_accent", Color(1.0, 0.78, 0.28, 1.0)))
	var rect := Rect2(Vector2(1.0, 1.0), size - Vector2(2.0, 2.0))
	var focus_ratio := 1.0 if has_focus() or is_hovered() else 0.0
	var selected_ratio := 1.0 if selected_for_current_slot else 0.0
	var bg := Color(0.030, 0.040, 0.052, 0.98).lerp(secondary.darkened(0.32), 0.38)
	if selected_for_current_slot:
		bg = bg.lerp(primary.darkened(0.18), 0.34)
	draw_rect(rect, bg, true)
	draw_rect(Rect2(Vector2(8.0, 48.0), Vector2(size.x - 16.0, 72.0)), Color(0.0, 0.0, 0.0, 0.18), true)
	var border := Color(0.18, 0.24, 0.30, 1.0).lerp(accent, maxf(focus_ratio, selected_ratio))
	if selected_for_current_slot:
		var pulse := 0.55 + 0.45 * sin(animation_time * 4.0)
		border = border.lerp(Color.WHITE, pulse * 0.22)
	draw_rect(rect, border, false, 2.0 + selected_ratio)
	if has_focus():
		draw_rect(rect.grow(-4.0), Color.WHITE, false, 1.4)
	_draw_assignment_pips(accent)
	_draw_stats(accent)

func _draw_assignment_pips(accent: Color) -> void:
	if assigned_slots.is_empty():
		return
	for index in range(assigned_slots.size()):
		var slot := assigned_slots[index]
		var center := Vector2(size.x - 16.0 - float(index) * 18.0, 18.0)
		draw_circle(center, 7.0, Color(0.0, 0.0, 0.0, 0.45))
		draw_circle(center, 5.0, accent.lightened(0.15))
		var font := get_theme_font("font", "Label")
		draw_string(
			font,
			center + Vector2(-3.5, 4.0),
			str(slot),
			HORIZONTAL_ALIGNMENT_CENTER,
			7.0,
			9,
			Color(0.02, 0.025, 0.03, 1.0)
		)

func _draw_stats(accent: Color) -> void:
	var labels := ["HP", "ATK", "DEF", "SPD", "RNG"]
	var ratios := [
		float(character_profile.get("max_hp", 0)) / 140.0,
		float(character_profile.get("attack", 0)) / 14.0,
		float(character_profile.get("defense", 0)) / 8.0,
		float(character_profile.get("speed", 1.0)) / 1.20,
		_weapon_range() / 800.0
	]
	var font := get_theme_font("font", "Label")
	var start_y := size.y - 40.0
	for index in range(labels.size()):
		var x := 12.0 + float(index) * ((size.x - 24.0) / 5.0)
		var width := ((size.x - 34.0) / 5.0)
		var bar_rect := Rect2(Vector2(x, start_y + 15.0), Vector2(width, 7.0))
		draw_string(font, Vector2(x, start_y + 10.0), labels[index], HORIZONTAL_ALIGNMENT_LEFT, width, 8, Color(0.72, 0.80, 0.86, 1.0))
		draw_rect(bar_rect, Color(0.08, 0.10, 0.12, 1.0), true)
		draw_rect(Rect2(bar_rect.position, Vector2(bar_rect.size.x * clampf(ratios[index], 0.0, 1.0), bar_rect.size.y)), accent, true)

func _weapon_range() -> float:
	if weapon_data == null:
		return 0.0
	return weapon_data.max_range

func _add_transparent_button_styles() -> void:
	var empty := StyleBoxEmpty.new()
	add_theme_stylebox_override("normal", empty)
	add_theme_stylebox_override("hover", empty)
	add_theme_stylebox_override("pressed", empty)
	add_theme_stylebox_override("focus", empty)
	add_theme_stylebox_override("disabled", empty)
