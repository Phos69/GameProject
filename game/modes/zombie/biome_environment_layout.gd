extends Resource
class_name BiomeEnvironmentLayout

const DEFAULT_ZONE_SIZE := Vector2i(500, 500)
const PERIMETER_VISUAL_WALL: StringName = &"procedural_wall"
const PERIMETER_VISUAL_RAISED_CLIFF: StringName = &"raised_cliff"
const RAISED_CLIFF_HEIGHT_CELLS := 7

@export var zone_size: Vector2i = DEFAULT_ZONE_SIZE
@export var generation_seed: int = 0
@export var logical_tile_scale: float = 8.0

@export var terrain_patch_tags: Array[StringName] = []
@export var terrain_patch_positions: Array[Vector2] = []
@export var terrain_patch_radii: Array[float] = []

@export var obstacle_ids: Array[StringName] = []
@export var obstacle_positions: Array[Vector2] = []
@export var obstacle_sizes: Array[Vector2] = []
@export var obstacle_rotations: Array[float] = []
@export var obstacle_shape_ids: Array[StringName] = []

@export var crate_ids: Array[StringName] = []
@export var crate_positions: Array[Vector2] = []

@export var hazard_ids: Array[StringName] = []
@export var hazard_positions: Array[Vector2] = []
@export var hazard_sizes: Array[Vector2] = []
@export var hazard_rotations: Array[float] = []
@export var hazard_sides: Array[StringName] = []

@export_range(80.0, 500.0, 10.0) var central_corridor_width: float = 220.0

# Explicit perimeter wall contract: the chunk is ringed by tall, isometric
# vertical walls. Walls are emitted as a contiguous run of tile-sized segments
# (see ObstacleLayoutGenerator) instead of a single stretched obstacle per side,
# so the whole perimeter reads as a continuous wall and not just a central tile.
const PERIMETER_WALL_HEIGHT_CELLS := 5
@export var wall_height_cells: int = PERIMETER_WALL_HEIGHT_CELLS
@export var perimeter_visual_style: StringName = PERIMETER_VISUAL_WALL

var road_rects: Array[Rect2i] = []
var road_rect_tags: Array[StringName] = []
var road_cell_tags: Dictionary = {}
var floor_rects: Array[Rect2i] = []
var floor_rect_tags: Array[StringName] = []
var block_rects: Array[Rect2i] = []
var block_kinds: Array[StringName] = []
var wall_segment_rects: Array[Rect2i] = []
var wall_segment_sides: Array[StringName] = []
var passage_rects: Array[Rect2i] = []
var passage_connector_rects: Array[Rect2i] = []
var bridge_rects: Array[Rect2i] = []
var obstacle_rects: Array[Rect2i] = []
# Void-first generation: square rock footprints (placed first) and square forest
# regions (placed second). Forests skip rock cells; roads route around rocks.
var rock_rects: Array[Rect2i] = []
var forest_rects: Array[Rect2i] = []
var water_rects: Array[Rect2i] = []
var fall_zone_rects: Array[Rect2i] = []
var hazard_rects: Array[Rect2i] = []
var crate_cells: Array[Vector2i] = []
var player_spawn_cell: Vector2i = DEFAULT_ZONE_SIZE / 2
var validation_report: Dictionary = {}
var generation_summary: Dictionary = {}
var terrain_classification_counts: Dictionary = {}
var terrain_classification_total: int = 0
var terrain_classification_complete: bool = false

const TERRAIN_WALKABLE: StringName = &"walkable"
const TERRAIN_OBSTACLE: StringName = &"obstacle"
const TERRAIN_HAZARD: StringName = &"hazard"
const TERRAIN_BORDER: StringName = &"border"
const TERRAIN_VOID: StringName = &"void"
const TERRAIN_FALL_ZONE: StringName = &"fall_zone"
const TERRAIN_CODE_VOID := 0
const TERRAIN_CODE_WALKABLE := 1
const TERRAIN_CODE_OBSTACLE := 2
const TERRAIN_CODE_HAZARD := 3
const TERRAIN_CODE_BORDER := 4
const TERRAIN_CODE_FALL_ZONE := 5

var _terrain_class_cache: PackedByteArray = PackedByteArray()
# Per-cell floor-rect index (rect_index + 1; 0 means no floor). Rebuilt alongside
# the terrain classification so get_floor_tag_at_cell() is O(1).
var _floor_tag_cache: PackedInt32Array = PackedInt32Array()
# Per-cell wall-segment membership (1 inside a wall segment). Rebuilt with the
# terrain classification so is_wall_segment_cell() is O(1).
var _wall_segment_cache: PackedByteArray = PackedByteArray()

# Copia profonda e indipendente del layout. Copia OGNI variabile di script (sia
# @export sia interna) iterando la property list, cosi resta corretta anche quando
# si aggiungono nuovi campi senza dover aggiornare il clone a mano. Serve alla
# WorldDataCache per restituire mondi riusabili senza che teardown/rebake di una
# run intacchino lo snapshot in cache.
func clone() -> BiomeEnvironmentLayout:
	var copy := BiomeEnvironmentLayout.new()
	for property in get_property_list():
		if int(property.get("usage", 0)) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		var property_name := String(property.get("name", ""))
		copy.set(property_name, _duplicate_value(get(property_name)))
	return copy

static func _duplicate_value(value: Variant) -> Variant:
	if value is Array or value is Dictionary:
		return value.duplicate(true)
	# Tutti i Packed*Array stanno in coda all'enum dei tipi: una sola soglia li
	# copre tutti (e i loro elementi sono value-type, quindi duplicate() basta).
	if typeof(value) >= TYPE_PACKED_BYTE_ARRAY:
		return value.duplicate()
	return value

# --- Serializzazione (WorldSnapshotCodec / cache su disco) ------------------
# Rappresentazione a Dictionary di SOLI value-type/array, salvabile con
# FileAccess.store_var(). Speculare a clone(): itera la property list cosi resta
# corretta aggiungendo nuovi campi. Su disco gli array tipizzati perdono il tipo
# (store_var/get_var ritorna Array non tipizzati); from_dict li ri-tipizza con
# Array.assign() sull'array (gia tipizzato e vuoto) della property di destinazione.
func to_dict() -> Dictionary:
	var data := {}
	for property in get_property_list():
		if int(property.get("usage", 0)) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		var property_name := String(property.get("name", ""))
		data[property_name] = _duplicate_value(get(property_name))
	return data

static func from_dict(data: Dictionary) -> BiomeEnvironmentLayout:
	var layout := BiomeEnvironmentLayout.new()
	for property in layout.get_property_list():
		if int(property.get("usage", 0)) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		var property_name := String(property.get("name", ""))
		if not data.has(property_name):
			continue
		var value: Variant = data[property_name]
		var target: Variant = layout.get(property_name)
		if target is Array and value is Array and (target as Array).is_typed():
			# L'array della property e gia tipizzato (vuoto): assign() converte e
			# valida gli elementi dell'array non tipizzato letto dal disco.
			(target as Array).assign(value as Array)
		else:
			layout.set(property_name, _duplicate_value(value))
	return layout

func has_generated_map_data() -> bool:
	return (
		generation_seed != 0
		and zone_size.x > 0
		and zone_size.y > 0
		and (
			not floor_rects.is_empty()
			or not road_rects.is_empty()
			or not road_cell_tags.is_empty()
		)
	)

func logical_to_world(cell: Vector2i) -> Vector2:
	return (
		Vector2(cell.x - zone_size.x / 2, cell.y - zone_size.y / 2)
		* logical_tile_scale
	)

func rect_center_to_world(rect: Rect2i) -> Vector2:
	return logical_to_world(rect.position + rect.size / 2)

func rect_size_to_world(rect: Rect2i) -> Vector2:
	return Vector2(rect.size) * logical_tile_scale

func get_obstacle_record(
	index: int,
	manifest: IsometricEnvironmentManifest = null
) -> Dictionary:
	if index < 0 or index >= obstacle_ids.size() or index >= obstacle_rects.size():
		return {}
	var source_manifest := manifest
	if source_manifest == null:
		source_manifest = IsometricEnvironmentManifest.get_shared()
	var obstacle_id := obstacle_ids[index]
	var occupied_cells := obstacle_rects[index]
	var asset_contract := source_manifest.get_object_asset_contract(obstacle_id)
	return {
		"type": obstacle_id,
		"category": source_manifest.get_category(obstacle_id),
		"footprint_slots": source_manifest.get_footprint_slots(obstacle_id),
		"footprint_tiles": occupied_cells.size,
		"occupied_cells": occupied_cells,
		"asset_path": String(asset_contract.get("asset_path", "")),
		"asset_variant": obstacle_id,
		"visual_height_tiles": source_manifest.get_visual_height_tiles(obstacle_id),
		"collision_shape": source_manifest.get_collision_shape(obstacle_id),
		"blocks_movement": source_manifest.blocks_movement(obstacle_id),
		"blocks_projectiles": source_manifest.blocks_projectiles(obstacle_id)
	}

func validate_obstacle_records(
	manifest: IsometricEnvironmentManifest = null
) -> PackedStringArray:
	var failures := PackedStringArray()
	var source_manifest := manifest
	if source_manifest == null:
		source_manifest = IsometricEnvironmentManifest.get_shared()
	var count := obstacle_rects.size()
	if (
		obstacle_ids.size() != count
		or obstacle_positions.size() != count
		or obstacle_sizes.size() != count
		or obstacle_rotations.size() != count
		or obstacle_shape_ids.size() != count
	):
		failures.append("obstacle arrays must have identical lengths")
		return failures
	for index in range(count):
		var obstacle_id := obstacle_ids[index]
		var rect := obstacle_rects[index]
		if not source_manifest.has_object(obstacle_id):
			failures.append("%s[%d]: missing manifest object" % [String(obstacle_id), index])
			continue
		if rect.size.x <= 0 or rect.size.y <= 0:
			failures.append("%s[%d]: occupied cell rect is empty" % [String(obstacle_id), index])
			continue
		if (
			source_manifest.get_category(obstacle_id) != &"border"
			and not source_manifest.is_scalable(obstacle_id)
			and rect.size != source_manifest.get_footprint_tiles(obstacle_id)
		):
			failures.append(
				"%s[%d]: logical rect %s differs from manifest footprint %s"
				% [
					String(obstacle_id),
					index,
					str(rect.size),
					str(source_manifest.get_footprint_tiles(obstacle_id))
				]
			)
		if not obstacle_positions[index].is_equal_approx(rect_center_to_world(rect)):
			failures.append("%s[%d]: world anchor differs from occupied cells" % [String(obstacle_id), index])
		if not obstacle_sizes[index].is_equal_approx(rect_size_to_world(rect)):
			failures.append("%s[%d]: collision size differs from occupied cells" % [String(obstacle_id), index])
		var asset_path := String(
			source_manifest.get_object_asset_contract(obstacle_id).get("asset_path", "")
		)
		if source_manifest.blocks_movement(obstacle_id) and asset_path.is_empty():
			failures.append("%s[%d]: blocking obstacle has no asset" % [String(obstacle_id), index])
	return failures

func world_to_logical(position: Vector2) -> Vector2i:
	return Vector2i(
		roundi(position.x / logical_tile_scale + float(zone_size.x) * 0.5),
		roundi(position.y / logical_tile_scale + float(zone_size.y) * 0.5)
	)

func is_world_position_inside_zone(position: Vector2) -> bool:
	var cell := world_to_logical(position)
	return (
		cell.x >= 0
		and cell.y >= 0
		and cell.x < zone_size.x
		and cell.y < zone_size.y
	)

func get_generation_signature() -> String:
	return "%d:%s:%d:%d:%d:%d:%d:%d:%d" % [
		generation_seed,
		str(zone_size),
		floor_rects.size(),
		block_rects.size(),
		road_rects.size(),
		road_cell_tags.size(),
		obstacle_rects.size(),
		fall_zone_rects.size(),
		hazard_rects.size()
	]

func add_road_cell(cell: Vector2i, terrain_tag: StringName) -> void:
	if (
		cell.x < 0
		or cell.y < 0
		or cell.x >= zone_size.x
		or cell.y >= zone_size.y
	):
		return
	var key := _cell_key(cell)
	var tags: Array[StringName] = get_road_tags_at_cell(cell)
	if not tags.has(terrain_tag):
		tags.append(terrain_tag)
	road_cell_tags[key] = tags

func add_floor_rect(rect: Rect2i, terrain_tag: StringName = &"floor_base") -> void:
	var clipped := _clip_rect(rect)
	if clipped.size.x <= 0 or clipped.size.y <= 0:
		return
	floor_rects.append(clipped)
	floor_rect_tags.append(terrain_tag)

func get_floor_tag_at_cell(cell: Vector2i) -> StringName:
	# Fast path: a per-cell index cache (built with the terrain classification) turns
	# this from an O(floor_rects) scan into an O(1) lookup. On a 500x500 chunk with
	# hundreds of floor rects this is the difference between a multi-second tile-layer
	# bake and an instant one, since the tile resolver calls it for every cell.
	if _floor_tag_cache.size() == zone_size.x * zone_size.y:
		if (
			cell.x < 0
			or cell.y < 0
			or cell.x >= zone_size.x
			or cell.y >= zone_size.y
		):
			return &""
		var encoded := _floor_tag_cache[_cell_key(cell)]
		if encoded == 0:
			return &""
		var cached_index := encoded - 1
		if cached_index < floor_rect_tags.size():
			return floor_rect_tags[cached_index]
		return &"floor_base"
	for index in range(floor_rects.size() - 1, -1, -1):
		if not floor_rects[index].has_point(cell):
			continue
		if index < floor_rect_tags.size():
			return floor_rect_tags[index]
		return &"floor_base"
	return &""

func add_block_rect(rect: Rect2i, block_kind: StringName) -> void:
	var clipped := _clip_rect(rect)
	if clipped.size.x <= 0 or clipped.size.y <= 0:
		return
	block_rects.append(clipped)
	block_kinds.append(block_kind)

func add_wall_segment(rect: Rect2i, side: StringName) -> void:
	var clipped := _clip_rect(rect)
	if clipped.size.x <= 0 or clipped.size.y <= 0:
		return
	wall_segment_rects.append(clipped)
	wall_segment_sides.append(side)

func add_bridge_rect(rect: Rect2i) -> void:
	var clipped := _clip_rect(rect)
	if clipped.size.x <= 0 or clipped.size.y <= 0:
		return
	bridge_rects.append(clipped)

func get_wall_segments_for_side(side: StringName) -> Array[Rect2i]:
	var result: Array[Rect2i] = []
	for index in range(wall_segment_rects.size()):
		if index < wall_segment_sides.size() and wall_segment_sides[index] == side:
			result.append(wall_segment_rects[index])
	return result

func get_wall_segment_side(rect: Rect2i) -> StringName:
	for index in range(wall_segment_rects.size()):
		if wall_segment_rects[index] != rect:
			continue
		if index < wall_segment_sides.size():
			return wall_segment_sides[index]
	return &""

func uses_raised_perimeter_cliffs() -> bool:
	return perimeter_visual_style == PERIMETER_VISUAL_RAISED_CLIFF

func add_fall_zone_rect(rect: Rect2i, side: StringName = &"") -> void:
	var clipped := _clip_rect(rect)
	if clipped.size.x <= 0 or clipped.size.y <= 0:
		return
	fall_zone_rects.append(clipped)
	hazard_rects.append(clipped)
	hazard_ids.append(&"fall_zone")
	hazard_positions.append(rect_center_to_world(clipped))
	hazard_sizes.append(rect_size_to_world(clipped))
	hazard_rotations.append(0.0)
	hazard_sides.append(side)

func add_hazard_rect(
	rect: Rect2i,
	hazard_id: StringName,
	rotation_radians: float = 0.0,
	side: StringName = &""
) -> void:
	var clipped := _clip_rect(rect)
	if clipped.size.x <= 0 or clipped.size.y <= 0:
		return
	hazard_rects.append(clipped)
	hazard_ids.append(hazard_id)
	hazard_positions.append(rect_center_to_world(clipped))
	hazard_sizes.append(rect_size_to_world(clipped))
	hazard_rotations.append(rotation_radians)
	hazard_sides.append(side)
	if hazard_id == &"deep_water":
		water_rects.append(clipped)

func has_road_cell(cell: Vector2i) -> bool:
	return road_cell_tags.has(_cell_key(cell))

func is_bridge_cell(cell: Vector2i) -> bool:
	if _cell_inside_any_rect(cell, bridge_rects):
		return true
	for index in range(road_rects.size()):
		if index >= road_rect_tags.size():
			continue
		if road_rect_tags[index] == &"bridge" and road_rects[index].has_point(cell):
			return true
	var tags := get_road_tags_at_cell(cell)
	return tags.has(&"bridge")

func get_road_tags_at_cell(cell: Vector2i) -> Array[StringName]:
	var result: Array[StringName] = []
	var key := _cell_key(cell)
	if not road_cell_tags.has(key):
		return result
	var raw_tags: Array = road_cell_tags[key] as Array
	for tag in raw_tags:
		result.append(StringName(tag))
	return result

func get_road_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for key_value in road_cell_tags.keys():
		var key := int(key_value)
		cells.append(Vector2i(key % zone_size.x, floori(float(key) / float(zone_size.x))))
	return cells

func rebuild_terrain_classification(cell: BiomeCell = null) -> void:
	terrain_classification_counts = {
		TERRAIN_WALKABLE: 0,
		TERRAIN_OBSTACLE: 0,
		TERRAIN_HAZARD: 0,
		TERRAIN_BORDER: 0,
		TERRAIN_VOID: 0,
		TERRAIN_FALL_ZONE: 0
	}
	_rebuild_terrain_class_cache(cell)
	_rebuild_floor_tag_cache()
	_rebuild_wall_segment_cache()
	terrain_classification_total = _terrain_class_cache.size()
	for code in _terrain_class_cache:
		var terrain_class := _terrain_class_from_code(int(code))
		terrain_classification_counts[terrain_class] = (
			int(terrain_classification_counts.get(terrain_class, 0)) + 1
		)
	terrain_classification_complete = (
		terrain_classification_total == zone_size.x * zone_size.y
	)

func get_terrain_class_at_cell(
	cell: Vector2i,
	biome_cell: BiomeCell = null
) -> StringName:
	if (
		cell.x < 0
		or cell.y < 0
		or cell.x >= zone_size.x
		or cell.y >= zone_size.y
	):
		return TERRAIN_VOID
	if _terrain_class_cache.size() == zone_size.x * zone_size.y:
		return _terrain_class_from_code(_terrain_class_cache[_cell_key(cell)])
	if is_bridge_cell(cell):
		return TERRAIN_WALKABLE
	if _cell_inside_any_rect(cell, fall_zone_rects):
		return TERRAIN_FALL_ZONE
	if _cell_inside_any_rect(cell, obstacle_rects):
		return TERRAIN_OBSTACLE
	if _cell_inside_any_rect(cell, hazard_rects):
		return TERRAIN_HAZARD
	if _cell_inside_any_rect(cell, passage_rects):
		return TERRAIN_WALKABLE
	if _cell_inside_any_rect(cell, road_rects):
		return TERRAIN_WALKABLE
	if has_road_cell(cell):
		return TERRAIN_WALKABLE
	if _cell_inside_any_rect(cell, floor_rects):
		return TERRAIN_WALKABLE
	if _is_border_cell(cell, biome_cell):
		return TERRAIN_BORDER
	return TERRAIN_VOID

func get_classification_report() -> Dictionary:
	return {
		"is_complete": terrain_classification_complete,
		"total": terrain_classification_total,
		"expected_total": zone_size.x * zone_size.y,
		"counts": terrain_classification_counts.duplicate(true)
	}

func _is_border_cell(cell: Vector2i, biome_cell: BiomeCell = null) -> bool:
	if cell.y == 0:
		return _side_is_non_fall_border(&"north", biome_cell)
	if cell.y == zone_size.y - 1:
		return _side_is_non_fall_border(&"south", biome_cell)
	if cell.x == 0:
		return _side_is_non_fall_border(&"west", biome_cell)
	if cell.x == zone_size.x - 1:
		return _side_is_non_fall_border(&"east", biome_cell)
	return false

func _side_is_non_fall_border(
	side: StringName,
	biome_cell: BiomeCell = null
) -> bool:
	if biome_cell == null:
		return true
	return biome_cell.get_border(side) != BiomeCell.BorderType.FALL

func _cell_inside_any_rect(cell: Vector2i, rects: Array[Rect2i]) -> bool:
	for rect in rects:
		if rect.has_point(cell):
			return true
	return false

func _rebuild_terrain_class_cache(biome_cell: BiomeCell = null) -> void:
	var total := zone_size.x * zone_size.y
	_terrain_class_cache = PackedByteArray()
	_terrain_class_cache.resize(total)
	_terrain_class_cache.fill(TERRAIN_CODE_VOID)
	for rect in floor_rects:
		_mark_rect_in_cache(rect, TERRAIN_CODE_WALKABLE)
	for rect in road_rects:
		_mark_rect_in_cache(rect, TERRAIN_CODE_WALKABLE)
	for key_value in road_cell_tags.keys():
		var key := int(key_value)
		if key >= 0 and key < total:
			_terrain_class_cache[key] = TERRAIN_CODE_WALKABLE
	for rect in passage_rects:
		_mark_rect_in_cache(rect, TERRAIN_CODE_WALKABLE)
	_mark_border_in_cache(biome_cell)
	for rect in hazard_rects:
		_mark_rect_in_cache(rect, TERRAIN_CODE_HAZARD)
	for rect in obstacle_rects:
		_mark_rect_in_cache(rect, TERRAIN_CODE_OBSTACLE)
	for rect in fall_zone_rects:
		_mark_rect_in_cache(rect, TERRAIN_CODE_FALL_ZONE)
	for rect in bridge_rects:
		_mark_rect_in_cache(rect, TERRAIN_CODE_WALKABLE)
	for key_value in road_cell_tags.keys():
		var key := int(key_value)
		if key < 0 or key >= total:
			continue
		var raw_tags: Array = road_cell_tags[key] as Array
		if raw_tags.has(&"bridge") or raw_tags.has("bridge"):
			_terrain_class_cache[key] = TERRAIN_CODE_WALKABLE

func _rebuild_floor_tag_cache() -> void:
	var total := zone_size.x * zone_size.y
	_floor_tag_cache = PackedInt32Array()
	if total <= 0:
		return
	_floor_tag_cache.resize(total)
	_floor_tag_cache.fill(0)
	# Forward order so later rects overwrite earlier ones, matching the "last rect
	# wins" semantics of the linear get_floor_tag_at_cell() scan.
	for index in range(floor_rects.size()):
		var clipped := _clip_rect(floor_rects[index])
		var encoded := index + 1
		for y in range(clipped.position.y, clipped.position.y + clipped.size.y):
			var row_offset := y * zone_size.x
			for x in range(clipped.position.x, clipped.position.x + clipped.size.x):
				_floor_tag_cache[row_offset + x] = encoded

func is_wall_segment_cell(cell: Vector2i) -> bool:
	# O(1) via the per-cell cache; falls back to a rect scan before the cache exists.
	if _wall_segment_cache.size() == zone_size.x * zone_size.y:
		if (
			cell.x < 0
			or cell.y < 0
			or cell.x >= zone_size.x
			or cell.y >= zone_size.y
		):
			return false
		return _wall_segment_cache[_cell_key(cell)] != 0
	return _cell_inside_any_rect(cell, wall_segment_rects)

func _rebuild_wall_segment_cache() -> void:
	var total := zone_size.x * zone_size.y
	_wall_segment_cache = PackedByteArray()
	if total <= 0:
		return
	_wall_segment_cache.resize(total)
	_wall_segment_cache.fill(0)
	for rect in wall_segment_rects:
		var clipped := _clip_rect(rect)
		for y in range(clipped.position.y, clipped.position.y + clipped.size.y):
			var row_offset := y * zone_size.x
			for x in range(clipped.position.x, clipped.position.x + clipped.size.x):
				_wall_segment_cache[row_offset + x] = 1

func _mark_rect_in_cache(rect: Rect2i, terrain_code: int) -> void:
	var clipped := _clip_rect(rect)
	for y in range(clipped.position.y, clipped.position.y + clipped.size.y):
		var row_offset := y * zone_size.x
		for x in range(clipped.position.x, clipped.position.x + clipped.size.x):
			_terrain_class_cache[row_offset + x] = terrain_code

func _mark_border_in_cache(biome_cell: BiomeCell = null) -> void:
	if zone_size.x <= 0 or zone_size.y <= 0:
		return
	for x in range(zone_size.x):
		_mark_border_cell_if_void(Vector2i(x, 0), &"north", biome_cell)
		_mark_border_cell_if_void(Vector2i(x, zone_size.y - 1), &"south", biome_cell)
	for y in range(zone_size.y):
		_mark_border_cell_if_void(Vector2i(0, y), &"west", biome_cell)
		_mark_border_cell_if_void(Vector2i(zone_size.x - 1, y), &"east", biome_cell)

func _mark_border_cell_if_void(
	cell: Vector2i,
	side: StringName,
	biome_cell: BiomeCell
) -> void:
	if not _side_is_non_fall_border(side, biome_cell):
		return
	var key := _cell_key(cell)
	if key >= 0 and key < _terrain_class_cache.size() and _terrain_class_cache[key] == TERRAIN_CODE_VOID:
		_terrain_class_cache[key] = TERRAIN_CODE_BORDER

func _terrain_class_from_code(code: int) -> StringName:
	match code:
		TERRAIN_CODE_WALKABLE:
			return TERRAIN_WALKABLE
		TERRAIN_CODE_OBSTACLE:
			return TERRAIN_OBSTACLE
		TERRAIN_CODE_HAZARD:
			return TERRAIN_HAZARD
		TERRAIN_CODE_BORDER:
			return TERRAIN_BORDER
		TERRAIN_CODE_FALL_ZONE:
			return TERRAIN_FALL_ZONE
		_:
			return TERRAIN_VOID

func _clip_rect(rect: Rect2i) -> Rect2i:
	var x := clampi(rect.position.x, 0, zone_size.x)
	var y := clampi(rect.position.y, 0, zone_size.y)
	var end_x := clampi(rect.position.x + rect.size.x, 0, zone_size.x)
	var end_y := clampi(rect.position.y + rect.size.y, 0, zone_size.y)
	return Rect2i(Vector2i(x, y), Vector2i(maxi(end_x - x, 0), maxi(end_y - y, 0)))

func _cell_key(cell: Vector2i) -> int:
	return cell.y * zone_size.x + cell.x
