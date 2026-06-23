extends GutTest
## Suite di bootstrap della fondazione GUT (Milestone M0).
##
## Non copre comportamento di gioco "reale": serve a dimostrare che
##   1. GUT gira headless e raccoglie i test sotto tests/suites/**;
##   2. le classi di gioco (GameConstants, BiomeManager) si caricano sotto GUT;
##   3. la fixture golden condivisa produce un mondo deterministico, riusando una
##      sola istanza per tutta la suite (pattern dei tempi ottimizzati).
##
## Verra rimossa o assorbita quando A1 (World Generation) sara migrata in M1.

const GoldenWorldFixture = preload("res://tests/support/golden_world_fixture.gd")

var _world: GoldenWorldFixture

func before_all() -> void:
	_world = GoldenWorldFixture.new()
	_world.attach(self)
	await wait_physics_frames(1)
	_world.start_compact()
	await wait_physics_frames(1)

func after_all() -> void:
	_world.teardown()
	_world = null

func test_gut_runs_headless() -> void:
	assert_true(true, "GUT esegue la suite in headless")

func test_game_classes_load_under_gut() -> void:
	assert_ne(GameConstants.GOLDEN_WORLD_SEED, 0,
		"la costante GOLDEN_WORLD_SEED e accessibile sotto GUT")

func test_fixture_uses_shared_golden_seed() -> void:
	assert_eq(_world.generation_seed(), GameConstants.GOLDEN_WORLD_SEED,
		"la fixture condivisa usa il seed golden")
	assert_ne(_world.signature(), "",
		"la fixture condivisa produce una firma del mondo non vuota")

func test_golden_world_is_deterministic() -> void:
	var expected := _world.signature()
	var other := GoldenWorldFixture.new()
	other.attach(self, "GoldenWorldFixtureDeterminism")
	await wait_physics_frames(1)
	other.start_compact()
	await wait_physics_frames(1)
	assert_eq(other.signature(), expected,
		"stesso seed golden -> stessa firma del mondo")
	other.teardown()
