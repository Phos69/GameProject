extends Node2D
class_name BriciolaCompanion

enum State { FOLLOW, ACQUIRE_TARGET, DASH_ATTACK, RECOVER, RETURN, SUPER_FRENZY }

var owner_player: Node2D
var state: State = State.FOLLOW
var target: Node2D
var follow_offset: Vector2 = Vector2(-30.0, 22.0)
var attack_range: float = 150.0
var return_range: float = 220.0
var follow_speed: float = 260.0
var dash_speed: float = 520.0
var attack_damage: int = 6
var attack_cooldown: float = 0.75
var cooldown_timer: float = 0.0
var frenzy_timer: float = 0.0
var bite_applied: bool = false
var animation_time: float = 0.0

func setup(next_owner: Node2D) -> void:
	owner_player = next_owner
	global_position = owner_player.global_position + follow_offset
	add_to_group("rpg_companions")
	set_process(true)
	queue_redraw()

func start_frenzy(duration: float) -> void:
	frenzy_timer = maxf(duration, 0.0)
	state = State.SUPER_FRENZY
	cooldown_timer = 0.0
	bite_applied = false
	queue_redraw()

func _process(delta: float) -> void:
	animation_time += delta
	if owner_player == null or not is_instance_valid(owner_player):
		queue_free()
		return
	cooldown_timer = maxf(cooldown_timer - delta, 0.0)
	frenzy_timer = maxf(frenzy_timer - delta, 0.0)
	if frenzy_timer <= 0.0 and state == State.SUPER_FRENZY:
		state = State.FOLLOW
	_update_state(delta)
	queue_redraw()

func _update_state(delta: float) -> void:
	if global_position.distance_to(owner_player.global_position) > return_range:
		state = State.RETURN
	match state:
		State.FOLLOW, State.RETURN:
			_move_toward(owner_player.global_position + follow_offset, follow_speed, delta)
			if cooldown_timer <= 0.0:
				target = _find_target()
				if target != null:
					state = State.DASH_ATTACK
					bite_applied = false
		State.ACQUIRE_TARGET:
			target = _find_target()
			state = State.DASH_ATTACK if target != null else State.FOLLOW
		State.DASH_ATTACK, State.SUPER_FRENZY:
			if target == null or not is_instance_valid(target):
				state = State.RECOVER
				return
			_move_toward(target.global_position, dash_speed, delta)
			if global_position.distance_to(target.global_position) <= 18.0 and not bite_applied:
				_apply_bite(target)
				bite_applied = true
				cooldown_timer = attack_cooldown * (0.45 if frenzy_timer > 0.0 else 1.0)
				state = State.RECOVER
		State.RECOVER:
			_move_toward(owner_player.global_position + follow_offset, follow_speed * 0.8, delta)
			if cooldown_timer <= attack_cooldown * 0.35:
				state = State.FOLLOW if frenzy_timer <= 0.0 else State.SUPER_FRENZY
				if frenzy_timer > 0.0:
					target = _find_target()

func _move_toward(destination: Vector2, speed: float, delta: float) -> void:
	global_position = global_position.move_toward(destination, speed * delta)

func _find_target() -> Node2D:
	var best_target: Node2D
	var best_score := INF
	var search_range := attack_range * (1.35 if frenzy_timer > 0.0 else 1.0)
	for candidate in get_tree().get_nodes_in_group("damageable_targets"):
		if not (candidate is Node2D) or candidate == owner_player:
			continue
		var health_component := candidate.get_node_or_null("HealthComponent") as HealthComponent
		if health_component == null or not health_component.is_alive():
			continue
		var distance := global_position.distance_to((candidate as Node2D).global_position)
		if distance > search_range:
			continue
		var low_hp_bonus := 40.0 if health_component.get_health_ratio() <= 0.35 else 0.0
		var owner_threat_bonus := maxf(0.0, 60.0 - owner_player.global_position.distance_to((candidate as Node2D).global_position))
		var score := distance - low_hp_bonus - owner_threat_bonus
		if score < best_score:
			best_score = score
			best_target = candidate as Node2D
	return best_target

func _apply_bite(next_target: Node2D) -> void:
	var health_system := get_tree().get_first_node_in_group("health_system") as HealthSystem
	if health_system == null:
		return
	var damage := roundi(float(attack_damage) * (1.75 if frenzy_timer > 0.0 else 1.0))
	health_system.apply_damage(next_target, damage, owner_player, &"briciola_bite", next_target.global_position)

func _draw() -> void:
	var body_color := Color(0.16, 0.18, 0.18, 1.0)
	var copper := Color(0.66, 0.34, 0.14, 1.0)
	var led := Color(0.30, 1.0, 0.92, 1.0)
	var pulse := 0.5 + 0.5 * sin(animation_time * 10.0)
	var scale_bonus := 1.25 if frenzy_timer > 0.0 else 1.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * scale_bonus)
	draw_rect(Rect2(Vector2(-11.0, -7.0), Vector2(22.0, 14.0)), body_color, true)
	draw_rect(Rect2(Vector2(-8.0, -5.0), Vector2(16.0, 10.0)), copper, false, 2.0)
	draw_circle(Vector2(7.0, -2.0), 2.2, led.lightened(pulse * 0.25))
	draw_circle(Vector2(7.0, 3.0), 2.2, led.lightened(pulse * 0.25))
	draw_line(Vector2(-9.0, 5.0), Vector2(-15.0, 10.0), copper, 2.5, true)
	draw_line(Vector2(9.0, 5.0), Vector2(15.0, 10.0), copper, 2.5, true)
	if state == State.DASH_ATTACK or frenzy_timer > 0.0:
		draw_arc(Vector2.ZERO, 16.0, 0.0, TAU, 24, Color(led, 0.55), 2.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
