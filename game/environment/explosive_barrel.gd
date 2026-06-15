extends Area2D
class_name ExplosiveBarrel

signal warning_started(barrel: ExplosiveBarrel, duration: float, radius: float)
signal exploded(barrel: ExplosiveBarrel, damaged_targets: Array[Node])

@export_range(0.05, 5.0, 0.05) var warning_duration: float = 0.8
@export_range(20.0, 300.0, 1.0) var explosion_radius: float = 118.0
@export_range(1, 500, 1) var explosion_damage: int = 48
@export var body_color: Color = Color(0.42, 0.34, 0.18, 1.0)
@export var warning_color: Color = Color(1.0, 0.38, 0.12, 1.0)

@onready var health_component := $HealthComponent as HealthComponent

var is_armed: bool = false
var has_exploded: bool = false
var warning_time_left: float = 0.0
var high_contrast: bool = false

func _ready() -> void:
	add_to_group("interactive_environment_props")
	add_to_group("visual_settings_consumers")
	VisualSettingsManager.sync_consumer(self)
	health_component.died.connect(_on_health_depleted)
	queue_redraw()

func apply_visual_settings(settings: Dictionary) -> void:
	high_contrast = bool(settings.get("high_contrast", false))
	queue_redraw()

func _process(delta: float) -> void:
	if is_armed and not has_exploded:
		advance_warning(delta)
	queue_redraw()

func configure_colors(primary: Color, warning: Color) -> void:
	body_color = primary
	warning_color = warning
	queue_redraw()

func arm_explosion() -> bool:
	if is_armed or has_exploded:
		return false
	is_armed = true
	warning_time_left = warning_duration
	collision_layer = 0
	set_deferred("monitorable", false)
	warning_started.emit(self, warning_duration, explosion_radius)
	queue_redraw()
	return true

func advance_warning(delta: float) -> void:
	if not is_armed or has_exploded:
		return
	warning_time_left = maxf(warning_time_left - maxf(delta, 0.0), 0.0)
	if warning_time_left <= 0.0:
		_explode()

func _on_health_depleted() -> void:
	arm_explosion()

func _explode() -> void:
	if has_exploded:
		return
	has_exploded = true
	is_armed = false
	var damaged_targets: Array[Node] = []
	var seen_ids: Dictionary = {}
	var health_system := get_tree().get_first_node_in_group(
		"health_system"
	) as HealthSystem
	if health_system != null:
		for group_name in [&"players", &"enemies", &"bosses"]:
			for target in get_tree().get_nodes_in_group(group_name):
				if not target is Node2D or target == self:
					continue
				var instance_id := target.get_instance_id()
				if seen_ids.has(instance_id):
					continue
				seen_ids[instance_id] = true
				if global_position.distance_to(
					(target as Node2D).global_position
				) > explosion_radius:
					continue
				var applied_damage := health_system.apply_damage(
					target,
					explosion_damage
				)
				if applied_damage > 0:
					damaged_targets.append(target)
	var gameplay_effects := get_tree().get_first_node_in_group(
		"gameplay_effects"
	) as GameplayEffects
	if gameplay_effects != null:
		gameplay_effects.spawn_environment_explosion(
			global_position,
			warning_color,
			explosion_radius
		)
	exploded.emit(self, damaged_targets)
	queue_free()

func _draw() -> void:
	var shadow_color := Color(0.0, 0.0, 0.0, 0.42)
	_draw_shadow_ellipse(Vector2(0.0, 18.0), Vector2(22.0, 8.0), shadow_color)
	draw_rect(Rect2(-17.0, -20.0, 34.0, 40.0), body_color, true)
	draw_rect(Rect2(-17.0, -18.0, 34.0, 8.0), body_color.lightened(0.18), true)
	draw_rect(Rect2(-17.0, 8.0, 34.0, 8.0), body_color.darkened(0.16), true)
	draw_line(Vector2(-17.0, -3.0), Vector2(17.0, -3.0), warning_color, 4.0, true)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(0.0, -10.0),
			Vector2(8.0, 5.0),
			Vector2(-8.0, 5.0)
		]),
		Color(warning_color, 0.88)
	)
	draw_circle(Vector2.ZERO, 2.5, Color(0.08, 0.06, 0.04, 1.0))
	if not is_armed:
		return
	var ratio := (
		warning_time_left / warning_duration
		if warning_duration > 0.0
		else 0.0
	)
	var pulse := 0.42 + (1.0 - ratio) * 0.42
	draw_circle(
		Vector2.ZERO,
		explosion_radius,
		Color(warning_color, pulse * 0.16)
	)
	draw_arc(
		Vector2.ZERO,
		explosion_radius,
		-PI / 2.0,
		-PI / 2.0 + TAU * (1.0 - ratio),
		64,
		Color.WHITE if high_contrast else Color(warning_color, pulse),
		7.0 if high_contrast else 5.0,
		true
	)
	draw_arc(
		Vector2.ZERO,
		28.0 + (1.0 - ratio) * 10.0,
		0.0,
		TAU,
		32,
		Color(warning_color, pulse),
		4.0,
		true
	)

func _draw_shadow_ellipse(
	center: Vector2,
	radii: Vector2,
	color: Color
) -> void:
	var points := PackedVector2Array()
	for index in range(25):
		var angle := TAU * float(index) / 24.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
