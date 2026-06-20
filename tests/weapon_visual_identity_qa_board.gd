extends Node2D

const VIEWPORT_SIZE := Vector2(1280.0, 720.0)
const BACKGROUND_COLOR := Color(0.018, 0.024, 0.036, 1.0)
const PANEL_COLOR := Color(0.040, 0.056, 0.078, 1.0)
const PANEL_BORDER_COLOR := Color(0.20, 0.34, 0.48, 1.0)

var board_title: String = "Weapon Visual Identity QA"
var cells: Array[Dictionary] = []

func configure(title: String, cell_specs: Array[Dictionary]) -> void:
	board_title = title
	cells = cell_specs
	z_index = -100
	queue_redraw()

func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, VIEWPORT_SIZE), BACKGROUND_COLOR, true)
	draw_string(
		font,
		Vector2(42.0, 48.0),
		board_title,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		26,
		Color(0.90, 0.95, 1.0, 1.0)
	)
	for cell in cells:
		var rect := cell.get("rect", Rect2()) as Rect2
		var label := str(cell.get("label", "sample"))
		draw_rect(rect, PANEL_COLOR, true)
		draw_rect(rect, PANEL_BORDER_COLOR, false, 2.0)
		draw_string(
			font,
			rect.position + Vector2(12.0, 24.0),
			label,
			HORIZONTAL_ALIGNMENT_LEFT,
			rect.size.x - 24.0,
			16,
			Color(0.72, 0.82, 0.92, 1.0)
		)
