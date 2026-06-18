extends Node
class_name ZombieModeController

signal zombie_run_started(biome_id: StringName)
signal zombie_run_stopped()
signal active_biome_applied(biome_id: StringName)

@export var biome_manager_path: NodePath = NodePath("BiomeManager")
@export var wave_director_path: NodePath = NodePath("WaveDirector")
@export var zombie_spawner_path: NodePath = NodePath("ZombieSpawner")
@export var terrain_generator_path: NodePath = NodePath("TerrainGenerator")
@export var resource_crate_system_path: NodePath = NodePath("ResourceCrateSystem")
@export var obstacle_system_path: NodePath = NodePath("ObstacleSystem")
@export var hazard_system_path: NodePath = NodePath("HazardSystem")
@export var transition_system_path: NodePath = NodePath("TransitionSystem")
@export var random_encounter_system_path: NodePath = NodePath("RandomEncounterSystem")
@export var world_runtime_path: NodePath = NodePath("WorldRuntime")
@export var enable_multi_region_render: bool = true

const REGION_SEAM_SYSTEM_SCRIPT = preload(
	"res://game/world/region_seam_system.gd"
)
const WORLD_REGION_STREAMER_SCRIPT = preload(
	"res://game/world/world_region_streamer.gd"
)

var biome_manager
var wave_director
var zombie_spawner
var terrain_generator
var resource_crate_system
var obstacle_system
var hazard_system
var transition_system
var random_encounter_system
var world_runtime: WorldRuntime
var region_seam_system
var world_region_streamer
var multi_region_renderer: MultiRegionRenderer
var is_active: bool = false
var last_applied_region_id: StringName = &""

func _ready() -> void:
	add_to_group("zombie_mode_controller")
	_resolve_components()
	_connect_biome_manager()

func start_run(context: Dictionary = {}) -> void:
	_resolve_components()
	if biome_manager != null:
		biome_manager.start_run(context)
	if world_runtime != null and biome_manager != null:
		world_runtime.start_run(biome_manager.active_world_data, biome_manager)
	if region_seam_system != null and biome_manager != null:
		region_seam_system.start_run(biome_manager, world_runtime)
	var biome = get_current_biome()
	is_active = true
	if wave_director != null and wave_director.has_method("start_run"):
		wave_director.start_run()
	if random_encounter_system != null and random_encounter_system.has_method("configure_seed"):
		random_encounter_system.configure_seed(
			int(context.get("world_seed", context.get("run_seed", 0)))
		)
	_apply_active_biome(biome)
	zombie_run_started.emit(
		StringName(biome.get("biome_id")) if biome != null else &""
	)

func stop_run() -> void:
	if terrain_generator != null:
		terrain_generator.stop_run()
	if obstacle_system != null:
		obstacle_system.stop_run()
	if resource_crate_system != null:
		resource_crate_system.stop_run()
	if hazard_system != null:
		hazard_system.stop_run()
	if transition_system != null:
		transition_system.stop_run()
	if region_seam_system != null:
		region_seam_system.stop_run()
	if world_region_streamer != null:
		world_region_streamer.clear()
	if multi_region_renderer != null:
		multi_region_renderer.clear()
	if random_encounter_system != null and random_encounter_system.has_method("cleanup_encounter"):
		random_encounter_system.cleanup_encounter()
	if world_runtime != null:
		world_runtime.stop_run()
	if wave_director != null and wave_director.has_method("stop_run"):
		wave_director.stop_run()
	if biome_manager != null and biome_manager.has_method("stop_run"):
		biome_manager.stop_run()
	is_active = false
	last_applied_region_id = &""
	zombie_run_stopped.emit()

func get_current_biome():
	_resolve_components()
	return biome_manager.get_current_biome() if biome_manager != null else null

func get_current_biome_id() -> StringName:
	var biome = get_current_biome()
	return StringName(biome.get("biome_id")) if biome != null else &""

func _resolve_components() -> void:
	biome_manager = _resolve_node(biome_manager_path, &"biome_manager")
	wave_director = _resolve_node(wave_director_path, &"wave_director")
	zombie_spawner = _resolve_node(zombie_spawner_path, &"zombie_spawner")
	terrain_generator = _resolve_node(
		terrain_generator_path,
		&"terrain_generator"
	)
	resource_crate_system = _resolve_node(
		resource_crate_system_path,
		&"resource_crate_system"
	)
	obstacle_system = _resolve_node(
		obstacle_system_path,
		&"obstacle_system"
	)
	hazard_system = _resolve_node(hazard_system_path, &"hazard_system")
	transition_system = _resolve_node(
		transition_system_path,
		&"biome_transition_system"
	)
	random_encounter_system = _resolve_node(
		random_encounter_system_path,
		&"random_encounter_system"
	)
	world_runtime = _resolve_node(
		world_runtime_path,
		&"world_runtime"
	) as WorldRuntime
	region_seam_system = get_tree().get_first_node_in_group(
		"region_seam_system"
	)
	if region_seam_system == null:
		region_seam_system = REGION_SEAM_SYSTEM_SCRIPT.new()
		region_seam_system.name = "RegionSeamSystem"
		add_child(region_seam_system)
	if world_region_streamer == null:
		world_region_streamer = get_tree().get_first_node_in_group(
			"world_region_streamer"
		)
	if world_region_streamer == null:
		world_region_streamer = WORLD_REGION_STREAMER_SCRIPT.new()
		world_region_streamer.name = "WorldRegionStreamer"
		add_child(world_region_streamer)
	if multi_region_renderer == null:
		multi_region_renderer = get_tree().get_first_node_in_group(
			"multi_region_renderer"
		) as MultiRegionRenderer
	_connect_biome_manager()
	_connect_wave_manager()

func _connect_wave_manager() -> void:
	var wave_manager := get_tree().get_first_node_in_group("wave_manager") as WaveManager
	if wave_manager == null:
		return
	var callback := Callable(self, "_on_wave_started")
	if not wave_manager.wave_started.is_connected(callback):
		wave_manager.wave_started.connect(callback)

func _connect_biome_manager() -> void:
	if biome_manager == null:
		return
	var callback := Callable(self, "_on_current_biome_changed")
	if not biome_manager.current_biome_changed.is_connected(callback):
		biome_manager.current_biome_changed.connect(callback)
	var region_callback := Callable(self, "_on_current_region_changed")
	if not biome_manager.current_region_changed.is_connected(region_callback):
		biome_manager.current_region_changed.connect(region_callback)

func _on_wave_started(wave_index: int) -> void:
	if not is_active or random_encounter_system == null:
		return
	var wave_manager := get_tree().get_first_node_in_group("wave_manager") as WaveManager
	var critical := wave_manager != null and wave_manager.current_wave_is_boss
	if random_encounter_system.has_method("try_start_encounter"):
		random_encounter_system.try_start_encounter(get_current_biome(), wave_index, critical)

func _on_current_biome_changed(
	_biome_id: StringName,
	_display_name: String
) -> void:
	if is_active:
		_apply_active_biome(get_current_biome())

func _on_current_region_changed(
	region_id: StringName,
	_biome_id: StringName
) -> void:
	if world_runtime != null:
		world_runtime.set_current_region(region_id)
	if is_active:
		_apply_active_biome(get_current_biome())

func _apply_active_biome(biome: BiomeDefinition) -> void:
	if biome == null:
		return
	var region_id: StringName = (
		biome_manager.get_current_region_id()
		if biome_manager != null
		else &""
	)
	if not region_id.is_empty() and region_id == last_applied_region_id:
		return
	last_applied_region_id = region_id
	if transition_system != null:
		if transition_system.is_active:
			transition_system.configure_biome(biome)
		else:
			transition_system.start_run(biome, biome_manager)
	if _stream_active_regions(region_id):
		active_biome_applied.emit(biome.biome_id)
		return
	if terrain_generator != null:
		terrain_generator.start_run(biome)
	if obstacle_system != null:
		obstacle_system.start_run(biome)
	if hazard_system != null:
		hazard_system.start_run(biome)
	if resource_crate_system != null:
		resource_crate_system.start_run(biome)
	_render_neighbor_regions(region_id)
	active_biome_applied.emit(biome.biome_id)

func _stream_active_regions(region_id: StringName) -> bool:
	if (
		not enable_multi_region_render
		or world_region_streamer == null
		or biome_manager == null
		or region_id.is_empty()
	):
		return false
	var graph = biome_manager.get_world_graph()
	if graph == null:
		return false
	var environment_container := _get_environment_container()
	var pickup_container := _get_pickup_container()
	if environment_container == null:
		return false
	return world_region_streamer.stream_world(
		graph,
		region_id,
		biome_manager,
		world_runtime,
		environment_container,
		pickup_container,
		terrain_generator,
		obstacle_system,
		hazard_system,
		resource_crate_system
	)

func _render_neighbor_regions(region_id: StringName) -> void:
	if (
		not enable_multi_region_render
		or biome_manager == null
		or region_id.is_empty()
	):
		return
	if multi_region_renderer == null:
		multi_region_renderer = get_tree().get_first_node_in_group(
			"multi_region_renderer"
		) as MultiRegionRenderer
	if multi_region_renderer == null:
		multi_region_renderer = MultiRegionRenderer.new()
		multi_region_renderer.name = "LegacyMultiRegionRenderer"
		add_child(multi_region_renderer)
	var graph = biome_manager.get_world_graph()
	if graph == null:
		return
	var container := _get_environment_container()
	if container == null:
		return
	multi_region_renderer.render_world(
		graph,
		region_id,
		container,
		_layout_for_region,
		_palette_for_biome,
		_neighbor_ground_sample_step()
	)

func _layout_for_region(region_id: StringName) -> BiomeEnvironmentLayout:
	if biome_manager == null:
		return null
	var cell := biome_manager.get_cell_by_region_id(region_id) as BiomeCell
	return cell.generated_layout if cell != null else null

func _palette_for_biome(biome_id: StringName) -> BiomePalette:
	if biome_manager == null:
		return null
	var definition = biome_manager.get_biome_definition(biome_id)
	return definition.palette if definition != null else null

func _neighbor_ground_sample_step() -> int:
	# Neighbors are background context: sample coarser than the current region.
	return IsometricEnvironmentManifest.get_shared().get_terrain_sample_step(
		&"performance"
	)

func _get_environment_container() -> Node:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	return scene.get_node_or_null("World/EnvironmentProps")

func _get_pickup_container() -> Node:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	return scene.get_node_or_null("World/Pickups")

func _resolve_node(path: NodePath, group_name: StringName) -> Node:
	if not path.is_empty():
		var node := get_node_or_null(path)
		if node != null:
			return node
	return get_tree().get_first_node_in_group(group_name)
