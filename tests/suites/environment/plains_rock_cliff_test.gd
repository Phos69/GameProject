extends GutTest

const WorldGen = preload("res://tests/support/world_gen_helpers.gd")

func test_manifest_declares_complete_external_plains_rock_kit() -> void:
	var manifest := EnvironmentAssetManifest.reload_shared()
	assert_gte(manifest.version, 18, "rock cliff kit uses manifest v18")
	var report := manifest.validate()
	assert_true(bool(report.get("is_valid", false)), "manifest with pending external atlas validates")
	var biome_contract := manifest.get_biome_asset_set_contract(&"plains")
	assert_eq(
		StringName(biome_contract.get("rock_cliff_kit_id", &"")),
		&"plains_dark_fantasy",
		"Plains selects the dark-fantasy rock kit"
	)
	var kit := manifest.get_rock_cliff_kit_contract(&"plains_dark_fantasy")
	assert_eq(String(kit.get("status", "")), "needs_asset", "external atlases remain an explicit delivery gate")
	assert_eq((kit.get("wall_regions", {}) as Dictionary).size(), 16, "wall atlas maps all sixteen modules")
	assert_eq((kit.get("top_regions", {}) as Dictionary).size(), 16, "top atlas maps all sixteen modules")
	assert_false(manifest.rock_cliff_kit_has_external_assets(&"plains_dark_fantasy"), "missing authored PNGs do not masquerade as final art")
	assert_true(
		manifest.get_rock_cliff_kit_asset_path(&"plains_dark_fantasy", &"wall").ends_with("cliff_face_generated_v2.png"),
		"pending wall atlas resolves the explicit shared-rock fallback"
	)
	assert_true(
		manifest.get_rock_cliff_kit_asset_path(&"plains_dark_fantasy", &"top").ends_with("rock_plateau_top_generated.png"),
		"pending top atlas resolves the explicit plateau fallback"
	)

func test_topology_roles_and_seeded_centers_are_complete() -> void:
	assert_eq(RockCliffTopologyResolver.WALL_ROLES.size(), 16, "wall topology exposes sixteen roles")
	assert_eq(RockCliffTopologyResolver.TOP_ROLES.size(), 16, "mountain top exposes sixteen roles")
	assert_eq(
		RockCliffTopologyResolver.top_role_for_cell(Vector2i.ZERO, Vector2i(5, 5), 41),
		&"convex_north_west",
		"north-west top corner has an authored role"
	)
	assert_eq(
		RockCliffTopologyResolver.top_role_for_cell(Vector2i(4, 4), Vector2i(5, 5), 41),
		&"convex_south_east",
		"south-east top corner has an authored role"
	)
	var center_a := RockCliffTopologyResolver.top_role_for_cell(Vector2i(2, 2), Vector2i(5, 5), 41)
	var center_b := RockCliffTopologyResolver.top_role_for_cell(Vector2i(2, 2), Vector2i(5, 5), 41)
	assert_eq(center_a, center_b, "center selection is deterministic without consuming RNG")
	assert_true(center_a in [&"center_01", &"center_02", &"center_03", &"center_04"], "center selection stays in the authored pool")

func test_vertex_topology_classifies_straights_corners_diagonals_and_caps() -> void:
	var expected := {
		1: &"convex_north_west", 2: &"convex_north_east",
		4: &"convex_south_east", 8: &"convex_south_west",
		14: &"concave_north_west", 13: &"concave_north_east",
		11: &"concave_south_east", 7: &"concave_south_west",
		3: &"edge_south", 6: &"edge_west", 12: &"edge_north", 9: &"edge_east",
		5: &"diagonal_north_west_south_east",
		10: &"diagonal_north_east_south_west",
	}
	for mask in expected:
		assert_eq(
			RockCliffTopologyResolver.wall_role_for_vertex_mask(mask),
			expected[mask],
			"vertex mask %d resolves to an authored module" % mask
		)
	assert_eq(RockCliffTopologyResolver.wall_role_for_vertex_mask(0), &"", "empty vertex emits no wall")
	assert_eq(RockCliffTopologyResolver.wall_role_for_vertex_mask(15), &"", "internal vertex emits no wall")
	assert_eq(RockCliffTopologyResolver.cap_role_for_orientation(FallZoneBoundaryRuns.TOP), &"cap_horizontal")
	assert_eq(RockCliffTopologyResolver.cap_role_for_orientation(FallZoneBoundaryRuns.LEFT), &"cap_vertical")
	var occupied := {Vector2i.ZERO: true, Vector2i.RIGHT: true, Vector2i.DOWN: true}
	assert_eq(
		RockCliffTopologyResolver.vertex_mask_for_cells(occupied, Vector2i(1, 1)),
		11,
		"an L union exposes one concave vertex and never an internal edge"
	)
	assert_eq(
		RockCliffTopologyResolver.wall_role_for_vertex_mask(11),
		&"concave_south_east",
		"the L union selects the matching concave module"
	)

func test_plains_survival_mesa_is_split_into_mountain_and_south_chasm() -> void:
	var biome := WorldGen.load_starter_biome()
	var layout := _generate_plains_layout(biome, 88117, {})
	assert_eq(layout.mesa_rects.size(), 1, "Plains keeps one mesa parcel")
	var content := layout.generation_summary.get("parcel_content", {}) as Dictionary
	assert_eq(int(content.get("mountain_void_contact_count", 0)), 1, "Plains records one mountain-to-void contact")
	var mesa: Rect2i = layout.mesa_rects.front()
	var contact := _south_contact(layout, mesa)
	assert_true(contact.has_area(), "the mountain has a direct southern chasm")
	if contact.has_area():
		assert_eq(contact.size.y, TerrainParcelContentPass.PLAINS_MOUNTAIN_VOID_DEPTH, "the contact chasm is exactly two tiles deep")
		assert_eq(contact.position.x, mesa.position.x, "the contact starts at the mountain west edge")
		assert_eq(contact.end.x, mesa.end.x, "the contact reaches the mountain east edge")

func test_disable_internal_void_preserves_infinite_arena_contract() -> void:
	var biome := WorldGen.load_starter_biome()
	var layout := _generate_plains_layout(
		biome,
		88117,
		{"arena_boundary_mode": "walled"}
	)
	var content := layout.generation_summary.get("parcel_content", {}) as Dictionary
	assert_eq(int(content.get("mountain_void_contact_count", 0)), 0, "walled arena does not split its mountain")
	assert_true(layout.fall_zone_rects.is_empty(), "walled arena still has no internal fall zone before perimeter generation")

func test_contact_builds_one_full_height_face_and_suppresses_ground_lip() -> void:
	var zone_size := Vector2i(20, 16)
	var mesa_rects: Array[Rect2i] = [Rect2i(5, 4, 6, 5)]
	var fall_rects: Array[Rect2i] = [Rect2i(5, 9, 6, 2)]
	var sides: Array[StringName] = [&"internal"]
	var runs := FallZoneBoundaryRuns.build(fall_rects, sides, zone_size)
	RockCliffTopologyResolver.annotate_mountain_contacts(runs, mesa_rects)
	var contact_run: Dictionary = {}
	for run in runs:
		if RockCliffTopologyResolver.is_mountain_contact(run):
			contact_run = run
			break
	assert_false(contact_run.is_empty(), "synthetic layout resolves the direct mountain contact")
	var face_builder := RectilinearCliffFaceMeshBuilder.new()
	face_builder.build(fall_rects, sides, zone_size, 48.0, mesa_rects)
	assert_eq(face_builder.mountain_contact_count, 1, "face builder emits one combined contact wall")
	if not contact_run.is_empty():
		var face := face_builder._describe_boundary_run(contact_run, Vector2(zone_size) * 0.5, 48.0)
		var drop := face.get("default_drop", Vector2.ZERO) as Vector2
		assert_almost_eq(drop.y, 48.0 * 3.75, 0.001, "contact face spans +2 to -1.75 tiles")
		assert_true(bool(face.get("mountain_contact", false)), "contact face retains diagnostic metadata")
	var border_builder := TopDownCliffBorderMeshBuilder.new()
	border_builder.build(fall_rects, sides, zone_size, 48.0, false, mesa_rects)
	assert_eq(border_builder.suppressed_mountain_contact_count, 1, "ground lip is absent at the mountain seam")

func test_contact_annotation_splits_a_larger_void_run_at_mountain_edges() -> void:
	var runs: Array[Dictionary] = [{
		"orientation": FallZoneBoundaryRuns.TOP,
		"boundary": 9,
		"start": 2,
		"end": 14,
		"depth_cells": 2,
		"start_corner": FallZoneBoundaryRuns.CORNER_CONVEX,
		"end_corner": FallZoneBoundaryRuns.CORNER_CONVEX,
		"perimeter_side": FallZoneBoundaryRuns.INTERNAL,
	}]
	RockCliffTopologyResolver.annotate_mountain_contacts(
		runs,
		[Rect2i(5, 4, 6, 5)]
	)
	assert_eq(runs.size(), 3, "a merged void edge is split at both mountain ports")
	assert_eq(int(runs[1].get("start", -1)), 5)
	assert_eq(int(runs[1].get("end", -1)), 11)
	assert_true(RockCliffTopologyResolver.is_mountain_contact(runs[1]), "only the overlapping run becomes the tall wall")
	assert_false(RockCliffTopologyResolver.is_mountain_contact(runs[0]), "west continuation remains a regular void wall")
	assert_false(RockCliffTopologyResolver.is_mountain_contact(runs[2]), "east continuation remains a regular void wall")

func test_mesa_contact_suppresses_its_duplicate_south_wall() -> void:
	var normal := RectilinearRockAreaMeshBuilder.new()
	normal.build_local_size(Vector2(288.0, 240.0), 48.0)
	var contact := RectilinearRockAreaMeshBuilder.new()
	contact.build_local_size(Vector2(288.0, 240.0), 48.0, Vector2.ZERO, true)
	assert_lt(contact.face_count, normal.face_count, "contact mesa omits its normal south wall")
	assert_true(contact.suppress_south_face, "suppression remains inspectable for runtime QA")

func _generate_plains_layout(
	biome: BiomeDefinition,
	seed_value: int,
	context: Dictionary
) -> BiomeEnvironmentLayout:
	var cell := BiomeCell.new()
	cell.configure(
		&"plains_rock_test",
		&"plains",
		Vector2i.ZERO,
		BiomeEnvironmentLayout.DEFAULT_ZONE_SIZE,
		seed_value
	)
	var layout := BiomeEnvironmentLayout.new()
	layout.zone_size = BiomeEnvironmentLayout.DEFAULT_ZONE_SIZE
	layout.generation_seed = seed_value
	ObstacleLayoutGenerator.new().populate_layout_voidfirst(
		layout,
		cell,
		biome,
		context
	)
	return layout

func _south_contact(
	layout: BiomeEnvironmentLayout,
	mesa: Rect2i
) -> Rect2i:
	for fall_rect in layout.fall_zone_rects:
		if (
			fall_rect.position.y == mesa.end.y
			and fall_rect.position.x == mesa.position.x
			and fall_rect.end.x == mesa.end.x
		):
			return fall_rect
	return Rect2i()
