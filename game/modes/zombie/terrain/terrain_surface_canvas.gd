extends Node2D
class_name TerrainSurfaceCanvas

const TERRAIN_SURFACE_SHADER = preload(
	"res://game/modes/zombie/ground/terrain_surface_blend.gdshader"
)

var surface_mesh: ArrayMesh
var surface_material: ShaderMaterial
var surface_material_ids: Array[StringName] = []
var chunk_world_rect := Rect2()
var mask_uv_rect := Rect2()


func configure(render_data: Dictionary) -> void:
	chunk_world_rect = render_data.get("chunk_world_rect", Rect2()) as Rect2
	mask_uv_rect = render_data.get("mask_uv_rect", Rect2()) as Rect2
	surface_material_ids.clear()
	for material_id_value in render_data.get("surface_material_ids", []) as Array:
		surface_material_ids.append(StringName(material_id_value))
	surface_mesh = _build_quad_mesh(chunk_world_rect)
	surface_material = ShaderMaterial.new()
	surface_material.shader = TERRAIN_SURFACE_SHADER
	_set_texture_parameter(surface_material, &"surface_mask", render_data, "mask_texture")
	_set_texture_parameter(surface_material, &"grass_texture", render_data, "grass_texture")
	_set_texture_parameter(surface_material, &"path_texture", render_data, "path_texture")
	_set_texture_parameter(surface_material, &"asphalt_texture", render_data, "asphalt_texture")
	_set_texture_parameter(surface_material, &"divider_texture", render_data, "divider_texture")
	surface_material.set_shader_parameter(&"mask_uv_origin", mask_uv_rect.position)
	surface_material.set_shader_parameter(&"mask_uv_size", mask_uv_rect.size)
	surface_material.set_shader_parameter(
		&"texture_world_origin",
		render_data.get("texture_world_origin", chunk_world_rect.position) as Vector2
	)
	surface_material.set_shader_parameter(&"world_size", chunk_world_rect.size)
	surface_material.set_shader_parameter(
		&"grass_repeat_world",
		float(render_data.get("grass_repeat_world", 256.0))
	)
	surface_material.set_shader_parameter(
		&"path_repeat_world",
		float(render_data.get("path_repeat_world", 256.0))
	)
	surface_material.set_shader_parameter(
		&"asphalt_repeat_world",
		float(render_data.get("asphalt_repeat_world", 256.0))
	)
	surface_material.set_shader_parameter(
		&"divider_repeat_world",
		float(render_data.get("divider_repeat_world", 256.0))
	)
	surface_material.set_shader_parameter(
		&"void_color",
		render_data.get("void_color", Color(0.025, 0.035, 0.03, 1.0)) as Color
	)
	material = surface_material
	show_behind_parent = true
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	queue_redraw()


func get_surface_material_ids() -> Array[StringName]:
	return surface_material_ids.duplicate()


func _draw() -> void:
	if surface_mesh != null and surface_material != null:
		draw_mesh(surface_mesh, null)


func _set_texture_parameter(
	shader_material: ShaderMaterial,
	parameter: StringName,
	render_data: Dictionary,
	key: String
) -> void:
	var texture := render_data.get(key) as Texture2D
	if texture != null:
		shader_material.set_shader_parameter(parameter, texture)


func _build_quad_mesh(rect: Rect2) -> ArrayMesh:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	])
	arrays[Mesh.ARRAY_COLOR] = PackedColorArray([
		Color.WHITE,
		Color.WHITE,
		Color.WHITE,
		Color.WHITE,
	])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([
		Vector2.ZERO,
		Vector2.RIGHT,
		Vector2.ONE,
		Vector2.DOWN,
	])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
