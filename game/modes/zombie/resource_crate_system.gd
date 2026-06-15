extends Node
class_name ResourceCrateSystem

signal crate_rules_configured(biome_id: StringName)

var active_biome
var is_active: bool = false

func _ready() -> void:
	add_to_group("resource_crate_system")

func start_run(biome) -> void:
	active_biome = biome
	is_active = true
	crate_rules_configured.emit(
		StringName(active_biome.get("biome_id")) if active_biome != null else &""
	)

func stop_run() -> void:
	is_active = false
	active_biome = null

func get_active_crate_ids() -> Array[StringName]:
	if active_biome == null:
		return []
	return active_biome.get("crate_ids").duplicate()
