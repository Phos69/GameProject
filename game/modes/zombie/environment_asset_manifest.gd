extends RefCounted
class_name EnvironmentAssetManifest

const WorldGridConfig = preload("res://game/core/world_grid_config.gd")
const RESOLVER_UTILS := preload(
	"res://game/modes/zombie/biome_tile_resolver_utils.gd"
)

## Loader and validator for the top-down environment asset manifest.
##
## The manifest is the single source of truth for how environment objects are
## converted to the orthogonal top-down pipeline: collision shape, footprint,
## blocking flags, procedural draw mode, asset contract and ground sort offset.
## Manifest v16 separates placement footprint from physical collision, supports
## contextual and deterministic-random asset variants, and keeps object
## orientation cardinal.
## Missing art is allowed only when the entry explicitly declares a fallback or
## a needs_asset/procedural_fallback status.

const MANIFEST_PATH: String = "res://assets/environment/top_down/manifest.json"
const EXPECTED_COORDINATE_SYSTEM: String = "orthogonal_top_down"
const EXPECTED_VOLUME_STYLE: String = "controlled_perspective"
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
	"forest_grass",
	"forest_path",
	"forest_road",
	"forest_tall_grass",
	"forest_transition",
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
	"dense_vegetation",
	"fence",
	"forest_mountain_wall",
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
	"floor_center",
	"edge_aligned"
]

static var _cached: EnvironmentAssetManifest

var version: int = 0
var coordinate_system: String = ""
var volume_style: String = ""
var default_sort_offset: float = 0.0
var footprint_slot_size_cells: Vector2i = Vector2i(4, 4)
var asset_contract_defaults: Dictionary = {}
var fallback_policy: Dictionary = {}
var asset_contracts: Dictionary = {}
var objects: Dictionary = {}
var object_visual_styles: Dictionary = {}
var terrain_styles: Dictionary = {}
var terrain_sample_step_presets: Dictionary = {}
var conversion_backlog: Array[StringName] = []
var load_error: String = ""

static func get_shared() -> EnvironmentAssetManifest:
	if _cached == null:
		_cached = EnvironmentAssetManifest.new()
		_cached.load_from_disk()
	return _cached

static func reload_shared() -> EnvironmentAssetManifest:
	_cached = null
	return get_shared()

static func clear_shared() -> void:
	if _cached != null:
		_cached._clear_loaded_data()
	_cached = null

func load_from_disk(path: String = MANIFEST_PATH) -> bool:
	_clear_loaded_data()
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
	volume_style = String(data.get("volume_style", ""))
	var footprint_contract := data.get("obstacle_footprint", {}) as Dictionary
	var slot_values := footprint_contract.get("slot_size_cells", [4, 4]) as Array
	if slot_values.size() >= 2:
		footprint_slot_size_cells = Vector2i(
			maxi(int(slot_values[0]), 1),
			maxi(int(slot_values[1]), 1)
		)
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

func _clear_loaded_data() -> void:
	version = 0
	coordinate_system = ""
	volume_style = ""
	default_sort_offset = 0.0
	footprint_slot_size_cells = Vector2i(4, 4)
	asset_contract_defaults.clear()
	fallback_policy.clear()
	asset_contracts.clear()
	objects.clear()
	object_visual_styles.clear()
	terrain_styles.clear()
	terrain_sample_step_presets.clear()
	conversion_backlog.clear()
	load_error = ""

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

func get_object_asset_path(
	object_id: StringName,
	variant_id: StringName = &""
) -> String:
	var contract := get_object_asset_contract(object_id)
	var variants := contract.get("variant_asset_paths", {}) as Dictionary
	if not variant_id.is_empty() and variants.has(variant_id):
		return String(variants[variant_id])
	return String(contract.get("asset_path", ""))

func get_object_random_variant_ids(
	object_id: StringName,
	context_id: StringName
) -> Array[StringName]:
	var contract := get_object_asset_contract(object_id)
	var contexts := contract.get("random_variant_ids_by_context", {}) as Dictionary
	if contexts.has(context_id):
		return (contexts[context_id] as Array[StringName]).duplicate()
	return []

func get_object_visual_scale(
	object_id: StringName,
	variant_id: StringName = &""
) -> float:
	var contract := get_object_asset_contract(object_id)
	var variants := contract.get("variant_visual_scales", {}) as Dictionary
	if not variant_id.is_empty() and variants.has(variant_id):
		return maxf(float(variants[variant_id]), 0.01)
	return get_visual_scale(object_id)

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

func get_footprint_tiles(object_id: StringName) -> Vector2i:
	if objects.has(object_id):
		return (objects[object_id] as Dictionary).get(
			"footprint_tiles", Vector2i.ONE
		) as Vector2i
	return Vector2i.ONE

func get_footprint_slots(object_id: StringName) -> Vector2i:
	if objects.has(object_id):
		return (objects[object_id] as Dictionary).get(
			"footprint_slots", Vector2i.ONE
		) as Vector2i
	return Vector2i.ONE

func get_footprint_slot_size_cells() -> Vector2i:
	return footprint_slot_size_cells

func get_visual_height_tiles(object_id: StringName) -> int:
	if objects.has(object_id):
		return int((objects[object_id] as Dictionary).get("visual_height_tiles", 0))
	return 0

func get_entrance_side(object_id: StringName) -> StringName:
	if objects.has(object_id):
		return (objects[object_id] as Dictionary).get(
			"entrance_side", &"south"
		) as StringName
	return &"south"

func get_entrance_offset_tiles(object_id: StringName) -> Vector2i:
	if objects.has(object_id):
		var value := (objects[object_id] as Dictionary).get(
			"entrance_offset_tiles", Vector2.ZERO
		) as Vector2
		return Vector2i(roundi(value.x), roundi(value.y))
	return Vector2i.ZERO

func get_visual_scale(object_id: StringName) -> float:
	if objects.has(object_id):
		return float((objects[object_id] as Dictionary).get("visual_scale", 1.0))
	return 1.0

func get_native_visual_size(
	object_id: StringName,
	logical_tile_scale: float = WorldGridConfig.LEGACY_TILE_SCALE,
	variant_id: StringName = &""
) -> Vector2:
	var footprint := get_footprint_tiles(object_id)
	var visual_height := get_visual_height_tiles(object_id)
	var native_size := Vector2(
		maxf(float(footprint.x) * logical_tile_scale * 1.55, 56.0),
		maxf(float(footprint.y + visual_height) * logical_tile_scale, 56.0)
	)
	return native_size * get_object_visual_scale(object_id, variant_id)

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

func get_collision_size_ratio(
	object_id: StringName,
	variant_id: StringName = &""
) -> Vector2:
	if not variant_id.is_empty():
		var contract := get_object_asset_contract(object_id)
		var variants := contract.get("variant_collision_size_ratios", {}) as Dictionary
		if variants.has(variant_id):
			return variants[variant_id] as Vector2
	if objects.has(object_id):
		return (objects[object_id] as Dictionary).get(
			"collision_size_ratio", Vector2.ONE
		) as Vector2
	return Vector2.ONE

func get_collision_offset_ratio(
	object_id: StringName,
	variant_id: StringName = &""
) -> Vector2:
	if not variant_id.is_empty():
		var contract := get_object_asset_contract(object_id)
		var variants := contract.get("variant_collision_offset_ratios", {}) as Dictionary
		if variants.has(variant_id):
			return variants[variant_id] as Vector2
	if objects.has(object_id):
		return (objects[object_id] as Dictionary).get(
			"collision_offset_ratio", Vector2.ZERO
		) as Vector2
	return Vector2.ZERO

func is_jumpable_gap_anchor(object_id: StringName) -> bool:
	if objects.has(object_id):
		return bool((objects[object_id] as Dictionary).get("is_jumpable_gap_anchor", false))
	return false

func is_scalable(object_id: StringName) -> bool:
	# Scalable objects (e.g. rocks) are placed at a per-instance square footprint
	# instead of the fixed manifest footprint, so their art and collision adapt to
	# the instance size. They are exempt from the slot-size footprint rule.
	if objects.has(object_id):
		return bool((objects[object_id] as Dictionary).get("scalable", false))
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
	if coordinate_system != EXPECTED_COORDINATE_SYSTEM:
		failures.append(
			"manifest coordinate_system must be '%s', got '%s'"
			% [EXPECTED_COORDINATE_SYSTEM, coordinate_system]
		)
	if volume_style != EXPECTED_VOLUME_STYLE:
		failures.append(
			"manifest volume_style must be '%s', got '%s'"
			% [EXPECTED_VOLUME_STYLE, volume_style]
		)
	if footprint_slot_size_cells.x <= 0 or footprint_slot_size_cells.y <= 0:
		failures.append("obstacle_footprint.slot_size_cells must be positive")
	if version >= 7:
		_validate_asset_contracts(failures)
	for object_id in objects.keys():
		var entry := objects[object_id] as Dictionary
		var collision_shape := String(entry.get("collision_shape", ""))
		if not COLLISION_SHAPES.has(collision_shape):
			failures.append("%s: unknown collision_shape '%s'" % [object_id, collision_shape])
		var collision_size_ratio := entry.get(
			"collision_size_ratio", Vector2.ONE
		) as Vector2
		if (
			collision_size_ratio.x <= 0.0
			or collision_size_ratio.y <= 0.0
			or collision_size_ratio.x > 3.0
			or collision_size_ratio.y > 3.0
		):
			failures.append(
				"%s: collision_size_ratio must stay within (0, 3]" % object_id
			)
		var collision_offset_ratio := entry.get(
			"collision_offset_ratio", Vector2.ZERO
		) as Vector2
		if absf(collision_offset_ratio.x) > 1.0 or absf(collision_offset_ratio.y) > 1.0:
			failures.append(
				"%s: collision_offset_ratio must stay within [-1, 1]" % object_id
			)
		var footprint := entry.get("footprint_tiles", Vector2i.ZERO) as Vector2i
		if footprint.x <= 0 or footprint.y <= 0:
			failures.append("%s: footprint_tiles must be positive" % object_id)
		var footprint_slots := entry.get("footprint_slots", Vector2i.ZERO) as Vector2i
		if footprint_slots.x <= 0 or footprint_slots.y <= 0:
			failures.append("%s: footprint_slots must be positive" % object_id)
		if (
			version >= 9
			and StringName(entry.get("category", &"obstacle")) not in [&"border", &"cliff", &"passage"]
			and not bool(entry.get("scalable", false))
			and footprint != Vector2i(
				footprint_slots.x * footprint_slot_size_cells.x,
				footprint_slots.y * footprint_slot_size_cells.y
			)
		):
			failures.append(
				"%s: footprint_tiles must equal footprint_slots * slot_size_cells"
				% object_id
			)
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
		"attribution_key": String(defaults.get("attribution_key", "environment_top_down_internal")),
		"anchor": StringName(str(defaults.get("anchor", "floor_center"))),
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
		"variant_asset_paths": _normalize_path_dictionary(
			entry.get("variant_asset_paths", {})
		),
		"random_variant_ids_by_context": _normalize_string_name_array_dictionary(
			entry.get("random_variant_ids_by_context", {})
		),
		"variant_visual_scales": _normalize_scale_dictionary(
			entry.get("variant_visual_scales", {})
		),
		"variant_collision_size_ratios": _normalize_vector2_dictionary(
			entry.get("variant_collision_size_ratios", {}),
			Vector2.ONE
		),
		"variant_collision_offset_ratios": _normalize_vector2_dictionary(
			entry.get("variant_collision_offset_ratios", {}),
			Vector2.ZERO
		),
		"render_mode": StringName(str(entry.get("render_mode", "sprite"))),
		"status": String(entry.get("status", asset_contract_defaults.get("status", "needs_asset"))),
		"biome_ids": _normalize_string_name_array(
			entry.get("biome_ids", asset_contract_defaults.get("biome_ids", ["shared"]))
		),
		"footprint_tiles": _resolve_contract_footprint(section, entry, legacy_object),
		"footprint_slots": _resolve_contract_footprint_slots(section, entry, legacy_object),
		"visual_height_tiles": int(entry.get(
			"visual_height_tiles",
			legacy_object.get("visual_height_tiles", 0)
		)),
		"anchor": StringName(str(entry.get("anchor", asset_contract_defaults.get("anchor", &"floor_center")))),
		"sort_offset": float(entry.get("sort_offset", _resolve_contract_sort_offset(section, legacy_object))),
		"collision_shape": String(entry.get("collision_shape", _resolve_contract_collision_shape(section, legacy_object))),
		"collision_size_ratio": _normalize_vector2(
			entry.get(
				"collision_size_ratio",
				legacy_object.get("collision_size_ratio", Vector2.ONE)
			),
			Vector2.ONE
		),
		"collision_offset_ratio": _normalize_vector2(
			entry.get(
				"collision_offset_ratio",
				legacy_object.get("collision_offset_ratio", Vector2.ZERO)
			),
			Vector2.ZERO
		),
		"blocks_movement": bool(entry.get("blocks_movement", _resolve_contract_blocks_movement(section, legacy_object))),
		"blocks_projectiles": bool(entry.get("blocks_projectiles", _resolve_contract_blocks_projectiles(section, legacy_object))),
		"source": String(entry.get("source", asset_contract_defaults.get("source", "internal_generated"))),
		"license": String(entry.get("license", asset_contract_defaults.get("license", "Project original"))),
		"attribution_key": String(entry.get("attribution_key", asset_contract_defaults.get("attribution_key", "environment_top_down_internal"))),
		"fallback_path": String(entry.get("fallback_path", default_fallback)),
		"fallback_reason": String(entry.get("fallback_reason", terrain_style.get("fallback", ""))),
		"tile_set": StringName(str(entry.get("tile_set", ""))),
		"generated_theme_id": StringName(str(entry.get("generated_theme_id", ""))),
		"generated_surface_roles": _normalize_string_name_array(
			entry.get("generated_surface_roles", [])
		),
		"generated_cliff_roles": _normalize_string_name_array(
			entry.get("generated_cliff_roles", [])
		),
		"terrain_tiles": _normalize_string_name_array(entry.get("terrain_tiles", [])),
		"object_scenes": _normalize_string_name_array(entry.get("object_scenes", [])),
		"edge_tiles": _normalize_string_name_array(entry.get("edge_tiles", [])),
		"void_tiles": _normalize_string_name_array(entry.get("void_tiles", [])),
		"passage_tiles": _normalize_string_name_array(entry.get("passage_tiles", []))
	}

func _normalize_string_name_array(value: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if value is Array:
		for item in value as Array:
			result.append(StringName(str(item)))
	elif value != null:
		result.append(StringName(str(value)))
	return result

func _normalize_path_dictionary(value: Variant) -> Dictionary:
	var result := {}
	if not value is Dictionary:
		return result
	for key in (value as Dictionary).keys():
		result[StringName(str(key))] = String((value as Dictionary).get(key, ""))
	return result

func _normalize_string_name_array_dictionary(value: Variant) -> Dictionary:
	var result := {}
	if not value is Dictionary:
		return result
	for key in (value as Dictionary).keys():
		result[StringName(str(key))] = _normalize_string_name_array(
			(value as Dictionary).get(key, [])
		)
	return result

func _normalize_scale_dictionary(value: Variant) -> Dictionary:
	var result := {}
	if not value is Dictionary:
		return result
	for key in (value as Dictionary).keys():
		result[StringName(str(key))] = float((value as Dictionary).get(key, 1.0))
	return result

func _normalize_vector2_dictionary(value: Variant, default_value: Vector2) -> Dictionary:
	var result := {}
	if not value is Dictionary:
		return result
	for key in (value as Dictionary).keys():
		result[StringName(str(key))] = _normalize_vector2(
			(value as Dictionary).get(key, default_value),
			default_value
		)
	return result

func _normalize_vector2(value: Variant, default_value: Vector2) -> Vector2:
	if value is Vector2:
		return value as Vector2
	if value is Array:
		var values := value as Array
		if values.size() >= 2:
			return Vector2(float(values[0]), float(values[1]))
	return default_value

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

func _resolve_contract_footprint_slots(
	section: StringName,
	entry: Dictionary,
	legacy_object: Dictionary
) -> Vector2i:
	if entry.has("footprint_slots"):
		var values := entry.get("footprint_slots", [1, 1]) as Array
		if values.size() >= 2:
			return Vector2i(maxi(int(values[0]), 1), maxi(int(values[1]), 1))
	if legacy_object.has("footprint_slots"):
		return legacy_object.get("footprint_slots", Vector2i.ONE) as Vector2i
	var footprint := _resolve_contract_footprint(section, entry, legacy_object)
	return Vector2i(
		maxi(ceili(float(footprint.x) / float(footprint_slot_size_cells.x)), 1),
		maxi(ceili(float(footprint.y) / float(footprint_slot_size_cells.y)), 1)
	)

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
	if not MISSING_ASSET_STATUSES.has(status) and not RESOLVER_UTILS.asset_path_exists(asset_path):
		failures.append("%s/%s: asset_path does not exist for status '%s'" % [String(section), contract_id, status])
	var variant_asset_paths := contract.get("variant_asset_paths", {}) as Dictionary
	var random_variant_contexts := contract.get(
		"random_variant_ids_by_context", {}
	) as Dictionary
	var variant_visual_scales := contract.get("variant_visual_scales", {}) as Dictionary
	var variant_collision_size_ratios := contract.get("variant_collision_size_ratios", {}) as Dictionary
	var variant_collision_offset_ratios := contract.get("variant_collision_offset_ratios", {}) as Dictionary
	for variant_id in variant_asset_paths.keys():
		var variant_path := String(variant_asset_paths[variant_id])
		if String(variant_id).is_empty() or variant_path.is_empty():
			failures.append("%s/%s: variant asset id/path must not be empty" % [String(section), contract_id])
		elif not RESOLVER_UTILS.asset_path_exists(variant_path):
			failures.append("%s/%s: variant asset path does not exist for '%s'" % [String(section), contract_id, String(variant_id)])
		if variant_visual_scales.has(variant_id) and float(variant_visual_scales[variant_id]) <= 0.0:
			failures.append("%s/%s: variant visual scale must be positive for '%s'" % [String(section), contract_id, String(variant_id)])
	for variant_id in variant_visual_scales.keys():
		if not variant_asset_paths.has(variant_id):
			failures.append("%s/%s: visual scale has no asset variant for '%s'" % [String(section), contract_id, String(variant_id)])
	for variant_id in variant_collision_size_ratios.keys():
		if not variant_asset_paths.has(variant_id):
			failures.append("%s/%s: collision size ratio has no asset variant for '%s'" % [String(section), contract_id, String(variant_id)])
		var ratio := variant_collision_size_ratios[variant_id] as Vector2
		if ratio.x <= 0.0 or ratio.y <= 0.0 or ratio.x > 3.0 or ratio.y > 3.0:
			failures.append("%s/%s: variant collision_size_ratio must stay within (0, 3] for '%s'" % [String(section), contract_id, String(variant_id)])
	for variant_id in variant_collision_offset_ratios.keys():
		if not variant_asset_paths.has(variant_id):
			failures.append("%s/%s: collision offset ratio has no asset variant for '%s'" % [String(section), contract_id, String(variant_id)])
		var offset := variant_collision_offset_ratios[variant_id] as Vector2
		if absf(offset.x) > 1.0 or absf(offset.y) > 1.0:
			failures.append("%s/%s: variant collision_offset_ratio must stay within [-1, 1] for '%s'" % [String(section), contract_id, String(variant_id)])
	for context_id in random_variant_contexts.keys():
		var random_variant_ids := random_variant_contexts[context_id] as Array[StringName]
		if String(context_id).is_empty() or random_variant_ids.is_empty():
			failures.append(
				"%s/%s: random variant context/id list must not be empty"
				% [String(section), contract_id]
			)
		for variant_id in random_variant_ids:
			if not variant_asset_paths.has(variant_id):
				failures.append(
					"%s/%s: random variant context '%s' references missing asset variant '%s'"
					% [String(section), contract_id, String(context_id), String(variant_id)]
				)

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
	for border_id in [&"boundary_fence", &"forest_mountain_wall", &"toxic_boundary_wall", &"lava_boundary", &"ice_boundary", &"deep_water_boundary"]:
		if not has_asset_contract(&"edge_tiles", border_id):
			failures.append("%s: border id missing edge_tiles asset contract" % String(border_id))
	for void_id in [
		&"fall_zone",
		&"void_edge_near",
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
		&"void_diagonal_north_west_south_east",
		&"forest_void",
		&"forest_cliff_edge",
		&"cliff_lip_north",
		&"cliff_lip_south",
		&"cliff_lip_east",
		&"cliff_lip_west",
		&"void_depth",
		&"void_vertical_lines"
	]:
		if not has_asset_contract(&"void_tiles", void_id):
			failures.append("%s: missing void_tiles asset contract" % String(void_id))

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
	var footprint_slots := Vector2i(
		maxi(ceili(float(footprint.x) / float(footprint_slot_size_cells.x)), 1),
		maxi(ceili(float(footprint.y) / float(footprint_slot_size_cells.y)), 1)
	)
	if entry.has("footprint_slots"):
		var slot_values := entry.get("footprint_slots", [1, 1]) as Array
		if slot_values.size() >= 2:
			footprint_slots = Vector2i(
				maxi(int(slot_values[0]), 1),
				maxi(int(slot_values[1]), 1)
			)
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
		"collision_size_ratio": _normalize_vector2(
			entry.get("collision_size_ratio", Vector2.ONE),
			Vector2.ONE
		),
		"collision_offset_ratio": _normalize_vector2(
			entry.get("collision_offset_ratio", Vector2.ZERO),
			Vector2.ZERO
		),
		"footprint_tiles": footprint,
		"footprint_slots": footprint_slots,
		"visual_height_tiles": maxi(int(entry.get("visual_height_tiles", 0)), 0),
		"entrance_side": StringName(str(entry.get("entrance_side", "south"))),
		"entrance_offset_tiles": _normalize_vector2(
			entry.get("entrance_offset_tiles", Vector2.ZERO),
			Vector2.ZERO
		),
		"visual_scale": maxf(float(entry.get("visual_scale", 1.0)), 0.01),
		"blocks_movement": bool(entry.get("blocks_movement", true)),
		"blocks_projectiles": bool(entry.get("blocks_projectiles", true)),
		"is_jumpable_gap_anchor": bool(entry.get("is_jumpable_gap_anchor", false)),
		"scalable": bool(entry.get("scalable", false)),
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
