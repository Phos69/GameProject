extends Node
class_name BaseGameMode

signal mode_started(mode_id: StringName)
signal mode_stopped(mode_id: StringName)
signal boss_requested(mode_id: StringName, reason: StringName)

@export var mode_id: StringName = &"base"

var is_running: bool = false
# Roster del run: il personaggio "principale" (slot 1 / single player) e la mappa
# slot -> personaggio per il co-op locale. Condivisi da ogni modalita cosi il
# sistema personaggi RPG vale per tutte, non solo per la sopravvivenza.
var selected_character_id: StringName = &""
var selected_character_ids_by_slot: Dictionary = {}
var player_manager: PlayerManager

func start_mode(context: Dictionary = {}) -> void:
	if is_running:
		return
	is_running = true
	_resolve_player_manager()
	_apply_character_context(context)
	mode_started.emit(mode_id)

func stop_mode() -> void:
	if not is_running:
		return
	is_running = false
	mode_stopped.emit(mode_id)

func request_boss(reason: StringName) -> void:
	boss_requested.emit(mode_id, reason)

# Legge il roster dal context di avvio e lo applica ai player gia presenti. I
# player che entrano dopo (respawn, join in co-op) sono coperti da
# `_on_player_spawned`.
func _apply_character_context(context: Dictionary) -> void:
	selected_character_id = (
		StringName(context.get("character_id", &""))
		if context.has("character_id")
		else &""
	)
	selected_character_ids_by_slot = _parse_character_ids_by_slot(
		context.get("character_ids_by_slot", {})
	)
	_apply_character_to_active_players()

func _resolve_player_manager() -> void:
	if player_manager == null:
		player_manager = get_tree().get_first_node_in_group(
			"player_manager"
		) as PlayerManager
	if player_manager == null:
		return
	var spawn_callback := Callable(self, "_on_player_spawned")
	if not player_manager.player_spawned.is_connected(spawn_callback):
		player_manager.player_spawned.connect(spawn_callback)

func _apply_character_to_active_players() -> void:
	for player in PlayerQuery.all(get_tree()):
		_apply_character_to_player(player)

func _apply_character_to_player(player: Node) -> void:
	if player == null:
		return
	var character_id := _get_character_id_for_player(player)
	if character_id.is_empty():
		if player.has_method("clear_rpg_character"):
			player.clear_rpg_character()
		return
	if player.has_method("apply_rpg_character"):
		player.apply_rpg_character(character_id)

func _on_player_spawned(_player_slot: int, player: Node) -> void:
	if is_running:
		_apply_character_to_player(player)

func _parse_character_ids_by_slot(raw_value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if not raw_value is Dictionary:
		return result
	var raw_dictionary := raw_value as Dictionary
	for raw_key in raw_dictionary.keys():
		var player_slot := int(str(raw_key))
		if player_slot < 1 or player_slot > 4:
			continue
		var character_id := StringName(raw_dictionary[raw_key])
		if character_id.is_empty():
			continue
		result[player_slot] = character_id
	return result

func _get_character_id_for_player(player: Node) -> StringName:
	var player_slot := int(player.get("player_slot"))
	var slot_character_id := StringName(
		selected_character_ids_by_slot.get(player_slot, &"")
	)
	if not slot_character_id.is_empty():
		return slot_character_id
	return selected_character_id
