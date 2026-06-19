extends SceneTree

## Test unitario del logger condiviso GameLog (Fase 1 roadmap tecnica).
## Verifica il gating per livello (puro) e che le chiamate non sollevino errori
## quando silenziate.

var failures: PackedStringArray = []

func _initialize() -> void:
	var original_level := GameLog.min_level

	# Soglia INFO (default): debug filtrato, info/warn/error abilitati.
	GameLog.min_level = GameLog.Level.INFO
	_expect(not GameLog.is_enabled(GameLog.Level.DEBUG), "INFO filtra debug")
	_expect(GameLog.is_enabled(GameLog.Level.INFO), "INFO abilita info")
	_expect(GameLog.is_enabled(GameLog.Level.WARN), "INFO abilita warn")
	_expect(GameLog.is_enabled(GameLog.Level.ERROR), "INFO abilita error")

	# Soglia DEBUG: tutto abilitato.
	GameLog.min_level = GameLog.Level.DEBUG
	_expect(GameLog.is_enabled(GameLog.Level.DEBUG), "DEBUG abilita debug")

	# Soglia ERROR: solo gli errori passano.
	GameLog.min_level = GameLog.Level.ERROR
	_expect(not GameLog.is_enabled(GameLog.Level.WARN), "ERROR filtra warn")
	_expect(GameLog.is_enabled(GameLog.Level.ERROR), "ERROR abilita error")

	# Soglia SILENT: niente passa, nemmeno gli errori.
	GameLog.min_level = GameLog.Level.SILENT
	_expect(not GameLog.is_enabled(GameLog.Level.ERROR), "SILENT filtra tutto")

	# Con SILENT le chiamate pubbliche non emettono ne sollevano errori.
	GameLog.debug(&"Test", "debug soppresso")
	GameLog.info(&"Test", "info soppresso")
	GameLog.warn(&"Test", "warn soppresso")
	GameLog.error(&"Test", "error soppresso")

	GameLog.min_level = original_level
	_finish()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("FAIL: %s" % message)

func _finish() -> void:
	if failures.is_empty():
		print("game_log_smoke_test passed")
		quit(0)
	else:
		push_error("game_log_smoke_test FAILED (%d)" % failures.size())
		quit(1)
