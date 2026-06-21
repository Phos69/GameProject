extends Node2D
class_name BiomeTileLayer

signal build_completed

const DEFAULT_CHUNK_SIZE := 20
const PERFORMANCE_CHUNK_SIZE := 25
const QUALITY_CHUNK_SIZE := 16
const CLIFF_MESH_BUILDER_SCRIPT = preload(
	"res://game/modes/zombie/cliffs/isometric_cliff_mesh_builder.gd"
)
const FOREST_GROUND_MESH_BUILDER_SCRIPT = preload(
	"res://game/modes/zombie/ground/isometric_forest_ground_mesh_builder.gd"
)
const SVG_TEXTURE_LOADER = preload(
	"res://game/modes/zombie/isometric_svg_texture_loader.gd"
)
const CLIFF_FACE_TEXTURE_ID := &"cliff_face_texture"
const CLIFF_LIP_TEXTURE_ID := &"cliff_lip_texture"
const FOREST_GRASS_TEXTURE_ID := &"forest_grass"
const FOREST_SURFACE_TEXTURE_WORLD_SIZE := 256.0
const FOREST_SURFACE_TEXTURE_IDS: Array[StringName] = [
	&"forest_grass",
	&"forest_path",
	&"forest_road",
	&"grass_to_path",
	&"grass_to_road",
	&"path_to_road"
]
const FOREST_GRASS_SURFACE_TILE_IDS: Array[StringName] = [
	&"forest_grass",
	&"forest_grass_variant_01",
	&"forest_grass_variant_02",
	&"forest_tall_grass",
	&"grass_to_tall_grass"
]
const FOREST_TRANSITION_TEXTURE_IDS: Array[StringName] = [
	&"grass_to_path",
	&"grass_to_road",
	&"path_to_road"
]

var layout: BiomeEnvironmentLayout
var palette: BiomePalette
var biome_id: StringName = &""
var quality_preset: StringName = &"balanced"
var chunk_size: int = DEFAULT_CHUNK_SIZE
var manifest: IsometricEnvironmentManifest
var resolver: IsometricTileResolver

var _chunks: Array[Rect2i] = []
var _tile_id_cache: Dictionary = {}
var _tile_section_cache: Dictionary = {}
var _tile_role_cache: Dictionary = {}
var _asset_path_cache: Dictionary = {}
var _missing_asset_count: int = 0
# The whole static ground is baked once into meshes instead of issuing one draw
# command per cell every frame. Godot re-walks a canvas item's full command list
# each frame, so per-tile draw commands were the dominant constant frame cost on
# gl_compatibility.
var _ground_mesh: ArrayMesh
var _ground_underlay_mesh: ArrayMesh
var _forest_surface_meshes: Dictionary = {}
var _cliff_mesh_builder: IsometricCliffMeshBuilder
var _cliff_face_texture: Texture2D
var _cliff_lip_texture: Texture2D
var _forest_surface_textures: Dictionary = {}
var _forest_surface_art_asset_paths: Dictionary = {}
var _cliff_art_asset_paths: Dictionary = {}
var _grid_points: PackedVector2Array = PackedVector2Array()
var _texture_dark_lines: PackedVector2Array = PackedVector2Array()
var _texture_light_lines: PackedVector2Array = PackedVector2Array()
var _transition_lines: PackedVector2Array = PackedVector2Array()
var _depth_lines: PackedVector2Array = PackedVector2Array()
var _suppressed_void_texture_count: int = 0
# Optional worker thread that bakes the (CPU-heavy) tile cache + ground geometry
# off the main thread so the game does not freeze while a 500x500 chunk is built.
var _build_thread: Thread
var _is_building: bool = false

func configure(
	next_layout: BiomeEnvironmentLayout,
	next_palette: BiomePalette,
	next_biome_id: StringName,
	next_quality_preset: StringName = &"balanced",
	next_chunk_size: int = 0,
	next_resolver: IsometricTileResolver = null,
	next_manifest: IsometricEnvironmentManifest = null,
	async_build: bool = false
) -> void:
	layout = next_layout
	palette = next_palette
	biome_id = next_biome_id
	quality_preset = next_quality_preset
	manifest = next_manifest if next_manifest != null else IsometricEnvironmentManifest.get_shared()
	resolver = next_resolver if next_resolver != null else IsometricTileResolver.new(manifest)
	_load_cliff_art_textures()
	_load_forest_surface_art_textures()
	_cliff_mesh_builder = CLIFF_MESH_BUILDER_SCRIPT.new() as IsometricCliffMeshBuilder
	_cliff_mesh_builder.configure(
		palette,
		layout.generation_seed if layout != null else 0,
		has_cliff_art_textures()
	)
	chunk_size = _resolve_chunk_size(next_chunk_size, quality_preset)
	z_index = -9
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	add_to_group("biome_tile_layers")
	_rebuild_chunks()
	if async_build:
		# The node is already in the tree but draws nothing until the bake finishes.
		_is_building = true
		_build_thread = Thread.new()
		_build_thread.start(_threaded_build)
		return
	_rebuild_tile_cache()
	_rebuild_ground_geometry()
	queue_redraw()

func is_building() -> bool:
	return _is_building

func _threaded_build() -> void:
	# Runs on the worker thread: pure CPU work that fills the tile caches and bakes
	# the ground geometry. The node is not drawn yet, so there is no render race.
	_rebuild_tile_cache()
	_rebuild_ground_geometry()
	call_deferred("_finalize_threaded_build")

func _finalize_threaded_build() -> void:
	if _build_thread != null and _build_thread.is_started():
		_build_thread.wait_to_finish()
	_build_thread = null
	_is_building = false
	queue_redraw()
	build_completed.emit()

func _exit_tree() -> void:
	if _build_thread != null and _build_thread.is_started():
		_build_thread.wait_to_finish()
	_build_thread = null
	_is_building = false

func get_chunk_count() -> int:
	return _chunks.size()

func get_chunk_size() -> int:
	return chunk_size

func get_quality_preset() -> StringName:
	return quality_preset

func get_visual_tile_count() -> int:
	return _tile_id_cache.size()

func get_missing_asset_count() -> int:
	return _missing_asset_count

func uses_procedural_fallback() -> bool:
	return _missing_asset_count > 0

func get_texture_detail_line_count() -> int:
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

func get_cliff_art_asset_paths() -> Dictionary:
	return _cliff_art_asset_paths.duplicate(true)

func has_forest_ground_art_texture() -> bool:
	return _forest_surface_textures.get(FOREST_GRASS_TEXTURE_ID) is Texture2D

func get_forest_ground_art_asset_path() -> String:
	return String(_forest_surface_art_asset_paths.get(FOREST_GRASS_TEXTURE_ID, ""))

func has_forest_surface_art_textures() -> bool:
	for texture_id in FOREST_SURFACE_TEXTURE_IDS:
		if not (_forest_surface_textures.get(texture_id) is Texture2D):
			return false
	return true

func get_forest_surface_art_asset_paths() -> Dictionary:
	return _forest_surface_art_asset_paths.duplicate(true)

func get_suppressed_void_texture_count() -> int:
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

func has_visual_tile_for_cell(cell: Vector2i) -> bool:
	return _asset_path_exists(get_resolved_asset_path(cell))

func _draw() -> void:
	# The ground is pre-baked in _rebuild_ground_geometry(): a mesh for the
	# filled diamonds and, for forest terrain, a coloured underlay that removes
	# black gaps between playable tiles.
	if _ground_underlay_mesh != null:
		draw_mesh(_ground_underlay_mesh, null)
	for texture_id in FOREST_SURFACE_TEXTURE_IDS:
		var surface_mesh := _forest_surface_meshes.get(texture_id) as ArrayMesh
		var surface_texture := _forest_surface_textures.get(texture_id) as Texture2D
		if surface_mesh != null and surface_texture != null:
			draw_mesh(surface_mesh, surface_texture)
	if _ground_mesh != null:
		draw_mesh(_ground_mesh, null)
	if _cliff_mesh_builder != null and _cliff_mesh_builder.face_mesh != null:
		draw_mesh(_cliff_mesh_builder.face_mesh, _cliff_face_texture)
	if (
		_cliff_mesh_builder != null
		and _cliff_mesh_builder.lip_mesh != null
		and _cliff_lip_texture != null
	):
		draw_mesh(_cliff_mesh_builder.lip_mesh, _cliff_lip_texture)
	if _texture_dark_lines.size() >= 2:
		draw_multiline(_texture_dark_lines, Color(0.09, 0.18, 0.075, 0.34), 1.0)
	if _texture_light_lines.size() >= 2:
		draw_multiline(_texture_light_lines, Color(0.70, 0.76, 0.42, 0.24), 1.0)
	if _transition_lines.size() >= 2:
		draw_multiline(_transition_lines, Color(0.24, 0.15, 0.075, 0.42), 1.2)
	if _depth_lines.size() >= 2:
		draw_multiline(_depth_lines, Color(0.12, 0.22, 0.14, 0.48), 1.4)
	if _cliff_mesh_builder != null and _cliff_mesh_builder.fissure_lines.size() >= 2:
		var fissure_alpha := 0.20 if has_cliff_art_textures() else 0.82
		var fissure_width := 0.9 if has_cliff_art_textures() else 1.4
		draw_multiline(
			_cliff_mesh_builder.fissure_lines,
			Color(palette.background_color.lightened(0.24), fissure_alpha),
			fissure_width
		)
	if _cliff_mesh_builder != null and _cliff_mesh_builder.lip_lines.size() >= 2:
		var lip_alpha := 0.68 if has_cliff_art_textures() else 0.96
		var lip_width := 1.4 if has_cliff_art_textures() else 2.8
		draw_multiline(
			_cliff_mesh_builder.lip_lines,
			Color(palette.floor_color.lightened(0.46), lip_alpha),
			lip_width
		)
	if _should_draw_grid() and _grid_points.size() >= 2:
		draw_multiline(_grid_points, Color(palette.grid_color, 0.12))

func _load_cliff_art_textures() -> void:
	_cliff_face_texture = null
	_cliff_lip_texture = null
	_cliff_art_asset_paths.clear()
	if manifest == null:
		return
	_cliff_face_texture = _load_cliff_art_texture(CLIFF_FACE_TEXTURE_ID)
	_cliff_lip_texture = _load_cliff_art_texture(CLIFF_LIP_TEXTURE_ID)

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

func _load_forest_surface_art_textures() -> void:
	_forest_surface_textures.clear()
	_forest_surface_art_asset_paths.clear()
	if manifest == null or not _uses_forest_ground():
		return
	for texture_id in FOREST_SURFACE_TEXTURE_IDS:
		var contract := manifest.get_terrain_asset_contract(texture_id)
		var asset_path := String(contract.get("asset_path", ""))
		_forest_surface_art_asset_paths[texture_id] = asset_path
		if asset_path.is_empty():
			continue
		var texture := SVG_TEXTURE_LOADER.load_texture(
			asset_path,
			palette.floor_color if palette != null else Color(0.26, 0.40, 0.18, 1.0),
			palette.alternate_floor_color if palette != null else Color(0.18, 0.30, 0.14, 1.0),
			Vector2i(512, 512)
		)
		if texture != null:
			_forest_surface_textures[texture_id] = texture

func _rebuild_ground_geometry() -> void:
	_ground_mesh = null
	_ground_underlay_mesh = null
	_forest_surface_meshes.clear()
	_grid_points = PackedVector2Array()
	_texture_dark_lines = PackedVector2Array()
	_texture_light_lines = PackedVector2Array()
	_transition_lines = PackedVector2Array()
	_depth_lines = PackedVector2Array()
	_suppressed_void_texture_count = 0
	if _cliff_mesh_builder != null:
		_cliff_mesh_builder.reset()
	if layout == null or palette == null:
		return
	var scale := layout.logical_tile_scale
	var half_w := scale * 0.62
	var half_h := scale * 0.34
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var grid := PackedVector2Array()
	if _uses_forest_ground():
		_ground_underlay_mesh = _build_forest_underlay_mesh(scale)
		for texture_id in FOREST_SURFACE_TEXTURE_IDS:
			if not (_forest_surface_textures.get(texture_id) is Texture2D):
				continue
			var surface_mesh := _build_forest_surface_mesh(scale, texture_id)
			if surface_mesh != null:
				_forest_surface_meshes[texture_id] = surface_mesh
	for chunk in _chunks:
		for y in range(chunk.position.y, chunk.position.y + chunk.size.y):
			for x in range(chunk.position.x, chunk.position.x + chunk.size.x):
				var cell := Vector2i(x, y)
				var tile_id := get_resolved_tile_id(cell)
				if tile_id.is_empty():
					continue
				if _is_untextured_void_tile(tile_id):
					_suppressed_void_texture_count += 1
					continue
				var center := _cell_center_to_world(cell)
				if _uses_generated_forest_surface(tile_id):
					continue
				var top := center + Vector2(0.0, -half_h)
				var right := center + Vector2(half_w, 0.0)
				var bottom := center + Vector2(0.0, half_h)
				var left := center + Vector2(-half_w, 0.0)
				var base := vertices.size()
				vertices.append(top)
				vertices.append(right)
				vertices.append(bottom)
				vertices.append(left)
				var color := _tile_color(tile_id)
				colors.append(color)
				colors.append(color)
				colors.append(color)
				colors.append(color)
				indices.append(base)
				indices.append(base + 1)
				indices.append(base + 2)
				indices.append(base)
				indices.append(base + 2)
				indices.append(base + 3)
				grid.append(top)
				grid.append(right)
				grid.append(right)
				grid.append(bottom)
				grid.append(bottom)
				grid.append(left)
				grid.append(left)
				grid.append(top)
				_append_texture_details(
					cell,
					tile_id,
					center,
					half_w,
					half_h
				)
				if (
					_cliff_mesh_builder != null
					and resolver != null
					and resolver.is_void_transition_tile_id(tile_id)
				):
					var cliff_depth := maxf(half_h * 8.0, 28.0)
					var south_lookahead := ceili(cliff_depth / scale) + 1
					_cliff_mesh_builder.append_transition(
						tile_id,
						center,
						half_w,
						half_h,
						_get_southern_tile_ids(cell, south_lookahead),
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
	if _cliff_mesh_builder != null:
		_cliff_mesh_builder.build_meshes()

func _uses_generated_forest_surface(tile_id: StringName) -> bool:
	var texture_id := _forest_surface_texture_id(tile_id)
	return (
		not texture_id.is_empty()
		and _forest_surface_textures.get(texture_id) is Texture2D
	)

func _forest_surface_texture_id(tile_id: StringName) -> StringName:
	if FOREST_GRASS_SURFACE_TILE_IDS.has(tile_id):
		return FOREST_GRASS_TEXTURE_ID
	match tile_id:
		IsometricTileResolver.TILE_FOREST_PATH:
			return &"forest_path"
		IsometricTileResolver.TILE_FOREST_ROAD:
			return &"forest_road"
		IsometricTileResolver.TILE_GRASS_TO_PATH:
			return &"grass_to_path"
		IsometricTileResolver.TILE_GRASS_TO_ROAD:
			return &"grass_to_road"
		IsometricTileResolver.TILE_PATH_TO_ROAD:
			return &"path_to_road"
		_:
			return &""

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

func _build_forest_underlay_mesh(scale: float) -> ArrayMesh:
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for y in range(layout.zone_size.y):
		var run_start := 0
		var run_key := _forest_underlay_key(get_resolved_tile_id(Vector2i(0, y)))
		for x in range(1, layout.zone_size.x + 1):
			var next_key := &""
			if x < layout.zone_size.x:
				next_key = _forest_underlay_key(get_resolved_tile_id(Vector2i(x, y)))
			if x < layout.zone_size.x and next_key == run_key:
				continue
			_append_underlay_run(vertices, colors, indices, run_start, x, y, scale, _forest_underlay_color(run_key))
			run_start = x
			run_key = next_key
	if vertices.is_empty():
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _build_forest_surface_mesh(scale: float, texture_id: StringName) -> ArrayMesh:
	var surface_runs: Array[Rect2i] = []
	for y in range(layout.zone_size.y):
		var run_start := -1
		for x in range(layout.zone_size.x + 1):
			var uses_texture := (
				x < layout.zone_size.x
				and _forest_surface_texture_id(
					get_resolved_tile_id(Vector2i(x, y))
				) == texture_id
			)
			if uses_texture and run_start < 0:
				run_start = x
			elif not uses_texture and run_start >= 0:
				surface_runs.append(Rect2i(run_start, y, x - run_start, 1))
				run_start = -1
	return FOREST_GROUND_MESH_BUILDER_SCRIPT.build_mesh(
		surface_runs,
		layout.zone_size,
		scale,
		_forest_surface_texture_world_size(texture_id)
	)

func _forest_surface_texture_world_size(texture_id: StringName) -> float:
	if FOREST_TRANSITION_TEXTURE_IDS.has(texture_id):
		# Transition cells are one logical cell wide. A shorter repeat period makes
		# both source materials survive mipmapped downscale without creating a
		# checkerboard along long junction runs.
		return 128.0
	return FOREST_SURFACE_TEXTURE_WORLD_SIZE

func _append_underlay_run(
	vertices: PackedVector2Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	start_x: int,
	end_x: int,
	y: int,
	scale: float,
	color: Color
) -> void:
	if end_x <= start_x:
		return
	var zone_offset := Vector2(float(layout.zone_size.x), float(layout.zone_size.y)) * 0.5
	var left := (float(start_x) - zone_offset.x) * scale
	var right := (float(end_x) - zone_offset.x) * scale
	var top := (float(y) - zone_offset.y) * scale
	var bottom := (float(y + 1) - zone_offset.y) * scale
	var base := vertices.size()
	vertices.append(Vector2(left, top))
	vertices.append(Vector2(right, top))
	vertices.append(Vector2(right, bottom))
	vertices.append(Vector2(left, bottom))
	for _index in range(4):
		colors.append(color)
	indices.append(base)
	indices.append(base + 1)
	indices.append(base + 2)
	indices.append(base)
	indices.append(base + 2)
	indices.append(base + 3)

func _forest_underlay_key(tile_id: StringName) -> StringName:
	if resolver != null and resolver.is_void_transition_tile_id(tile_id):
		return &"cliff"
	match tile_id:
		IsometricTileResolver.TILE_FOREST_PATH, IsometricTileResolver.TILE_GRASS_TO_PATH:
			return &"path"
		IsometricTileResolver.TILE_FOREST_ROAD, IsometricTileResolver.TILE_GRASS_TO_ROAD, IsometricTileResolver.TILE_PATH_TO_ROAD:
			return &"road"
		IsometricTileResolver.TILE_FOREST_CLIFF_EDGE, IsometricTileResolver.TILE_GROUND_TO_VOID_CLIFF:
			return &"cliff"
		IsometricTileResolver.TILE_FOREST_VOID:
			return &"void"
		IsometricTileResolver.TILE_FOREST_MOUNTAIN_WALL, IsometricTileResolver.TILE_GROUND_TO_MOUNTAIN_WALL:
			return &"wall"
		_:
			return &"grass"

func _forest_underlay_color(key: StringName) -> Color:
	match key:
		&"path":
			return Color(0.31, 0.20, 0.10, 1.0)
		&"road":
			return Color(0.36, 0.25, 0.12, 1.0)
		&"cliff":
			var cliff_value := clampf(
				palette.prop_color.get_luminance() * 0.82,
				0.20,
				0.34
			)
			return Color(cliff_value, cliff_value, cliff_value, 1.0)
		&"void":
			return get_void_background_color()
		&"wall":
			return Color(0.18, 0.22, 0.14, 1.0)
		_:
			return Color(0.13, 0.24, 0.12, 1.0)

func _uses_forest_ground() -> bool:
	return biome_id == IsometricTileResolver.FOREST_BIOME_ID

func _should_draw_grid() -> bool:
	return not _uses_forest_ground()

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
			var contract_key := "%s:%s" % [String(section), String(tile_id)]
			if not asset_exists_by_contract.has(contract_key):
				asset_exists_by_contract[contract_key] = _asset_path_exists(cached_asset_path)
			var key := _cell_key(cell)
			_tile_id_cache[key] = tile_id
			_tile_section_cache[key] = section
			_tile_role_cache[key] = role
			_asset_path_cache[key] = cached_asset_path
			if not bool(asset_exists_by_contract[contract_key]):
				_missing_asset_count += 1

func _resolve_chunk_size(next_chunk_size: int, preset: StringName) -> int:
	if next_chunk_size > 0:
		return next_chunk_size
	match preset:
		&"performance":
			return PERFORMANCE_CHUNK_SIZE
		&"quality":
			return QUALITY_CHUNK_SIZE
		_:
			return DEFAULT_CHUNK_SIZE

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
		if _uses_forest_ground():
			return Color(0.12, 0.205, 0.135, 1.0)
		return palette.background_color.darkened(0.38)
	match tile_id:
		IsometricTileResolver.TILE_FOREST_GRASS:
			return Color(0.20, 0.34, 0.17, 1.0)
		IsometricTileResolver.TILE_FOREST_GRASS_VARIANT_01:
			return Color(0.17, 0.30, 0.15, 1.0)
		IsometricTileResolver.TILE_FOREST_GRASS_VARIANT_02:
			return Color(0.23, 0.36, 0.18, 1.0)
		IsometricTileResolver.TILE_FOREST_TALL_GRASS:
			return Color(0.12, 0.25, 0.11, 1.0)
		IsometricTileResolver.TILE_FOREST_PATH:
			return Color(0.43, 0.31, 0.17, 1.0)
		IsometricTileResolver.TILE_FOREST_ROAD:
			return Color(0.50, 0.38, 0.22, 1.0)
		IsometricTileResolver.TILE_GRASS_TO_PATH:
			return Color(0.34, 0.31, 0.16, 1.0)
		IsometricTileResolver.TILE_GRASS_TO_ROAD:
			return Color(0.37, 0.32, 0.17, 1.0)
		IsometricTileResolver.TILE_GRASS_TO_TALL_GRASS:
			return Color(0.15, 0.28, 0.12, 1.0)
		IsometricTileResolver.TILE_PATH_TO_ROAD:
			return Color(0.47, 0.35, 0.19, 1.0)
		IsometricTileResolver.TILE_GROUND_TO_VOID_CLIFF:
			return Color(0.19, 0.28, 0.15, 1.0)
		IsometricTileResolver.TILE_GROUND_TO_MOUNTAIN_WALL:
			return Color(0.21, 0.25, 0.16, 1.0)
		IsometricTileResolver.TILE_FOREST_CLIFF_EDGE:
			return Color(0.13, 0.21, 0.14, 1.0)
		IsometricTileResolver.TILE_FOREST_VOID:
			return Color(0.08, 0.14, 0.095, 1.0)
		IsometricTileResolver.TILE_FOREST_MOUNTAIN_WALL:
			return Color(0.19, 0.21, 0.17, 1.0)
		IsometricTileResolver.TILE_MAIN_ROAD, IsometricTileResolver.TILE_ROAD:
			return Color(palette.lane_color, maxf(palette.lane_color.a, 0.46))
		IsometricTileResolver.TILE_ROAD_INTERSECTION:
			return Color(palette.lane_color.lightened(0.12), 0.58)
		IsometricTileResolver.TILE_ROAD_EDGE:
			return Color(palette.lane_color.darkened(0.12), 0.50)
		IsometricTileResolver.TILE_ROAD_CURVE_NORTH, IsometricTileResolver.TILE_ROAD_CURVE_EAST, IsometricTileResolver.TILE_ROAD_CURVE_SOUTH, IsometricTileResolver.TILE_ROAD_CURVE_WEST:
			return Color(palette.lane_color.lightened(0.06), 0.54)
		IsometricTileResolver.TILE_BROKEN_STREET:
			return Color(palette.lane_color.darkened(0.18), 0.52)
		IsometricTileResolver.TILE_SERVICE_LANE:
			return Color(palette.gate_color.lightened(0.06), 0.52)
		IsometricTileResolver.TILE_ASH_LANE, IsometricTileResolver.TILE_BURNED_ROAD:
			return Color(palette.hazard_color.darkened(0.22), 0.58)
		IsometricTileResolver.TILE_PACKED_SNOW_PATH, IsometricTileResolver.TILE_SNOW_PASS:
			return Color(palette.floor_color.lightened(0.22), 0.58)
		IsometricTileResolver.TILE_WOODEN_WALKWAY, IsometricTileResolver.TILE_BRIDGE:
			return Color(palette.prop_color.lightened(0.08), 0.56)
		IsometricTileResolver.TILE_BROKEN_GATE:
			return Color(palette.gate_color.darkened(0.10), 0.54)
		IsometricTileResolver.TILE_BRIDGE_BROKEN:
			return Color(palette.prop_color.darkened(0.18), 0.56)
		IsometricTileResolver.TILE_CLIFF_RAMP:
			return Color(palette.background_color.lightened(0.12), 0.54)
		IsometricTileResolver.TILE_HAZARD_FLOOR:
			return Color(palette.hazard_color, 0.60)
		IsometricTileResolver.TILE_BORDER_FLOOR:
			return palette.floor_color.darkened(0.24)
		IsometricTileResolver.TILE_VOID_EDGE_NEAR:
			return palette.background_color.darkened(0.38)
		IsometricTileResolver.TILE_VOID_DEPTH:
			# The depth remains dark, but not pure black: cliff faces, fissures and
			# low mist provide a readable visual descent from the walkable lip.
			return palette.background_color.darkened(0.56)
		IsometricTileResolver.TILE_FLOOR_VARIANT_01:
			return palette.alternate_floor_color
		IsometricTileResolver.TILE_FLOOR_VARIANT_02:
			return palette.floor_color.lightened(0.035)
		IsometricTileResolver.TILE_FLOOR_VARIANT_03:
			return palette.alternate_floor_color.darkened(0.045)
		_:
			return palette.floor_color

func _is_untextured_void_tile(tile_id: StringName) -> bool:
	return (
		tile_id == IsometricTileResolver.TILE_VOID_DEPTH
		or tile_id == IsometricTileResolver.TILE_FOREST_VOID
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
		IsometricTileResolver.TILE_FOREST_GRASS, IsometricTileResolver.TILE_FOREST_GRASS_VARIANT_01, IsometricTileResolver.TILE_FOREST_GRASS_VARIANT_02:
			_append_grass_texture(cell, center, half_w, half_h)
		IsometricTileResolver.TILE_FOREST_TALL_GRASS:
			_append_tall_grass_texture(cell, center, half_w, half_h)
		IsometricTileResolver.TILE_FOREST_PATH, IsometricTileResolver.TILE_GRASS_TO_PATH:
			_append_path_texture(cell, center, half_w, half_h, false)
		IsometricTileResolver.TILE_FOREST_ROAD, IsometricTileResolver.TILE_GRASS_TO_ROAD, IsometricTileResolver.TILE_PATH_TO_ROAD:
			_append_path_texture(cell, center, half_w, half_h, true)
		IsometricTileResolver.TILE_GRASS_TO_TALL_GRASS, IsometricTileResolver.TILE_GROUND_TO_MOUNTAIN_WALL:
			_append_transition_texture(cell, center, half_w, half_h)
		IsometricTileResolver.TILE_GROUND_TO_VOID_CLIFF, IsometricTileResolver.TILE_FOREST_CLIFF_EDGE:
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
