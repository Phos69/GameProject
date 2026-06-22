extends RefCounted
class_name RectilinearRockAreaMeshBuilder

const FOREST_GROUND_MESH_BUILDER_SCRIPT = preload(
	"res://game/modes/zombie/ground/isometric_forest_ground_mesh_builder.gd"
)
const CLIFF_BORDER_MESH_BUILDER_SCRIPT = preload(
	"res://game/modes/zombie/cliffs/isometric_cliff_border_mesh_builder.gd"
)
const CLIFF_TILE_MESH_BUILDER_SCRIPT = preload(
	"res://game/modes/zombie/cliffs/isometric_cliff_mesh_builder.gd"
)
const TOP_TEXTURE_REPEAT_WORLD_SIZE := 256.0
const BACK_OVERHANG_CELLS := 8
const FRONT_FACE_DEPTH_CELLS := 6
const CLIFF_TILE_SPAN_CELLS := 4
const RAISED_FACE_MODE := &"raise"

var top_mesh: ArrayMesh
var border_builder: IsometricCliffBorderMeshBuilder
var raised_cliff_builder: IsometricCliffMeshBuilder
var area_count: int = 0

func _init() -> void:
	border_builder = (
		CLIFF_BORDER_MESH_BUILDER_SCRIPT.new() as IsometricCliffBorderMeshBuilder
	)
	raised_cliff_builder = (
		CLIFF_TILE_MESH_BUILDER_SCRIPT.new() as IsometricCliffMeshBuilder
	)

func configure(next_palette: BiomePalette, generation_seed: int) -> void:
	if raised_cliff_builder == null:
		raised_cliff_builder = (
			CLIFF_TILE_MESH_BUILDER_SCRIPT.new() as IsometricCliffMeshBuilder
		)
	raised_cliff_builder.configure(
		next_palette,
		generation_seed,
		true,
		RAISED_FACE_MODE
	)

func reset() -> void:
	top_mesh = null
	area_count = 0
	if border_builder != null:
		border_builder.reset()
	if raised_cliff_builder != null:
		raised_cliff_builder.reset()

func build(
	rock_rects: Array[Rect2i],
	zone_size: Vector2i,
	logical_scale: float
) -> void:
	reset()
	if (
		rock_rects.is_empty()
		or logical_scale <= 0.0
		or raised_cliff_builder == null
		or raised_cliff_builder.palette == null
	):
		return
	var clipped_rects: Array[Rect2i] = []
	var top_rects: Array[Rect2i] = []
	var zone_bounds := Rect2i(Vector2i.ZERO, zone_size)
	for source_rect in rock_rects:
		var rect := source_rect.intersection(zone_bounds)
		if rect.size.x <= 0 or rect.size.y <= 0:
			continue
		clipped_rects.append(rect)
		var top_start_y := maxi(rect.position.y - BACK_OVERHANG_CELLS, 0)
		var face_start_y := maxi(
			rect.end.y - mini(FRONT_FACE_DEPTH_CELLS, rect.size.y),
			top_start_y + 1
		)
		top_rects.append(Rect2i(
			Vector2i(rect.position.x, top_start_y),
			Vector2i(rect.size.x, face_start_y - top_start_y)
		))
	area_count = clipped_rects.size()
	if clipped_rects.is_empty():
		return
	top_mesh = FOREST_GROUND_MESH_BUILDER_SCRIPT.build_mesh(
		top_rects,
		zone_size,
		logical_scale,
		TOP_TEXTURE_REPEAT_WORLD_SIZE
	)
	var internal_sides: Array[StringName] = []
	internal_sides.resize(clipped_rects.size())
	internal_sides.fill(&"internal")
	border_builder.build(
		top_rects,
		internal_sides,
		zone_size,
		logical_scale
	)
	_append_raised_front_tiles(clipped_rects, zone_size, logical_scale)
	raised_cliff_builder.build_meshes()

func has_geometry() -> bool:
	return (
		area_count > 0
		and top_mesh != null
		and get_face_mesh() != null
	)

func get_counts() -> Dictionary:
	return {
		"areas": area_count,
		"horizontal": (
			border_builder.horizontal_segment_count
			if border_builder != null
			else 0
		),
		"vertical": (
			border_builder.vertical_segment_count
			if border_builder != null
			else 0
		),
		"corners": border_builder.corner_count if border_builder != null else 0,
		"raised_tiles": (
			raised_cliff_builder.transition_count
			if raised_cliff_builder != null
			else 0
		),
		"raised_segments": _raised_segment_count(),
		"back_overhang_cells": BACK_OVERHANG_CELLS,
		"front_face_depth_cells": FRONT_FACE_DEPTH_CELLS,
		"cliff_tile_span_cells": CLIFF_TILE_SPAN_CELLS
	}

func get_horizontal_mesh() -> ArrayMesh:
	return border_builder.horizontal_mesh if border_builder != null else null

func get_vertical_mesh() -> ArrayMesh:
	return border_builder.vertical_mesh if border_builder != null else null

func get_face_mesh() -> ArrayMesh:
	return (
		raised_cliff_builder.face_mesh
		if raised_cliff_builder != null
		else null
	)

func get_lip_mesh() -> ArrayMesh:
	return (
		raised_cliff_builder.lip_mesh
		if raised_cliff_builder != null
		else null
	)

func get_upward_lines() -> PackedVector2Array:
	return (
		raised_cliff_builder.fissure_lines
		if raised_cliff_builder != null
		else PackedVector2Array()
	)

func _append_raised_front_tiles(
	rock_rects: Array[Rect2i],
	zone_size: Vector2i,
	logical_scale: float
) -> void:
	var zone_offset := Vector2(zone_size) * 0.5
	for rect in rock_rects:
		var face_depth := float(
			mini(FRONT_FACE_DEPTH_CELLS, rect.size.y)
		) * logical_scale
		var base_y := (
			float(rect.end.y) - zone_offset.y
		) * logical_scale
		for x in range(
			rect.position.x,
			rect.end.x,
			CLIFF_TILE_SPAN_CELLS
		):
			var tile_span := mini(CLIFF_TILE_SPAN_CELLS, rect.end.x - x)
			var half_w := float(tile_span) * logical_scale * 0.62
			var half_h := float(tile_span) * logical_scale * 0.34
			var tile_id := IsometricTileResolver.TILE_VOID_EDGE_SOUTH
			if x == rect.position.x:
				tile_id = IsometricTileResolver.TILE_VOID_CORNER_OUTER_SOUTH_WEST
			elif x + tile_span >= rect.end.x:
				tile_id = IsometricTileResolver.TILE_VOID_CORNER_OUTER_SOUTH_EAST
			var center := Vector2(
				(float(x) + float(tile_span) * 0.5 - zone_offset.x) * logical_scale,
				base_y - half_h
			)
			raised_cliff_builder.append_transition(
				tile_id,
				center,
				half_w,
				half_h,
				[],
				logical_scale,
				face_depth
			)

func _raised_segment_count() -> int:
	if raised_cliff_builder == null:
		return 0
	return int(raised_cliff_builder.fissure_lines.size() / 4)
