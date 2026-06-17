extends Resource
class_name WeaponData

@export var weapon_id: StringName = &"weapon"
@export var display_name: String = "Weapon"
@export_range(1, 1000) var damage: int = 10
@export_range(0.1, 30.0, 0.1) var fire_rate: float = 5.0
@export_range(1.0, 2000.0, 1.0) var projectile_speed: float = 600.0
@export_range(0.0, 3000.0, 1.0) var max_range: float = 0.0
@export_range(0.0, 45.0, 0.1) var scatter_degrees: float = 0.0
@export var attack_type: StringName = &"projectile"
@export var hitbox_type: StringName = &"circle"
@export var hitbox_size: Vector2 = Vector2(8.0, 8.0)
@export_range(1, 16) var max_hit_count: int = 1
@export var melee_shape: StringName = &""
@export_range(0.0, 360.0, 1.0) var melee_arc_degrees: float = 90.0
@export_range(0.0, 400.0, 1.0) var melee_range: float = 0.0
@export_range(0.0, 240.0, 1.0) var melee_width: float = 0.0
@export_range(0.0, 2.0, 0.01) var windup_time: float = 0.0
@export_range(0.01, 2.0, 0.01) var active_time: float = 0.08
@export_range(0.0, 2.0, 0.01) var recovery_time: float = 0.0
@export_range(0.0, 600.0, 1.0) var knockback: float = 0.0
@export_range(0.0, 0.20, 0.01) var hitstop: float = 0.0
@export var trail_style: StringName = &""
@export var effect_key: StringName = &""
@export var sound_key: StringName = &""
@export_range(1, 999) var magazine_size: int = 12
@export_range(0, 9999) var starting_reserve_ammo: int = 36
@export_range(1, 100) var ammo_per_shot: int = 1
@export_range(0.0, 10.0, 0.05) var reload_duration: float = 1.0
@export var infinite_reserve_ammo: bool = false
@export var projectile_scene: PackedScene
@export var visual_data: WeaponVisualData

func uses_projectile_attack() -> bool:
	return attack_type == &"projectile"

func uses_melee_attack() -> bool:
	return (
		attack_type == &"melee_arc"
		or attack_type == &"melee_rect"
		or attack_type == &"melee_sweep"
		or attack_type == &"dash_slash"
	)

func get_resolved_melee_shape() -> StringName:
	if not melee_shape.is_empty():
		return melee_shape
	if attack_type == &"melee_arc":
		return &"arc"
	if attack_type == &"melee_rect" or attack_type == &"melee_sweep":
		return &"rectangle"
	if attack_type == &"dash_slash":
		return &"dash"
	return hitbox_type

func get_resolved_melee_range() -> float:
	if melee_range > 0.0:
		return melee_range
	if max_range > 0.0:
		return max_range
	return maxf(hitbox_size.x, 1.0)

func get_resolved_melee_width() -> float:
	if melee_width > 0.0:
		return melee_width
	if hitbox_size.y > 0.0:
		return hitbox_size.y
	return maxf(hitbox_size.x, 1.0)
