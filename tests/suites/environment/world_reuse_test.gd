extends GutTest
## Environment — Riuso rapido del mondo costruito (retry stesso seed).
##
## Migra:
##   tests/world_reuse_retry_smoke_test.gd  (ZombieModeController + BiomeManager sintetici)
##
## stop_run(keep_world=true) parcheggia il mondo costruito: un start_run() con lo
## stesso seed lo riusa (niente rigenerazione, niente rebuild dei tile) resettando
## solo il layer di gameplay. Un contesto diverso ricostruisce; uno stop completo
## svuota il parcheggio.

const GoldenWorld = preload("res://tests/support/golden_world.gd")

func test_same_seed_retry_reuses_world() -> void:
	var harness := Node.new()
	harness.name = "WorldReuseHarness"
	add_child(harness)
	var biome_manager := BiomeManager.new()
	biome_manager.name = "BiomeManager"
	harness.add_child(biome_manager)
	var controller := ZombieModeController.new()
	controller.name = "ZombieModeController"
	controller.biome_manager_path = NodePath("../BiomeManager")
	controller.enable_multi_region_render = false
	harness.add_child(controller)
	await wait_frames(1)

	var context := GoldenWorld.compact_context()
	controller.start_run(context)
	assert_true(controller.is_active, "world is active after first start")
	var cell := biome_manager.get_current_biome_cell()
	assert_not_null(cell, "first run resolves a current cell")
	if cell == null:
		harness.queue_free()
		await wait_frames(1)
		return
	assert_not_null(cell.generated_layout, "first run cell owns a generated layout")

	# Park the world for a retry.
	controller.stop_run(true)
	assert_false(controller.is_active, "world deactivates on keep_world stop")
	assert_true(controller.can_reuse_world(context), "parked world is reusable for the same context")
	assert_eq(biome_manager.get_current_biome_cell(), cell, "parked world keeps its cell instances")
	assert_not_null(cell.generated_layout, "parked cell keeps its generated layout")

	# Retry with the same context reuses the world: same cell instance, no regen.
	controller.start_run(context)
	assert_true(controller.is_active, "world is active again after retry")
	assert_eq(
		biome_manager.get_current_biome_cell(), cell,
		"retry reuses the same world cells without regenerating"
	)

	# A different seed is not reusable and rebuilds with new cells.
	controller.stop_run(true)
	var other_context := GoldenWorld.compact_context({"world_seed": GoldenWorld.SEED + 101})
	assert_false(controller.can_reuse_world(other_context), "a different seed is not reusable")
	controller.start_run(other_context)
	assert_ne(
		biome_manager.get_current_biome_cell(), cell,
		"a different context rebuilds the world with new cells"
	)

	# A full stop clears any parked world.
	controller.stop_run(false)
	assert_false(controller.can_reuse_world(other_context), "full stop clears the parked world")

	harness.queue_free()
	await wait_frames(1)
