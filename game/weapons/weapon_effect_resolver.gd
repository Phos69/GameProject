extends RefCounted
class_name WeaponEffectResolver

class WeaponStatusRuntime extends Node2D:
	var target: Node
	var owner_ref: Node
	var source_id: StringName
	var effects: Dictionary = {}
	var tick_timer: float = 0.0
	var base_move_speed: float = -1.0

	func configure(target_node: Node, owner_node: Node, weapon_id: StringName) -> void:
		target = target_node
		owner_ref = owner_node
		source_id = weapon_id
		name = "WeaponStatusRuntime"
		z_index = 40
		if _has_property(target, &"move_speed"):
			base_move_speed = float(target.get("move_speed"))

	func add_effect(effect_id: StringName, duration: float, strength: float) -> void:
		effects[effect_id] = {
			"time_left": maxf(duration, 0.15),
			"strength": maxf(strength, 0.05)
		}
		_apply_speed_modifier()
		queue_redraw()

	func _process(delta: float) -> void:
		if target == null or not is_instance_valid(target):
			queue_free()
			return
		var expired: Array[StringName] = []
		for key in effects:
			var state := effects[key] as Dictionary
			state["time_left"] = float(state.get("time_left", 0.0)) - delta
			effects[key] = state
			if float(state["time_left"]) <= 0.0:
				expired.append(StringName(key))
		for key in expired:
			effects.erase(key)
		tick_timer -= delta
		if tick_timer <= 0.0:
			tick_timer = 0.5
			_apply_damage_over_time()
		_apply_speed_modifier()
		queue_redraw()
		if effects.is_empty():
			_restore_speed()
			queue_free()

	func _apply_damage_over_time() -> void:
		var damage := 0
		for effect_id in [&"burn", &"poison", &"bleed"]:
			if effects.has(effect_id):
				damage += maxi(roundi(float((effects[effect_id] as Dictionary).get("strength", 0.1)) * 8.0), 1)
		if damage <= 0:
			return
		var health_system = get_tree().get_first_node_in_group("health_system")
		if health_system != null and health_system.has_method("apply_damage"):
			health_system.apply_damage(target, damage, owner_ref, source_id, global_position)

	func _apply_speed_modifier() -> void:
		if base_move_speed < 0.0 or not _has_property(target, &"move_speed"):
			return
		var multiplier := 1.0
		if effects.has(&"slow"):
			multiplier = minf(multiplier, 1.0 - clampf(float((effects[&"slow"] as Dictionary).get("strength", 0.35)), 0.1, 0.85))
		if effects.has(&"freeze"):
			multiplier = minf(multiplier, 0.15)
		if effects.has(&"stun"):
			multiplier = 0.0
		target.set("move_speed", base_move_speed * multiplier)

	func _restore_speed() -> void:
		if base_move_speed >= 0.0 and target != null and is_instance_valid(target) and _has_property(target, &"move_speed"):
			target.set("move_speed", base_move_speed)

	func _exit_tree() -> void:
		_restore_speed()

	func _draw() -> void:
		if effects.is_empty():
			return
		var color := Color(1.0, 0.32, 0.12, 0.8)
		if effects.has(&"freeze") or effects.has(&"slow"):
			color = Color(0.45, 0.88, 1.0, 0.8)
		elif effects.has(&"poison"):
			color = Color(0.42, 1.0, 0.30, 0.8)
		elif effects.has(&"stun"):
			color = Color(1.0, 0.92, 0.20, 0.9)
		draw_arc(Vector2.ZERO, 18.0, 0.0, TAU, 24, color, 3.0)

	func _has_property(object: Object, property_name: StringName) -> bool:
		if object == null:
			return false
		for property in object.get_property_list():
			if StringName(property.get("name", &"")) == property_name:
				return true
		return false

class GroundHazardRuntime extends Node2D:
	var radius: float = 80.0
	var duration: float = 3.0
	var tick_timer: float = 0.0
	var damage: int = 2
	var owner_ref: Node
	var source_id: StringName
	var effect_id: StringName = &"poison"

	func _ready() -> void:
		z_index = -1
		queue_redraw()

	func _process(delta: float) -> void:
		duration -= delta
		tick_timer -= delta
		if tick_timer <= 0.0:
			tick_timer = 0.5
			for target in WeaponEffectResolver._targets_in_radius(get_tree(), global_position, radius, owner_ref):
				var health_system = get_tree().get_first_node_in_group("health_system")
				if health_system != null:
					health_system.apply_damage(target, damage, owner_ref, source_id, global_position)
				WeaponEffectResolver._apply_status(target, owner_ref, source_id, effect_id, 0.8, 0.25)
		if duration <= 0.0:
			queue_free()

	func _draw() -> void:
		var color := Color(0.45, 0.95, 0.24, 0.22) if effect_id == &"poison" else Color(1.0, 0.32, 0.12, 0.22)
		if source_id == &"acid_flask":
			color = Color(0.36, 1.0, 0.18, 0.24)
		elif source_id == &"toxic_spores":
			color = Color(0.52, 0.95, 0.28, 0.18)
		draw_circle(Vector2.ZERO, radius, color)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 36, Color(color, 0.72), 2.0)
		if source_id == &"acid_flask":
			for index in range(8):
				var direction := Vector2.RIGHT.rotated(TAU * float(index) / 8.0)
				draw_circle(
					direction * radius * 0.42,
					radius * 0.08,
					Color(color.lightened(0.20), 0.30)
				)
		elif source_id == &"toxic_spores":
			for index in range(10):
				var direction := Vector2.RIGHT.rotated(TAU * float(index) / 10.0)
				var distance := radius * (0.22 + 0.055 * float(index % 4))
				draw_circle(
					direction * distance,
					radius * 0.05,
					Color(color.lightened(0.28), 0.34)
				)

static func resolve_impact(tree: SceneTree, definition: WeaponData, target: Node, position: Vector2, owner_ref: Node, applied_damage: int) -> void:
	if tree == null or definition == null:
		return
	if definition.delayed_explosion > 0.0:
		_resolve_delayed(tree, definition, target, position, owner_ref)
		return
	_resolve_now(tree, definition, target, position, owner_ref, applied_damage)

static func _resolve_delayed(tree: SceneTree, definition: WeaponData, target: Node, position: Vector2, owner_ref: Node) -> void:
	await tree.create_timer(definition.delayed_explosion).timeout
	_resolve_now(tree, definition, target, position, owner_ref, definition.damage)

static func _resolve_now(tree: SceneTree, definition: WeaponData, target: Node, position: Vector2, owner_ref: Node, _applied_damage: int) -> void:
	var tags := definition.effect_tags.duplicate()
	if not definition.effect_key.is_empty() and not tags.has(definition.effect_key):
		tags.append(definition.effect_key)
	for tag in tags:
		if tag in [&"burn", &"poison", &"bleed", &"slow", &"freeze", &"stun"]:
			_apply_status(target, owner_ref, definition.weapon_id, tag, definition.effect_duration, definition.effect_strength)
	if tags.has(&"critical") and randf() <= definition.effect_strength:
		var critical_health_system = tree.get_first_node_in_group("health_system")
		if critical_health_system != null and target != null:
			critical_health_system.apply_damage(target, definition.damage, owner_ref, definition.weapon_id, position)
	if tags.has(&"group_bonus") and target != null:
		var grouped := _targets_in_radius(tree, position, maxf(definition.melee_range, 100.0), owner_ref)
		if grouped.size() >= 3:
			var group_health_system = tree.get_first_node_in_group("health_system")
			if group_health_system != null:
				group_health_system.apply_damage(target, maxi(roundi(definition.damage * 0.35), 1), owner_ref, definition.weapon_id, position)
	if tags.has(&"defensive_bash") and owner_ref != null:
		_grant_defensive_window(tree, owner_ref)
	if definition.knockback > 0.0 and target is CharacterBody2D and owner_ref is Node2D:
		var direction := (owner_ref as Node2D).global_position.direction_to((target as Node2D).global_position)
		(target as CharacterBody2D).velocity += direction * definition.knockback
	if definition.aoe_radius > 0.0 or tags.has(&"explosion") or tags.has(&"aoe"):
		var radius := definition.aoe_radius if definition.aoe_radius > 0.0 else 72.0
		for nearby in _targets_in_radius(tree, position, radius, owner_ref):
			if nearby == target:
				continue
			var health_system = tree.get_first_node_in_group("health_system")
			if health_system != null:
				health_system.apply_damage(nearby, maxi(roundi(definition.damage * 0.7), 1), owner_ref, definition.weapon_id, position)
			for tag in tags:
				if tag in [&"burn", &"poison", &"slow", &"freeze", &"stun"]:
					_apply_status(nearby, owner_ref, definition.weapon_id, tag, definition.effect_duration, definition.effect_strength)
	if tags.has(&"pull"):
		for nearby in _targets_in_radius(tree, position, maxf(definition.aoe_radius, 100.0), owner_ref):
			if nearby is CharacterBody2D:
				(nearby as CharacterBody2D).velocity += (nearby as Node2D).global_position.direction_to(position) * maxf(definition.knockback, 120.0)
	if definition.chain_targets > 0:
		_apply_chain(tree, definition, target, position, owner_ref)
	if definition.ground_hazard_duration > 0.0:
		_spawn_ground_hazard(tree, definition, position, owner_ref)

static func _apply_status(target: Node, owner_ref: Node, source_id: StringName, effect_id: StringName, duration: float, strength: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var runtime := target.get_node_or_null("WeaponStatusRuntime") as Node2D
	if runtime == null:
		runtime = WeaponStatusRuntime.new()
		target.add_child(runtime)
		(runtime as WeaponStatusRuntime).configure(target, owner_ref, source_id)
	(runtime as WeaponStatusRuntime).add_effect(effect_id, duration, strength)

static func _apply_chain(tree: SceneTree, definition: WeaponData, first_target: Node, position: Vector2, owner_ref: Node) -> void:
	var candidates := _targets_in_radius(tree, position, maxf(definition.chain_range, 120.0), owner_ref)
	candidates.erase(first_target)
	candidates.sort_custom(func(a: Node, b: Node) -> bool: return (a as Node2D).global_position.distance_squared_to(position) < (b as Node2D).global_position.distance_squared_to(position))
	var health_system = tree.get_first_node_in_group("health_system")
	for index in range(mini(definition.chain_targets, candidates.size())):
		if health_system != null:
			health_system.apply_damage(candidates[index], maxi(roundi(definition.damage * 0.65), 1), owner_ref, definition.weapon_id, (candidates[index] as Node2D).global_position)
		_apply_status(candidates[index], owner_ref, definition.weapon_id, &"stun", maxf(definition.effect_duration, 0.2), maxf(definition.effect_strength, 0.2))

static func _spawn_ground_hazard(tree: SceneTree, definition: WeaponData, position: Vector2, owner_ref: Node) -> void:
	var root := tree.current_scene
	if root == null:
		return
	var hazard := GroundHazardRuntime.new()
	hazard.global_position = position
	hazard.radius = maxf(definition.aoe_radius, 64.0)
	hazard.duration = definition.ground_hazard_duration
	hazard.damage = maxi(roundi(definition.damage * 0.18), 1)
	hazard.owner_ref = owner_ref
	hazard.source_id = definition.weapon_id
	hazard.effect_id = &"poison" if definition.effect_tags.has(&"poison") else &"burn"
	root.add_child(hazard)

static func _grant_defensive_window(tree: SceneTree, owner_ref: Node) -> void:
	var health := owner_ref.get_node_or_null("HealthComponent") as HealthComponent
	if health == null:
		return
	health.add_invulnerability_source(&"offensive_shield")
	await tree.create_timer(0.25).timeout
	if is_instance_valid(health):
		health.remove_invulnerability_source(&"offensive_shield")

static func _targets_in_radius(tree: SceneTree, position: Vector2, radius: float, owner_ref: Node) -> Array[Node]:
	var result: Array[Node] = []
	var seen: Dictionary = {}
	for group_id in [&"enemies", &"bosses", &"combat_targets", &"damageable_targets"]:
		for candidate in tree.get_nodes_in_group(group_id):
			if candidate == owner_ref or not candidate is Node2D or seen.has(candidate.get_instance_id()):
				continue
			if (candidate as Node2D).global_position.distance_to(position) <= radius:
				seen[candidate.get_instance_id()] = true
				result.append(candidate)
	return result
