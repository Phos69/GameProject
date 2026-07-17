extends RefCounted
class_name StaticHazardPlacementPass

const WorldGridConfig = preload("res://game/core/world_grid_config.gd")

const MAX_COUNT := 2
const ATTEMPTS_PER_ID := 500
const BORDER_MARGIN := 3
const ROUTE_CLEARANCE := 1
const SPAWN_CLEARANCE := 8
const FALLBACK_SIZE_BY_ID: Dictionary = {
	&"toxic_puddle": Vector2i(5, 3),
	&"gas_cloud": Vector2i(5, 3),
	&"lava_crack": Vector2i(6, 2),
	&"fire_zone": Vector2i(4, 4),
	&"slippery_ice": Vector2i(6, 4),
	&"deep_snow_slow": Vector2i(5, 4),
	&"deep_water": Vector2i(7, 4),
	&"mud_slow": Vector2i(5, 4),
}


# Places static biome identity hazards on final walkable floor. The caller owns
# the RNG stream so this pass remains deterministic and isolated from other
# generation phases.
func place(
	layout: BiomeEnvironmentLayout,
	biome: BiomeDefinition,
	rng: RandomNumberGenerator
) -> int:
	var placed := 0
	for hazard_id in _static_hazard_ids(biome):
		var size := _static_hazard_size(biome, hazard_id)
		var rect := _find_random_rect(layout, size, rng)
		if rect.size.x <= 0 or rect.size.y <= 0:
			rect = _scan_rect(layout, size)
		if rect.size.x <= 0 or rect.size.y <= 0:
			continue
		# Consume the historical angle sample so later RNG-driven placement stays
		# seed-compatible; the layout cardinal lock stores rotation zero.
		var legacy_rotation_sample := rng.randf_range(-0.16, 0.16)
		layout.add_hazard_rect(rect, hazard_id, legacy_rotation_sample)
		placed += 1
	return placed


func _static_hazard_ids(biome: BiomeDefinition) -> Array[StringName]:
	var result: Array[StringName] = []
	if biome == null:
		return result
	if biome.generation_profile != null:
		return biome.generation_profile.get_static_hazard_ids()
	for hazard_id in biome.hazard_ids:
		if hazard_id == &"fall_zone" or not FALLBACK_SIZE_BY_ID.has(hazard_id):
			continue
		result.append(hazard_id)
		if result.size() >= MAX_COUNT:
			break
	return result


func _static_hazard_size(
	biome: BiomeDefinition,
	hazard_id: StringName
) -> Vector2i:
	if biome != null and biome.generation_profile != null:
		var profile_size := biome.generation_profile.get_static_hazard_size(hazard_id)
		if profile_size.x > 0 and profile_size.y > 0:
			return profile_size
	return FALLBACK_SIZE_BY_ID.get(hazard_id, Vector2i(4, 3)) as Vector2i


func _find_random_rect(
	layout: BiomeEnvironmentLayout,
	size: Vector2i,
	rng: RandomNumberGenerator
) -> Rect2i:
	var lo := WorldGridConfig.BORDER_THICKNESS_TILES + BORDER_MARGIN
	var hi_x := layout.zone_size.x - lo - size.x
	var hi_y := layout.zone_size.y - lo - size.y
	if hi_x < lo or hi_y < lo:
		return Rect2i()
	for _attempt in range(ATTEMPTS_PER_ID):
		var rect := Rect2i(
			Vector2i(rng.randi_range(lo, hi_x), rng.randi_range(lo, hi_y)),
			size
		)
		if _can_place(layout, rect):
			return rect
	return Rect2i()


func _scan_rect(layout: BiomeEnvironmentLayout, size: Vector2i) -> Rect2i:
	var lo := WorldGridConfig.BORDER_THICKNESS_TILES + BORDER_MARGIN
	var max_x := layout.zone_size.x - lo - size.x
	var max_y := layout.zone_size.y - lo - size.y
	for y in range(lo, max_y + 1):
		for x in range(lo, max_x + 1):
			var rect := Rect2i(Vector2i(x, y), size)
			if _can_place(layout, rect):
				return rect
	return Rect2i()


func _can_place(layout: BiomeEnvironmentLayout, rect: Rect2i) -> bool:
	# Parcel layouts keep biome hazards inside clearings so mesa, forest, town and
	# fall-zone identities remain pure. Legacy/manual layouts have no parcel map
	# and retain their previous behavior.
	if not layout.parcel_types.is_empty():
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				if (
					layout.get_parcel_type_at_cell(Vector2i(x, y))
					!= BiomeEnvironmentLayout.PARCEL_CLEARING
				):
					return false
	var padded := GeometryUtils.inflate_rect(rect, ROUTE_CLEARANCE)
	if layout.rect_intersects_route(padded):
		return false
	if layout.rect_overlaps_passage_corridor(padded):
		return false
	if GeometryUtils.intersects_any(padded, layout.obstacle_rects):
		return false
	if GeometryUtils.intersects_any(padded, layout.mesa_rects):
		return false
	if GeometryUtils.intersects_any(padded, layout.mass_rects):
		return false
	if GeometryUtils.intersects_any(padded, layout.fall_zone_rects):
		return false
	if GeometryUtils.intersects_any(padded, layout.hazard_rects):
		return false
	var spawn_clearance := Rect2i(
		layout.player_spawn_cell - Vector2i.ONE * SPAWN_CLEARANCE,
		Vector2i.ONE * (SPAWN_CLEARANCE * 2 + 1)
	)
	if rect.intersects(spawn_clearance):
		return false
	return _rect_is_final_floor(layout, rect)


func _rect_is_final_floor(
	layout: BiomeEnvironmentLayout,
	rect: Rect2i
) -> bool:
	if (
		rect.position.x < 0
		or rect.position.y < 0
		or rect.end.x > layout.zone_size.x
		or rect.end.y > layout.zone_size.y
	):
		return false
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if not _cell_inside_any_rect(Vector2i(x, y), layout.floor_rects):
				return false
	return true


func _cell_inside_any_rect(cell: Vector2i, rects: Array[Rect2i]) -> bool:
	for rect in rects:
		if rect.has_point(cell):
			return true
	return false

