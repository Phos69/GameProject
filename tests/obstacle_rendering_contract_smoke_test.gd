extends SceneTree

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
	&"infected_plains",
	&"toxic_wastes",
	&"burning_fields",
	&"frozen_outskirts",
	&"drowned_marsh"
]

var failures := PackedStringArray()

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var manifest := IsometricEnvironmentManifest.reload_shared()
	_expect(manifest.version >= 9, "obstacle manifest uses the slot-based contract")
	var validation := manifest.validate()
	_expect(bool(validation.get("is_valid", false)), "obstacle manifest validates")
	if not bool(validation.get("is_valid", false)):
		for failure in validation.get("failures", PackedStringArray()):
			push_error("manifest: " + String(failure))

	_validate_required_footprints(manifest)
	_validate_authored_layouts(manifest)
	await _validate_generated_layout(manifest)
	await _validate_runtime_object(manifest)
	_validate_void_identity(manifest)
	await _validate_main_scene()
	_finish()

func _validate_required_footprints(manifest: IsometricEnvironmentManifest) -> void:
	var slot_size := manifest.get_footprint_slot_size_cells()
	for slots_value in REQUIRED_FOOTPRINTS.keys():
		var slots := slots_value as Vector2i
		var obstacle_id := StringName(REQUIRED_FOOTPRINTS[slots])
		_expect(manifest.has_object(obstacle_id), "%s footprint object exists" % str(slots))
		_expect(
			manifest.get_footprint_slots(obstacle_id) == slots,
			"%s declares its exact slot footprint" % String(obstacle_id)
		)
		_expect(
			manifest.get_footprint_tiles(obstacle_id)
			== Vector2i(slots.x * slot_size.x, slots.y * slot_size.y),
			"%s slot footprint maps exactly to logical cells" % String(obstacle_id)
		)
		var contract := manifest.get_object_asset_contract(obstacle_id)
		var asset_path := String(contract.get("asset_path", ""))
		_expect(not asset_path.is_empty(), "%s has a visible asset" % String(obstacle_id))
		_expect(FileAccess.file_exists(asset_path), "%s asset exists" % String(obstacle_id))
		_expect(
			asset_path.get_file().contains("%dx%d" % [slots.x, slots.y]),
			"%s asset filename records its footprint" % String(obstacle_id)
		)
		_expect(manifest.blocks_movement(obstacle_id), "%s is a solid obstacle" % String(obstacle_id))

func _validate_generated_layout(manifest: IsometricEnvironmentManifest) -> void:
	var generator := BiomeTerrainGenerator.new()
	root.add_child(generator)
	var biome := load(
		"res://game/modes/zombie/biomes/infected_plains.tres"
	) as BiomeDefinition
	_expect(biome != null, "starter biome loads for generated footprint validation")
	if biome != null:
		var cell := BiomeCell.new()
		cell.configure(
			&"obstacle_contract_cell",
			biome.biome_id,
			Vector2i.ZERO,
			BiomeEnvironmentLayout.DEFAULT_ZONE_SIZE,
			90210
		)
		var layout := generator.generate_layout_for_cell(cell, biome)
		_expect(layout != null, "starter generated layout exists")
		if layout == null:
			generator.queue_free()
			return
		var record_failures := layout.validate_obstacle_records(manifest)
		_expect(
			record_failures.is_empty(),
			"logical rectangles, collision sizes and assets share one footprint"
		)
		for failure in record_failures:
			push_error("obstacle record: " + failure)
		for index in range(layout.obstacle_rects.size()):
			var record := layout.get_obstacle_record(index, manifest)
			_expect(not record.is_empty(), "generated obstacle exposes a render record")
			if record.is_empty():
				continue
			_expect(
				bool(record.get("blocks_movement", false))
				== manifest.blocks_movement(StringName(record.get("type", &""))),
				"render record keeps the collision contract"
			)
			_expect(
				not String(record.get("asset_path", "")).is_empty(),
				"generated obstacle cannot become invisible collision"
			)
	generator.queue_free()
	await process_frame

func _validate_authored_layouts(manifest: IsometricEnvironmentManifest) -> void:
	for biome_id in BIOME_IDS:
		var biome := load(
			"res://game/modes/zombie/biomes/%s.tres" % String(biome_id)
		) as BiomeDefinition
		if biome == null or biome.environment_layout == null:
			continue
		var layout := biome.environment_layout
		for index in range(layout.obstacle_ids.size()):
			if index >= layout.obstacle_sizes.size():
				_expect(false, "%s authored obstacle arrays align" % String(biome_id))
				break
			var obstacle_id := layout.obstacle_ids[index]
			if manifest.get_category(obstacle_id) == &"border":
				continue
			_expect(
				layout.obstacle_sizes[index].is_equal_approx(
					Vector2(manifest.get_footprint_tiles(obstacle_id)) * layout.logical_tile_scale
				),
				"%s authored %s size matches its manifest footprint"
				% [String(biome_id), String(obstacle_id)]
			)

func _validate_runtime_object(manifest: IsometricEnvironmentManifest) -> void:
	var system := ObstacleSystem.new()
	root.add_child(system)
	await process_frame
	var obstacle_id := &"ruined_house"
	var footprint := manifest.get_footprint_tiles(obstacle_id)
	var world_size := Vector2(footprint) * 8.0
	var obstacle := system.create_obstacle_instance(
		obstacle_id,
		world_size,
		&"rectangle",
		0.0,
		Color(0.38, 0.32, 0.22, 1.0),
		Color(0.78, 0.64, 0.28, 1.0)
	)
	_expect(obstacle != null, "runtime house object is created")
	if obstacle != null:
		root.add_child(obstacle)
		await process_frame
		_expect(obstacle.get_visual_base_size().is_equal_approx(world_size), "visual base equals collision footprint")
		_expect(obstacle.is_footprint_contract_aligned(), "runtime footprint matches manifest")
		_expect(obstacle.get_footprint_slots() == Vector2i(4, 4), "large house exposes its 4x4 footprint")
		_expect(obstacle.z_index == 0, "runtime object participates in Y-sort")
		_expect(is_equal_approx(obstacle.get_sort_anchor_y(), manifest.get_sort_offset(obstacle_id)), "sprite floor anchor uses the manifest sort offset")
		_expect(bool(obstacle.call("has_asset_sprite")), "runtime house uses its isometric asset")
		system.register_streamed_obstacle(obstacle, obstacle_id)
		system.set_debug_footprints_visible(true)
		_expect(system.are_debug_footprints_visible(), "F9 debug state is exposed")
		_expect(bool(obstacle.call("has_debug_footprint")), "debug state reaches active obstacle footprints")
		obstacle.queue_free()
	system.queue_free()
	await process_frame

func _validate_void_identity(manifest: IsometricEnvironmentManifest) -> void:
	var cliff := manifest.get_object_asset_contract(&"fall_zone")
	var house := manifest.get_object_asset_contract(&"ruined_house")
	_expect(manifest.get_category(&"fall_zone") == &"cliff", "fall zone keeps cliff identity")
	_expect(not manifest.blocks_movement(&"fall_zone"), "fall zone is not a solid obstacle")
	_expect(
		String(cliff.get("asset_path", "")) != String(house.get("asset_path", "")),
		"void/cliff art is distinct from solid obstacle art"
	)

func _validate_main_scene() -> void:
	var packed := load("res://game/main/main.tscn") as PackedScene
	_expect(packed != null, "main scene loads after obstacle rendering changes")
	if packed == null:
		return
	var main := packed.instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await physics_frame
	var system := get_first_node_in_group("obstacle_system") as ObstacleSystem
	var environment_props := main.get_node_or_null("World/EnvironmentProps") as Node2D
	_expect(system != null, "main scene exposes the shared obstacle system")
	_expect(
		environment_props != null and environment_props.y_sort_enabled,
		"main scene keeps environment obstacles in Y-sort"
	)
	main.queue_free()
	current_scene = null
	await process_frame

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("OBSTACLE_RENDERING_CONTRACT_SMOKE_TEST: PASS")
		quit(0)
		return
	print("OBSTACLE_RENDERING_CONTRACT_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
