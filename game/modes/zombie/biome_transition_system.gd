extends Node
class_name BiomeTransitionSystem

signal biome_transitioned(
	previous_biome_id: StringName,
	current_biome_id: StringName
)

# Command API to force a biome/region change from debug helpers and smoke tests.
# The standard survival runtime does NOT use this to navigate: region changes are
# detected by RegionSeamSystem from the party world-space position and open
# WorldRegionConnection data. The legacy Area2D `BiomeTransitionGate` portals were
# removed; this node keeps only the imperative transition command.

@export var party_entry_offset: float = 410.0
@export_range(0.1, 3.0, 0.1) var transition_cooldown: float = 0.8
@export var move_party_on_transition: bool = false

var biome_manager: BiomeManager
var active_biome: BiomeDefinition
var is_active: bool = false
var cooldown_timer: float = 0.0

func _ready() -> void:
	add_to_group("biome_transition_system")

func _process(delta: float) -> void:
	cooldown_timer = maxf(cooldown_timer - delta, 0.0)

func start_run(
	biome: BiomeDefinition,
	manager: BiomeManager = null
) -> void:
	biome_manager = manager if manager != null else _resolve_biome_manager()
	is_active = true
	configure_biome(biome)

func configure_biome(biome: BiomeDefinition) -> void:
	active_biome = biome

func stop_run() -> void:
	active_biome = null
	biome_manager = null
	is_active = false
	cooldown_timer = 0.0

func transition_to(
	target_biome_id: StringName,
	direction_id: StringName = &"east",
	target_region_id: StringName = &""
) -> bool:
	if not is_active or target_biome_id.is_empty():
		return false
	if cooldown_timer > 0.0:
		return false
	if biome_manager == null:
		biome_manager = _resolve_biome_manager()
	if biome_manager == null:
		return false
	var previous_id := biome_manager.get_current_biome_id()
	var changed := (
		biome_manager.set_current_region(target_region_id)
		if not target_region_id.is_empty()
		else biome_manager.set_current_biome(target_biome_id)
	)
	if not changed:
		return false
	if move_party_on_transition:
		_move_party_to_entry(direction_id)
	cooldown_timer = transition_cooldown
	biome_transitioned.emit(previous_id, target_biome_id)
	return true

func _move_party_to_entry(direction_id: StringName) -> void:
	var entry_position := Vector2.ZERO
	match direction_id:
		&"east":
			entry_position = Vector2(-party_entry_offset, 0.0)
		&"west":
			entry_position = Vector2(party_entry_offset, 0.0)
		&"north":
			entry_position = Vector2(0.0, party_entry_offset)
		&"south":
			entry_position = Vector2(0.0, -party_entry_offset)
		_:
			entry_position = Vector2(-party_entry_offset, 0.0)
	var players := PlayerQuery.all(get_tree())
	players.sort_custom(func(a: Node, b: Node) -> bool:
		return int(a.get("player_slot")) < int(b.get("player_slot"))
	)
	for index in range(players.size()):
		var player := players[index] as Node2D
		if player == null:
			continue
		var party_offset := (float(index) - float(players.size() - 1) * 0.5) * 44.0
		if direction_id == &"north" or direction_id == &"south":
			player.global_position = entry_position + Vector2(party_offset, 0.0)
		else:
			player.global_position = entry_position + Vector2(0.0, party_offset)
		if player is CharacterBody2D:
			(player as CharacterBody2D).velocity = Vector2.ZERO

func _resolve_biome_manager() -> BiomeManager:
	return get_tree().get_first_node_in_group("biome_manager") as BiomeManager
