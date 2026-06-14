extends Node
class_name DropSystem

signal drops_rolled(source: Node, drops: Array[Dictionary])
signal drop_collected(drop_data: Dictionary, collector: Node)

func _ready() -> void:
	add_to_group("drop_system")

func roll_drops(source: Node, loot_table: Resource) -> Array[Dictionary]:
	var drops: Array[Dictionary] = []
	if loot_table == null:
		drops_rolled.emit(source, drops)
		return drops

	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var entries: Array = loot_table.get("entries")
	for raw_entry in entries:
		var entry: Dictionary = raw_entry
		var chance := float(entry.get("chance", 0.0))
		if rng.randf() <= chance:
			drops.append(entry.duplicate(true))

	drops_rolled.emit(source, drops)
	return drops

func collect_drop(drop_data: Dictionary, collector: Node) -> void:
	drop_collected.emit(drop_data, collector)
