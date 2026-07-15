extends CharacterBody2D
class_name PlayerController

signal entity_state_changed(previous_state: StringName, current_state: StringName)

const STARTER_WEAPON: WeaponData = preload("res://game/weapons/starter_pistol.tres")

enum EntityState {
	NORMAL,
	DODGING,
	FALLING,
	DEAD
}

@export_range(1, 4) var player_slot: int = 1
@export var move_speed: float = 260.0
@export var acceleration: float = 1700.0
@export var friction: float = 1900.0
@export var aim_line_length: float = 46.0
@export var slot_colors: Array[Color] = [
	Color(0.18, 0.74, 0.95, 1.0),
	Color(0.95, 0.42, 0.34, 1.0),
	Color(0.52, 0.86, 0.32, 1.0),
	Color(0.94, 0.78, 0.28, 1.0)
]

@onready var visual := $Visual as PlayerVisual
@onready var aim_line := $AimLine as Line2D
@onready var world_hud = $WorldHud
@onready var weapon_system = $WeaponSystem
@onready var rpg_component := $RpgPlayerComponent as RpgPlayerComponent
@onready var dodge_component := $PlayerDodgeComponent as PlayerDodgeComponent
@onready var void_fall_component := $VoidFallComponent as EntityVoidFallComponent
@onready var health_component := $HealthComponent as HealthComponent
@onready var revive_indicator := $ReviveIndicator as ReviveIndicatorVisual

var facing_direction: Vector2 = Vector2.RIGHT
var input_manager: InputManager
var game_mode_manager: GameModeManager
var hazard_system: HazardSystem
var base_max_health: int = 100
var base_move_speed: float = 260.0
var current_run_health_bonus: int = 0
var character_speed_multiplier: float = 1.0
var environment_speed_multiplier: float = 1.0
var weapon_feedback_label: Label
var has_prepared_run: bool = false
var current_entity_state: EntityState = EntityState.NORMAL
var gameplay_input_enabled: bool = true

func _ready() -> void:
	add_to_group("players")
	_resolve_runtime_dependencies()
	health_component.died.connect(_on_died)
	health_component.downed.connect(_on_downed)
	health_component.revived.connect(_on_revived)
	health_component.damaged.connect(_on_damaged)
	weapon_system.fired.connect(_on_weapon_fired)
	weapon_system.reload_started.connect(_on_reload_started)
	weapon_system.reload_finished.connect(_on_reload_finished)
	weapon_system.weapon_changed.connect(_on_weapon_changed)
	weapon_system.weapon_switch_feedback.connect(_on_weapon_switch_feedback)
	rpg_component.character_changed.connect(_on_rpg_character_changed)
	rpg_component.stats_changed.connect(_on_rpg_stats_changed)
	rpg_component.leveled_up.connect(_on_rpg_leveled_up)
	dodge_component.dodge_started.connect(_on_dodge_started)
	dodge_component.dodge_finished.connect(_on_dodge_finished)
	void_fall_component.fall_finished.connect(_on_void_fall_finished)
	base_max_health = health_component.max_health
	base_move_speed = move_speed
	_apply_slot_color()
	visual.set_player_slot(player_slot)
	if world_hud != null:
		world_hud.set_player_slot(player_slot)
	visual.set_weapon_data(weapon_system.weapon_data)
	_update_aim_line()
	_create_weapon_feedback_label()

func configure_runtime_dependencies(
	next_input_manager: InputManager,
	next_game_mode_manager: GameModeManager,
	next_hazard_system: HazardSystem
) -> void:
	if next_input_manager != null:
		input_manager = next_input_manager
	if next_game_mode_manager != null:
		game_mode_manager = next_game_mode_manager
	if next_hazard_system != null:
		hazard_system = next_hazard_system

func _physics_process(delta: float) -> void:
	if health_component.is_incapacitated():
		_set_entity_state(EntityState.DEAD)
		velocity = Vector2.ZERO
		visual.set_motion(velocity, move_speed)
		return
	if void_fall_component != null and void_fall_component.is_falling:
		velocity = Vector2.ZERO
		visual.set_motion(velocity, move_speed)
		return
	if game_mode_manager == null:
		_resolve_runtime_dependencies()
	if game_mode_manager != null and not game_mode_manager.is_gameplay_active():
		velocity = Vector2.ZERO
		visual.set_motion(velocity, move_speed)
		return
	if not gameplay_input_enabled:
		velocity = Vector2.ZERO
		visual.set_motion(velocity, move_speed)
		return
	if input_manager == null:
		_resolve_runtime_dependencies()
		if input_manager == null:
			return

	var move_input: Vector2 = input_manager.get_player_move_vector(player_slot)
	if dodge_component != null:
		dodge_component.process_cooldown(delta)
	if dodge_component != null and dodge_component.is_dodging:
		dodge_component.physics_process_dodge(delta)
		visual.set_motion(velocity, move_speed)
		return
	if _handle_dodge_input(move_input):
		if dodge_component != null:
			dodge_component.physics_process_dodge(delta)
		visual.set_motion(velocity, move_speed)
		return
	var desired_velocity: Vector2 = _movement_from_input(move_input) * move_speed

	if desired_velocity.length_squared() > 0.01:
		velocity = velocity.move_toward(desired_velocity, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	move_and_slide()
	_update_facing(move_input)
	visual.set_motion(velocity, move_speed)
	_handle_weapon_input()
	_set_entity_state(EntityState.NORMAL)

func get_entity_state_name() -> StringName:
	match current_entity_state:
		EntityState.DODGING:
			return &"dodging"
		EntityState.FALLING:
			return &"falling"
		EntityState.DEAD:
			return &"dead"
		_:
			return &"normal"

func set_gameplay_input_enabled(enabled: bool) -> void:
	gameplay_input_enabled = enabled
	if not gameplay_input_enabled:
		velocity = Vector2.ZERO

func try_start_void_fall() -> bool:
	if (
		current_entity_state == EntityState.DODGING
		or current_entity_state == EntityState.FALLING
		or health_component == null
		or health_component.is_incapacitated()
		or void_fall_component == null
	):
		return false
	if hazard_system == null:
		_resolve_runtime_dependencies()
	if (
		hazard_system == null
		or not hazard_system.has_method("is_void_at_world_position")
		or not bool(hazard_system.is_void_at_world_position(global_position))
	):
		return false
	velocity = Vector2.ZERO
	aim_line.hide()
	visual.finish_dodge()
	if not void_fall_component.begin_fall(global_position, visual):
		return false
	_set_entity_state(EntityState.FALLING)
	return true

func _handle_dodge_input(move_input: Vector2) -> bool:
	if dodge_component == null or input_manager == null:
		return false
	if not input_manager.is_player_dodge_just_pressed(player_slot):
		return false
	var dodge_direction := facing_direction
	if move_input.length() > 0.20:
		var move_direction := _movement_from_input(move_input)
		if move_direction.length_squared() > 0.01:
			dodge_direction = move_direction.normalized()
	return dodge_component.try_start(dodge_direction)

func _movement_from_input(input_vector: Vector2) -> Vector2:
	if input_vector.length_squared() <= 0.01:
		return Vector2.ZERO
	return input_vector.normalized() * minf(input_vector.length(), 1.0)

func _update_facing(move_input: Vector2) -> void:
	var aim_input: Vector2 = input_manager.get_player_aim_vector(player_slot)
	if aim_input.length() > 0.20:
		facing_direction = aim_input.normalized()
	elif move_input.length() > 0.20:
		var move_direction := _movement_from_input(move_input)
		if move_direction.length_squared() > 0.01:
			facing_direction = move_direction.normalized()
	_update_aim_line()

func _update_aim_line() -> void:
	if aim_line == null:
		return
	aim_line.points = PackedVector2Array([Vector2.ZERO, facing_direction * aim_line_length])
	visual.set_facing(facing_direction)

func _apply_slot_color() -> void:
	if visual == null or slot_colors.is_empty():
		return
	var index := clampi(player_slot - 1, 0, slot_colors.size() - 1)
	visual.set_slot_color(slot_colors[index])
	if world_hud != null:
		world_hud.set_slot_color(slot_colors[index])
	revive_indicator.set_slot_color(slot_colors[index])

func _handle_weapon_input() -> void:
	if weapon_system == null:
		return
	if input_manager.is_player_weapon_previous_just_pressed(player_slot):
		weapon_system.switch_weapon(-1)
	if input_manager.is_player_weapon_next_just_pressed(player_slot):
		weapon_system.switch_weapon(1)
	if input_manager.is_player_reload_just_pressed(player_slot):
		weapon_system.start_reload()
	var super_activated := false
	if input_manager.is_player_super_just_pressed(player_slot):
		super_activated = (
			rpg_component != null
			and rpg_component.try_activate_super(facing_direction)
		)
		if super_activated:
			visual.play_fire()
	if super_activated:
		return
	var attack_origin := global_position + facing_direction * 22.0
	if input_manager.is_player_base_attack_pressed(player_slot):
		weapon_system.try_fire_base(
			attack_origin,
			facing_direction,
			self
		)
	if input_manager.is_player_equipped_attack_pressed(player_slot):
		weapon_system.try_fire_equipped(
			attack_origin,
			facing_direction,
			self
		)

func prepare_for_run(max_health_bonus: int = 0) -> void:
	current_run_health_bonus = maxi(max_health_bonus, 0)
	if weapon_system != null and has_prepared_run:
		weapon_system.reset_for_run(weapon_system.fallback_weapon_data)
	has_prepared_run = true
	_apply_rpg_runtime_stats(true)
	velocity = Vector2.ZERO
	if dodge_component != null:
		dodge_component.reset_runtime()
	if void_fall_component != null:
		void_fall_component.reset_runtime()
	_set_entity_state(EntityState.NORMAL)
	visual.reset_visual()
	revive_indicator.set_downed(false)

func apply_rpg_character(character_id: StringName) -> bool:
	if rpg_component == null:
		return false
	var applied := rpg_component.apply_character(character_id)
	if applied:
		_equip_rpg_base_weapon()
	if applied and game_mode_manager != null and game_mode_manager.is_gameplay_active():
		_apply_rpg_runtime_stats(true)
	return applied

func clear_rpg_character() -> void:
	if rpg_component != null:
		rpg_component.clear_character()
	if weapon_system != null:
		weapon_system.set_base_weapon(STARTER_WEAPON)
	_apply_rpg_runtime_stats(true)

func set_revive_progress(ratio: float, active: bool) -> void:
	revive_indicator.set_revive_progress(ratio, active)

func is_downed() -> bool:
	return health_component.is_downed

func set_environment_speed_multiplier(multiplier: float) -> void:
	environment_speed_multiplier = clampf(multiplier, 0.25, 1.25)
	_refresh_move_speed()

func get_environment_speed_multiplier() -> float:
	return environment_speed_multiplier

func _on_downed() -> void:
	_set_entity_state(EntityState.DEAD)
	velocity = Vector2.ZERO
	visual.play_downed()
	revive_indicator.set_downed(true)
	aim_line.hide()

func _on_revived(_current_health: int, _max_health: int) -> void:
	_set_entity_state(EntityState.NORMAL)
	velocity = Vector2.ZERO
	visual.reset_visual()
	revive_indicator.set_downed(false)

func _on_died() -> void:
	_set_entity_state(EntityState.DEAD)
	velocity = Vector2.ZERO
	visual.play_dead()
	aim_line.hide()

func _on_damaged(_amount: int, _current_health: int, _max_health: int) -> void:
	visual.play_hurt()

func _on_weapon_fired(
	_origin: Vector2,
	_direction: Vector2,
	_damage: int
) -> void:
	visual.play_fire()

func _on_reload_started(duration: float) -> void:
	visual.play_reload(duration)

func _on_reload_finished() -> void:
	if rpg_component != null:
		rpg_component.notify_reload_finished()

func _on_weapon_changed(weapon_data: WeaponData) -> void:
	visual.set_weapon_data(weapon_data)

func _create_weapon_feedback_label() -> void:
	weapon_feedback_label = Label.new()
	weapon_feedback_label.name = "WeaponFeedback"
	weapon_feedback_label.position = Vector2(-86.0, -68.0)
	weapon_feedback_label.size = Vector2(172.0, 28.0)
	weapon_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	weapon_feedback_label.add_theme_font_size_override("font_size", 14)
	weapon_feedback_label.add_theme_constant_override("outline_size", 4)
	weapon_feedback_label.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.03, 0.95))
	weapon_feedback_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	weapon_feedback_label.hide()
	add_child(weapon_feedback_label)

func _on_weapon_switch_feedback(text: String, definition: WeaponData) -> void:
	if weapon_feedback_label == null:
		return
	weapon_feedback_label.text = text
	weapon_feedback_label.modulate = (
		definition.visual_data.projectile_color
		if definition != null and definition.visual_data != null
		else Color(1.0, 0.82, 0.34, 1.0)
	)
	weapon_feedback_label.show()
	var tween := create_tween()
	tween.tween_interval(1.0)
	tween.tween_property(weapon_feedback_label, "modulate:a", 0.0, 0.45)
	tween.tween_callback(weapon_feedback_label.hide)

func _on_rpg_character_changed(_character_id: StringName, profile: Dictionary) -> void:
	visual.set_character_profile(profile)
	if world_hud != null:
		world_hud.set_character_profile(profile)

func _apply_rpg_runtime_stats(refill_health: bool) -> void:
	var resolved_max_health := base_max_health + current_run_health_bonus
	character_speed_multiplier = 1.0
	if rpg_component != null and rpg_component.has_character():
		resolved_max_health = rpg_component.get_max_hp() + current_run_health_bonus
		character_speed_multiplier = rpg_component.get_speed_multiplier()
	health_component.set_max_health(resolved_max_health, refill_health)
	_refresh_move_speed()

func _refresh_move_speed() -> void:
	move_speed = (
		base_move_speed
		* character_speed_multiplier
		* environment_speed_multiplier
	)

func _equip_rpg_base_weapon() -> void:
	if rpg_component == null or not rpg_component.has_character():
		return
	var weapon_id := StringName(
		rpg_component.character_profile.get("base_weapon_id", &"")
	)
	var base_weapon := RpgCharacterRegistry.load_base_weapon(weapon_id)
	if base_weapon != null and weapon_system != null:
		weapon_system.set_base_weapon(base_weapon)

func _on_rpg_stats_changed() -> void:
	if health_component == null:
		return
	_apply_rpg_runtime_stats(false)

func _on_rpg_leveled_up(_level: int) -> void:
	_apply_rpg_runtime_stats(false)
	if health_component != null and health_component.is_alive():
		health_component.heal(roundi(float(health_component.max_health) * 0.25))

func _on_dodge_started(
	direction: Vector2,
	_target_position: Vector2,
	_crosses_gap: bool
) -> void:
	_set_entity_state(EntityState.DODGING)
	visual.play_dodge(direction, dodge_component.dodge_duration)
	aim_line.hide()

func _on_dodge_finished() -> void:
	visual.finish_dodge()
	if try_start_void_fall():
		return
	_set_entity_state(EntityState.NORMAL)

func _on_void_fall_finished(fall_origin: Vector2) -> void:
	if hazard_system == null:
		_resolve_runtime_dependencies()
	if (
		hazard_system != null
		and hazard_system.has_method("complete_player_fall")
	):
		hazard_system.complete_player_fall(self, fall_origin)
	if health_component != null and health_component.is_alive():
		_set_entity_state(EntityState.NORMAL)
	else:
		_set_entity_state(EntityState.DEAD)

func _set_entity_state(next_state: EntityState) -> void:
	if current_entity_state == next_state:
		return
	var previous_state := get_entity_state_name()
	current_entity_state = next_state
	entity_state_changed.emit(previous_state, get_entity_state_name())

func _resolve_runtime_dependencies() -> void:
	if input_manager == null:
		input_manager = _resolve_node(&"input_manager") as InputManager
	if game_mode_manager == null:
		game_mode_manager = _resolve_node(&"game_mode_manager") as GameModeManager
	if hazard_system == null:
		hazard_system = _resolve_node(&"hazard_system") as HazardSystem

func _resolve_node(group_name: StringName) -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group(group_name)
