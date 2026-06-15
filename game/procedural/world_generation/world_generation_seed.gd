extends Node
class_name WorldGenerationSeed

signal seed_changed(seed_value: int)

@export var default_seed: int = 20260615

var global_seed: int = 0

func _ready() -> void:
	add_to_group("world_generation_seed")

func start_run(context: Dictionary = {}) -> int:
	var requested_seed := _read_seed_from_context(context)
	if requested_seed == 0:
		requested_seed = default_seed
	set_seed(requested_seed)
	return global_seed

func set_seed(seed_value: int) -> void:
	global_seed = maxi(absi(seed_value), 1)
	seed_changed.emit(global_seed)

func get_global_seed() -> int:
	return global_seed

func get_stream_seed(stream_id: StringName, salt: int = 0) -> int:
	if global_seed == 0:
		set_seed(default_seed)
	var raw := hash("%d:%s:%d" % [global_seed, String(stream_id), salt])
	return maxi(absi(raw), 1)

func create_rng(stream_id: StringName, salt: int = 0) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = get_stream_seed(stream_id, salt)
	return rng

func get_seed_record() -> Dictionary:
	return {
		"global_seed": global_seed,
		"biome_map_rng": get_stream_seed(&"biome_map"),
		"biome_terrain_rng": get_stream_seed(&"biome_terrain"),
		"obstacle_rng": get_stream_seed(&"obstacle"),
		"border_rng": get_stream_seed(&"border"),
		"loot_rng": get_stream_seed(&"loot"),
		"enemy_spawn_rng": get_stream_seed(&"enemy_spawn")
	}

func _read_seed_from_context(context: Dictionary) -> int:
	for key in [&"world_seed", &"global_seed", &"seed"]:
		if context.has(key):
			return int(context[key])
		var string_key := String(key)
		if context.has(string_key):
			return int(context[string_key])
	return 0
