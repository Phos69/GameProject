extends Node
class_name MultiRegionRenderer

## Milestone 8 - Megamappa persistente (renderer multi-regione, primo prototipo).
##
## Instantiates the current region plus its connected neighbors at world-space
## offsets derived from WorldRegion.world_origin, so adjacent territories are
## rendered simultaneously around the playable arena. Only the current region
## owns gameplay content (obstacles, hazard, crates, spawns) through the
## existing zombie systems; neighbors are visual ground only, and regions
## beyond the neighbor radius are left as pure save data (never instantiated).
## This keeps the contract "current + neighbors instantiated without duplicating
## crates/hazard and without spawning enemies in distant regions".

enum ContentLevel { NONE = 0, VISUAL = 1, FULL = 2 }

const REGION_GROUND_SCRIPT = preload(
	"res://game/modes/zombie/biome_region_ground.gd"
)

@export_range(0, 3, 1) var neighbor_radius: int = 1

var current_region_id: StringName = &""
# String(region_id) -> { "offset": Vector2, "level": int, "node": Node2D|null }
var _entries: Dictionary = {}

func _ready() -> void:
	add_to_group("multi_region_renderer")

func render_world(
	graph: WorldGraph,
	center_region_id: StringName,
	container: Node,
	layout_provider: Callable,
	palette_provider: Callable,
	sample_step: int = 8
) -> bool:
	clear()
	if graph == null or container == null:
		return false
	var center := graph.get_region(center_region_id)
	if center == null:
		return false
	current_region_id = center_region_id
	var tile_scale := _resolve_tile_scale(layout_provider, center_region_id)
	for region_id in _collect_active_region_ids(graph, center_region_id):
		var region := graph.get_region(region_id)
		if region == null:
			continue
		var offset := Vector2(region.world_origin - center.world_origin) * tile_scale
		if region_id == center_region_id:
			# The current region's content is owned by the live zombie systems;
			# the renderer records it as FULL without drawing a second ground.
			_entries[String(region_id)] = {
				"offset": offset,
				"level": ContentLevel.FULL,
				"node": null
			}
			continue
		var layout := layout_provider.call(region_id) as BiomeEnvironmentLayout
		var palette := palette_provider.call(region.biome_id) as BiomePalette
		if layout == null or palette == null:
			continue
		var ground := REGION_GROUND_SCRIPT.new() as BiomeRegionGround
		ground.name = "NeighborGround_%s" % String(region_id)
		container.add_child(ground)
		ground.position = offset
		ground.configure(layout, palette, sample_step)
		_entries[String(region_id)] = {
			"offset": offset,
			"level": ContentLevel.VISUAL,
			"node": ground
		}
	return true

func clear() -> void:
	for key in _entries.keys():
		var node = (_entries[key] as Dictionary).get("node")
		if node != null and is_instance_valid(node):
			node.queue_free()
	_entries.clear()
	current_region_id = &""

func get_rendered_region_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for key in _entries.keys():
		ids.append(StringName(key))
	ids.sort()
	return ids

func is_region_rendered(region_id: StringName) -> bool:
	return _entries.has(String(region_id))

func get_region_offset(region_id: StringName) -> Vector2:
	return (_entries.get(String(region_id), {}) as Dictionary).get("offset", Vector2.ZERO)

func get_content_level(region_id: StringName) -> int:
	return int((_entries.get(String(region_id), {}) as Dictionary).get("level", ContentLevel.NONE))

func get_neighbor_ground_nodes() -> Array[Node]:
	var nodes: Array[Node] = []
	for key in _entries.keys():
		var node = (_entries[key] as Dictionary).get("node")
		if node != null:
			nodes.append(node)
	return nodes

func _collect_active_region_ids(
	graph: WorldGraph,
	center_region_id: StringName
) -> Array[StringName]:
	var result: Array[StringName] = [center_region_id]
	var depth := {center_region_id: 0}
	var frontier: Array[StringName] = [center_region_id]
	while not frontier.is_empty():
		var current: StringName = frontier.pop_front()
		var current_depth := int(depth[current])
		if current_depth >= neighbor_radius:
			continue
		for neighbor_id in graph.get_connected_region_ids(current):
			if depth.has(neighbor_id):
				continue
			depth[neighbor_id] = current_depth + 1
			if not result.has(neighbor_id):
				result.append(neighbor_id)
			frontier.append(neighbor_id)
	return result

func _resolve_tile_scale(
	layout_provider: Callable,
	center_region_id: StringName
) -> float:
	var layout := layout_provider.call(center_region_id) as BiomeEnvironmentLayout
	return layout.logical_tile_scale if layout != null else 8.0
