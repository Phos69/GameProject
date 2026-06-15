extends Node
class_name ProgressionManager

signal experience_changed(experience: int, level: int)
signal money_changed(money: int)
signal leveled_up(level: int)
signal progression_restored(experience: int, level: int, money: int)

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
	var level_threshold := maxi(experience_to_next_level, 1)
	while experience >= level_threshold:
		experience -= level_threshold
		level += 1
		leveled_up.emit(level)
	experience_changed.emit(experience, level)

func add_money(amount: int) -> void:
	if amount <= 0:
		return
	money += amount
	money_changed.emit(money)

func get_save_data() -> Dictionary:
	return {
		"level": level,
		"experience": experience,
		"money": money
	}

func restore_save_data(data: Dictionary) -> void:
	var restored_level := maxi(int(data.get("level", 1)), 1)
	var restored_experience := maxi(int(data.get("experience", 0)), 0)
	var restored_money := maxi(int(data.get("money", 0)), 0)
	var level_threshold := maxi(experience_to_next_level, 1)
	while restored_experience >= level_threshold:
		restored_experience -= level_threshold
		restored_level += 1

	level = restored_level
	experience = restored_experience
	money = restored_money
	experience_changed.emit(experience, level)
	money_changed.emit(money)
	progression_restored.emit(experience, level, money)
