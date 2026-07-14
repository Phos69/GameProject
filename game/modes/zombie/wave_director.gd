extends Node
class_name WaveDirector

@export var biome_manager_path: NodePath

var biome_manager
var run_elapsed: float = 0.0
var is_run_active: bool = false

func _ready() -> void:
	add_to_group("wave_director")
	_resolve_biome_manager()

func _process(delta: float) -> void:
	if is_run_active:
		run_elapsed += delta

func start_run() -> void:
	run_elapsed = 0.0
	is_run_active = true

func stop_run() -> void:
	is_run_active = false

func configure_wave(
	wave_index: int,
	_is_boss_wave: bool,
	base_regular_total: int
) -> Dictionary:
	var biome = get_current_biome()
	var regular_total := maxi(base_regular_total, 0)
	var spawn_rate_multiplier := 1.0
	var biome_id := &""
	if biome != null:
		var pressure := _get_pressure_multipliers(biome)
		biome_id = biome.biome_id
		if regular_total > 0:
			regular_total = maxi(
				1,
				ceili(float(regular_total) * biome.wave_size_multiplier)
			)
			regular_total = maxi(
				1,
				ceili(
					float(regular_total)
					* float(pressure.get("time", 1.0))
					* float(pressure.get("distance", 1.0))
				)
			)
		spawn_rate_multiplier = maxf(
			biome.spawn_rate_multiplier
			* float(pressure.get("party", 1.0)),
			0.05
		)
	return {
		"biome_id": biome_id,
		"regular_total": regular_total,
		"spawn_rate_multiplier": spawn_rate_multiplier
	}

func get_resource_drop_modifier() -> float:
	var biome = get_current_biome()
	return (
		maxf(biome.resource_drop_modifier, 0.0)
		if biome != null
		else 1.0
	)

func get_enemy_id_for_spawn(
	wave_index: int,
	spawn_index: int,
	regular_total: int
) -> StringName:
	var biome = get_current_biome()
	if biome != null:
		return biome.resolve_enemy_id(wave_index, spawn_index, regular_total)
	return _legacy_enemy_id_for_spawn(wave_index, spawn_index, regular_total)

func get_wave_scaling_multipliers() -> Dictionary:
	var biome = get_current_biome()
	if biome == null:
		return {
			"health": 1.0,
			"move_speed": 1.0,
			"damage": 1.0
		}
	var pressure := _get_pressure_multipliers(biome)
	var full_pressure := (
		float(pressure.get("party", 1.0))
		* float(pressure.get("time", 1.0))
		* float(pressure.get("distance", 1.0))
	)
	return {
		"health": biome.health_multiplier * full_pressure,
		"move_speed": biome.move_speed_multiplier * sqrt(full_pressure),
		"damage": biome.damage_multiplier * full_pressure
	}

func get_current_biome():
	_resolve_biome_manager()
	return biome_manager.get_current_biome() if biome_manager != null else null

func _resolve_biome_manager() -> void:
	if biome_manager != null:
		return
	if not biome_manager_path.is_empty():
		biome_manager = get_node_or_null(biome_manager_path)
	if biome_manager == null:
		biome_manager = get_tree().get_first_node_in_group(
			"biome_manager"
		)

func _legacy_enemy_id_for_spawn(
	wave_index: int,
	spawn_index: int,
	regular_total: int
) -> StringName:
	if (
		wave_index >= 3
		and regular_total >= 5
		and spawn_index == regular_total - 1
	):
		return &"survival_tank"
	if wave_index >= 4 and (spawn_index + 1) % 4 == 0:
		return &"survival_shooter"
	if wave_index >= 2 and (spawn_index + 1) % 3 == 0:
		return &"survival_runner"
	return &"survival_zombie"

func _get_pressure_multipliers(biome: BiomeDefinition) -> Dictionary:
	var living_players := PlayerQuery.alive(get_tree()).size()
	return {
		"party": 1.0 + float(maxi(living_players - 1, 0)) * 0.12,
		"time": 1.0 + minf(
			maxf(run_elapsed - 120.0, 0.0) / 600.0,
			0.20
		),
		"distance": 1.0 + float(biome.progression_depth) * 0.04
	}
