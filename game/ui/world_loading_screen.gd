extends CanvasLayer
class_name WorldLoadingScreen

# Full-screen overlay shown while the world is generated/baked on a worker thread.
# It animates every frame (the build runs off the main thread), so the window reads
# as "loading" instead of a frozen application.

const BACKDROP_COLOR := Color(0.03, 0.05, 0.08, 1.0)

var _title_label: Label
var _status_label: Label
var _bar_fill: ColorRect
var _message: String = "Caricamento..."
var _elapsed: float = 0.0

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
	column.add_theme_constant_override("separation", 18)
	center.add_child(column)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 28)
	column.add_child(_title_label)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.modulate = Color(0.7, 0.8, 0.95, 1.0)
	column.add_child(_status_label)

	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0.12, 0.15, 0.20, 1.0)
	bar_bg.custom_minimum_size = Vector2(360.0, 8.0)
	column.add_child(bar_bg)
	_bar_fill = ColorRect.new()
	_bar_fill.color = Color(0.45, 0.78, 0.95, 1.0)
	_bar_fill.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	bar_bg.add_child(_bar_fill)

	set_message(_message)

func set_message(text: String) -> void:
	_message = text
	if _title_label != null:
		_title_label.text = _message

func _process(delta: float) -> void:
	_elapsed += delta
	if _status_label != null:
		var dots := ".".repeat(1 + (int(_elapsed * 2.0) % 3))
		_status_label.text = "Generazione in corso%s" % dots
	if _bar_fill != null and _bar_fill.get_parent() is Control:
		# Indeterminate sweep: a fill that slides back and forth across the track.
		var track_width := (_bar_fill.get_parent() as Control).custom_minimum_size.x
		var span := track_width * 0.32
		var t := 0.5 - 0.5 * cos(_elapsed * 2.4)
		_bar_fill.position.x = t * (track_width - span)
		_bar_fill.custom_minimum_size = Vector2(span, 8.0)
		_bar_fill.size = Vector2(span, 8.0)
