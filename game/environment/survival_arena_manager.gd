extends Node
class_name SurvivalArenaManager

signal arena_selected(arena_id: StringName, display_name: String)
signal environment_prop_spawned(prop: Node)

const INDUSTRIAL_CROSSROADS: SurvivalArenaProfile = preload(
	"res://game/environment/industrial_crossroads.tres"
)
const RIFT_FOUNDRY: SurvivalArenaProfile = preload(
	"res://game/environment/rift_foundry.tres"
)
const EXPLOSIVE_BARREL_SCENE: PackedScene = preload(
	"res://game/environment/explosive_barrel.tscn"
)

@export var default_arena_id: StringName = &"industrial_crossroads"
@export var playground_path: NodePath = NodePath("../../World/Playground")
@export var environment_container_path: NodePath = NodePath(
	"../../World/EnvironmentProps"
)

var arena_profiles: Dictionary = {}
var active_profile: SurvivalArenaProfile
var spawn_gates: Array[SpawnGateVisual] = []
var interactive_props: Array[Node] = []
var is_active: bool = false

func _ready() -> void:
	add_to_group("survival_arena_manager")
	register_profile(INDUSTRIAL_CROSSROADS)
	register_profile(RIFT_FOUNDRY)
	select_arena(default_arena_id)
	call_deferred("_connect_wave_manager")

func register_profile(profile: SurvivalArenaProfile) -> void:
	if profile == null or profile.arena_id.is_empty():
		return
	arena_profiles[profile.arena_id] = profile

func activate_arena(arena_id: StringName = &"") -> bool:
	var requested_id := arena_id if not arena_id.is_empty() else default_arena_id
	if not select_arena(requested_id):
		if not select_arena(default_arena_id):
			return false
	_clear_runtime()
	_spawn_gates()
	_spawn_interactive_props()
	_move_players_to_spawns()
	is_active = true
	return true

func deactivate_arena() -> void:
	is_active = false
	_clear_runtime()

func select_arena(arena_id: StringName) -> bool:
	var profile := arena_profiles.get(arena_id) as SurvivalArenaProfile
	if profile == null:
		return false
	active_profile = profile
	_apply_profile_to_systems(profile)
	arena_selected.emit(profile.arena_id, profile.display_name)
	return true

func get_available_arena_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for arena_id in arena_profiles.keys():
		ids.append(StringName(arena_id))
	ids.sort()
	return ids

func get_active_arena_id() -> StringName:
	return active_profile.arena_id if active_profile != null else &""

func get_active_display_name() -> String:
	return active_profile.display_name if active_profile != null else "Survival Arena"

func get_boss_spawn_position(fallback: Vector2) -> Vector2:
	return (
		active_profile.boss_spawn_position
		if active_profile != null
		else fallback
	)

func get_spawn_gates() -> Array[SpawnGateVisual]:
	_prune_runtime()
	return spawn_gates.duplicate()

func get_interactive_props() -> Array[Node]:
	_prune_runtime()
	return interactive_props.duplicate()

func _apply_profile_to_systems(profile: SurvivalArenaProfile) -> void:
	var playground := get_node_or_null(playground_path) as IsometricPlayground
	if playground != null:
		playground.configure_arena(profile)
	var wave_manager := get_tree().get_first_node_in_group(
		"wave_manager"
	) as WaveManager
	if wave_manager != null:
		wave_manager.configure_spawn_points(profile.enemy_spawn_points)
	var zombie_spawner = get_tree().get_first_node_in_group(
		"zombie_spawner"
	)
	if zombie_spawner != null:
		zombie_spawner.configure_fallback_spawn_points(profile.enemy_spawn_points)
	var player_manager := get_tree().get_first_node_in_group(
		"player_manager"
	) as PlayerManager
	if player_manager != null and not profile.player_spawn_points.is_empty():
		player_manager.spawn_points = profile.player_spawn_points.duplicate()
	var ammo_director := get_tree().get_first_node_in_group(
		"survival_ammo_director"
	) as SurvivalAmmoDirector
	if ammo_director != null and not profile.crate_spawn_points.is_empty():
		ammo_director.crate_spawn_points = profile.crate_spawn_points.duplicate()

func _spawn_gates() -> void:
	if active_profile == null or active_profile.biome == null:
		return
	var container := _get_environment_container()
	if container == null:
		return
	for index in range(active_profile.enemy_spawn_points.size()):
		var spawn_position := active_profile.enemy_spawn_points[index]
		var gate := SpawnGateVisual.new()
		gate.name = "SpawnGate%d" % (index + 1)
		gate.position = spawn_position
		gate.z_index = -2
		gate.configure(
			active_profile.biome.gate_color,
			index,
			spawn_position.direction_to(Vector2.ZERO)
		)
		container.add_child(gate)
		spawn_gates.append(gate)

func _spawn_interactive_props() -> void:
	if active_profile == null or active_profile.biome == null:
		return
	var container := _get_environment_container()
	if container == null:
		return
	for prop_position in active_profile.barrel_positions:
		var barrel := EXPLOSIVE_BARREL_SCENE.instantiate() as ExplosiveBarrel
		if barrel == null:
			continue
		barrel.position = prop_position
		barrel.configure_colors(
			active_profile.biome.prop_color,
			active_profile.biome.hazard_color.lightened(0.18)
		)
		container.add_child(barrel)
		interactive_props.append(barrel)
		environment_prop_spawned.emit(barrel)

func _move_players_to_spawns() -> void:
	if active_profile == null or active_profile.player_spawn_points.is_empty():
		return
	var players := PlayerQuery.all(get_tree())
	players.sort_custom(func(a: Node, b: Node) -> bool:
		return int(a.get("player_slot")) < int(b.get("player_slot"))
	)
	for index in range(players.size()):
		var player := players[index] as Node2D
		if player != null:
			player.global_position = active_profile.player_spawn_points[
				index % active_profile.player_spawn_points.size()
			]

func _connect_wave_manager() -> void:
	var wave_manager := get_tree().get_first_node_in_group(
		"wave_manager"
	) as WaveManager
	if wave_manager == null:
		return
	var callback := Callable(self, "_on_wave_enemy_spawned")
	if not wave_manager.enemy_spawned.is_connected(callback):
		wave_manager.enemy_spawned.connect(callback)

func _on_wave_enemy_spawned(
	_enemy: Node,
	spawn_position: Vector2,
	_spawn_index: int
) -> void:
	if not is_active or spawn_gates.is_empty():
		return
	var nearest_gate: SpawnGateVisual
	var nearest_distance := INF
	for gate in spawn_gates:
		if not is_instance_valid(gate):
			continue
		var distance := gate.global_position.distance_squared_to(spawn_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_gate = gate
	if nearest_gate != null:
		nearest_gate.play_spawn_pulse()

func _get_environment_container() -> Node:
	var container := get_node_or_null(environment_container_path)
	return container if container != null else get_tree().current_scene

func _clear_runtime() -> void:
	for gate in spawn_gates:
		if is_instance_valid(gate):
			gate.queue_free()
	for prop in interactive_props:
		if is_instance_valid(prop):
			prop.queue_free()
	spawn_gates.clear()
	interactive_props.clear()

func _prune_runtime() -> void:
	for gate in spawn_gates.duplicate():
		if not is_instance_valid(gate) or gate.is_queued_for_deletion():
			spawn_gates.erase(gate)
	for prop in interactive_props.duplicate():
		if not is_instance_valid(prop) or prop.is_queued_for_deletion():
			interactive_props.erase(prop)

