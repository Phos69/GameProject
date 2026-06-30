extends GutTest
## UI/Audio A9 — Strumenti di diagnostica: overlay di debug biome e logger.
##
## Migra e accorpa (scena sintetica / logica pura, niente boot di main.tscn):
##   tests/biome_debug_overlay_smoke_test.gd  (BiomeMapDebugOverlay + encounter)
##   tests/game_log_smoke_test.gd             (gating per livello di GameLog)

# --- overlay di debug della mappa biome (biome_debug_overlay) ----------------

func test_biome_debug_overlay_summary() -> void:
	var scene_root := _make_current_scene_root()
	var overlay := BiomeMapDebugOverlay.new()
	scene_root.add_child(overlay)
	var encounter := RandomEncounterSystem.new()
	scene_root.add_child(encounter)
	await wait_physics_frames(1)
	encounter.configure_seed(99)
	var biome := load("res://game/modes/zombie/biomes/toxic_wastes.tres") as BiomeDefinition
	var cell := BiomeCell.new()
	cell.id = &"debug_cell"
	cell.biome_id = &"toxic_wastes"
	cell.seed = 99
	cell.validation_report = {"is_valid": true}
	var layout := BiomeEnvironmentLayout.new()
	layout.obstacle_rects.append(Rect2i(Vector2i(10, 10), Vector2i(4, 4)))
	layout.hazard_rects.append(Rect2i(Vector2i(30, 30), Vector2i(5, 5)))
	layout.crate_cells.append(Vector2i(50, 50))
	layout.generation_summary = {
		"main_road_count": 2,
		"path_count": 2,
		"house_count": 1,
		"dense_vegetation_count": 1,
		"bridge_count": 1,
		"river_count": 1,
		"water_segment_count": 3,
		"car_count": 1,
		"fence_count": 2
	}
	layout.rebuild_terrain_classification(cell)
	cell.generated_layout = layout
	var cells: Array[BiomeCell] = [cell]
	overlay.configure(99, cells)
	var result := encounter.force_encounter(biome, &"survivor_cache", 2)
	var summary := overlay.get_debug_summary()
	assert_eq(summary.get("seed"), 99, "overlay reports seed")
	assert_eq(summary.get("cell_count"), 1, "overlay counts cells")
	assert_eq(summary.get("obstacle_count"), 1, "overlay counts obstacles")
	assert_eq(summary.get("hazard_count"), 1, "overlay counts hazards")
	assert_eq(summary.get("crate_count"), 1, "overlay counts crates")
	assert_eq(summary.get("main_road_count"), 2, "overlay counts main roads")
	assert_eq(summary.get("path_count"), 2, "overlay counts paths")
	assert_eq(summary.get("house_count"), 1, "overlay counts houses")
	assert_eq(summary.get("dense_vegetation_count"), 1, "overlay counts dense vegetation")
	assert_eq(summary.get("bridge_count"), 1, "overlay counts bridges")
	assert_eq(summary.get("river_count"), 1, "overlay counts rivers")
	assert_eq(summary.get("water_segment_count"), 3, "overlay counts water segments")
	assert_eq(summary.get("car_count"), 1, "overlay counts cars")
	assert_eq(summary.get("fence_count"), 2, "overlay counts fences")
	assert_eq(
		int(summary.get("terrain_classification_total", 0)),
		layout.zone_size.x * layout.zone_size.y,
		"overlay reports terrain classification total"
	)
	assert_eq(
		int(summary.get("terrain_classification_complete", 0)), 1,
		"overlay reports complete terrain classification"
	)
	var terrain_counts := summary.get("terrain_class_counts") as Dictionary
	assert_gt(
		int(terrain_counts.get(BiomeEnvironmentLayout.TERRAIN_OBSTACLE, 0)), 0,
		"overlay reports obstacle terrain class"
	)
	assert_gt(
		int(terrain_counts.get(BiomeEnvironmentLayout.TERRAIN_HAZARD, 0)), 0,
		"overlay reports hazard terrain class"
	)
	var encounter_summary := summary.get("encounter") as Dictionary
	assert_eq(
		encounter_summary.get("last_encounter_id"), &"survivor_cache",
		"overlay exposes last encounter"
	)
	assert_eq(
		int(encounter_summary.get("last_threat_score", 0)),
		int(result.get("threat_score", 0)),
		"overlay exposes threat score"
	)
	_free_current_scene_root(scene_root)
	await wait_physics_frames(1)

# --- gating per livello del logger condiviso (game_log) ----------------------

func test_game_log_level_gating() -> void:
	var original_level := GameLog.min_level

	# Soglia INFO (default): debug filtrato, info/warn/error abilitati.
	GameLog.min_level = GameLog.Level.INFO
	assert_false(GameLog.is_enabled(GameLog.Level.DEBUG), "INFO filtra debug")
	assert_true(GameLog.is_enabled(GameLog.Level.INFO), "INFO abilita info")
	assert_true(GameLog.is_enabled(GameLog.Level.WARN), "INFO abilita warn")
	assert_true(GameLog.is_enabled(GameLog.Level.ERROR), "INFO abilita error")

	# Soglia DEBUG: tutto abilitato.
	GameLog.min_level = GameLog.Level.DEBUG
	assert_true(GameLog.is_enabled(GameLog.Level.DEBUG), "DEBUG abilita debug")

	# Soglia ERROR: solo gli errori passano.
	GameLog.min_level = GameLog.Level.ERROR
	assert_false(GameLog.is_enabled(GameLog.Level.WARN), "ERROR filtra warn")
	assert_true(GameLog.is_enabled(GameLog.Level.ERROR), "ERROR abilita error")

	# Soglia SILENT: niente passa, nemmeno gli errori.
	GameLog.min_level = GameLog.Level.SILENT
	assert_false(GameLog.is_enabled(GameLog.Level.ERROR), "SILENT filtra tutto")

	# Con SILENT le chiamate pubbliche non emettono ne sollevano errori.
	GameLog.debug(&"Test", "debug soppresso")
	GameLog.info(&"Test", "info soppresso")
	GameLog.warn(&"Test", "warn soppresso")
	GameLog.error(&"Test", "error soppresso")

	GameLog.min_level = original_level

# --- helper -----------------------------------------------------------------

# Gli encounter aggiungono telegraph/crate al container risolto via
# get_tree().current_scene: la scena sintetica va agganciata alla root e
# impostata come current_scene (come faceva il vecchio test SceneTree).
func _make_current_scene_root() -> Node2D:
	var scene_root := Node2D.new()
	get_tree().root.add_child(scene_root)
	get_tree().current_scene = scene_root
	return scene_root

func _free_current_scene_root(scene_root: Node2D) -> void:
	if get_tree().current_scene == scene_root:
		get_tree().current_scene = null
	scene_root.queue_free()
