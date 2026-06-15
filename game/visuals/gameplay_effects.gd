extends Node2D
class_name GameplayEffects

var effect_spawn_count: int = 0
var flash_intensity: float = 1.0
var glow_intensity: float = 1.0
var reduced_motion: bool = false

func _ready() -> void:
	add_to_group("gameplay_effects")
	add_to_group("visual_settings_consumers")
	VisualSettingsManager.sync_consumer(self)
	call_deferred("_connect_systems")

func apply_visual_settings(settings: Dictionary) -> void:
	flash_intensity = clampf(
		float(settings.get("flash_intensity", 1.0)),
		0.0,
		1.0
	)
	glow_intensity = clampf(
		float(settings.get("glow_intensity", 1.0)),
		0.0,
		1.0
	)
	reduced_motion = bool(settings.get("reduced_motion", false))

func _connect_systems() -> void:
	var projectile_system := get_tree().get_first_node_in_group(
		"projectile_system"
	) as ProjectileSystem
	if projectile_system != null:
		var spawn_callback := Callable(self, "_on_projectile_spawned")
		if not projectile_system.projectile_spawned.is_connected(spawn_callback):
			projectile_system.projectile_spawned.connect(spawn_callback)
		var impact_callback := Callable(self, "_on_projectile_impacted")
		if not projectile_system.projectile_impacted.is_connected(impact_callback):
			projectile_system.projectile_impacted.connect(impact_callback)

	var enemy_system := get_tree().get_first_node_in_group("enemy_system") as EnemySystem
	if enemy_system != null:
		var death_callback := Callable(self, "_on_enemy_died")
		if not enemy_system.enemy_died.is_connected(death_callback):
			enemy_system.enemy_died.connect(death_callback)

	var drop_system := get_tree().get_first_node_in_group("drop_system") as DropSystem
	if drop_system != null:
		var pickup_callback := Callable(self, "_on_drop_collected")
		if not drop_system.drop_collected.is_connected(pickup_callback):
			drop_system.drop_collected.connect(pickup_callback)

	var hazard_system := get_tree().get_first_node_in_group(
		"hazard_system"
	) as HazardSystem
	if hazard_system != null:
		var fall_callback := Callable(self, "_on_player_fell")
		if not hazard_system.player_fell.is_connected(fall_callback):
			hazard_system.player_fell.connect(fall_callback)
		var damage_callback := Callable(
			self,
			"_on_environment_damage"
		)
		if not hazard_system.player_environment_damaged.is_connected(
			damage_callback
		):
			hazard_system.player_environment_damaged.connect(
				damage_callback
			)

	var player_manager := get_tree().get_first_node_in_group(
		"player_manager"
	) as PlayerManager
	if player_manager != null:
		var player_spawned_callback := Callable(self, "_on_player_spawned")
		if not player_manager.player_spawned.is_connected(
			player_spawned_callback
		):
			player_manager.player_spawned.connect(player_spawned_callback)
	for player in get_tree().get_nodes_in_group("players"):
		_connect_rpg_feedback(player)

func _on_projectile_spawned(projectile: Node) -> void:
	if not projectile is Projectile:
		return
	var typed_projectile := projectile as Projectile
	var color := typed_projectile.get_muzzle_color()
	var angle := typed_projectile.velocity.angle()
	_spawn_effect(
		&"muzzle",
		typed_projectile.global_position,
		color,
		typed_projectile.get_muzzle_size() * 2.2,
		0.10,
		angle,
		flash_intensity
	)

func _on_projectile_impacted(
	projectile: Node,
	target: Node,
	applied_damage: int
) -> void:
	if applied_damage <= 0:
		return
	var position := Vector2.ZERO
	if projectile is Node2D:
		position = (projectile as Node2D).global_position
	elif target is Node2D:
		position = (target as Node2D).global_position
	_spawn_effect(
		&"hit",
		position,
		Color(1.0, 0.42, 0.24, 1.0),
		20.0,
		0.22,
		0.0,
		flash_intensity
	)
	_request_camera_shake(1.5, 0.08)

func _on_enemy_died(enemy: Node) -> void:
	if not enemy is Node2D:
		return
	_spawn_effect(
		&"death",
		(enemy as Node2D).global_position,
		Color(0.55, 0.82, 0.34, 1.0),
		30.0,
		0.42,
		0.0,
		glow_intensity
	)

func _on_drop_collected(drop_data: Dictionary, collector: Node) -> void:
	if not collector is Node2D:
		return
	var drop_type := StringName(drop_data.get("type", &"unknown"))
	_spawn_effect(
		&"pickup",
		(collector as Node2D).global_position,
		_color_for_drop(drop_type),
		24.0,
		0.34,
		0.0,
		glow_intensity
	)

func spawn_boss_death(position: Vector2) -> GameplayEffect:
	var effect := _spawn_effect(
		&"boss_death",
		position,
		Color(0.96, 0.24, 0.72, 1.0),
		82.0,
		0.78,
		0.0,
		glow_intensity
	)
	_request_camera_shake(8.0, 0.45)
	return effect

func spawn_environment_explosion(
	position: Vector2,
	color: Color,
	radius: float
) -> GameplayEffect:
	var effect := _spawn_effect(
		&"environment_explosion",
		position,
		color,
		radius,
		0.62,
		0.0,
		glow_intensity
	)
	_request_camera_shake(10.0, 0.50)
	return effect

func spawn_fall_feedback(
	fall_position: Vector2,
	respawn_position: Vector2
) -> Array[GameplayEffect]:
	var effects: Array[GameplayEffect] = []
	effects.append(_spawn_effect(
		&"fall_damage",
		fall_position,
		Color(0.96, 0.22, 0.16, 1.0),
		48.0,
		0.48,
		0.0,
		flash_intensity
	))
	effects.append(_spawn_effect(
		&"fall_respawn",
		respawn_position,
		Color(0.34, 0.82, 1.0, 1.0),
		42.0,
		0.52,
		0.0,
		glow_intensity
	))
	_request_camera_shake(5.0, 0.24)
	return effects

func spawn_environment_damage(
	position: Vector2,
	hazard_id: StringName
) -> GameplayEffect:
	var color := Color(0.82, 0.28, 0.16, 1.0)
	match hazard_id:
		&"poisoned", &"toxic_puddle", &"gas_cloud", &"toxic_cloud":
			color = Color(0.30, 1.0, 0.42, 1.0)
		&"burning", &"fire_zone", &"lava_crack", &"fire_patch":
			color = Color(1.0, 0.30, 0.08, 1.0)
		&"chilled", &"slippery_ice", &"deep_snow_slow":
			color = Color(0.54, 0.90, 1.0, 1.0)
		&"mudded", &"soaked", &"mud_slow", &"deep_water":
			color = Color(0.18, 0.68, 0.64, 1.0)
	return _spawn_effect(
		&"environment_damage",
		position,
		color,
		30.0,
		0.34,
		0.0,
		flash_intensity
	)

func spawn_rpg_level_up(position: Vector2) -> GameplayEffect:
	var effect := _spawn_effect(
		&"rpg_level_up",
		position,
		Color(0.34, 0.78, 1.0, 1.0),
		46.0,
		0.58,
		0.0,
		glow_intensity
	)
	_request_camera_shake(2.5, 0.14)
	return effect

func spawn_rpg_super(position: Vector2, super_id: StringName) -> GameplayEffect:
	var effect := _spawn_effect(
		&"rpg_super",
		position,
		_color_for_super(super_id),
		62.0,
		0.64,
		0.0,
		glow_intensity
	)
	_request_camera_shake(4.5, 0.20)
	return effect

func _spawn_effect(
	kind: StringName,
	position: Vector2,
	color: Color,
	size: float,
	lifetime: float,
	angle: float = 0.0,
	intensity: float = 1.0
) -> GameplayEffect:
	var effect := GameplayEffect.new()
	effect.global_position = position
	effect.configure(
		kind,
		color,
		size,
		lifetime,
		angle,
		intensity,
		reduced_motion
	)
	add_child(effect)
	effect_spawn_count += 1
	return effect

func _request_camera_shake(strength: float, duration: float) -> void:
	var camera := get_viewport().get_camera_2d() as IsometricCameraController
	if camera != null:
		camera.request_shake(strength, duration)

func _color_for_drop(drop_type: StringName) -> Color:
	match drop_type:
		GameConstants.DROP_EXPERIENCE:
			return Color(0.32, 0.72, 1.0, 1.0)
		GameConstants.DROP_MONEY:
			return Color(1.0, 0.76, 0.18, 1.0)
		GameConstants.DROP_AMMO:
			return Color(1.0, 0.42, 0.16, 1.0)
		GameConstants.DROP_HEALTH:
			return Color(0.30, 0.92, 0.48, 1.0)
		GameConstants.DROP_WEAPON:
			return Color(0.76, 0.38, 1.0, 1.0)
		_:
			return Color.WHITE

func _connect_rpg_feedback(player: Node) -> void:
	var rpg_component := player.get_node_or_null(
		"RpgPlayerComponent"
	) as RpgPlayerComponent
	if rpg_component == null:
		return
	var level_callback := Callable(self, "_on_rpg_leveled_up").bind(player)
	if not rpg_component.leveled_up.is_connected(level_callback):
		rpg_component.leveled_up.connect(level_callback)
	var super_callback := Callable(self, "_on_rpg_super_activated").bind(player)
	if not rpg_component.super_activated.is_connected(super_callback):
		rpg_component.super_activated.connect(super_callback)

func _on_player_spawned(_player_slot: int, player: Node) -> void:
	_connect_rpg_feedback(player)

func _on_player_fell(
	_player: Node,
	_damage: int,
	fall_position: Vector2,
	respawn_position: Vector2
) -> void:
	spawn_fall_feedback(fall_position, respawn_position)

func _on_environment_damage(
	player: Node,
	hazard_id: StringName,
	_damage: int
) -> void:
	if player is Node2D:
		spawn_environment_damage(
			(player as Node2D).global_position,
			hazard_id
		)

func _on_rpg_leveled_up(_level: int, player: Node) -> void:
	if player is Node2D:
		spawn_rpg_level_up((player as Node2D).global_position)

func _on_rpg_super_activated(
	super_id: StringName,
	_super_name: String,
	player: Node
) -> void:
	if player is Node2D:
		spawn_rpg_super((player as Node2D).global_position, super_id)

func _color_for_super(super_id: StringName) -> Color:
	match super_id:
		&"arrow_rain":
			return Color(0.36, 0.84, 1.0, 1.0)
		&"final_barrage":
			return Color(1.0, 0.72, 0.24, 1.0)
		&"blood_quake":
			return Color(1.0, 0.24, 0.18, 1.0)
		&"phantom_blade":
			return Color(0.62, 0.76, 1.0, 1.0)
		_:
			return Color(0.70, 1.0, 0.74, 1.0)
