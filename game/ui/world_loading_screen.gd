extends CanvasLayer
class_name WorldLoadingScreen

# Full-screen overlay shown while a mode builds its world/scene. It animates every
# frame (heavy work runs off the main thread or across frames), so the window reads
# as "loading" instead of a frozen application.
#
# Progress model: each build phase declares a [floor, ceil] band via set_phase().
# The displayed fill eases from floor toward ceil while the phase runs (so the bar
# keeps moving during an opaque worker-thread step) and the next phase raises the
# floor. complete() fills it to 100%.

const BACKDROP_COLOR := Color(0.03, 0.05, 0.08, 1.0)
const BAR_SIZE := Vector2(360.0, 10.0)
const TRACK_COLOR := Color(0.12, 0.15, 0.20, 1.0)
const FILL_COLOR := Color(0.45, 0.78, 0.95, 1.0)
# Exponential approach toward the current phase ceiling: fast at first, easing as it
# nears the ceiling so an opaque phase never visually completes before it really does.
const EASE_SPEED := 2.6

var _title_label: Label
var _status_label: Label
var _bar_fill: ColorRect
var _message: String = "Caricamento..."
var _floor: float = 0.0
var _ceil: float = 0.0
var _shown: float = 0.0

func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = BACKDROP_COLOR
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.add_child(center)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 16)
	center.add_child(column)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 28)
	column.add_child(_title_label)

	var bar_bg := ColorRect.new()
	bar_bg.name = "Track"
	bar_bg.color = TRACK_COLOR
	bar_bg.custom_minimum_size = BAR_SIZE
	column.add_child(bar_bg)
	_bar_fill = ColorRect.new()
	_bar_fill.name = "Fill"
	_bar_fill.color = FILL_COLOR
	_bar_fill.position = Vector2.ZERO
	_bar_fill.size = Vector2(0.0, BAR_SIZE.y)
	bar_bg.add_child(_bar_fill)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.modulate = Color(0.7, 0.8, 0.95, 1.0)
	column.add_child(_status_label)

	set_message(_message)
	_update_bar()

func set_message(text: String) -> void:
	_message = text
	if _title_label != null:
		_title_label.text = _message

# Declares the current build phase. The fill eases from `floor_value` toward
# `ceil_value` while the phase runs; the next phase raises the floor.
func set_phase(text: String, floor_value: float, ceil_value: float) -> void:
	set_message(text)
	_floor = clampf(floor_value, 0.0, 1.0)
	_ceil = clampf(ceil_value, _floor, 1.0)
	if _shown < _floor:
		_shown = _floor
	_update_bar()

# Hard-sets the displayed progress (e.g. for cheap, deterministic step counters).
func set_progress(value: float) -> void:
	var clamped := clampf(value, 0.0, 1.0)
	_floor = clamped
	_ceil = clamped
	_shown = clamped
	_update_bar()

func complete() -> void:
	_floor = 1.0
	_ceil = 1.0
	_shown = 1.0
	_update_bar()

# Convenience for modes whose setup is synchronous and instant (Dungeon, Tower
# Defense): shows the overlay as a short, consistent "entering mode" transition
# that fills and then completes after `duration`, instead of a sub-frame flash.
static func show_brief(
	host: Node,
	message: String,
	duration: float = 0.5
) -> WorldLoadingScreen:
	if host == null:
		return null
	var tree := host.get_tree()
	if tree == null:
		return null
	var screen := WorldLoadingScreen.new()
	screen.name = "WorldLoadingScreen"
	var scene := tree.current_scene
	if scene != null and scene != host:
		scene.add_child(screen)
	else:
		host.add_child(screen)
	screen.set_phase(message, 0.0, 1.0)
	var timer := tree.create_timer(maxf(duration, 0.05))
	timer.timeout.connect(func() -> void:
		if is_instance_valid(screen):
			screen.complete()
			screen.queue_free()
	)
	return screen

func _process(delta: float) -> void:
	if _shown < _ceil:
		_shown += (_ceil - _shown) * clampf(delta * EASE_SPEED, 0.0, 1.0)
		if _ceil - _shown < 0.002:
			_shown = _ceil
		_update_bar()

func get_progress() -> float:
	return _shown

func _update_bar() -> void:
	if _bar_fill != null:
		_bar_fill.size = Vector2(BAR_SIZE.x * _shown, BAR_SIZE.y)
	if _status_label != null:
		_status_label.text = "%d%%" % int(round(_shown * 100.0))
