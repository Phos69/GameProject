class_name QuadMeshBuffers
extends RefCounted

# Batcher condiviso per mesh 2D a quad: buffer (vertici/colori/UV/indici),
# append di un quad a 4 vertici con winding a due triangoli e costruzione
# della ArrayMesh finale. Unica fonte per i corpi prima duplicati nei mesh
# builder di cliff e rocce (gruppo 4.2 del report repo health).

static func create() -> Dictionary:
	return {
		"vertices": PackedVector2Array(),
		"colors": PackedColorArray(),
		"uvs": PackedVector2Array(),
		"indices": PackedInt32Array()
	}

static func append_quad(
	buffers: Dictionary,
	quad_vertices: PackedVector2Array,
	quad_uvs: PackedVector2Array,
	quad_colors: PackedColorArray
) -> void:
	if (
		quad_vertices.size() != 4
		or quad_uvs.size() != 4
		or quad_colors.size() != 4
	):
		return
	var vertices := buffers["vertices"] as PackedVector2Array
	var colors := buffers["colors"] as PackedColorArray
	var uvs := buffers["uvs"] as PackedVector2Array
	var indices := buffers["indices"] as PackedInt32Array
	var base := vertices.size()
	for index in range(4):
		vertices.append(quad_vertices[index])
		colors.append(quad_colors[index])
		uvs.append(quad_uvs[index])
	indices.append(base)
	indices.append(base + 1)
	indices.append(base + 2)
	indices.append(base)
	indices.append(base + 2)
	indices.append(base + 3)
	buffers["vertices"] = vertices
	buffers["colors"] = colors
	buffers["uvs"] = uvs
	buffers["indices"] = indices

static func append_triangle(
	buffers: Dictionary,
	triangle_vertices: PackedVector2Array,
	triangle_uvs: PackedVector2Array,
	triangle_colors: PackedColorArray
) -> void:
	if (
		triangle_vertices.size() != 3
		or triangle_uvs.size() != 3
		or triangle_colors.size() != 3
	):
		return
	var vertices := buffers["vertices"] as PackedVector2Array
	var colors := buffers["colors"] as PackedColorArray
	var uvs := buffers["uvs"] as PackedVector2Array
	var indices := buffers["indices"] as PackedInt32Array
	var base := vertices.size()
	for index in range(3):
		vertices.append(triangle_vertices[index])
		colors.append(triangle_colors[index])
		uvs.append(triangle_uvs[index])
	indices.append(base)
	indices.append(base + 1)
	indices.append(base + 2)
	buffers["vertices"] = vertices
	buffers["colors"] = colors
	buffers["uvs"] = uvs
	buffers["indices"] = indices

static func build_mesh(buffers: Dictionary) -> ArrayMesh:
	var vertices := buffers["vertices"] as PackedVector2Array
	var indices := buffers["indices"] as PackedInt32Array
	if vertices.is_empty() or indices.is_empty():
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = buffers["colors"]
	arrays[Mesh.ARRAY_TEX_UV] = buffers["uvs"]
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
