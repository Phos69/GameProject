extends SceneTree

var failures: PackedStringArray = []
var completed_waves: Array[int] = []
var tower_shots: int = 0

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
	await process_frame
	await process_frame

	var game_mode_manager := get_first_node_in_group("game_mode_manager") as GameModeManager
	var survival_mode := get_first_node_in_group("survival_mode") as SurvivalMode
	var tower_defense_mode := get_first_node_in_group(
		"tower_defense_mode"
	) as TowerDefenseMode
	var tower_defense_manager := get_first_node_in_group(
		"tower_defense_manager"
	) as TowerDefenseManager
	var enemy_system := get_first_node_in_group("enemy_system") as EnemySystem
	var boss_system := get_first_node_in_group("boss_system") as BossSystem
	var hud := get_first_node_in_group("hud_manager") as HUDManager
	_expect(game_mode_manager != null, "game mode manager is available")
	_expect(survival_mode != null, "survival mode is available")
	_expect(tower_defense_mode != null, "tower defense mode is registered")
	_expect(tower_defense_manager != null, "tower defense manager is available")
	_expect(enemy_system != null, "enemy system is available")
	_expect(boss_system != null, "boss system is available")
	_expect(hud != null, "HUD manager is available")
	if (
		game_mode_manager == null
		or survival_mode == null
		or tower_defense_mode == null
		or tower_defense_manager == null
		or enemy_system == null
		or boss_system == null
		or hud == null
	):
		_finish()
		return

	var wave_controller: TowerDefenseWaveController = tower_defense_mode.wave_controller
	_expect(wave_controller != null, "tower defense wave controller is available")
	if wave_controller == null:
		_finish()
		return
	wave_controller.initial_delay = 0.0
	wave_controller.intermission_duration = 0.08
	wave_controller.spawn_interval = 0.0
	wave_controller.base_enemy_count = 1
	wave_controller.enemy_count_growth = 0
	wave_controller.boss_wave_interval = 2
	wave_controller.boss_wave_escort_count = 0
	tower_defense_mode.defense_wave_completed.connect(_on_wave_completed)

	game_mode_manager.set_mode(
		GameConstants.MODE_TOWER_DEFENSE,
		{"initial_delay": 0.0, "starting_credits": 75}
	)
	await process_frame
	await physics_frame

	_expect(tower_defense_mode.is_running, "tower defense mode starts")
	_expect(not survival_mode.is_running, "tower defense stops survival")
	_expect(tower_defense_mode.active_arena != null, "tower defense arena is created")
	_expect(tower_defense_manager.base_health == 250, "core starts at full health")
	_expect(tower_defense_manager.credits == 75, "run starts with build credits")
	_expect("Tower Defense" in hud.status_label.text, "HUD switches to tower defense")
	_expect(
		hud.status_panel != null and hud.status_panel.is_visible_in_tree(),
		"HUD shows the tower defense status panel"
	)
	_expect(
		_status_panel_avoids_player_cards(hud),
		"tower defense status panel avoids critical corner HUD"
	)

	var path_enemy := await _wait_for_path_enemy(tower_defense_mode)
	_expect(path_enemy != null, "wave one spawns a path enemy through EnemySystem")
	if path_enemy == null:
		_finish()
		return
	_expect(path_enemy is TowerDefenseEnemy, "tower defense uses the dedicated path enemy")
	_expect(
		path_enemy.is_in_group("tower_defense_targets"),
		"path enemy is targetable by defense towers"
	)
	var base_health_before := tower_defense_manager.base_health
	path_enemy.move_speed = 1800.0
	path_enemy.acceleration = 20000.0
	_expect(
		await _wait_for_base_damage(tower_defense_manager, base_health_before),
		"path enemy follows the route and damages the core"
	)
	_expect(await _wait_for_wave_completed(1), "wave one completes after the enemy escapes")
	_expect(tower_defense_manager.credits == 91, "wave completion grants defense credits")

	var tower := tower_defense_mode.try_build_at_slot(&"slot_b") as DefenseTower
	_expect(tower != null, "an available slot builds a tower")
	if tower == null:
		_finish()
		return
	_expect(tower_defense_manager.credits == 66, "building spends the slot cost")
	tower.attack_range = 1200.0
	tower.fire_rate = 20.0
	tower.projectile_damage = 999
	tower.fired.connect(_on_tower_fired)

	var boss := await _wait_for_boss(boss_system)
	_expect(boss != null, "wave two spawns a boss through BossSystem")
	if boss == null:
		_finish()
		return
	_expect(tower_defense_mode.current_wave_is_boss, "wave two is marked as a boss wave")
	_expect(
		boss.is_in_group("tower_defense_targets"),
		"tower defense boss is targetable by towers"
	)
	_expect(await _wait_for_tower_shot(), "the placed tower fires automatically")
	_expect(await _wait_for_wave_completed(2), "boss wave completes after the tower kills the boss")
	_expect(
		tower_defense_manager.base_health == base_health_before - 12,
		"destroyed boss does not damage the core"
	)
	_expect(
		tower_defense_manager.credits == 106,
		"boss bounty and wave reward are added to credits"
	)
	await process_frame
	await process_frame
	_expect("Core 238/250" in hud.status_label.text, "HUD displays core health")
	_expect("Credits 106" in hud.status_label.text, "HUD displays defense credits")

	tower_defense_manager.damage_base(tower_defense_manager.base_health)
	await process_frame
	_expect(tower_defense_mode.state == TowerDefenseWaveController.State.DEFEATED, "destroying the core defeats the run")
	_expect(
		tower_defense_mode.get_enemies_remaining() == 0,
		"defeat clears the active wave"
	)

	game_mode_manager.set_mode(GameConstants.MODE_SURVIVAL)
	await process_frame
	_expect(not tower_defense_mode.is_running, "leaving tower defense stops its runtime")
	_expect(survival_mode.is_running, "survival restarts after tower defense")
	_expect(
		hud.status_label.text.find("Tower Defense") == -1,
		"survival does not keep tower defense status text"
	)
	_expect(
		hud.status_panel == null or not hud.status_panel.is_visible_in_tree(),
		"survival hides the tower defense status panel"
	)
	_expect(get_nodes_in_group("defense_towers").is_empty(), "mode switch clears built towers")
	_expect(
		get_first_node_in_group("tower_build_slots") == null,
		"mode switch clears the tower defense arena"
	)
	survival_mode.stop_mode()
	_finish()

func _wait_for_path_enemy(tower_defense_mode: TowerDefenseMode) -> TowerDefenseEnemy:
	for _frame in range(180):
		for enemy in tower_defense_mode.wave_enemies:
			if enemy is TowerDefenseEnemy:
				return enemy as TowerDefenseEnemy
		await physics_frame
	return null

func _wait_for_base_damage(
	tower_defense_manager: TowerDefenseManager,
	previous_health: int
) -> bool:
	for _frame in range(240):
		if tower_defense_manager.base_health < previous_health:
			return true
		await physics_frame
	return false

func _wait_for_boss(boss_system: BossSystem) -> BasicBoss:
	for _frame in range(240):
		var boss := boss_system.get_active_boss()
		if boss is BasicBoss:
			return boss as BasicBoss
		await physics_frame
	return null

func _wait_for_tower_shot() -> bool:
	for _frame in range(180):
		if tower_shots > 0:
			return true
		await physics_frame
	return false

func _wait_for_wave_completed(wave_index: int) -> bool:
	for _frame in range(240):
		if completed_waves.has(wave_index):
			return true
		await physics_frame
	return false

func _on_wave_completed(wave_index: int, _reward_credits: int) -> void:
	completed_waves.append(wave_index)

func _on_tower_fired(_target: Node, _projectile: Node) -> void:
	tower_shots += 1

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

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("TOWER_DEFENSE_SMOKE_TEST: PASS")
		quit(0)
		return
	print("TOWER_DEFENSE_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
