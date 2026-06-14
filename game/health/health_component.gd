extends Node
class_name HealthComponent

signal damaged(amount: int, current_health: int, max_health: int)
signal healed(amount: int, current_health: int, max_health: int)
signal died()

@export var max_health: int = 100
@export var invulnerable: bool = false

var current_health: int = 100
var is_dead: bool = false

func _ready() -> void:
	current_health = max_health

func apply_damage(amount: int) -> void:
	if invulnerable or is_dead or amount <= 0:
		return
	current_health = maxi(current_health - amount, 0)
	damaged.emit(amount, current_health, max_health)
	if current_health == 0:
		is_dead = true
		died.emit()

func heal(amount: int) -> void:
	if is_dead or amount <= 0:
		return
	var previous_health := current_health
	current_health = mini(current_health + amount, max_health)
	healed.emit(current_health - previous_health, current_health, max_health)

func reset_health() -> void:
	is_dead = false
	current_health = max_health

