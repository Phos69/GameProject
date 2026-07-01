extends GutTest
## Modes A8 — Modalità core: survival wave loop, tower defense, dungeon, grafo.
##
## Migra e accorpa:
##   tests/survival_wave_smoke_test.gd   (main.tscn)
##   tests/tower_defense_smoke_test.gd   (main.tscn)
##   tests/dungeon_smoke_test.gd         (main.tscn)
##   tests/dungeon_graph_smoke_test.gd   (DungeonGenerator sintetico)

var _completed_waves: Array[int] = []
var _boss_waves: Array[int] = []
var _boss_requests: Array[StringName] = []
var _td_completed_waves: Array[int] = []
var _tower_shots: int = 0
var _completed_runs: Array[int] = []

# --- survival wave loop (survival_wave) -------------------------------------

func test_survival_wave_flow() -> void:
	_completed_waves = []
	_boss_waves = []
	_boss_requests = []
	var scene = _new_main_scene_fixture()
	assert_true(scene.boot(self), "main scene can be loaded")
	await wait_physics_frames(2)
	var wave_manager: WaveManager = scene.node(&"wave_manager") as WaveManager
	var game_mode_manager: GameModeManager = scene.node(&"game_mode_manager") as GameModeManager
	var survival_mode: SurvivalMode = scene.node(&"survival_mode") as SurvivalMode
	var local_multiplayer: LocalMultiplayerManager = scene.node(&"local_multiplayer_manager") as LocalMultiplayerManager
	var player_manager: PlayerManager = scene.node(&"player_manager") as PlayerManager
	var health_system: HealthSystem = scene.node(&"health_system") as HealthSystem
	var progression: ProgressionManager = scene.node(&"progression_manager") as ProgressionManager
	var hud: HUDManager = scene.node(&"hud_manager") as HUDManager
	var boss_system: BossSystem = scene.node(&"boss_system") as BossSystem
	var ammo_director: SurvivalAmmoDirector = scene.node(&"survival_ammo_director") as SurvivalAmmoDirector
	if wave_manager == null or game_mode_manager == null or survival_mode == null or local_multiplayer == null or player_manager == null or health_system == null or progression == null or hud == null or boss_system == null or ammo_director == null:
		assert_true(false, "survival wave systems are available")
		scene.teardown()
		scene = null
		return

	survival_mode.stop_mode()
	await wait_physics_frames(1)
	wave_manager.initial_delay = 0.0
	wave_manager.intermission_duration = 0.08
	wave_manager.spawn_interval = 0.05
	wave_manager.base_enemy_count = 2
	wave_manager.enemy_count_growth = 1
	wave_manager.boss_wave_interval = 3
	survival_mode.boss_wave_interval = 3
	wave_manager.boss_wave_escort_count = 4
	wave_manager.spawn_points = [Vector2(1100.0, 0.0), Vector2(-1100.0, 0.0), Vector2(0.0, 700.0), Vector2(0.0, -700.0), Vector2(900.0, 500.0)]
	wave_manager.wave_completed.connect(_on_survival_wave_completed)
	wave_manager.boss_wave_requested.connect(_on_boss_wave_requested)
	boss_system.boss_requested.connect(_on_boss_requested)

	var player_one := player_manager.players.get(1) as PlayerController
	if player_one == null:
		scene.teardown()
		scene = null
		return
	var player_one_health := player_one.get_node("HealthComponent") as HealthComponent
	var player_one_weapon := player_one.get_node("WeaponSystem") as WeaponSystem
	var blaster := load("res://game/weapons/prototype_blaster.tres") as WeaponData
	player_one_weapon.equip_weapon(blaster)
	var player_one_starting_reserve := player_one_weapon.reserve_ammo

	game_mode_manager.set_mode(GameConstants.MODE_SURVIVAL)
	assert_true(survival_mode.is_running, "survival mode starts the wave run")
	health_system.apply_damage(player_one, 30)

	assert_true(await _wait_for_wave_spawning(wave_manager, 1), "wave one enters spawning state")
	assert_true(await _wait_for_wave_combat(wave_manager, 1), "wave one reaches combat state")
	var wave_one_enemies := wave_manager.get_active_wave_enemies()
	assert_eq(wave_one_enemies.size(), 2, "wave one contains two enemies")
	var wave_one_enemy := wave_one_enemies[0] as BasicEnemy
	var wave_one_health := wave_one_enemy.health_component.max_health
	var wave_one_speed := wave_one_enemy.move_speed
	var wave_one_damage := wave_one_enemy.attack_damage
	_freeze_and_kill_wave(wave_manager, health_system)
	assert_true(await _wait_for_completed_wave(1), "wave one completes when all enemies die")
	assert_eq(progression.money, 4, "wave one grants party money")
	assert_eq(player_one_health.current_health, 76, "wave one reward heals player one")
	assert_eq(player_one_weapon.reserve_ammo, player_one_starting_reserve + 4, "wave one reward grants ammunition")

	local_multiplayer.activate_slot(2)
	await wait_physics_frames(1)
	var player_two := player_manager.players.get(2) as PlayerController
	if player_two == null:
		_teardown_survival(scene, local_multiplayer)
		return
	var player_two_weapon := player_two.get_node("WeaponSystem") as WeaponSystem
	player_two_weapon.equip_weapon(blaster)
	var player_two_starting_reserve := player_two_weapon.reserve_ammo

	assert_true(await _wait_for_wave_combat(wave_manager, 2), "wave two reaches combat state")
	var wave_two_enemies := wave_manager.get_active_wave_enemies()
	assert_eq(wave_two_enemies.size(), 3, "wave two increases enemy count to three")
	var wave_two_enemy := wave_two_enemies[0] as BasicEnemy
	var wave_two_health := wave_two_enemy.health_component.max_health
	assert_gt(wave_two_health, wave_one_health, "wave two increases enemy health")
	assert_gt(wave_two_enemy.move_speed, wave_one_speed, "wave two increases enemy speed")
	assert_gt(wave_two_enemy.attack_damage, wave_one_damage, "wave two increases enemy damage")
	await wait_physics_frames(1)
	assert_false(hud.status_label.text.contains("Wave 2"), "survival HUD omits the persistent wave info panel")
	assert_false(hud.status_label.text.contains("Enemies 3/3"), "survival HUD omits the persistent enemy count panel")
	var saved_current_ammo := player_one_weapon.current_ammo
	var saved_reserve_ammo := player_one_weapon.reserve_ammo
	player_one_weapon.current_ammo = 0
	player_one_weapon.reserve_ammo = 0
	assert_true(ammo_director.evaluate_ammo_pressure(), "ammo director spawns support when a living player has low special ammo")
	player_one_weapon.current_ammo = saved_current_ammo
	player_one_weapon.reserve_ammo = saved_reserve_ammo
	_freeze_and_kill_wave(wave_manager, health_system)
	assert_true(await _wait_for_completed_wave(2), "wave two completes")
	assert_eq(progression.money, 10, "wave two adds its party reward")
	assert_eq(player_two_weapon.reserve_ammo, player_two_starting_reserve + 5, "joined player receives wave two ammunition reward")

	assert_true(await _wait_for_wave_combat(wave_manager, 3), "wave three reaches combat state")
	var wave_three_enemies := wave_manager.get_active_wave_enemies()
	assert_eq(wave_three_enemies.size(), 4, "boss-marked wave spawns four escorts")
	assert_eq(wave_manager.current_wave_enemy_total, 5, "boss counts toward the wave total")
	assert_true(wave_manager.get_active_boss() is BasicBoss, "boss-marked wave spawns a real boss")
	assert_gt((wave_three_enemies[0] as BasicEnemy).health_component.max_health, wave_two_health, "boss-marked wave applies additional health scaling")
	assert_true(_boss_waves.has(3), "wave manager marks wave three as a boss wave")
	assert_true(_boss_requests.has(&"survival_wave_3"), "survival mode forwards the boss request to BossSystem")
	var boss_supply_crates := ammo_director.get_active_crates()
	assert_false(boss_supply_crates.is_empty(), "boss wave has a guaranteed supply crate")
	if not boss_supply_crates.is_empty():
		assert_true(boss_supply_crates[0].try_open(player_one), "supply crate opens and rolls its configured ammo and health loot")
		await wait_physics_frames(1)
		assert_true(_has_pickup_type(scene, GameConstants.DROP_AMMO) and _has_pickup_type(scene, GameConstants.DROP_HEALTH), "supply crate produces ammo and health pickups")
	_freeze_and_kill_wave(wave_manager, health_system)
	assert_true(await _wait_for_completed_wave(3), "wave three completes")
	assert_eq(progression.money, 18, "three wave rewards accumulate correctly")
	assert_eq(player_one_weapon.reserve_ammo, player_one_starting_reserve + 15, "player one receives ammunition after all three waves")
	assert_eq(player_two_weapon.reserve_ammo, player_two_starting_reserve + 11, "player two receives rewards only after joining")
	assert_eq(int(wave_manager.last_reward.get("money", 0)), 8, "wave manager exposes the latest reward to the HUD")

	player_one_weapon.current_ammo = 0
	player_one_weapon.reserve_ammo = 0
	player_two_weapon.current_ammo = 0
	player_two_weapon.reserve_ammo = 0
	assert_true(player_one_weapon.try_fire_base(player_one.global_position, Vector2.RIGHT, player_one), "player one can still use the separate base weapon at zero equipped ammo")
	assert_true(player_two_weapon.try_fire_base(player_two.global_position, Vector2.LEFT, player_two), "player two can still use the separate base weapon at zero equipped ammo")
	assert_true(player_one_weapon.get_base_weapon_data() != null and player_two_weapon.get_base_weapon_data() != null and not player_one_weapon.is_base_weapon_active() and not player_two_weapon.is_base_weapon_active(), "base attacks do not replace the equipped weapon selection")

	survival_mode.stop_mode()
	assert_false(wave_manager.run_active, "stopping survival stops the wave loop")
	_teardown_survival(scene, local_multiplayer)

func _teardown_survival(scene, local_multiplayer: LocalMultiplayerManager) -> void:
	if local_multiplayer != null:
		local_multiplayer.deactivate_slot(2)
	scene.teardown()
	scene = null
	await wait_physics_frames(1)

# --- tower defense (tower_defense) ------------------------------------------

func test_tower_defense_flow() -> void:
	_td_completed_waves = []
	_tower_shots = 0
	var scene = _new_main_scene_fixture()
	assert_true(scene.boot(self), "main scene can be loaded")
	await wait_physics_frames(2)
	var game_mode_manager: GameModeManager = scene.node(&"game_mode_manager") as GameModeManager
	var survival_mode: SurvivalMode = scene.node(&"survival_mode") as SurvivalMode
	var tower_defense_mode: TowerDefenseMode = scene.node(&"tower_defense_mode") as TowerDefenseMode
	var tower_defense_manager: TowerDefenseManager = scene.node(&"tower_defense_manager") as TowerDefenseManager
	var boss_system: BossSystem = scene.node(&"boss_system") as BossSystem
	var hud: HUDManager = scene.node(&"hud_manager") as HUDManager
	if game_mode_manager == null or survival_mode == null or tower_defense_mode == null or tower_defense_manager == null or boss_system == null or hud == null:
		assert_true(false, "tower defense systems are available")
		scene.teardown()
		scene = null
		return
	var wave_controller: TowerDefenseWaveController = tower_defense_mode.wave_controller
	if wave_controller == null:
		assert_true(false, "tower defense wave controller is available")
		scene.teardown()
		scene = null
		return
	wave_controller.initial_delay = 0.0
	wave_controller.intermission_duration = 0.08
	wave_controller.spawn_interval = 0.0
	wave_controller.base_enemy_count = 1
	wave_controller.enemy_count_growth = 0
	wave_controller.boss_wave_interval = 2
	wave_controller.boss_wave_escort_count = 0
	tower_defense_mode.defense_wave_completed.connect(_on_td_wave_completed)

	game_mode_manager.set_mode(GameConstants.MODE_TOWER_DEFENSE, {"initial_delay": 0.0, "starting_credits": 75})
	await wait_physics_frames(4)
	await wait_physics_frames(1)
	assert_true(tower_defense_mode.is_running, "tower defense mode starts")
	assert_false(survival_mode.is_running, "tower defense stops survival")
	assert_not_null(tower_defense_mode.active_arena, "tower defense arena is created")
	assert_eq(tower_defense_manager.base_health, 250, "core starts at full health")
	assert_eq(tower_defense_manager.credits, 75, "run starts with build credits")
	assert_true("Tower Defense" in hud.status_label.text, "HUD switches to tower defense")
	assert_true(hud.status_panel != null and hud.status_panel.is_visible_in_tree(), "HUD shows the tower defense status panel")
	assert_true(_status_panel_avoids_player_cards(hud), "tower defense status panel avoids critical corner HUD")

	var path_enemy := await _wait_for_path_enemy(tower_defense_mode)
	assert_not_null(path_enemy, "wave one spawns a path enemy through EnemySystem")
	if path_enemy == null:
		_teardown_simple(scene)
		return
	assert_true(path_enemy is TowerDefenseEnemy, "tower defense uses the dedicated path enemy")
	assert_true(path_enemy.is_in_group("tower_defense_targets"), "path enemy is targetable by defense towers")
	var base_health_before := tower_defense_manager.base_health
	path_enemy.move_speed = 1800.0
	path_enemy.acceleration = 20000.0
	assert_true(await _wait_for_base_damage(tower_defense_manager, base_health_before), "path enemy follows the route and damages the core")
	assert_true(await _wait_for_td_wave(1), "wave one completes after the enemy escapes")
	assert_eq(tower_defense_manager.credits, 91, "wave completion grants defense credits")

	var tower := tower_defense_mode.try_build_at_slot(&"slot_b") as DefenseTower
	assert_not_null(tower, "an available slot builds a tower")
	if tower == null:
		_teardown_simple(scene)
		return
	assert_eq(tower_defense_manager.credits, 66, "building spends the slot cost")
	tower.attack_range = 1200.0
	tower.fire_rate = 20.0
	tower.projectile_damage = 999
	tower.fired.connect(_on_tower_fired)

	var boss := await _wait_for_boss(boss_system)
	assert_not_null(boss, "wave two spawns a boss through BossSystem")
	if boss == null:
		_teardown_simple(scene)
		return
	assert_true(tower_defense_mode.current_wave_is_boss, "wave two is marked as a boss wave")
	assert_true(boss.is_in_group("tower_defense_targets"), "tower defense boss is targetable by towers")
	assert_true(await _wait_for_tower_shot(), "the placed tower fires automatically")
	assert_true(await _wait_for_td_wave(2), "boss wave completes after the tower kills the boss")
	assert_eq(tower_defense_manager.base_health, base_health_before - 12, "destroyed boss does not damage the core")
	assert_eq(tower_defense_manager.credits, 106, "boss bounty and wave reward are added to credits")
	await wait_physics_frames(2)
	assert_true("Core 238/250" in hud.status_label.text, "HUD displays core health")
	assert_true("Credits 106" in hud.status_label.text, "HUD displays defense credits")

	tower_defense_manager.damage_base(tower_defense_manager.base_health)
	await wait_physics_frames(1)
	assert_eq(tower_defense_mode.state, TowerDefenseWaveController.State.DEFEATED, "destroying the core defeats the run")
	assert_eq(tower_defense_mode.get_enemies_remaining(), 0, "defeat clears the active wave")

	game_mode_manager.set_mode(GameConstants.MODE_SURVIVAL)
	await wait_physics_frames(1)
	assert_false(tower_defense_mode.is_running, "leaving tower defense stops its runtime")
	assert_true(survival_mode.is_running, "survival restarts after tower defense")
	assert_eq(hud.status_label.text.find("Tower Defense"), -1, "survival does not keep tower defense status text")
	assert_true(hud.status_panel == null or not hud.status_panel.is_visible_in_tree(), "survival hides the tower defense status panel")
	assert_true(scene.nodes(&"defense_towers").is_empty(), "mode switch clears built towers")
	assert_null(scene.node(&"tower_build_slots"), "mode switch clears the tower defense arena")
	survival_mode.stop_mode()
	_teardown_simple(scene)

# --- dungeon (dungeon) ------------------------------------------------------

func test_dungeon_flow() -> void:
	_completed_runs = []
	var scene = _new_main_scene_fixture()
	assert_true(scene.boot(self), "main scene can be loaded")
	await wait_physics_frames(2)
	var game_mode_manager: GameModeManager = scene.node(&"game_mode_manager") as GameModeManager
	var survival_mode: SurvivalMode = scene.node(&"survival_mode") as SurvivalMode
	var dungeon_mode: DungeonMode = scene.node(&"dungeon_mode") as DungeonMode
	var dungeon_generator: DungeonGenerator = scene.node(&"dungeon_generator") as DungeonGenerator
	var player_manager: PlayerManager = scene.node(&"player_manager") as PlayerManager
	var health_system: HealthSystem = scene.node(&"health_system") as HealthSystem
	var boss_system: BossSystem = scene.node(&"boss_system") as BossSystem
	var hud: HUDManager = scene.node(&"hud_manager") as HUDManager
	if game_mode_manager == null or survival_mode == null or dungeon_mode == null or dungeon_generator == null or player_manager == null or health_system == null or boss_system == null or hud == null:
		assert_true(false, "dungeon systems are available")
		scene.teardown()
		scene = null
		return

	var layout_a := dungeon_generator.generate_layout(4242, 8)
	assert_eq(layout_a.size(), 8, "requested room count is respected")
	assert_eq(StringName(layout_a[0]["kind"]), &"start", "first room is a start room")
	assert_gte(DungeonGenerator.get_boss_room_id(layout_a), 0, "layout has a boss room")
	assert_true(DungeonGenerator.boss_is_always_reachable(layout_a), "boss is reachable from every room")
	assert_true(_has_branch(layout_a), "the layout offers a real choice between two rooms")
	assert_gte(_count_kind(layout_a, &"shop"), 1, "the layout contains a shop room")

	dungeon_mode.combat_base_enemy_count = 2
	dungeon_mode.combat_enemy_growth = 1
	dungeon_mode.dungeon_completed.connect(_on_dungeon_completed)
	game_mode_manager.set_mode(GameConstants.MODE_DUNGEON, {"seed": 4242, "room_count": 8})
	await wait_physics_frames(4)
	await wait_physics_frames(1)

	assert_true(dungeon_mode.is_running, "dungeon mode starts")
	assert_false(survival_mode.is_running, "starting dungeon stops survival")
	assert_eq(dungeon_mode.run_seed, 4242, "dungeon exposes the active seed")
	assert_eq(StringName(dungeon_mode.get_current_room_data().get("kind", &"")), &"start", "run begins in the start room")
	assert_false(dungeon_mode.active_room.is_locked, "the start room exit is open")
	assert_true("Procedural Dungeon" in hud.status_label.text, "HUD switches to dungeon status")
	assert_true("Seed 4242" in hud.status_label.text, "HUD displays the dungeon seed")
	assert_true("Map" in hud.status_label.text, "HUD shows the dungeon path map")

	var player_one := player_manager.players.get(1) as PlayerController
	if player_one == null:
		_teardown_simple(scene)
		return
	var first_target := dungeon_mode.get_forward_options()[0]
	player_one.global_position = dungeon_mode.active_room.get_exit_position_for_target(first_target)
	assert_true(await _wait_for_room(dungeon_mode, first_target), "walking the exit portal advances to the chosen room")

	var visited_shop := false
	var guard := 0
	while StringName(dungeon_mode.get_current_room_data().get("kind", &"")) != &"boss" and guard < 40:
		guard += 1
		var kind := StringName(dungeon_mode.get_current_room_data().get("kind", &""))
		if kind == &"combat":
			_kill_room_enemies(dungeon_mode, health_system)
			assert_true(await _wait_for_room_unlocked(dungeon_mode), "combat room unlocks after clearing")
		if kind == &"shop" and not visited_shop:
			visited_shop = true
			await _test_shop(scene, dungeon_mode, player_one)
		var forward := dungeon_mode.get_forward_options()
		assert_false(forward.is_empty(), "non-boss room has a forward path")
		if forward.is_empty():
			break
		var target := forward[0]
		if not visited_shop:
			for option in forward:
				if StringName(dungeon_mode.layout[option].get("kind", &"")) == &"shop":
					target = option
		assert_true(dungeon_mode.choose_next_room(target), "room accepts a real room choice")
		await wait_physics_frames(1)
		await wait_physics_frames(1)

	assert_true(visited_shop, "the walk visited the shop branch")
	assert_eq(StringName(dungeon_mode.get_current_room_data().get("kind", &"")), &"boss", "the path reaches the boss room")
	assert_true(dungeon_mode.active_room.is_locked, "boss room locks its exit")
	var boss := boss_system.get_active_boss()
	assert_not_null(boss, "boss room requests a shared boss")
	if boss != null:
		boss.set_physics_process(false)
		health_system.apply_damage(boss, 99999)
		assert_true(await _wait_for_room_unlocked(dungeon_mode), "boss defeat unlocks the final exit")

	assert_true(dungeon_mode.request_next_room(), "the final exit completes the run")
	assert_eq(dungeon_mode.current_room_state, &"complete", "dungeon enters complete state")
	assert_true(_completed_runs.has(4242), "dungeon completion reports the seed")

	game_mode_manager.set_mode(GameConstants.MODE_SURVIVAL)
	await wait_physics_frames(1)
	assert_false(dungeon_mode.is_running, "leaving dungeon stops its runtime")
	assert_true(survival_mode.is_running, "survival can restart after the dungeon")
	survival_mode.stop_mode()
	_teardown_simple(scene)

func _test_shop(scene, dungeon_mode: DungeonMode, buyer: Node) -> void:
	var offers := dungeon_mode.get_shop_offers()
	assert_gte(offers.size(), 2, "shop presents at least two offers")
	var credits_before := dungeon_mode.run_credits
	var cheapest_index := 0
	for index in range(offers.size()):
		if int(offers[index].get("cost", 0)) < int(offers[cheapest_index].get("cost", 0)):
			cheapest_index = index
	var cost := int(offers[cheapest_index].get("cost", 0))
	var pickups_before = scene.nodes(&"drop_pickups").size()
	assert_true(dungeon_mode.purchase_offer(cheapest_index, buyer), "an affordable offer can be purchased")
	assert_eq(dungeon_mode.run_credits, credits_before - cost, "purchase spends exactly the offer cost")
	await wait_physics_frames(1)
	assert_gt(scene.nodes(&"drop_pickups").size(), pickups_before, "purchase spawns the reward through DropSystem")
	assert_false(dungeon_mode.purchase_offer(cheapest_index, buyer), "a sold offer cannot be bought again")
	dungeon_mode.run_credits = 0
	assert_false(dungeon_mode.purchase_offer((cheapest_index + 1) % offers.size(), buyer), "an unaffordable offer is rejected")

# --- grafo del dungeon (dungeon_graph) --------------------------------------

func test_dungeon_graph() -> void:
	var generator := DungeonGenerator.new()
	add_child(generator)
	for seed_value in [101, 202, 303, 404, 505, 606, 707, 808]:
		for room_count in [6, 8, 10]:
			_check_layout(generator, seed_value, room_count)
	var tiny := generator.generate_layout(999, 4)
	assert_eq(tiny.size(), 4, "minimum room count is respected")
	assert_true(DungeonGenerator.boss_is_always_reachable(tiny), "tiny dungeon keeps boss reachable")
	generator.queue_free()
	await wait_physics_frames(1)

func _check_layout(generator: DungeonGenerator, seed_value: int, room_count: int) -> void:
	var label := "seed %d / %d rooms" % [seed_value, room_count]
	var layout := generator.generate_layout(seed_value, room_count)
	var again := generator.generate_layout(seed_value, room_count)
	assert_eq(layout.size(), room_count, "%s: total room count respected" % label)
	assert_true(_layouts_equal(layout, again), "%s: same seed is deterministic" % label)
	assert_eq(_count_kind(layout, DungeonGenerator.KIND_START), 1, "%s: exactly one start" % label)
	assert_eq(_count_kind(layout, DungeonGenerator.KIND_BOSS), 1, "%s: exactly one boss" % label)
	assert_gte(_count_kind(layout, DungeonGenerator.KIND_SHOP), 1, "%s: at least one shop" % label)
	assert_true(_has_branch(layout), "%s: at least one room offers a real choice" % label)
	assert_true(DungeonGenerator.boss_is_always_reachable(layout), "%s: boss reachable from every room" % label)
	assert_true(_grids_unique(layout), "%s: room grid cells do not overlap" % label)

# --- helper -----------------------------------------------------------------

func _teardown_simple(scene) -> void:
	scene.teardown()
	scene = null
	await wait_physics_frames(1)

func _freeze_and_kill_wave(wave_manager: WaveManager, health_system: HealthSystem) -> void:
	for enemy in wave_manager.get_active_wave_enemies():
		enemy.set_physics_process(false)
		health_system.apply_damage(enemy, 9999)
	var boss := wave_manager.get_active_boss()
	if boss != null:
		boss.set_physics_process(false)
		health_system.apply_damage(boss, 9999)

func _wait_for_wave_spawning(wave_manager: WaveManager, wave_index: int) -> bool:
	for _frame in range(180):
		if wave_manager.current_wave == wave_index and wave_manager.state == WaveManager.State.SPAWNING:
			return true
		await wait_physics_frames(1)
	return false

func _wait_for_wave_combat(wave_manager: WaveManager, wave_index: int) -> bool:
	for _frame in range(300):
		if wave_manager.current_wave == wave_index and wave_manager.state == WaveManager.State.COMBAT:
			return true
		await wait_physics_frames(1)
	return false

func _wait_for_completed_wave(wave_index: int) -> bool:
	for _frame in range(180):
		if _completed_waves.has(wave_index):
			return true
		await wait_physics_frames(1)
	return false

func _wait_for_td_wave(wave_index: int) -> bool:
	for _frame in range(240):
		if _td_completed_waves.has(wave_index):
			return true
		await wait_physics_frames(1)
	return false

func _wait_for_path_enemy(tower_defense_mode: TowerDefenseMode) -> TowerDefenseEnemy:
	for _frame in range(180):
		for enemy in tower_defense_mode.wave_enemies:
			if enemy is TowerDefenseEnemy:
				return enemy as TowerDefenseEnemy
		await wait_physics_frames(1)
	return null

func _wait_for_base_damage(tower_defense_manager: TowerDefenseManager, previous_health: int) -> bool:
	for _frame in range(240):
		if tower_defense_manager.base_health < previous_health:
			return true
		await wait_physics_frames(1)
	return false

func _wait_for_boss(boss_system: BossSystem) -> BasicBoss:
	for _frame in range(240):
		var boss := boss_system.get_active_boss()
		if boss is BasicBoss:
			return boss as BasicBoss
		await wait_physics_frames(1)
	return null

func _wait_for_tower_shot() -> bool:
	for _frame in range(180):
		if _tower_shots > 0:
			return true
		await wait_physics_frames(1)
	return false

func _wait_for_room(dungeon_mode: DungeonMode, room_index: int) -> bool:
	for _frame in range(120):
		if dungeon_mode.current_room_index == room_index:
			return true
		await wait_physics_frames(1)
	return false

func _wait_for_room_unlocked(dungeon_mode: DungeonMode) -> bool:
	for _frame in range(120):
		if dungeon_mode.active_room != null and not dungeon_mode.active_room.is_locked:
			return true
		await wait_physics_frames(1)
	return false

func _kill_room_enemies(dungeon_mode: DungeonMode, health_system: HealthSystem) -> void:
	for enemy in dungeon_mode.room_enemies.duplicate():
		if not is_instance_valid(enemy):
			continue
		enemy.set_physics_process(false)
		health_system.apply_damage(enemy, 99999)

func _status_panel_avoids_player_cards(hud: HUDManager) -> bool:
	if hud.status_panel == null or not hud.status_panel.is_visible_in_tree():
		return false
	var status_rect := hud.status_panel.get_global_rect()
	for card_value in hud.player_cards.values():
		var card := card_value as Control
		if card == null or not card.is_visible_in_tree():
			continue
		if status_rect.intersects(card.get_global_rect()):
			return false
	return true

func _has_pickup_type(scene, drop_type: StringName) -> bool:
	for pickup in scene.nodes(&"drop_pickups"):
		if pickup is DropPickup and StringName((pickup as DropPickup).drop_data.get("type", &"")) == drop_type:
			return true
	return false

func _has_branch(rooms: Array[Dictionary]) -> bool:
	for room in rooms:
		if (room.get("forward", []) as Array).size() >= 2:
			return true
	return false

func _count_kind(rooms: Array[Dictionary], kind: StringName) -> int:
	var count := 0
	for room in rooms:
		if StringName(room.get("kind", &"")) == kind:
			count += 1
	return count

func _grids_unique(rooms: Array[Dictionary]) -> bool:
	var seen: Dictionary = {}
	for room in rooms:
		var grid := room.get("grid", Vector2i.ZERO) as Vector2i
		if seen.has(grid):
			return false
		seen[grid] = true
	return true

func _layouts_equal(a: Array[Dictionary], b: Array[Dictionary]) -> bool:
	if a.size() != b.size():
		return false
	for index in range(a.size()):
		if StringName(a[index].get("kind", &"")) != StringName(b[index].get("kind", &"")):
			return false
		if (a[index].get("grid", Vector2i.ZERO) as Vector2i) != (b[index].get("grid", Vector2i.ZERO) as Vector2i):
			return false
		if (a[index].get("forward", []) as Array) != (b[index].get("forward", []) as Array):
			return false
	return true

# --- signal handler ---------------------------------------------------------

func _on_survival_wave_completed(wave_index: int) -> void:
	_completed_waves.append(wave_index)

func _on_boss_wave_requested(wave_index: int) -> void:
	_boss_waves.append(wave_index)

func _on_boss_requested(_mode_id: StringName, reason: StringName) -> void:
	_boss_requests.append(reason)

func _on_td_wave_completed(wave_index: int, _reward_credits: int) -> void:
	_td_completed_waves.append(wave_index)

func _on_tower_fired(_target: Node, _projectile: Node) -> void:
	_tower_shots += 1

func _on_dungeon_completed(seed_value: int, _room_count: int) -> void:
	_completed_runs.append(seed_value)
func _new_main_scene_fixture():
	var script := ResourceLoader.load(
		"res://tests/support/main_scene_fixture.gd",
		"",
		ResourceLoader.CACHE_MODE_IGNORE
	) as Script
	assert_true(script != null, "main scene fixture script loads")
	return script.new() if script != null else null
