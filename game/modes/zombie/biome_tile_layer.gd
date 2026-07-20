extends Node2D
class_name BiomeTileLayer

signal build_completed

enum AsyncGeometryPhase {
	IDLE = -1,
	RESET = 0,
	SURFACE_MASK = 1,
	CHUNKS = 2,
	CLIFFS = 3,
	BORDERS = 4,
	MESAS = 5,
	CLEANUP = 6
}

const DEFAULT_CHUNK_SIZE := 10
const PERFORMANCE_CHUNK_SIZE := 13
const QUALITY_CHUNK_SIZE := 8
const CLIFF_MESH_BUILDER_SCRIPT = preload(
	"res://game/modes/zombie/cliffs/top_down_cliff_mesh_builder.gd"
)
const CLIFF_BORDER_MESH_BUILDER_SCRIPT = preload(
	"res://game/modes/zombie/cliffs/top_down_cliff_border_mesh_builder.gd"
)
const RECTILINEAR_CLIFF_FACE_MESH_BUILDER_SCRIPT = preload(
	"res://game/modes/zombie/cliffs/rectilinear_cliff_face_mesh_builder.gd"
)
const RECTILINEAR_ROCK_AREA_MESH_BUILDER_SCRIPT = preload(
	"res://game/modes/zombie/rocks/rectilinear_rock_area_mesh_builder.gd"
)
const SVG_TEXTURE_LOADER = preload(
	"res://game/modes/zombie/environment_texture_loader.gd"
)
const TILE_BAKE_CACHE = preload(
	"res://game/modes/zombie/tile_bake_cache.gd"
)
const GENERATED_ART_CATALOG = preload(
	"res://game/modes/zombie/biome_generated_art_catalog.gd"
)
const GENERATED_TEXTURE_TOOLS = preload(
	"res://game/modes/zombie/generated_biome_texture_tools.gd"
)
const TERRAIN_SURFACE_CLASSIFIER = preload(
	"res://game/modes/zombie/terrain/terrain_surface_classifier.gd"
)
const TERRAIN_BOUNDARY_MASK_BUILDER = preload(
	"res://game/modes/zombie/terrain/terrain_boundary_mask_builder.gd"
)
const BIOME_TILE_CHUNK_BAKER_SCRIPT = preload(
	"res://game/modes/zombie/terrain/biome_tile_chunk_baker.gd"
)
const CLIFF_FACE_TEXTURE_ID := &"cliff_face_texture"
const CLIFF_LIP_TEXTURE_ID := &"cliff_lip_texture"
const CLIFF_LIP_VERTICAL_TEXTURE_ID := &"cliff_lip_vertical_texture"
const ROCK_CLIFF_FACE_TEXTURE_ID := &"rock_cliff_face_texture"
const LARGE_ROCK_OBJECT_ID := &"large_rock"
const FOREST_MESA_PROFILE_ID := &"forest"
const FOREST_GRASS_TEXTURE_ID := &"forest_grass"
const FOREST_PATH_TEXTURE_ID := &"forest_path"
const FOREST_ROAD_TEXTURE_ID := &"forest_road"
const TERRAIN_DIVIDER_TEXTURE_ID := &"terrain_divider_dirt"
const FOREST_SURFACE_TEXTURE_WORLD_SIZE := 256.0
const TERRAIN_DIVIDER_TEXTURE_WORLD_SIZE := 256.0
const TOXIC_SURFACE_TEXTURE_WORLD_SIZE := 1024.0
const FROZEN_SURFACE_TEXTURE_WORLD_SIZE := 512.0
const FROZEN_GROUND_TEXTURE_WORLD_SIZE := 1024.0
const MARSH_SURFACE_TEXTURE_WORLD_SIZE := 512.0
const MARSH_GROUND_TEXTURE_WORLD_SIZE := 1024.0
const BURNING_SURFACE_TEXTURE_WORLD_SIZE := 512.0
const FOREST_SURFACE_TEXTURE_IDS: Array[StringName] = [
	&"forest_grass",
	&"forest_path",
	&"forest_road",
]
var layout: BiomeEnvironmentLayout
var palette: BiomePalette
var biome_id: StringName = &""
var quality_preset: StringName = &"balanced"
var chunk_size: int = DEFAULT_CHUNK_SIZE
## Posizione del centro regione nel sistema condiviso usato per il repeat delle
## texture. Lo streamer passa l'offset della regione, cosi la fase non riparte
## sui seam; i layer standalone mantengono Vector2.ZERO.
var terrain_texture_world_origin := Vector2.ZERO
var manifest: EnvironmentAssetManifest
var resolver: BiomeTileResolver

var _chunks: Array[Rect2i] = []
var _tile_id_cache: Dictionary = {}
var _tile_section_cache: Dictionary = {}
var _tile_role_cache: Dictionary = {}
var _asset_path_cache: Dictionary = {}
var _material_asset_id_cache: Dictionary = {}
var _material_asset_path_cache: Dictionary = {}
var _missing_asset_count: int = 0
# The whole static ground is baked once into meshes instead of issuing one draw
# command per cell every frame. Godot re-walks a canvas item's full command list
# each frame, so per-tile draw commands were the dominant constant frame cost on
# gl_compatibility.
var _ground_mesh: ArrayMesh
var _ground_underlay_mesh: ArrayMesh
var _forest_surface_meshes: Dictionary = {}
var _cliff_mesh_builder: TopDownCliffMeshBuilder
var _cliff_border_mesh_builder: TopDownCliffBorderMeshBuilder
var _mesa_dirt_border_mesh_builder: TopDownCliffBorderMeshBuilder
var _rectilinear_cliff_face_mesh_builder: RectilinearCliffFaceMeshBuilder
var _rock_area_mesh_builder: RectilinearRockAreaMeshBuilder
var _mesa_area_mesh_builders: Dictionary = {}
var _cliff_face_texture: Texture2D
var _cliff_lip_texture: Texture2D
var _cliff_lip_vertical_texture: Texture2D
var _rock_top_texture: Texture2D
var _rock_cliff_face_texture: Texture2D
var _forest_surface_textures: Dictionary = {}
var _forest_surface_art_asset_paths: Dictionary = {}
var _surface_texture_ids: Array[StringName] = []
var _terrain_surface_mask_data: Dictionary = {}
var _terrain_surface_mask_texture: ImageTexture
var _terrain_surface_texture_ids: Dictionary = {}
var _fallback_surface_textures: Dictionary = {}
var _cliff_art_asset_paths: Dictionary = {}
var _cliff_variant_textures: Dictionary = {}
var _rock_art_asset_paths: Dictionary = {}
var _mesa_art_by_profile: Dictionary = {}
var _mesa_art_asset_paths: Dictionary = {}
var _mesa_profile_mismatch_count: int = 0
var _grid_points: PackedVector2Array = PackedVector2Array()
var _texture_dark_lines: PackedVector2Array = PackedVector2Array()
var _texture_light_lines: PackedVector2Array = PackedVector2Array()
var _transition_lines: PackedVector2Array = PackedVector2Array()
var _depth_lines: PackedVector2Array = PackedVector2Array()
var _suppressed_void_texture_count: int = 0
var _chunk_nodes: Dictionary = {}
var _uses_chunk_nodes: bool = false
var _build_all_chunks_on_finalize: bool = true
var _cliff_transition_built_chunks: Dictionary = {}
# WorkerThreadPool task for the CPU-heavy tile cache. Meshes and chunk nodes
# are finalized on the main thread in separate phases, one phase per frame.
var _build_task_id: int = -1
var _is_building: bool = false
var _async_geometry_phase: int = AsyncGeometryPhase.IDLE
var _async_chunk_cursor: int = 0
var _last_geometry_phase_msec: float = 0.0
var _max_geometry_phase_msec: float = 0.0
# Chiave del tile-bake su disco (TileBakeCache): un hit salta l'intero loop di
# resolve per-cella, la parte dominante del bake.
var _bake_key: String = ""

func prewarm_assets(
	next_layout: BiomeEnvironmentLayout,
	next_palette: BiomePalette,
	next_biome_id: StringName,
	next_manifest: EnvironmentAssetManifest = null
) -> void:
	layout = next_layout
	palette = next_palette
	biome_id = next_biome_id
	manifest = (
		next_manifest
		if next_manifest != null
		else EnvironmentAssetManifest.get_shared()
	)
	_load_cliff_art_textures()
	_load_forest_surface_art_textures()
	_load_rock_art_texture()

func configure(
	next_layout: BiomeEnvironmentLayout,
	next_palette: BiomePalette,
	next_biome_id: StringName,
	next_quality_preset: StringName = &"balanced",
	next_chunk_size: int = 0,
	next_resolver: BiomeTileResolver = null,
	next_manifest: EnvironmentAssetManifest = null,
	async_build: bool = false,
	build_all_chunks: bool = true,
	next_terrain_texture_world_origin: Vector2 = Vector2.ZERO
) -> void:
	layout = next_layout
	palette = next_palette
	biome_id = next_biome_id
	quality_preset = next_quality_preset
	terrain_texture_world_origin = next_terrain_texture_world_origin
	manifest = next_manifest if next_manifest != null else EnvironmentAssetManifest.get_shared()
	resolver = next_resolver if next_resolver != null else BiomeTileResolver.new(manifest)
	_load_cliff_art_textures()
	_load_forest_surface_art_textures()
	_load_rock_art_texture()
	_cliff_mesh_builder = CLIFF_MESH_BUILDER_SCRIPT.new() as TopDownCliffMeshBuilder
	_cliff_border_mesh_builder = (
		CLIFF_BORDER_MESH_BUILDER_SCRIPT.new() as TopDownCliffBorderMeshBuilder
	)
	_mesa_dirt_border_mesh_builder = (
		CLIFF_BORDER_MESH_BUILDER_SCRIPT.new() as TopDownCliffBorderMeshBuilder
	)
	var divider_repeat_world := _terrain_divider_texture_world_size()
	_cliff_border_mesh_builder.transition_texture_repeat_world_size = divider_repeat_world
	_mesa_dirt_border_mesh_builder.transition_texture_repeat_world_size = divider_repeat_world
	_rectilinear_cliff_face_mesh_builder = (
		RECTILINEAR_CLIFF_FACE_MESH_BUILDER_SCRIPT.new() as RectilinearCliffFaceMeshBuilder
	)
	_cliff_mesh_builder.configure(
		palette,
		layout.generation_seed if layout != null else 0,
		has_cliff_art_textures()
	)
	chunk_size = _resolve_chunk_size(next_chunk_size, quality_preset)
	_build_all_chunks_on_finalize = build_all_chunks
	z_index = -9
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	# Vedi BiomeTileChunk: filtering con mipmap per le texture minificate.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_to_group("biome_tile_layers")
	_rebuild_chunks()
	_bake_key = TILE_BAKE_CACHE.make_key(
		biome_id,
		quality_preset,
		layout.get_generation_signature() if layout != null else "",
		chunk_size
	)
	if async_build:
		# The node is already in the tree but draws nothing until the bake finishes.
		_is_building = true
		_async_geometry_phase = AsyncGeometryPhase.IDLE
		set_process(false)
		_build_task_id = WorkerThreadPool.add_task(
			_threaded_build,
			false,
			"Biome tile cache %s" % String(biome_id)
		)
		return
	_ensure_tile_cache()
	_rebuild_ground_geometry()
	queue_redraw()

func is_building() -> bool:
	return _is_building

func _threaded_build() -> void:
	# Only deterministic numeric/cache data is prepared off-thread. ArrayMesh and
	# scene-tree chunk creation are finalized on the main thread.
	_ensure_tile_cache()
	call_deferred("_finalize_threaded_build")

# Carica le mappe-tile risolte dalla cache su disco (salta il loop di resolve) o,
# in mancanza, le ribuilda e le persiste. La geometria viene comunque ricostruita
# dal chiamante leggendo queste mappe in O(1).
func _ensure_tile_cache() -> void:
	if layout == null:
		return
	var cell_count := layout.zone_size.x * layout.zone_size.y
	var cached := TILE_BAKE_CACHE.fetch(_bake_key, cell_count)
	if not cached.is_empty():
		_apply_tile_cache_payload(cached)
		return
	_rebuild_tile_cache()
	TILE_BAKE_CACHE.store(_bake_key, cell_count, _tile_cache_payload())

func _tile_cache_payload() -> Dictionary:
	return {
		"tile_id": _tile_id_cache,
		"tile_section": _tile_section_cache,
		"tile_role": _tile_role_cache,
		"asset_path": _asset_path_cache,
		"material_asset_id": _material_asset_id_cache,
		"material_asset_path": _material_asset_path_cache,
		"missing_asset_count": _missing_asset_count
	}

func _apply_tile_cache_payload(payload: Dictionary) -> void:
	_tile_id_cache = payload.get("tile_id", {}) as Dictionary
	_tile_section_cache = payload.get("tile_section", {}) as Dictionary
	_tile_role_cache = payload.get("tile_role", {}) as Dictionary
	_asset_path_cache = payload.get("asset_path", {}) as Dictionary
	_material_asset_id_cache = payload.get("material_asset_id", {}) as Dictionary
	_material_asset_path_cache = payload.get("material_asset_path", {}) as Dictionary
	_missing_asset_count = int(payload.get("missing_asset_count", 0))

func _finalize_threaded_build() -> void:
	if _build_task_id >= 0:
		if not WorkerThreadPool.is_task_completed(_build_task_id):
			call_deferred("_finalize_threaded_build")
			return
		WorkerThreadPool.wait_for_task_completion(_build_task_id)
		_build_task_id = -1
	_async_chunk_cursor = 0
	_async_geometry_phase = AsyncGeometryPhase.RESET
	set_process(true)

func _process(_delta: float) -> void:
	if _async_geometry_phase == AsyncGeometryPhase.IDLE:
		set_process(false)
		return
	var started_usec := Time.get_ticks_usec()
	match _async_geometry_phase:
		AsyncGeometryPhase.RESET:
			_reset_ground_geometry()
			_async_geometry_phase = AsyncGeometryPhase.SURFACE_MASK
		AsyncGeometryPhase.SURFACE_MASK:
			if layout != null and palette != null:
				_rebuild_terrain_surface_mask()
			_async_geometry_phase = AsyncGeometryPhase.CHUNKS
		AsyncGeometryPhase.CHUNKS:
			if (
				_build_all_chunks_on_finalize
				and layout != null
				and _async_chunk_cursor < _chunks.size()
			):
				_build_visual_chunk(
					_chunks[_async_chunk_cursor],
					layout.logical_tile_scale
				)
				_async_chunk_cursor += 1
			else:
				_uses_chunk_nodes = true
				_async_geometry_phase = AsyncGeometryPhase.CLIFFS
		AsyncGeometryPhase.CLIFFS:
			_build_region_cliffs()
			_async_geometry_phase = AsyncGeometryPhase.BORDERS
		AsyncGeometryPhase.BORDERS:
			_build_region_borders()
			_async_geometry_phase = AsyncGeometryPhase.MESAS
		AsyncGeometryPhase.MESAS:
			if layout != null and palette != null:
				_rebuild_mesa_geometry(layout.logical_tile_scale)
			_async_geometry_phase = AsyncGeometryPhase.CLEANUP
		AsyncGeometryPhase.CLEANUP:
			_cleanup_ground_buffers()
			_async_geometry_phase = AsyncGeometryPhase.IDLE
			_is_building = false
			set_process(false)
			queue_redraw()
			build_completed.emit()
	_last_geometry_phase_msec = (
		float(Time.get_ticks_usec() - started_usec) / 1000.0
	)
	_max_geometry_phase_msec = maxf(
		_max_geometry_phase_msec,
		_last_geometry_phase_msec
	)

func _exit_tree() -> void:
	if _build_task_id >= 0:
		WorkerThreadPool.wait_for_task_completion(_build_task_id)
		_build_task_id = -1
	_async_geometry_phase = AsyncGeometryPhase.IDLE
	_is_building = false
	_chunk_nodes.clear()

func get_async_build_stats() -> Dictionary:
	return {
		"phase": _async_geometry_phase,
		"last_geometry_phase_msec": _last_geometry_phase_msec,
		"max_geometry_phase_msec": _max_geometry_phase_msec
	}

func get_chunk_count() -> int:
	return _chunks.size()

func get_chunk_size() -> int:
	return chunk_size

func get_quality_preset() -> StringName:
	return quality_preset

func get_visual_tile_count() -> int:
	if layout != null:
		return layout.zone_size.x * layout.zone_size.y
	return _tile_id_cache.size()

func get_cached_visual_tile_count() -> int:
	return _tile_id_cache.size()

func get_loaded_visual_tile_count() -> int:
	if _is_building:
		return 0
	var result := 0
	for node_value in _chunk_nodes.values():
		var chunk := node_value as Node2D
		if chunk != null and is_instance_valid(chunk) and chunk.visible:
			result += int(chunk.call("get_visual_tile_count"))
	return result if _uses_chunk_nodes else get_visual_tile_count()

func get_loaded_chunk_count() -> int:
	if not _uses_chunk_nodes:
		return _chunks.size()
	var count := 0
	for node_value in _chunk_nodes.values():
		var chunk := node_value as Node2D
		if chunk != null and is_instance_valid(chunk) and chunk.visible:
			count += 1
	return count

func get_resident_chunk_count() -> int:
	return _chunk_nodes.size()

func get_resident_chunk_coords() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for key in _chunk_nodes.keys():
		var chunk := _chunk_nodes[key] as Node
		if chunk != null and is_instance_valid(chunk):
			result.append(key as Vector2i)
	result.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or (a.y == b.y and a.x < b.x)
	)
	return result

func has_chunk(coord: Vector2i) -> bool:
	var chunk := _chunk_nodes.get(coord) as Node2D
	return chunk != null and is_instance_valid(chunk)

func get_loaded_chunk_coords() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for key in _chunk_nodes.keys():
		var chunk := _chunk_nodes[key] as Node2D
		if chunk != null and is_instance_valid(chunk) and chunk.visible:
			result.append(key as Vector2i)
	result.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or (a.y == b.y and a.x < b.x)
	)
	return result

func set_active_chunk_coords(coords: Array[Vector2i]) -> void:
	if not _uses_chunk_nodes:
		return
	var active := {}
	for coord in coords:
		active[coord] = true
	for key in _chunk_nodes.keys():
		var chunk := _chunk_nodes[key] as Node2D
		if chunk != null and is_instance_valid(chunk):
			chunk.visible = active.has(key)

func request_chunk(coord: Vector2i) -> bool:
	var chunk := _chunk_nodes.get(coord) as Node2D
	if chunk == null or not is_instance_valid(chunk):
		if not _build_chunk_for_coord(coord):
			return false
		chunk = _chunk_nodes.get(coord) as Node2D
	chunk.visible = true
	return true

func release_chunk(coord: Vector2i) -> bool:
	var chunk := _chunk_nodes.get(coord) as Node2D
	if chunk == null or not is_instance_valid(chunk):
		return false
	chunk.visible = false
	return true

func evict_chunks_except(retained_coords: Array[Vector2i]) -> void:
	if not _uses_chunk_nodes and _chunk_nodes.is_empty():
		return
	var retained := {}
	for coord in retained_coords:
		retained[coord] = true
	for key in _chunk_nodes.keys().duplicate():
		if retained.has(key):
			continue
		evict_chunk(key as Vector2i)
	_uses_chunk_nodes = true

func evict_chunk(coord: Vector2i) -> bool:
	if not _chunk_nodes.has(coord):
		return false
	var chunk := _chunk_nodes.get(coord) as Node
	if chunk != null and is_instance_valid(chunk):
		chunk.set("visible", false)
		if chunk.is_inside_tree():
			chunk.queue_free()
		else:
			chunk.free()
	_chunk_nodes.erase(coord)
	_uses_chunk_nodes = true
	return true

func ensure_chunk(coord: Vector2i) -> bool:
	if has_chunk(coord):
		return true
	return _build_chunk_for_coord(coord)

func get_missing_asset_count() -> int:
	return _missing_asset_count

func uses_procedural_fallback() -> bool:
	return _missing_asset_count > 0

func get_texture_detail_line_count() -> int:
	if _uses_chunk_nodes:
		var chunk_line_count: int = 0
		for chunk_value in _chunk_nodes.values():
			var chunk := chunk_value as BiomeTileChunk
			if chunk != null and is_instance_valid(chunk):
				chunk_line_count += chunk.get_texture_detail_line_count()
		return chunk_line_count
	return int((
		_texture_dark_lines.size()
		+ _texture_light_lines.size()
		+ _transition_lines.size()
		+ _depth_lines.size()
	) / 2)

func get_cliff_transition_count() -> int:
	return _cliff_mesh_builder.transition_count if _cliff_mesh_builder != null else 0

func has_cliff_art_textures() -> bool:
	return _cliff_face_texture != null and _cliff_lip_texture != null

func has_forest_cliff_border_art() -> bool:
	return (
		_uses_themed_ground()
		and _cliff_lip_texture != null
		and _cliff_lip_vertical_texture != null
	)

func uses_mesa_top_for_fall_zone_rim() -> bool:
	return _uses_forest_ground() and _rock_top_texture != null

func get_forest_cliff_border_counts() -> Dictionary:
	if _cliff_border_mesh_builder == null:
		return {}
	return {
		"horizontal": _cliff_border_mesh_builder.horizontal_segment_count,
		"vertical": _cliff_border_mesh_builder.vertical_segment_count,
		"terrain_transitions": (
			_cliff_border_mesh_builder.terrain_transition_segment_count
		),
		"terrain_transition_corners": (
			_cliff_border_mesh_builder.terrain_transition_corner_count
		),
		"diagonal_void_patches": (
			_cliff_border_mesh_builder.diagonal_void_patch_count
		),
		"corners": _cliff_border_mesh_builder.corner_count,
		"concave_corners": _cliff_border_mesh_builder.concave_corner_count,
		"faces": (
			_rectilinear_cliff_face_mesh_builder.face_count
			if _rectilinear_cliff_face_mesh_builder != null
			else 0
		),
		"concave_joins": (
			_rectilinear_cliff_face_mesh_builder.concave_join_count
			if _rectilinear_cliff_face_mesh_builder != null
			else 0
		),
		"total": _cliff_border_mesh_builder.get_total_segment_count()
	}

func get_cliff_art_asset_paths() -> Dictionary:
	return _cliff_art_asset_paths.duplicate(true)

func has_rock_area_art() -> bool:
	return has_mesa_area_art()

func has_mesa_area_art() -> bool:
	for profile_id_value in _mesa_area_mesh_builders:
		var profile_id := StringName(profile_id_value)
		var builder := (
			_mesa_area_mesh_builders.get(profile_id)
			as RectilinearRockAreaMeshBuilder
		)
		var art := _mesa_art_by_profile.get(profile_id, {}) as Dictionary
		if (
			builder != null
			and builder.has_geometry()
			and art.get(&"top") is Texture2D
			and art.get(&"face") is Texture2D
		):
			return true
	return false

func renders_mesa_area_batch() -> bool:
	# Geometry reports remain available for validation, but the terrain canvas no
	# longer draws this batch. Runtime mesa visuals belong to Y-sorted blockers.
	return false

func get_rock_area_counts() -> Dictionary:
	return get_mesa_area_counts()

func get_mesa_area_counts() -> Dictionary:
	var area_count := 0
	var face_count := 0
	var rendered_profiles := 0
	for builder_value in _mesa_area_mesh_builders.values():
		var builder := builder_value as RectilinearRockAreaMeshBuilder
		if builder == null or not builder.has_geometry():
			continue
		var counts := builder.get_counts()
		area_count += int(counts.get("areas", 0))
		face_count += int(counts.get("faces", 0))
		rendered_profiles += 1
	return {
		"areas": area_count,
		"faces": face_count,
		"dirt_transitions": (
			_mesa_dirt_border_mesh_builder.terrain_transition_segment_count
			if _mesa_dirt_border_mesh_builder != null
			else 0
		),
		"dirt_corners": (
			_mesa_dirt_border_mesh_builder.terrain_transition_corner_count
			if _mesa_dirt_border_mesh_builder != null
			else 0
		),
		"dirt_inset_corners": (
			_mesa_dirt_border_mesh_builder.mesa_inset_corner_patch_count
			if _mesa_dirt_border_mesh_builder != null
			else 0
		),
		"profiles": rendered_profiles,
		"profile_mismatches": _mesa_profile_mismatch_count,
		"raise_height_cells": RectilinearRockAreaMeshBuilder.RAISE_HEIGHT_CELLS,
	}

func get_rock_art_asset_paths() -> Dictionary:
	return _rock_art_asset_paths.duplicate(true)

func get_mesa_art_asset_paths() -> Dictionary:
	return _mesa_art_asset_paths.duplicate(true)

func get_mesa_profile_render_report() -> Dictionary:
	var report := {}
	for profile_id_value in _mesa_area_mesh_builders:
		var profile_id := StringName(profile_id_value)
		var builder := (
			_mesa_area_mesh_builders.get(profile_id)
			as RectilinearRockAreaMeshBuilder
		)
		var entry := (
			builder.get_counts() if builder != null else {}
		) as Dictionary
		entry["asset_paths"] = (
			_mesa_art_asset_paths.get(profile_id, {}) as Dictionary
		).duplicate(true)
		entry["has_top_texture"] = (
			(_mesa_art_by_profile.get(profile_id, {}) as Dictionary).get(&"top")
			is Texture2D
		)
		entry["has_face_texture"] = (
			(_mesa_art_by_profile.get(profile_id, {}) as Dictionary).get(&"face")
			is Texture2D
		)
		report[profile_id] = entry
	return report

func has_forest_ground_art_texture() -> bool:
	if _uses_generated_theme():
		return not _surface_texture_ids.is_empty()
	return _forest_surface_textures.get(FOREST_GRASS_TEXTURE_ID) is Texture2D

func get_forest_ground_art_asset_path() -> String:
	if _uses_generated_theme() and not _surface_texture_ids.is_empty():
		return String(
			_forest_surface_art_asset_paths.get(_surface_texture_ids[0], "")
		)
	return String(_forest_surface_art_asset_paths.get(FOREST_GRASS_TEXTURE_ID, ""))

func has_forest_surface_art_textures() -> bool:
	if not _uses_themed_ground():
		return false
	_refresh_terrain_surface_texture_ids()
	for surface_kind in [
		TERRAIN_SURFACE_CLASSIFIER.SURFACE_GRASS,
		TERRAIN_SURFACE_CLASSIFIER.SURFACE_PATH,
		TERRAIN_SURFACE_CLASSIFIER.SURFACE_ASPHALT,
	]:
		var texture_id := StringName(_terrain_surface_texture_ids.get(surface_kind, &""))
		if texture_id.is_empty() or not (_forest_surface_textures.get(texture_id) is Texture2D):
			return false
	return _forest_surface_textures.get(TERRAIN_DIVIDER_TEXTURE_ID) is Texture2D

func get_forest_surface_art_asset_paths() -> Dictionary:
	return _forest_surface_art_asset_paths.duplicate(true)

func get_suppressed_void_texture_count() -> int:
	if _uses_chunk_nodes:
		var suppressed_count: int = 0
		for chunk_value in _chunk_nodes.values():
			var chunk := chunk_value as BiomeTileChunk
			if chunk != null and is_instance_valid(chunk):
				suppressed_count += chunk.get_suppressed_void_texture_count()
		return suppressed_count
	return _suppressed_void_texture_count

func get_void_background_color() -> Color:
	return ZombieModeController.get_void_background_color(palette)

func get_chunk_rects() -> Array[Rect2i]:
	return _chunks.duplicate()

func get_resolved_tile_id(cell: Vector2i) -> StringName:
	var key := _cell_key(cell)
	if _tile_id_cache.has(key):
		return StringName(_tile_id_cache[key])
	if resolver == null:
		return &""
	return resolver.resolve_tile_id(layout, cell, biome_id, quality_preset)

func get_resolved_tile_section(cell: Vector2i) -> StringName:
	var key := _cell_key(cell)
	if _tile_section_cache.has(key):
		return StringName(_tile_section_cache[key])
	if resolver == null:
		return &""
	return StringName(
		resolver.resolve_tile_data(layout, cell, biome_id, quality_preset).get("section", &"")
	)

func get_resolved_tile_role(cell: Vector2i) -> StringName:
	var key := _cell_key(cell)
	if _tile_role_cache.has(key):
		return StringName(_tile_role_cache[key])
	if resolver == null:
		return &""
	return StringName(
		resolver.resolve_tile_data(layout, cell, biome_id, quality_preset).get("role", &"")
	)

func get_resolved_asset_path(cell: Vector2i) -> String:
	var key := _cell_key(cell)
	if _asset_path_cache.has(key):
		return String(_asset_path_cache[key])
	if resolver == null:
		return ""
	return resolver.resolve_asset_path(layout, cell, biome_id, quality_preset)

func get_resolved_material_asset_id(cell: Vector2i) -> StringName:
	var key := _cell_key(cell)
	if _material_asset_id_cache.has(key):
		return StringName(_material_asset_id_cache[key])
	var data := resolver.resolve_tile_data(layout, cell, biome_id, quality_preset)
	return StringName(data.get("material_asset_id", &""))

func get_resolved_material_asset_path(cell: Vector2i) -> String:
	var key := _cell_key(cell)
	if _material_asset_path_cache.has(key):
		return String(_material_asset_path_cache[key])
	var data := resolver.resolve_tile_data(layout, cell, biome_id, quality_preset)
	return String(data.get("material_asset_path", ""))

func get_loaded_surface_texture_ids() -> Array[StringName]:
	return _surface_texture_ids.duplicate()

func get_rendered_surface_material_ids() -> Array[StringName]:
	if _uses_chunk_nodes:
		var resident_material_ids := {}
		for chunk_value in _chunk_nodes.values():
			var chunk := chunk_value as BiomeTileChunk
			if chunk == null or not is_instance_valid(chunk):
				continue
			for material_id in chunk.get_rendered_surface_material_ids():
				resident_material_ids[material_id] = true
		var chunk_result: Array[StringName] = []
		for material_id in resident_material_ids.keys():
			chunk_result.append(material_id as StringName)
		chunk_result.sort()
		return chunk_result
	var result: Array[StringName] = []
	for material_id in _surface_texture_ids:
		var surface_mesh := _forest_surface_meshes.get(material_id) as ArrayMesh
		if surface_mesh != null and surface_mesh.get_surface_count() > 0:
			result.append(material_id)
	return result

func get_terrain_surface_kind(cell: Vector2i) -> int:
	if layout == null:
		return TERRAIN_SURFACE_CLASSIFIER.SURFACE_VOID
	if not _terrain_surface_mask_data.is_empty():
		return TERRAIN_BOUNDARY_MASK_BUILDER.surface_kind_at_cell(
			_terrain_surface_mask_data,
			layout.zone_size,
			cell
		)
	return TERRAIN_SURFACE_CLASSIFIER.classify_cell(layout, resolver, cell)

func get_terrain_boundary_report() -> Dictionary:
	if _terrain_surface_mask_data.is_empty():
		return {}
	return {
		"image_size": _terrain_surface_mask_data.get("image_size", Vector2i.ZERO),
		"pixels_per_tile": int(_terrain_surface_mask_data.get("pixels_per_tile", 0)),
		"divider_pixel_count": int(
			_terrain_surface_mask_data.get("divider_pixel_count", 0)
		),
		"boundary_segment_count": int(
			_terrain_surface_mask_data.get("boundary_segment_count", 0)
		),
		"divider_asset_path": String(
			_forest_surface_art_asset_paths.get(TERRAIN_DIVIDER_TEXTURE_ID, "")
		),
	}

func get_loaded_cliff_variant_count() -> int:
	return _cliff_variant_textures.size()

func has_visual_tile_for_cell(cell: Vector2i) -> bool:
	return _asset_path_exists(get_resolved_asset_path(cell))

func _draw() -> void:
	# Il terreno (underlay/superfici/diamanti/dettagli/griglia) e' disegnato dai
	# BiomeTileChunk figli: _rebuild_ground_geometry() attiva sempre la modalita'
	# a chunk. Qui restano solo le feature di livello regione (rocce, cliff,
	# fessure), che non vengono spezzate sui confini dei chunk.
	# Mesa volumes are rendered by their individual `large_rock` obstacle nodes.
	# Keeping them out of this z=-9 terrain layer lets the environment Y-sort put
	# one actor behind a mesa while another remains in front of it.
	var uses_rectilinear_cliff_art := has_forest_cliff_border_art()
	var flat_rim_texture := (
		_rock_top_texture
		if uses_mesa_top_for_fall_zone_rim()
		else null
	) as Texture2D
	var terrain_divider_texture := _forest_surface_textures.get(
		TERRAIN_DIVIDER_TEXTURE_ID
	) as Texture2D
	if (
		terrain_divider_texture != null
		and _mesa_dirt_border_mesh_builder != null
		and _mesa_dirt_border_mesh_builder.terrain_transition_mesh != null
	):
		draw_mesh(
			_mesa_dirt_border_mesh_builder.terrain_transition_mesh,
			terrain_divider_texture
		)
	# The vertical edge raster is an underlay: the projected side face owns the
	# visible wall and must cover the texture band. Only the horizontal crest is
	# composited above the face.
	if (
		uses_rectilinear_cliff_art
		and _cliff_border_mesh_builder != null
		and _cliff_border_mesh_builder.vertical_mesh != null
	):
		draw_mesh(
			_cliff_border_mesh_builder.vertical_mesh,
			flat_rim_texture
			if flat_rim_texture != null
			else _cliff_lip_vertical_texture
		)
	if (
		uses_rectilinear_cliff_art
		and _rectilinear_cliff_face_mesh_builder != null
		and _rectilinear_cliff_face_mesh_builder.face_mesh != null
	):
		draw_mesh(
			_rectilinear_cliff_face_mesh_builder.face_mesh,
			_cliff_face_texture
		)
	elif _cliff_mesh_builder != null and _cliff_mesh_builder.face_mesh != null:
		draw_mesh(_cliff_mesh_builder.face_mesh, _cliff_face_texture)
	if uses_rectilinear_cliff_art and _cliff_border_mesh_builder != null:
		if _cliff_border_mesh_builder.horizontal_mesh != null:
			draw_mesh(
				_cliff_border_mesh_builder.horizontal_mesh,
				flat_rim_texture
				if flat_rim_texture != null
				else _cliff_lip_texture
			)
	elif (
		_cliff_mesh_builder != null
		and _cliff_mesh_builder.lip_mesh != null
		and _cliff_lip_texture != null
	):
		draw_mesh(_cliff_mesh_builder.lip_mesh, _cliff_lip_texture)
	# The dirt core stays on terrain, while its short inner feather is composited
	# above the flat rim to soften the rock-side join as well.
	if (
		uses_rectilinear_cliff_art
		and terrain_divider_texture != null
		and _cliff_border_mesh_builder != null
		and _cliff_border_mesh_builder.terrain_transition_mesh != null
	):
		draw_mesh(
			_cliff_border_mesh_builder.terrain_transition_mesh,
			terrain_divider_texture
		)
	if (
		uses_rectilinear_cliff_art
		and _cliff_border_mesh_builder != null
		and _cliff_border_mesh_builder.diagonal_void_mesh != null
	):
		draw_mesh(
			_cliff_border_mesh_builder.diagonal_void_mesh,
			null,
			Transform2D.IDENTITY,
			get_void_background_color()
		)
	if (
		not uses_rectilinear_cliff_art
		and _cliff_mesh_builder != null
		and _cliff_mesh_builder.fissure_lines.size() >= 2
	):
		var fissure_alpha := 0.20 if has_cliff_art_textures() else 0.82
		var fissure_width := 0.9 if has_cliff_art_textures() else 1.4
		draw_multiline(
			_cliff_mesh_builder.fissure_lines,
			Color(palette.background_color.lightened(0.24), fissure_alpha),
			fissure_width
		)
	if (
		not uses_rectilinear_cliff_art
		and _cliff_mesh_builder != null
		and _cliff_mesh_builder.lip_lines.size() >= 2
	):
		var lip_alpha := 0.68 if has_cliff_art_textures() else 0.96
		var lip_width := 1.4 if has_cliff_art_textures() else 2.8
		draw_multiline(
			_cliff_mesh_builder.lip_lines,
			Color(palette.floor_color.lightened(0.46), lip_alpha),
			lip_width
		)

func _load_cliff_art_textures() -> void:
	_cliff_face_texture = null
	_cliff_lip_texture = null
	_cliff_lip_vertical_texture = null
	_cliff_art_asset_paths.clear()
	_cliff_variant_textures.clear()
	if _uses_generated_theme():
		var generation_seed := layout.generation_seed if layout != null else 0
		var face_path := GENERATED_ART_CATALOG.select_cliff_asset_path(
			biome_id,
			GENERATED_ART_CATALOG.ROLE_CLIFF_FACE,
			generation_seed
		)
		var horizontal_path := GENERATED_ART_CATALOG.select_cliff_asset_path(
			biome_id,
			GENERATED_ART_CATALOG.ROLE_CLIFF_LIP_HORIZONTAL,
			generation_seed
		)
		var vertical_path := GENERATED_ART_CATALOG.select_cliff_asset_path(
			biome_id,
			GENERATED_ART_CATALOG.ROLE_CLIFF_LIP_VERTICAL,
			generation_seed
		)
		_cliff_art_asset_paths[CLIFF_FACE_TEXTURE_ID] = face_path
		_cliff_art_asset_paths[CLIFF_LIP_TEXTURE_ID] = horizontal_path
		_cliff_art_asset_paths[CLIFF_LIP_VERTICAL_TEXTURE_ID] = vertical_path
		_cliff_face_texture = _load_generated_cliff_texture(face_path)
		_cliff_lip_texture = _load_generated_cliff_texture(horizontal_path)
		_cliff_lip_vertical_texture = _load_generated_cliff_texture(vertical_path)
		for asset_path in GENERATED_ART_CATALOG.get_all_cliff_asset_paths(biome_id):
			var material_id := GENERATED_ART_CATALOG.material_id_from_path(asset_path)
			var texture := _load_generated_cliff_texture(asset_path)
			if texture != null:
				_cliff_variant_textures[material_id] = texture
		return
	if manifest == null:
		return
	_cliff_face_texture = _load_cliff_art_texture(CLIFF_FACE_TEXTURE_ID)
	_cliff_lip_texture = _load_cliff_art_texture(CLIFF_LIP_TEXTURE_ID)
	_cliff_lip_vertical_texture = _load_cliff_art_texture(
		CLIFF_LIP_VERTICAL_TEXTURE_ID
	)

func _load_cliff_art_texture(asset_id: StringName) -> Texture2D:
	var contract := manifest.get_void_asset_contract(asset_id)
	var asset_path := String(contract.get("asset_path", ""))
	_cliff_art_asset_paths[asset_id] = asset_path
	if asset_path.is_empty():
		return null
	return SVG_TEXTURE_LOADER.load_texture(
		asset_path,
		palette.prop_color if palette != null else Color(0.32, 0.30, 0.27, 1.0),
		palette.floor_color if palette != null else Color(0.44, 0.48, 0.31, 1.0),
		Vector2i(512, 512)
	)

func _load_generated_texture(asset_path: String) -> Texture2D:
	if asset_path.is_empty():
		return null
	return SVG_TEXTURE_LOADER.load_texture(
		asset_path,
		palette.prop_color if palette != null else Color(0.32, 0.30, 0.27, 1.0),
		palette.floor_color if palette != null else Color(0.44, 0.48, 0.31, 1.0),
		Vector2i(512, 512)
	)

func _load_generated_surface_texture(asset_path: String) -> Texture2D:
	var texture := _load_generated_texture(asset_path)
	if texture == null:
		return null
	return GENERATED_TEXTURE_TOOLS.normalize_surface_texture(
		texture,
		biome_id,
		asset_path
	)

func _load_generated_cliff_texture(asset_path: String) -> Texture2D:
	var texture := _load_generated_texture(asset_path)
	if texture == null:
		return null
	return _trim_repeating_texture(
		texture,
		_generated_cliff_texture_edge_trim_pixels(),
		_should_harmonize_generated_cliff_edges(),
		asset_path,
		GENERATED_TEXTURE_TOOLS.cliff_texture_downscale(biome_id)
	)

func _trim_repeating_texture(
	texture: Texture2D,
	trim: int,
	harmonize_edges: bool = false,
	cache_key: String = "",
	downscale: float = 1.0
) -> Texture2D:
	return GENERATED_TEXTURE_TOOLS.normalize_repeating_texture(
		texture,
		trim,
		harmonize_edges,
		GENERATED_TEXTURE_TOOLS.BURNING_FIELDS_EDGE_BLEND_PIXELS,
		cache_key,
		downscale
	)

func _generated_surface_texture_edge_trim_pixels() -> int:
	return GENERATED_TEXTURE_TOOLS.surface_edge_trim_pixels(biome_id)

func _generated_cliff_texture_edge_trim_pixels() -> int:
	return GENERATED_TEXTURE_TOOLS.cliff_edge_trim_pixels(biome_id)

func _should_harmonize_generated_surface_edges() -> bool:
	return GENERATED_TEXTURE_TOOLS.should_harmonize_surface_edges(biome_id)

func _should_harmonize_generated_cliff_edges() -> bool:
	return GENERATED_TEXTURE_TOOLS.should_harmonize_cliff_edges(biome_id)

func _load_rock_art_texture() -> void:
	_rock_top_texture = null
	_rock_cliff_face_texture = null
	_rock_art_asset_paths.clear()
	_mesa_art_by_profile.clear()
	_mesa_art_asset_paths.clear()
	if layout == null:
		return
	for profile_id in _mesa_profile_ids_for_render():
		_load_mesa_profile_art(profile_id)
	var default_profile := _default_mesa_profile_id()
	var default_art := _mesa_art_by_profile.get(default_profile, {}) as Dictionary
	var default_paths := (
		_mesa_art_asset_paths.get(default_profile, {}) as Dictionary
	)
	_rock_top_texture = default_art.get(&"top") as Texture2D
	_rock_cliff_face_texture = default_art.get(&"face") as Texture2D
	_rock_art_asset_paths = default_paths.duplicate(true)

func _load_mesa_profile_art(profile_id: StringName) -> void:
	if _mesa_art_by_profile.has(profile_id):
		return
	var top_path := ""
	var face_path := ""
	var top_texture: Texture2D = null
	var face_texture: Texture2D = null
	if profile_id == FOREST_MESA_PROFILE_ID:
		if manifest == null:
			return
		var contract := manifest.get_object_asset_contract(LARGE_ROCK_OBJECT_ID)
		top_path = String(contract.get("asset_path", ""))
		var face_contract := manifest.get_void_asset_contract(
			ROCK_CLIFF_FACE_TEXTURE_ID
		)
		face_path = String(face_contract.get("asset_path", ""))
		if not top_path.is_empty():
			top_texture = SVG_TEXTURE_LOADER.load_texture(
				top_path,
				palette.prop_color if palette != null else Color(0.34, 0.31, 0.27, 1.0),
				palette.floor_color if palette != null else Color(0.48, 0.43, 0.34, 1.0),
				Vector2i(512, 512)
			)
		if not face_path.is_empty():
			face_texture = SVG_TEXTURE_LOADER.load_texture(
				face_path,
				palette.prop_color if palette != null else Color(0.34, 0.31, 0.27, 1.0),
				palette.floor_color if palette != null else Color(0.48, 0.43, 0.34, 1.0),
				Vector2i(512, 512)
			)
	else:
		top_path = _select_mesa_profile_asset_path(
			profile_id,
			GENERATED_ART_CATALOG.ROLE_GROUND
		)
		face_path = _select_mesa_profile_asset_path(
			profile_id,
			GENERATED_ART_CATALOG.ROLE_CLIFF_FACE
		)
		top_texture = _forest_surface_textures.get(
			GENERATED_ART_CATALOG.material_id_from_path(top_path)
		) as Texture2D
		face_texture = _cliff_variant_textures.get(
			GENERATED_ART_CATALOG.material_id_from_path(face_path)
		) as Texture2D
		if top_texture == null:
			top_texture = _load_generated_surface_texture(top_path)
		if face_texture == null:
			face_texture = _load_generated_cliff_texture(face_path)
	_mesa_art_by_profile[profile_id] = {
		&"top": top_texture,
		&"face": face_texture,
	}
	var top_role := GENERATED_ART_CATALOG.ROLE_GROUND
	var face_role := GENERATED_ART_CATALOG.ROLE_CLIFF_FACE
	if profile_id == FOREST_MESA_PROFILE_ID:
		top_role = LARGE_ROCK_OBJECT_ID
		face_role = ROCK_CLIFF_FACE_TEXTURE_ID
	_mesa_art_asset_paths[profile_id] = {
		&"top": top_path,
		&"face": face_path,
		&"top_role": top_role,
		&"face_role": face_role,
	}
	if profile_id == FOREST_MESA_PROFILE_ID:
		(_mesa_art_asset_paths[profile_id] as Dictionary)[&"horizontal_border"] = String(
			_cliff_art_asset_paths.get(CLIFF_LIP_TEXTURE_ID, "")
		)
		(_mesa_art_asset_paths[profile_id] as Dictionary)[&"vertical_border"] = String(
			_cliff_art_asset_paths.get(CLIFF_LIP_VERTICAL_TEXTURE_ID, "")
		)

func _select_mesa_profile_asset_path(
	profile_id: StringName,
	role: StringName
) -> String:
	var profile := GENERATED_ART_CATALOG.get_profile_for_theme(profile_id)
	var pool := profile.get(role, PackedStringArray()) as PackedStringArray
	if pool.is_empty():
		return ""
	var generation_seed := layout.generation_seed if layout != null else 0
	var key := "%d|%s|mesa|%s" % [
		generation_seed,
		String(profile_id),
		String(role),
	]
	return pool[posmod(key.hash(), pool.size())]

func _mesa_profile_ids_for_render() -> Array[StringName]:
	var result: Array[StringName] = []
	if layout == null:
		return result
	if not layout.mesa_rects.is_empty():
		for index in range(layout.mesa_rects.size()):
			var profile_id := (
				layout.mesa_profile_ids[index]
				if index < layout.mesa_profile_ids.size()
				else _default_mesa_profile_id()
			)
			profile_id = _normalize_mesa_profile_id(profile_id)
			if not result.has(profile_id):
				result.append(profile_id)
	elif _uses_forest_ground() and not layout.rock_rects.is_empty():
		# Compatibility is intentionally limited to the historical forest layout.
		# Advanced-biome `rock_rects` used to mean generic building masses and must
		# never be promoted silently to mesa geometry.
		result.append(FOREST_MESA_PROFILE_ID)
	# The forest fall-zone rim is also a consumer of the mesa top material. Load
	# the profile even in synthetic/runtime layouts that contain a chasm but no
	# raised mesa instance.
	if (
		_uses_forest_ground()
		and not layout.fall_zone_rects.is_empty()
		and not result.has(FOREST_MESA_PROFILE_ID)
	):
		result.append(FOREST_MESA_PROFILE_ID)
	return result

func _default_mesa_profile_id() -> StringName:
	if _uses_forest_ground():
		return FOREST_MESA_PROFILE_ID
	var generated_theme := GENERATED_ART_CATALOG.get_theme_id_for_biome(biome_id)
	return generated_theme if not generated_theme.is_empty() else FOREST_MESA_PROFILE_ID

func _normalize_mesa_profile_id(profile_id: StringName) -> StringName:
	if profile_id == FOREST_MESA_PROFILE_ID:
		return profile_id
	if not GENERATED_ART_CATALOG.get_profile_for_theme(profile_id).is_empty():
		return profile_id
	return _default_mesa_profile_id()

func _load_forest_surface_art_textures() -> void:
	_forest_surface_textures.clear()
	_forest_surface_art_asset_paths.clear()
	_surface_texture_ids.clear()
	_terrain_surface_texture_ids.clear()
	_fallback_surface_textures.clear()
	if manifest == null or not _uses_themed_ground():
		return
	if _uses_generated_theme():
		for asset_path in GENERATED_ART_CATALOG.get_runtime_surface_asset_paths(biome_id):
			var material_id := GENERATED_ART_CATALOG.material_id_from_path(asset_path)
			var texture := _load_generated_surface_texture(asset_path)
			if texture == null:
				continue
			_register_surface_texture(material_id, asset_path, texture)
		if (
			biome_id == &"frozen_tundra"
			or biome_id == &"swamp"
		):
			_apply_offset_ground_macro_texture()
		_load_terrain_divider_texture()
		_refresh_terrain_surface_texture_ids()
		return
	for texture_id in FOREST_SURFACE_TEXTURE_IDS:
		var contract := manifest.get_terrain_asset_contract(_themed_surface_asset_id(texture_id))
		var asset_path := String(contract.get("asset_path", ""))
		_forest_surface_art_asset_paths[texture_id] = asset_path
		if asset_path.is_empty():
			continue
		# Forest PNGs share the generated-surface repeat contract. Normalizing them
		# here removes the luminance jump between opposite edges before mipmaps.
		var texture := _load_generated_surface_texture(asset_path)
		if texture != null:
			_register_surface_texture(texture_id, asset_path, texture)
	_load_terrain_divider_texture()
	_refresh_terrain_surface_texture_ids()

func _load_terrain_divider_texture() -> void:
	if manifest == null:
		return
	# Plains and Burning Plains use one dirt material for paths and every terrain
	# divider. Reusing the normalized runtime instance also keeps atlas phase,
	# filtering and world-space density identical across both consumers.
	if _uses_path_as_terrain_divider():
		var path_texture_id := FOREST_PATH_TEXTURE_ID
		if _uses_generated_theme():
			var generation_seed := layout.generation_seed if layout != null else 0
			path_texture_id = _generated_surface_texture_id_for_role(
				GENERATED_ART_CATALOG.ROLE_PATH,
				generation_seed
			)
		var path_texture := (
			_forest_surface_textures.get(path_texture_id) as Texture2D
		)
		var path_asset_path := String(
			_forest_surface_art_asset_paths.get(path_texture_id, "")
		)
		if path_texture != null and not path_asset_path.is_empty():
			_register_surface_texture(
				TERRAIN_DIVIDER_TEXTURE_ID,
				path_asset_path,
				path_texture
			)
			return
	var contract := manifest.get_terrain_asset_contract(TERRAIN_DIVIDER_TEXTURE_ID)
	var asset_path := String(contract.get("asset_path", ""))
	if asset_path.is_empty():
		return
	var source_texture := _load_generated_texture(asset_path)
	if source_texture == null:
		return
	var texture := GENERATED_TEXTURE_TOOLS.normalize_repeating_texture(
		source_texture,
		2,
		true,
		GENERATED_TEXTURE_TOOLS.BURNING_FIELDS_EDGE_BLEND_PIXELS,
		"%s|terrain_divider" % asset_path
	)
	if texture != null:
		_register_surface_texture(TERRAIN_DIVIDER_TEXTURE_ID, asset_path, texture)

func _register_surface_texture(
	texture_id: StringName,
	asset_path: String,
	texture: Texture2D
) -> void:
	if texture_id.is_empty() or texture == null:
		return
	_forest_surface_art_asset_paths[texture_id] = asset_path
	_forest_surface_textures[texture_id] = texture
	if not _surface_texture_ids.has(texture_id):
		_surface_texture_ids.append(texture_id)

func _refresh_terrain_surface_texture_ids() -> void:
	_terrain_surface_texture_ids.clear()
	if _uses_generated_theme():
		var generation_seed := layout.generation_seed if layout != null else 0
		_terrain_surface_texture_ids[
			TERRAIN_SURFACE_CLASSIFIER.SURFACE_GRASS
		] = _generated_surface_texture_id_for_role(
			GENERATED_ART_CATALOG.ROLE_GROUND,
			generation_seed
		)
		_terrain_surface_texture_ids[
			TERRAIN_SURFACE_CLASSIFIER.SURFACE_PATH
		] = _generated_surface_texture_id_for_role(
			GENERATED_ART_CATALOG.ROLE_PATH,
			generation_seed
		)
		_terrain_surface_texture_ids[
			TERRAIN_SURFACE_CLASSIFIER.SURFACE_ASPHALT
		] = _generated_surface_texture_id_for_role(
			GENERATED_ART_CATALOG.ROLE_ROAD,
			generation_seed
		)
	else:
		_terrain_surface_texture_ids[
			TERRAIN_SURFACE_CLASSIFIER.SURFACE_GRASS
		] = FOREST_GRASS_TEXTURE_ID
		_terrain_surface_texture_ids[
			TERRAIN_SURFACE_CLASSIFIER.SURFACE_PATH
		] = FOREST_PATH_TEXTURE_ID
		_terrain_surface_texture_ids[
			TERRAIN_SURFACE_CLASSIFIER.SURFACE_ASPHALT
		] = FOREST_ROAD_TEXTURE_ID

func _generated_surface_texture_id_for_role(
	role: StringName,
	generation_seed: int
) -> StringName:
	var asset_path := GENERATED_ART_CATALOG.select_surface_asset_path(
		biome_id,
		role,
		generation_seed,
		Vector2i.ZERO
	)
	var texture_id := GENERATED_ART_CATALOG.material_id_from_path(asset_path)
	if _forest_surface_textures.get(texture_id) is Texture2D:
		return texture_id
	for fallback_path in GENERATED_ART_CATALOG.get_asset_paths_for_role(biome_id, role):
		var fallback_id := GENERATED_ART_CATALOG.material_id_from_path(fallback_path)
		if _forest_surface_textures.get(fallback_id) is Texture2D:
			return fallback_id
	return &""

func _apply_offset_ground_macro_texture() -> void:
	var ground_id := &""
	for material_id in _surface_texture_ids:
		var asset_path := String(
			_forest_surface_art_asset_paths.get(material_id, "")
		)
		if asset_path.contains("base_ground_variation_01"):
			ground_id = material_id
	if ground_id.is_empty():
		return
	var ground_texture := _forest_surface_textures.get(ground_id) as Texture2D
	var macro_texture := (
		GENERATED_TEXTURE_TOOLS.build_offset_ground_macro_texture(
			ground_texture,
			String(_forest_surface_art_asset_paths.get(ground_id, ""))
		)
	)
	if macro_texture != null:
		_forest_surface_textures[ground_id] = macro_texture

func _rebuild_ground_geometry() -> void:
	_reset_ground_geometry()
	if layout == null or palette == null:
		return
	var scale := layout.logical_tile_scale
	_rebuild_terrain_surface_mask()
	if _build_all_chunks_on_finalize:
		for chunk_rect in _chunks:
			_build_visual_chunk(chunk_rect, scale)
	_uses_chunk_nodes = true
	_build_region_cliffs()
	_build_region_borders()
	_rebuild_mesa_geometry(scale)
	_cleanup_ground_buffers()

func _reset_ground_geometry() -> void:
	_ground_mesh = null
	_ground_underlay_mesh = null
	_forest_surface_meshes.clear()
	_terrain_surface_mask_data.clear()
	_terrain_surface_mask_texture = null
	_grid_points = PackedVector2Array()
	_texture_dark_lines = PackedVector2Array()
	_texture_light_lines = PackedVector2Array()
	_transition_lines = PackedVector2Array()
	_depth_lines = PackedVector2Array()
	_suppressed_void_texture_count = 0
	for chunk_value in _chunk_nodes.values():
		var existing_chunk := chunk_value as Node
		if existing_chunk != null and is_instance_valid(existing_chunk):
			existing_chunk.queue_free()
	_chunk_nodes.clear()
	_uses_chunk_nodes = false
	_cliff_transition_built_chunks.clear()
	if _cliff_mesh_builder != null:
		_cliff_mesh_builder.reset()
	if _cliff_border_mesh_builder != null:
		_cliff_border_mesh_builder.reset()
	if _mesa_dirt_border_mesh_builder != null:
		_mesa_dirt_border_mesh_builder.reset()
	if _rectilinear_cliff_face_mesh_builder != null:
		_rectilinear_cliff_face_mesh_builder.reset()
	for builder_value in _mesa_area_mesh_builders.values():
		var mesa_builder := builder_value as RectilinearRockAreaMeshBuilder
		if mesa_builder != null:
			mesa_builder.reset()
	_mesa_area_mesh_builders.clear()
	_rock_area_mesh_builder = null
	_mesa_profile_mismatch_count = 0

func _build_region_cliffs() -> void:
	# Per-cell cliff transitions are collected while each chunk is built, then
	# committed once as the region-level feature layer. Large cliff/rock features
	# also remain region-owned so a long feature is never duplicated at a seam.
	if _cliff_mesh_builder != null:
		_cliff_mesh_builder.build_meshes()

func _build_region_borders() -> void:
	if layout == null or palette == null:
		return
	var scale := layout.logical_tile_scale
	if has_forest_cliff_border_art() and _cliff_border_mesh_builder != null:
		var fall_zone_sides := _get_fall_zone_sides()
		_cliff_border_mesh_builder.build(
			layout.fall_zone_rects,
			fall_zone_sides,
			layout.zone_size,
			scale,
			_uses_generated_theme()
		)
		if _rectilinear_cliff_face_mesh_builder != null:
			_rectilinear_cliff_face_mesh_builder.build(
				layout.fall_zone_rects,
				fall_zone_sides,
				layout.zone_size,
				scale
			)

func _cleanup_ground_buffers() -> void:
	# Ground/detail buffers now belong to BiomeTileChunk children.
	_ground_mesh = null
	_ground_underlay_mesh = null
	_forest_surface_meshes.clear()
	_grid_points = PackedVector2Array()
	_texture_dark_lines = PackedVector2Array()
	_texture_light_lines = PackedVector2Array()
	_transition_lines = PackedVector2Array()
	_depth_lines = PackedVector2Array()

func _rebuild_terrain_surface_mask() -> void:
	_terrain_surface_mask_data.clear()
	_terrain_surface_mask_texture = null
	if not _uses_themed_ground() or layout == null or resolver == null:
		return
	_refresh_terrain_surface_texture_ids()
	_terrain_surface_mask_data = TERRAIN_BOUNDARY_MASK_BUILDER.build(
		layout,
		resolver
	)
	var mask_image := _terrain_surface_mask_data.get("image") as Image
	if mask_image != null and not mask_image.is_empty():
		_terrain_surface_mask_texture = ImageTexture.create_from_image(mask_image)

func _terrain_surface_render_data_for_chunk(
	chunk_rect: Rect2i,
	scale: float
) -> Dictionary:
	if (
		_terrain_surface_mask_texture == null
		or layout == null
		or layout.zone_size.x <= 0
		or layout.zone_size.y <= 0
	):
		return {}
	var grass_id := StringName(_terrain_surface_texture_ids.get(
		TERRAIN_SURFACE_CLASSIFIER.SURFACE_GRASS,
		&""
	))
	var path_id := StringName(_terrain_surface_texture_ids.get(
		TERRAIN_SURFACE_CLASSIFIER.SURFACE_PATH,
		&""
	))
	var asphalt_id := StringName(_terrain_surface_texture_ids.get(
		TERRAIN_SURFACE_CLASSIFIER.SURFACE_ASPHALT,
		&""
	))
	var surface_material_ids: Array[StringName] = []
	for material_id in [
		grass_id,
		path_id,
		asphalt_id,
		TERRAIN_DIVIDER_TEXTURE_ID,
		&"terrain_void_color",
	]:
		if not material_id.is_empty() and not surface_material_ids.has(material_id):
			surface_material_ids.append(material_id)
	var zone_offset := Vector2(layout.zone_size) * 0.5
	var chunk_world_rect := Rect2(
		(Vector2(chunk_rect.position) - zone_offset) * scale,
		Vector2(chunk_rect.size) * scale
	)
	var mask_uv_rect := Rect2(
		Vector2(chunk_rect.position) / Vector2(layout.zone_size),
		Vector2(chunk_rect.size) / Vector2(layout.zone_size)
	)
	return {
		"chunk_world_rect": chunk_world_rect,
		"texture_world_origin": (
			terrain_texture_world_origin + chunk_world_rect.position
		),
		"mask_uv_rect": mask_uv_rect,
		"mask_texture": _terrain_surface_mask_texture,
		"grass_texture": _terrain_surface_texture(
			TERRAIN_SURFACE_CLASSIFIER.SURFACE_GRASS,
			Color(0.24, 0.39, 0.16, 1.0)
		),
		"path_texture": _terrain_surface_texture(
			TERRAIN_SURFACE_CLASSIFIER.SURFACE_PATH,
			Color(0.40, 0.30, 0.17, 1.0)
		),
		"asphalt_texture": _terrain_surface_texture(
			TERRAIN_SURFACE_CLASSIFIER.SURFACE_ASPHALT,
			Color(0.17, 0.18, 0.17, 1.0)
		),
		"divider_texture": _surface_texture_or_fallback(
			TERRAIN_DIVIDER_TEXTURE_ID,
			&"divider",
			Color(0.34, 0.23, 0.13, 1.0)
		),
		"grass_repeat_world": _forest_surface_texture_world_size(grass_id),
		"path_repeat_world": _forest_surface_texture_world_size(path_id),
		"asphalt_repeat_world": _forest_surface_texture_world_size(asphalt_id),
		"divider_repeat_world": _terrain_divider_texture_world_size(),
		"void_color": get_void_background_color(),
		"surface_material_ids": surface_material_ids,
	}

func _terrain_surface_texture(surface_kind: int, fallback_color: Color) -> Texture2D:
	var texture_id := StringName(_terrain_surface_texture_ids.get(surface_kind, &""))
	return _surface_texture_or_fallback(
		texture_id,
		TERRAIN_SURFACE_CLASSIFIER.kind_name(surface_kind),
		fallback_color
	)

func _surface_texture_or_fallback(
	texture_id: StringName,
	fallback_id: StringName,
	fallback_color: Color
) -> Texture2D:
	var texture := _forest_surface_textures.get(texture_id) as Texture2D
	if texture != null:
		return texture
	if _fallback_surface_textures.get(fallback_id) is Texture2D:
		return _fallback_surface_textures[fallback_id] as Texture2D
	var fallback_image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	fallback_image.set_pixel(0, 0, fallback_color)
	var fallback_texture := ImageTexture.create_from_image(fallback_image)
	_fallback_surface_textures[fallback_id] = fallback_texture
	return fallback_texture

func _rebuild_mesa_geometry(scale: float) -> void:
	var rect_groups := _mesa_rect_groups()
	if _mesa_dirt_border_mesh_builder != null:
		_mesa_dirt_border_mesh_builder.build_dirt_outline(
			_mesa_rects_for_dirt_outline(),
			layout.zone_size,
			scale
		)
	for profile_id_value in rect_groups:
		var profile_id := StringName(profile_id_value)
		var rects: Array[Rect2i] = []
		rects.assign(rect_groups[profile_id] as Array)
		if rects.is_empty():
			continue
		if not _mesa_art_by_profile.has(profile_id):
			_load_mesa_profile_art(profile_id)
		var art_paths := (
			_mesa_art_asset_paths.get(profile_id, {}) as Dictionary
		)
		var top_path := String(art_paths.get(&"top", ""))
		var top_repeat := RectilinearRockAreaMeshBuilder.TOP_TEXTURE_REPEAT_WORLD_SIZE
		if profile_id != FOREST_MESA_PROFILE_ID and not top_path.is_empty():
			top_repeat = _forest_surface_texture_world_size(
				GENERATED_ART_CATALOG.material_id_from_path(top_path)
			)
		var builder := (
			RECTILINEAR_ROCK_AREA_MESH_BUILDER_SCRIPT.new()
			as RectilinearRockAreaMeshBuilder
		)
		builder.configure(
			palette,
			layout.generation_seed,
			top_repeat,
			RectilinearRockAreaMeshBuilder.FACE_TEXTURE_REPEAT_WORLD_SIZE
		)
		builder.build(rects, layout.zone_size, scale)
		_mesa_area_mesh_builders[profile_id] = builder
		if profile_id == _default_mesa_profile_id():
			_rock_area_mesh_builder = builder

func _mesa_rects_for_dirt_outline() -> Array[Rect2i]:
	if layout == null:
		return []
	if not layout.mesa_rects.is_empty():
		return layout.mesa_rects.duplicate()
	if _uses_forest_ground() and not layout.rock_rects.is_empty():
		return layout.rock_rects.duplicate()
	return []

func _mesa_rect_groups() -> Dictionary:
	var groups := {}
	if layout == null:
		return groups
	if not layout.mesa_rects.is_empty():
		_mesa_profile_mismatch_count = abs(
			layout.mesa_profile_ids.size() - layout.mesa_rects.size()
		)
		for index in range(layout.mesa_rects.size()):
			var raw_profile_id := (
				layout.mesa_profile_ids[index]
				if index < layout.mesa_profile_ids.size()
				else _default_mesa_profile_id()
			)
			var profile_id := _normalize_mesa_profile_id(raw_profile_id)
			if profile_id != raw_profile_id:
				_mesa_profile_mismatch_count += 1
			if not groups.has(profile_id):
				var new_rects: Array[Rect2i] = []
				groups[profile_id] = new_rects
			var profile_rects: Array[Rect2i] = []
			profile_rects.assign(groups[profile_id] as Array)
			profile_rects.append(layout.mesa_rects[index])
			groups[profile_id] = profile_rects
	elif _uses_forest_ground() and not layout.rock_rects.is_empty():
		groups[FOREST_MESA_PROFILE_ID] = layout.rock_rects.duplicate()
	return groups

func _build_visual_chunk(chunk_rect: Rect2i, scale: float) -> void:
	_ground_mesh = null
	_ground_underlay_mesh = null
	_forest_surface_meshes.clear()
	_grid_points = PackedVector2Array()
	_texture_dark_lines = PackedVector2Array()
	_texture_light_lines = PackedVector2Array()
	_transition_lines = PackedVector2Array()
	_depth_lines = PackedVector2Array()
	_suppressed_void_texture_count = 0
	# The gameplay grid is screen-aligned: every fallback cell must cover exactly
	# one logical square. Textured surface runs already use this contract; keeping
	# the untextured path rectangular prevents a missing asset from reintroducing
	# a rotated projection.
	var half_w := scale * 0.5
	var half_h := scale * 0.5
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var grid := PackedVector2Array()
	var coord := Vector2i(
		chunk_rect.position.x / chunk_size,
		chunk_rect.position.y / chunk_size
	)
	var collect_cliff_transitions := (
		not _cliff_transition_built_chunks.has(coord)
	)
	var terrain_surface_render_data := (
		_terrain_surface_render_data_for_chunk(chunk_rect, scale)
		if _uses_themed_ground()
		else {}
	)
	for y in range(
		chunk_rect.position.y,
		chunk_rect.position.y + chunk_rect.size.y
	):
		for x in range(
			chunk_rect.position.x,
			chunk_rect.position.x + chunk_rect.size.x
		):
			var cell := Vector2i(x, y)
			var tile_id := get_resolved_tile_id(cell)
			if tile_id.is_empty():
				continue
			if _is_untextured_void_tile(tile_id):
				_suppressed_void_texture_count += 1
				continue
			var center := _cell_center_to_world(cell)
			if _uses_rectilinear_void_transition_art(tile_id):
				_suppressed_void_texture_count += 1
				if collect_cliff_transitions:
					_append_cliff_transition_mesh(
						cell,
						tile_id,
						center,
						half_w,
						half_h,
						scale
					)
				continue
			if _uses_themed_ground():
				if collect_cliff_transitions:
					_append_cliff_transition_mesh(
						cell,
						tile_id,
						center,
						half_w,
						half_h,
						scale
					)
				continue
			var top_left := center + Vector2(-half_w, -half_h)
			var top_right := center + Vector2(half_w, -half_h)
			var bottom_right := center + Vector2(half_w, half_h)
			var bottom_left := center + Vector2(-half_w, half_h)
			var base := vertices.size()
			vertices.append(top_left)
			vertices.append(top_right)
			vertices.append(bottom_right)
			vertices.append(bottom_left)
			var color := _tile_color(tile_id)
			for _index in range(4):
				colors.append(color)
			indices.append(base)
			indices.append(base + 1)
			indices.append(base + 2)
			indices.append(base)
			indices.append(base + 2)
			indices.append(base + 3)
			grid.append(top_left)
			grid.append(top_right)
			grid.append(top_right)
			grid.append(bottom_right)
			grid.append(bottom_right)
			grid.append(bottom_left)
			grid.append(bottom_left)
			grid.append(top_left)
			_append_texture_details(cell, tile_id, center, half_w, half_h)
			if collect_cliff_transitions:
				_append_cliff_transition_mesh(
					cell,
					tile_id,
					center,
					half_w,
					half_h,
					scale
				)
	_grid_points = grid
	if not vertices.is_empty():
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_INDEX] = indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		_ground_mesh = mesh
	var chunk := BIOME_TILE_CHUNK_BAKER_SCRIPT.bake_chunk(
		self,
		coord,
		chunk_rect,
		_ground_underlay_mesh,
		_ground_mesh,
		_forest_surface_meshes,
		_forest_surface_textures,
		_surface_texture_ids,
		_texture_dark_lines,
		_texture_light_lines,
		_transition_lines,
		_depth_lines,
		_grid_points,
		Color(palette.grid_color, 0.12) if _should_draw_grid() else Color.TRANSPARENT,
		_suppressed_void_texture_count,
		terrain_surface_render_data
	) as BiomeTileChunk
	if chunk == null:
		return
	_chunk_nodes[coord] = chunk
	_cliff_transition_built_chunks[coord] = true

func _build_chunk_for_coord(coord: Vector2i) -> bool:
	if layout == null or chunk_size <= 0:
		return false
	var position := coord * chunk_size
	if (
		position.x < 0
		or position.y < 0
		or position.x >= layout.zone_size.x
		or position.y >= layout.zone_size.y
	):
		return false
	var rect := Rect2i(
		position,
		Vector2i(
			mini(chunk_size, layout.zone_size.x - position.x),
			mini(chunk_size, layout.zone_size.y - position.y)
		)
	)
	var had_cliff_transitions := _cliff_transition_built_chunks.has(coord)
	_build_visual_chunk(rect, layout.logical_tile_scale)
	_uses_chunk_nodes = not _chunk_nodes.is_empty()
	if not had_cliff_transitions and _cliff_mesh_builder != null:
		# Aggiunge solo la geometria cliff di questo chunk come nuova superficie
		# invece di ritriangolare l'intera storia della regione (build_meshes()):
		# altrimenti il costo per commit cresceva con ogni chunk-con-cliff gia'
		# visitato mentre si esplora lungo una scogliera.
		_cliff_mesh_builder.flush_pending_surface()
		queue_redraw()
	return has_chunk(coord)

func _get_fall_zone_sides() -> Array[StringName]:
	var sides: Array[StringName] = []
	for fall_rect in layout.fall_zone_rects:
		var side := &"internal"
		for hazard_index in range(layout.hazard_rects.size()):
			if (
				hazard_index < layout.hazard_ids.size()
				and hazard_index < layout.hazard_sides.size()
				and layout.hazard_ids[hazard_index] == &"fall_zone"
				and layout.hazard_rects[hazard_index] == fall_rect
			):
				side = layout.hazard_sides[hazard_index]
				if side.is_empty():
					side = &"internal"
				break
		sides.append(side)
	return sides

func _get_southern_tile_ids(
	cell: Vector2i,
	lookahead: int
) -> Array[StringName]:
	var result: Array[StringName] = []
	for offset in range(1, lookahead + 1):
		var southern_cell := cell + Vector2i(0, offset)
		if southern_cell.y >= layout.zone_size.y:
			break
		result.append(get_resolved_tile_id(southern_cell))
	return result

func _append_cliff_transition_mesh(
	cell: Vector2i,
	tile_id: StringName,
	center: Vector2,
	half_w: float,
	half_h: float,
	scale: float
) -> void:
	if (
		_cliff_mesh_builder == null
		or resolver == null
		or not resolver.is_void_transition_tile_id(tile_id)
	):
		return
	# Preserve the established apparent depth after switching the cell fallback
	# from a compressed projected tile to a full square. Depth is visual only and
	# remains independent from the rectangular fall-zone collision.
	var cliff_depth := maxf(scale * 2.72, 28.0)
	var south_lookahead := ceili(cliff_depth / scale) + 1
	_cliff_mesh_builder.append_transition(
		tile_id,
		center,
		half_w,
		half_h,
		_get_southern_tile_ids(cell, south_lookahead),
		scale
	)

func _forest_surface_texture_world_size(texture_id: StringName) -> float:
	if _uses_generated_theme():
		var texture_name := String(texture_id)
		if biome_id == &"toxic_wastes":
			return TOXIC_SURFACE_TEXTURE_WORLD_SIZE
		if biome_id == &"frozen_tundra":
			if texture_name.contains("base_ground_variation_01"):
				return FROZEN_GROUND_TEXTURE_WORLD_SIZE
			return FROZEN_SURFACE_TEXTURE_WORLD_SIZE
		if biome_id == &"swamp":
			if texture_name.contains("base_ground_variation_01"):
				return MARSH_GROUND_TEXTURE_WORLD_SIZE
			return MARSH_SURFACE_TEXTURE_WORLD_SIZE
		if biome_id == &"burning_plains":
			return BURNING_SURFACE_TEXTURE_WORLD_SIZE
	return FOREST_SURFACE_TEXTURE_WORLD_SIZE

func _terrain_divider_texture_world_size() -> float:
	# Plains-family biomes that alias their path must also share its UV period;
	# the remaining biomes retain the standalone divider's historical period.
	var divider_asset_path := String(
		_forest_surface_art_asset_paths.get(TERRAIN_DIVIDER_TEXTURE_ID, "")
	)
	var path_id := StringName(_terrain_surface_texture_ids.get(
		TERRAIN_SURFACE_CLASSIFIER.SURFACE_PATH,
		&""
	))
	var path_asset_path := String(
		_forest_surface_art_asset_paths.get(path_id, "")
	)
	if (
		_uses_path_as_terrain_divider()
		and not path_id.is_empty()
		and not path_asset_path.is_empty()
		and divider_asset_path == path_asset_path
	):
		return _forest_surface_texture_world_size(path_id)
	return TERRAIN_DIVIDER_TEXTURE_WORLD_SIZE

func _uses_path_as_terrain_divider() -> bool:
	return (
		_uses_forest_ground()
		or biome_id == &"burning_plains"
		or biome_id == &"frozen_tundra"
		or biome_id == &"swamp"
	)

func _uses_forest_ground() -> bool:
	return biome_id == BiomeTileResolver.FOREST_BIOME_ID

func _uses_generated_theme() -> bool:
	return GENERATED_ART_CATALOG.has_generated_theme(biome_id)

# True when the biome renders the RGBA terrain mask with forest or generated
# full-bleed surface textures. Mesa art remains selected by its own profile.
func _uses_themed_ground() -> bool:
	return _uses_forest_ground() or _uses_generated_theme()

# Manifest terrain tile supplying a forest surface slot.
func _themed_surface_asset_id(slot: StringName) -> StringName:
	return slot

func _should_draw_grid() -> bool:
	return not _uses_themed_ground()

func _rebuild_chunks() -> void:
	_chunks.clear()
	if layout == null or chunk_size <= 0:
		return
	for y in range(0, layout.zone_size.y, chunk_size):
		for x in range(0, layout.zone_size.x, chunk_size):
			var size := Vector2i(
				mini(chunk_size, layout.zone_size.x - x),
				mini(chunk_size, layout.zone_size.y - y)
			)
			_chunks.append(Rect2i(Vector2i(x, y), size))

func _rebuild_tile_cache() -> void:
	_tile_id_cache.clear()
	_tile_section_cache.clear()
	_tile_role_cache.clear()
	_asset_path_cache.clear()
	_material_asset_id_cache.clear()
	_material_asset_path_cache.clear()
	_missing_asset_count = 0
	if layout == null or resolver == null:
		return
	var asset_exists_by_contract: Dictionary = {}
	for y in range(layout.zone_size.y):
		for x in range(layout.zone_size.x):
			var cell := Vector2i(x, y)
			var tile_data := resolver.resolve_tile_data(layout, cell, biome_id, quality_preset)
			var tile_id := StringName(tile_data.get("tile_id", &""))
			var section := StringName(tile_data.get("section", &""))
			var role := StringName(tile_data.get("role", &""))
			var cached_asset_path := String(tile_data.get("asset_path", ""))
			var material_asset_id := StringName(
				tile_data.get("material_asset_id", &"")
			)
			var material_asset_path := String(
				tile_data.get("material_asset_path", "")
			)
			var contract_key := (
				cached_asset_path
				if not cached_asset_path.is_empty()
				else "%s:%s" % [String(section), String(tile_id)]
			)
			if not asset_exists_by_contract.has(contract_key):
				asset_exists_by_contract[contract_key] = _asset_path_exists(cached_asset_path)
			var key := _cell_key(cell)
			_tile_id_cache[key] = tile_id
			_tile_section_cache[key] = section
			_tile_role_cache[key] = role
			_asset_path_cache[key] = cached_asset_path
			_material_asset_id_cache[key] = material_asset_id
			_material_asset_path_cache[key] = material_asset_path
			if not bool(asset_exists_by_contract[contract_key]):
				_missing_asset_count += 1

## Fonte unica preset->chunk size, condivisa con WorldChunkVisibilityController:
## se divergessero, le coordinate chunk del controller non mapperebbero piu' sui
## nodi chunk del layer.
static func chunk_size_for_preset(preset: StringName) -> int:
	match preset:
		&"performance":
			return PERFORMANCE_CHUNK_SIZE
		&"quality":
			return QUALITY_CHUNK_SIZE
		_:
			return DEFAULT_CHUNK_SIZE

func _resolve_chunk_size(next_chunk_size: int, preset: StringName) -> int:
	if next_chunk_size > 0:
		return next_chunk_size
	return chunk_size_for_preset(preset)

func _cell_center_to_world(cell: Vector2i) -> Vector2:
	return (
		Vector2(
			float(cell.x) + 0.5 - float(layout.zone_size.x) * 0.5,
			float(cell.y) + 0.5 - float(layout.zone_size.y) * 0.5
		)
		* layout.logical_tile_scale
	)

func _tile_color(tile_id: StringName) -> Color:
	if _is_passage_endpoint_tile(tile_id):
		return palette.gate_color.lightened(0.08)
	if resolver != null and resolver.is_void_transition_tile_id(tile_id):
		return get_void_background_color()
	match tile_id:
		BiomeTileResolver.TILE_FOREST_GRASS:
			return Color(0.20, 0.34, 0.17, 1.0)
		BiomeTileResolver.TILE_FOREST_GRASS_VARIANT_01:
			return Color(0.17, 0.30, 0.15, 1.0)
		BiomeTileResolver.TILE_FOREST_GRASS_VARIANT_02:
			return Color(0.23, 0.36, 0.18, 1.0)
		BiomeTileResolver.TILE_FOREST_TALL_GRASS:
			return Color(0.12, 0.25, 0.11, 1.0)
		BiomeTileResolver.TILE_FOREST_PATH:
			return Color(0.43, 0.31, 0.17, 1.0)
		BiomeTileResolver.TILE_FOREST_ROAD:
			return Color(0.50, 0.38, 0.22, 1.0)
		BiomeTileResolver.TILE_GRASS_TO_PATH:
			return Color(0.34, 0.31, 0.16, 1.0)
		BiomeTileResolver.TILE_GRASS_TO_ROAD:
			return Color(0.37, 0.32, 0.17, 1.0)
		BiomeTileResolver.TILE_GRASS_TO_TALL_GRASS:
			return Color(0.15, 0.28, 0.12, 1.0)
		BiomeTileResolver.TILE_PATH_TO_ROAD:
			return Color(0.47, 0.35, 0.19, 1.0)
		BiomeTileResolver.TILE_GROUND_TO_VOID_CLIFF:
			return Color(0.19, 0.28, 0.15, 1.0)
		BiomeTileResolver.TILE_GROUND_TO_MOUNTAIN_WALL:
			return Color(0.21, 0.25, 0.16, 1.0)
		BiomeTileResolver.TILE_FOREST_CLIFF_EDGE:
			return Color(0.13, 0.21, 0.14, 1.0)
		BiomeTileResolver.TILE_FOREST_VOID:
			return Color(0.08, 0.14, 0.095, 1.0)
		BiomeTileResolver.TILE_FOREST_MOUNTAIN_WALL:
			return Color(0.19, 0.21, 0.17, 1.0)
		BiomeTileResolver.TILE_MAIN_ROAD, BiomeTileResolver.TILE_ROAD:
			return Color(palette.lane_color, maxf(palette.lane_color.a, 0.46))
		BiomeTileResolver.TILE_ROAD_INTERSECTION:
			return Color(palette.lane_color.lightened(0.12), 0.58)
		BiomeTileResolver.TILE_ROAD_EDGE:
			return Color(palette.lane_color.darkened(0.12), 0.50)
		BiomeTileResolver.TILE_ROAD_CURVE_NORTH, BiomeTileResolver.TILE_ROAD_CURVE_EAST, BiomeTileResolver.TILE_ROAD_CURVE_SOUTH, BiomeTileResolver.TILE_ROAD_CURVE_WEST:
			return Color(palette.lane_color.lightened(0.06), 0.54)
		BiomeTileResolver.TILE_BROKEN_STREET:
			return Color(palette.lane_color.darkened(0.18), 0.52)
		BiomeTileResolver.TILE_SERVICE_LANE:
			return Color(palette.gate_color.lightened(0.06), 0.52)
		BiomeTileResolver.TILE_ASH_LANE, BiomeTileResolver.TILE_BURNED_ROAD:
			return Color(palette.hazard_color.darkened(0.22), 0.58)
		BiomeTileResolver.TILE_PACKED_SNOW_PATH, BiomeTileResolver.TILE_SNOW_PASS:
			return Color(palette.floor_color.lightened(0.22), 0.58)
		BiomeTileResolver.TILE_WOODEN_WALKWAY, BiomeTileResolver.TILE_BRIDGE:
			return Color(palette.prop_color.lightened(0.08), 0.56)
		BiomeTileResolver.TILE_BROKEN_GATE:
			return Color(palette.gate_color.darkened(0.10), 0.54)
		BiomeTileResolver.TILE_BRIDGE_BROKEN:
			return Color(palette.prop_color.darkened(0.18), 0.56)
		BiomeTileResolver.TILE_CLIFF_RAMP:
			return Color(palette.background_color.lightened(0.12), 0.54)
		BiomeTileResolver.TILE_HAZARD_FLOOR:
			return Color(palette.hazard_color, 0.60)
		BiomeTileResolver.TILE_BORDER_FLOOR:
			return palette.floor_color.darkened(0.24)
		BiomeTileResolver.TILE_VOID_EDGE_NEAR:
			return palette.background_color.darkened(0.38)
		BiomeTileResolver.TILE_VOID_DEPTH:
			# The depth remains dark, but not pure black: cliff faces, fissures and
			# low mist provide a readable visual descent from the walkable lip.
			return palette.background_color.darkened(0.56)
		BiomeTileResolver.TILE_FLOOR_VARIANT_01:
			return palette.alternate_floor_color
		BiomeTileResolver.TILE_FLOOR_VARIANT_02:
			return palette.floor_color.lightened(0.035)
		BiomeTileResolver.TILE_FLOOR_VARIANT_03:
			return palette.alternate_floor_color.darkened(0.045)
		_:
			return palette.floor_color

func _is_untextured_void_tile(tile_id: StringName) -> bool:
	return (
		tile_id == BiomeTileResolver.TILE_VOID_DEPTH
		or tile_id == BiomeTileResolver.TILE_FOREST_VOID
	)

func _uses_rectilinear_void_transition_art(tile_id: StringName) -> bool:
	return (
		has_forest_cliff_border_art()
		and resolver != null
		and resolver.is_void_transition_tile_id(tile_id)
	)

func _append_texture_details(
	cell: Vector2i,
	tile_id: StringName,
	center: Vector2,
	half_w: float,
	half_h: float
) -> void:
	if resolver != null and resolver.is_void_transition_tile_id(tile_id):
		_append_cliff_texture(cell, center, half_w, half_h)
		return
	match tile_id:
		BiomeTileResolver.TILE_FOREST_GRASS, BiomeTileResolver.TILE_FOREST_GRASS_VARIANT_01, BiomeTileResolver.TILE_FOREST_GRASS_VARIANT_02:
			_append_grass_texture(cell, center, half_w, half_h)
		BiomeTileResolver.TILE_FOREST_TALL_GRASS:
			_append_tall_grass_texture(cell, center, half_w, half_h)
		BiomeTileResolver.TILE_FOREST_PATH, BiomeTileResolver.TILE_GRASS_TO_PATH:
			_append_path_texture(cell, center, half_w, half_h, false)
		BiomeTileResolver.TILE_FOREST_ROAD, BiomeTileResolver.TILE_GRASS_TO_ROAD, BiomeTileResolver.TILE_PATH_TO_ROAD:
			_append_path_texture(cell, center, half_w, half_h, true)
		BiomeTileResolver.TILE_GRASS_TO_TALL_GRASS, BiomeTileResolver.TILE_GROUND_TO_MOUNTAIN_WALL:
			_append_transition_texture(cell, center, half_w, half_h)
		BiomeTileResolver.TILE_GROUND_TO_VOID_CLIFF, BiomeTileResolver.TILE_FOREST_CLIFF_EDGE:
			_append_cliff_texture(cell, center, half_w, half_h)
		_:
			pass

func _append_grass_texture(
	cell: Vector2i,
	center: Vector2,
	half_w: float,
	half_h: float
) -> void:
	var seed := _detail_hash(cell)
	if seed % 5 != 0:
		return
	var base := center + _seeded_offset(seed, half_w * 0.58, half_h * 0.45)
	_append_line(_texture_dark_lines, base + Vector2(-3.0, 1.0), base + Vector2(3.0, -2.0))
	if seed % 3 == 0:
		var leaf := center + _seeded_offset(seed + 41, half_w * 0.42, half_h * 0.35)
		_append_line(_texture_light_lines, leaf + Vector2(-2.0, -1.0), leaf + Vector2(2.5, 1.0))

func _append_tall_grass_texture(
	cell: Vector2i,
	center: Vector2,
	half_w: float,
	half_h: float
) -> void:
	var seed := _detail_hash(cell)
	if seed % 3 != 0:
		return
	for index in range(2):
		var base := center + _seeded_offset(seed + index * 23, half_w * 0.55, half_h * 0.46)
		var bend := float(((seed + index) % 5) - 2)
		_append_line(_texture_dark_lines, base + Vector2(0.0, 3.0), base + Vector2(bend, -6.0))
	_append_line(
		_texture_light_lines,
		center + Vector2(-half_w * 0.28, half_h * 0.10),
		center + Vector2(half_w * 0.22, -half_h * 0.12)
	)

func _append_path_texture(
	cell: Vector2i,
	center: Vector2,
	half_w: float,
	half_h: float,
	wide: bool
) -> void:
	var seed := _detail_hash(cell)
	var modulo := 4 if wide else 3
	if seed % modulo != 0:
		return
	var span := half_w * (0.72 if wide else 0.48)
	var y_offset := float((seed % 7) - 3) * half_h * 0.06
	_append_line(
		_transition_lines,
		center + Vector2(-span, y_offset),
		center + Vector2(span, y_offset + half_h * 0.20)
	)
	if wide and seed % 5 == 0:
		var pebble := center + _seeded_offset(seed + 19, half_w * 0.42, half_h * 0.28)
		_append_line(_texture_dark_lines, pebble + Vector2(-1.5, 0.0), pebble + Vector2(1.5, 0.0))

func _append_transition_texture(
	cell: Vector2i,
	center: Vector2,
	half_w: float,
	half_h: float
) -> void:
	var seed := _detail_hash(cell)
	if seed % 2 != 0:
		return
	_append_line(
		_transition_lines,
		center + Vector2(-half_w * 0.46, -half_h * 0.12),
		center + Vector2(half_w * 0.42, half_h * 0.18)
	)
	if seed % 5 == 0:
		_append_line(
			_texture_light_lines,
			center + Vector2(-half_w * 0.24, half_h * 0.18),
			center + Vector2(half_w * 0.18, half_h * 0.02)
		)

func _append_cliff_texture(
	cell: Vector2i,
	center: Vector2,
	half_w: float,
	half_h: float
) -> void:
	var seed := _detail_hash(cell)
	if seed % 2 != 0:
		return
	_append_line(
		_depth_lines,
		center + Vector2(-half_w * 0.36, -half_h * 0.16),
		center + Vector2(-half_w * 0.18, half_h * 0.82)
	)
	if seed % 4 == 0:
		_append_line(
			_transition_lines,
			center + Vector2(-half_w * 0.58, -half_h * 0.18),
			center + Vector2(half_w * 0.52, -half_h * 0.02)
		)

func _append_line(
	target: PackedVector2Array,
	start: Vector2,
	end: Vector2
) -> void:
	target.append(start)
	target.append(end)

func _seeded_offset(seed: int, radius_x: float, radius_y: float) -> Vector2:
	var x := (float(posmod(seed * 37, 1000)) / 1000.0 - 0.5) * radius_x * 2.0
	var y := (float(posmod(seed * 91, 1000)) / 1000.0 - 0.5) * radius_y * 2.0
	return Vector2(x, y)

func _detail_hash(cell: Vector2i) -> int:
	var seed := layout.generation_seed if layout != null else 0
	var value := seed * 1664525 + cell.x * 73856093 + cell.y * 19349663
	return posmod(value, 2147483647)

func _is_passage_endpoint_tile(tile_id: StringName) -> bool:
	return String(tile_id).ends_with("_entry") or String(tile_id).ends_with("_exit")

func _cell_key(cell: Vector2i) -> int:
	if layout == null:
		return cell.y * 100000 + cell.x
	return cell.y * layout.zone_size.x + cell.x

func _asset_path_exists(asset_path: String) -> bool:
	if asset_path.is_empty():
		return false
	if ResourceLoader.exists(asset_path):
		return true
	return FileAccess.file_exists(asset_path)
