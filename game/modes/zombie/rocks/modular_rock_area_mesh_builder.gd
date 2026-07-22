extends RefCounted
class_name ModularRockAreaMeshBuilder

## Atlas-safe Plains mesa renderer. Quads are grouped by semantic atlas role and
## every quad samples exactly one 0..1 module. This keeps draw calls bounded by
## the number of roles while avoiding AtlasTexture repetition across transparent
## cells.

const RAISE_HEIGHT_CELLS := RectilinearRockAreaMeshBuilder.RAISE_HEIGHT_CELLS
const TOP_BRIGHTNESS := RectilinearRockAreaMeshBuilder.TOP_BRIGHTNESS
const CENTER_ROLES: Array[StringName] = [
	&"center_01", &"center_02", &"center_03", &"center_04",
]

var top_meshes_by_role: Dictionary = {}
var face_meshes_by_role: Dictionary = {}
var top_quad_count: int = 0
var face_quad_count: int = 0

func reset() -> void:
	top_meshes_by_role.clear()
	face_meshes_by_role.clear()
	top_quad_count = 0
	face_quad_count = 0

func build_local_size(
	world_size: Vector2,
	logical_scale: float,
	generation_seed: int,
	suppress_south_face: bool = false,
	atlas_set: RockCliffAtlasSet = null
) -> void:
	reset()
	if world_size.x <= 0.0 or world_size.y <= 0.0 or logical_scale <= 0.0:
		return
	var columns := maxi(1, roundi(world_size.x / logical_scale))
	var rows := maxi(1, roundi(world_size.y / logical_scale))
	var raise := RAISE_HEIGHT_CELLS * logical_scale
	var ground_rect := Rect2(-world_size * 0.5, world_size)
	var crown_rect := Rect2(
		ground_rect.position + Vector2(0.0, -raise),
		world_size
	)
	var top_buffers := {}
	var face_buffers := {}
	_append_top_tiles(
		top_buffers, crown_rect, columns, rows, generation_seed, atlas_set
	)
	_append_wall_stamps(
		face_buffers,
		crown_rect,
		columns,
		rows,
		suppress_south_face,
		atlas_set
	)
	top_meshes_by_role = _build_role_meshes(top_buffers)
	face_meshes_by_role = _build_role_meshes(face_buffers)

func has_geometry() -> bool:
	return top_quad_count > 0 and not top_meshes_by_role.is_empty()

func get_counts() -> Dictionary:
	return {
		"top_quads": top_quad_count,
		"face_quads": face_quad_count,
		"top_batches": top_meshes_by_role.size(),
		"face_batches": face_meshes_by_role.size(),
	}

func _append_top_tiles(
	buffers_by_role: Dictionary,
	rect: Rect2,
	columns: int,
	rows: int,
	generation_seed: int,
	atlas_set: RockCliffAtlasSet
) -> void:
	var tile_size := Vector2(rect.size.x / float(columns), rect.size.y / float(rows))
	var crown := Color(TOP_BRIGHTNESS, TOP_BRIGHTNESS, TOP_BRIGHTNESS, 1.0)
	# East/west wall modules own the outer logical tile from their authored
	# crest to the collision boundary. Do not keep an opaque center tile under
	# that face: the mountain crown begins one complete tile farther inward.
	# Narrow fallback blockers keep their only available top column.
	var first_column := 1 if columns >= 3 else 0
	var end_column := columns - 1 if columns >= 3 else columns
	for row in range(rows):
		for column in range(first_column, end_column):
			var role := _center_role(generation_seed, Vector2i(column, row))
			var buffers := _buffers_for_role(buffers_by_role, role)
			var nw := rect.position + Vector2(column * tile_size.x, row * tile_size.y)
			var ne := nw + Vector2(tile_size.x, 0.0)
			var se := nw + tile_size
			var sw := nw + Vector2(0.0, tile_size.y)
			QuadMeshBuffers.append_quad(
				buffers,
				PackedVector2Array([nw, ne, se, sw]),
				_module_uvs(
					atlas_set.get_top_uv_rect(role)
					if atlas_set != null
					else Rect2(Vector2.ZERO, Vector2.ONE)
				),
				PackedColorArray([crown, crown, crown, crown])
			)
			top_quad_count += 1

func _append_wall_stamps(
	buffers_by_role: Dictionary,
	crown_rect: Rect2,
	columns: int,
	rows: int,
	suppress_south_face: bool,
	atlas_set: RockCliffAtlasSet
) -> void:
	var occupied := {}
	for row in range(rows):
		for column in range(columns):
			occupied[Vector2i(column, row)] = true
	var tile_size := Vector2(
		crown_rect.size.x / float(columns),
		crown_rect.size.y / float(rows)
	)
	var stamp_color := Color.WHITE
	for vertex_y in range(rows + 1):
		for vertex_x in range(columns + 1):
			if suppress_south_face and vertex_y == rows:
				continue
			var vertex := Vector2i(vertex_x, vertex_y)
			var mask := RockCliffTopologyResolver.vertex_mask_for_cells(
				occupied, vertex
			)
			var role := RockCliffTopologyResolver.wall_role_for_vertex_mask(mask)
			if role.is_empty():
				continue
			var uv_rect := (
				atlas_set.get_wall_uv_rect(role)
				if atlas_set != null
				else Rect2(Vector2.ZERO, Vector2.ONE)
			)
			var stamp_nw := crown_rect.position + Vector2(
				(float(vertex_x) - 1.0) * tile_size.x,
				(float(vertex_y) - 1.0) * tile_size.y
			)
			var stamp_rect := Rect2(stamp_nw, tile_size * 2.0)
			# A topology stamp is authored as four quadrants around one vertex.
			# Quadrants outside the mesa are transparent, but keeping their quad
			# geometry would still extend one tile beyond the collision footprint.
			# Clip both geometry and UVs to the crown. The visible lateral face then
			# runs from its inset authored crest to the exact hitbox boundary.
			var clipped_rect := stamp_rect.intersection(crown_rect)
			if not clipped_rect.has_area():
				continue
			var clipped_uv_rect := _clipped_uv_rect(
				uv_rect, stamp_rect, clipped_rect
			)
			var nw := clipped_rect.position
			var ne := Vector2(clipped_rect.end.x, clipped_rect.position.y)
			var se := clipped_rect.end
			var sw := Vector2(clipped_rect.position.x, clipped_rect.end.y)
			QuadMeshBuffers.append_quad(
				_buffers_for_role(buffers_by_role, role),
				PackedVector2Array([nw, ne, se, sw]),
				_module_uvs(clipped_uv_rect),
				PackedColorArray([
					stamp_color, stamp_color, stamp_color, stamp_color,
				])
			)
			face_quad_count += 1

func _clipped_uv_rect(
	uv_rect: Rect2,
	stamp_rect: Rect2,
	clipped_rect: Rect2
) -> Rect2:
	var normalized_position := Vector2(
		(clipped_rect.position.x - stamp_rect.position.x) / stamp_rect.size.x,
		(clipped_rect.position.y - stamp_rect.position.y) / stamp_rect.size.y
	)
	var normalized_size := Vector2(
		clipped_rect.size.x / stamp_rect.size.x,
		clipped_rect.size.y / stamp_rect.size.y
	)
	return Rect2(
		uv_rect.position + normalized_position * uv_rect.size,
		normalized_size * uv_rect.size
	)

func _center_role(generation_seed: int, cell: Vector2i) -> StringName:
	var variant := posmod(
		("%d|%d|%d|mountain_top" % [generation_seed, cell.x, cell.y]).hash(),
		CENTER_ROLES.size()
	)
	return CENTER_ROLES[variant]

func _buffers_for_role(buffers_by_role: Dictionary, role: StringName) -> Dictionary:
	if not buffers_by_role.has(role):
		buffers_by_role[role] = QuadMeshBuffers.create()
	return buffers_by_role[role] as Dictionary

func _build_role_meshes(buffers_by_role: Dictionary) -> Dictionary:
	var meshes := {}
	for role in buffers_by_role:
		var mesh := QuadMeshBuffers.build_mesh(buffers_by_role[role] as Dictionary)
		if mesh != null:
			meshes[role] = mesh
	return meshes

func _module_uvs(uv_rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([
		uv_rect.position,
		uv_rect.position + Vector2(uv_rect.size.x, 0.0),
		uv_rect.end,
		uv_rect.position + Vector2(0.0, uv_rect.size.y),
	])
