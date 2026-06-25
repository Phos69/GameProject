extends RefCounted
class_name WorldDataCache

## Cache LRU di processo dei dati-mondo generati, condivisa da gioco e suite GUT.
##
## Lo stato e statico (come IsometricEnvironmentManifest.get_shared): vive per
## l'intero processo, quindi la PRIMA costruzione di un dato mondo serve anche
## ogni run successiva e ogni suite di test successiva nello stesso processo.
##
## Si cachea il DATO del mondo (il Dictionary puro prodotto da
## BiomeWorldGenerator: celle + grafo + layout), non la scena bakeata: il dato e
## deterministico per contesto di generazione e gia generabile su worker thread.
## Lo snapshot in cache e immutabile e disaccoppiato dalle run vive tramite clone
## (sia in scrittura sia in lettura), cosi teardown/rebake di una run non lo
## intaccano mai.
##
## Chiave = firma CANONICA di sola generazione: solo i parametri che cambiano il
## mondo generato. Le chiavi di gameplay (personaggio, run_seed, async...) e di
## render/runtime (streaming, world_runtime, arena) sono escluse, cosi lo stesso
## seed riusa lo stesso mondo a prescindere da esse. Questo e il motivo per cui il
## "riuso golden" prima falliva: la firma includeva anche le chiavi di gameplay.
##
## Cap a numero di mondi (LRU): l'entry meno usata di recente viene sfrattata
## quando si supera il limite. Con la megamappa 3x3 (~13 MB/mondo) il default di 8
## mondi resta sotto i ~110 MB; regolabile con set_max_worlds().
##
## Nota test: per le suite che verificano la GENERAZIONE in se (determinismo,
## contenuto void-first) disabilitare la cache con set_enabled(false) cosi il
## secondo build non viene servito come clone del primo.

const DEFAULT_MAX_WORLDS: int = 8

## Chiavi che non cambiano MAI il mondo costruito: escluse sia dalla firma dati
## sia dalla firma scena (park del controller).
const GAMEPLAY_KEYS: Array[StringName] = [
	&"selected_character_id",
	&"selected_character_ids_by_slot",
	&"run_seed",
	&"async_world_build",
]

## Chiavi che cambiano la scena bakeata/streamata ma NON i dati generati: la cache
## dei dati le ignora (stesso world_data), il park del controller le tiene.
const NON_DATA_KEYS: Array[StringName] = [
	&"disable_world_runtime",
	&"disable_region_streaming",
	&"arena_id",
]

static var _enabled: bool = true
static var _max_worlds: int = DEFAULT_MAX_WORLDS
# Ordinato per ricenza: chiave LRU in testa (keys()[0]), MRU in coda.
static var _entries: Dictionary = {}
static var _hits: int = 0
static var _misses: int = 0

# --- Firme -----------------------------------------------------------------

## Identita dei DATI generati: esclude gameplay e render/runtime.
static func canonical_key(context: Dictionary) -> String:
	return _signature(context, GAMEPLAY_KEYS + NON_DATA_KEYS)

## Identita della SCENA bakeata (per il park del ZombieModeController): esclude
## solo il gameplay, tiene i toggle di render/runtime che cambiano cosa viene
## bakeato/streamato.
static func build_signature(context: Dictionary) -> String:
	return _signature(context, GAMEPLAY_KEYS)

static func _signature(context: Dictionary, excluded: Array[StringName]) -> String:
	var excluded_set := {}
	for key in excluded:
		excluded_set[String(key)] = true
	# Normalizza i nomi a String (il context usa sia String sia StringName) e
	# deduplica, cosi varianti della stessa chiave non sdoppiano la firma.
	var normalized := {}
	for key in context.keys():
		var name := String(key)
		if excluded_set.has(name):
			continue
		normalized[name] = str(context[key])
	var names := normalized.keys()
	names.sort()
	var parts := PackedStringArray()
	for name in names:
		parts.append("%s=%s" % [name, normalized[name]])
	return "|".join(parts)

# --- Lettura / scrittura ---------------------------------------------------

## Restituisce un CLONE indipendente del mondo in cache per `context`, oppure un
## Dictionary vuoto se la cache e disabilitata o non c'e hit. Un hit promuove
## l'entry a MRU.
static func fetch(context: Dictionary) -> Dictionary:
	if not _enabled:
		return {}
	var key := canonical_key(context)
	if not _entries.has(key):
		_misses += 1
		return {}
	_hits += 1
	var master := _entries[key] as Dictionary
	_entries.erase(key)
	_entries[key] = master
	return clone_world_data(master)

## Memorizza uno snapshot (clone immutabile) di `world_data` per `context`.
## No-op se disabilitata o se i dati sono vuoti.
static func store(context: Dictionary, world_data: Dictionary) -> void:
	if not _enabled or world_data.is_empty():
		return
	if (world_data.get("cells", []) as Array).is_empty():
		return
	var key := canonical_key(context)
	_entries.erase(key)
	_entries[key] = clone_world_data(world_data)
	_evict_to_limit()

static func has(context: Dictionary) -> bool:
	return _enabled and _entries.has(canonical_key(context))

# --- Clone -----------------------------------------------------------------

## Deep clone del world_data: clona celle (con i link ai vicini ricollegati tra i
## cloni), passaggi e layout; ricostruisce il grafo in modo deterministico dalle
## celle clonate (configure_from_biome_cells) invece di clonarlo a mano.
static func clone_world_data(world_data: Dictionary) -> Dictionary:
	var source_cells := world_data.get("cells", []) as Array
	var cloned_cells: Array[BiomeCell] = []
	var clones_by_id := {}
	var pairs: Array = []
	for cell in source_cells:
		var typed := cell as BiomeCell
		if typed == null:
			continue
		var cloned := typed.clone()
		clones_by_id[cloned.id] = cloned
		cloned_cells.append(cloned)
		pairs.append([typed, cloned])
	for pair in pairs:
		(pair[1] as BiomeCell).relink_neighbors(pair[0] as BiomeCell, clones_by_id)
	var seed_value := int(world_data.get("seed", 0))
	var graph := WorldGraph.new()
	graph.configure_from_biome_cells(cloned_cells, seed_value)
	var start_cell: BiomeCell = null
	var source_start := world_data.get("start_cell", null) as BiomeCell
	if source_start != null:
		start_cell = clones_by_id.get(source_start.id, null) as BiomeCell
	return {
		"seed": seed_value,
		"cells": cloned_cells,
		"world_graph": graph,
		"start_cell": start_cell,
		"signature": String(world_data.get("signature", "")),
		"seed_record": (world_data.get("seed_record", {}) as Dictionary).duplicate(true)
	}

# --- Gestione / introspezione ----------------------------------------------

static func _evict_to_limit() -> void:
	while _entries.size() > _max_worlds:
		_entries.erase(_entries.keys()[0])

static func set_max_worlds(value: int) -> void:
	_max_worlds = maxi(value, 1)
	_evict_to_limit()

static func get_max_worlds() -> int:
	return _max_worlds

static func set_enabled(value: bool) -> void:
	_enabled = value

static func is_enabled() -> bool:
	return _enabled

## Svuota la cache e azzera le statistiche (isolamento tra suite di test).
static func clear() -> void:
	_entries.clear()
	_hits = 0
	_misses = 0

static func size() -> int:
	return _entries.size()

static func stats() -> Dictionary:
	return {
		"enabled": _enabled,
		"size": _entries.size(),
		"max_worlds": _max_worlds,
		"hits": _hits,
		"misses": _misses
	}
