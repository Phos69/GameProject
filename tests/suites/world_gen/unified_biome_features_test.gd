extends GutTest
## WORLD-UNIFY-001 fuzz guardrail: twenty deterministic seeds for every biome.

const WorldGen = preload("res://tests/support/world_gen_helpers.gd")
const RANDOM_PROP_PLACEMENT_PASS = preload(
	"res://game/procedural/world_generation/passes/random_prop_placement_pass.gd"
)
const BIOME_IDS: Array[String] = [
	"infected_plains",
	"toxic_wastes",
	"burning_fields",
	"frozen_outskirts",
	"drowned_marsh",
]
const SENTINEL_SEEDS: Array[int] = [
	10101, 18020, 25939, 33858, 41777,
	49696, 57615, 65534, 73453, 81372,
	89291, 97210, 105129, 113048, 120967,
	128886, 136805, 144724, 152643, 160562,
]

func test_unified_features_hold_and_vary_across_sentinel_seeds() -> void:
	var categories := ObstacleLayoutGenerator.get_generated_obstacle_categories()
	var manifest := IsometricEnvironmentManifest.get_shared()
	for biome_id in BIOME_IDS:
		var biome := WorldGen.load_biome(biome_id)
		assert_not_null(biome, "carica %s" % biome_id)
		if biome == null:
			continue
		assert_not_null(biome.generation_profile,
			"%s espone un profilo generativo tipizzato" % biome_id)
		if biome.generation_profile == null:
			continue
		assert_eq(String(biome.generation_profile.biome_id), biome_id,
			"%s collega il profilo corretto" % biome_id)
		assert_eq(biome.generation_profile.get_validation_errors().size(), 0,
			"%s ha un profilo generativo valido" % biome_id)
		var biome_asset_objects := _string_name_array(
			manifest.get_biome_asset_set_contract(biome.biome_id).get("object_scenes", [])
		)
		for prop_id in biome.generation_profile.random_prop_ids:
			assert_true(biome.obstacle_ids.has(prop_id),
				"%s dichiara %s negli obstacle_ids" % [biome_id, prop_id])
			assert_true(manifest.has_object(prop_id),
				"%s trova %s nel manifest" % [biome_id, prop_id])
			assert_true(biome_asset_objects.has(prop_id),
				"%s include %s nel proprio asset set" % [biome_id, prop_id])
		for hazard_id in biome.generation_profile.static_hazard_ids:
			assert_true(biome.hazard_ids.has(hazard_id),
				"%s dichiara %s negli hazard_ids" % [biome_id, hazard_id])
		var mesa_variants: Dictionary = {}
		var chasm_variants: Dictionary = {}
		var prop_variants: Dictionary = {}
		var hazard_variants: Dictionary = {}
		for seed_value in SENTINEL_SEEDS:
			var layout := WorldGen.voidfirst_layout(biome, seed_value)
			assert_gte(layout.mesa_rects.size(), biome.generation_profile.mesa_min_count,
				"%s/%d rispetta la quota minima mesa" % [biome_id, seed_value])
			assert_eq(layout.mesa_profile_ids.size(), layout.mesa_rects.size(),
				"%s/%d mantiene paralleli i profili mesa" % [biome_id, seed_value])
			assert_eq(layout.obstacle_ids.count(&"large_rock"), layout.mesa_rects.size(),
				"%s/%d ha un blocker per mesa" % [biome_id, seed_value])
			assert_true(_has_internal_chasm(layout),
				"%s/%d garantisce un chasm interno" % [biome_id, seed_value])
			assert_between(
				layout.random_prop_rects.size(),
				biome.generation_profile.random_prop_min_count,
				biome.generation_profile.random_prop_max_count,
				"%s/%d rispetta il budget prop" % [biome_id, seed_value]
			)
			assert_eq(layout.random_prop_ids.size(), layout.random_prop_rects.size(),
				"%s/%d mantiene paralleli i random prop" % [biome_id, seed_value])
			var prop_categories: Dictionary = {}
			for prop_id in layout.random_prop_ids:
				prop_categories[categories.get(prop_id, &"")] = true
			assert_gte(prop_categories.size(), 2,
				"%s/%d usa almeno due categorie" % [biome_id, seed_value])
			var static_hazards := _static_hazard_records(layout)
			var expected_hazard_count := (
				biome.generation_profile.get_static_hazard_ids().size()
			)
			assert_eq(
				static_hazards.size(),
				expected_hazard_count,
				"%s/%d mantiene la quota hazard statica" % [biome_id, seed_value]
			)
			for record in static_hazards:
				var hazard_id := record.get("id", &"") as StringName
				var hazard_rect := record.get("rect", Rect2i()) as Rect2i
				assert_true(biome.hazard_ids.has(hazard_id),
					"%s/%d usa hazard dal profilo" % [biome_id, seed_value])
				assert_true(_hazard_has_safe_placement(layout, hazard_rect),
					"%s/%d piazza %s su terreno sicuro" % [biome_id, seed_value, hazard_id])
			mesa_variants[str(layout.mesa_rects)] = true
			chasm_variants[str(layout.fall_zone_rects)] = true
			prop_variants[str([layout.random_prop_ids, layout.random_prop_rects])] = true
			hazard_variants[str(static_hazards)] = true
		assert_gt(mesa_variants.size(), 1, "%s varia le mesa tra seed" % biome_id)
		assert_gt(chasm_variants.size(), 1, "%s varia i chasm tra seed" % biome_id)
		assert_gt(prop_variants.size(), 1, "%s varia i prop tra seed" % biome_id)
		if biome_id != "infected_plains":
			assert_gt(hazard_variants.size(), 1, "%s varia gli hazard tra seed" % biome_id)

func test_random_prop_scan_fallback_reaches_the_profile_minimum() -> void:
	var biome := WorldGen.load_biome("infected_plains")
	assert_not_null(biome, "carica il profilo per il fallback prop")
	if biome == null:
		return
	var layout := BiomeEnvironmentLayout.new()
	layout.add_floor_rect(Rect2i(Vector2i.ZERO, layout.zone_size), &"open_block")
	layout.player_spawn_cell = layout.zone_size / 2
	var rng := RandomNumberGenerator.new()
	rng.seed = 734521
	var placed: int = RANDOM_PROP_PLACEMENT_PASS.new().place(
		layout,
		biome,
		rng,
		ObstacleLayoutGenerator.get_generated_obstacle_categories(),
		0
	)
	assert_between(
		placed,
		biome.generation_profile.random_prop_min_count,
		biome.generation_profile.random_prop_max_count,
		"la scansione esaustiva raggiunge il budget senza rejection sampling"
	)
	assert_eq(layout.random_prop_rects.size(), placed,
		"il fallback registra ogni rettangolo prop")
	assert_eq(layout.random_prop_ids.size(), placed,
		"il fallback registra ogni ID prop")
	var categories := ObstacleLayoutGenerator.get_generated_obstacle_categories()
	var seen_categories: Dictionary = {}
	for prop_id in layout.random_prop_ids:
		seen_categories[categories.get(prop_id, &"")] = true
	assert_gte(seen_categories.size(), 2,
		"il fallback preserva almeno due categorie tematiche")
	for index in range(layout.random_prop_rects.size()):
		for other_index in range(index + 1, layout.random_prop_rects.size()):
			assert_false(
				layout.random_prop_rects[index].intersects(
					layout.random_prop_rects[other_index]
				),
				"i prop del fallback non si sovrappongono"
			)

func _has_internal_chasm(layout: BiomeEnvironmentLayout) -> bool:
	for index in range(layout.hazard_ids.size()):
		if layout.hazard_ids[index] != &"fall_zone":
			continue
		if index < layout.hazard_sides.size() and layout.hazard_sides[index] == &"internal":
			return true
	return false

func _static_hazard_records(layout: BiomeEnvironmentLayout) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var count := mini(layout.hazard_ids.size(), layout.hazard_rects.size())
	for index in range(count):
		if layout.hazard_ids[index] == &"fall_zone":
			continue
		result.append({
			"id": layout.hazard_ids[index],
			"rect": layout.hazard_rects[index],
		})
	return result

func _hazard_has_safe_placement(
	layout: BiomeEnvironmentLayout,
	rect: Rect2i
) -> bool:
	var padded := Rect2i(rect.position - Vector2i.ONE, rect.size + Vector2i(2, 2))
	if _intersects_any(padded, layout.road_rects):
		return false
	if _intersects_any(padded, layout.passage_rects):
		return false
	if _intersects_any(padded, layout.passage_connector_rects):
		return false
	if _intersects_any(rect, layout.obstacle_rects):
		return false
	if _intersects_any(rect, layout.fall_zone_rects):
		return false
	for y in range(padded.position.y, padded.end.y):
		for x in range(padded.position.x, padded.end.x):
			if layout.has_road_cell(Vector2i(x, y)):
				return false
	var spawn_rect := Rect2i(
		layout.player_spawn_cell
		- Vector2i.ONE * ObstacleLayoutGenerator.VOIDFIRST_HAZARD_SPAWN_CLEARANCE,
		Vector2i.ONE
		* (ObstacleLayoutGenerator.VOIDFIRST_HAZARD_SPAWN_CLEARANCE * 2 + 1)
	)
	return not rect.intersects(spawn_rect)

func _intersects_any(rect: Rect2i, others: Array[Rect2i]) -> bool:
	for other in others:
		if rect.intersects(other):
			return true
	return false

func _string_name_array(values: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if values is not Array:
		return result
	for value in values as Array:
		result.append(StringName(value))
	return result
