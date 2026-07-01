extends Node
class_name RegionSeamSystem

const IsoGridConfig = preload("res://game/core/iso_grid_config.gd")

signal region_seam_crossed(
	previous_region_id: StringName,
	current_region_id: StringName,
	connection_id: StringName
)

@export_range(0.05, 3.0, 0.05) var transition_cooldown: float = 0.45
@export_range(0, 12, 1) var crossing_margin_tiles: int = IsoGridConfig.CROSSING_MARGIN_TILES
@export var player_group: StringName = &"players"

var biome_manager: BiomeManager
var world_runtime: WorldRuntime
var graph: WorldGraph
var anchor_region_id: StringName = &""
var is_active: bool = false
var cooldown_timer: float = 0.0

func _ready() -> void:
	add_to_group("region_seam_system")

func _process(delta: float) -> void:
	cooldown_timer = maxf(cooldown_timer - delta, 0.0)
	if is_active:
		update_region_from_party()

func start_run(
	manager: BiomeManager,
	runtime: WorldRuntime = null
) -> void:
	biome_manager = manager
	world_runtime = runtime
	graph = (
		world_runtime.graph
		if world_runtime != null and world_runtime.graph != null
		else biome_manager.get_world_graph() if biome_manager != null else null
	)
	anchor_region_id = graph.start_region_id if graph != null else &""
	is_active = graph != null and biome_manager != null
	cooldown_timer = 0.0

func stop_run() -> void:
	biome_manager = null
	world_runtime = null
	graph = null
	anchor_region_id = &""
	is_active = false
	cooldown_timer = 0.0

func update_region_from_party() -> bool:
	var party_position: Variant = get_party_center()
	if party_position == null:
		return false
	return try_update_region_for_position(party_position as Vector2)

func try_update_region_for_position(world_position: Vector2) -> bool:
	if not is_active or cooldown_timer > 0.0:
		return false
	var current_region_id := get_current_region_id()
	if current_region_id.is_empty():
		return false
	var target_region_id := get_region_id_for_world_position(world_position)
	if target_region_id.is_empty() or target_region_id == current_region_id:
		return false
	var connection := get_open_connection_for_world_position(
		current_region_id,
		target_region_id,
		world_position
	)
	if connection == null:
		return false
	var changed := biome_manager.set_current_region(target_region_id)
	if not changed:
		return false
	if (
		world_runtime != null
		and world_runtime.get_current_region_id() != target_region_id
	):
		world_runtime.set_current_region(target_region_id)
	cooldown_timer = transition_cooldown
	region_seam_crossed.emit(
		current_region_id,
		target_region_id,
		connection.connection_id
	)
	return true

func get_current_region_id() -> StringName:
	if biome_manager != null:
		return biome_manager.get_current_region_id()
	if world_runtime != null:
		return world_runtime.get_current_region_id()
	return &""

func get_party_center() -> Variant:
	var players := get_tree().get_nodes_in_group(player_group)
	var sum := Vector2.ZERO
	var count := 0
	for player in players:
		if not player is Node2D:
			continue
		var health_component := player.get_node_or_null(
			"HealthComponent"
		) as HealthComponent
		if health_component != null and not health_component.is_alive():
			continue
		sum += (player as Node2D).global_position
		count += 1
	if count <= 0:
		return null
	return sum / float(count)

func get_region_id_for_world_position(world_position: Vector2) -> StringName:
	if graph == null:
		return &""
	var world_tile := world_position_to_logical_tile(world_position)
	var region := graph.get_region_at_world_tile(world_tile)
	return region.region_id if region != null else &""

func world_position_to_logical_tile(world_position: Vector2) -> Vector2i:
	var anchor := _get_anchor_region()
	if anchor == null:
		return Vector2i.ZERO
	var scale := _tile_scale_for_region(anchor.region_id)
	var zone_size := anchor.size_tiles
	return anchor.world_origin + Vector2i(
		floori(world_position.x / scale + float(zone_size.x) * 0.5),
		floori(world_position.y / scale + float(zone_size.y) * 0.5)
	)

func logical_tile_to_world_position(
	world_tile: Vector2i,
	reference_region_id: StringName = &""
) -> Vector2:
	var reference := _get_reference_region(reference_region_id)
	if reference == null:
		return Vector2.ZERO
	var scale := _tile_scale_for_region(reference.region_id)
	var local_tile := world_tile - reference.world_origin
	return (
		Vector2(
			float(local_tile.x) + 0.5 - float(reference.size_tiles.x) * 0.5,
			float(local_tile.y) + 0.5 - float(reference.size_tiles.y) * 0.5
		)
		* scale
	)

func get_crossing_position_for_connection(
	connection: WorldRegionConnection,
	reference_region_id: StringName = &""
) -> Vector2:
	if connection == null:
		return Vector2.ZERO
	var tile := _connection_seam_tile(connection)
	return logical_tile_to_world_position(tile, reference_region_id)

func get_open_connection_for_world_position(
	from_region_id: StringName,
	to_region_id: StringName,
	world_position: Vector2
) -> WorldRegionConnection:
	if graph == null:
		return null
	var source := graph.get_region(from_region_id)
	if source == null:
		return null
	var world_tile := world_position_to_logical_tile(world_position)
	for connection in source.connection_edges:
		if (
			connection.to_region_id == to_region_id
			and connection.is_open
			and connection.physical_passage
			and _connection_contains_world_tile(source, connection, world_tile)
		):
			return connection
	return null

func region_contains_world_tile(region: WorldRegion, world_tile: Vector2i) -> bool:
	if region == null:
		return false
	return Rect2i(region.world_origin, region.size_tiles).has_point(world_tile)

func _get_anchor_region() -> WorldRegion:
	if graph == null:
		return null
	var resolved_anchor := anchor_region_id
	if resolved_anchor.is_empty():
		resolved_anchor = graph.start_region_id
	return graph.get_region(resolved_anchor)

func _get_reference_region(reference_region_id: StringName) -> WorldRegion:
	if graph == null:
		return null
	if not reference_region_id.is_empty():
		var explicit := graph.get_region(reference_region_id)
		if explicit != null:
			return explicit
	return _get_anchor_region()

func _tile_scale_for_region(region_id: StringName) -> float:
	var region := graph.get_region(region_id) if graph != null else null
	if region != null and region.generated_layout != null:
		return region.generated_layout.logical_tile_scale
	var cell := (
		biome_manager.get_cell_by_region_id(region_id)
		if biome_manager != null
		else null
	)
	if cell != null and cell.generated_layout != null:
		return cell.generated_layout.logical_tile_scale
	return IsoGridConfig.LOGICAL_TILE_SCALE

func _connection_contains_world_tile(
	source: WorldRegion,
	connection: WorldRegionConnection,
	world_tile: Vector2i
) -> bool:
	for rect in [
		connection.world_rect,
		connection.world_connector_rect,
		connection.target_world_rect,
		connection.target_world_connector_rect
	]:
		if _expanded_rect_has_point(rect, world_tile, crossing_margin_tiles):
			return true
	return _fallback_connection_band_contains(source, connection, world_tile)

func _expanded_rect_has_point(
	rect: Rect2i,
	world_tile: Vector2i,
	margin: int
) -> bool:
	if rect.size.x <= 0 or rect.size.y <= 0:
		return false
	var expanded := Rect2i(
		rect.position - Vector2i(margin, margin),
		rect.size + Vector2i(margin * 2, margin * 2)
	)
	return expanded.has_point(world_tile)

func _fallback_connection_band_contains(
	source: WorldRegion,
	connection: WorldRegionConnection,
	world_tile: Vector2i
) -> bool:
	var half_width := maxi(connection.passage_width / 2, 1) + crossing_margin_tiles
	var center := source.world_origin + Vector2i(
		connection.passage_position,
		connection.passage_position
	)
	match connection.side:
		&"east":
			return (
				abs(world_tile.x - (source.world_origin.x + source.size_tiles.x)) <= crossing_margin_tiles
				and abs(world_tile.y - center.y) <= half_width
			)
		&"west":
			return (
				abs(world_tile.x - source.world_origin.x) <= crossing_margin_tiles
				and abs(world_tile.y - center.y) <= half_width
			)
		&"north":
			return (
				abs(world_tile.y - source.world_origin.y) <= crossing_margin_tiles
				and abs(world_tile.x - center.x) <= half_width
			)
		&"south":
			return (
				abs(world_tile.y - (source.world_origin.y + source.size_tiles.y)) <= crossing_margin_tiles
				and abs(world_tile.x - center.x) <= half_width
			)
		_:
			return false

func _connection_seam_tile(connection: WorldRegionConnection) -> Vector2i:
	var rect := (
		connection.target_world_connector_rect
		if connection.target_world_connector_rect.size.x > 0
		and connection.target_world_connector_rect.size.y > 0
		else connection.target_world_rect
	)
	if rect.size.x > 0 and rect.size.y > 0:
		# The crossing position must sit on the seam (the target cell adjacent to
		# the source boundary), centred on the passage span -- not the centre of
		# the connector corridor, which can be many tiles deep inside the target.
		var center_x := rect.position.x + maxi(rect.size.x / 2, 0)
		var center_y := rect.position.y + maxi(rect.size.y / 2, 0)
		match connection.side:
			&"east":
				return Vector2i(rect.position.x, center_y)
			&"west":
				return Vector2i(rect.position.x + rect.size.x - 1, center_y)
			&"north":
				return Vector2i(center_x, rect.position.y + rect.size.y - 1)
			&"south":
				return Vector2i(center_x, rect.position.y)
			_:
				return Vector2i(center_x, center_y)
	return Vector2i(
		connection.passage_position,
		connection.passage_position
	)
