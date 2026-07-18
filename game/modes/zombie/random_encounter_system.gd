extends Node
class_name RandomEncounterSystem

signal encounter_announced(message: String, encounter_id: StringName)
signal encounter_started(encounter_id: StringName, biome_id: StringName)
signal encounter_cleaned(encounter_id: StringName)
signal encounter_telegraph_started(
	encounter_id: StringName,
	position: Vector2,
	duration: float
)

const ENCOUNTER_TELEGRAPH_MARKER = preload(
	"res://game/modes/zombie/encounter_telegraph_marker.gd"
)

const ENCOUNTERS_BY_BIOME := {
	&"plains": [&"ambush", &"survivor_cache"],
	&"toxic_wastes": [&"ambush", &"elite_pack", &"cursed_crate", &"hazard_burst", &"toxic_leak", &"survivor_cache"],
	&"burning_plains": [&"ambush", &"elite_pack", &"cursed_crate", &"hazard_burst", &"fire_breakout", &"survivor_cache"],
	&"frozen_tundra": [&"ambush", &"elite_pack", &"hazard_burst", &"whiteout", &"survivor_cache"],
	&"swamp": [&"ambush", &"elite_pack", &"cursed_crate", &"hazard_burst", &"marsh_emergence", &"survivor_cache"]
}

const MINI_EVENT_BY_BIOME := {
	&"toxic_wastes": &"toxic_leak",
	&"burning_plains": &"fire_breakout",
	&"frozen_tundra": &"whiteout",
	&"swamp": &"marsh_emergence"
}

@export_range(0.0, 1.0, 0.01) var base_chance: float = 0.18
@export_range(120.0, 480.0, 5.0) var safe_distance: float = 180.0
@export_range(0, 10, 1) var cooldown_waves: int = 2
@export_range(1, 12, 1) var max_position_attempts: int = 8
@export_range(0.1, 3.0, 0.1) var danger_telegraph_duration: float = 0.9
@export_range(1, 8, 1) var max_encounter_pack_size: int = 6

var rng := RandomNumberGenerator.new()
var active_entities: Array[Node] = []
var last_encounter_id: StringName = &""
var last_encounter_wave: int = -999
var last_encounter_biome_id: StringName = &""
var last_reward_id: StringName = &""
var last_threat_score: int = 0
var last_position: Vector2 = Vector2.ZERO
var last_skip_reason: StringName = &"not_checked"
var last_party_size: int = 1
var pending_telegraph_count: int = 0
var run_seed: int = 0
var telegraph_generation: int = 0
var active_telegraph_timers: Array[Timer] = []

func _ready() -> void:
	add_to_group("random_encounter_system")

func _exit_tree() -> void:
	_cleanup_entities()

func configure_seed(run_seed: int, salt: int = 7717) -> void:
	self.run_seed = run_seed
	rng.seed = hash("%d:%d:random_encounter" % [run_seed, salt])
	last_encounter_wave = -999
	last_encounter_id = &""
	last_encounter_biome_id = &""
	last_reward_id = &""
	last_threat_score = 0
	last_position = Vector2.ZERO
	last_skip_reason = &"seed_configured"
	last_party_size = 1
	pending_telegraph_count = 0

func try_start_encounter(biome: BiomeDefinition, wave_index: int, critical_state: bool = false) -> Dictionary:
	if not can_start_encounter(biome, wave_index, critical_state):
		return {}
	var chance := _chance_for_biome(biome, wave_index)
	if rng.randf() > chance:
		last_skip_reason = &"chance_failed"
		return {}
	var encounter_id := _pick_encounter_id(biome)
	return force_encounter(biome, encounter_id, wave_index)

func can_start_encounter(
	biome: BiomeDefinition,
	wave_index: int,
	critical_state: bool = false
) -> bool:
	if biome == null:
		last_skip_reason = &"missing_biome"
		return false
	if critical_state:
		last_skip_reason = &"critical_state"
		return false
	if wave_index <= 1:
		last_skip_reason = &"first_wave"
		return false
	if wave_index - last_encounter_wave <= cooldown_waves:
		last_skip_reason = &"cooldown"
		return false
	if _has_active_revive():
		last_skip_reason = &"revive_active"
		return false
	if not _players_can_handle_encounter():
		last_skip_reason = &"no_standing_players"
		return false
	last_skip_reason = &"ready"
	return true

func force_encounter(biome: BiomeDefinition, encounter_id: StringName, wave_index: int = 1) -> Dictionary:
	_cleanup_entities()
	last_encounter_id = encounter_id
	last_encounter_wave = wave_index
	last_encounter_biome_id = biome.biome_id if biome != null else &""
	var spawn_position := _find_valid_encounter_position(biome)
	last_position = spawn_position
	var tuning := _build_encounter_tuning(biome, encounter_id, wave_index)
	last_party_size = int(tuning.get("party_size", 1))
	var result := {
		"encounter_id": encounter_id,
		"biome_id": biome.biome_id if biome != null else &"",
		"entities": [],
		"reward": "standard",
		"threat_score": _threat_score(encounter_id, wave_index),
		"tuning": tuning,
		"position": spawn_position
	}
	match encounter_id:
		&"ambush":
			_spawn_enemy_pack(
				biome,
				spawn_position,
				int(tuning.get("enemy_count", 3)),
				false,
				wave_index,
				tuning,
				result
			)
			_announce("Ambush at the perimeter!", encounter_id)
		&"elite_pack":
			_spawn_enemy_pack(
				biome,
				spawn_position,
				int(tuning.get("enemy_count", 3)),
				true,
				wave_index,
				tuning,
				result
			)
			result["reward"] = "elite"
			_announce("Elite pack incoming!", encounter_id)
		&"cursed_crate":
			result["reward"] = "cursed_loot"
			_spawn_reward_crate(biome, spawn_position, true, tuning, result)
			_begin_cursed_crate_telegraph(biome, spawn_position, result)
			_announce("Cursed crate: rich loot, bad aura.", encounter_id)
		&"hazard_burst":
			_begin_hazard_burst_telegraph(biome, spawn_position, tuning, result)
			_announce("Environmental hazard burst!", encounter_id)
		&"toxic_leak":
			result["reward"] = "toxic_salvage"
			_begin_hazard_burst_telegraph(
				biome,
				spawn_position,
				tuning,
				result,
				encounter_id
			)
			_spawn_reward_crate_near(biome, spawn_position, true, tuning, result)
			_announce("Toxic pipe leak: keep moving!", encounter_id)
		&"fire_breakout":
			result["reward"] = "fire_salvage"
			_begin_hazard_burst_telegraph(
				biome,
				spawn_position,
				tuning,
				result,
				encounter_id
			)
			_spawn_reward_crate_near(biome, spawn_position, true, tuning, result)
			_announce("Fire breakout crossing the lane!", encounter_id)
		&"whiteout":
			result["reward"] = "frost_cache"
			_begin_cursed_crate_telegraph(
				biome,
				spawn_position,
				result,
				encounter_id
			)
			_spawn_reward_crate_near(biome, spawn_position, true, tuning, result)
			_announce("Whiteout front: brace for the chill!", encounter_id)
		&"marsh_emergence":
			result["reward"] = "marsh_salvage"
			_begin_emergence_telegraph(biome, spawn_position, tuning, result)
			_spawn_reward_crate_near(biome, spawn_position, true, tuning, result)
			_announce("Something is rising from the marsh!", encounter_id)
		&"survivor_cache":
			result["reward"] = "healing_ammo_cache"
			_spawn_reward_crate(biome, spawn_position, false, tuning, result)
			_announce("Survivor cache found.", encounter_id)
		_:
			_spawn_enemy_pack(
				biome,
				spawn_position,
				int(tuning.get("enemy_count", 2)),
				false,
				wave_index,
				tuning,
				result
			)
	last_reward_id = StringName(str(result.get("reward", "")))
	last_threat_score = int(result.get("threat_score", 0))
	last_skip_reason = &"started"
	encounter_started.emit(encounter_id, biome.biome_id if biome != null else &"")
	return result

func cleanup_encounter() -> void:
	_cleanup_entities()
	encounter_cleaned.emit(last_encounter_id)
	last_encounter_id = &""

func get_biome_mini_event_id(biome_id: StringName) -> StringName:
	return StringName(MINI_EVENT_BY_BIOME.get(biome_id, &""))

func get_debug_snapshot() -> Dictionary:
	_prune_entities()
	return {
		"run_seed": run_seed,
		"last_encounter_id": last_encounter_id,
		"last_biome_id": last_encounter_biome_id,
		"last_wave": last_encounter_wave,
		"last_reward_id": last_reward_id,
		"last_threat_score": last_threat_score,
		"last_position": last_position,
		"last_skip_reason": last_skip_reason,
		"last_party_size": last_party_size,
		"active_entity_count": active_entities.size(),
		"pending_telegraph_count": pending_telegraph_count,
		"cooldown_waves": cooldown_waves
	}

func _spawn_enemy_pack(
	biome: BiomeDefinition,
	center: Vector2,
	count: int,
	elite: bool,
	wave_index: int,
	tuning: Dictionary,
	result: Dictionary
) -> void:
	var enemy_system := get_tree().get_first_node_in_group("enemy_system") as EnemySystem
	if enemy_system == null:
		return
	for index in range(count):
		var enemy_id := (
			biome.resolve_enemy_id(maxi(wave_index, 2), index, count)
			if biome != null
			else &"survival_zombie"
		)
		var spawn_position := center + Vector2(
			34.0 * float(index),
			0.0
		).rotated(float(index) * TAU / float(maxi(count, 1)))
		var health_multiplier := 1.0
		var damage_multiplier := 1.0
		if elite and index == 0:
			health_multiplier = float(
				tuning.get("elite_health_multiplier", 1.35)
			)
			damage_multiplier = float(
				tuning.get("elite_damage_multiplier", 1.20)
			)
		var enemy := enemy_system.spawn_enemy(
			enemy_id,
			spawn_position,
			null,
			{
				"health_multiplier": health_multiplier,
				"damage_multiplier": damage_multiplier
			}
		)
		if enemy != null:
			if elite and index == 0:
				enemy.set_meta("encounter_elite", true)
			active_entities.append(enemy)
			(result["entities"] as Array).append(enemy)

func _spawn_reward_crate(
	biome: BiomeDefinition,
	position: Vector2,
	cursed: bool,
	tuning: Dictionary,
	result: Dictionary
) -> void:
	var crate_system := get_tree().get_first_node_in_group(
		"resource_crate_system"
	) as ResourceCrateSystem
	if crate_system == null:
		return
	var crate_id := StringName(
		tuning.get("reward_crate_id", _reward_crate_id(biome, cursed))
	)
	var crate := crate_system.spawn_encounter_crate(
		crate_id,
		position,
		last_encounter_id
	)
	if crate != null:
		active_entities.append(crate)
		(result["entities"] as Array).append(crate)

func _spawn_reward_crate_near(
	biome: BiomeDefinition,
	position: Vector2,
	cursed: bool,
	tuning: Dictionary,
	result: Dictionary
) -> void:
	var hazard_radius := maxf(float(tuning.get("hazard_radius", 64.0)), 64.0)
	var reward_distance := maxf(hazard_radius * 2.35, 136.0)
	for index in range(6):
		var angle := (
			float(index) * TAU / 6.0
			+ rng.randf_range(-0.18, 0.18)
		)
		var candidate := position + Vector2(reward_distance, 0.0).rotated(angle)
		if not _is_encounter_position_valid(candidate, biome):
			continue
		var before_count := (result["entities"] as Array).size()
		_spawn_reward_crate(biome, candidate, cursed, tuning, result)
		if (result["entities"] as Array).size() > before_count:
			return
	_spawn_reward_crate(biome, position, cursed, tuning, result)

func _spawn_hazard_burst(
	biome: BiomeDefinition,
	position: Vector2,
	tuning: Dictionary,
	result: Dictionary
) -> void:
	var hazard_system := get_tree().get_first_node_in_group("hazard_system") as HazardSystem
	if hazard_system == null:
		return
	var hazard_count := int(tuning.get("hazard_count", 3))
	var hazard_radius := float(tuning.get("hazard_radius", 62.0))
	var hazard_lifetime := float(tuning.get("hazard_lifetime", 4.0))
	for index in range(hazard_count):
		var offset := Vector2(hazard_radius * 0.95, 0.0).rotated(
			float(index) * TAU / float(maxi(hazard_count, 1))
			+ rng.randf_range(-0.25, 0.25)
		)
		var zone := hazard_system.spawn_runtime_hazard(
			_biome_hazard(biome),
			position + offset,
			{"lifetime": hazard_lifetime, "radius": hazard_radius}
		)
		if zone != null:
			active_entities.append(zone)
			(result["entities"] as Array).append(zone)

func _begin_cursed_crate_telegraph(
	biome: BiomeDefinition,
	position: Vector2,
	result: Dictionary,
	encounter_id: StringName = &"cursed_crate"
) -> void:
	var warning_radius := 74.0
	var marker := _spawn_telegraph_marker(
		encounter_id,
		position,
		warning_radius,
		_encounter_color(encounter_id, biome)
	)
	if marker != null:
		(result["entities"] as Array).append(marker)
	var generation := telegraph_generation
	_schedule_telegraph_action(func() -> void:
		if not _is_telegraph_generation_active(generation):
			return
		_apply_status_to_near_players(
			_biome_status(biome),
			2.5,
			position,
			warning_radius
		)
	)

func _begin_hazard_burst_telegraph(
	biome: BiomeDefinition,
	position: Vector2,
	tuning: Dictionary,
	result: Dictionary,
	encounter_id: StringName = &"hazard_burst"
) -> void:
	var marker := _spawn_telegraph_marker(
		encounter_id,
		position,
		float(tuning.get("hazard_radius", 62.0)) * 1.65,
		_encounter_color(encounter_id, biome)
	)
	if marker != null:
		(result["entities"] as Array).append(marker)
	var generation := telegraph_generation
	_schedule_telegraph_action(func() -> void:
		if not _is_telegraph_generation_active(generation):
			return
		_spawn_hazard_burst(biome, position, tuning, result)
	)

func _begin_emergence_telegraph(
	biome: BiomeDefinition,
	position: Vector2,
	tuning: Dictionary,
	result: Dictionary
) -> void:
	var marker := _spawn_telegraph_marker(
		&"marsh_emergence",
		position,
		86.0,
		_encounter_color(&"marsh_emergence", biome)
	)
	if marker != null:
		(result["entities"] as Array).append(marker)
	var generation := telegraph_generation
	_schedule_telegraph_action(func() -> void:
		if not _is_telegraph_generation_active(generation):
			return
		_spawn_enemy_pack(
			biome,
			position,
			int(tuning.get("enemy_count", 3)),
			false,
			maxi(last_encounter_wave, 2),
			tuning,
			result
		)
	)

func _spawn_telegraph_marker(
	encounter_id: StringName,
	position: Vector2,
	radius: float,
	color: Color
) -> EncounterTelegraphMarker:
	var marker := ENCOUNTER_TELEGRAPH_MARKER.new() as EncounterTelegraphMarker
	if marker == null:
		return null
	marker.name = "%sEncounterTelegraph" % String(encounter_id).capitalize()
	marker.configure(encounter_id, radius, danger_telegraph_duration, color)
	var container := _get_telegraph_container()
	container.add_child(marker)
	marker.global_position = position
	active_entities.append(marker)
	pending_telegraph_count += 1
	marker.tree_exited.connect(_on_telegraph_marker_exited)
	encounter_telegraph_started.emit(
		encounter_id,
		position,
		danger_telegraph_duration
	)
	return marker

func _schedule_telegraph_action(callback: Callable) -> void:
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = maxf(danger_telegraph_duration, 0.01)
	add_child(timer)
	active_telegraph_timers.append(timer)
	timer.timeout.connect(
		_on_telegraph_timer_timeout.bind(timer, callback)
	)
	timer.start()

func _on_telegraph_timer_timeout(
	timer: Timer,
	callback: Callable
) -> void:
	active_telegraph_timers.erase(timer)
	if callback.is_valid():
		callback.call()
	if is_instance_valid(timer):
		timer.queue_free()

func _clear_telegraph_timers() -> void:
	for timer in active_telegraph_timers:
		if not is_instance_valid(timer):
			continue
		timer.stop()
		if timer.get_parent() != null:
			timer.get_parent().remove_child(timer)
		timer.free()
	active_telegraph_timers.clear()

func _is_telegraph_generation_active(generation: int) -> bool:
	return is_inside_tree() and generation == telegraph_generation

func _on_telegraph_marker_exited() -> void:
	pending_telegraph_count = maxi(pending_telegraph_count - 1, 0)

func _apply_status_to_near_players(
	status_id: StringName,
	duration: float,
	position: Vector2,
	radius: float
) -> void:
	var hazard_system := get_tree().get_first_node_in_group("hazard_system") as HazardSystem
	if hazard_system == null:
		return
	for player in PlayerQuery.all(get_tree()):
		if not player is Node2D:
			continue
		if (player as Node2D).global_position.distance_to(position) > radius:
			continue
		hazard_system.apply_status(player, status_id, duration, 1.0, self)

func _find_valid_encounter_position(biome: BiomeDefinition) -> Vector2:
	var anchor := _find_player_anchor()
	for attempt in range(max_position_attempts):
		var direction := Vector2.RIGHT.rotated(
			rng.randf() * TAU + float(attempt) * TAU / float(maxi(max_position_attempts, 1))
		)
		var candidate := anchor + direction * safe_distance
		if _is_encounter_position_valid(candidate, biome):
			return candidate
	return anchor + Vector2.RIGHT * safe_distance

func _find_player_anchor() -> Vector2:
	for player in PlayerQuery.all(get_tree()):
		if player is Node2D:
			return (player as Node2D).global_position
	return Vector2.ZERO

func _is_encounter_position_valid(position: Vector2, biome: BiomeDefinition) -> bool:
	for player in PlayerQuery.all(get_tree()):
		if (
			player is Node2D
			and (player as Node2D).global_position.distance_to(position)
			< safe_distance * 0.75
		):
			return false
	var zombie_spawner := get_tree().get_first_node_in_group(
		"zombie_spawner"
	) as ZombieSpawner
	if (
		zombie_spawner != null
		and not zombie_spawner.is_spawn_position_valid(position, biome)
	):
		return false
	var hazard_system := get_tree().get_first_node_in_group("hazard_system")
	if (
		hazard_system != null
		and hazard_system.has_method("is_position_hazardous")
		and hazard_system.is_position_hazardous(position)
	):
		return false
	var obstacle_system := get_tree().get_first_node_in_group("obstacle_system")
	if (
		obstacle_system != null
		and obstacle_system.has_method("is_position_blocked")
		and obstacle_system.is_position_blocked(position)
	):
		return false
	return true

func _players_can_handle_encounter() -> bool:
	var players := PlayerQuery.all(get_tree())
	if players.is_empty():
		return true
	for player in players:
		if not PlayerQuery.is_incapacitated(player):
			return true
	return false

func _has_active_revive() -> bool:
	var revive_system := get_tree().get_first_node_in_group("revive_system")
	if revive_system == null:
		return false
	var progress_value: Variant = revive_system.get("progress_by_target")
	if not progress_value is Dictionary:
		return false
	var progress := progress_value as Dictionary
	for value in progress.values():
		if float(value) > 0.0:
			return true
	return false

func _pick_encounter_id(biome: BiomeDefinition) -> StringName:
	var types := ENCOUNTERS_BY_BIOME.get(biome.biome_id, [&"ambush"]) as Array
	if types.is_empty():
		return &"ambush"
	var candidate := StringName(types[rng.randi_range(0, types.size() - 1)])
	if types.size() > 1 and candidate == last_encounter_id:
		var next_index := (types.find(candidate) + 1) % types.size()
		candidate = StringName(types[next_index])
	return candidate

func _chance_for_biome(biome: BiomeDefinition, wave_index: int) -> float:
	var biome_bonus := clampf(
		float(biome.environmental_hazard_chance) * 0.25,
		0.0,
		0.12
	)
	var wave_bonus := clampf(float(wave_index - 2) * 0.015, 0.0, 0.12)
	return clampf(base_chance + biome_bonus + wave_bonus, 0.0, 0.65)

func _build_encounter_tuning(
	biome: BiomeDefinition,
	encounter_id: StringName,
	wave_index: int
) -> Dictionary:
	var party_size := _get_active_party_size()
	var threat := _threat_score(encounter_id, wave_index)
	var depth := biome.progression_depth if biome != null else 0
	var enemy_count := 0
	var hazard_count := 0
	var reward_crate_id := _reward_crate_id(biome, encounter_id == &"cursed_crate")
	match encounter_id:
		&"ambush":
			enemy_count = 2 + mini(party_size, 2) + mini(int(wave_index / 5), 2)
		&"elite_pack":
			enemy_count = 2 + mini(party_size, 3)
			reward_crate_id = _reward_crate_id(biome, true)
		&"hazard_burst":
			hazard_count = 2 + mini(party_size, 2) + mini(depth, 1)
		&"toxic_leak", &"fire_breakout":
			hazard_count = 3 + mini(party_size, 2) + mini(depth, 1)
			reward_crate_id = _reward_crate_id(biome, true)
		&"whiteout":
			hazard_count = 0
			reward_crate_id = _reward_crate_id(biome, true)
		&"marsh_emergence":
			enemy_count = 2 + mini(party_size, 2) + mini(depth, 1)
			reward_crate_id = _reward_crate_id(biome, true)
		&"cursed_crate":
			hazard_count = 0
			reward_crate_id = _reward_crate_id(biome, true)
		&"survivor_cache":
			reward_crate_id = _reward_crate_id(biome, false)
		_:
			enemy_count = 2 + mini(party_size, 1)
	enemy_count = clampi(enemy_count, 0, max_encounter_pack_size)
	hazard_count = clampi(hazard_count, 0, 5)
	return {
		"party_size": party_size,
		"threat_score": threat,
		"enemy_count": enemy_count,
		"hazard_count": hazard_count,
		"hazard_radius": clampf(52.0 + float(threat * 4), 52.0, 88.0),
		"hazard_lifetime": clampf(3.2 + float(threat) * 0.28, 3.2, 6.5),
		"elite_health_multiplier": clampf(1.20 + float(threat) * 0.04, 1.20, 1.60),
		"elite_damage_multiplier": clampf(1.10 + float(threat) * 0.025, 1.10, 1.35),
		"reward_crate_id": reward_crate_id
	}

func _threat_score(encounter_id: StringName, wave_index: int) -> int:
	var base_score := 1
	match encounter_id:
		&"elite_pack":
			base_score = 4
		&"hazard_burst", &"cursed_crate":
			base_score = 3
		&"toxic_leak", &"fire_breakout", &"whiteout", &"marsh_emergence":
			base_score = 3
		&"ambush":
			base_score = 2
		_:
			base_score = 1
	return base_score + maxi(int(wave_index / 4), 0)

func _get_active_party_size() -> int:
	var count := 0
	for player in PlayerQuery.all(get_tree()):
		if not PlayerQuery.is_incapacitated(player):
			count += 1
	return maxi(count, 1)

func _reward_crate_id(biome: BiomeDefinition, cursed: bool) -> StringName:
	if cursed:
		match biome.biome_id if biome != null else &"":
			&"toxic_wastes":
				return &"biome_toxic"
			&"burning_plains":
				return &"biome_fire"
			&"frozen_tundra":
				return &"biome_frost"
			&"swamp":
				return &"biome_marsh"
			_:
				return &"military"
	if biome != null and biome.crate_ids.has(&"medical"):
		return &"medical"
	return &"common"

func _encounter_color(encounter_id: StringName, biome: BiomeDefinition) -> Color:
	match encounter_id:
		&"cursed_crate":
			return Color(0.78, 0.24, 1.0, 1.0)
		&"hazard_burst":
			match biome.biome_id if biome != null else &"":
				&"burning_plains":
					return Color(1.0, 0.28, 0.08, 1.0)
				&"frozen_tundra":
					return Color(0.48, 0.90, 1.0, 1.0)
				&"swamp":
					return Color(0.18, 0.72, 0.56, 1.0)
				_:
					return Color(0.38, 1.0, 0.22, 1.0)
		&"toxic_leak":
			return Color(0.38, 1.0, 0.22, 1.0)
		&"fire_breakout":
			return Color(1.0, 0.28, 0.08, 1.0)
		&"whiteout":
			return Color(0.70, 0.95, 1.0, 1.0)
		&"marsh_emergence":
			return Color(0.18, 0.72, 0.56, 1.0)
		_:
			return Color(1.0, 0.64, 0.18, 1.0)

func _get_telegraph_container() -> Node:
	var environment := get_tree().get_first_node_in_group("environment_props")
	return environment if environment != null else get_tree().current_scene

func _biome_status(biome: BiomeDefinition) -> StringName:
	match biome.biome_id if biome != null else &"":
		&"burning_plains":
			return &"burn"
		&"frozen_tundra":
			return &"freeze"
		&"swamp":
			return &"bleed"
		_:
			return &"poison"

func _biome_hazard(biome: BiomeDefinition) -> StringName:
	match biome.biome_id if biome != null else &"":
		&"burning_plains":
			return &"fire_patch"
		&"frozen_tundra":
			return &"deep_snow_slow"
		&"swamp":
			return &"mud_pool"
		_:
			return &"toxic_cloud"

func _announce(message: String, encounter_id: StringName) -> void:
	encounter_announced.emit(message, encounter_id)

func _cleanup_entities() -> void:
	telegraph_generation += 1
	_clear_telegraph_timers()
	for entity in active_entities:
		if is_instance_valid(entity):
			entity.queue_free()
	active_entities.clear()
	pending_telegraph_count = 0

func _prune_entities() -> void:
	for entity in active_entities.duplicate():
		if not is_instance_valid(entity) or entity.is_queued_for_deletion():
			active_entities.erase(entity)
