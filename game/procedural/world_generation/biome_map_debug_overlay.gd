extends CanvasLayer
class_name BiomeMapDebugOverlay

signal regenerate_same_seed_requested()
signal regenerate_new_seed_requested()

@export var visible_on_start: bool = false
@export var input_enabled: bool = false

var seed_value: int = 0
var cells: Array[BiomeCell] = []
var label: Label
var show_borders: bool = true
var show_pathfinding: bool = false
var show_collision: bool = false

func _ready() -> void:
	add_to_group("biome_map_debug_overlay")
	visible = visible_on_start
	label = Label.new()
	label.name = "DebugLabel"
	label.position = Vector2(20.0, 20.0)
	label.add_theme_font_size_override("font_size", 14)
	add_child(label)
	_refresh_label()

func configure(
	new_seed: int,
	new_cells: Array[BiomeCell]
) -> void:
	seed_value = new_seed
	cells = new_cells.duplicate()
	_refresh_label()

func copy_seed_to_clipboard() -> void:
	DisplayServer.clipboard_set(str(seed_value))

func get_debug_summary() -> Dictionary:
	var passage_count := 0
	var fall_side_count := 0
	var validation_failures := 0
	for cell in cells:
		passage_count += cell.passages.size()
		for side in BiomeCell.SIDES:
			if cell.get_border(side) == BiomeCell.BorderType.FALL:
				fall_side_count += 1
		if not bool(cell.validation_report.get("is_valid", false)):
			validation_failures += 1
	return {
		"seed": seed_value,
		"cell_count": cells.size(),
		"passage_count": passage_count,
		"fall_side_count": fall_side_count,
		"validation_failures": validation_failures,
		"show_borders": show_borders,
		"show_pathfinding": show_pathfinding,
		"show_collision": show_collision
	}

func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_F1:
			visible = not visible
			get_viewport().set_input_as_handled()
		KEY_F2:
			if visible:
				show_collision = not show_collision
				_refresh_label()
				get_viewport().set_input_as_handled()
		KEY_F3:
			if visible:
				show_pathfinding = not show_pathfinding
				_refresh_label()
				get_viewport().set_input_as_handled()
		KEY_F4:
			if visible:
				show_borders = not show_borders
				_refresh_label()
				get_viewport().set_input_as_handled()
		KEY_F5:
			if visible:
				regenerate_same_seed_requested.emit()
				get_viewport().set_input_as_handled()
		KEY_F6:
			if visible:
				regenerate_new_seed_requested.emit()
				get_viewport().set_input_as_handled()
		_:
			pass

func _refresh_label() -> void:
	if label == null:
		return
	var lines := PackedStringArray()
	lines.append("Seed: %d" % seed_value)
	lines.append("Cells: %d" % cells.size())
	lines.append("Borders:%s  Path:%s  Collision:%s" % [
		str(show_borders),
		str(show_pathfinding),
		str(show_collision)
	])
	for cell in cells:
		lines.append("%s %s %s" % [
			String(cell.id),
			String(cell.biome_id),
			str(cell.grid)
		])
	label.text = "\n".join(lines)
