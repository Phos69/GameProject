extends RefCounted

# Helper condiviso dai test che vogliono il mondo "golden" deterministico.
# Non estende SceneTree: il runner (tools/run_tests.ps1 / .sh) non lo esegue come
# test. I test lo usano via preload, non via class_name, per restare robusti anche
# se la cache delle classi globali non e aggiornata.
#
# Uso tipico:
#   const GoldenWorld = preload("res://tests/support/golden_world.gd")
#   biome_manager.start_run(GoldenWorld.standard_context())

const SEED: int = GameConstants.GOLDEN_WORLD_SEED

# Contesto di generazione che riproduce ESATTAMENTE il mondo golden di default
# del gioco (contesto vuoto), ma con il seed reso leggibile nel test.
# Nota: BiomeMapGenerator usa preserve_biome_sequence=true quando il contesto NON
# specifica un seed, e lo mette a false quando un seed e esplicito (biomi
# mescolati dal seed). Per ottenere lo stesso mondo del default, l'helper fissa
# preserve_biome_sequence=true insieme al seed golden.
static func standard_context(extra: Dictionary = {}) -> Dictionary:
	var context: Dictionary = {
		"world_seed": SEED,
		"preserve_biome_sequence": true
	}
	for key in extra.keys():
		context[key] = extra[key]
	return context

# Variante compatta 1x1 murata: stessa generazione, molto piu veloce, per i test
# che devono solo verificare propagazione del seed o determinismo.
static func compact_context(extra: Dictionary = {}) -> Dictionary:
	var context: Dictionary = {
		"world_seed": SEED,
		"single_biome_arena": true,
		"biome_map_width": 1,
		"biome_map_height": 1,
		"arena_boundary_mode": "walled",
		"disable_world_runtime": true,
		"disable_region_streaming": true
	}
	for key in extra.keys():
		context[key] = extra[key]
	return context
