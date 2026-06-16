extends Node
class_name VideoSettingsManager

signal video_settings_changed(settings: Dictionary)

const DEFAULT_SETTINGS: Dictionary = {
	"display_mode": &"windowed",
	"borderless": false,
	"resolution_width": 1280,
	"resolution_height": 720,
	"max_fps": 60,
	"vsync": true
}
const RESOLUTION_PRESETS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160)
]
const FPS_LIMITS: Array[int] = [
	0,
	30,
	60,
	120,
	144,
	165,
	240
]

var settings: Dictionary = DEFAULT_SETTINGS.duplicate(true)

func _enter_tree() -> void:
	add_to_group("video_settings_manager")

func _ready() -> void:
	_apply_settings(false)

func set_display_mode(display_mode: StringName) -> bool:
	if not [&"windowed", &"fullscreen", &"exclusive_fullscreen"].has(
		display_mode
	):
		return false
	settings["display_mode"] = display_mode
	_apply_settings()
	return true

func set_borderless(enabled: bool) -> void:
	settings["borderless"] = enabled
	_apply_settings()

func set_resolution(size: Vector2i) -> bool:
	if size.x < 640 or size.y < 360:
		return false
	settings["resolution_width"] = size.x
	settings["resolution_height"] = size.y
	_apply_settings()
	return true

func set_max_fps(limit: int) -> bool:
	if not FPS_LIMITS.has(limit):
		return false
	settings["max_fps"] = limit
	_apply_settings()
	return true

func set_vsync(enabled: bool) -> void:
	settings["vsync"] = enabled
	_apply_settings()

func get_setting(setting_id: StringName, fallback: Variant = null) -> Variant:
	return settings.get(setting_id, fallback)

func get_settings_data() -> Dictionary:
	return settings.duplicate(true)

func restore_settings_data(data: Dictionary) -> void:
	var restored := DEFAULT_SETTINGS.duplicate(true)
	var display_mode := StringName(data.get("display_mode", &"windowed"))
	if [&"windowed", &"fullscreen", &"exclusive_fullscreen"].has(
		display_mode
	):
		restored["display_mode"] = display_mode
	restored["borderless"] = bool(data.get("borderless", false))
	restored["resolution_width"] = clampi(
		int(data.get("resolution_width", 1280)),
		640,
		7680
	)
	restored["resolution_height"] = clampi(
		int(data.get("resolution_height", 720)),
		360,
		4320
	)
	var max_fps := int(data.get("max_fps", 60))
	if FPS_LIMITS.has(max_fps):
		restored["max_fps"] = max_fps
	restored["vsync"] = bool(data.get("vsync", true))
	settings = restored
	_apply_settings()

func _apply_settings(emit_change: bool = true) -> void:
	Engine.max_fps = int(settings.get("max_fps", 60))
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(
			DisplayServer.VSYNC_ENABLED
			if bool(settings.get("vsync", true))
			else DisplayServer.VSYNC_DISABLED
		)
		_apply_window_mode()
		if StringName(settings.get("display_mode", &"windowed")) == &"windowed":
			DisplayServer.window_set_size(Vector2i(
				int(settings.get("resolution_width", 1280)),
				int(settings.get("resolution_height", 720))
			))
	if emit_change:
		video_settings_changed.emit(get_settings_data())

func _apply_window_mode() -> void:
	var display_mode := StringName(settings.get("display_mode", &"windowed"))
	match display_mode:
		&"fullscreen":
			DisplayServer.window_set_flag(
				DisplayServer.WINDOW_FLAG_BORDERLESS,
				true
			)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		&"exclusive_fullscreen":
			DisplayServer.window_set_flag(
				DisplayServer.WINDOW_FLAG_BORDERLESS,
				false
			)
			DisplayServer.window_set_mode(
				DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
			)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(
				DisplayServer.WINDOW_FLAG_BORDERLESS,
				bool(settings.get("borderless", false))
			)
