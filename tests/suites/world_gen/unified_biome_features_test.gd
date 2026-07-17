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

func test_terrain_parcels_hold_and_vary_across_sentinel_seeds() -> void:
	var manifest := EnvironmentAssetManifest.get_shared()
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
		for required_id in [biome.generation_profile.forest_tree_id, &"abandoned_car"]:
			assert_true(manifest.has_object(required_id),
				"%s trova %s nel manifest" % [biome_id, required_id])
			assert_true(biome_asset_objects.has(required_id),
				"%s include %s nel proprio asset set" % [biome_id, required_id])
		for hazard_id in biome.generation_profile.static_hazard_ids:
			assert_true(biome.hazard_ids.has(hazard_id),
				"%s dichiara %s negli hazard_ids" % [biome_id, hazard_id])
		var parcel_variants: Dictionary = {}
		var hazard_variants: Dictionary = {}
		for seed_value in SENTINEL_SEEDS:
			var layout := WorldGen.voidfirst_layout(biome, seed_value)
			var replay := WorldGen.voidfirst_layout(biome, seed_value)
			var validation_cell := BiomeCell.new()
			validation_cell.configure(
				&"terrain_parcel_fuzz_cell",
				biome.biome_id,
				Vector2i.ZERO,
				layout.zone_size,
				seed_value
			)
			for side in BiomeCell.SIDES:
				validation_cell.set_border(side, BiomeCell.BorderType.BLOCKED)
			layout.rebuild_terrain_classification(validation_cell)
			var report := layout.get_parcel_report()
			var type_counts := report.get("type_counts", {}) as Dictionary
			assert_between(layout.parcel_types.size(), 7, 10,
				"%s/%d genera 7..10 lotti" % [biome_id, seed_value])
			assert_eq(layout.parcel_bounds.size(), layout.parcel_types.size(),
				"%s/%d mantiene bounds paralleli" % [biome_id, seed_value])
			assert_eq(layout.parcel_areas.size(), layout.parcel_types.size(),
				"%s/%d mantiene aree parallele" % [biome_id, seed_value])
			assert_eq(int(type_counts.get(BiomeEnvironmentLayout.PARCEL_MESA, 0)), 1,
				"%s/%d garantisce una mesa" % [biome_id, seed_value])
			assert_eq(int(type_counts.get(BiomeEnvironmentLayout.PARCEL_TOWN, 0)), 1,
				"%s/%d garantisce una town" % [biome_id, seed_value])
			assert_eq(layout.parcel_types, replay.parcel_types,
				"%s/%d assegna archetipi deterministicamente" % [biome_id, seed_value])
			assert_eq(layout.parcel_cell_indices, replay.parcel_cell_indices,
				"%s/%d partiziona deterministicamente" % [biome_id, seed_value])
			assert_eq(layout.get_generation_signature(), replay.get_generation_signature(),
				"%s/%d mantiene la firma deterministica" % [biome_id, seed_value])
			assert_true(_all_non_route_cells_belong_to_one_parcel(layout),
				"%s/%d copre ogni cella interna non-route" % [biome_id, seed_value])
			assert_true(_all_trails_stay_inside_region(layout),
				"%s/%d mantiene i sentieri sui bordi interni" % [biome_id, seed_value])
			var validation := MapValidationSystem.new().validate_terrain_parcels(layout)
			assert_true(bool(validation.get("is_valid", false)),
				"%s/%d valida rim, corridoi forest e ingressi town" % [biome_id, seed_value])
			var full_validation := MapValidationSystem.new().validate_layout(validation_cell, layout)
			assert_true(bool(full_validation.get("is_valid", false)),
				"%s/%d mantiene route, accessi e contenuti raggiungibili" % [biome_id, seed_value])
			assert_eq(
				layout.obstacle_rotations.size(),
				layout.obstacle_ids.size(),
				"%s/%d mantiene paralleli i record di rotazione" % [biome_id, seed_value]
			)
			assert_true(
				_all_obstacle_rotations_are_zero(layout),
				"%s/%d blocca tutti gli ostacoli sugli assi cardinali"
				% [biome_id, seed_value]
			)
			assert_eq(
				layout.hazard_rotations.size(),
				layout.hazard_ids.size(),
				"%s/%d mantiene paralleli i record hazard" % [biome_id, seed_value]
			)
			assert_true(
				_all_hazard_rotations_are_zero(layout),
				"%s/%d blocca tutti gli hazard sugli assi cardinali"
				% [biome_id, seed_value]
			)
			assert_eq(layout.mesa_rects.size(), 1,
				"%s/%d costruisce una sola montagna" % [biome_id, seed_value])
			assert_eq(layout.mesa_profile_ids.size(), layout.mesa_rects.size(),
				"%s/%d mantiene paralleli i profili mesa" % [biome_id, seed_value])
			assert_eq(layout.obstacle_ids.count(&"large_rock"), layout.mesa_rects.size(),
				"%s/%d ha un blocker per mesa" % [biome_id, seed_value])
			assert_true(layout.random_prop_rects.is_empty(),
				"%s/%d non usa scatter globali" % [biome_id, seed_value])
			var content := layout.generation_summary.get("parcel_content", {}) as Dictionary
			assert_between(int(content.get("town_building_count", 0)), 2, 4,
				"%s/%d town con 2..4 edifici" % [biome_id, seed_value])
			assert_between(int(content.get("town_vehicle_count", 0)), 1, 3,
				"%s/%d town con 1..3 veicoli" % [biome_id, seed_value])
			assert_eq(int(content.get("town_driveway_count", 0)),
				int(content.get("town_building_count", 0)),
				"%s/%d collega ogni ingresso town" % [biome_id, seed_value])
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
				assert_true(_rect_belongs_to_clearing(layout, hazard_rect),
					"%s/%d limita %s alle radure" % [biome_id, seed_value, hazard_id])
			parcel_variants[str(layout.parcel_cell_indices)] = true
			hazard_variants[str(static_hazards)] = true
		assert_gt(parcel_variants.size(), 1, "%s varia i lotti tra seed" % biome_id)
		if biome_id != "infected_plains":
			assert_gt(hazard_variants.size(), 1, "%s varia gli hazard tra seed" % biome_id)

func _all_non_route_cells_belong_to_one_parcel(layout: BiomeEnvironmentLayout) -> bool:
	for y in range(1, layout.zone_size.y - 1):
		for x in range(1, layout.zone_size.x - 1):
			var cell := Vector2i(x, y)
			if layout.has_road_cell(cell):
				continue
			if layout.get_parcel_index_at_cell(cell) < 0:
				return false
	return true

func _all_trails_stay_inside_region(layout: BiomeEnvironmentLayout) -> bool:
	for cell in layout.get_road_cells():
		if not layout.get_road_tags_at_cell(cell).has(&"parcel_trail"):
			continue
		if cell.x <= 0 or cell.y <= 0 or cell.x >= layout.zone_size.x - 1 or cell.y >= layout.zone_size.y - 1:
			return false
	return true

func _rect_belongs_to_clearing(layout: BiomeEnvironmentLayout, rect: Rect2i) -> bool:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if layout.get_parcel_type_at_cell(Vector2i(x, y)) != BiomeEnvironmentLayout.PARCEL_CLEARING:
				return false
	return true

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
	var reference_rng := RandomNumberGenerator.new()
	reference_rng.seed = rng.seed
	var expected_target := reference_rng.randi_range(
		biome.generation_profile.random_prop_min_count,
		biome.generation_profile.random_prop_max_count
	)
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
	assert_eq(placed, expected_target,
		"il pavimento aperto permette di completare il target estratto")
	assert_eq(layout.obstacle_rotations.size(), placed,
		"ogni prop registra una rotazione runtime")
	assert_true(_all_obstacle_rotations_are_zero(layout),
		"i prop del fallback restano dritti sugli assi cardinali")
	for _index in range(placed):
		reference_rng.randf_range(-0.35, 0.35)
	assert_eq(
		rng.state,
		reference_rng.state,
		"il lock cardinale conserva un campione RNG di rotazione per prop"
	)
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

func _all_obstacle_rotations_are_zero(layout: BiomeEnvironmentLayout) -> bool:
	for rotation_radians in layout.obstacle_rotations:
		if not is_zero_approx(rotation_radians):
			return false
	return true

func _all_hazard_rotations_are_zero(layout: BiomeEnvironmentLayout) -> bool:
	for rotation_radians in layout.hazard_rotations:
		if not is_zero_approx(rotation_radians):
			return false
	return true

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
