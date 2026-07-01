extends Resource
class_name BiomeEnemyProfile

@export var enemy_id: StringName = &"toxic_zombie"
@export var display_name: String = "Thematic Zombie"
@export_enum("basic", "runner", "tank", "shooter") var visual_archetype: String = "basic"
@export var theme_id: StringName = &"toxic"

## AI level for pathfinding: 0 = avoid obstacles only (may fall into pits),
## 1 = also avoid pits (void / fall zones). Higher levels reserved for future.
@export_range(0, 3, 1) var ai_level: int = 0

@export_range(1, 999, 1) var max_health: int = 30
@export_range(20.0, 300.0, 1.0) var move_speed: float = 95.0
@export_range(100.0, 1600.0, 10.0) var acceleration: float = 650.0
@export_range(20.0, 100.0, 1.0) var attack_range: float = 42.0
@export_range(1, 100, 1) var attack_damage: int = 8
@export_range(0.2, 3.0, 0.05) var attack_cooldown: float = 0.85
@export_range(1, 100, 1) var kill_experience: int = 7
@export_range(0.2, 2.0, 0.05) var incoming_damage_multiplier: float = 1.0

@export var contact_status_id: StringName = &""
@export_range(0.0, 10.0, 0.1) var contact_status_duration: float = 0.0
@export_range(0.25, 1.25, 0.05) var contact_movement_multiplier: float = 1.0
@export_range(0, 50, 1) var contact_damage_per_tick: int = 0
@export var death_hazard_id: StringName = &""
@export_range(0.0, 10.0, 0.1) var death_hazard_duration: float = 0.0
@export_range(24.0, 180.0, 2.0) var death_hazard_radius: float = 68.0
@export_range(0.0, 3.0, 0.05) var emerge_duration: float = 0.0
