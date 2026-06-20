extends SceneTree

const FEATURE_IDS: Array[StringName] = [&"forest_tree", &"large_rock"]
const EXPECTED_SLOTS := Vector2i(3, 3)
const EXPECTED_CELLS := Vector2i(12, 12)
const LOGICAL_TILE_SCALE := 8.0

var failures := PackedStringArray()

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var manifest := IsometricEnvironmentManifest.reload_shared()
	_validate_manifest(manifest)
	await _validate_runtime(manifest)
	await _validate_generated_placement(manifest)
	_finish()

func _validate_manifest(manifest: IsometricEnvironmentManifest) -> void:
	for obstacle_id in FEATURE_IDS:
		_expect(manifest.has_object(obstacle_id), "%s exists" % String(obstacle_id))
		_expect(
			manifest.get_footprint_slots(obstacle_id) == EXPECTED_SLOTS,
			"%s occupies exactly 3x3 slots" % String(obstacle_id)
		)
		_expect(
			manifest.get_footprint_tiles(obstacle_id) == EXPECTED_CELLS,
			"%s maps 3x3 slots to 12x12 logical cells" % String(obstacle_id)
		)
		_expect(manifest.blocks_movement(obstacle_id), "%s blocks movement" % String(obstacle_id))
		_expect(manifest.blocks_projectiles(obstacle_id), "%s blocks projectiles" % String(obstacle_id))
		var contract := manifest.get_object_asset_contract(obstacle_id)
		var asset_path := String(contract.get("asset_path", ""))
		_expect(asset_path.ends_with("_3x3.png"), "%s uses a named 3x3 PNG" % String(obstacle_id))
		_expect(FileAccess.file_exists(asset_path), "%s PNG exists" % String(obstacle_id))
		_expect(
			String(contract.get("source", "")) == "openai_image_generation",
			"%s records generated-art provenance" % String(obstacle_id)
		)

func _validate_runtime(manifest: IsometricEnvironmentManifest) -> void:
	var system := ObstacleSystem.new()
	root.add_child(system)
	await process_frame
	var world_size := Vector2(EXPECTED_CELLS) * LOGICAL_TILE_SCALE
	for obstacle_id in FEATURE_IDS:
		var obstacle := system.create_obstacle_instance(
			obstacle_id,
			world_size,
			&"rectangle",
			0.0,
			Color(0.27, 0.34, 0.18, 1.0),
			Color(0.72, 0.62, 0.30, 1.0)
		)
		_expect(obstacle != null, "%s runtime object is created" % String(obstacle_id))
		if obstacle == null:
			continue
		root.add_child(obstacle)
		await process_frame
		_expect(obstacle.get_footprint_slots() == EXPECTED_SLOTS, "%s keeps 3x3 runtime slots" % String(obstacle_id))
		_expect(obstacle.get_visual_base_size().is_equal_approx(world_size), "%s base matches its collision" % String(obstacle_id))
		_expect(obstacle.is_footprint_contract_aligned(), "%s runtime footprint is aligned" % String(obstacle_id))
		_expect(obstacle.contains_global_position(obstacle.global_position), "%s blocks its center" % String(obstacle_id))
		_expect(
			obstacle.contains_global_position(obstacle.global_position + world_size * 0.49),
			"%s blocks the full 3x3 rectangle" % String(obstacle_id)
		)
		_expect(bool(obstacle.call("has_asset_sprite")), "%s loads its generated sprite" % String(obstacle_id))
		var collision := obstacle.get_node_or_null("CollisionShape2D") as CollisionShape2D
		var rectangle := collision.shape as RectangleShape2D if collision != null else null
		_expect(rectangle != null and rectangle.size.is_equal_approx(world_size), "%s collision is a 3x3 rectangle" % String(obstacle_id))
		obstacle.queue_free()
		await process_frame
	system.queue_free()
	await process_frame

func _validate_generated_placement(manifest: IsometricEnvironmentManifest) -> void:
	var generator := BiomeTerrainGenerator.new()
	root.add_child(generator)
	var biome := load("res://game/modes/zombie/biomes/infected_plains.tres") as BiomeDefinition
	_expect(biome != null, "infected plains loads")
	if biome == null:
		generator.queue_free()
		return
	var cell := BiomeCell.new()
	cell.configure(
		&"feature_obstacle_cell",
		biome.biome_id,
		Vector2i.ZERO,
		BiomeEnvironmentLayout.DEFAULT_ZONE_SIZE,
		314159
	)
	var layout := generator.generate_layout_for_cell(cell, biome)
	_expect(layout != null, "generated layout exists")
	if layout == null:
		generator.queue_free()
		return
	for obstacle_id in FEATURE_IDS:
		var index := layout.obstacle_ids.find(obstacle_id)
		_expect(index >= 0, "%s is positioned in the starter biome" % String(obstacle_id))
		if index < 0:
			continue
		var rect := layout.obstacle_rects[index]
		_expect(rect.size == EXPECTED_CELLS, "%s placement owns exactly 12x12 logical cells" % String(obstacle_id))
		_expect(
			layout.obstacle_sizes[index].is_equal_approx(Vector2(EXPECTED_CELLS) * LOGICAL_TILE_SCALE),
			"%s placement and collision share one size" % String(obstacle_id)
		)
		for sample in [rect.position, rect.position + rect.size / 2, rect.end - Vector2i.ONE]:
			_expect(
				layout.get_terrain_class_at_cell(sample) == BiomeEnvironmentLayout.TERRAIN_OBSTACLE,
				"%s occupied sample is classified as obstacle" % String(obstacle_id)
			)
	var record_failures := layout.validate_obstacle_records(manifest)
	_expect(record_failures.is_empty(), "generated obstacle records remain aligned")
	for failure in record_failures:
		push_error("obstacle record: " + failure)
	generator.queue_free()
	await process_frame

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("OBSTACLE_3X3_SMOKE_TEST: PASS")
		quit(0)
		return
	print("OBSTACLE_3X3_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
