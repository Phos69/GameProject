extends Area2D
class_name SupplyCrate

signal opened(crate: SupplyCrate, opener: Node)

@export var loot_table: LootTable = preload(
	"res://game/drops/supply_crate_loot.tres"
)

var is_open: bool = false

func _ready() -> void:
	add_to_group("supply_crates")
	body_entered.connect(_on_body_entered)

func try_open(opener: Node) -> bool:
	if is_open or opener == null or not opener.is_in_group("players"):
		return false
	var health_component := opener.get_node_or_null("HealthComponent") as HealthComponent
	if health_component == null or not health_component.is_alive():
		return false
	var drop_system := get_tree().get_first_node_in_group("drop_system") as DropSystem
	if drop_system == null:
		return false

	is_open = true
	monitoring = false
	drop_system.spawn_drops(self, loot_table, global_position)
	opened.emit(self, opener)
	queue_free()
	return true

func _on_body_entered(body: Node2D) -> void:
	try_open(body)
