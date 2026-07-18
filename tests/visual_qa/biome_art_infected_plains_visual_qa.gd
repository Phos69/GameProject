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
	_expect_route_surfaces_are_crisp(layer)

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
	layout.road_rects.append(Rect2i(Vector2i(66, 7), Vector2i(7, 28)))
	layout.road_rect_tags.append(&"main_road")
	layout.fall_zone_rects.append(Rect2i(Vector2i(9, 34), Vector2i(12, 8)))
	layout.rebuild_terrain_classification()
	return layout

func _expect_route_surfaces_are_crisp(layer: BiomeTileLayer) -> void:
	var rendered_ids := layer.get_rendered_surface_material_ids()
	var required_ids: Array[StringName] = [
		&"forest_grass",
		&"forest_path",
		&"forest_road",
		&"terrain_divider_dirt",
		&"terrain_void_color",
	]
	for required_id in required_ids:
		_expect(
			rendered_ids.has(required_id),
			"terrain mask renders %s" % String(required_id)
		)
	var boundary_report := layer.get_terrain_boundary_report()
	_expect(not boundary_report.is_empty(), "terrain boundary report is available")
	_expect(
		int(boundary_report.get("boundary_segment_count", 0)) > 0,
		"terrain boundary mask contains boundary segments"
	)
	_expect(
		int(boundary_report.get("divider_pixel_count", 0)) > 0,
		"terrain boundary mask contains divider pixels"
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
	var manifest := EnvironmentAssetManifest.get_shared()
	var footprint := manifest.get_footprint_tiles(&"forest_tree")
	var tree_size := Vector2(
		float(footprint.x),
		float(footprint.y)
	) * WorldGridConfig.LEGACY_TILE_SCALE
	var tree_cells: Array[Vector2i] = [
		Vector2i(12, 10),
		Vector2i(18, 9),
		Vector2i(24, 11),
		Vector2i(30, 9),
		Vector2i(42, 10),
		Vector2i(48, 9),
		Vector2i(54, 11),
		Vector2i(62, 9)
	]
	var selected_variants := {}
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
		ObstacleSystem.attach_obstacle_at_layout_center(
			scene_root,
			tree,
			LAYER_ORIGIN + layout.logical_to_world(tree_cells[index])
		)
		var selection_key := Vector2(float(index + 100) * 48.0, 240.0)
		_expect(
			ObstacleSystem.configure_random_obstacle_asset_variant(
				tree,
				&"infected_plains",
				selection_key
			),
			"forest_tree QA instance %d selects an imported variant" % index
		)
		if tree is EnvironmentObject:
			selected_variants[(tree as EnvironmentObject).get_asset_variant_id()] = true
		if tree.has_method("has_asset_visual"):
			_expect(bool(tree.call("has_asset_visual")), "forest_tree QA instance %d uses asset visual" % index)
	_expect(selected_variants.size() == 8, "forest_tree QA board covers all eight imported variants")

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
		"Grass, path, asphalt and void share one regional mask; compacted earth traces every terrain boundary.",
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
