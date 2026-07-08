extends Area2D
class_name TowerBuildSlot

signal build_requested(build_slot: TowerBuildSlot, player: Node)
signal upgrade_requested(build_slot: TowerBuildSlot, player: Node)

@export var slot_id: StringName = &"slot"
@export var tower_cost: int = 25
@export var tower_scene: PackedScene = preload("res://game/modes/tower_defense/defense_tower.tscn")

@onready var visual := $Visual as Polygon2D
@onready var prompt_label := $PromptLabel as Label

var built_tower: Node2D

func _ready() -> void:
	add_to_group("tower_build_slots")
	_update_visual()

func _process(_delta: float) -> void:
	# Stesso gesto (interact sullo slot) per costruire e per potenziare la
	# torre gia' costruita (TD-001).
	var wants_build := can_build()
	var wants_upgrade := not wants_build and can_upgrade_tower()
	if not wants_build and not wants_upgrade:
		return
	var input_manager := get_tree().get_first_node_in_group("input_manager") as InputManager
	if input_manager == null:
		return
	for body in get_overlapping_bodies():
		if not body.is_in_group("players"):
			continue
		var player_slot := int(body.get("player_slot"))
		if input_manager.is_player_interact_just_pressed(player_slot):
			if wants_build:
				build_requested.emit(self, body)
			else:
				upgrade_requested.emit(self, body)
			return

func can_build() -> bool:
	return tower_scene != null and (
		built_tower == null
		or not is_instance_valid(built_tower)
		or built_tower.is_queued_for_deletion()
	)

func can_upgrade_tower() -> bool:
	var tower := get_built_tower()
	return (
		tower != null
		and tower.has_method("can_upgrade")
		and bool(tower.call("can_upgrade"))
	)

func get_built_tower() -> Node2D:
	if (
		built_tower == null
		or not is_instance_valid(built_tower)
		or built_tower.is_queued_for_deletion()
	):
		return null
	return built_tower

func refresh_prompt() -> void:
	_update_visual()

func build_tower(parent: Node) -> Node:
	if not can_build() or parent == null:
		return null
	var tower := tower_scene.instantiate() as Node2D
	if tower == null:
		return null
	tower.global_position = global_position
	parent.add_child(tower)
	built_tower = tower
	_update_visual()
	return tower

func _update_visual() -> void:
	if visual == null or prompt_label == null:
		return
	if can_build():
		visual.color = Color(0.22, 0.72, 0.88, 0.42)
		prompt_label.text = "E / A\n%d C" % tower_cost
		prompt_label.show()
	elif can_upgrade_tower():
		visual.color = Color(0.92, 0.72, 0.26, 0.36)
		prompt_label.text = "E / A\nUP %d C" % int(get_built_tower().call("get_upgrade_cost"))
		prompt_label.show()
	else:
		visual.color = Color(0.18, 0.34, 0.45, 0.24)
		prompt_label.hide()
