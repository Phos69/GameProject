extends Node
class_name BiomeManager

signal current_biome_changed(biome_id: StringName, display_name: String)

const INFECTED_PLAINS = preload(
	"res://game/modes/zombie/biomes/infected_plains.tres"
)
const TOXIC_WASTES = preload(
	"res://game/modes/zombie/biomes/toxic_wastes.tres"
)
const BURNING_FIELDS = preload(
	"res://game/modes/zombie/biomes/burning_fields.tres"
)
const FROZEN_OUTSKIRTS = preload(
	"res://game/modes/zombie/biomes/frozen_outskirts.tres"
)
const DROWNED_MARSH = preload(
	"res://game/modes/zombie/biomes/drowned_marsh.tres"
)

@export var default_biome_id: StringName = &"infected_plains"
@export var biome_definitions: Array[Resource] = []

var biomes: Dictionary = {}
var current_biome

func _ready() -> void:
	add_to_group("biome_manager")
	_register_builtin_biomes()
	for definition in biome_definitions:
		register_biome(definition)
	select_starting_biome()

func start_run(_context: Dictionary = {}) -> void:
	select_starting_biome()

func register_biome(definition) -> void:
	if definition == null:
		return
	var biome_id := StringName(definition.get("biome_id"))
	if biome_id.is_empty():
		return
	biomes[biome_id] = definition

func select_starting_biome() -> bool:
	for definition in biomes.values():
		if definition != null and bool(definition.get("is_starting_biome")):
			return set_current_biome(StringName(definition.get("biome_id")))
	return set_current_biome(default_biome_id)

func set_current_biome(biome_id: StringName) -> bool:
	var next_biome = biomes.get(biome_id)
	if next_biome == null:
		return false
	if current_biome == next_biome:
		return true
	current_biome = next_biome
	current_biome_changed.emit(
		StringName(current_biome.get("biome_id")),
		String(current_biome.get("display_name"))
	)
	return true

func get_current_biome():
	return current_biome

func get_current_biome_id() -> StringName:
	return StringName(current_biome.get("biome_id")) if current_biome != null else &""

func get_current_display_name() -> String:
	return String(current_biome.get("display_name")) if current_biome != null else ""

func get_biome_definition(biome_id: StringName):
	return biomes.get(biome_id)

func get_available_biome_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for biome_id in biomes.keys():
		ids.append(StringName(biome_id))
	ids.sort()
	return ids

func _register_builtin_biomes() -> void:
	register_biome(INFECTED_PLAINS)
	register_biome(TOXIC_WASTES)
	register_biome(BURNING_FIELDS)
	register_biome(FROZEN_OUTSKIRTS)
	register_biome(DROWNED_MARSH)
