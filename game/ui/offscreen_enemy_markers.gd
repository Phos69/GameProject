extends Control
class_name OffscreenEnemyMarkers

## Marker direzionali ai bordi schermo per i minion fuori dalla visuale.
##
## Nodo presentazionale figlio dell'HUD: legge il gruppo `enemies` (i boss
## restano nel gruppo `bosses` e hanno la propria barra), converte ogni minion
## off-screen in una freccia ancorata al bordo del viewport e ne deriva colore
## tematico, dimensione e opacita dalla distanza dal party. Non possiede ne
## modifica stato gameplay: legge solo posizioni, profilo nemico e impostazioni
## visuali condivise. Il calcolo dei marker vive in `compute_markers()` cosi i
## test headless possono verificarlo senza dipendere dal rendering.

const ENEMY_GROUP: StringName = &"enemies"
const EDGE_MARGIN: float = 34.0
const ON_SCREEN_BUFFER: float = 12.0
const MIN_SIZE: float = 9.0
const MAX_SIZE: float = 16.0
const NEAR_DISTANCE: float = 240.0
const FAR_DISTANCE: float = 1500.0
const MAX_MARKERS: int = 18
const DEFAULT_COLOR: Color = Color(1.0, 0.40, 0.30, 1.0)

const THEME_COLORS: Dictionary = {
	&"toxic": Color(0.46, 0.85, 0.30, 1.0),
	&"fire": Color(1.0, 0.46, 0.18, 1.0),
	&"frost": Color(0.46, 0.80, 1.0, 1.0),
	&"marsh": Color(0.72, 0.58, 0.34, 1.0)
}

var high_contrast: bool = false
var reduced_motion: bool = false

func _ready() -> void:
	add_to_group("visual_settings_consumers")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	VisualSettingsManager.sync_consumer(self)

func apply_visual_settings(settings: Dictionary) -> void:
	high_contrast = bool(settings.get("high_contrast", false))
	reduced_motion = bool(settings.get("reduced_motion", false))
	queue_redraw()

func _process(_delta: float) -> void:
	if not visible:
		return
	queue_redraw()

## Calcola i marker off-screen per i minion del gruppo `enemies`.
## Ogni voce: `border` (punto sul bordo, screen-space), `facing` (direzione
## uscente normalizzata), `closeness` (0 lontano .. 1 vicino) e `color`.
func compute_markers() -> Array[Dictionary]:
	var markers: Array[Dictionary] = []
	var enemies := get_tree().get_nodes_in_group(ENEMY_GROUP)
	if enemies.is_empty():
		return markers
	var canvas_xform := get_viewport().get_canvas_transform()
	var view_rect := get_viewport_rect()
	var center := view_rect.size * 0.5
	var half := view_rect.size * 0.5 - Vector2(EDGE_MARGIN, EDGE_MARGIN)
	if half.x <= 0.0 or half.y <= 0.0:
		return markers
	var party_center := _party_center_world(canvas_xform, center)
	var visible_rect := view_rect.grow(-ON_SCREEN_BUFFER)

	for enemy in enemies:
		var node2d := enemy as Node2D
		if node2d == null or node2d.is_queued_for_deletion():
			continue
		var world_pos := node2d.global_position
		var screen_pos := canvas_xform * world_pos
		if visible_rect.has_point(screen_pos):
			continue
		if screen_pos.distance_squared_to(center) < 1.0:
			continue
		markers.append({
			"border": _project_to_border(center, screen_pos, half),
			"facing": (screen_pos - center).normalized(),
			"closeness": _closeness(party_center.distance_to(world_pos)),
			"color": _enemy_color(node2d)
		})

	markers.sort_custom(func(a, b): return a["closeness"] > b["closeness"])
	if markers.size() > MAX_MARKERS:
		markers.resize(MAX_MARKERS)
	return markers

func _draw() -> void:
	var markers := compute_markers()
	if markers.is_empty():
		return
	var pulse := 1.0
	if not reduced_motion:
		pulse = 0.82 + 0.18 * sin(Time.get_ticks_msec() * 0.006)
	for marker in markers:
		_draw_marker(marker, pulse)

func _draw_marker(marker: Dictionary, pulse: float) -> void:
	var border: Vector2 = marker["border"]
	var facing: Vector2 = marker["facing"]
	var closeness: float = marker["closeness"]
	var size := lerpf(MIN_SIZE, MAX_SIZE, closeness)
	var alpha := lerpf(0.40, 0.95, closeness)
	if not reduced_motion and closeness > 0.66:
		alpha = clampf(alpha * pulse, 0.0, 1.0)
	var base_color: Color = marker["color"]
	var side := facing.orthogonal()
	var tip := border + facing * size
	var back := border - facing * (size * 0.55)
	var p1 := tip
	var p2 := back + side * (size * 0.78)
	var p3 := back - side * (size * 0.78)
	draw_colored_polygon(PackedVector2Array([p1, p2, p3]), Color(base_color, alpha))
	var outline := (
		Color.WHITE
		if high_contrast
		else Color(base_color.darkened(0.45), minf(alpha + 0.12, 1.0))
	)
	draw_polyline(
		PackedVector2Array([p1, p2, p3, p1]),
		outline,
		2.5 if high_contrast else 1.5,
		true
	)

func _project_to_border(
	center: Vector2,
	target: Vector2,
	half: Vector2
) -> Vector2:
	var dir := target - center
	var scale := INF
	if absf(dir.x) > 0.0001:
		scale = minf(scale, half.x / absf(dir.x))
	if absf(dir.y) > 0.0001:
		scale = minf(scale, half.y / absf(dir.y))
	if scale == INF:
		return center
	return center + dir * scale

func _closeness(distance: float) -> float:
	return clampf(
		1.0 - (distance - NEAR_DISTANCE) / (FAR_DISTANCE - NEAR_DISTANCE),
		0.0,
		1.0
	)

func _enemy_color(enemy: Node) -> Color:
	var profile := enemy.get("enemy_profile") as BiomeEnemyProfile
	if profile != null and THEME_COLORS.has(profile.theme_id):
		return THEME_COLORS[profile.theme_id]
	return DEFAULT_COLOR

func _party_center_world(canvas_xform: Transform2D, screen_center: Vector2) -> Vector2:
	var alive := PlayerQuery.alive(get_tree())
	if alive.is_empty():
		return canvas_xform.affine_inverse() * screen_center
	var sum := Vector2.ZERO
	for player in alive:
		sum += (player as Node2D).global_position
	return sum / float(alive.size())
