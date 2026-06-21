extends SceneTree

var failures: PackedStringArray = []
var gameplay_feedback_events: Array[StringName] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main_scene := load("res://game/main/main.tscn") as PackedScene
	_expect(main_scene != null, "main scene can be loaded")
	if main_scene == null:
		_finish()
		return

	var main := main_scene.instantiate()
	root.add_child(main)
	current_scene = main
	await _wait_process_frames(4)

	var game_mode_manager := get_first_node_in_group(
		"game_mode_manager"
	) as GameModeManager
	var player_manager := get_first_node_in_group(
		"player_manager"
	) as PlayerManager
	var enemy_system := get_first_node_in_group("enemy_system") as EnemySystem
	var drop_system := get_first_node_in_group("drop_system") as DropSystem
	var health_system := get_first_node_in_group("health_system") as HealthSystem
	var progression := get_first_node_in_group(
		"progression_manager"
	) as ProgressionManager
	var audio_manager := get_first_node_in_group("audio_manager") as AudioManager
	var gameplay_effects := get_first_node_in_group(
		"gameplay_effects"
	) as GameplayEffects
	_expect(game_mode_manager != null, "game mode manager is available")
	_expect(player_manager != null, "player manager is available")
	_expect(enemy_system != null, "enemy system is available")
	_expect(drop_system != null, "drop system is available")
	_expect(health_system != null, "health system is available")
	_expect(progression != null, "progression manager is available")
	_expect(audio_manager != null, "audio manager is available")
	_expect(gameplay_effects != null, "gameplay effects system is available")
	if (
		game_mode_manager == null
		or player_manager == null
		or enemy_system == null
		or drop_system == null
		or health_system == null
		or progression == null
		or audio_manager == null
		or gameplay_effects == null
	):
		_finish()
		return

	audio_manager.gameplay_feedback_generated.connect(
		_on_gameplay_feedback_generated
	)
	game_mode_manager.set_mode(
		GameConstants.MODE_SURVIVAL,
		{
			"character_id": &"ranger",
			"single_biome_arena": true,
			"arena_boundary_mode": "walled",
			"world_seed": 20260621
		}
	)
	await _wait_process_frames(6)

	for initial_enemy in get_nodes_in_group("enemies"):
		initial_enemy.queue_free()
	await _wait_process_frames(2)

	var player := player_manager.players.get(1) as PlayerController
	_expect(player != null, "player one is spawned for the run")
	if player == null:
		_finish()
		return
	player.global_position = Vector2.ZERO

	var weapon_system := player.get_node("WeaponSystem") as WeaponSystem
	var rpg_component := player.get_node(
		"RpgPlayerComponent"
	) as RpgPlayerComponent
	var world_hud := player.get_node("WorldHud") as PlayerWorldHudVisual
	_expect(weapon_system != null, "player weapon system is available")
	_expect(rpg_component != null, "player RPG component is available")
	_expect(world_hud != null, "player world HUD is available")
	if weapon_system == null or rpg_component == null or world_hud == null:
		_finish()
		return
	_expect(rpg_component.character_id == &"ranger", "survival run applies the selected RPG class")
	_expect(weapon_system.has_base_weapon(&"rpg_bow"), "Ranger base weapon is separate and permanent")

	var blaster := load("res://game/weapons/prototype_blaster.tres") as WeaponData
	var revolver := WeaponCatalog.get_definition(&"heavy_revolver")
	_expect(
		drop_system.collect_drop(
			{
				"type": GameConstants.DROP_WEAPON,
				"amount": 1,
				"weapon_data": blaster
			},
			player
		),
		"first weapon pickup is collected"
	)
	_expect(
		drop_system.collect_drop(
			{
				"type": GameConstants.DROP_WEAPON,
				"amount": 1,
				"weapon_data": revolver
			},
			player
		),
		"second weapon pickup is collected"
	)
	_expect(weapon_system.get_weapon_count() == 2, "two picked weapons stay in the inventory")
	_expect(weapon_system.weapon_data.weapon_id == &"heavy_revolver", "latest pickup is auto-selected")
	_expect(weapon_system.switch_weapon(1), "inventory slot switch succeeds with two weapons")
	_expect(weapon_system.weapon_data.weapon_id == &"prototype_blaster", "slot switch restores the previous weapon")
	_expect(world_hud.get_magazine_size() == blaster.magazine_size, "world HUD follows the equipped weapon magazine")

	weapon_system.current_ammo = 1
	weapon_system.reserve_ammo = 0
	weapon_system.cooldown = 0.0
	_expect(
		weapon_system.try_fire_equipped(player.global_position, Vector2.RIGHT, player),
		"equipped weapon fires its last round"
	)
	_expect(weapon_system.current_ammo == 0, "equipped weapon consumes ammo")
	weapon_system.cooldown = 0.0
	_expect(
		not weapon_system.try_fire_equipped(
			player.global_position,
			Vector2.RIGHT,
			player
		),
		"empty equipped weapon does not fire"
	)
	_expect(
		weapon_system.weapon_data.weapon_id == &"prototype_blaster",
		"empty equipped weapon remains selected"
	)
	_expect(
		drop_system.collect_drop(
			{"type": GameConstants.DROP_AMMO, "amount": 5},
			player
		),
		"ammo pickup is collected"
	)
	_expect(weapon_system.is_reloading, "ammo pickup starts reload on the empty special")
	_expect(world_hud.is_showing_reload(), "world HUD exposes reload feedback")

	rpg_component.add_experience(40)
	var effects_before_kill := gameplay_effects.effect_spawn_count
	var money_before := progression.money
	var enemy := enemy_system.spawn_enemy(
		&"survival_zombie",
		Vector2(650.0, 0.0)
	) as BasicEnemy
	_expect(enemy != null, "survival zombie can be spawned for the loop")
	if enemy == null:
		_finish()
		return
	enemy.set_physics_process(false)
	enemy.global_position = Vector2(650.0, 0.0)
	enemy.loot_table = _make_guaranteed_money_loot(9)
	_expect(
		health_system.apply_damage(
			enemy,
			9999,
			player,
			&"milestone_11_kill",
			enemy.global_position
		) > 0,
		"player damage kills the zombie through HealthSystem"
	)
	await _wait_process_frames(6)

	_expect(rpg_component.level == 2, "killer XP levels up the RPG component")
	_expect(rpg_component.experience == 0, "level-up consumes the exact XP threshold")
	_expect(
		rpg_component.get_active_passive_text().begins_with("OCCHIO"),
		"Ranger passive feedback is active after a distant hit"
	)
	_expect(
		_count_xp_pickups() == 0,
		"survival zombie kill grants RPG XP directly without XP pickup"
	)
	_expect(
		_has_effect_kind(gameplay_effects, &"rpg_level_up"),
		"level-up visual feedback is spawned"
	)
	_expect(
		gameplay_effects.effect_spawn_count > effects_before_kill,
		"kill and level-up produce gameplay effects"
	)

	var money_pickup := _find_pickup(GameConstants.DROP_MONEY)
	_expect(money_pickup != null, "enemy death spawns a physical money drop")
	if money_pickup != null:
		_expect(money_pickup.try_collect(player), "physical money drop can be collected")
		await _wait_process_frames(2)
		_expect(progression.money == money_before + 9, "physical drop updates party money")

	_expect(
		gameplay_feedback_events.has(&"pickup"),
		"pickup loop emits gameplay audio feedback"
	)
	_expect(
		gameplay_feedback_events.has(&"shot"),
		"weapon loop emits gameplay shot audio feedback"
	)

	_finish()

func _make_guaranteed_money_loot(amount: int) -> LootTable:
	var money_entry := DropEntry.new()
	money_entry.drop_type = GameConstants.DROP_MONEY
	money_entry.chance = 1.0
	money_entry.min_amount = amount
	money_entry.max_amount = amount
	var loot := LootTable.new()
	loot.entries = [money_entry]
	return loot

func _count_xp_pickups() -> int:
	var count := 0
	for pickup in get_nodes_in_group("drop_pickups"):
		if not pickup is DropPickup:
			continue
		var data := (pickup as DropPickup).drop_data
		if StringName(data.get("type", &"")) == GameConstants.DROP_EXPERIENCE:
			count += 1
	return count

func _find_pickup(drop_type: StringName) -> DropPickup:
	for pickup in get_nodes_in_group("drop_pickups"):
		if not pickup is DropPickup:
			continue
		var typed_pickup := pickup as DropPickup
		if StringName(typed_pickup.drop_data.get("type", &"")) == drop_type:
			return typed_pickup
	return null

func _has_effect_kind(effects: GameplayEffects, effect_kind: StringName) -> bool:
	for child in effects.get_children():
		if child is GameplayEffect and (child as GameplayEffect).effect_kind == effect_kind:
			return true
	return false

func _wait_process_frames(count: int) -> void:
	for _index in range(count):
		await process_frame

func _on_gameplay_feedback_generated(
	feedback_type: StringName,
	_source_id: StringName,
	_frames_written: int
) -> void:
	gameplay_feedback_events.append(feedback_type)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("MILESTONE_11_WEAPON_DROP_PROGRESSION_SMOKE_TEST: PASS")
		quit(0)
		return

	print("MILESTONE_11_WEAPON_DROP_PROGRESSION_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
