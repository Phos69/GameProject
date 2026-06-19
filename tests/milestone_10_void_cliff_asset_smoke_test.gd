extends SceneTree

const FALL_ZONE_SCRIPT = preload("res://game/modes/zombie/biome_fall_zone.gd")
const REQUIRED_VOID_ASSET_IDS: Array[StringName] = [
	&"fall_zone",
	&"void_edge_near",
	&"cliff_lip_north",
	&"cliff_lip_south",
	&"cliff_lip_east",
	&"cliff_lip_west",
	&"void_depth",
	&"void_vertical_lines"
]
const REQUIRED_RUNTIME_ASSET_IDS: Array[StringName] = [
	&"fall_zone",
	&"void_edge_near",
	&"void_depth",
	&"void_vertical_lines"
]
const REQUIRED_TRANSITION_ASSET_IDS: Array[StringName] = [
	&"void_edge_north",
	&"void_edge_south",
	&"void_edge_east",
	&"void_edge_west",
	&"void_corner_inner_north_east",
	&"void_corner_inner_south_east",
	&"void_corner_inner_south_west",
	&"void_corner_inner_north_west",
	&"void_corner_outer_north_east",
	&"void_corner_outer_south_east",
	&"void_corner_outer_south_west",
	&"void_corner_outer_north_west",
	&"void_diagonal_north_east_south_west",
	&"void_diagonal_north_west_south_east"
]
const SIDES: Array[StringName] = [&"north", &"south", &"east", &"west"]

var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var manifest := IsometricEnvironmentManifest.reload_shared()
	_expect(manifest.load_error.is_empty(), "manifest loads")
	var report := manifest.validate()
	_expect(bool(report.get("is_valid", false)), "manifest validates")
	if not bool(report.get("is_valid", false)):
		for failure in report.get("failures", PackedStringArray()):
			push_error("manifest failure: " + String(failure))

	_run_manifest_coverage(manifest)
	_run_transition_resolver_coverage()
	_run_cliff_corner_join_coverage()
	await _run_fall_zone_instance_coverage(manifest)
	await _run_tile_layer_visual_authority()
	await _run_layout_side_metadata()
	await _run_hazard_system_runtime()
	_finish()

func _run_manifest_coverage(manifest: IsometricEnvironmentManifest) -> void:
	for asset_id in REQUIRED_VOID_ASSET_IDS:
		_expect(
			manifest.has_asset_contract(&"void_tiles", asset_id),
			"%s has void_tiles contract" % String(asset_id)
		)
		var contract := manifest.get_void_asset_contract(asset_id)
		var asset_path := String(contract.get("asset_path", ""))
		_expect(not asset_path.is_empty(), "%s declares asset path" % String(asset_id))
		_expect(_asset_exists(asset_path), "%s asset file exists" % String(asset_id))
		_expect(
			String(contract.get("fallback_path", ""))
			== "res://game/modes/zombie/biome_fall_zone.gd",
			"%s fallback path is explicit" % String(asset_id)
		)

	for biome_id in [
		&"infected_plains",
		&"toxic_wastes",
		&"burning_fields",
		&"frozen_outskirts",
		&"drowned_marsh"
	]:
		var set_contract := manifest.get_biome_asset_set_contract(biome_id)
		var void_tiles := _string_name_array(set_contract.get("void_tiles", []))
		for asset_id in REQUIRED_VOID_ASSET_IDS:
			_expect(
				void_tiles.has(asset_id),
				"%s biome asset set includes %s"
				% [String(biome_id), String(asset_id)]
			)

	for asset_id in REQUIRED_TRANSITION_ASSET_IDS:
		var contract := manifest.get_void_asset_contract(asset_id)
		var asset_path := String(contract.get("asset_path", ""))
		_expect(not contract.is_empty(), "%s has a transition contract" % String(asset_id))
		_expect(_asset_exists(asset_path), "%s transition texture exists" % String(asset_id))
		_expect(
			String(contract.get("fallback_path", ""))
			== "res://game/modes/zombie/biome_tile_layer.gd",
			"%s falls back to the chunked cliff renderer" % String(asset_id)
		)

func _run_transition_resolver_coverage() -> void:
	var resolver := IsometricTileResolver.new()
	_expect_transition(resolver, [Vector2i.UP], IsometricTileResolver.TILE_VOID_EDGE_NORTH)
	_expect_transition(resolver, [Vector2i.DOWN], IsometricTileResolver.TILE_VOID_EDGE_SOUTH)
	_expect_transition(resolver, [Vector2i.RIGHT], IsometricTileResolver.TILE_VOID_EDGE_EAST)
	_expect_transition(resolver, [Vector2i.LEFT], IsometricTileResolver.TILE_VOID_EDGE_WEST)
	_expect_transition(resolver, [Vector2i.UP, Vector2i.RIGHT], IsometricTileResolver.TILE_VOID_CORNER_INNER_NORTH_EAST)
	_expect_transition(resolver, [Vector2i.DOWN, Vector2i.RIGHT], IsometricTileResolver.TILE_VOID_CORNER_INNER_SOUTH_EAST)
	_expect_transition(resolver, [Vector2i.DOWN, Vector2i.LEFT], IsometricTileResolver.TILE_VOID_CORNER_INNER_SOUTH_WEST)
	_expect_transition(resolver, [Vector2i.UP, Vector2i.LEFT], IsometricTileResolver.TILE_VOID_CORNER_INNER_NORTH_WEST)
	_expect_transition(resolver, [Vector2i(1, -1)], IsometricTileResolver.TILE_VOID_CORNER_OUTER_NORTH_EAST)
	_expect_transition(resolver, [Vector2i(1, 1)], IsometricTileResolver.TILE_VOID_CORNER_OUTER_SOUTH_EAST)
	_expect_transition(resolver, [Vector2i(-1, 1)], IsometricTileResolver.TILE_VOID_CORNER_OUTER_SOUTH_WEST)
	_expect_transition(resolver, [Vector2i(-1, -1)], IsometricTileResolver.TILE_VOID_CORNER_OUTER_NORTH_WEST)
	_expect_transition(resolver, [Vector2i.UP, Vector2i.DOWN], IsometricTileResolver.TILE_VOID_DIAGONAL_NORTH_EAST_SOUTH_WEST)
	_expect_transition(resolver, [Vector2i.LEFT, Vector2i.RIGHT], IsometricTileResolver.TILE_VOID_DIAGONAL_NORTH_WEST_SOUTH_EAST)
	_expect_external_border_resolves_cliff(resolver)

func _run_cliff_corner_join_coverage() -> void:
	var builder := IsometricCliffMeshBuilder.new()
	var depth := 32.0
	var south_east_faces := builder._cliff_faces(
		IsometricTileResolver.TILE_VOID_CORNER_INNER_SOUTH_EAST,
		Vector2.ZERO,
		18.0,
		10.0,
		depth
	)
	_expect(south_east_faces.size() == 2, "south-east cliff corner has two joined faces")
	if south_east_faces.size() == 2:
		var east_path: PackedVector2Array = south_east_faces[1].get("path", PackedVector2Array())
		var east_drops: PackedVector2Array = south_east_faces[1].get("drops", PackedVector2Array())
		_expect(
			east_path.size() == 2,
			"south-east lateral face omits the segment owned by the south face"
		)
		_expect(
			east_drops.size() == 2
			and east_drops[0].x < 0.0
			and east_drops[1] == Vector2(0.0, IsometricCliffMeshBuilder.SOUTH_INSTANT_DEPTH),
			"south-east lateral face tapers into the shallow south drop"
		)

	var north_west_faces := builder._cliff_faces(
		IsometricTileResolver.TILE_VOID_CORNER_INNER_NORTH_WEST,
		Vector2.ZERO,
		18.0,
		10.0,
		depth
	)
	_expect(north_west_faces.size() == 2, "north-west cliff corner has two joined faces")
	if north_west_faces.size() == 2:
		var west_path: PackedVector2Array = north_west_faces[1].get("path", PackedVector2Array())
		var west_drops: PackedVector2Array = north_west_faces[1].get("drops", PackedVector2Array())
		_expect(
			west_path.size() == 2,
			"north-west lateral face omits the segment owned by the north face"
		)
		_expect(
			west_drops.size() == 2 and west_drops[0] == Vector2(0.0, depth),
			"north-west lateral face starts at the north face depth"
		)

	var upstream_faces := builder._cliff_faces(
		IsometricTileResolver.TILE_VOID_EDGE_WEST,
		Vector2(0.0, -12.0),
		18.0,
		10.0,
		depth,
		IsometricCliffMeshBuilder.SOUTH_INSTANT_DEPTH
	)
	var upstream_path: PackedVector2Array = upstream_faces[0].get(
		"path",
		PackedVector2Array()
	)
	var upstream_drops: PackedVector2Array = upstream_faces[0].get(
		"drops",
		PackedVector2Array()
	)
	var stays_above_join := upstream_path.size() == upstream_drops.size()
	for index in range(upstream_path.size()):
		stays_above_join = (
			stays_above_join
			and upstream_path[index].y + upstream_drops[index].y
			<= IsometricCliffMeshBuilder.SOUTH_INSTANT_DEPTH
		)
	_expect(
		stays_above_join,
		"lateral faces before a south corner do not extend below the join"
	)

	var palette := load(
		"res://game/modes/zombie/biomes/infected_plains_palette.tres"
	) as BiomePalette
	builder.configure(palette, 44017)
	builder.append_transition(
		IsometricTileResolver.TILE_VOID_EDGE_WEST,
		Vector2.ZERO,
		18.0,
		10.0
	)
	var expected_void_color := Color(palette.background_color.darkened(0.68), 1.0)
	var face_reaches_void_color := false
	for color in builder._face_colors:
		if color.is_equal_approx(expected_void_color):
			face_reaches_void_color = true
			break
	_expect(
		face_reaches_void_color,
		"cliff face gradient reaches the exact pure-void colour"
	)

func _expect_external_border_resolves_cliff(resolver: IsometricTileResolver) -> void:
	var layout := BiomeEnvironmentLayout.new()
	layout.zone_size = Vector2i(7, 7)
	layout.generation_seed = 8130
	var biome_cell := BiomeCell.new()
	biome_cell.configure(&"synthetic", &"toxic_wastes", Vector2i.ZERO, layout.zone_size, 8130)
	biome_cell.set_border(&"north", BiomeCell.BorderType.BLOCKED)
	var fall_cell := Vector2i(3, 1)
	layout.add_fall_zone_rect(Rect2i(fall_cell, Vector2i.ONE), &"internal")
	layout.rebuild_terrain_classification(biome_cell)
	_expect(
		resolver.resolve_tile_id(
			layout,
			fall_cell,
			&"toxic_wastes",
			&"balanced",
			biome_cell
		) == IsometricTileResolver.TILE_VOID_EDGE_NORTH,
		"fall zone beside an external border resolves an oriented cliff"
	)

func _expect_transition(
	resolver: IsometricTileResolver,
	ground_offsets: Array[Vector2i],
	expected_tile_id: StringName
) -> void:
	var layout := BiomeEnvironmentLayout.new()
	layout.zone_size = Vector2i(7, 7)
	layout.generation_seed = 8128
	var center := Vector2i(3, 3)
	layout.add_fall_zone_rect(Rect2i(center, Vector2i.ONE), &"north")
	for offset in ground_offsets:
		layout.add_floor_rect(Rect2i(center + offset, Vector2i.ONE), &"floor_base")
	layout.rebuild_terrain_classification()
	var actual_tile_id := resolver.resolve_tile_id(
		layout,
		center,
		&"toxic_wastes",
		&"balanced"
	)
	_expect(
		actual_tile_id == expected_tile_id,
		"%s neighbor mask resolves to %s"
		% [str(ground_offsets), String(expected_tile_id)]
	)

func _run_fall_zone_instance_coverage(
	manifest: IsometricEnvironmentManifest
) -> void:
	for side in SIDES:
		var zone := FALL_ZONE_SCRIPT.new() as BiomeFallZone
		root.add_child(zone)
		var size := Vector2(420.0, 48.0)
		if side == &"east" or side == &"west":
			size = Vector2(48.0, 420.0)
		zone.configure(
			&"fall_zone",
			size,
			0.0,
			Color(0.82, 0.58, 0.16, 0.92),
			&"cliff",
			side,
			9901
		)
		await process_frame
		_expect(zone.get_fall_side() == side, "%s fall zone stores side" % String(side))
		# All fall zones now render the clean procedural void (no stretched SVG
		# placeholder), at the perimeter and inside the chunk alike.
		_expect(
			zone.uses_procedural_fallback(),
			"%s fall zone renders the clean procedural void" % String(side)
		)
		_expect(
			not zone.has_asset_renderer(),
			"%s fall zone drops the grainy SVG cliff sprites" % String(side)
		)
		_expect(
			zone.get_cliff_lip_asset_id() == StringName("cliff_lip_%s" % String(side)),
			"%s fall zone selects oriented cliff lip" % String(side)
		)
		# The void asset contracts must still be fully declared in the manifest
		# even though the runtime paints them procedurally.
		for asset_id in REQUIRED_RUNTIME_ASSET_IDS:
			_expect(
				zone.get_void_asset_ids().has(asset_id),
				"%s void contract still lists %s" % [String(side), String(asset_id)]
			)
			_expect(
				not String(
					manifest.get_void_asset_contract(asset_id).get("asset_path", "")
				).is_empty(),
				"%s %s keeps a manifest asset contract" % [String(side), String(asset_id)]
			)
		_expect(
			zone.get_void_asset_ids().has(zone.get_cliff_lip_asset_id()),
			"%s renderer requires side lip asset" % String(side)
		)
		_expect(
			zone.get_vertical_line_count() >= 5
			and zone.get_vertical_line_count() <= 8,
			"%s vertical line density is deterministic and bounded"
			% String(side)
		)
		_expect(
			zone.contains_global_position(zone.global_position),
			"%s fall zone center remains inside collision area" % String(side)
		)
		_expect(
			zone.distance_to_zone(
				zone.global_position + Vector2(size.x + 24.0, size.y + 24.0)
			) > 0.0,
			"%s fall zone distance query remains functional" % String(side)
		)
		var collision_shape := zone.get_node_or_null("CollisionShape2D") as CollisionShape2D
		_expect(
			collision_shape != null
			and collision_shape.shape is RectangleShape2D
			and (collision_shape.shape as RectangleShape2D).size == zone.zone_size,
			"%s fall zone keeps rectangle collision contract" % String(side)
		)
		_expect(
			zone.is_in_group("fall_zones")
			and zone.is_in_group("environment_hazards"),
			"%s fall zone keeps hazard groups" % String(side)
		)
		zone.set_debug_visual_visible(true)
		await process_frame
		_expect(
			zone.uses_procedural_fallback(),
			"%s debug overlay keeps the procedural void" % String(side)
		)
		zone.queue_free()
		await process_frame

func _run_tile_layer_visual_authority() -> void:
	var layer_marker := Node2D.new()
	layer_marker.add_to_group("biome_tile_layers")
	root.add_child(layer_marker)
	var zone := FALL_ZONE_SCRIPT.new() as BiomeFallZone
	root.add_child(zone)
	zone.configure(
		&"fall_zone",
		Vector2(180.0, 180.0),
		0.0,
		Color(0.82, 0.58, 0.16, 0.92),
		&"cliff",
		&"internal",
		9902
	)
	await process_frame
	_expect(
		zone.is_world_edge_visual_suppressed(),
		"tile layer suppresses the duplicate rectangular fall-zone border"
	)
	zone.queue_free()
	layer_marker.queue_free()
	await process_frame

func _run_layout_side_metadata() -> void:
	var biome_manager := BiomeManager.new()
	root.add_child(biome_manager)
	await process_frame
	biome_manager.start_run({
		"world_seed": 106106,
		"biome_map_width": 3,
		"biome_map_height": 3,
		"extra_edge_chance": 0.35
	})
	var cells := biome_manager.get_generated_biome_map()
	var cells_by_grid := {}
	for cell in cells:
		cells_by_grid[cell.grid] = cell
	for cell in cells:
		for side in BiomeCell.SIDES:
			var adjacent_exists := cells_by_grid.has(
				cell.grid + BorderGenerator.get_side_offset(side)
			)
			if adjacent_exists:
				continue
			_expect(
				cell.get_border(side) == BiomeCell.BorderType.FALL,
				"%s %s missing neighbor is fall border"
				% [String(cell.id), String(side)]
			)
			_expect(
				_layout_has_fall_side(cell.generated_layout, side),
				"%s %s layout stores matching fall side"
				% [String(cell.id), String(side)]
			)
	biome_manager.queue_free()
	await process_frame

func _run_hazard_system_runtime() -> void:
	var container := Node2D.new()
	container.name = "EnvironmentProps"
	root.add_child(container)
	var biome_manager := BiomeManager.new()
	root.add_child(biome_manager)
	await process_frame
	biome_manager.start_run({
		"world_seed": 106206,
		"biome_map_width": 3,
		"biome_map_height": 3,
		"extra_edge_chance": 0.35
	})
	var target_cell := _first_cell_with_fall_zone(
		biome_manager.get_generated_biome_map()
	)
	_expect(target_cell != null, "generated map has at least one fall-zone region")
	if target_cell == null:
		biome_manager.queue_free()
		container.queue_free()
		await process_frame
		return
	_expect(
		biome_manager.set_current_region(target_cell.id),
		"biome manager selects fall-zone region"
	)
	var biome := biome_manager.get_current_biome() as BiomeDefinition
	_expect(biome != null, "selected biome definition is available")
	if biome == null:
		biome_manager.queue_free()
		container.queue_free()
		await process_frame
		return

	var hazard_system := HazardSystem.new()
	hazard_system.environment_container_path = NodePath("../EnvironmentProps")
	root.add_child(hazard_system)
	await process_frame
	hazard_system.start_run(biome)
	await process_frame
	var fall_zone_count := 0
	for hazard in hazard_system.get_active_hazards():
		var fall_zone := hazard as BiomeFallZone
		if fall_zone == null:
			continue
		fall_zone_count += 1
		# Every fall zone now paints the clean procedural void (no stretched SVG
		# placeholder), perimeter strips and internal pits alike.
		_expect(
			fall_zone.uses_procedural_fallback(),
			"runtime fall zone uses the clean procedural void"
		)
		var is_large_void := minf(
			fall_zone.zone_size.x,
			fall_zone.zone_size.y
		) >= 110.0
		if is_large_void:
			# Internal pits are side-agnostic; only require a valid orientation.
			_expect(
				SIDES.has(fall_zone.get_fall_side()),
				"runtime internal void pit keeps a valid side-agnostic orientation"
			)
		else:
			var expected_side := _expected_side_for_position(
				biome.environment_layout,
				fall_zone.global_position
			)
			_expect(
				fall_zone.get_fall_side() == expected_side,
				"runtime perimeter fall zone side comes from layout metadata"
			)
		_expect(
			fall_zone.get_void_asset_ids().has(
				fall_zone.get_cliff_lip_asset_id()
			),
			"runtime fall zone has oriented cliff lip asset"
		)
		_expect(
			hazard_system.is_position_fall_zone(fall_zone.global_position),
			"runtime fall-zone query still detects fall zone"
		)
		_expect(
			not hazard_system.is_position_environment_hazard(
				fall_zone.global_position
			),
			"runtime fall zone is not generic environment hazard"
		)
	_expect(fall_zone_count > 0, "hazard system spawns fall zones")

	hazard_system.queue_free()
	biome_manager.queue_free()
	container.queue_free()
	await process_frame

func _layout_has_fall_side(
	layout: BiomeEnvironmentLayout,
	side: StringName
) -> bool:
	if layout == null:
		return false
	for index in range(layout.hazard_ids.size()):
		if layout.hazard_ids[index] != &"fall_zone":
			continue
		if index >= layout.hazard_sides.size():
			continue
		if layout.hazard_sides[index] != side:
			continue
		if index < layout.hazard_rects.size() and _rect_matches_side(
			layout.hazard_rects[index],
			layout,
			side
		):
			return true
	return false

func _rect_matches_side(
	rect: Rect2i,
	layout: BiomeEnvironmentLayout,
	side: StringName
) -> bool:
	match side:
		&"north":
			return rect.position.y <= 0 and rect.size.y <= 8
		&"south":
			return (
				rect.position.y + rect.size.y >= layout.zone_size.y
				and rect.size.y <= 8
			)
		&"west":
			return rect.position.x <= 0 and rect.size.x <= 8
		_:
			return (
				rect.position.x + rect.size.x >= layout.zone_size.x
				and rect.size.x <= 8
			)

func _first_cell_with_fall_zone(cells: Array[BiomeCell]) -> BiomeCell:
	for cell in cells:
		if cell.generated_layout != null and not cell.generated_layout.fall_zone_rects.is_empty():
			return cell
	return null

func _expected_side_for_position(
	layout: BiomeEnvironmentLayout,
	position: Vector2
) -> StringName:
	if layout == null:
		return &""
	for index in range(layout.hazard_ids.size()):
		if layout.hazard_ids[index] != &"fall_zone":
			continue
		if index >= layout.hazard_positions.size() or index >= layout.hazard_sides.size():
			continue
		if layout.hazard_positions[index].distance_to(position) <= 1.0:
			return layout.hazard_sides[index]
	return &""

func _string_name_array(value: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if value is Array:
		for item in value as Array:
			result.append(StringName(str(item)))
	return result

func _asset_exists(asset_path: String) -> bool:
	if asset_path.is_empty():
		return false
	if ResourceLoader.exists(asset_path):
		return true
	return FileAccess.file_exists(asset_path)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("MILESTONE_10_VOID_CLIFF_ASSET_SMOKE_TEST: PASS")
		quit(0)
		return
	print("MILESTONE_10_VOID_CLIFF_ASSET_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
