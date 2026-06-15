extends Node
class_name ZombieSpawner

@export var spawn_margin: float = 140.0
@export var min_distance_from_player: float = 220.0
@export_range(1, 64) var max_spawn_attempts: int = 20
@export var spawn_group_radius: float = 24.0
@export_range(1, 32) var max_spawn_per_tick: int = 1
@export var spawn_delay_between_groups: float = 0.45
@export var spawn_blocker_collision_mask: int = 0
@export var fallback_spawn_points: Array[Vector2] = []
@export var spawn_edge_weights: Dictionary = {
	&"north": 1.0,
	&"south": 1.0,
	&"east": 1.0,
	&"west": 1.0
}

var last_spawn_edge: StringName = &""

func _ready() -> void:
	add_to_group("zombie_spawner")

func configure_fallback_spawn_points(points: Array[Vector2]) -> void:
	if points.is_empty():
		return
	fallback_spawn_points = points.duplicate()

func get_spawn_position(
	spawn_index: int,
	_enemy_id: StringName = &"",
	biome = null
) -> Vector2:
	var visible_rect := get_visible_world_rect()
	if visible_rect.size.x <= 0.0 or visible_rect.size.y <= 0.0:
		return _fallback_spawn_position(spawn_index)

	for attempt in range(max_spawn_attempts):
		var edge := _select_edge(spawn_index, attempt)
		var candidate := _candidate_on_edge(visible_rect, edge, spawn_index, attempt)
		if is_spawn_position_valid(candidate, biome):
			last_spawn_edge = edge
			return candidate

	last_spawn_edge = &"fallback"
	return _fallback_spawn_position(spawn_index)

func is_spawn_position_valid(position: Vector2, _biome = null) -> bool:
	if not is_position_outside_camera_view(position):
		return false
	if not _is_position_inside_generated_biome(position, _biome):
		return false
	if _is_too_close_to_players(position):
		return false
	if _is_position_blocked_by_obstacles(position):
		return false
	if _is_position_hazardous(position):
		return false
	return true

func get_visible_world_rect() -> Rect2:
	var viewport := get_viewport()
	if viewport == null:
		return Rect2()
	var camera := viewport.get_camera_2d()
	if camera == null:
		return Rect2()
	var viewport_size := viewport.get_visible_rect().size
	var camera_zoom := Vector2(
		maxf(camera.zoom.x, 0.01),
		maxf(camera.zoom.y, 0.01)
	)
	var world_size := Vector2(
		viewport_size.x / camera_zoom.x,
		viewport_size.y / camera_zoom.y
	)
	var center := camera.get_screen_center_position()
	return Rect2(center - world_size * 0.5, world_size)

func is_position_outside_camera_view(position: Vector2) -> bool:
	var visible_rect := get_visible_world_rect()
	return visible_rect.size.x <= 0.0 or not visible_rect.has_point(position)

func get_last_spawn_edge() -> StringName:
	return last_spawn_edge

func _select_edge(spawn_index: int, attempt: int) -> StringName:
	var edges := _weighted_edges()
	if edges.is_empty():
		return [&"north", &"south", &"east", &"west"][(spawn_index + attempt) % 4]
	var total_weight := 0.0
	for data in edges:
		total_weight += float(data["weight"])
	var roll := _unit_sample(spawn_index, attempt, 17) * total_weight
	var cursor := 0.0
	for data in edges:
		cursor += float(data["weight"])
		if roll <= cursor:
			return StringName(data["edge"])
	return StringName(edges.back()["edge"])

func _weighted_edges() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for edge in [&"north", &"south", &"east", &"west"]:
		var weight := maxf(float(spawn_edge_weights.get(edge, 0.0)), 0.0)
		if weight > 0.0:
			result.append({"edge": edge, "weight": weight})
	return result

func _candidate_on_edge(
	visible_rect: Rect2,
	edge: StringName,
	spawn_index: int,
	attempt: int
) -> Vector2:
	var t := _unit_sample(spawn_index, attempt, 101)
	var along_x := lerpf(visible_rect.position.x, visible_rect.end.x, t)
	var along_y := lerpf(visible_rect.position.y, visible_rect.end.y, t)
	var jitter := (
		Vector2.RIGHT.rotated(TAU * _unit_sample(spawn_index, attempt, 211))
		* spawn_group_radius
		* _unit_sample(spawn_index, attempt, 307)
	)
	match edge:
		&"north":
			return Vector2(along_x, visible_rect.position.y - spawn_margin) + jitter
		&"south":
			return Vector2(along_x, visible_rect.end.y + spawn_margin) + jitter
		&"east":
			return Vector2(visible_rect.end.x + spawn_margin, along_y) + jitter
		&"west":
			return Vector2(visible_rect.position.x - spawn_margin, along_y) + jitter
		_:
			return Vector2(visible_rect.end.x + spawn_margin, along_y) + jitter

func _fallback_spawn_position(spawn_index: int) -> Vector2:
	if not fallback_spawn_points.is_empty():
		var best_point := fallback_spawn_points[spawn_index % fallback_spawn_points.size()]
		var best_distance := -1.0
		for point in fallback_spawn_points:
			var distance := _distance_squared_to_nearest_player(point)
			if distance > best_distance:
				best_distance = distance
				best_point = point
		return best_point
	var visible_rect := get_visible_world_rect()
	if visible_rect.size.x > 0.0:
		return Vector2(visible_rect.end.x + spawn_margin, visible_rect.get_center().y)
	return Vector2.ZERO

func _is_too_close_to_players(position: Vector2) -> bool:
	return (
		_distance_squared_to_nearest_player(position)
		< min_distance_from_player * min_distance_from_player
	)

func _distance_squared_to_nearest_player(position: Vector2) -> float:
	var nearest := INF
	for player in get_tree().get_nodes_in_group("players"):
		if not player is Node2D:
			continue
		var health_component := player.get_node_or_null("HealthComponent") as HealthComponent
		if health_component != null and not health_component.is_alive():
			continue
		nearest = minf(
			nearest,
			position.distance_squared_to((player as Node2D).global_position)
		)
	return nearest

func _is_position_blocked_by_obstacles(position: Vector2) -> bool:
	var obstacle_system := get_tree().get_first_node_in_group("obstacle_system")
	if (
		obstacle_system != null
		and obstacle_system.has_method("is_position_blocked")
		and obstacle_system.is_position_blocked(position)
	):
		return true
	if spawn_blocker_collision_mask <= 0:
		return false
	var viewport := get_viewport()
	if viewport == null or viewport.world_2d == null:
		return false
	var shape := CircleShape2D.new()
	shape.radius = 12.0
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, position)
	query.collision_mask = spawn_blocker_collision_mask
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var results := viewport.world_2d.direct_space_state.intersect_shape(query, 12)
	for result in results:
		var collider := result.get("collider") as Node
		if collider == null:
			continue
		if (
			collider.is_in_group("spawn_blockers")
			or collider.is_in_group("fall_zones")
			or collider.is_in_group("environment_obstacles")
		):
			return true
	return false

func _is_position_hazardous(position: Vector2) -> bool:
	var hazard_system := get_tree().get_first_node_in_group("hazard_system")
	return (
		hazard_system != null
		and hazard_system.has_method("is_position_hazardous")
		and hazard_system.is_position_hazardous(position)
	)

func _is_position_inside_generated_biome(position: Vector2, biome) -> bool:
	if biome == null:
		return true
	var layout := biome.get("environment_layout") as BiomeEnvironmentLayout
	if layout == null or not layout.has_generated_map_data():
		return true
	return layout.is_world_position_inside_zone(position)

func _unit_sample(spawn_index: int, attempt: int, salt: int) -> float:
	var raw := absi(spawn_index * 110351 + attempt * 9176 + salt * 131)
	return float(raw % 10000) / 9999.0
