extends RefCounted
class_name BiomeStatusRuntime

signal environment_damaged(player: Node, hazard_id: StringName, damage: int)
signal status_changed(player: Node, status_ids: Array[StringName])

const STATUS_DEFINITIONS := {
	&"poison": {"duration": 5.0, "movement": 0.94, "damage": 2, "tick": 1.0},
	&"burn": {"duration": 3.0, "movement": 1.0, "damage": 4, "tick": 0.8},
	&"bleed": {"duration": 4.5, "movement": 0.98, "damage": 3, "tick": 1.0},
	&"freeze": {"duration": 3.0, "movement": 0.62, "damage": 0, "tick": 1.0},
	&"shock": {"duration": 1.1, "movement": 0.45, "damage": 1, "tick": 0.55}
}
const STATUS_ALIASES := {
	&"poisoned": &"poison", &"toxic_puddle": &"poison", &"gas_cloud": &"poison", &"toxic_cloud": &"poison",
	&"burning": &"burn", &"fire_zone": &"burn", &"lava_crack": &"burn", &"fire_patch": &"burn", &"explosion": &"burn",
	&"chilled": &"freeze", &"slippery_ice": &"freeze", &"deep_snow_slow": &"freeze",
	&"mudded": &"bleed", &"mud_slow": &"bleed", &"mud_pool": &"bleed",
	&"soaked": &"poison", &"deep_water": &"poison"
}

var hazard_damage_timers: Dictionary = {}
var timed_statuses: Dictionary = {}
var last_status_signatures: Dictionary = {}

static func canonical_status_id(status_id: StringName) -> StringName:
	return STATUS_ALIASES.get(status_id, status_id)

static func get_status_definition(status_id: StringName) -> Dictionary:
	return (STATUS_DEFINITIONS.get(canonical_status_id(status_id), {}) as Dictionary).duplicate(true)

func process_runtime(delta: float, tree: SceneTree, active_hazards: Array[Node2D]) -> void:
	_tick_hazard_damage_timers(delta)
	_tick_timed_statuses(delta, tree, active_hazards)
	_update_environment_effects(tree, active_hazards)

func apply_status(player: Node, status_id: StringName, duration: float = 0.0, intensity: float = 1.0, source: Variant = null, active_hazards: Array[Node2D] = []) -> bool:
	var canonical := canonical_status_id(status_id)
	var definition := get_status_definition(canonical)
	if definition.is_empty():
		definition = {"duration": duration, "movement": 1.0, "damage": 0, "tick": 1.0}
	return apply_status_to_player(player, canonical, duration if duration > 0.0 else float(definition.get("duration", 1.0)), clampf(float(definition.get("movement", 1.0)) / maxf(intensity, 0.1), 0.25, 1.25), roundi(float(definition.get("damage", 0)) * maxf(intensity, 0.0)), active_hazards, float(definition.get("tick", 1.0)), source)

func apply_status_to_player(player: Node, status_id: StringName, duration: float, movement_multiplier: float, damage_per_tick: int, active_hazards: Array[Node2D], tick_interval: float = 1.0, source: Variant = null) -> bool:
	if player == null or not player.is_in_group("players") or status_id.is_empty() or duration <= 0.0:
		return false
	var canonical := canonical_status_id(status_id)
	var player_id := player.get_instance_id()
	var player_statuses := timed_statuses.get(player_id, {}) as Dictionary
	var existing := player_statuses.get(canonical, {}) as Dictionary
	player_statuses[canonical] = {"player": player, "time_left": maxf(duration, float(existing.get("time_left", 0.0))), "duration": maxf(duration, float(existing.get("duration", duration))), "movement_multiplier": minf(clampf(movement_multiplier, 0.25, 1.25), float(existing.get("movement_multiplier", 1.25))), "damage": maxi(damage_per_tick, int(existing.get("damage", 0))), "damage_timer": minf(float(existing.get("damage_timer", 0.0)), 0.2), "tick_interval": maxf(tick_interval, 0.1), "source": source}
	timed_statuses[player_id] = player_statuses
	_emit_status_if_changed(player, active_hazards)
	_call_player_status_feedback(player, canonical)
	return true

func clear_status(player: Node, status_id: StringName, active_hazards: Array[Node2D] = []) -> void:
	if player == null: return
	var statuses := timed_statuses.get(player.get_instance_id(), {}) as Dictionary
	statuses.erase(canonical_status_id(status_id))
	if statuses.is_empty(): timed_statuses.erase(player.get_instance_id())
	_emit_status_if_changed(player, active_hazards)

func has_status(player: Node, status_id: StringName) -> bool:
	if player == null: return false
	return (timed_statuses.get(player.get_instance_id(), {}) as Dictionary).has(canonical_status_id(status_id))

func get_status_ids(player: Node, active_hazards: Array[Node2D]) -> Array[StringName]:
	var result: Array[StringName] = []
	if player == null or not player is Node2D: return result
	for hazard in active_hazards:
		if is_instance_valid(hazard) and not hazard.is_queued_for_deletion() and hazard is BiomeHazardZone and (hazard as BiomeHazardZone).contains_global_position((player as Node2D).global_position):
			var hazard_id := canonical_status_id((hazard as BiomeHazardZone).hazard_id)
			if not result.has(hazard_id): result.append(hazard_id)
	for status_id in (timed_statuses.get(player.get_instance_id(), {}) as Dictionary).keys():
		var typed_id := canonical_status_id(StringName(status_id))
		if not result.has(typed_id): result.append(typed_id)
	result.sort()
	return result

func get_status_snapshots(player: Node) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if player == null: return result
	for status_id in (timed_statuses.get(player.get_instance_id(), {}) as Dictionary).keys():
		var data := (timed_statuses[player.get_instance_id()] as Dictionary)[status_id] as Dictionary
		result.append({"id": StringName(status_id), "time_left": float(data.get("time_left", 0.0)), "duration": float(data.get("duration", 1.0))})
	return result

func clear_runtime(tree: SceneTree) -> void:
	for player in tree.get_nodes_in_group("players"):
		_set_player_environment_multiplier(player, 1.0)
	hazard_damage_timers.clear(); timed_statuses.clear(); last_status_signatures.clear()

func _update_environment_effects(tree: SceneTree, active_hazards: Array[Node2D]) -> void:
	for player in tree.get_nodes_in_group("players"):
		if not player is Node2D: continue
		var health_component := player.get_node_or_null("HealthComponent") as HealthComponent
		if health_component == null or health_component.is_incapacitated():
			_set_player_environment_multiplier(player, 1.0); continue
		var speed_multiplier := 1.0
		for hazard in active_hazards:
			if is_instance_valid(hazard) and not hazard.is_queued_for_deletion() and hazard is BiomeHazardZone and (hazard as BiomeHazardZone).contains_global_position((player as Node2D).global_position):
				var zone := hazard as BiomeHazardZone
				speed_multiplier = minf(speed_multiplier, zone.movement_multiplier)
				_apply_zone_damage(player, zone, tree)
				var status_id := canonical_status_id(zone.hazard_id)
				if STATUS_DEFINITIONS.has(status_id): apply_status(player, status_id, 1.25, 1.0, zone, active_hazards)
		for data_value in (timed_statuses.get(player.get_instance_id(), {}) as Dictionary).values():
			speed_multiplier = minf(speed_multiplier, float((data_value as Dictionary).get("movement_multiplier", 1.0)))
		_set_player_environment_multiplier(player, speed_multiplier)
		_emit_status_if_changed(player, active_hazards)

func _apply_zone_damage(player: Node, zone: BiomeHazardZone, tree: SceneTree) -> void:
	if zone.damage_per_tick <= 0: return
	var timer_key := "%d_%d" % [player.get_instance_id(), zone.get_instance_id()]
	if float(hazard_damage_timers.get(timer_key, 0.0)) > 0.0: return
	var health_system := tree.get_first_node_in_group("health_system") as HealthSystem
	if health_system == null: return
	var applied_damage := health_system.apply_damage(player, zone.damage_per_tick, null, zone.hazard_id, (player as Node2D).global_position)
	hazard_damage_timers[timer_key] = zone.tick_interval
	if applied_damage > 0: environment_damaged.emit(player, zone.hazard_id, applied_damage)

func _tick_timed_statuses(delta: float, tree: SceneTree, active_hazards: Array[Node2D]) -> void:
	for player_id in timed_statuses.keys():
		var player_statuses := timed_statuses[player_id] as Dictionary
		var affected_player: Node
		for status_id in player_statuses.keys():
			var data := player_statuses[status_id] as Dictionary
			var player := data.get("player") as Node; affected_player = player
			if player == null or not is_instance_valid(player): player_statuses.erase(status_id); continue
			var time_left := maxf(float(data.get("time_left", 0.0)) - delta, 0.0)
			var damage_timer := maxf(float(data.get("damage_timer", 0.0)) - delta, 0.0)
			if time_left <= 0.0: player_statuses.erase(status_id); continue
			var damage := int(data.get("damage", 0))
			if damage > 0 and damage_timer <= 0.0:
				_apply_timed_status_damage(player, StringName(status_id), damage, tree)
				damage_timer = maxf(float(data.get("tick_interval", 1.0)), 0.1)
			data["time_left"] = time_left; data["damage_timer"] = damage_timer; player_statuses[status_id] = data
		if player_statuses.is_empty(): timed_statuses.erase(player_id)
		else: timed_statuses[player_id] = player_statuses
		if affected_player != null and is_instance_valid(affected_player): _emit_status_if_changed(affected_player, active_hazards)

func _apply_timed_status_damage(player: Node, status_id: StringName, damage: int, tree: SceneTree) -> void:
	var health_system := tree.get_first_node_in_group("health_system") as HealthSystem
	if health_system == null: return
	var applied_damage := health_system.apply_damage(player, damage, null, status_id, (player as Node2D).global_position)
	if applied_damage > 0: environment_damaged.emit(player, status_id, applied_damage)

func _tick_hazard_damage_timers(delta: float) -> void:
	for timer_key in hazard_damage_timers.keys():
		var time_left := maxf(float(hazard_damage_timers[timer_key]) - delta, 0.0)
		if time_left <= 0.0: hazard_damage_timers.erase(timer_key)
		else: hazard_damage_timers[timer_key] = time_left

func _emit_status_if_changed(player: Node, active_hazards: Array[Node2D]) -> void:
	var statuses := get_status_ids(player, active_hazards)
	var signature := PackedStringArray()
	for status_id in statuses: signature.append(String(status_id))
	var signature_text := ",".join(signature)
	var player_id := player.get_instance_id()
	if String(last_status_signatures.get(player_id, "")) == signature_text: return
	last_status_signatures[player_id] = signature_text
	status_changed.emit(player, statuses)

func _set_player_environment_multiplier(player: Node, multiplier: float) -> void:
	if player.has_method("set_environment_speed_multiplier"):
		player.set_environment_speed_multiplier(multiplier)

func _call_player_status_feedback(player: Node, status_id: StringName) -> void:
	if player.has_method("play_status_feedback"):
		player.play_status_feedback(status_id)
	var visual := player.get_node_or_null("Visual")
	if visual != null and visual.has_method("play_status_feedback"):
		visual.play_status_feedback(status_id)
