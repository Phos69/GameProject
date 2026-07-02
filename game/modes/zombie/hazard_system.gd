extends Node
class_name HazardSystem

signal hazard_rules_configured(biome_id: StringName)
signal hazard_spawned(hazard: Node2D, hazard_id: StringName)
signal safe_position_updated(player: Node, position: Vector2)
signal player_fell(
	player: Node,
	damage: int,
	fall_position: Vector2,
	respawn_position: Vector2
)
signal player_environment_damaged(
	player: Node,
	hazard_id: StringName,
	damage: int
)
signal player_status_changed(player: Node, status_ids: Array[StringName])

const FALL_ZONE_SCRIPT = preload(
	"res://game/modes/zombie/biome_fall_zone.gd"
)
const HAZARD_ZONE_SCRIPT = preload(
	"res://game/modes/zombie/biome_hazard_zone.gd"
)

## I nemici vengono verificati contro il void a fette rotanti (1/N della
## popolazione per frame): la query terreno costa ~16µs e per-frame su tutta
## la popolazione arrivava a ~3.5ms con 192 nemici (vedi
## tests/suites/soak/perf_bottleneck_stress_test.gd). Copertura completa ogni
## N frame (~67ms a 60Hz): un nemico oltrepassa il bordo di pochi px prima di
## cadere. I player restano verificati ogni frame (pochi e gameplay-critici).
const VOID_CHECK_ENEMY_SLICES: int = 4

@export var environment_container_path: NodePath = NodePath(
	"../../../../World/EnvironmentProps"
)
@export_range(1, 999, 1) var fall_damage: int = 20
@export_range(0.1, 5.0, 0.1) var fall_respawn_invulnerability: float = 1.25
@export_range(0.05, 2.0, 0.05) var safe_position_update_interval: float = 0.20
@export_range(0.0, 240.0, 4.0) var minimum_safe_distance_from_hazard: float = 56.0
@export_range(0.1, 3.0, 0.1) var fall_retrigger_cooldown: float = 0.50

var active_biome: BiomeDefinition
var is_active: bool = false
var active_hazards: Array[Node2D] = []
var safe_positions: Dictionary = {}
var safe_update_timer: float = 0.0
var fall_cooldowns: Dictionary = {}
var invulnerability_timers: Dictionary = {}
var status_runtime: BiomeStatusRuntime
var _biome_manager_ref: BiomeManager
var _seam_system_ref: Node
var _void_scan_cursor: int = 0

func _ready() -> void:
	add_to_group("hazard_system")
	status_runtime = BiomeStatusRuntime.new()
	status_runtime.environment_damaged.connect(
		_on_runtime_environment_damaged
	)
	status_runtime.status_changed.connect(_on_runtime_status_changed)

func _process(delta: float) -> void:
	if not is_active:
		return
	_tick_fall_cooldowns(delta)
	_tick_invulnerability(delta)
	status_runtime.process_runtime(delta, get_tree(), active_hazards)
	_check_void_entities()
	safe_update_timer = maxf(safe_update_timer - delta, 0.0)
	if safe_update_timer <= 0.0:
		safe_update_timer = safe_position_update_interval
		_update_safe_positions()

func start_run(biome: BiomeDefinition) -> void:
	_clear_runtime()
	active_biome = biome
	is_active = true
	_generate_hazards()
	status_runtime.process_runtime(0.0, get_tree(), active_hazards)
	_update_safe_positions()
	hazard_rules_configured.emit(
		active_biome.biome_id if active_biome != null else &""
	)

func begin_streaming_run(biome: BiomeDefinition) -> void:
	_clear_runtime()
	active_biome = biome
	is_active = true
	hazard_rules_configured.emit(
		active_biome.biome_id if active_biome != null else &""
	)

func set_active_biome(biome: BiomeDefinition) -> void:
	active_biome = biome
	is_active = biome != null
	if active_biome != null:
		hazard_rules_configured.emit(active_biome.biome_id)

func stop_run() -> void:
	_clear_runtime()
	is_active = false
	active_biome = null

func get_active_hazards() -> Array[Node2D]:
	_prune_hazards()
	return active_hazards.duplicate()

func get_last_safe_position(player: Node) -> Vector2:
	if player == null:
		return Vector2.ZERO
	return safe_positions.get(
		player.get_instance_id(),
		_resolve_fallback_position(player)
	)

func get_player_status_ids(player: Node) -> Array[StringName]:
	return status_runtime.get_status_ids(player, active_hazards)

func get_player_status_snapshots(player: Node) -> Array[Dictionary]:
	return status_runtime.get_status_snapshots(player)

func has_status(player: Node, status_id: StringName) -> bool:
	return status_runtime.has_status(player, status_id)

func clear_status(player: Node, status_id: StringName) -> void:
	status_runtime.clear_status(player, status_id, active_hazards)

func apply_status(player: Node, status_id: StringName, duration: float = 0.0, intensity: float = 1.0, source: Variant = null) -> bool:
	if not is_active or player == null or not player.is_in_group("players"):
		return false
	return status_runtime.apply_status(player, status_id, duration, intensity, source, active_hazards)

func apply_status_to_player(
	player: Node,
	status_id: StringName,
	duration: float,
	movement_multiplier: float = 1.0,
	damage_per_tick: int = 0
) -> bool:
	if (
		not is_active
		or player == null
		or not player.is_in_group("players")
		or status_id.is_empty()
		or duration <= 0.0
	):
		return false
	return status_runtime.apply_status_to_player(
		player,
		status_id,
		duration,
		movement_multiplier,
		damage_per_tick,
		active_hazards
	)

func spawn_runtime_hazard(
	hazard_id: StringName,
	position: Vector2,
	config: Dictionary = {}
) -> BiomeHazardZone:
	if not is_active or hazard_id.is_empty():
		return null
	var resolved_config := BiomeHazardCatalog.get_config(hazard_id)
	for key in config.keys():
		resolved_config[key] = config[key]
	var radius := maxf(float(resolved_config.get("radius", 68.0)), 20.0)
	var zone := HAZARD_ZONE_SCRIPT.new() as BiomeHazardZone
	if zone == null:
		return null
	var color := BiomeHazardCatalog.get_color(hazard_id, active_biome)
	zone.name = "%sRuntimeHazard" % BiomeHazardCatalog.pascal_case(
		String(hazard_id)
	)
	zone.add_to_group("world_streaming_pins")
	zone.configure(
		hazard_id,
		Vector2(radius * 2.0, radius * 1.25),
		0.0,
		color,
		resolved_config
	)
	var container := _get_environment_container()
	if container == null:
		return null
	container.add_child(zone)
	zone.global_position = position
	active_hazards.append(zone)
	hazard_spawned.emit(zone, hazard_id)
	return zone

func is_position_hazardous(position: Vector2) -> bool:
	return is_void_at_world_position(position) or is_position_environment_hazard(position)

func is_position_fall_zone(position: Vector2) -> bool:
	return is_void_at_world_position(position)

func _get_biome_manager() -> BiomeManager:
	if _biome_manager_ref == null or not is_instance_valid(_biome_manager_ref):
		_biome_manager_ref = get_tree().get_first_node_in_group(
			"biome_manager"
		) as BiomeManager
	return _biome_manager_ref

func _get_seam_system() -> Node:
	if _seam_system_ref == null or not is_instance_valid(_seam_system_ref):
		_seam_system_ref = get_tree().get_first_node_in_group(
			"region_seam_system"
		)
	return _seam_system_ref

func get_terrain_at_world_position(position: Vector2) -> StringName:
	# Query chiamata per-frame per ogni player/nemico (_check_void_entities) e per
	# campione dal pathfinder: i riferimenti ai sistemi sono cache-ati invece di
	# risolvere i gruppi a ogni chiamata.
	var biome_manager := _get_biome_manager()
	var seam_system := _get_seam_system()
	if (
		biome_manager != null
		and seam_system != null
		and bool(seam_system.get("is_active"))
		and biome_manager.get_world_graph() != null
		and seam_system.has_method("get_region_id_for_world_position")
		and seam_system.has_method("world_position_to_logical_tile")
	):
		var region_id := StringName(
			seam_system.get_region_id_for_world_position(position)
		)
		if region_id.is_empty():
			return BiomeEnvironmentLayout.TERRAIN_VOID
		var cell := biome_manager.get_cell_by_region_id(region_id) as BiomeCell
		if cell == null or cell.generated_layout == null:
			return BiomeEnvironmentLayout.TERRAIN_VOID
		var world_tile: Vector2i = seam_system.world_position_to_logical_tile(
			position
		)
		var local_tile := world_tile - cell.world_origin
		return cell.generated_layout.get_terrain_class_at_cell(
			local_tile,
			cell
		)

	var layout := (
		active_biome.environment_layout
		if active_biome != null
		else null
	) as BiomeEnvironmentLayout
	if layout != null and layout.has_generated_map_data():
		return layout.get_terrain_class_at_cell(
			layout.world_to_logical(position)
		)
	if _is_position_inside_group(position, "fall_zones"):
		return BiomeEnvironmentLayout.TERRAIN_FALL_ZONE
	if _is_position_inside_group(position, "environment_hazards"):
		return BiomeEnvironmentLayout.TERRAIN_HAZARD
	return BiomeEnvironmentLayout.TERRAIN_WALKABLE

func is_void_at_world_position(position: Vector2) -> bool:
	var terrain_class := get_terrain_at_world_position(position)
	return (
		terrain_class == BiomeEnvironmentLayout.TERRAIN_VOID
		or terrain_class == BiomeEnvironmentLayout.TERRAIN_FALL_ZONE
	)

func is_walkable_at_world_position(position: Vector2) -> bool:
	return (
		get_terrain_at_world_position(position)
		== BiomeEnvironmentLayout.TERRAIN_WALKABLE
	)

func is_position_environment_hazard(position: Vector2) -> bool:
	if (
		get_terrain_at_world_position(position)
		== BiomeEnvironmentLayout.TERRAIN_HAZARD
	):
		return true
	for hazard in get_tree().get_nodes_in_group("environment_hazards"):
		if hazard.is_in_group("fall_zones"):
			continue
		if _node_contains_position(hazard, position):
			return true
	return false

func is_position_safe(position: Vector2) -> bool:
	if is_position_hazardous(position):
		return false
	for hazard in active_hazards:
		if (
			is_instance_valid(hazard)
			and hazard.has_method("distance_to_zone")
			and float(hazard.distance_to_zone(position))
			< minimum_safe_distance_from_hazard
		):
			return false
	var obstacle_system := get_tree().get_first_node_in_group(
		"obstacle_system"
	)
	return not (
		obstacle_system != null
		and obstacle_system.has_method("is_position_blocked")
		and obstacle_system.is_position_blocked(position)
	)

func create_hazard_instance(
	hazard_id: StringName,
	size: Vector2,
	rotation_radians: float,
	biome: BiomeDefinition,
	layout: BiomeEnvironmentLayout,
	index: int,
	position: Vector2
) -> Node2D:
	if biome == null:
		return null
	var palette := biome.palette
	if palette == null:
		return null
	if hazard_id == &"fall_zone":
		var fall_zone := FALL_ZONE_SCRIPT.new() as BiomeFallZone
		if fall_zone == null:
			return null
		var hazard_side := _hazard_side_for(layout, index, position, size)
		fall_zone.configure(
			hazard_id,
			size,
			rotation_radians,
			palette.hazard_color,
			_fall_style_for_biome(biome.biome_id),
			hazard_side,
			layout.generation_seed + index * 97 if layout != null else index * 97
		)
		fall_zone.body_entered.connect(
			_on_hazard_body_entered.bind(fall_zone)
		)
		return fall_zone
	var hazard_zone := HAZARD_ZONE_SCRIPT.new() as BiomeHazardZone
	if hazard_zone == null:
		return null
	hazard_zone.configure(
		hazard_id,
		size,
		rotation_radians,
		BiomeHazardCatalog.get_color(hazard_id, biome),
		BiomeHazardCatalog.get_config(hazard_id)
	)
	return hazard_zone

func register_streamed_hazard(
	hazard: Node2D,
	hazard_id: StringName
) -> void:
	if hazard == null:
		return
	if not active_hazards.has(hazard):
		active_hazards.append(hazard)
	hazard_spawned.emit(hazard, hazard_id)

func unregister_streamed_hazard(hazard: Node2D) -> void:
	if hazard == null:
		return
	active_hazards.erase(hazard)

func finalize_streamed_hazards() -> void:
	if status_runtime != null:
		status_runtime.process_runtime(0.0, get_tree(), active_hazards)
	_update_safe_positions()

func trigger_fall(player: Node, _hazard: BiomeFallZone = null) -> bool:
	if (
		not is_active
		or player == null
		or not player is Node2D
		or not player.is_in_group("players")
	):
		return false
	var player_id := player.get_instance_id()
	if float(fall_cooldowns.get(player_id, 0.0)) > 0.0:
		return false
	if not is_void_at_world_position((player as Node2D).global_position):
		return false
	var dodge_component := player.get_node_or_null(
		"PlayerDodgeComponent"
	) as PlayerDodgeComponent
	if dodge_component != null and dodge_component.is_dodging:
		return false
	if player.has_method("try_start_void_fall"):
		return bool(player.call("try_start_void_fall"))
	return complete_player_fall(
		player,
		(player as Node2D).global_position
	)

func complete_player_fall(player: Node, fall_position: Vector2) -> bool:
	if (
		not is_active
		or player == null
		or not player is Node2D
		or not player.is_in_group("players")
	):
		return false
	var player_id := player.get_instance_id()
	var health_component := player.get_node_or_null(
		"HealthComponent"
	) as HealthComponent
	if health_component == null or health_component.is_incapacitated():
		return false
	var respawn_position := get_last_safe_position(player)
	var health_system := get_tree().get_first_node_in_group(
		"health_system"
	) as HealthSystem
	if health_system == null:
		return false
	var applied_damage := health_system.apply_damage(
		player,
		fall_damage,
		null,
		&"fall_zone",
		fall_position,
		true
	)
	_respawn_player(player, respawn_position)
	_begin_fall_invulnerability(player, health_component)
	fall_cooldowns[player_id] = fall_retrigger_cooldown
	safe_positions[player_id] = respawn_position
	player_fell.emit(
		player,
		applied_damage,
		fall_position,
		respawn_position
	)
	return true

func _generate_hazards() -> void:
	if active_biome == null:
		return
	var layout := active_biome.environment_layout
	var palette := active_biome.palette
	var allowed_ids := active_biome.hazard_ids
	var container := _get_environment_container()
	if layout == null or palette == null or container == null:
		return
	for index in range(layout.hazard_positions.size()):
		if index >= layout.hazard_ids.size():
			break
		var hazard_id := layout.hazard_ids[index]
		if not allowed_ids.has(hazard_id):
			continue
		var size := (
			layout.hazard_sizes[index]
			if index < layout.hazard_sizes.size()
			else Vector2(150.0, 72.0)
		)
		var rotation_radians := (
			layout.hazard_rotations[index]
			if index < layout.hazard_rotations.size()
			else 0.0
		)
		var hazard_side := _hazard_side_for(layout, index, layout.hazard_positions[index], size)
		var hazard: Node2D
		if hazard_id == &"fall_zone":
			var fall_zone := FALL_ZONE_SCRIPT.new() as BiomeFallZone
			if fall_zone == null:
				continue
			fall_zone.configure(
				hazard_id,
				size,
				rotation_radians,
				palette.hazard_color,
				_fall_style_for_biome(active_biome.biome_id),
				hazard_side,
				layout.generation_seed + index * 97
			)
			fall_zone.body_entered.connect(
				_on_hazard_body_entered.bind(fall_zone)
			)
			hazard = fall_zone
		else:
			var hazard_zone := HAZARD_ZONE_SCRIPT.new() as BiomeHazardZone
			if hazard_zone == null:
				continue
			hazard_zone.configure(
				hazard_id,
				size,
				rotation_radians,
				BiomeHazardCatalog.get_color(hazard_id, active_biome),
				BiomeHazardCatalog.get_config(hazard_id)
			)
			hazard = hazard_zone
		hazard.name = "%s%d" % [
			BiomeHazardCatalog.pascal_case(String(hazard_id)),
			index + 1
		]
		container.add_child(hazard)
		hazard.global_position = layout.hazard_positions[index]
		active_hazards.append(hazard)
		hazard_spawned.emit(hazard, hazard_id)

func _hazard_side_for(
	layout: BiomeEnvironmentLayout,
	index: int,
	position: Vector2,
	size: Vector2
) -> StringName:
	if (
		layout != null
		and index >= 0
		and index < layout.hazard_sides.size()
		and _is_valid_fall_side(layout.hazard_sides[index])
	):
		return layout.hazard_sides[index]
	return _infer_hazard_side(layout, position, size)

func _infer_hazard_side(
	layout: BiomeEnvironmentLayout,
	position: Vector2,
	size: Vector2
) -> StringName:
	if layout == null:
		if size.x >= size.y:
			return &"north"
		return &"west"
	var cell := layout.world_to_logical(position)
	if size.x >= size.y:
		if cell.y < layout.zone_size.y / 2:
			return &"north"
		return &"south"
	if cell.x < layout.zone_size.x / 2:
		return &"west"
	return &"east"

func _is_valid_fall_side(side: StringName) -> bool:
	return [&"north", &"south", &"east", &"west"].has(side)

func _update_safe_positions() -> void:
	for player in get_tree().get_nodes_in_group("players"):
		if not player is Node2D:
			continue
		var health_component := player.get_node_or_null(
			"HealthComponent"
		) as HealthComponent
		if health_component == null or health_component.is_incapacitated():
			continue
		var position := (player as Node2D).global_position
		if not is_position_safe(position):
			continue
		var player_id := player.get_instance_id()
		if (
			not safe_positions.has(player_id)
			or not (safe_positions[player_id] as Vector2).is_equal_approx(
				position
			)
		):
			safe_positions[player_id] = position
			safe_position_updated.emit(player, position)

func _respawn_player(player: Node, position: Vector2) -> void:
	var player_node := player as Node2D
	player_node.global_position = position
	if player is CharacterBody2D:
		(player as CharacterBody2D).velocity = Vector2.ZERO

func _begin_fall_invulnerability(
	player: Node,
	health_component: HealthComponent
) -> void:
	var player_id := player.get_instance_id()
	var source_id := StringName("fall_respawn_%d" % player_id)
	health_component.add_invulnerability_source(source_id)
	invulnerability_timers[player_id] = {
		"player": player,
		"health_component": health_component,
		"source_id": source_id,
		"time_left": fall_respawn_invulnerability
	}

func _tick_fall_cooldowns(delta: float) -> void:
	for player_id in fall_cooldowns.keys():
		var time_left := maxf(
			float(fall_cooldowns[player_id]) - delta,
			0.0
		)
		if time_left <= 0.0:
			fall_cooldowns.erase(player_id)
		else:
			fall_cooldowns[player_id] = time_left

func _tick_invulnerability(delta: float) -> void:
	for player_id in invulnerability_timers.keys():
		var data := invulnerability_timers[player_id] as Dictionary
		var health_component := data.get(
			"health_component"
		) as HealthComponent
		var source_id := StringName(data.get("source_id", &""))
		var time_left := maxf(
			float(data.get("time_left", 0.0)) - delta,
			0.0
		)
		if (
			time_left <= 0.0
			or health_component == null
			or not is_instance_valid(health_component)
		):
			if health_component != null and is_instance_valid(health_component):
				health_component.remove_invulnerability_source(source_id)
			invulnerability_timers.erase(player_id)
		else:
			data["time_left"] = time_left
			invulnerability_timers[player_id] = data

func _resolve_fallback_position(player: Node) -> Vector2:
	var player_slot := int(player.get("player_slot"))
	var player_manager := get_tree().get_first_node_in_group(
		"player_manager"
	) as PlayerManager
	if player_manager != null and not player_manager.spawn_points.is_empty():
		var index := clampi(
			player_slot - 1,
			0,
			player_manager.spawn_points.size() - 1
		)
		var spawn_position := player_manager.spawn_points[index]
		if is_position_safe(spawn_position):
			return spawn_position
	if is_position_safe(Vector2.ZERO):
		return Vector2.ZERO
	for index in range(8):
		var candidate := Vector2.RIGHT.rotated(
			TAU * float(index) / 8.0
		) * 140.0
		if is_position_safe(candidate):
			return candidate
	return Vector2.ZERO

func _fall_style_for_biome(biome_id: StringName) -> StringName:
	match biome_id:
		&"toxic_wastes":
			return &"toxic_cliff"
		&"burning_fields":
			return &"lava_cliff"
		&"frozen_outskirts":
			return &"ice_cliff"
		&"drowned_marsh":
			return &"marsh_cliff"
		_:
			return &"cliff"

func _on_hazard_body_entered(
	body: Node2D,
	hazard: BiomeFallZone
) -> void:
	if body.is_in_group("players"):
		trigger_fall(body, hazard)

func _check_void_entities() -> void:
	for player in get_tree().get_nodes_in_group("players"):
		if (
			player is Node2D
			and is_void_at_world_position((player as Node2D).global_position)
		):
			trigger_fall(player)
	var enemies := get_tree().get_nodes_in_group("enemies")
	var enemy_count := enemies.size()
	if enemy_count == 0:
		_void_scan_cursor = 0
		return
	var slice_size := ceili(float(enemy_count) / float(VOID_CHECK_ENEMY_SLICES))
	for offset in range(mini(slice_size, enemy_count)):
		var enemy = enemies[(_void_scan_cursor + offset) % enemy_count]
		if (
			enemy is Node2D
			and enemy.has_method("try_start_void_fall")
			and is_void_at_world_position((enemy as Node2D).global_position)
		):
			enemy.call("try_start_void_fall")
	_void_scan_cursor = (_void_scan_cursor + slice_size) % enemy_count

func _on_runtime_environment_damaged(
	player: Node,
	hazard_id: StringName,
	damage: int
) -> void:
	player_environment_damaged.emit(player, hazard_id, damage)

func _on_runtime_status_changed(
	player: Node,
	status_ids: Array[StringName]
) -> void:
	player_status_changed.emit(player, status_ids)

func _node_contains_position(node: Node, position: Vector2) -> bool:
	return ObstacleSystem.node_contains_position(node, position)

func _is_position_inside_group(position: Vector2, group_name: StringName) -> bool:
	for node in get_tree().get_nodes_in_group(group_name):
		if _node_contains_position(node, position):
			return true
	return false

func _get_environment_container() -> Node:
	var container := get_node_or_null(environment_container_path)
	return container if container != null else get_tree().current_scene

func _clear_runtime() -> void:
	for data_value in invulnerability_timers.values():
		var data := data_value as Dictionary
		var health_component := data.get(
			"health_component"
		) as HealthComponent
		if health_component != null and is_instance_valid(health_component):
			health_component.remove_invulnerability_source(
				StringName(data.get("source_id", &""))
			)
	if status_runtime != null:
		status_runtime.clear_runtime(get_tree())
	for hazard in active_hazards:
		if is_instance_valid(hazard):
			hazard.queue_free()
	active_hazards.clear()
	safe_positions.clear()
	fall_cooldowns.clear()
	invulnerability_timers.clear()
	safe_update_timer = 0.0

func _prune_hazards() -> void:
	for hazard in active_hazards.duplicate():
		if (
			not is_instance_valid(hazard)
			or hazard.is_queued_for_deletion()
		):
			active_hazards.erase(hazard)
