extends Node2D
class_name TowerDefenseArena

@export var path_points: PackedVector2Array = PackedVector2Array([
	Vector2(-540.0, -210.0),
	Vector2(-320.0, -210.0),
	Vector2(-180.0, 80.0),
	Vector2(80.0, 80.0),
	Vector2(220.0, -150.0),
	Vector2(500.0, -150.0)
])
@export var player_spawn_position: Vector2 = Vector2(-40.0, 260.0)

@onready var path_line := $PathLine as Line2D
@onready var core_visual := $Core as Polygon2D
@onready var base_health_bar := $BaseHealthBar as Line2D

func _ready() -> void:
	path_line.points = path_points

func configure(manager: TowerDefenseManager) -> void:
	if manager == null:
		return
	var callback := Callable(self, "_on_base_health_changed")
	if not manager.base_health_changed.is_connected(callback):
		manager.base_health_changed.connect(callback)
	_on_base_health_changed(manager.base_health, manager.base_max_health)

func get_world_path_points() -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in path_points:
		result.append(to_global(point))
	return result

func get_build_slots() -> Array[TowerBuildSlot]:
	var result: Array[TowerBuildSlot] = []
	for child in $BuildSlots.get_children():
		if child is TowerBuildSlot:
			result.append(child as TowerBuildSlot)
	return result

func _on_base_health_changed(current_health: int, max_health: int) -> void:
	var ratio := 0.0
	if max_health > 0:
		ratio = float(current_health) / float(max_health)
	base_health_bar.points = PackedVector2Array([
		Vector2(456.0, -205.0),
		Vector2(456.0 + 88.0 * ratio, -205.0)
	])
	base_health_bar.default_color = Color(1.0 - ratio, ratio, 0.18, 1.0)
	core_visual.color = Color(0.25 + 0.55 * (1.0 - ratio), 0.72 * ratio, 0.95 * ratio, 1.0)
