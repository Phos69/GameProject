extends RefCounted
class_name BiomeGeneratedArtCatalog

const ASSET_ROOT := "res://assets/environment/isometric/generated_images"
const EXPECTED_TOTAL_ASSET_COUNT := 195
const EXPECTED_ACTIVE_ASSET_COUNT := 133
const SURFACE_MACRO_CELL_SIZE := 8
const COHERENT_SURFACE_SAMPLE_THEMES: Array[StringName] = [
	&"frozen_tundra",
	&"swamp",
	&"urban_ruins",
	&"volcanic",
]
const REGION_COHERENT_SURFACE_SAMPLE_THEMES: Array[StringName] = [
	&"frozen_tundra",
	&"swamp",
	&"urban_ruins",
	&"volcanic",
]
const GROUND_DETAIL_POOL_THEMES: Array[StringName] = [
	&"desert",
	&"forest",
]
const ROAD_BORDER_THEME_IDS: Array[StringName] = [
	&"frozen_tundra",
	&"swamp",
	&"urban_ruins",
	&"volcanic",
]

const ROLE_GROUND: StringName = &"ground"
const ROLE_PATH: StringName = &"path"
const ROLE_ROAD: StringName = &"road"
const ROLE_GROUND_TO_PATH: StringName = &"ground_to_path"
const ROLE_GROUND_TO_ROAD: StringName = &"ground_to_road"
const ROLE_DETAIL: StringName = &"detail"
const ROLE_CLIFF_FACE: StringName = &"cliff_face"
const ROLE_CLIFF_LIP_HORIZONTAL: StringName = &"cliff_lip_horizontal"
const ROLE_CLIFF_LIP_VERTICAL: StringName = &"cliff_lip_vertical"
const ROLE_CLIFF_OUTER_CORNER: StringName = &"cliff_outer_corner"
const ROLE_CLIFF_INNER_CORNER: StringName = &"cliff_inner_corner"
const ROLE_CLIFF_CAP: StringName = &"cliff_cap"

const BIOME_THEME_IDS: Dictionary = {
	&"toxic_wastes": &"urban_ruins",
	&"burning_fields": &"volcanic",
	&"frozen_outskirts": &"frozen_tundra",
	&"drowned_marsh": &"swamp",
}
const UNASSIGNED_THEME_IDS: Array[StringName] = [&"desert", &"forest"]
const ALL_THEME_IDS: Array[StringName] = [
	&"desert",
	&"forest",
	&"frozen_tundra",
	&"swamp",
	&"urban_ruins",
	&"volcanic",
]
const SURFACE_ROLES: Array[StringName] = [
	ROLE_GROUND,
	ROLE_PATH,
	ROLE_ROAD,
	ROLE_GROUND_TO_PATH,
	ROLE_GROUND_TO_ROAD,
	ROLE_DETAIL,
]
const CLIFF_ROLES: Array[StringName] = [
	ROLE_CLIFF_FACE,
	ROLE_CLIFF_LIP_HORIZONTAL,
	ROLE_CLIFF_LIP_VERTICAL,
	ROLE_CLIFF_OUTER_CORNER,
	ROLE_CLIFF_INNER_CORNER,
	ROLE_CLIFF_CAP,
]

static var _profiles: Dictionary = {}

static func has_generated_theme(biome_id: StringName) -> bool:
	return not get_theme_id_for_biome(biome_id).is_empty()

static func get_theme_id_for_biome(biome_id: StringName) -> StringName:
	var contract := (
		IsometricEnvironmentManifest.get_shared()
		.get_biome_asset_set_contract(biome_id)
	)
	return StringName(contract.get("generated_theme_id", &""))

static func get_unassigned_theme_ids() -> Array[StringName]:
	return UNASSIGNED_THEME_IDS.duplicate()

static func get_profile_for_biome(biome_id: StringName) -> Dictionary:
	var theme_id := get_theme_id_for_biome(biome_id)
	if theme_id.is_empty():
		return {}
	return get_profile_for_theme(theme_id)

static func get_profile_for_theme(theme_id: StringName) -> Dictionary:
	_ensure_profiles()
	return (_profiles.get(theme_id, {}) as Dictionary).duplicate(true)

static func get_asset_paths_for_role(
	biome_id: StringName,
	role: StringName
) -> PackedStringArray:
	var profile := get_profile_for_biome(biome_id)
	return (profile.get(role, PackedStringArray()) as PackedStringArray).duplicate()

static func get_all_surface_asset_paths(
	biome_id: StringName
) -> PackedStringArray:
	var result := PackedStringArray()
	for role in SURFACE_ROLES:
		result.append_array(get_asset_paths_for_role(biome_id, role))
	return result

static func get_all_cliff_asset_paths(
	biome_id: StringName
) -> PackedStringArray:
	var result := PackedStringArray()
	for role in CLIFF_ROLES:
		result.append_array(get_asset_paths_for_role(biome_id, role))
	return result

static func get_all_asset_paths_for_theme(
	theme_id: StringName
) -> PackedStringArray:
	var profile := get_profile_for_theme(theme_id)
	var result := PackedStringArray()
	for role in SURFACE_ROLES:
		result.append_array(
			(profile.get(role, PackedStringArray()) as PackedStringArray)
		)
	for role in CLIFF_ROLES:
		result.append_array(
			(profile.get(role, PackedStringArray()) as PackedStringArray)
		)
	return result

static func get_asset_descriptor(
	biome_id: StringName,
	asset_path: String
) -> Dictionary:
	var profile := get_profile_for_biome(biome_id)
	var resolved_role: StringName = &""
	for role in SURFACE_ROLES:
		if (
			profile.get(role, PackedStringArray()) as PackedStringArray
		).has(asset_path):
			resolved_role = role
			break
	if resolved_role.is_empty():
		for role in CLIFF_ROLES:
			if (
				profile.get(role, PackedStringArray()) as PackedStringArray
			).has(asset_path):
				resolved_role = role
				break
	if resolved_role.is_empty():
		return {}
	var set_contract := (
		IsometricEnvironmentManifest.get_shared()
		.get_biome_asset_set_contract(biome_id)
	)
	return {
		&"asset_path": asset_path,
		&"material_asset_id": material_id_from_path(asset_path),
		&"theme_id": get_theme_id_for_biome(biome_id),
		&"role": resolved_role,
		&"status": String(set_contract.get("status", "")),
		&"source": String(set_contract.get("source", "")),
		&"license": String(set_contract.get("license", "")),
		&"attribution_key": String(
			set_contract.get("attribution_key", "")
		),
	}

static func get_total_asset_count() -> int:
	var unique: Dictionary = {}
	for theme_id in ALL_THEME_IDS:
		for asset_path in get_all_asset_paths_for_theme(theme_id):
			unique[asset_path] = true
	return unique.size()

static func get_active_asset_count() -> int:
	var unique: Dictionary = {}
	for biome_id in BIOME_THEME_IDS:
		for asset_path in get_all_surface_asset_paths(StringName(biome_id)):
			unique[asset_path] = true
		for asset_path in get_all_cliff_asset_paths(StringName(biome_id)):
			unique[asset_path] = true
	return unique.size()

static func select_surface_asset_path(
	biome_id: StringName,
	role: StringName,
	generation_seed: int,
	cell: Vector2i
) -> String:
	var pool := _surface_pool(biome_id, role)
	if pool.is_empty():
		return ""
	var sample_cell := cell
	var theme_id := get_theme_id_for_biome(biome_id)
	if REGION_COHERENT_SURFACE_SAMPLE_THEMES.has(theme_id):
		sample_cell = Vector2i.ZERO
	elif role == ROLE_GROUND or COHERENT_SURFACE_SAMPLE_THEMES.has(theme_id):
		sample_cell = Vector2i(
			floori(float(cell.x) / float(SURFACE_MACRO_CELL_SIZE)),
			floori(float(cell.y) / float(SURFACE_MACRO_CELL_SIZE))
		)
	var key := "%d|%s|%s|%d|%d" % [
		generation_seed,
		String(biome_id),
		String(role),
		sample_cell.x,
		sample_cell.y,
	]
	return pool[posmod(key.hash(), pool.size())]

static func resolve_runtime_surface_role(
	biome_id: StringName,
	role: StringName
) -> StringName:
	if (
		biome_id != &"toxic_wastes"
		and biome_id != &"burning_fields"
		and biome_id != &"frozen_outskirts"
		and biome_id != &"drowned_marsh"
	):
		return role
	match role:
		ROLE_GROUND_TO_PATH:
			return ROLE_PATH
		_:
			return role

static func select_cliff_asset_path(
	biome_id: StringName,
	role: StringName,
	generation_seed: int,
	variant_key: int = 0
) -> String:
	var pool := get_asset_paths_for_role(biome_id, role)
	if pool.is_empty():
		return ""
	var key := "%d|%s|%s|%d" % [
		generation_seed,
		String(biome_id),
		String(role),
		variant_key,
	]
	return pool[posmod(key.hash(), pool.size())]

static func material_id_from_path(asset_path: String) -> StringName:
	if asset_path.is_empty():
		return &""
	return StringName(asset_path.get_file().get_basename())

static func validate_catalog() -> PackedStringArray:
	var failures := PackedStringArray()
	_ensure_profiles()
	if get_total_asset_count() != EXPECTED_TOTAL_ASSET_COUNT:
		failures.append(
			"generated asset catalog expected %d files, found %d"
			% [EXPECTED_TOTAL_ASSET_COUNT, get_total_asset_count()]
		)
	if get_active_asset_count() != EXPECTED_ACTIVE_ASSET_COUNT:
		failures.append(
			"active generated asset catalog expected %d files, found %d"
			% [EXPECTED_ACTIVE_ASSET_COUNT, get_active_asset_count()]
		)
	for theme_id in ALL_THEME_IDS:
		var profile := get_profile_for_theme(theme_id)
		for role in SURFACE_ROLES:
			if (
				(role == ROLE_PATH or role == ROLE_ROAD)
				and UNASSIGNED_THEME_IDS.has(theme_id)
			):
				continue
			if (profile.get(role, PackedStringArray()) as PackedStringArray).is_empty():
				failures.append("%s has no %s assets" % [String(theme_id), String(role)])
		for role in CLIFF_ROLES:
			if (profile.get(role, PackedStringArray()) as PackedStringArray).is_empty():
				failures.append("%s has no %s assets" % [String(theme_id), String(role)])
		for asset_path in get_all_asset_paths_for_theme(theme_id):
			if not FileAccess.file_exists(asset_path):
				failures.append("generated asset missing: %s" % asset_path)
	for biome_id_value in BIOME_THEME_IDS:
		var biome_id := biome_id_value as StringName
		var set_contract := (
			IsometricEnvironmentManifest.get_shared()
			.get_biome_asset_set_contract(biome_id)
		)
		if (
			set_contract.get("generated_surface_roles", []) as Array
		) != SURFACE_ROLES:
			failures.append(
				"%s generated surface pool contract is out of sync"
				% String(biome_id)
			)
		if (
			set_contract.get("generated_cliff_roles", []) as Array
		) != CLIFF_ROLES:
			failures.append(
				"%s generated cliff pool contract is out of sync"
				% String(biome_id)
			)
		for asset_path in get_all_surface_asset_paths(biome_id):
			_validate_active_descriptor(
				failures,
				get_asset_descriptor(biome_id, asset_path)
			)
		for asset_path in get_all_cliff_asset_paths(biome_id):
			_validate_active_descriptor(
				failures,
				get_asset_descriptor(biome_id, asset_path)
			)
	return failures

static func _validate_active_descriptor(
	failures: PackedStringArray,
	descriptor: Dictionary
) -> void:
	var asset_path := String(descriptor.get(&"asset_path", ""))
	if (
		asset_path.is_empty()
		or String(descriptor.get(&"status", "")) != "final"
		or String(descriptor.get(&"source", "")).is_empty()
		or String(descriptor.get(&"license", "")).is_empty()
	):
		failures.append(
			"active generated asset has incomplete metadata: %s"
			% asset_path
		)

static func _surface_pool(
	biome_id: StringName,
	role: StringName
) -> PackedStringArray:
	var resolved_role := role
	if role == &"path_to_road":
		resolved_role = ROLE_GROUND_TO_ROAD
	var pool := get_asset_paths_for_role(biome_id, resolved_role)
	if resolved_role == ROLE_GROUND and _ground_pool_accepts_detail(biome_id):
		pool.append_array(get_asset_paths_for_role(biome_id, ROLE_DETAIL))
	if pool.is_empty() and resolved_role != ROLE_GROUND:
		pool = get_asset_paths_for_role(biome_id, ROLE_GROUND)
	return pool

static func _ground_pool_accepts_detail(biome_id: StringName) -> bool:
	return GROUND_DETAIL_POOL_THEMES.has(get_theme_id_for_biome(biome_id))

static func _ensure_profiles() -> void:
	if not _profiles.is_empty():
		return
	for theme_id in ALL_THEME_IDS:
		_profiles[theme_id] = _build_profile(theme_id)

static func _build_profile(theme_id: StringName) -> Dictionary:
	var profile := {
		&"theme_id": theme_id,
		ROLE_GROUND: PackedStringArray(),
		ROLE_PATH: PackedStringArray(),
		ROLE_ROAD: PackedStringArray(),
		ROLE_GROUND_TO_PATH: PackedStringArray(),
		ROLE_GROUND_TO_ROAD: PackedStringArray(),
		ROLE_DETAIL: PackedStringArray(),
		ROLE_CLIFF_FACE: PackedStringArray(),
		ROLE_CLIFF_LIP_HORIZONTAL: PackedStringArray(),
		ROLE_CLIFF_LIP_VERTICAL: PackedStringArray(),
		ROLE_CLIFF_OUTER_CORNER: PackedStringArray(),
		ROLE_CLIFF_INNER_CORNER: PackedStringArray(),
		ROLE_CLIFF_CAP: PackedStringArray(),
	}
	_append_directory_assets(
		ASSET_ROOT.path_join("terrain").path_join(String(theme_id)),
		profile,
		false
	)
	_append_directory_assets(
		ASSET_ROOT.path_join("cliff").path_join(String(theme_id)),
		profile,
		true
	)
	return profile

static func _append_directory_assets(
	directory_path: String,
	profile: Dictionary,
	cliff_assets: bool
) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return
	var file_names := PackedStringArray()
	for file_name in directory.get_files():
		if file_name.to_lower().ends_with(".png"):
			file_names.append(file_name)
	file_names.sort()
	for file_name in file_names:
		var theme_id := StringName(profile.get(&"theme_id", &""))
		var role := (
			_cliff_role_for_file(file_name)
			if cliff_assets
			else _surface_role_for_file(theme_id, file_name)
		)
		if role.is_empty():
			continue
		var paths := profile.get(role, PackedStringArray()) as PackedStringArray
		paths.append(directory_path.path_join(file_name))
		profile[role] = paths

static func _surface_role_for_file(
	theme_id: StringName,
	file_name: String
) -> StringName:
	if (
		theme_id == &"frozen_tundra"
		and (
			file_name.contains("base_ground_variation_02")
			or file_name.contains("base_ground_variation_03")
			or file_name.contains("base_ground_variation_04")
		)
	):
		return ROLE_DETAIL
	if (
		theme_id == &"swamp"
		and (
			file_name.contains("base_ground_variation_02")
			or file_name.contains("base_ground_variation_03")
		)
	):
		return ROLE_DETAIL
	if (
		theme_id == &"volcanic"
		and (
			file_name.contains("base_ground_variation_01")
			or file_name.contains("base_ground_variation_03")
			or file_name.contains("base_ground_variation_04")
		)
	):
		return ROLE_DETAIL
	if (
		theme_id == &"urban_ruins"
		and (
			file_name.contains("base_ground_variation_01")
			or file_name.contains("base_ground_variation_04")
		)
	):
		# The light lichen sheet (01) and the brown gravel (04) contrast too much
		# with the grey rubble pair: at macro-cell granularity they read as a
		# checkerboard of panels (ART-VIS-FIX, VIS-002). Keep the tonally close
		# rubble variants (02/03) as the base surface.
		return ROLE_DETAIL
	if file_name.contains("transition_ground_to_path"):
		return ROLE_GROUND_TO_PATH
	if file_name.contains("road_border_defined"):
		return ROLE_GROUND_TO_ROAD
	if file_name.contains("transition_ground_to_road"):
		if ROAD_BORDER_THEME_IDS.has(theme_id):
			return ROLE_DETAIL
		return ROLE_GROUND_TO_ROAD
	if file_name.contains("base_ground_variation"):
		return ROLE_GROUND
	if file_name.contains("path_variation"):
		return ROLE_PATH
	if file_name.contains("road_variation"):
		return ROLE_ROAD
	if file_name.contains("detail_decal"):
		return ROLE_DETAIL
	return &""

static func _cliff_role_for_file(file_name: String) -> StringName:
	if file_name.contains("cliff_face"):
		return ROLE_CLIFF_FACE
	if file_name.contains("horizontal_top_edge"):
		return ROLE_CLIFF_LIP_HORIZONTAL
	if file_name.contains("vertical_top_edge"):
		return ROLE_CLIFF_LIP_VERTICAL
	if file_name.contains("outer_corner"):
		return ROLE_CLIFF_OUTER_CORNER
	if file_name.contains("inner_corner"):
		return ROLE_CLIFF_INNER_CORNER
	if file_name.contains("short_lip_cap"):
		return ROLE_CLIFF_CAP
	return &""
