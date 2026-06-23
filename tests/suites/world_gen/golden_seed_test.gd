extends GutTest
## World Generation A1 — Seed golden unico e determinismo.
## Migra: tests/golden_seed_default_smoke_test.gd
##
## Verifica che il seed golden sia la singola sorgente di verita condivisa tra
## gioco (default di WorldGenerationSeed), costante (GameConstants) e helper di
## test (GoldenWorld), e che produca un mondo deterministico.

const GoldenWorld = preload("res://tests/support/golden_world.gd")
const WorldGen = preload("res://tests/support/world_gen_helpers.gd")

func test_constant_alignment() -> void:
	var seed_service := WorldGenerationSeed.new()
	assert_eq(seed_service.default_seed, GameConstants.GOLDEN_WORLD_SEED,
		"WorldGenerationSeed default == GOLDEN_WORLD_SEED")
	assert_eq(GoldenWorld.SEED, GameConstants.GOLDEN_WORLD_SEED,
		"GoldenWorld helper SEED == GOLDEN_WORLD_SEED")
	assert_eq(seed_service.start_run({}), GameConstants.GOLDEN_WORLD_SEED,
		"seed service con contesto vuoto risolve sul seed golden")
	seed_service.free()

func test_default_run_uses_golden() -> void:
	var default_manager := WorldGen.start_biome_manager(self, {}, "GoldenDefault")
	assert_eq(default_manager.get_generation_seed(), GameConstants.GOLDEN_WORLD_SEED,
		"la run di default genera con il seed golden")
	assert_eq(int(default_manager.get_seed_record().get("global_seed", 0)),
		GameConstants.GOLDEN_WORLD_SEED,
		"il seed record della run di default usa il seed golden")
	var default_signature := default_manager.get_generation_signature()
	assert_ne(default_signature, "", "la run di default produce una firma del mondo")

	var explicit_manager := WorldGen.start_biome_manager(
		self, GoldenWorld.standard_context(), "GoldenExplicit")
	assert_eq(explicit_manager.get_generation_signature(), default_signature,
		"il contesto golden esplicito combacia col mondo default a contesto vuoto")

	WorldGen.free_biome_manager(default_manager)
	WorldGen.free_biome_manager(explicit_manager)

func test_compact_golden_is_deterministic() -> void:
	var first := WorldGen.start_biome_manager(
		self, GoldenWorld.compact_context(), "GoldenDetA")
	var second := WorldGen.start_biome_manager(
		self, GoldenWorld.compact_context(), "GoldenDetB")
	var signature := first.get_generation_signature()
	assert_eq(second.get_generation_signature(), signature,
		"stesso seed golden -> stessa firma del mondo")
	assert_ne(signature, "", "la firma golden compatta non e vuota")
	WorldGen.free_biome_manager(first)
	WorldGen.free_biome_manager(second)
