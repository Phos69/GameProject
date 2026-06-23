extends Node
class_name ZombieModeController

signal zombie_run_started(biome_id: StringName)
signal zombie_run_stopped()
signal active_biome_applied(biome_id: StringName)
# Emitted once the world (generation + active-region terrain bake) is fully ready.
# For the synchronous path this fires within start_run(); for the async path it
# fires after the worker-thread build finishes.
signal world_ready(biome_id: StringName)

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
const WORLD_LOADING_SCREEN_SCRIPT = preload(
	"res://game/ui/world_loading_screen.gd"
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
var is_active: bool = false
var last_applied_region_id: StringName = &""
# Screen-space backdrop painted with the active biome's void colour so anything
# beyond the chunk borders reads as void instead of the default clear colour.
var _void_backdrop_layer: CanvasLayer
var _void_backdrop: ColorRect

const VOID_BACKDROP_DARKEN := 0.68
const SINGLE_BIOME_ARENA_KEY := "single_biome_arena"
const DISABLE_WORLD_RUNTIME_KEY := "disable_world_runtime"
const DISABLE_REGION_STREAMING_KEY := "disable_region_streaming"
const ASYNC_WORLD_BUILD_KEY := "async_world_build"

var world_runtime_enabled_for_run: bool = true
var region_streaming_enabled_for_run: bool = true
var _loading_screen: CanvasLayer
# Fast retry: when a run is stopped with keep_world=true the built world (terrain,
# tiles, obstacles, hazards, streamed regions, biome data) is parked instead of torn
# down. A following start_run() with the same context signature reuses it and only
# the gameplay layer (waves/enemies/players) resets, so retry is instant.
var _world_parked: bool = false
var _built_context_signature: String = ""

static func get_void_background_color(palette: BiomePalette) -> Color:
	if palette == null:
		return RenderingServer.get_default_clear_color()
	return palette.background_color.darkened(VOID_BACKDROP_DARKEN)

func _ready() -> void:
	add_to_group("zombie_mode_controller")
	_resolve_components()
	_connect_biome_manager()

func start_run(context: Dictionary = {}) -> void:
	_resolve_components()
	var resolved_context := _resolve_survival_world_context(context)
	var signature := _context_signature(resolved_context)
	if _world_parked and signature == _built_context_signature:
		# Same world already built and parked: reuse it, skip generation and bake.
		_reuse_parked_world(resolved_context)
		return
	if _world_parked:
		# Parked world no longer matches the request: discard it before rebuilding.
		_teardown_world()
		_world_parked = false
		last_applied_region_id = &""
	world_runtime_enabled_for_run = not _get_context_bool(
		resolved_context,
		DISABLE_WORLD_RUNTIME_KEY,
		false
	)
	region_streaming_enabled_for_run = (
		enable_multi_region_render
		and not _get_context_bool(
			resolved_context,
			DISABLE_REGION_STREAMING_KEY,
			false
		)
	)
	_built_context_signature = signature
	if _get_context_bool(resolved_context, ASYNC_WORLD_BUILD_KEY, false):
		await _start_run_async(resolved_context)
	else:
		_start_run_sync(resolved_context)

# True when stop_run(keep_world=true) parked a world that matches `context`, so a
# retry can reuse it without rebuilding.
func can_reuse_world(context: Dictionary = {}) -> bool:
	return (
		_world_parked
		and _context_signature(_resolve_survival_world_context(context))
		== _built_context_signature
	)

func _reuse_parked_world(resolved_context: Dictionary) -> void:
	_world_parked = false
	is_active = true
	if wave_director != null and wave_director.has_method("start_run"):
		wave_director.start_run()
	if random_encounter_system != null and random_encounter_system.has_method("configure_seed"):
		random_encounter_system.configure_seed(
			int(resolved_context.get("world_seed", resolved_context.get("run_seed", 0)))
		)
	_emit_run_started()

func _context_signature(context: Dictionary) -> String:
	var keys := context.keys()
	keys.sort_custom(func(a, b) -> bool: return str(a) < str(b))
	var parts := PackedStringArray()
	for key in keys:
		parts.append("%s=%s" % [str(key), str(context[key])])
	return "|".join(parts)

func _start_run_sync(resolved_context: Dictionary) -> void:
	if biome_manager != null:
		biome_manager.start_run(resolved_context)
	_finish_start_run(resolved_context)
	_emit_run_started()

func _start_run_async(resolved_context: Dictionary) -> void:
	_show_loading_screen("Preparazione mondo")
	_set_loading_phase("Preparazione mondo", 0.0, 0.1)
	# Pre-warm shared, lazily-loaded resources on the main thread so the worker
	# thread only ever reads them.
	IsometricEnvironmentManifest.get_shared()
	if biome_manager != null:
		biome_manager.begin_world_build()
		# Opaque worker-thread phase: the bar eases across the band while it runs.
		_set_loading_phase("Generazione mondo", 0.1, 0.6)
		var thread := Thread.new()
		thread.start(_threaded_generate_world.bind(resolved_context))
		# Yield each frame so the loading screen keeps animating while the worker
		# thread generates the (CPU-heavy) world data.
		while thread.is_alive():
			await get_tree().process_frame
		var world_data: Dictionary = thread.wait_to_finish()
		biome_manager.apply_world_data(world_data)
	_set_loading_phase("Costruzione terreno", 0.6, 0.92)
	if terrain_generator != null:
		terrain_generator.async_tile_build = true
	_finish_start_run(resolved_context)
	if terrain_generator != null:
		terrain_generator.async_tile_build = false
	await _await_active_tile_build()
	_complete_loading_screen()
	_hide_loading_screen()
	_emit_run_started()

func _threaded_generate_world(resolved_context: Dictionary) -> Dictionary:
	if biome_manager == null:
		return {}
	return biome_manager.generate_world_data(resolved_context)

func _await_active_tile_build() -> void:
	if terrain_generator == null:
		return
	var tile_layer = terrain_generator.get_active_tile_layer()
	# Poll (rather than awaiting the signal) to avoid a missed-signal race if the
	# bake finishes between the check and the await.
	while (
		tile_layer != null
		and is_instance_valid(tile_layer)
		and tile_layer.has_method("is_building")
		and bool(tile_layer.call("is_building"))
	):
		await get_tree().process_frame

func _finish_start_run(resolved_context: Dictionary) -> void:
	if world_runtime_enabled_for_run and world_runtime != null and biome_manager != null:
		world_runtime.start_run(biome_manager.active_world_data, biome_manager)
	if world_runtime_enabled_for_run and region_seam_system != null and biome_manager != null:
		region_seam_system.start_run(biome_manager, world_runtime)
	var biome = get_current_biome()
	is_active = true
	if wave_director != null and wave_director.has_method("start_run"):
		wave_director.start_run()
	if random_encounter_system != null and random_encounter_system.has_method("configure_seed"):
		random_encounter_system.configure_seed(
			int(resolved_context.get("world_seed", resolved_context.get("run_seed", 0)))
		)
	_apply_active_biome(biome)

func _emit_run_started() -> void:
	var biome_id := get_current_biome_id()
	zombie_run_started.emit(biome_id)
	world_ready.emit(biome_id)

func _show_loading_screen(message: String) -> void:
	if _loading_screen != null and is_instance_valid(_loading_screen):
		_loading_screen.call("set_message", message)
		return
	_loading_screen = WORLD_LOADING_SCREEN_SCRIPT.new() as CanvasLayer
	_loading_screen.name = "WorldLoadingScreen"
	var scene := get_tree().current_scene
	if scene != null:
		scene.add_child(_loading_screen)
	else:
		add_child(_loading_screen)
	_loading_screen.call("set_message", message)

func _set_loading_phase(
	message: String,
	floor_value: float,
	ceil_value: float
) -> void:
	if _loading_screen != null and is_instance_valid(_loading_screen):
		_loading_screen.call("set_phase", message, floor_value, ceil_value)

func _complete_loading_screen() -> void:
	if _loading_screen != null and is_instance_valid(_loading_screen):
		_loading_screen.call("complete")

func _hide_loading_screen() -> void:
	if _loading_screen != null and is_instance_valid(_loading_screen):
		_loading_screen.queue_free()
	_loading_screen = null

# Standard survival uses BiomeMapGenerator's default 3x3 multi-biome world. The
# compact 1x1 arena is kept as an explicit quick/test profile and never overrides
# caller-provided map dimensions.
func _resolve_survival_world_context(context: Dictionary) -> Dictionary:
	var resolved := context.duplicate(true)
	if not _get_context_bool(resolved, SINGLE_BIOME_ARENA_KEY, false):
		return resolved
	if not _has_context_key(resolved, "biome_map_width"):
		resolved["biome_map_width"] = 1
	if not _has_context_key(resolved, "biome_map_height"):
		resolved["biome_map_height"] = 1
	return resolved

func _has_context_key(context: Dictionary, key: String) -> bool:
	return context.has(key) or context.has(StringName(key))

func _get_context_bool(
	context: Dictionary,
	key: String,
	default_value: bool
) -> bool:
	if context.has(key):
		return bool(context.get(key))
	var string_name_key := StringName(key)
	if context.has(string_name_key):
		return bool(context.get(string_name_key))
	return default_value

# keep_world=true parks the built world for a same-seed retry: only the gameplay
# layer is stopped here (waves/encounters), while terrain, tiles, obstacles,
# hazards, streamed regions and biome data stay alive for reuse. The gameplay
# entities (enemies, players) are reset by the mode's own stop/start and by
# ProgressionManager on game_mode_started, not by the world teardown.
func stop_run(keep_world: bool = false) -> void:
	_hide_loading_screen()
	if terrain_generator != null:
		terrain_generator.async_tile_build = false
	if random_encounter_system != null and random_encounter_system.has_method("cleanup_encounter"):
		random_encounter_system.cleanup_encounter()
	if wave_director != null and wave_director.has_method("stop_run"):
		wave_director.stop_run()
	is_active = false
	if keep_world:
		_world_parked = true
		zombie_run_stopped.emit()
		return
	_teardown_world()
	_world_parked = false
	world_runtime_enabled_for_run = true
	region_streaming_enabled_for_run = true
	last_applied_region_id = &""
	_built_context_signature = ""
	zombie_run_stopped.emit()

func _teardown_world() -> void:
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
	if world_runtime != null:
		world_runtime.stop_run()
	if biome_manager != null and biome_manager.has_method("stop_run"):
		biome_manager.stop_run()
	_clear_void_backdrop()

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
	if (
		zombie_spawner != null
		and zombie_spawner.has_method("configure_runtime_dependencies")
	):
		zombie_spawner.configure_runtime_dependencies(
			obstacle_system,
			hazard_system,
			biome_manager,
			region_seam_system,
			world_region_streamer
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
	if world_runtime_enabled_for_run and world_runtime != null:
		world_runtime.set_current_region(region_id)
	if is_active:
		_apply_active_biome(get_current_biome())

func _ensure_void_backdrop() -> void:
	if _void_backdrop != null and is_instance_valid(_void_backdrop):
		return
	_void_backdrop_layer = CanvasLayer.new()
	_void_backdrop_layer.name = "VoidBackdropLayer"
	# Behind the world (canvas layer 0) but still rendered, so everything outside
	# the streamed chunk shows the void colour.
	_void_backdrop_layer.layer = -100
	add_child(_void_backdrop_layer)
	_void_backdrop = ColorRect.new()
	_void_backdrop.name = "VoidBackdrop"
	_void_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_void_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_void_backdrop_layer.add_child(_void_backdrop)

func _update_void_backdrop(biome: BiomeDefinition) -> void:
	if biome == null or biome.palette == null:
		return
	_ensure_void_backdrop()
	# The same shared colour contract is used by BiomeTileLayer for pure void.
	_void_backdrop.color = get_void_background_color(biome.palette)
	_void_backdrop_layer.visible = true

func _clear_void_backdrop() -> void:
	if _void_backdrop_layer != null and is_instance_valid(_void_backdrop_layer):
		_void_backdrop_layer.queue_free()
	_void_backdrop_layer = null
	_void_backdrop = null

func _apply_active_biome(biome: BiomeDefinition) -> void:
	if biome == null:
		return
	_update_void_backdrop(biome)
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
	active_biome_applied.emit(biome.biome_id)

func _stream_active_regions(region_id: StringName) -> bool:
	if (
		not region_streaming_enabled_for_run
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
