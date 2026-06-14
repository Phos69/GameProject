extends CanvasLayer
class_name DebugOverlay

@export var visible_on_start: bool = false

func _ready() -> void:
	visible = visible_on_start
	add_to_group("debug_overlay")

