extends RefCounted
class_name IsometricForestGroundMeshBuilder

## Builds seamless, world-space UV surfaces for forest terrain-material runs.
## Terrain classification stays in BiomeTileLayer; this class only owns mesh data.

static func build_mesh(
	runs: Array[Rect2i],
	zone_size: Vector2i,
	logical_scale: float,
	texture_world_size: float,
	overdraw_pixels: float = 0.0
) -> ArrayMesh:
	if runs.is_empty() or texture_world_size <= 0.0:
		return null
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for run in runs:
		_append_run(
			vertices,
			colors,
			uvs,
			indices,
			run,
			zone_size,
			logical_scale,
			texture_world_size,
			overdraw_pixels
		)
	if vertices.is_empty():
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

static func _append_run(
	vertices: PackedVector2Array,
	colors: PackedColorArray,
	uvs: PackedVector2Array,
	indices: PackedInt32Array,
	run: Rect2i,
	zone_size: Vector2i,
	logical_scale: float,
	texture_world_size: float,
	overdraw_pixels: float
) -> void:
	if run.size.x <= 0 or run.size.y <= 0:
		return
	var zone_offset := Vector2(float(zone_size.x), float(zone_size.y)) * 0.5
	var left := (float(run.position.x) - zone_offset.x) * logical_scale
	var right := (float(run.end.x) - zone_offset.x) * logical_scale
	var top := (float(run.position.y) - zone_offset.y) * logical_scale
	var bottom := (float(run.end.y) - zone_offset.y) * logical_scale
	var overdraw := maxf(overdraw_pixels, 0.0)
	var draw_left := left - overdraw
	var draw_right := right + overdraw
	var draw_top := top - overdraw
	var draw_bottom := bottom + overdraw
	var base := vertices.size()
	vertices.append(Vector2(draw_left, draw_top))
	vertices.append(Vector2(draw_right, draw_top))
	vertices.append(Vector2(draw_right, draw_bottom))
	vertices.append(Vector2(draw_left, draw_bottom))
	for _index in range(4):
		colors.append(Color.WHITE)
	uvs.append(Vector2(left, top) / texture_world_size)
	uvs.append(Vector2(right, top) / texture_world_size)
	uvs.append(Vector2(right, bottom) / texture_world_size)
	uvs.append(Vector2(left, bottom) / texture_world_size)
	indices.append(base)
	indices.append(base + 1)
	indices.append(base + 2)
	indices.append(base)
	indices.append(base + 2)
	indices.append(base + 3)
