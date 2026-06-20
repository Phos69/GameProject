extends Node2D
class_name WeaponSystem

signal fired(origin: Vector2, direction: Vector2, damage: int)
signal fire_blocked(reason: StringName)
signal ammo_changed(current_ammo: int, reserve_ammo: int)
signal reload_started(duration: float)
signal reload_finished()
signal weapon_changed(weapon_data: WeaponData)
signal inventory_changed(weapon_ids: Array[StringName])
signal weapon_added(weapon_data: WeaponData)
signal weapon_switch_feedback(text: String, weapon_data: WeaponData)
signal low_ammo_changed(is_low: bool, total_ammo: int)
signal melee_attack_started(attack: Node, weapon_data: WeaponData)
signal melee_attack_hit(attack: Node, target: Node, applied_damage: int, hit_position: Vector2)

const MELEE_ATTACK_SCRIPT := preload("res://game/weapons/melee_attack.gd")
const EFFECT_RESOLVER := preload("res://game/weapons/weapon_effect_resolver.gd")

@export var weapon_data: WeaponData = preload("res://game/weapons/starter_pistol.tres")
@export var fallback_weapon_data: WeaponData = preload("res://game/weapons/starter_pistol.tres")
@export_range(0, 999) var low_ammo_threshold: int = 8

# Compatibility fields remain public for existing consumers. The equipped
# instance, or the base instance when no collected weapon exists, is
# authoritative for these values at API/frame boundaries.
var cooldown: float = 0.0
var current_ammo: int = 0
var reserve_ammo: int = 0
var reload_timer: float = 0.0
var is_reloading: bool = false
var special_weapon_data: WeaponData
var special_current_ammo: int = 0
var special_reserve_ammo: int = 0
var fallback_current_ammo: int = 0
var low_ammo_active: bool = false
var inventory := PlayerWeaponInventory.new()
var last_special_weapon_id: StringName = &""

func _ready() -> void:
	_initialize_loadout()

func _process(delta: float) -> void:
	_store_active_state()
	var active := inventory.get_active()
	var base_instance := inventory.get_base()
	if base_instance != null:
		var base_finished := base_instance.tick(delta)
		if base_finished and base_instance == active:
			reload_finished.emit()
	for instance in inventory.instances:
		var finished := instance.tick(delta)
		if finished and instance == active:
			reload_finished.emit()
	_sync_from_active()
	_refresh_low_ammo_state()

func try_fire(origin: Vector2, direction: Vector2, owner_ref: Node = null) -> bool:
	if inventory.get_selected() != null:
		return try_fire_equipped(origin, direction, owner_ref)
	return try_fire_base(origin, direction, owner_ref)

func try_fire_base(
	origin: Vector2,
	direction: Vector2,
	owner_ref: Node = null
) -> bool:
	_store_active_state()
	return _try_fire_instance(inventory.get_base(), origin, direction, owner_ref)

func try_fire_equipped(
	origin: Vector2,
	direction: Vector2,
	owner_ref: Node = null
) -> bool:
	_store_active_state()
	return _try_fire_instance(inventory.get_selected(), origin, direction, owner_ref)

func _try_fire_instance(
	instance: WeaponInstance,
	origin: Vector2,
	direction: Vector2,
	owner_ref: Node
) -> bool:
	if instance == null or instance.definition == null:
		fire_blocked.emit(&"no_weapon")
		return false
	var definition := instance.definition
	if direction.length_squared() <= 0.01:
		fire_blocked.emit(&"no_direction")
		return false
	if instance.is_reloading:
		fire_blocked.emit(&"reloading")
		return false
	if instance.cooldown > 0.0:
		fire_blocked.emit(&"cooldown")
		return false
	if instance.current_ammo < definition.ammo_per_shot:
		if _start_reload_instance(instance):
			fire_blocked.emit(&"reload_started")
			return false
		fire_blocked.emit(&"empty")
		return false

	var base_cooldown := 1.0 / maxf(
		definition.fire_rate * _get_modified_fire_rate_multiplier(),
		0.01
	)
	instance.cooldown = base_cooldown
	if definition.uses_melee_attack():
		instance.cooldown = maxf(
			base_cooldown,
			definition.windup_time
			+ definition.active_time
			+ definition.recovery_time
		)
	instance.current_ammo -= definition.ammo_per_shot
	_sync_from_active()
	if instance == inventory.get_active():
		ammo_changed.emit(current_ammo, reserve_ammo)
	else:
		fallback_current_ammo = instance.current_ammo
	_refresh_low_ammo_state()
	var normalized_direction := _apply_weapon_scatter(
		direction.normalized(),
		definition
	)
	fired.emit(origin, normalized_direction, definition.damage)
	var windup_delay := definition.windup_duration
	if windup_delay > 0.0:
		var now_seconds := Time.get_ticks_msec() / 1000.0
		var spun_up_until := float(instance.temporary_state.get("spun_up_until", 0.0))
		if now_seconds < spun_up_until:
			windup_delay = 0.0
		instance.temporary_state["spun_up_until"] = now_seconds + 0.65
	var delay := definition.charge_duration + windup_delay
	if delay > 0.0:
		instance.charge_time = delay
		_fire_pattern_delayed(origin, normalized_direction, owner_ref, definition, delay)
	else:
		_fire_pattern(origin, normalized_direction, owner_ref, definition)
	return true

func _fire_pattern_delayed(origin: Vector2, direction: Vector2, owner_ref: Node, definition: WeaponData, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if not is_instance_valid(self):
		return
	var instance := inventory.get_instance_or_base(definition.weapon_id)
	if instance != null:
		instance.charge_time = 0.0
	_fire_pattern(origin, direction, owner_ref, definition)

func _fire_pattern(origin: Vector2, direction: Vector2, owner_ref: Node, definition: WeaponData) -> void:
	if definition.uses_melee_attack():
		if definition.attack_type == &"dash_slash" and owner_ref is CharacterBody2D:
			(owner_ref as CharacterBody2D).move_and_collide(direction.normalized() * 42.0)
		_spawn_melee_attack(origin, direction, owner_ref, definition)
		return
	if definition.weapon_id in [&"frost_nova", &"seismic_crystal"]:
		var center := (owner_ref as Node2D).global_position if owner_ref is Node2D else origin
		EFFECT_RESOLVER.resolve_impact(get_tree(), definition, null, center, owner_ref, 0)
		return
	for burst_index in range(maxi(definition.burst_count, 1)):
		if burst_index > 0 and definition.burst_interval > 0.0:
			await get_tree().create_timer(definition.burst_interval).timeout
		for projectile_index in range(maxi(definition.projectile_count, 1)):
			var shot_direction := direction
			if definition.projectile_count > 1:
				var ratio := float(projectile_index) / float(definition.projectile_count - 1)
				shot_direction = direction.rotated(deg_to_rad(lerpf(-definition.scatter_degrees, definition.scatter_degrees, ratio)))
			_spawn_projectile(origin, shot_direction, owner_ref, definition)

func _spawn_projectile(origin: Vector2, direction: Vector2, owner_ref: Node, definition: WeaponData) -> void:
	var projectile_system = get_tree().get_first_node_in_group("projectile_system")
	var projectile: Node
	if projectile_system != null and projectile_system.has_method("spawn_projectile"):
		projectile = projectile_system.spawn_projectile(origin, direction, definition.projectile_speed, owner_ref, definition.projectile_scene, definition.damage, definition.weapon_id, definition.visual_data, definition.max_range, definition.hitbox_type, definition.hitbox_size, definition.max_hit_count)
	elif definition.projectile_scene != null:
		projectile = definition.projectile_scene.instantiate()
		if projectile is Node2D:
			(projectile as Node2D).global_position = origin
		if projectile.has_method("launch"):
			projectile.launch(direction, definition.projectile_speed, owner_ref, definition.damage, definition.weapon_id, definition.visual_data, definition.max_range, definition.hitbox_type, definition.hitbox_size, definition.max_hit_count)
		var root := get_tree().current_scene
		if root != null:
			root.add_child(projectile)
	if projectile != null and projectile.has_signal("impacted"):
		projectile.connect("impacted", Callable(self, "_on_projectile_effect_impact").bind(definition, owner_ref, projectile))
	if projectile != null and projectile.has_method("set_arc_height"):
		projectile.set_arc_height(definition.projectile_arc_height)

func _on_projectile_effect_impact(target: Node, applied_damage: int, definition: WeaponData, owner_ref: Node, projectile: Node) -> void:
	var impact_position := (projectile as Node2D).global_position if projectile is Node2D else Vector2.ZERO
	EFFECT_RESOLVER.resolve_impact(get_tree(), definition, target, impact_position, owner_ref, applied_damage)

func _spawn_melee_attack(origin: Vector2, direction: Vector2, owner_ref: Node = null, definition: WeaponData = null) -> Node:
	var resolved := definition if definition != null else weapon_data
	if resolved == null:
		return null
	var attack_origin := origin
	if owner_ref is Node2D:
		attack_origin = (owner_ref as Node2D).global_position
	var attack := MELEE_ATTACK_SCRIPT.new()
	attack.configure(attack_origin, direction, owner_ref, resolved.damage, resolved.weapon_id, resolved.get_resolved_melee_shape(), resolved.get_resolved_melee_range(), resolved.get_resolved_melee_width(), resolved.melee_arc_degrees, resolved.windup_time, resolved.active_time, resolved.knockback, resolved.hitstop, resolved.max_hit_count, resolved.visual_data, resolved.trail_style, resolved.effect_key)
	attack.hit_target.connect(_on_melee_attack_hit.bind(attack, resolved, owner_ref))
	var root := get_tree().current_scene
	if root == null:
		root = get_tree().root
	root.add_child(attack)
	melee_attack_started.emit(attack, resolved)
	return attack

func _on_melee_attack_hit(target: Node, applied_damage: int, hit_position: Vector2, attack: Node, definition: WeaponData, owner_ref: Node) -> void:
	EFFECT_RESOLVER.resolve_impact(get_tree(), definition, target, hit_position, owner_ref, applied_damage)
	melee_attack_hit.emit(attack, target, applied_damage, hit_position)

func start_reload() -> bool:
	_store_active_state()
	return _start_reload_instance(inventory.get_active())

func _start_reload_instance(instance: WeaponInstance) -> bool:
	if (
		instance == null
		or not instance.begin_reload(
			_get_modified_reload_duration(instance.definition)
		)
	):
		return false
	_sync_from_active()
	reload_started.emit(instance.reload_timer)
	if not instance.is_reloading:
		reload_finished.emit()
	return true

func get_ammo_text() -> String:
	_store_active_state()
	if weapon_data == null:
		return "-"
	var reserve_text := "INF" if weapon_data.infinite_reserve_ammo else str(reserve_ammo)
	var tags := PackedStringArray()
	if is_reloading:
		tags.append("RELOAD")
	if low_ammo_active:
		tags.append("LOW")
	var suffix := " " + " ".join(tags) if not tags.is_empty() else ""
	return "%d/%s%s" % [current_ammo, reserve_text, suffix]

func get_reload_ratio() -> float:
	_store_active_state()
	var instance := inventory.get_active()
	return instance.get_reload_ratio() if instance != null else 0.0

func add_reserve_ammo(amount: int) -> int:
	if amount <= 0:
		return 0
	_store_active_state()
	var target := inventory.get_selected()
	if target == null or target.definition.infinite_reserve_ammo:
		target = inventory.get_instance(last_special_weapon_id)
	if target == null or target.definition.infinite_reserve_ammo:
		return 0
	target.reserve_ammo += amount
	if target.current_ammo <= 0:
		_start_reload_instance(target)
	_sync_from_active()
	ammo_changed.emit(current_ammo, reserve_ammo)
	_refresh_low_ammo_state()
	return amount

func get_active_ammo_refill_amount() -> int:
	_store_active_state()
	return _get_instance_refill_amount(inventory.get_active())

func get_all_ammo_refill_amount() -> int:
	_store_active_state()
	var total := _get_instance_refill_amount(inventory.get_base())
	for instance in inventory.instances:
		total += _get_instance_refill_amount(instance)
	return total

func refill_active_ammo() -> int:
	_store_active_state()
	var applied := _refill_instance(inventory.get_active())
	_sync_from_active()
	if applied > 0:
		ammo_changed.emit(current_ammo, reserve_ammo)
		_refresh_low_ammo_state()
	return applied

func refill_all_ammo() -> int:
	_store_active_state()
	var applied := _refill_instance(inventory.get_base())
	for instance in inventory.instances:
		applied += _refill_instance(instance)
	_sync_from_active()
	if applied > 0:
		ammo_changed.emit(current_ammo, reserve_ammo)
		_refresh_low_ammo_state()
	return applied

func add_ammo_to_weapon(weapon_id: StringName, amount: int) -> int:
	if amount <= 0:
		return 0
	_store_active_state()
	var instance := inventory.get_instance(weapon_id)
	if instance == null or instance.definition.infinite_reserve_ammo:
		return 0
	instance.reserve_ammo += amount
	_sync_from_active()
	ammo_changed.emit(current_ammo, reserve_ammo)
	_refresh_low_ammo_state()
	return amount

func add_weapon(new_weapon_data: WeaponData, auto_select: bool = true) -> bool:
	if new_weapon_data == null or inventory.has_weapon(new_weapon_data.weapon_id):
		return false
	_store_active_state()
	var instance := inventory.add_weapon(new_weapon_data, auto_select)
	if instance == null:
		return false
	if not new_weapon_data.infinite_reserve_ammo:
		last_special_weapon_id = new_weapon_data.weapon_id
		special_weapon_data = new_weapon_data
	if auto_select:
		_select_instance(instance, false)
	weapon_added.emit(new_weapon_data)
	inventory_changed.emit(inventory.get_weapon_ids())
	weapon_switch_feedback.emit("Nuova arma: %s" % new_weapon_data.display_name, new_weapon_data)
	return true

func equip_weapon(new_weapon_data: WeaponData) -> bool:
	# Legacy callers expect equipping a new finite weapon to select it. Duplicate
	# IDs now select their persistent instance instead of resetting its state.
	if new_weapon_data == null:
		return false
	var existing := inventory.get_instance(new_weapon_data.weapon_id)
	if existing != null:
		_select_instance(existing, false)
		return true
	return add_weapon(new_weapon_data, true)

func set_base_weapon(new_weapon_data: WeaponData) -> bool:
	if new_weapon_data == null:
		return false
	_store_active_state()
	var instance := inventory.replace_base_weapon(new_weapon_data)
	fallback_weapon_data = new_weapon_data
	fallback_current_ammo = instance.current_ammo
	_sync_from_active()
	inventory_changed.emit(inventory.get_weapon_ids())
	weapon_changed.emit(weapon_data)
	return true

func reset_for_run(base_definition: WeaponData = null) -> void:
	var resolved_base := base_definition if base_definition != null else fallback_weapon_data
	inventory.clear()
	last_special_weapon_id = &""
	special_weapon_data = null
	special_current_ammo = 0
	special_reserve_ammo = 0
	low_ammo_active = false
	if resolved_base != null:
		fallback_weapon_data = resolved_base
		inventory.set_base_weapon(resolved_base)
	_sync_from_active()
	inventory_changed.emit(inventory.get_weapon_ids())
	weapon_changed.emit(weapon_data)

func switch_weapon(direction: int) -> bool:
	if inventory.instances.is_empty():
		return false
	if inventory.instances.size() == 1 and inventory.selected_index == 0:
		return false
	_store_active_state()
	var instance := inventory.cycle(direction)
	_select_instance(instance, true)
	return true

func select_weapon(weapon_id: StringName) -> bool:
	_store_active_state()
	var instance := inventory.select_weapon(weapon_id)
	if instance == null:
		return false
	_select_instance(instance, true)
	return true

func has_weapon(weapon_id: StringName) -> bool:
	return inventory.has_weapon(weapon_id)

func has_base_weapon(weapon_id: StringName) -> bool:
	var base_instance := inventory.get_base()
	return base_instance != null and base_instance.get_weapon_id() == weapon_id

func get_base_weapon_data() -> WeaponData:
	var base_instance := inventory.get_base()
	return base_instance.definition if base_instance != null else null

func get_weapon_count() -> int:
	return inventory.instances.size()

func get_inventory_weapon_ids() -> Array[StringName]:
	return inventory.get_weapon_ids()

func get_inventory_display_names() -> PackedStringArray:
	return inventory.get_display_names()

func has_special_weapon() -> bool:
	return not last_special_weapon_id.is_empty() and inventory.has_weapon(last_special_weapon_id)

func is_base_weapon_active() -> bool:
	return inventory.get_selected() == null and inventory.get_base() != null

func is_fallback_active() -> bool:
	return is_base_weapon_active()

func get_special_ammo_total() -> int:
	_store_active_state()
	var instance := inventory.get_instance(last_special_weapon_id)
	return instance.current_ammo + instance.reserve_ammo if instance != null else -1

func is_special_ammo_low(threshold: int = -1) -> bool:
	if not has_special_weapon():
		return false
	var resolved_threshold := low_ammo_threshold if threshold < 0 else threshold
	return get_special_ammo_total() <= maxi(resolved_threshold, 0)

func _initialize_loadout() -> void:
	var initial_weapon_data := weapon_data
	if fallback_weapon_data == null:
		fallback_weapon_data = initial_weapon_data
	if fallback_weapon_data != null:
		inventory.set_base_weapon(fallback_weapon_data)
	if initial_weapon_data != null and (fallback_weapon_data == null or initial_weapon_data.weapon_id != fallback_weapon_data.weapon_id):
		inventory.add_weapon(initial_weapon_data, true)
		if not initial_weapon_data.infinite_reserve_ammo:
			last_special_weapon_id = initial_weapon_data.weapon_id
			special_weapon_data = initial_weapon_data
	_sync_from_active()
	inventory_changed.emit(inventory.get_weapon_ids())
	weapon_changed.emit(weapon_data)
	_refresh_low_ammo_state()

func _select_instance(instance: WeaponInstance, show_feedback: bool) -> void:
	if instance == null:
		return
	inventory.selected_index = inventory.instances.find(instance)
	if inventory.selected_index < 0:
		return
	_sync_from_active()
	ammo_changed.emit(current_ammo, reserve_ammo)
	weapon_changed.emit(weapon_data)
	if show_feedback:
		weapon_switch_feedback.emit("Arma: %s" % weapon_data.display_name, weapon_data)
	_refresh_low_ammo_state()

func _store_active_state() -> void:
	var instance := inventory.get_active()
	if instance == null:
		return
	instance.current_ammo = current_ammo
	instance.reserve_ammo = reserve_ammo
	instance.cooldown = cooldown
	instance.reload_timer = reload_timer
	instance.is_reloading = is_reloading
	if instance.is_reloading and instance.reload_duration <= 0.0:
		instance.reload_duration = _get_modified_reload_duration(
			instance.definition
		)
	if instance == inventory.get_base():
		fallback_current_ammo = current_ammo
	elif not instance.definition.infinite_reserve_ammo:
		special_current_ammo = current_ammo
		special_reserve_ammo = reserve_ammo

func _sync_from_active() -> void:
	var instance := inventory.get_active()
	if instance == null:
		weapon_data = null
		current_ammo = 0
		reserve_ammo = 0
		cooldown = 0.0
		reload_timer = 0.0
		is_reloading = false
		return
	weapon_data = instance.definition
	current_ammo = instance.current_ammo
	reserve_ammo = instance.reserve_ammo
	cooldown = instance.cooldown
	reload_timer = instance.reload_timer
	is_reloading = instance.is_reloading
	if instance == inventory.get_base():
		fallback_current_ammo = current_ammo
	elif not instance.definition.infinite_reserve_ammo:
		special_weapon_data = instance.definition
		special_current_ammo = current_ammo
		special_reserve_ammo = reserve_ammo

func _refresh_low_ammo_state() -> void:
	var is_low := is_special_ammo_low()
	if is_low == low_ammo_active:
		return
	low_ammo_active = is_low
	low_ammo_changed.emit(low_ammo_active, maxi(get_special_ammo_total(), 0))

func _get_instance_refill_amount(instance: WeaponInstance) -> int:
	if instance == null or instance.definition == null:
		return 0
	if instance.definition.infinite_reserve_ammo:
		return 0
	return (
		maxi(instance.definition.magazine_size - instance.current_ammo, 0)
		+ maxi(
			instance.definition.starting_reserve_ammo - instance.reserve_ammo,
			0
		)
	)

func _refill_instance(instance: WeaponInstance) -> int:
	var applied := _get_instance_refill_amount(instance)
	if applied <= 0:
		return 0
	instance.current_ammo = maxi(
		instance.current_ammo,
		instance.definition.magazine_size
	)
	instance.reserve_ammo = maxi(
		instance.reserve_ammo,
		instance.definition.starting_reserve_ammo
	)
	instance.is_reloading = false
	instance.reload_timer = 0.0
	return applied

func _apply_weapon_scatter(
	direction: Vector2,
	definition: WeaponData
) -> Vector2:
	if (
		definition == null
		or definition.scatter_degrees <= 0.0
		or definition.projectile_count > 1
	):
		return direction
	var scatter_radians := deg_to_rad(definition.scatter_degrees)
	return direction.rotated(randf_range(-scatter_radians, scatter_radians))

func _get_modified_reload_duration(definition: WeaponData) -> float:
	if definition == null:
		return 0.0
	var duration := definition.reload_duration
	var rpg_component := _get_parent_rpg_component()
	if rpg_component != null and rpg_component.has_character():
		duration /= rpg_component.get_reload_speed_multiplier()
	return maxf(duration, 0.0)

func _get_modified_fire_rate_multiplier() -> float:
	var rpg_component := _get_parent_rpg_component()
	if rpg_component != null and rpg_component.has_character():
		return rpg_component.get_fire_rate_multiplier()
	return 1.0

func _get_parent_rpg_component() -> RpgPlayerComponent:
	var parent := get_parent()
	return parent.get_node_or_null("RpgPlayerComponent") as RpgPlayerComponent if parent != null else null
