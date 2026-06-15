extends Resource
class_name WeaponData

@export var weapon_id: StringName = &"weapon"
@export var display_name: String = "Weapon"
@export_range(1, 1000) var damage: int = 10
@export_range(0.1, 30.0, 0.1) var fire_rate: float = 5.0
@export_range(1.0, 2000.0, 1.0) var projectile_speed: float = 600.0
@export_range(1, 999) var magazine_size: int = 12
@export_range(0, 9999) var starting_reserve_ammo: int = 36
@export_range(1, 100) var ammo_per_shot: int = 1
@export_range(0.0, 10.0, 0.05) var reload_duration: float = 1.0
@export var infinite_reserve_ammo: bool = false
@export var projectile_scene: PackedScene
@export var visual_data: WeaponVisualData
