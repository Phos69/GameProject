extends Node
class_name ProgressionManager

signal experience_changed(experience: int, level: int)
signal money_changed(money: int)
signal leveled_up(level: int)

@export var experience_to_next_level: int = 100

var experience: int = 0
var money: int = 0
var level: int = 1

func _ready() -> void:
	add_to_group("progression_manager")

func add_experience(amount: int) -> void:
	if amount <= 0:
		return
	experience += amount
	while experience >= experience_to_next_level:
		experience -= experience_to_next_level
		level += 1
		leveled_up.emit(level)
	experience_changed.emit(experience, level)

func add_money(amount: int) -> void:
	if amount <= 0:
		return
	money += amount
	money_changed.emit(money)

