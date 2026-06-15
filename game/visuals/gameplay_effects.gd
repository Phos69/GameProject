extends Node2D
class_name GameplayEffects

var effect_spawn_count: int = 0

func _ready() -> void:
	add_to_group("gameplay_effects")
	call_deferred("_connect_systems")

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
		angle
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
		0.22
	)

func _on_enemy_died(enemy: Node) -> void:
	if not enemy is Node2D:
		return
	_spawn_effect(
		&"death",
		(enemy as Node2D).global_position,
		Color(0.55, 0.82, 0.34, 1.0),
		30.0,
		0.42
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
		0.34
	)

func spawn_boss_death(position: Vector2) -> GameplayEffect:
	return _spawn_effect(
		&"boss_death",
		position,
		Color(0.96, 0.24, 0.72, 1.0),
		82.0,
		0.78
	)

func _spawn_effect(
	kind: StringName,
	position: Vector2,
	color: Color,
	size: float,
	lifetime: float,
	angle: float = 0.0
) -> GameplayEffect:
	var effect := GameplayEffect.new()
	effect.global_position = position
	effect.configure(kind, color, size, lifetime, angle)
	add_child(effect)
	effect_spawn_count += 1
	return effect

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
