extends Node
class_name BiomeWorldGenerator

signal world_generated(seed_value: int, cells: Array[BiomeCell])

var seed_service: WorldGenerationSeed
var map_generator: BiomeMapGenerator
var terrain_generator: BiomeTerrainGenerator
var debug_overlay: BiomeMapDebugOverlay
var active_seed: int = 0
var active_cells: Array[BiomeCell] = []
var active_graph: WorldGraph
var active_context: Dictionary = {}

func _ready() -> void:
	add_to_group("biome_world_generator")
	_ensure_components()

func generate_world(
	context: Dictionary,
	biome_definitions: Dictionary
) -> Dictionary:
	_ensure_components()
	clear_world()
	active_context = context.duplicate(true)
	active_seed = seed_service.start_run(context)
	var biome_ids := _get_biome_ids(biome_definitions)
	active_cells = map_generator.generate_map(active_seed, biome_ids, context)
	active_graph = map_generator.get_world_graph()
	terrain_generator.generate_layouts_for_cells(
		active_cells,
		biome_definitions,
		context
	)
	if active_graph != null:
		active_graph.configure_from_biome_cells(active_cells, active_seed)
	if debug_overlay != null:
		debug_overlay.configure(active_seed, active_cells)
	world_generated.emit(active_seed, active_cells)
	return get_world_data()

func regenerate_same_seed(biome_definitions: Dictionary) -> Dictionary:
	var context := active_context.duplicate(true)
	context["world_seed"] = active_seed
	context["preserve_biome_sequence"] = bool(
		active_context.get("preserve_biome_sequence", true)
	)
	return generate_world(context, biome_definitions)

func regenerate_new_seed(biome_definitions: Dictionary) -> Dictionary:
	var context := active_context.duplicate(true)
	var next_seed := maxi(active_seed + 7919, 1)
	context["world_seed"] = next_seed
	context["preserve_biome_sequence"] = false
	return generate_world(context, biome_definitions)

func get_world_data() -> Dictionary:
	return {
		"seed": active_seed,
		"cells": active_cells,
		"world_graph": active_graph,
		"start_cell": map_generator.get_starting_cell(active_cells),
		"signature": map_generator.get_map_signature(active_cells),
		"seed_record": seed_service.get_seed_record()
	}

func get_cell_by_biome_id(biome_id: StringName) -> BiomeCell:
	for cell in active_cells:
		if cell.biome_id == biome_id:
			return cell
	return null

func get_neighbor_for_biome(
	source_cell: BiomeCell,
	target_biome_id: StringName
) -> BiomeCell:
	if source_cell == null:
		return get_cell_by_biome_id(target_biome_id)
	for side in BiomeCell.SIDES:
		var neighbor := source_cell.get_neighbor(side)
		if neighbor != null and neighbor.biome_id == target_biome_id:
			return neighbor
	return get_cell_by_biome_id(target_biome_id)

func get_map_signature() -> String:
	_ensure_components()
	return map_generator.get_map_signature(active_cells)

func get_seed_record() -> Dictionary:
	_ensure_components()
	return seed_service.get_seed_record()

func clear_world() -> void:
	if debug_overlay != null:
		debug_overlay.configure(0, [])
	if map_generator != null:
		map_generator.clear_generated_data()
	else:
		for cell in active_cells:
			if cell != null:
				cell.clear_runtime_links()
	active_cells.clear()
	active_graph = null
	active_context.clear()
	active_seed = 0

func _ensure_components() -> void:
	if seed_service == null:
		seed_service = WorldGenerationSeed.new()
		seed_service.name = "WorldGenerationSeed"
		add_child(seed_service)
	if map_generator == null:
		map_generator = BiomeMapGenerator.new()
		map_generator.name = "BiomeMapGenerator"
		add_child(map_generator)
	if terrain_generator == null:
		terrain_generator = BiomeTerrainGenerator.new()
		terrain_generator.name = "BiomeTerrainGenerator"
		add_child(terrain_generator)
	if debug_overlay == null:
		debug_overlay = BiomeMapDebugOverlay.new()
		debug_overlay.name = "BiomeMapDebugOverlay"
		add_child(debug_overlay)

func _get_biome_ids(biome_definitions: Dictionary) -> Array[StringName]:
	var ids: Array[StringName] = []
	for key in biome_definitions.keys():
		ids.append(StringName(key))
	ids.sort()
	return ids
