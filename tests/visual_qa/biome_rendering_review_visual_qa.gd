extends SceneTree

const OUTPUT_DIR := "res://build/qa/biome_rendering_review"
const VISUAL_QA_RUNTIME = preload(
	"res://tests/visual_qa/helpers/visual_qa_runtime.gd"
)
const GENERATED_ART_CATALOG = preload(
	"res://game/modes/zombie/biome_generated_art_catalog.gd"
)
const BIOMES: Array[StringName] = [
	&"infected_plains",
	&"toxic_wastes",
	&"burning_fields",
	&"frozen_outskirts",
	&"drowned_marsh"
]
const REVIEW_SEEDS: Array[int] = [641004, 772031, 918273]
const REVIEW_RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(960, 540)
]
const FOCUS_CENTER := &"center"
const FOCUS_PASSAGE := &"passage"
const FOCUS_CLIFF := &"fall_cliff"
const FOCUS_OBSTACLE := &"obstacle_hazard"
const FOCUS_CRATE := &"resource_crate"
const FOCUS_REED_WALL := &"reed_wall"
const FOCUS_ACTORS := &"actors"
const FOCUS_PLAYER_ROSTER := &"player_roster"
const FOCUS_ROUTE_TRANSITION := &"route_transition"
const FOCUSES: Array[StringName] = [
	FOCUS_CENTER,
	FOCUS_PASSAGE,
	FOCUS_CLIFF,
	FOCUS_OBSTACLE,
	FOCUS_ACTORS
]
const GENERATED_ROAD_SURFACE_TILE_IDS: Array[StringName] = [
	&"main_road",
	&"road",
	&"road_intersection",
	&"road_entry",
	&"road_exit",
	&"bridge",
	&"bridge_entry",
	&"bridge_exit",
	&"snow_pass",
	&"snow_pass_entry",
	&"snow_pass_exit",
	&"broken_gate",
	&"broken_gate_entry",
	&"broken_gate_exit",
	&"burned_road",
	&"burned_road_entry",
	&"burned_road_exit",
]
const GENERATED_PATH_SURFACE_TILE_IDS: Array[StringName] = [
	&"service_lane",
	&"ash_lane",
	&"packed_snow_path",
	&"wooden_walkway",
]
const GENERATED_ROAD_BORDER_TILE_IDS: Array[StringName] = [
	&"road_edge",
	&"road_curve_north",
	&"road_curve_east",
	&"road_curve_south",
	&"road_curve_west",
]
const WORLD_CONTEXT_BASE := {
	"biome_map_width": 3,
	"biome_map_height": 3,
	"extra_edge_chance": 0.5,
	"async_world_build": false
}
const MIN_DETAIL_RATIO := 0.035
const MIN_WORLD_COVERAGE_RATIO := 0.30
const INVALID_FOCUS_POSITION := Vector2(1.0e20, 1.0e20)

var failures := PackedStringArray()
var game_mode_manager: GameModeManager
var survival_mode: SurvivalMode
var wave_manager: WaveManager
var biome_manager: BiomeManager
var enemy_system: EnemySystem
var player_manager: PlayerManager
var terrain_generator: TerrainGenerator
var streamer: WorldRegionStreamer
var seam_system: Node

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var output_absolute := ProjectSettings.globalize_path(_get_output_dir())
	_expect(
		DirAccess.make_dir_recursive_absolute(output_absolute) == OK,
		"biome rendering review output directory is available"
	)
	var main_scene := load("res://game/main/main.tscn") as PackedScene
	_expect(main_scene != null, "main scene can be loaded for biome rendering review")
	if main_scene == null:
		_finish()
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	current_scene = main
	await _wait_process_frames(3)
	_resolve_runtime()
	if not _runtime_is_available():
		_finish()
		return
	if wave_manager != null:
		wave_manager.initial_delay = 100.0
	for seed in _get_review_seeds():
		await _start_review_world(seed)
		for biome_id in _get_review_biomes():
			await _review_biome(seed, biome_id)
		_stop_survival()
		await _wait_process_frames(2)
	await _wait_process_frames(2)
	_finish()

func _resolve_runtime() -> void:
	game_mode_manager = get_first_node_in_group("game_mode_manager") as GameModeManager
	survival_mode = get_first_node_in_group("survival_mode") as SurvivalMode
	wave_manager = get_first_node_in_group("wave_manager") as WaveManager
	biome_manager = get_first_node_in_group("biome_manager") as BiomeManager
	enemy_system = get_first_node_in_group("enemy_system") as EnemySystem
	player_manager = get_first_node_in_group("player_manager") as PlayerManager
	terrain_generator = get_first_node_in_group("terrain_generator") as TerrainGenerator
	streamer = get_first_node_in_group("world_region_streamer") as WorldRegionStreamer
	seam_system = get_first_node_in_group("region_seam_system")
	if seam_system != null:
		seam_system.set_process(false)
	_expect(game_mode_manager != null, "game mode manager is available")
	_expect(survival_mode != null, "survival mode is available")
	_expect(wave_manager != null, "wave manager is available")
	_expect(biome_manager != null, "biome manager is available")
	_expect(enemy_system != null, "enemy system is available")
	_expect(player_manager != null, "player manager is available")
	_expect(terrain_generator != null, "terrain generator is available")
	_expect(streamer != null, "world region streamer is available")

func _runtime_is_available() -> bool:
	return (
		game_mode_manager != null
		and survival_mode != null
		and biome_manager != null
		and enemy_system != null
		and player_manager != null
		and terrain_generator != null
		and streamer != null
	)

func _apply_resolution(resolution: Vector2i) -> void:
	root.content_scale_size = resolution
	root.size = resolution

func _start_review_world(seed: int) -> void:
	_stop_survival()
	await _wait_process_frames(2)
	var context := WORLD_CONTEXT_BASE.duplicate(true)
	context["world_seed"] = seed
	_expect(
		game_mode_manager.set_mode(GameConstants.MODE_SURVIVAL, context),
		"survival starts for biome rendering review seed %d" % seed
	)
	await _wait_until_world_ready()
	_expect(
		_all_biomes_generated(),
		"seed %d generates all review biomes" % seed
	)

func _stop_survival() -> void:
	if survival_mode != null:
		survival_mode.stop_mode()

func _wait_until_world_ready() -> void:
	var ready: Dictionary = await VISUAL_QA_RUNTIME.wait_for_capture_ready(
		self,
		func() -> bool:
			return (
				biome_manager != null
				and biome_manager.get_world_graph() != null
				and not biome_manager.get_generated_biome_map().is_empty()
			)
	)
	_expect(
		bool(ready.get("ready", false)),
		"review world is capture-ready: %s"
		% VISUAL_QA_RUNTIME.describe_failure(ready)
	)

func _all_biomes_generated() -> bool:
	for biome_id in _get_review_biomes():
		if _first_cell_for_biome(biome_id) == null:
			return false
	return true

func _review_biome(
	seed: int,
	biome_id: StringName
) -> void:
	var cell := _first_cell_for_biome(biome_id)
	_expect(cell != null, "%s region exists for seed %d" % [String(biome_id), seed])
	if cell == null:
		return
	_expect(
		biome_manager.set_current_region(cell.id),
		"%s region is selected for seed %d" % [String(biome_id), seed]
	)
	await _wait_for_current_region(cell.id, biome_id)
	_expect(
		_current_region_has_streamed_content(cell),
		"%s streams full visual content for seed %d" % [String(biome_id), seed]
	)
	_assert_tile_layers_have_assets(biome_id, seed)
	_assert_runtime_obstacles_have_assets(biome_id, seed)
	for focus in _get_focuses():
		await _capture_focus(seed, cell, focus)
	_clear_review_enemies()

func _first_cell_for_biome(biome_id: StringName) -> BiomeCell:
	if biome_manager == null:
		return null
	for cell in biome_manager.get_generated_biome_map():
		if cell.biome_id == biome_id and cell.generated_layout != null:
			return cell
	return null

func _wait_for_current_region(region_id: StringName, biome_id: StringName) -> void:
	var ready: Dictionary = await VISUAL_QA_RUNTIME.wait_for_capture_ready(
		self,
		func() -> bool:
			return (
				biome_manager.get_current_region_id() == region_id
				and (
					streamer.get_content_level(region_id)
					== WorldRegionStreamer.ContentLevel.FULL
				)
			)
	)
	_expect(
		bool(ready.get("ready", false)),
		"%s current tile layer is capture-ready: %s"
		% [
			String(biome_id),
			VISUAL_QA_RUNTIME.describe_failure(ready)
		]
	)

func _current_region_has_streamed_content(cell: BiomeCell) -> bool:
	if cell == null or cell.generated_layout == null or streamer == null:
		return false
	var counts := streamer.get_region_content_counts(cell.id)
	var layout := cell.generated_layout
	return (
		int(counts.get("tiles", 0)) == layout.zone_size.x * layout.zone_size.y
		and int(counts.get("obstacles", 0)) == layout.obstacle_positions.size()
		and int(counts.get("hazards", 0)) == layout.hazard_positions.size()
	)

func _assert_tile_layers_have_assets(biome_id: StringName, seed: int) -> void:
	var checked := 0
	var missing_assets := 0
	var procedural_fallbacks := 0
	var generated_route_layers := 0
	var generated_route_cells := 0
	var route_material_failures := PackedStringArray()
	for node in get_nodes_in_group("biome_tile_layers"):
		var layer := node as BiomeTileLayer
		if layer == null or not is_instance_valid(layer) or layer.is_queued_for_deletion():
			continue
		if layer.is_building():
			continue
		checked += 1
		if layer.get_visual_tile_count() <= 0:
			missing_assets += 1
		missing_assets += layer.get_missing_asset_count()
		if layer.uses_procedural_fallback():
			procedural_fallbacks += 1
		var route_report := _generated_route_material_report(layer)
		if int(route_report.get("route_cells", 0)) > 0:
			generated_route_layers += 1
			generated_route_cells += int(route_report.get("route_cells", 0))
		route_material_failures.append_array(
			route_report.get("failures", PackedStringArray()) as PackedStringArray
		)
	_expect(checked > 0, "%s seed %d exposes tile layers" % [String(biome_id), seed])
	_expect(
		missing_assets == 0,
		"%s seed %d tile layers have no missing assets (%d checked)"
		% [String(biome_id), seed, checked]
	)
	_expect(
		procedural_fallbacks == 0,
		"%s seed %d tile layers avoid procedural fallback (%d checked)"
		% [String(biome_id), seed, checked]
	)
	if GENERATED_ART_CATALOG.has_generated_theme(biome_id):
		_expect(
			generated_route_layers > 0 and generated_route_cells > 0,
			"%s seed %d exposes generated route material cells"
			% [String(biome_id), seed]
		)
	_expect(
		route_material_failures.is_empty(),
		"%s seed %d generated route materials are assigned: %s"
		% [String(biome_id), seed, "; ".join(route_material_failures)]
	)

func _generated_route_material_report(layer: BiomeTileLayer) -> Dictionary:
	var failures := PackedStringArray()
	var route_cells := 0
	if (
		layer == null
		or layer.layout == null
		or not GENERATED_ART_CATALOG.has_generated_theme(layer.biome_id)
	):
		return {"route_cells": route_cells, "failures": failures}
	var theme_fragment := "/%s/" % String(
		GENERATED_ART_CATALOG.get_theme_id_for_biome(layer.biome_id)
	)
	for y in range(layer.layout.zone_size.y):
		for x in range(layer.layout.zone_size.x):
			var cell := Vector2i(x, y)
			var tile_id := layer.get_resolved_tile_id(cell)
			if GENERATED_ROAD_SURFACE_TILE_IDS.has(tile_id):
				route_cells += 1
				_assert_generated_route_path(
					failures,
					layer,
					cell,
					theme_fragment,
					"road_border_defined",
					true
				)
			elif GENERATED_PATH_SURFACE_TILE_IDS.has(tile_id):
				route_cells += 1
				_assert_generated_route_path(
					failures,
					layer,
					cell,
					theme_fragment,
					"path_variation",
					false
				)
			elif GENERATED_ROAD_BORDER_TILE_IDS.has(tile_id):
				route_cells += 1
				_assert_generated_route_path(
					failures,
					layer,
					cell,
					theme_fragment,
					"road_border_defined",
					true
				)
	return {"route_cells": route_cells, "failures": failures}

func _assert_generated_route_path(
	failures: PackedStringArray,
	layer: BiomeTileLayer,
	cell: Vector2i,
	theme_fragment: String,
	expected_fragment: String,
	expect_oriented_id: bool
) -> void:
	var material_path := layer.get_resolved_material_asset_path(cell)
	var material_id := layer.get_resolved_material_asset_id(cell)
	if (
		material_path.contains(theme_fragment)
		and material_path.contains(expected_fragment)
		and (
			not expect_oriented_id
			or String(material_id).ends_with("__horizontal")
			or String(material_id).ends_with("__vertical")
		)
	):
		return
	failures.append(
		"%s %s cell %s -> id=%s path=%s"
		% [
			String(layer.biome_id),
			String(layer.get_resolved_tile_id(cell)),
			str(cell),
			String(material_id),
			material_path,
		]
	)

func _assert_runtime_obstacles_have_assets(biome_id: StringName, seed: int) -> void:
	var checked := 0
	var current_region_id := biome_manager.get_current_region_id()
	var generic_failures := PackedStringArray()
	var generic_path_failures := PackedStringArray()
	for node in get_nodes_in_group("environment_obstacles"):
		if not is_instance_valid(node) or node.is_queued_for_deletion():
			continue
		if node.has_meta("region_id") and StringName(node.get_meta("region_id")) != current_region_id:
			continue
		if node.has_method("is_perimeter_wall") and bool(node.call("is_perimeter_wall")):
			continue
		if node.has_method("uses_generic_fallback"):
			checked += 1
			if bool(node.call("uses_generic_fallback")):
				generic_failures.append(String(node.name))
		if node.has_method("get_asset_path"):
			var asset_path := String(node.call("get_asset_path"))
			if _path_has_generic_marker(asset_path):
				generic_path_failures.append("%s -> %s" % [String(node.name), asset_path])
	_expect(checked > 0, "%s seed %d checks runtime obstacle assets" % [String(biome_id), seed])
	if not generic_failures.is_empty():
		_expect(
			false,
			"%s seed %d generic obstacle fallback: %s"
			% [String(biome_id), seed, ", ".join(generic_failures)]
		)
	else:
		_expect(
			true,
			"%s seed %d runtime obstacles avoid generic fallback (%d checked)"
			% [String(biome_id), seed, checked]
		)
	if not generic_path_failures.is_empty():
		_expect(
			false,
			"%s seed %d generic obstacle asset paths: %s"
			% [String(biome_id), seed, ", ".join(generic_path_failures)]
		)
	else:
		_expect(
			true,
			"%s seed %d runtime obstacle paths avoid generic markers (%d checked)"
			% [String(biome_id), seed, checked]
		)

func _capture_focus(
	seed: int,
	cell: BiomeCell,
	focus: StringName
) -> void:
	if cell == null or cell.generated_layout == null:
		return
	_clear_review_enemies()
	var focus_position := _focus_position(cell, focus)
	var player := player_manager.players.get(1) as PlayerController
	if player != null:
		_move_node(player, focus_position)
	if focus == FOCUS_ACTORS or focus == FOCUS_PLAYER_ROSTER:
		_spawn_biome_roster(cell.biome_id, focus_position)
	var camera := root.get_camera_2d()
	var original_zoom := camera.zoom if camera != null else Vector2.ONE
	if camera != null and focus == FOCUS_ROUTE_TRANSITION:
		camera.zoom = original_zoom * 1.35
	for resolution in _get_review_resolutions():
		_apply_resolution(resolution)
		_snap_camera(focus_position)
		var capture_ready: Dictionary = (
			await VISUAL_QA_RUNTIME.wait_for_capture_ready(
				self,
				func() -> bool: return _focus_marker_is_ready(
					cell,
					focus
				)
			)
		)
		var file_name := "%s_seed_%d_%s_%s_%s.png" % [
			_resolution_slug(resolution),
			seed,
			String(cell.biome_id),
			String(cell.id),
			String(focus)
		]
		_expect(
			bool(capture_ready.get("ready", false)),
			"%s capture state is ready with no missing chunks: %s"
			% [
				file_name,
				VISUAL_QA_RUNTIME.describe_failure(capture_ready)
			]
		)
		if not bool(capture_ready.get("ready", false)):
			continue
		var image := root.get_texture().get_image()
		_expect(
			image != null and not image.is_empty(),
			"%s capture image is available" % file_name
		)
		if image == null or image.is_empty():
			continue
		_expect(
			_image_has_world_detail(image),
			"%s capture has enough visible detail" % file_name
		)
		_expect(
			_image_has_world_coverage(image),
			"%s capture has enough rendered world coverage"
			% file_name
		)
		var output_absolute := ProjectSettings.globalize_path(
			_get_output_dir().path_join(_resolution_slug(resolution))
		)
		_expect(
			DirAccess.make_dir_recursive_absolute(output_absolute) == OK,
			"%s output directory is available" % _resolution_slug(resolution)
		)
		_expect(
			image.save_png(output_absolute.path_join(file_name)) == OK,
			"%s screenshot is saved" % file_name
		)
	if camera != null:
		camera.zoom = original_zoom

func _focus_position(cell: BiomeCell, focus: StringName) -> Vector2:
	var layout := cell.generated_layout
	var offset := streamer.get_region_offset(cell.id)
	match focus:
		FOCUS_PASSAGE:
			if not layout.passage_connector_rects.is_empty():
				return offset + layout.rect_center_to_world(layout.passage_connector_rects.front())
			if not layout.passage_rects.is_empty():
				return offset + layout.rect_center_to_world(layout.passage_rects.front())
		FOCUS_CLIFF:
			if not layout.fall_zone_rects.is_empty():
				var safe_cell := _find_walkable_cell_near_rect(
					layout,
					layout.fall_zone_rects.front(),
					cell
				)
				if safe_cell != Vector2i(-1, -1):
					return offset + layout.logical_to_world(safe_cell)
				return offset + layout.rect_center_to_world(layout.fall_zone_rects.front())
		FOCUS_OBSTACLE:
			var hazard_position := _first_non_fall_hazard_focus(layout, cell)
			if hazard_position != INVALID_FOCUS_POSITION:
				return offset + hazard_position
			if not layout.obstacle_positions.is_empty():
				return offset + layout.obstacle_positions.front()
			if not layout.rock_rects.is_empty():
				return offset + layout.rect_center_to_world(layout.rock_rects.front())
		FOCUS_CRATE:
			if not layout.crate_cells.is_empty():
				var crate_focus_cell := _find_walkable_cell_near_crate(
					layout,
					layout.crate_cells.front(),
					cell
				)
				if crate_focus_cell != Vector2i(-1, -1):
					return offset + layout.logical_to_world(crate_focus_cell)
		FOCUS_REED_WALL:
			for index in range(layout.obstacle_ids.size()):
				if layout.obstacle_ids[index] != &"reed_wall":
					continue
				if index < layout.obstacle_rects.size():
					var reed_focus_cell := _find_walkable_cell_near_rect(
						layout,
						layout.obstacle_rects[index],
						cell
					)
					if reed_focus_cell != Vector2i(-1, -1):
						return offset + layout.logical_to_world(reed_focus_cell)
				if index < layout.obstacle_positions.size():
					return offset + layout.obstacle_positions[index]
		FOCUS_ROUTE_TRANSITION:
			var route_cell := _find_route_transition_cell(layout, cell)
			if route_cell != Vector2i(-1, -1):
				return offset + layout.logical_to_world(route_cell)
		FOCUS_CENTER, FOCUS_ACTORS, FOCUS_PLAYER_ROSTER:
			var actor_cell := _find_walkable_cell_near_center(layout, cell)
			if actor_cell != Vector2i(-1, -1):
				return offset + layout.logical_to_world(actor_cell)
		_:
			pass
	return offset + layout.logical_to_world(layout.player_spawn_cell)

func _focus_marker_is_ready(
	cell: BiomeCell,
	focus: StringName
) -> bool:
	return (
		biome_manager.get_current_region_id() == cell.id
		and (
			(focus != FOCUS_ACTORS and focus != FOCUS_PLAYER_ROSTER)
			or get_nodes_in_group(
				"biome_rendering_review_enemies"
			).size() > 0
		)
	)

func _find_route_transition_cell(
	layout: BiomeEnvironmentLayout,
	cell: BiomeCell
) -> Vector2i:
	var center := Vector2(layout.zone_size) * 0.5
	var best_cell := Vector2i(-1, -1)
	var best_distance := INF
	for y in range(layout.zone_size.y):
		for x in range(layout.zone_size.x):
			var candidate := Vector2i(x, y)
			if not _layout_has_route_at(layout, candidate):
				continue
			if (
				layout.get_terrain_class_at_cell(candidate, cell)
				!= BiomeEnvironmentLayout.TERRAIN_WALKABLE
			):
				continue
			var touches_ground := false
			for offset in IsometricTileResolver.CARDINAL_OFFSETS:
				var neighbor := candidate + offset
				if (
					neighbor.x < 0
					or neighbor.y < 0
					or neighbor.x >= layout.zone_size.x
					or neighbor.y >= layout.zone_size.y
				):
					continue
				if (
					not _layout_has_route_at(layout, neighbor)
					and layout.get_terrain_class_at_cell(neighbor, cell)
					== BiomeEnvironmentLayout.TERRAIN_WALKABLE
				):
					touches_ground = true
					break
			if not touches_ground:
				continue
			var distance := Vector2(candidate).distance_squared_to(center)
			if distance < best_distance:
				best_distance = distance
				best_cell = candidate
	return best_cell

func _layout_has_route_at(
	layout: BiomeEnvironmentLayout,
	cell: Vector2i
) -> bool:
	if layout.has_road_cell(cell):
		return true
	for road_rect in layout.road_rects:
		if road_rect.has_point(cell):
			return true
	return false

func _first_non_fall_hazard_focus(
	layout: BiomeEnvironmentLayout,
	cell: BiomeCell
) -> Vector2:
	for index in range(layout.hazard_ids.size()):
		if layout.hazard_ids[index] == &"fall_zone":
			continue
		if index >= layout.hazard_rects.size():
			continue
		var safe_cell := _find_walkable_cell_near_rect(
			layout,
			layout.hazard_rects[index],
			cell
		)
		if safe_cell != Vector2i(-1, -1):
			return layout.logical_to_world(safe_cell)
		if index < layout.hazard_positions.size():
			return layout.hazard_positions[index]
	return INVALID_FOCUS_POSITION

func _find_walkable_cell_near_center(
	layout: BiomeEnvironmentLayout,
	cell: BiomeCell
) -> Vector2i:
	var center := layout.zone_size / 2
	var best_cell := Vector2i(-1, -1)
	var best_distance := INF
	var rect := Rect2i(center - Vector2i(18, 18), Vector2i(36, 36)).intersection(
		Rect2i(Vector2i.ZERO, layout.zone_size)
	)
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var candidate := Vector2i(x, y)
			if layout.get_terrain_class_at_cell(candidate, cell) != BiomeEnvironmentLayout.TERRAIN_WALKABLE:
				continue
			var distance := Vector2(candidate).distance_squared_to(Vector2(center))
			if distance < best_distance:
				best_distance = distance
				best_cell = candidate
	return best_cell

func _find_walkable_cell_near_rect(
	layout: BiomeEnvironmentLayout,
	target_rect: Rect2i,
	cell: BiomeCell
) -> Vector2i:
	var expanded := target_rect.grow(8).intersection(
		Rect2i(Vector2i.ZERO, layout.zone_size)
	)
	var target_center := Vector2(target_rect.position) + Vector2(target_rect.size) * 0.5
	var best_cell := Vector2i(-1, -1)
	var best_distance := INF
	for y in range(expanded.position.y, expanded.end.y):
		for x in range(expanded.position.x, expanded.end.x):
			var candidate := Vector2i(x, y)
			if layout.get_terrain_class_at_cell(candidate, cell) != BiomeEnvironmentLayout.TERRAIN_WALKABLE:
				continue
			var distance := Vector2(candidate).distance_squared_to(target_center)
			if distance < best_distance:
				best_distance = distance
				best_cell = candidate
	return best_cell

func _find_walkable_cell_near_crate(
	layout: BiomeEnvironmentLayout,
	crate_cell: Vector2i,
	cell: BiomeCell
) -> Vector2i:
	var bounds := Rect2i(Vector2i.ZERO, layout.zone_size)
	var search_rect := Rect2i(
		crate_cell - Vector2i(6, 6),
		Vector2i(13, 13)
	).intersection(bounds)
	var best_cell := Vector2i(-1, -1)
	var best_distance := INF
	for y in range(search_rect.position.y, search_rect.end.y):
		for x in range(search_rect.position.x, search_rect.end.x):
			var candidate := Vector2i(x, y)
			var distance := Vector2(candidate).distance_to(Vector2(crate_cell))
			if distance < 2.5:
				continue
			if (
				layout.get_terrain_class_at_cell(candidate, cell)
				!= BiomeEnvironmentLayout.TERRAIN_WALKABLE
			):
				continue
			if distance < best_distance:
				best_distance = distance
				best_cell = candidate
	return best_cell

func _spawn_biome_roster(biome_id: StringName, origin: Vector2) -> void:
	var roster: Array[StringName] = [&"survival_zombie", &"survival_runner"]
	match biome_id:
		&"toxic_wastes":
			roster = [&"toxic_zombie", &"toxic_exploder"]
		&"burning_fields":
			roster = [&"burned_zombie", &"fire_runner", &"fire_exploder"]
		&"frozen_outskirts":
			roster = [&"frozen_zombie", &"ice_armored_zombie", &"heavy_slow_zombie"]
		&"drowned_marsh":
			roster = [&"drowned_zombie", &"marsh_zombie", &"water_emerging_zombie"]
	for index in range(roster.size()):
		var enemy := enemy_system.spawn_enemy(
			roster[index],
			origin + Vector2(-170.0 + float(index) * 170.0, -95.0),
			null,
			{"wave_index": 1}
		)
		if enemy == null:
			continue
		enemy.add_to_group("biome_rendering_review_enemies")
		enemy.set_physics_process(false)
		var visual := enemy.get_node_or_null("Visual") as ZombieVisual
		if visual != null:
			visual.modulate = Color.WHITE
			visual.set_state(&"chase")
			visual.set_facing(Vector2.DOWN)

func _clear_review_enemies() -> void:
	for enemy in get_nodes_in_group("biome_rendering_review_enemies"):
		if is_instance_valid(enemy):
			enemy.queue_free()

func _move_node(node: Node2D, position: Vector2) -> void:
	node.global_position = position
	if node is CharacterBody2D:
		(node as CharacterBody2D).velocity = Vector2.ZERO

func _snap_camera(position: Vector2) -> void:
	var camera := root.get_camera_2d()
	if camera == null:
		return
	camera.global_position = position
	camera.reset_smoothing()

func _image_has_world_detail(image: Image) -> bool:
	var sampled := 0
	var contrast_samples := 0
	var start_y := image.get_height() / 4
	for y in range(start_y, image.get_height() - 4, 8):
		for x in range(0, image.get_width() - 4, 8):
			var color := image.get_pixel(x, y)
			var right := image.get_pixel(x + 4, y)
			var down := image.get_pixel(x, y + 4)
			var contrast := (
				absf(color.r - right.r)
				+ absf(color.g - right.g)
				+ absf(color.b - right.b)
				+ absf(color.r - down.r)
				+ absf(color.g - down.g)
				+ absf(color.b - down.b)
			)
			sampled += 1
			if contrast >= 0.03:
				contrast_samples += 1
	return (
		sampled > 0
		and float(contrast_samples) / float(sampled) >= MIN_DETAIL_RATIO
	)

func _image_has_world_coverage(image: Image) -> bool:
	var sampled := 0
	var world_samples := 0
	var start_y := image.get_height() / 4
	for y in range(start_y, image.get_height(), 8):
		for x in range(0, image.get_width(), 8):
			var color := image.get_pixel(x, y)
			sampled += 1
			if maxf(color.r, maxf(color.g, color.b)) >= 0.035:
				world_samples += 1
	return (
		sampled > 0
		and float(world_samples) / float(sampled)
		>= MIN_WORLD_COVERAGE_RATIO
	)

func _path_has_generic_marker(path: String) -> bool:
	var lower_path := path.to_lower()
	return lower_path.contains("placeholder") or lower_path.contains("generic")

func _resolution_slug(resolution: Vector2i) -> String:
	return "%dx%d" % [resolution.x, resolution.y]

func _wait_process_frames(count: int) -> void:
	for _index in range(count):
		await process_frame

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	_clear_review_enemies()
	_stop_survival()
	var exit_code := 0
	if failures.is_empty():
		print("%s: PASS" % _get_result_label())
	else:
		exit_code = 1
		print("%s: FAIL (%d)" % [_get_result_label(), failures.size()])
	await VISUAL_QA_RUNTIME.cleanup_scene(self)
	quit(exit_code)

func _get_output_dir() -> String:
	return OUTPUT_DIR

func _get_review_biomes() -> Array[StringName]:
	return BIOMES.duplicate()

func _get_review_seeds() -> Array[int]:
	return REVIEW_SEEDS.duplicate()

func _get_review_resolutions() -> Array[Vector2i]:
	return REVIEW_RESOLUTIONS.duplicate()

func _get_focuses() -> Array[StringName]:
	return FOCUSES.duplicate()

func _get_result_label() -> String:
	return "BIOME_RENDERING_REVIEW_VISUAL_QA"
