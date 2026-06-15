extends Node
class_name TerrainGenerator

signal terrain_configured(biome_id: StringName)

var active_biome
var is_active: bool = false

func _ready() -> void:
	add_to_group("terrain_generator")

func start_run(biome) -> void:
	active_biome = biome
	is_active = true
	terrain_configured.emit(
		StringName(active_biome.get("biome_id")) if active_biome != null else &""
	)

func stop_run() -> void:
	is_active = false
	active_biome = null

func get_active_biome_id() -> StringName:
	return StringName(active_biome.get("biome_id")) if active_biome != null else &""
