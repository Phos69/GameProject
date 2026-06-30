extends RefCounted
## Fixture condivisa per le suite GUT che lavorano sul mondo "golden" deterministico.
##
## Pensata per `before_all()`: una sola istanza di BiomeManager viene costruita per
## l'intera suite e riusata da tutti i `test_*`, evitando il boot ripetuto del mondo.
## Costruisce sopra l'helper esistente `GoldenWorld` per restare allineata al seed
## golden condiviso tra gioco e test.
##
## Uso tipico:
##   const GoldenWorldFixture = preload("res://tests/support/golden_world_fixture.gd")
##   var _world: GoldenWorldFixture
##   func before_all():
##       _world = GoldenWorldFixture.new()
##       _world.attach(self)
##       await wait_physics_frames(1)
##       _world.start_compact()
##   func after_all():
##       _world.teardown()

const GoldenWorld = preload("res://tests/support/golden_world.gd")

var biome_manager: BiomeManager
var _host: Node

## Crea il BiomeManager e lo aggancia all'albero tramite `host` (di solito il
## nodo GutTest stesso). Dopo questa chiamata attendere un frame prima di start_*.
func attach(host: Node, manager_name: String = "GoldenWorldFixtureBiomeManager") -> void:
	_host = host
	biome_manager = BiomeManager.new()
	biome_manager.name = manager_name
	host.add_child(biome_manager)

## Avvia la run sul mondo golden completo (contesto vuoto -> seed golden).
func start_standard(extra: Dictionary = {}) -> void:
	biome_manager.start_run(GoldenWorld.standard_context(extra))

## Avvia la run sulla variante compatta 1x1 murata: stessa generazione, molto
## piu veloce, adatta ai test che verificano seed/determinismo.
func start_compact(extra: Dictionary = {}) -> void:
	biome_manager.start_run(GoldenWorld.compact_context(extra))

func signature() -> String:
	return biome_manager.get_generation_signature()

func generation_seed() -> int:
	return biome_manager.get_generation_seed()

func teardown() -> void:
	if biome_manager != null and is_instance_valid(biome_manager):
		biome_manager.stop_run()
		var parent := biome_manager.get_parent()
		if parent != null:
			parent.remove_child(biome_manager)
		biome_manager.free()
	biome_manager = null
	_host = null
