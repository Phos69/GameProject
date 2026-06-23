extends SceneTree

# Fast retry: stop_run(keep_world=true) parks the built world so a same-seed
# start_run() reuses it (no regeneration, no tile rebuild) and only the gameplay
# layer resets. A different context still rebuilds; a full stop clears the park.

const GoldenWorld = preload("res://tests/support/golden_world.gd")

var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var harness := Node.new()
	harness.name = "WorldReuseHarness"
	root.add_child(harness)
	var biome_manager := BiomeManager.new()
	biome_manager.name = "BiomeManager"
	harness.add_child(biome_manager)
	var controller := ZombieModeController.new()
	controller.name = "ZombieModeController"
	controller.biome_manager_path = NodePath("../BiomeManager")
	controller.enable_multi_region_render = false
	harness.add_child(controller)
	await process_frame

	var context := GoldenWorld.compact_context()
	controller.start_run(context)
	_expect(controller.is_active, "world is active after first start")
	var cell := biome_manager.get_current_biome_cell()
	_expect(cell != null, "first run resolves a current cell")
	if cell == null:
		_finish_and_free(harness)
		return
	_expect(cell.generated_layout != null, "first run cell owns a generated layout")

	# Park the world for a retry.
	controller.stop_run(true)
	_expect(not controller.is_active, "world deactivates on keep_world stop")
	_expect(controller.can_reuse_world(context), "parked world is reusable for the same context")
	_expect(biome_manager.get_current_biome_cell() == cell, "parked world keeps its cell instances")
	_expect(cell.generated_layout != null, "parked cell keeps its generated layout")

	# Retry with the same context reuses the world: same cell instance, no regen.
	controller.start_run(context)
	_expect(controller.is_active, "world is active again after retry")
	_expect(
		biome_manager.get_current_biome_cell() == cell,
		"retry reuses the same world cells without regenerating"
	)

	# A different seed is not reusable and rebuilds with new cells.
	controller.stop_run(true)
	var other_context := GoldenWorld.compact_context({"world_seed": GoldenWorld.SEED + 101})
	_expect(not controller.can_reuse_world(other_context), "a different seed is not reusable")
	controller.start_run(other_context)
	_expect(
		biome_manager.get_current_biome_cell() != cell,
		"a different context rebuilds the world with new cells"
	)

	# A full stop clears any parked world.
	controller.stop_run(false)
	_expect(not controller.can_reuse_world(other_context), "full stop clears the parked world")

	_finish_and_free(harness)

func _finish_and_free(harness: Node) -> void:
	harness.queue_free()
	await process_frame
	_finish()

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("WORLD_REUSE_RETRY_SMOKE_TEST: PASS")
		quit(0)
		return
	print("WORLD_REUSE_RETRY_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
