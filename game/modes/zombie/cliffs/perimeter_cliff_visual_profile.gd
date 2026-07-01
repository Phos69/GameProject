extends RefCounted
class_name PerimeterCliffVisualProfile

const TEXTURE_LOADER := preload(
	"res://game/modes/zombie/isometric_svg_texture_loader.gd"
)
const GENERATED_ART_CATALOG := preload(
	"res://game/modes/zombie/biome_generated_art_catalog.gd"
)
const GENERATED_TEXTURE_TOOLS := preload(
	"res://game/modes/zombie/generated_biome_texture_tools.gd"
)
const FACE_TEXTURE_ID := &"rock_cliff_face_texture"
const TOP_OBJECT_ID := &"large_rock"
const TEXTURE_SIZE := Vector2i(512, 512)

var style: StringName = BiomeEnvironmentLayout.PERIMETER_VISUAL_WALL
var side: StringName = &""
var uv_origin: Vector2 = Vector2.ZERO
var wall_height: float = 0.0
var face_texture: Texture2D
var top_texture: Texture2D
var asset_paths: Dictionary = {}

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
	asset_paths.clear()
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
		return
	var manifest := IsometricEnvironmentManifest.get_shared()
	var face_path := String(
		manifest.get_void_asset_contract(FACE_TEXTURE_ID).get("asset_path", "")
	)
	var top_path := String(
		manifest.get_object_asset_contract(TOP_OBJECT_ID).get("asset_path", "")
	)
	asset_paths = {
		&"face": face_path,
		&"top": top_path
	}
	face_texture = TEXTURE_LOADER.load_texture(
		face_path,
		primary_color,
		accent_color,
		TEXTURE_SIZE
	)
	top_texture = TEXTURE_LOADER.load_texture(
		top_path,
		primary_color,
		accent_color,
		TEXTURE_SIZE
	)

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
		harmonize_edges
	)
