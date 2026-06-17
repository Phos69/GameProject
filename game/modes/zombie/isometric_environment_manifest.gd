extends RefCounted
class_name IsometricEnvironmentManifest

## Loader and validator for assets/environment/isometric/manifest.json.
##
## The manifest is the single source of truth for how environment objects are
## converted to the pseudo-isometric pipeline: collision shape, footprint,
## blocking flags and ground sort offset. Visuals stay procedural (no external
## art is mandatory for bootstrap): when `visual_scene` is empty or points to a
## script, the spawning system uses its built-in procedural drawing as fallback.

const MANIFEST_PATH: String = "res://assets/environment/isometric/manifest.json"
const COLLISION_SHAPES: Array[String] = [
	"rectangle",
	"circle",
	"rectangle_area",
	"circle_or_rectangle",
	"open"
]

static var _cached: IsometricEnvironmentManifest

var version: int = 0
var coordinate_system: String = ""
var default_sort_offset: float = 0.0
var objects: Dictionary = {}
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

func get_sort_offset(object_id: StringName) -> float:
	if objects.has(object_id):
		return float((objects[object_id] as Dictionary).get("sort_offset", default_sort_offset))
	return default_sort_offset

func blocks_movement(object_id: StringName) -> bool:
	if objects.has(object_id):
		return bool((objects[object_id] as Dictionary).get("blocks_movement", true))
	return true

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
		if requires_external_asset(object_id):
			failures.append(
				"%s: visual_scene '%s' is a mandatory external asset"
				% [object_id, String(entry.get("visual_scene", ""))]
			)
	return {
		"is_valid": failures.is_empty(),
		"failures": failures
	}

func _normalize_object(entry: Dictionary) -> Dictionary:
	var footprint_values := entry.get("footprint_tiles", [0, 0]) as Array
	var footprint := Vector2i.ZERO
	if footprint_values.size() >= 2:
		footprint = Vector2i(int(footprint_values[0]), int(footprint_values[1]))
	return {
		"id": StringName(str(entry.get("id", ""))),
		"category": StringName(str(entry.get("category", "obstacle"))),
		"status": StringName(str(entry.get("status", "placeholder"))),
		"visual_scene": String(entry.get("visual_scene", "")),
		"collision_shape": String(entry.get("collision_shape", "rectangle")),
		"footprint_tiles": footprint,
		"blocks_movement": bool(entry.get("blocks_movement", true)),
		"blocks_projectiles": bool(entry.get("blocks_projectiles", true)),
		"is_jumpable_gap_anchor": bool(entry.get("is_jumpable_gap_anchor", false)),
		"sort_offset": float(entry.get("sort_offset", 0.0))
	}
