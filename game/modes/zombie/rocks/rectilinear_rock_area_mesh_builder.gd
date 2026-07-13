extends RefCounted
class_name RectilinearRockAreaMeshBuilder

const IsoGridConfig = preload("res://game/core/iso_grid_config.gd")

# Builds a raised rock plateau for each rock rect. It is the void cliff mirrored
# upward: instead of the ground dropping into the void, the rock rim is lifted by
# RAISE_HEIGHT_CELLS and the rock walls ascend from the surrounding grass up to the
# rim. The lateral walls lean inward (LATERAL_LEAN_RATIO) so the mass reads as an
# oblique mesa in the fake-perspective view, exactly like the void's sheared sides.
#
# Geometry per rect (top crown drawn last so it masks the wall seams):
#   - top    : the footprint translated up by `raise`, inset by `lean` (mesa crown).
#   - front  : full-width south wall, ground south edge -> crown south edge.
#   - east   : right side wall, ground east edge -> crown east edge (lit side).
#   - west   : left side wall, ground west edge -> crown west edge (shadow side).
# The north wall faces away from the camera and is never emitted.
#
# No procedural fissure/lip lines are drawn: all rock detail comes from the crown
# and cliff-face textures, so the surface stays free of hand-drawn strokes.

const TOP_TEXTURE_REPEAT_WORLD_SIZE := 256.0
const FACE_TEXTURE_REPEAT_WORLD_SIZE := 128.0
const RAISE_HEIGHT_CELLS: float = IsoGridConfig.RAISED_CLIFF_HEIGHT_TILES
const LATERAL_LEAN_RATIO := 0.42
# Per-side shading mirrors IsometricCliffMeshBuilder: front brightest, east lit,
# west in shadow; every wall darkens toward the ground and the crown is brightest.
const FRONT_BRIGHTNESS := 1.0
const EAST_BRIGHTNESS := 0.84
const WEST_BRIGHTNESS := 0.62
const FACE_GROUND_SHADE := 0.70
const TOP_BRIGHTNESS := 1.06

var palette: BiomePalette
var generation_seed: int = 0
var top_texture_repeat_world_size: float = TOP_TEXTURE_REPEAT_WORLD_SIZE
var face_texture_repeat_world_size: float = FACE_TEXTURE_REPEAT_WORLD_SIZE

var top_mesh: ArrayMesh
var face_mesh: ArrayMesh
var area_count: int = 0
var face_count: int = 0

func configure(
	next_palette: BiomePalette,
	next_generation_seed: int,
	next_top_texture_repeat_world_size: float = TOP_TEXTURE_REPEAT_WORLD_SIZE,
	next_face_texture_repeat_world_size: float = FACE_TEXTURE_REPEAT_WORLD_SIZE
) -> void:
	palette = next_palette
	generation_seed = next_generation_seed
	top_texture_repeat_world_size = maxf(
		next_top_texture_repeat_world_size,
		1.0
	)
	face_texture_repeat_world_size = maxf(
		next_face_texture_repeat_world_size,
		1.0
	)
	reset()

func reset() -> void:
	top_mesh = null
	face_mesh = null
	area_count = 0
	face_count = 0

func build(
	mesa_rects: Array[Rect2i],
	zone_size: Vector2i,
	logical_scale: float
) -> void:
	reset()
	if mesa_rects.is_empty() or logical_scale <= 0.0:
		return
	var top := _new_buffers()
	var face := _new_buffers()
	var zone_bounds := Rect2i(Vector2i.ZERO, zone_size)
	var zone_offset := Vector2(zone_size) * 0.5
	var raise := RAISE_HEIGHT_CELLS * logical_scale
	for source_rect in mesa_rects:
		var rect := source_rect.intersection(zone_bounds)
		if rect.size.x <= 0 or rect.size.y <= 0:
			continue
		var left := (float(rect.position.x) - zone_offset.x) * logical_scale
		var right := (float(rect.end.x) - zone_offset.x) * logical_scale
		var north := (float(rect.position.y) - zone_offset.y) * logical_scale
		var south := (float(rect.end.y) - zone_offset.y) * logical_scale
		var lean := minf(raise * LATERAL_LEAN_RATIO, float(rect.size.x) * logical_scale * 0.3)
		# Ground footprint corners (rock meets grass).
		var b_nw := Vector2(left, north)
		var b_ne := Vector2(right, north)
		var b_se := Vector2(right, south)
		var b_sw := Vector2(left, south)
		# Raised, inset crown corners.
		var t_nw := Vector2(left + lean, north - raise)
		var t_ne := Vector2(right - lean, north - raise)
		var t_se := Vector2(right - lean, south - raise)
		var t_sw := Vector2(left + lean, south - raise)
		# Side walls first, then the front wall on top of them at the corners.
		_append_wall(face, b_nw, b_sw, t_sw, t_nw, WEST_BRIGHTNESS)
		_append_wall(face, b_se, b_ne, t_ne, t_se, EAST_BRIGHTNESS)
		_append_wall(face, b_sw, b_se, t_se, t_sw, FRONT_BRIGHTNESS)
		_append_top(top, t_nw, t_ne, t_se, t_sw)
		area_count += 1
	top_mesh = _build_mesh(top)
	face_mesh = _build_mesh(face)

func has_geometry() -> bool:
	return area_count > 0 and top_mesh != null and face_mesh != null

func get_counts() -> Dictionary:
	return {
		"areas": area_count,
		"faces": face_count,
		"raise_height_cells": RAISE_HEIGHT_CELLS,
		"top_texture_repeat_world_size": top_texture_repeat_world_size,
		"face_texture_repeat_world_size": face_texture_repeat_world_size,
	}

func get_face_mesh() -> ArrayMesh:
	return face_mesh

func _append_wall(
	buffers: Dictionary,
	ground_a: Vector2,
	ground_b: Vector2,
	top_b: Vector2,
	top_a: Vector2,
	brightness: float
) -> void:
	# World-length UVs keep the cliff-face columns upright and at a constant scale
	# regardless of the wall's run, so they never smear across a wide rock.
	var run := ground_a.distance_to(ground_b) / face_texture_repeat_world_size
	var rise := ground_a.distance_to(top_a) / face_texture_repeat_world_size
	var ground_color := Color(
		brightness * FACE_GROUND_SHADE,
		brightness * FACE_GROUND_SHADE,
		brightness * FACE_GROUND_SHADE,
		1.0
	)
	var crest_color := Color(brightness, brightness, brightness, 1.0)
	_append_quad(
		buffers,
		PackedVector2Array([ground_a, ground_b, top_b, top_a]),
		PackedVector2Array([
			Vector2(0.0, rise),
			Vector2(run, rise),
			Vector2(run, 0.0),
			Vector2(0.0, 0.0)
		]),
		PackedColorArray([ground_color, ground_color, crest_color, crest_color])
	)
	face_count += 1

func _append_top(
	buffers: Dictionary,
	nw: Vector2,
	ne: Vector2,
	se: Vector2,
	sw: Vector2
) -> void:
	var crown := Color(TOP_BRIGHTNESS, TOP_BRIGHTNESS, TOP_BRIGHTNESS, 1.0)
	_append_quad(
		buffers,
		PackedVector2Array([nw, ne, se, sw]),
		PackedVector2Array([
			nw / top_texture_repeat_world_size,
			ne / top_texture_repeat_world_size,
			se / top_texture_repeat_world_size,
			sw / top_texture_repeat_world_size
		]),
		PackedColorArray([crown, crown, crown, crown])
	)

func _new_buffers() -> Dictionary:
	return {
		"vertices": PackedVector2Array(),
		"colors": PackedColorArray(),
		"uvs": PackedVector2Array(),
		"indices": PackedInt32Array()
	}

func _append_quad(
	buffers: Dictionary,
	quad_vertices: PackedVector2Array,
	quad_uvs: PackedVector2Array,
	quad_colors: PackedColorArray
) -> void:
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

func _build_mesh(buffers: Dictionary) -> ArrayMesh:
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
