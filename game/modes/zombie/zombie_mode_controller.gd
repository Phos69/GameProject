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

var biome_manager
var wave_director
var zombie_spawner
var terrain_generator
var resource_crate_system
var obstacle_system
var hazard_system
var transition_system
var random_encounter_system
var is_active: bool = false

func _ready() -> void:
	add_to_group("zombie_mode_controller")
	_resolve_components()
	_connect_biome_manager()

func start_run(context: Dictionary = {}) -> void:
	_resolve_components()
	if biome_manager != null:
		biome_manager.start_run(context)
	var biome = get_current_biome()
	is_active = true
	if wave_director != null and wave_director.has_method("start_run"):
		wave_director.start_run()
	if random_encounter_system != null and random_encounter_system.has_method("configure_seed"):
		random_encounter_system.configure_seed(int(context.get("run_seed", 0)))
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
	if random_encounter_system != null and random_encounter_system.has_method("cleanup_encounter"):
		random_encounter_system.cleanup_encounter()
	if wave_director != null and wave_director.has_method("stop_run"):
		wave_director.stop_run()
	is_active = false
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

func _apply_active_biome(biome: BiomeDefinition) -> void:
	if biome == null:
		return
	if terrain_generator != null:
		terrain_generator.start_run(biome)
	if obstacle_system != null:
		obstacle_system.start_run(biome)
	if hazard_system != null:
		hazard_system.start_run(biome)
	if resource_crate_system != null:
		resource_crate_system.start_run(biome)
	if transition_system != null:
		if transition_system.is_active:
			transition_system.configure_biome(biome)
		else:
			transition_system.start_run(biome, biome_manager)
	active_biome_applied.emit(biome.biome_id)

func _resolve_node(path: NodePath, group_name: StringName) -> Node:
	if not path.is_empty():
		var node := get_node_or_null(path)
		if node != null:
			return node
	return get_tree().get_first_node_in_group(group_name)
