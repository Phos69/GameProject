extends RefCounted
class_name RectilinearRockAreaMeshBuilder

const WorldGridConfig = preload("res://game/core/world_grid_config.gd")

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
const RAISE_HEIGHT_CELLS: float = WorldGridConfig.RAISED_CLIFF_HEIGHT_TILES
const LATERAL_LEAN_RATIO := 0.42
# Per-side shading mirrors TopDownCliffMeshBuilder: front brightest, east lit,
# west in shadow; every wall darkens toward the ground and the crown is brightest.
const FRONT_BRIGHTNESS := 1.0
const EAST_BRIGHTNESS := 0.84
const WEST_BRIGHTNESS := 0.62
const FACE_GROUND_SHADE := 0.70
const TOP_BRIGHTNESS := 1.06
const CONVEX_CORNER_RADIUS_TILES := 0.75
const CONVEX_CORNER_SEGMENTS := 6

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
	var top := QuadMeshBuffers.create()
	var face := QuadMeshBuffers.create()
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
		_append_area(
			top,
			face,
			Rect2(Vector2(left, north), Vector2(right - left, south - north)),
			raise,
			Vector2.ZERO
		)
	top_mesh = QuadMeshBuffers.build_mesh(top)
	face_mesh = QuadMeshBuffers.build_mesh(face)

func build_local_size(
	world_size: Vector2,
	logical_scale: float,
	world_uv_origin: Vector2 = Vector2.ZERO
) -> void:
	reset()
	if world_size.x <= 0.0 or world_size.y <= 0.0 or logical_scale <= 0.0:
		return
	var top := QuadMeshBuffers.create()
	var face := QuadMeshBuffers.create()
	_append_area(
		top,
		face,
		Rect2(-world_size * 0.5, world_size),
		RAISE_HEIGHT_CELLS * logical_scale,
		world_uv_origin
	)
	top_mesh = QuadMeshBuffers.build_mesh(top)
	face_mesh = QuadMeshBuffers.build_mesh(face)

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

func _append_area(
	top: Dictionary,
	face: Dictionary,
	ground_rect: Rect2,
	raise: float,
	world_uv_origin: Vector2
) -> void:
	var left := ground_rect.position.x
	var right := ground_rect.end.x
	var north := ground_rect.position.y
	var south := ground_rect.end.y
	var lean := minf(raise * LATERAL_LEAN_RATIO, ground_rect.size.x * 0.3)
	var corner_radius := minf(
		CONVEX_CORNER_RADIUS_TILES * WorldGridConfig.LOGICAL_TILE_SCALE,
		minf(ground_rect.size.x, ground_rect.size.y) * 0.24
	)
	var base_outline := _rounded_rect_outline(ground_rect, corner_radius)
	var crown_rect := Rect2(
		Vector2(left + lean, north - raise),
		Vector2(right - left - lean * 2.0, south - north)
	)
	var crown_outline := _rounded_rect_outline(
		crown_rect,
		minf(corner_radius, crown_rect.size.x * 0.24)
	)
	for index in range(base_outline.size()):
		var next := (index + 1) % base_outline.size()
		var delta := base_outline[next] - base_outline[index]
		var outward := Vector2(delta.y, -delta.x).normalized()
		# The north face points away from the cardinal camera and remains hidden.
		if outward.y < -0.35:
			continue
		var brightness := FRONT_BRIGHTNESS
		if outward.x < -0.35:
			brightness = WEST_BRIGHTNESS
		elif outward.x > 0.35:
			brightness = EAST_BRIGHTNESS
		_append_wall(
			face,
			base_outline[index],
			base_outline[next],
			crown_outline[next],
			crown_outline[index],
			brightness
		)
	_append_rounded_top(top, crown_outline, world_uv_origin)
	area_count += 1

func _rounded_rect_outline(rect: Rect2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var centers: Array[Vector2] = [
		Vector2(rect.position.x + radius, rect.position.y + radius),
		Vector2(rect.end.x - radius, rect.position.y + radius),
		Vector2(rect.end.x - radius, rect.end.y - radius),
		Vector2(rect.position.x + radius, rect.end.y - radius),
	]
	var start_angles: Array[float] = [PI, -PI * 0.5, 0.0, PI * 0.5]
	for corner in range(centers.size()):
		for segment in range(CONVEX_CORNER_SEGMENTS + 1):
			var angle := start_angles[corner] + PI * 0.5 * float(segment) / float(CONVEX_CORNER_SEGMENTS)
			points.append(centers[corner] + Vector2(cos(angle), sin(angle)) * radius)
	return points

func _append_rounded_top(
	buffers: Dictionary,
	outline: PackedVector2Array,
	world_uv_origin: Vector2
) -> void:
	if outline.size() < 3:
		return
	var center := Vector2.ZERO
	for point in outline:
		center += point
	center /= float(outline.size())
	var crown := Color(TOP_BRIGHTNESS, TOP_BRIGHTNESS, TOP_BRIGHTNESS, 1.0)
	for index in range(outline.size()):
		var next := (index + 1) % outline.size()
		QuadMeshBuffers.append_triangle(
			buffers,
			PackedVector2Array([center, outline[index], outline[next]]),
			PackedVector2Array([
				(center + world_uv_origin) / top_texture_repeat_world_size,
				(outline[index] + world_uv_origin) / top_texture_repeat_world_size,
				(outline[next] + world_uv_origin) / top_texture_repeat_world_size,
			]),
			PackedColorArray([crown, crown, crown])
		)

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
	QuadMeshBuffers.append_quad(
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
	sw: Vector2,
	world_uv_origin: Vector2
) -> void:
	var crown := Color(TOP_BRIGHTNESS, TOP_BRIGHTNESS, TOP_BRIGHTNESS, 1.0)
	QuadMeshBuffers.append_quad(
		buffers,
		PackedVector2Array([nw, ne, se, sw]),
		PackedVector2Array([
			(nw + world_uv_origin) / top_texture_repeat_world_size,
			(ne + world_uv_origin) / top_texture_repeat_world_size,
			(se + world_uv_origin) / top_texture_repeat_world_size,
			(sw + world_uv_origin) / top_texture_repeat_world_size
		]),
		PackedColorArray([crown, crown, crown, crown])
	)
