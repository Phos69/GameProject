extends Node2D
class_name RockAreaOccluderVisual

const SVG_TEXTURE_LOADER = preload(
	"res://game/modes/zombie/isometric_svg_texture_loader.gd"
)

const LOGICAL_TILE_SCALE := 8.0
const BACK_OVERHANG_CELLS := 8
const COVER_DEPTH_CELLS := 3
const TEXTURE_REPEAT_WORLD_SIZE := 256.0

var footprint_size := Vector2(120.0, 120.0)
var top_texture: Texture2D
var cover_mesh: ArrayMesh
var cover_bounds := Rect2()

func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	add_to_group("rock_area_occluders")

func configure(next_footprint_size: Vector2, texture_path: String) -> bool:
	footprint_size = Vector2(
		maxf(next_footprint_size.x, 16.0),
		maxf(next_footprint_size.y, 16.0)
	)
	top_texture = null
	cover_mesh = null
	visible = false
	if texture_path.is_empty():
		queue_redraw()
		return false
	top_texture = SVG_TEXTURE_LOADER.load_texture(
		texture_path,
		Color(0.34, 0.31, 0.27, 1.0),
		Color(0.56, 0.50, 0.40, 1.0),
		Vector2i(512, 512)
	)
	if top_texture == null:
		queue_redraw()
		return false
	_rebuild_mesh()
	visible = cover_mesh != null
	queue_redraw()
	return visible

func has_texture() -> bool:
	return visible and top_texture != null and cover_mesh != null

func get_cover_bounds() -> Rect2:
	return cover_bounds

func _draw() -> void:
	if has_texture():
		draw_mesh(cover_mesh, top_texture)

func _rebuild_mesh() -> void:
	var collision_top := -footprint_size.y * 0.5
	var top := collision_top - BACK_OVERHANG_CELLS * LOGICAL_TILE_SCALE + 2.0
	var bottom := collision_top + COVER_DEPTH_CELLS * LOGICAL_TILE_SCALE
	cover_bounds = Rect2(
		Vector2(-footprint_size.x * 0.5, top),
		Vector2(footprint_size.x, bottom - top)
	)
	var left := cover_bounds.position.x
	var right := cover_bounds.end.x
	var vertices := PackedVector2Array([
		Vector2(left, top),
		Vector2(right, top),
		Vector2(right, bottom),
		Vector2(left, bottom)
	])
	var uvs := PackedVector2Array([
		Vector2(left, top) / TEXTURE_REPEAT_WORLD_SIZE,
		Vector2(right, top) / TEXTURE_REPEAT_WORLD_SIZE,
		Vector2(right, bottom) / TEXTURE_REPEAT_WORLD_SIZE,
		Vector2(left, bottom) / TEXTURE_REPEAT_WORLD_SIZE
	])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = PackedColorArray([
		Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE
	])
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	cover_mesh = ArrayMesh.new()
	cover_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
