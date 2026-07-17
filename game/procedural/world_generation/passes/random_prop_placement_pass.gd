extends RefCounted
class_name RandomPropPlacementPass

const WorldGridConfig = preload("res://game/core/world_grid_config.gd")

## Default shared budget for sparse, final-floor biome props.
const MIN_COUNT: int = 10
const MAX_COUNT: int = 16
const ATTEMPTS: int = 1200
const BORDER_MARGIN: int = 2
const SPAWN_CLEARANCE: int = 6

const BORDER_THICKNESS: int = WorldGridConfig.BORDER_THICKNESS_TILES
const GAP: int = WorldGridConfig.MIN_RECT_GAP_TILES
const REQUIRED_CATEGORY_COUNT: int = 2


## Places weighted biome props on the final walkable floor and records every
## placement both as a runtime obstacle and as explicit random-prop membership.
##
## Rejection sampling preserves the historical seeded distribution. If it does
## not reach the selected target, an exhaustive deterministic scan tries every
## valid pool ID and every legal origin. Consequently, a result below the
## configured minimum means that no remaining candidate footprint physically
## fits the current layout under the route, passage, blocker, hazard, crate,
## spawn-clearance and final-floor constraints.
func place(
	layout: BiomeEnvironmentLayout,
	biome: BiomeDefinition,
	rng: RandomNumberGenerator,
	categories: Dictionary,
	rejection_attempt_limit: int = ATTEMPTS
) -> int:
	var pool := _prop_pool(biome)
	if pool.is_empty():
		return 0

	var minimum := MIN_COUNT
	var maximum := MAX_COUNT
	if biome != null and biome.generation_profile != null:
		minimum = biome.generation_profile.random_prop_min_count
		maximum = biome.generation_profile.random_prop_max_count
	minimum = maxi(minimum, 0)
	maximum = maxi(maximum, minimum)
	var target := rng.randi_range(minimum, maximum)
	if target <= 0:
		return 0

	var required_ids := _required_category_ids(
		pool,
		mini(REQUIRED_CATEGORY_COUNT, target),
		categories
	)
	var placed := _place_by_rejection_sampling(
		layout,
		pool,
		required_ids,
		target,
		rng,
		maxi(rejection_attempt_limit, 0)
	)
	if placed < target:
		placed += _place_by_deterministic_scan(
			layout,
			pool,
			target - placed,
			target,
			rng,
			categories
		)
	return placed


func _place_by_rejection_sampling(
	layout: BiomeEnvironmentLayout,
	pool: Array[Dictionary],
	required_ids: Array[StringName],
	target: int,
	rng: RandomNumberGenerator,
	attempt_limit: int
) -> int:
	var placed := 0
	var attempts := 0
	while placed < target and attempts < attempt_limit:
		attempts += 1
		var prop_id := (
			required_ids[placed]
			if placed < required_ids.size()
			else _weighted_prop_id(pool, rng)
		)
		var footprint := _logical_footprint_tiles(prop_id)
		var rect := _random_rect_for_footprint(layout, footprint, rng)
		if rect.size.x <= 0 or rect.size.y <= 0:
			continue
		if not _can_place(layout, rect):
			continue
		_register_prop(layout, prop_id, rect, rng.randf_range(-0.35, 0.35))
		placed += 1
	return placed


## The fallback first completes category diversity, trying alternate IDs if a
## category's first footprint cannot fit. It then fills with smallest footprints
## first. Each unsuccessful fill round has scanned every valid ID at every legal
## origin, which makes lack of physical space the only below-target outcome.
func _place_by_deterministic_scan(
	layout: BiomeEnvironmentLayout,
	pool: Array[Dictionary],
	remaining_target: int,
	total_target: int,
	rng: RandomNumberGenerator,
	categories: Dictionary
) -> int:
	var placed := 0
	var ordered_pool := _fallback_order(pool)
	var available_categories := _available_categories(ordered_pool, categories)
	var represented_categories := _represented_categories(
		layout,
		available_categories,
		categories
	)
	var diversity_target := mini(
		REQUIRED_CATEGORY_COUNT,
		mini(total_target, available_categories.size())
	)

	for rule in ordered_pool:
		if placed >= remaining_target or represented_categories.size() >= diversity_target:
			break
		var prop_id := StringName(rule.get("id", &""))
		var category := _category_for(prop_id, categories)
		if category.is_empty() or represented_categories.has(category):
			continue
		var rect := _scan_rect_for_footprint(
			layout,
			_logical_footprint_tiles(prop_id)
		)
		if rect.size.x <= 0 or rect.size.y <= 0:
			continue
		_register_prop(layout, prop_id, rect, rng.randf_range(-0.35, 0.35))
		represented_categories[category] = true
		placed += 1

	while placed < remaining_target:
		var added := false
		for rule in ordered_pool:
			var prop_id := StringName(rule.get("id", &""))
			var rect := _scan_rect_for_footprint(
				layout,
				_logical_footprint_tiles(prop_id)
			)
			if rect.size.x <= 0 or rect.size.y <= 0:
				continue
			_register_prop(layout, prop_id, rect, rng.randf_range(-0.35, 0.35))
			placed += 1
			added = true
			break
		if not added:
			break
	return placed


func _random_rect_for_footprint(
	layout: BiomeEnvironmentLayout,
	footprint: Vector2i,
	rng: RandomNumberGenerator
) -> Rect2i:
	if footprint.x <= 0 or footprint.y <= 0:
		return Rect2i()
	var lo := BORDER_THICKNESS + BORDER_MARGIN
	var hi_x := layout.zone_size.x - lo - footprint.x
	var hi_y := layout.zone_size.y - lo - footprint.y
	if hi_x < lo or hi_y < lo:
		return Rect2i()
	return Rect2i(
		Vector2i(rng.randi_range(lo, hi_x), rng.randi_range(lo, hi_y)),
		footprint
	)


func _scan_rect_for_footprint(
	layout: BiomeEnvironmentLayout,
	footprint: Vector2i
) -> Rect2i:
	if footprint.x <= 0 or footprint.y <= 0:
		return Rect2i()
	var lo := BORDER_THICKNESS + BORDER_MARGIN
	var hi_x := layout.zone_size.x - lo - footprint.x
	var hi_y := layout.zone_size.y - lo - footprint.y
	if hi_x < lo or hi_y < lo:
		return Rect2i()
	for y in range(lo, hi_y + 1):
		for x in range(lo, hi_x + 1):
			var rect := Rect2i(Vector2i(x, y), footprint)
			if _can_place(layout, rect):
				return rect
	return Rect2i()


func _can_place(layout: BiomeEnvironmentLayout, rect: Rect2i) -> bool:
	var padded := GeometryUtils.inflate_rect(rect, GAP)
	if layout.rect_intersects_route(padded):
		return false
	if layout.rect_overlaps_passage_corridor(padded):
		return false
	if GeometryUtils.intersects_any(padded, layout.obstacle_rects):
		return false
	if GeometryUtils.intersects_any(rect, layout.mesa_rects):
		return false
	if GeometryUtils.intersects_any(rect, layout.mass_rects):
		return false
	if GeometryUtils.intersects_any(rect, layout.fall_zone_rects):
		return false
	if GeometryUtils.intersects_any(rect, layout.hazard_rects):
		return false
	if _contains_crate(rect, layout.crate_cells):
		return false
	var spawn_clearance := Rect2i(
		layout.player_spawn_cell - Vector2i.ONE * SPAWN_CLEARANCE,
		Vector2i.ONE * (SPAWN_CLEARANCE * 2 + 1)
	)
	if rect.intersects(spawn_clearance):
		return false
	return _rect_is_final_floor(layout, rect)


func _rect_is_final_floor(layout: BiomeEnvironmentLayout, rect: Rect2i) -> bool:
	if (
		rect.position.x < 0
		or rect.position.y < 0
		or rect.end.x > layout.zone_size.x
		or rect.end.y > layout.zone_size.y
	):
		return false
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if not _cell_inside_any(Vector2i(x, y), layout.floor_rects):
				return false
	return true


func _contains_crate(rect: Rect2i, crate_cells: Array[Vector2i]) -> bool:
	for crate_cell in crate_cells:
		if rect.has_point(crate_cell):
			return true
	return false


func _register_prop(
	layout: BiomeEnvironmentLayout,
	prop_id: StringName,
	rect: Rect2i,
	_rotation_radians: float
) -> void:
	layout.obstacle_rects.append(rect)
	layout.obstacle_ids.append(prop_id)
	layout.obstacle_positions.append(
		layout.obstacle_rect_center_to_world(rect, prop_id)
	)
	layout.obstacle_sizes.append(layout.rect_size_to_world(rect))
	# Keep consuming the caller's RNG sample for seed compatibility, but the
	# cardinal top-down contract locks every environment object to screen axes.
	layout.obstacle_rotations.append(0.0)
	layout.obstacle_shape_ids.append(&"rectangle")
	layout.random_prop_rects.append(rect)
	layout.random_prop_ids.append(prop_id)


func _prop_pool(biome: BiomeDefinition) -> Array[Dictionary]:
	if biome != null and biome.generation_profile != null:
		var profile_pool := _validated_pool(biome.generation_profile.get_prop_rules())
		if not profile_pool.is_empty():
			return profile_pool
	var biome_id := biome.biome_id if biome != null else &"infected_plains"
	return _validated_pool(_fallback_pool(biome_id))


func _fallback_pool(biome_id: StringName) -> Array[Dictionary]:
	match biome_id:
		&"toxic_wastes":
			return [
				{"id": &"lab_ruin", "weight": 0.6},
				{"id": &"chemical_barrel", "weight": 1.4},
				{"id": &"toxic_barrel", "weight": 1.2},
				{"id": &"pipe_stack", "weight": 1.0},
				{"id": &"industrial_fence", "weight": 1.1},
				{"id": &"lab_wall", "weight": 1.0},
				{"id": &"corroded_barrier", "weight": 1.1},
			]
		&"burning_fields":
			return [
				{"id": &"burned_house", "weight": 0.6},
				{"id": &"burned_car", "weight": 1.3},
				{"id": &"metal_wreck", "weight": 1.0},
				{"id": &"charred_wall", "weight": 1.2},
				{"id": &"ash_barrier", "weight": 1.3},
				{"id": &"scorched_barricade", "weight": 1.1},
			]
		&"frozen_outskirts":
			return [
				{"id": &"snow_cabin", "weight": 0.7},
				{"id": &"ice_rock", "weight": 1.4},
				{"id": &"ice_block", "weight": 1.3},
				{"id": &"snow_wall", "weight": 1.2},
				{"id": &"fallen_log", "weight": 1.0},
			]
		&"drowned_marsh":
			return [
				{"id": &"sunken_house", "weight": 0.6},
				{"id": &"sunken_wreck", "weight": 1.1},
				{"id": &"dead_tree", "weight": 1.4},
				{"id": &"marsh_log", "weight": 1.2},
				{"id": &"reed_wall", "weight": 1.2},
				{"id": &"broken_walkway", "weight": 0.9},
			]
		_:
			return [
				{"id": &"ruined_house", "weight": 0.6},
				{"id": &"abandoned_house", "weight": 0.6},
				{"id": &"abandoned_car", "weight": 1.2},
				{"id": &"broken_fence", "weight": 1.3},
				{"id": &"wood_barrier", "weight": 1.2},
				{"id": &"small_rock", "weight": 1.5},
				{"id": &"fallen_log", "weight": 1.0},
			]


func _validated_pool(source: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var manifest := EnvironmentAssetManifest.get_shared()
	for rule in source:
		var prop_id := StringName(rule.get("id", &""))
		if prop_id.is_empty() or not manifest.has_object(prop_id):
			continue
		var footprint := _logical_footprint_tiles(prop_id)
		if footprint.x <= 0 or footprint.y <= 0:
			continue
		result.append({
			"id": prop_id,
			"weight": maxf(float(rule.get("weight", 0.0)), 0.0),
		})
	return result


func _required_category_ids(
	pool: Array[Dictionary],
	count: int,
	categories: Dictionary
) -> Array[StringName]:
	var result: Array[StringName] = []
	var seen: Dictionary = {}
	for rule in pool:
		var prop_id := StringName(rule.get("id", &""))
		var category := _category_for(prop_id, categories)
		if category.is_empty() or seen.has(category):
			continue
		result.append(prop_id)
		seen[category] = true
		if result.size() >= count:
			break
	return result


func _weighted_prop_id(
	pool: Array[Dictionary],
	rng: RandomNumberGenerator
) -> StringName:
	var total_weight := 0.0
	for rule in pool:
		total_weight += maxf(float(rule.get("weight", 0.0)), 0.0)
	if total_weight <= 0.0:
		return StringName(pool.front().get("id", &""))
	var roll := rng.randf() * total_weight
	var cursor := 0.0
	for rule in pool:
		cursor += maxf(float(rule.get("weight", 0.0)), 0.0)
		if roll <= cursor:
			return StringName(rule.get("id", &""))
	return StringName(pool.back().get("id", &""))


func _fallback_order(pool: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	result.append_array(pool)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_id := StringName(a.get("id", &""))
		var b_id := StringName(b.get("id", &""))
		var a_size := _logical_footprint_tiles(a_id)
		var b_size := _logical_footprint_tiles(b_id)
		var a_area := a_size.x * a_size.y
		var b_area := b_size.x * b_size.y
		if a_area != b_area:
			return a_area < b_area
		if a_size.y != b_size.y:
			return a_size.y < b_size.y
		if a_size.x != b_size.x:
			return a_size.x < b_size.x
		return String(a_id) < String(b_id)
	)
	return result


func _available_categories(
	pool: Array[Dictionary],
	categories: Dictionary
) -> Dictionary:
	var result: Dictionary = {}
	for rule in pool:
		var category := _category_for(
			StringName(rule.get("id", &"")),
			categories
		)
		if not category.is_empty():
			result[category] = true
	return result


func _represented_categories(
	layout: BiomeEnvironmentLayout,
	available_categories: Dictionary,
	categories: Dictionary
) -> Dictionary:
	var result: Dictionary = {}
	for prop_id in layout.random_prop_ids:
		var category := _category_for(prop_id, categories)
		if available_categories.has(category):
			result[category] = true
	return result


func _category_for(prop_id: StringName, categories: Dictionary) -> StringName:
	return StringName(categories.get(prop_id, &""))


func _logical_footprint_tiles(prop_id: StringName) -> Vector2i:
	return WorldGridConfig.legacy_size_to_new_tiles(
		EnvironmentAssetManifest.get_shared().get_footprint_tiles(prop_id)
	)


func _cell_inside_any(cell: Vector2i, rects: Array[Rect2i]) -> bool:
	for rect in rects:
		if rect.has_point(cell):
			return true
	return false


