extends Node
class_name ObstacleSystem

signal obstacle_rules_configured(biome_id: StringName)
signal obstacle_spawned(obstacle: Node2D, obstacle_id: StringName)
signal obstacle_debug_overlay_changed(visible: bool)

const BIOME_OBSTACLE_SCRIPT = preload(
	"res://game/modes/zombie/biome_obstacle.gd"
)
const ENVIRONMENT_OBJECT_FACTORY_SCRIPT = preload(
	"res://game/modes/zombie/environment_object_factory.gd"
)
const SORT_ANCHOR_META: StringName = &"environment_obstacle_sort_anchor"

@export var environment_container_path: NodePath = NodePath(
	"../../../../World/EnvironmentProps"
)

## Lato di un bucket dell'indice spaziale dei blocker. Piu' grande del footprint
## tipico (48-150px) cosi' un ostacolo copre pochi bucket e la query resta un
## singolo lookup del bucket del punto.
const BLOCKER_BUCKET_SIZE: float = 192.0

var active_biome: BiomeDefinition
var is_active: bool = false
var active_obstacles: Array[Node2D] = []
var manifest: EnvironmentAssetManifest
var object_factory: RefCounted
var debug_footprints_visible: bool = false

# Indice spaziale dei nodi nei gruppi spawn_blockers/environment_obstacles:
# bucket Vector2i -> Array di blocker la cui AABB conservativa copre il bucket.
# Le query erano group scan O(N) (~0.7ms con 387 ostacoli streamed) moltiplicate
# per centinaia di celle da LOS/A* del pathfinder: vedi la suite
# tests/suites/soak/perf_bottleneck_stress_test.gd.
# Si ricostruisce pigramente alla prima query quando gli hook di registrazione
# lo marcano dirty oppure quando cambia il conteggio dei gruppi (nodi aggiunti
# ai gruppi senza passare da ObstacleSystem, es. fixture nei test). Assunzione:
# i blocker sono statici; chi muove un blocker gia' indicizzato deve chiamare
# invalidate_blocker_index().
var _blocker_buckets: Dictionary = {}
var _blocker_index_dirty: bool = true
var _indexed_blocker_group_count: int = -1

func _ready() -> void:
	add_to_group("obstacle_system")
	manifest = EnvironmentAssetManifest.get_shared()
	object_factory = ENVIRONMENT_OBJECT_FACTORY_SCRIPT.new(manifest)
	set_process_unhandled_key_input(true)

func _exit_tree() -> void:
	_clear_runtime()
	active_biome = null
	manifest = null
	object_factory = null

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F9:
		set_debug_footprints_visible(not debug_footprints_visible)
		get_viewport().set_input_as_handled()

func start_run(biome: BiomeDefinition) -> void:
	_clear_runtime()
	active_biome = biome
	is_active = true
	_generate_obstacles()
	obstacle_rules_configured.emit(
		active_biome.biome_id if active_biome != null else &""
	)

func begin_streaming_run(biome: BiomeDefinition) -> void:
	_clear_runtime()
	active_biome = biome
	is_active = true
	obstacle_rules_configured.emit(
		active_biome.biome_id if active_biome != null else &""
	)

func set_active_biome(biome: BiomeDefinition) -> void:
	active_biome = biome
	is_active = biome != null
	if active_biome != null:
		obstacle_rules_configured.emit(active_biome.biome_id)

func stop_run() -> void:
	_clear_runtime()
	is_active = false
	active_biome = null

func get_active_obstacles() -> Array[Node2D]:
	_prune_runtime()
	return active_obstacles.duplicate()

func set_debug_footprints_visible(visible: bool) -> void:
	debug_footprints_visible = visible
	for obstacle in get_active_obstacles():
		_apply_debug_visibility(obstacle)
	for hazard_system in get_tree().get_nodes_in_group("hazard_system"):
		if hazard_system.has_method("set_debug_fall_zones_visible"):
			hazard_system.call(
				"set_debug_fall_zones_visible",
				debug_footprints_visible
			)
	obstacle_debug_overlay_changed.emit(debug_footprints_visible)

func are_debug_footprints_visible() -> bool:
	return debug_footprints_visible

func is_position_blocked(position: Vector2) -> bool:
	return _is_position_blocked(position, false)

# Solid-only query: jumpable obstacles (gap anchors) are skipped so a dodge can
# cross over them while spawn/landing checks keep treating them as occupied.
func is_position_blocked_by_non_jumpable(position: Vector2) -> bool:
	return _is_position_blocked(position, true)

func is_position_jumpable_obstacle(position: Vector2) -> bool:
	_ensure_blocker_index()
	var candidates = _blocker_buckets.get(_bucket_for(position))
	if candidates == null:
		return false
	for blocker in candidates:
		if blocker == null or not is_instance_valid(blocker):
			continue
		if (
			_is_jumpable(blocker)
			and blocker.is_in_group("environment_obstacles")
			and node_contains_position(blocker, position)
		):
			return true
	return false

## Da chiamare se un blocker gia' indicizzato viene spostato o cambia footprint:
## l'indice si ricostruisce alla query successiva.
func invalidate_blocker_index() -> void:
	_blocker_index_dirty = true

func create_obstacle_instance(
	obstacle_id: StringName,
	size: Vector2,
	shape_id: StringName,
	rotation_radians: float,
	base_color: Color,
	detail_color: Color
) -> BiomeObstacle:
	return _create_obstacle(
		obstacle_id,
		size,
		shape_id,
		rotation_radians,
		base_color,
		detail_color
	)

func register_streamed_obstacle(
	obstacle: Node2D,
	obstacle_id: StringName
) -> void:
	if obstacle == null:
		return
	if not active_obstacles.has(obstacle):
		active_obstacles.append(obstacle)
	_blocker_index_dirty = true
	_apply_debug_visibility(obstacle)
	obstacle_spawned.emit(obstacle, obstacle_id)

func unregister_streamed_obstacle(obstacle: Node2D) -> void:
	if obstacle == null:
		return
	active_obstacles.erase(obstacle)
	_blocker_index_dirty = true

func _is_position_blocked(position: Vector2, skip_jumpable: bool) -> bool:
	_ensure_blocker_index()
	var candidates = _blocker_buckets.get(_bucket_for(position))
	if candidates == null:
		return false
	for blocker in candidates:
		if blocker == null or not is_instance_valid(blocker):
			continue
		if skip_jumpable and _is_jumpable(blocker):
			continue
		if node_contains_position(blocker, position):
			return true
	return false

func _ensure_blocker_index() -> void:
	var group_count := _blocker_group_count()
	if not _blocker_index_dirty and group_count == _indexed_blocker_group_count:
		return
	_rebuild_blocker_index(group_count)

func _blocker_group_count() -> int:
	var tree := get_tree()
	if tree == null:
		return 0
	return (
		tree.get_node_count_in_group("spawn_blockers")
		+ tree.get_node_count_in_group("environment_obstacles")
	)

func _rebuild_blocker_index(group_count: int) -> void:
	_blocker_buckets.clear()
	var tree := get_tree()
	if tree != null:
		var seen := {}
		for group in ["spawn_blockers", "environment_obstacles"]:
			for blocker in tree.get_nodes_in_group(group):
				if not blocker is Node2D:
					continue
				var blocker_id := blocker.get_instance_id()
				if seen.has(blocker_id):
					continue
				seen[blocker_id] = true
				_insert_blocker(blocker as Node2D)
	_indexed_blocker_group_count = group_count
	_blocker_index_dirty = false

func _insert_blocker(blocker: Node2D) -> void:
	var extents := _blocker_cover_extents(blocker)
	var position := blocker.global_position
	var min_bucket := _bucket_for(position - extents)
	var max_bucket := _bucket_for(position + extents)
	for bucket_y in range(min_bucket.y, max_bucket.y + 1):
		for bucket_x in range(min_bucket.x, max_bucket.x + 1):
			var key := Vector2i(bucket_x, bucket_y)
			if not _blocker_buckets.has(key):
				_blocker_buckets[key] = []
			(_blocker_buckets[key] as Array).append(blocker)

## AABB world-space conservativa del test di contenimento reale
## (node_contains_position): rettangolo ruotato per gli ostacoli/zone, cerchio
## per shape circolari e per il fallback zone_radius dei nodi generici.
static func _blocker_cover_extents(blocker: Node2D) -> Vector2:
	var size_value: Variant = (
		blocker.call("get_collision_size")
		if blocker.has_method("get_collision_size")
		else blocker.get("obstacle_size")
	)
	if not size_value is Vector2:
		size_value = blocker.get("zone_size")
	if size_value is Vector2:
		var half := (size_value as Vector2) * 0.5
		var center_offset := Vector2.ZERO
		if blocker.has_method("get_collision_offset"):
			center_offset = blocker.call("get_collision_offset") as Vector2
		if blocker.get("collision_shape_id") == &"circle":
			var radius := minf(half.x, half.y)
			return center_offset.abs() + Vector2(
				maxf(radius, 8.0),
				maxf(radius, 8.0)
			)
		var cos_r := absf(cos(blocker.global_rotation))
		var sin_r := absf(sin(blocker.global_rotation))
		var rotated_half := Vector2(
			maxf(cos_r * half.x + sin_r * half.y, 8.0),
			maxf(sin_r * half.x + cos_r * half.y, 8.0)
		)
		var rotated_offset := Vector2(
			cos_r * absf(center_offset.x) + sin_r * absf(center_offset.y),
			sin_r * absf(center_offset.x) + cos_r * absf(center_offset.y)
		)
		return rotated_half + rotated_offset
	var radius := maxf(float(blocker.get_meta("zone_radius", 32.0)), 8.0)
	return Vector2(radius, radius)

func _bucket_for(position: Vector2) -> Vector2i:
	return Vector2i(
		floori(position.x / BLOCKER_BUCKET_SIZE),
		floori(position.y / BLOCKER_BUCKET_SIZE)
	)

func _is_jumpable(node: Node) -> bool:
	return (
		node != null
		and is_instance_valid(node)
		and node.has_method("is_jumpable_obstacle")
		and bool(node.is_jumpable_obstacle())
	)

# Test di appartenenza condiviso da ostacoli e hazard (HazardSystem delega qui):
# footprint esplicita via contains_global_position, altrimenti raggio zone_radius.
static func node_contains_position(node: Node, position: Vector2) -> bool:
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
		var obstacle := _create_obstacle(
			obstacle_id,
			size,
			shape_id,
			rotation_radians,
			palette.prop_color,
			palette.hazard_color
		)
		if obstacle == null:
			continue
		obstacle.name = "%s%d" % [
			BiomeHazardCatalog.pascal_case(String(obstacle_id)),
			index + 1
		]
		obstacle.obstacle_key = make_obstacle_key(
			active_biome.biome_id,
			index,
			obstacle_id
		)
		attach_obstacle_at_layout_center(
			container,
			obstacle,
			layout.obstacle_positions[index]
		)
		if index < layout.obstacle_rects.size():
			obstacle.set_meta(
				"obstacle_record",
				layout.get_obstacle_record(
					index,
					manifest,
					active_biome.biome_id if active_biome != null else &""
				)
			)
		if manifest != null and not manifest.blocks_movement(obstacle_id):
			obstacle.remove_from_group("spawn_blockers")
			obstacle.remove_from_group("environment_obstacles")
		configure_perimeter_obstacle_visual(
			obstacle,
			layout,
			index,
			active_biome.biome_id
		)
		configure_mesa_obstacle_visual(
			obstacle,
			layout,
			index,
			active_biome.biome_id,
			palette
		)
		active_obstacles.append(obstacle)
		_apply_debug_visibility(obstacle)
		obstacle_spawned.emit(obstacle, obstacle_id)
	_blocker_index_dirty = true

func _get_environment_container() -> Node:
	var container := get_node_or_null(environment_container_path)
	return container if container != null else get_tree().current_scene

func _create_obstacle(
	obstacle_id: StringName,
	size: Vector2,
	shape_id: StringName,
	rotation_radians: float,
	base_color: Color,
	detail_color: Color
) -> BiomeObstacle:
	if object_factory == null:
		object_factory = ENVIRONMENT_OBJECT_FACTORY_SCRIPT.new(manifest)
	var obstacle := object_factory.call(
		"create_obstacle",
		obstacle_id,
		size,
		shape_id,
		rotation_radians,
		base_color,
		detail_color,
		_sort_offset_for(obstacle_id),
		active_biome.biome_id if active_biome != null else &""
	) as BiomeObstacle
	if obstacle != null:
		return obstacle
	obstacle = BIOME_OBSTACLE_SCRIPT.new() as BiomeObstacle
	if obstacle == null:
		return null
	obstacle.configure(
		obstacle_id,
		size,
		shape_id,
		rotation_radians,
		base_color,
		detail_color,
		_sort_offset_for(obstacle_id)
	)
	return obstacle

func _clear_runtime() -> void:
	for obstacle in active_obstacles:
		if is_instance_valid(obstacle):
			var sort_anchor := obstacle.get_parent()
			if sort_anchor != null and sort_anchor.has_meta(SORT_ANCHOR_META):
				sort_anchor.queue_free()
			else:
				obstacle.queue_free()
	active_obstacles.clear()
	_blocker_buckets.clear()
	_blocker_index_dirty = true

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

static func configure_perimeter_obstacle_visual(
	obstacle: BiomeObstacle,
	layout: BiomeEnvironmentLayout,
	index: int,
	biome_id: StringName = &""
) -> void:
	if (
		obstacle == null
		or layout == null
		or not obstacle.is_perimeter_wall()
		or index < 0
		or index >= layout.obstacle_rects.size()
	):
		return
	var rect := layout.obstacle_rects[index]
	var side := layout.get_wall_segment_side(rect)
	if side.is_empty():
		return
	obstacle.configure_perimeter_visual(
		layout.perimeter_visual_style,
		side,
		Vector2(rect.position) * layout.logical_tile_scale,
		layout.wall_height_cells,
		layout.logical_tile_scale,
		biome_id
	)

static func attach_obstacle_at_layout_center(
	parent: Node,
	obstacle: BiomeObstacle,
	layout_center: Vector2
) -> Node2D:
	if parent == null or obstacle == null:
		return null
	var sort_anchor := Node2D.new()
	sort_anchor.name = "%sSortAnchor" % obstacle.name
	sort_anchor.set_meta(SORT_ANCHOR_META, true)
	var anchor_offset := obstacle.get_sort_anchor_offset()
	sort_anchor.set_meta("sort_anchor_offset", anchor_offset)
	sort_anchor.position = layout_center + anchor_offset
	parent.add_child(sort_anchor)
	sort_anchor.add_child(obstacle)
	obstacle.position = -anchor_offset
	obstacle.set_meta("layout_center", layout_center)
	obstacle.set_meta("sort_anchor_offset", anchor_offset)
	return sort_anchor

static func configure_mesa_obstacle_visual(
	obstacle: BiomeObstacle,
	layout: BiomeEnvironmentLayout,
	index: int,
	biome_id: StringName,
	palette: BiomePalette
) -> void:
	if (
		obstacle == null
		or layout == null
		or obstacle.obstacle_id != &"large_rock"
		or not obstacle.has_method("configure_mesa_visual")
		or index < 0
		or index >= layout.obstacle_rects.size()
	):
		return
	var mesa_rect := layout.obstacle_rects[index]
	var mesa_index := layout.mesa_rects.find(mesa_rect)
	var profile_id: StringName = &"forest"
	if mesa_index >= 0 and mesa_index < layout.mesa_profile_ids.size():
		profile_id = layout.mesa_profile_ids[mesa_index]
	elif biome_id != &"infected_plains":
		profile_id = BiomeGeneratedArtCatalog.get_theme_id_for_biome(biome_id)
	obstacle.call(
		"configure_mesa_visual",
		profile_id,
		biome_id,
		layout.generation_seed,
		palette,
		layout.logical_tile_scale,
		layout.obstacle_positions[index]
	)

func _sort_offset_for(obstacle_id: StringName) -> float:
	if manifest == null:
		return 0.0
	return manifest.get_sort_offset(obstacle_id)

func _apply_debug_visibility(obstacle: Node) -> void:
	if obstacle != null and obstacle.has_method("set_debug_footprint_visible"):
		obstacle.call("set_debug_footprint_visible", debug_footprints_visible)
