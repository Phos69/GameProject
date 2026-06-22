extends Node
class_name TerrainGenerator

signal terrain_configured(biome_id: StringName)

const BIOME_TILE_LAYER_SCRIPT = preload(
	"res://game/modes/zombie/biome_tile_layer.gd"
)

@export var playground_path: NodePath = NodePath("../../../../World/Playground")
@export var environment_container_path: NodePath = NodePath(
	"../../../../World/EnvironmentProps"
)
@export_enum("performance", "balanced", "quality") var region_ground_quality_preset: String = "balanced"

# When true the active-region tile layer bakes its geometry on a worker thread so
# the main thread (and the loading screen) stay responsive. Set by the async build
# coordinator only for the current region; streaming/tests keep the synchronous bake.
var async_tile_build: bool = false

var active_biome: BiomeDefinition
var is_active: bool = false
var active_tile_layer: BiomeTileLayer

func _ready() -> void:
	add_to_group("terrain_generator")

func start_run(biome: BiomeDefinition) -> void:
	_clear_runtime()
	active_biome = biome
	is_active = true
	_apply_biome_palette()
	_set_legacy_playground_visible(true)
	_build_tile_layer()
	terrain_configured.emit(
		active_biome.biome_id if active_biome != null else &""
	)

func begin_streaming_run(biome: BiomeDefinition) -> void:
	_clear_runtime()
	active_biome = biome
	is_active = true
	_apply_biome_palette()
	# The streamed tile layer paints the whole chunk, so the legacy playground
	# arena (a default tile grid, barricades and lane markers drawn at the world
	# origin) is obsolete and would show through at the map centre. Hide it.
	_set_legacy_playground_visible(false)
	terrain_configured.emit(
		active_biome.biome_id if active_biome != null else &""
	)

func stop_run() -> void:
	_clear_runtime()
	_set_legacy_playground_visible(true)
	is_active = false
	active_biome = null

func _set_legacy_playground_visible(value: bool) -> void:
	var playground := get_node_or_null(playground_path) as IsometricPlayground
	if playground != null:
		playground.visible = value

func get_active_biome_id() -> StringName:
	return active_biome.biome_id if active_biome != null else &""

func get_active_tile_layer() -> BiomeTileLayer:
	return active_tile_layer

func register_streamed_tile_layer(
	tile_layer: BiomeTileLayer,
	is_current_region: bool
) -> void:
	if tile_layer == null:
		return
	if is_current_region:
		active_tile_layer = tile_layer

func _apply_biome_palette() -> void:
	if active_biome == null:
		return
	var playground := get_node_or_null(playground_path) as IsometricPlayground
	var palette := active_biome.palette
	if playground != null and palette != null:
		playground.configure_biome_palette(palette)

func _build_tile_layer() -> void:
	if active_biome == null:
		return
	var layout := active_biome.environment_layout
	var palette := active_biome.palette
	var container := _get_environment_container()
	if layout == null or palette == null or container == null:
		return
	active_tile_layer = BIOME_TILE_LAYER_SCRIPT.new() as BiomeTileLayer
	if active_tile_layer == null:
		return
	active_tile_layer.name = "BiomeTileLayer"
	container.add_child(active_tile_layer)
	active_tile_layer.configure(
		layout,
		palette,
		active_biome.biome_id,
		StringName(region_ground_quality_preset),
		0,
		null,
		null,
		async_tile_build
	)

func _get_environment_container() -> Node:
	var container := get_node_or_null(environment_container_path)
	return container if container != null else get_tree().current_scene

func _clear_runtime() -> void:
	if active_tile_layer != null and is_instance_valid(active_tile_layer):
		active_tile_layer.queue_free()
	active_tile_layer = null
