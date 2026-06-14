extends CanvasLayer
class_name HUDManager

var status_label: Label

func _ready() -> void:
	add_to_group("hud_manager")
	status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.position = Vector2(18.0, 18.0)
	status_label.add_theme_font_size_override("font_size", 18)
	status_label.modulate = Color(0.90, 0.96, 1.0, 1.0)
	add_child(status_label)
	_refresh()

func _process(_delta: float) -> void:
	_refresh()

func _refresh() -> void:
	if status_label == null:
		return

	var players := get_tree().get_nodes_in_group("players")
	var progression = get_tree().get_first_node_in_group("progression_manager")
	var level := 1
	var experience := 0
	var money := 0
	if progression != null:
		level = progression.level
		experience = progression.experience
		money = progression.money

	status_label.text = "Prototype Arena\nPlayers: %d\nParty Lv %d  XP %d  Money %d" % [
		players.size(),
		level,
		experience,
		money
	]
