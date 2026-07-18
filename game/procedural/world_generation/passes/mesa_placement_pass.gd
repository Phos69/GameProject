extends RefCounted
class_name MesaPlacementPass

const WorldGridConfig = preload("res://game/core/world_grid_config.gd")

## Shared mesa density used by advanced biomes. Infected plains keeps the denser
## legacy range below so extracting this pass does not alter existing seeds.
const MIN_COUNT: int = 2
const MAX_COUNT: int = 4
const PLAINS_MIN_COUNT: int = 10
const PLAINS_MAX_COUNT: int = 16

const MIN_SIZE: int = WorldGridConfig.VOIDFIRST_ROCK_MIN_SIZE_TILES
const MAX_SIZE: int = WorldGridConfig.VOIDFIRST_ROCK_MAX_SIZE_TILES
const GAP: int = WorldGridConfig.VOIDFIRST_ROCK_GAP_TILES
const MARGIN: int = WorldGridConfig.VOIDFIRST_ROCK_MARGIN_TILES
const BORDER_THICKNESS: int = WorldGridConfig.BORDER_THICKNESS_TILES
const MAX_ATTEMPTS: int = 600


## Places first-class mesa terrain and its matching collision-only blocker.
## The RNG calls and fallback scan intentionally mirror the original generator.
func place(
	layout: BiomeEnvironmentLayout,
	biome: BiomeDefinition,
	rng: RandomNumberGenerator
) -> int:
	var is_plains := biome != null and biome.biome_id == &"plains"
	var minimum := PLAINS_MIN_COUNT if is_plains else MIN_COUNT
	var maximum := PLAINS_MAX_COUNT if is_plains else MAX_COUNT
	if biome != null and biome.generation_profile != null:
		minimum = biome.generation_profile.mesa_min_count
		maximum = biome.generation_profile.mesa_max_count
	maximum = maxi(maximum, minimum)

	var target := rng.randi_range(minimum, maximum)
	var profile_id := _mesa_profile_id(biome)
	var placed := _try_place_mesas(
		layout,
		rng,
		target,
		GAP,
		profile_id,
		is_plains
	)
	if placed < minimum:
		placed += _try_place_mesas(
			layout,
			rng,
			minimum - placed,
			0,
			profile_id,
			is_plains
		)
	if placed < minimum:
		placed += _scan_place_mesas(
			layout,
			minimum - placed,
			profile_id,
			is_plains
		)
	return placed


func _try_place_mesas(
	layout: BiomeEnvironmentLayout,
	rng: RandomNumberGenerator,
	count: int,
	gap: int,
	profile_id: StringName,
	mirror_legacy_rocks: bool
) -> int:
	var placed := 0
	var attempts := 0
	var lo := BORDER_THICKNESS + MARGIN
	while placed < count and attempts < MAX_ATTEMPTS:
		attempts += 1
		var side := rng.randi_range(MIN_SIZE, MAX_SIZE)
		var hi_x := layout.zone_size.x - lo - side
		var hi_y := layout.zone_size.y - lo - side
		if hi_x <= lo or hi_y <= lo:
			continue
		var rect := Rect2i(
			Vector2i(rng.randi_range(lo, hi_x), rng.randi_range(lo, hi_y)),
			Vector2i(side, side)
		)
		if not _can_place_mesa(layout, rect, gap):
			continue
		_register_mesa(layout, rect, profile_id, mirror_legacy_rocks)
		placed += 1
	return placed


func _scan_place_mesas(
	layout: BiomeEnvironmentLayout,
	count: int,
	profile_id: StringName,
	mirror_legacy_rocks: bool
) -> int:
	var placed := 0
	var lo := BORDER_THICKNESS + MARGIN
	for side in range(MAX_SIZE, MIN_SIZE - 1, -1):
		for y in range(lo, layout.zone_size.y - lo - side + 1):
			for x in range(lo, layout.zone_size.x - lo - side + 1):
				var rect := Rect2i(Vector2i(x, y), Vector2i(side, side))
				if not _can_place_mesa(layout, rect, 0):
					continue
				_register_mesa(layout, rect, profile_id, mirror_legacy_rocks)
				placed += 1
				if placed >= count:
					return placed
	return placed


func _can_place_mesa(
	layout: BiomeEnvironmentLayout,
	rect: Rect2i,
	gap: int
) -> bool:
	var padded := GeometryUtils.inflate_rect(rect, gap)
	if padded.intersects(_center_reserved_rect(layout)):
		return false
	if layout.rect_overlaps_passage_corridor(padded):
		return false
	if GeometryUtils.intersects_any(padded, layout.mesa_rects):
		return false
	if GeometryUtils.intersects_any(padded, layout.mass_rects):
		return false
	return true


func _register_mesa(
	layout: BiomeEnvironmentLayout,
	rect: Rect2i,
	profile_id: StringName,
	mirror_legacy_rocks: bool
) -> void:
	layout.mesa_rects.append(rect)
	layout.mesa_profile_ids.append(profile_id)
	if mirror_legacy_rocks:
		layout.rock_rects.append(rect)

	# Complete runtime obstacle record; `large_rock` is collision-only for mesas.
	layout.obstacle_rects.append(rect)
	layout.obstacle_ids.append(&"large_rock")
	layout.obstacle_positions.append(
		layout.obstacle_rect_center_to_world(rect, &"large_rock")
	)
	layout.obstacle_sizes.append(layout.rect_size_to_world(rect))
	layout.obstacle_rotations.append(0.0)
	layout.obstacle_shape_ids.append(&"rectangle")


func _mesa_profile_id(biome: BiomeDefinition) -> StringName:
	if (
		biome != null
		and biome.generation_profile != null
		and not biome.generation_profile.mesa_profile_id.is_empty()
	):
		return biome.generation_profile.mesa_profile_id
	var biome_id := biome.biome_id if biome != null else &"plains"
	match biome_id:
		&"toxic_wastes":
			return &"urban_ruins"
		&"burning_plains":
			return &"burning_plains"
		&"frozen_tundra":
			return &"frozen_tundra"
		&"swamp":
			return &"swamp"
		_:
			return &"forest"


func _center_reserved_rect(layout: BiomeEnvironmentLayout) -> Rect2i:
	var center := layout.zone_size / 2
	var half := WorldGridConfig.CENTER_RESERVED_HALF_TILES
	return Rect2i(center - Vector2i(half, half), Vector2i(half * 2, half * 2))

