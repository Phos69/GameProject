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

func apply_damage(amount: int) -> int:
	if invulnerable or is_dead or amount <= 0:
		return 0
	var previous_health := current_health
	current_health = maxi(current_health - amount, 0)
	var applied_amount := previous_health - current_health
	damaged.emit(applied_amount, current_health, max_health)
	if current_health == 0:
		is_dead = true
		died.emit()
	return applied_amount

func heal(amount: int) -> int:
	if is_dead or amount <= 0:
		return 0
	var previous_health := current_health
	current_health = mini(current_health + amount, max_health)
	var applied_amount := current_health - previous_health
	if applied_amount > 0:
		healed.emit(applied_amount, current_health, max_health)
	return applied_amount

func reset_health() -> void:
	is_dead = false
	current_health = max_health

func set_max_health(value: int, refill: bool = false) -> void:
	max_health = maxi(value, 1)
	if refill:
		reset_health()
	else:
		current_health = mini(current_health, max_health)

func get_health_ratio() -> float:
	if max_health <= 0:
		return 0.0
	return float(current_health) / float(max_health)

func is_alive() -> bool:
	return not is_dead
