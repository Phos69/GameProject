extends Node2D
class_name SupplyCrateVisual

const SUPPLY_CRATE_ASSET_ID := &"supply_crate"
const ASSET_SPRITE_NAME := "AssetSprite"
const SVG_TEXTURE_LOADER = preload(
	"res://game/modes/zombie/environment_texture_loader.gd"
)
const CONTENT_ALPHA_THRESHOLD := 0.08

var animation_time: float = 0.0
var glow_intensity: float = 1.0
var high_contrast: bool = false
var reduced_motion: bool = false
var crate_type: StringName = &"common"
var body_color: Color = Color(0.18, 0.58, 0.68, 1.0)
var accent_color: Color = Color(0.95, 0.66, 0.15, 1.0)
var asset_path: String = ""
var asset_sprite: Sprite2D
var procedural_fallback_active: bool = false

func _ready() -> void:
	add_to_group("visual_settings_consumers")
	_load_asset_sprite()
	VisualSettingsManager.sync_consumer(self)

func _process(delta: float) -> void:
	if not reduced_motion:
		animation_time += delta
	queue_redraw()

func apply_visual_settings(settings: Dictionary) -> void:
	glow_intensity = clampf(
		float(settings.get("glow_intensity", 1.0)),
		0.0,
		1.0
	)
	high_contrast = bool(settings.get("high_contrast", false))
	reduced_motion = bool(settings.get("reduced_motion", false))
	if reduced_motion:
		animation_time = 0.0
	queue_redraw()

func configure_crate_type(next_crate_type: StringName) -> void:
	crate_type = next_crate_type
	match crate_type:
		&"medical":
			body_color = Color(0.24, 0.68, 0.42, 1.0)
			accent_color = Color(0.92, 0.98, 0.94, 1.0)
		&"military":
			body_color = Color(0.35, 0.38, 0.24, 1.0)
			accent_color = Color(0.94, 0.72, 0.20, 1.0)
		&"biome_toxic":
			body_color = Color(0.20, 0.62, 0.26, 1.0)
			accent_color = Color(0.58, 1.0, 0.26, 1.0)
		&"biome_fire":
			body_color = Color(0.62, 0.24, 0.12, 1.0)
			accent_color = Color(1.0, 0.55, 0.12, 1.0)
		&"biome_frost":
			body_color = Color(0.28, 0.56, 0.68, 1.0)
			accent_color = Color(0.70, 0.94, 1.0, 1.0)
		&"biome_marsh":
			body_color = Color(0.18, 0.46, 0.40, 1.0)
			accent_color = Color(0.34, 0.82, 0.70, 1.0)
		_:
			body_color = Color(0.18, 0.58, 0.68, 1.0)
			accent_color = Color(0.95, 0.66, 0.15, 1.0)
	_load_asset_sprite()
	queue_redraw()

func get_asset_path() -> String:
	return asset_path

func has_asset_sprite() -> bool:
	return (
		asset_sprite != null
		and is_instance_valid(asset_sprite)
		and asset_sprite.texture != null
		and asset_sprite.visible
	)

func uses_procedural_fallback() -> bool:
	return procedural_fallback_active

func get_asset_visual_bounds() -> Rect2:
	if not has_asset_sprite():
		return Rect2()
	var texture_size := asset_sprite.texture.get_size()
	var content_rect := _get_content_bounds(asset_sprite.texture)
	return Rect2(
		asset_sprite.position
			+ (content_rect.position - texture_size * 0.5) * asset_sprite.scale.abs(),
		content_rect.size * asset_sprite.scale.abs()
	)

func _draw() -> void:
	var glow_alpha := (
		0.16 + (sin(animation_time * 3.0) + 1.0) * 0.05
	) * glow_intensity
	draw_colored_polygon(
		GeometryUtils.ellipse_points(Vector2(0.0, 20.0), Vector2(29.0, 8.0), 18),
		Color(0.01, 0.015, 0.02, 0.52)
	)
	draw_circle(Vector2.ZERO, 31.0, Color(accent_color, glow_alpha))
	if has_asset_sprite():
		return
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(-27.0, -14.0),
			Vector2(21.0, -14.0),
			Vector2(27.0, -7.0),
			Vector2(27.0, 16.0),
			Vector2(-27.0, 16.0)
		]),
		Color(0.055, 0.10, 0.13, 1.0)
	)
	draw_rect(Rect2(-24.0, -11.0, 48.0, 23.0), body_color, true)
	draw_rect(
		Rect2(-24.0, -11.0, 48.0, 23.0),
		Color.WHITE if high_contrast else Color(0.55, 0.92, 1.0, 0.9),
		false,
		3.0 if high_contrast else 2.0
	)
	draw_rect(Rect2(-5.0, -11.0, 10.0, 23.0), accent_color, true)
	draw_rect(Rect2(-9.0, -2.0, 18.0, 8.0), Color(0.05, 0.08, 0.09, 1.0), true)
	if crate_type == &"medical":
		draw_rect(Rect2(-2.0, -7.0, 4.0, 18.0), accent_color, true)
		draw_rect(Rect2(-8.0, -2.0, 16.0, 6.0), accent_color, true)
	else:
		draw_colored_polygon(
			PackedVector2Array([
				Vector2(-7.0, 5.0),
				Vector2(0.0, -6.0),
				Vector2(7.0, 5.0)
			]),
			accent_color.lightened(0.18)
		)
	for x in [-20.0, 20.0]:
		draw_circle(Vector2(x, 9.0), 2.5, Color(0.04, 0.07, 0.08, 1.0))

func _load_asset_sprite() -> void:
	asset_sprite = get_node_or_null(ASSET_SPRITE_NAME) as Sprite2D
	if asset_sprite == null:
		asset_sprite = Sprite2D.new()
		asset_sprite.name = ASSET_SPRITE_NAME
		add_child(asset_sprite)
	asset_sprite.centered = true
	asset_sprite.visible = false
	asset_sprite.texture = null
	procedural_fallback_active = true
	var manifest := EnvironmentAssetManifest.get_shared()
	asset_path = manifest.get_object_asset_path(SUPPLY_CRATE_ASSET_ID, crate_type)
	if asset_path.is_empty():
		return
	var texture := SVG_TEXTURE_LOADER.load_texture(
		asset_path,
		body_color,
		accent_color
	)
	if texture == null:
		return
	asset_sprite.texture = texture
	asset_sprite.visible = true
	procedural_fallback_active = false
	_position_asset_sprite()
	_update_asset_modulate()

func _position_asset_sprite() -> void:
	if asset_sprite == null or asset_sprite.texture == null:
		return
	var texture_size := asset_sprite.texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var target_width := 64.0
	var target_height := 52.0
	var visual_scale := EnvironmentAssetManifest.get_shared().get_visual_scale(
		SUPPLY_CRATE_ASSET_ID
	)
	var scale_factor := minf(
		target_width * visual_scale / texture_size.x,
		target_height * visual_scale / texture_size.y
	)
	var min_scale := 0.25 if asset_path.ends_with(".svg") else 0.04
	asset_sprite.scale = Vector2.ONE * clampf(scale_factor, min_scale, 1.25)
	var content_rect := _get_content_bounds(asset_sprite.texture)
	var canvas_center := texture_size * 0.5
	var content_center_x := content_rect.get_center().x
	var content_bottom := content_rect.end.y
	asset_sprite.position = Vector2(
		-(content_center_x - canvas_center.x) * asset_sprite.scale.x,
		18.0 - (content_bottom - canvas_center.y) * asset_sprite.scale.y
	)

func _get_content_bounds(texture: Texture2D) -> Rect2:
	var texture_size := texture.get_size()
	var fallback := Rect2(Vector2.ZERO, texture_size)
	var image := texture.get_image()
	if image == null or image.is_empty():
		return fallback
	if image.is_compressed():
		image = image.duplicate()
		image.decompress()
	var width := image.get_width()
	var height := image.get_height()
	var step := maxi(1, int(round(maxf(float(width), float(height)) / 256.0)))
	var min_x := width
	var min_y := height
	var max_x := -1
	var max_y := -1
	for y in range(0, height, step):
		for x in range(0, width, step):
			if image.get_pixel(x, y).a <= CONTENT_ALPHA_THRESHOLD:
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
	if max_x < min_x or max_y < min_y:
		return fallback
	var bounds_min := Vector2i(maxi(min_x - step, 0), maxi(min_y - step, 0))
	var bounds_max := Vector2i(
		mini(max_x + step, width - 1),
		mini(max_y + step, height - 1)
	)
	return Rect2(bounds_min, bounds_max - bounds_min + Vector2i.ONE)

func _update_asset_modulate() -> void:
	if asset_sprite == null:
		return
	asset_sprite.modulate = Color.WHITE if not high_contrast else Color(1.08, 1.08, 1.08, 1.0)

