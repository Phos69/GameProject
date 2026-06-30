extends CanvasLayer
class_name BiomeMapDebugOverlay

signal regenerate_same_seed_requested()
signal regenerate_new_seed_requested()

@export var visible_on_start: bool = false
@export var input_enabled: bool = false
@export_range(0.1, 2.0, 0.1) var refresh_interval: float = 0.5

const CELL_BORDER_FALL := 2
const CELL_SIDES: Array[StringName] = [&"north", &"south", &"east", &"west"]
const TERRAIN_BORDER := &"border"
const TERRAIN_FALL_ZONE := &"fall_zone"
const TERRAIN_HAZARD := &"hazard"
const TERRAIN_OBSTACLE := &"obstacle"
const TERRAIN_VOID := &"void"
const TERRAIN_WALKABLE := &"walkable"

var seed_value: int = 0
var cells: Array = []
var label: Label
var show_borders: bool = true
var show_pathfinding: bool = false
var show_collision: bool = false
var show_terrain_classes: bool = true
var show_graph: bool = true
var refresh_timer: float = 0.0

func _ready() -> void:
	add_to_group("biome_map_debug_overlay")
	visible = visible_on_start
	label = Label.new()
	label.name = "DebugLabel"
	label.position = Vector2(20.0, 20.0)
	label.add_theme_font_size_override("font_size", 14)
	add_child(label)
	_refresh_label()

func _exit_tree() -> void:
	cells.clear()
	label = null

func _process(delta: float) -> void:
	if not visible:
		return
	refresh_timer = maxf(refresh_timer - delta, 0.0)
	if refresh_timer > 0.0:
		return
	refresh_timer = refresh_interval
	_refresh_label()

func configure(
	new_seed: int,
	new_cells: Array
) -> void:
	seed_value = new_seed
	cells = new_cells.duplicate()
	if is_inside_tree():
		# Deferred so this stays safe when world generation runs on a worker thread:
		# the Label (a UI node) is then only touched on the main thread.
		call_deferred("_refresh_label")

func copy_seed_to_clipboard() -> void:
	DisplayServer.clipboard_set(str(seed_value))

func get_debug_summary() -> Dictionary:
	var passage_count := 0
	var fall_side_count := 0
	var validation_failures := 0
	var obstacle_count := 0
	var hazard_count := 0
	var crate_count := 0
	var main_road_count := 0
	var path_count := 0
	var house_count := 0
	var dense_vegetation_count := 0
	var bridge_count := 0
	var river_count := 0
	var water_segment_count := 0
	var car_count := 0
	var fence_count := 0
	var terrain_class_counts := _empty_terrain_class_counts()
	var terrain_classification_total := 0
	var terrain_classification_complete := 0
	var current_biome_id := &""
	var current_validation := {}
	for cell in cells:
		passage_count += cell.passages.size()
		if cell.generated_layout != null:
			obstacle_count += cell.generated_layout.obstacle_rects.size()
			hazard_count += cell.generated_layout.hazard_rects.size()
			hazard_count += cell.generated_layout.fall_zone_rects.size()
			crate_count += cell.generated_layout.crate_cells.size()
			var generation_summary: Dictionary = cell.generated_layout.generation_summary
			main_road_count += int(generation_summary.get("main_road_count", 0))
			path_count += int(generation_summary.get("path_count", 0))
			house_count += int(generation_summary.get("house_count", 0))
			dense_vegetation_count += int(generation_summary.get("dense_vegetation_count", 0))
			bridge_count += int(generation_summary.get("bridge_count", 0))
			river_count += int(generation_summary.get("river_count", 0))
			water_segment_count += int(generation_summary.get("water_segment_count", 0))
			car_count += int(generation_summary.get("car_count", 0))
			fence_count += int(generation_summary.get("fence_count", 0))
			var report: Dictionary = cell.generated_layout.get_classification_report()
			terrain_classification_total += int(report.get("total", 0))
			if bool(report.get("is_complete", false)):
				terrain_classification_complete += 1
			var counts := report.get("counts", {}) as Dictionary
			for terrain_class in counts.keys():
				var class_id := StringName(terrain_class)
				terrain_class_counts[class_id] = (
					int(terrain_class_counts.get(class_id, 0))
					+ int(counts[terrain_class])
				)
		for side in CELL_SIDES:
			if cell.get_border(side) == CELL_BORDER_FALL:
				fall_side_count += 1
		if not bool(cell.validation_report.get("is_valid", false)):
			validation_failures += 1
	var current_region_id := &""
	var graph_report := {}
	var biome_manager := get_tree().get_first_node_in_group(
		"biome_manager"
	)
	if biome_manager != null:
		current_biome_id = biome_manager.get_current_biome_id()
		current_region_id = biome_manager.get_current_region_id()
		var current_cell: Variant = biome_manager.get_current_biome_cell()
		if current_cell != null:
			current_validation = current_cell.validation_report
		var graph: Variant = biome_manager.get_world_graph()
		if graph != null:
			graph_report = graph.get_connectivity_report()
	var active_region_ids: Array[StringName] = []
	var world_runtime := get_tree().get_first_node_in_group("world_runtime")
	if world_runtime != null and world_runtime.has_method("get_active_region_ids"):
		active_region_ids = world_runtime.get_active_region_ids()
	var loaded_region_count := active_region_ids.size()
	var unloaded_region_count := maxi(
		int(graph_report.get("region_count", 0)) - loaded_region_count,
		0
	)
	var encounter_snapshot := _get_encounter_snapshot()
	return {
		"seed": seed_value,
		"cell_count": cells.size(),
		"passage_count": passage_count,
		"fall_side_count": fall_side_count,
		"validation_failures": validation_failures,
		"obstacle_count": obstacle_count,
		"hazard_count": hazard_count,
		"crate_count": crate_count,
		"main_road_count": main_road_count,
		"path_count": path_count,
		"house_count": house_count,
		"dense_vegetation_count": dense_vegetation_count,
		"bridge_count": bridge_count,
		"river_count": river_count,
		"water_segment_count": water_segment_count,
		"car_count": car_count,
		"fence_count": fence_count,
		"terrain_class_counts": terrain_class_counts,
		"terrain_classification_total": terrain_classification_total,
		"terrain_classification_complete": terrain_classification_complete,
		"current_biome_id": current_biome_id,
		"current_region_id": current_region_id,
		"current_validation": current_validation,
		"graph": graph_report,
		"active_region_ids": active_region_ids,
		"active_region_count": loaded_region_count,
		"unloaded_region_count": unloaded_region_count,
		"encounter": encounter_snapshot,
		"show_borders": show_borders,
		"show_pathfinding": show_pathfinding,
		"show_collision": show_collision,
		"show_terrain_classes": show_terrain_classes,
		"show_graph": show_graph
	}

func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_F1:
			visible = not visible
			get_viewport().set_input_as_handled()
		KEY_F2:
			if visible:
				show_collision = not show_collision
				_refresh_label()
				get_viewport().set_input_as_handled()
		KEY_F3:
			if visible:
				show_pathfinding = not show_pathfinding
				_refresh_label()
				get_viewport().set_input_as_handled()
		KEY_F4:
			if visible:
				show_borders = not show_borders
				_refresh_label()
				get_viewport().set_input_as_handled()
		KEY_F7:
			if visible:
				show_terrain_classes = not show_terrain_classes
				_refresh_label()
				get_viewport().set_input_as_handled()
		KEY_F8:
			if visible:
				show_graph = not show_graph
				_refresh_label()
				get_viewport().set_input_as_handled()
		KEY_F5:
			if visible:
				regenerate_same_seed_requested.emit()
				get_viewport().set_input_as_handled()
		KEY_F6:
			if visible:
				regenerate_new_seed_requested.emit()
				get_viewport().set_input_as_handled()
		_:
			pass

func _refresh_label() -> void:
	if label == null or not is_inside_tree():
		return
	var summary := get_debug_summary()
	var encounter := summary.get("encounter", {}) as Dictionary
	var current_validation := summary.get("current_validation", {}) as Dictionary
	var lines := PackedStringArray()
	lines.append("Seed: %d  Biome: %s" % [
		int(summary.get("seed", 0)),
		String(summary.get("current_biome_id", &""))
	])
	lines.append("Cells:%d Passages:%d Falls:%d ValidationFail:%d" % [
		int(summary.get("cell_count", 0)),
		int(summary.get("passage_count", 0)),
		int(summary.get("fall_side_count", 0)),
		int(summary.get("validation_failures", 0))
	])
	lines.append("Obstacles:%d Hazards:%d Crates:%d CurrentValid:%s" % [
		int(summary.get("obstacle_count", 0)),
		int(summary.get("hazard_count", 0)),
		int(summary.get("crate_count", 0)),
		str(current_validation.get("is_valid", false))
	])
	lines.append("Roads:%d Paths:%d Houses:%d Dense:%d Bridges:%d Rivers:%d Water:%d" % [
		int(summary.get("main_road_count", 0)),
		int(summary.get("path_count", 0)),
		int(summary.get("house_count", 0)),
		int(summary.get("dense_vegetation_count", 0)),
		int(summary.get("bridge_count", 0)),
		int(summary.get("river_count", 0)),
		int(summary.get("water_segment_count", 0))
	])
	lines.append("Cars:%d Fences:%d" % [
		int(summary.get("car_count", 0)),
		int(summary.get("fence_count", 0))
	])
	if bool(summary.get("show_terrain_classes", false)):
		var terrain_counts := summary.get("terrain_class_counts", {}) as Dictionary
		lines.append("Terrain complete:%d/%d total:%d" % [
			int(summary.get("terrain_classification_complete", 0)),
			int(summary.get("cell_count", 0)),
			int(summary.get("terrain_classification_total", 0))
		])
		lines.append("Walk:%d Obs:%d Haz:%d Border:%d Void:%d Fall:%d" % [
			int(terrain_counts.get(TERRAIN_WALKABLE, 0)),
			int(terrain_counts.get(TERRAIN_OBSTACLE, 0)),
			int(terrain_counts.get(TERRAIN_HAZARD, 0)),
			int(terrain_counts.get(TERRAIN_BORDER, 0)),
			int(terrain_counts.get(TERRAIN_VOID, 0)),
			int(terrain_counts.get(TERRAIN_FALL_ZONE, 0))
		])
	lines.append("Encounter:%s Wave:%d Party:%d Threat:%d Ent:%d Tel:%d Skip:%s" % [
		String(encounter.get("last_encounter_id", &"")),
		int(encounter.get("last_wave", -1)),
		int(encounter.get("last_party_size", 1)),
		int(encounter.get("last_threat_score", 0)),
		int(encounter.get("active_entity_count", 0)),
		int(encounter.get("pending_telegraph_count", 0)),
		String(encounter.get("last_skip_reason", &""))
	])
	if bool(summary.get("show_graph", false)):
		var graph_data := summary.get("graph", {}) as Dictionary
		lines.append("Graph connected:%s regions:%d edges:%d unreachable:%d" % [
			str(graph_data.get("is_connected", false)),
			int(graph_data.get("region_count", 0)),
			int(graph_data.get("connection_count", 0)),
			int(graph_data.get("unreachable_count", 0))
		])
		lines.append("Region:%s Active:%d Unloaded:%d [%s]" % [
			String(summary.get("current_region_id", &"")),
			int(summary.get("active_region_count", 0)),
			int(summary.get("unloaded_region_count", 0)),
			", ".join(_region_ids_to_strings(summary.get("active_region_ids", [])))
		])
	lines.append("Borders:%s  Path:%s  Collision:%s" % [
		str(show_borders),
		str(show_pathfinding),
		str(show_collision)
	])
	for cell in cells:
		lines.append("%s %s %s" % [
			String(cell.id),
			String(cell.biome_id),
			str(cell.grid)
		])
	label.text = "\n".join(lines)

func _get_encounter_snapshot() -> Dictionary:
	var encounter_system := get_tree().get_first_node_in_group(
		"random_encounter_system"
	)
	if (
		encounter_system == null
		or not encounter_system.has_method("get_debug_snapshot")
	):
		return {}
	return encounter_system.get_debug_snapshot()

func _region_ids_to_strings(region_ids: Array) -> PackedStringArray:
	var result := PackedStringArray()
	for region_id in region_ids:
		result.append(String(region_id))
	return result

func _empty_terrain_class_counts() -> Dictionary:
	return {
		TERRAIN_WALKABLE: 0,
		TERRAIN_OBSTACLE: 0,
		TERRAIN_HAZARD: 0,
		TERRAIN_BORDER: 0,
		TERRAIN_VOID: 0,
		TERRAIN_FALL_ZONE: 0
	}
