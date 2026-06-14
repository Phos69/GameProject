extends Node2D
class_name WeaponSystem

signal fired(origin: Vector2, direction: Vector2, damage: int)
signal fire_blocked(reason: StringName)
signal ammo_changed(current_ammo: int, reserve_ammo: int)
signal reload_started(duration: float)
signal reload_finished()

@export var weapon_data: WeaponData = preload("res://game/weapons/starter_pistol.tres")

var cooldown: float = 0.0
var current_ammo: int = 0
var reserve_ammo: int = 0
var reload_timer: float = 0.0
var is_reloading: bool = false

func _ready() -> void:
	if weapon_data == null:
		return
	current_ammo = weapon_data.magazine_size
	reserve_ammo = weapon_data.starting_reserve_ammo
	ammo_changed.emit(current_ammo, reserve_ammo)

func _process(delta: float) -> void:
	cooldown = maxf(cooldown - delta, 0.0)
	if not is_reloading:
		return

	reload_timer = maxf(reload_timer - delta, 0.0)
	if reload_timer <= 0.0:
		_finish_reload()

func try_fire(origin: Vector2, direction: Vector2, owner_ref: Node = null) -> bool:
	if weapon_data == null:
		fire_blocked.emit(&"no_weapon")
		return false
	if direction.length_squared() <= 0.01:
		fire_blocked.emit(&"no_direction")
		return false
	if is_reloading:
		fire_blocked.emit(&"reloading")
		return false
	if cooldown > 0.0:
		fire_blocked.emit(&"cooldown")
		return false
	if current_ammo < weapon_data.ammo_per_shot:
		fire_blocked.emit(&"empty")
		start_reload()
		return false

	cooldown = 1.0 / maxf(weapon_data.fire_rate, 0.01)
	current_ammo -= weapon_data.ammo_per_shot
	ammo_changed.emit(current_ammo, reserve_ammo)
	var normalized_direction := direction.normalized()
	fired.emit(origin, normalized_direction, weapon_data.damage)

	if weapon_data.projectile_scene != null:
		var projectile_system = get_tree().get_first_node_in_group("projectile_system")
		if projectile_system != null and projectile_system.has_method("spawn_projectile"):
			projectile_system.spawn_projectile(
				origin,
				normalized_direction,
				weapon_data.projectile_speed,
				owner_ref,
				weapon_data.projectile_scene,
				weapon_data.damage,
				weapon_data.weapon_id
			)
		else:
			var projectile := weapon_data.projectile_scene.instantiate()
			if projectile is Node2D:
				(projectile as Node2D).global_position = origin
			if projectile.has_method("launch"):
				projectile.launch(
					normalized_direction,
					weapon_data.projectile_speed,
					owner_ref,
					weapon_data.damage,
					weapon_data.weapon_id
				)
			var root := get_tree().current_scene
			if root != null:
				root.add_child(projectile)

	return true

func start_reload() -> bool:
	if weapon_data == null or is_reloading:
		return false
	if current_ammo >= weapon_data.magazine_size:
		return false
	if not weapon_data.infinite_reserve_ammo and reserve_ammo <= 0:
		return false

	is_reloading = true
	reload_timer = weapon_data.reload_duration
	reload_started.emit(reload_timer)
	if reload_timer <= 0.0:
		_finish_reload()
	return true

func get_ammo_text() -> String:
	if weapon_data == null:
		return "-"
	var reserve_text := "INF" if weapon_data.infinite_reserve_ammo else str(reserve_ammo)
	var suffix := " R" if is_reloading else ""
	return "%d/%s%s" % [current_ammo, reserve_text, suffix]

func _finish_reload() -> void:
	if weapon_data == null:
		is_reloading = false
		return

	var required_ammo := weapon_data.magazine_size - current_ammo
	var loaded_ammo := required_ammo
	if not weapon_data.infinite_reserve_ammo:
		loaded_ammo = mini(required_ammo, reserve_ammo)
		reserve_ammo -= loaded_ammo

	current_ammo += loaded_ammo
	is_reloading = false
	reload_timer = 0.0
	ammo_changed.emit(current_ammo, reserve_ammo)
	reload_finished.emit()
