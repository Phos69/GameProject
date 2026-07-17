extends GutTest

const SNAPSHOT_CODEC = preload(
	"res://game/procedural/world_generation/world_snapshot_codec.gd"
)

func test_cache_keys_carry_the_generation_revision() -> void:
	assert_true(
		WorldDataCache.canonical_key({}).begins_with("generator_revision=5|"),
		"la cache dati non puo riusare chiavi della revisione pre-unificazione"
	)
	assert_true(
		WorldDataCache.build_signature({}).begins_with("generator_revision=5|"),
		"anche la firma scena dichiara la revisione del generatore"
	)

func test_deep_signature_tracks_generated_content_not_only_counts() -> void:
	var baseline := _make_layout()
	var baseline_signature := baseline.get_generation_signature()
	assert_true(
		baseline_signature.begins_with("layout-v4:"),
		"la firma dichiara la versione del contratto profondo"
	)

	var mesa_changed := baseline.clone()
	mesa_changed.mesa_rects[0] = Rect2i(13, 8, 5, 4)
	assert_ne(mesa_changed.get_generation_signature(), baseline_signature,
		"la geometria mesa cambia la firma a conteggi invariati")

	var mesa_profile_changed := baseline.clone()
	mesa_profile_changed.mesa_profile_ids[0] = &"volcanic"
	assert_ne(mesa_profile_changed.get_generation_signature(), baseline_signature,
		"il profilo visuale della mesa cambia la firma")

	var prop_changed := baseline.clone()
	prop_changed.random_prop_ids[0] = &"burned_car"
	assert_ne(prop_changed.get_generation_signature(), baseline_signature,
		"l'identita del prop casuale cambia la firma a conteggi invariati")

	var obstacle_changed := baseline.clone()
	obstacle_changed.obstacle_shape_ids[0] = &"circle"
	assert_ne(obstacle_changed.get_generation_signature(), baseline_signature,
		"il contratto ostacolo cambia la firma")

	var fall_changed := baseline.clone()
	fall_changed.fall_zone_rects[0] = Rect2i(1, 0, 6, 2)
	assert_ne(fall_changed.get_generation_signature(), baseline_signature,
		"il cliff nel void cambia la firma")

	var hazard_changed := baseline.clone()
	hazard_changed.hazard_rotations[1] = 0.75
	assert_ne(hazard_changed.get_generation_signature(), baseline_signature,
		"il record hazard cambia la firma")

	var crate_changed := baseline.clone()
	crate_changed.crate_cells[0] = Vector2i(27, 26)
	assert_ne(crate_changed.get_generation_signature(), baseline_signature,
		"la posizione logica della crate cambia la firma")

func test_deep_signature_canonicalizes_dictionary_insertion_order() -> void:
	var first := _make_layout()
	first.road_cell_tags = {}
	first.road_cell_tags[17] = [&"road", &"bridge"]
	first.road_cell_tags[3] = [&"path"]
	var second := first.clone()
	second.road_cell_tags = {}
	second.road_cell_tags[3] = [&"path"]
	second.road_cell_tags[17] = [&"road", &"bridge"]
	assert_eq(
		second.get_generation_signature(),
		first.get_generation_signature(),
		"l'ordine di inserimento di un Dictionary non cambia la firma canonica"
	)

func test_deep_signature_ignores_rebuildable_diagnostics() -> void:
	var first := _make_layout()
	var content_signature := first.get_generation_signature()
	var second := first.clone()
	first.rebuild_terrain_classification()
	first.validation_report = {"elapsed_ms": 1}
	first.generation_summary = {"attempt": 1}
	second.validation_report = {"elapsed_ms": 999}
	second.generation_summary = {"attempt": 8}
	assert_eq(first.get_generation_signature(), content_signature,
		"ricostruire cache e classificazione non cambia il contenuto firmato")
	assert_eq(
		second.get_generation_signature(),
		first.get_generation_signature(),
		"report e summary diagnostici non fanno parte del mondo generato"
	)

func test_cell_signature_includes_the_deep_layout_signature() -> void:
	var first := _make_cell(_make_layout())
	var second := first.clone()
	second.generated_layout.random_prop_rects[0] = Rect2i(42, 22, 1, 1)
	assert_ne(
		second.get_signature(),
		first.get_signature(),
		"due celle identiche con contenuto interno diverso hanno firme diverse"
	)

func test_snapshot_v7_roundtrips_deep_content_and_rejects_v6() -> void:
	var source_cell := _make_cell(_make_layout())
	var cells: Array[BiomeCell] = [source_cell]
	var source_world := {
		"seed": 770041,
		"cells": cells,
		"world_graph": null,
		"start_cell": source_cell,
		"signature": source_cell.get_signature(),
		"seed_record": {"global_seed": 770041},
	}
	var encoded := SNAPSHOT_CODEC.world_data_to_dict(source_world)
	assert_eq(int(encoded.get("format_version", -1)), 7,
		"il codec scrive il nuovo formato snapshot")

	var decoded := SNAPSHOT_CODEC.world_data_from_dict(encoded)
	assert_false(decoded.is_empty(), "lo snapshot v7 e decodificato")
	var decoded_cell := (decoded.get("cells", []) as Array)[0] as BiomeCell
	assert_not_null(decoded_cell.generated_layout, "il layout profondo sopravvive")
	assert_eq(
		decoded_cell.generated_layout.get_generation_signature(),
		source_cell.generated_layout.get_generation_signature(),
		"mesa, prop, cliff, ostacoli, hazard e crate sopravvivono al round-trip"
	)
	assert_eq(decoded_cell.get_signature(), source_cell.get_signature(),
		"la firma profonda della cella sopravvive al round-trip")

	var tampered := encoded.duplicate(true)
	var tampered_cells := tampered.get("cells", []) as Array
	var tampered_cell := tampered_cells[0] as Dictionary
	var tampered_layout := tampered_cell.get("generated_layout", {}) as Dictionary
	tampered_layout["random_prop_ids"] = [&"burned_car"]
	assert_true(
		SNAPSHOT_CODEC.world_data_from_dict(tampered).is_empty(),
		"un blob v7 con layout alterato e firma stale viene rifiutato"
	)

	var legacy_v6 := encoded.duplicate(true)
	legacy_v6["format_version"] = 6
	assert_true(
		SNAPSHOT_CODEC.world_data_from_dict(legacy_v6).is_empty(),
		"un blob v6 viene rifiutato e dovra essere rigenerato"
	)
	WorldDataCache.release_world_data(decoded)

func _make_layout() -> BiomeEnvironmentLayout:
	var layout := BiomeEnvironmentLayout.new()
	layout.zone_size = Vector2i(75, 75)
	layout.generation_seed = 770041
	layout.floor_rects = [Rect2i(4, 4, 67, 67)]
	layout.floor_rect_tags = [&"floor_base"]
	layout.road_rects = [Rect2i(35, 4, 5, 67)]
	layout.road_rect_tags = [&"road"]
	layout.road_cell_tags = {17: [&"road"], 3: [&"path"]}
	layout.mesa_rects = [Rect2i(12, 8, 5, 4)]
	layout.mesa_profile_ids = [&"urban_ruins"]
	layout.mass_rects = [Rect2i(50, 12, 3, 2)]
	layout.random_prop_rects = [Rect2i(41, 22, 1, 1)]
	layout.random_prop_ids = [&"abandoned_car"]
	layout.obstacle_rects = [Rect2i(12, 8, 5, 4), Rect2i(41, 22, 1, 1)]
	layout.obstacle_ids = [&"large_rock", &"abandoned_car"]
	layout.obstacle_positions = [Vector2(-1176, -1320), Vector2(312, -744)]
	layout.obstacle_sizes = [Vector2(240, 192), Vector2(48, 48)]
	layout.obstacle_rotations = [0.0, 0.0]
	layout.obstacle_shape_ids = [&"rectangle", &"rectangle"]
	layout.crate_cells = [Vector2i(26, 26)]
	layout.crate_ids = [&"common"]
	layout.crate_positions = [Vector2(-528, -528)]
	layout.add_fall_zone_rect(Rect2i(0, 0, 6, 2), &"north")
	layout.add_hazard_rect(Rect2i(55, 48, 3, 3), &"toxic_pool", 0.25)
	layout.player_spawn_cell = Vector2i(37, 37)
	return layout

func _make_cell(layout: BiomeEnvironmentLayout) -> BiomeCell:
	var cell := BiomeCell.new()
	cell.configure(
		&"region_0_0",
		&"toxic_wastes",
		Vector2i.ZERO,
		layout.zone_size,
		layout.generation_seed
	)
	cell.generated_layout = layout
	return cell
