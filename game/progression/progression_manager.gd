extends Node
class_name ProgressionManager

signal experience_changed(experience: int, level: int)
signal money_changed(money: int)
signal leveled_up(level: int)
signal progression_restored(experience: int, level: int, money: int)
signal unlock_granted(unlock_id: StringName)
signal unlocks_changed(unlock_ids: Array[StringName])

@export var experience_to_next_level: int = 100

const FIELD_KIT_UNLOCK: StringName = &"field_kit"
const FIELD_KIT_UNLOCK_LEVEL: int = 2
const FIELD_KIT_HEALTH_BONUS: int = 20

var experience: int = 0
var money: int = 0
var level: int = 1
var unlocked_ids: Array[StringName] = []

var game_mode_manager: GameModeManager
var player_manager: PlayerManager

func _ready() -> void:
	add_to_group("progression_manager")
	call_deferred("_initialize")

func add_experience(amount: int) -> void:
	if amount <= 0:
		return
	experience += amount
	var level_threshold := maxi(experience_to_next_level, 1)
	while experience >= level_threshold:
		experience -= level_threshold
		level += 1
		leveled_up.emit(level)
	_grant_level_unlocks()
	experience_changed.emit(experience, level)

func add_money(amount: int) -> void:
	if amount <= 0:
		return
	money += amount
	money_changed.emit(money)

func can_afford(amount: int) -> bool:
	return amount >= 0 and money >= amount

func try_spend_money(amount: int) -> bool:
	if amount <= 0 or not can_afford(amount):
		return false
	money -= amount
	money_changed.emit(money)
	return true

func get_save_data() -> Dictionary:
	var serialized_unlocks: Array[String] = []
	for unlock_id in unlocked_ids:
		serialized_unlocks.append(String(unlock_id))
	return {
		"level": level,
		"experience": experience,
		"money": money,
		"unlocks": serialized_unlocks
	}

func restore_save_data(data: Dictionary) -> void:
	var restored_level := maxi(int(data.get("level", 1)), 1)
	var restored_experience := maxi(int(data.get("experience", 0)), 0)
	var restored_money := maxi(int(data.get("money", 0)), 0)
	var level_threshold := maxi(experience_to_next_level, 1)
	while restored_experience >= level_threshold:
		restored_experience -= level_threshold
		restored_level += 1

	level = restored_level
	experience = restored_experience
	money = restored_money
	unlocked_ids.clear()
	var restored_unlocks: Variant = data.get("unlocks", [])
	if restored_unlocks is Array:
		for value in restored_unlocks:
			var unlock_id := _sanitize_unlock(StringName(str(value)))
			if unlock_id != &"" and not unlocked_ids.has(unlock_id):
				unlocked_ids.append(unlock_id)
	_grant_level_unlocks(false)
	experience_changed.emit(experience, level)
	money_changed.emit(money)
	unlocks_changed.emit(unlocked_ids.duplicate())
	progression_restored.emit(experience, level, money)

func has_unlock(unlock_id: StringName) -> bool:
	return unlocked_ids.has(unlock_id)

func get_run_max_health_bonus() -> int:
	return FIELD_KIT_HEALTH_BONUS if has_unlock(FIELD_KIT_UNLOCK) else 0

func get_unlock_status_text() -> String:
	if has_unlock(FIELD_KIT_UNLOCK):
		return "Field Kit: +%d HP max" % FIELD_KIT_HEALTH_BONUS
	return "Prossimo sblocco: Field Kit a Gruppo Lv %d" % FIELD_KIT_UNLOCK_LEVEL

func prepare_players_for_run() -> void:
	for player in PlayerQuery.all(get_tree()):
		_prepare_player_for_run(player)

func _initialize() -> void:
	game_mode_manager = get_tree().get_first_node_in_group(
		"game_mode_manager"
	) as GameModeManager
	player_manager = get_tree().get_first_node_in_group(
		"player_manager"
	) as PlayerManager
	if game_mode_manager != null:
		var mode_callback := Callable(self, "_on_game_mode_started")
		if not game_mode_manager.game_mode_started.is_connected(mode_callback):
			game_mode_manager.game_mode_started.connect(mode_callback)
	if player_manager != null:
		var spawn_callback := Callable(self, "_on_player_spawned")
		if not player_manager.player_spawned.is_connected(spawn_callback):
			player_manager.player_spawned.connect(spawn_callback)

func _grant_level_unlocks(emit_signals: bool = true) -> void:
	if level < FIELD_KIT_UNLOCK_LEVEL or has_unlock(FIELD_KIT_UNLOCK):
		return
	unlocked_ids.append(FIELD_KIT_UNLOCK)
	if emit_signals:
		unlock_granted.emit(FIELD_KIT_UNLOCK)
		unlocks_changed.emit(unlocked_ids.duplicate())

func _sanitize_unlock(unlock_id: StringName) -> StringName:
	match unlock_id:
		FIELD_KIT_UNLOCK:
			return unlock_id
		_:
			return &""

func _on_game_mode_started(_mode_id: StringName) -> void:
	prepare_players_for_run()

func _on_player_spawned(_player_slot: int, player: Node) -> void:
	if game_mode_manager != null and game_mode_manager.is_gameplay_active():
		_prepare_player_for_run(player)

func _prepare_player_for_run(player: Node) -> void:
	if player != null and player.has_method("prepare_for_run"):
		player.prepare_for_run(get_run_max_health_bonus())
