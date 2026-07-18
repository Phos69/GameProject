extends Control
class_name MainMenuBackdrop
## Fondale del main menu (VIS-012): gradiente notturno, griglia cardinale e
## celle rettangolari nei toni dei quattro biomi, cosi' la prima schermata parla
## il linguaggio visivo del mondo di gioco. Disegno statico: nessuna
## animazione, quindi coerente anche con il preset reduced motion.

const GRADIENT_TOP := Color(0.012, 0.020, 0.038, 1.0)
const GRADIENT_BOTTOM := Color(0.030, 0.052, 0.090, 1.0)
const GRID_CELL := Vector2(96.0, 96.0)
const GRID_LINE_COLOR := Color(0.30, 0.52, 0.70, 0.055)
const BIOME_TILE_COLORS: Array[Color] = [
	Color(0.30, 0.44, 0.20, 1.0),
	Color(0.50, 0.27, 0.15, 1.0),
	Color(0.60, 0.70, 0.78, 1.0),
	Color(0.20, 0.30, 0.27, 1.0)
]
# Posizioni relative al viewport: fasce laterali, lontane dalla colonna
# centrale del menu.
const BIOME_TILES: Array[Dictionary] = [
	{"anchor": Vector2(0.115, 0.185), "width": 150.0, "biome": 0},
	{"anchor": Vector2(0.185, 0.255), "width": 96.0, "biome": 0},
	{"anchor": Vector2(0.130, 0.800), "width": 168.0, "biome": 3},
	{"anchor": Vector2(0.215, 0.870), "width": 104.0, "biome": 1},
	{"anchor": Vector2(0.865, 0.190), "width": 150.0, "biome": 2},
	{"anchor": Vector2(0.800, 0.130), "width": 92.0, "biome": 2},
	{"anchor": Vector2(0.880, 0.780), "width": 168.0, "biome": 1},
	{"anchor": Vector2(0.800, 0.870), "width": 104.0, "biome": 1}
]

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	var view := size
	draw_polygon(
		PackedVector2Array([
			Vector2.ZERO,
			Vector2(view.x, 0.0),
			view,
			Vector2(0.0, view.y)
		]),
		PackedColorArray([
			GRADIENT_TOP,
			GRADIENT_TOP,
			GRADIENT_BOTTOM,
			GRADIENT_BOTTOM
		])
	)
	_draw_cardinal_grid(view)
	for tile in BIOME_TILES:
		_draw_biome_cell(
			Vector2(tile.get("anchor", Vector2.ZERO)) * view,
			float(tile.get("width", 120.0)),
			BIOME_TILE_COLORS[int(tile.get("biome", 0)) % BIOME_TILE_COLORS.size()]
		)

func _draw_cardinal_grid(view: Vector2) -> void:
	for segment in _get_cardinal_grid_segments(view):
		draw_line(segment[0], segment[1], GRID_LINE_COLOR, 1.0, true)

func _get_cardinal_grid_segments(view: Vector2) -> Array[PackedVector2Array]:
	var segments: Array[PackedVector2Array] = []
	var x := fmod(view.x * 0.5, GRID_CELL.x)
	while x <= view.x:
		segments.append(PackedVector2Array([Vector2(x, 0.0), Vector2(x, view.y)]))
		x += GRID_CELL.x
	var y := fmod(view.y * 0.5, GRID_CELL.y)
	while y <= view.y:
		segments.append(PackedVector2Array([Vector2(0.0, y), Vector2(view.x, y)]))
		y += GRID_CELL.y
	return segments

func _draw_biome_cell(center: Vector2, width: float, base_color: Color) -> void:
	var cell_size := Vector2(width, width * 0.62)
	var cell_rect := Rect2(center - cell_size * 0.5, cell_size)
	var shadow_rect := Rect2(cell_rect.position + Vector2(5.0, 7.0), cell_rect.size)
	draw_rect(shadow_rect, Color(0.0, 0.0, 0.0, 0.22), true)
	draw_rect(cell_rect, Color(base_color, 0.30), true)
	draw_rect(
		cell_rect,
		Color(base_color.lightened(0.18), 0.34),
		false,
		1.5,
		true
	)
	draw_line(
		Vector2(cell_rect.position.x + cell_size.x * 0.12, cell_rect.position.y + cell_size.y * 0.24),
		Vector2(cell_rect.end.x - cell_size.x * 0.12, cell_rect.position.y + cell_size.y * 0.24),
		Color(base_color.lightened(0.35), 0.30),
		2.0,
		true
	)
	draw_line(
		Vector2(cell_rect.position.x + cell_size.x * 0.30, cell_rect.position.y + cell_size.y * 0.12),
		Vector2(cell_rect.position.x + cell_size.x * 0.30, cell_rect.end.y - cell_size.y * 0.12),
		Color(base_color.lightened(0.25), 0.22),
		1.0,
		true
	)
