extends BaseGameMode
class_name SurvivalMode

signal survival_defeated(wave_index: int)

@export var boss_wave_interval: int = GameConstants.DEFAULT_BOSS_WAVE_INTERVAL
@export var boss_spawn_position: Vector2 = Vector2(0.0, -220.0)
@export var boss_health_scale_per_wave: float = 0.10
@export var boss_damage_scale_per_wave: float = 0.08

var wave_manager: WaveManager
var ammo_director: SurvivalAmmoDirector
var arena_manager: SurvivalArenaManager
var zombie_mode_controller
var player_manager: PlayerManager
var selected_character_id: StringName = &""
var selected_character_ids_by_slot: Dictionary = {}

func _ready() -> void:
	mode_id = GameConstants.MODE_SURVIVAL
	add_to_group("survival_mode")
	_resolve_wave_manager()
	_resolve_ammo_director()
	_resolve_arena_manager()
	_resolve_zombie_mode_controller()
	_resolve_player_manager()

	var game_mode_manager = get_tree().get_first_node_in_group("game_mode_manager")
	if game_mode_manager != null:
		game_mode_manager.register_mode(self)

func _process(_delta: float) -> void:
	if not is_running or wave_manager == null or not wave_manager.run_active:
		return
	var players := get_tree().get_nodes_in_group("players")
	if players.is_empty():
		return
	for player in players:
		var health_component := player.get_node_or_null("HealthComponent") as HealthComponent
		if health_component != null and health_component.is_alive():
			return
	var defeated_wave := wave_manager.current_wave
	survival_defeated.emit(defeated_wave)
	stop_mode()

func start_mode(context: Dictionary = {}) -> void:
	if is_running:
		return
	super.start_mode(context)
	_resolve_wave_manager()
	_resolve_ammo_director()
	_resolve_arena_manager()
	_resolve_zombie_mode_controller()
	_resolve_player_manager()
	selected_character_id = (
		StringName(context.get("character_id", &""))
		if context.has("character_id")
		else &""
	)
	selected_character_ids_by_slot = _parse_character_ids_by_slot(
		context.get("character_ids_by_slot", {})
	)
	_apply_character_to_active_players()
	if arena_manager != null:
		var arena_id := StringName(
			context.get("arena_id", arena_manager.default_arena_id)
		)
		arena_manager.activate_arena(arena_id)
	if zombie_mode_controller != null:
		zombie_mode_controller.start_run(context)
	if ammo_director != null:
		ammo_director.start_run()
	if wave_manager != null:
		wave_manager.start_run()

func stop_mode() -> void:
	if not is_running:
		return
	if ammo_director != null:
		ammo_director.stop_run(true)
	if wave_manager != null:
		wave_manager.stop_run(true)
	if zombie_mode_controller != null:
		zombie_mode_controller.stop_run()
	if arena_manager != null:
		arena_manager.deactivate_arena()
	super.stop_mode()

func should_spawn_boss_for_wave(wave_index: int) -> bool:
	return boss_wave_interval > 0 and wave_index % boss_wave_interval == 0

func _on_boss_wave_requested(wave_index: int) -> void:
	var game_mode_manager = get_tree().get_first_node_in_group("game_mode_manager")
	if game_mode_manager == null or wave_manager == null:
		return
	var wave_offset := maxi(wave_index - 1, 0)
	var config := {
		"boss_id": &"wave_warden",
		"wave_index": wave_index,
		"health_multiplier": 1.0 + float(wave_offset) * boss_health_scale_per_wave,
		"damage_multiplier": 1.0 + float(wave_offset) * boss_damage_scale_per_wave
	}
	var boss: Node = game_mode_manager.request_boss(
		StringName("survival_wave_%d" % wave_index),
		arena_manager.get_boss_spawn_position(boss_spawn_position)
		if arena_manager != null
		else boss_spawn_position,
		null,
		config
	)
	wave_manager.register_wave_boss(boss)

func _resolve_wave_manager() -> void:
	if wave_manager == null:
		wave_manager = get_tree().get_first_node_in_group("wave_manager") as WaveManager
	if wave_manager == null:
		return
	wave_manager.boss_wave_interval = boss_wave_interval
	var callback := Callable(self, "_on_boss_wave_requested")
	if not wave_manager.boss_wave_requested.is_connected(callback):
		wave_manager.boss_wave_requested.connect(callback)

func _resolve_ammo_director() -> void:
	if ammo_director == null:
		ammo_director = get_node_or_null("AmmoDirector") as SurvivalAmmoDirector

func _resolve_arena_manager() -> void:
	if arena_manager == null:
		arena_manager = get_tree().get_first_node_in_group(
			"survival_arena_manager"
		) as SurvivalArenaManager

func _resolve_zombie_mode_controller() -> void:
	if zombie_mode_controller == null:
		zombie_mode_controller = get_tree().get_first_node_in_group(
			"zombie_mode_controller"
		)

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
	for player in get_tree().get_nodes_in_group("players"):
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
