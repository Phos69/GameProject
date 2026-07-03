extends Control
class_name PlayerWorldHudVisual

const SLOT_COLORS: Array[Color] = [
	Color(0.18, 0.74, 0.95, 1.0),
	Color(0.95, 0.42, 0.34, 1.0),
	Color(0.52, 0.86, 0.32, 1.0),
	Color(0.94, 0.78, 0.28, 1.0)
]
# Faceplate compatto (VIS-007): il pannello 152x64 era largo ~4x il player e
# copriva ostacoli/bersagli sopra l'attore. I font restano >= 10.
const HUD_OFFSET: Vector2 = Vector2(-61.0, -86.0)
const HUD_SIZE: Vector2 = Vector2(122.0, 50.0)
const PANEL_RECT: Rect2 = Rect2(Vector2.ZERO, HUD_SIZE)
const LEVEL_CENTER: Vector2 = Vector2(17.0, 17.0)
const LEVEL_RING_RADIUS: float = 12.0
const AMMO_BAR_RECT: Rect2 = Rect2(Vector2(34.0, 31.0), Vector2(80.0, 13.0))
const HEALTH_BAR_RECT: Rect2 = Rect2(Vector2(34.0, 5.0), Vector2(80.0, 22.0))
const SUPER_BAR_RECT: Rect2 = Rect2(Vector2(114.0, 4.0), Vector2(5.0, 42.0))
const LOW_MAGAZINE_RATIO: float = 0.25
const LEVEL_UP_FLASH_DURATION: float = 0.70
const TEXT_OUTLINE: Color = Color(0.005, 0.008, 0.012, 0.96)
const SUPER_COLOR: Color = Color(0.18, 0.58, 1.0, 1.0)
const SUPER_READY_COLOR: Color = Color(0.42, 0.82, 1.0, 1.0)
const STATUS_FONT_SIZE: int = 10
const BAR_FONT_SIZE: int = 10

var player_slot: int = 1
var slot_color: Color = SLOT_COLORS[0]
var character_profile: Dictionary = {}
var hud_text_scale: float = 1.0
var high_contrast: bool = false
var reduced_motion: bool = false
var glow_intensity: float = 1.0
var animation_time: float = 0.0
var level_up_flash_timer: float = 0.0
var observed_rpg_component: RpgPlayerComponent
var hud_font: Font

func _ready() -> void:
	add_to_group("visual_settings_consumers")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = HUD_OFFSET
	size = HUD_SIZE
	custom_minimum_size = HUD_SIZE
	z_index = 30
	z_as_relative = false
	VisualSettingsManager.sync_consumer(self)
	_sync_rpg_component()
	queue_redraw()

func _exit_tree() -> void:
	_disconnect_rpg_component()

func _process(delta: float) -> void:
	_sync_rpg_component()
	if not reduced_motion:
		animation_time += delta
	level_up_flash_timer = maxf(level_up_flash_timer - delta, 0.0)
	queue_redraw()

func apply_visual_settings(settings: Dictionary) -> void:
	hud_text_scale = clampf(
		float(settings.get("hud_text_scale", 1.0)),
		0.80,
		1.20
	)
	high_contrast = bool(settings.get("high_contrast", false))
	reduced_motion = bool(settings.get("reduced_motion", false))
	glow_intensity = clampf(
		float(settings.get("glow_intensity", 1.0)),
		0.0,
		1.0
	)
	if reduced_motion:
		animation_time = 0.0
	queue_redraw()

func set_player_slot(slot: int) -> void:
	player_slot = clampi(slot, 1, 4)
	slot_color = SLOT_COLORS[player_slot - 1]
	queue_redraw()

func set_slot_color(color: Color) -> void:
	slot_color = color
	queue_redraw()

func set_character_profile(profile: Dictionary) -> void:
	character_profile = profile.duplicate(true)
	queue_redraw()

func get_health_ratio() -> float:
	var health_component := _get_health_component()
	if health_component == null:
		return 0.0
	return health_component.get_health_ratio()

func is_showing_reload() -> bool:
	var weapon_system := _get_weapon_system()
	return weapon_system != null and weapon_system.is_reloading

func get_reload_ratio() -> float:
	var weapon_system := _get_weapon_system()
	if weapon_system == null:
		return 0.0
	return weapon_system.get_reload_ratio()

func get_ammo_ratio() -> float:
	var weapon_system := _get_weapon_system()
	if weapon_system == null or weapon_system.weapon_data == null:
		return 0.0
	var magazine_size := maxi(weapon_system.weapon_data.magazine_size, 1)
	return clampf(
		float(weapon_system.current_ammo) / float(magazine_size),
		0.0,
		1.0
	)

func get_magazine_size() -> int:
	var weapon_system := _get_weapon_system()
	if weapon_system == null or weapon_system.weapon_data == null:
		return 0
	return maxi(weapon_system.weapon_data.magazine_size, 1)

func get_current_ammo() -> int:
	var weapon_system := _get_weapon_system()
	if weapon_system == null:
		return 0
	return maxi(weapon_system.current_ammo, 0)

func get_level() -> int:
	var rpg_component := _get_rpg_component()
	if rpg_component == null or not rpg_component.has_character():
		return 1
	return rpg_component.level

func get_exp_ratio() -> float:
	var rpg_component := _get_rpg_component()
	if rpg_component == null or not rpg_component.has_character():
		return 0.0
	return rpg_component.get_experience_ratio()

func get_super_ratio() -> float:
	var rpg_component := _get_rpg_component()
	if rpg_component == null or not rpg_component.has_character():
		return 0.0
	return rpg_component.get_adrenaline_ratio()

func is_super_ready_display() -> bool:
	var rpg_component := _get_rpg_component()
	return rpg_component != null and rpg_component.is_super_ready()

func get_layout_snapshot() -> Dictionary:
	return {
		"shows_player_label": false,
		"level_center": LEVEL_CENTER,
		"health_bar_rect": HEALTH_BAR_RECT,
		"health_orientation": &"horizontal_two_rows",
		"health_colors": [
			_resolve_health_color(1.0, false),
			_resolve_health_color(0.5, false),
			_resolve_health_color(0.2, false)
		],
		"super_bar_rect": SUPER_BAR_RECT,
		"super_orientation": &"vertical",
		"super_color": SUPER_COLOR,
		"ready_glows_faceplate": true,
		"ammo_bar_rect": AMMO_BAR_RECT,
		"status_font_size": STATUS_FONT_SIZE,
		"bar_font_size": BAR_FONT_SIZE
	}

func _draw() -> void:
	var accent := _resolve_accent_color()
	_draw_panel(accent)
	_draw_level_ring(accent)
	_draw_health()
	_draw_ammo_or_reload(accent)
	_draw_super_bar()

func _draw_panel(accent: Color) -> void:
	var ready := is_super_ready_display()
	if ready:
		var pulse := 1.0
		if not reduced_motion:
			pulse = 0.68 + 0.32 * (0.5 + 0.5 * sin(animation_time * 6.0))
		draw_rect(
			PANEL_RECT.grow(4.0),
			Color(SUPER_READY_COLOR, 0.10 * pulse * glow_intensity),
			true
		)
		draw_rect(
			PANEL_RECT.grow(2.0),
			Color(SUPER_READY_COLOR, 0.34 * pulse * glow_intensity),
			false,
			2.2
		)
	var border := Color.WHITE if high_contrast else Color(accent, 0.92)
	if ready and not high_contrast:
		border = accent.lerp(SUPER_READY_COLOR, 0.72)
	draw_rect(PANEL_RECT.grow(1.0), Color(0.0, 0.0, 0.0, 0.48), true)
	draw_rect(PANEL_RECT, Color(0.016, 0.024, 0.032, 0.88), true)
	draw_rect(PANEL_RECT, border, false, 1.65 if ready else 1.35)

func _draw_health() -> void:
	var health_component := _get_health_component()
	var ratio := 0.0
	var label := "HP --"
	var downed := false
	if health_component != null:
		ratio = health_component.get_health_ratio()
		downed = health_component.is_downed
		label = (
			"DOWN"
			if downed
			else "HP %d/%d" % [
				health_component.current_health,
				health_component.max_health
			]
		)
	var fill_color := _resolve_health_color(ratio, downed)
	_draw_bar(HEALTH_BAR_RECT, ratio, fill_color)
	_draw_text(
		label,
		HEALTH_BAR_RECT.position + Vector2(0.0, 16.0),
		HEALTH_BAR_RECT.size.x,
		_scaled_font_size(STATUS_FONT_SIZE),
		Color.WHITE,
		HORIZONTAL_ALIGNMENT_CENTER,
		1.25,
		true
	)

func _draw_level_ring(accent: Color) -> void:
	var level := get_level()
	var exp_ratio := get_exp_ratio()
	var ring_color := Color.WHITE if high_contrast else accent.lightened(0.18)
	draw_arc(
		LEVEL_CENTER,
		LEVEL_RING_RADIUS,
		0.0,
		TAU,
		34,
		Color(0.05, 0.07, 0.10, 0.95),
		3.4,
		true
	)
	if exp_ratio > 0.0:
		draw_arc(
			LEVEL_CENTER,
			LEVEL_RING_RADIUS,
			-PI * 0.5,
			-PI * 0.5 + TAU * exp_ratio,
			34,
			ring_color,
			3.4,
			true
		)
	if level_up_flash_timer > 0.0:
		var flash_ratio := clampf(
			level_up_flash_timer / LEVEL_UP_FLASH_DURATION,
			0.0,
			1.0
		)
		draw_arc(
			LEVEL_CENTER,
			LEVEL_RING_RADIUS + 4.0 * (1.0 - flash_ratio),
			0.0,
			TAU,
			38,
			Color(ring_color.lightened(0.35), flash_ratio * glow_intensity),
			3.0,
			true
		)
	_draw_text(
		"LV",
		LEVEL_CENTER - Vector2(LEVEL_RING_RADIUS, 4.0),
		LEVEL_RING_RADIUS * 2.0,
		_scaled_font_size(6),
		Color(0.74, 0.84, 0.90, 1.0),
		HORIZONTAL_ALIGNMENT_CENTER,
		0.75,
		false
	)
	_draw_text(
		str(level),
		LEVEL_CENTER - Vector2(LEVEL_RING_RADIUS, -8.0),
		LEVEL_RING_RADIUS * 2.0,
		_scaled_font_size(12),
		Color.WHITE,
		HORIZONTAL_ALIGNMENT_CENTER,
		1.2,
		true
	)

func _draw_ammo_or_reload(accent: Color) -> void:
	var weapon_system := _get_weapon_system()
	if weapon_system == null or weapon_system.weapon_data == null:
		_draw_bar(AMMO_BAR_RECT, 0.0, Color(0.42, 0.48, 0.52, 1.0))
		_draw_center_bar_text(AMMO_BAR_RECT, "AMMO --", Color(0.76, 0.82, 0.86, 1.0))
		return
	if weapon_system.is_reloading:
		_draw_reload_bar(weapon_system)
		return
	_draw_ammo_bar(weapon_system, accent)

func _draw_reload_bar(weapon_system: WeaponSystem) -> void:
	var ratio := weapon_system.get_reload_ratio()
	_draw_bar(AMMO_BAR_RECT, ratio, Color(1.0, 0.70, 0.22, 1.0))
	var progress_x := AMMO_BAR_RECT.position.x + AMMO_BAR_RECT.size.x * ratio
	draw_line(
		Vector2(progress_x, AMMO_BAR_RECT.position.y - 1.0),
		Vector2(progress_x, AMMO_BAR_RECT.position.y + AMMO_BAR_RECT.size.y + 1.0),
		Color(1.0, 0.95, 0.55, 0.88),
		1.2,
		true
	)
	_draw_center_bar_text(
		AMMO_BAR_RECT,
		"RELOAD %d%%" % roundi(ratio * 100.0),
		Color(1.0, 0.92, 0.58, 1.0)
	)

func _draw_ammo_bar(weapon_system: WeaponSystem, accent: Color) -> void:
	var magazine_size := maxi(weapon_system.weapon_data.magazine_size, 1)
	var current_ammo := clampi(weapon_system.current_ammo, 0, magazine_size)
	var ratio := float(current_ammo) / float(magazine_size)
	var fill_color := _resolve_ammo_color(weapon_system, ratio, accent)
	_draw_bar(AMMO_BAR_RECT, ratio, fill_color)
	_draw_ammo_segments(magazine_size)
	if current_ammo == 0:
		_draw_low_ammo_frame(Color(1.0, 0.20, 0.12, 1.0))
		_draw_center_bar_text(
			AMMO_BAR_RECT,
			"AMMO 0/%d" % magazine_size,
			Color(1.0, 0.72, 0.58, 1.0)
		)
	elif ratio <= LOW_MAGAZINE_RATIO:
		_draw_low_ammo_frame(Color(1.0, 0.56, 0.16, 1.0))
		_draw_center_bar_text(
			AMMO_BAR_RECT,
			"AMMO %d/%d" % [current_ammo, magazine_size],
			Color(1.0, 0.90, 0.50, 1.0)
		)
	else:
		_draw_center_bar_text(
			AMMO_BAR_RECT,
			"AMMO %d/%d" % [current_ammo, magazine_size],
			Color(0.92, 0.98, 1.0, 1.0)
		)

func _draw_super_bar() -> void:
	var super_ratio := get_super_ratio()
	var ready := is_super_ready_display()
	var fill_color := SUPER_READY_COLOR if ready else SUPER_COLOR
	_draw_vertical_bar(SUPER_BAR_RECT, super_ratio, fill_color)

func _draw_bar(rect: Rect2, ratio: float, fill_color: Color) -> void:
	var clamped_ratio := clampf(ratio, 0.0, 1.0)
	draw_rect(rect, Color(0.055, 0.065, 0.078, 0.96), true)
	if clamped_ratio > 0.0:
		draw_rect(
			Rect2(rect.position, Vector2(rect.size.x * clamped_ratio, rect.size.y)),
			fill_color,
			true
		)
	draw_rect(rect, Color(0.0, 0.0, 0.0, 0.72), false, 1.0)

func _draw_vertical_bar(rect: Rect2, ratio: float, fill_color: Color) -> void:
	var clamped_ratio := clampf(ratio, 0.0, 1.0)
	draw_rect(rect, Color(0.055, 0.065, 0.078, 0.96), true)
	if clamped_ratio > 0.0:
		var fill_height := rect.size.y * clamped_ratio
		draw_rect(
			Rect2(
				Vector2(rect.position.x, rect.end.y - fill_height),
				Vector2(rect.size.x, fill_height)
			),
			fill_color,
			true
		)
	draw_rect(rect, Color(0.0, 0.0, 0.0, 0.72), false, 1.0)

func _draw_ammo_segments(magazine_size: int) -> void:
	if magazine_size <= 1 or magazine_size > 12:
		return
	for index in range(1, magazine_size):
		var x := AMMO_BAR_RECT.position.x + AMMO_BAR_RECT.size.x * float(index) / float(magazine_size)
		draw_line(
			Vector2(x, AMMO_BAR_RECT.position.y + 1.0),
			Vector2(x, AMMO_BAR_RECT.end.y - 1.0),
			Color(0.0, 0.0, 0.0, 0.50),
			1.0,
			false
		)

func _draw_low_ammo_frame(color: Color) -> void:
	var alpha := 0.88
	if not reduced_motion:
		alpha = 0.58 + 0.30 * (0.5 + 0.5 * sin(animation_time * 8.0))
	draw_rect(AMMO_BAR_RECT.grow(1.0), Color(color, alpha), false, 1.4)

func _draw_center_bar_text(rect: Rect2, text: String, color: Color) -> void:
	_draw_text(
		text,
		rect.position + Vector2(0.0, 10.0),
		rect.size.x,
		_scaled_font_size(BAR_FONT_SIZE),
		color,
		HORIZONTAL_ALIGNMENT_CENTER,
		1.25,
		true
	)

func _resolve_health_color(ratio: float, downed: bool) -> Color:
	if downed or ratio <= 0.30:
		return Color(1.0, 0.28, 0.20, 1.0)
	if ratio <= 0.60:
		return Color(1.0, 0.70, 0.24, 1.0)
	return Color(0.30, 0.90, 0.44, 1.0)

func _resolve_ammo_color(
	weapon_system: WeaponSystem,
	ratio: float,
	accent: Color
) -> Color:
	if high_contrast:
		return Color.WHITE
	if ratio <= 0.0:
		return Color(1.0, 0.20, 0.12, 1.0)
	if ratio <= LOW_MAGAZINE_RATIO:
		return Color(1.0, 0.58, 0.16, 1.0)
	if weapon_system.weapon_data.visual_data != null:
		return weapon_system.weapon_data.visual_data.projectile_color
	return accent.lightened(0.18)

func _resolve_accent_color() -> Color:
	if high_contrast:
		return Color.WHITE
	if not character_profile.is_empty():
		return Color(character_profile.get("palette_accent", slot_color))
	var rpg_component := _get_rpg_component()
	if rpg_component != null and rpg_component.has_character():
		return Color(rpg_component.character_profile.get("palette_accent", slot_color))
	return slot_color

func _get_health_component() -> HealthComponent:
	var parent := get_parent()
	if parent == null:
		return null
	return parent.get_node_or_null("HealthComponent") as HealthComponent

func _get_weapon_system() -> WeaponSystem:
	var parent := get_parent()
	if parent == null:
		return null
	return parent.get_node_or_null("WeaponSystem") as WeaponSystem

func _get_rpg_component() -> RpgPlayerComponent:
	var parent := get_parent()
	if parent == null:
		return null
	return parent.get_node_or_null("RpgPlayerComponent") as RpgPlayerComponent

func _sync_rpg_component() -> void:
	var next_component := _get_rpg_component()
	if next_component == observed_rpg_component:
		return
	_disconnect_rpg_component()
	observed_rpg_component = next_component
	if observed_rpg_component == null:
		return
	var level_callback := Callable(self, "_on_rpg_leveled_up")
	if not observed_rpg_component.leveled_up.is_connected(level_callback):
		observed_rpg_component.leveled_up.connect(level_callback)
	var character_callback := Callable(self, "_on_rpg_character_changed")
	if not observed_rpg_component.character_changed.is_connected(character_callback):
		observed_rpg_component.character_changed.connect(character_callback)
	if observed_rpg_component.has_character():
		set_character_profile(observed_rpg_component.character_profile)

func _disconnect_rpg_component() -> void:
	if observed_rpg_component == null or not is_instance_valid(observed_rpg_component):
		observed_rpg_component = null
		return
	var level_callback := Callable(self, "_on_rpg_leveled_up")
	if observed_rpg_component.leveled_up.is_connected(level_callback):
		observed_rpg_component.leveled_up.disconnect(level_callback)
	var character_callback := Callable(self, "_on_rpg_character_changed")
	if observed_rpg_component.character_changed.is_connected(character_callback):
		observed_rpg_component.character_changed.disconnect(character_callback)
	observed_rpg_component = null

func _on_rpg_leveled_up(_level: int) -> void:
	level_up_flash_timer = LEVEL_UP_FLASH_DURATION
	queue_redraw()

func _on_rpg_character_changed(_character_id: StringName, profile: Dictionary) -> void:
	set_character_profile(profile)

func _draw_text(
	text: String,
	baseline: Vector2,
	width: float,
	font_size: int,
	color: Color,
	alignment: HorizontalAlignment,
	outline_size: float,
	bold: bool
) -> void:
	var font := _get_hud_font()
	if font == null:
		return
	var outline_offsets: Array[Vector2] = [
		Vector2(-outline_size, 0.0),
		Vector2(outline_size, 0.0),
		Vector2(0.0, -outline_size),
		Vector2(0.0, outline_size)
	]
	for offset in outline_offsets:
		draw_string(font, baseline + offset, text, alignment, width, font_size, TEXT_OUTLINE)
	draw_string(font, baseline, text, alignment, width, font_size, color)
	if bold:
		draw_string(font, baseline + Vector2(0.45, 0.0), text, alignment, width, font_size, color)

func _get_hud_font() -> Font:
	if hud_font == null:
		hud_font = get_theme_font("font", "Label")
	return hud_font

func _scaled_font_size(base_size: int) -> int:
	return maxi(1, roundi(float(base_size) * hud_text_scale))
