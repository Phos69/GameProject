extends Resource
class_name SurvivalArenaProfile

@export var arena_id: StringName = &"industrial_crossroads"
@export var display_name: String = "Industrial Crossroads"
@export var layout_kind: StringName = &"crossroads"
@export_range(5, 12) var grid_radius: int = 9
@export var biome: BiomePalette
@export var enemy_spawn_points: Array[Vector2] = []
@export var player_spawn_points: Array[Vector2] = []
@export var crate_spawn_points: Array[Vector2] = []
@export var barrel_positions: Array[Vector2] = []
@export var boss_spawn_position: Vector2 = Vector2(0.0, -220.0)

