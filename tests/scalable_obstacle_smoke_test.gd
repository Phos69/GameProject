extends SceneTree

# M0 — Scalable obstacles. Rocks are placed at a per-instance square footprint and
# their art + collision follow the instance size, unlike fixed-footprint obstacles.

const ROCK_ID := &"large_rock"
const NON_SCALABLE_ID := &"small_rock"
const LOGICAL_TILE_SCALE := 8.0
const SMALL_CELLS := Vector2i(15, 15)
const LARGE_CELLS := Vector2i(30, 30)

var failures := PackedStringArray()

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var manifest := IsometricEnvironmentManifest.reload_shared()
	_validate_manifest(manifest)
	await _validate_runtime(manifest)
	await _validate_generated_records(manifest)
	_finish()

func _validate_manifest(manifest: IsometricEnvironmentManifest) -> void:
	_expect(manifest.is_scalable(ROCK_ID), "large_rock is scalable")
	_expect(not manifest.is_scalable(NON_SCALABLE_ID), "small_rock is not scalable")
	_expect(
		manifest.get_footprint_tiles(ROCK_ID) == Vector2i(15, 15),
		"large_rock base footprint is 15x15"
	)
	var report := manifest.validate()
	_expect(
		bool(report.get("is_valid", false)),
		"manifest stays valid with a scalable non-slot footprint"
	)
	for failure in report.get("failures", PackedStringArray()):
		push_error("manifest: " + String(failure))

func _validate_runtime(manifest: IsometricEnvironmentManifest) -> void:
	var system := ObstacleSystem.new()
	root.add_child(system)
	await process_frame
	var small := await _spawn(system, ROCK_ID, SMALL_CELLS)
	var large := await _spawn(system, ROCK_ID, LARGE_CELLS)
	_expect(small != null and large != null, "both rock instances are created")
	if small != null and large != null:
		_expect_collision_size(small, Vector2(SMALL_CELLS) * LOGICAL_TILE_SCALE, "small rock")
		_expect_collision_size(large, Vector2(LARGE_CELLS) * LOGICAL_TILE_SCALE, "large rock")
		_expect(bool(small.call("has_asset_sprite")), "small rock loads its sprite")
		_expect(bool(large.call("has_asset_sprite")), "large rock loads its sprite")
		var small_scale := _sprite_scale(small)
		var large_scale := _sprite_scale(large)
		_expect(small_scale > 0.0 and large_scale > 0.0, "both rock sprites are scaled")
		# The 30x30 rock owns twice the footprint of the 15x15 rock, so its art is
		# scaled ~2x: the asset adapts to the instance size.
		if small_scale > 0.0:
			var ratio := large_scale / small_scale
			_expect(
				absf(ratio - 2.0) < 0.2,
				"large rock sprite scales ~2x the small one (ratio %0.2f)" % ratio
			)
		_expect(
			bool(large.call("is_footprint_contract_aligned")),
			"scalable rock counts as footprint-aligned"
		)
	system.queue_free()
	await process_frame

func _validate_generated_records(manifest: IsometricEnvironmentManifest) -> void:
	# A scalable rock placed at an arbitrary square footprint must not break the
	# layout obstacle-record contract.
	var layout := BiomeEnvironmentLayout.new()
	layout.generation_seed = 4242
	var rect := Rect2i(Vector2i(40, 40), LARGE_CELLS)
	layout.obstacle_rects.append(rect)
	layout.obstacle_ids.append(ROCK_ID)
	layout.obstacle_positions.append(layout.rect_center_to_world(rect))
	layout.obstacle_sizes.append(layout.rect_size_to_world(rect))
	layout.obstacle_rotations.append(0.0)
	layout.obstacle_shape_ids.append(&"rectangle")
	var record_failures := layout.validate_obstacle_records(manifest)
	_expect(
		record_failures.is_empty(),
		"scalable rock record is valid at a non-base footprint"
	)
	for failure in record_failures:
		push_error("record: " + String(failure))

func _spawn(
	system: ObstacleSystem,
	obstacle_id: StringName,
	cells: Vector2i
) -> Node:
	var obstacle := system.create_obstacle_instance(
		obstacle_id,
		Vector2(cells) * LOGICAL_TILE_SCALE,
		&"rectangle",
		0.0,
		Color(0.30, 0.30, 0.30, 1.0),
		Color(0.70, 0.70, 0.70, 1.0)
	)
	if obstacle == null:
		return null
	root.add_child(obstacle)
	await process_frame
	return obstacle

func _expect_collision_size(obstacle: Node, expected: Vector2, label: String) -> void:
	var collision := obstacle.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var rectangle := collision.shape as RectangleShape2D if collision != null else null
	_expect(
		rectangle != null and rectangle.size.is_equal_approx(expected),
		"%s collision matches its instance footprint" % label
	)

func _sprite_scale(obstacle: Node) -> float:
	var sprite := obstacle.get_node_or_null("AssetSprite") as Sprite2D
	if sprite == null:
		return 0.0
	return sprite.scale.x

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("SCALABLE_OBSTACLE_SMOKE_TEST: PASS")
		quit(0)
		return
	print("SCALABLE_OBSTACLE_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
