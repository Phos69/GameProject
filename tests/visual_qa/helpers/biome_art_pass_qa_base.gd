extends SceneTree

## Base condivisa per le QA dedicate ART-VIS-FIX (una per bioma).
##
## Riusa il contratto di readiness del review biomi (overlay assente, marker,
## terreno pronto, zero chunk visibili mancanti) ma limita il lavoro a un solo
## bioma, cosi' il ciclo screenshot -> fix -> verifica resta rapido. Le entry
## point per-bioma impostano `biome_id`, `output_dir` e `qa_label` in _init().

const VISUAL_QA_RUNTIME = preload(
	"res://tests/visual_qa/helpers/visual_qa_runtime.gd"
)
const REVIEW_SEEDS: Array[int] = [641004, 772031, 918273]
const REVIEW_RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(960, 540)
]
const CLOSEUP_RESOLUTION := Vector2i(640, 360)
const FOCUS_CENTER := &"center"
const FOCUS_PASSAGE := &"passage"
const FOCUS_CLIFF := &"fall_cliff"
const FOCUS_OBSTACLE := &"obstacle_hazard"
const FOCUS_ROSTER := &"player_roster"
const FOCUSES: Array[StringName] = [
	FOCUS_CENTER,
	FOCUS_PASSAGE,
	FOCUS_CLIFF,
	FOCUS_OBSTACLE,
	FOCUS_ROSTER
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

var biome_id: StringName = &""
var output_dir := ""
var qa_label := "BIOME_ART_PASS_QA"

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
	if biome_id.is_empty() or output_dir.is_empty():
		_expect(false, "biome art QA entry point configures biome_id and output_dir")
		_finish()
		return
	var output_absolute := ProjectSettings.globalize_path(output_dir)
	_expect(
		DirAccess.make_dir_recursive_absolute(output_absolute) == OK,
		"%s output directory is available" % String(biome_id)
	)
	var main_scene := load("res://game/main/main.tscn") as PackedScene
	_expect(main_scene != null, "main scene loads for %s art QA" % String(biome_id))
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
	for seed in REVIEW_SEEDS:
		await _start_world(seed)
		await _review_biome(seed)
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

func _start_world(seed: int) -> void:
	_stop_survival()
	await _wait_process_frames(2)
	var context := WORLD_CONTEXT_BASE.duplicate(true)
	context["world_seed"] = seed
	_expect(
		game_mode_manager.set_mode(GameConstants.MODE_SURVIVAL, context),
		"survival starts for %s art QA seed %d" % [String(biome_id), seed]
	)
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
		"world is capture-ready for seed %d: %s"
		% [seed, VISUAL_QA_RUNTIME.describe_failure(ready)]
	)

func _stop_survival() -> void:
	if survival_mode != null:
		survival_mode.stop_mode()

func _review_biome(seed: int) -> void:
	var cell := _first_cell_for_biome()
	_expect(cell != null, "%s region exists for seed %d" % [String(biome_id), seed])
	if cell == null:
		return
	_expect(
		biome_manager.set_current_region(cell.id),
		"%s region is selected for seed %d" % [String(biome_id), seed]
	)
	var ready: Dictionary = await VISUAL_QA_RUNTIME.wait_for_capture_ready(
		self,
		func() -> bool:
			return (
				biome_manager.get_current_region_id() == cell.id
				and (
					streamer.get_content_level(cell.id)
					== WorldRegionStreamer.ContentLevel.FULL
				)
			)
	)
	_expect(
		bool(ready.get("ready", false)),
		"%s region is capture-ready for seed %d: %s"
		% [String(biome_id), seed, VISUAL_QA_RUNTIME.describe_failure(ready)]
	)
	_assert_tile_layers_have_assets(seed)
	for focus in FOCUSES:
		await _capture_focus(seed, cell, focus)
	await _capture_route_closeup(seed, cell)
	_clear_review_enemies()

func _first_cell_for_biome() -> BiomeCell:
	if biome_manager == null:
		return null
	for cell in biome_manager.get_generated_biome_map():
		if cell.biome_id == biome_id and cell.generated_layout != null:
			return cell
	return null

func _assert_tile_layers_have_assets(seed: int) -> void:
	var checked := 0
	var missing_assets := 0
	var procedural_fallbacks := 0
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
	if focus == FOCUS_ROSTER:
		_spawn_biome_roster(focus_position)
	for resolution in REVIEW_RESOLUTIONS:
		await _capture_at(
			resolution,
			focus_position,
			"%s_seed_%d_%s_%s.png" % [
				_resolution_slug(resolution),
				seed,
				String(cell.id),
				String(focus)
			],
			focus == FOCUS_ROSTER
		)

func _capture_route_closeup(seed: int, cell: BiomeCell) -> void:
	if cell == null or cell.generated_layout == null:
		return
	_clear_review_enemies()
	var layout := cell.generated_layout
	if layout.road_rects.is_empty():
		_expect(false, "%s seed %d has a road rect for the close-up" % [String(biome_id), seed])
		return
	var rect := layout.road_rects[0] as Rect2i
	# Punto interno alla regione sul bordo nord della strada: inquadra il
	# contatto terreno -> strada lontano dai seam di regione.
	var edge_cell := Vector2i(
		clampi(
			rect.position.x + maxi(rect.size.x / 4, 2),
			4,
			layout.zone_size.x - 5
		),
		clampi(
			rect.position.y + rect.size.y / 2,
			4,
			layout.zone_size.y - 5
		)
	)
	var offset := streamer.get_region_offset(cell.id)
	var focus_position := offset + layout.logical_to_world(edge_cell)
	var player := player_manager.players.get(1) as PlayerController
	if player != null:
		_move_node(player, focus_position)
	await _capture_at(
		CLOSEUP_RESOLUTION,
		focus_position,
		"closeup_seed_%d_%s_route_edge.png" % [seed, String(cell.id)],
		false
	)

func _capture_at(
	resolution: Vector2i,
	focus_position: Vector2,
	file_name: String,
	require_roster: bool
) -> void:
	_apply_resolution(resolution)
	_snap_camera(focus_position)
	var capture_ready: Dictionary = await VISUAL_QA_RUNTIME.wait_for_capture_ready(
		self,
		func() -> bool:
			return (
				not require_roster
				or get_nodes_in_group("biome_art_pass_enemies").size() > 0
			)
	)
	_expect(
		bool(capture_ready.get("ready", false)),
		"%s capture state is ready with no missing chunks: %s"
		% [file_name, VISUAL_QA_RUNTIME.describe_failure(capture_ready)]
	)
	if not bool(capture_ready.get("ready", false)):
		return
	var image := root.get_texture().get_image()
	_expect(
		image != null and not image.is_empty(),
		"%s capture image is available" % file_name
	)
	if image == null or image.is_empty():
		return
	_expect(
		_image_has_world_detail(image),
		"%s capture has enough visible detail" % file_name
	)
	_expect(
		_image_has_world_coverage(image),
		"%s capture has enough rendered world coverage" % file_name
	)
	var output_absolute := ProjectSettings.globalize_path(output_dir)
	_expect(
		image.save_png(output_absolute.path_join(file_name)) == OK,
		"%s screenshot is saved" % file_name
	)

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
		FOCUS_CENTER, FOCUS_ROSTER:
			var actor_cell := _find_walkable_cell_near_center(layout, cell)
			if actor_cell != Vector2i(-1, -1):
				return offset + layout.logical_to_world(actor_cell)
		_:
			pass
	return offset + layout.logical_to_world(layout.player_spawn_cell)

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

func _spawn_biome_roster(origin: Vector2) -> void:
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
		enemy.add_to_group("biome_art_pass_enemies")
		enemy.set_physics_process(false)
		var visual := enemy.get_node_or_null("Visual") as ZombieVisual
		if visual != null:
			visual.modulate = Color.WHITE
			visual.set_state(&"chase")
			visual.set_facing(Vector2.DOWN)

func _clear_review_enemies() -> void:
	for enemy in get_nodes_in_group("biome_art_pass_enemies"):
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
		print("%s: PASS" % qa_label)
	else:
		exit_code = 1
		print("%s: FAIL (%d)" % [qa_label, failures.size()])
	await VISUAL_QA_RUNTIME.cleanup_scene(self)
	quit(exit_code)
