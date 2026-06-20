extends SceneTree

var failures := PackedStringArray()

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main_scene := load("res://game/main/main.tscn") as PackedScene
	_expect(main_scene != null, "main scene loads with the survival market")
	if main_scene == null:
		_finish()
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame

	var game_mode_manager := get_first_node_in_group("game_mode_manager") as GameModeManager
	var survival_mode := get_first_node_in_group("survival_mode") as SurvivalMode
	var wave_manager := get_first_node_in_group("wave_manager") as WaveManager
	var market := get_first_node_in_group(
		"survival_market_controller"
	) as SurvivalMarketController
	var market_ui := get_first_node_in_group("survival_market_ui") as SurvivalMarketUI
	var progression := get_first_node_in_group("progression_manager") as ProgressionManager
	var player_manager := get_first_node_in_group("player_manager") as PlayerManager
	var multiplayer := get_first_node_in_group(
		"local_multiplayer_manager"
	) as LocalMultiplayerManager
	var health_system := get_first_node_in_group("health_system") as HealthSystem
	_expect(game_mode_manager != null, "game mode manager is available")
	_expect(survival_mode != null, "survival mode is available")
	_expect(wave_manager != null, "wave manager is available")
	_expect(market != null, "market controller is available")
	_expect(market_ui != null, "market UI is available")
	_expect(progression != null, "shared wallet is available")
	_expect(player_manager != null and multiplayer != null, "multiplayer players are available")
	_expect(health_system != null, "health system is available")
	if (
		game_mode_manager == null
		or survival_mode == null
		or wave_manager == null
		or market == null
		or market_ui == null
		or progression == null
		or player_manager == null
		or multiplayer == null
		or health_system == null
	):
		_finish()
		return

	survival_mode.stop_mode()
	multiplayer.activate_slot(2)
	await process_frame
	var player_one := player_manager.players.get(1) as PlayerController
	var player_two := player_manager.players.get(2) as PlayerController
	_expect(player_one != null and player_two != null, "two local players can enter the market")
	if player_one == null or player_two == null:
		_finish()
		return

	wave_manager.initial_delay = 0.0
	wave_manager.intermission_duration = 0.01
	wave_manager.spawn_interval = 0.001
	wave_manager.base_enemy_count = 1
	wave_manager.enemy_count_growth = 0
	wave_manager.boss_wave_escort_count = 1
	wave_manager.boss_wave_interval = 5
	survival_mode.boss_wave_interval = 5
	market.set_random_seed(20260620)
	progression.add_money(220)
	_expect(game_mode_manager.set_mode(GameConstants.MODE_SURVIVAL), "survival run starts")
	var player_one_health := player_one.get_node("HealthComponent") as HealthComponent
	health_system.apply_damage(player_one, 90)

	_expect(
		await _advance_until_market(wave_manager, market, health_system),
		"waves 1-4 complete and the market opens only after boss wave 5"
	)
	_expect(wave_manager.current_wave == 5, "market belongs to wave 5")
	_expect(market.is_market_open, "market phase is active")
	_expect(
		wave_manager.state == WaveManager.State.REWARD
		and wave_manager.is_next_wave_blocked(),
		"wave progression remains blocked in reward state during the market"
	)
	_expect(
		wave_manager.get_enemies_remaining() == 0,
		"no zombie or boss remains and no new spawn starts during the market"
	)
	_expect(
		not player_one.gameplay_input_enabled
		and not player_two.gameplay_input_enabled,
		"combat input is disabled for every active player"
	)
	_expect(
		player_one_health.has_invulnerability_source(
			SurvivalMarketController.MARKET_INVULNERABILITY
		),
		"players cannot take combat damage during the market phase"
	)
	_expect(market_ui.visible, "market UI is visible")
	_expect(
		market_ui.wallet_label.text.contains(str(progression.money)),
		"market UI always exposes the shared wallet total"
	)

	var offers := market.get_weapon_offers()
	var unique_ids: Dictionary = {}
	for offer in offers:
		var weapon_id := StringName(offer.get("weapon_id", &""))
		unique_ids[weapon_id] = true
		_expect(
			WeaponCatalog.get_definition(weapon_id) != null,
			"weapon offer comes from the existing catalog"
		)
		_expect(
			not str(offer.get("display_name", "")).is_empty()
			and not StringName(offer.get("category", &"")).is_empty()
			and not StringName(offer.get("rarity", &"")).is_empty()
			and int(offer.get("cost", 0)) > 0
			and str(offer.get("stats_text", "")).contains("DMG"),
			"offer exposes name, category, rarity, price and readable stats"
		)
	_expect(offers.size() == 4 and unique_ids.size() == 4, "market rolls four unique weapons")

	var wallet_before_heal := progression.money
	var health_before := player_one_health.current_health
	_expect(
		market.try_purchase(1, SurvivalMarketController.ITEM_HEAL_SMALL),
		"P1 buys health for itself"
	)
	_expect(
		player_one_health.current_health > health_before
		and player_one_health.current_health <= player_one_health.max_health,
		"health purchase heals without exceeding max HP"
	)
	_expect(
		progression.money == wallet_before_heal - market.heal_small_cost,
		"health purchase deducts the shared wallet exactly once"
	)

	if not offers.is_empty():
		var weapon_offer := offers[0]
		var weapon_id := StringName(weapon_offer.get("weapon_id", &""))
		var wallet_before_weapon := progression.money
		_expect(market.try_purchase(1, weapon_id), "P1 buys a catalog weapon")
		var weapon_one := player_one.get_node("WeaponSystem") as WeaponSystem
		var weapon_two := player_two.get_node("WeaponSystem") as WeaponSystem
		_expect(
			weapon_one.has_weapon(weapon_id) and not weapon_two.has_weapon(weapon_id),
			"purchased weapon is assigned only to the buying player"
		)
		_expect(
			progression.money == wallet_before_weapon - int(weapon_offer.get("cost", 0)),
			"weapon purchase uses the shared wallet"
		)
		var refill_weapon := weapon_offer.get("weapon_data") as WeaponData
		if refill_weapon == null or refill_weapon.infinite_reserve_ammo:
			refill_weapon = WeaponCatalog.get_definition(&"tactical_carbine")
			weapon_one.add_weapon(refill_weapon, true)
		else:
			weapon_one.select_weapon(refill_weapon.weapon_id)
		weapon_one.current_ammo = 0
		weapon_one.reserve_ammo = 0
		var wallet_before_ammo := progression.money
		_expect(
			market.try_purchase(1, SurvivalMarketController.ITEM_AMMO_ACTIVE),
			"P1 refills only its equipped weapon"
		)
		_expect(
			weapon_one.current_ammo == refill_weapon.magazine_size
			and weapon_one.reserve_ammo == refill_weapon.starting_reserve_ammo,
			"equipped ammo purchase restores magazine and reserve"
		)
		_expect(
			progression.money == wallet_before_ammo - market.ammo_active_cost,
			"ammo purchase deducts its configured price"
		)

	progression.try_spend_money(progression.money)
	var denied_offer := offers[1] if offers.size() > 1 else {}
	var denied_id := StringName(denied_offer.get("weapon_id", &""))
	var player_two_weapons := player_two.get_node("WeaponSystem") as WeaponSystem
	_expect(
		not market.try_purchase(2, denied_id)
		and not player_two_weapons.has_weapon(denied_id)
		and progression.money == 0,
		"insufficient shared funds deny the purchase without assigning the weapon"
	)
	progression.add_money(100)
	player_one_health.current_health = player_one_health.max_health
	var wallet_at_full_health := progression.money
	_expect(
		not market.try_purchase(1, SurvivalMarketController.ITEM_HEAL_SMALL)
		and progression.money == wallet_at_full_health,
		"full HP denies healing without wasting money"
	)

	_expect(market.set_player_ready(1, true), "P1 marks itself ready")
	_expect(market.is_market_open, "one player cannot close the market for everyone")
	_expect(market.set_player_ready(2, true), "P2 marks itself ready")
	_expect(not market.is_market_open, "all living players ready close the market")
	_expect(
		await _wait_for_wave(wave_manager, 6),
		"closing the market resumes the run at wave 6"
	)
	_expect(
		player_one.gameplay_input_enabled
		and player_two.gameplay_input_enabled
		and not player_one_health.has_invulnerability_source(
			SurvivalMarketController.MARKET_INVULNERABILITY
		),
		"closing the market restores combat state"
	)
	_expect(
		market.should_open_after_wave(10)
		and market.should_open_after_wave(15)
		and not market.should_open_after_wave(6),
		"the recurring schedule targets waves 10, 15 and later multiples of five"
	)
	wave_manager.wave_completed.emit(5)
	await process_frame
	_expect(not market.is_market_open, "processed boss wave cannot reopen its market")

	survival_mode.stop_mode()
	_expect(
		not market.is_run_active
		and not market.is_market_open
		and market.get_weapon_offers().is_empty(),
		"new-run cleanup resets market state and offers"
	)
	_finish()

func _advance_until_market(
	wave_manager: WaveManager,
	market: SurvivalMarketController,
	health_system: HealthSystem
) -> bool:
	for _frame in range(2400):
		for enemy in wave_manager.get_active_wave_enemies():
			enemy.set_physics_process(false)
			health_system.apply_damage(enemy, 999999)
		var boss := wave_manager.get_active_boss()
		if boss != null:
			boss.set_physics_process(false)
			health_system.apply_damage(boss, 999999)
		if market.is_market_open:
			return true
		await physics_frame
	return false

func _wait_for_wave(wave_manager: WaveManager, wave_index: int) -> bool:
	for _frame in range(300):
		if wave_manager.current_wave == wave_index and wave_manager.wave_running:
			return true
		await physics_frame
	return false

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("ZOMBIE_MARKET_SMOKE_TEST: PASS")
		quit(0)
		return
	print("ZOMBIE_MARKET_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
