extends SceneTree

var failures := PackedStringArray()
var melee_started: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := Node2D.new()
	world.name = "WeaponInventorySmokeWorld"
	root.add_child(world)
	current_scene = world
	var health_system := HealthSystem.new()
	world.add_child(health_system)
	var owner := Node2D.new()
	world.add_child(owner)
	var weapon_system := WeaponSystem.new()
	weapon_system.name = "WeaponSystem"
	owner.add_child(weapon_system)
	await process_frame

	_expect(weapon_system.get_weapon_count() == 0, "base weapon is separate from the collected inventory")
	_expect(weapon_system.has_base_weapon(&"starter_pistol"), "base weapon is always addressable")
	_expect(not weapon_system.has_weapon(&"starter_pistol"), "base weapon is not reported as a collected weapon")
	var revolver := WeaponCatalog.get_definition(&"heavy_revolver")
	var smg := WeaponCatalog.get_definition(&"unstable_smg")
	_expect(weapon_system.add_weapon(revolver), "second weapon is added instead of replacing the base")
	weapon_system.current_ammo = 2
	weapon_system.reserve_ammo = 17
	weapon_system.cooldown = 0.8
	weapon_system.is_reloading = true
	weapon_system.reload_timer = 0.55
	_expect(weapon_system.add_weapon(smg), "third weapon is added")
	_expect(weapon_system.select_weapon(&"heavy_revolver"), "stored weapon can be selected by stable ID")
	_expect(weapon_system.current_ammo == 2 and weapon_system.reserve_ammo == 17, "ammo persists across switches")
	_expect(weapon_system.is_reloading and is_equal_approx(weapon_system.reload_timer, 0.55), "reload progress persists across switches")
	_expect(is_equal_approx(weapon_system.cooldown, 0.8), "cooldown persists across switches")
	_expect(not weapon_system.add_weapon(revolver), "duplicate weapon IDs are rejected")
	var starting_id := weapon_system.weapon_data.weapon_id
	for _index in range(weapon_system.get_weapon_count()):
		weapon_system.switch_weapon(1)
	_expect(weapon_system.weapon_data.weapon_id == starting_id, "weapon cycling wraps circularly")
	_expect(not weapon_system.has_weapon(&"starter_pistol"), "base weapon stays outside the switch cycle")
	weapon_system.reset_for_run()
	_expect(weapon_system.get_weapon_count() == 0 and weapon_system.has_base_weapon(&"starter_pistol"), "new run clears collected weapons but keeps the separate base")

	var definitions := WeaponCatalog.get_all()
	_expect(definitions.size() == 30, "catalog exposes exactly thirty new weapons")
	_expect(WeaponCatalog.get_category(&"firearm").size() == 10, "catalog has ten firearms")
	_expect(WeaponCatalog.get_category(&"melee").size() == 10, "catalog has ten melee weapons")
	_expect(WeaponCatalog.get_category(&"elemental").size() == 10, "catalog has ten elemental weapons")
	_expect(WeaponCatalog.get_definition(&"pump_shotgun").projectile_count == 7, "shotgun has a cone multi-projectile profile")
	_expect(WeaponCatalog.get_definition(&"scrap_railgun").charge_duration > 0.0, "railgun has charged-shot state")
	_expect(WeaponCatalog.get_definition(&"improvised_sniper").max_hit_count > 1, "sniper supports piercing")
	_expect(WeaponCatalog.get_definition(&"acid_flask").ground_hazard_duration > 0.0, "acid flask creates a temporary ground hazard")
	_expect(WeaponCatalog.get_definition(&"grenade_launcher").projectile_arc_height > 0.0, "grenade launcher exposes an arc trajectory")

	var drop_system := DropSystem.new()
	world.add_child(drop_system)
	weapon_system.add_weapon(revolver)
	var duplicate_reserve_before := weapon_system.reserve_ammo
	_expect(drop_system.collect_drop({"type": GameConstants.DROP_WEAPON, "amount": 1, "weapon_data": revolver}, owner), "duplicate pickup is consumed as a fallback reward")
	_expect(weapon_system.get_weapon_count() == 1 and weapon_system.reserve_ammo > duplicate_reserve_before, "duplicate pickup adds ammo without creating another instance")
	var catalog_entry := DropEntry.new()
	catalog_entry.drop_type = GameConstants.DROP_WEAPON
	catalog_entry.chance = 1.0
	catalog_entry.resource_tag = &"weapon_catalog"
	var loot := LootTable.new()
	loot.entries = [catalog_entry]
	var rolled_ids: Dictionary = {}
	for _index in range(30):
		var drops := drop_system.roll_drops(owner, loot)
		_expect(drops.size() == 1 and StringName(drops[0].get("type")) == GameConstants.DROP_WEAPON, "available catalog roll returns a weapon")
		if drops.size() == 1:
			rolled_ids[StringName(drops[0].get("weapon_id", &""))] = true
	_expect(rolled_ids.size() == 30, "no weapon ID is dropped twice during one run")
	var exhausted := drop_system.roll_drops(owner, loot)
	_expect(exhausted.size() == 1 and StringName(exhausted[0].get("type")) == GameConstants.DROP_AMMO, "exhausted weapon pool falls back to ammo")

	var input_manager := InputManager.new()
	world.add_child(input_manager)
	await process_frame
	_expect(_has_joy_button(&"p1_base_attack", 0, JOY_BUTTON_RIGHT_SHOULDER), "P1 RB maps to the base weapon")
	_expect(_has_joy_button(&"p1_equipped_attack", 0, JOY_BUTTON_LEFT_SHOULDER), "P1 LB maps to the equipped weapon")
	_expect(_has_joy_button(&"p1_weapon_previous", 0, JOY_BUTTON_DPAD_UP), "P1 D-pad up maps to previous weapon")
	_expect(_has_joy_button(&"p2_weapon_next", 1, JOY_BUTTON_DPAD_DOWN), "P2 D-pad down maps independently to next weapon")

	var target := _make_target(world, Vector2.ZERO)
	var nearby := _make_target(world, Vector2(35.0, 0.0))
	var fireball := WeaponCatalog.get_definition(&"fireball")
	WeaponEffectResolver.resolve_impact(self, fireball, target, Vector2.ZERO, owner, fireball.damage)
	await process_frame
	_expect((nearby.get_node("HealthComponent") as HealthComponent).current_health < 100, "explosion applies AOE damage")
	_expect(target.has_node("WeaponStatusRuntime"), "fire weapon applies visible burn runtime")
	var ice_lance := WeaponCatalog.get_definition(&"ice_lance")
	WeaponEffectResolver.resolve_impact(self, ice_lance, target, Vector2.ZERO, owner, ice_lance.damage)
	var taser := WeaponCatalog.get_definition(&"arcane_taser")
	WeaponEffectResolver.resolve_impact(self, taser, target, Vector2.ZERO, owner, taser.damage)
	var status_runtime := target.get_node("WeaponStatusRuntime")
	_expect((status_runtime.get("effects") as Dictionary).has(&"freeze"), "ice weapon applies freeze")
	_expect((status_runtime.get("effects") as Dictionary).has(&"stun"), "taser applies stun")

	var knife := WeaponCatalog.get_definition(&"quick_knife")
	weapon_system.melee_attack_started.connect(_on_melee_started)
	weapon_system.equip_weapon(knife)
	weapon_system.cooldown = 0.0
	_expect(weapon_system.try_fire(Vector2.ZERO, Vector2.RIGHT, owner), "melee catalog weapon can attack")
	await process_frame
	_expect(melee_started, "melee attack dispatch creates the shared hitbox runtime")

	_finish()

func _make_target(parent: Node, position: Vector2) -> CharacterBody2D:
	var target := CharacterBody2D.new()
	target.global_position = position
	target.add_to_group("enemies")
	var health := HealthComponent.new()
	health.name = "HealthComponent"
	target.add_child(health)
	parent.add_child(target)
	return target

func _has_joy_button(action: StringName, device: int, button: int) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and event.device == device and event.button_index == button:
			return true
	return false

func _on_melee_started(_attack: Node, _definition: WeaponData) -> void:
	melee_started = true

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("WEAPON_INVENTORY_CATALOG_SMOKE_TEST: PASS")
		quit(0)
		return
	print("WEAPON_INVENTORY_CATALOG_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
