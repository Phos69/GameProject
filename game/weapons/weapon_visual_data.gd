extends Resource
class_name WeaponVisualData

@export var profile_id: StringName = &"weapon"
@export var primary_color: Color = Color(0.15, 0.18, 0.22, 1.0)
@export var secondary_color: Color = Color(1.0, 0.72, 0.24, 1.0)
@export var glow_color: Color = Color(1.0, 0.48, 0.12, 0.45)
@export var muzzle_color: Color = Color(1.0, 0.78, 0.24, 1.0)
@export var projectile_color: Color = Color(1.0, 0.78, 0.26, 1.0)
@export var projectile_glow_color: Color = Color(1.0, 0.58, 0.12, 0.28)
@export var projectile_scale: Vector2 = Vector2.ONE
@export var family_id: StringName = &""
@export var held_shape_id: StringName = &""
@export var pickup_shape_id: StringName = &""
@export var hud_shape_id: StringName = &""
@export var projectile_shape_id: StringName = &""
@export var slash_shape_id: StringName = &""
@export var impact_shape_id: StringName = &""
@export var muzzle_shape_id: StringName = &""
@export var impact_vfx_id: StringName = &""
@export var outline_color: Color = Color(1.0, 1.0, 1.0, 0.0)
@export_range(0.0, 1.0, 0.01) var rarity_glow: float = 0.0
@export var pickup_scale: Vector2 = Vector2.ONE
@export var held_scale: Vector2 = Vector2.ONE
@export var pickup_sprite_path: String = ""
@export var held_sprite_path: String = ""
@export var projectile_sprite_path: String = ""
@export var slash_sprite_path: String = ""
@export_range(12.0, 64.0, 1.0) var weapon_length: float = 24.0
@export_range(3.0, 20.0, 1.0) var weapon_width: float = 6.0
@export_range(3.0, 24.0, 1.0) var muzzle_size: float = 7.0
@export_range(4.0, 48.0, 1.0) var trail_length: float = 16.0
@export_range(1.0, 12.0, 0.5) var trail_width: float = 4.0
