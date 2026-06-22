extends SceneTree

# Milestone A - Seed golden unico.
# Verifica che il seed golden sia la singola sorgente di verita condivisa tra
# gioco (default di WorldGenerationSeed) e test, e che produca un mondo
# deterministico quando il contesto non specifica un seed.

const GoldenWorld = preload("res://tests/support/golden_world.gd")

var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_constant_alignment()
	await _test_default_run_uses_golden()
	await _test_determinism()
	_finish()

# Il default del seed service, la costante condivisa e l'helper di test puntano
# tutti allo stesso valore golden.
func _test_constant_alignment() -> void:
	var seed_service := WorldGenerationSeed.new()
	_expect(
		seed_service.default_seed == GameConstants.GOLDEN_WORLD_SEED,
		"WorldGenerationSeed default == GOLDEN_WORLD_SEED"
	)
	_expect(
		GoldenWorld.SEED == GameConstants.GOLDEN_WORLD_SEED,
		"GoldenWorld helper SEED == GOLDEN_WORLD_SEED"
	)
	# Contesto vuoto -> il gioco ricade sul seed golden.
	var resolved := seed_service.start_run({})
	_expect(
		resolved == GameConstants.GOLDEN_WORLD_SEED,
		"seed service with empty context resolves to golden seed"
	)
	seed_service.free()

# Una run senza seed nel contesto deve generare il mondo golden: stesso seed e
# stessa firma del mondo costruito col seed golden esplicito. Si usano due
# BiomeManager separati per isolare l'effetto del contesto dallo stato di run.
func _test_default_run_uses_golden() -> void:
	var default_manager := BiomeManager.new()
	default_manager.name = "GoldenDefaultBiomeManager"
	root.add_child(default_manager)
	var explicit_manager := BiomeManager.new()
	explicit_manager.name = "GoldenExplicitBiomeManager"
	root.add_child(explicit_manager)
	await process_frame

	default_manager.start_run({})
	_expect(
		default_manager.get_generation_seed() == GameConstants.GOLDEN_WORLD_SEED,
		"default run generation seed == golden seed"
	)
	_expect(
		int(default_manager.get_seed_record().get("global_seed", 0))
		== GameConstants.GOLDEN_WORLD_SEED,
		"default run seed record global_seed == golden seed"
	)
	var default_signature := default_manager.get_generation_signature()
	_expect(default_signature != "", "default run produces a world signature")

	explicit_manager.start_run(GoldenWorld.standard_context())
	_expect(
		explicit_manager.get_generation_signature() == default_signature,
		"explicit golden context matches the empty-context default world"
	)

	default_manager.stop_run()
	explicit_manager.stop_run()
	default_manager.queue_free()
	explicit_manager.queue_free()
	await process_frame

# Due generazioni col seed golden devono produrre la stessa firma del mondo.
func _test_determinism() -> void:
	var first := BiomeManager.new()
	first.name = "GoldenDeterminismA"
	root.add_child(first)
	var second := BiomeManager.new()
	second.name = "GoldenDeterminismB"
	root.add_child(second)
	await process_frame

	first.start_run(GoldenWorld.compact_context())
	second.start_run(GoldenWorld.compact_context())
	_expect(
		first.get_generation_signature() == second.get_generation_signature(),
		"same golden seed yields identical world signature"
	)
	_expect(
		first.get_generation_signature() != "",
		"golden world signature is not empty"
	)
	first.stop_run()
	second.stop_run()
	first.queue_free()
	second.queue_free()
	await process_frame

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("GOLDEN_SEED_DEFAULT_SMOKE_TEST: PASS")
		quit(0)
		return
	print("GOLDEN_SEED_DEFAULT_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
