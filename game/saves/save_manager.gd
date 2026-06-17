extends Node
class_name SaveManager

signal save_completed(path: String)
signal load_completed(data: Dictionary)
signal save_failed(path: String, reason: String)
signal load_failed(path: String, reason: String)

const SAVE_VERSION: int = 6
const DEFAULT_SAVE_PATH: String = "user://savegame.json"

@export var save_path: String = DEFAULT_SAVE_PATH
@export var auto_load: bool = true
@export var autosave_progression: bool = true
@export var autosave_mode_selection: bool = true
@export var auto_persist_in_headless: bool = false

var progression_manager: ProgressionManager
var audio_manager: AudioManager
var visual_settings_manager: VisualSettingsManager
var video_settings_manager: VideoSettingsManager
var input_manager: InputManager
var local_multiplayer_manager: LocalMultiplayerManager
var world_runtime: WorldRuntime
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
			"money": 0,
			"unlocks": []
		},
		"settings": {
			"last_mode": String(GameConstants.MODE_SURVIVAL),
			"audio": {
				"master": 1.0,
				"music": 0.8,
				"sfx": 0.9
			},
			"visual": VisualSettingsManager.DEFAULT_SETTINGS.duplicate(true),
			"video": VideoSettingsManager.DEFAULT_SETTINGS.duplicate(true),
			"controls": {
				"input": InputManager.create_default_settings_data(),
				"local_multiplayer": (
					LocalMultiplayerManager.create_default_settings_data()
				)
			}
		},
		"world": PersistentWorldState.create_empty_save_data()
	}

func save_game() -> bool:
	_resolve_progression_manager()
	var data := create_empty_save()
	if progression_manager != null:
		data["party"] = progression_manager.get_save_data()
	_resolve_audio_manager()
	var audio_settings: Dictionary = (
		audio_manager.get_settings_data()
		if audio_manager != null
		else create_empty_save()["settings"]["audio"] as Dictionary
	)
	_resolve_visual_settings_manager()
	var visual_settings: Dictionary = (
		visual_settings_manager.get_settings_data()
		if visual_settings_manager != null
		else create_empty_save()["settings"]["visual"] as Dictionary
	)
	_resolve_video_settings_manager()
	var video_settings: Dictionary = (
		video_settings_manager.get_settings_data()
		if video_settings_manager != null
		else create_empty_save()["settings"]["video"] as Dictionary
	)
	_resolve_input_manager()
	_resolve_local_multiplayer_manager()
	var controls_settings := {
		"input": (
			input_manager.get_settings_data()
			if input_manager != null
			else InputManager.create_default_settings_data()
		),
		"local_multiplayer": (
			local_multiplayer_manager.get_settings_data()
			if local_multiplayer_manager != null
			else LocalMultiplayerManager.create_default_settings_data()
		)
	}
	data["settings"] = {
		"last_mode": String(last_mode),
		"audio": audio_settings,
		"visual": visual_settings,
		"video": video_settings,
		"controls": controls_settings
	}
	_resolve_world_runtime()
	data["world"] = (
		world_runtime.get_save_data()
		if world_runtime != null
		else PersistentWorldState.create_empty_save_data()
	)

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
	_resolve_audio_manager()
	if audio_manager != null:
		audio_manager.restore_settings_data(
			settings.get("audio", {}) as Dictionary
		)
	_resolve_visual_settings_manager()
	if visual_settings_manager != null:
		visual_settings_manager.restore_settings_data(
			settings.get("visual", {}) as Dictionary
		)
	_resolve_video_settings_manager()
	if video_settings_manager != null:
		video_settings_manager.restore_settings_data(
			settings.get("video", {}) as Dictionary
		)
	var controls_settings := settings.get("controls", {}) as Dictionary
	_resolve_input_manager()
	if input_manager != null:
		input_manager.restore_settings_data(
			controls_settings.get("input", {}) as Dictionary
		)
	_resolve_local_multiplayer_manager()
	if local_multiplayer_manager != null:
		local_multiplayer_manager.restore_settings_data(
			controls_settings.get("local_multiplayer", {}) as Dictionary
		)
	_resolve_world_runtime()
	if world_runtime != null:
		world_runtime.restore_save_data(
			data.get("world", {}) as Dictionary
		)
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
	_resolve_audio_manager()
	_resolve_visual_settings_manager()
	_resolve_video_settings_manager()
	_resolve_input_manager()
	_resolve_local_multiplayer_manager()
	_resolve_world_runtime()
	if progression_manager != null:
		var progression_callback := Callable(self, "_on_progression_changed")
		if not progression_manager.experience_changed.is_connected(
			progression_callback
		):
			progression_manager.experience_changed.connect(progression_callback)
		if not progression_manager.money_changed.is_connected(progression_callback):
			progression_manager.money_changed.connect(progression_callback)
		var unlock_callback := Callable(self, "_on_unlocks_changed")
		if not progression_manager.unlocks_changed.is_connected(unlock_callback):
			progression_manager.unlocks_changed.connect(unlock_callback)

	var game_mode_manager := get_tree().get_first_node_in_group(
		"game_mode_manager"
	) as GameModeManager
	if game_mode_manager != null:
		var mode_callback := Callable(self, "_on_game_mode_changed")
		if not game_mode_manager.game_mode_changed.is_connected(mode_callback):
			game_mode_manager.game_mode_changed.connect(mode_callback)
	if audio_manager != null:
		var audio_callback := Callable(self, "_on_audio_settings_changed")
		if not audio_manager.audio_settings_changed.is_connected(audio_callback):
			audio_manager.audio_settings_changed.connect(audio_callback)
	if visual_settings_manager != null:
		var visual_callback := Callable(self, "_on_visual_settings_changed")
		if not visual_settings_manager.visual_settings_changed.is_connected(
			visual_callback
		):
			visual_settings_manager.visual_settings_changed.connect(
				visual_callback
			)
	if video_settings_manager != null:
		var video_callback := Callable(self, "_on_video_settings_changed")
		if not video_settings_manager.video_settings_changed.is_connected(
			video_callback
		):
			video_settings_manager.video_settings_changed.connect(
				video_callback
			)
	if input_manager != null:
		var input_callback := Callable(self, "_on_controls_changed")
		if not input_manager.controls_changed.is_connected(input_callback):
			input_manager.controls_changed.connect(input_callback)
	if local_multiplayer_manager != null:
		var multiplayer_callback := Callable(self, "_on_controls_changed")
		if not local_multiplayer_manager.multiplayer_controls_changed.is_connected(
			multiplayer_callback
		):
			local_multiplayer_manager.multiplayer_controls_changed.connect(
				multiplayer_callback
			)
	if world_runtime != null:
		var world_callback := Callable(self, "_on_world_state_changed")
		if not world_runtime.exploration_changed.is_connected(world_callback):
			world_runtime.exploration_changed.connect(world_callback)
		var region_runtime_callback := Callable(self, "_on_region_runtime_changed")
		if not world_runtime.region_runtime_changed.is_connected(
			region_runtime_callback
		):
			world_runtime.region_runtime_changed.connect(region_runtime_callback)

	if auto_load and _auto_persistence_enabled():
		load_game()

func _resolve_progression_manager() -> void:
	if progression_manager == null:
		progression_manager = get_tree().get_first_node_in_group(
			"progression_manager"
		) as ProgressionManager

func _resolve_audio_manager() -> void:
	if audio_manager == null:
		audio_manager = get_tree().get_first_node_in_group(
			"audio_manager"
		) as AudioManager

func _resolve_visual_settings_manager() -> void:
	if visual_settings_manager == null:
		visual_settings_manager = get_tree().get_first_node_in_group(
			"visual_settings_manager"
		) as VisualSettingsManager

func _resolve_video_settings_manager() -> void:
	if video_settings_manager == null:
		video_settings_manager = get_tree().get_first_node_in_group(
			"video_settings_manager"
		) as VideoSettingsManager

func _resolve_input_manager() -> void:
	if input_manager == null:
		input_manager = get_tree().get_first_node_in_group(
			"input_manager"
		) as InputManager

func _resolve_local_multiplayer_manager() -> void:
	if local_multiplayer_manager == null:
		local_multiplayer_manager = get_tree().get_first_node_in_group(
			"local_multiplayer_manager"
		) as LocalMultiplayerManager

func _resolve_world_runtime() -> void:
	if world_runtime == null:
		world_runtime = get_tree().get_first_node_in_group(
			"world_runtime"
		) as WorldRuntime

func _on_progression_changed(_value: int, _secondary_value: int = 0) -> void:
	if autosave_progression and _auto_persistence_enabled():
		request_save()

func _on_unlocks_changed(_unlock_ids: Array[StringName]) -> void:
	if autosave_progression and _auto_persistence_enabled():
		request_save()

func _on_game_mode_changed(mode_id: StringName) -> void:
	if mode_id != GameConstants.MODE_MENU:
		set_last_mode(mode_id)

func _on_audio_settings_changed(_settings: Dictionary) -> void:
	if _auto_persistence_enabled():
		request_save()

func _on_visual_settings_changed(_settings: Dictionary) -> void:
	if _auto_persistence_enabled():
		request_save()

func _on_video_settings_changed(_settings: Dictionary) -> void:
	if _auto_persistence_enabled():
		request_save()

func _on_controls_changed(_settings: Dictionary) -> void:
	if _auto_persistence_enabled():
		request_save()

func _on_world_state_changed(_state: WorldExplorationState) -> void:
	if _auto_persistence_enabled():
		request_save()

func _on_region_runtime_changed(_region_id: StringName) -> void:
	if _auto_persistence_enabled():
		request_save()

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
