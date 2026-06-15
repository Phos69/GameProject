extends PanelContainer
class_name CombatAnnouncement

var title_label: Label
var subtitle_label: Label
var display_timer: float = 0.0
var display_duration: float = 0.0
var accent_color: Color = Color(1.0, 0.72, 0.24, 1.0)
var announcement_id: StringName = &""
var hud_text_scale: float = 1.0
var high_contrast: bool = false
var reduced_motion: bool = false

func _ready() -> void:
	add_to_group("visual_settings_consumers")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 0.5
	anchor_top = 0.23
	anchor_right = 0.5
	anchor_bottom = 0.23
	offset_left = -250.0
	offset_top = -54.0
	offset_right = 250.0
	offset_bottom = 54.0
	pivot_offset = Vector2(250.0, 54.0)
	_build_ui()
	hide()
	VisualSettingsManager.sync_consumer(self)

func apply_visual_settings(settings: Dictionary) -> void:
	hud_text_scale = clampf(
		float(settings.get("hud_text_scale", 1.0)),
		0.80,
		1.20
	)
	high_contrast = bool(settings.get("high_contrast", false))
	reduced_motion = bool(settings.get("reduced_motion", false))
	if title_label != null:
		title_label.add_theme_font_size_override(
			"font_size",
			roundi(28.0 * hud_text_scale)
		)
	if subtitle_label != null:
		subtitle_label.add_theme_font_size_override(
			"font_size",
			roundi(15.0 * hud_text_scale)
		)
	_apply_style()

func _process(delta: float) -> void:
	if display_timer <= 0.0:
		return
	display_timer = maxf(display_timer - delta, 0.0)
	var progress := 1.0 - display_timer / maxf(display_duration, 0.01)
	var fade := minf(progress / 0.12, (1.0 - progress) / 0.18)
	modulate.a = clampf(fade, 0.0, 1.0)
	scale = (
		Vector2.ONE
		if reduced_motion
		else Vector2.ONE * lerpf(
			1.06,
			1.0,
			minf(progress / 0.18, 1.0)
		)
	)
	if display_timer <= 0.0:
		hide()

func show_announcement(
	id: StringName,
	title: String,
	subtitle: String,
	color: Color,
	duration: float = 1.8
) -> void:
	announcement_id = id
	accent_color = color
	display_duration = maxf(duration, 0.25)
	display_timer = display_duration
	title_label.text = title
	subtitle_label.text = subtitle
	subtitle_label.visible = not subtitle.is_empty()
	title_label.modulate = accent_color.lightened(0.18)
	subtitle_label.modulate = Color(0.88, 0.92, 0.94, 1.0)
	_apply_style()
	modulate.a = 0.0
	scale = Vector2.ONE if reduced_motion else Vector2(1.06, 1.06)
	show()

func is_active() -> bool:
	return display_timer > 0.0 and visible

func _build_ui() -> void:
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 2)
	add_child(content)

	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_constant_override("outline_size", 5)
	title_label.add_theme_color_override("font_outline_color", Color(0.01, 0.015, 0.02, 0.95))
	content.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_font_size_override("font_size", 15)
	subtitle_label.add_theme_constant_override("outline_size", 3)
	subtitle_label.add_theme_color_override("font_outline_color", Color(0.01, 0.015, 0.02, 0.95))
	content.add_child(subtitle_label)
	_apply_style()

func _apply_style() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.02, 0.025, 0.04, 0.88)
	panel_style.border_color = (
		Color.WHITE if high_contrast else Color(accent_color, 0.92)
	)
	panel_style.border_width_top = 3 if high_contrast else 2
	panel_style.border_width_bottom = 3 if high_contrast else 2
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.corner_radius_bottom_right = 10
	panel_style.content_margin_left = 20.0
	panel_style.content_margin_right = 20.0
	panel_style.content_margin_top = 10.0
	panel_style.content_margin_bottom = 10.0
	add_theme_stylebox_override("panel", panel_style)
