extends RefCounted
class_name BiomeTileChunkBaker

const BIOME_TILE_CHUNK_SCRIPT = preload(
	"res://game/modes/zombie/terrain/biome_tile_chunk.gd"
)

static func bake_chunk(
	parent: Node,
	coord: Vector2i,
	chunk_rect: Rect2i,
	ground_underlay_mesh: ArrayMesh,
	ground_mesh: ArrayMesh,
	surface_meshes: Dictionary,
	surface_textures: Dictionary,
	surface_texture_ids: Array[StringName],
	texture_dark_lines: PackedVector2Array,
	texture_light_lines: PackedVector2Array,
	transition_lines: PackedVector2Array,
	depth_lines: PackedVector2Array,
	grid_points: PackedVector2Array,
	grid_color: Color,
	suppressed_void_texture_count: int,
	terrain_surface_render_data: Dictionary = {}
) -> BiomeTileChunk:
	if parent == null:
		return null
	var rendered_surface_ids: Array[StringName] = []
	for texture_id in surface_texture_ids:
		var surface_mesh := surface_meshes.get(texture_id) as ArrayMesh
		if surface_mesh != null and surface_mesh.get_surface_count() > 0:
			rendered_surface_ids.append(texture_id)
	var chunk := BIOME_TILE_CHUNK_SCRIPT.new() as BiomeTileChunk
	if chunk == null:
		return null
	chunk.name = "Chunk_%d_%d" % [coord.x, coord.y]
	parent.add_child(chunk)
	chunk.configure(
		chunk_rect,
		ground_underlay_mesh,
		ground_mesh,
		surface_meshes,
		surface_textures,
		rendered_surface_ids,
		texture_dark_lines,
		texture_light_lines,
		transition_lines,
		depth_lines,
		grid_points,
		grid_color,
		suppressed_void_texture_count,
		terrain_surface_render_data
	)
	return chunk
