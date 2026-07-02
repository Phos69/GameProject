extends GutTest
## Environment A2 — Confini di caduta (fall boundary) e schivata sui varchi.
##
## Migra e accorpa:
##   tests/fall_boundary_visual_logic_smoke_test.gd
##   tests/player_dodge_gap_smoke_test.gd
##
## (zombie_fall_hazard NON e qui: e un test di integrazione con boot di main.tscn,
## migra nella suite di integrazione environment.)

const WorldGen = preload("res://tests/support/world_gen_helpers.gd")
const IsoGridConfig = preload("res://game/core/iso_grid_config.gd")

const BORDER_IDS: Array[StringName] = [
	&"boundary_fence", &"toxic_boundary_wall", &"lava_boundary", &"ice_boundary", &"deep_water_boundary"
]

var _manager: BiomeManager
var _cells: Array[BiomeCell] = []

func before_all() -> void:
	_manager = WorldGen.start_biome_manager(self, {
		"world_seed": 616161, "biome_map_width": 3, "biome_map_height": 3, "extra_edge_chance": 0.35
	}, "FallBoundaryManager")
	await wait_physics_frames(1)
	_cells = _manager.get_generated_biome_map()

func after_all() -> void:
	WorldGen.free_biome_manager(_manager)
	_manager = null
	_cells = []

# --- confini di caduta (fall_boundary_visual_logic) -----------------------

func test_fall_boundaries() -> void:
	var cells_by_grid := {}
	for cell in _cells:
		cells_by_grid[cell.grid] = cell
	for cell in _cells:
		for side in BiomeCell.SIDES:
			var adjacent_exists := cells_by_grid.has(cell.grid + BorderGenerator.get_side_offset(side))
			var border_type := cell.get_border(side)
			var layout := cell.generated_layout
			if not adjacent_exists:
				assert_eq(border_type, BiomeCell.BorderType.FALL, "%s %s senza regione e fall boundary" % [String(cell.id), String(side)])
				assert_true(_has_fall_rect_for_side(layout, side), "%s %s ha rect fall visuale/collisione" % [String(cell.id), String(side)])
				assert_true(_has_fall_hazard_side_for_side(layout, side), "%s %s memorizza metadati fall hazard" % [String(cell.id), String(side)])
			elif border_type == BiomeCell.BorderType.CONNECTED:
				assert_false(_has_fall_rect_for_side(layout, side), "%s connected %s senza rect fall" % [String(cell.id), String(side)])
				assert_false(cell.get_passages_for_side(side).is_empty(), "%s connected %s ha passaggio fisico" % [String(cell.id), String(side)])
			else:
				assert_eq(border_type, BiomeCell.BorderType.BLOCKED, "%s adiacente non-edge %s e blocked" % [String(cell.id), String(side)])
				assert_false(_has_fall_rect_for_side(layout, side), "%s blocked %s non e fall" % [String(cell.id), String(side)])
				assert_true(_has_border_obstacle_for_side(layout, side, _expected_border_obstacle_id(cell.biome_id)),
					"%s blocked %s usa il visual di bordo del biome" % [String(cell.id), String(side)])
			assert_true(_only_expected_border_ids(layout, cell.biome_id), "%s i bordi generati usano id biome canonici" % String(cell.id))
	var graph := _manager.get_world_graph()
	assert_true(graph != null and bool(graph.validate_physical_passages().get("is_valid", false)),
		"la logica fall boundary mantiene coerenti i passaggi fisici")

func test_odd_sized_fall_zone_centers_map_to_perimeter_cells() -> void:
	var layout := BiomeEnvironmentLayout.new()
	layout.zone_size = IsoGridConfig.BIOME_SIZE
	layout.logical_tile_scale = IsoGridConfig.LOGICAL_TILE_SCALE
	var thickness := IsoGridConfig.FALL_BOUNDARY_THICKNESS_TILES
	layout.add_fall_zone_rect(
		Rect2i(Vector2i.ZERO, Vector2i(layout.zone_size.x, thickness)),
		&"north"
	)
	layout.add_fall_zone_rect(
		Rect2i(Vector2i.ZERO, Vector2i(thickness, layout.zone_size.y)),
		&"west"
	)
	layout.rebuild_terrain_classification()

	var north_cell := layout.world_to_logical(layout.hazard_positions[0])
	var west_cell := layout.world_to_logical(layout.hazard_positions[1])
	assert_eq(
		north_cell,
		Vector2i(layout.zone_size.x / 2, 0),
		"north fall strip center maps back to the first perimeter row"
	)
	assert_eq(
		west_cell,
		Vector2i(0, layout.zone_size.y / 2),
		"west fall strip center maps back to the first perimeter column"
	)
	assert_eq(
		layout.get_terrain_class_at_cell(north_cell),
		BiomeEnvironmentLayout.TERRAIN_FALL_ZONE,
		"north fall strip center remains a fall zone terrain cell"
	)
	assert_eq(
		layout.get_terrain_class_at_cell(west_cell),
		BiomeEnvironmentLayout.TERRAIN_FALL_ZONE,
		"west fall strip center remains a fall zone terrain cell"
	)

# --- schivata sui varchi (player_dodge_gap) -------------------------------

func test_dodge_gap_validation() -> void:
	var component := PlayerDodgeComponent.new()
	add_child(component)
	component.max_gap_cross_distance = 160.0
	var landing := [Rect2(Vector2(80.0, -24.0), Vector2(90.0, 48.0))]
	var gap := [Rect2(Vector2(38.0, -18.0), Vector2(34.0, 36.0))]

	var clear_report := component.validate_gap_trajectory(Vector2.ZERO, Vector2(120.0, 0.0), [], gap, landing)
	assert_true(bool(clear_report.get("is_valid", false)), "la schivata attraversa un varco piccolo valido")
	assert_true(bool(clear_report.get("crosses_gap", false)), "la traversata di un varco piccolo e rilevata")

	var wall_report := component.validate_gap_trajectory(Vector2.ZERO, Vector2(120.0, 0.0), [Rect2(Vector2(52.0, -20.0), Vector2(20.0, 40.0))], gap, landing)
	assert_false(bool(wall_report.get("is_valid", true)), "la schivata non attraversa i muri")
	assert_true(bool(wall_report.get("blocked", false)), "l'ostruzione del muro e riportata")

	var hazard_report := component.validate_gap_trajectory(Vector2.ZERO, Vector2(120.0, 0.0), [], [], landing, [Rect2(Vector2(48.0, -18.0), Vector2(36.0, 36.0))])
	assert_false(bool(hazard_report.get("is_valid", true)), "la schivata non attraversa gli hazard ambientali come varchi")
	assert_true(bool(hazard_report.get("hazard_blocked", false)), "l'ostruzione hazard ambientale e riportata")
	assert_false(bool(hazard_report.get("crosses_gap", true)), "gli hazard ambientali non contano come varchi attraversati")

	var long_gap_report := component.validate_gap_trajectory(Vector2.ZERO, Vector2(220.0, 0.0), [], [Rect2(Vector2(30.0, -18.0), Vector2(150.0, 36.0))], [Rect2(Vector2(200.0, -24.0), Vector2(70.0, 48.0))])
	assert_false(bool(long_gap_report.get("is_valid", true)), "la schivata rifiuta varchi oltre la distanza massima")
	component.free()

func test_dodge_runtime() -> void:
	var player := CharacterBody2D.new()
	var runtime_dodge := PlayerDodgeComponent.new()
	player.add_child(runtime_dodge)
	add_child(player)
	assert_true(runtime_dodge.try_start(Vector2.RIGHT), "la schivata runtime parte su un body player minimale")
	for _frame in range(20):
		runtime_dodge.physics_process_dodge(0.02)
	assert_false(runtime_dodge.is_dodging, "la schivata runtime finisce")
	assert_gt(runtime_dodge.get_cooldown_ratio(), 0.0, "la schivata runtime avvia il cooldown")
	player.free()

# --- helper (porting da fall_boundary_visual_logic) -----------------------

func _has_fall_rect_for_side(layout: BiomeEnvironmentLayout, side: StringName) -> bool:
	if layout == null:
		return false
	for rect in layout.fall_zone_rects:
		if _rect_matches_side(rect, layout, side):
			return true
	return false

func _has_fall_hazard_side_for_side(layout: BiomeEnvironmentLayout, side: StringName) -> bool:
	if layout == null:
		return false
	for index in range(layout.hazard_ids.size()):
		if layout.hazard_ids[index] != &"fall_zone":
			continue
		if index >= layout.hazard_rects.size() or index >= layout.hazard_sides.size():
			continue
		if layout.hazard_sides[index] != side:
			continue
		if _rect_matches_side(layout.hazard_rects[index], layout, side):
			return true
	return false

func _rect_matches_side(rect: Rect2i, layout: BiomeEnvironmentLayout, side: StringName) -> bool:
	match side:
		&"north":
			return rect.position.y <= 0 and rect.size.y <= 8
		&"south":
			return rect.position.y + rect.size.y >= layout.zone_size.y and rect.size.y <= 8
		&"west":
			return rect.position.x <= 0 and rect.size.x <= 8
		_:
			return rect.position.x + rect.size.x >= layout.zone_size.x and rect.size.x <= 8

func _has_border_obstacle_for_side(layout: BiomeEnvironmentLayout, side: StringName, obstacle_id: StringName) -> bool:
	if layout == null:
		return false
	for index in range(layout.obstacle_rects.size()):
		if index >= layout.obstacle_ids.size():
			continue
		if layout.obstacle_ids[index] != obstacle_id:
			continue
		if _rect_matches_side(layout.obstacle_rects[index], layout, side):
			return true
	return false

func _only_expected_border_ids(layout: BiomeEnvironmentLayout, biome_id: StringName) -> bool:
	if layout == null:
		return false
	var expected_id := _expected_border_obstacle_id(biome_id)
	for obstacle_id in layout.obstacle_ids:
		if BORDER_IDS.has(obstacle_id) and obstacle_id != expected_id:
			return false
	return true

func _expected_border_obstacle_id(biome_id: StringName) -> StringName:
	match biome_id:
		&"toxic_wastes":
			return &"toxic_boundary_wall"
		&"burning_fields":
			return &"lava_boundary"
		&"frozen_outskirts":
			return &"ice_boundary"
		&"drowned_marsh":
			return &"deep_water_boundary"
		_:
			return &"boundary_fence"
