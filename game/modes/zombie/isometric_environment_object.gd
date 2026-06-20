extends BiomeObstacle
class_name IsometricEnvironmentObject

@export var show_debug_footprint: bool = false
@export var show_damage_overlay: bool = false

const ASSET_SPRITE_NAME := "AssetSprite"
const DAMAGE_OVERLAY_NAME := "DamageOverlay"
const SVG_TEXTURE_LOADER = preload(
	"res://game/modes/zombie/isometric_svg_texture_loader.gd"
)
const MISSING_ASSET_FALLBACK_STATUSES: Array[String] = [
	"needs_asset",
	"procedural_fallback",
	"deprecated"
]

var asset_path: String = ""
var anchor_id: StringName = &"iso_floor_center"
var asset_status: String = ""
var asset_sprite: Sprite2D
var damage_overlay: Sprite2D
var procedural_fallback_active: bool = false

func configure(
	next_obstacle_id: StringName,
	next_size: Vector2,
	next_shape_id: StringName,
	rotation_radians: float,
	base_color: Color,
	detail_color: Color,
	next_sort_offset: float = 0.0
) -> void:
	super.configure(
		next_obstacle_id,
		next_size,
		next_shape_id,
		rotation_radians,
		base_color,
		detail_color,
		next_sort_offset
	)
	_apply_asset_contract()
	queue_redraw()

func _ready() -> void:
	super._ready()
	_ensure_visual_nodes()
	_apply_asset_contract()

func get_asset_path() -> String:
	return asset_path

func get_anchor_id() -> StringName:
	return anchor_id

func get_asset_status() -> String:
	return asset_status

func has_asset_sprite() -> bool:
	return (
		asset_sprite != null
		and is_instance_valid(asset_sprite)
		and asset_sprite.texture != null
		and asset_sprite.visible
	)

func uses_procedural_fallback() -> bool:
	return procedural_fallback_active

func uses_generic_fallback() -> bool:
	if has_asset_sprite() and not procedural_fallback_active:
		return false
	return super.uses_generic_fallback()

func has_debug_footprint() -> bool:
	return show_debug_footprint

func set_debug_footprint_visible(enabled: bool) -> void:
	show_debug_footprint = enabled
	queue_redraw()

func _draw() -> void:
	if is_perimeter_wall() or procedural_fallback_active:
		super._draw()
		return
	_draw_ground_shadow()
	_draw_occupied_base()
	if show_debug_footprint:
		_draw_iso_debug_footprint()

func _apply_asset_contract() -> void:
	var manifest := IsometricEnvironmentManifest.get_shared()
	var contract := manifest.get_object_asset_contract(obstacle_id)
	asset_path = String(contract.get("asset_path", ""))
	anchor_id = StringName(str(contract.get("anchor", "iso_floor_center")))
	asset_status = String(contract.get("status", ""))
	if contract.has("sort_offset"):
		sort_offset = float(contract.get("sort_offset", sort_offset))
	if contract.has("collision_shape"):
		collision_shape_id = _resolve_collision_shape(
			StringName(str(contract.get("collision_shape", ""))),
			shape_id
		)
		shape_id = collision_shape_id
	if contract.has("blocks_movement"):
		blocks_movement = bool(contract.get("blocks_movement", blocks_movement))
	if contract.has("blocks_projectiles"):
		projectile_blocking = bool(contract.get("blocks_projectiles", projectile_blocking))
	# Perimeter walls are tiled across the whole side, so a single centred
	# sprite cannot represent them; render the procedural isometric wall volume
	# (orientation-aware, tileable) for every border segment instead.
	if is_perimeter_wall():
		asset_path = ""
	_apply_collision_layers()
	_rebuild_collision()
	_ensure_visual_nodes()
	_load_asset_texture(contract)
	_position_asset_sprite()
	_update_damage_overlay()

func _ensure_visual_nodes() -> void:
	asset_sprite = get_node_or_null(ASSET_SPRITE_NAME) as Sprite2D
	if asset_sprite == null:
		asset_sprite = Sprite2D.new()
		asset_sprite.name = ASSET_SPRITE_NAME
		add_child(asset_sprite)
		asset_sprite.owner = owner
	asset_sprite.centered = true
	asset_sprite.z_index = 0
	asset_sprite.y_sort_enabled = false

	damage_overlay = get_node_or_null(DAMAGE_OVERLAY_NAME) as Sprite2D
	if damage_overlay == null:
		damage_overlay = Sprite2D.new()
		damage_overlay.name = DAMAGE_OVERLAY_NAME
		add_child(damage_overlay)
		damage_overlay.owner = owner
	damage_overlay.centered = true
	damage_overlay.visible = false
	damage_overlay.z_index = 1
	damage_overlay.y_sort_enabled = false

func _load_asset_texture(contract: Dictionary) -> void:
	procedural_fallback_active = false
	if asset_sprite == null:
		return
	asset_sprite.texture = null
	asset_sprite.visible = false
	if asset_path.is_empty():
		procedural_fallback_active = _contract_allows_procedural_fallback(contract)
		return
	var texture := SVG_TEXTURE_LOADER.load_texture(
		asset_path,
		primary_color,
		accent_color
	)
	if texture != null:
		asset_sprite.texture = texture
		asset_sprite.visible = true
		return
	procedural_fallback_active = _contract_allows_procedural_fallback(contract)

func _contract_allows_procedural_fallback(contract: Dictionary) -> bool:
	var status := String(contract.get("status", ""))
	if MISSING_ASSET_FALLBACK_STATUSES.has(status):
		return true
	var fallback_path := String(contract.get("fallback_path", ""))
	return fallback_path == "res://game/modes/zombie/biome_obstacle.gd"

func _position_asset_sprite() -> void:
	if asset_sprite == null:
		return
	if asset_sprite.texture == null:
		asset_sprite.scale = Vector2.ONE
		asset_sprite.position = Vector2.ZERO
		return
	var texture_size := asset_sprite.texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		asset_sprite.scale = Vector2.ONE
		asset_sprite.position = Vector2.ZERO
		return
	var target_size := IsometricEnvironmentManifest.get_shared().get_native_visual_size(
		obstacle_id
	)
	var scale_factor := minf(
		target_size.x / texture_size.x,
		target_size.y / texture_size.y
	)
	# Scaling is deterministic and comes from the manifest footprint/visual
	# height contract. Generator randomness never changes the sprite dimensions.
	asset_sprite.scale = Vector2.ONE * clampf(scale_factor, 0.25, 4.0)
	var visual_size := texture_size * asset_sprite.scale
	var floor_y := clampf(sort_offset, 0.0, obstacle_size.y * 0.5 + 12.0)
	match anchor_id:
		&"bottom_center", &"iso_floor_center":
			asset_sprite.position = Vector2(0.0, floor_y - visual_size.y * 0.5)
		&"edge_aligned":
			asset_sprite.position = Vector2(0.0, floor_y - visual_size.y * 0.42)
		_:
			asset_sprite.position = Vector2(0.0, floor_y - visual_size.y * 0.34)
	if damage_overlay != null:
		damage_overlay.texture = asset_sprite.texture
		damage_overlay.scale = asset_sprite.scale
		damage_overlay.position = asset_sprite.position

func _update_damage_overlay() -> void:
	if damage_overlay == null:
		return
	damage_overlay.visible = show_damage_overlay and has_asset_sprite()
	damage_overlay.modulate = Color(0.62, 0.12, 0.08, 0.32)

func _apply_collision_layers() -> void:
	collision_layer = 0
	if blocks_movement:
		collision_layer |= MOVEMENT_BLOCK_LAYER_BIT
	if projectile_blocking:
		collision_layer |= PROJECTILE_BLOCK_LAYER_BIT
	collision_mask = 0

func _draw_iso_debug_footprint() -> void:
	var half_width := maxf(obstacle_size.x * 0.5, 8.0)
	var half_height := maxf(obstacle_size.y * 0.25, 6.0)
	var floor_y := clampf(sort_offset, 0.0, obstacle_size.y * 0.5 + 12.0)
	var points := PackedVector2Array([
		Vector2(0.0, floor_y - half_height),
		Vector2(half_width, floor_y),
		Vector2(0.0, floor_y + half_height),
		Vector2(-half_width, floor_y)
	])
	draw_colored_polygon(points, Color(0.15, 0.60, 0.95, 0.12))
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, Color(0.30, 0.80, 1.0, 0.68), 1.5, true)

func _draw_occupied_base() -> void:
	if not blocks_movement:
		return
	var half_width := maxf(obstacle_size.x * 0.5, 8.0)
	var half_height := maxf(obstacle_size.y * 0.25, 6.0)
	var floor_y := clampf(sort_offset, 0.0, obstacle_size.y * 0.5 + 12.0)
	var points := PackedVector2Array([
		Vector2(0.0, floor_y - half_height),
		Vector2(half_width, floor_y),
		Vector2(0.0, floor_y + half_height),
		Vector2(-half_width, floor_y)
	])
	var base_color := primary_color.darkened(0.46)
	base_color.a = 0.72 if obstacle_category in [&"building", &"dense_vegetation"] else 0.48
	draw_colored_polygon(points, base_color)
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, accent_color.darkened(0.20), 1.5, true)
