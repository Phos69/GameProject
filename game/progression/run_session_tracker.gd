extends Node
class_name RunSessionTracker

var game_mode_manager: GameModeManager
var progression_manager: ProgressionManager
var active_mode_id: StringName = &""
var started_at_msec: int = 0
var starting_level: int = 1
var starting_experience: int = 0
var starting_money: int = 0
var starting_unlocks: Array[StringName] = []

func _ready() -> void:
	add_to_group("run_session_tracker")
	call_deferred("_initialize")

func _initialize() -> void:
	game_mode_manager = get_tree().get_first_node_in_group(
		"game_mode_manager"
	) as GameModeManager
	progression_manager = get_tree().get_first_node_in_group(
		"progression_manager"
	) as ProgressionManager
	if game_mode_manager != null:
		var start_callback := Callable(self, "_on_game_mode_started")
		if not game_mode_manager.game_mode_started.is_connected(start_callback):
			game_mode_manager.game_mode_started.connect(start_callback)
	_connect_mode_signals()

func _connect_mode_signals() -> void:
	var survival_mode := get_tree().get_first_node_in_group(
		"survival_mode"
	) as SurvivalMode
	if survival_mode != null:
		var callback := Callable(self, "_on_survival_defeated")
		if not survival_mode.survival_defeated.is_connected(callback):
			survival_mode.survival_defeated.connect(callback)
	var dungeon_mode := get_tree().get_first_node_in_group(
		"dungeon_mode"
	) as DungeonMode
	if dungeon_mode != null:
		var complete_callback := Callable(self, "_on_dungeon_completed")
		if not dungeon_mode.dungeon_completed.is_connected(complete_callback):
			dungeon_mode.dungeon_completed.connect(complete_callback)
		var defeat_callback := Callable(self, "_on_dungeon_defeated")
		if not dungeon_mode.dungeon_defeated.is_connected(defeat_callback):
			dungeon_mode.dungeon_defeated.connect(defeat_callback)
	var tower_mode := get_tree().get_first_node_in_group(
		"tower_defense_mode"
	) as TowerDefenseMode
	if tower_mode != null:
		var callback := Callable(self, "_on_defense_defeated")
		if not tower_mode.defense_defeated.is_connected(callback):
			tower_mode.defense_defeated.connect(callback)

func _on_game_mode_started(mode_id: StringName) -> void:
	active_mode_id = mode_id
	started_at_msec = Time.get_ticks_msec()
	if progression_manager == null:
		return
	starting_level = progression_manager.level
	starting_experience = progression_manager.experience
	starting_money = progression_manager.money
	starting_unlocks = progression_manager.unlocked_ids.duplicate()

func _on_survival_defeated(wave_index: int) -> void:
	_finish_run(&"defeat", "RUN OVER", "Reached wave %d" % wave_index, {
		"wave": wave_index
	})

func _on_dungeon_completed(_seed_value: int, room_count: int) -> void:
	_finish_run(
		&"victory",
		"DUNGEON COMPLETE",
		"Cleared %d rooms" % room_count,
		{"rooms": room_count}
	)

func _on_dungeon_defeated(room_index: int) -> void:
	_finish_run(
		&"defeat",
		"DUNGEON FAILED",
		"Reached room %d" % maxi(room_index + 1, 1),
		{"rooms": maxi(room_index + 1, 1)}
	)

func _on_defense_defeated(wave_index: int) -> void:
	_finish_run(
		&"defeat",
		"DEFENSE FAILED",
		"Reached wave %d" % wave_index,
		{"wave": wave_index}
	)

func _finish_run(
	outcome: StringName,
	title: String,
	summary: String,
	progress: Dictionary
) -> void:
	if (
		game_mode_manager == null
		or active_mode_id.is_empty()
		or game_mode_manager.run_result_active
	):
		return
	var result := {
		"mode_id": active_mode_id,
		"outcome": outcome,
		"title": title,
		"summary": summary,
		"elapsed_seconds": maxf(
			float(Time.get_ticks_msec() - started_at_msec) / 1000.0,
			0.0
		),
		"experience_gained": _get_experience_gained(),
		"money_gained": (
			maxi(progression_manager.money - starting_money, 0)
			if progression_manager != null
			else 0
		),
		"unlocks": _get_new_unlocks(),
		"progress": progress.duplicate(true)
	}
	game_mode_manager.finish_run(result)

func _get_experience_gained() -> int:
	if progression_manager == null:
		return 0
	var level_delta := progression_manager.level - starting_level
	return maxi(
		level_delta * progression_manager.experience_to_next_level
		+ progression_manager.experience
		- starting_experience,
		0
	)

func _get_new_unlocks() -> Array[StringName]:
	var result: Array[StringName] = []
	if progression_manager == null:
		return result
	for unlock_id in progression_manager.unlocked_ids:
		if not starting_unlocks.has(unlock_id):
			result.append(unlock_id)
	return result
