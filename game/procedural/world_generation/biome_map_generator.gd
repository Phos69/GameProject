extends Node
class_name BiomeMapGenerator

signal biome_map_generated(cells: Array[BiomeCell])

@export_range(1, 12, 1) var map_width: int = 5
@export_range(1, 12, 1) var map_height: int = 1
@export var cell_size: Vector2i = Vector2i(200, 200)
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

func _ready() -> void:
	add_to_group("biome_map_generator")

func generate_map(
	seed_value: int,
	available_biome_ids: Array[StringName],
	context: Dictionary = {}
) -> Array[BiomeCell]:
	var width := maxi(int(context.get("biome_map_width", map_width)), 1)
	var height := maxi(int(context.get("biome_map_height", map_height)), 1)
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
			var biome_id := ordered_biomes[index % ordered_biomes.size()]
			if index == 0 and available_biome_ids.has(starting_biome_id):
				biome_id = starting_biome_id
			var cell := BiomeCell.new()
			cell.configure(
				StringName("biome_%d_%d" % [x, y]),
				biome_id,
				Vector2i(x, y),
				cell_size,
				_derive_cell_seed(seed_value, x, y, biome_id)
			)
			cells.append(cell)
			index += 1

	border_generator.configure_borders(cells)
	passage_generator.generate_passages(cells, seed_value)
	last_cells = cells
	biome_map_generated.emit(cells)
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
	while ordered.size() < required_count:
		ordered.append(ordered[(ordered.size() - 1) % maxi(ordered.size(), 1)])
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

func _context_has_explicit_seed(context: Dictionary) -> bool:
	return (
		context.has(&"world_seed")
		or context.has(&"global_seed")
		or context.has(&"seed")
		or context.has("world_seed")
		or context.has("global_seed")
		or context.has("seed")
	)
