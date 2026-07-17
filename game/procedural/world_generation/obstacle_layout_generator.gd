extends RefCounted
class_name ObstacleLayoutGenerator

const WorldGridConfig = preload("res://game/core/world_grid_config.gd")
const MESA_PLACEMENT_PASS = preload(
	"res://game/procedural/world_generation/passes/mesa_placement_pass.gd"
)
const STATIC_HAZARD_PLACEMENT_PASS = preload(
	"res://game/procedural/world_generation/passes/static_hazard_placement_pass.gd"
)
const RANDOM_PROP_PLACEMENT_PASS = preload(
	"res://game/procedural/world_generation/passes/random_prop_placement_pass.gd"
)
const TERRAIN_PARCEL_PARTITION_PASS = preload(
	"res://game/procedural/world_generation/passes/terrain_parcel_partition_pass.gd"
)
const TERRAIN_PARCEL_CONTENT_PASS = preload(
	"res://game/procedural/world_generation/passes/terrain_parcel_content_pass.gd"
)
const TERRAIN_ROUTE_PASS = preload(
	"res://game/procedural/world_generation/passes/terrain_route_pass.gd"
)

const ROAD_WIDTH := WorldGridConfig.ROAD_WIDTH_TILES
const SECONDARY_ROAD_WIDTH := WorldGridConfig.SECONDARY_ROAD_WIDTH_TILES
const BORDER_THICKNESS := WorldGridConfig.BORDER_THICKNESS_TILES
# Perimeter walls are tiled as a contiguous run of segments so the whole side
# reads as a continuous cardinal wall instead of a single centred sprite.
const WALL_SEGMENT_LENGTH := WorldGridConfig.WALL_SEGMENT_LENGTH_TILES
const WALL_MIN_SEGMENT := WorldGridConfig.WALL_MIN_SEGMENT_TILES
# Small thematic props scattered inside internal blocks for ambient detail.
const MAX_BLOCK_PROPS := 64
const PROP_BLOCK_MARGIN := WorldGridConfig.PROP_BLOCK_MARGIN_TILES
const MIN_RECT_GAP := WorldGridConfig.MIN_RECT_GAP_TILES
const BLOCK_INSET := 0
const MIN_BLOCK_SIZE := WorldGridConfig.MIN_BLOCK_SIZE_TILES
const STARTER_RIVER_WIDTH := WorldGridConfig.STARTER_RIVER_WIDTH_TILES
const STARTER_BRIDGE_EXTRA_WIDTH := WorldGridConfig.STARTER_BRIDGE_EXTRA_WIDTH_TILES

# --- Void-first generation (rocks -> forests -> roads -> tree borders -> void
# lottery). The chunk starts as pure void and each pass carves into it. ---
const VOIDFIRST_ROCK_MIN_SIZE := WorldGridConfig.VOIDFIRST_ROCK_MIN_SIZE_TILES
const VOIDFIRST_ROCK_MAX_SIZE := WorldGridConfig.VOIDFIRST_ROCK_MAX_SIZE_TILES
const VOIDFIRST_ROCK_MIN_COUNT := 10
const VOIDFIRST_ROCK_MAX_COUNT := 16
const VOIDFIRST_ROCK_GAP := WorldGridConfig.VOIDFIRST_ROCK_GAP_TILES
const VOIDFIRST_ROCK_MARGIN := WorldGridConfig.VOIDFIRST_ROCK_MARGIN_TILES
const VOIDFIRST_ROCK_ATTEMPTS := 600
# Real mesas use the same proven 3..5-cell footprint as the original plains
# plateaus. Plains retain their historical density; advanced biomes use a lower
# shared budget alongside their thematic solid masses.
const VOIDFIRST_MESA_MIN_COUNT := MESA_PLACEMENT_PASS.MIN_COUNT
const VOIDFIRST_MESA_MAX_COUNT := MESA_PLACEMENT_PASS.MAX_COUNT
const VOIDFIRST_FOREST_MIN_SIZE := WorldGridConfig.VOIDFIRST_FOREST_MIN_SIZE_TILES
const VOIDFIRST_FOREST_MAX_SIZE := WorldGridConfig.VOIDFIRST_FOREST_MAX_SIZE_TILES
const VOIDFIRST_FOREST_MIN_COUNT := 4
const VOIDFIRST_FOREST_MAX_COUNT := 7
const VOIDFIRST_FOREST_ATTEMPTS := 120
const VOIDFIRST_FOREST_EDGE_MARGIN := WorldGridConfig.VOIDFIRST_FOREST_EDGE_MARGIN_TILES
# Trees fill a forest on a jittered grid; spacing > footprint keeps walkable gaps
# between trunks so roads/paths can cross and zombies can navigate the interior.
const VOIDFIRST_TREE_SPACING := WorldGridConfig.VOIDFIRST_TREE_SPACING_TILES
const VOIDFIRST_TREE_JITTER := WorldGridConfig.VOIDFIRST_TREE_JITTER_TILES
const VOIDFIRST_MAX_TREES := 240
# Roads route on a coarse grid (cell = step logical cells) that treats rocks as
# solid, so the carved corridor goes around rocks and through forests.
const VOIDFIRST_ROUTE_STEP := WorldGridConfig.VOIDFIRST_ROUTE_STEP_TILES
const VOIDFIRST_ROAD_ROCK_CLEARANCE := WorldGridConfig.VOIDFIRST_ROAD_ROCK_CLEARANCE_TILES
# Trails (sentieri) are narrow routes that cross forests but stop at the first rock.
const VOIDFIRST_PATH_WIDTH := WorldGridConfig.VOIDFIRST_PATH_WIDTH_TILES
const VOIDFIRST_PATH_MAX_LEN := WorldGridConfig.VOIDFIRST_PATH_MAX_LEN_TILES
const VOIDFIRST_PATH_COUNT := 3
# Roads crossing open void get a tree lining where they are not already bounded by
# a rock or forest ("confine").
const VOIDFIRST_ROAD_LINE_SPACING := WorldGridConfig.VOIDFIRST_ROAD_LINE_SPACING_TILES
const VOIDFIRST_ROAD_LINE_NEAR := WorldGridConfig.VOIDFIRST_ROAD_LINE_NEAR_TILES
const VOIDFIRST_ROAD_LINE_CONFINE := WorldGridConfig.VOIDFIRST_ROAD_LINE_CONFINE_TILES
const VOIDFIRST_MAX_LINE_TREES := 220
# Void lottery: the leftover void is split into floor / chasm patches at a fixed
# ratio of 1 chasm : 3 walkable. The route clearance leaves room for the cliff
# lip without letting its ground material overlap roads or passage tiles.
const VOIDFIRST_VOID_PATCH := WorldGridConfig.VOIDFIRST_VOID_PATCH_TILES
const VOIDFIRST_VOID_CHASM_DIVISOR := 4
const VOIDFIRST_CHASM_ROUTE_CLEARANCE := (
	WorldGridConfig.VOIDFIRST_CHASM_ROUTE_CLEARANCE_TILES
)

# Final-floor random props. They are intentionally much sparser than cluster
# vegetation and have their own deterministic stream, so tuning the prop pool
# cannot move roads, mesas or chasms for an existing seed.
const VOIDFIRST_PROP_MIN_COUNT := RANDOM_PROP_PLACEMENT_PASS.MIN_COUNT
const VOIDFIRST_PROP_MAX_COUNT := RANDOM_PROP_PLACEMENT_PASS.MAX_COUNT
const VOIDFIRST_PROP_ATTEMPTS := RANDOM_PROP_PLACEMENT_PASS.ATTEMPTS
const VOIDFIRST_PROP_BORDER_MARGIN := RANDOM_PROP_PLACEMENT_PASS.BORDER_MARGIN
const VOIDFIRST_PROP_SPAWN_CLEARANCE := RANDOM_PROP_PLACEMENT_PASS.SPAWN_CLEARANCE
# Static biome hazards are placed only after the void/floor lottery, so their
# footprint is validated against the final terrain. The first two eligible IDs
# in each BiomeDefinition reproduce the authored thematic pair without copying
# layout coordinates from the legacy pipeline.
const VOIDFIRST_HAZARD_MAX_COUNT := STATIC_HAZARD_PLACEMENT_PASS.MAX_COUNT
const VOIDFIRST_HAZARD_ATTEMPTS_PER_ID := STATIC_HAZARD_PLACEMENT_PASS.ATTEMPTS_PER_ID
const VOIDFIRST_HAZARD_BORDER_MARGIN := STATIC_HAZARD_PLACEMENT_PASS.BORDER_MARGIN
const VOIDFIRST_HAZARD_ROUTE_CLEARANCE := STATIC_HAZARD_PLACEMENT_PASS.ROUTE_CLEARANCE
const VOIDFIRST_HAZARD_SPAWN_CLEARANCE := STATIC_HAZARD_PLACEMENT_PASS.SPAWN_CLEARANCE
const VOIDFIRST_HAZARD_SIZE_BY_ID: Dictionary = (
	STATIC_HAZARD_PLACEMENT_PASS.FALLBACK_SIZE_BY_ID
)
const RNG_STREAM_SALTS: Dictionary = {
	&"mesa": 0x13579BDF,
	&"void": 0x2468ACE,
	&"hazards": 0x31415927,
	&"props": 0x5A17C9E3,
	&"parcels": 0x6B8B4567,
	&"parcel_content": 0x327B23C6,
}

const GENERATED_OBSTACLE_CATEGORIES: Dictionary = {
	&"abandoned_car": &"wreck",
	&"abandoned_house": &"building",
	&"ash_barrier": &"barrier",
	&"boundary_fence": &"border",
	&"broken_fence": &"barrier",
	&"broken_walkway": &"bridge",
	&"burned_car": &"wreck",
	&"burned_house": &"building",
	&"charred_wall": &"barrier",
	&"chemical_barrel": &"barrel",
	&"corroded_barrier": &"barrier",
	&"dead_tree": &"tree",
	&"dense_vegetation": &"dense_vegetation",
	&"deep_water_boundary": &"border",
	&"fallen_log": &"log",
	&"forest_tree": &"tree",
	&"ice_boundary": &"border",
	&"ice_block": &"rock",
	&"ice_rock": &"rock",
	&"industrial_fence": &"barrier",
	&"lab_block": &"building",
	&"lab_ruin": &"building",
	&"lab_wall": &"barrier",
	&"large_rock": &"rock",
	&"lava_boundary": &"border",
	&"marsh_log": &"log",
	&"metal_wreck": &"wreck",
	&"pipe_stack": &"barrier",
	&"reed_wall": &"barrier",
	&"ruined_house": &"building",
	&"small_rock": &"rock",
	&"snow_cabin": &"building",
	&"snow_wall": &"barrier",
	&"scorched_barricade": &"barrier",
	&"sunken_house": &"building",
	&"sunken_wreck": &"wreck",
	&"toxic_barrel": &"barrel",
	&"toxic_boundary_wall": &"border",
	&"wood_barrier": &"barrier"
}
const GENERATED_TERRAIN_TAG_CATEGORIES: Dictionary = {
	&"ash_lane": &"road",
	&"broken_street": &"road",
	&"main_road": &"road",
	&"packed_snow_path": &"road",
	&"service_lane": &"road",
	&"wooden_walkway": &"road"
}

static func get_generated_obstacle_categories() -> Dictionary:
	return GENERATED_OBSTACLE_CATEGORIES.duplicate()

static func get_generated_terrain_tag_categories() -> Dictionary:
	return GENERATED_TERRAIN_TAG_CATEGORIES.duplicate()

func populate_layout(
	layout: BiomeEnvironmentLayout,
	cell: BiomeCell,
	biome: BiomeDefinition,
	context: Dictionary = {}
) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = maxi(cell.seed, 1)
	var allow_internal_void := _internal_void_enabled(context)
	_add_roads(layout, cell)
	_add_biome_navigation_features(layout, biome, rng)
	_add_internal_blocks(layout, biome, rng, allow_internal_void)
	_add_starter_water_crossing(layout, biome, rng)
	_add_large_obstacles(layout, biome, rng)
	_add_secondary_obstacles(layout, biome, rng)
	_add_starter_roadside_details(layout, biome, rng)
	_add_connected_border_walls(layout, cell, biome, context)
	_add_crates(layout, biome)
	_add_theme_hazards(layout, biome)
	_add_block_props(layout, biome, rng)
	_ensure_starter_house_obstacle(layout, biome, rng)
	_ensure_starter_dense_obstacle(layout, biome, rng)
	_ensure_starter_3x3_obstacles(layout, biome)
	_update_generation_summary(layout, biome)

# Void-first pipeline orchestrator. Grown one milestone at a time; the chunk
# starts as pure void and each pass carves into it:
#   passages -> rocks -> forests -> roads/paths -> road tree borders -> void lottery
# Roads use a single unified "hub + spokes" model for both survival and the
# Infinite Arena (see _add_voidfirst_roads): inter-biome passages and arena walls
# are both treated as exits the central network connects to.
func populate_layout_voidfirst(
	layout: BiomeEnvironmentLayout,
	cell: BiomeCell,
	biome: BiomeDefinition,
	context: Dictionary = {}
) -> void:
	var parcel_rng := _make_rng_stream(cell.seed, &"parcels")
	var content_rng := _make_rng_stream(cell.seed, &"parcel_content")
	var hazard_rng := _make_rng_stream(cell.seed, &"hazards")
	var palette := _voidfirst_palette(biome.biome_id)
	# TERRAIN-PARCELS-001: routes are authoritative and are carved before any
	# obstacle or hazard. Secondary trails then partition the untouched floor.
	var route_report: Dictionary = TERRAIN_ROUTE_PASS.new().generate(
		layout,
		cell,
		context,
		palette["road_tag"] as StringName,
		palette["spoke_tag"] as StringName
	)
	var parcel_report: Dictionary = TERRAIN_PARCEL_PARTITION_PASS.new().generate(
		layout, biome, parcel_rng, palette["spoke_tag"] as StringName
	)
	var parcel_content: Dictionary = TERRAIN_PARCEL_CONTENT_PASS.new().populate(
		layout, biome, content_rng, palette["spoke_tag"] as StringName
	)
	_add_connected_border_walls(layout, cell, biome, context)
	_place_voidfirst_theme_hazards(layout, biome, hazard_rng)
	_add_voidfirst_crates(layout, biome)
	_update_generation_summary(layout, biome)
	layout.generation_summary["parcel_report"] = parcel_report
	layout.generation_summary["parcel_content"] = parcel_content
	layout.generation_summary["route_report"] = route_report

func _make_rng_stream(seed: int, stream_id: StringName) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	var salt := int(RNG_STREAM_SALTS.get(stream_id, 1))
	# Keep the derived seed positive/non-zero without relying on engine hash order.
	rng.seed = maxi((absi(seed) ^ salt) & 0x7FFFFFFF, 1)
	return rng

# Place crates on the road cross around the spawn so they are always walkable and
# comfortably reachable from the party start.
func _add_voidfirst_crates(
	layout: BiomeEnvironmentLayout,
	biome: BiomeDefinition
) -> void:
	var crate_ids := _crate_ids(biome.biome_id)
	var anchor := layout.player_spawn_cell
	var offsets: Array[Vector2i] = [
		Vector2i(-WorldGridConfig.VOIDFIRST_CRATE_OFFSET_TILES, 0),
		Vector2i(WorldGridConfig.VOIDFIRST_CRATE_OFFSET_TILES, 0),
		Vector2i(0, -WorldGridConfig.VOIDFIRST_CRATE_OFFSET_TILES),
		Vector2i(0, WorldGridConfig.VOIDFIRST_CRATE_OFFSET_TILES)
	]
	for index in range(offsets.size()):
		_add_crate(layout, crate_ids[index % crate_ids.size()], anchor + offsets[index])

# Place the static environmental identity of advanced biomes on final walkable
# floor. Hazards never occupy routes, passages, blockers, cliff lips or the
# protected spawn area; later crates and random props therefore see them as
# already-reserved terrain.
func _place_voidfirst_theme_hazards(
	layout: BiomeEnvironmentLayout,
	biome: BiomeDefinition,
	rng: RandomNumberGenerator
) -> int:
	return STATIC_HAZARD_PLACEMENT_PASS.new().place(layout, biome, rng)

# Final-floor prop pass. Unlike the earlier mass/cluster passes, these objects are
# sparse ambient landmarks and cover chosen from weighted biome pools. Membership
# is recorded explicitly for testing, snapshots and future persistence.
func _place_voidfirst_random_props(
	layout: BiomeEnvironmentLayout,
	biome: BiomeDefinition,
	rng: RandomNumberGenerator
) -> int:
	return RANDOM_PROP_PLACEMENT_PASS.new().place(
		layout,
		biome,
		rng,
		GENERATED_OBSTACLE_CATEGORIES
	)

func _voidfirst_center_reserved(layout: BiomeEnvironmentLayout) -> Rect2i:
	# Keep the chunk centre clear of rocks so the main-road cross, player spawn and
	# crates always sit on walkable road.
	var center := layout.zone_size / 2
	var half := WorldGridConfig.CENTER_RESERVED_HALF_TILES
	return Rect2i(center - Vector2i(half, half), Vector2i(half * 2, half * 2))

# Pick a guaranteed-walkable spawn: the centre if it is road, else the nearest
# road cell to the centre.
func _choose_voidfirst_spawn(layout: BiomeEnvironmentLayout) -> void:
	var center := layout.zone_size / 2
	if layout.has_road_cell(center):
		layout.player_spawn_cell = center
		return
	var limit := maxi(layout.zone_size.x, layout.zone_size.y)
	for radius in range(1, limit):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if absi(dx) != radius and absi(dy) != radius:
					continue
				var candidate := center + Vector2i(dx, dy)
				if layout.has_road_cell(candidate):
					layout.player_spawn_cell = candidate
					return

# Carve the mandatory inter-biome passage corridors as walkable connectors so the
# later rock/forest passes avoid them and the road router can hook onto them.
func _carve_passages(layout: BiomeEnvironmentLayout, cell: BiomeCell) -> void:
	var zone_size := layout.zone_size
	for passage in cell.passages:
		var passage_rect := passage.get_local_rect(zone_size)
		layout.passage_rects.append(passage_rect)
		var connector_rect := passage.get_connector_rect(zone_size)
		layout.passage_connector_rects.append(connector_rect)
		_add_road_rect(layout, passage_rect, passage.passage_type)
		_add_road_rect(layout, connector_rect, passage.passage_type)

# M1a - place real square mesas on every biome's void canvas. The rectangle is
# the terrain-volume authority; `large_rock` is a collision-only scalable blocker
# at runtime. Plains mirrors the same rects into rock_rects for legacy consumers.
func _place_mesas(
	layout: BiomeEnvironmentLayout,
	biome: BiomeDefinition,
	rng: RandomNumberGenerator
) -> int:
	return MESA_PLACEMENT_PASS.new().place(layout, biome, rng)

# M1b - advanced biomes also scatter natural-footprint thematic objects as
# solid masses. They are explicitly separate from mesa geometry.
func _place_biome_masses(
	layout: BiomeEnvironmentLayout,
	biome: BiomeDefinition,
	rng: RandomNumberGenerator
) -> int:
	var palette := _voidfirst_palette(biome.biome_id)
	if bool(palette["rock_scalable"]):
		return 0
	return _scatter_biome_masses(layout, rng, palette["scatter_ids"])

func _scatter_biome_masses(
	layout: BiomeEnvironmentLayout,
	rng: RandomNumberGenerator,
	scatter_ids: Array
) -> int:
	if scatter_ids.is_empty():
		return 0
	var target := rng.randi_range(VOIDFIRST_ROCK_MIN_COUNT, VOIDFIRST_ROCK_MAX_COUNT)
	var placed := 0
	var attempts := 0
	var lo := BORDER_THICKNESS + VOIDFIRST_ROCK_MARGIN
	while placed < target and attempts < VOIDFIRST_ROCK_ATTEMPTS:
		attempts += 1
		var obstacle_id := scatter_ids[rng.randi_range(0, scatter_ids.size() - 1)] as StringName
		var footprint := _logical_footprint_tiles(obstacle_id)
		if footprint.x <= 0 or footprint.y <= 0:
			continue
		var hi_x := layout.zone_size.x - lo - footprint.x
		var hi_y := layout.zone_size.y - lo - footprint.y
		if hi_x <= lo or hi_y <= lo:
			continue
		var rect := Rect2i(
			Vector2i(rng.randi_range(lo, hi_x), rng.randi_range(lo, hi_y)),
			footprint
		)
		var padded := GeometryUtils.inflate_rect(rect, VOIDFIRST_ROCK_GAP)
		if padded.intersects(_voidfirst_center_reserved(layout)):
			continue
		if layout.rect_overlaps_passage_corridor(padded):
			continue
		if GeometryUtils.intersects_any(padded, layout.mesa_rects):
			continue
		if GeometryUtils.intersects_any(padded, layout.mass_rects):
			continue
		layout.mass_rects.append(rect)
		_add_obstacle(layout, obstacle_id, rect, &"rectangle", 0.0)
		placed += 1
	return placed

# M2 — place square forests (side 9..60). Each forest is a walkable floor patch
# (forest_tall_grass) filled with natural-size forest_tree obstacles on a jittered
# grid. Trees never land on a rock (rock wins) and spacing leaves walkable gaps so
# the interior stays traversable.
func _place_forests(
	layout: BiomeEnvironmentLayout,
	biome: BiomeDefinition,
	rng: RandomNumberGenerator
) -> int:
	var palette := _voidfirst_palette(biome.biome_id)
	var floor_tag := palette["cluster_floor"] as StringName
	var cluster_id := palette["cluster_id"] as StringName
	var count := rng.randi_range(VOIDFIRST_FOREST_MIN_COUNT, VOIDFIRST_FOREST_MAX_COUNT)
	var placed := 0
	var attempts := 0
	var lo := BORDER_THICKNESS + VOIDFIRST_FOREST_EDGE_MARGIN
	while placed < count and attempts < VOIDFIRST_FOREST_ATTEMPTS:
		attempts += 1
		var side := rng.randi_range(VOIDFIRST_FOREST_MIN_SIZE, VOIDFIRST_FOREST_MAX_SIZE)
		var hi_x := layout.zone_size.x - lo - side
		var hi_y := layout.zone_size.y - lo - side
		if hi_x <= lo or hi_y <= lo:
			continue
		var rect := Rect2i(
			Vector2i(rng.randi_range(lo, hi_x), rng.randi_range(lo, hi_y)),
			Vector2i(side, side)
		)
		layout.forest_rects.append(rect)
		layout.add_floor_rect(rect, floor_tag)
		placed += 1
	_fill_forests_with_trees(layout, rng, cluster_id)
	return placed

func _fill_forests_with_trees(
	layout: BiomeEnvironmentLayout,
	rng: RandomNumberGenerator,
	cluster_id: StringName
) -> int:
	var footprint := _logical_footprint_tiles(cluster_id)
	var tree_count := 0
	for forest_rect in layout.forest_rects:
		if tree_count >= VOIDFIRST_MAX_TREES:
			break
		var max_x := forest_rect.end.x - footprint.x - VOIDFIRST_FOREST_EDGE_MARGIN
		var max_y := forest_rect.end.y - footprint.y - VOIDFIRST_FOREST_EDGE_MARGIN
		var min_x := forest_rect.position.x + VOIDFIRST_FOREST_EDGE_MARGIN
		var min_y := forest_rect.position.y + VOIDFIRST_FOREST_EDGE_MARGIN
		var y := min_y
		while y <= max_y:
			var x := min_x
			while x <= max_x:
				if tree_count >= VOIDFIRST_MAX_TREES:
					break
				var pos := Vector2i(
					clampi(x + rng.randi_range(-VOIDFIRST_TREE_JITTER, VOIDFIRST_TREE_JITTER), min_x, max_x),
					clampi(y + rng.randi_range(-VOIDFIRST_TREE_JITTER, VOIDFIRST_TREE_JITTER), min_y, max_y)
				)
				var rect := Rect2i(pos, footprint)
				if _can_place_tree(layout, rect):
					_add_obstacle(layout, cluster_id, rect, &"rectangle", 0.0)
					tree_count += 1
				x += VOIDFIRST_TREE_SPACING
			y += VOIDFIRST_TREE_SPACING
	return tree_count

# A tree may be placed only on a clear cell: never overlapping an existing
# obstacle (rocks win, and trees never stack) nor a passage corridor.
func _can_place_tree(layout: BiomeEnvironmentLayout, rect: Rect2i) -> bool:
	if rect.intersects(_voidfirst_center_reserved(layout)):
		return false
	if GeometryUtils.intersects_any(rect, layout.obstacle_rects):
		return false
	if layout.rect_overlaps_passage_corridor(rect):
		return false
	return true

# M3 — build the region's road backbone with a single unified "hub + spokes"
# model. The network connects the chunk centre to one spoke per "exit", where an
# exit is either:
#   - an inter-biome passage (survival megamap → the roads "depend on the
#     neighbours": one broken_street spoke routes from each passage to the centre);
#   - or an arena wall (the walled Infinite Arena → each of the four enclosing
#     walls becomes a main_road spoke to its mid-point, and the four together form
#     the classic edge-to-edge cross).
# "Wall = neighbour" is what lets both modes share one code path: the cross is just
# the degenerate case where every side is a wall. A fully isolated region with
# neither passages nor walls (e.g. a standalone unit-test cell) falls back to the
# four wall mid-points so it is never roadless.
#
# The central hub plaza is carved only when passages converge on it (it gives the
# converging corridors a shared walkable node); the pure wall-cross needs none,
# since its spokes already meet at the centre. The old fixed edge-to-edge cross was
# dropped for connected regions because, with passages at random border positions,
# its arms dead-ended at empty borders and ran parallel to the passage corridors,
# reading as two overlapping roads — the spoke model avoids that by construction.
func _add_voidfirst_roads(
	layout: BiomeEnvironmentLayout,
	_rng: RandomNumberGenerator,
	cell: BiomeCell,
	context: Dictionary,
	palette: Dictionary
) -> void:
	var spokes := _collect_road_spokes(layout, cell, context, palette)
	if spokes.is_empty():
		return
	var has_passage_spoke := false
	for spoke in spokes:
		if bool(spoke.get("is_passage", false)):
			has_passage_spoke = true
			break
	if has_passage_spoke:
		_carve_center_hub(layout, palette["road_tag"])
	var astar := _build_road_astar(layout)
	var center := layout.zone_size / 2
	for spoke in spokes:
		_carve_astar_road(
			layout,
			astar,
			spoke["anchor"] as Vector2i,
			center,
			spoke["tag"] as StringName
		)

# One road spoke per region exit (see _add_voidfirst_roads): every passage becomes
# a broken_street spoke to its inner anchor, and — when the region is a walled
# arena — every border without a passage becomes a main_road spoke to its
# mid-point. With no exits at all the region is treated as fully walled (fallback
# cross) so it always has through-roads and a walkable centre.
func _collect_road_spokes(
	layout: BiomeEnvironmentLayout,
	cell: BiomeCell,
	context: Dictionary,
	palette: Dictionary
) -> Array[Dictionary]:
	var spokes: Array[Dictionary] = []
	var covered_sides: Dictionary = {}
	for passage in cell.passages:
		spokes.append({
			"anchor": passage.edge_anchor_cell(layout.zone_size),
			"tag": palette["spoke_tag"] as StringName,
			"is_passage": true
		})
		covered_sides[passage.side] = true
	if _is_walled_arena_context(context):
		spokes.append_array(_wall_spokes(layout, covered_sides, palette["road_tag"]))
	if spokes.is_empty():
		spokes = _wall_spokes(layout, covered_sides, palette["road_tag"])
	return spokes

# A main_road spoke to the mid-point of every border not already served by a
# passage. The four of them together carve the edge-to-edge cross.
func _wall_spokes(
	layout: BiomeEnvironmentLayout,
	covered_sides: Dictionary,
	road_tag: StringName
) -> Array[Dictionary]:
	var spokes: Array[Dictionary] = []
	for side in BiomeCell.SIDES:
		if covered_sides.has(side):
			continue
		spokes.append({
			"anchor": _wall_midpoint_anchor(layout, side),
			"tag": road_tag,
			"is_passage": false
		})
	return spokes

func _wall_midpoint_anchor(
	layout: BiomeEnvironmentLayout,
	side: StringName
) -> Vector2i:
	var mid := layout.zone_size / 2
	match side:
		&"north":
			return Vector2i(mid.x, BORDER_THICKNESS)
		&"south":
			return Vector2i(mid.x, layout.zone_size.y - BORDER_THICKNESS - 1)
		&"west":
			return Vector2i(BORDER_THICKNESS, mid.y)
		_:
			return Vector2i(layout.zone_size.x - BORDER_THICKNESS - 1, mid.y)

# Central hub plaza: a compact walkable square at the chunk centre, registered both
# as a road rect (route metadata/rendering) and as per-cell road tags so the spawn
# picker, walkability classification and the tile resolver all see the centre as
# walkable road that the passage spokes hook onto.
func _carve_center_hub(layout: BiomeEnvironmentLayout, road_tag: StringName) -> void:
	var hub := _voidfirst_center_reserved(layout)
	_add_road_rect(layout, hub, road_tag)
	for hub_y in range(hub.position.y, hub.end.y):
		for hub_x in range(hub.position.x, hub.end.x):
			layout.add_road_cell(Vector2i(hub_x, hub_y), road_tag)

func _build_road_astar(layout: BiomeEnvironmentLayout) -> AStarGrid2D:
	var step := VOIDFIRST_ROUTE_STEP
	var w := int(ceil(float(layout.zone_size.x) / float(step)))
	var h := int(ceil(float(layout.zone_size.y) / float(step)))
	var astar := AStarGrid2D.new()
	astar.region = Rect2i(0, 0, w, h)
	astar.cell_size = Vector2.ONE
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.update()
	for solid_rect in _voidfirst_solid_rects(layout):
		var inflated := GeometryUtils.inflate_rect(solid_rect, VOIDFIRST_ROAD_ROCK_CLEARANCE)
		var c0 := _to_coarse_cell(inflated.position, step, w, h)
		var c1 := _to_coarse_cell(inflated.end - Vector2i.ONE, step, w, h)
		for cy in range(c0.y, c1.y + 1):
			for cx in range(c0.x, c1.x + 1):
				astar.set_point_solid(Vector2i(cx, cy), true)
	return astar

func _carve_astar_road(
	layout: BiomeEnvironmentLayout,
	astar: AStarGrid2D,
	start_full: Vector2i,
	end_full: Vector2i,
	tag: StringName
) -> void:
	var step := VOIDFIRST_ROUTE_STEP
	var region := astar.region
	var start_c := _nearest_open_coarse(astar, _to_coarse_cell(start_full, step, region.size.x, region.size.y))
	var end_c := _nearest_open_coarse(astar, _to_coarse_cell(end_full, step, region.size.x, region.size.y))
	if start_c.x < 0 or end_c.x < 0:
		_add_cardinal_road(layout, start_full, end_full, ROAD_WIDTH, tag)
		return
	var path := astar.get_id_path(start_c, end_c)
	if path.is_empty():
		_add_cardinal_road(layout, start_full, end_full, ROAD_WIDTH, tag)
		return
	var prev := start_full
	for coarse_cell in path:
		var center := Vector2i(
			coarse_cell.x * step + step / 2,
			coarse_cell.y * step + step / 2
		)
		_add_cardinal_road(layout, prev, center, ROAD_WIDTH, tag)
		prev = center
	_add_cardinal_road(layout, prev, end_full, ROAD_WIDTH, tag)

func _to_coarse_cell(point: Vector2i, step: int, w: int, h: int) -> Vector2i:
	return Vector2i(
		clampi(int(floor(float(point.x) / float(step))), 0, w - 1),
		clampi(int(floor(float(point.y) / float(step))), 0, h - 1)
	)

# Spiral outward from a coarse cell to the nearest non-solid cell so road
# endpoints never start inside a rock clearance zone. Returns (-1,-1) if none.
func _nearest_open_coarse(astar: AStarGrid2D, cell: Vector2i) -> Vector2i:
	var region := astar.region
	if not astar.is_point_solid(cell):
		return cell
	for radius in range(1, maxi(region.size.x, region.size.y)):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if absi(dx) != radius and absi(dy) != radius:
					continue
				var candidate := cell + Vector2i(dx, dy)
				if not region.has_point(candidate):
					continue
				if not astar.is_point_solid(candidate):
					return candidate
	return Vector2i(-1, -1)

# M3 — carve narrow trails (sentieri) starting at forest centers, crossing the
# forest and stopping at the first rock (or border / max length).
func _add_voidfirst_paths(
	layout: BiomeEnvironmentLayout,
	rng: RandomNumberGenerator,
	trail_tag: StringName
) -> void:
	if layout.forest_rects.is_empty():
		return
	var directions: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
	]
	var count := mini(VOIDFIRST_PATH_COUNT, layout.forest_rects.size())
	for index in range(count):
		var forest_rect := layout.forest_rects[index]
		var start := forest_rect.position + _center_offset(forest_rect.size)
		var direction: Vector2i = directions[rng.randi_range(0, directions.size() - 1)]
		_carve_trail(layout, start, direction, VOIDFIRST_PATH_WIDTH, VOIDFIRST_PATH_MAX_LEN, trail_tag)

func _carve_trail(
	layout: BiomeEnvironmentLayout,
	start: Vector2i,
	direction: Vector2i,
	width: int,
	max_len: int,
	tag: StringName
) -> int:
	var carved := 0
	var pos := start
	for _step in range(max_len):
		var next := pos + direction
		var band := _trail_band_rect(next, direction, width)
		if GeometryUtils.intersects_any(band, _voidfirst_solid_rects(layout)):
			break
		if (
			band.position.x < 0
			or band.position.y < 0
			or band.end.x > layout.zone_size.x
			or band.end.y > layout.zone_size.y
		):
			break
		for y in range(band.position.y, band.end.y):
			for x in range(band.position.x, band.end.x):
				layout.add_road_cell(Vector2i(x, y), tag)
		carved += 1
		pos = next
	return carved

func _trail_band_rect(center: Vector2i, direction: Vector2i, width: int) -> Rect2i:
	var span_before := _span_before_center(width)
	if direction.x != 0:
		return Rect2i(Vector2i(center.x, center.y - span_before), Vector2i(1, width))
	return Rect2i(Vector2i(center.x - span_before, center.y), Vector2i(width, 1))

# Remove forest trees whose footprint overlaps any carved route cell, so roads and
# trails read as cleared lanes through the woods.
func _clear_trees_on_routes(layout: BiomeEnvironmentLayout, cluster_id: StringName) -> void:
	for index in range(layout.obstacle_ids.size() - 1, -1, -1):
		if layout.obstacle_ids[index] != cluster_id:
			continue
		if not layout.rect_overlaps_road_cells(layout.obstacle_rects[index]):
			continue
		layout.obstacle_rects.remove_at(index)
		layout.obstacle_ids.remove_at(index)
		layout.obstacle_positions.remove_at(index)
		layout.obstacle_sizes.remove_at(index)
		layout.obstacle_rotations.remove_at(index)
		layout.obstacle_shape_ids.remove_at(index)

# M4 — line roads with a layer of trees wherever the road runs through open void,
# i.e. where it is not already bounded by a rock or forest ("confine"). Candidate
# tree slots are scanned on a coarse grid; a tree is placed only if it sits beside
# a road on a free cell with no existing border nearby.
# Road tree-lining is a forest-biome flourish: only biomes whose palette opts in
# (line_vegetation) line open-void roads with their cluster obstacle. Non-plains
# biomes skip it so their roads read as bare thematic lanes rather than tree alleys.
func _line_roads_with_trees(layout: BiomeEnvironmentLayout, palette: Dictionary) -> int:
	if not bool(palette["line_vegetation"]):
		return 0
	var cluster_id := palette["cluster_id"] as StringName
	var footprint := _logical_footprint_tiles(cluster_id)
	var added := 0
	var lo := BORDER_THICKNESS
	var max_x := layout.zone_size.x - lo - footprint.x
	var max_y := layout.zone_size.y - lo - footprint.y
	var y := lo
	while y <= max_y:
		var x := lo
		while x <= max_x:
			if added >= VOIDFIRST_MAX_LINE_TREES:
				return added
			var rect := Rect2i(Vector2i(x, y), footprint)
			if _should_line_with_tree(layout, rect):
				_add_obstacle(layout, cluster_id, rect, &"rectangle", 0.0)
				added += 1
			x += VOIDFIRST_ROAD_LINE_SPACING
		y += VOIDFIRST_ROAD_LINE_SPACING
	return added

func _should_line_with_tree(layout: BiomeEnvironmentLayout, rect: Rect2i) -> bool:
	# Free of obstacles and passage corridors, and not on the road itself.
	if not _can_place_tree(layout, rect):
		return false
	if layout.rect_overlaps_road_cells(rect):
		return false
	# Must sit beside a road to count as a lining.
	if not layout.rect_overlaps_road_cells(GeometryUtils.inflate_rect(rect, VOIDFIRST_ROAD_LINE_NEAR)):
		return false
	# Skip if the road is already bounded here by a rock or forest.
	var confine := GeometryUtils.inflate_rect(rect, VOIDFIRST_ROAD_LINE_CONFINE)
	if GeometryUtils.intersects_any(confine, _voidfirst_solid_rects(layout)):
		return false
	if GeometryUtils.intersects_any(confine, layout.forest_rects):
		return false
	return true

# M5 — resolve the leftover void. The map is scanned in square patches: fully-void
# patches enter a lottery (1 chasm : 3 walkable), partially-void patches are filled
# with floor so no random void slivers remain. Chasms only ever land on fully-void
# patches with enough route clearance for the visual cliff lip, so they never
# overwrite or visually bleed onto roads, obstacles or passages.
func _resolve_void_lottery(
	layout: BiomeEnvironmentLayout,
	rng: RandomNumberGenerator,
	allow_chasms: bool = true,
	minimum_internal_chasms: int = 1
) -> void:
	var occ := _compute_occupancy(layout)
	var patch := VOIDFIRST_VOID_PATCH
	var full_void: Array[Rect2i] = []
	var partial_void: Array[Rect2i] = []
	var route_near_void: Array[Rect2i] = []
	var py := 0
	while py < layout.zone_size.y:
		var px := 0
		while px < layout.zone_size.x:
			var rect := Rect2i(
				Vector2i(px, py),
				Vector2i(
					mini(patch, layout.zone_size.x - px),
					mini(patch, layout.zone_size.y - py)
				)
			)
			var void_cells := _count_void_cells(occ, rect, layout.zone_size.x)
			var total_cells := rect.size.x * rect.size.y
			if void_cells == total_cells and total_cells > 0:
				if _chasm_has_route_clearance(layout, rect):
					full_void.append(rect)
				else:
					route_near_void.append(rect)
			elif void_cells > 0:
				partial_void.append(rect)
			px += patch
		py += patch

	# A non-empty internal chasm is a generation contract, not a probabilistic
	# side-effect. If the aligned patch grid found none, scan for the largest fully
	# free internal square (down to one cell) before filling partial patches.
	if allow_chasms and minimum_internal_chasms > 0 and full_void.is_empty():
		var fallback := _find_internal_chasm_fallback(occ, layout)
		if fallback.size.x > 0 and fallback.size.y > 0:
			full_void.append(fallback)
	for rect in route_near_void:
		layout.add_floor_rect(rect, &"open_block")
	for rect in partial_void:
		# Fall-zone classification wins over floor when the fallback lies inside an
		# aligned partial patch; filling the remainder prevents raw void slivers.
		layout.add_floor_rect(rect, &"open_block")
	_shuffle_rects(full_void, rng)
	if not allow_chasms:
		for rect in full_void:
			layout.add_floor_rect(rect, &"open_block")
		return
	var chasm_count := 0
	if not full_void.is_empty():
		chasm_count = mini(
			maxi(
				maxi(minimum_internal_chasms, 0),
				full_void.size() / VOIDFIRST_VOID_CHASM_DIVISOR
			),
			full_void.size()
		)
	var chasm_rects: Array[Rect2i] = []
	for index in range(full_void.size()):
		if index < chasm_count:
			chasm_rects.append(full_void[index])
		else:
			layout.add_floor_rect(full_void[index], &"open_block")
	for chasm_rect in _merge_row_runs(chasm_rects):
		layout.add_fall_zone_rect(chasm_rect, &"internal")

func _find_internal_chasm_fallback(
	occ: PackedByteArray,
	layout: BiomeEnvironmentLayout
) -> Rect2i:
	var zone_size := layout.zone_size
	for side in range(VOIDFIRST_VOID_PATCH, 0, -1):
		var max_x := zone_size.x - BORDER_THICKNESS - side
		var max_y := zone_size.y - BORDER_THICKNESS - side
		for y in range(BORDER_THICKNESS, max_y + 1):
			for x in range(BORDER_THICKNESS, max_x + 1):
				var rect := Rect2i(Vector2i(x, y), Vector2i(side, side))
				if (
					_count_void_cells(occ, rect, zone_size.x) == side * side
					and _chasm_has_route_clearance(layout, rect)
				):
					return rect
	return Rect2i()

func _chasm_has_route_clearance(
	layout: BiomeEnvironmentLayout,
	rect: Rect2i
) -> bool:
	var padded := GeometryUtils.inflate_rect(rect, VOIDFIRST_CHASM_ROUTE_CLEARANCE)
	if GeometryUtils.intersects_any(padded, layout.road_rects):
		return false
	if GeometryUtils.intersects_any(padded, layout.passage_rects):
		return false
	if GeometryUtils.intersects_any(padded, layout.passage_connector_rects):
		return false
	return not layout.rect_overlaps_road_cells(padded)

func _compute_occupancy(layout: BiomeEnvironmentLayout) -> PackedByteArray:
	var total := layout.zone_size.x * layout.zone_size.y
	var occ := PackedByteArray()
	occ.resize(total)
	occ.fill(0)
	_occ_mark_rects(occ, layout.floor_rects, layout.zone_size)
	_occ_mark_rects(occ, layout.passage_rects, layout.zone_size)
	_occ_mark_rects(occ, layout.passage_connector_rects, layout.zone_size)
	_occ_mark_rects(occ, layout.obstacle_rects, layout.zone_size)
	_occ_mark_rects(occ, layout.hazard_rects, layout.zone_size)
	_occ_mark_rects(occ, layout.road_rects, layout.zone_size)
	for key_value in layout.road_cell_tags.keys():
		var key := int(key_value)
		if key >= 0 and key < total:
			occ[key] = 1
	# Reserve the border ring so the lottery stays inside the chunk body.
	var z := layout.zone_size
	for x in range(z.x):
		for band in range(BORDER_THICKNESS):
			occ[band * z.x + x] = 1
			occ[(z.y - 1 - band) * z.x + x] = 1
	for y in range(z.y):
		for band in range(BORDER_THICKNESS):
			occ[y * z.x + band] = 1
			occ[y * z.x + (z.x - 1 - band)] = 1
	return occ

func _occ_mark_rects(
	occ: PackedByteArray,
	rects: Array[Rect2i],
	zone_size: Vector2i
) -> void:
	for rect in rects:
		var clipped := GeometryUtils.clip_rect(rect, zone_size)
		for y in range(clipped.position.y, clipped.end.y):
			var row := y * zone_size.x
			for x in range(clipped.position.x, clipped.end.x):
				occ[row + x] = 1

func _count_void_cells(occ: PackedByteArray, rect: Rect2i, width: int) -> int:
	var count := 0
	for y in range(rect.position.y, rect.end.y):
		var row := y * width
		for x in range(rect.position.x, rect.end.x):
			if occ[row + x] == 0:
				count += 1
	return count

func _shuffle_rects(rects: Array[Rect2i], rng: RandomNumberGenerator) -> void:
	for i in range(rects.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := rects[i]
		rects[i] = rects[j]
		rects[j] = tmp

# Merge chasm patches that are contiguous in the same patch row into single rects
# so the runtime instantiates fewer fall zones.
func _merge_row_runs(rects: Array[Rect2i]) -> Array[Rect2i]:
	rects.sort_custom(
		func(a: Rect2i, b: Rect2i) -> bool:
			if a.position.y != b.position.y:
				return a.position.y < b.position.y
			return a.position.x < b.position.x
	)
	var merged: Array[Rect2i] = []
	for rect in rects:
		if not merged.is_empty():
			var last: Rect2i = merged[merged.size() - 1]
			if (
				last.position.y == rect.position.y
				and last.size.y == rect.size.y
				and last.end.x == rect.position.x
			):
				merged[merged.size() - 1] = Rect2i(
					last.position,
					Vector2i(last.size.x + rect.size.x, last.size.y)
				)
				continue
		merged.append(rect)
	return merged

func repair_layout(layout: BiomeEnvironmentLayout) -> void:
	for index in range(layout.obstacle_rects.size() - 1, -1, -1):
		var obstacle_rect := layout.obstacle_rects[index]
		# Walled arenas intentionally let decorative roads terminate underneath
		# their solid perimeter. Removing that obstacle would leave a visual and
		# collision hole while wall_segment_rects still advertised full coverage.
		if (
			layout.uses_raised_perimeter_cliffs()
			and not layout.get_wall_segment_side(obstacle_rect).is_empty()
		):
			continue
		if layout.rect_intersects_route(obstacle_rect):
			var obstacle_id := (
				layout.obstacle_ids[index]
				if index < layout.obstacle_ids.size()
				else &""
			)
			_remove_voidfirst_feature_membership(layout, obstacle_id, obstacle_rect)
			layout.obstacle_rects.remove_at(index)
			layout.obstacle_ids.remove_at(index)
			layout.obstacle_positions.remove_at(index)
			layout.obstacle_sizes.remove_at(index)
			layout.obstacle_rotations.remove_at(index)
			layout.obstacle_shape_ids.remove_at(index)

func _remove_voidfirst_feature_membership(
	layout: BiomeEnvironmentLayout,
	obstacle_id: StringName,
	rect: Rect2i
) -> void:
	if obstacle_id == &"large_rock":
		var mesa_index := layout.mesa_rects.find(rect)
		if mesa_index >= 0:
			layout.mesa_rects.remove_at(mesa_index)
			if mesa_index < layout.mesa_profile_ids.size():
				layout.mesa_profile_ids.remove_at(mesa_index)
		layout.rock_rects.erase(rect)
	layout.mass_rects.erase(rect)
	for prop_index in range(layout.random_prop_rects.size() - 1, -1, -1):
		if layout.random_prop_rects[prop_index] != rect:
			continue
		if (
			prop_index < layout.random_prop_ids.size()
			and layout.random_prop_ids[prop_index] != obstacle_id
		):
			continue
		layout.random_prop_rects.remove_at(prop_index)
		if prop_index < layout.random_prop_ids.size():
			layout.random_prop_ids.remove_at(prop_index)
		break

func refresh_generation_summary(
	layout: BiomeEnvironmentLayout,
	biome: BiomeDefinition
) -> void:
	var parcel_report: Dictionary = layout.generation_summary.get("parcel_report", {}) as Dictionary
	var parcel_content: Dictionary = layout.generation_summary.get("parcel_content", {}) as Dictionary
	_update_generation_summary(layout, biome)
	if not parcel_report.is_empty():
		layout.generation_summary["parcel_report"] = parcel_report
	if not parcel_content.is_empty():
		layout.generation_summary["parcel_content"] = parcel_content

func _add_roads(layout: BiomeEnvironmentLayout, cell: BiomeCell) -> void:
	var zone_size := layout.zone_size
	var center := zone_size / 2
	var main_before := _span_before_center(ROAD_WIDTH)
	_add_road_rect(
		layout,
		Rect2i(
			Vector2i(0, center.y - main_before),
			Vector2i(zone_size.x, ROAD_WIDTH)
		),
		&"main_road"
	)
	_add_road_rect(
		layout,
		Rect2i(
			Vector2i(center.x - main_before, 0),
			Vector2i(ROAD_WIDTH, zone_size.y)
		),
		&"main_road"
	)

	for passage in cell.passages:
		var passage_rect := passage.get_local_rect(zone_size)
		layout.passage_rects.append(passage_rect)
		var connector_rect := passage.get_connector_rect(zone_size)
		layout.passage_connector_rects.append(connector_rect)
		_add_road_rect(layout, passage_rect, passage.passage_type)
		_add_road_rect(layout, connector_rect, passage.passage_type)

func _add_biome_navigation_features(
	layout: BiomeEnvironmentLayout,
	biome: BiomeDefinition,
	rng: RandomNumberGenerator
) -> void:
	var path_tag := _secondary_path_tag(biome.biome_id)
	var vertical_ratio := 0.32
	var horizontal_ratio := 0.68
	match biome.biome_id:
		&"infected_plains":
			vertical_ratio = 0.34
			horizontal_ratio = 0.66
		&"toxic_wastes":
			vertical_ratio = 0.38
			horizontal_ratio = 0.62
		&"burning_fields":
			vertical_ratio = 0.30
			horizontal_ratio = 0.70
		&"frozen_outskirts":
			vertical_ratio = 0.36
			horizontal_ratio = 0.64
		&"drowned_marsh":
			vertical_ratio = 0.28 + rng.randf_range(-0.015, 0.015)
			horizontal_ratio = 0.72 + rng.randf_range(-0.015, 0.015)
		_:
			pass
	_add_secondary_grid_paths(layout, path_tag, vertical_ratio, horizontal_ratio)

func _add_starter_water_crossing(
	layout: BiomeEnvironmentLayout,
	biome: BiomeDefinition,
	rng: RandomNumberGenerator
) -> void:
	if biome == null or biome.biome_id != &"infected_plains":
		return
	var river_y := _select_starter_river_y(layout, rng)
	var river_band := Rect2i(
		Vector2i(
			0,
			river_y - _span_before_center(STARTER_RIVER_WIDTH) - WorldGridConfig.STARTER_RIVER_PADDING_TILES
		),
		Vector2i(
			layout.zone_size.x,
			STARTER_RIVER_WIDTH + WorldGridConfig.STARTER_RIVER_PADDING_TILES * 2
		)
	)
	var segment_width := int(ceil(float(layout.zone_size.x) / 3.0))
	var offsets: Array[int] = [
		0,
		-WorldGridConfig.legacy_cells_to_new_tiles(5),
		WorldGridConfig.legacy_cells_to_new_tiles(4)
	]
	for index in range(3):
		var start_x := clampi(
			index * segment_width - WorldGridConfig.STARTER_BRIDGE_PADDING_TILES,
			0,
			layout.zone_size.x
		)
		var end_x := clampi(
			(index + 1) * segment_width + WorldGridConfig.STARTER_BRIDGE_PADDING_TILES,
			0,
			layout.zone_size.x
		)
		if end_x <= start_x:
			continue
		var offset_y := offsets[index % offsets.size()]
		var water_rect := Rect2i(
			Vector2i(start_x, river_y + offset_y - _span_before_center(STARTER_RIVER_WIDTH)),
			Vector2i(end_x - start_x, STARTER_RIVER_WIDTH)
		)
		layout.add_hazard_rect(water_rect, &"deep_water")
	_add_bridge_rects_over_water(layout, river_band)

func _select_starter_river_y(
	layout: BiomeEnvironmentLayout,
	rng: RandomNumberGenerator
) -> int:
	var candidates: Array[int] = [
		int(float(layout.zone_size.y) * 0.29),
		int(float(layout.zone_size.y) * 0.35),
		int(float(layout.zone_size.y) * 0.59),
		int(float(layout.zone_size.y) * 0.71)
	]
	var start_index := rng.randi_range(0, candidates.size() - 1)
	for offset in range(candidates.size()):
		var river_y := candidates[(start_index + offset) % candidates.size()]
		var river_band := Rect2i(
			Vector2i(
				0,
				river_y - _span_before_center(STARTER_RIVER_WIDTH) - WorldGridConfig.STARTER_RIVER_PADDING_TILES
			),
			Vector2i(
				layout.zone_size.x,
				STARTER_RIVER_WIDTH + WorldGridConfig.STARTER_RIVER_PADDING_TILES * 2
			)
		)
		if _starter_river_band_is_clear(layout, river_band):
			return river_y
	return int(float(layout.zone_size.y) * 0.35)

func _starter_river_band_is_clear(
	layout: BiomeEnvironmentLayout,
	river_band: Rect2i
) -> bool:
	for index in range(layout.road_rects.size()):
		var road_rect := layout.road_rects[index]
		if not road_rect.intersects(river_band):
			continue
		if road_rect.size.x > road_rect.size.y:
			return false
	return true

func _add_bridge_rects_over_water(
	layout: BiomeEnvironmentLayout,
	river_band: Rect2i
) -> void:
	var bridge_count := 0
	for road_rect in layout.road_rects:
		if road_rect.size.y <= road_rect.size.x:
			continue
		if not road_rect.intersects(river_band):
			continue
		var bridge_rect := Rect2i(
			Vector2i(
				road_rect.position.x - _span_before_center(STARTER_BRIDGE_EXTRA_WIDTH),
				river_band.position.y - WorldGridConfig.STARTER_BRIDGE_PADDING_TILES
			),
			Vector2i(
				road_rect.size.x + STARTER_BRIDGE_EXTRA_WIDTH,
				river_band.size.y + WorldGridConfig.STARTER_BRIDGE_PADDING_TILES * 2
			)
		)
		_add_road_rect(layout, bridge_rect, &"bridge")
		bridge_count += 1
	if bridge_count > 0:
		return
	var center_x := layout.zone_size.x / 2
	_add_road_rect(
		layout,
		Rect2i(
			Vector2i(
				center_x - _span_before_center(ROAD_WIDTH + STARTER_BRIDGE_EXTRA_WIDTH),
				river_band.position.y - WorldGridConfig.STARTER_BRIDGE_PADDING_TILES
			),
			Vector2i(
				ROAD_WIDTH + STARTER_BRIDGE_EXTRA_WIDTH,
				river_band.size.y + WorldGridConfig.STARTER_BRIDGE_PADDING_TILES * 2
			)
		),
		&"bridge"
	)

func _add_cover_cluster(
	layout: BiomeEnvironmentLayout,
	obstacle_id: StringName,
	anchor: Vector2i,
	horizontal: bool
) -> void:
	var first_size := (
		WorldGridConfig.legacy_size_to_new_tiles(Vector2i(13, 6))
		if horizontal
		else WorldGridConfig.legacy_size_to_new_tiles(Vector2i(6, 13))
	)
	var second_size := (
		WorldGridConfig.legacy_size_to_new_tiles(Vector2i(10, 5))
		if horizontal
		else WorldGridConfig.legacy_size_to_new_tiles(Vector2i(5, 10))
	)
	var second_offset := (
		WorldGridConfig.legacy_size_to_new_tiles(Vector2i(18, 8))
		if horizontal
		else WorldGridConfig.legacy_size_to_new_tiles(Vector2i(8, 18))
	)
	var first := Rect2i(anchor, first_size)
	var second := Rect2i(
		anchor + second_offset,
		second_size
	)
	_add_obstacle_if_clear(layout, obstacle_id, first, &"rectangle", 0.0)
	_add_obstacle_if_clear(layout, obstacle_id, second, &"rectangle", 0.0)

func _add_secondary_grid_paths(
	layout: BiomeEnvironmentLayout,
	path_tag: StringName,
	vertical_ratio: float,
	horizontal_ratio: float
) -> void:
	var zone_size := layout.zone_size
	var half_path := _span_before_center(SECONDARY_ROAD_WIDTH)
	var vertical_x := clampi(
		roundi(float(zone_size.x) * vertical_ratio),
		BORDER_THICKNESS + half_path,
		zone_size.x - BORDER_THICKNESS - half_path
	)
	var horizontal_y := clampi(
		roundi(float(zone_size.y) * horizontal_ratio),
		BORDER_THICKNESS + half_path,
		zone_size.y - BORDER_THICKNESS - half_path
	)
	_add_road_rect(
		layout,
		Rect2i(
			Vector2i(vertical_x - half_path, BORDER_THICKNESS),
			Vector2i(SECONDARY_ROAD_WIDTH, zone_size.y - BORDER_THICKNESS * 2)
		),
		path_tag
	)
	_add_road_rect(
		layout,
		Rect2i(
			Vector2i(BORDER_THICKNESS, horizontal_y - half_path),
			Vector2i(zone_size.x - BORDER_THICKNESS * 2, SECONDARY_ROAD_WIDTH)
		),
		path_tag
	)

func _secondary_path_tag(biome_id: StringName) -> StringName:
	match biome_id:
		&"toxic_wastes":
			return &"service_lane"
		&"burning_fields":
			return &"ash_lane"
		&"frozen_outskirts":
			return &"packed_snow_path"
		&"drowned_marsh":
			return &"wooden_walkway"
		_:
			return &"broken_street"

func _add_choke_pair(
	layout: BiomeEnvironmentLayout,
	obstacle_id: StringName,
	anchor: Vector2i,
	rotation_radians: float
) -> void:
	_add_obstacle_if_clear(
		layout,
		obstacle_id,
		Rect2i(anchor, _legacy_rect_size(8, 18)),
		&"rectangle",
		rotation_radians
	)
	_add_obstacle_if_clear(
		layout,
		obstacle_id,
		Rect2i(
			anchor + Vector2i(_legacy_cells(28), -_legacy_cells(6)),
			_legacy_rect_size(8, 18)
		),
		&"rectangle",
		-rotation_radians
	)

func _add_internal_blocks(
	layout: BiomeEnvironmentLayout,
	biome: BiomeDefinition,
	rng: RandomNumberGenerator,
	allow_internal_void: bool = true
) -> void:
	var vertical_bands := _collect_axis_bands(layout, true)
	var horizontal_bands := _collect_axis_bands(layout, false)
	var x_intervals := _intervals_between_bands(vertical_bands, layout.zone_size.x)
	var y_intervals := _intervals_between_bands(horizontal_bands, layout.zone_size.y)
	var block_index := 0
	for y_interval in y_intervals:
		for x_interval in x_intervals:
			var raw_rect := Rect2i(
				Vector2i(int(x_interval.x), int(y_interval.x)),
				Vector2i(
					int(x_interval.y - x_interval.x),
					int(y_interval.y - y_interval.x)
				)
			)
			var block_rect := _inset_rect(raw_rect, BLOCK_INSET)
			if (
				block_rect.size.x < MIN_BLOCK_SIZE
				or block_rect.size.y < MIN_BLOCK_SIZE
			):
				continue
			var block_kind := _resolve_block_kind(biome.biome_id, block_index, rng)
			# Never drop a void/fall block onto a passage corridor: the connector
			# road must stay walkable and free of fall hazards so cross-biome
			# passages remain reachable.
			if not allow_internal_void and _is_void_block_kind(block_kind):
				block_kind = &"open"
			if _is_void_block_kind(block_kind) and layout.rect_overlaps_passage_corridor(block_rect):
				block_kind = &"open"
			layout.add_block_rect(block_rect, block_kind)
			_apply_block_surface(layout, block_rect, block_kind, biome.biome_id)
			block_index += 1
	if biome != null and biome.biome_id == &"infected_plains":
		_ensure_starter_block_mix(layout, biome.biome_id)
	if allow_internal_void:
		_ensure_internal_void_block(layout, biome.biome_id if biome != null else &"")

func _is_void_block_kind(block_kind: StringName) -> bool:
	return block_kind == &"full_void" or block_kind == &"partial_void"

func _is_walled_arena_context(context: Dictionary) -> bool:
	return (
		ContextUtils.get_string(context, "arena_boundary_mode", "") == "walled"
		or ContextUtils.get_string(context, "arena_boundary_mode", "") == "blocked"
	)

# Internal void/chasms are a shared terrain feature, decoupled from the boundary
# mode: they are emitted in every mode (Survival and the walled Infinite Arena
# alike) and only suppressed by an explicit opt-out flag. The walled boundary now
# governs the perimeter only (walls vs fall edge), never the interior.
func _internal_void_enabled(context: Dictionary) -> bool:
	return not ContextUtils.get_bool(context, "disable_internal_void", false)

func _ensure_internal_void_block(
	layout: BiomeEnvironmentLayout,
	biome_id: StringName
) -> void:
	if (
		layout.block_kinds.has(&"full_void")
		or layout.block_kinds.has(&"partial_void")
	):
		return
	var selected_index := -1
	var selected_area := 0
	for index in range(layout.block_rects.size()):
		var block_rect := layout.block_rects[index]
		var block_kind := (
			layout.block_kinds[index]
			if index < layout.block_kinds.size()
			else &"open"
		)
		if (
			biome_id == &"infected_plains"
			and (block_kind == &"building" or block_kind == &"dense_vegetation")
		):
			continue
		if layout.rect_overlaps_passage_corridor(block_rect):
			continue
		var area := block_rect.size.x * block_rect.size.y
		if area <= selected_area:
			continue
		selected_index = index
		selected_area = area
	if selected_index < 0:
		return
	layout.block_kinds[selected_index] = &"partial_void"
	_apply_block_surface(
		layout,
		layout.block_rects[selected_index],
		&"partial_void",
		biome_id
	)

func _ensure_starter_block_mix(
	layout: BiomeEnvironmentLayout,
	biome_id: StringName
) -> void:
	if not layout.block_kinds.has(&"building"):
		var building_index := _largest_non_void_block_index(layout, [])
		if building_index >= 0:
			layout.block_kinds[building_index] = &"building"
			_apply_block_surface(
				layout,
				layout.block_rects[building_index],
				&"building",
				biome_id
			)
	if not layout.block_kinds.has(&"dense_vegetation"):
		var dense_index := _largest_non_void_block_index(layout, [&"building"])
		if dense_index >= 0:
			layout.block_kinds[dense_index] = &"dense_vegetation"
			_apply_block_surface(
				layout,
				layout.block_rects[dense_index],
				&"dense_vegetation",
				biome_id
			)

func _largest_non_void_block_index(
	layout: BiomeEnvironmentLayout,
	excluded_kinds: Array
) -> int:
	var selected_index := -1
	var selected_area := 0
	for index in range(layout.block_rects.size()):
		var kind := (
			layout.block_kinds[index]
			if index < layout.block_kinds.size()
			else &"open"
		)
		if (
			kind == &"full_void"
			or kind == &"partial_void"
			or excluded_kinds.has(kind)
		):
			continue
		var area := layout.block_rects[index].size.x * layout.block_rects[index].size.y
		if area <= selected_area:
			continue
		selected_area = area
		selected_index = index
	return selected_index

func _apply_block_surface(
	layout: BiomeEnvironmentLayout,
	block_rect: Rect2i,
	block_kind: StringName,
	biome_id: StringName = &""
) -> void:
	match block_kind:
		&"full_void":
			layout.add_fall_zone_rect(
				_extend_void_rect_to_world_edge(layout, block_rect),
				&"internal"
			)
		&"partial_void":
			layout.add_floor_rect(block_rect, &"open_block")
			var pocket := _inset_rect(
				block_rect,
				maxi(mini(block_rect.size.x, block_rect.size.y) / 4, 10)
			)
			layout.add_fall_zone_rect(pocket, &"internal")
		&"dense_vegetation":
			layout.add_floor_rect(block_rect, &"forest_tall_grass")
		_:
			var floor_tag := &"open_block"
			if biome_id == &"infected_plains" and block_kind == &"forest":
				floor_tag = &"forest_tall_grass"
			layout.add_floor_rect(block_rect, floor_tag)

func _extend_void_rect_to_world_edge(
	layout: BiomeEnvironmentLayout,
	void_rect: Rect2i
) -> Rect2i:
	var start := void_rect.position
	var finish := void_rect.end
	if start.x <= BORDER_THICKNESS:
		start.x = 0
	if start.y <= BORDER_THICKNESS:
		start.y = 0
	if finish.x >= layout.zone_size.x - BORDER_THICKNESS:
		finish.x = layout.zone_size.x
	if finish.y >= layout.zone_size.y - BORDER_THICKNESS:
		finish.y = layout.zone_size.y
	return Rect2i(start, finish - start)

func _resolve_block_kind(
	biome_id: StringName,
	block_index: int,
	rng: RandomNumberGenerator
) -> StringName:
	var pattern: Array[StringName] = [
		&"building",
		&"open",
		&"dense_vegetation",
		&"partial_void",
		&"forest",
		&"ruins",
		&"large_obstacle",
		&"full_void"
	]
	match biome_id:
		&"toxic_wastes":
			pattern = [&"building", &"ruins", &"partial_void", &"open", &"large_obstacle", &"open", &"building", &"full_void"]
		&"burning_fields":
			pattern = [&"ruins", &"partial_void", &"building", &"full_void", &"large_obstacle", &"open", &"ruins", &"open"]
		&"frozen_outskirts":
			pattern = [&"building", &"open", &"large_obstacle", &"partial_void", &"forest", &"open", &"full_void", &"ruins"]
		&"drowned_marsh":
			pattern = [&"partial_void", &"forest", &"open", &"full_void", &"building", &"open", &"large_obstacle", &"forest"]
		_:
			pass
	var offset := rng.randi_range(0, pattern.size() - 1)
	return pattern[(block_index + offset) % pattern.size()]

func _collect_axis_bands(
	layout: BiomeEnvironmentLayout,
	vertical: bool
) -> Array[Vector2i]:
	var bands: Array[Vector2i] = []
	for rect in layout.road_rects:
		var is_vertical := (
			rect.size.y >= layout.zone_size.y - BORDER_THICKNESS * 2
			and rect.size.x <= ROAD_WIDTH + SECONDARY_ROAD_WIDTH
		)
		var is_horizontal := (
			rect.size.x >= layout.zone_size.x - BORDER_THICKNESS * 2
			and rect.size.y <= ROAD_WIDTH + SECONDARY_ROAD_WIDTH
		)
		if vertical and is_vertical:
			bands.append(Vector2i(rect.position.x, rect.position.x + rect.size.x))
		elif not vertical and is_horizontal:
			bands.append(Vector2i(rect.position.y, rect.position.y + rect.size.y))
	bands.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x)
	return _merge_bands(bands)

func _merge_bands(bands: Array[Vector2i]) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for band in bands:
		if result.is_empty() or band.x > result.back().y:
			result.append(band)
			continue
		var last: Vector2i = result.pop_back()
		result.append(Vector2i(last.x, maxi(last.y, band.y)))
	return result

func _intervals_between_bands(
	bands: Array[Vector2i],
	limit: int
) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var cursor := BORDER_THICKNESS
	for band in bands:
		var start := clampi(band.x, BORDER_THICKNESS, limit - BORDER_THICKNESS)
		var finish := clampi(band.y, BORDER_THICKNESS, limit - BORDER_THICKNESS)
		if start - cursor >= MIN_BLOCK_SIZE:
			result.append(Vector2i(cursor, start))
		cursor = maxi(cursor, finish)
	if limit - BORDER_THICKNESS - cursor >= MIN_BLOCK_SIZE:
		result.append(Vector2i(cursor, limit - BORDER_THICKNESS))
	return result

func _add_road_rect(
	layout: BiomeEnvironmentLayout,
	rect: Rect2i,
	tag: StringName
) -> void:
	rect = GeometryUtils.clip_rect(rect, layout.zone_size)
	if rect.size.x <= 0 or rect.size.y <= 0:
		return
	layout.road_rects.append(rect)
	layout.road_rect_tags.append(tag)
	if tag == &"bridge":
		layout.add_bridge_rect(rect)
	_add_route_metadata(layout, layout.rect_center_to_world(rect), maxf(float(maxi(rect.size.x, rect.size.y)) * layout.logical_tile_scale * 0.18, 28.0), tag)

func _add_cardinal_road(
	layout: BiomeEnvironmentLayout,
	start: Vector2i,
	end: Vector2i,
	width: int,
	tag: StringName
) -> void:
	var touched: Dictionary = {}
	var solid_rects := _voidfirst_solid_rects(layout)
	var elbow := Vector2i(end.x, start.y)
	_add_cardinal_road_segment(
		layout, start, elbow, width, tag, solid_rects, touched
	)
	_add_cardinal_road_segment(
		layout, elbow, end, width, tag, solid_rects, touched
	)
	if touched.is_empty():
		return
	var midpoint := Vector2(
		(float(start.x) + float(end.x)) * 0.5,
		(float(start.y) + float(end.y)) * 0.5
	)
	var world_midpoint := layout.logical_to_world(Vector2i(roundi(midpoint.x), roundi(midpoint.y)))
	var world_radius := maxf(
		float(absi(end.x - start.x) + absi(end.y - start.y))
			* layout.logical_tile_scale * 0.10,
		34.0
	)
	_add_route_metadata(layout, world_midpoint, world_radius, tag)

func _add_cardinal_road_segment(
	layout: BiomeEnvironmentLayout,
	start: Vector2i,
	end: Vector2i,
	width: int,
	tag: StringName,
	solid_rects: Array[Rect2i],
	touched: Dictionary
) -> void:
	var before := _span_before_center(width)
	var after := _span_after_center(width)
	var min_x := mini(start.x, end.x)
	var max_x := maxi(start.x, end.x)
	var min_y := mini(start.y, end.y)
	var max_y := maxi(start.y, end.y)
	for center_y in range(min_y, max_y + 1):
		for center_x in range(min_x, max_x + 1):
			var center := Vector2i(center_x, center_y)
			for y in range(center.y - before, center.y + after):
				for x in range(center.x - before, center.x + after):
					var cell := Vector2i(x, y)
					if (
						cell.x < 0
						or cell.y < 0
						or cell.x >= layout.zone_size.x
						or cell.y >= layout.zone_size.y
						or _cell_inside_any_rect(cell, solid_rects)
					):
						continue
					layout.add_road_cell(cell, tag)
					touched[_route_cell_key(layout, cell)] = true

func _add_route_metadata(
	layout: BiomeEnvironmentLayout,
	position: Vector2,
	radius: float,
	tag: StringName
) -> void:
	layout.terrain_patch_tags.append(tag)
	layout.terrain_patch_positions.append(position)
	layout.terrain_patch_radii.append(radius)

func _add_large_obstacles(
	layout: BiomeEnvironmentLayout,
	biome: BiomeDefinition,
	rng: RandomNumberGenerator
) -> void:
	for index in range(layout.block_rects.size()):
		var block_kind := (
			layout.block_kinds[index]
			if index < layout.block_kinds.size()
			else &"open"
		)
		if not [&"building", &"forest", &"ruins", &"large_obstacle", &"dense_vegetation"].has(block_kind):
			continue
		var block_rect := layout.block_rects[index]
		if block_kind == &"dense_vegetation":
			_add_dense_vegetation_cluster(layout, block_rect, rng)
			continue
		var min_size := _legacy_rect_size(12, 10)
		var max_candidate := _legacy_rect_size(34, 28)
		var size := Vector2i(
			clampi(
				rng.randi_range(_legacy_cells(18), max_candidate.x),
				min_size.x,
				maxi(block_rect.size.x - _legacy_cells(10), min_size.x)
			),
			clampi(
				rng.randi_range(_legacy_cells(14), max_candidate.y),
				min_size.y,
				maxi(block_rect.size.y - _legacy_cells(10), min_size.y)
			)
		)
		var obstacle_rect := _centered_rect(block_rect, size)
		_add_obstacle_if_clear(
			layout,
			_block_obstacle_id(biome.biome_id, block_kind, index),
			obstacle_rect,
			&"rectangle",
			rng.randf_range(-0.18, 0.18)
		)

func _add_dense_vegetation_cluster(
	layout: BiomeEnvironmentLayout,
	block_rect: Rect2i,
	rng: RandomNumberGenerator
) -> void:
	var cluster_size := Vector2i(
		clampi(
			int(float(block_rect.size.x) * rng.randf_range(0.46, 0.64)),
			_legacy_cells(18),
			maxi(block_rect.size.x - _legacy_cells(8), _legacy_cells(18))
		),
		clampi(
			int(float(block_rect.size.y) * rng.randf_range(0.46, 0.64)),
			_legacy_cells(16),
			maxi(block_rect.size.y - _legacy_cells(8), _legacy_cells(16))
		)
	)
	var centered := _centered_rect(block_rect, cluster_size)
	var offsets: Array[Vector2i] = [
		Vector2i.ZERO,
		Vector2i(0, -block_rect.size.y / 4),
		Vector2i(0, block_rect.size.y / 4),
		Vector2i(-block_rect.size.x / 5, 0),
		Vector2i(block_rect.size.x / 5, 0)
	]
	for offset in offsets:
		var cluster_rect := _fit_rect_inside(centered.position + offset, cluster_size, block_rect)
		if _add_obstacle_if_clear(
			layout,
			&"dense_vegetation",
			cluster_rect,
			&"rectangle",
			rng.randf_range(-0.12, 0.12)
		):
			return

func _add_starter_roadside_details(
	layout: BiomeEnvironmentLayout,
	biome: BiomeDefinition,
	rng: RandomNumberGenerator
) -> void:
	if biome == null or biome.biome_id != &"infected_plains":
		return
	var center := layout.zone_size / 2
	var car_rects: Array[Rect2i] = [
		Rect2i(
			center + Vector2i(-_legacy_cells(105), _span_before_center(ROAD_WIDTH) + _legacy_cells(12)),
			_legacy_rect_size(16, 8)
		),
		Rect2i(
			center + Vector2i(_legacy_cells(82), -_span_before_center(ROAD_WIDTH) - _legacy_cells(26)),
			_legacy_rect_size(17, 8)
		)
	]
	for index in range(car_rects.size()):
		_add_obstacle_if_clear(
			layout,
			&"abandoned_car",
			car_rects[index],
			&"rectangle",
			rng.randf_range(-0.24, 0.24)
		)
	for index in range(layout.block_rects.size()):
		if index >= layout.block_kinds.size() or layout.block_kinds[index] != &"building":
			continue
		var block_rect := layout.block_rects[index]
		var fence_rect := Rect2i(
			block_rect.position + Vector2i(
				_legacy_cells(8),
				maxi(block_rect.size.y - _legacy_cells(10), _legacy_cells(8))
			),
			Vector2i(
				maxi(
					mini(block_rect.size.x - _legacy_cells(16), _legacy_cells(22)),
					_legacy_cells(10)
				),
				_legacy_cells(4)
			)
		)
		_add_obstacle_if_clear(
			layout,
			&"broken_fence",
			fence_rect,
			&"rectangle",
			rng.randf_range(-0.08, 0.08)
		)
		return

func _ensure_starter_dense_obstacle(
	layout: BiomeEnvironmentLayout,
	biome: BiomeDefinition,
	rng: RandomNumberGenerator
) -> void:
	if biome == null or biome.biome_id != &"infected_plains":
		return
	if layout.obstacle_ids.has(&"dense_vegetation"):
		return
	var preferred_kinds: Array[StringName] = [&"dense_vegetation", &"forest", &"open"]
	for preferred_kind in preferred_kinds:
		for index in range(layout.block_rects.size()):
			var block_kind := (
				layout.block_kinds[index]
				if index < layout.block_kinds.size()
				else &"open"
			)
			if block_kind != preferred_kind:
				continue
			var block_rect := layout.block_rects[index]
			var cluster_size := Vector2i(
				clampi(
					int(float(block_rect.size.x) * 0.38),
					_legacy_cells(16),
					maxi(block_rect.size.x - _legacy_cells(10), _legacy_cells(16))
				),
				clampi(
					int(float(block_rect.size.y) * 0.34),
					_legacy_cells(14),
					maxi(block_rect.size.y - _legacy_cells(10), _legacy_cells(14))
				)
			)
			var centered := _centered_rect(block_rect, cluster_size)
			var offsets: Array[Vector2i] = [
				Vector2i.ZERO,
				Vector2i(0, -block_rect.size.y / 4),
				Vector2i(0, block_rect.size.y / 4),
				Vector2i(-block_rect.size.x / 5, 0),
				Vector2i(block_rect.size.x / 5, 0)
			]
			for offset in offsets:
				var cluster_rect := _fit_rect_inside(
					centered.position + offset,
					cluster_size,
					block_rect
				)
				if _add_obstacle_if_clear(
					layout,
					&"dense_vegetation",
					cluster_rect,
					&"rectangle",
					rng.randf_range(-0.10, 0.10)
				):
					return

func _ensure_starter_3x3_obstacles(
	layout: BiomeEnvironmentLayout,
	biome: BiomeDefinition
) -> void:
	if biome == null or biome.biome_id != &"infected_plains":
		return
	var preferred_kinds: Dictionary = {
		&"forest_tree": [&"forest", &"dense_vegetation", &"open", &"ruins"],
		&"large_rock": [&"large_obstacle", &"ruins", &"open", &"forest"]
	}
	for obstacle_id_value in [&"forest_tree", &"large_rock"]:
		var obstacle_id := obstacle_id_value as StringName
		if layout.obstacle_ids.has(obstacle_id):
			continue
		var placed := false
		for preferred_kind_value in preferred_kinds[obstacle_id] as Array:
			var preferred_kind := preferred_kind_value as StringName
			for index in range(layout.block_rects.size()):
				var block_kind := (
					layout.block_kinds[index]
					if index < layout.block_kinds.size()
					else &"open"
				)
				if block_kind != preferred_kind:
					continue
				if _place_feature_obstacle_in_block(
					layout,
					obstacle_id,
					layout.block_rects[index]
				):
					placed = true
					break
			if placed:
				break
		if placed:
			continue
		_place_feature_obstacle_at_fallback(layout, obstacle_id)

func _place_feature_obstacle_in_block(
	layout: BiomeEnvironmentLayout,
	obstacle_id: StringName,
	block_rect: Rect2i
) -> bool:
	var footprint := _logical_footprint_tiles(obstacle_id)
	var margin := _legacy_cells(6)
	if block_rect.size.x < footprint.x + margin * 2 or block_rect.size.y < footprint.y + margin * 2:
		return false
	var max_position := block_rect.position + block_rect.size - footprint - Vector2i.ONE * margin
	var center_position := block_rect.position + _center_offset(block_rect.size - footprint)
	var candidates: Array[Vector2i] = [
		block_rect.position + Vector2i.ONE * margin,
		Vector2i(max_position.x, block_rect.position.y + margin),
		Vector2i(block_rect.position.x + margin, max_position.y),
		max_position,
		center_position
	]
	for position in candidates:
		var rect := Rect2i(position, footprint)
		if not _rect_is_walkable(layout, rect):
			continue
		if _add_obstacle_if_clear(layout, obstacle_id, rect, &"rectangle", 0.0):
			return true
	return false

func _place_feature_obstacle_at_fallback(
	layout: BiomeEnvironmentLayout,
	obstacle_id: StringName
) -> bool:
	var footprint := _logical_footprint_tiles(obstacle_id)
	var ratios: Array[Vector2] = [
		Vector2(0.16, 0.16),
		Vector2(0.84, 0.16),
		Vector2(0.16, 0.84),
		Vector2(0.84, 0.84),
		Vector2(0.50, 0.16),
		Vector2(0.16, 0.50),
		Vector2(0.84, 0.50),
		Vector2(0.50, 0.84)
	]
	for ratio in ratios:
		var center := Vector2i(
			roundi(float(layout.zone_size.x) * ratio.x),
			roundi(float(layout.zone_size.y) * ratio.y)
		)
		var rect := Rect2i(center - _center_offset(footprint), footprint)
		if not _rect_is_walkable(layout, rect):
			continue
		if _add_obstacle_if_clear(layout, obstacle_id, rect, &"rectangle", 0.0):
			return true
	return false

func _rect_is_walkable(layout: BiomeEnvironmentLayout, rect: Rect2i) -> bool:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if (
				layout.get_terrain_class_at_cell(Vector2i(x, y))
				!= BiomeEnvironmentLayout.TERRAIN_WALKABLE
			):
				return false
	return true

func _ensure_starter_house_obstacle(
	layout: BiomeEnvironmentLayout,
	biome: BiomeDefinition,
	rng: RandomNumberGenerator
) -> void:
	if biome == null or biome.biome_id != &"infected_plains":
		return
	if layout.obstacle_ids.has(&"ruined_house"):
		return
	var preferred_kinds: Array[StringName] = [&"building", &"open", &"ruins"]
	for preferred_kind in preferred_kinds:
		for index in range(layout.block_rects.size()):
			var block_kind := (
				layout.block_kinds[index]
				if index < layout.block_kinds.size()
				else &"open"
			)
			if block_kind != preferred_kind:
				continue
			var block_rect := layout.block_rects[index]
			var house_size := Vector2i(
				clampi(
					_legacy_cells(28),
					_legacy_cells(18),
					maxi(block_rect.size.x - _legacy_cells(12), _legacy_cells(18))
				),
				clampi(
					_legacy_cells(24),
					_legacy_cells(16),
					maxi(block_rect.size.y - _legacy_cells(12), _legacy_cells(16))
				)
			)
			var centered := _centered_rect(block_rect, house_size)
			var offsets: Array[Vector2i] = [
				Vector2i.ZERO,
				Vector2i(-block_rect.size.x / 5, 0),
				Vector2i(block_rect.size.x / 5, 0),
				Vector2i(0, -block_rect.size.y / 5),
				Vector2i(0, block_rect.size.y / 5)
			]
			for offset in offsets:
				var house_rect := _fit_rect_inside(
					centered.position + offset,
					house_size,
					block_rect
				)
				if _add_obstacle_if_clear(
					layout,
					&"ruined_house",
					house_rect,
					&"rectangle",
					rng.randf_range(-0.08, 0.08)
				):
					return

func _add_secondary_obstacles(
	layout: BiomeEnvironmentLayout,
	biome: BiomeDefinition,
	rng: RandomNumberGenerator
) -> void:
	var ids := _secondary_obstacle_ids(biome.biome_id)
	var placed := 0
	for index in range(layout.block_rects.size()):
		if placed >= 8:
			return
		var block_kind := (
			layout.block_kinds[index]
			if index < layout.block_kinds.size()
			else &"open"
		)
		if block_kind == &"full_void" or block_kind == &"partial_void":
			continue
		var block_rect := layout.block_rects[index]
		var horizontal := rng.randi_range(0, 1) == 0
		var size := (
			Vector2i(rng.randi_range(_legacy_cells(10), _legacy_cells(18)), _legacy_cells(4))
			if horizontal
			else Vector2i(_legacy_cells(4), rng.randi_range(_legacy_cells(10), _legacy_cells(18)))
		)
		var offset := Vector2i(
			rng.randi_range(
				_legacy_cells(6),
				maxi(block_rect.size.x - size.x - _legacy_cells(6), _legacy_cells(6))
			),
			rng.randi_range(
				_legacy_cells(6),
				maxi(block_rect.size.y - size.y - _legacy_cells(6), _legacy_cells(6))
			)
		)
		var rect := Rect2i(block_rect.position + offset, size)
		_add_obstacle_if_clear(
			layout,
			ids[(index + placed) % ids.size()],
			rect,
			&"rectangle",
			rng.randf_range(-0.3, 0.3)
		)
		placed += 1

func _add_block_props(
	layout: BiomeEnvironmentLayout,
	biome: BiomeDefinition,
	rng: RandomNumberGenerator
) -> void:
	# Enrich each non-void block with small thematic props so open areas read as
	# finished spaces, not empty rectangles. Props are placed only on clear
	# interior cells (never on routes, obstacles, fall zones or hazards), so they
	# add detail without breaking pathfinding.
	var prop_ids := _small_prop_ids(biome.biome_id if biome != null else &"")
	if prop_ids.is_empty():
		return
	var placed := 0
	for index in range(layout.block_rects.size()):
		if placed >= MAX_BLOCK_PROPS:
			return
		var kind := (
			layout.block_kinds[index]
			if index < layout.block_kinds.size()
			else &"open"
		)
		if kind == &"full_void" or kind == &"dense_vegetation":
			continue
		var block_rect := layout.block_rects[index]
		var attempts := _prop_attempts_for_kind(kind, block_rect)
		for _attempt in range(attempts):
			if placed >= MAX_BLOCK_PROPS:
				break
			var prop_id := prop_ids[rng.randi_range(0, prop_ids.size() - 1)]
			var size := _prop_size(prop_id, rng)
			var max_x := maxi(block_rect.size.x - size.x - PROP_BLOCK_MARGIN, PROP_BLOCK_MARGIN)
			var max_y := maxi(block_rect.size.y - size.y - PROP_BLOCK_MARGIN, PROP_BLOCK_MARGIN)
			var pos := block_rect.position + Vector2i(
				rng.randi_range(PROP_BLOCK_MARGIN, max_x),
				rng.randi_range(PROP_BLOCK_MARGIN, max_y)
			)
			if _add_prop_if_clear(layout, prop_id, Rect2i(pos, size), rng):
				placed += 1

func _prop_attempts_for_kind(kind: StringName, block_rect: Rect2i) -> int:
	var equivalent_legacy_area := (
		block_rect.size.x
		* block_rect.size.y
		* WorldGridConfig.NEW_TILE_SCALE
		* WorldGridConfig.NEW_TILE_SCALE
	)
	var area_budget := int(float(equivalent_legacy_area) / 1100.0)
	var density := 2
	match kind:
		&"forest":
			density = 6
		&"ruins":
			density = 5
		&"open":
			density = 3
		&"large_obstacle", &"building", &"partial_void":
			density = 2
		_:
			density = 2
	if density <= 0:
		return 0
	return clampi(area_budget, 1, density)

func _add_prop_if_clear(
	layout: BiomeEnvironmentLayout,
	prop_id: StringName,
	rect: Rect2i,
	rng: RandomNumberGenerator
) -> bool:
	var canonical_rect := _canonical_obstacle_rect(prop_id, rect)
	var padded := GeometryUtils.inflate_rect(canonical_rect, MIN_RECT_GAP)
	if layout.rect_intersects_route(padded):
		return false
	if GeometryUtils.intersects_any(padded, layout.obstacle_rects):
		return false
	if GeometryUtils.intersects_any(canonical_rect, layout.fall_zone_rects):
		return false
	if GeometryUtils.intersects_any(canonical_rect, layout.hazard_rects):
		return false
	if _contains_any_crate(canonical_rect, layout.crate_cells):
		return false
	_add_obstacle(
		layout,
		prop_id,
		canonical_rect,
		&"rectangle",
		rng.randf_range(-0.4, 0.4)
	)
	return true

func _prop_size(prop_id: StringName, _rng: RandomNumberGenerator) -> Vector2i:
	return _logical_footprint_tiles(prop_id)

func _small_prop_ids(biome_id: StringName) -> Array[StringName]:
	# Only contract-complete, biome-whitelisted ids so props always render with a
	# finished look (no placeholders). Bespoke bush/lamp art is a later R3 step.
	match biome_id:
		&"toxic_wastes":
			return [&"small_rock", &"toxic_barrel", &"industrial_fence"]
		&"burning_fields":
			return [&"small_rock", &"ash_barrier", &"broken_fence"]
		&"frozen_outskirts":
			return [&"ice_rock", &"fallen_log", &"small_rock"]
		&"drowned_marsh":
			return [&"marsh_log", &"small_rock", &"reed_wall"]
		_:
			return [&"small_rock", &"broken_fence", &"fallen_log"]

func _add_connected_border_walls(
	layout: BiomeEnvironmentLayout,
	cell: BiomeCell,
	biome: BiomeDefinition,
	context: Dictionary = {}
) -> void:
	var border_obstacle_id := _border_obstacle_id(biome.biome_id if biome != null else &"")
	var solid_walled_arena := _is_walled_arena_context(context)
	for side in BiomeCell.SIDES:
		var border_type := cell.get_border(side)
		if border_type == BiomeCell.BorderType.FALL:
			continue
		var axis_limit := _side_axis_limit(layout, side)
		var gaps: Array[Vector2i] = []
		if not solid_walled_arena:
			gaps = _wall_gaps_for_side(layout, cell, side, axis_limit)
		var wall_span := (
			_walled_arena_wall_span(side, axis_limit)
			if solid_walled_arena
			else _wall_axis_span_away_from_fall_corners(
				cell,
				side,
				axis_limit
			)
		)
		# Wall the side, leaving a clean physical opening for every passage so
		# additional (extra-edge) connections are never sealed shut. If an
		# endpoint touches an external fall side, leave that corner as pure void.
		var cursor := wall_span.x
		for gap in gaps:
			if cursor >= wall_span.y:
				break
			_add_border_segment(
				layout,
				side,
				cursor,
				mini(gap.x, wall_span.y),
				border_obstacle_id
			)
			cursor = maxi(cursor, gap.y)
		_add_border_segment(
			layout,
			side,
			cursor,
			wall_span.y,
			border_obstacle_id
		)

func _walled_arena_wall_span(
	side: StringName,
	axis_limit: int
) -> Vector2i:
	# North/south own the four corner footprints. The vertical sides stop at
	# their inner edges so collision and raised-cliff crowns never overlap.
	if side == &"west" or side == &"east":
		return Vector2i(
			BORDER_THICKNESS,
			maxi(axis_limit - BORDER_THICKNESS, BORDER_THICKNESS)
		)
	return Vector2i(0, axis_limit)

func _wall_gaps_for_side(
	layout: BiomeEnvironmentLayout,
	cell: BiomeCell,
	side: StringName,
	axis_limit: int
) -> Array[Vector2i]:
	var gaps := _passage_gaps_for_side(cell, side, axis_limit)
	# Decorative roads may reach a blocked edge, but they terminate against its
	# wall. Only a CONNECTED side is allowed to turn route geometry into a physical
	# opening; its authored passage remains the primary gap authority.
	if cell.get_border(side) == BiomeCell.BorderType.CONNECTED:
		gaps.append_array(_road_gaps_for_side(layout, side, axis_limit))
		gaps.append_array(_road_cell_gaps_for_side(layout, side, axis_limit))
	gaps.append_array(_void_gaps_for_side(layout, side, axis_limit))
	gaps.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x)
	var merged: Array[Vector2i] = []
	for gap in gaps:
		if merged.is_empty() or gap.x > merged.back().y:
			merged.append(gap)
			continue
		var previous: Vector2i = merged.pop_back()
		merged.append(Vector2i(previous.x, maxi(previous.y, gap.y)))
	return merged

func _road_gaps_for_side(
	layout: BiomeEnvironmentLayout,
	side: StringName,
	axis_limit: int
) -> Array[Vector2i]:
	var gaps: Array[Vector2i] = []
	for rect in layout.road_rects:
		var touches_side := false
		var start := 0
		var finish := 0
		match side:
			&"north":
				touches_side = rect.position.y <= BORDER_THICKNESS
				start = rect.position.x
				finish = rect.end.x
			&"south":
				touches_side = rect.end.y >= layout.zone_size.y - BORDER_THICKNESS
				start = rect.position.x
				finish = rect.end.x
			&"west":
				touches_side = rect.position.x <= BORDER_THICKNESS
				start = rect.position.y
				finish = rect.end.y
			_:
				touches_side = rect.end.x >= layout.zone_size.x - BORDER_THICKNESS
				start = rect.position.y
				finish = rect.end.y
		if not touches_side:
			continue
		start = clampi(start - WorldGridConfig.WALL_GAP_PADDING_TILES, 0, axis_limit)
		finish = clampi(finish + WorldGridConfig.WALL_GAP_PADDING_TILES, 0, axis_limit)
		if finish > start:
			gaps.append(Vector2i(start, finish))
	return gaps

# Void-first roads are carved as road cells (not rects), so the wall must also open
# where road cells reach the side. Scans the inner-edge line and groups contiguous
# road-cell runs into gaps.
func _road_cell_gaps_for_side(
	layout: BiomeEnvironmentLayout,
	side: StringName,
	axis_limit: int
) -> Array[Vector2i]:
	var gaps: Array[Vector2i] = []
	if layout.road_cell_tags.is_empty():
		return gaps
	var probe := BORDER_THICKNESS
	var run_start := -1
	for axis in range(axis_limit):
		var cell: Vector2i
		match side:
			&"north":
				cell = Vector2i(axis, probe)
			&"south":
				cell = Vector2i(axis, layout.zone_size.y - 1 - probe)
			&"west":
				cell = Vector2i(probe, axis)
			_:
				cell = Vector2i(layout.zone_size.x - 1 - probe, axis)
		if layout.has_road_cell(cell):
			if run_start < 0:
				run_start = axis
		elif run_start >= 0:
			gaps.append(Vector2i(
				clampi(run_start - WorldGridConfig.WALL_GAP_PADDING_TILES, 0, axis_limit),
				clampi(axis + WorldGridConfig.WALL_GAP_PADDING_TILES, 0, axis_limit)
			))
			run_start = -1
	if run_start >= 0:
		gaps.append(Vector2i(
			clampi(run_start - WorldGridConfig.WALL_GAP_PADDING_TILES, 0, axis_limit),
			axis_limit
		))
	return gaps

func _void_gaps_for_side(
	layout: BiomeEnvironmentLayout,
	side: StringName,
	axis_limit: int
) -> Array[Vector2i]:
	var gaps: Array[Vector2i] = []
	for void_rect in layout.fall_zone_rects:
		var touches_side := false
		var start := 0
		var finish := 0
		match side:
			&"north":
				touches_side = void_rect.position.y <= 0
				start = void_rect.position.x
				finish = void_rect.end.x
			&"south":
				touches_side = void_rect.end.y >= layout.zone_size.y
				start = void_rect.position.x
				finish = void_rect.end.x
			&"west":
				touches_side = void_rect.position.x <= 0
				start = void_rect.position.y
				finish = void_rect.end.y
			_:
				touches_side = void_rect.end.x >= layout.zone_size.x
				start = void_rect.position.y
				finish = void_rect.end.y
		if not touches_side:
			continue
		start = clampi(start, 0, axis_limit)
		finish = clampi(finish, 0, axis_limit)
		if finish > start:
			gaps.append(Vector2i(start, finish))
	return gaps

func _wall_axis_span_away_from_fall_corners(
	cell: BiomeCell,
	side: StringName,
	axis_limit: int
) -> Vector2i:
	var start_side := &"north" if side == &"west" or side == &"east" else &"west"
	var end_side := &"south" if side == &"west" or side == &"east" else &"east"
	var start := 0
	var finish := axis_limit
	if cell.get_border(start_side) == BiomeCell.BorderType.FALL:
		start += FallBoundaryGenerator.FALL_THICKNESS
	if cell.get_border(end_side) == BiomeCell.BorderType.FALL:
		finish -= FallBoundaryGenerator.FALL_THICKNESS
	return Vector2i(start, maxi(finish, start))

func _side_axis_limit(layout: BiomeEnvironmentLayout, side: StringName) -> int:
	if side == &"west" or side == &"east":
		return layout.zone_size.y
	return layout.zone_size.x

func _passage_gaps_for_side(
	cell: BiomeCell,
	side: StringName,
	axis_limit: int
) -> Array[Vector2i]:
	var gaps: Array[Vector2i] = []
	if cell.get_border(side) != BiomeCell.BorderType.CONNECTED:
		return gaps
	for passage in cell.get_passages_for_side(side):
		var span_before := _span_before_center(passage.width)
		var span_after := _span_after_center(passage.width)
		var start := clampi(
			passage.position - span_before - WorldGridConfig.WALL_GAP_PADDING_TILES,
			0,
			axis_limit
		)
		var finish := clampi(
			passage.position + span_after + WorldGridConfig.WALL_GAP_PADDING_TILES,
			0,
			axis_limit
		)
		if finish > start:
			gaps.append(Vector2i(start, finish))
	gaps.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x)
	return gaps

func _add_border_segment(
	layout: BiomeEnvironmentLayout,
	side: StringName,
	start: int,
	finish: int,
	obstacle_id: StringName
) -> void:
	# Tile the [start, finish) span into contiguous wall-tile segments so the
	# entire perimeter is a continuous cardinal wall, recording the explicit
	# wall contract on the layout for validation and rendering.
	var cursor := start
	while cursor < finish:
		var remaining := finish - cursor
		if remaining < WALL_MIN_SEGMENT:
			break
		var segment_length := mini(WALL_SEGMENT_LENGTH, remaining)
		# Absorb a tiny trailing remainder into the current segment so we never
		# leave a sub-minimum sliver behind.
		if remaining - segment_length > 0 and remaining - segment_length < WALL_MIN_SEGMENT:
			segment_length = remaining
		var rect := _wall_segment_rect(layout, side, cursor, segment_length)
		_add_obstacle(layout, obstacle_id, rect, &"rectangle", 0.0)
		layout.add_wall_segment(rect, side)
		cursor += segment_length

func _wall_segment_rect(
	layout: BiomeEnvironmentLayout,
	side: StringName,
	axis_start: int,
	axis_length: int
) -> Rect2i:
	var zone_size := layout.zone_size
	match side:
		&"north":
			return Rect2i(Vector2i(axis_start, 0), Vector2i(axis_length, BORDER_THICKNESS))
		&"south":
			return Rect2i(
				Vector2i(axis_start, zone_size.y - BORDER_THICKNESS),
				Vector2i(axis_length, BORDER_THICKNESS)
			)
		&"west":
			return Rect2i(Vector2i(0, axis_start), Vector2i(BORDER_THICKNESS, axis_length))
		_:
			return Rect2i(
				Vector2i(zone_size.x - BORDER_THICKNESS, axis_start),
				Vector2i(BORDER_THICKNESS, axis_length)
			)

func _add_obstacle_if_clear(
	layout: BiomeEnvironmentLayout,
	obstacle_id: StringName,
	rect: Rect2i,
	shape_id: StringName,
	rotation_radians: float
) -> bool:
	var canonical_rect := _canonical_obstacle_rect(obstacle_id, rect)
	if layout.rect_intersects_route(GeometryUtils.inflate_rect(canonical_rect, MIN_RECT_GAP)):
		return false
	if GeometryUtils.intersects_any(GeometryUtils.inflate_rect(canonical_rect, MIN_RECT_GAP), layout.obstacle_rects):
		return false
	if GeometryUtils.intersects_any(canonical_rect, layout.fall_zone_rects):
		return false
	if GeometryUtils.intersects_any(canonical_rect, layout.hazard_rects):
		return false
	if _contains_any_crate(canonical_rect, layout.crate_cells):
		return false
	_add_obstacle(layout, obstacle_id, canonical_rect, shape_id, rotation_radians)
	return true

func _legacy_rect_size(width: int, height: int, minimum: int = 1) -> Vector2i:
	return WorldGridConfig.legacy_size_to_new_tiles(Vector2i(width, height), minimum)

func _legacy_cells(value: int, minimum: int = 1) -> int:
	return WorldGridConfig.legacy_cells_to_new_tiles(value, minimum)

func _span_before_center(span: int) -> int:
	return maxi(floori(float(span) * 0.5), 0)

func _span_after_center(span: int) -> int:
	return maxi(span - _span_before_center(span), 0)

func _center_offset(size: Vector2i) -> Vector2i:
	return Vector2i(_span_before_center(size.x), _span_before_center(size.y))

func _logical_footprint_tiles(object_id: StringName) -> Vector2i:
	return WorldGridConfig.legacy_size_to_new_tiles(
		EnvironmentAssetManifest.get_shared().get_footprint_tiles(object_id)
	)

func _contains_any_crate(rect: Rect2i, crate_cells: Array[Vector2i]) -> bool:
	for crate_cell in crate_cells:
		if rect.has_point(crate_cell):
			return true
	return false

func _canonical_obstacle_rect(obstacle_id: StringName, requested: Rect2i) -> Rect2i:
	var manifest := EnvironmentAssetManifest.get_shared()
	if not manifest.has_object(obstacle_id):
		return requested
	# Border segments are intentionally variable-length tiles, and scalable
	# obstacles (rocks) own a per-instance square footprint. Every other obstacle
	# uses the exact manifest footprint so placement, collision and art share one
	# size instead of inheriting generator randomness.
	if manifest.get_category(obstacle_id) == &"border" or manifest.is_scalable(obstacle_id):
		return requested
	var footprint := _logical_footprint_tiles(obstacle_id)
	var center := requested.position + _center_offset(requested.size)
	return Rect2i(center - _center_offset(footprint), footprint)

func _add_crates(
	layout: BiomeEnvironmentLayout,
	biome: BiomeDefinition
) -> void:
	var crate_ids := _crate_ids(biome.biome_id)
	var center := layout.zone_size / 2
	var cells: Array[Vector2i] = [
		center + Vector2i(-WorldGridConfig.LEGACY_CRATE_OFFSET_TILES, 0),
		center + Vector2i(WorldGridConfig.LEGACY_CRATE_OFFSET_TILES, 0),
		center + Vector2i(0, -WorldGridConfig.LEGACY_CRATE_OFFSET_TILES),
		center + Vector2i(0, WorldGridConfig.LEGACY_CRATE_OFFSET_TILES)
	]
	for index in range(cells.size()):
		_add_crate(layout, crate_ids[index % crate_ids.size()], cells[index])

func _add_theme_hazards(
	layout: BiomeEnvironmentLayout,
	biome: BiomeDefinition
) -> void:
	match biome.biome_id:
		&"toxic_wastes":
			_add_hazard_at_ratio(layout, &"toxic_puddle", Vector2(0.42, 0.22), _legacy_rect_size(26, 14))
			_add_hazard_at_ratio(layout, &"gas_cloud", Vector2(0.74, 0.78), _legacy_rect_size(30, 18))
		&"burning_fields":
			_add_hazard_at_ratio(layout, &"lava_crack", Vector2(0.36, 0.76), _legacy_rect_size(34, 10))
			_add_hazard_at_ratio(layout, &"fire_zone", Vector2(0.72, 0.24), _legacy_rect_size(20, 20))
		&"frozen_outskirts":
			_add_hazard_at_ratio(layout, &"slippery_ice", Vector2(0.34, 0.74), _legacy_rect_size(34, 20))
			_add_hazard_at_ratio(layout, &"deep_snow_slow", Vector2(0.74, 0.22), _legacy_rect_size(28, 24))
		&"drowned_marsh":
			_add_hazard_at_ratio(layout, &"deep_water", Vector2(0.30, 0.74), _legacy_rect_size(38, 22))
			_add_hazard_at_ratio(layout, &"mud_slow", Vector2(0.74, 0.26), _legacy_rect_size(28, 22))
		_:
			pass

func _add_obstacle(
	layout: BiomeEnvironmentLayout,
	obstacle_id: StringName,
	rect: Rect2i,
	shape_id: StringName,
	_rotation_radians: float
) -> void:
	layout.obstacle_rects.append(rect)
	layout.obstacle_ids.append(obstacle_id)
	layout.obstacle_positions.append(
		layout.obstacle_rect_center_to_world(rect, obstacle_id)
	)
	layout.obstacle_sizes.append(layout.rect_size_to_world(rect))
	layout.obstacle_rotations.append(0.0)
	layout.obstacle_shape_ids.append(shape_id)

func _add_crate(
	layout: BiomeEnvironmentLayout,
	crate_id: StringName,
	cell: Vector2i
) -> void:
	# A bridge can make a deep-water cell logically walkable, but the current
	# runtime hazard zone still spans the water rect. Keep layout crates off all
	# hazard geometry so generation never advertises a crate that streaming must
	# discard as unsafe.
	for hazard_rect in layout.hazard_rects:
		if hazard_rect.has_point(cell):
			return
	if (
		layout.get_terrain_class_at_cell(cell)
		!= BiomeEnvironmentLayout.TERRAIN_WALKABLE
	):
		return
	layout.crate_cells.append(cell)
	layout.crate_ids.append(crate_id)
	layout.crate_positions.append(layout.logical_to_world(cell))

func _add_hazard(
	layout: BiomeEnvironmentLayout,
	hazard_id: StringName,
	rect: Rect2i
) -> void:
	layout.add_hazard_rect(rect, hazard_id)

func _add_hazard_at_ratio(
	layout: BiomeEnvironmentLayout,
	hazard_id: StringName,
	ratio: Vector2,
	size: Vector2i
) -> void:
	var center := Vector2i(
		roundi(float(layout.zone_size.x) * ratio.x),
		roundi(float(layout.zone_size.y) * ratio.y)
	)
	_add_hazard(
		layout,
		hazard_id,
		Rect2i(center - _center_offset(size), size)
	)

func _large_obstacle_id(biome_id: StringName) -> StringName:
	match biome_id:
		&"toxic_wastes":
			return &"lab_block"
		&"burning_fields":
			return &"burned_house"
		&"frozen_outskirts":
			return &"snow_cabin"
		&"drowned_marsh":
			return &"sunken_house"
		_:
			return &"ruined_house"

func _block_obstacle_id(
	biome_id: StringName,
	block_kind: StringName,
	index: int
) -> StringName:
	match block_kind:
		&"forest":
			match biome_id:
				&"drowned_marsh":
					return &"dead_tree"
				&"frozen_outskirts":
					return &"ice_block"
				&"burning_fields":
					return &"burned_car"
				&"toxic_wastes":
					return &"pipe_stack"
				_:
					return &"fallen_log" if index % 2 == 0 else &"small_rock"
		&"ruins":
			match biome_id:
				&"toxic_wastes":
					return &"lab_wall"
				&"burning_fields":
					return &"charred_wall"
				&"frozen_outskirts":
					return &"snow_wall"
				&"drowned_marsh":
					return &"reed_wall"
				_:
					return &"wood_barrier"
		&"large_obstacle":
			var ids := _secondary_obstacle_ids(biome_id)
			return ids[index % ids.size()]
		_:
			if biome_id == &"infected_plains" and index % 2 == 1:
				return &"abandoned_house"
			return _large_obstacle_id(biome_id)

func _secondary_obstacle_ids(biome_id: StringName) -> Array[StringName]:
	match biome_id:
		&"toxic_wastes":
			return [&"industrial_fence", &"toxic_barrel", &"lab_wall"]
		&"burning_fields":
			return [&"charred_wall", &"ash_barrier", &"burned_car"]
		&"frozen_outskirts":
			return [&"snow_wall", &"ice_rock", &"fallen_log"]
		&"drowned_marsh":
			return [&"reed_wall", &"marsh_log", &"broken_walkway"]
		_:
			return [&"small_rock", &"broken_fence", &"wood_barrier", &"abandoned_car"]

func _border_obstacle_id(biome_id: StringName) -> StringName:
	match biome_id:
		&"toxic_wastes":
			return &"toxic_boundary_wall"
		&"burning_fields":
			return &"lava_boundary"
		&"frozen_outskirts":
			return &"ice_boundary"
		&"drowned_marsh":
			return &"deep_water_boundary"
		_:
			return &"boundary_fence"

func _crate_ids(biome_id: StringName) -> Array[StringName]:
	match biome_id:
		&"toxic_wastes":
			return [&"biome_toxic", &"medical", &"common"]
		&"burning_fields":
			return [&"biome_fire", &"military", &"common"]
		&"frozen_outskirts":
			return [&"biome_frost", &"medical", &"common"]
		&"drowned_marsh":
			return [&"biome_marsh", &"common", &"medical"]
		_:
			return [&"common", &"medical", &"common"]

func _voidfirst_internal_chasm_min_count(biome: BiomeDefinition) -> int:
	if biome != null and biome.generation_profile != null:
		return maxi(biome.generation_profile.internal_chasm_min_count, 0)
	return 1

# Per-biome asset palette for the void-first pipeline. infected_plains resolves to
# the historical literals so its output stays byte-identical (rock-area + forest
# rendering only exist for the forest biome). The four thematic biomes reuse
# existing selectors so the shared structure — rock/mass scatter, vegetation
# clusters, hub+spokes roads, void lottery — is skinned per biome with no new art:
#   - scatter_ids: solid masses for the "rock" pass (no scalable rock outside plains)
#   - cluster_id / cluster_floor: the "forest" pass obstacle + its floor tag
#   - road_tag / spoke_tag: wall-spoke (main) and passage-spoke (lane) road tags
#   - line_vegetation: whether open-void roads get a cluster tree-lining
func _voidfirst_palette(biome_id: StringName) -> Dictionary:
	match biome_id:
		# road_tag stays main_road for every biome: it is the universal, biome-tinted
		# main-road network the validator and renderer expect at the centre. Only the
		# passage-spoke/trail tag is skinned to the biome's thematic lane.
		&"toxic_wastes":
			return {
				"rock_scalable": false,
				"scatter_ids": [&"lab_block", &"pipe_stack", &"industrial_fence"],
				"cluster_id": &"toxic_barrel",
				"cluster_floor": &"open_block",
				"road_tag": &"main_road",
				"spoke_tag": &"service_lane",
				"line_vegetation": false,
			}
		&"burning_fields":
			return {
				"rock_scalable": false,
				"scatter_ids": [&"burned_house", &"burned_car", &"charred_wall"],
				"cluster_id": &"ash_barrier",
				"cluster_floor": &"open_block",
				"road_tag": &"main_road",
				"spoke_tag": &"ash_lane",
				"line_vegetation": false,
			}
		&"frozen_outskirts":
			return {
				"rock_scalable": false,
				"scatter_ids": [&"snow_cabin", &"ice_rock", &"snow_wall"],
				"cluster_id": &"ice_block",
				"cluster_floor": &"open_block",
				"road_tag": &"main_road",
				"spoke_tag": &"packed_snow_path",
				"line_vegetation": false,
			}
		&"drowned_marsh":
			return {
				"rock_scalable": false,
				"scatter_ids": [&"sunken_house", &"marsh_log", &"reed_wall"],
				"cluster_id": &"dead_tree",
				"cluster_floor": &"open_block",
				"road_tag": &"main_road",
				"spoke_tag": &"wooden_walkway",
				"line_vegetation": false,
			}
		_:
			return {
				"rock_scalable": true,
				"scatter_ids": [&"large_rock"],
				"cluster_id": &"forest_tree",
				"cluster_floor": &"forest_tall_grass",
				"road_tag": &"main_road",
				"spoke_tag": &"broken_street",
				"line_vegetation": true,
			}

func _update_generation_summary(
	layout: BiomeEnvironmentLayout,
	biome: BiomeDefinition
) -> void:
	var obstacle_counts: Dictionary = {}
	for obstacle_id in layout.obstacle_ids:
		obstacle_counts[obstacle_id] = int(obstacle_counts.get(obstacle_id, 0)) + 1

	var block_counts: Dictionary = {}
	for block_kind in layout.block_kinds:
		block_counts[block_kind] = int(block_counts.get(block_kind, 0)) + 1

	var main_road_count := 0
	var path_count := 0
	for tag_value in layout.road_rect_tags:
		var tag := tag_value as StringName
		if tag == &"main_road":
			main_road_count += 1
		elif tag != &"bridge" and not _is_passage_route_tag(tag):
			path_count += 1

	var house_count := _count_obstacle_ids(
		obstacle_counts,
		[
			&"ruined_house",
			&"abandoned_house",
			&"lab_block",
			&"burned_house",
			&"snow_cabin",
			&"sunken_house"
		]
	)
	var car_count := _count_obstacle_ids(
		obstacle_counts,
		[&"abandoned_car", &"burned_car", &"metal_wreck", &"sunken_wreck"]
	)
	var fence_count := _count_obstacle_ids(
		obstacle_counts,
		[
			&"broken_fence",
			&"wood_barrier",
			&"boundary_fence",
			&"industrial_fence",
			&"reed_wall",
			&"snow_wall",
			&"charred_wall"
		]
	)
	var dense_count := (
		int(block_counts.get(&"dense_vegetation", 0))
		+ int(obstacle_counts.get(&"dense_vegetation", 0))
	)
	var random_prop_counts: Dictionary = {}
	for prop_id in layout.random_prop_ids:
		random_prop_counts[prop_id] = int(random_prop_counts.get(prop_id, 0)) + 1
	var static_hazard_counts: Dictionary = {}
	var static_hazard_count := 0
	for hazard_id in layout.hazard_ids:
		if hazard_id == &"fall_zone":
			continue
		static_hazard_count += 1
		static_hazard_counts[hazard_id] = (
			int(static_hazard_counts.get(hazard_id, 0)) + 1
		)
	layout.generation_summary = {
		"biome_id": String(biome.biome_id) if biome != null else "",
		"seed": layout.generation_seed,
		"main_road_count": main_road_count,
		"path_count": path_count,
		"house_count": house_count,
		"dense_vegetation_count": dense_count,
		"bridge_count": layout.bridge_rects.size(),
		"river_count": (
			1
			if biome != null and biome.biome_id == &"infected_plains" and layout.water_rects.size() > 0
			else 0
		),
		"water_segment_count": layout.water_rects.size(),
		"car_count": car_count,
		"fence_count": fence_count,
		"mesa_count": layout.mesa_rects.size(),
		"mass_count": layout.mass_rects.size(),
		"random_prop_count": layout.random_prop_rects.size(),
		"random_prop_counts": random_prop_counts,
		"static_hazard_count": static_hazard_count,
		"static_hazard_counts": static_hazard_counts,
		"obstacle_counts": obstacle_counts,
		"block_counts": block_counts
	}
	layout.generation_summary["terrain_parcels"] = layout.get_parcel_report()

func _count_obstacle_ids(
	obstacle_counts: Dictionary,
	ids: Array[StringName]
) -> int:
	var total := 0
	for id in ids:
		total += int(obstacle_counts.get(id, 0))
	return total

func _is_passage_route_tag(tag: StringName) -> bool:
	return (
		tag == &"road"
		or tag == &"snow_pass"
		or tag == &"broken_gate"
		or tag == &"burned_road"
	)

func _voidfirst_solid_rects(layout: BiomeEnvironmentLayout) -> Array[Rect2i]:
	var result: Array[Rect2i] = []
	result.append_array(layout.mesa_rects)
	result.append_array(layout.mass_rects)
	# Direct unit fixtures and old snapshots may still carry only rock_rects.
	for rect in layout.rock_rects:
		if not result.has(rect):
			result.append(rect)
	return result

func _cell_inside_any_rect(cell: Vector2i, rects: Array[Rect2i]) -> bool:
	for rect in rects:
		if rect.has_point(cell):
			return true
	return false

func _inset_rect(rect: Rect2i, amount: int) -> Rect2i:
	var inset := mini(amount, _span_before_center(mini(rect.size.x, rect.size.y)))
	return Rect2i(
		rect.position + Vector2i(inset, inset),
		rect.size - Vector2i(inset * 2, inset * 2)
	)

func _centered_rect(container: Rect2i, size: Vector2i) -> Rect2i:
	var clamped_size := Vector2i(
		mini(size.x, container.size.x),
		mini(size.y, container.size.y)
	)
	return Rect2i(
		container.position + _center_offset(container.size - clamped_size),
		clamped_size
	)

func _fit_rect_inside(
	position: Vector2i,
	size: Vector2i,
	container: Rect2i
) -> Rect2i:
	var margin := _legacy_cells(4)
	var min_x := container.position.x + margin
	var min_y := container.position.y + margin
	var max_x := maxi(container.end.x - size.x - margin, min_x)
	var max_y := maxi(container.end.y - size.y - margin, min_y)
	return Rect2i(
		Vector2i(
			clampi(position.x, min_x, max_x),
			clampi(position.y, min_y, max_y)
		),
		size
	)

func _route_cell_key(layout: BiomeEnvironmentLayout, cell: Vector2i) -> int:
	return cell.y * layout.zone_size.x + cell.x
