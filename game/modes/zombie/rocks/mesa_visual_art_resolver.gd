extends RefCounted
class_name MesaVisualArtResolver

const GENERATED_ART_CATALOG = preload(
	"res://game/modes/zombie/biome_generated_art_catalog.gd"
)
const TEXTURE_LOADER = preload(
	"res://game/modes/zombie/environment_texture_loader.gd"
)

const FOREST_PROFILE_ID: StringName = &"forest"
const LARGE_ROCK_OBJECT_ID: StringName = &"large_rock"
const ROCK_FACE_TEXTURE_ID: StringName = &"cliff_face_texture"
const TEXTURE_LOAD_SIZE := Vector2i(512, 512)
const FACE_REPEAT_WORLD_SIZE := 128.0
const TOP_REPEAT_BY_PROFILE: Dictionary = {
	&"forest": 256.0,
	&"urban_ruins": 1024.0,
	&"burning_plains": 512.0,
	&"volcanic": 512.0,
	&"frozen_tundra": 1024.0,
	&"swamp": 1024.0,
}

static func resolve(
	requested_profile_id: StringName,
	biome_id: StringName,
	generation_seed: int,
	palette: BiomePalette,
	manifest: EnvironmentAssetManifest = null
) -> Dictionary:
	var source_manifest := manifest
	if source_manifest == null:
		source_manifest = EnvironmentAssetManifest.get_shared()
	var profile_id := normalize_profile_id(requested_profile_id, biome_id)
	var top_path := ""
	var face_path := ""
	var top_texture: Texture2D = null
	var face_texture: Texture2D = null
	var top_role: StringName = &""
	var face_role: StringName = &""
	var rock_cliff_kit_id := source_manifest.get_biome_rock_cliff_kit_id(biome_id)
	var external_rock_atlas_ready := (
		not rock_cliff_kit_id.is_empty()
		and source_manifest.rock_cliff_kit_has_external_assets(rock_cliff_kit_id)
	)
	if profile_id == FOREST_PROFILE_ID:
		if external_rock_atlas_ready:
			var atlas_set := RockCliffAtlasSet.new()
			if atlas_set.configure(biome_id, source_manifest):
				var variant := posmod(
					("%d|mesa_top" % generation_seed).hash(),
					4
				)
				top_role = RockCliffTopologyResolver.TOP_ROLES[12 + variant]
				face_role = &"edge_south"
				top_texture = atlas_set.get_top_texture(top_role)
				face_texture = atlas_set.get_wall_texture(face_role)
				top_path = source_manifest.get_rock_cliff_kit_asset_path(
					rock_cliff_kit_id, &"top"
				)
				face_path = source_manifest.get_rock_cliff_kit_asset_path(
					rock_cliff_kit_id, &"wall"
				)
		elif not rock_cliff_kit_id.is_empty():
			top_path = source_manifest.get_rock_cliff_kit_fallback_path(
				rock_cliff_kit_id, &"top"
			)
			face_path = source_manifest.get_rock_cliff_kit_fallback_path(
				rock_cliff_kit_id, &"wall"
			)
		else:
			top_path = String(
				source_manifest.get_object_asset_contract(
					LARGE_ROCK_OBJECT_ID
				).get("asset_path", "")
			)
			face_path = String(
				source_manifest.get_void_asset_contract(
					ROCK_FACE_TEXTURE_ID
				).get("asset_path", "")
			)
	else:
		top_role = GENERATED_ART_CATALOG.ROLE_GROUND
		face_role = GENERATED_ART_CATALOG.ROLE_CLIFF_FACE
		top_path = _select_profile_path(
			profile_id,
			GENERATED_ART_CATALOG.ROLE_GROUND,
			generation_seed
		)
		face_path = _select_profile_path(
			profile_id,
			GENERATED_ART_CATALOG.ROLE_CLIFF_FACE,
			generation_seed
		)
	var primary := (
		palette.prop_color
		if palette != null
		else Color(0.34, 0.31, 0.27, 1.0)
	)
	var accent := (
		palette.floor_color
		if palette != null
		else Color(0.48, 0.43, 0.34, 1.0)
	)
	if top_texture == null:
		top_texture = TEXTURE_LOADER.load_texture(
			top_path, primary, accent, TEXTURE_LOAD_SIZE
		)
	if face_texture == null:
		face_texture = TEXTURE_LOADER.load_texture(
			face_path, primary, accent, TEXTURE_LOAD_SIZE
		)
	return {
		"profile_id": profile_id,
		"rock_cliff_kit_id": rock_cliff_kit_id,
		"external_rock_atlas_ready": external_rock_atlas_ready,
		"top_path": top_path,
		"face_path": face_path,
		"top_role": top_role,
		"face_role": face_role,
		"top_texture": top_texture,
		"face_texture": face_texture,
		"top_repeat_world_size": float(
			TOP_REPEAT_BY_PROFILE.get(profile_id, 256.0)
		),
		"face_repeat_world_size": FACE_REPEAT_WORLD_SIZE,
	}

static func normalize_profile_id(
	profile_id: StringName,
	biome_id: StringName
) -> StringName:
	if profile_id == FOREST_PROFILE_ID:
		return profile_id
	if not GENERATED_ART_CATALOG.get_profile_for_theme(profile_id).is_empty():
		return profile_id
	var biome_profile := GENERATED_ART_CATALOG.get_theme_id_for_biome(biome_id)
	if not biome_profile.is_empty():
		return biome_profile
	return FOREST_PROFILE_ID

static func _select_profile_path(
	profile_id: StringName,
	role: StringName,
	generation_seed: int
) -> String:
	var profile := GENERATED_ART_CATALOG.get_profile_for_theme(profile_id)
	var pool := profile.get(role, PackedStringArray()) as PackedStringArray
	if pool.is_empty():
		return ""
	var key := "%d|%s|mesa|%s" % [
		generation_seed,
		String(profile_id),
		String(role),
	]
	return pool[posmod(key.hash(), pool.size())]
