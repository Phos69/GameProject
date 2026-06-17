extends PanelContainer
class_name ExplorationMapPanel

var graph: WorldGraph
var exploration_state: WorldExplorationState
var active_region_ids: Dictionary = {}
var high_contrast: bool = false
var title_label: Label
var legend_label: Label
var map_bounds: Rect2 = Rect2(0.0, 0.0, 520.0, 360.0)

const UNKNOWN_COLOR := Color(0.055, 0.065, 0.075, 0.96)
const DISCOVERED_COLOR := Color(0.25, 0.31, 0.33, 0.98)
const VISITED_COLOR := Color(0.31, 0.54, 0.58, 0.98)
const CLEARED_COLOR := Color(0.36, 0.68, 0.45, 0.98)
const CURRENT_COLOR := Color(1.0, 0.86, 0.34, 1.0)
const LOADED_COLOR := Color(0.62, 0.78, 1.0, 0.95)
const LINK_COLOR := Color(0.58, 0.70, 0.70, 0.72)
const BRIDGE_LINK_COLOR := Color(0.62, 0.82, 0.86, 0.82)
const SNOW_LINK_COLOR := Color(0.82, 0.90, 0.97, 0.84)
const GATE_LINK_COLOR := Color(0.70, 0.74, 0.56, 0.80)
const BURNED_LINK_COLOR := Color(0.82, 0.56, 0.44, 0.80)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 0.5
	anchor_top = 0.5
	anchor_right = 0.5
	anchor_bottom = 0.5
	offset_left = -330.0
	offset_top = -235.0
	offset_right = 330.0
	offset_bottom = 235.0
	visible = false
	add_to_group("visual_settings_consumers")
	_build_ui()
	_apply_style()
	VisualSettingsManager.sync_consumer(self)

func configure(
	next_graph: WorldGraph,
	next_exploration_state: WorldExplorationState,
	next_active_region_ids: Array = []
) -> void:
	graph = next_graph
	exploration_state = next_exploration_state
	active_region_ids.clear()
	for region_id in next_active_region_ids:
		active_region_ids[StringName(region_id)] = true
	_refresh_labels()
	queue_redraw()

func apply_visual_settings(settings: Dictionary) -> void:
	high_contrast = bool(settings.get("high_contrast", false))
	queue_redraw()

func is_region_active(region_id: StringName) -> bool:
	return active_region_ids.has(region_id)

func get_active_region_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for region_id in active_region_ids.keys():
		result.append(StringName(region_id))
	result.sort()
	return result

# Known passages = graph edges whose endpoints are both visible (not unknown).
# The map never reveals connections out of the fog, so this mirrors what a
# player can legitimately read from explored territory.
func get_known_connections() -> Array[WorldRegionConnection]:
	var result: Array[WorldRegionConnection] = []
	if graph == null:
		return result
	for connection in graph.connections:
		if _connection_visible(connection):
			result.append(connection)
	return result

func toggle() -> void:
	visible = not visible
	_refresh_labels()
	queue_redraw()

func show_map() -> void:
	visible = true
	_refresh_labels()
	queue_redraw()

func hide_map() -> void:
	visible = false

func _draw() -> void:
	if graph == null:
		return
	var regions := graph.get_regions_sorted()
	if regions.is_empty():
		return
	var grid_rect := _get_grid_rect(regions)
	var cell_size := _resolve_cell_size(grid_rect)
	var origin := Vector2(70.0, 82.0)
	var link_width := 4.0 if high_contrast else 3.0
	for connection in graph.connections:
		if not _connection_visible(connection):
			continue
		var from_region := graph.get_region(connection.from_region_id)
		var to_region := graph.get_region(connection.to_region_id)
		if from_region == null or to_region == null:
			continue
		draw_line(
			_grid_to_panel(from_region.grid_position, grid_rect, cell_size, origin),
			_grid_to_panel(to_region.grid_position, grid_rect, cell_size, origin),
			_link_color_for(connection),
			link_width,
			true
		)
	for region in regions:
		_draw_region(region, grid_rect, cell_size, origin)

func _draw_region(
	region: WorldRegion,
	grid_rect: Rect2i,
	cell_size: float,
	origin: Vector2
) -> void:
	var center := _grid_to_panel(region.grid_position, grid_rect, cell_size, origin)
	var size := Vector2(cell_size * 0.74, cell_size * 0.52)
	var points := PackedVector2Array([
		center + Vector2(0.0, -size.y),
		center + Vector2(size.x, 0.0),
		center + Vector2(0.0, size.y),
		center + Vector2(-size.x, 0.0)
	])
	var state := _state_for_region(region.region_id)
	draw_colored_polygon(points, _color_for_state(state))
	var closed := points.duplicate()
	closed.append(points[0])
	var outline_width := 3.0 if high_contrast else 2.0
	draw_polyline(
		closed,
		Color.WHITE if state != WorldExplorationState.STATE_UNKNOWN else Color(0.22, 0.25, 0.27, 1.0),
		outline_width,
		true
	)
	var is_current := (
		exploration_state != null
		and exploration_state.current_region_id == region.region_id
	)
	# Loaded-as-data marker (active region that is not the current one): an
	# axis-aligned square, geometrically distinct from the diamond so it reads
	# without relying on color (high-contrast friendly).
	if is_region_active(region.region_id) and not is_current:
		var sx := size.x * 1.04
		var sy := size.y * 1.18
		var square := PackedVector2Array([
			center + Vector2(-sx, -sy),
			center + Vector2(sx, -sy),
			center + Vector2(sx, sy),
			center + Vector2(-sx, sy),
			center + Vector2(-sx, -sy)
		])
		draw_polyline(square, LOADED_COLOR, outline_width, true)
	if is_current:
		draw_polyline(closed, CURRENT_COLOR, 5.0 if high_contrast else 4.0, true)
		draw_circle(center, maxf(cell_size * 0.11, 4.0), CURRENT_COLOR)

func _build_ui() -> void:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	add_child(content)
	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.modulate = Color(0.92, 0.98, 1.0, 1.0)
	content.add_child(title_label)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(1.0, 352.0)
	content.add_child(spacer)
	legend_label = Label.new()
	legend_label.add_theme_font_size_override("font_size", 13)
	legend_label.modulate = Color(0.74, 0.84, 0.86, 1.0)
	content.add_child(legend_label)

func _apply_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.024, 0.028, 0.94)
	style.border_color = Color(0.46, 0.58, 0.56, 0.92)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 22.0
	style.content_margin_right = 22.0
	style.content_margin_top = 16.0
	style.content_margin_bottom = 16.0
	add_theme_stylebox_override("panel", style)

func _refresh_labels() -> void:
	if title_label == null or legend_label == null:
		return
	var current := (
		String(exploration_state.current_region_id)
		if exploration_state != null
		else ""
	)
	title_label.text = "Territory Map  %s" % current
	legend_label.text = "Unknown  Discovered  Visited  Cleared  Current  [Loaded]"

func _get_grid_rect(regions: Array[WorldRegion]) -> Rect2i:
	var first_region: WorldRegion = regions.front()
	var min_grid: Vector2i = first_region.grid_position
	var max_grid: Vector2i = first_region.grid_position
	for region in regions:
		min_grid.x = mini(min_grid.x, region.grid_position.x)
		min_grid.y = mini(min_grid.y, region.grid_position.y)
		max_grid.x = maxi(max_grid.x, region.grid_position.x)
		max_grid.y = maxi(max_grid.y, region.grid_position.y)
	return Rect2i(min_grid, max_grid - min_grid + Vector2i.ONE)

func _resolve_cell_size(grid_rect: Rect2i) -> float:
	var usable := Vector2(560.0, 310.0)
	var columns := maxf(float(grid_rect.size.x), 1.0)
	var rows := maxf(float(grid_rect.size.y), 1.0)
	return minf(usable.x / columns * 0.72, usable.y / rows * 0.72)

func _grid_to_panel(
	grid_position: Vector2i,
	grid_rect: Rect2i,
	cell_size: float,
	origin: Vector2
) -> Vector2:
	var local := grid_position - grid_rect.position
	return origin + Vector2(
		float(local.x) * cell_size * 1.42 + cell_size,
		float(local.y) * cell_size * 1.16 + cell_size
	)

func _connection_visible(connection: WorldRegionConnection) -> bool:
	if exploration_state == null:
		return false
	return (
		exploration_state.is_visible(connection.from_region_id)
		and exploration_state.is_visible(connection.to_region_id)
	)

func _state_for_region(region_id: StringName) -> StringName:
	if exploration_state == null:
		return WorldExplorationState.STATE_UNKNOWN
	return exploration_state.get_state(region_id)

func _color_for_state(state: StringName) -> Color:
	match state:
		WorldExplorationState.STATE_CLEARED:
			return CLEARED_COLOR
		WorldExplorationState.STATE_VISITED:
			return VISITED_COLOR
		WorldExplorationState.STATE_DISCOVERED:
			return DISCOVERED_COLOR
		_:
			return UNKNOWN_COLOR

func _link_color_for(connection: WorldRegionConnection) -> Color:
	match connection.passage_type:
		&"bridge":
			return BRIDGE_LINK_COLOR
		&"snow_pass":
			return SNOW_LINK_COLOR
		&"broken_gate":
			return GATE_LINK_COLOR
		&"burned_road":
			return BURNED_LINK_COLOR
		_:
			return LINK_COLOR
