extends RefCounted
class_name RockCliffTopologyResolver

## Shared semantic contract for the externally-authored Plains rock atlases.
## Geometry remains cardinal and deterministic; this resolver only maps
## topology to authored atlas roles and marks direct mesa-to-void contacts.

const WALL_ROLES: Array[StringName] = [
	&"edge_north", &"edge_east", &"edge_south", &"edge_west",
	&"convex_north_east", &"convex_south_east",
	&"convex_south_west", &"convex_north_west",
	&"concave_north_east", &"concave_south_east",
	&"concave_south_west", &"concave_north_west",
	&"diagonal_north_east_south_west",
	&"diagonal_north_west_south_east",
	&"cap_horizontal", &"cap_vertical",
]

const TOP_ROLES: Array[StringName] = [
	&"convex_north_east", &"convex_south_east",
	&"convex_south_west", &"convex_north_west",
	&"edge_north", &"edge_east", &"edge_south", &"edge_west",
	&"concave_north_east", &"concave_south_east",
	&"concave_south_west", &"concave_north_west",
	&"center_01", &"center_02", &"center_03", &"center_04",
]

const MOUNTAIN_CONTACT_KEY: StringName = &"mountain_contact"
const MOUNTAIN_INDEX_KEY: StringName = &"mountain_index"

enum VertexQuadrant {
	NORTH_WEST = 1,
	NORTH_EAST = 2,
	SOUTH_EAST = 4,
	SOUTH_WEST = 8,
}

static func annotate_mountain_contacts(
	boundary_runs: Array[Dictionary],
	mesa_rects: Array[Rect2i]
) -> void:
	var annotated: Array[Dictionary] = []
	for source_run in boundary_runs:
		var run := source_run.duplicate(true)
		run[MOUNTAIN_CONTACT_KEY] = false
		run[MOUNTAIN_INDEX_KEY] = -1
		if StringName(run.get("orientation", &"")) != FallZoneBoundaryRuns.TOP:
			annotated.append(run)
			continue
		var boundary_y := int(run.get("boundary", -1))
		var start_x := int(run.get("start", -1))
		var end_x := int(run.get("end", -1))
		var cuts: Array[int] = [start_x, end_x]
		for mesa in mesa_rects:
			if mesa.end.y != boundary_y:
				continue
			var overlap_start := maxi(start_x, mesa.position.x)
			var overlap_end := mini(end_x, mesa.end.x)
			if overlap_start < overlap_end:
				if not cuts.has(overlap_start):
					cuts.append(overlap_start)
				if not cuts.has(overlap_end):
					cuts.append(overlap_end)
		cuts.sort()
		for cut_index in range(cuts.size() - 1):
			var segment_start := cuts[cut_index]
			var segment_end := cuts[cut_index + 1]
			if segment_start >= segment_end:
				continue
			var segment := run.duplicate(true)
			segment["start"] = segment_start
			segment["end"] = segment_end
			if segment_start != start_x:
				segment["start_corner"] = FallZoneBoundaryRuns.CORNER_STRAIGHT
			if segment_end != end_x:
				segment["end_corner"] = FallZoneBoundaryRuns.CORNER_STRAIGHT
			for mesa_index in range(mesa_rects.size()):
				var mesa := mesa_rects[mesa_index]
				if (
					mesa.end.y == boundary_y
					and mesa.position.x <= segment_start
					and mesa.end.x >= segment_end
				):
					segment[MOUNTAIN_CONTACT_KEY] = true
					segment[MOUNTAIN_INDEX_KEY] = mesa_index
					break
			annotated.append(segment)
	boundary_runs.clear()
	boundary_runs.append_array(annotated)

static func is_mountain_contact(run: Dictionary) -> bool:
	return bool(run.get(MOUNTAIN_CONTACT_KEY, false))

static func wall_role_for_run(run: Dictionary) -> StringName:
	var orientation := StringName(run.get("orientation", &""))
	match orientation:
		FallZoneBoundaryRuns.TOP:
			return &"edge_north"
		FallZoneBoundaryRuns.BOTTOM:
			return &"edge_south"
		FallZoneBoundaryRuns.LEFT:
			return &"edge_west"
		FallZoneBoundaryRuns.RIGHT:
			return &"edge_east"
	return &"cap_horizontal"

static func cap_role_for_orientation(orientation: StringName) -> StringName:
	if orientation in [FallZoneBoundaryRuns.TOP, FallZoneBoundaryRuns.BOTTOM]:
		return &"cap_horizontal"
	return &"cap_vertical"

## Classifies the four terrain quadrants that meet at one grid vertex. This is
## the canonical source for convex/concave/diagonal modules; rectangles joined
## into L, T or cross silhouettes are therefore composed without special-case
## sprites and without emitting an edge between two occupied cells.
static func wall_role_for_vertex_mask(mask: int) -> StringName:
	match mask & 0xF:
		VertexQuadrant.NORTH_WEST:
			return &"convex_north_west"
		VertexQuadrant.NORTH_EAST:
			return &"convex_north_east"
		VertexQuadrant.SOUTH_EAST:
			return &"convex_south_east"
		VertexQuadrant.SOUTH_WEST:
			return &"convex_south_west"
		14:
			return &"concave_north_west"
		13:
			return &"concave_north_east"
		11:
			return &"concave_south_east"
		7:
			return &"concave_south_west"
		3:
			return &"edge_south"
		6:
			return &"edge_west"
		12:
			return &"edge_north"
		9:
			return &"edge_east"
		5:
			return &"diagonal_north_west_south_east"
		10:
			return &"diagonal_north_east_south_west"
	return &""

static func vertex_mask_for_cells(
	occupied_cells: Dictionary,
	vertex: Vector2i
) -> int:
	var mask := 0
	if occupied_cells.has(vertex + Vector2i(-1, -1)):
		mask |= VertexQuadrant.NORTH_WEST
	if occupied_cells.has(vertex + Vector2i(0, -1)):
		mask |= VertexQuadrant.NORTH_EAST
	if occupied_cells.has(vertex):
		mask |= VertexQuadrant.SOUTH_EAST
	if occupied_cells.has(vertex + Vector2i(-1, 0)):
		mask |= VertexQuadrant.SOUTH_WEST
	return mask

static func top_role_for_cell(
	cell: Vector2i,
	size: Vector2i,
	generation_seed: int = 0
) -> StringName:
	if size.x <= 0 or size.y <= 0:
		return &"center_01"
	var at_west := cell.x <= 0
	var at_east := cell.x >= size.x - 1
	var at_north := cell.y <= 0
	var at_south := cell.y >= size.y - 1
	if at_north and at_east:
		return &"convex_north_east"
	if at_south and at_east:
		return &"convex_south_east"
	if at_south and at_west:
		return &"convex_south_west"
	if at_north and at_west:
		return &"convex_north_west"
	if at_north:
		return &"edge_north"
	if at_east:
		return &"edge_east"
	if at_south:
		return &"edge_south"
	if at_west:
		return &"edge_west"
	var variant := posmod(
		("%d|%d|%d|mountain_top" % [generation_seed, cell.x, cell.y]).hash(),
		4
	)
	return TOP_ROLES[12 + variant]
