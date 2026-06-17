extends CanvasLayer
class_name BiomeMapDebugOverlay

signal regenerate_same_seed_requested()
signal regenerate_new_seed_requested()

@export var visible_on_start: bool = false
@export var input_enabled: bool = false
@export_range(0.1, 2.0, 0.1) var refresh_interval: float = 0.5

var seed_value: int = 0
var cells: Array[BiomeCell] = []
var label: Label
var show_borders: bool = true
var show_pathfinding: bool = false
var show_collision: bool = false
var show_terrain_classes: bool = true
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
	new_cells: Array[BiomeCell]
) -> void:
	seed_value = new_seed
	cells = new_cells.duplicate()
	if is_inside_tree():
		_refresh_label()

func copy_seed_to_clipboard() -> void:
	DisplayServer.clipboard_set(str(seed_value))

func get_debug_summary() -> Dictionary:
	var passage_count := 0
	var fall_side_count := 0
	var validation_failures := 0
	var obstacle_count := 0
	var hazard_count := 0
	var crate_count := 0
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
			var report := cell.generated_layout.get_classification_report()
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
		for side in BiomeCell.SIDES:
			if cell.get_border(side) == BiomeCell.BorderType.FALL:
				fall_side_count += 1
		if not bool(cell.validation_report.get("is_valid", false)):
			validation_failures += 1
	var biome_manager := get_tree().get_first_node_in_group(
		"biome_manager"
	) as BiomeManager
	if biome_manager != null:
		current_biome_id = biome_manager.get_current_biome_id()
		var current_cell := biome_manager.get_current_biome_cell()
		if current_cell != null:
			current_validation = current_cell.validation_report
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
		"terrain_class_counts": terrain_class_counts,
		"terrain_classification_total": terrain_classification_total,
		"terrain_classification_complete": terrain_classification_complete,
		"current_biome_id": current_biome_id,
		"current_validation": current_validation,
		"encounter": encounter_snapshot,
		"show_borders": show_borders,
		"show_pathfinding": show_pathfinding,
		"show_collision": show_collision,
		"show_terrain_classes": show_terrain_classes
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
	if bool(summary.get("show_terrain_classes", false)):
		var terrain_counts := summary.get("terrain_class_counts", {}) as Dictionary
		lines.append("Terrain complete:%d/%d total:%d" % [
			int(summary.get("terrain_classification_complete", 0)),
			int(summary.get("cell_count", 0)),
			int(summary.get("terrain_classification_total", 0))
		])
		lines.append("Walk:%d Obs:%d Haz:%d Border:%d Void:%d Fall:%d" % [
			int(terrain_counts.get(BiomeEnvironmentLayout.TERRAIN_WALKABLE, 0)),
			int(terrain_counts.get(BiomeEnvironmentLayout.TERRAIN_OBSTACLE, 0)),
			int(terrain_counts.get(BiomeEnvironmentLayout.TERRAIN_HAZARD, 0)),
			int(terrain_counts.get(BiomeEnvironmentLayout.TERRAIN_BORDER, 0)),
			int(terrain_counts.get(BiomeEnvironmentLayout.TERRAIN_VOID, 0)),
			int(terrain_counts.get(BiomeEnvironmentLayout.TERRAIN_FALL_ZONE, 0))
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

func _empty_terrain_class_counts() -> Dictionary:
	return {
		BiomeEnvironmentLayout.TERRAIN_WALKABLE: 0,
		BiomeEnvironmentLayout.TERRAIN_OBSTACLE: 0,
		BiomeEnvironmentLayout.TERRAIN_HAZARD: 0,
		BiomeEnvironmentLayout.TERRAIN_BORDER: 0,
		BiomeEnvironmentLayout.TERRAIN_VOID: 0,
		BiomeEnvironmentLayout.TERRAIN_FALL_ZONE: 0
	}
