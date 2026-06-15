extends Resource
class_name BiomeDefinition

@export var biome_id: StringName = &"infected_plains"
@export var display_name: String = "Pianura Infetta"
@export_multiline var description: String = ""
@export var is_starting_biome: bool = false
@export_range(0.1, 5.0, 0.05) var difficulty_rating: float = 1.0
@export var palette: BiomePalette

@export var terrain_tags: Array[StringName] = []
@export var obstacle_ids: Array[StringName] = []
@export var crate_ids: Array[StringName] = []
@export var hazard_ids: Array[StringName] = []
@export var resource_tags: Array[StringName] = []

@export var allowed_zombie_types: Array[StringName] = [&"survival_zombie"]
@export var weighted_zombie_ids: Array[StringName] = [&"survival_zombie"]
@export var weighted_zombie_values: Array[float] = [1.0]
@export var base_enemy_id: StringName = &"survival_zombie"
@export var runner_enemy_id: StringName = &"survival_runner"
@export var tank_enemy_id: StringName = &"survival_tank"
@export var shooter_enemy_id: StringName = &"survival_shooter"

@export_range(1, 20) var runner_start_wave: int = 2
@export_range(1, 20) var tank_start_wave: int = 3
@export_range(1, 20) var shooter_start_wave: int = 4
@export_range(1, 20) var special_start_wave: int = 2

@export_range(0.2, 3.0, 0.05) var wave_size_multiplier: float = 1.0
@export_range(0.2, 3.0, 0.05) var spawn_rate_multiplier: float = 1.0
@export_range(0.2, 5.0, 0.05) var health_multiplier: float = 1.0
@export_range(0.2, 5.0, 0.05) var move_speed_multiplier: float = 1.0
@export_range(0.2, 5.0, 0.05) var damage_multiplier: float = 1.0
@export_range(0.0, 3.0, 0.05) var resource_drop_modifier: float = 1.0
@export_range(0.0, 1.0, 0.01) var elite_spawn_chance: float = 0.0
@export_range(0.0, 1.0, 0.01) var boss_spawn_chance: float = 0.0
@export_range(0.0, 1.0, 0.01) var environmental_hazard_chance: float = 0.0

func resolve_enemy_id(
	wave_index: int,
	spawn_index: int,
	regular_total: int
) -> StringName:
	if wave_index <= 1:
		return base_enemy_id
	if _uses_legacy_survival_roster():
		return _resolve_legacy_survival_enemy(wave_index, spawn_index, regular_total)
	return _resolve_weighted_enemy(wave_index, spawn_index)

func get_spawn_weight(enemy_id: StringName) -> float:
	var index := weighted_zombie_ids.find(enemy_id)
	if index < 0 or index >= weighted_zombie_values.size():
		return 0.0
	return maxf(weighted_zombie_values[index], 0.0)

func has_enemy_type(enemy_id: StringName) -> bool:
	return allowed_zombie_types.has(enemy_id)

func get_safe_allowed_zombie_types(wave_index: int) -> Array[StringName]:
	var result: Array[StringName] = []
	for enemy_id in allowed_zombie_types:
		if enemy_id == base_enemy_id or wave_index >= special_start_wave:
			result.append(enemy_id)
	if result.is_empty():
		result.append(base_enemy_id)
	return result

func _uses_legacy_survival_roster() -> bool:
	return is_starting_biome or biome_id == &"infected_plains"

func _resolve_legacy_survival_enemy(
	wave_index: int,
	spawn_index: int,
	regular_total: int
) -> StringName:
	if (
		wave_index >= tank_start_wave
		and regular_total >= 5
		and spawn_index == regular_total - 1
		and has_enemy_type(tank_enemy_id)
	):
		return tank_enemy_id
	if (
		wave_index >= shooter_start_wave
		and (spawn_index + 1) % 4 == 0
		and has_enemy_type(shooter_enemy_id)
	):
		return shooter_enemy_id
	if (
		wave_index >= runner_start_wave
		and (spawn_index + 1) % 3 == 0
		and has_enemy_type(runner_enemy_id)
	):
		return runner_enemy_id
	return base_enemy_id

func _resolve_weighted_enemy(wave_index: int, spawn_index: int) -> StringName:
	var candidates := get_safe_allowed_zombie_types(wave_index)
	var total_weight := 0.0
	for enemy_id in candidates:
		total_weight += get_spawn_weight(enemy_id)
	if total_weight <= 0.0:
		return base_enemy_id

	var roll := _deterministic_unit(wave_index, spawn_index) * total_weight
	var cursor := 0.0
	for enemy_id in candidates:
		cursor += get_spawn_weight(enemy_id)
		if roll <= cursor:
			return enemy_id
	return candidates.back()

func _deterministic_unit(wave_index: int, spawn_index: int) -> float:
	var raw := absi(
		wave_index * 928371
		+ spawn_index * 364479
		+ int(roundf(difficulty_rating * 100.0)) * 1297
	)
	return float(raw % 10000) / 9999.0
