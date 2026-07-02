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
var last_spawn_rejection_reason: StringName = &""
var last_spawn_attempt_report: Array[Dictionary] = []
var obstacle_system: ObstacleSystem
var hazard_system: HazardSystem
var biome_manager: BiomeManager
var region_seam_system: RegionSeamSystem
var world_region_streamer: WorldRegionStreamer

func _ready() -> void:
	add_to_group("zombie_spawner")

func configure_runtime_dependencies(
	next_obstacle_system: ObstacleSystem,
	next_hazard_system: HazardSystem,
	next_biome_manager: BiomeManager,
	next_region_seam_system: RegionSeamSystem,
	next_world_region_streamer: WorldRegionStreamer
) -> void:
	obstacle_system = next_obstacle_system
	hazard_system = next_hazard_system
	biome_manager = next_biome_manager
	region_seam_system = next_region_seam_system
	world_region_streamer = next_world_region_streamer

func configure_fallback_spawn_points(points: Array[Vector2]) -> void:
	if points.is_empty():
		return
	fallback_spawn_points = points.duplicate()

func get_spawn_position(
	spawn_index: int,
	_enemy_id: StringName = &"",
	biome = null
) -> Vector2:
	last_spawn_rejection_reason = &""
	last_spawn_attempt_report.clear()
	var visible_rect := get_visible_world_rect()
	if visible_rect.size.x <= 0.0 or visible_rect.size.y <= 0.0:
		var no_camera_fallback := _fallback_spawn_position(spawn_index, biome, true)
		last_spawn_edge = StringName(no_camera_fallback.get("edge", &"fallback"))
		last_spawn_rejection_reason = StringName(no_camera_fallback.get("reason", &""))
		return no_camera_fallback.get("position", Vector2.ZERO) as Vector2

	for attempt in range(max_spawn_attempts):
		var edge := _select_edge(spawn_index, attempt)
		var candidate := _candidate_on_edge(visible_rect, edge, spawn_index, attempt)
		var rejection_reason := get_spawn_rejection_reason(candidate, biome)
		_record_spawn_attempt(edge, candidate, rejection_reason)
		if rejection_reason.is_empty():
			last_spawn_edge = edge
			last_spawn_rejection_reason = &""
			return candidate

	var fallback := _fallback_spawn_position(
		spawn_index,
		biome,
		max_spawn_attempts <= 0
	)
	last_spawn_edge = StringName(fallback.get("edge", &"fallback"))
	last_spawn_rejection_reason = StringName(fallback.get("reason", &""))
	return fallback.get("position", Vector2.ZERO) as Vector2

func is_spawn_position_valid(position: Vector2, _biome = null) -> bool:
	return get_spawn_rejection_reason(position, _biome).is_empty()

func get_spawn_rejection_reason(position: Vector2, _biome = null) -> StringName:
	if not is_position_outside_camera_view(position):
		return &"inside_camera"
	if not _is_position_inside_generated_biome(position, _biome):
		return &"outside_generated_biome"
	if _is_too_close_to_players(position):
		return &"too_close_to_player"
	if _is_position_blocked_by_obstacles(position):
		return &"blocked"
	if _is_position_hazardous(position):
		return &"hazard"
	return &""

func get_visible_world_rect() -> Rect2:
	return WorldChunkVisibilityController.get_visible_world_rect(get_viewport())

func is_position_outside_camera_view(position: Vector2) -> bool:
	var visible_rect := get_visible_world_rect()
	return visible_rect.size.x <= 0.0 or not visible_rect.has_point(position)

func get_last_spawn_edge() -> StringName:
	return last_spawn_edge

func get_last_spawn_rejection_reason() -> StringName:
	return last_spawn_rejection_reason

func get_last_spawn_attempt_report() -> Array[Dictionary]:
	return last_spawn_attempt_report.duplicate(true)

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
	return _candidate_on_edge_with_margin(
		visible_rect,
		edge,
		spawn_index,
		attempt,
		spawn_margin
	)

func _candidate_on_edge_with_margin(
	visible_rect: Rect2,
	edge: StringName,
	spawn_index: int,
	attempt: int,
	margin: float
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
			return Vector2(along_x, visible_rect.position.y - margin) + jitter
		&"south":
			return Vector2(along_x, visible_rect.end.y + margin) + jitter
		&"east":
			return Vector2(visible_rect.end.x + margin, along_y) + jitter
		&"west":
			return Vector2(visible_rect.position.x - margin, along_y) + jitter
		_:
			return Vector2(visible_rect.end.x + margin, along_y) + jitter

func _fallback_spawn_position(
	spawn_index: int,
	biome = null,
	prefer_configured: bool = false
) -> Dictionary:
	if prefer_configured:
		var preferred_configured := _configured_fallback_spawn_position(
			spawn_index,
			biome
		)
		if bool(preferred_configured.get("found", false)):
			return preferred_configured
	var edge_fallback := _edge_fallback_spawn_position(spawn_index, biome)
	if bool(edge_fallback.get("found", false)):
		return edge_fallback
	var streamed_fallback := _streamed_region_fallback_spawn_position(
		spawn_index,
		biome
	)
	if bool(streamed_fallback.get("found", false)):
		return streamed_fallback
	var configured_fallback := _configured_fallback_spawn_position(
		spawn_index,
		biome
	)
	if bool(configured_fallback.get("found", false)):
		return configured_fallback
	var visible_rect := get_visible_world_rect()
	var raw_position := (
		Vector2(visible_rect.end.x + spawn_margin, visible_rect.get_center().y)
		if visible_rect.size.x > 0.0
		else Vector2.ZERO
	)
	var reason := get_spawn_rejection_reason(raw_position, biome)
	_record_spawn_attempt(&"fallback", raw_position, reason)
	return {
		"found": false,
		"edge": &"fallback",
		"position": raw_position,
		"reason": reason
	}

func _configured_fallback_spawn_position(spawn_index: int, biome = null) -> Dictionary:
	if not fallback_spawn_points.is_empty():
		var best_point := Vector2.ZERO
		var best_distance := -1.0
		for point in fallback_spawn_points:
			var reason := get_spawn_rejection_reason(point, biome)
			_record_spawn_attempt(&"fallback", point, reason)
			if not reason.is_empty():
				continue
			var distance := _distance_squared_to_nearest_player(point)
			if distance > best_distance:
				best_distance = distance
				best_point = point
		if best_distance >= 0.0:
			var fallback_edge := _edge_for_offscreen_position(best_point)
			return {
				"found": true,
				"edge": fallback_edge if not fallback_edge.is_empty() else &"fallback",
				"position": best_point,
				"reason": &""
			}
	return {
		"found": false,
		"edge": &"fallback",
		"position": Vector2.ZERO,
		"reason": &"no_valid_configured_fallback"
	}

func _edge_fallback_spawn_position(spawn_index: int, biome = null) -> Dictionary:
	var visible_rect := get_visible_world_rect()
	if visible_rect.size.x <= 0.0 or visible_rect.size.y <= 0.0:
		return {
			"found": false,
			"edge": &"fallback",
			"position": Vector2.ZERO,
			"reason": &"no_camera"
		}
	var attempts := maxi(max_spawn_attempts, 16)
	var edges := _weighted_edge_names()
	if edges.is_empty():
		edges = [&"north", &"south", &"east", &"west"]
	for ring in range(3):
		var margin := spawn_margin + float(ring) * 80.0
		for attempt in range(attempts):
			var edge := edges[(spawn_index + attempt) % edges.size()]
			var candidate := _candidate_on_edge_with_margin(
				visible_rect,
				edge,
				spawn_index,
				attempt + 1000 + ring * attempts,
				margin
			)
			var reason := get_spawn_rejection_reason(candidate, biome)
			_record_spawn_attempt(edge, candidate, reason)
			if reason.is_empty():
				return {
					"found": true,
					"edge": edge,
					"position": candidate,
					"reason": &""
				}
	return {
		"found": false,
		"edge": &"fallback",
		"position": Vector2(
			visible_rect.end.x + spawn_margin,
			visible_rect.get_center().y
		),
		"reason": &"no_valid_edge_fallback"
	}

func _streamed_region_fallback_spawn_position(spawn_index: int, biome = null) -> Dictionary:
	_resolve_runtime_dependencies()
	var streamer := world_region_streamer
	if (
		streamer == null
		or biome_manager == null
		or not streamer.has_method("get_streamed_region_ids")
		or not streamer.has_method("get_region_offset")
	):
		return {
			"found": false,
			"edge": &"fallback",
			"position": Vector2.ZERO,
			"reason": &"no_streamed_regions"
		}
	var best_position := Vector2.ZERO
	var best_edge: StringName = &""
	var best_distance := INF
	for region_id_value in streamer.get_streamed_region_ids():
		var region_id := StringName(region_id_value)
		var cell := biome_manager.get_cell_by_region_id(region_id) as BiomeCell
		if cell == null or cell.generated_layout == null:
			continue
		var offset: Vector2 = streamer.get_region_offset(region_id)
		for local_cell in _candidate_cells_for_layout(
			cell.generated_layout,
			spawn_index
		):
			var candidate := offset + cell.generated_layout.logical_to_world(
				local_cell
			)
			var edge := _edge_for_offscreen_position(candidate)
			var reason := get_spawn_rejection_reason(candidate, biome)
			_record_spawn_attempt(
				edge if not edge.is_empty() else &"streamed",
				candidate,
				reason
			)
			if not reason.is_empty():
				continue
			var distance := _distance_squared_to_nearest_player(candidate)
			if distance < best_distance:
				best_distance = distance
				best_position = candidate
				best_edge = edge
	if best_distance < INF:
		return {
			"found": true,
			"edge": best_edge if not best_edge.is_empty() else &"fallback",
			"position": best_position,
			"reason": &""
		}
	return {
		"found": false,
		"edge": &"fallback",
		"position": Vector2.ZERO,
		"reason": &"no_valid_streamed_region_fallback"
	}

func _is_too_close_to_players(position: Vector2) -> bool:
	return (
		_distance_squared_to_nearest_player(position)
		< min_distance_from_player * min_distance_from_player
	)

func _distance_squared_to_nearest_player(position: Vector2) -> float:
	return PlayerQuery.nearest_distance_squared(get_tree(), position)

func _is_position_blocked_by_obstacles(position: Vector2) -> bool:
	_resolve_runtime_dependencies()
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
	_resolve_runtime_dependencies()
	return (
		hazard_system != null
		and hazard_system.has_method("is_position_hazardous")
		and hazard_system.is_position_hazardous(position)
	)

func _is_position_inside_generated_biome(position: Vector2, biome) -> bool:
	_resolve_runtime_dependencies()
	var seam_system := region_seam_system
	if (
		seam_system != null
		and bool(seam_system.get("is_active"))
		and seam_system.has_method("get_region_id_for_world_position")
	):
		var region_id := StringName(
			seam_system.get_region_id_for_world_position(position)
		)
		if region_id.is_empty():
			return false
		var streamer := world_region_streamer
		if (
			streamer != null
			and streamer.has_method("is_region_streamed")
			and not bool(streamer.is_region_streamed(region_id))
		):
			return false
		return _is_position_on_streamed_walkable_terrain(
			position,
			region_id,
			seam_system
		)
	if biome == null:
		return true
	var layout := biome.get("environment_layout") as BiomeEnvironmentLayout
	if layout == null or not layout.has_generated_map_data():
		return true
	if not layout.is_world_position_inside_zone(position):
		return false
	var cell := layout.world_to_logical(position)
	return _is_walkable_spawn_class(layout.get_terrain_class_at_cell(cell))

func _is_position_on_streamed_walkable_terrain(
	position: Vector2,
	region_id: StringName,
	seam_system: Node
) -> bool:
	_resolve_runtime_dependencies()
	if biome_manager == null or not seam_system.has_method("world_position_to_logical_tile"):
		return true
	var cell := biome_manager.get_cell_by_region_id(region_id) as BiomeCell
	if cell == null or cell.generated_layout == null:
		return true
	var world_tile: Vector2i = seam_system.world_position_to_logical_tile(position)
	var local_tile := world_tile - cell.world_origin
	return _is_walkable_spawn_class(
		cell.generated_layout.get_terrain_class_at_cell(local_tile, cell)
	)

func _weighted_edge_names() -> Array[StringName]:
	var result: Array[StringName] = []
	for data in _weighted_edges():
		result.append(StringName(data["edge"]))
	return result

func _candidate_cells_for_layout(
	layout: BiomeEnvironmentLayout,
	spawn_index: int
) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if layout == null:
		return result
	_append_unique_cell(result, layout.player_spawn_cell)
	for rect in layout.passage_rects:
		_append_unique_cell(result, rect.position + rect.size / 2)
	for rect in layout.bridge_rects:
		_append_unique_cell(result, rect.position + rect.size / 2)
	for rect in layout.road_rects:
		_append_unique_cell(result, rect.position + rect.size / 2)
	for rect in layout.floor_rects:
		_append_unique_cell(result, rect.position + rect.size / 2)
	for cell in layout.crate_cells:
		_append_unique_cell(result, cell)
	var road_cells := layout.get_road_cells()
	if not road_cells.is_empty():
		var sample_count := mini(road_cells.size(), 32)
		for index in range(sample_count):
			var road_index := (spawn_index * 11 + index * 17) % road_cells.size()
			_append_unique_cell(result, road_cells[road_index])
	return result

func _append_unique_cell(cells: Array[Vector2i], cell: Vector2i) -> void:
	if not cells.has(cell):
		cells.append(cell)

func _edge_for_offscreen_position(position: Vector2) -> StringName:
	var visible_rect := get_visible_world_rect()
	if visible_rect.size.x <= 0.0 or visible_rect.size.y <= 0.0:
		return &""
	if visible_rect.has_point(position):
		return &""
	var distances := {
		&"west": maxf(visible_rect.position.x - position.x, 0.0),
		&"east": maxf(position.x - visible_rect.end.x, 0.0),
		&"north": maxf(visible_rect.position.y - position.y, 0.0),
		&"south": maxf(position.y - visible_rect.end.y, 0.0)
	}
	var best_edge: StringName = &""
	var best_distance := 0.0
	for edge in distances.keys():
		var distance := float(distances[edge])
		if distance > best_distance:
			best_distance = distance
			best_edge = StringName(edge)
	return best_edge

func _record_spawn_attempt(
	edge: StringName,
	position: Vector2,
	rejection_reason: StringName
) -> void:
	if last_spawn_attempt_report.size() >= 64:
		return
	last_spawn_attempt_report.append({
		"edge": edge,
		"position": position,
		"reason": rejection_reason
	})
	if not rejection_reason.is_empty():
		last_spawn_rejection_reason = rejection_reason

func _is_walkable_spawn_class(terrain_class: StringName) -> bool:
	return terrain_class == BiomeEnvironmentLayout.TERRAIN_WALKABLE

func _unit_sample(spawn_index: int, attempt: int, salt: int) -> float:
	var raw := absi(spawn_index * 110351 + attempt * 9176 + salt * 131)
	return float(raw % 10000) / 9999.0

func _resolve_runtime_dependencies() -> void:
	if obstacle_system == null:
		obstacle_system = _resolve_node(&"obstacle_system") as ObstacleSystem
	if hazard_system == null:
		hazard_system = _resolve_node(&"hazard_system") as HazardSystem
	if biome_manager == null:
		biome_manager = _resolve_node(&"biome_manager") as BiomeManager
	if region_seam_system == null:
		region_seam_system = _resolve_node(
			&"region_seam_system"
		) as RegionSeamSystem
	if world_region_streamer == null:
		world_region_streamer = _resolve_node(
			&"world_region_streamer"
		) as WorldRegionStreamer

func _resolve_node(group_name: StringName) -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group(group_name)
