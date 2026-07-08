extends SceneTree

const OUTPUT_DIR := "res://build/qa/biome_art_fix/infected_plains"
const OUTPUT_FILE := "infected_plains_route_edges.png"
const LAYER_ORIGIN := Vector2(640.0, 420.0)

var failures := PackedStringArray()

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var output_absolute := ProjectSettings.globalize_path(OUTPUT_DIR)
	_expect(
		DirAccess.make_dir_recursive_absolute(output_absolute) == OK,
		"infected_plains QA output directory is available"
	)
	var biome := load(
		"res://game/modes/zombie/biomes/infected_plains.tres"
	) as BiomeDefinition
	_expect(biome != null and biome.palette != null, "infected_plains palette loads")
	if biome == null or biome.palette == null:
		_finish()
		return

	var scene_root := Node2D.new()
	scene_root.name = "BiomeArtInfectedPlainsVisualQa"
	scene_root.y_sort_enabled = true
	root.add_child(scene_root)
	current_scene = scene_root
	_add_background(scene_root)
	_add_labels(scene_root)

	var layout := _make_layout()
	var layer := BiomeTileLayer.new()
	layer.position = LAYER_ORIGIN
	scene_root.add_child(layer)
	layer.configure(
		layout,
		biome.palette,
		&"infected_plains",
		&"quality",
		14
	)
	await process_frame
	await process_frame
	_expect(layer.has_forest_surface_art_textures(), "forest surface textures load")
	_expect(layer.get_missing_asset_count() == 0, "forest tile layer has no missing assets")
	_expect(_route_surfaces_are_crisp(layer), "road transition cells render with defined road-border surfaces")

	await _add_tree_cluster(scene_root, layout, biome.palette)
	for _frame in range(4):
		await process_frame
	var image := root.get_texture().get_image()
	_expect(image != null and not image.is_empty(), "infected_plains route QA capture is available")
	if image != null and not image.is_empty():
		_expect(
			image.save_png(output_absolute.path_join(OUTPUT_FILE)) == OK,
			"infected_plains route QA screenshot is saved"
		)
	_finish()

func _make_layout() -> BiomeEnvironmentLayout:
	var layout := BiomeEnvironmentLayout.new()
	layout.zone_size = Vector2i(80, 48)
	layout.logical_tile_scale = 10.0
	layout.generation_seed = 641004
	layout.add_floor_rect(Rect2i(Vector2i.ZERO, layout.zone_size), &"forest_grass")
	layout.add_floor_rect(Rect2i(Vector2i(5, 5), Vector2i(20, 13)), &"forest_tall_grass")
	layout.add_floor_rect(Rect2i(Vector2i(55, 6), Vector2i(18, 14)), &"forest_tall_grass")
	layout.road_rects.append(Rect2i(Vector2i(6, 20), Vector2i(68, 8)))
	layout.road_rect_tags.append(&"main_road")
	layout.road_rects.append(Rect2i(Vector2i(37, 5), Vector2i(7, 38)))
	layout.road_rect_tags.append(&"broken_street")
	layout.fall_zone_rects.append(Rect2i(Vector2i(9, 34), Vector2i(12, 8)))
	layout.rebuild_terrain_classification()
	return layout

func _route_surfaces_are_crisp(layer: BiomeTileLayer) -> bool:
	var rendered_ids := layer.get_rendered_surface_material_ids()
	return (
		rendered_ids.has(&"forest_path")
		and rendered_ids.has(&"forest_road")
		and rendered_ids.has(&"forest_road_border")
		and not rendered_ids.has(&"grass_to_path")
		and not rendered_ids.has(&"grass_to_road")
		and not rendered_ids.has(&"path_to_road")
	)

func _add_tree_cluster(
	scene_root: Node2D,
	layout: BiomeEnvironmentLayout,
	palette: BiomePalette
) -> void:
	var system := ObstacleSystem.new()
	system.name = "QaObstacleSystem"
	scene_root.add_child(system)
	await process_frame
	var manifest := IsometricEnvironmentManifest.get_shared()
	var footprint := manifest.get_footprint_tiles(&"forest_tree")
	var tree_size := Vector2(
		float(footprint.x),
		float(footprint.y)
	) * layout.logical_tile_scale
	var tree_cells: Array[Vector2i] = [
		Vector2i(12, 10),
		Vector2i(18, 9),
		Vector2i(24, 11),
		Vector2i(62, 12)
	]
	for index in range(tree_cells.size()):
		var tree := system.create_obstacle_instance(
			&"forest_tree",
			tree_size,
			&"rectangle",
			0.0,
			palette.prop_color,
			palette.hazard_color
		)
		_expect(tree != null, "forest_tree QA instance %d is created" % index)
		if tree == null:
			continue
		tree.name = "ForestTreeQa%d" % index
		scene_root.add_child(tree)
		tree.global_position = LAYER_ORIGIN + layout.logical_to_world(tree_cells[index])
		if tree.has_method("has_asset_visual"):
			_expect(bool(tree.call("has_asset_visual")), "forest_tree QA instance %d uses asset visual" % index)

func _add_background(scene_root: Node2D) -> void:
	var background := ColorRect.new()
	background.color = Color("0d1410")
	background.size = Vector2(1280.0, 720.0)
	background.z_index = -40
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scene_root.add_child(background)

func _add_labels(scene_root: Node2D) -> void:
	var title := _make_label(
		"ART-VIS-FIX / INFECTED PLAINS",
		Vector2(0.0, 18.0),
		Vector2(1280.0, 36.0),
		24,
		Color("f1dda6")
	)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scene_root.add_child(title)
	var subtitle := _make_label(
		"Road contacts use a defined border material; no generic blended transition texture is rendered.",
		Vector2(0.0, 55.0),
		Vector2(1280.0, 26.0),
		15,
		Color("a9bea0")
	)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scene_root.add_child(subtitle)

func _make_label(
	text_value: String,
	position_value: Vector2,
	size_value: Vector2,
	font_size: int,
	color: Color
) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = position_value
	label.size = size_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.z_index = 20
	return label

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("BIOME_ART_INFECTED_PLAINS_VISUAL_QA: PASS")
		quit(0)
		return
	print("BIOME_ART_INFECTED_PLAINS_VISUAL_QA: FAIL (%d)" % failures.size())
	quit(1)
