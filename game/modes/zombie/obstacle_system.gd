extends Node
class_name ObstacleSystem

signal obstacle_rules_configured(biome_id: StringName)
signal obstacle_spawned(obstacle: Node2D, obstacle_id: StringName)

const BIOME_OBSTACLE_SCRIPT = preload(
	"res://game/modes/zombie/biome_obstacle.gd"
)

@export var environment_container_path: NodePath = NodePath(
	"../../../../World/EnvironmentProps"
)

var active_biome: BiomeDefinition
var is_active: bool = false
var active_obstacles: Array[Node2D] = []
var manifest: IsometricEnvironmentManifest

func _ready() -> void:
	add_to_group("obstacle_system")
	manifest = IsometricEnvironmentManifest.get_shared()

func start_run(biome: BiomeDefinition) -> void:
	_clear_runtime()
	active_biome = biome
	is_active = true
	_generate_obstacles()
	obstacle_rules_configured.emit(
		active_biome.biome_id if active_biome != null else &""
	)

func stop_run() -> void:
	_clear_runtime()
	is_active = false
	active_biome = null

func get_active_obstacles() -> Array[Node2D]:
	_prune_runtime()
	return active_obstacles.duplicate()

func is_position_blocked(position: Vector2) -> bool:
	return _is_position_blocked(position, false)

# Solid-only query: jumpable obstacles (gap anchors) are skipped so a dodge can
# cross over them while spawn/landing checks keep treating them as occupied.
func is_position_blocked_by_non_jumpable(position: Vector2) -> bool:
	return _is_position_blocked(position, true)

func is_position_jumpable_obstacle(position: Vector2) -> bool:
	for blocker in get_tree().get_nodes_in_group("environment_obstacles"):
		if _is_jumpable(blocker) and _node_contains_position(blocker, position):
			return true
	return false

func _is_position_blocked(position: Vector2, skip_jumpable: bool) -> bool:
	for group in ["spawn_blockers", "environment_obstacles"]:
		for blocker in get_tree().get_nodes_in_group(group):
			if skip_jumpable and _is_jumpable(blocker):
				continue
			if _node_contains_position(blocker, position):
				return true
	return false

func _is_jumpable(node: Node) -> bool:
	return (
		node != null
		and is_instance_valid(node)
		and node.has_method("is_jumpable_obstacle")
		and bool(node.is_jumpable_obstacle())
	)

func _node_contains_position(node: Node, position: Vector2) -> bool:
	if (
		node == null
		or not is_instance_valid(node)
		or node.is_queued_for_deletion()
	):
		return false
	if node.has_method("contains_global_position"):
		return bool(node.contains_global_position(position))
	if node is Node2D:
		var radius := float(node.get_meta("zone_radius", 32.0))
		return (node as Node2D).global_position.distance_squared_to(position) <= radius * radius
	if node is CollisionObject2D and node is Node2D:
		return (node as Node2D).global_position.distance_squared_to(position) <= 32.0 * 32.0
	return false

func _generate_obstacles() -> void:
	if active_biome == null:
		return
	var layout := active_biome.environment_layout
	var palette := active_biome.palette
	var allowed_ids := active_biome.obstacle_ids
	var container := _get_environment_container()
	if layout == null or palette == null or container == null:
		return
	for index in range(layout.obstacle_positions.size()):
		if index >= layout.obstacle_ids.size():
			break
		var obstacle_id := layout.obstacle_ids[index]
		if not allowed_ids.has(obstacle_id):
			continue
		var obstacle := BIOME_OBSTACLE_SCRIPT.new() as BiomeObstacle
		if obstacle == null:
			continue
		var size := (
			layout.obstacle_sizes[index]
			if index < layout.obstacle_sizes.size()
			else Vector2(48.0, 32.0)
		)
		var rotation_radians := (
			layout.obstacle_rotations[index]
			if index < layout.obstacle_rotations.size()
			else 0.0
		)
		var shape_id := (
			layout.obstacle_shape_ids[index]
			if index < layout.obstacle_shape_ids.size()
			else &"rectangle"
		)
		obstacle.name = "%s%d" % [
			_pascal_case(String(obstacle_id)),
			index + 1
		]
		obstacle.configure(
			obstacle_id,
			size,
			shape_id,
			rotation_radians,
			palette.prop_color,
			palette.hazard_color,
			_sort_offset_for(obstacle_id)
		)
		obstacle.obstacle_key = make_obstacle_key(
			active_biome.biome_id,
			index,
			obstacle_id
		)
		container.add_child(obstacle)
		if manifest != null and not manifest.blocks_movement(obstacle_id):
			obstacle.remove_from_group("spawn_blockers")
			obstacle.remove_from_group("environment_obstacles")
		obstacle.global_position = layout.obstacle_positions[index]
		active_obstacles.append(obstacle)
		obstacle_spawned.emit(obstacle, obstacle_id)

func _get_environment_container() -> Node:
	var container := get_node_or_null(environment_container_path)
	return container if container != null else get_tree().current_scene

func _clear_runtime() -> void:
	for obstacle in active_obstacles:
		if is_instance_valid(obstacle):
			obstacle.queue_free()
	active_obstacles.clear()

func _prune_runtime() -> void:
	for obstacle in active_obstacles.duplicate():
		if (
			not is_instance_valid(obstacle)
			or obstacle.is_queued_for_deletion()
		):
			active_obstacles.erase(obstacle)

# Deterministic key: the layout regenerates in the same order for a given seed
# and region, so {biome}:{index}:{id} is stable across revisits and safe to use
# as a persistence key for future destructible-obstacle ledgers.
static func make_obstacle_key(
	biome_id: StringName,
	index: int,
	obstacle_id: StringName
) -> StringName:
	return StringName("%s:%d:%s" % [String(biome_id), index, String(obstacle_id)])

func _sort_offset_for(obstacle_id: StringName) -> float:
	if manifest == null:
		return 0.0
	return manifest.get_sort_offset(obstacle_id)

func _pascal_case(value: String) -> String:
	var result := ""
	for part in value.split("_", false):
		result += part.capitalize()
	return result
