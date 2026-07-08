extends GutTest
## Modes A8 — Join/leave locale a meta' ondata (QA-001).
##
## Copre il churn di slot durante una wave attiva di Zombie Survival:
## LocalMultiplayerManager + PlayerManager + WaveManager + HUD. Il joiner
## viene spawnato e preparato per la run in corso, chi lascia viene despawnato
## senza lasciare bersagli penzolanti nei nemici (retarget), lo slot 1 non
## puo' mai lasciare e la wave si completa con il roster cambiato.

var _completed_waves: Array[int] = []

func test_join_and_leave_mid_wave() -> void:
	_completed_waves = []
	var scene = _new_main_scene_fixture()
	assert_true(scene.boot(self), "main scene can be loaded")
	await wait_physics_frames(3)

	var local_multiplayer: LocalMultiplayerManager = scene.node(&"local_multiplayer_manager") as LocalMultiplayerManager
	var player_manager: PlayerManager = scene.node(&"player_manager") as PlayerManager
	var wave_manager: WaveManager = scene.node(&"wave_manager") as WaveManager
	var health_system: HealthSystem = scene.node(&"health_system") as HealthSystem
	var progression: ProgressionManager = scene.node(&"progression_manager") as ProgressionManager
	var hud: HUDManager = scene.node(&"hud_manager") as HUDManager
	if local_multiplayer == null or player_manager == null or wave_manager == null or health_system == null or progression == null or hud == null:
		assert_true(false, "multiplayer/wave systems are available")
		scene.teardown()
		scene = null
		return

	wave_manager.wave_completed.connect(_on_wave_completed)
	local_multiplayer.activate_slot(2)
	await wait_physics_frames(1)
	assert_true(scene.start_survival(), "survival starts for the mid-wave churn")
	await wait_physics_frames(2)

	# Wave 1 forzata con spawn rapido, tre nemici regolari e nessun boss.
	wave_manager.spawn_interval = 0.05
	wave_manager.base_enemy_count = 3
	wave_manager.boss_wave_interval = 50
	wave_manager.start_next_wave()
	var spawn_frames := 0
	while wave_manager.get_active_wave_enemies().size() < 3 and spawn_frames < 300:
		await wait_physics_frames(1)
		spawn_frames += 1
	var enemies := wave_manager.get_active_wave_enemies()
	assert_eq(enemies.size(), 3, "three wave enemies are active mid-wave")
	if enemies.size() < 3:
		wave_manager.wave_completed.disconnect(_on_wave_completed)
		scene.teardown()
		scene = null
		return

	# JOIN a meta' wave: lo slot 3 entra, viene spawnato, preparato per la run
	# in corso e riceve la sua card HUD.
	local_multiplayer.activate_slot(3)
	await wait_physics_frames(2)
	var player_three := player_manager.players.get(3) as PlayerController
	assert_not_null(player_three, "joining mid-wave spawns player three")
	if player_three != null:
		var expected_max := 100 + progression.get_run_max_health_bonus()
		assert_eq(
			player_three.health_component.max_health,
			expected_max,
			"the mid-wave joiner is prepared for the current run"
		)
		assert_true(player_three.health_component.is_alive(), "the joiner spawns alive")
	var card_three := hud.player_cards.get(3) as Control
	assert_true(card_three != null and card_three.visible, "the joiner's HUD card becomes visible")

	# I player si avvicinano ai nemici cosi' il retarget dopo il leave resta
	# dentro la detection range.
	var player_one := player_manager.players.get(1) as PlayerController
	var player_two := player_manager.players.get(2) as PlayerController
	assert_true(player_one != null and player_two != null, "players one and two are active")
	if player_one == null or player_two == null:
		wave_manager.wave_completed.disconnect(_on_wave_completed)
		scene.teardown()
		scene = null
		return
	var anchor := (enemies[0] as Node2D).global_position
	player_two.global_position = anchor + Vector2(40.0, 0.0)
	player_one.global_position = anchor + Vector2(90.0, 0.0)
	if player_three != null:
		player_three.global_position = anchor + Vector2(130.0, 0.0)
	await wait_physics_frames(3)

	# LEAVE a meta' wave: lo slot 2 lascia; il player viene rimosso, la card
	# si nasconde e nessun nemico resta agganciato al player liberato.
	var player_two_id := player_two.get_instance_id()
	local_multiplayer.deactivate_slot(2)
	await wait_physics_frames(3)
	assert_false(player_manager.players.has(2), "leaving removes player two from the roster")
	var card_two := hud.player_cards.get(2) as Control
	assert_true(card_two != null and not card_two.visible, "the leaver's HUD card hides")
	var retargeted := 0
	for enemy in wave_manager.get_active_wave_enemies():
		var enemy_target: Node = enemy.get("target")
		if enemy_target != null and is_instance_valid(enemy_target):
			assert_ne(
				enemy_target.get_instance_id(),
				player_two_id,
				"no enemy keeps the departed player as target"
			)
			retargeted += 1
	assert_gt(retargeted, 0, "enemies re-acquire a living target after the leave")

	# Lo slot 1 non puo' mai lasciare la run.
	local_multiplayer.deactivate_slot(1)
	assert_true(player_manager.players.has(1), "slot one can never leave the run")
	assert_true(local_multiplayer.get_active_slots().has(1), "slot one stays active")

	# La wave si completa con il roster cambiato (1 + joiner) e senza residui.
	for enemy in wave_manager.get_active_wave_enemies():
		health_system.apply_damage(enemy, 999999, player_one, &"qa_smoke")
	var completion_frames := 0
	while not _completed_waves.has(1) and completion_frames < 240:
		await wait_physics_frames(1)
		completion_frames += 1
	assert_true(_completed_waves.has(1), "the wave completes after the slot churn")
	assert_eq(wave_manager.get_enemies_remaining(), 0, "no wave enemies remain after completion")

	wave_manager.wave_completed.disconnect(_on_wave_completed)
	local_multiplayer.deactivate_slot(3)
	await wait_physics_frames(1)
	scene.teardown()
	scene = null
	await wait_physics_frames(1)

func _on_wave_completed(wave_index: int) -> void:
	_completed_waves.append(wave_index)

func _new_main_scene_fixture():
	var script := ResourceLoader.load(
		"res://tests/support/main_scene_fixture.gd",
		"",
		ResourceLoader.CACHE_MODE_IGNORE
	) as Script
	assert_true(script != null, "main scene fixture script loads")
	return script.new() if script != null else null
