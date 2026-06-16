extends PanelContainer
class_name CharacterDetailPanel

const CHARACTER_GAMEPLAY_PREVIEW_SCRIPT := preload(
	"res://game/ui/character_gameplay_preview.gd"
)

var preview: Control
var hero_label: Label
var class_label: Label
var style_label: Label
var weapon_label: Label
var passive_label: Label
var super_label: Label
var stats_rows: Dictionary = {}
var current_profile: Dictionary = {}
var current_weapon_data: WeaponData

func _ready() -> void:
	custom_minimum_size = Vector2(318.0, 398.0)
	add_theme_stylebox_override("panel", _make_panel_style())
	_build_ui()

func set_profile(profile: Dictionary, weapon_data: WeaponData = null) -> void:
	current_profile = profile.duplicate(true)
	current_weapon_data = weapon_data
	if current_profile.is_empty():
		hero_label.text = "SURVIVOR DOSSIER"
		class_label.text = "Focus a card"
		style_label.text = ""
		weapon_label.text = ""
		passive_label.text = ""
		super_label.text = ""
		preview.call("set_profile", {}, null)
		for stat_id in stats_rows.keys():
			_set_stat_row(StringName(stat_id), 0.0, "")
		return
	hero_label.text = str(current_profile.get("hero_name", current_profile.get("display_name", "Survivor"))).to_upper()
	class_label.text = "%s / %s" % [
		str(current_profile.get("class_name", "Survivor")),
		str(current_profile.get("base_weapon_name", "Weapon"))
	]
	style_label.text = str(current_profile.get("style_description", ""))
	weapon_label.text = "Weapon: %s  Range %dm" % [
		str(current_profile.get("base_weapon_name", "Weapon")),
		int(_weapon_range())
	]
	passive_label.text = "Passive: %s\n%s" % [
		str(current_profile.get("passive_name", "")),
		str(current_profile.get("passive_description", ""))
	]
	super_label.text = "Super: %s\n%s" % [
		str(current_profile.get("super_name", "")),
		str(current_profile.get("super_description", ""))
	]
	preview.call("set_profile", current_profile, current_weapon_data)
	_update_stats()

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 7)
	margin.add_child(content)

	hero_label = Label.new()
	hero_label.add_theme_font_size_override("font_size", 20)
	hero_label.modulate = Color(0.93, 0.96, 1.0, 1.0)
	hero_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero_label.text = "SURVIVOR DOSSIER"
	content.add_child(hero_label)

	class_label = Label.new()
	class_label.add_theme_font_size_override("font_size", 13)
	class_label.modulate = Color(0.72, 0.82, 0.90, 1.0)
	class_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(class_label)

	preview = CHARACTER_GAMEPLAY_PREVIEW_SCRIPT.new() as Control
	preview.custom_minimum_size = Vector2(292.0, 154.0)
	content.add_child(preview)

	style_label = _make_wrapped_label(12, 3, Color(0.86, 0.90, 0.94, 1.0))
	content.add_child(style_label)

	var stats := VBoxContainer.new()
	stats.add_theme_constant_override("separation", 4)
	content.add_child(stats)
	_add_stat_row(stats, &"hp", "HP")
	_add_stat_row(stats, &"attack", "ATK")
	_add_stat_row(stats, &"defense", "DEF")
	_add_stat_row(stats, &"speed", "SPD")
	_add_stat_row(stats, &"range", "RNG")

	weapon_label = _make_wrapped_label(11, 1, Color(0.76, 0.85, 0.92, 1.0))
	content.add_child(weapon_label)
	passive_label = _make_wrapped_label(11, 2, Color(0.82, 0.88, 0.94, 1.0))
	content.add_child(passive_label)
	super_label = _make_wrapped_label(11, 2, Color(0.82, 0.88, 0.94, 1.0))
	content.add_child(super_label)

func _make_wrapped_label(font_size: int, lines: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.max_lines_visible = lines
	label.modulate = color
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

func _add_stat_row(parent: VBoxContainer, stat_id: StringName, label_text: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(36.0, 17.0)
	label.add_theme_font_size_override("font_size", 11)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(150.0, 14.0)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.show_percentage = false
	bar.min_value = 0.0
	bar.max_value = 1.0
	row.add_child(bar)
	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(54.0, 17.0)
	value_label.add_theme_font_size_override("font_size", 11)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(value_label)
	stats_rows[stat_id] = {
		"bar": bar,
		"value": value_label
	}

func _update_stats() -> void:
	_set_stat_row(&"hp", float(current_profile.get("max_hp", 0)) / 140.0, "%d" % int(current_profile.get("max_hp", 0)))
	_set_stat_row(&"attack", float(current_profile.get("attack", 0)) / 14.0, "%d" % int(current_profile.get("attack", 0)))
	_set_stat_row(&"defense", float(current_profile.get("defense", 0)) / 8.0, "%d" % int(current_profile.get("defense", 0)))
	_set_stat_row(&"speed", float(current_profile.get("speed", 1.0)) / 1.20, "%.2f" % float(current_profile.get("speed", 1.0)))
	_set_stat_row(&"range", _weapon_range() / 800.0, "%dm" % int(_weapon_range()))

func _set_stat_row(stat_id: StringName, ratio: float, text: String) -> void:
	var row := stats_rows.get(stat_id, {}) as Dictionary
	if row.is_empty():
		return
	var bar := row.get("bar") as ProgressBar
	if bar != null:
		bar.value = clampf(ratio, 0.0, 1.0)
	var value_label := row.get("value") as Label
	if value_label != null:
		value_label.text = text

func _weapon_range() -> float:
	if current_weapon_data == null:
		return 0.0
	return current_weapon_data.max_range

func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.030, 0.042, 0.055, 0.97)
	style.border_color = Color(0.26, 0.34, 0.40, 1.0)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	return style
