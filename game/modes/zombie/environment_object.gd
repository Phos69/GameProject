extends BiomeObstacle
class_name EnvironmentObject

@export var show_debug_footprint: bool = false
@export var show_damage_overlay: bool = false

const ASSET_SPRITE_NAME := "AssetSprite"
const DAMAGE_OVERLAY_NAME := "DamageOverlay"
const MESA_RENDER_MODE := &"y_sorted_mesa"
const TILE_LAYER_MESA_RENDER_MODE := &"tile_layer_rock_area"
# Public compatibility alias for callers/tests written before mesas became a
# shared multi-biome contract.
const TILE_LAYER_ROCK_RENDER_MODE := TILE_LAYER_MESA_RENDER_MODE
const ROCK_AREA_OCCLUDER_NAME := "RockAreaOccluder"
const MESA_COLLISION_POLYGON_NAME := "MesaCollisionPolygon"
const OCCLUSION_HORIZONTAL_MARGIN := 8.0
const CLIFF_RELATION_OUTSIDE := &"outside"
const CLIFF_RELATION_BEHIND := &"behind"
const CLIFF_RELATION_FRONT := &"front"
const SVG_TEXTURE_LOADER = preload(
	"res://game/modes/zombie/environment_texture_loader.gd"
)
const MESA_MESH_BUILDER = preload(
	"res://game/modes/zombie/rocks/rectilinear_rock_area_mesh_builder.gd"
)
const MESA_ART_RESOLVER = preload(
	"res://game/modes/zombie/rocks/mesa_visual_art_resolver.gd"
)
const MISSING_ASSET_FALLBACK_STATUSES: Array[String] = [
	"needs_asset",
	"procedural_fallback",
	"deprecated"
]
const NATIVE_SVG_OBJECT_IDS: Array[StringName] = [&"reed_wall", &"dead_tree"]

const CONTENT_ALPHA_THRESHOLD := 0.08
const LEGACY_TILE_SCALE := WorldGridConfig.LEGACY_TILE_SCALE

var asset_path: String = ""
var asset_variant_id: StringName = &""
var asset_variant_context_id: StringName = &""
var anchor_id: StringName = &"floor_center"
var asset_status: String = ""
var asset_sprite: Sprite2D
var damage_overlay: Sprite2D
var procedural_fallback_active: bool = false
var render_mode: StringName = &"sprite"
var _asset_variation_pending: bool = false
var _mesa_mesh_builder: RectilinearRockAreaMeshBuilder
var _mesa_top_texture: Texture2D
var _mesa_face_texture: Texture2D
var _mesa_profile_id: StringName = &""
var _mesa_art_asset_paths: Dictionary = {}

# Opaque-content metrics (bounds + width profile, texture pixels) keyed by
# asset_path. The same asset always loads at one deterministic size, so it is
# scanned once and reused across every instance instead of re-reading the image
# per object. The profile is the cumulative-max opaque half-width measured from
# the art's bottom upward, used to seat the footprint-wide row on the tile.
static var _content_metrics_cache: Dictionary = {}

static func clear_content_metrics_cache() -> void:
	_content_metrics_cache.clear()

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
	_queue_asset_variation()
	queue_redraw()

func _ready() -> void:
	super._ready()
	_ensure_visual_nodes()
	_apply_asset_contract()
	_queue_asset_variation()

func _process(_delta: float) -> void:
	if not _asset_variation_pending:
		set_process(false)
		return
	_asset_variation_pending = false
	_apply_asset_variation()
	set_process(false)

func get_asset_path() -> String:
	return asset_path

func get_anchor_id() -> StringName:
	return anchor_id

func get_asset_status() -> String:
	return asset_status

func get_asset_variant_id() -> StringName:
	return asset_variant_id

func select_random_asset_variant(
	context_id: StringName,
	world_position_key: Vector2
) -> bool:
	var manifest := EnvironmentAssetManifest.get_shared()
	var variant_ids := manifest.get_object_random_variant_ids(
		obstacle_id,
		context_id
	)
	if variant_ids.is_empty():
		return false
	asset_variant_context_id = context_id
	var seed := _asset_variation_seed(world_position_key)
	asset_variant_id = variant_ids[seed % variant_ids.size()]
	set_meta("asset_variant_context", asset_variant_context_id)
	set_meta("asset_variant_id", asset_variant_id)
	_apply_asset_contract()
	_apply_asset_variation()
	return true

func has_asset_sprite() -> bool:
	return (
		asset_sprite != null
		and is_instance_valid(asset_sprite)
		and asset_sprite.texture != null
		and asset_sprite.visible
	)

func has_asset_visual() -> bool:
	return has_asset_sprite() or has_mesa_visual()

func get_asset_visual_bounds() -> Rect2:
	if not has_asset_sprite():
		return Rect2()
	var texture_size := asset_sprite.texture.get_size()
	var metrics := _get_content_metrics(asset_sprite.texture)
	var content_rect := metrics.get(
		"bounds",
		Rect2(Vector2.ZERO, texture_size)
	) as Rect2
	var scaled_position := (
		content_rect.position - texture_size * 0.5
	) * asset_sprite.scale.abs()
	return Rect2(
		asset_sprite.position + scaled_position,
		content_rect.size * asset_sprite.scale.abs()
	)

func get_asset_root_center() -> Vector2:
	if not has_asset_sprite():
		return collision_offset
	var texture_size := asset_sprite.texture.get_size()
	var metrics := _get_content_metrics(asset_sprite.texture)
	var root_center := metrics.get(
		"root_center",
		Vector2(texture_size.x * 0.5, texture_size.y)
	) as Vector2
	var root_delta := (root_center - texture_size * 0.5) * asset_sprite.scale
	if asset_sprite.flip_h:
		root_delta.x = -root_delta.x
	return asset_sprite.position + root_delta

func get_render_mode() -> StringName:
	return render_mode

func uses_tile_layer_rock_visual() -> bool:
	return uses_mesa_visual()

func uses_tile_layer_mesa_visual() -> bool:
	return uses_mesa_visual()

func uses_mesa_visual() -> bool:
	return render_mode in [MESA_RENDER_MODE, TILE_LAYER_MESA_RENDER_MODE]

func has_mesa_visual() -> bool:
	return (
		uses_mesa_visual()
		and _mesa_mesh_builder != null
		and _mesa_mesh_builder.has_geometry()
		and _mesa_top_texture != null
		and _mesa_face_texture != null
	)

func get_mesa_profile_id() -> StringName:
	return _mesa_profile_id

func get_mesa_art_asset_paths() -> Dictionary:
	return _mesa_art_asset_paths.duplicate(true)

func get_mesa_geometry_counts() -> Dictionary:
	if _mesa_mesh_builder == null:
		return {}
	return _mesa_mesh_builder.get_counts()

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
	return (
		CLIFF_RELATION_BEHIND
		if world_position.y < get_cliff_sort_line_y()
		else CLIFF_RELATION_FRONT
	)

func get_cliff_sort_line_y() -> float:
	var sort_anchor := get_parent() as Node2D
	if (
		sort_anchor != null
		and sort_anchor.has_meta(ObstacleSystem.SORT_ANCHOR_META)
	):
		return sort_anchor.global_position.y
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
	if uses_mesa_visual():
		if has_mesa_visual():
			var face_mesh := _mesa_mesh_builder.get_face_mesh()
			if face_mesh != null:
				draw_mesh(
					face_mesh,
					_mesa_face_texture,
					Transform2D.IDENTITY,
					Color(1.12, 1.12, 1.12, 1.0)
					if _mesa_profile_id == &"forest"
					else Color.WHITE
				)
			draw_mesh(
				_mesa_mesh_builder.top_mesh,
				_mesa_top_texture,
				Transform2D.IDENTITY,
				Color(1.06, 1.06, 1.06, 1.0)
				if _mesa_profile_id == &"forest"
				else Color.WHITE
			)
		if show_debug_footprint:
			_draw_rect_debug_footprint()
		return
	if is_perimeter_wall() or procedural_fallback_active:
		super._draw()
		return
	if show_debug_footprint:
		_draw_rect_debug_footprint()

func _apply_asset_contract() -> void:
	var manifest := EnvironmentAssetManifest.get_shared()
	var contract := manifest.get_object_asset_contract(obstacle_id)
	asset_path = manifest.get_object_asset_path(obstacle_id, asset_variant_id)
	render_mode = StringName(str(contract.get("render_mode", "sprite")))
	anchor_id = StringName(str(contract.get("anchor", "floor_center")))
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
	_apply_collision_contract(manifest)
	# Perimeter walls are tiled across the whole side, so a single centred
	# sprite cannot represent them; render the procedural top-down wall volume
	# (orientation-aware, tileable) for every border segment instead.
	if is_perimeter_wall():
		asset_path = ""
	_apply_collision_layers()
	_rebuild_collision()
	_ensure_visual_nodes()
	_load_asset_texture(contract)
	_position_asset_sprite()
	_ensure_default_mesa_visual()
	_update_damage_overlay()

func _apply_collision_contract(manifest: EnvironmentAssetManifest) -> void:
	collision_size = obstacle_size * manifest.get_collision_size_ratio(
		obstacle_id,
		asset_variant_id
	)
	collision_size = Vector2(
		maxf(collision_size.x, 4.0),
		maxf(collision_size.y, 4.0)
	)
	collision_offset = obstacle_size * manifest.get_collision_offset_ratio(
		obstacle_id,
		asset_variant_id
	)
	sort_anchor_y = get_sort_anchor_offset().y
	set_meta("collision_size", collision_size)
	set_meta("collision_offset", collision_offset)
	set_meta("sort_anchor_y", sort_anchor_y)
	set_meta("zone_radius", get_clearance_radius())

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

	var stale_rock_area_occluder := get_node_or_null(ROCK_AREA_OCCLUDER_NAME)
	if stale_rock_area_occluder != null:
		stale_rock_area_occluder.queue_free()

func _load_asset_texture(contract: Dictionary) -> void:
	procedural_fallback_active = false
	if asset_sprite == null:
		return
	asset_sprite.texture = null
	asset_sprite.visible = false
	if uses_mesa_visual():
		return
	if asset_path.is_empty():
		procedural_fallback_active = _contract_allows_procedural_fallback(contract)
		return
	var texture_size := SVG_TEXTURE_LOADER.DEFAULT_SIZE
	if asset_path.ends_with(".svg") and NATIVE_SVG_OBJECT_IDS.has(obstacle_id):
		var native_size := EnvironmentAssetManifest.get_shared().get_native_visual_size(
			obstacle_id
		)
		texture_size = Vector2i(roundi(native_size.x), roundi(native_size.y))
	var texture := SVG_TEXTURE_LOADER.load_texture(
		asset_path,
		primary_color,
		accent_color,
		texture_size
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
	var manifest := EnvironmentAssetManifest.get_shared()
	var target_size := manifest.get_native_visual_size(
		obstacle_id,
		LEGACY_TILE_SCALE,
		asset_variant_id
	)
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
	# Authored high-resolution textures and scalable objects need a lower floor:
	# their native source can be several hundred pixels wide even when the world
	# footprint is intentionally small. SVGs keep the legacy 0.25 guard because
	# they are rasterized near their target size by the loader.
	var min_scale := (
		0.04
		if manifest.is_scalable(obstacle_id) or not asset_path.ends_with(".svg")
		else 0.25
	)
	asset_sprite.scale = Vector2.ONE * clampf(scale_factor, min_scale, 4.0)
	# Plant the *visible* art on the floor, not the raw canvas. High-res source
	# PNGs (and SVGs) carry transparent padding, so resting the canvas bottom on
	# floor_y would float the art above its tile. Anchoring on the opaque bounds
	# keeps every asset seated on floor_center regardless of that padding.
	var metrics := _get_content_metrics(asset_sprite.texture)
	var content_rect := metrics.get("bounds", Rect2(Vector2.ZERO, texture_size)) as Rect2
	var canvas_center := texture_size * 0.5
	var content_center_x := content_rect.position.x + content_rect.size.x * 0.5
	var content_center_y := content_rect.position.y + content_rect.size.y * 0.5
	var content_bottom := content_rect.position.y + content_rect.size.y
	var root_center := metrics.get(
		"root_center",
		Vector2(content_center_x, content_bottom)
	) as Vector2
	var horizontal_anchor_pixel := (
		root_center.x
		if obstacle_category == &"tree"
		else content_center_x
	)
	var horizontal_anchor_delta := (
		horizontal_anchor_pixel - canvas_center.x
	) * asset_sprite.scale.x
	if obstacle_category == &"tree" and asset_sprite.flip_h:
		horizontal_anchor_delta = -horizontal_anchor_delta
	var anchor_x := collision_offset.x - horizontal_anchor_delta
	var content_center_y_local := (
		content_center_y - canvas_center.y
	) * asset_sprite.scale.y
	var content_bottom_local := (content_bottom - canvas_center.y) * asset_sprite.scale.y
	var content_height_local := content_rect.size.y * asset_sprite.scale.y
	var floor_y := clampf(sort_offset, 0.0, obstacle_size.y * 0.5 + 12.0)
	# Seat ordinary wide assets on the south edge of their placement footprint.
	# A narrow authored skirt may extend below that edge without changing logical
	# cells. Tree roots use the explicit collision contract in the branch below,
	# so their canopy footprint never becomes a hidden square hitbox.
	var skirt_height := _content_skirt_height(metrics, obstacle_size.x * 0.5, asset_sprite.scale.x)
	var skirt_local := minf(skirt_height * asset_sprite.scale.y, obstacle_size.y * 0.35)
	var base_y := maxf(
		obstacle_size.y * 0.5 + skirt_local,
		floor_y + maxf(obstacle_size.y * 0.25, 6.0)
	)
	var root_center_y_local := (
		root_center.y - canvas_center.y
	) * asset_sprite.scale.y
	match anchor_id:
		&"floor_center":
			# A floor-centered asset represents the same footprint as its physical
			# body. Align opaque content with the collider center; seating it on the
			# south edge shifts buildings by roughly half their height.
			asset_sprite.position = Vector2(
				anchor_x,
				collision_offset.y - content_center_y_local
			)
		&"bottom_center":
			if obstacle_category == &"tree":
				# The visual root center, physics circle center and Y-sort anchor
				# share one point. The canopy footprint remains placement-only.
				asset_sprite.position = Vector2(
					anchor_x,
					collision_offset.y - root_center_y_local
				)
			else:
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

func _queue_asset_variation() -> void:
	if not is_inside_tree():
		_apply_asset_variation()
		return
	_asset_variation_pending = true
	set_process(true)

func configure_mesa_visual(
	profile_id: StringName,
	biome_id: StringName,
	generation_seed: int,
	palette: BiomePalette,
	logical_tile_scale: float,
	world_uv_origin: Vector2 = Vector2.ZERO
) -> void:
	if not uses_mesa_visual():
		return
	var art := MESA_ART_RESOLVER.resolve(
		profile_id,
		biome_id,
		generation_seed,
		palette,
		EnvironmentAssetManifest.get_shared()
	)
	_mesa_profile_id = StringName(art.get("profile_id", &"forest"))
	_mesa_top_texture = art.get("top_texture") as Texture2D
	_mesa_face_texture = art.get("face_texture") as Texture2D
	_mesa_art_asset_paths = {
		"top": String(art.get("top_path", "")),
		"face": String(art.get("face_path", "")),
	}
	_mesa_mesh_builder = MESA_MESH_BUILDER.new() as RectilinearRockAreaMeshBuilder
	_mesa_mesh_builder.configure(
		palette,
		generation_seed,
		float(art.get("top_repeat_world_size", 256.0)),
		float(art.get("face_repeat_world_size", 128.0))
	)
	_mesa_mesh_builder.build_local_size(
		obstacle_size,
		logical_tile_scale,
		world_uv_origin
	)
	_configure_mesa_collision_polygon(logical_tile_scale)
	queue_redraw()

func _configure_mesa_collision_polygon(logical_tile_scale: float) -> void:
	var rectangle := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if rectangle != null:
		rectangle.disabled = true
	var polygon := get_node_or_null(MESA_COLLISION_POLYGON_NAME) as CollisionPolygon2D
	if polygon == null:
		polygon = CollisionPolygon2D.new()
		polygon.name = MESA_COLLISION_POLYGON_NAME
		add_child(polygon)
	var radius := minf(
		RectilinearRockAreaMeshBuilder.CONVEX_CORNER_RADIUS_TILES * logical_tile_scale,
		minf(obstacle_size.x, obstacle_size.y) * 0.24
	)
	var rect := Rect2(-obstacle_size * 0.5, obstacle_size)
	var centers: Array[Vector2] = [
		Vector2(rect.position.x + radius, rect.position.y + radius),
		Vector2(rect.end.x - radius, rect.position.y + radius),
		Vector2(rect.end.x - radius, rect.end.y - radius),
		Vector2(rect.position.x + radius, rect.end.y - radius),
	]
	var start_angles: Array[float] = [PI, -PI * 0.5, 0.0, PI * 0.5]
	var points := PackedVector2Array()
	for corner in range(centers.size()):
		for segment in range(RectilinearRockAreaMeshBuilder.CONVEX_CORNER_SEGMENTS + 1):
			var angle := start_angles[corner] + PI * 0.5 * float(segment) / float(
				RectilinearRockAreaMeshBuilder.CONVEX_CORNER_SEGMENTS
			)
			points.append(centers[corner] + Vector2(cos(angle), sin(angle)) * radius)
	polygon.polygon = points
	polygon.build_mode = CollisionPolygon2D.BUILD_SOLIDS

func _ensure_default_mesa_visual() -> void:
	if not uses_mesa_visual() or _mesa_mesh_builder != null:
		return
	configure_mesa_visual(
		&"forest",
		&"plains",
		0,
		null,
		WorldGridConfig.LOGICAL_TILE_SCALE
	)

func _apply_asset_variation() -> void:
	if asset_sprite == null:
		return
	asset_sprite.flip_h = false
	asset_sprite.modulate = Color.WHITE
	if damage_overlay != null:
		damage_overlay.flip_h = false
	if obstacle_id != &"forest_tree":
		return
	var seed := _asset_variation_seed()
	asset_sprite.flip_h = seed % 2 == 0
	var crown_value := 0.94 + float(seed % 7) * 0.018
	var trunk_value := 0.96 + float(int(seed / 11) % 5) * 0.012
	asset_sprite.modulate = Color(crown_value, trunk_value, crown_value * 0.92, 1.0)
	_position_asset_sprite()
	if damage_overlay != null:
		damage_overlay.flip_h = asset_sprite.flip_h

func _asset_variation_seed(
	world_position_key: Vector2 = global_position
) -> int:
	var position_key := Vector2i(
		roundi(world_position_key.x / WorldGridConfig.LOGICAL_TILE_SCALE),
		roundi(world_position_key.y / WorldGridConfig.LOGICAL_TILE_SCALE)
	)
	return abs(
		String(obstacle_id).hash()
		+ position_key.x * 73856093
		+ position_key.y * 19349663
	)

func _scalable_target_size(
	manifest: EnvironmentAssetManifest,
	base_target: Vector2
) -> Vector2:
	# The base footprint defines the manifest native visual size; an instance can be
	# larger or smaller, so scale the native size by the instance/base ratio. The
	# logical tile scale cancels in the ratio (both terms use the same scale).
	var base_footprint := manifest.get_footprint_tiles(obstacle_id)
	if base_footprint.x <= 0:
		return base_target
	var base_width_px := float(base_footprint.x) * LEGACY_TILE_SCALE
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
		"step": 1,
		"root_center": Vector2(texture_size.x * 0.5, texture_size.y)
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
			"step": step,
			"root_center": Vector2(float(width) * 0.5, float(height))
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
	# Roots occupy the widest opaque row in the lowest 8% of the visible tree,
	# capped so low canopy branches cannot become the physical anchor. This is a
	# visual alignment metric only: collider size remains manifest-authored.
	var root_band_height := clampi(
		roundi(bounds.size.y * 0.08),
		maxi(step * 4, 12),
		maxi(step * 4, 32)
	)
	var root_center := Vector2(center_x, float(max_y))
	var widest_root_row := -1
	for root_row_index in range(row_min.size()):
		var root_scan_y := root_row_index * step
		if root_scan_y < max_y - root_band_height or root_scan_y > max_y:
			continue
		if row_max[root_row_index] < 0:
			continue
		var root_row_width := row_max[root_row_index] - row_min[root_row_index] + 1
		if root_row_width > widest_root_row:
			widest_root_row = root_row_width
			root_center = Vector2(
				(float(row_min[root_row_index]) + float(row_max[root_row_index])) * 0.5,
				float(root_scan_y)
			)
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
	return {
		"bounds": bounds,
		"profile": profile,
		"step": step,
		"root_center": root_center
	}

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

func _draw_rect_debug_footprint() -> void:
	var fill := Color(0.15, 0.60, 0.95, 0.16)
	var outline := Color(0.30, 0.80, 1.0, 0.92)
	if collision_shape_id == &"circle":
		var radius := minf(collision_size.x, collision_size.y) * 0.5
		draw_circle(collision_offset, radius, fill)
		draw_arc(collision_offset, radius, 0.0, TAU, 40, outline, 2.5, true)
		return
	var collision_rect := Rect2(
		collision_offset - collision_size * 0.5,
		collision_size
	)
	draw_rect(collision_rect, fill, true)
	draw_rect(collision_rect, outline, false, 2.5)
