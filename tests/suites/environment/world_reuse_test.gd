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

# Stub di PlayerManager: conta le richieste di riposizionamento allo spawn, cosi il
# test verifica che il retry riporti i player allo spawn (non li lasci dove erano).
class FakePlayerManager extends Node:
	var reset_calls: int = 0
	func reset_players_to_spawn() -> void:
		reset_calls += 1

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
	await wait_physics_frames(1)

	var context := GoldenWorld.compact_context()
	controller.start_run(context)
	assert_true(controller.is_active, "world is active after first start")
	var cell := biome_manager.get_current_biome_cell()
	assert_not_null(cell, "first run resolves a current cell")
	if cell == null:
		harness.queue_free()
		await wait_physics_frames(1)
		return
	assert_not_null(cell.generated_layout, "first run cell owns a generated layout")

	# Park the world for a retry.
	controller.stop_run(true)
	assert_false(controller.is_active, "world deactivates on keep_world stop")
	assert_true(controller.can_reuse_world(context), "parked world is reusable for the same context")
	assert_eq(biome_manager.get_current_biome_cell(), cell, "parked world keeps its cell instances")
	assert_not_null(cell.generated_layout, "parked cell keeps its generated layout")

	# Stale loot dropped during the previous run must NOT survive a retry, even
	# though the world itself is reused. Simulate a ground drop left behind.
	var stale_pickup := Node.new()
	stale_pickup.name = "StaleDropPickup"
	stale_pickup.add_to_group("drop_pickups")
	harness.add_child(stale_pickup)

	# Players persist across a retry, so the reuse path must ask the player manager to
	# put them back at spawn (otherwise they'd stay where they died).
	var player_manager := FakePlayerManager.new()
	player_manager.name = "FakePlayerManager"
	player_manager.add_to_group("player_manager")
	harness.add_child(player_manager)

	# Retry with the same context reuses the world: same cell instance, no regen.
	controller.start_run(context)
	assert_true(controller.is_active, "world is active again after retry")
	assert_eq(
		biome_manager.get_current_biome_cell(), cell,
		"retry reuses the same world cells without regenerating"
	)
	# The loot layer was reset: the stale ground drop is cleared on reuse.
	await wait_physics_frames(1)
	assert_true(
		not is_instance_valid(stale_pickup) or stale_pickup.is_queued_for_deletion(),
		"retry clears stale ground loot while keeping the parked world"
	)
	# Players were repositioned to spawn on the retry.
	assert_eq(
		player_manager.reset_calls, 1,
		"retry repositions players to spawn"
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
	await wait_physics_frames(1)
