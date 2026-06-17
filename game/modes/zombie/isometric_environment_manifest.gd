extends RefCounted
class_name IsometricEnvironmentManifest

## Loader and validator for assets/environment/isometric/manifest.json.
##
## The manifest is the single source of truth for how environment objects are
## converted to the pseudo-isometric pipeline: collision shape, footprint,
## blocking flags, procedural draw mode and ground sort offset. Visuals stay
## procedural (no external art is mandatory for bootstrap): when `visual_scene`
## is empty or points to a script, the spawning system uses its built-in drawing.

const MANIFEST_PATH: String = "res://assets/environment/isometric/manifest.json"
const COLLISION_SHAPES: Array[String] = [
	"rectangle",
	"circle",
	"rectangle_area",
	"circle_or_rectangle",
	"open"
]
const TERRAIN_DRAW_MODES: Array[String] = [
	"ash_lane",
	"broken_gate",
	"broken_street",
	"bridge_path",
	"burned_road",
	"crack",
	"debris",
	"dirt",
	"dry_grass",
	"growth",
	"main_road",
	"pool",
	"road",
	"service_lane",
	"snow_path",
	"wooden_walkway"
]
const OBJECT_DRAW_MODES: Array[String] = [
	"ash_barrier",
	"barrel",
	"boundary",
	"bridge",
	"broken_walkway",
	"burned_car",
	"burned_house",
	"charred_wall",
	"dead_tree",
	"deep_water_boundary",
	"fence",
	"generic_barrier",
	"ice_boundary",
	"ice_block",
	"lab_block",
	"lab_wall",
	"lava_boundary",
	"log",
	"marsh_log",
	"pipe_stack",
	"reed_wall",
	"rock",
	"ruined_house",
	"scorched_barricade",
	"snow_cabin",
	"snow_wall",
	"sunken_house",
	"toxic_barrel",
	"toxic_boundary_wall",
	"wood_barrier",
	"wreck"
]
const BIOME_OBSTACLE_SCENE := "res://game/modes/zombie/biome_obstacle.gd"

static var _cached: IsometricEnvironmentManifest

var version: int = 0
var coordinate_system: String = ""
var default_sort_offset: float = 0.0
var objects: Dictionary = {}
var object_visual_styles: Dictionary = {}
var terrain_styles: Dictionary = {}
var terrain_sample_step_presets: Dictionary = {}
var conversion_backlog: Array[StringName] = []
var load_error: String = ""

static func get_shared() -> IsometricEnvironmentManifest:
	if _cached == null:
		_cached = IsometricEnvironmentManifest.new()
		_cached.load_from_disk()
	return _cached

static func reload_shared() -> IsometricEnvironmentManifest:
	_cached = null
	return get_shared()

func load_from_disk(path: String = MANIFEST_PATH) -> bool:
	version = 0
	coordinate_system = ""
	default_sort_offset = 0.0
	objects.clear()
	object_visual_styles.clear()
	terrain_styles.clear()
	terrain_sample_step_presets.clear()
	conversion_backlog.clear()
	load_error = ""
	if not FileAccess.file_exists(path):
		load_error = "manifest not found: %s" % path
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		load_error = "cannot open manifest: %s" % path
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		load_error = "manifest root must be a JSON object"
		return false
	var data := parsed as Dictionary
	version = int(data.get("version", 0))
	coordinate_system = String(data.get("coordinate_system", ""))
	var default_sorting := data.get("default_sorting", {}) as Dictionary
	default_sort_offset = float(default_sorting.get("sort_offset", 0.0))
	_load_object_visual_data(data.get("object_visuals", {}))
	_load_terrain_data(data.get("terrain", {}))
	for entry_value in data.get("objects", []) as Array:
		var entry := entry_value as Dictionary
		if entry == null:
			continue
		var normalized := _normalize_object(entry)
		objects[normalized["id"]] = normalized
	for backlog_value in data.get("conversion_backlog", []) as Array:
		conversion_backlog.append(StringName(str(backlog_value)))
	return true

func has_object(object_id: StringName) -> bool:
	return objects.has(object_id)

func get_object(object_id: StringName) -> Dictionary:
	return (objects.get(object_id, {}) as Dictionary).duplicate(true)

func get_object_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for key in objects.keys():
		ids.append(StringName(key))
	ids.sort()
	return ids

func get_category(object_id: StringName) -> StringName:
	if objects.has(object_id):
		return StringName((objects[object_id] as Dictionary).get("category", &"obstacle"))
	return &"obstacle"

func get_object_draw_mode(object_id: StringName) -> StringName:
	if objects.has(object_id):
		return StringName((objects[object_id] as Dictionary).get("draw_mode", &"generic_barrier"))
	return &"generic_barrier"

func object_has_dedicated_draw(object_id: StringName) -> bool:
	if objects.has(object_id):
		return bool((objects[object_id] as Dictionary).get("dedicated_draw", false))
	return false

func get_object_visual_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for key in object_visual_styles.keys():
		ids.append(StringName(key))
	ids.sort()
	return ids

func has_terrain_tag(terrain_tag: StringName) -> bool:
	return terrain_styles.has(terrain_tag)

func get_terrain_style(terrain_tag: StringName) -> Dictionary:
	if terrain_styles.has(terrain_tag):
		return (terrain_styles[terrain_tag] as Dictionary).duplicate(true)
	return {
		"id": terrain_tag,
		"category": &"fallback",
		"draw_mode": &"dirt",
		"dedicated_draw": false,
		"fallback": "undocumented fallback"
	}

func get_terrain_tag_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for key in terrain_styles.keys():
		ids.append(StringName(key))
	ids.sort()
	return ids

func get_terrain_draw_mode(terrain_tag: StringName) -> StringName:
	return StringName(get_terrain_style(terrain_tag).get("draw_mode", &"dirt"))

func terrain_tag_has_dedicated_draw(terrain_tag: StringName) -> bool:
	return bool(get_terrain_style(terrain_tag).get("dedicated_draw", false))

func get_terrain_sample_step(preset: StringName = &"balanced") -> int:
	if terrain_sample_step_presets.has(preset):
		return int(terrain_sample_step_presets[preset])
	if terrain_sample_step_presets.has(&"balanced"):
		return int(terrain_sample_step_presets[&"balanced"])
	return 8

func get_sort_offset(object_id: StringName) -> float:
	if objects.has(object_id):
		return float((objects[object_id] as Dictionary).get("sort_offset", default_sort_offset))
	return default_sort_offset

func blocks_movement(object_id: StringName) -> bool:
	if objects.has(object_id):
		return bool((objects[object_id] as Dictionary).get("blocks_movement", true))
	return true

func blocks_projectiles(object_id: StringName) -> bool:
	if objects.has(object_id):
		return bool((objects[object_id] as Dictionary).get("blocks_projectiles", true))
	return true

func get_collision_shape(object_id: StringName) -> StringName:
	if objects.has(object_id):
		return StringName((objects[object_id] as Dictionary).get("collision_shape", &"rectangle"))
	return &"rectangle"

func is_jumpable_gap_anchor(object_id: StringName) -> bool:
	if objects.has(object_id):
		return bool((objects[object_id] as Dictionary).get("is_jumpable_gap_anchor", false))
	return false

func requires_external_asset(object_id: StringName) -> bool:
	if not objects.has(object_id):
		return false
	var scene := String((objects[object_id] as Dictionary).get("visual_scene", ""))
	if scene.is_empty():
		return false
	return not (scene.ends_with(".gd") or ResourceLoader.exists(scene))

func validate() -> Dictionary:
	var failures := PackedStringArray()
	if not load_error.is_empty():
		failures.append(load_error)
	if version <= 0:
		failures.append("manifest version must be positive")
	for object_id in objects.keys():
		var entry := objects[object_id] as Dictionary
		var collision_shape := String(entry.get("collision_shape", ""))
		if not COLLISION_SHAPES.has(collision_shape):
			failures.append("%s: unknown collision_shape '%s'" % [object_id, collision_shape])
		var footprint := entry.get("footprint_tiles", Vector2i.ZERO) as Vector2i
		if footprint.x <= 0 or footprint.y <= 0:
			failures.append("%s: footprint_tiles must be positive" % object_id)
		if _uses_biome_obstacle_visual(entry):
			var draw_mode := String(entry.get("draw_mode", ""))
			if not OBJECT_DRAW_MODES.has(draw_mode):
				failures.append("%s: unknown object draw_mode '%s'" % [object_id, draw_mode])
			if draw_mode == "generic_barrier" and String(entry.get("fallback", "")).is_empty():
				failures.append("%s: generic object draw_mode requires an explicit fallback note" % object_id)
		if requires_external_asset(object_id):
			failures.append(
				"%s: visual_scene '%s' is a mandatory external asset"
				% [object_id, String(entry.get("visual_scene", ""))]
			)
	for visual_id in object_visual_styles.keys():
		if not objects.has(visual_id):
			failures.append("%s: object_visuals entry has no matching object" % visual_id)
	if terrain_styles.is_empty():
		failures.append("terrain section must define generated terrain tags")
	for terrain_id in terrain_styles.keys():
		var entry := terrain_styles[terrain_id] as Dictionary
		var draw_mode := String(entry.get("draw_mode", ""))
		if not TERRAIN_DRAW_MODES.has(draw_mode):
			failures.append("%s: unknown terrain draw_mode '%s'" % [terrain_id, draw_mode])
		if String(entry.get("category", "")).is_empty():
			failures.append("%s: terrain category must not be empty" % terrain_id)
	for preset_id in terrain_sample_step_presets.keys():
		var step := int(terrain_sample_step_presets[preset_id])
		if step <= 0:
			failures.append("%s: sample_step preset must be positive" % preset_id)
	return {
		"is_valid": failures.is_empty(),
		"failures": failures
	}

func _load_object_visual_data(value: Variant) -> void:
	if not value is Dictionary:
		return
	var visual_data := value as Dictionary
	for key in visual_data.keys():
		var object_id := StringName(str(key))
		var entry_value: Variant = visual_data[key]
		var draw_mode := &"generic_barrier"
		var dedicated_draw := false
		var fallback := ""
		if entry_value is Dictionary:
			var entry := entry_value as Dictionary
			draw_mode = StringName(str(entry.get("draw_mode", "generic_barrier")))
			dedicated_draw = bool(entry.get("dedicated_draw", false))
			fallback = String(entry.get("fallback", ""))
		else:
			draw_mode = StringName(str(entry_value))
			dedicated_draw = true
		object_visual_styles[object_id] = {
			"id": object_id,
			"draw_mode": draw_mode,
			"dedicated_draw": dedicated_draw,
			"fallback": fallback
		}

func _load_terrain_data(value: Variant) -> void:
	if not value is Dictionary:
		return
	var terrain := value as Dictionary
	var presets := terrain.get("sample_step_presets", {}) as Dictionary
	for preset_key in presets.keys():
		terrain_sample_step_presets[StringName(str(preset_key))] = int(presets[preset_key])
	for entry_value in terrain.get("tags", []) as Array:
		var entry := entry_value as Dictionary
		if entry == null:
			continue
		var normalized := _normalize_terrain_style(entry)
		terrain_styles[normalized["id"]] = normalized

func _normalize_object(entry: Dictionary) -> Dictionary:
	var object_id := StringName(str(entry.get("id", "")))
	var footprint_values := entry.get("footprint_tiles", [0, 0]) as Array
	var footprint := Vector2i.ZERO
	if footprint_values.size() >= 2:
		footprint = Vector2i(int(footprint_values[0]), int(footprint_values[1]))
	var visual_style := object_visual_styles.get(object_id, {}) as Dictionary
	return {
		"id": object_id,
		"category": StringName(str(entry.get("category", "obstacle"))),
		"status": StringName(str(entry.get("status", "placeholder"))),
		"visual_scene": String(entry.get("visual_scene", "")),
		"draw_mode": StringName(str(entry.get("draw_mode", visual_style.get("draw_mode", &"generic_barrier")))),
		"dedicated_draw": bool(entry.get("dedicated_draw", visual_style.get("dedicated_draw", false))),
		"fallback": String(entry.get("fallback", visual_style.get("fallback", ""))),
		"collision_shape": String(entry.get("collision_shape", "rectangle")),
		"footprint_tiles": footprint,
		"blocks_movement": bool(entry.get("blocks_movement", true)),
		"blocks_projectiles": bool(entry.get("blocks_projectiles", true)),
		"is_jumpable_gap_anchor": bool(entry.get("is_jumpable_gap_anchor", false)),
		"sort_offset": float(entry.get("sort_offset", 0.0))
	}

func _normalize_terrain_style(entry: Dictionary) -> Dictionary:
	return {
		"id": StringName(str(entry.get("id", ""))),
		"category": StringName(str(entry.get("category", "terrain"))),
		"draw_mode": StringName(str(entry.get("draw_mode", "dirt"))),
		"dedicated_draw": bool(entry.get("dedicated_draw", false)),
		"fallback": String(entry.get("fallback", ""))
	}

func _uses_biome_obstacle_visual(entry: Dictionary) -> bool:
	return String(entry.get("visual_scene", "")) == BIOME_OBSTACLE_SCENE
