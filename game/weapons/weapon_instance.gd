extends RefCounted
class_name WeaponInstance

var definition: WeaponData
var current_ammo: int = 0
var reserve_ammo: int = 0
var reload_timer: float = 0.0
var reload_duration: float = 0.0
var is_reloading: bool = false
var cooldown: float = 0.0
var charge_time: float = 0.0
var temporary_state: Dictionary = {}

func _init(weapon_definition: WeaponData = null) -> void:
	definition = weapon_definition
	if definition != null:
		current_ammo = definition.magazine_size
		reserve_ammo = definition.starting_reserve_ammo

func get_weapon_id() -> StringName:
	return definition.weapon_id if definition != null else &""

func tick(delta: float) -> bool:
	cooldown = maxf(cooldown - delta, 0.0)
	if not is_reloading:
		return false
	reload_timer = maxf(reload_timer - delta, 0.0)
	if reload_timer > 0.0:
		return false
	finish_reload()
	return true

func begin_reload(duration: float) -> bool:
	if definition == null or is_reloading:
		return false
	if current_ammo >= definition.magazine_size:
		return false
	if not definition.infinite_reserve_ammo and reserve_ammo <= 0:
		return false
	is_reloading = true
	reload_duration = maxf(duration, 0.0)
	reload_timer = reload_duration
	if reload_timer <= 0.0:
		finish_reload()
	return true

func finish_reload() -> void:
	if definition == null:
		is_reloading = false
		reload_timer = 0.0
		return
	var required_ammo := definition.magazine_size - current_ammo
	var loaded_ammo := required_ammo
	if not definition.infinite_reserve_ammo:
		loaded_ammo = mini(required_ammo, reserve_ammo)
		reserve_ammo -= loaded_ammo
	current_ammo += loaded_ammo
	is_reloading = false
	reload_timer = 0.0

func get_reload_ratio() -> float:
	if not is_reloading:
		return 0.0
	return clampf(1.0 - reload_timer / maxf(reload_duration, 0.01), 0.0, 1.0)
