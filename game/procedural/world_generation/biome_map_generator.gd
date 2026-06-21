extends Node
class_name BiomeMapGenerator

signal biome_map_generated(cells: Array[BiomeCell])

@export_range(1, 12, 1) var map_width: int = 3
@export_range(1, 12, 1) var map_height: int = 3
@export var cell_size: Vector2i = BiomeEnvironmentLayout.DEFAULT_ZONE_SIZE
@export_range(0.0, 1.0, 0.05) var extra_edge_chance: float = 0.38
@export var starting_biome_id: StringName = &"infected_plains"
@export var default_biome_order: Array[StringName] = [
	&"infected_plains",
	&"toxic_wastes",
	&"burning_fields",
	&"frozen_outskirts",
	&"drowned_marsh"
]

var border_generator := BorderGenerator.new()
var passage_generator := BiomePassageGenerator.new()
var last_cells: Array[BiomeCell] = []
var last_graph: WorldGraph

const ARENA_BOUNDARY_WALLED := "walled"
const ARENA_BOUNDARY_BLOCKED := "blocked"

func _ready() -> void:
	add_to_group("biome_map_generator")

func generate_map(
	seed_value: int,
	available_biome_ids: Array[StringName],
	context: Dictionary = {}
) -> Array[BiomeCell]:
	var width := maxi(int(context.get("biome_map_width", map_width)), 1)
	var height := maxi(int(context.get("biome_map_height", map_height)), 1)
	var resolved_cell_size := _resolve_cell_size(context)
	var preserve_sequence := bool(context.get(
		"preserve_biome_sequence",
		not _context_has_explicit_seed(context)
	))
	var ordered_biomes := _resolve_biome_order(
		available_biome_ids,
		seed_value,
		width * height,
		preserve_sequence
	)
	var cells: Array[BiomeCell] = []
	var index := 0
	for y in range(height):
		for x in range(width):
			var biome_id := _resolve_biome_for_grid(
				Vector2i(x, y),
				width,
				height,
				ordered_biomes
			)
			var cell := BiomeCell.new()
			cell.configure(
				StringName("biome_%d_%d" % [x, y]),
				biome_id,
				Vector2i(x, y),
				resolved_cell_size,
				_derive_cell_seed(seed_value, x, y, biome_id)
			)
			cells.append(cell)
			index += 1

	_configure_connected_topology(cells, seed_value, width, height, context)
	_apply_outer_boundary_mode(cells, context)
	passage_generator.generate_passages(cells, seed_value)
	last_graph = WorldGraph.new()
	last_graph.configure_from_biome_cells(cells, seed_value)
	last_cells = cells
	# Safe to emit from the world-build worker thread: defer when off the main thread.
	if OS.get_thread_caller_id() == OS.get_main_thread_id():
		biome_map_generated.emit(cells)
	else:
		call_deferred("emit_signal", &"biome_map_generated", cells)
	return cells

func get_starting_cell(cells: Array[BiomeCell] = []) -> BiomeCell:
	var source := cells if not cells.is_empty() else last_cells
	for cell in source:
		if cell.biome_id == starting_biome_id:
			return cell
	return source.front() if not source.is_empty() else null

func get_map_signature(cells: Array[BiomeCell] = []) -> String:
	var source := cells if not cells.is_empty() else last_cells
	var parts := PackedStringArray()
	for cell in source:
		parts.append(cell.get_signature())
	parts.sort()
	return "\n".join(parts)

func get_world_graph() -> WorldGraph:
	return last_graph

func clear_generated_data() -> void:
	for cell in last_cells:
		if cell != null:
			cell.clear_runtime_links()
	last_cells.clear()
	last_graph = null

func _resolve_biome_order(
	available_biome_ids: Array[StringName],
	seed_value: int,
	required_count: int,
	preserve_sequence: bool
) -> Array[StringName]:
	var ordered := _default_order_from_available(available_biome_ids)
	if ordered.is_empty():
		ordered.append(starting_biome_id)
	if not preserve_sequence:
		ordered = _shuffled_advanced_order(ordered, seed_value)
	var base_order := ordered.duplicate()
	while ordered.size() < required_count:
		ordered.append(base_order[ordered.size() % maxi(base_order.size(), 1)])
	return ordered

func _default_order_from_available(
	available_biome_ids: Array[StringName]
) -> Array[StringName]:
	var ordered: Array[StringName] = []
	for biome_id in default_biome_order:
		if available_biome_ids.has(biome_id):
			ordered.append(biome_id)
	var extra := available_biome_ids.duplicate()
	extra.sort()
	for biome_id in extra:
		if not ordered.has(biome_id):
			ordered.append(biome_id)
	return ordered

func _shuffled_advanced_order(
	ordered: Array[StringName],
	seed_value: int
) -> Array[StringName]:
	var result: Array[StringName] = []
	if ordered.has(starting_biome_id):
		result.append(starting_biome_id)
	else:
		result.append(ordered.front())
	var advanced: Array[StringName] = []
	for biome_id in ordered:
		if biome_id != result.front():
			advanced.append(biome_id)
	var rng := RandomNumberGenerator.new()
	rng.seed = maxi(absi(hash("%d:biome-order" % seed_value)), 1)
	while not advanced.is_empty():
		var index := rng.randi_range(0, advanced.size() - 1)
		result.append(advanced[index])
		advanced.remove_at(index)
	return result

func _derive_cell_seed(
	seed_value: int,
	grid_x: int,
	grid_y: int,
	biome_id: StringName
) -> int:
	var raw := hash("%d:%d:%d:%s" % [
		seed_value,
		grid_x,
		grid_y,
		String(biome_id)
	])
	return maxi(absi(raw), 1)

func _resolve_biome_for_grid(
	grid_position: Vector2i,
	width: int,
	height: int,
	ordered_biomes: Array[StringName]
) -> StringName:
	var cluster_order := _unique_biome_order(ordered_biomes)
	if cluster_order.is_empty():
		return starting_biome_id
	if grid_position == Vector2i.ZERO and cluster_order.has(starting_biome_id):
		return starting_biome_id
	var max_distance := maxi(width + height - 2, 1)
	var distance := grid_position.x + grid_position.y
	var ratio := float(distance) / float(max_distance)
	var index := clampi(
		floori(ratio * float(cluster_order.size())),
		0,
		cluster_order.size() - 1
	)
	return cluster_order[index]

func _unique_biome_order(source: Array[StringName]) -> Array[StringName]:
	var result: Array[StringName] = []
	for biome_id in source:
		if not result.has(biome_id):
			result.append(biome_id)
	return result

func _configure_connected_topology(
	cells: Array[BiomeCell],
	seed_value: int,
	width: int,
	height: int,
	context: Dictionary
) -> void:
	var cells_by_grid := {}
	for cell in cells:
		cells_by_grid[cell.grid] = cell
	var candidate_edges := _build_candidate_edges(cells_by_grid, width, height)
	var rng := RandomNumberGenerator.new()
	rng.seed = maxi(absi(hash("%d:world-graph-topology" % seed_value)), 1)
	var selected_edges := _build_spanning_tree_edges(cells, candidate_edges, rng)
	var extra_chance := clampf(
		float(context.get("extra_edge_chance", extra_edge_chance)),
		0.0,
		1.0
	)
	for edge in candidate_edges:
		var key := _edge_key(edge)
		if selected_edges.has(key):
			continue
		if rng.randf() <= extra_chance:
			selected_edges[key] = edge
	for edge in candidate_edges:
		if selected_edges.has(_edge_key(edge)):
			_connect_edge(edge)
		else:
			_block_edge(edge)

func _build_candidate_edges(
	cells_by_grid: Dictionary,
	width: int,
	height: int
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for y in range(height):
		for x in range(width):
			var cell := cells_by_grid.get(Vector2i(x, y), null) as BiomeCell
			if cell == null:
				continue
			var east := cells_by_grid.get(Vector2i(x + 1, y), null) as BiomeCell
			if east != null:
				result.append({"from": cell, "to": east, "side": &"east"})
			var south := cells_by_grid.get(Vector2i(x, y + 1), null) as BiomeCell
			if south != null:
				result.append({"from": cell, "to": south, "side": &"south"})
	return result

func _build_spanning_tree_edges(
	cells: Array[BiomeCell],
	candidate_edges: Array[Dictionary],
	rng: RandomNumberGenerator
) -> Dictionary:
	var selected := {}
	if cells.is_empty():
		return selected
	var visited := {}
	var start := get_starting_cell(cells)
	if start == null:
		start = cells.front()
	visited[start.id] = true
	var frontier := _frontier_edges(candidate_edges, visited)
	while visited.size() < cells.size() and not frontier.is_empty():
		var index := rng.randi_range(0, frontier.size() - 1)
		var edge := frontier[index]
		frontier.remove_at(index)
		var from_cell := edge["from"] as BiomeCell
		var to_cell := edge["to"] as BiomeCell
		var from_visited := visited.has(from_cell.id)
		var to_visited := visited.has(to_cell.id)
		if from_visited and to_visited:
			continue
		selected[_edge_key(edge)] = edge
		visited[(to_cell.id if from_visited else from_cell.id)] = true
		frontier = _frontier_edges(candidate_edges, visited)
	return selected

func _frontier_edges(
	candidate_edges: Array[Dictionary],
	visited: Dictionary
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for edge in candidate_edges:
		var from_cell := edge["from"] as BiomeCell
		var to_cell := edge["to"] as BiomeCell
		if visited.has(from_cell.id) != visited.has(to_cell.id):
			result.append(edge)
	return result

func _connect_edge(edge: Dictionary) -> void:
	var from_cell := edge["from"] as BiomeCell
	var to_cell := edge["to"] as BiomeCell
	var side := StringName(edge["side"])
	from_cell.set_neighbor(side, to_cell)
	to_cell.set_neighbor(BorderGenerator.get_opposite_side(side), from_cell)

func _block_edge(edge: Dictionary) -> void:
	var from_cell := edge["from"] as BiomeCell
	var to_cell := edge["to"] as BiomeCell
	var side := StringName(edge["side"])
	from_cell.set_border(side, BiomeCell.BorderType.BLOCKED)
	to_cell.set_border(
		BorderGenerator.get_opposite_side(side),
		BiomeCell.BorderType.BLOCKED
	)

func _apply_outer_boundary_mode(
	cells: Array[BiomeCell],
	context: Dictionary
) -> void:
	var boundary_mode := _get_context_string(context, "arena_boundary_mode", "")
	if (
		boundary_mode != ARENA_BOUNDARY_WALLED
		and boundary_mode != ARENA_BOUNDARY_BLOCKED
	):
		return
	for cell in cells:
		for side in BiomeCell.SIDES:
			if not cell.has_neighbor(side):
				cell.set_border(side, BiomeCell.BorderType.BLOCKED)

func _edge_key(edge: Dictionary) -> String:
	var from_cell := edge["from"] as BiomeCell
	var to_cell := edge["to"] as BiomeCell
	var ids := [String(from_cell.id), String(to_cell.id)]
	ids.sort()
	return "%s:%s" % [ids[0], ids[1]]

func _context_has_explicit_seed(context: Dictionary) -> bool:
	return (
		context.has(&"world_seed")
		or context.has(&"global_seed")
		or context.has(&"seed")
		or context.has("world_seed")
		or context.has("global_seed")
		or context.has("seed")
	)

func _get_context_string(
	context: Dictionary,
	key: String,
	default_value: String
) -> String:
	if context.has(key):
		return str(context.get(key))
	var string_name_key := StringName(key)
	if context.has(string_name_key):
		return str(context.get(string_name_key))
	return default_value

func _resolve_cell_size(context: Dictionary) -> Vector2i:
	var raw_size: Variant = context.get("biome_cell_size", cell_size)
	if raw_size is Vector2i:
		return _valid_cell_size(raw_size as Vector2i)
	if raw_size is Vector2:
		var vector := raw_size as Vector2
		return _valid_cell_size(Vector2i(roundi(vector.x), roundi(vector.y)))
	if raw_size is Array:
		var values := raw_size as Array
		if values.size() >= 2:
			return _valid_cell_size(Vector2i(int(values[0]), int(values[1])))
	if context.has("biome_cell_width") or context.has("biome_cell_height"):
		return _valid_cell_size(Vector2i(
			int(context.get("biome_cell_width", cell_size.x)),
			int(context.get("biome_cell_height", cell_size.y))
		))
	return _valid_cell_size(cell_size)

func _valid_cell_size(value: Vector2i) -> Vector2i:
	if value.x <= 0 or value.y <= 0:
		return BiomeEnvironmentLayout.DEFAULT_ZONE_SIZE
	return value
