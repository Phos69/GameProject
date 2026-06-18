extends RefCounted
class_name IsometricEnvironmentManifest

## Loader and validator for assets/environment/isometric/manifest.json.
##
## The manifest is the single source of truth for how environment objects are
## converted to the pseudo-isometric pipeline: collision shape, footprint,
## blocking flags, procedural draw mode, asset contract and ground sort offset.
## Manifest v7 separates the normal asset path from the technical fallback path:
## missing art is allowed only when the entry explicitly declares a fallback or a
## needs_asset/procedural_fallback status.

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
const ASSET_CONTRACT_SECTIONS: Array[String] = [
	"tile_sets",
	"tile_variants",
	"terrain_tiles",
	"edge_tiles",
	"void_tiles",
	"object_scenes",
	"passage_tiles",
	"biome_asset_sets"
]
const ASSET_STATUSES: Array[String] = [
	"final",
	"base_complete",
	"needs_polish",
	"procedural_fallback",
	"needs_asset",
	"deprecated"
]
const MISSING_ASSET_STATUSES: Array[String] = [
	"needs_asset",
	"procedural_fallback",
	"deprecated"
]
const ASSET_ANCHORS: Array[String] = [
	"center",
	"bottom_center",
	"iso_floor_center",
	"edge_aligned"
]

static var _cached: IsometricEnvironmentManifest

var version: int = 0
var coordinate_system: String = ""
var default_sort_offset: float = 0.0
var asset_contract_defaults: Dictionary = {}
var fallback_policy: Dictionary = {}
var asset_contracts: Dictionary = {}
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
	asset_contract_defaults.clear()
	fallback_policy.clear()
	asset_contracts.clear()
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
	_load_asset_contract_data(data)
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

func get_asset_contract_section_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for section in asset_contracts.keys():
		ids.append(StringName(str(section)))
	ids.sort()
	return ids

func has_asset_contract(section: StringName, asset_id: StringName) -> bool:
	var section_data := asset_contracts.get(section, {}) as Dictionary
	return section_data.has(asset_id)

func get_asset_contract(section: StringName, asset_id: StringName) -> Dictionary:
	var section_data := asset_contracts.get(section, {}) as Dictionary
	if section_data.has(asset_id):
		return (section_data[asset_id] as Dictionary).duplicate(true)
	return {}

func get_asset_contract_ids(section: StringName) -> Array[StringName]:
	var ids: Array[StringName] = []
	var section_data := asset_contracts.get(section, {}) as Dictionary
	for key in section_data.keys():
		ids.append(StringName(str(key)))
	ids.sort()
	return ids

func get_object_asset_contract(object_id: StringName) -> Dictionary:
	return get_asset_contract(&"object_scenes", object_id)

func get_terrain_asset_contract(terrain_tag: StringName) -> Dictionary:
	return get_asset_contract(&"terrain_tiles", terrain_tag)

func get_passage_asset_contract(passage_type: StringName) -> Dictionary:
	return get_asset_contract(&"passage_tiles", passage_type)

func get_void_asset_contract(void_id: StringName) -> Dictionary:
	return get_asset_contract(&"void_tiles", void_id)

func get_tile_variant_asset_contract(tile_id: StringName) -> Dictionary:
	return get_asset_contract(&"tile_variants", tile_id)

func get_biome_asset_set_contract(biome_id: StringName) -> Dictionary:
	return get_asset_contract(&"biome_asset_sets", biome_id)

func get_fallback_policy() -> Dictionary:
	return fallback_policy.duplicate(true)

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
	if version >= 7:
		_validate_asset_contracts(failures)
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

func _load_asset_contract_data(data: Dictionary) -> void:
	asset_contract_defaults = _normalize_contract_defaults(
		data.get("asset_contract_defaults", {}) as Dictionary
	)
	fallback_policy = (data.get("fallback_policy", {}) as Dictionary).duplicate(true)
	for section in ASSET_CONTRACT_SECTIONS:
		asset_contracts[StringName(section)] = {}
		_load_asset_contract_section(StringName(section), data.get(section, {}))

func _load_asset_contract_section(section: StringName, value: Variant) -> void:
	var section_data := asset_contracts.get(section, {}) as Dictionary
	if value is Dictionary:
		var entries := value as Dictionary
		for key in entries.keys():
			var entry_value: Variant = entries[key]
			if not entry_value is Dictionary:
				continue
			var entry := (entry_value as Dictionary).duplicate(true)
			if not entry.has("id"):
				entry["id"] = str(key)
			var normalized := _normalize_asset_contract(section, entry)
			section_data[normalized["id"]] = normalized
	elif value is Array:
		for entry_value in value as Array:
			if not entry_value is Dictionary:
				continue
			var normalized := _normalize_asset_contract(section, entry_value as Dictionary)
			section_data[normalized["id"]] = normalized
	asset_contracts[section] = section_data

func _normalize_contract_defaults(defaults: Dictionary) -> Dictionary:
	return {
		"status": String(defaults.get("status", "needs_asset")),
		"source": String(defaults.get("source", "internal_generated")),
		"license": String(defaults.get("license", "Project original")),
		"attribution_key": String(defaults.get("attribution_key", "environment_isometric_internal")),
		"anchor": StringName(str(defaults.get("anchor", "iso_floor_center"))),
		"biome_ids": _normalize_string_name_array(defaults.get("biome_ids", ["shared"]))
	}

func _normalize_asset_contract(section: StringName, entry: Dictionary) -> Dictionary:
	var asset_id := StringName(str(entry.get("id", "")))
	var legacy_object := objects.get(asset_id, {}) as Dictionary
	var terrain_style := terrain_styles.get(asset_id, {}) as Dictionary
	var default_fallback := _get_default_fallback_path(section, asset_id)
	return {
		"id": asset_id,
		"section": section,
		"asset_path": String(entry.get("asset_path", "")),
		"status": String(entry.get("status", asset_contract_defaults.get("status", "needs_asset"))),
		"biome_ids": _normalize_string_name_array(
			entry.get("biome_ids", asset_contract_defaults.get("biome_ids", ["shared"]))
		),
		"footprint_tiles": _resolve_contract_footprint(section, entry, legacy_object),
		"anchor": StringName(str(entry.get("anchor", asset_contract_defaults.get("anchor", &"iso_floor_center")))),
		"sort_offset": float(entry.get("sort_offset", _resolve_contract_sort_offset(section, legacy_object))),
		"collision_shape": String(entry.get("collision_shape", _resolve_contract_collision_shape(section, legacy_object))),
		"blocks_movement": bool(entry.get("blocks_movement", _resolve_contract_blocks_movement(section, legacy_object))),
		"blocks_projectiles": bool(entry.get("blocks_projectiles", _resolve_contract_blocks_projectiles(section, legacy_object))),
		"source": String(entry.get("source", asset_contract_defaults.get("source", "internal_generated"))),
		"license": String(entry.get("license", asset_contract_defaults.get("license", "Project original"))),
		"attribution_key": String(entry.get("attribution_key", asset_contract_defaults.get("attribution_key", "environment_isometric_internal"))),
		"fallback_path": String(entry.get("fallback_path", default_fallback)),
		"fallback_reason": String(entry.get("fallback_reason", terrain_style.get("fallback", "")))
	}

func _normalize_string_name_array(value: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if value is Array:
		for item in value as Array:
			result.append(StringName(str(item)))
	elif value != null:
		result.append(StringName(str(value)))
	return result

func _resolve_contract_footprint(
	section: StringName,
	entry: Dictionary,
	legacy_object: Dictionary
) -> Vector2i:
	if entry.has("footprint_tiles"):
		var footprint_values := entry.get("footprint_tiles", [0, 0]) as Array
		if footprint_values.size() >= 2:
			return Vector2i(int(footprint_values[0]), int(footprint_values[1]))
	if legacy_object.has("footprint_tiles"):
		return legacy_object.get("footprint_tiles", Vector2i.ONE) as Vector2i
	match section:
		&"tile_sets", &"tile_variants", &"terrain_tiles", &"passage_tiles":
			return Vector2i.ONE
		&"edge_tiles":
			return Vector2i(16, 4)
		&"void_tiles":
			return Vector2i(200, 6)
		_:
			return Vector2i.ONE

func _resolve_contract_sort_offset(section: StringName, legacy_object: Dictionary) -> float:
	if legacy_object.has("sort_offset"):
		return float(legacy_object.get("sort_offset", default_sort_offset))
	if section == &"object_scenes":
		return default_sort_offset
	return 0.0

func _resolve_contract_collision_shape(section: StringName, legacy_object: Dictionary) -> String:
	if legacy_object.has("collision_shape"):
		return String(legacy_object.get("collision_shape", "rectangle"))
	match section:
		&"object_scenes", &"edge_tiles":
			return "rectangle"
		&"void_tiles":
			return "rectangle_area"
		_:
			return "open"

func _resolve_contract_blocks_movement(section: StringName, legacy_object: Dictionary) -> bool:
	if legacy_object.has("blocks_movement"):
		return bool(legacy_object.get("blocks_movement", true))
	return section == &"object_scenes" or section == &"edge_tiles"

func _resolve_contract_blocks_projectiles(section: StringName, legacy_object: Dictionary) -> bool:
	if legacy_object.has("blocks_projectiles"):
		return bool(legacy_object.get("blocks_projectiles", true))
	return section == &"object_scenes" or section == &"edge_tiles"

func _get_default_fallback_path(section: StringName, asset_id: StringName) -> String:
	var technical := fallback_policy.get("technical_fallbacks", {}) as Dictionary
	match section:
		&"tile_sets", &"tile_variants":
			return String(technical.get("terrain", ""))
		&"terrain_tiles":
			return String(technical.get("terrain_patch", ""))
		&"edge_tiles":
			return String(technical.get("object", ""))
		&"void_tiles":
			return String(technical.get("void", ""))
		&"passage_tiles":
			return String(technical.get("passage", ""))
		&"object_scenes":
			if asset_id == &"supply_crate":
				return String(technical.get("crate", ""))
			if asset_id == &"fall_zone":
				return String(technical.get("void", ""))
			if asset_id == &"bridge_passage":
				return String(technical.get("passage", ""))
			return String(technical.get("object", ""))
		_:
			return ""

func _validate_asset_contracts(failures: PackedStringArray) -> void:
	if fallback_policy.is_empty():
		failures.append("fallback_policy section is required in manifest v7")
	elif bool(fallback_policy.get("implicit_fallback_allowed", true)):
		failures.append("fallback_policy must disable implicit fallbacks")
	for section_name in ASSET_CONTRACT_SECTIONS:
		var section := StringName(section_name)
		var section_data := asset_contracts.get(section, {}) as Dictionary
		if section_data.is_empty():
			failures.append("%s section must not be empty in manifest v7" % section_name)
			continue
		for contract_id in section_data.keys():
			_validate_asset_contract(section, section_data[contract_id] as Dictionary, failures)
	_validate_asset_coverage(failures)

func _validate_asset_contract(
	section: StringName,
	contract: Dictionary,
	failures: PackedStringArray
) -> void:
	var contract_id := String(contract.get("id", ""))
	if contract_id.is_empty():
		failures.append("%s: asset contract id must not be empty" % String(section))
	var status := String(contract.get("status", ""))
	if not ASSET_STATUSES.has(status):
		failures.append("%s/%s: unknown asset status '%s'" % [String(section), contract_id, status])
	var asset_path := String(contract.get("asset_path", ""))
	if asset_path.is_empty() and status != "deprecated":
		failures.append("%s/%s: asset_path must not be empty" % [String(section), contract_id])
	var anchor := String(contract.get("anchor", ""))
	if not ASSET_ANCHORS.has(anchor):
		failures.append("%s/%s: unknown anchor '%s'" % [String(section), contract_id, anchor])
	var footprint := contract.get("footprint_tiles", Vector2i.ZERO) as Vector2i
	if footprint.x <= 0 or footprint.y <= 0:
		failures.append("%s/%s: footprint_tiles must be positive" % [String(section), contract_id])
	var collision_shape := String(contract.get("collision_shape", ""))
	if not COLLISION_SHAPES.has(collision_shape):
		failures.append("%s/%s: unknown collision_shape '%s'" % [String(section), contract_id, collision_shape])
	for required_field in ["source", "license", "attribution_key"]:
		if String(contract.get(required_field, "")).is_empty():
			failures.append("%s/%s: %s must not be empty" % [String(section), contract_id, required_field])
	var biome_ids := contract.get("biome_ids", []) as Array
	if biome_ids.is_empty():
		failures.append("%s/%s: biome_ids must not be empty" % [String(section), contract_id])
	var fallback_path := String(contract.get("fallback_path", ""))
	if MISSING_ASSET_STATUSES.has(status) and fallback_path.is_empty():
		failures.append("%s/%s: missing assets require explicit fallback_path" % [String(section), contract_id])
	if not MISSING_ASSET_STATUSES.has(status) and not _asset_path_exists(asset_path):
		failures.append("%s/%s: asset_path does not exist for status '%s'" % [String(section), contract_id, status])

func _validate_asset_coverage(failures: PackedStringArray) -> void:
	for object_id in objects.keys():
		if not has_asset_contract(&"object_scenes", StringName(object_id)):
			failures.append("%s: object id missing object_scenes asset contract" % String(object_id))
	for terrain_id in terrain_styles.keys():
		if not has_asset_contract(&"terrain_tiles", StringName(terrain_id)):
			failures.append("%s: terrain tag missing terrain_tiles asset contract" % String(terrain_id))
	for passage_id in BiomePassageGenerator.get_generated_passage_terrain_tag_categories().keys():
		var passage_type := StringName(passage_id)
		if not has_asset_contract(&"passage_tiles", passage_type):
			failures.append("%s: passage type missing passage_tiles asset contract" % String(passage_type))
	for border_id in [&"boundary_fence", &"toxic_boundary_wall", &"lava_boundary", &"ice_boundary", &"deep_water_boundary"]:
		if not has_asset_contract(&"edge_tiles", border_id):
			failures.append("%s: border id missing edge_tiles asset contract" % String(border_id))
	for void_id in [&"fall_zone", &"void_edge_near", &"void_depth"]:
		if not has_asset_contract(&"void_tiles", void_id):
			failures.append("%s: missing void_tiles asset contract" % String(void_id))

func _asset_path_exists(asset_path: String) -> bool:
	if asset_path.is_empty():
		return false
	if ResourceLoader.exists(asset_path):
		return true
	return FileAccess.file_exists(asset_path)

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
