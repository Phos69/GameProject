extends GutTest
## Combat A5 — Armi base dei personaggi, ammo/reload HUD e catalogo/inventario.
##
## Migra e accorpa:
##   tests/milestone_rpg_3_weapons_smoke_test.gd
##   tests/milestone_rpg_5_ammo_reload_smoke_test.gd
##   tests/weapon_inventory_catalog_smoke_test.gd

var _melee_started: bool = false

# --- armi base per personaggio e profili statistici -------------------------

func test_character_base_weapons_and_stats() -> void:
	var player_scene := load("res://game/player/player.tscn") as PackedScene
	assert_not_null(player_scene, "player scene can be loaded")
	if player_scene == null:
		return
	var player := player_scene.instantiate() as PlayerController
	add_child(player)
	await wait_physics_frames(2)
	var weapon_system := player.get_node("WeaponSystem") as WeaponSystem
	assert_not_null(weapon_system, "weapon system is available")
	if weapon_system == null:
		player.queue_free()
		return

	var expected_weapons := {
		&"ranger": &"rpg_bow", &"pistoliere": &"rpg_pistol", &"berserker": &"rpg_axe",
		&"spadaccino": &"rpg_sword", &"mago": &"rpg_staff", &"domatrice": &"rpg_slingshot", &"licantropo": &"rpg_claws"
	}
	for character_id in expected_weapons.keys():
		assert_true(player.apply_rpg_character(StringName(character_id)), "%s character can be applied" % str(character_id))
		assert_eq(weapon_system.weapon_data.weapon_id, expected_weapons[character_id], "%s equips expected base weapon" % str(character_id))
		assert_true(weapon_system.weapon_data.infinite_reserve_ammo, "%s base weapon keeps an infinite reserve" % str(character_id))

	var bow := load("res://game/weapons/rpg_bow.tres") as WeaponData
	var pistol := load("res://game/weapons/rpg_pistol.tres") as WeaponData
	var axe := load("res://game/weapons/rpg_axe.tres") as WeaponData
	var sword := load("res://game/weapons/rpg_sword.tres") as WeaponData
	var staff := load("res://game/weapons/rpg_staff.tres") as WeaponData
	var slingshot := load("res://game/weapons/rpg_slingshot.tres") as WeaponData
	var claws := load("res://game/weapons/rpg_claws.tres") as WeaponData
	assert_true(bow.damage == 20 and bow.max_range == 750.0, "bow has long precise profile")
	assert_true(pistol.magazine_size == 8 and pistol.scatter_degrees == 8.0, "pistol has eight shots and scatter")
	assert_true(axe.damage == 28 and axe.max_range == 95.0, "axe is high damage and short range")
	assert_true(sword.magazine_size == 4 and sword.reload_duration == 0.85, "sword has fast four-swing reload")
	assert_true(staff.magazine_size == 5 and staff.hitbox_size.x >= 18.0, "staff uses five visible arcane charges")
	assert_true(slingshot.magazine_size == 8 and slingshot.fire_rate >= 4.0, "slingshot uses eight fast scrap shots")
	assert_true(claws.hitbox_type == &"arc" and claws.max_range <= 90.0, "claws use short melee arc")
	assert_eq(bow.attack_type, &"projectile", "bow keeps projectile attack type")
	assert_eq(pistol.attack_type, &"projectile", "pistol keeps projectile attack type")
	assert_eq(axe.attack_type, &"melee_arc", "axe uses melee arc attack type")
	assert_eq(sword.attack_type, &"melee_sweep", "sword uses melee sweep attack type")
	assert_eq(claws.attack_type, &"melee_arc", "claws use melee arc attack type")

	player.queue_free()
	await wait_physics_frames(1)

# --- ammo/reload e world HUD ------------------------------------------------

func test_ammo_reload_world_hud() -> void:
	var player_scene := load("res://game/player/player.tscn") as PackedScene
	assert_not_null(player_scene, "player scene can be loaded")
	if player_scene == null:
		return
	var player := player_scene.instantiate() as PlayerController
	add_child(player)
	await wait_physics_frames(2)
	player.apply_rpg_character(&"ranger")
	var world_hud := player.get_node("WorldHud")
	assert_not_null(world_hud, "player has a world-space HUD package")
	var weapon_system := player.get_node("WeaponSystem") as WeaponSystem
	weapon_system.current_ammo = 0
	weapon_system.start_reload()
	var expected_reload := 0.55 / 1.08
	assert_true(is_equal_approx(weapon_system.reload_timer, expected_reload), "reload speed multiplier modifies reload duration")
	assert_eq(weapon_system.get_reload_ratio(), 0.0, "reload ratio starts empty")
	assert_true(world_hud.is_showing_reload(), "world HUD switches to reload state")
	await wait_physics_frames(1)
	assert_gte(weapon_system.get_reload_ratio(), 0.0, "reload ratio is exposed during reload")
	assert_gte(world_hud.get_reload_ratio(), 0.0, "world HUD exposes reload progress")

	var card := PlayerHudCard.new()
	add_child(card)
	await wait_physics_frames(1)
	card.configure(1, Color(0.18, 0.74, 0.95, 1.0))
	card.refresh(player)
	assert_true(card.ammo_pips.is_empty(), "corner card no longer owns magazine pips")
	assert_null(card.reload_bar, "corner card no longer duplicates reload bar")
	assert_eq(world_hud.get_magazine_size(), 1, "bow world HUD uses one ammo segment")

	player.apply_rpg_character(&"pistoliere")
	await wait_physics_frames(1)
	card.refresh(player)
	assert_eq(world_hud.get_magazine_size(), 8, "pistol world HUD shows eight-shot magazine")

	card.queue_free()
	player.queue_free()
	await wait_physics_frames(1)

# --- inventario, catalogo, drop e effetti delle armi ------------------------

func test_weapon_inventory_and_catalog() -> void:
	_melee_started = false
	var world := Node2D.new()
	add_child(world)
	world.add_child(HealthSystem.new())
	var owner := Node2D.new()
	world.add_child(owner)
	var weapon_system := WeaponSystem.new()
	weapon_system.name = "WeaponSystem"
	owner.add_child(weapon_system)
	await wait_physics_frames(1)

	assert_eq(weapon_system.get_weapon_count(), 0, "base weapon is separate from the collected inventory")
	assert_true(weapon_system.has_base_weapon(&"starter_pistol"), "base weapon is always addressable")
	assert_false(weapon_system.has_weapon(&"starter_pistol"), "base weapon is not reported as a collected weapon")
	var revolver := WeaponCatalog.get_definition(&"heavy_revolver")
	var smg := WeaponCatalog.get_definition(&"unstable_smg")
	assert_true(weapon_system.add_weapon(revolver), "second weapon is added instead of replacing the base")
	weapon_system.current_ammo = 2
	weapon_system.reserve_ammo = 17
	weapon_system.cooldown = 0.8
	weapon_system.is_reloading = true
	weapon_system.reload_timer = 0.55
	assert_true(weapon_system.add_weapon(smg), "third weapon is added")
	assert_true(weapon_system.select_weapon(&"heavy_revolver"), "stored weapon can be selected by stable ID")
	assert_true(weapon_system.current_ammo == 2 and weapon_system.reserve_ammo == 17, "ammo persists across switches")
	assert_true(weapon_system.is_reloading and is_equal_approx(weapon_system.reload_timer, 0.55), "reload progress persists across switches")
	assert_true(is_equal_approx(weapon_system.cooldown, 0.8), "cooldown persists across switches")
	assert_false(weapon_system.add_weapon(revolver), "duplicate weapon IDs are rejected")
	var starting_id := weapon_system.weapon_data.weapon_id
	for _index in range(weapon_system.get_weapon_count()):
		weapon_system.switch_weapon(1)
	assert_eq(weapon_system.weapon_data.weapon_id, starting_id, "weapon cycling wraps circularly")
	assert_false(weapon_system.has_weapon(&"starter_pistol"), "base weapon stays outside the switch cycle")
	weapon_system.reset_for_run()
	assert_true(weapon_system.get_weapon_count() == 0 and weapon_system.has_base_weapon(&"starter_pistol"), "new run clears collected weapons but keeps the separate base")

	var definitions := WeaponCatalog.get_all()
	assert_eq(definitions.size(), 30, "catalog exposes exactly thirty new weapons")
	assert_eq(WeaponCatalog.get_category(&"firearm").size(), 10, "catalog has ten firearms")
	assert_eq(WeaponCatalog.get_category(&"melee").size(), 10, "catalog has ten melee weapons")
	assert_eq(WeaponCatalog.get_category(&"elemental").size(), 10, "catalog has ten elemental weapons")
	assert_eq(WeaponCatalog.get_definition(&"pump_shotgun").projectile_count, 7, "shotgun has a cone multi-projectile profile")
	assert_gt(WeaponCatalog.get_definition(&"scrap_railgun").charge_duration, 0.0, "railgun has charged-shot state")
	assert_gt(WeaponCatalog.get_definition(&"improvised_sniper").max_hit_count, 1, "sniper supports piercing")
	assert_gt(WeaponCatalog.get_definition(&"acid_flask").ground_hazard_duration, 0.0, "acid flask creates a temporary ground hazard")
	assert_gt(WeaponCatalog.get_definition(&"grenade_launcher").projectile_arc_height, 0.0, "grenade launcher exposes an arc trajectory")

	var drop_system := DropSystem.new()
	world.add_child(drop_system)
	weapon_system.add_weapon(revolver)
	var duplicate_reserve_before := weapon_system.reserve_ammo
	assert_true(drop_system.collect_drop({"type": GameConstants.DROP_WEAPON, "amount": 1, "weapon_data": revolver}, owner), "duplicate pickup is consumed as a fallback reward")
	assert_true(weapon_system.get_weapon_count() == 1 and weapon_system.reserve_ammo > duplicate_reserve_before, "duplicate pickup adds ammo without creating another instance")
	var catalog_entry := DropEntry.new()
	catalog_entry.drop_type = GameConstants.DROP_WEAPON
	catalog_entry.chance = 1.0
	catalog_entry.resource_tag = &"weapon_catalog"
	var loot := LootTable.new()
	loot.entries = [catalog_entry]
	var rolled_ids: Dictionary = {}
	for _index in range(30):
		var drops := drop_system.roll_drops(owner, loot)
		assert_true(drops.size() == 1 and StringName(drops[0].get("type")) == GameConstants.DROP_WEAPON, "available catalog roll returns a weapon")
		if drops.size() == 1:
			rolled_ids[StringName(drops[0].get("weapon_id", &""))] = true
	assert_eq(rolled_ids.size(), 30, "no weapon ID is dropped twice during one run")
	var exhausted := drop_system.roll_drops(owner, loot)
	assert_true(exhausted.size() == 1 and StringName(exhausted[0].get("type")) == GameConstants.DROP_AMMO, "exhausted weapon pool falls back to ammo")

	var input_manager := InputManager.new()
	world.add_child(input_manager)
	await wait_physics_frames(1)
	assert_true(_has_joy_button(&"p1_base_attack", 0, JOY_BUTTON_RIGHT_SHOULDER), "P1 RB maps to the base weapon")
	assert_true(_has_joy_button(&"p1_equipped_attack", 0, JOY_BUTTON_LEFT_SHOULDER), "P1 LB maps to the equipped weapon")
	assert_true(_has_joy_button(&"p1_weapon_previous", 0, JOY_BUTTON_DPAD_UP), "P1 D-pad up maps to previous weapon")
	assert_true(_has_joy_button(&"p2_weapon_next", 1, JOY_BUTTON_DPAD_DOWN), "P2 D-pad down maps independently to next weapon")

	var target := _make_target(world, Vector2.ZERO)
	var nearby := _make_target(world, Vector2(35.0, 0.0))
	var fireball := WeaponCatalog.get_definition(&"fireball")
	WeaponEffectResolver.resolve_impact(get_tree(), fireball, target, Vector2.ZERO, owner, fireball.damage)
	await wait_physics_frames(1)
	assert_lt((nearby.get_node("HealthComponent") as HealthComponent).current_health, 100, "explosion applies AOE damage")
	assert_true(target.has_node("WeaponStatusRuntime"), "fire weapon applies visible burn runtime")
	var ice_lance := WeaponCatalog.get_definition(&"ice_lance")
	WeaponEffectResolver.resolve_impact(get_tree(), ice_lance, target, Vector2.ZERO, owner, ice_lance.damage)
	var taser := WeaponCatalog.get_definition(&"arcane_taser")
	WeaponEffectResolver.resolve_impact(get_tree(), taser, target, Vector2.ZERO, owner, taser.damage)
	var status_runtime := target.get_node("WeaponStatusRuntime")
	assert_true((status_runtime.get("effects") as Dictionary).has(&"freeze"), "ice weapon applies freeze")
	assert_true((status_runtime.get("effects") as Dictionary).has(&"stun"), "taser applies stun")

	var knife := WeaponCatalog.get_definition(&"quick_knife")
	weapon_system.melee_attack_started.connect(_on_melee_started)
	weapon_system.equip_weapon(knife)
	weapon_system.cooldown = 0.0
	assert_true(weapon_system.try_fire(Vector2.ZERO, Vector2.RIGHT, owner), "melee catalog weapon can attack")
	await wait_physics_frames(1)
	assert_true(_melee_started, "melee attack dispatch creates the shared hitbox runtime")

	world.queue_free()
	await wait_physics_frames(1)

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
	_melee_started = true
