extends Node
class_name SaveManager

signal save_completed(path: String)
signal load_completed(data: Dictionary)
signal save_failed(path: String, reason: String)
signal load_failed(path: String, reason: String)

const SAVE_VERSION: int = 1
const DEFAULT_SAVE_PATH: String = "user://savegame.json"

@export var save_path: String = DEFAULT_SAVE_PATH
@export var auto_load: bool = true
@export var autosave_progression: bool = true
@export var autosave_mode_selection: bool = true
@export var auto_persist_in_headless: bool = false

var progression_manager: ProgressionManager
var last_mode: StringName = GameConstants.MODE_SURVIVAL
var save_pending: bool = false
var is_loading: bool = false

func _enter_tree() -> void:
	add_to_group("save_manager")

func _ready() -> void:
	call_deferred("_initialize")

func create_empty_save() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"party": {
			"level": 1,
			"experience": 0,
			"money": 0
		},
		"settings": {
			"last_mode": String(GameConstants.MODE_SURVIVAL)
		}
	}

func save_game() -> bool:
	_resolve_progression_manager()
	var data := create_empty_save()
	if progression_manager != null:
		data["party"] = progression_manager.get_save_data()
	data["settings"] = {
		"last_mode": String(last_mode)
	}

	var temporary_path := save_path + ".tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		save_failed.emit(save_path, "cannot open temporary save file")
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

	var backup_path := save_path + ".bak"
	var absolute_save_path := ProjectSettings.globalize_path(save_path)
	var absolute_temporary_path := ProjectSettings.globalize_path(temporary_path)
	var absolute_backup_path := ProjectSettings.globalize_path(backup_path)
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(absolute_backup_path)
	if FileAccess.file_exists(save_path):
		var backup_error := DirAccess.rename_absolute(
			absolute_save_path,
			absolute_backup_path
		)
		if backup_error != OK:
			DirAccess.remove_absolute(absolute_temporary_path)
			save_failed.emit(save_path, error_string(backup_error))
			return false
	var rename_error := DirAccess.rename_absolute(
		absolute_temporary_path,
		absolute_save_path
	)
	if rename_error != OK:
		if FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(absolute_backup_path, absolute_save_path)
		DirAccess.remove_absolute(absolute_temporary_path)
		save_failed.emit(save_path, error_string(rename_error))
		return false
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(absolute_backup_path)
	save_completed.emit(save_path)
	return true

func load_game() -> bool:
	var source_path := save_path
	var backup_path := save_path + ".bak"
	if not FileAccess.file_exists(source_path) and FileAccess.file_exists(backup_path):
		source_path = backup_path
	if not FileAccess.file_exists(source_path):
		return false
	var file := FileAccess.open(source_path, FileAccess.READ)
	if file == null:
		load_failed.emit(save_path, "cannot open save file")
		return false
	var parsed_data: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed_data is Dictionary:
		load_failed.emit(save_path, "save root must be a dictionary")
		return false
	var data := parsed_data as Dictionary
	if not _is_valid_save(data):
		load_failed.emit(save_path, "unsupported or malformed save data")
		return false

	is_loading = true
	_resolve_progression_manager()
	if progression_manager != null:
		progression_manager.restore_save_data(data.get("party", {}))
	var settings := data.get("settings", {}) as Dictionary
	last_mode = _sanitize_mode(StringName(settings.get(
		"last_mode",
		GameConstants.MODE_SURVIVAL
	)))
	is_loading = false
	load_completed.emit(data.duplicate(true))
	return true

func request_save() -> void:
	if is_loading or save_pending:
		return
	save_pending = true
	call_deferred("_flush_pending_save")

func set_last_mode(mode_id: StringName) -> void:
	var sanitized_mode := _sanitize_mode(mode_id)
	if sanitized_mode == last_mode:
		return
	last_mode = sanitized_mode
	if autosave_mode_selection and _auto_persistence_enabled():
		request_save()

func get_last_mode() -> StringName:
	return last_mode

func _initialize() -> void:
	_resolve_progression_manager()
	if progression_manager != null:
		var progression_callback := Callable(self, "_on_progression_changed")
		if not progression_manager.experience_changed.is_connected(
			progression_callback
		):
			progression_manager.experience_changed.connect(progression_callback)
		if not progression_manager.money_changed.is_connected(progression_callback):
			progression_manager.money_changed.connect(progression_callback)

	var game_mode_manager := get_tree().get_first_node_in_group(
		"game_mode_manager"
	) as GameModeManager
	if game_mode_manager != null:
		var mode_callback := Callable(self, "_on_game_mode_changed")
		if not game_mode_manager.game_mode_changed.is_connected(mode_callback):
			game_mode_manager.game_mode_changed.connect(mode_callback)

	if auto_load and _auto_persistence_enabled():
		load_game()

func _resolve_progression_manager() -> void:
	if progression_manager == null:
		progression_manager = get_tree().get_first_node_in_group(
			"progression_manager"
		) as ProgressionManager

func _on_progression_changed(_value: int, _secondary_value: int = 0) -> void:
	if autosave_progression and _auto_persistence_enabled():
		request_save()

func _on_game_mode_changed(mode_id: StringName) -> void:
	if mode_id != GameConstants.MODE_MENU:
		set_last_mode(mode_id)

func _flush_pending_save() -> void:
	save_pending = false
	save_game()

func _auto_persistence_enabled() -> bool:
	return DisplayServer.get_name() != "headless" or auto_persist_in_headless

func _is_valid_save(data: Dictionary) -> bool:
	var version := int(data.get("version", 0))
	if version < 1 or version > SAVE_VERSION:
		return false
	return data.get("party", null) is Dictionary

func _sanitize_mode(mode_id: StringName) -> StringName:
	match mode_id:
		GameConstants.MODE_DUNGEON, GameConstants.MODE_TOWER_DEFENSE:
			return mode_id
		_:
			return GameConstants.MODE_SURVIVAL
