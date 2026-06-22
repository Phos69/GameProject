extends BiomeObstacle
class_name IsometricEnvironmentObject

@export var show_debug_footprint: bool = false
@export var show_damage_overlay: bool = false

const ASSET_SPRITE_NAME := "AssetSprite"
const DAMAGE_OVERLAY_NAME := "DamageOverlay"
const TILE_LAYER_ROCK_RENDER_MODE := &"tile_layer_rock_area"
const ROCK_AREA_OCCLUDER_NAME := "RockAreaOccluder"
const ROCK_AREA_OCCLUDER_SCRIPT = preload(
	"res://game/modes/zombie/rocks/rock_area_occluder_visual.gd"
)
const OCCLUSION_HORIZONTAL_MARGIN := 8.0
const CLIFF_RELATION_OUTSIDE := &"outside"
const CLIFF_RELATION_BEHIND := &"behind"
const CLIFF_RELATION_FRONT := &"front"
const SVG_TEXTURE_LOADER = preload(
	"res://game/modes/zombie/isometric_svg_texture_loader.gd"
)
const MISSING_ASSET_FALLBACK_STATUSES: Array[String] = [
	"needs_asset",
	"procedural_fallback",
	"deprecated"
]

const CONTENT_ALPHA_THRESHOLD := 0.08
const LOGICAL_TILE_SCALE := 8.0

var asset_path: String = ""
var anchor_id: StringName = &"iso_floor_center"
var asset_status: String = ""
var asset_sprite: Sprite2D
var damage_overlay: Sprite2D
var rock_area_occluder: RockAreaOccluderVisual
var procedural_fallback_active: bool = false
var render_mode: StringName = &"sprite"

# Opaque-content metrics (bounds + width profile, texture pixels) keyed by
# asset_path. The same asset always loads at one deterministic size, so it is
# scanned once and reused across every instance instead of re-reading the image
# per object. The profile is the cumulative-max opaque half-width measured from
# the art's bottom upward, used to seat the footprint-wide row on the tile.
static var _content_metrics_cache: Dictionary = {}

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

func has_asset_visual() -> bool:
	return (
		has_asset_sprite()
		or (
			uses_tile_layer_rock_visual()
			and rock_area_occluder != null
			and rock_area_occluder.has_texture()
		)
	)

func get_render_mode() -> StringName:
	return render_mode

func uses_tile_layer_rock_visual() -> bool:
	return render_mode == TILE_LAYER_ROCK_RENDER_MODE

func is_world_position_behind_cliff(world_position: Vector2) -> bool:
	return (
		classify_world_position_relative_to_cliff(world_position)
		== CLIFF_RELATION_BEHIND
	)

func is_world_position_in_front_of_cliff(world_position: Vector2) -> bool:
	return (
		classify_world_position_relative_to_cliff(world_position)
		== CLIFF_RELATION_FRONT
	)

func classify_world_position_relative_to_cliff(
	world_position: Vector2
) -> StringName:
	if not uses_tile_layer_rock_visual():
		return CLIFF_RELATION_OUTSIDE
	var local_position := to_local(world_position)
	if absf(local_position.x) > obstacle_size.x * 0.5 + OCCLUSION_HORIZONTAL_MARGIN:
		return CLIFF_RELATION_OUTSIDE
	return CLIFF_RELATION_BEHIND if local_position.y < 0.0 else CLIFF_RELATION_FRONT

func get_cliff_sort_line_y() -> float:
	return global_position.y

func uses_procedural_fallback() -> bool:
	return procedural_fallback_active

func uses_generic_fallback() -> bool:
	if has_asset_visual() and not procedural_fallback_active:
		return false
	return super.uses_generic_fallback()

func has_debug_footprint() -> bool:
	return show_debug_footprint

func set_debug_footprint_visible(enabled: bool) -> void:
	show_debug_footprint = enabled
	queue_redraw()

func _draw() -> void:
	if uses_tile_layer_rock_visual():
		if show_debug_footprint:
			_draw_rect_debug_footprint()
		return
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
	render_mode = StringName(str(contract.get("render_mode", "sprite")))
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

	rock_area_occluder = get_node_or_null(
		ROCK_AREA_OCCLUDER_NAME
	) as RockAreaOccluderVisual
	if rock_area_occluder == null:
		rock_area_occluder = (
			ROCK_AREA_OCCLUDER_SCRIPT.new() as RockAreaOccluderVisual
		)
		rock_area_occluder.name = ROCK_AREA_OCCLUDER_NAME
		add_child(rock_area_occluder)
		rock_area_occluder.owner = owner
	rock_area_occluder.z_index = 0
	rock_area_occluder.y_sort_enabled = false

func _load_asset_texture(contract: Dictionary) -> void:
	procedural_fallback_active = false
	if asset_sprite == null:
		return
	asset_sprite.texture = null
	asset_sprite.visible = false
	if rock_area_occluder != null:
		rock_area_occluder.visible = false
	if uses_tile_layer_rock_visual():
		if rock_area_occluder != null:
			rock_area_occluder.configure(obstacle_size, asset_path)
		return
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
	var manifest := IsometricEnvironmentManifest.get_shared()
	var target_size := manifest.get_native_visual_size(obstacle_id)
	# Scalable obstacles (e.g. rocks) are placed at a per-instance square footprint,
	# so the art must follow the instance size instead of the fixed manifest visual
	# size. Scale the native visual size by the instance/base footprint ratio.
	if manifest.is_scalable(obstacle_id):
		target_size = _scalable_target_size(manifest, target_size)
	var scale_factor := minf(
		target_size.x / texture_size.x,
		target_size.y / texture_size.y
	)
	# Scaling is deterministic and comes from the manifest footprint/visual
	# height contract (or, for scalable objects, the instance footprint).
	# Generator randomness never changes the sprite dimensions.
	# Scalable objects use a lower floor so a small instance does not clamp to the
	# same scale as a large one: the art tracks the instance footprint linearly.
	var min_scale := 0.04 if manifest.is_scalable(obstacle_id) else 0.25
	asset_sprite.scale = Vector2.ONE * clampf(scale_factor, min_scale, 4.0)
	# Plant the *visible* art on the floor, not the raw canvas. High-res source
	# PNGs (and SVGs) carry transparent padding, so resting the canvas bottom on
	# floor_y would float the art above its tile. Anchoring on the opaque bounds
	# keeps every asset seated on iso_floor_center regardless of that padding.
	var metrics := _get_content_metrics(asset_sprite.texture)
	var content_rect := metrics.get("bounds", Rect2(Vector2.ZERO, texture_size)) as Rect2
	var canvas_center := texture_size * 0.5
	var content_center_x := content_rect.position.x + content_rect.size.x * 0.5
	var content_bottom := content_rect.position.y + content_rect.size.y
	var anchor_x := -(content_center_x - canvas_center.x) * asset_sprite.scale.x
	var content_bottom_local := (content_bottom - canvas_center.y) * asset_sprite.scale.y
	var content_height_local := content_rect.size.y * asset_sprite.scale.y
	var floor_y := clampf(sort_offset, 0.0, obstacle_size.y * 0.5 + 12.0)
	# Seat the asset so the row where the art first spans the footprint width sits
	# on the collision front edge (obstacle_size.y * 0.5 — the square rect built in
	# BiomeObstacle._rebuild_collision). The narrow "skirt" below that row (tree
	# roots, rock base) spills past the edge, so the art blankets the whole
	# occupied tile and the obstacle-terrain "hitbox" patch never peeks out. Wide
	# assets (no skirt) just rest on the front edge.
	var skirt_height := _content_skirt_height(metrics, obstacle_size.x * 0.5, asset_sprite.scale.x)
	var skirt_local := minf(skirt_height * asset_sprite.scale.y, obstacle_size.y * 0.35)
	var base_y := maxf(
		obstacle_size.y * 0.5 + skirt_local,
		floor_y + maxf(obstacle_size.y * 0.25, 6.0)
	)
	match anchor_id:
		&"bottom_center", &"iso_floor_center":
			asset_sprite.position = Vector2(anchor_x, base_y - content_bottom_local)
		&"edge_aligned":
			asset_sprite.position = Vector2(
				anchor_x, base_y - content_bottom_local - content_height_local * 0.08
			)
		_:
			asset_sprite.position = Vector2(
				anchor_x, base_y - content_bottom_local - content_height_local * 0.16
			)
	if damage_overlay != null:
		damage_overlay.texture = asset_sprite.texture
		damage_overlay.scale = asset_sprite.scale
		damage_overlay.position = asset_sprite.position

func _scalable_target_size(
	manifest: IsometricEnvironmentManifest,
	base_target: Vector2
) -> Vector2:
	# The base footprint defines the manifest native visual size; an instance can be
	# larger or smaller, so scale the native size by the instance/base ratio. The
	# logical tile scale cancels in the ratio (both terms use the same scale).
	var base_footprint := manifest.get_footprint_tiles(obstacle_id)
	if base_footprint.x <= 0:
		return base_target
	var base_width_px := float(base_footprint.x) * LOGICAL_TILE_SCALE
	if base_width_px <= 0.0:
		return base_target
	var ratio := obstacle_size.x / base_width_px
	if ratio <= 0.0:
		return base_target
	return base_target * ratio

func _get_content_metrics(texture: Texture2D) -> Dictionary:
	var texture_size := texture.get_size()
	var full := {
		"bounds": Rect2(Vector2.ZERO, texture_size),
		"profile": PackedFloat32Array(),
		"step": 1
	}
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return full
	if not asset_path.is_empty() and _content_metrics_cache.has(asset_path):
		return _content_metrics_cache[asset_path] as Dictionary
	var image := texture.get_image()
	var metrics := full
	if image != null and image.get_width() > 0 and image.get_height() > 0:
		var scanned := _scan_content_metrics(image)
		var bounds := scanned.get("bounds", Rect2()) as Rect2
		if bounds.size.x > 0.0 and bounds.size.y > 0.0:
			metrics = scanned
	if not asset_path.is_empty():
		_content_metrics_cache[asset_path] = metrics
	return metrics

# Texture-pixel height of the tapered "skirt" below the lowest row that already
# spans the footprint width. `target_half_width` is the on-screen half-width the
# art must cover; dividing by the sprite scale converts it to texture pixels.
func _content_skirt_height(
	metrics: Dictionary,
	target_half_width: float,
	scale_x: float
) -> float:
	var profile := metrics.get("profile", PackedFloat32Array()) as PackedFloat32Array
	var step := int(metrics.get("step", 1))
	if profile.is_empty() or step <= 0 or scale_x <= 0.0:
		return 0.0
	var needed := target_half_width / scale_x
	for index in range(profile.size()):
		if profile[index] >= needed:
			return float(index * step)
	return float((profile.size() - 1) * step)

func _scan_content_metrics(image: Image) -> Dictionary:
	if image.is_compressed():
		image = image.duplicate()
		image.decompress()
	var width := image.get_width()
	var height := image.get_height()
	# Sub-sample very large source art so the one-time scan stays cheap; the
	# resulting bounds are padded by one step to absorb stride undershoot.
	var step := maxi(1, int(round(maxf(float(width), float(height)) / 256.0)))
	var row_min := PackedInt32Array()
	var row_max := PackedInt32Array()
	var min_x := width
	var min_y := height
	var max_x := -1
	var max_y := -1
	var y := 0
	while y < height:
		var rmin := width
		var rmax := -1
		var x := 0
		while x < width:
			if image.get_pixel(x, y).a > CONTENT_ALPHA_THRESHOLD:
				rmin = mini(rmin, x)
				rmax = maxi(rmax, x)
			x += step
		row_min.append(rmin)
		row_max.append(rmax)
		if rmax >= 0:
			min_x = mini(min_x, rmin)
			max_x = maxi(max_x, rmax)
			min_y = mini(min_y, y)
			max_y = maxi(max_y, y)
		y += step
	if max_x < min_x or max_y < min_y:
		return {
			"bounds": Rect2(Vector2.ZERO, Vector2(float(width), float(height))),
			"profile": PackedFloat32Array(),
			"step": step
		}
	var b_min_x := maxi(0, min_x - step)
	var b_min_y := maxi(0, min_y - step)
	var b_max_x := mini(width - 1, max_x + step)
	var b_max_y := mini(height - 1, max_y + step)
	var bounds := Rect2(
		Vector2(float(b_min_x), float(b_min_y)),
		Vector2(float(b_max_x - b_min_x + 1), float(b_max_y - b_min_y + 1))
	)
	var center_x := (float(b_min_x) + float(b_max_x)) * 0.5
	# Cumulative-max half-width from the opaque bottom upward (one bucket per
	# scan step). Monotonic by construction, so a single forward search finds the
	# first row that spans a requested width.
	var bucket_count := int((max_y - min_y) / step) + 1
	var profile := PackedFloat32Array()
	profile.resize(bucket_count)
	var running := 0.0
	var row_index := row_min.size() - 1
	while row_index >= 0:
		var scan_y := row_index * step
		if row_max[row_index] >= 0 and scan_y <= max_y:
			var half := maxf(center_x - float(row_min[row_index]), float(row_max[row_index]) - center_x)
			running = maxf(running, half)
			var bucket := clampi(int((max_y - scan_y) / step), 0, bucket_count - 1)
			profile[bucket] = maxf(profile[bucket], running)
		row_index -= 1
	var carry := 0.0
	for index in range(bucket_count):
		carry = maxf(carry, profile[index])
		profile[index] = carry
	return { "bounds": bounds, "profile": profile, "step": step }

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

func _draw_rect_debug_footprint() -> void:
	var footprint_rect := Rect2(-obstacle_size * 0.5, obstacle_size)
	draw_rect(footprint_rect, Color(0.15, 0.60, 0.95, 0.12), true)
	draw_rect(footprint_rect, Color(0.30, 0.80, 1.0, 0.88), false, 2.5)

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
