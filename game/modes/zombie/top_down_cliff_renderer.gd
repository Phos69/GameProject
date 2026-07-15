extends Node2D
class_name TopDownCliffRenderer

const SVG_TEXTURE_LOADER = preload(
	"res://game/modes/zombie/environment_texture_loader.gd"
)

const FALL_ZONE_ID := &"fall_zone"
const VOID_EDGE_NEAR_ID := &"void_edge_near"
const VOID_DEPTH_ID := &"void_depth"
const VOID_VERTICAL_LINES_ID := &"void_vertical_lines"
const VALID_SIDES: Array[StringName] = [&"north", &"south", &"east", &"west"]

const FALL_ZONE_SPRITE_NAME := "FallZoneSprite"
const DEPTH_SPRITE_NAME := "VoidDepthSprite"
const VERTICAL_LINES_SPRITE_NAME := "VoidVerticalLinesSprite"
const EDGE_SPRITE_NAME := "VoidEdgeNearSprite"
const LIP_SPRITE_NAME := "CliffLipSprite"

var zone_size: Vector2 = Vector2(150.0, 72.0)
var fall_side: StringName = &"north"
var fall_style: StringName = &"cliff"
var edge_color: Color = Color(0.82, 0.58, 0.16, 0.92)
var depth_color: Color = Color(0.025, 0.028, 0.022, 1.0)
var visual_seed: int = 0
var show_debug_visual: bool = false
var procedural_fallback_active: bool = true

var asset_paths: Dictionary = {}
var loaded_asset_ids: Array[StringName] = []
var fall_zone_sprite: Sprite2D
var depth_sprite: Sprite2D
var vertical_lines_sprite: Sprite2D
var edge_sprite: Sprite2D
var lip_sprite: Sprite2D

func configure(
	next_zone_size: Vector2,
	next_fall_side: StringName,
	next_fall_style: StringName,
	next_edge_color: Color,
	next_depth_color: Color,
	next_visual_seed: int = 0,
	debug_visual_enabled: bool = false,
	disable_assets: bool = false
) -> void:
	zone_size = Vector2(
		maxf(next_zone_size.x, 32.0),
		maxf(next_zone_size.y, 24.0)
	)
	fall_side = _normalize_side(next_fall_side)
	fall_style = next_fall_style
	edge_color = next_edge_color
	depth_color = next_depth_color
	visual_seed = next_visual_seed
	show_debug_visual = debug_visual_enabled
	_ensure_sprites()
	if disable_assets:
		# Large internal void blocks must not stretch a small void tile across the
		# whole area (it rasterises into a grainy placeholder). The owning fall
		# zone renders a clean procedural void instead.
		procedural_fallback_active = true
		loaded_asset_ids.clear()
		_hide_sprites()
	else:
		_load_asset_sprites()
		_position_sprites()
	queue_redraw()

func _ready() -> void:
	_ensure_sprites()
	if loaded_asset_ids.is_empty():
		_load_asset_sprites()
		_position_sprites()

func has_assets() -> bool:
	return (
		not procedural_fallback_active
		and fall_zone_sprite != null
		and depth_sprite != null
		and vertical_lines_sprite != null
		and edge_sprite != null
		and lip_sprite != null
		and fall_zone_sprite.visible
		and depth_sprite.visible
		and vertical_lines_sprite.visible
		and edge_sprite.visible
		and lip_sprite.visible
	)

func uses_procedural_fallback() -> bool:
	return procedural_fallback_active

func get_asset_ids() -> Array[StringName]:
	return [
		FALL_ZONE_ID,
		VOID_EDGE_NEAR_ID,
		VOID_DEPTH_ID,
		VOID_VERTICAL_LINES_ID,
		get_cliff_lip_id()
	]

func get_loaded_asset_ids() -> Array[StringName]:
	return loaded_asset_ids.duplicate()

func get_asset_paths() -> Dictionary:
	return asset_paths.duplicate(true)

func get_cliff_lip_id() -> StringName:
	return StringName("cliff_lip_%s" % String(fall_side))

func get_fall_side() -> StringName:
	return fall_side

func get_vertical_line_count() -> int:
	var seed_value: int = absi(
		visual_seed
		+ int(zone_size.x) * 17
		+ int(zone_size.y) * 31
		+ int(hash(String(fall_side))) * 7
	)
	return 5 + seed_value % 4

func set_debug_visual_visible(enabled: bool) -> void:
	show_debug_visual = enabled
	queue_redraw()

func _draw() -> void:
	if procedural_fallback_active:
		return
	_draw_seeded_vertical_lines()
	if show_debug_visual:
		_draw_debug_overlay()

func _ensure_sprites() -> void:
	fall_zone_sprite = _ensure_sprite(FALL_ZONE_SPRITE_NAME, -5)
	depth_sprite = _ensure_sprite(DEPTH_SPRITE_NAME, -4)
	vertical_lines_sprite = _ensure_sprite(VERTICAL_LINES_SPRITE_NAME, -3)
	edge_sprite = _ensure_sprite(EDGE_SPRITE_NAME, -2)
	lip_sprite = _ensure_sprite(LIP_SPRITE_NAME, -1)

func _ensure_sprite(sprite_name: String, next_z_index: int) -> Sprite2D:
	var sprite := get_node_or_null(sprite_name) as Sprite2D
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = sprite_name
		add_child(sprite)
		sprite.owner = owner
	sprite.centered = true
	sprite.visible = false
	sprite.z_index = next_z_index
	sprite.y_sort_enabled = false
	return sprite

func _load_asset_sprites() -> void:
	procedural_fallback_active = true
	loaded_asset_ids.clear()
	asset_paths.clear()
	_hide_sprites()
	var manifest := EnvironmentAssetManifest.get_shared()
	for asset_id in get_asset_ids():
		var contract := manifest.get_void_asset_contract(asset_id)
		var asset_path := String(contract.get("asset_path", ""))
		asset_paths[asset_id] = asset_path
		if asset_path.is_empty() or not _asset_path_exists(asset_path):
			return
		var sprite := _sprite_for_asset(asset_id)
		if sprite == null:
			return
		var texture := SVG_TEXTURE_LOADER.load_texture(
			asset_path,
			_depth_color_for_style(),
			_edge_color_for_style(),
			_texture_size_for_asset(asset_id)
		)
		if texture == null:
			return
		sprite.texture = texture
		sprite.visible = true
		sprite.modulate = _modulate_for_asset(asset_id)
		loaded_asset_ids.append(asset_id)
	procedural_fallback_active = false

func _hide_sprites() -> void:
	for sprite in [
		fall_zone_sprite,
		depth_sprite,
		vertical_lines_sprite,
		edge_sprite,
		lip_sprite
	]:
		if sprite == null:
			continue
		sprite.texture = null
		sprite.visible = false

func _position_sprites() -> void:
	if procedural_fallback_active:
		return
	var horizontal := _side_is_horizontal()
	_fit_sprite(
		fall_zone_sprite,
		zone_size,
		Vector2.ZERO
	)
	_fit_sprite(
		depth_sprite,
		_depth_target_size(horizontal),
		_depth_position()
	)
	_fit_sprite(
		vertical_lines_sprite,
		_depth_target_size(horizontal),
		_depth_position() + _outward_direction() * 5.0
	)
	_fit_sprite(
		edge_sprite,
		_edge_target_size(horizontal),
		_edge_position()
	)
	_fit_sprite(
		lip_sprite,
		_edge_target_size(horizontal),
		_edge_position()
	)

func _fit_sprite(
	sprite: Sprite2D,
	target_size: Vector2,
	target_position: Vector2
) -> void:
	if sprite == null or sprite.texture == null:
		return
	var texture_size := sprite.texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	sprite.scale = Vector2(
		target_size.x / texture_size.x,
		target_size.y / texture_size.y
	)
	sprite.position = target_position

func _sprite_for_asset(asset_id: StringName) -> Sprite2D:
	match asset_id:
		FALL_ZONE_ID:
			return fall_zone_sprite
		VOID_EDGE_NEAR_ID:
			return edge_sprite
		VOID_DEPTH_ID:
			return depth_sprite
		VOID_VERTICAL_LINES_ID:
			return vertical_lines_sprite
		_:
			if asset_id == get_cliff_lip_id():
				return lip_sprite
	return null

func _texture_size_for_asset(asset_id: StringName) -> Vector2i:
	match asset_id:
		VOID_DEPTH_ID:
			return Vector2i(320, 180)
		VOID_VERTICAL_LINES_ID:
			return Vector2i(320, 180)
		_:
			return Vector2i(320, 160)

func _modulate_for_asset(asset_id: StringName) -> Color:
	match asset_id:
		VOID_DEPTH_ID:
			return Color(1.0, 1.0, 1.0, 0.92)
		VOID_VERTICAL_LINES_ID:
			return Color(1.08, 1.08, 1.08, 0.78)
		VOID_EDGE_NEAR_ID:
			return Color(1.10, 1.10, 1.10, 0.92)
		_:
			return Color.WHITE

func _depth_target_size(_horizontal: bool) -> Vector2:
	# Depth art fills the rectangular hazard footprint. The visible face inside
	# it may still be shaded directionally, but it never expands the gameplay base.
	return zone_size

func _edge_target_size(horizontal: bool) -> Vector2:
	if horizontal:
		return Vector2(zone_size.x, minf(maxf(zone_size.y * 0.35, 12.0), zone_size.y))
	return Vector2(minf(maxf(zone_size.x * 0.35, 12.0), zone_size.x), zone_size.y)

func _edge_position() -> Vector2:
	var half_size := zone_size * 0.5
	var edge_size := _edge_target_size(_side_is_horizontal())
	match fall_side:
		&"north":
			return Vector2(0.0, half_size.y - edge_size.y * 0.5)
		&"south":
			return Vector2(0.0, -half_size.y + edge_size.y * 0.5)
		&"west":
			return Vector2(half_size.x - edge_size.x * 0.5, 0.0)
		_:
			return Vector2(-half_size.x + edge_size.x * 0.5, 0.0)

func _depth_position() -> Vector2:
	return Vector2.ZERO

func _outward_direction() -> Vector2:
	match fall_side:
		&"north":
			return Vector2.UP
		&"south":
			return Vector2.DOWN
		&"west":
			return Vector2.LEFT
		_:
			return Vector2.RIGHT

func _side_is_horizontal() -> bool:
	return fall_side == &"north" or fall_side == &"south"

func _draw_seeded_vertical_lines() -> void:
	var count := get_vertical_line_count()
	var half_size := zone_size * 0.5
	var edge_position := _edge_position()
	var outward := _outward_direction()
	var line_color := Color(_edge_color_for_style().darkened(0.32), 0.58)
	if _side_is_horizontal():
		for index in range(count):
			var ratio := float(index + 1) / float(count + 1)
			var jitter := _seeded_unit(index) * zone_size.x * 0.035
			var x_position := lerpf(
				-half_size.x * 0.44,
				half_size.x * 0.44,
				ratio
			) + jitter
			var start := Vector2(x_position, edge_position.y)
			var length := clampf(
				zone_size.y * (0.70 + _seeded_unit(index + 17) * 0.16),
				minf(zone_size.y, 12.0),
				zone_size.y
			)
			var end := start + outward * length
			draw_line(start, end, line_color, 2.0, true)
	else:
		for index in range(count):
			var ratio := float(index + 1) / float(count + 1)
			var jitter := _seeded_unit(index) * zone_size.y * 0.035
			var y_position := lerpf(
				-half_size.y * 0.44,
				half_size.y * 0.44,
				ratio
			) + jitter
			var start := Vector2(edge_position.x, y_position)
			var length := clampf(
				zone_size.x * (0.70 + _seeded_unit(index + 17) * 0.16),
				minf(zone_size.x, 12.0),
				zone_size.x
			)
			var end := start + outward * length
			draw_line(start, end, line_color, 2.0, true)

func _draw_debug_overlay() -> void:
	var half_size := zone_size * 0.5
	var rect := Rect2(-half_size, zone_size)
	draw_rect(rect, Color(0.18, 0.80, 1.0, 0.55), false, 2.0)
	draw_line(
		_edge_position() - _edge_parallel_direction() * 24.0,
		_edge_position() + _edge_parallel_direction() * 24.0,
		Color(1.0, 0.95, 0.24, 0.86),
		3.0,
		true
	)

func _edge_parallel_direction() -> Vector2:
	if _side_is_horizontal():
		return Vector2.RIGHT
	return Vector2.DOWN

func _seeded_unit(index: int) -> float:
	var value := int(
		hash(
			"%d:%s:%s:%d" % [
				visual_seed,
				String(fall_style),
				String(fall_side),
				index
			]
		)
	)
	var normalized := float(abs(value % 2001)) / 1000.0
	return normalized - 1.0

func _normalize_side(value: StringName) -> StringName:
	if VALID_SIDES.has(value):
		return value
	return &"north"

func _depth_color_for_style() -> Color:
	match fall_style:
		&"toxic_cliff":
			return Color(0.018, 0.035, 0.024, 1.0)
		&"lava_cliff":
			return Color(0.055, 0.018, 0.012, 1.0)
		&"ice_cliff":
			return Color(0.018, 0.030, 0.042, 1.0)
		&"marsh_cliff":
			return Color(0.014, 0.026, 0.030, 1.0)
		_:
			return depth_color

func _edge_color_for_style() -> Color:
	match fall_style:
		&"toxic_cliff":
			return Color(edge_color.lightened(0.10), 0.92)
		&"lava_cliff":
			return Color(0.98, 0.30, 0.10, 0.92)
		&"ice_cliff":
			return Color(0.54, 0.82, 0.96, 0.92)
		&"marsh_cliff":
			return Color(0.22, 0.56, 0.50, 0.92)
		_:
			return edge_color

func _asset_path_exists(asset_path: String) -> bool:
	if asset_path.is_empty():
		return false
	if ResourceLoader.exists(asset_path):
		return true
	return FileAccess.file_exists(asset_path)
