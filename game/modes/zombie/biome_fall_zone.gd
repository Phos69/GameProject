extends Area2D
class_name BiomeFallZone

const CLIFF_RENDERER_SCRIPT = preload(
	"res://game/modes/zombie/isometric_cliff_renderer.gd"
)
const VALID_FALL_SIDES: Array[StringName] = [&"north", &"south", &"east", &"west"]

var hazard_id: StringName = &"fall_zone"
var fall_style: StringName = &"cliff"
var fall_side: StringName = &"north"
var visual_seed: int = 0
var zone_size: Vector2 = Vector2(150.0, 72.0)
var edge_color: Color = Color(0.82, 0.58, 0.16, 0.92)
var depth_color: Color = Color(0.025, 0.028, 0.022, 1.0)
var show_debug_visual: bool = false
var cliff_renderer: Node2D

func configure(
	next_hazard_id: StringName,
	next_size: Vector2,
	rotation_radians: float,
	warning_color: Color,
	next_fall_style: StringName = &"cliff",
	next_fall_side: StringName = &"",
	next_visual_seed: int = 0
) -> void:
	hazard_id = next_hazard_id
	fall_style = next_fall_style
	zone_size = Vector2(
		maxf(next_size.x, 32.0),
		maxf(next_size.y, 24.0)
	)
	fall_side = _normalize_fall_side(next_fall_side)
	visual_seed = next_visual_seed
	rotation = rotation_radians
	edge_color = warning_color
	collision_layer = 0
	collision_mask = GameConstants.LAYER_BODIES
	monitoring = true
	monitorable = false
	z_index = -1
	set_meta("zone_radius", maxf(zone_size.x, zone_size.y) * 0.5)
	_rebuild_collision()
	_ensure_cliff_renderer()
	_configure_cliff_renderer()
	queue_redraw()

func _ready() -> void:
	add_to_group("fall_zones")
	add_to_group("environment_hazards")
	if get_node_or_null("CollisionShape2D") == null:
		_rebuild_collision()
	_ensure_cliff_renderer()
	_configure_cliff_renderer()

func contains_global_position(world_position: Vector2) -> bool:
	var local_position := to_local(world_position)
	var half_size := zone_size * 0.5
	return (
		absf(local_position.x) <= half_size.x
		and absf(local_position.y) <= half_size.y
	)

func distance_to_zone(world_position: Vector2) -> float:
	var local_position := to_local(world_position)
	var half_size := zone_size * 0.5
	var outside := Vector2(
		maxf(absf(local_position.x) - half_size.x, 0.0),
		maxf(absf(local_position.y) - half_size.y, 0.0)
	)
	return outside.length()

func get_fall_style() -> StringName:
	return fall_style

func get_fall_side() -> StringName:
	return fall_side

func get_visual_seed() -> int:
	return visual_seed

func has_asset_renderer() -> bool:
	return (
		cliff_renderer != null
		and is_instance_valid(cliff_renderer)
		and cliff_renderer.has_method("has_assets")
		and bool(cliff_renderer.call("has_assets"))
	)

func uses_procedural_fallback() -> bool:
	if cliff_renderer == null or not is_instance_valid(cliff_renderer):
		return true
	if not cliff_renderer.has_method("uses_procedural_fallback"):
		return true
	return bool(cliff_renderer.call("uses_procedural_fallback"))

func get_void_asset_ids() -> Array[StringName]:
	if (
		cliff_renderer != null
		and is_instance_valid(cliff_renderer)
		and cliff_renderer.has_method("get_asset_ids")
	):
		return cliff_renderer.call("get_asset_ids") as Array[StringName]
	return [
		&"fall_zone",
		&"void_edge_near",
		&"void_depth",
		&"void_vertical_lines",
		get_cliff_lip_asset_id()
	]

func get_loaded_void_asset_ids() -> Array[StringName]:
	if (
		cliff_renderer != null
		and is_instance_valid(cliff_renderer)
		and cliff_renderer.has_method("get_loaded_asset_ids")
	):
		return cliff_renderer.call("get_loaded_asset_ids") as Array[StringName]
	return []

func get_void_asset_paths() -> Dictionary:
	if (
		cliff_renderer != null
		and is_instance_valid(cliff_renderer)
		and cliff_renderer.has_method("get_asset_paths")
	):
		return cliff_renderer.call("get_asset_paths") as Dictionary
	return {}

func get_cliff_lip_asset_id() -> StringName:
	if (
		cliff_renderer != null
		and is_instance_valid(cliff_renderer)
		and cliff_renderer.has_method("get_cliff_lip_id")
	):
		return StringName(str(cliff_renderer.call("get_cliff_lip_id")))
	return StringName("cliff_lip_%s" % String(fall_side))

func get_vertical_line_count() -> int:
	if (
		cliff_renderer != null
		and is_instance_valid(cliff_renderer)
		and cliff_renderer.has_method("get_vertical_line_count")
	):
		return int(cliff_renderer.call("get_vertical_line_count"))
	return 0

func set_debug_visual_visible(enabled: bool) -> void:
	show_debug_visual = enabled
	if (
		cliff_renderer != null
		and is_instance_valid(cliff_renderer)
		and cliff_renderer.has_method("set_debug_visual_visible")
	):
		cliff_renderer.call("set_debug_visual_visible", enabled)
	queue_redraw()

func _rebuild_collision() -> void:
	var collision_shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null:
		collision_shape = CollisionShape2D.new()
		collision_shape.name = "CollisionShape2D"
		add_child(collision_shape)
	var rectangle := RectangleShape2D.new()
	rectangle.size = zone_size
	collision_shape.shape = rectangle

func _draw() -> void:
	# No void "image": the void colour is painted by the tile layer (void cells)
	# and the off-map backdrop. The fall zone only draws the world-end boundary so
	# the edge of the map reads clearly, like a wall/ledge where the world stops.
	# In the asset-driven runtime the neighbor-aware tile layer owns that edge;
	# drawing this rectangle too would recreate borders where two void sides meet.
	if is_world_edge_visual_suppressed():
		return
	_draw_world_edges()

func is_world_edge_visual_suppressed() -> bool:
	return (
		is_inside_tree()
		and not get_tree().get_nodes_in_group("biome_tile_layers").is_empty()
	)

func _draw_world_edges() -> void:
	var half := zone_size * 0.5
	if _is_edge_strip():
		# Perimeter strip: floor only on the inner side; mark that single edge.
		var inner := _inner_edge(half)
		_draw_world_edge(inner[0], inner[1], inner[2])
	else:
		# Internal pit: floor surrounds it; outline the whole drop.
		_draw_world_edge(Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2.DOWN)
		_draw_world_edge(Vector2(-half.x, half.y), Vector2(half.x, half.y), Vector2.UP)
		_draw_world_edge(Vector2(-half.x, -half.y), Vector2(-half.x, half.y), Vector2.RIGHT)
		_draw_world_edge(Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2.LEFT)

func _draw_world_edge(p1: Vector2, p2: Vector2, into_void: Vector2) -> void:
	# A clear ledge: a bright lit crest exactly at the floor/void boundary with a
	# dark shadow stepped into the void, so the edge of the world reads as a wall.
	var crest := Color(_edge_color_for_style().lightened(0.18), 0.95)
	var shadow := Color(0.0, 0.0, 0.0, 0.7)
	var lift := 8.0
	draw_line(p1 + into_void * lift, p2 + into_void * lift, shadow, 2.0, true)
	draw_line(p1 + into_void * (lift * 0.5), p2 + into_void * (lift * 0.5), Color(0.0, 0.0, 0.0, 0.35), 2.0, true)
	draw_line(p1, p2, crest, 3.5, true)

func _is_edge_strip() -> bool:
	# Thin, elongated zones are perimeter strips along a single map border; blocky
	# zones are internal pits ringed by floor on every side.
	var longest := maxf(zone_size.x, zone_size.y)
	var shortest := maxf(minf(zone_size.x, zone_size.y), 1.0)
	return longest / shortest > 4.0

func _inner_edge(half: Vector2) -> Array:
	# Returns [p1, p2, into_void] for the floor-facing boundary of a perimeter
	# strip, oriented by which map border the strip sits on.
	match fall_side:
		&"south":
			return [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2.DOWN]
		&"west":
			return [Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2.LEFT]
		&"east":
			return [Vector2(-half.x, -half.y), Vector2(-half.x, half.y), Vector2.RIGHT]
		_:
			# north (and fallback): floor is below the strip, void extends upward.
			return [Vector2(-half.x, half.y), Vector2(half.x, half.y), Vector2.UP]

func _ensure_cliff_renderer() -> void:
	if cliff_renderer != null and is_instance_valid(cliff_renderer):
		return
	cliff_renderer = get_node_or_null("IsometricCliffRenderer") as Node2D
	if cliff_renderer == null:
		cliff_renderer = CLIFF_RENDERER_SCRIPT.new() as Node2D
		cliff_renderer.name = "IsometricCliffRenderer"
		add_child(cliff_renderer)
		cliff_renderer.owner = owner

func _configure_cliff_renderer() -> void:
	if cliff_renderer == null or not is_instance_valid(cliff_renderer):
		return
	if not cliff_renderer.has_method("configure"):
		return
	cliff_renderer.call(
		"configure",
		zone_size,
		fall_side,
		fall_style,
		edge_color,
		depth_color,
		visual_seed,
		show_debug_visual,
		true
	)

func _normalize_fall_side(value: StringName) -> StringName:
	if VALID_FALL_SIDES.has(value):
		return value
	if zone_size.x >= zone_size.y:
		return &"north"
	return &"west"

func _edge_color_for_style() -> Color:
	match fall_style:
		&"toxic_cliff":
			return Color(edge_color.lightened(0.10), 0.92)
		&"lava_cliff":
			return Color(0.98, 0.30, 0.10, 0.92)
		&"ice_cliff":
			return Color(0.54, 0.82, 0.96, 0.92)
		&"marsh_cliff":
			return Color(0.22, 0.56, 0.50, 0.92)
		_:
			return edge_color
