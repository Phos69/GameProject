extends RefCounted
class_name WorldChunkVisibilityController

signal visual_chunks_changed(loaded_count: int, pending_count: int)

var graph: WorldGraph
var biome_manager: BiomeManager
var current_region_id: StringName = &""
var quality_preset: StringName = &"balanced"
var render_margin_chunks: int = 1
var prefetch_margin_chunks: int = 2
var retain_margin_chunks: int = 3
var unload_grace_msec: int = 2000
var commit_budget_msec: float = 2.0
var max_commits_per_frame: int = 2

var loaded_chunk_keys: Array[StringName] = []
var visible_chunk_keys: Array[StringName] = []
var _pending_requests: Array[Dictionary] = []
var _pending_keys: Dictionary = {}
var _eviction_deadlines: Dictionary = {}
var _last_camera_center := Vector2.INF
var _movement_direction := Vector2.ZERO
var _last_frame_commit_count: int = 0
var _last_frame_commit_msec: float = 0.0
var _max_chunk_commit_msec: float = 0.0
var _total_chunk_commit_msec: float = 0.0
var _total_chunk_commit_count: int = 0
var _visible_missing_chunk_count: int = 0
# I set di coordinate per tier cambiano solo quando la camera attraversa un
# confine di chunk (i margini sono multipli esatti del passo chunk, quindi ogni
# tier trasla della stessa firma): tra un attraversamento e l'altro il refresh
# per-frame ricalcolava set identici. String(region key) -> Rect2i firma.
var _refresh_requested: bool = true
var _refresh_signatures: Dictionary = {}

func configure(
	next_graph: WorldGraph,
	next_biome_manager: BiomeManager,
	next_current_region_id: StringName,
	next_quality_preset: StringName,
	next_render_margin_chunks: int,
	next_prefetch_margin_chunks: int,
	next_retain_margin_chunks: int,
	next_unload_grace_seconds: float,
	next_commit_budget_msec: float,
	next_max_commits_per_frame: int
) -> void:
	var normalized_render_margin := maxi(next_render_margin_chunks, 0)
	var normalized_prefetch_margin := maxi(
		next_prefetch_margin_chunks,
		normalized_render_margin
	)
	var normalized_retain_margin := maxi(
		next_retain_margin_chunks,
		normalized_prefetch_margin
	)
	if (
		graph != next_graph
		or biome_manager != next_biome_manager
		or current_region_id != next_current_region_id
		or quality_preset != next_quality_preset
		or render_margin_chunks != normalized_render_margin
		or prefetch_margin_chunks != normalized_prefetch_margin
		or retain_margin_chunks != normalized_retain_margin
	):
		_refresh_requested = true
	graph = next_graph
	biome_manager = next_biome_manager
	current_region_id = next_current_region_id
	quality_preset = next_quality_preset
	render_margin_chunks = normalized_render_margin
	prefetch_margin_chunks = normalized_prefetch_margin
	retain_margin_chunks = normalized_retain_margin
	unload_grace_msec = maxi(roundi(next_unload_grace_seconds * 1000.0), 0)
	commit_budget_msec = maxf(next_commit_budget_msec, 0.1)
	max_commits_per_frame = maxi(next_max_commits_per_frame, 1)

func mark_dirty() -> void:
	_refresh_requested = true

func clear() -> void:
	graph = null
	biome_manager = null
	loaded_chunk_keys.clear()
	visible_chunk_keys.clear()
	_pending_requests.clear()
	_pending_keys.clear()
	_eviction_deadlines.clear()
	_last_camera_center = Vector2.INF
	_movement_direction = Vector2.ZERO
	_last_frame_commit_count = 0
	_last_frame_commit_msec = 0.0
	_max_chunk_commit_msec = 0.0
	_total_chunk_commit_msec = 0.0
	_total_chunk_commit_count = 0
	_visible_missing_chunk_count = 0
	_refresh_requested = true
	_refresh_signatures.clear()

func process(entries: Dictionary, viewport: Viewport) -> void:
	_last_frame_commit_count = 0
	_last_frame_commit_msec = 0.0
	# Refresh completo solo quando l'esito puo' cambiare: firma camera/chunk
	# diversa, eviction in scadenza o richiesta esplicita (mark_dirty, cambio
	# regione, build completata). Con la camera dentro lo stesso chunk il
	# refresh e' un no-op e saltarlo elimina il costo fisso per-frame dello
	# streaming (allocazioni chiavi, sort, scansione dei chunk residenti).
	if _should_refresh(entries, viewport):
		refresh(entries, viewport)
	_process_pending(entries)
	if _last_frame_commit_count > 0:
		refresh(entries, viewport, true)

func prepare_area(
	entries: Dictionary,
	viewport: Viewport,
	world_rect: Rect2 = Rect2()
) -> bool:
	refresh(entries, viewport, true, world_rect)
	return is_area_ready(entries, viewport, world_rect)

func prepare_area_immediate(
	entries: Dictionary,
	viewport: Viewport,
	world_rect: Rect2 = Rect2()
) -> bool:
	refresh(entries, viewport, true, world_rect)
	while (
		not is_area_ready(entries, viewport, world_rect)
		and not _pending_requests.is_empty()
	):
		var pending_before := _pending_requests.size()
		_process_pending(entries, true)
		refresh(entries, viewport, true, world_rect)
		if _pending_requests.size() >= pending_before:
			break
	return is_area_ready(entries, viewport, world_rect)

func is_area_ready(
	entries: Dictionary,
	viewport: Viewport,
	world_rect: Rect2 = Rect2()
) -> bool:
	if world_rect.size.x <= 0.0 or world_rect.size.y <= 0.0:
		world_rect = get_visible_world_rect(viewport)
	for entry_key in entries.keys():
		var region_id := StringName(entry_key)
		var visible_coords := _chunk_coords_for_region_rect(
			entries,
			region_id,
			world_rect,
			prefetch_margin_chunks
		)
		if visible_coords.is_empty():
			continue
		var entry := entries.get(String(region_id), {}) as Dictionary
		var tile_layer := entry.get("tile_layer") as BiomeTileLayer
		if tile_layer == null or tile_layer.is_building():
			return false
	for key in _chunk_keys_for_world_rect(
		entries,
		world_rect,
		prefetch_margin_chunks
	):
		if not loaded_chunk_keys.has(key):
			return false
	return true

func get_streaming_stats() -> Dictionary:
	return {
		"loaded_visual_chunks": loaded_chunk_keys.size(),
		"visible_visual_chunks": visible_chunk_keys.size(),
		"pending_chunks": _pending_requests.size(),
		"scheduled_chunk_unloads": _eviction_deadlines.size(),
		"visible_missing_chunks": _visible_missing_chunk_count,
		"last_frame_chunk_commits": _last_frame_commit_count,
		"last_frame_chunk_commit_msec": _last_frame_commit_msec,
		"max_chunk_commit_msec": _max_chunk_commit_msec,
		"average_chunk_commit_msec": (
			_total_chunk_commit_msec / float(_total_chunk_commit_count)
			if _total_chunk_commit_count > 0
			else 0.0
		),
		"chunk_commit_budget_msec": commit_budget_msec,
		"max_chunk_commits_per_frame": max_commits_per_frame
	}

func get_pending_chunk_keys() -> Array[StringName]:
	var result: Array[StringName] = []
	for request in _pending_requests:
		result.append(StringName(request.get("key", &"")))
	return result

func get_chunk_coords_for_world_rect(
	entries: Dictionary,
	region_id: StringName,
	world_rect: Rect2,
	margin_chunks: int = 0
) -> Array[Vector2i]:
	return _chunk_coords_for_region_rect(
		entries,
		region_id,
		world_rect,
		maxi(margin_chunks, 0)
	)

func refresh(
	entries: Dictionary,
	viewport: Viewport,
	force: bool = false,
	explicit_world_rect: Rect2 = Rect2()
) -> void:
	if graph == null or biome_manager == null:
		return
	var world_rect := explicit_world_rect
	if world_rect.size.x <= 0.0 or world_rect.size.y <= 0.0:
		world_rect = get_visible_world_rect(viewport)
	if world_rect.size.x <= 0.0 or world_rect.size.y <= 0.0:
		return
	_refresh_requested = false
	_refresh_signatures.clear()
	for entry_key in entries.keys():
		_refresh_signatures[entry_key] = _region_refresh_signature(
			entries,
			StringName(entry_key),
			world_rect
		)
	_update_movement_direction(world_rect.get_center())
	var next_loaded_keys: Array[StringName] = []
	var next_visible_keys: Array[StringName] = []
	var desired_request_priorities := {}
	var resident_keys := {}
	var visible_missing_count := 0
	for region_id in _ordered_region_ids(entries):
		var entry := entries.get(String(region_id), {}) as Dictionary
		var tile_layer := entry.get("tile_layer") as BiomeTileLayer
		var visible_coords := _chunk_coords_for_region_rect(
			entries,
			region_id,
			world_rect,
			0
		)
		if tile_layer == null or tile_layer.is_building():
			# A visible region whose tile layer is not ready is missing all of
			# its intersecting chunks. Skipping it produced a false zero while
			# gameplay objects could already be present over an empty backdrop.
			visible_missing_count += visible_coords.size()
			continue
		var loaded_coords := _chunk_coords_for_region_rect(
			entries,
			region_id,
			world_rect,
			render_margin_chunks
		)
		var prefetch_coords := _chunk_coords_for_region_rect(
			entries,
			region_id,
			world_rect,
			prefetch_margin_chunks
		)
		var retain_coords := _chunk_coords_for_region_rect(
			entries,
			region_id,
			world_rect,
			retain_margin_chunks
		)
		var retained_resident_coords := _apply_retention_policy(
			region_id,
			tile_layer,
			retain_coords
		)
		tile_layer.evict_chunks_except(retained_resident_coords)
		_queue_requests(
			region_id,
			tile_layer,
			visible_coords,
			desired_request_priorities,
			0
		)
		_queue_requests(
			region_id,
			tile_layer,
			loaded_coords,
			desired_request_priorities,
			1
		)
		_queue_requests(
			region_id,
			tile_layer,
			prefetch_coords,
			desired_request_priorities,
			2
		)
		tile_layer.set_active_chunk_coords(visible_coords)
		for coord in tile_layer.get_resident_chunk_coords():
			var resident_key := _make_chunk_key(region_id, coord)
			resident_keys[resident_key] = true
			next_loaded_keys.append(resident_key)
		for coord in visible_coords:
			if tile_layer.has_chunk(coord):
				next_visible_keys.append(_make_chunk_key(region_id, coord))
			else:
				visible_missing_count += 1
	_prune_pending_requests(desired_request_priorities)
	_sort_pending_requests(
		desired_request_priorities,
		entries,
		world_rect.get_center()
	)
	for deadline_key in _eviction_deadlines.keys().duplicate():
		if not resident_keys.has(deadline_key):
			_eviction_deadlines.erase(deadline_key)
	next_loaded_keys.sort()
	next_visible_keys.sort()
	if (
		not force
		and next_loaded_keys == loaded_chunk_keys
		and next_visible_keys == visible_chunk_keys
		and visible_missing_count == _visible_missing_chunk_count
	):
		return
	loaded_chunk_keys = next_loaded_keys
	visible_chunk_keys = next_visible_keys
	_visible_missing_chunk_count = visible_missing_count
	visual_chunks_changed.emit(
		loaded_chunk_keys.size(),
		_pending_requests.size()
	)

func _should_refresh(entries: Dictionary, viewport: Viewport) -> bool:
	if _refresh_requested:
		return true
	if graph == null or biome_manager == null:
		return false
	if not _eviction_deadlines.is_empty():
		var now := Time.get_ticks_msec()
		for deadline in _eviction_deadlines.values():
			if now >= int(deadline):
				return true
	var world_rect := get_visible_world_rect(viewport)
	if world_rect.size.x <= 0.0 or world_rect.size.y <= 0.0:
		return false
	if entries.size() != _refresh_signatures.size():
		return true
	for entry_key in entries.keys():
		if (
			not _refresh_signatures.has(entry_key)
			or _refresh_signatures[entry_key]
			!= _region_refresh_signature(entries, StringName(entry_key), world_rect)
		):
			return true
	return false

# Firma del rect camera in coordinate chunk (pre-clamp) per una regione: Rect2i
# con position = chunk minimo e size = chunk massimo. I margini di tier sono
# multipli esatti del passo chunk, quindi ogni tier trasla di un numero intero
# di chunk rispetto a questa firma: se non cambia, nessun set per-tier cambia.
func _region_refresh_signature(
	entries: Dictionary,
	region_id: StringName,
	world_rect: Rect2
) -> Rect2i:
	var region := graph.get_region(region_id) if graph != null else null
	var layout := _layout_for_region(region)
	if layout == null or layout.logical_tile_scale <= 0.0:
		return Rect2i(0, 0, -1, -1)
	var entry := entries.get(String(region_id), {}) as Dictionary
	var offset: Vector2 = entry.get("offset", Vector2.ZERO)
	var scale := layout.logical_tile_scale
	var half_zone := Vector2(layout.zone_size) * 0.5
	var min_cell := Vector2i(
		floori((world_rect.position.x - offset.x) / scale + half_zone.x),
		floori((world_rect.position.y - offset.y) / scale + half_zone.y)
	)
	var max_cell := Vector2i(
		ceili((world_rect.end.x - offset.x) / scale + half_zone.x),
		ceili((world_rect.end.y - offset.y) / scale + half_zone.y)
	)
	var chunk := float(_chunk_size_for_quality())
	return Rect2i(
		Vector2i(
			floori(float(min_cell.x) / chunk),
			floori(float(min_cell.y) / chunk)
		),
		Vector2i(
			floori(float(max_cell.x - 1) / chunk),
			floori(float(max_cell.y - 1) / chunk)
		)
	)

static func get_visible_world_rect(viewport: Viewport) -> Rect2:
	if viewport == null:
		return Rect2()
	var camera := viewport.get_camera_2d()
	if camera == null:
		return Rect2()
	var viewport_size := viewport.get_visible_rect().size
	var camera_zoom := Vector2(
		maxf(camera.zoom.x, 0.01),
		maxf(camera.zoom.y, 0.01)
	)
	var world_size := Vector2(
		viewport_size.x / camera_zoom.x,
		viewport_size.y / camera_zoom.y
	)
	return Rect2(
		camera.get_screen_center_position() - world_size * 0.5,
		world_size
	)

func _process_pending(entries: Dictionary, ignore_budget: bool = false) -> void:
	if _pending_requests.is_empty():
		return
	var started_usec := Time.get_ticks_usec()
	var committed := 0
	while (
		not _pending_requests.is_empty()
		and (ignore_budget or committed < max_commits_per_frame)
		and (
			ignore_budget
			or
			committed == 0
			or float(Time.get_ticks_usec() - started_usec) / 1000.0
			< commit_budget_msec
		)
	):
		var request := _pending_requests.pop_front() as Dictionary
		var request_key := StringName(request.get("key", &""))
		_pending_keys.erase(request_key)
		var region_id := StringName(request.get("region_id", &""))
		var coord: Vector2i = request.get("coord", Vector2i.ZERO)
		var entry := entries.get(String(region_id), {}) as Dictionary
		var tile_layer := entry.get("tile_layer") as BiomeTileLayer
		if (
			tile_layer == null
			or tile_layer.is_building()
			or tile_layer.has_chunk(coord)
		):
			continue
		var chunk_started_usec := Time.get_ticks_usec()
		if tile_layer.ensure_chunk(coord):
			var chunk_elapsed_msec := (
				float(Time.get_ticks_usec() - chunk_started_usec) / 1000.0
			)
			committed += 1
			_last_frame_commit_count += 1
			_last_frame_commit_msec += chunk_elapsed_msec
			_max_chunk_commit_msec = maxf(
				_max_chunk_commit_msec,
				chunk_elapsed_msec
			)
			_total_chunk_commit_msec += chunk_elapsed_msec
			_total_chunk_commit_count += 1

func _queue_requests(
	region_id: StringName,
	tile_layer: BiomeTileLayer,
	coords: Array[Vector2i],
	desired_request_priorities: Dictionary,
	priority_tier: int
) -> void:
	# Niente ordinamento qui: l'ordine di inserimento e' irrilevante perche' ogni
	# refresh riordina l'intera coda con _sort_pending_requests (tier, regione,
	# distanza dalla camera). Il caso comune - tutti i chunk gia' residenti - resta
	# una passata lineare senza allocazioni.
	for coord in coords:
		var key := _make_chunk_key(region_id, coord)
		desired_request_priorities[key] = mini(
			int(desired_request_priorities.get(key, priority_tier)),
			priority_tier
		)
		if tile_layer.has_chunk(coord):
			continue
		if _pending_keys.has(key):
			continue
		_pending_keys[key] = true
		_pending_requests.append({
			"key": key,
			"region_id": region_id,
			"coord": coord
		})

func _ordered_region_ids(entries: Dictionary) -> Array[StringName]:
	var result: Array[StringName] = []
	for key in entries.keys():
		result.append(StringName(key))
	result.sort()
	result.erase(current_region_id)
	if entries.has(String(current_region_id)):
		result.push_front(current_region_id)
	return result

func _apply_retention_policy(
	region_id: StringName,
	tile_layer: BiomeTileLayer,
	retain_coords: Array[Vector2i]
) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var now := Time.get_ticks_msec()
	var retained_lookup := {}
	for coord in retain_coords:
		retained_lookup[coord] = true
	for coord in tile_layer.get_resident_chunk_coords():
		var key := _make_chunk_key(region_id, coord)
		if retained_lookup.has(coord):
			_eviction_deadlines.erase(key)
			result.append(coord)
			continue
		if not _eviction_deadlines.has(key):
			_eviction_deadlines[key] = now + unload_grace_msec
		if now < int(_eviction_deadlines[key]):
			result.append(coord)
		else:
			_eviction_deadlines.erase(key)
	return result

func _prune_pending_requests(desired_request_priorities: Dictionary) -> void:
	var retained_requests: Array[Dictionary] = []
	for request in _pending_requests:
		var key := StringName(request.get("key", &""))
		if desired_request_priorities.has(key):
			retained_requests.append(request)
		else:
			_pending_keys.erase(key)
	_pending_requests = retained_requests

func _sort_pending_requests(
	desired_request_priorities: Dictionary,
	entries: Dictionary,
	camera_center: Vector2
) -> void:
	_pending_requests.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			var a_key := StringName(a.get("key", &""))
			var b_key := StringName(b.get("key", &""))
			var a_tier := int(desired_request_priorities.get(a_key, 99))
			var b_tier := int(desired_request_priorities.get(b_key, 99))
			if a_tier != b_tier:
				return a_tier < b_tier
			var a_region_id := StringName(a.get("region_id", &""))
			var b_region_id := StringName(b.get("region_id", &""))
			var a_region_rank := 0 if a_region_id == current_region_id else 1
			var b_region_rank := 0 if b_region_id == current_region_id else 1
			if a_region_rank != b_region_rank:
				return a_region_rank < b_region_rank
			var a_coord: Vector2i = a.get("coord", Vector2i.ZERO)
			var b_coord: Vector2i = b.get("coord", Vector2i.ZERO)
			var a_priority := _chunk_priority(
				entries,
				a_region_id,
				a_coord,
				camera_center
			)
			var b_priority := _chunk_priority(
				entries,
				b_region_id,
				b_coord,
				camera_center
			)
			if not is_equal_approx(a_priority, b_priority):
				return a_priority < b_priority
			return String(a_key) < String(b_key)
	)

func _update_movement_direction(camera_center: Vector2) -> void:
	if _last_camera_center != Vector2.INF:
		var movement := camera_center - _last_camera_center
		if movement.length_squared() > 1.0:
			_movement_direction = movement.normalized()
	_last_camera_center = camera_center

func _chunk_priority(
	entries: Dictionary,
	region_id: StringName,
	coord: Vector2i,
	camera_center: Vector2
) -> float:
	var chunk_center := _chunk_world_center(entries, region_id, coord)
	var delta := chunk_center - camera_center
	var forward_bias := delta.dot(_movement_direction) * 0.35
	return delta.length() - forward_bias

func _chunk_world_center(
	entries: Dictionary,
	region_id: StringName,
	coord: Vector2i
) -> Vector2:
	var region := graph.get_region(region_id) if graph != null else null
	var layout := _layout_for_region(region)
	if layout == null:
		return Vector2.ZERO
	var entry := entries.get(String(region_id), {}) as Dictionary
	var offset: Vector2 = entry.get("offset", Vector2.ZERO)
	var chunk_size := _chunk_size_for_quality()
	var cell_center := Vector2(coord * chunk_size) + Vector2.ONE * float(chunk_size) * 0.5
	return (
		offset
		+ (
			cell_center
			- Vector2(layout.zone_size) * 0.5
		) * layout.logical_tile_scale
	)

func _chunk_keys_for_world_rect(
	entries: Dictionary,
	world_rect: Rect2,
	margin_chunks: int
) -> Array[StringName]:
	var result: Array[StringName] = []
	for key in entries.keys():
		var region_id := StringName(key)
		var entry := entries[key] as Dictionary
		var tile_layer := entry.get("tile_layer") as BiomeTileLayer
		if tile_layer == null:
			continue
		for coord in _chunk_coords_for_region_rect(
			entries,
			region_id,
			world_rect,
			margin_chunks
		):
			result.append(_make_chunk_key(region_id, coord))
	result.sort()
	return result

func _chunk_coords_for_region_rect(
	entries: Dictionary,
	region_id: StringName,
	world_rect: Rect2,
	margin_chunks: int
) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var region := graph.get_region(region_id) if graph != null else null
	var layout := _layout_for_region(region)
	if layout == null:
		return result
	var entry := entries.get(String(region_id), {}) as Dictionary
	var offset: Vector2 = entry.get("offset", Vector2.ZERO)
	var chunk_size := _chunk_size_for_quality()
	var margin_world := (
		float(margin_chunks * chunk_size)
		* layout.logical_tile_scale
	)
	var expanded := world_rect.grow(margin_world)
	var local_start := expanded.position - offset
	var local_end := expanded.end - offset
	var half_zone := Vector2(layout.zone_size) * 0.5
	var min_cell := Vector2i(
		floori(local_start.x / layout.logical_tile_scale + half_zone.x),
		floori(local_start.y / layout.logical_tile_scale + half_zone.y)
	)
	var max_cell := Vector2i(
		ceili(local_end.x / layout.logical_tile_scale + half_zone.x),
		ceili(local_end.y / layout.logical_tile_scale + half_zone.y)
	)
	min_cell = min_cell.clamp(Vector2i.ZERO, layout.zone_size)
	max_cell = max_cell.clamp(Vector2i.ZERO, layout.zone_size)
	if max_cell.x <= min_cell.x or max_cell.y <= min_cell.y:
		return result
	var min_coord := Vector2i(
		min_cell.x / chunk_size,
		min_cell.y / chunk_size
	)
	var max_coord := Vector2i(
		(max_cell.x - 1) / chunk_size,
		(max_cell.y - 1) / chunk_size
	)
	for y in range(min_coord.y, max_coord.y + 1):
		for x in range(min_coord.x, max_coord.x + 1):
			result.append(Vector2i(x, y))
	return result

func _layout_for_region(region: WorldRegion) -> BiomeEnvironmentLayout:
	if biome_manager == null:
		return null
	return biome_manager.get_layout_for_region(region)

# Deve corrispondere alla dimensione chunk scelta dal BiomeTileLayer, altrimenti
# le coordinate chunk del controller non mappano piu' sui nodi del layer.
func _chunk_size_for_quality() -> int:
	return BiomeTileLayer.chunk_size_for_preset(quality_preset)

func _make_chunk_key(
	region_id: StringName,
	coord: Vector2i
) -> StringName:
	return StringName("%s:%d:%d" % [String(region_id), coord.x, coord.y])
