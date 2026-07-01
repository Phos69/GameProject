extends Node2D
class_name BiomeTileChunk

var chunk_rect: Rect2i
var ground_underlay_mesh: ArrayMesh
var ground_mesh: ArrayMesh
var surface_meshes: Dictionary = {}
var surface_textures: Dictionary = {}
var surface_texture_ids: Array[StringName] = []
var texture_dark_lines := PackedVector2Array()
var texture_light_lines := PackedVector2Array()
var transition_lines := PackedVector2Array()
var depth_lines := PackedVector2Array()
var grid_points := PackedVector2Array()
var grid_color := Color(1.0, 1.0, 1.0, 0.12)
var suppressed_void_texture_count: int = 0

func configure(
	next_rect: Rect2i,
	next_ground_underlay_mesh: ArrayMesh,
	next_ground_mesh: ArrayMesh,
	next_surface_meshes: Dictionary,
	next_surface_textures: Dictionary,
	next_surface_texture_ids: Array[StringName],
	next_texture_dark_lines: PackedVector2Array,
	next_texture_light_lines: PackedVector2Array,
	next_transition_lines: PackedVector2Array,
	next_depth_lines: PackedVector2Array,
	next_grid_points: PackedVector2Array,
	next_grid_color: Color,
	next_suppressed_void_texture_count: int
) -> void:
	chunk_rect = next_rect
	ground_underlay_mesh = next_ground_underlay_mesh
	ground_mesh = next_ground_mesh
	surface_meshes = next_surface_meshes.duplicate()
	surface_textures = next_surface_textures.duplicate()
	surface_texture_ids = next_surface_texture_ids.duplicate()
	texture_dark_lines = next_texture_dark_lines
	texture_light_lines = next_texture_light_lines
	transition_lines = next_transition_lines
	depth_lines = next_depth_lines
	grid_points = next_grid_points
	grid_color = next_grid_color
	suppressed_void_texture_count = next_suppressed_void_texture_count
	z_index = -9
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	add_to_group("biome_tile_chunks")
	queue_redraw()

func get_visual_tile_count() -> int:
	return chunk_rect.size.x * chunk_rect.size.y

func get_texture_detail_line_count() -> int:
	return int((
		texture_dark_lines.size()
		+ texture_light_lines.size()
		+ transition_lines.size()
		+ depth_lines.size()
	) / 2)

func get_suppressed_void_texture_count() -> int:
	return suppressed_void_texture_count

func _draw() -> void:
	if ground_underlay_mesh != null:
		draw_mesh(ground_underlay_mesh, null)
	for texture_id in surface_texture_ids:
		var surface_mesh := surface_meshes.get(texture_id) as ArrayMesh
		var surface_texture := surface_textures.get(texture_id) as Texture2D
		if surface_mesh != null and surface_texture != null:
			draw_mesh(surface_mesh, surface_texture)
	if ground_mesh != null:
		draw_mesh(ground_mesh, null)
	if texture_dark_lines.size() >= 2:
		draw_multiline(
			texture_dark_lines,
			Color(0.09, 0.18, 0.075, 0.34),
			1.0
		)
	if texture_light_lines.size() >= 2:
		draw_multiline(
			texture_light_lines,
			Color(0.70, 0.76, 0.42, 0.24),
			1.0
		)
	if transition_lines.size() >= 2:
		draw_multiline(
			transition_lines,
			Color(0.24, 0.15, 0.075, 0.42),
			1.2
		)
	if depth_lines.size() >= 2:
		draw_multiline(
			depth_lines,
			Color(0.12, 0.22, 0.14, 0.48),
			1.4
		)
	if grid_points.size() >= 2:
		draw_multiline(grid_points, grid_color)
