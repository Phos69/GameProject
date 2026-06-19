extends RefCounted
class_name GameLog

## Logger condiviso con livelli e categoria (Fase 1 roadmap tecnica).
##
## Punto unico per il logging del gameplay: invece di chiamare `print`,
## `push_warning` o `push_error` grezzi, i sistemi usano GameLog cosi il rumore
## di debug e filtrabile per livello (e silenziabile del tutto, es. negli
## smoke test headless). Funzioni statiche, nessun nodo o autoload.
##
## Convenzione: `category` identifica il sistema (es. &"WaveManager"); il
## messaggio e gia formattato. debug/info usano `print`, warn -> `push_warning`,
## error -> `push_error`.

enum Level { DEBUG, INFO, WARN, ERROR, SILENT }

## Soglia minima: i messaggi con livello inferiore vengono ignorati.
## Default INFO: i debug restano silenziosi finche non viene abbassata.
static var min_level: Level = Level.INFO

## True se un messaggio di questo livello verrebbe emesso con la soglia corrente.
## Esposta per permettere ai chiamanti di evitare formattazioni costose
## (`if GameLog.is_enabled(GameLog.Level.DEBUG): GameLog.debug(...)`).
static func is_enabled(level: Level) -> bool:
	return level >= min_level

static func debug(category: StringName, message: String) -> void:
	if is_enabled(Level.DEBUG):
		print(_format(category, message))

static func info(category: StringName, message: String) -> void:
	if is_enabled(Level.INFO):
		print(_format(category, message))

static func warn(category: StringName, message: String) -> void:
	if is_enabled(Level.WARN):
		push_warning(_format(category, message))

static func error(category: StringName, message: String) -> void:
	if is_enabled(Level.ERROR):
		push_error(_format(category, message))

static func _format(category: StringName, message: String) -> String:
	return "[%s] %s" % [category, message]
