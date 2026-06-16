extends Node
class_name RandomEncounterSystem

signal encounter_announced(message: String, encounter_id: StringName)
signal encounter_started(encounter_id: StringName, biome_id: StringName)
signal encounter_cleaned(encounter_id: StringName)

const ENCOUNTERS_BY_BIOME := {
	&"infected_plains": [&"ambush", &"survivor_cache"],
	&"toxic_wastes": [&"ambush", &"elite_pack", &"cursed_crate", &"hazard_burst", &"survivor_cache"],
	&"burning_fields": [&"ambush", &"elite_pack", &"cursed_crate", &"hazard_burst", &"survivor_cache"],
	&"frozen_outskirts": [&"ambush", &"elite_pack", &"hazard_burst", &"survivor_cache"],
	&"drowned_marsh": [&"ambush", &"elite_pack", &"cursed_crate", &"hazard_burst", &"survivor_cache"]
}

@export_range(0.0, 1.0, 0.01) var base_chance: float = 0.18
@export_range(120.0, 480.0, 5.0) var safe_distance: float = 180.0

var rng := RandomNumberGenerator.new()
var active_entities: Array[Node] = []
var last_encounter_id: StringName = &""

func _ready() -> void:
	add_to_group("random_encounter_system")

func configure_seed(run_seed: int, salt: int = 7717) -> void:
	rng.seed = hash("%d:%d:random_encounter" % [run_seed, salt])

func try_start_encounter(biome: BiomeDefinition, wave_index: int, critical_state: bool = false) -> Dictionary:
	if biome == null or critical_state or wave_index <= 1:
		return {}
	if rng.randf() > base_chance:
		return {}
	var types := ENCOUNTERS_BY_BIOME.get(biome.biome_id, [&"ambush"]) as Array
	var encounter_id := StringName(types[rng.randi_range(0, types.size() - 1)])
	return force_encounter(biome, encounter_id, wave_index)

func force_encounter(biome: BiomeDefinition, encounter_id: StringName, wave_index: int = 1) -> Dictionary:
	_cleanup_entities()
	last_encounter_id = encounter_id
	var spawn_position := _find_edge_position()
	var result := {"encounter_id": encounter_id, "biome_id": biome.biome_id if biome != null else &"", "entities": [], "reward": "standard", "position": spawn_position}
	match encounter_id:
		&"ambush":
			_spawn_enemy_pack(biome, spawn_position, 3, false, result)
			_announce("Ambush at the perimeter!", encounter_id)
		&"elite_pack":
			_spawn_enemy_pack(biome, spawn_position, 3, true, result)
			result["reward"] = "elite"
			_announce("Elite pack incoming!", encounter_id)
		&"cursed_crate":
			result["reward"] = "cursed_loot"
			_apply_status_to_near_players(_biome_status(biome), 2.5)
			_announce("Cursed crate: rich loot, bad aura.", encounter_id)
		&"hazard_burst":
			_spawn_hazard_burst(biome, spawn_position, result)
			_announce("Environmental hazard burst!", encounter_id)
		&"survivor_cache":
			result["reward"] = "healing_ammo_cache"
			_announce("Survivor cache found.", encounter_id)
		_:
			_spawn_enemy_pack(biome, spawn_position, 2, false, result)
	encounter_started.emit(encounter_id, biome.biome_id if biome != null else &"")
	return result

func cleanup_encounter() -> void:
	_cleanup_entities()
	encounter_cleaned.emit(last_encounter_id)
	last_encounter_id = &""

func _spawn_enemy_pack(biome: BiomeDefinition, center: Vector2, count: int, elite: bool, result: Dictionary) -> void:
	var enemy_system := get_tree().get_first_node_in_group("enemy_system") as EnemySystem
	if enemy_system == null:
		return
	for index in range(count):
		var enemy_id := biome.resolve_enemy_id(maxi(2, index + 2), index, count) if biome != null else &"survival_zombie"
		var enemy := enemy_system.spawn_enemy(enemy_id, center + Vector2(34.0 * float(index), 0.0).rotated(float(index)), null, {"health_multiplier": 1.25 if elite and index == 0 else 1.0, "damage_multiplier": 1.15 if elite and index == 0 else 1.0})
		if enemy != null:
			active_entities.append(enemy); (result["entities"] as Array).append(enemy)

func _spawn_hazard_burst(biome: BiomeDefinition, position: Vector2, result: Dictionary) -> void:
	var hazard_system := get_tree().get_first_node_in_group("hazard_system") as HazardSystem
	if hazard_system == null:
		return
	var zone := hazard_system.spawn_runtime_hazard(_biome_hazard(biome), position, {"lifetime": 4.0, "radius": 82.0})
	if zone != null:
		active_entities.append(zone); (result["entities"] as Array).append(zone)

func _apply_status_to_near_players(status_id: StringName, duration: float) -> void:
	var hazard_system := get_tree().get_first_node_in_group("hazard_system") as HazardSystem
	if hazard_system == null: return
	for player in get_tree().get_nodes_in_group("players"):
		hazard_system.apply_status(player, status_id, duration, 1.0, self)

func _find_edge_position() -> Vector2:
	for player in get_tree().get_nodes_in_group("players"):
		if player is Node2D:
			return (player as Node2D).global_position + Vector2.RIGHT.rotated(rng.randf() * TAU) * safe_distance
	return Vector2.RIGHT * safe_distance

func _biome_status(biome: BiomeDefinition) -> StringName:
	match biome.biome_id if biome != null else &"":
		&"burning_fields": return &"burn"
		&"frozen_outskirts": return &"freeze"
		&"drowned_marsh": return &"bleed"
		_: return &"poison"

func _biome_hazard(biome: BiomeDefinition) -> StringName:
	match biome.biome_id if biome != null else &"":
		&"burning_fields": return &"fire_patch"
		&"frozen_outskirts": return &"deep_snow_slow"
		&"drowned_marsh": return &"mud_pool"
		_: return &"toxic_cloud"

func _announce(message: String, encounter_id: StringName) -> void:
	encounter_announced.emit(message, encounter_id)

func _cleanup_entities() -> void:
	for entity in active_entities:
		if is_instance_valid(entity): entity.queue_free()
	active_entities.clear()
