extends RefCounted
class_name RockCliffAtlasSet

## Loads independently delivered external atlases and exposes deterministic
## AtlasTexture cut-outs. It never rasterizes or paints replacement art.

var kit_id: StringName = &""
var contract: Dictionary = {}
var wall_atlas: Texture2D
var top_atlas: Texture2D
var _textures: Dictionary = {}

func configure(
	biome_id: StringName,
	manifest: EnvironmentAssetManifest = null
) -> bool:
	reset()
	var source_manifest := manifest
	if source_manifest == null:
		source_manifest = EnvironmentAssetManifest.get_shared()
	var biome_contract := source_manifest.get_biome_asset_set_contract(biome_id)
	kit_id = StringName(str(biome_contract.get("rock_cliff_kit_id", "")))
	contract = source_manifest.get_rock_cliff_kit_contract(kit_id)
	if contract.is_empty():
		return false
	var expected_size := Vector2(
		contract.get("atlas_grid", Vector2i.ZERO) as Vector2i
	) * Vector2(contract.get("module_size_px", Vector2i.ZERO) as Vector2i)
	if source_manifest.rock_cliff_kit_has_external_asset(kit_id, &"wall"):
		wall_atlas = load(String(contract.get("wall_atlas_path", ""))) as Texture2D
		if wall_atlas != null and wall_atlas.get_size() != expected_size:
			wall_atlas = null
	if source_manifest.rock_cliff_kit_has_external_asset(kit_id, &"top"):
		top_atlas = load(String(contract.get("top_atlas_path", ""))) as Texture2D
		if top_atlas != null and top_atlas.get_size() != expected_size:
			top_atlas = null
	return is_wall_ready() or is_top_ready()

func reset() -> void:
	kit_id = &""
	contract.clear()
	wall_atlas = null
	top_atlas = null
	_textures.clear()

func is_ready() -> bool:
	return is_wall_ready() and is_top_ready()

func is_wall_ready() -> bool:
	return wall_atlas != null and not contract.is_empty()

func is_top_ready() -> bool:
	return top_atlas != null and not contract.is_empty()

func get_wall_texture(role: StringName) -> AtlasTexture:
	return _get_texture(&"wall", role)

func get_top_texture(role: StringName) -> AtlasTexture:
	return _get_texture(&"top", role)

func get_wall_uv_rect(role: StringName) -> Rect2:
	return _get_uv_rect(&"wall", role)

func get_top_uv_rect(role: StringName) -> Rect2:
	return _get_uv_rect(&"top", role)

func _get_uv_rect(kind: StringName, role: StringName) -> Rect2:
	var regions := contract.get("%s_regions" % String(kind), {}) as Dictionary
	if not regions.has(role):
		return Rect2(Vector2.ZERO, Vector2.ONE)
	var grid := contract.get("atlas_grid", Vector2i.ONE) as Vector2i
	if grid.x <= 0 or grid.y <= 0:
		return Rect2(Vector2.ZERO, Vector2.ONE)
	var cell := regions[role] as Vector2i
	var cell_size := Vector2(1.0 / float(grid.x), 1.0 / float(grid.y))
	# Half a source pixel keeps bilinear filtering inside the declared module.
	var atlas_size := (
		wall_atlas.get_size()
		if kind == &"wall" and wall_atlas != null
		else top_atlas.get_size()
		if top_atlas != null
		else Vector2(grid)
	)
	var inset := Vector2(0.5 / atlas_size.x, 0.5 / atlas_size.y)
	return Rect2(Vector2(cell) * cell_size + inset, cell_size - inset * 2.0)

func _get_texture(kind: StringName, role: StringName) -> AtlasTexture:
	if (
		(kind == &"wall" and not is_wall_ready())
		or (kind == &"top" and not is_top_ready())
	):
		return null
	var cache_key := "%s:%s" % [String(kind), String(role)]
	if _textures.has(cache_key):
		return _textures[cache_key] as AtlasTexture
	var regions := contract.get("%s_regions" % String(kind), {}) as Dictionary
	if not regions.has(role):
		return null
	var module_size := contract.get("module_size_px", Vector2i.ZERO) as Vector2i
	var cell := regions[role] as Vector2i
	var texture := AtlasTexture.new()
	texture.atlas = wall_atlas if kind == &"wall" else top_atlas
	texture.region = Rect2(cell * module_size, module_size)
	texture.filter_clip = true
	_textures[cache_key] = texture
	return texture
