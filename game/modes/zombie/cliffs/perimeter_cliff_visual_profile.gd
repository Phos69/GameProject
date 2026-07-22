extends RefCounted
class_name PerimeterCliffVisualProfile

const TEXTURE_LOADER := preload(
	"res://game/modes/zombie/environment_texture_loader.gd"
)
const GENERATED_ART_CATALOG := preload(
	"res://game/modes/zombie/biome_generated_art_catalog.gd"
)
const GENERATED_TEXTURE_TOOLS := preload(
	"res://game/modes/zombie/generated_biome_texture_tools.gd"
)
const FACE_TEXTURE_ID := &"cliff_face_texture"
const TOP_OBJECT_ID := &"large_rock"
const TEXTURE_SIZE := Vector2i(512, 512)

var style: StringName = BiomeEnvironmentLayout.PERIMETER_VISUAL_WALL
var side: StringName = &""
var uv_origin: Vector2 = Vector2.ZERO
var wall_height: float = 0.0
var face_texture: Texture2D
var top_texture: Texture2D
var face_draw_texture: Texture2D
var top_draw_texture: Texture2D
var face_uv_rect: Rect2 = Rect2()
var top_uv_rect: Rect2 = Rect2()
var asset_paths: Dictionary = {}
var rock_cliff_kit_id: StringName = &""
var external_rock_atlas_ready: bool = false

func configure(
	next_style: StringName,
	next_side: StringName,
	next_uv_origin: Vector2,
	height_cells: int,
	logical_tile_scale: float,
	primary_color: Color,
	accent_color: Color,
	biome_id: StringName = &""
) -> void:
	style = next_style
	side = next_side
	uv_origin = next_uv_origin
	wall_height = maxf(
		float(height_cells) * logical_tile_scale,
		logical_tile_scale
	)
	face_texture = null
	top_texture = null
	face_draw_texture = null
	top_draw_texture = null
	face_uv_rect = Rect2()
	top_uv_rect = Rect2()
	asset_paths.clear()
	rock_cliff_kit_id = &""
	external_rock_atlas_ready = false
	if style == BiomeEnvironmentLayout.PERIMETER_VISUAL_RAISED_CLIFF:
		_load_textures(primary_color, accent_color, biome_id)

func has_raised_cliff_art() -> bool:
	return (
		style == BiomeEnvironmentLayout.PERIMETER_VISUAL_RAISED_CLIFF
		and face_texture != null
		and top_texture != null
	)

func uses_fallback() -> bool:
	return (
		style == BiomeEnvironmentLayout.PERIMETER_VISUAL_RAISED_CLIFF
		and not has_raised_cliff_art()
	)

func _load_textures(
	primary_color: Color,
	accent_color: Color,
	biome_id: StringName
) -> void:
	if GENERATED_ART_CATALOG.has_generated_theme(biome_id):
		var face_path := GENERATED_ART_CATALOG.select_cliff_asset_path(
			biome_id,
			GENERATED_ART_CATALOG.ROLE_CLIFF_FACE,
			0
		)
		var top_path := GENERATED_ART_CATALOG.select_surface_asset_path(
			biome_id,
			GENERATED_ART_CATALOG.ROLE_GROUND,
			0,
			Vector2i.ZERO
		)
		asset_paths = {
			&"face": face_path,
			&"top": top_path,
		}
		face_texture = _load_generated_repeating_texture(
			face_path,
			primary_color,
			accent_color,
			GENERATED_TEXTURE_TOOLS.cliff_edge_trim_pixels(biome_id),
			GENERATED_TEXTURE_TOOLS.should_harmonize_cliff_edges(biome_id)
		)
		top_texture = _load_generated_repeating_texture(
			top_path,
			primary_color,
			accent_color,
			GENERATED_TEXTURE_TOOLS.surface_edge_trim_pixels(biome_id),
			GENERATED_TEXTURE_TOOLS.should_harmonize_surface_edges(biome_id)
		)
		face_draw_texture = face_texture
		top_draw_texture = top_texture
		return
	var manifest := EnvironmentAssetManifest.get_shared()
	rock_cliff_kit_id = manifest.get_biome_rock_cliff_kit_id(biome_id)
	external_rock_atlas_ready = (
		not rock_cliff_kit_id.is_empty()
		and manifest.rock_cliff_kit_has_external_assets(rock_cliff_kit_id)
	)
	var face_path := ""
	var top_path := ""
	var face_role: StringName = &""
	var top_role: StringName = &""
	if external_rock_atlas_ready:
		var atlas_set := RockCliffAtlasSet.new()
		if atlas_set.configure(biome_id, manifest):
			face_role = StringName("edge_%s" % String(side))
			top_role = &"center_01"
			face_texture = atlas_set.get_wall_texture(face_role)
			top_texture = atlas_set.get_top_texture(top_role)
			face_draw_texture = atlas_set.wall_atlas
			top_draw_texture = atlas_set.top_atlas
			face_uv_rect = atlas_set.get_wall_uv_rect(face_role)
			top_uv_rect = atlas_set.get_top_uv_rect(top_role)
			face_path = manifest.get_rock_cliff_kit_asset_path(
				rock_cliff_kit_id, &"wall"
			)
			top_path = manifest.get_rock_cliff_kit_asset_path(
				rock_cliff_kit_id, &"top"
			)
	elif not rock_cliff_kit_id.is_empty():
		face_path = manifest.get_rock_cliff_kit_fallback_path(rock_cliff_kit_id, &"wall")
		top_path = manifest.get_rock_cliff_kit_fallback_path(rock_cliff_kit_id, &"top")
	else:
		face_path = String(
			manifest.get_void_asset_contract(FACE_TEXTURE_ID).get("asset_path", "")
		)
		top_path = String(
			manifest.get_object_asset_contract(TOP_OBJECT_ID).get("asset_path", "")
		)
	asset_paths = {
		&"face": face_path,
		&"top": top_path,
		&"rock_cliff_kit_id": rock_cliff_kit_id,
		&"external_rock_atlas_ready": external_rock_atlas_ready,
		&"face_role": face_role,
		&"top_role": top_role,
	}
	if face_texture == null:
		face_texture = TEXTURE_LOADER.load_texture(
			face_path,
			primary_color,
			accent_color,
			TEXTURE_SIZE
		)
	if top_texture == null:
		top_texture = TEXTURE_LOADER.load_texture(
			top_path,
			primary_color,
			accent_color,
			TEXTURE_SIZE
		)
	if face_draw_texture == null:
		face_draw_texture = face_texture
	if top_draw_texture == null:
		top_draw_texture = top_texture

func _load_generated_repeating_texture(
	asset_path: String,
	primary_color: Color,
	accent_color: Color,
	trim: int,
	harmonize_edges: bool
) -> Texture2D:
	var texture := TEXTURE_LOADER.load_texture(
		asset_path,
		primary_color,
		accent_color,
		TEXTURE_SIZE
	)
	if texture == null:
		return null
	return GENERATED_TEXTURE_TOOLS.normalize_repeating_texture(
		texture,
		trim,
		harmonize_edges,
		GENERATED_TEXTURE_TOOLS.BURNING_FIELDS_EDGE_BLEND_PIXELS,
		asset_path
	)
