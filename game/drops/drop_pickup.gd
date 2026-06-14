extends Area2D
class_name DropPickup

@onready var visual := $Visual as Polygon2D
@onready var label := $Label as Label

var drop_data: Dictionary = {}
var collected: bool = false

func setup(value: Dictionary) -> void:
	drop_data = value.duplicate(true)

func _ready() -> void:
	add_to_group("drop_pickups")
	body_entered.connect(_on_body_entered)
	_apply_visual()

func try_collect(collector: Node) -> bool:
	if collected or collector == null or not collector.is_in_group("players"):
		return false

	var drop_system = get_tree().get_first_node_in_group("drop_system")
	if drop_system == null or not drop_system.has_method("collect_drop"):
		return false
	if not drop_system.collect_drop(drop_data, collector):
		return false

	collected = true
	set_deferred("monitoring", false)
	queue_free()
	return true

func _on_body_entered(body: Node2D) -> void:
	try_collect(body)

func _apply_visual() -> void:
	var drop_type := StringName(drop_data.get("type", &"unknown"))
	match drop_type:
		GameConstants.DROP_EXPERIENCE:
			visual.color = Color(0.40, 0.75, 1.0, 1.0)
			label.text = "XP"
		GameConstants.DROP_MONEY:
			visual.color = Color(1.0, 0.78, 0.20, 1.0)
			label.text = "$"
		GameConstants.DROP_AMMO:
			visual.color = Color(1.0, 0.46, 0.18, 1.0)
			label.text = "A"
		GameConstants.DROP_HEALTH:
			visual.color = Color(0.35, 0.95, 0.45, 1.0)
			label.text = "+"
		GameConstants.DROP_WEAPON:
			visual.color = Color(0.78, 0.42, 1.0, 1.0)
			label.text = "W"
		_:
			visual.color = Color(0.75, 0.75, 0.75, 1.0)
			label.text = "?"
