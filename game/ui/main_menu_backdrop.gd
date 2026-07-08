extends Control
class_name MainMenuBackdrop
## Fondale del main menu (VIS-012): gradiente notturno, griglia isometrica e
## tessere diamante nei toni dei cinque biomi, cosi' la prima schermata parla
## il linguaggio visivo del mondo di gioco. Disegno statico: nessuna
## animazione, quindi coerente anche con il preset reduced motion.

const GRADIENT_TOP := Color(0.012, 0.020, 0.038, 1.0)
const GRADIENT_BOTTOM := Color(0.030, 0.052, 0.090, 1.0)
const GRID_CELL := Vector2(124.0, 62.0)
const GRID_LINE_COLOR := Color(0.30, 0.52, 0.70, 0.055)
const BIOME_TILE_COLORS: Array[Color] = [
	Color(0.30, 0.44, 0.20, 1.0),
	Color(0.40, 0.44, 0.38, 1.0),
	Color(0.60, 0.70, 0.78, 1.0),
	Color(0.20, 0.30, 0.27, 1.0),
	Color(0.50, 0.27, 0.15, 1.0)
]
# Posizioni relative al viewport: fasce laterali, lontane dalla colonna
# centrale del menu.
const BIOME_TILES: Array[Dictionary] = [
	{"anchor": Vector2(0.115, 0.185), "width": 150.0, "biome": 0},
	{"anchor": Vector2(0.185, 0.255), "width": 96.0, "biome": 0},
	{"anchor": Vector2(0.130, 0.800), "width": 168.0, "biome": 3},
	{"anchor": Vector2(0.215, 0.870), "width": 104.0, "biome": 4},
	{"anchor": Vector2(0.865, 0.190), "width": 150.0, "biome": 2},
	{"anchor": Vector2(0.800, 0.130), "width": 92.0, "biome": 2},
	{"anchor": Vector2(0.880, 0.780), "width": 168.0, "biome": 1},
	{"anchor": Vector2(0.800, 0.870), "width": 104.0, "biome": 4}
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
	_draw_iso_grid(view)
	for tile in BIOME_TILES:
		_draw_biome_tile(
			Vector2(tile.get("anchor", Vector2.ZERO)) * view,
			float(tile.get("width", 120.0)),
			BIOME_TILE_COLORS[int(tile.get("biome", 0)) % BIOME_TILE_COLORS.size()]
		)

func _draw_iso_grid(view: Vector2) -> void:
	var slope := GRID_CELL.y / GRID_CELL.x
	var rise := view.x * slope
	var offset := -rise
	while offset < view.y + rise:
		draw_line(
			Vector2(0.0, offset),
			Vector2(view.x, offset + rise),
			GRID_LINE_COLOR,
			1.0,
			true
		)
		draw_line(
			Vector2(0.0, offset + rise),
			Vector2(view.x, offset),
			GRID_LINE_COLOR,
			1.0,
			true
		)
		offset += GRID_CELL.y

func _draw_biome_tile(center: Vector2, width: float, base_color: Color) -> void:
	var half_width := width * 0.5
	var half_height := width * 0.25
	var top := center + Vector2(0.0, -half_height)
	var right := center + Vector2(half_width, 0.0)
	var bottom := center + Vector2(0.0, half_height)
	var left := center + Vector2(-half_width, 0.0)
	draw_colored_polygon(
		PackedVector2Array([
			top + Vector2(0.0, 5.0),
			right + Vector2(5.0, 5.0),
			bottom + Vector2(0.0, 10.0),
			left + Vector2(-5.0, 5.0)
		]),
		Color(0.0, 0.0, 0.0, 0.22)
	)
	draw_colored_polygon(
		PackedVector2Array([top, right, bottom, left]),
		Color(base_color, 0.30)
	)
	draw_polyline(
		PackedVector2Array([top, right, bottom, left, top]),
		Color(base_color.lightened(0.18), 0.34),
		1.5,
		true
	)
	draw_line(
		left.lerp(top, 0.12),
		top.lerp(right, 0.55),
		Color(base_color.lightened(0.35), 0.30),
		2.0,
		true
	)
