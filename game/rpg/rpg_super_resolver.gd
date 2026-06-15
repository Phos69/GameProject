extends RefCounted
class_name RpgSuperResolver

const ARROW_RAIN_PROJECTILE_COUNT: int = 12
const ARROW_RAIN_SPREAD_RADIANS: float = 0.70
const ARROW_RAIN_DAMAGE_MULTIPLIER: float = 0.70
const FINAL_BARRAGE_RANGE: float = 620.0
const FINAL_BARRAGE_DAMAGE_MULTIPLIER: float = 0.85
const BLOOD_QUAKE_RADIUS: float = 155.0
const BLOOD_QUAKE_DAMAGE_MULTIPLIER: float = 2.10
const PHANTOM_BLADE_DISTANCE: float = 180.0
const PHANTOM_BLADE_WIDTH: float = 62.0
const PHANTOM_BLADE_DAMAGE_MULTIPLIER: float = 1.65

static func execute_arrow_rain(
	component: RpgPlayerComponent,
	player: Node2D,
	direction: Vector2
) -> bool:
	var projectile_system := _get_projectile_system(player)
	var weapon_data := _get_weapon_data(player)
	if projectile_system == null or weapon_data == null:
		return false
	var base_direction := _resolve_direction(direction)
	var side := base_direction.orthogonal()
	var origin := player.global_position + base_direction * 28.0
	var center := float(ARROW_RAIN_PROJECTILE_COUNT - 1) * 0.5
	var damage := maxi(
		1,
		roundi(float(weapon_data.damage) * ARROW_RAIN_DAMAGE_MULTIPLIER)
	)
	for index in range(ARROW_RAIN_PROJECTILE_COUNT):
		var ratio := (float(index) - center) / maxf(center, 1.0)
		var projectile_direction := base_direction.rotated(
			ratio * ARROW_RAIN_SPREAD_RADIANS
		)
		projectile_system.spawn_projectile(
			origin + side * ratio * 26.0,
			projectile_direction,
			weapon_data.projectile_speed * 0.95,
			player,
			weapon_data.projectile_scene,
			damage,
			component.get_super_id(),
			weapon_data.visual_data,
			maxf(weapon_data.max_range, 620.0),
			weapon_data.hitbox_type,
			weapon_data.hitbox_size,
			weapon_data.max_hit_count
		)
	return true

static func fire_final_barrage_shot(
	component: RpgPlayerComponent,
	player: Node2D
) -> bool:
	var projectile_system := _get_projectile_system(player)
	var weapon_data := _get_weapon_data(player)
	var target := _find_nearest_target(player, FINAL_BARRAGE_RANGE)
	if projectile_system == null or weapon_data == null or target == null:
		return false
	var direction := player.global_position.direction_to(target.global_position)
	var damage := maxi(
		1,
		roundi(float(weapon_data.damage) * FINAL_BARRAGE_DAMAGE_MULTIPLIER)
	)
	projectile_system.spawn_projectile(
		player.global_position + direction * 28.0,
		direction,
		weapon_data.projectile_speed * 1.10,
		player,
		weapon_data.projectile_scene,
		damage,
		component.get_super_id(),
		weapon_data.visual_data,
		maxf(weapon_data.max_range, FINAL_BARRAGE_RANGE),
		weapon_data.hitbox_type,
		weapon_data.hitbox_size,
		weapon_data.max_hit_count
	)
	return true

static func execute_blood_quake(
	component: RpgPlayerComponent,
	player: Node2D
) -> bool:
	var health_system := _get_health_system(player)
	if health_system == null:
		return false
	var damage := maxi(
		1,
		roundi(float(component.get_current_weapon_damage()) * BLOOD_QUAKE_DAMAGE_MULTIPLIER)
	)
	for target in _find_targets_in_radius(player, BLOOD_QUAKE_RADIUS):
		health_system.apply_damage(
			target,
			damage,
			player,
			component.get_super_id(),
			(target as Node2D).global_position
		)
	return true

static func execute_phantom_blade(
	component: RpgPlayerComponent,
	player: Node2D,
	direction: Vector2
) -> bool:
	var health_system := _get_health_system(player)
	if health_system == null:
		return false
	var base_direction := _resolve_direction(direction)
	var start_position := player.global_position
	var end_position := start_position + base_direction * PHANTOM_BLADE_DISTANCE
	var damage := maxi(
		1,
		roundi(float(component.get_current_weapon_damage()) * PHANTOM_BLADE_DAMAGE_MULTIPLIER)
	)
	player.global_position = end_position
	for target in _find_targets_in_segment(
		player,
		start_position,
		end_position,
		PHANTOM_BLADE_WIDTH
	):
		health_system.apply_damage(
			target,
			damage,
			player,
			component.get_super_id(),
			(target as Node2D).global_position
		)
	return true

static func _get_weapon_data(player: Node) -> WeaponData:
	var weapon_system := player.get_node_or_null("WeaponSystem") as WeaponSystem
	if weapon_system == null:
		return null
	return weapon_system.weapon_data

static func _get_projectile_system(player: Node) -> ProjectileSystem:
	return player.get_tree().get_first_node_in_group(
		"projectile_system"
	) as ProjectileSystem

static func _get_health_system(player: Node) -> HealthSystem:
	return player.get_tree().get_first_node_in_group(
		"health_system"
	) as HealthSystem

static func _resolve_direction(direction: Vector2) -> Vector2:
	if direction.length_squared() <= 0.01:
		return Vector2.RIGHT
	return direction.normalized()

static func _find_nearest_target(player: Node2D, max_distance: float) -> Node2D:
	var nearest_target: Node2D
	var nearest_distance := max_distance
	for target in _get_damageable_targets(player):
		var distance := player.global_position.distance_to(target.global_position)
		if distance <= nearest_distance:
			nearest_distance = distance
			nearest_target = target
	return nearest_target

static func _find_targets_in_radius(
	player: Node2D,
	radius: float
) -> Array[Node2D]:
	var targets: Array[Node2D] = []
	for target in _get_damageable_targets(player):
		if player.global_position.distance_to(target.global_position) <= radius:
			targets.append(target)
	return targets

static func _find_targets_in_segment(
	player: Node2D,
	start_position: Vector2,
	end_position: Vector2,
	width: float
) -> Array[Node2D]:
	var targets: Array[Node2D] = []
	var segment := end_position - start_position
	var segment_length_squared := maxf(segment.length_squared(), 1.0)
	for target in _get_damageable_targets(player):
		var to_target := target.global_position - start_position
		var projection := clampf(
			to_target.dot(segment) / segment_length_squared,
			0.0,
			1.0
		)
		var closest_point := start_position + segment * projection
		if closest_point.distance_to(target.global_position) <= width:
			targets.append(target)
	return targets

static func _get_damageable_targets(player: Node2D) -> Array[Node2D]:
	var targets: Array[Node2D] = []
	for candidate in player.get_tree().get_nodes_in_group("damageable_targets"):
		if (
			candidate == player
			or not (candidate is Node2D)
			or not is_instance_valid(candidate)
			or candidate.is_queued_for_deletion()
		):
			continue
		var health_component := candidate.get_node_or_null(
			"HealthComponent"
		) as HealthComponent
		if health_component == null or not health_component.is_alive():
			continue
		targets.append(candidate as Node2D)
	return targets
