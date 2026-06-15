extends Node2D
class_name WeaponSystem

signal fired(origin: Vector2, direction: Vector2, damage: int)
signal fire_blocked(reason: StringName)
signal ammo_changed(current_ammo: int, reserve_ammo: int)
signal reload_started(duration: float)
signal reload_finished()
signal weapon_changed(weapon_data: WeaponData)
signal low_ammo_changed(is_low: bool, total_ammo: int)
signal fallback_activated(weapon_data: WeaponData)
signal special_weapon_activated(weapon_data: WeaponData)

@export var weapon_data: WeaponData = preload("res://game/weapons/starter_pistol.tres")
@export var fallback_weapon_data: WeaponData = preload(
	"res://game/weapons/starter_pistol.tres"
)
@export_range(0, 999) var low_ammo_threshold: int = 8

var cooldown: float = 0.0
var current_ammo: int = 0
var reserve_ammo: int = 0
var reload_timer: float = 0.0
var is_reloading: bool = false
var special_weapon_data: WeaponData
var special_current_ammo: int = 0
var special_reserve_ammo: int = 0
var fallback_current_ammo: int = 0
var low_ammo_active: bool = false

func _ready() -> void:
	_initialize_loadout()

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
		if start_reload():
			fire_blocked.emit(&"reload_started")
			return false
		if not is_fallback_active() and _activate_fallback_weapon():
			if current_ammo < weapon_data.ammo_per_shot:
				start_reload()
				fire_blocked.emit(&"fallback_reloading")
				return false
		else:
			fire_blocked.emit(&"empty")
			return false

	cooldown = 1.0 / maxf(weapon_data.fire_rate, 0.01)
	current_ammo -= weapon_data.ammo_per_shot
	_store_active_ammo()
	ammo_changed.emit(current_ammo, reserve_ammo)
	_refresh_low_ammo_state()
	var normalized_direction := _apply_weapon_scatter(direction.normalized())
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
				weapon_data.weapon_id,
				weapon_data.visual_data,
				weapon_data.max_range,
				weapon_data.hitbox_type,
				weapon_data.hitbox_size,
				weapon_data.max_hit_count
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
					weapon_data.weapon_id,
					weapon_data.visual_data,
					weapon_data.max_range,
					weapon_data.hitbox_type,
					weapon_data.hitbox_size,
					weapon_data.max_hit_count
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
	var tags := PackedStringArray()
	if is_reloading:
		tags.append("RELOAD")
	if is_fallback_active() and special_weapon_data != null:
		tags.append("FALLBACK")
	elif low_ammo_active:
		tags.append("LOW")
	var suffix := " " + " ".join(tags) if not tags.is_empty() else ""
	return "%d/%s%s" % [current_ammo, reserve_text, suffix]

func add_reserve_ammo(amount: int) -> int:
	if special_weapon_data == null or amount <= 0:
		return 0
	if is_fallback_active():
		special_reserve_ammo += amount
		_activate_special_weapon()
		start_reload()
	else:
		reserve_ammo += amount
		_store_active_ammo()
		ammo_changed.emit(current_ammo, reserve_ammo)
	_refresh_low_ammo_state()
	return amount

func equip_weapon(new_weapon_data: WeaponData) -> bool:
	if new_weapon_data == null:
		return false
	_store_active_ammo()
	if new_weapon_data.infinite_reserve_ammo:
		fallback_weapon_data = new_weapon_data
		fallback_current_ammo = new_weapon_data.magazine_size
		_activate_fallback_weapon()
		return true

	special_weapon_data = new_weapon_data
	special_current_ammo = new_weapon_data.magazine_size
	special_reserve_ammo = new_weapon_data.starting_reserve_ammo
	_activate_special_weapon()
	return true

func has_special_weapon() -> bool:
	return special_weapon_data != null

func is_fallback_active() -> bool:
	return (
		weapon_data != null
		and fallback_weapon_data != null
		and weapon_data.weapon_id == fallback_weapon_data.weapon_id
	)

func get_special_ammo_total() -> int:
	if special_weapon_data == null:
		return -1
	if is_fallback_active():
		return special_current_ammo + special_reserve_ammo
	return current_ammo + reserve_ammo

func is_special_ammo_low(threshold: int = -1) -> bool:
	if special_weapon_data == null:
		return false
	var resolved_threshold := low_ammo_threshold if threshold < 0 else threshold
	return get_special_ammo_total() <= maxi(resolved_threshold, 0)

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
	_store_active_ammo()
	ammo_changed.emit(current_ammo, reserve_ammo)
	_refresh_low_ammo_state()
	reload_finished.emit()

func _initialize_loadout() -> void:
	var initial_weapon_data := weapon_data
	if fallback_weapon_data == null and weapon_data != null:
		fallback_weapon_data = weapon_data
	if fallback_weapon_data != null:
		fallback_current_ammo = fallback_weapon_data.magazine_size

	if (
		initial_weapon_data != null
		and not initial_weapon_data.infinite_reserve_ammo
		and (
			fallback_weapon_data == null
			or initial_weapon_data.weapon_id != fallback_weapon_data.weapon_id
		)
	):
		special_weapon_data = initial_weapon_data
		special_current_ammo = initial_weapon_data.magazine_size
		special_reserve_ammo = initial_weapon_data.starting_reserve_ammo
		weapon_data = null
		_activate_special_weapon()
		return
	weapon_data = null
	_activate_fallback_weapon()

func _activate_fallback_weapon() -> bool:
	if fallback_weapon_data == null:
		return false
	_store_active_ammo()
	weapon_data = fallback_weapon_data
	current_ammo = fallback_current_ammo
	reserve_ammo = 0
	_cancel_reload()
	cooldown = 0.0
	ammo_changed.emit(current_ammo, reserve_ammo)
	weapon_changed.emit(weapon_data)
	fallback_activated.emit(weapon_data)
	_refresh_low_ammo_state()
	return true

func _activate_special_weapon() -> bool:
	if special_weapon_data == null:
		return false
	_store_active_ammo()
	weapon_data = special_weapon_data
	current_ammo = special_current_ammo
	reserve_ammo = special_reserve_ammo
	_cancel_reload()
	cooldown = 0.0
	ammo_changed.emit(current_ammo, reserve_ammo)
	weapon_changed.emit(weapon_data)
	special_weapon_activated.emit(weapon_data)
	_refresh_low_ammo_state()
	return true

func _store_active_ammo() -> void:
	if weapon_data == null:
		return
	if is_fallback_active():
		fallback_current_ammo = current_ammo
	elif special_weapon_data != null and weapon_data.weapon_id == special_weapon_data.weapon_id:
		special_current_ammo = current_ammo
		special_reserve_ammo = reserve_ammo

func _cancel_reload() -> void:
	is_reloading = false
	reload_timer = 0.0

func _refresh_low_ammo_state() -> void:
	var is_low := is_special_ammo_low()
	if is_low == low_ammo_active:
		return
	low_ammo_active = is_low
	low_ammo_changed.emit(low_ammo_active, maxi(get_special_ammo_total(), 0))

func _apply_weapon_scatter(direction: Vector2) -> Vector2:
	if weapon_data == null or weapon_data.scatter_degrees <= 0.0:
		return direction
	var scatter_radians := deg_to_rad(weapon_data.scatter_degrees)
	return direction.rotated(randf_range(-scatter_radians, scatter_radians))
