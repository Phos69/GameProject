extends Node
class_name HealthComponent

signal damaged(amount: int, current_health: int, max_health: int)
signal healed(amount: int, current_health: int, max_health: int)
signal downed()
signal revived(current_health: int, max_health: int)
signal died()

@export var max_health: int = 100
@export var invulnerable: bool = false
@export var downed_enabled: bool = false

var current_health: int = 100
var is_dead: bool = false
var is_downed: bool = false
var invulnerability_sources: Dictionary = {}

func _ready() -> void:
	current_health = max_health

func apply_damage(amount: int, ignore_invulnerability: bool = false) -> int:
	if (
		(is_invulnerable() and not ignore_invulnerability)
		or is_dead
		or is_downed
		or amount <= 0
	):
		return 0
	var previous_health := current_health
	current_health = maxi(current_health - amount, 0)
	var applied_amount := previous_health - current_health
	damaged.emit(applied_amount, current_health, max_health)
	if current_health == 0:
		if downed_enabled:
			is_downed = true
			downed.emit()
		else:
			is_dead = true
			died.emit()
	return applied_amount

func heal(amount: int) -> int:
	if is_dead or is_downed or amount <= 0:
		return 0
	var previous_health := current_health
	current_health = mini(current_health + amount, max_health)
	var applied_amount := current_health - previous_health
	if applied_amount > 0:
		healed.emit(applied_amount, current_health, max_health)
	return applied_amount

func reset_health() -> void:
	is_dead = false
	is_downed = false
	invulnerability_sources.clear()
	current_health = max_health

func revive(health_amount: int) -> bool:
	if not is_downed or is_dead:
		return false
	is_downed = false
	current_health = clampi(health_amount, 1, max_health)
	revived.emit(current_health, max_health)
	return true

func kill_downed() -> void:
	if not is_downed or is_dead:
		return
	is_downed = false
	is_dead = true
	died.emit()

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
	return not is_dead and not is_downed

func is_incapacitated() -> bool:
	return is_dead or is_downed

func add_invulnerability_source(source_id: StringName) -> void:
	if not source_id.is_empty():
		invulnerability_sources[source_id] = true

func remove_invulnerability_source(source_id: StringName) -> void:
	invulnerability_sources.erase(source_id)

func has_invulnerability_source(source_id: StringName) -> bool:
	return invulnerability_sources.has(source_id)

func is_invulnerable() -> bool:
	return invulnerable or not invulnerability_sources.is_empty()
