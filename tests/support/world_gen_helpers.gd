extends RefCounted
## Helper statici condivisi dalle suite GUT dell'area World Generation (A1).
##
## Centralizzano la costruzione (costosa) dei layout cardinali e l'accesso ai
## BiomeManager, così le suite possono costruire il mondo una sola volta in
## before_all e riusarlo tra i test.

const STARTER_BIOME_PATH := "res://game/modes/zombie/biomes/infected_plains.tres"
const WorldGridConfig = preload("res://game/core/world_grid_config.gd")

## Carica una BiomeDefinition di zombie mode dal suo id (nome file .tres).
static func load_biome(biome_id: String) -> BiomeDefinition:
	return load("res://game/modes/zombie/biomes/%s.tres" % biome_id) as BiomeDefinition

static func load_starter_biome() -> BiomeDefinition:
	return load(STARTER_BIOME_PATH) as BiomeDefinition

## Costruisce un layout void-first completo per il biome dato e il seed
## indicato, attraverso ObstacleLayoutGenerator.populate_layout_voidfirst().
## È l'operazione costosa: chiamarla il meno possibile (riuso in before_all).
static func voidfirst_layout(biome: BiomeDefinition, seed_value: int) -> BiomeEnvironmentLayout:
	var cell := BiomeCell.new()
	cell.configure(
		&"world_gen_voidfirst_cell",
		biome.biome_id,
		Vector2i.ZERO,
		BiomeEnvironmentLayout.DEFAULT_ZONE_SIZE,
		seed_value
	)
	var layout := BiomeEnvironmentLayout.new()
	layout.zone_size = BiomeEnvironmentLayout.DEFAULT_ZONE_SIZE
	layout.generation_seed = seed_value
	layout.perimeter_visual_style = (
		BiomeEnvironmentLayout.PERIMETER_VISUAL_RAISED_CLIFF
	)
	layout.wall_height_cells = (
		BiomeEnvironmentLayout.RAISED_CLIFF_HEIGHT_CELLS
	)
	ObstacleLayoutGenerator.new().populate_layout_voidfirst(layout, cell, biome)
	return layout

## Crea un BiomeManager agganciato a `host`, già avviato con `context`.
## NB: chiamare dopo aver atteso un frame dall'attach del nodo host se serve.
static func start_biome_manager(host: Node, context: Dictionary, manager_name: String = "WorldGenBiomeManager") -> BiomeManager:
	var manager := BiomeManager.new()
	manager.name = manager_name
	host.add_child(manager)
	manager.start_run(context)
	return manager

static func free_biome_manager(manager: BiomeManager) -> void:
	if manager == null or not is_instance_valid(manager):
		return
	manager.stop_run()
	var parent := manager.get_parent()
	if parent != null:
		parent.remove_child(manager)
	manager.free()

## Primo BiomeCell incontrato per ciascun biome_id (campionamento per biome).
static func first_cell_per_biome(cells: Array[BiomeCell]) -> Array[BiomeCell]:
	var seen: Dictionary = {}
	var result: Array[BiomeCell] = []
	for cell in cells:
		if seen.has(cell.biome_id):
			continue
		seen[cell.biome_id] = true
		result.append(cell)
	return result

## Cella di sondaggio walkable appena dentro un passaggio (mirror dei test legacy).
static func passage_probe_cell(passage: BiomePassage, zone_size: Vector2i) -> Vector2i:
	var edge_depth := WorldGridConfig.PASSAGE_EDGE_DEPTH_TILES
	match passage.side:
		&"north":
			return Vector2i(passage.position, edge_depth)
		&"south":
			return Vector2i(passage.position, zone_size.y - edge_depth - 1)
		&"west":
			return Vector2i(edge_depth, passage.position)
		_:
			return Vector2i(zone_size.x - edge_depth - 1, passage.position)
