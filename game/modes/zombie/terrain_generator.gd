extends Node
class_name TerrainGenerator

signal terrain_configured(biome_id: StringName)
signal terrain_patch_spawned(patch: Node2D, terrain_tag: StringName)

const TERRAIN_PATCH_SCRIPT = preload(
	"res://game/modes/zombie/biome_terrain_patch.gd"
)
const REGION_GROUND_SCRIPT = preload(
	"res://game/modes/zombie/biome_region_ground.gd"
)
const BIOME_TILE_LAYER_SCRIPT = preload(
	"res://game/modes/zombie/biome_tile_layer.gd"
)

@export var playground_path: NodePath = NodePath("../../../../World/Playground")
@export var environment_container_path: NodePath = NodePath(
	"../../../../World/EnvironmentProps"
)
@export_enum("performance", "balanced", "quality") var region_ground_quality_preset: String = "balanced"
@export_range(0, 32, 1) var region_ground_sample_step_override: int = 0
@export var use_asset_tile_layer: bool = true

var active_biome: BiomeDefinition
var is_active: bool = false
var generated_patches: Array[Node2D] = []
var active_ground: BiomeRegionGround
var active_tile_layer: BiomeTileLayer

func _ready() -> void:
	add_to_group("terrain_generator")

func start_run(biome: BiomeDefinition) -> void:
	_clear_runtime()
	active_biome = biome
	is_active = true
	_apply_biome_palette()
	_set_legacy_playground_visible(true)
	_generate_region_ground()
	_generate_terrain_patches()
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

func get_generated_patches() -> Array[Node2D]:
	_prune_runtime()
	return generated_patches.duplicate()

func get_active_ground() -> BiomeRegionGround:
	return active_ground

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

func _generate_terrain_patches() -> void:
	if active_biome == null:
		return
	if active_tile_layer != null:
		return
	var layout := active_biome.environment_layout
	var palette := active_biome.palette
	var container := _get_environment_container()
	if layout == null or palette == null or container == null:
		return
	var manifest := IsometricEnvironmentManifest.get_shared()
	for index in range(layout.terrain_patch_positions.size()):
		if index >= layout.terrain_patch_tags.size():
			break
		var patch := TERRAIN_PATCH_SCRIPT.new() as BiomeTerrainPatch
		if patch == null:
			continue
		var terrain_tag := layout.terrain_patch_tags[index]
		var radius := (
			layout.terrain_patch_radii[index]
			if index < layout.terrain_patch_radii.size()
			else 34.0
		)
		patch.name = "TerrainPatch%d" % (index + 1)
		patch.configure(
			terrain_tag,
			radius,
			palette.floor_color,
			palette.major_grid_color,
			index + 1,
			manifest.get_terrain_style(terrain_tag)
		)
		container.add_child(patch)
		patch.global_position = layout.terrain_patch_positions[index]
		generated_patches.append(patch)
		terrain_patch_spawned.emit(patch, terrain_tag)

func _generate_region_ground() -> void:
	if active_biome == null:
		return
	var layout := active_biome.environment_layout
	var palette := active_biome.palette
	var container := _get_environment_container()
	if layout == null or palette == null or container == null:
		return
	if use_asset_tile_layer:
		active_tile_layer = BIOME_TILE_LAYER_SCRIPT.new() as BiomeTileLayer
		if active_tile_layer == null:
			return
		active_tile_layer.name = "BiomeTileLayer"
		active_tile_layer.configure(
			layout,
			palette,
			active_biome.biome_id,
			StringName(region_ground_quality_preset)
		)
		container.add_child(active_tile_layer)
		return
	active_ground = REGION_GROUND_SCRIPT.new() as BiomeRegionGround
	if active_ground == null:
		return
	active_ground.name = "BiomeRegionGround"
	active_ground.configure(layout, palette, _resolve_region_ground_sample_step())
	container.add_child(active_ground)

func _get_environment_container() -> Node:
	var container := get_node_or_null(environment_container_path)
	return container if container != null else get_tree().current_scene

func _resolve_region_ground_sample_step() -> int:
	if region_ground_sample_step_override > 0:
		return region_ground_sample_step_override
	return IsometricEnvironmentManifest.get_shared().get_terrain_sample_step(
		StringName(region_ground_quality_preset)
	)

func _clear_runtime() -> void:
	for patch in generated_patches:
		if is_instance_valid(patch):
			patch.queue_free()
	generated_patches.clear()
	if active_ground != null and is_instance_valid(active_ground):
		active_ground.queue_free()
	active_ground = null
	if active_tile_layer != null and is_instance_valid(active_tile_layer):
		active_tile_layer.queue_free()
	active_tile_layer = null

func _prune_runtime() -> void:
	for patch in generated_patches.duplicate():
		if (
			not is_instance_valid(patch)
			or patch.is_queued_for_deletion()
		):
			generated_patches.erase(patch)
