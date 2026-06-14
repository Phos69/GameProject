extends StaticBody2D
class_name CombatTarget

@onready var visual := $Visual as Polygon2D
@onready var health_bar := $HealthBar as Line2D
@onready var health_component := $HealthComponent as HealthComponent

func _ready() -> void:
	add_to_group("damageable_targets")
	health_component.damaged.connect(_on_health_changed)
	health_component.healed.connect(_on_health_changed)
	health_component.died.connect(_on_died)
	_update_health_bar()

func _on_health_changed(_amount: int, _current_health: int, _max_health: int) -> void:
	_update_health_bar()

func _on_died() -> void:
	collision_layer = 0
	visual.modulate = Color(0.35, 0.35, 0.35, 0.45)
	health_bar.hide()
	queue_free()

func _update_health_bar() -> void:
	var ratio := health_component.get_health_ratio()
	health_bar.points = PackedVector2Array([
		Vector2(-24.0, -32.0),
		Vector2(-24.0 + 48.0 * ratio, -32.0)
	])
	health_bar.default_color = Color(1.0 - ratio, ratio, 0.2, 1.0)
