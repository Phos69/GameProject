extends Node
class_name RuntimeDiagnostics

## Scatola nera runtime per freeze, OOM e crash nativi. Il log strutturato viene
## flushato periodicamente: se il processo termina senza _exit_tree(), l'ultima
## sessione resta marcata come incompleta e viene conservata al boot seguente.

const LOG_DIRECTORY := "user://diagnostics"
const LATEST_LOG_PATH := LOG_DIRECTORY + "/runtime_latest.jsonl"
const PREVIOUS_LOG_PATH := LOG_DIRECTORY + "/runtime_previous.jsonl"
const ENGINE_LOG_PATH := "user://logs/godot.log"
const SAMPLE_INTERVAL_SECONDS := 2.0
const LOW_AVAILABLE_MEMORY_BYTES := 512 * 1024 * 1024
# Tre/quattro root possono comparire transitoriamente durante grace + prefetch;
# lo streamer assegna gia priorita al backlog da tre. Il warning parte solo
# oltre il massimo transitorio osservato e resta separato dallo stall per eta.
const RETIREMENT_WARNING_ROOTS := 5
const RETIREMENT_WARNING_AGE_MSEC := 10_000

@export var persistence_enabled: bool = true

var _log_file: FileAccess
var _sample_timer: float = 0.0
var _session_started_unix: int = 0
var _max_frame_msec_since_sample: float = 0.0
var _frames_over_50_msec: int = 0
var _last_anomaly_signature: String = ""
var _session_open: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("runtime_diagnostics")
	if not persistence_enabled:
		set_process(false)
		return
	_start_session()


func _process(delta: float) -> void:
	var frame_msec := delta * 1000.0
	_max_frame_msec_since_sample = maxf(_max_frame_msec_since_sample, frame_msec)
	if frame_msec >= 50.0:
		_frames_over_50_msec += 1
	_sample_timer -= delta
	if _sample_timer > 0.0:
		return
	_sample_timer = SAMPLE_INTERVAL_SECONDS
	_write_sample()


func _exit_tree() -> void:
	mark_clean_shutdown("scene_tree_exit")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		mark_clean_shutdown("window_close")


func mark_clean_shutdown(reason: String = "requested") -> void:
	if not _session_open:
		return
	_write_record({
		"event": "session_ended",
		"clean_shutdown": true,
		"reason": reason,
		"uptime_msec": Time.get_ticks_msec()
	})
	_log_file.close()
	_log_file = null
	_session_open = false


func collect_snapshot() -> Dictionary:
	var memory_info := OS.get_memory_info()
	var snapshot := {
		"event": "sample",
		"uptime_msec": Time.get_ticks_msec(),
		"session_age_seconds": maxi(Time.get_unix_time_from_system() - _session_started_unix, 0),
		"fps": Performance.get_monitor(Performance.TIME_FPS),
		"process_frame_msec": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"physics_frame_msec": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"max_frame_msec_since_sample": _max_frame_msec_since_sample,
		"frames_over_50_msec_since_sample": _frames_over_50_msec,
		"static_memory_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
		"static_memory_peak_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC_MAX)),
		"video_memory_bytes": int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)),
		"texture_memory_bytes": int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)),
		"buffer_memory_bytes": int(Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED)),
		"system_physical_memory_bytes": int(memory_info.get("physical", -1)),
		"system_free_memory_bytes": int(memory_info.get("free", -1)),
		"system_available_memory_bytes": int(memory_info.get("available", -1)),
		"object_count": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"resource_count": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		"node_count": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphan_node_count": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"enemy_count": get_tree().get_node_count_in_group("enemies"),
		"player_count": get_tree().get_node_count_in_group("players"),
		"mode_id": _active_mode_id(),
		"streaming": _streaming_snapshot()
	}
	snapshot["anomalies"] = _detect_anomalies(snapshot)
	return snapshot


func get_log_paths() -> Dictionary:
	return {
		"latest": ProjectSettings.globalize_path(LATEST_LOG_PATH),
		"previous": ProjectSettings.globalize_path(PREVIOUS_LOG_PATH),
		"engine": ProjectSettings.globalize_path(ENGINE_LOG_PATH)
	}


func _start_session() -> void:
	var absolute_directory := ProjectSettings.globalize_path(LOG_DIRECTORY)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_directory)
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		push_warning("[RuntimeDiagnostics] Cannot create %s (error %d)" % [absolute_directory, directory_error])
		return
	var previous_session_unclean := false
	if FileAccess.file_exists(LATEST_LOG_PATH):
		var previous_text := FileAccess.get_file_as_string(LATEST_LOG_PATH)
		previous_session_unclean = not previous_text.contains('"event":"session_ended"')
		var absolute_previous := ProjectSettings.globalize_path(PREVIOUS_LOG_PATH)
		if FileAccess.file_exists(PREVIOUS_LOG_PATH):
			DirAccess.remove_absolute(absolute_previous)
		DirAccess.rename_absolute(
			ProjectSettings.globalize_path(LATEST_LOG_PATH),
			absolute_previous
		)
	_log_file = FileAccess.open(LATEST_LOG_PATH, FileAccess.WRITE)
	if _log_file == null:
		push_warning("[RuntimeDiagnostics] Cannot open %s (error %d)" % [
			ProjectSettings.globalize_path(LATEST_LOG_PATH),
			FileAccess.get_open_error()
		])
		return
	_session_open = true
	_session_started_unix = int(Time.get_unix_time_from_system())
	_write_record({
		"event": "session_started",
		"schema_version": 1,
		"previous_session_unclean": previous_session_unclean,
		"engine_version": Engine.get_version_info(),
		"os": OS.get_name(),
		"os_version": OS.get_version(),
		"process_id": OS.get_process_id(),
		"command_line_user_args": Array(OS.get_cmdline_user_args()),
		"paths": get_log_paths()
	})
	print("[RuntimeDiagnostics] latest=%s engine=%s" % [
		ProjectSettings.globalize_path(LATEST_LOG_PATH),
		ProjectSettings.globalize_path(ENGINE_LOG_PATH)
	])
	if previous_session_unclean:
		push_warning(
			"[RuntimeDiagnostics] Previous session ended unexpectedly; preserved at %s"
			% ProjectSettings.globalize_path(PREVIOUS_LOG_PATH)
		)


func _write_sample() -> void:
	var snapshot := collect_snapshot()
	_write_record(snapshot)
	var anomalies := snapshot.get("anomalies", []) as Array
	var anomaly_signature := ",".join(anomalies)
	if not anomalies.is_empty() and anomaly_signature != _last_anomaly_signature:
		push_warning("[RuntimeDiagnostics] %s" % anomaly_signature)
	_last_anomaly_signature = anomaly_signature
	_max_frame_msec_since_sample = 0.0
	_frames_over_50_msec = 0


func _write_record(record: Dictionary) -> void:
	if _log_file == null:
		return
	record["timestamp"] = Time.get_datetime_string_from_system(false, true)
	_log_file.store_line(JSON.stringify(record))
	# Il flush periodico e intenzionale: il file deve restare utile anche dopo
	# kill, OOM o crash nativo, casi nei quali FileAccess non viene chiuso.
	_log_file.flush()


func _active_mode_id() -> String:
	var manager := get_tree().get_first_node_in_group("game_mode_manager")
	if manager == null:
		return "unknown"
	return String(manager.get("active_mode_id"))


func _streaming_snapshot() -> Dictionary:
	var streamer := get_tree().get_first_node_in_group("world_region_streamer")
	if streamer == null or not streamer.has_method("get_streaming_stats"):
		return {}
	var stats := streamer.call("get_streaming_stats") as Dictionary
	stats["current_region_id"] = String(streamer.get("current_region_id"))
	var biome_manager := get_tree().get_first_node_in_group("biome_manager")
	if biome_manager != null and biome_manager.has_method("get_current_region_id"):
		stats["biome_manager_region_id"] = String(
			biome_manager.call("get_current_region_id")
		)
	var world_runtime := get_tree().get_first_node_in_group("world_runtime")
	if world_runtime != null and world_runtime.has_method("get_current_region_id"):
		stats["world_runtime_region_id"] = String(
			world_runtime.call("get_current_region_id")
		)
	var seam := get_tree().get_first_node_in_group("region_seam_system")
	if seam != null and seam.has_method("get_transition_diagnostics"):
		stats["seam"] = seam.call("get_transition_diagnostics")
	return stats


func _detect_anomalies(snapshot: Dictionary) -> Array[String]:
	var anomalies: Array[String] = []
	var available_memory := int(snapshot.get("system_available_memory_bytes", -1))
	if available_memory >= 0 and available_memory < LOW_AVAILABLE_MEMORY_BYTES:
		anomalies.append("low_system_memory")
	var streaming := snapshot.get("streaming", {}) as Dictionary
	if int(streaming.get("pending_retirement_roots", 0)) >= RETIREMENT_WARNING_ROOTS:
		anomalies.append("retirement_backlog")
	if int(streaming.get("oldest_retirement_msec", 0)) >= RETIREMENT_WARNING_AGE_MSEC:
		anomalies.append("retirement_stalled")
	# Corrente + precedente in grace + target in prefetch e uno stato valido.
	if int(streaming.get("gameplay_regions", 0)) > 3:
		anomalies.append("excess_gameplay_regions")
	var seam := streaming.get("seam", {}) as Dictionary
	var authoritative_id := String(seam.get("authoritative_region_id", ""))
	var geometric_id := String(seam.get("geometric_region_id", ""))
	var pending_target_id := String(seam.get("pending_target_region_id", ""))
	if (
		not authoritative_id.is_empty()
		and not geometric_id.is_empty()
		and authoritative_id != geometric_id
		and pending_target_id.is_empty()
	):
		anomalies.append("region_state_mismatch")
	return anomalies
