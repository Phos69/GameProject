class_name ContextUtils
extends RefCounted

# I context dictionary di run/generazione arrivano sia con chiavi String sia
# StringName (builder GDScript vs dati serializzati): ogni lettura controlla
# entrambe le forme prima di ripiegare sul default. Unica fonte per gli helper
# prima duplicati in ZombieModeController, ObstacleLayoutGenerator e
# BiomeMapGenerator.

static func has_key(context: Dictionary, key: String) -> bool:
	return context.has(key) or context.has(StringName(key))

static func get_bool(
	context: Dictionary,
	key: String,
	default_value: bool
) -> bool:
	if context.has(key):
		return bool(context.get(key))
	var string_name_key := StringName(key)
	if context.has(string_name_key):
		return bool(context.get(string_name_key))
	return default_value

static func get_string(
	context: Dictionary,
	key: String,
	default_value: String
) -> String:
	if context.has(key):
		return str(context.get(key))
	var string_name_key := StringName(key)
	if context.has(string_name_key):
		return str(context.get(string_name_key))
	return default_value
