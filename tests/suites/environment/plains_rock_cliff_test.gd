extends GutTest

const WorldGen = preload("res://tests/support/world_gen_helpers.gd")
const ROCK_ASSET_ROOT := "res://assets/environment/top_down/rock_cliffs/plains/"


func test_generation_manifest_tracks_v3_source_and_generated_hashes() -> void:
	var manifest_path := ROCK_ASSET_ROOT + "generation_manifest.json"
	var document: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(manifest_path)
	)
	assert_true(document is Dictionary, "rock generation manifest parses")
	if not document is Dictionary:
		return
	var generation_manifest := document as Dictionary
	assert_gte(
		int(generation_manifest.get("version", 0)),
		9,
		"one-tile wall and crown inset uses generation manifest v9"
	)
	var processing := generation_manifest.get("processing", {}) as Dictionary
	var assets := generation_manifest.get("assets", {}) as Dictionary
	var wall := assets.get("wall", {}) as Dictionary
	assert_eq(
		String(wall.get("source_file", "")),
		"plains_dark_fantasy_wall_cross_source_v3.png",
		"the approved source is the footprint-safe v3 cross"
	)
	var expected_hashes := {
		"wall_source_sha256": "plains_dark_fantasy_wall_cross_source_v3.png",
		"wall_alpha_source_sha256": "plains_dark_fantasy_wall_cross_source_v3_alpha.png",
		"wall_atlas_sha256": "plains_dark_fantasy_wall_atlas.png",
		"top_atlas_sha256": "plains_dark_fantasy_top_atlas.png",
	}
	for hash_key in expected_hashes:
		assert_eq(
			_sha256_file(ROCK_ASSET_ROOT + String(expected_hashes[hash_key])),
			String(processing.get(hash_key, "")),
			"%s matches the generated file" % hash_key
		)

func test_manifest_declares_complete_external_plains_rock_kit() -> void:
	var manifest := EnvironmentAssetManifest.reload_shared()
	assert_gte(manifest.version, 19, "rock cliff cutover uses manifest v19")
	var report := manifest.validate()
	assert_true(bool(report.get("is_valid", false)), "manifest with final rock atlas kit validates")
	var biome_contract := manifest.get_biome_asset_set_contract(&"plains")
	assert_eq(
		StringName(biome_contract.get("rock_cliff_kit_id", &"")),
		&"plains_dark_fantasy",
		"Plains selects the dark-fantasy rock kit"
	)
	var kit := manifest.get_rock_cliff_kit_contract(&"plains_dark_fantasy")
	assert_eq(String(kit.get("status", "")), "final", "source-derived atlases are promoted")
	assert_eq((kit.get("wall_regions", {}) as Dictionary).size(), 16, "wall atlas maps all sixteen modules")
	assert_eq((kit.get("top_regions", {}) as Dictionary).size(), 16, "top atlas maps all sixteen modules")
	assert_true(manifest.rock_cliff_kit_has_external_asset(&"plains_dark_fantasy", &"wall"), "approved wall atlas is delivered")
	assert_true(manifest.rock_cliff_kit_has_external_asset(&"plains_dark_fantasy", &"top"), "source-derived top atlas is delivered")
	assert_true(manifest.rock_cliff_kit_has_external_assets(&"plains_dark_fantasy"), "both authored-source atlases activate the kit")
	assert_true(
		manifest.get_rock_cliff_kit_asset_path(&"plains_dark_fantasy", &"wall").ends_with("plains_dark_fantasy_wall_atlas.png"),
		"delivered wall resolves to the approved atlas"
	)
	assert_true(
		manifest.get_rock_cliff_kit_asset_path(&"plains_dark_fantasy", &"top").ends_with("plains_dark_fantasy_top_atlas.png"),
		"delivered top resolves to the source-derived atlas"
	)

func test_delivered_wall_atlas_is_rgba_complete_unique_and_sliceable() -> void:
	var manifest := EnvironmentAssetManifest.get_shared()
	var kit := manifest.get_rock_cliff_kit_contract(&"plains_dark_fantasy")
	var wall_path := String(kit.get("wall_atlas_path", ""))
	var image := Image.load_from_file(ProjectSettings.globalize_path(wall_path))
	assert_false(image.is_empty(), "wall atlas PNG loads")
	assert_eq(image.get_size(), Vector2i(2048, 2048), "wall atlas is exactly 2048x2048")
	assert_true(image.get_format() in [Image.FORMAT_RGBA8, Image.FORMAT_RGBA4444], "wall atlas exposes alpha")
	var fingerprints := {}
	var expected_masks := {
		&"edge_north": 12, &"edge_east": 9,
		&"edge_south": 3, &"edge_west": 6,
		&"convex_north_east": 2, &"convex_south_east": 4,
		&"convex_south_west": 8, &"convex_north_west": 1,
		&"concave_north_east": 13, &"concave_south_east": 11,
		&"concave_south_west": 7, &"concave_north_west": 14,
		&"diagonal_north_east_south_west": 10,
		&"diagonal_north_west_south_east": 5,
	}
	var lateral_forbidden_rects := {
		&"edge_east": Rect2i(256, 0, 256, 512),
		&"edge_west": Rect2i(0, 0, 256, 512),
		&"convex_north_east": Rect2i(0, 0, 256, 512),
		&"convex_south_east": Rect2i(0, 0, 256, 512),
		&"convex_south_west": Rect2i(256, 0, 256, 512),
		&"convex_north_west": Rect2i(256, 0, 256, 512),
		&"concave_north_east": Rect2i(256, 0, 256, 256),
		&"concave_south_east": Rect2i(256, 256, 256, 256),
		&"concave_south_west": Rect2i(0, 256, 256, 256),
		&"concave_north_west": Rect2i(0, 0, 256, 256),
	}
	for role in RockCliffTopologyResolver.WALL_ROLES:
		var region := manifest.get_rock_cliff_atlas_region(
			&"plains_dark_fantasy", &"wall", role
		)
		assert_eq(region.size, Vector2i(512, 512), "%s owns one full module" % String(role))
		var module := image.get_region(region)
		var context := HashingContext.new()
		context.start(HashingContext.HASH_SHA256)
		context.update(module.get_data())
		var fingerprint := context.finish().hex_encode()
		assert_false(fingerprints.has(fingerprint), "%s is pixel-unique" % String(role))
		fingerprints[fingerprint] = role
		if expected_masks.has(role):
			assert_eq(
				_module_quadrant_mask(module),
				int(expected_masks[role]),
				"%s keeps the declared cardinal topology" % String(role)
			)
		if lateral_forbidden_rects.has(role):
			assert_lte(
				_module_rect_alpha_coverage(
					module,
					lateral_forbidden_rects[role] as Rect2i
				),
				0.001,
				"%s emits no alpha outside its occupied footprint" % String(role)
			)
		if role == &"edge_east":
			assert_gte(
				_module_rect_alpha_coverage(module, Rect2i(0, 0, 256, 512)),
				0.55,
				"east cliff occupies the internal one-tile band"
			)
		if role == &"edge_west":
			assert_gte(
				_module_rect_alpha_coverage(module, Rect2i(256, 0, 256, 512)),
				0.55,
				"west cliff occupies the internal one-tile band"
			)

	var atlas_set := RockCliffAtlasSet.new()
	assert_true(atlas_set.configure(&"plains", manifest), "complete atlas set loads")
	assert_true(atlas_set.is_wall_ready(), "wall atlas is ready")
	assert_true(atlas_set.is_top_ready(), "top atlas is ready")
	assert_true(atlas_set.is_ready(), "the complete kit is active")
	var south_edge := atlas_set.get_wall_texture(&"edge_south")
	assert_not_null(south_edge, "wall role resolves to AtlasTexture")
	if south_edge != null:
		assert_eq(south_edge.region, Rect2(1024.0, 0.0, 512.0, 512.0))
	var center := atlas_set.get_top_texture(&"center_01")
	assert_not_null(center, "top center resolves to AtlasTexture")
	if center != null:
		assert_eq(center.region, Rect2(0.0, 1536.0, 512.0, 512.0))
	var south_uv := atlas_set.get_wall_uv_rect(&"edge_south")
	assert_gt(south_uv.position.x, 0.49, "mesh UV starts inside the declared atlas cell")
	assert_lt(south_uv.size.x, 0.251, "mesh UV samples one module, not the full atlas")
	var center_uv := atlas_set.get_top_uv_rect(&"center_01")
	assert_gt(center_uv.position.y, 0.74, "top UV resolves the fourth atlas row")

func test_source_derived_top_atlas_has_sixteen_unique_rgba_modules() -> void:
	var manifest := EnvironmentAssetManifest.get_shared()
	var kit := manifest.get_rock_cliff_kit_contract(&"plains_dark_fantasy")
	var top_path := String(kit.get("top_atlas_path", ""))
	var image := Image.load_from_file(ProjectSettings.globalize_path(top_path))
	assert_false(image.is_empty(), "top atlas PNG loads")
	assert_eq(image.get_size(), Vector2i(2048, 2048), "top atlas is exactly 2048x2048")
	assert_true(image.get_format() in [Image.FORMAT_RGBA8, Image.FORMAT_RGBA4444], "top atlas exposes alpha")
	var fingerprints := {}
	for role in RockCliffTopologyResolver.TOP_ROLES:
		var region := manifest.get_rock_cliff_atlas_region(
			&"plains_dark_fantasy", &"top", role
		)
		var module := image.get_region(region)
		var context := HashingContext.new()
		context.start(HashingContext.HASH_SHA256)
		context.update(module.get_data())
		var fingerprint := context.finish().hex_encode()
		assert_false(fingerprints.has(fingerprint), "%s is pixel-unique" % String(role))
		fingerprints[fingerprint] = role
		if String(role).begins_with("center_"):
			assert_gte(_module_opaque_coverage(module), 0.98, "%s is an opaque surface" % String(role))

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
	var face_builder := RectilinearCliffFaceMeshBuilder.new()
	var expected_crops := {
		&"concave_north_west": Rect2(0.0, 0.0, 0.5, 0.5),
		&"concave_north_east": Rect2(0.5, 0.0, 0.5, 0.5),
		&"concave_south_east": Rect2(0.5, 0.5, 0.5, 0.5),
		&"concave_south_west": Rect2(0.0, 0.5, 0.5, 0.5),
	}
	for role in expected_crops:
		assert_eq(
			face_builder._atlas_stamp_crop(role, 0.0),
			expected_crops[role],
			"%s keeps only the corner quadrant and cannot overrun grass" % role
		)
	assert_eq(
		face_builder._atlas_stamp_crop(&"concave_south_east", 96.0),
		Rect2(Vector2.ZERO, Vector2.ONE),
		"raised mountain-contact corners retain their full-height drop"
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
	var atlas_set := RockCliffAtlasSet.new()
	assert_true(atlas_set.configure(&"plains"), "contact test loads the Plains atlas")
	face_builder.build(
		fall_rects, sides, zone_size, 48.0, mesa_rects, atlas_set
	)
	assert_eq(face_builder.mountain_contact_count, 1, "face builder emits one combined contact wall")
	assert_gt(face_builder.atlas_stamp_count, 0, "void outline emits batched atlas stamps")
	assert_gt(
		face_builder.mountain_contact_stamp_count,
		0,
		"mountain-contact stamps extend from the raised crest"
	)
	assert_eq(
		face_builder._atlas_stamp_size(48.0, 96.0, &"edge_south"),
		Vector2(96.0, 384.0),
		"the cross atlas doubles the straight mountain-contact visual height"
	)
	assert_eq(
		face_builder._atlas_stamp_size(
			48.0, 96.0, &"concave_south_west"
		),
		Vector2(96.0, 192.0),
		"a contact corner stops at the turn instead of growing a lateral tail"
	)
	assert_eq(
		face_builder._atlas_stamp_size(48.0, 0.0),
		Vector2(96.0, 96.0),
		"ordinary void and world-border stamps keep their original proportions"
	)
	assert_false(
		face_builder.face_meshes_by_role.is_empty(),
		"Plains wall stamps are grouped into semantic role meshes"
	)
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

func _module_quadrant_mask(image: Image) -> int:
	var mask := 0
	var quadrant_bits: Array[int] = [1, 2, 8, 4]
	for quadrant in range(4):
		var origin := Vector2i(
			256 if quadrant % 2 == 1 else 0,
			256 if quadrant >= 2 else 0
		)
		var occupied := 0
		var samples := 0
		for y in range(origin.y, origin.y + 256, 8):
			for x in range(origin.x, origin.x + 256, 8):
				samples += 1
				if image.get_pixel(x, y).a > 0.10:
					occupied += 1
		if float(occupied) / float(maxi(samples, 1)) >= 0.25:
			mask |= quadrant_bits[quadrant]
	return mask

func _module_opaque_coverage(image: Image) -> float:
	var opaque := 0
	var samples := 0
	for y in range(0, image.get_height(), 8):
		for x in range(0, image.get_width(), 8):
			samples += 1
			if image.get_pixel(x, y).a > 0.98:
				opaque += 1
	return float(opaque) / float(maxi(samples, 1))


func _module_rect_alpha_coverage(image: Image, rect: Rect2i) -> float:
	var occupied := 0
	var samples := 0
	for y in range(rect.position.y, rect.end.y, 8):
		for x in range(rect.position.x, rect.end.x, 8):
			samples += 1
			if image.get_pixel(x, y).a > 0.10:
				occupied += 1
	return float(occupied) / float(maxi(samples, 1))


func _sha256_file(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	while file.get_position() < file.get_length():
		var remaining := file.get_length() - file.get_position()
		context.update(file.get_buffer(mini(remaining, 1024 * 1024)))
	return context.finish().hex_encode()
