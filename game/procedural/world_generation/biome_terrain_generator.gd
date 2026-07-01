extends Node
class_name BiomeTerrainGenerator

const IsoGridConfig = preload("res://game/core/iso_grid_config.gd")

signal biome_layout_generated(cell: BiomeCell, layout: BiomeEnvironmentLayout)

var obstacle_layout_generator := ObstacleLayoutGenerator.new()
var fall_boundary_generator := FallBoundaryGenerator.new()
var validation_system := MapValidationSystem.new()

func _ready() -> void:
	add_to_group("biome_terrain_generator")

func generate_layouts_for_cells(
	cells: Array[BiomeCell],
	biome_definitions: Dictionary,
	context: Dictionary = {}
) -> void:
	for cell in cells:
		var definition := biome_definitions.get(cell.biome_id, null) as BiomeDefinition
		if definition == null:
			continue
		generate_layout_for_cell(cell, definition, context)

func generate_layout_for_cell(
	cell: BiomeCell,
	biome: BiomeDefinition,
	context: Dictionary = {}
) -> BiomeEnvironmentLayout:
	var layout := BiomeEnvironmentLayout.new()
	layout.zone_size = biome.get_biome_size()
	layout.generation_seed = cell.seed
	layout.logical_tile_scale = IsoGridConfig.LOGICAL_TILE_SCALE
	layout.central_corridor_width = IsoGridConfig.DEFAULT_CENTRAL_CORRIDOR_WORLD_WIDTH
	layout.player_spawn_cell = layout.zone_size / 2
	# Every physical biome-divider wall uses the same upward-cliff geometry as
	# Infinite Arena. Fall boundaries remain separate and keep their drop logic.
	layout.perimeter_visual_style = (
		BiomeEnvironmentLayout.PERIMETER_VISUAL_RAISED_CLIFF
	)
	layout.wall_height_cells = (
		BiomeEnvironmentLayout.RAISED_CLIFF_HEIGHT_CELLS
	)

	# All biomes share the void-first pipeline (rocks/masses -> vegetation clusters
	# -> hub+spokes roads -> tree borders -> void lottery), skinned per biome via the
	# void-first palette. The legacy populate_layout() is retained as reference only.
	obstacle_layout_generator.populate_layout_voidfirst(
		layout,
		cell,
		biome,
		context
	)
	fall_boundary_generator.apply_fall_boundaries(cell, layout)
	layout.rebuild_terrain_classification(cell)
	var report := validation_system.validate_layout(cell, layout)
	if not bool(report.get("is_valid", false)):
		obstacle_layout_generator.repair_layout(layout)
		layout.rebuild_terrain_classification(cell)
		report = validation_system.validate_layout(cell, layout)

	obstacle_layout_generator.refresh_generation_summary(layout, biome)
	layout.validation_report = report
	cell.generated_layout = layout
	cell.validation_report = report
	# Layout generation runs on the world-build worker thread; defer the emit there.
	if OS.get_thread_caller_id() == OS.get_main_thread_id():
		biome_layout_generated.emit(cell, layout)
	else:
		call_deferred("emit_signal", &"biome_layout_generated", cell, layout)
	return layout
