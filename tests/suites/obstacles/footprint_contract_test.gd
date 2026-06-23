extends GutTest
## Obstacles A3 — Contratto di footprint/rendering, ostacoli 3x3 e scalabili.
##
## Migra e accorpa:
##   tests/obstacle_rendering_contract_smoke_test.gd
##   tests/obstacle_3x3_smoke_test.gd
##   tests/scalable_obstacle_smoke_test.gd
##
## Il manifest condiviso si carica una sola volta in before_all. I layout generati
## (BiomeTerrainGenerator su una cella 500x500) sono l'operazione più costosa: si
## costruiscono dentro i test che li verificano. Il controllo su main.tscn è
## l'unico che boota la scena ed è isolato nell'ultimo test (via fixture condivisa)
## per non sporcare le query a gruppo degli altri.

const MainSceneFixture = preload("res://tests/support/main_scene_fixture.gd")

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
const EXPECTED_CELLS := Vector2i(12, 12)
const LOGICAL_TILE_SCALE := 8.0
const ROCK_ID := &"large_rock"
const NON_SCALABLE_ID := &"small_rock"
const SMALL_CELLS := Vector2i(15, 15)
const LARGE_CELLS := Vector2i(30, 30)

var _manifest: IsometricEnvironmentManifest

func before_all() -> void:
	_manifest = IsometricEnvironmentManifest.reload_shared()

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
			"%s slot footprint maps exactly to logical cells" % String(obstacle_id))
		var contract := _manifest.get_object_asset_contract(obstacle_id)
		var asset_path := String(contract.get("asset_path", ""))
		assert_false(asset_path.is_empty(), "%s has a visible asset" % String(obstacle_id))
		assert_true(FileAccess.file_exists(asset_path), "%s asset exists" % String(obstacle_id))
		assert_true(asset_path.get_file().contains("%dx%d" % [slots.x, slots.y]), "%s asset filename records its footprint" % String(obstacle_id))
		assert_true(_manifest.blocks_movement(obstacle_id), "%s is a solid obstacle" % String(obstacle_id))

func test_authored_layouts() -> void:
	for biome_id in BIOME_IDS:
		var biome := load("res://game/modes/zombie/biomes/%s.tres" % String(biome_id)) as BiomeDefinition
		if biome == null or biome.environment_layout == null:
			continue
		var layout := biome.environment_layout
		for index in range(layout.obstacle_ids.size()):
			if index >= layout.obstacle_sizes.size():
				assert_true(false, "%s authored obstacle arrays align" % String(biome_id))
				break
			var obstacle_id := layout.obstacle_ids[index]
			if _manifest.get_category(obstacle_id) == &"border":
				continue
			assert_true(layout.obstacle_sizes[index].is_equal_approx(Vector2(_manifest.get_footprint_tiles(obstacle_id)) * layout.logical_tile_scale),
				"%s authored %s size matches its manifest footprint" % [String(biome_id), String(obstacle_id)])

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
	await wait_frames(1)
	var obstacle_id := &"ruined_house"
	var footprint := _manifest.get_footprint_tiles(obstacle_id)
	var world_size := Vector2(footprint) * 8.0
	var obstacle := system.create_obstacle_instance(obstacle_id, world_size, &"rectangle", 0.0,
		Color(0.38, 0.32, 0.22, 1.0), Color(0.78, 0.64, 0.28, 1.0))
	assert_not_null(obstacle, "runtime house object is created")
	if obstacle != null:
		add_child(obstacle)
		await wait_frames(1)
		assert_true(obstacle.get_visual_base_size().is_equal_approx(world_size), "visual base equals collision footprint")
		assert_true(obstacle.is_footprint_contract_aligned(), "runtime footprint matches manifest")
		assert_eq(obstacle.get_footprint_slots(), Vector2i(4, 4), "large house exposes its 4x4 footprint")
		assert_eq(obstacle.z_index, 0, "runtime object participates in Y-sort")
		assert_true(is_equal_approx(obstacle.get_sort_anchor_y(), _manifest.get_sort_offset(obstacle_id)), "sprite floor anchor uses the manifest sort offset")
		assert_true(bool(obstacle.call("has_asset_sprite")), "runtime house uses its isometric asset")
		system.register_streamed_obstacle(obstacle, obstacle_id)
		system.set_debug_footprints_visible(true)
		assert_true(system.are_debug_footprints_visible(), "F9 debug state is exposed")
		assert_true(bool(obstacle.call("has_debug_footprint")), "debug state reaches active obstacle footprints")
		obstacle.queue_free()
	system.queue_free()
	await wait_frames(1)

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
		assert_true(record_failures.is_empty(), "logical rectangles, collision sizes and assets share one footprint")
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
	generator.queue_free()
	await wait_frames(1)

# --- feature obstacle 3x3 (forest_tree) -------------------------------------

func test_3x3_feature_obstacle() -> void:
	for obstacle_id in FEATURE_IDS:
		assert_true(_manifest.has_object(obstacle_id), "%s exists" % String(obstacle_id))
		assert_eq(_manifest.get_footprint_slots(obstacle_id), EXPECTED_SLOTS, "%s occupies exactly 3x3 slots" % String(obstacle_id))
		assert_eq(_manifest.get_footprint_tiles(obstacle_id), EXPECTED_CELLS, "%s maps 3x3 slots to 12x12 logical cells" % String(obstacle_id))
		assert_true(_manifest.blocks_movement(obstacle_id), "%s blocks movement" % String(obstacle_id))
		assert_true(_manifest.blocks_projectiles(obstacle_id), "%s blocks projectiles" % String(obstacle_id))
		var contract := _manifest.get_object_asset_contract(obstacle_id)
		var asset_path := String(contract.get("asset_path", ""))
		assert_true(asset_path.ends_with("_3x3.png"), "%s uses a named 3x3 PNG" % String(obstacle_id))
		assert_true(FileAccess.file_exists(asset_path), "%s PNG exists" % String(obstacle_id))
		assert_eq(String(contract.get("source", "")), "openai_image_generation", "%s records generated-art provenance" % String(obstacle_id))

	var system := ObstacleSystem.new()
	add_child(system)
	await wait_frames(1)
	var world_size := Vector2(EXPECTED_CELLS) * LOGICAL_TILE_SCALE
	for obstacle_id in FEATURE_IDS:
		var obstacle := system.create_obstacle_instance(obstacle_id, world_size, &"rectangle", 0.0,
			Color(0.27, 0.34, 0.18, 1.0), Color(0.72, 0.62, 0.30, 1.0))
		assert_not_null(obstacle, "%s runtime object is created" % String(obstacle_id))
		if obstacle == null:
			continue
		add_child(obstacle)
		await wait_frames(1)
		assert_eq(obstacle.get_footprint_slots(), EXPECTED_SLOTS, "%s keeps 3x3 runtime slots" % String(obstacle_id))
		assert_true(obstacle.get_visual_base_size().is_equal_approx(world_size), "%s base matches its collision" % String(obstacle_id))
		assert_true(obstacle.is_footprint_contract_aligned(), "%s runtime footprint is aligned" % String(obstacle_id))
		assert_true(obstacle.contains_global_position(obstacle.global_position), "%s blocks its center" % String(obstacle_id))
		assert_true(obstacle.contains_global_position(obstacle.global_position + world_size * 0.49), "%s blocks the full 3x3 rectangle" % String(obstacle_id))
		assert_true(bool(obstacle.call("has_asset_sprite")), "%s loads its generated sprite" % String(obstacle_id))
		var collision := obstacle.get_node_or_null("CollisionShape2D") as CollisionShape2D
		var rectangle := collision.shape as RectangleShape2D if collision != null else null
		assert_true(rectangle != null and rectangle.size.is_equal_approx(world_size), "%s collision is a 3x3 rectangle" % String(obstacle_id))
		obstacle.queue_free()
		await wait_frames(1)
	system.queue_free()
	await wait_frames(1)

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
		assert_eq(rect.size, EXPECTED_CELLS, "%s placement owns exactly 12x12 logical cells" % String(obstacle_id))
		assert_true(layout.obstacle_sizes[index].is_equal_approx(Vector2(EXPECTED_CELLS) * LOGICAL_TILE_SCALE), "%s placement and collision share one size" % String(obstacle_id))
		for sample in [rect.position, rect.position + rect.size / 2, rect.end - Vector2i.ONE]:
			assert_eq(layout.get_terrain_class_at_cell(sample), BiomeEnvironmentLayout.TERRAIN_OBSTACLE, "%s occupied sample is classified as obstacle" % String(obstacle_id))
	var record_failures := layout.validate_obstacle_records(_manifest)
	assert_true(record_failures.is_empty(), "generated obstacle records remain aligned")
	for failure in record_failures:
		push_error("obstacle record: " + failure)
	generator.queue_free()
	await wait_frames(1)

# --- ostacolo scalabile (large_rock) ----------------------------------------

func test_scalable_obstacle() -> void:
	assert_true(_manifest.is_scalable(ROCK_ID), "large_rock is scalable")
	assert_false(_manifest.is_scalable(NON_SCALABLE_ID), "small_rock is not scalable")
	assert_eq(_manifest.get_footprint_tiles(ROCK_ID), Vector2i(15, 15), "large_rock base footprint is 15x15")
	var report := _manifest.validate()
	assert_true(bool(report.get("is_valid", false)), "manifest stays valid with a scalable non-slot footprint")
	for failure in report.get("failures", PackedStringArray()):
		push_error("manifest: " + String(failure))

	var system := ObstacleSystem.new()
	add_child(system)
	await wait_frames(1)
	var small := await _spawn_rock(system, SMALL_CELLS)
	var large := await _spawn_rock(system, LARGE_CELLS)
	assert_true(small != null and large != null, "both rock instances are created")
	if small != null and large != null:
		_expect_collision_size(small, Vector2(SMALL_CELLS) * LOGICAL_TILE_SCALE, "small rock")
		_expect_collision_size(large, Vector2(LARGE_CELLS) * LOGICAL_TILE_SCALE, "large rock")
		assert_true(bool(small.call("has_asset_sprite")), "small rock loads its sprite")
		assert_true(bool(large.call("has_asset_sprite")), "large rock loads its sprite")
		var small_scale := _sprite_scale(small)
		var large_scale := _sprite_scale(large)
		assert_true(small_scale > 0.0 and large_scale > 0.0, "both rock sprites are scaled")
		if small_scale > 0.0:
			var ratio := large_scale / small_scale
			assert_lt(absf(ratio - 2.0), 0.2, "large rock sprite scales ~2x the small one (ratio %0.2f)" % ratio)
		assert_true(bool(large.call("is_footprint_contract_aligned")), "scalable rock counts as footprint-aligned")
	system.queue_free()
	await wait_frames(1)

	var layout := BiomeEnvironmentLayout.new()
	layout.generation_seed = 4242
	var rect := Rect2i(Vector2i(40, 40), LARGE_CELLS)
	layout.obstacle_rects.append(rect)
	layout.obstacle_ids.append(ROCK_ID)
	layout.obstacle_positions.append(layout.rect_center_to_world(rect))
	layout.obstacle_sizes.append(layout.rect_size_to_world(rect))
	layout.obstacle_rotations.append(0.0)
	layout.obstacle_shape_ids.append(&"rectangle")
	var record_failures := layout.validate_obstacle_records(_manifest)
	assert_true(record_failures.is_empty(), "scalable rock record is valid at a non-base footprint")
	for failure in record_failures:
		push_error("record: " + String(failure))

# --- main.tscn: obstacle system + Y-sort (ultimo: boota la scena) -----------

func test_main_scene_obstacle_system() -> void:
	var scene := MainSceneFixture.new()
	assert_true(scene.boot(self), "main scene loads after obstacle rendering changes")
	await wait_frames(2)
	await wait_physics_frames(1)
	var system := scene.node(&"obstacle_system") as ObstacleSystem
	var environment_props := scene.main.get_node_or_null("World/EnvironmentProps") as Node2D
	assert_not_null(system, "main scene exposes the shared obstacle system")
	assert_true(environment_props != null and environment_props.y_sort_enabled, "main scene keeps environment obstacles in Y-sort")
	scene.teardown()
	await wait_frames(1)

# --- helper (porting dei test legacy) ---------------------------------------

func _spawn_rock(system: ObstacleSystem, cells: Vector2i) -> Node:
	var obstacle := system.create_obstacle_instance(ROCK_ID, Vector2(cells) * LOGICAL_TILE_SCALE, &"rectangle", 0.0,
		Color(0.30, 0.30, 0.30, 1.0), Color(0.70, 0.70, 0.70, 1.0))
	if obstacle == null:
		return null
	add_child(obstacle)
	await wait_frames(1)
	return obstacle

func _expect_collision_size(obstacle: Node, expected: Vector2, label: String) -> void:
	var collision := obstacle.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var rectangle := collision.shape as RectangleShape2D if collision != null else null
	assert_true(rectangle != null and rectangle.size.is_equal_approx(expected), "%s collision matches its instance footprint" % label)

func _sprite_scale(obstacle: Node) -> float:
	var sprite := obstacle.get_node_or_null("AssetSprite") as Sprite2D
	if sprite == null:
		return 0.0
	return sprite.scale.x
