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

@export var playground_path: NodePath = NodePath("../../../../World/Playground")
@export var environment_container_path: NodePath = NodePath(
	"../../../../World/EnvironmentProps"
)

var active_biome: BiomeDefinition
var is_active: bool = false
var generated_patches: Array[Node2D] = []
var active_ground: BiomeRegionGround

func _ready() -> void:
	add_to_group("terrain_generator")

func start_run(biome: BiomeDefinition) -> void:
	_clear_runtime()
	active_biome = biome
	is_active = true
	_apply_biome_palette()
	_generate_region_ground()
	_generate_terrain_patches()
	terrain_configured.emit(
		active_biome.biome_id if active_biome != null else &""
	)

func stop_run() -> void:
	_clear_runtime()
	is_active = false
	active_biome = null

func get_active_biome_id() -> StringName:
	return active_biome.biome_id if active_biome != null else &""

func get_generated_patches() -> Array[Node2D]:
	_prune_runtime()
	return generated_patches.duplicate()

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
	var layout := active_biome.environment_layout
	var palette := active_biome.palette
	var container := _get_environment_container()
	if layout == null or palette == null or container == null:
		return
	for index in range(layout.terrain_patch_positions.size()):
		if index >= layout.terrain_patch_tags.size():
			break
		var patch := TERRAIN_PATCH_SCRIPT.new() as BiomeTerrainPatch
		if patch == null:
			continue
		var radius := (
			layout.terrain_patch_radii[index]
			if index < layout.terrain_patch_radii.size()
			else 34.0
		)
		patch.name = "TerrainPatch%d" % (index + 1)
		patch.configure(
			layout.terrain_patch_tags[index],
			radius,
			palette.floor_color,
			palette.major_grid_color,
			index + 1
		)
		container.add_child(patch)
		patch.global_position = layout.terrain_patch_positions[index]
		generated_patches.append(patch)
		terrain_patch_spawned.emit(patch, layout.terrain_patch_tags[index])

func _generate_region_ground() -> void:
	if active_biome == null:
		return
	var layout := active_biome.environment_layout
	var palette := active_biome.palette
	var container := _get_environment_container()
	if layout == null or palette == null or container == null:
		return
	active_ground = REGION_GROUND_SCRIPT.new() as BiomeRegionGround
	if active_ground == null:
		return
	active_ground.name = "BiomeRegionGround"
	active_ground.configure(layout, palette)
	container.add_child(active_ground)

func _get_environment_container() -> Node:
	var container := get_node_or_null(environment_container_path)
	return container if container != null else get_tree().current_scene

func _clear_runtime() -> void:
	for patch in generated_patches:
		if is_instance_valid(patch):
			patch.queue_free()
	generated_patches.clear()
	if active_ground != null and is_instance_valid(active_ground):
		active_ground.queue_free()
	active_ground = null

func _prune_runtime() -> void:
	for patch in generated_patches.duplicate():
		if (
			not is_instance_valid(patch)
			or patch.is_queued_for_deletion()
		):
			generated_patches.erase(patch)
