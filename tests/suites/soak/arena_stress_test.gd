extends GutTest
## Soak/Stress — Arena affollata (4 player, roster misto sotto carico).
##
## Migra:
##   tests/milestone_20_arena_stress_test.gd  (boot main.tscn, 32 nemici, 90 frame)
##
## NB: suite di stress, esclusa dal run rapido (.gutconfig.json). Si esegue su
## richiesta / notturno via .gutconfig.soak.json o tools/run_gut.sh -gdir.

const MainSceneFixture = preload("res://tests/support/main_scene_fixture.gd")
const ENEMY_IDS: Array[StringName] = [
	&"survival_zombie",
	&"survival_runner",
	&"survival_tank",
	&"survival_shooter"
]

func test_crowded_arena_under_load() -> void:
	var scene := MainSceneFixture.new()
	assert_true(scene.boot(self), "main scene can be loaded for arena stress")
	await wait_frames(3)

	var game_mode_manager := scene.node(&"game_mode_manager") as GameModeManager
	var local_multiplayer := scene.node(&"local_multiplayer_manager") as LocalMultiplayerManager
	var wave_manager := scene.node(&"wave_manager") as WaveManager
	var enemy_system := scene.node(&"enemy_system") as EnemySystem
	assert_not_null(game_mode_manager, "game mode manager is available")
	assert_not_null(local_multiplayer, "local multiplayer manager is available")
	assert_not_null(wave_manager, "wave manager is available")
	assert_not_null(enemy_system, "enemy system is available")
	if (
		game_mode_manager == null or local_multiplayer == null
		or wave_manager == null or enemy_system == null
	):
		scene.teardown()
		return

	for player_slot in range(2, 5):
		local_multiplayer.activate_slot(player_slot)
	wave_manager.initial_delay = 100.0
	game_mode_manager.set_mode(GameConstants.MODE_SURVIVAL, {})
	await wait_frames(2)
	assert_eq(scene.nodes(&"players").size(), 4, "stress scenario activates four local players")

	var spawned: Array[Node] = []
	var spawn_points: Array[Vector2] = []
	for spawn_index in range(6):
		spawn_points.append(Vector2.RIGHT.rotated(TAU * float(spawn_index) / 6.0) * 360.0)
	var start_msec := Time.get_ticks_msec()
	for index in range(32):
		var gate_position := spawn_points[index % spawn_points.size()]
		var inward := gate_position.direction_to(Vector2.ZERO)
		var side := inward.orthogonal()
		var enemy := enemy_system.spawn_enemy(
			ENEMY_IDS[index % ENEMY_IDS.size()],
			gate_position
			+ inward * float(28 + (index / spawn_points.size()) * 16)
			+ side * float((index % 3) - 1) * 18.0
		)
		if enemy != null:
			spawned.append(enemy)
	for _frame in range(90):
		await get_tree().physics_frame
	var elapsed_msec := Time.get_ticks_msec() - start_msec
	var roster_ids: Dictionary = {}
	for enemy in spawned:
		if is_instance_valid(enemy):
			roster_ids[StringName(enemy.get("enemy_id"))] = true
	assert_eq(spawned.size(), 32, "stress scenario spawns the full mixed roster")
	for enemy_id in ENEMY_IDS:
		assert_true(roster_ids.has(enemy_id), "stress scenario keeps %s active" % enemy_id)
	assert_lt(elapsed_msec, 5000, "mixed arena scenario processes 90 physics frames within budget")
	game_mode_manager.set_mode(GameConstants.MODE_MENU)
	await wait_frames(5)

	scene.teardown()
	await wait_frames(1)
