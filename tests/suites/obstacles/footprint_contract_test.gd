extends GutTest
## Obstacles A3 — Contratto di footprint/rendering, ostacoli 3x3 e scalabili.
##
## Migra e accorpa:
##   tests/obstacle_rendering_contract_smoke_test.gd
##   tests/obstacle_3x3_smoke_test.gd
##   tests/scalable_obstacle_smoke_test.gd
##
## Il manifest condiviso si carica una sola volta in before_all. I layout generati
## (BiomeTerrainGenerator su una cella cardinale logica) sono l'operazione più costosa: si
## costruiscono dentro i test che li verificano. Il controllo su main.tscn è
## l'unico che boota la scena ed è isolato nell'ultimo test (via fixture condivisa)
## per non sporcare le query a gruppo degli altri.

const ROCK_AREA_MESH_BUILDER_SCRIPT = preload(
	"res://game/modes/zombie/rocks/rectilinear_rock_area_mesh_builder.gd"
)
const WorldGridConfig = preload("res://game/core/world_grid_config.gd")

const REQUIRED_FOOTPRINTS: Dictionary = {
	Vector2i(1, 1): &"small_rock",
	Vector2i(2, 1): &"broken_fence",
	Vector2i(1, 2): &"ice_block",
	Vector2i(2, 2): &"metal_wreck",
	Vector2i(3, 1): &"fallen_log",
	Vector2i(1, 3): &"reed_wall",
	Vector2i(3, 2): &"abandoned_car",
	Vector2i(2, 3): &"burned_car",
	Vector2i(3, 3): &"ice_rock"
}
const BIOME_IDS: Array[StringName] = [
	&"infected_plains", &"toxic_wastes", &"burning_fields", &"frozen_outskirts", &"drowned_marsh"
]
const FEATURE_IDS: Array[StringName] = [&"forest_tree"]
const EXPECTED_SLOTS := Vector2i(3, 3)
const EXPECTED_LEGACY_CELLS := Vector2i(12, 12)
const EXPECTED_CELLS := Vector2i(2, 2)
const LOGICAL_TILE_SCALE := WorldGridConfig.LOGICAL_TILE_SCALE
const ROCK_ID := &"large_rock"
const NON_SCALABLE_ID := &"small_rock"
const SMALL_CELLS := Vector2i(3, 3)
const LARGE_CELLS := Vector2i(5, 5)

var _manifest: EnvironmentAssetManifest

func before_all() -> void:
	_manifest = EnvironmentAssetManifest.reload_shared()

func after_all() -> void:
	_manifest = null
	EnvironmentAssetManifest.clear_shared()
	EnvironmentObject.clear_content_metrics_cache()

# --- manifest a slot ---------------------------------------------------------

func test_manifest_contract() -> void:
	assert_gte(_manifest.version, 9, "obstacle manifest uses the slot-based contract")
	var validation := _manifest.validate()
	assert_true(bool(validation.get("is_valid", false)), "obstacle manifest validates")
	if not bool(validation.get("is_valid", false)):
		for failure in validation.get("failures", PackedStringArray()):
			push_error("manifest: " + String(failure))

func test_required_footprints() -> void:
	var slot_size := _manifest.get_footprint_slot_size_cells()
	for slots_value in REQUIRED_FOOTPRINTS.keys():
		var slots := slots_value as Vector2i
		var obstacle_id := StringName(REQUIRED_FOOTPRINTS[slots])
		assert_true(_manifest.has_object(obstacle_id), "%s footprint object exists" % str(slots))
		assert_eq(_manifest.get_footprint_slots(obstacle_id), slots, "%s declares its exact slot footprint" % String(obstacle_id))
		assert_eq(_manifest.get_footprint_tiles(obstacle_id), Vector2i(slots.x * slot_size.x, slots.y * slot_size.y),
			"%s slot footprint maps exactly to legacy asset cells" % String(obstacle_id))
		var contract := _manifest.get_object_asset_contract(obstacle_id)
		var asset_path := String(contract.get("asset_path", ""))
		assert_false(asset_path.is_empty(), "%s has a visible asset" % String(obstacle_id))
		assert_true(FileAccess.file_exists(asset_path), "%s asset exists" % String(obstacle_id))
		assert_true(asset_path.get_file().contains("%dx%d" % [slots.x, slots.y]), "%s asset filename records its footprint" % String(obstacle_id))
		assert_true(_manifest.blocks_movement(obstacle_id), "%s is a solid obstacle" % String(obstacle_id))

func test_authored_layouts() -> void:
	for biome_id in BIOME_IDS:
		# Carica una copia fresca dal disco: a runtime un'altra suite puo aver
		# sostituito definition.environment_layout con un layout generato sulla
		# BiomeDefinition condivisa in cache. Qui vogliamo il layout autoriale.
		var biome := ResourceLoader.load(
			"res://game/modes/zombie/biomes/%s.tres" % String(biome_id),
			"",
			ResourceLoader.CACHE_MODE_IGNORE
		) as BiomeDefinition
		if biome == null or biome.environment_layout == null:
			continue
		var layout := biome.environment_layout
		assert_true(
			_all_rotations_are_zero(layout.obstacle_rotations),
			"%s authored obstacles remain cardinal" % String(biome_id)
		)
		assert_true(
			_all_rotations_are_zero(layout.hazard_rotations),
			"%s authored hazards remain cardinal" % String(biome_id)
		)
		for index in range(layout.obstacle_ids.size()):
			if index >= layout.obstacle_sizes.size():
				assert_true(false, "%s authored obstacle arrays align" % String(biome_id))
				break
			var obstacle_id := layout.obstacle_ids[index]
			if _manifest.get_category(obstacle_id) == &"border":
				continue
			assert_true(
				layout.obstacle_sizes[index].is_equal_approx(
					Vector2(_manifest.get_footprint_tiles(obstacle_id))
					* WorldGridConfig.LEGACY_TILE_SCALE
				),
				"%s authored %s size matches its legacy asset footprint" % [String(biome_id), String(obstacle_id)]
			)

func _all_rotations_are_zero(rotations: Array[float]) -> bool:
	for rotation_radians in rotations:
		if not is_zero_approx(rotation_radians):
			return false
	return true

func test_void_identity() -> void:
	var cliff := _manifest.get_object_asset_contract(&"fall_zone")
	var house := _manifest.get_object_asset_contract(&"ruined_house")
	assert_eq(_manifest.get_category(&"fall_zone"), &"cliff", "fall zone keeps cliff identity")
	assert_false(_manifest.blocks_movement(&"fall_zone"), "fall zone is not a solid obstacle")
	assert_ne(String(cliff.get("asset_path", "")), String(house.get("asset_path", "")), "void/cliff art is distinct from solid obstacle art")

# --- oggetto runtime e footprint --------------------------------------------

func test_runtime_object() -> void:
	var system := ObstacleSystem.new()
	add_child(system)
	await wait_physics_frames(1)
	var obstacle_id := &"ruined_house"
	var footprint := WorldGridConfig.legacy_size_to_new_tiles(
		_manifest.get_footprint_tiles(obstacle_id)
	)
	var world_size := Vector2(footprint) * LOGICAL_TILE_SCALE
	var obstacle := system.create_obstacle_instance(obstacle_id, world_size, &"rectangle", 0.0,
		Color(0.38, 0.32, 0.22, 1.0), Color(0.78, 0.64, 0.28, 1.0))
	assert_not_null(obstacle, "runtime house object is created")
	if obstacle != null:
		add_child(obstacle)
		await wait_physics_frames(1)
		assert_true(obstacle.get_visual_base_size().is_equal_approx(world_size), "visual base equals collision footprint")
		assert_true(obstacle.is_footprint_contract_aligned(), "runtime footprint matches manifest")
		assert_eq(obstacle.get_footprint_slots(), Vector2i(8, 8), "town house exposes its doubled 8x8 footprint")
		assert_eq(obstacle.z_index, 0, "runtime object participates in Y-sort")
		assert_true(is_equal_approx(obstacle.get_sort_anchor_y(), _manifest.get_sort_offset(obstacle_id)), "sprite floor anchor uses the manifest sort offset")
		assert_true(bool(obstacle.call("has_asset_sprite")), "runtime house uses its top-down asset")
		system.register_streamed_obstacle(obstacle, obstacle_id)
		system.set_debug_footprints_visible(true)
		assert_true(system.are_debug_footprints_visible(), "F9 debug state is exposed")
		assert_true(bool(obstacle.call("has_debug_footprint")), "debug state reaches active obstacle footprints")
		obstacle.queue_free()
	system.queue_free()
	await wait_physics_frames(1)

func test_floor_center_visual_is_centered_on_its_collision() -> void:
	var system := ObstacleSystem.new()
	add_child(system)
	await wait_physics_frames(1)
	var obstacle_id := &"ruined_house"
	var footprint := WorldGridConfig.legacy_size_to_new_tiles(
		_manifest.get_footprint_tiles(obstacle_id)
	)
	var world_size := Vector2(footprint) * LOGICAL_TILE_SCALE
	var obstacle := system.create_obstacle_instance(
		obstacle_id,
		world_size,
		&"rectangle",
		0.0,
		Color(0.38, 0.32, 0.22, 1.0),
		Color(0.78, 0.64, 0.28, 1.0)
	) as EnvironmentObject
	assert_not_null(obstacle, "floor-centered house is created")
	if obstacle != null:
		add_child(obstacle)
		await wait_physics_frames(1)
		var visual_bounds := obstacle.get_asset_visual_bounds()
		var collision_center := obstacle.get_collision_offset()
		assert_lte(
			absf(visual_bounds.get_center().y - collision_center.y),
			1.0,
			"floor-centered house art stays centered on its physical footprint"
		)
		assert_lte(
			absf(visual_bounds.get_center().x - collision_center.x),
			1.0,
			"floor-centered house art keeps the collider horizontal center"
		)
		obstacle.queue_free()
	system.queue_free()
	await wait_physics_frames(1)

func test_generated_layout_records() -> void:
	var generator := BiomeTerrainGenerator.new()
	add_child(generator)
	var biome := load("res://game/modes/zombie/biomes/infected_plains.tres") as BiomeDefinition
	assert_not_null(biome, "starter biome loads for generated footprint validation")
	if biome != null:
		var cell := BiomeCell.new()
		cell.configure(&"obstacle_contract_cell", biome.biome_id, Vector2i.ZERO, BiomeEnvironmentLayout.DEFAULT_ZONE_SIZE, 90210)
		var layout := generator.generate_layout_for_cell(cell, biome)
		assert_not_null(layout, "starter generated layout exists")
		if layout == null:
			generator.queue_free()
			return
		var record_failures := layout.validate_obstacle_records(_manifest)
		assert_true(record_failures.is_empty(), "logical rectangles, placement sizes and assets share one footprint")
		for failure in record_failures:
			push_error("obstacle record: " + failure)
		for index in range(layout.obstacle_rects.size()):
			var record := layout.get_obstacle_record(index, _manifest)
			assert_false(record.is_empty(), "generated obstacle exposes a render record")
			if record.is_empty():
				continue
			assert_eq(bool(record.get("blocks_movement", false)), _manifest.blocks_movement(StringName(record.get("type", &""))),
				"render record keeps the collision contract")
			assert_false(String(record.get("asset_path", "")).is_empty(), "generated obstacle cannot become invisible collision")
			assert_true(
				(record.get("placement_size", Vector2.ZERO) as Vector2).is_equal_approx(
					layout.obstacle_sizes[index]
				),
				"render record keeps placement size separate from physical collision"
			)
			var record_id := StringName(record.get("type", &""))
			if record_id == &"forest_tree":
				assert_eq(record.get("collision_size"), Vector2(96.0, 96.0), "tree record exposes its full-width root collider")
				assert_eq(record.get("collision_offset"), Vector2(0.0, 24.0), "tree record exposes the root offset")
	generator.queue_free()
	await wait_physics_frames(1)

# --- feature obstacle 3x3 (forest_tree) -------------------------------------

func test_3x3_feature_obstacle() -> void:
	for obstacle_id in FEATURE_IDS:
		assert_true(_manifest.has_object(obstacle_id), "%s exists" % String(obstacle_id))
		assert_eq(_manifest.get_footprint_slots(obstacle_id), EXPECTED_SLOTS, "%s occupies exactly 3x3 slots" % String(obstacle_id))
		assert_eq(_manifest.get_footprint_tiles(obstacle_id), EXPECTED_LEGACY_CELLS, "%s maps 3x3 slots to 12x12 legacy asset cells" % String(obstacle_id))
		assert_true(_manifest.blocks_movement(obstacle_id), "%s blocks movement" % String(obstacle_id))
		assert_true(_manifest.blocks_projectiles(obstacle_id), "%s blocks projectiles" % String(obstacle_id))
		var contract := _manifest.get_object_asset_contract(obstacle_id)
		var asset_path := String(contract.get("asset_path", ""))
		assert_true(asset_path.ends_with("_3x3.png"), "%s uses a named 3x3 PNG" % String(obstacle_id))
		assert_true(FileAccess.file_exists(asset_path), "%s PNG exists" % String(obstacle_id))
		assert_eq(String(contract.get("source", "")), "user_provided", "%s records imported-art provenance" % String(obstacle_id))

	var system := ObstacleSystem.new()
	add_child(system)
	await wait_physics_frames(1)
	var world_size := Vector2(EXPECTED_CELLS) * LOGICAL_TILE_SCALE
	for obstacle_id in FEATURE_IDS:
		var obstacle := system.create_obstacle_instance(obstacle_id, world_size, &"rectangle", 0.0,
			Color(0.27, 0.34, 0.18, 1.0), Color(0.72, 0.62, 0.30, 1.0))
		assert_not_null(obstacle, "%s runtime object is created" % String(obstacle_id))
		if obstacle == null:
			continue
		add_child(obstacle)
		await wait_physics_frames(1)
		assert_eq(obstacle.get_footprint_slots(), EXPECTED_SLOTS, "%s keeps 3x3 runtime slots" % String(obstacle_id))
		assert_true(obstacle.get_visual_base_size().is_equal_approx(world_size), "%s keeps its 2x2 placement footprint" % String(obstacle_id))
		assert_true(obstacle.is_footprint_contract_aligned(), "%s runtime footprint is aligned" % String(obstacle_id))
		assert_eq(obstacle.get_collision_size(), Vector2(96.0, 96.0), "%s uses a full-width root collider" % String(obstacle_id))
		assert_eq(obstacle.get_collision_offset(), Vector2(0.0, 24.0), "%s moves its collider to the roots" % String(obstacle_id))
		var root_center := obstacle.to_global(obstacle.get_collision_offset())
		assert_true(obstacle.contains_global_position(root_center), "%s blocks the root center" % String(obstacle_id))
		assert_true(obstacle.contains_global_position(root_center + Vector2(47.0, 0.0)), "%s blocks inside the doubled root radius" % String(obstacle_id))
		assert_false(obstacle.contains_global_position(root_center + Vector2(49.0, 0.0)), "%s keeps a circular rather than square placement hitbox" % String(obstacle_id))
		assert_false(obstacle.contains_global_position(obstacle.global_position + world_size * 0.49), "%s canopy corner is not physical collision" % String(obstacle_id))
		assert_true(bool(obstacle.call("has_asset_sprite")), "%s loads its generated sprite" % String(obstacle_id))
		var collision := obstacle.get_node_or_null("CollisionShape2D") as CollisionShape2D
		var circle := collision.shape as CircleShape2D if collision != null else null
		assert_true(circle != null and is_equal_approx(circle.radius, 48.0), "%s collision is a doubled root-centered circle" % String(obstacle_id))
		assert_true(collision != null and collision.position.is_equal_approx(Vector2(0.0, 24.0)), "%s physics shape follows the root offset" % String(obstacle_id))
		obstacle.queue_free()
		await wait_physics_frames(1)
	system.queue_free()
	await wait_physics_frames(1)

	var generator := BiomeTerrainGenerator.new()
	add_child(generator)
	var biome := load("res://game/modes/zombie/biomes/infected_plains.tres") as BiomeDefinition
	assert_not_null(biome, "infected plains loads")
	if biome == null:
		generator.queue_free()
		return
	var cell := BiomeCell.new()
	cell.configure(&"feature_obstacle_cell", biome.biome_id, Vector2i.ZERO, BiomeEnvironmentLayout.DEFAULT_ZONE_SIZE, 314159)
	var layout := generator.generate_layout_for_cell(cell, biome)
	assert_not_null(layout, "generated layout exists")
	if layout == null:
		generator.queue_free()
		return
	for obstacle_id in FEATURE_IDS:
		var index := layout.obstacle_ids.find(obstacle_id)
		assert_gte(index, 0, "%s is positioned in the starter biome" % String(obstacle_id))
		if index < 0:
			continue
		var rect := layout.obstacle_rects[index]
		assert_eq(rect.size, EXPECTED_CELLS, "%s placement owns exactly 2x2 logical cells" % String(obstacle_id))
		assert_true(layout.obstacle_sizes[index].is_equal_approx(Vector2(EXPECTED_CELLS) * LOGICAL_TILE_SCALE), "%s placement reserves its full canopy footprint" % String(obstacle_id))
		for sample in [rect.position, rect.position + _center_offset(rect.size), rect.end - Vector2i.ONE]:
			assert_eq(layout.get_terrain_class_at_cell(sample), BiomeEnvironmentLayout.TERRAIN_OBSTACLE, "%s occupied sample is classified as obstacle" % String(obstacle_id))
	var record_failures := layout.validate_obstacle_records(_manifest)
	assert_true(record_failures.is_empty(), "generated obstacle records remain aligned")
	for failure in record_failures:
		push_error("obstacle record: " + failure)
	generator.queue_free()
	await wait_physics_frames(1)

# --- ostacolo scalabile (large_rock) ----------------------------------------

func test_scalable_obstacle() -> void:
	assert_true(_manifest.is_scalable(ROCK_ID), "large_rock is scalable")
	assert_false(_manifest.is_scalable(NON_SCALABLE_ID), "small_rock is not scalable")
	assert_eq(_manifest.get_footprint_tiles(ROCK_ID), Vector2i(15, 15), "large_rock base footprint is 15x15")
	var contract := _manifest.get_object_asset_contract(ROCK_ID)
	var top_path := String(contract.get("asset_path", ""))
	assert_true(top_path.ends_with("rock_plateau_top_generated.png"), "large_rock uses the dedicated harmonious top material")
	assert_true(FileAccess.file_exists(top_path), "dedicated rock top texture exists")
	var import_file := FileAccess.open(top_path + ".import", FileAccess.READ)
	assert_true(import_file != null, "rock top import contract exists")
	if import_file != null:
		var import_text := import_file.get_as_text()
		import_file.close()
		assert_true(import_text.contains("mipmaps/generate=true"), "rock top enables mipmaps")
		assert_true(import_text.contains("process/size_limit=512"), "rock top limits runtime size")
	var face_contract := _manifest.get_void_asset_contract(&"rock_cliff_face_texture")
	var face_path := String(face_contract.get("asset_path", ""))
	assert_true(face_path.ends_with("rock_cliff_face_upward_generated.png"), "raised rock tiles use the dedicated upward face material")
	assert_true(FileAccess.file_exists(face_path), "raised rock face texture exists")
	var face_import_file := FileAccess.open(face_path + ".import", FileAccess.READ)
	assert_true(face_import_file != null, "raised rock face import contract exists")
	if face_import_file != null:
		var face_import_text := face_import_file.get_as_text()
		face_import_file.close()
		assert_true(face_import_text.contains("mipmaps/generate=true"), "raised rock face enables mipmaps")
		assert_true(face_import_text.contains("process/size_limit=512"), "raised rock face limits runtime size")
	var report := _manifest.validate()
	assert_true(bool(report.get("is_valid", false)), "manifest stays valid with a scalable non-slot footprint")
	for failure in report.get("failures", PackedStringArray()):
		push_error("manifest: " + String(failure))

	var system := ObstacleSystem.new()
	add_child(system)
	await wait_physics_frames(1)
	var small := await _spawn_rock(system, SMALL_CELLS)
	var large := await _spawn_rock(system, LARGE_CELLS)
	assert_true(small != null and large != null, "both rock instances are created")
	if small != null and large != null:
		_expect_collision_size(small, Vector2(SMALL_CELLS) * LOGICAL_TILE_SCALE, "small rock")
		_expect_collision_size(large, Vector2(LARGE_CELLS) * LOGICAL_TILE_SCALE, "large rock")
		assert_true(bool(small.call("has_asset_visual")), "small rock owns an asset-backed mesa visual")
		assert_true(bool(large.call("has_asset_visual")), "large rock owns an asset-backed mesa visual")
		assert_true(StringName(small.call("get_render_mode")) == &"y_sorted_mesa", "large_rock selects the per-instance Y-sorted mesa render mode")
		assert_true(bool(small.call("has_mesa_visual")), "small rock builds its own mesa geometry")
		assert_true(bool(large.call("has_mesa_visual")), "large rock builds its own mesa geometry")
		var small_counts := small.call("get_mesa_geometry_counts") as Dictionary
		var large_counts := large.call("get_mesa_geometry_counts") as Dictionary
		assert_eq(int(small_counts.get("areas", 0)), 1, "small rock owns one mesa area")
		assert_eq(int(large_counts.get("areas", 0)), 1, "large rock owns one mesa area")
		assert_eq(int(small_counts.get("faces", 0)), 17, "small rock rounds visible walls with six-segment corners")
		assert_eq(int(large_counts.get("faces", 0)), 17, "large rock rounds visible walls with six-segment corners")
		assert_false(bool(small.call("has_asset_sprite")), "small rock does not stretch a sprite")
		assert_false(bool(large.call("has_asset_sprite")), "large rock does not stretch a sprite")
		assert_true(bool(small.call("is_world_position_behind_cliff", Vector2(0.0, -100.0))), "position north of the sort line is behind the cliff")
		assert_true(bool(small.call("is_world_position_in_front_of_cliff", Vector2(0.0, 100.0))), "position south of the sort line is in front of the cliff")
		assert_false(bool(small.call("is_world_position_behind_cliff", Vector2(200.0, -100.0))), "position outside the rock width is not occluded")
		assert_null(
			small.get_node_or_null("RockAreaOccluder"),
			"rock does not create a second shifted crown layer"
		)
		assert_true(bool(large.call("is_footprint_contract_aligned")), "scalable rock counts as footprint-aligned")
		small.queue_free()
		large.queue_free()
		await wait_physics_frames(1)
	system.queue_free()
	await wait_physics_frames(1)

	var layout := BiomeEnvironmentLayout.new()
	layout.generation_seed = 4242
	var rect := Rect2i(Vector2i(40, 40), LARGE_CELLS)
	layout.obstacle_rects.append(rect)
	layout.obstacle_ids.append(ROCK_ID)
	layout.obstacle_positions.append(
		layout.obstacle_rect_center_to_world(rect, ROCK_ID)
	)
	layout.obstacle_sizes.append(layout.rect_size_to_world(rect))
	layout.obstacle_rotations.append(0.0)
	layout.obstacle_shape_ids.append(&"rectangle")
	var record_failures := layout.validate_obstacle_records(_manifest)
	assert_true(record_failures.is_empty(), "scalable rock record is valid at a non-base footprint")
	for failure in record_failures:
		push_error("record: " + String(failure))

func test_rock_area_mesh_builder() -> void:
	var builder := ROCK_AREA_MESH_BUILDER_SCRIPT.new() as RectilinearRockAreaMeshBuilder
	var rock_rects: Array[Rect2i] = [
		Rect2i(Vector2i(8, 10), SMALL_CELLS),
		Rect2i(Vector2i(52, 42), LARGE_CELLS)
	]
	var palette := load("res://game/modes/zombie/biomes/infected_plains_palette.tres") as BiomePalette
	builder.configure(palette, 424242)
	builder.build(rock_rects, Vector2i(100, 100), LOGICAL_TILE_SCALE)
	var counts := builder.get_counts()
	assert_true(builder.has_geometry(), "rock-area builder creates a raised plateau")
	assert_eq(int(counts.get("areas", 0)), 2, "builder covers both generated rock rects")
	assert_eq(int(counts.get("faces", 0)), 34, "each plateau emits rounded east/south/west wall segments")
	assert_not_null(builder.get_face_mesh(), "ascending wall mesh exists")
	assert_not_null(builder.top_mesh, "raised crown mesh exists")
	var single_rect: Array[Rect2i] = [
		Rect2i(Vector2i(12, 12), SMALL_CELLS)
	]
	builder.build(single_rect, Vector2i(64, 64), LOGICAL_TILE_SCALE)
	var raise := RectilinearRockAreaMeshBuilder.RAISE_HEIGHT_CELLS * LOGICAL_TILE_SCALE
	var lean := minf(
		raise * RectilinearRockAreaMeshBuilder.LATERAL_LEAN_RATIO,
		float(SMALL_CELLS.x) * LOGICAL_TILE_SCALE * 0.3
	)
	var top_bounds := builder.top_mesh.get_aabb() if builder.top_mesh != null else AABB()
	# The crown is the footprint translated straight up and inset by `lean` per side.
	assert_lt(absf(top_bounds.size.x - (float(SMALL_CELLS.x) * LOGICAL_TILE_SCALE - lean * 2.0)), 0.01,
		"crown is inset on both sides into a mesa")
	assert_lt(absf(top_bounds.size.y - float(SMALL_CELLS.y) * LOGICAL_TILE_SCALE), 0.01,
		"crown keeps the footprint depth, lifted above the ground")
	# Walls span the full footprint width at the ground and rise the lift height.
	var face_bounds := builder.get_face_mesh().get_aabb() if builder.get_face_mesh() != null else AABB()
	assert_lt(absf(face_bounds.size.x - float(SMALL_CELLS.x) * LOGICAL_TILE_SCALE), 0.01,
		"walls reach the full footprint width at the ground")
	assert_gt(face_bounds.size.y, float(SMALL_CELLS.y) * LOGICAL_TILE_SCALE,
		"rounded walls still rise above the footprint depth")
	assert_lte(face_bounds.size.y, float(SMALL_CELLS.y) * LOGICAL_TILE_SCALE + raise,
		"rounded walls remain inside the lifted footprint envelope")

# --- main.tscn: obstacle system + Y-sort (ultimo: boota la scena) -----------

func test_main_scene_obstacle_system() -> void:
	var scene = _new_main_scene_fixture()
	assert_true(scene.boot(self), "main scene loads after obstacle rendering changes")
	await wait_physics_frames(2)
	await wait_physics_frames(1)
	var system: ObstacleSystem = scene.node(&"obstacle_system") as ObstacleSystem
	var environment_props: Node2D = scene.main.get_node_or_null("World/EnvironmentProps") as Node2D
	var players: Node2D = scene.main.get_node_or_null("World/Players") as Node2D
	var bosses: Node2D = scene.main.get_node_or_null("World/Bosses") as Node2D
	assert_not_null(system, "main scene exposes the shared obstacle system")
	assert_true(environment_props != null and environment_props.y_sort_enabled, "main scene keeps environment obstacles in Y-sort")
	assert_true(players != null and players.y_sort_enabled, "main scene keeps players in the same Y-sort space")
	assert_true(bosses != null and bosses.y_sort_enabled, "main scene keeps bosses in the same Y-sort space")
	scene.teardown()
	scene = null
	await wait_physics_frames(1)

# --- helper (porting dei test legacy) ---------------------------------------

func _spawn_rock(system: ObstacleSystem, cells: Vector2i) -> Node:
	var obstacle := system.create_obstacle_instance(ROCK_ID, Vector2(cells) * LOGICAL_TILE_SCALE, &"rectangle", 0.0,
		Color(0.30, 0.30, 0.30, 1.0), Color(0.70, 0.70, 0.70, 1.0))
	if obstacle == null:
		return null
	add_child(obstacle)
	await wait_physics_frames(1)
	return obstacle

func _expect_collision_size(obstacle: Node, expected: Vector2, label: String) -> void:
	var collision := obstacle.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var rectangle := collision.shape as RectangleShape2D if collision != null else null
	assert_true(rectangle != null and rectangle.size.is_equal_approx(expected), "%s collision matches its instance footprint" % label)

func _span_before_center(span: int) -> int:
	return maxi(floori(float(span) * 0.5), 0)

func _center_offset(size: Vector2i) -> Vector2i:
	return Vector2i(_span_before_center(size.x), _span_before_center(size.y))

func _new_main_scene_fixture():
	var script := ResourceLoader.load(
		"res://tests/support/main_scene_fixture.gd",
		"",
		ResourceLoader.CACHE_MODE_IGNORE
	) as Script
	assert_true(script != null, "main scene fixture script loads")
	return script.new() if script != null else null
