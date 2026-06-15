extends Node
class_name WaveDirector

@export var biome_manager_path: NodePath

var biome_manager

func _ready() -> void:
	add_to_group("wave_director")
	_resolve_biome_manager()

func configure_wave(
	wave_index: int,
	is_boss_wave: bool,
	base_regular_total: int
) -> Dictionary:
	var biome = get_current_biome()
	var regular_total := maxi(base_regular_total, 0)
	var spawn_rate_multiplier := 1.0
	var biome_id := &""
	if biome != null:
		biome_id = biome.biome_id
		if not is_boss_wave:
			regular_total = maxi(
				1,
				ceili(float(regular_total) * biome.wave_size_multiplier)
			)
		spawn_rate_multiplier = maxf(biome.spawn_rate_multiplier, 0.05)
	return {
		"biome_id": biome_id,
		"regular_total": regular_total,
		"spawn_rate_multiplier": spawn_rate_multiplier
	}

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
	return {
		"health": biome.health_multiplier,
		"move_speed": biome.move_speed_multiplier,
		"damage": biome.damage_multiplier
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
