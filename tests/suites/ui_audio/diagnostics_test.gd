extends GutTest
## UI/Audio A9 — Strumenti di diagnostica: overlay di debug biome e logger.
##
## Migra e accorpa (scena sintetica / logica pura, niente boot di main.tscn):
##   tests/biome_debug_overlay_smoke_test.gd  (BiomeMapDebugOverlay + encounter)
##   tests/game_log_smoke_test.gd             (gating per livello di GameLog)

const LOG_LEVEL_DEBUG := 0
const LOG_LEVEL_INFO := 1
const LOG_LEVEL_WARN := 2
const LOG_LEVEL_ERROR := 3
const LOG_LEVEL_SILENT := 4
const TERRAIN_HAZARD := &"hazard"
const TERRAIN_OBSTACLE := &"obstacle"

class FakeEncounterSystem:
	extends Node

	var snapshot: Dictionary = {}

	func _init(new_snapshot: Dictionary) -> void:
		snapshot = new_snapshot

	func _ready() -> void:
		add_to_group("random_encounter_system")

	func get_debug_snapshot() -> Dictionary:
		return snapshot

# --- overlay di debug della mappa biome (biome_debug_overlay) ----------------

func test_biome_debug_overlay_summary() -> void:
	var scene_root := _make_current_scene_root()
	var overlay = _new_script_instance(
		"res://game/procedural/world_generation/biome_map_debug_overlay.gd"
	)
	scene_root.add_child(overlay)
	var threat_score := 8
	var encounter := FakeEncounterSystem.new({
		"last_encounter_id": &"survivor_cache",
		"last_wave": 2,
		"last_party_size": 1,
		"last_threat_score": threat_score,
		"active_entity_count": 0,
		"pending_telegraph_count": 0,
		"last_skip_reason": &""
	})
	scene_root.add_child(encounter)
	await wait_physics_frames(1)
	var cell = _new_script_instance(
		"res://game/procedural/world_generation/biome_cell.gd"
	)
	cell.id = &"debug_cell"
	cell.biome_id = &"toxic_wastes"
	cell.seed = 99
	cell.validation_report = {"is_valid": true}
	var layout = _new_script_instance(
		"res://game/modes/zombie/biome_environment_layout.gd"
	)
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
	var cells: Array = Array([], TYPE_OBJECT, "RefCounted", cell.get_script())
	cells.append(cell)
	overlay.configure(99, cells)
	var summary: Dictionary = overlay.get_debug_summary()
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
		int(terrain_counts.get(TERRAIN_OBSTACLE, 0)), 0,
		"overlay reports obstacle terrain class"
	)
	assert_gt(
		int(terrain_counts.get(TERRAIN_HAZARD, 0)), 0,
		"overlay reports hazard terrain class"
	)
	var encounter_summary := summary.get("encounter") as Dictionary
	assert_eq(
		encounter_summary.get("last_encounter_id"), &"survivor_cache",
		"overlay exposes last encounter"
	)
	assert_eq(
		int(encounter_summary.get("last_threat_score", 0)),
		threat_score,
		"overlay exposes threat score"
	)
	overlay.cells.clear()
	cell.clear_runtime_links()
	_free_current_scene_root(scene_root)
	await wait_physics_frames(1)

# --- gating per livello del logger condiviso (game_log) ----------------------

func test_game_log_level_gating() -> void:
	var game_log := load("res://game/core/game_log.gd")
	var original_level: int = int(game_log.min_level)

	# Soglia INFO (default): debug filtrato, info/warn/error abilitati.
	game_log.min_level = LOG_LEVEL_INFO
	assert_false(game_log.is_enabled(LOG_LEVEL_DEBUG), "INFO filtra debug")
	assert_true(game_log.is_enabled(LOG_LEVEL_INFO), "INFO abilita info")
	assert_true(game_log.is_enabled(LOG_LEVEL_WARN), "INFO abilita warn")
	assert_true(game_log.is_enabled(LOG_LEVEL_ERROR), "INFO abilita error")

	# Soglia DEBUG: tutto abilitato.
	game_log.min_level = LOG_LEVEL_DEBUG
	assert_true(game_log.is_enabled(LOG_LEVEL_DEBUG), "DEBUG abilita debug")

	# Soglia ERROR: solo gli errori passano.
	game_log.min_level = LOG_LEVEL_ERROR
	assert_false(game_log.is_enabled(LOG_LEVEL_WARN), "ERROR filtra warn")
	assert_true(game_log.is_enabled(LOG_LEVEL_ERROR), "ERROR abilita error")

	# Soglia SILENT: niente passa, nemmeno gli errori.
	game_log.min_level = LOG_LEVEL_SILENT
	assert_false(game_log.is_enabled(LOG_LEVEL_ERROR), "SILENT filtra tutto")

	# Con SILENT le chiamate pubbliche non emettono ne sollevano errori.
	game_log.debug(&"Test", "debug soppresso")
	game_log.info(&"Test", "info soppresso")
	game_log.warn(&"Test", "warn soppresso")
	game_log.error(&"Test", "error soppresso")

	game_log.min_level = original_level

# --- helper -----------------------------------------------------------------

# L'overlay cerca i sistemi diagnostici via SceneTree/group: la scena sintetica
# va agganciata alla root e impostata come current_scene.
func _make_current_scene_root() -> Node2D:
	var scene_root := Node2D.new()
	get_tree().root.add_child(scene_root)
	get_tree().current_scene = scene_root
	return scene_root

func _free_current_scene_root(scene_root: Node2D) -> void:
	if get_tree().current_scene == scene_root:
		get_tree().current_scene = null
	if is_instance_valid(scene_root):
		var parent := scene_root.get_parent()
		if parent != null:
			parent.remove_child(scene_root)
		scene_root.free()

func _new_script_instance(path: String):
	var script := load(path) as Script
	assert_not_null(script, "%s loads" % path)
	return script.new() if script != null else null
