extends SceneTree

# Milestone 8 - Megamappa persistente (renderer multi-regione, prototipo).
# Copre: offset di rendering derivati da WorldRegion.world_origin, regione
# corrente + vicini istanziati mentre le regioni lontane restano dati, livelli
# di contenuto (FULL corrente, VISUAL vicini, NONE lontane), nessuna cassa/
# hazard duplicata sui vicini e cleanup completo.

var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var graph := _build_graph()
	var container := Node2D.new()
	container.name = "EnvironmentProps"
	root.add_child(container)

	var renderer := MultiRegionRenderer.new()
	root.add_child(renderer)

	var ok := renderer.render_world(
		graph,
		&"c",
		container,
		func(region_id: StringName) -> BiomeEnvironmentLayout: return _make_layout(),
		func(_biome_id: StringName) -> BiomePalette: return BiomePalette.new(),
		12
	)
	_expect(ok, "render_world succeeds for a valid center region")

	# Active set: current + connected neighbors, distant region excluded.
	var rendered := renderer.get_rendered_region_ids()
	_expect(rendered.size() == 3, "current region and its two neighbors are rendered")
	_expect(renderer.is_region_rendered(&"c"), "current region is rendered")
	_expect(renderer.is_region_rendered(&"e"), "east neighbor is rendered")
	_expect(renderer.is_region_rendered(&"n"), "north neighbor is rendered")
	_expect(not renderer.is_region_rendered(&"d"), "distant region stays unrendered data")

	# Offsets come from world_origin difference * tile scale (8 here).
	_expect(renderer.get_region_offset(&"c") == Vector2.ZERO, "current region sits at the local origin")
	_expect(renderer.get_region_offset(&"e") == Vector2(1600.0, 0.0), "east neighbor offset matches one region span")
	_expect(renderer.get_region_offset(&"n") == Vector2(0.0, -1600.0), "north neighbor offset matches one region span")

	# Content levels: current FULL, neighbors VISUAL, distant NONE.
	_expect(renderer.get_content_level(&"c") == MultiRegionRenderer.ContentLevel.FULL, "current region is FULL content")
	_expect(renderer.get_content_level(&"e") == MultiRegionRenderer.ContentLevel.VISUAL, "east neighbor is VISUAL only")
	_expect(renderer.get_content_level(&"n") == MultiRegionRenderer.ContentLevel.VISUAL, "north neighbor is VISUAL only")
	_expect(renderer.get_content_level(&"d") == MultiRegionRenderer.ContentLevel.NONE, "distant region has NONE content")

	# Neighbor grounds are visual-only: real BiomeRegionGround nodes positioned
	# at their offset, with no duplicated crate/hazard/obstacle content.
	var ground_nodes := renderer.get_neighbor_ground_nodes()
	_expect(ground_nodes.size() == 2, "only the two neighbors get a visual ground node")
	var visual_only := true
	for node in ground_nodes:
		if not (node is BiomeRegionGround):
			visual_only = false
		if (
			node.is_in_group("environment_obstacles")
			or node.is_in_group("spawn_blockers")
			or node.is_in_group("resource_crate_system")
		):
			visual_only = false
	_expect(visual_only, "neighbor grounds carry no obstacle/crate/spawn gameplay content")
	_expect(
		_count_named_children(container, "NeighborGround_") == 2,
		"container holds exactly the two neighbor ground nodes"
	)

	# Re-rendering a different center clears the previous neighbor grounds.
	renderer.render_world(
		graph,
		&"e",
		container,
		func(region_id: StringName) -> BiomeEnvironmentLayout: return _make_layout(),
		func(_biome_id: StringName) -> BiomePalette: return BiomePalette.new(),
		12
	)
	await process_frame
	_expect(renderer.get_content_level(&"c") == MultiRegionRenderer.ContentLevel.VISUAL, "old center becomes a VISUAL neighbor after moving east")
	_expect(renderer.get_content_level(&"e") == MultiRegionRenderer.ContentLevel.FULL, "new center is FULL after moving east")

	renderer.clear()
	await process_frame
	_expect(renderer.get_rendered_region_ids().is_empty(), "clear removes all rendered regions")
	_expect(
		_count_named_children(container, "NeighborGround_") == 0,
		"clear frees the neighbor ground nodes"
	)

	renderer.queue_free()
	container.queue_free()
	await process_frame
	_finish()

func _build_graph() -> WorldGraph:
	var save := {
		"seed": 808,
		"region_size": [200, 200],
		"start_region_id": "c",
		"regions": [
			_region_data("c", Vector2i(2, 2), Vector2i(400, 400)),
			_region_data("e", Vector2i(3, 2), Vector2i(600, 400)),
			_region_data("n", Vector2i(2, 1), Vector2i(400, 200)),
			_region_data("d", Vector2i(0, 0), Vector2i(0, 0))
		],
		"connections": [
			_connection_data("c", "e", "east", "west"),
			_connection_data("e", "c", "west", "east"),
			_connection_data("c", "n", "north", "south"),
			_connection_data("n", "c", "south", "north")
		]
	}
	return WorldGraph.from_save_data(save)

func _region_data(id: String, grid: Vector2i, origin: Vector2i) -> Dictionary:
	return {
		"region_id": id,
		"biome_id": "infected_plains",
		"grid_position": [grid.x, grid.y],
		"world_origin": [origin.x, origin.y],
		"size_tiles": [200, 200],
		"seed": 1,
		"neighbors": {},
		"border_types": {},
		"exploration_state": "discovered",
		"visited": false,
		"cleared": false
	}

func _connection_data(from_id: String, to_id: String, side: String, opposite: String) -> Dictionary:
	return {
		"connection_id": "%s_%s_%s" % [from_id, side, to_id],
		"from_region_id": from_id,
		"to_region_id": to_id,
		"from_biome_id": "infected_plains",
		"to_biome_id": "infected_plains",
		"side": side,
		"opposite_side": opposite,
		"passage_position": 100,
		"passage_width": 40,
		"passage_type": "road",
		"seed": 1,
		"is_open": true,
		"physical_passage": true
	}

func _make_layout() -> BiomeEnvironmentLayout:
	var layout := BiomeEnvironmentLayout.new()
	layout.zone_size = Vector2i(200, 200)
	layout.logical_tile_scale = 8.0
	return layout

func _count_named_children(container: Node, prefix: String) -> int:
	var count := 0
	for child in container.get_children():
		if (
			String(child.name).begins_with(prefix)
			and not child.is_queued_for_deletion()
		):
			count += 1
	return count

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("MILESTONE_8_MULTI_REGION_SMOKE_TEST: PASS")
		quit(0)
		return
	print("MILESTONE_8_MULTI_REGION_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
