extends SceneTree

const OUTPUT_DIR := "res://build/qa/scalable_rocks"
const OUTPUT_FILE := "rectilinear_rock_areas.png"

var failures := PackedStringArray()

class OcclusionProbe extends Node2D:
	var probe_color := Color("e84d3d")

	func _draw() -> void:
		draw_circle(Vector2(0.0, -32.0), 10.0, probe_color)
		draw_rect(Rect2(-8.0, -24.0, 16.0, 25.0), probe_color, true)
		draw_line(Vector2(-7.0, -18.0), Vector2(-14.0, -4.0), probe_color, 4.0, true)
		draw_line(Vector2(7.0, -18.0), Vector2(14.0, -4.0), probe_color, 4.0, true)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var output_absolute := ProjectSettings.globalize_path(OUTPUT_DIR)
	_expect(
		DirAccess.make_dir_recursive_absolute(output_absolute) == OK,
		"rock-area QA output directory is available"
	)
	var biome := load(
		"res://game/modes/zombie/biomes/plains.tres"
	) as BiomeDefinition
	_expect(biome != null and biome.palette != null, "infected plains palette loads")
	if biome == null or biome.palette == null:
		_finish()
		return
	var scene_root := Node2D.new()
	scene_root.name = "RockAreaVisualQa"
	scene_root.y_sort_enabled = true
	root.add_child(scene_root)
	current_scene = scene_root
	var background := ColorRect.new()
	background.color = Color("101816")
	background.size = Vector2(1280.0, 720.0)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.z_index = -20
	scene_root.add_child(background)
	var layout := _make_layout()
	var layer := BiomeTileLayer.new()
	layer.position = Vector2(640.0, 380.0)
	scene_root.add_child(layer)
	layer.configure(
		layout,
		biome.palette,
		&"plains",
		&"quality",
		16
	)
	await process_frame
	await process_frame
	_expect(layer.has_mesa_area_art(), "tile layer retains mesa geometry metadata")
	_expect(not layer.renders_mesa_area_batch(), "tile layer does not draw a mesa batch")
	var counts := layer.get_mesa_area_counts()
	_expect(int(counts.get("areas", 0)) == 2, "both rock areas are reported")
	_expect(
		int(counts.get("faces", 0)) == 34,
		"both plateau definitions report rounded visible wall segments"
	)
	_expect(
		int(counts.get("dirt_inset_corners", 0)) == 8,
		"both plateau dirt crowns fill their four rounded base cut-outs"
	)
	await _add_mesas_and_occlusion_probes(scene_root, layout, biome)
	_add_labels(scene_root)
	await process_frame
	var image := root.get_texture().get_image()
	_expect(image != null and not image.is_empty(), "rock-area capture is available")
	if image != null and not image.is_empty():
		_expect(
			image.save_png(output_absolute.path_join(OUTPUT_FILE)) == OK,
			"rock-area screenshot is saved"
		)
	_finish()

func _make_layout() -> BiomeEnvironmentLayout:
	var layout := BiomeEnvironmentLayout.new()
	layout.zone_size = Vector2i(80, 56)
	layout.logical_tile_scale = 8.0
	layout.generation_seed = 24681357
	layout.add_floor_rect(Rect2i(Vector2i.ZERO, layout.zone_size), &"forest_grass")
	var small := Rect2i(Vector2i(8, 20), Vector2i(15, 15))
	var large := Rect2i(Vector2i(43, 13), Vector2i(30, 30))
	layout.mesa_rects.append(small)
	layout.mesa_rects.append(large)
	layout.mesa_profile_ids.append(&"forest")
	layout.mesa_profile_ids.append(&"forest")
	for rect in layout.mesa_rects:
		layout.obstacle_rects.append(rect)
		layout.obstacle_ids.append(&"large_rock")
		layout.obstacle_positions.append(
			layout.obstacle_rect_center_to_world(rect, &"large_rock")
		)
		layout.obstacle_sizes.append(layout.rect_size_to_world(rect))
		layout.obstacle_rotations.append(0.0)
		layout.obstacle_shape_ids.append(&"rectangle")
	layout.rebuild_terrain_classification()
	return layout

func _add_mesas_and_occlusion_probes(
	scene_root: Node2D,
	layout: BiomeEnvironmentLayout,
	biome: BiomeDefinition
) -> void:
	var system := ObstacleSystem.new()
	scene_root.add_child(system)
	await process_frame
	for index in range(layout.mesa_rects.size()):
		var rect := layout.mesa_rects[index]
		var world_size := layout.obstacle_sizes[index]
		var rock := system.create_obstacle_instance(
			&"large_rock",
			world_size,
			&"rectangle",
			layout.obstacle_rotations[index],
			Color("514a3e"),
			Color("b5a178")
		) as EnvironmentObject
		_expect(rock != null, "occlusion rock %d is created" % index)
		if rock == null:
			continue
		var layout_center := Vector2(640.0, 380.0) + layout.obstacle_positions[index]
		var sort_anchor := ObstacleSystem.attach_obstacle_at_layout_center(
			scene_root,
			rock,
			layout_center
		)
		ObstacleSystem.configure_mesa_obstacle_visual(
			rock,
			layout,
			index,
			&"plains",
			biome.palette
		)
		_expect(sort_anchor != null, "rock %d owns a Y-sort wrapper" % index)
		_expect(
			sort_anchor != null and sort_anchor.has_meta(ObstacleSystem.SORT_ANCHOR_META),
			"rock %d participates in actor front/back sorting" % index
		)
		_expect(rock.rotation == 0.0, "rock %d remains screen-cardinal" % index)
		_expect(rock.has_mesa_visual(), "rock %d owns its raised local mesh" % index)
		var geometry := rock.get_mesa_geometry_counts()
		_expect(int(geometry.get("areas", 0)) == 1, "rock %d owns one crown" % index)
		_expect(
			int(geometry.get("faces", 0)) == 17,
			"rock %d owns rounded visible wall segments" % index
		)
		_expect(
			rock.global_position.is_equal_approx(layout_center),
			"rock %d visual remains on the layout center" % index
		)
		_expect(
			rock.get_collision_size().is_equal_approx(world_size),
			"rock %d collision matches the visual base size" % index
		)
		_expect(
			rock.get_collision_offset().is_zero_approx(),
			"rock %d collision and visual share one local origin" % index
		)
		var collision_node := rock.get_node_or_null("CollisionShape2D") as CollisionShape2D
		var rectangle := (
			collision_node.shape as RectangleShape2D
			if collision_node != null
			else null
		)
		_expect(
			rectangle != null and rectangle.size.is_equal_approx(world_size),
			"rock %d physical rectangle follows the mesh footprint" % index
		)
		var behind_position := rock.global_position + Vector2(0.0, -world_size.y * 0.5 - 10.0)
		var front_position := rock.global_position + Vector2(0.0, world_size.y * 0.5 + 28.0)
		_expect(rock.is_world_position_behind_cliff(behind_position), "north probe is behind rock %d" % index)
		_expect(rock.is_world_position_in_front_of_cliff(front_position), "south probe is in front of rock %d" % index)
		var behind_probe := OcclusionProbe.new()
		behind_probe.name = "BehindProbe%d" % index
		behind_probe.position = behind_position
		behind_probe.probe_color = Color("e05042")
		scene_root.add_child(behind_probe)
		var front_probe := OcclusionProbe.new()
		front_probe.name = "FrontProbe%d" % index
		front_probe.position = front_position
		front_probe.probe_color = Color("55c7ef")
		scene_root.add_child(front_probe)
	await process_frame

func _add_labels(scene_root: Node2D) -> void:
	var title := Label.new()
	title.text = "MESA CARDINALI - COLLISIONE E MESH LOCALI Y-SORTED"
	title.position = Vector2(0.0, 24.0)
	title.size = Vector2(1280.0, 42.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color("eadba9"))
	title.z_index = 10
	scene_root.add_child(title)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("ROCK_AREA_VISUAL_QA: PASS")
		quit(0)
		return
	print("ROCK_AREA_VISUAL_QA: FAIL (%d)" % failures.size())
	quit(1)
