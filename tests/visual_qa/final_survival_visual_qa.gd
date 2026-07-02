extends SceneTree

const OUTPUT_DIRECTORY: String = "res://build/qa"
const VISUAL_QA_RUNTIME = preload(
	"res://tests/visual_qa/helpers/visual_qa_runtime.gd"
)

var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main_scene := load("res://game/main/main.tscn") as PackedScene
	_expect(main_scene != null, "main scene can be loaded for final QA")
	if main_scene == null:
		_finish()
		return

	var main := main_scene.instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	await process_frame

	var game_mode_manager := get_first_node_in_group(
		"game_mode_manager"
	) as GameModeManager
	var wave_manager := get_first_node_in_group(
		"wave_manager"
	) as WaveManager
	var local_multiplayer := get_first_node_in_group(
		"local_multiplayer_manager"
	) as LocalMultiplayerManager
	var player_manager := get_first_node_in_group(
		"player_manager"
	) as PlayerManager
	var enemy_system := get_first_node_in_group(
		"enemy_system"
	) as EnemySystem
	var boss_system := get_first_node_in_group(
		"boss_system"
	) as BossSystem
	var health_system := get_first_node_in_group(
		"health_system"
	) as HealthSystem
	var hud := get_first_node_in_group("hud_manager") as HUDManager
	_expect(game_mode_manager != null, "game mode manager is available")
	_expect(wave_manager != null, "wave manager is available")
	_expect(local_multiplayer != null, "local multiplayer manager is available")
	_expect(player_manager != null, "player manager is available")
	_expect(enemy_system != null, "enemy system is available")
	_expect(boss_system != null, "boss system is available")
	_expect(health_system != null, "health system is available")
	_expect(hud != null, "HUD manager is available")
	if (
		game_mode_manager == null
		or wave_manager == null
		or local_multiplayer == null
		or player_manager == null
		or enemy_system == null
		or boss_system == null
		or health_system == null
		or hud == null
	):
		_finish()
		return

	wave_manager.initial_delay = 100.0
	for player_slot in range(2, 5):
		local_multiplayer.activate_slot(player_slot)
	game_mode_manager.set_mode(GameConstants.MODE_SURVIVAL)
	var world_ready: Dictionary = await VISUAL_QA_RUNTIME.wait_for_capture_ready(
		self,
		func() -> bool:
			return (
				game_mode_manager.active_mode_id == GameConstants.MODE_SURVIVAL
				and player_manager.players.size() == 4
			)
	)
	_expect(
		bool(world_ready.get("ready", false)),
		"final survival world is capture-ready: %s"
		% VISUAL_QA_RUNTIME.describe_failure(world_ready)
	)

	var player_positions: Array[Vector2] = [
		Vector2(-180.0, 80.0),
		Vector2(-55.0, 115.0),
		Vector2(70.0, 115.0),
		Vector2(195.0, 80.0)
	]
	var player_directions: Array[Vector2] = [
		Vector2(0.8, -0.4).normalized(),
		Vector2(0.5, -0.7).normalized(),
		Vector2(-0.5, -0.7).normalized(),
		Vector2(-0.8, -0.4).normalized()
	]
	var blaster := load(
		"res://game/weapons/prototype_blaster.tres"
	) as WeaponData
	var cannon := load(
		"res://game/weapons/wave_cannon.tres"
	) as WeaponData
	for player_slot in range(1, 5):
		var player := player_manager.players.get(player_slot) as PlayerController
		if player == null:
			continue
		player.global_position = player_positions[player_slot - 1]
		player.set_physics_process(false)
		player.facing_direction = player_directions[player_slot - 1]
		player.visual.set_facing(player.facing_direction)
		if player_slot == 2:
			(player.weapon_system as WeaponSystem).equip_weapon(blaster)
		elif player_slot >= 3:
			(player.weapon_system as WeaponSystem).equip_weapon(cannon)

	var enemies: Array[BasicEnemy] = []
	var enemy_ids: Array[StringName] = [
		&"survival_runner",
		&"survival_zombie",
		&"survival_tank"
	]
	var enemy_positions: Array[Vector2] = [
		Vector2(-310.0, -55.0),
		Vector2(0.0, -115.0),
		Vector2(310.0, -55.0)
	]
	for index in range(enemy_ids.size()):
		var enemy := enemy_system.spawn_enemy(
			enemy_ids[index],
			enemy_positions[index]
		) as BasicEnemy
		if enemy != null:
			enemy.set_physics_process(false)
			enemies.append(enemy)

	hud.combat_announcement.show_announcement(
		&"wave_started",
		"WAVE 4",
		"SURVIVE",
		Color(1.0, 0.72, 0.24, 1.0),
		4.0
	)
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(OUTPUT_DIRECTORY)
	)
	for _frame in range(15):
		await process_frame
	_expect(
		enemies.size() == enemy_ids.size()
		and hud.combat_announcement.is_active(),
		"wave presentation marker is active"
	)
	_expect(
		await _capture("milestone_14_wave_presentation.png"),
		"four-player wave presentation is captured"
	)

	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	await process_frame

	var boss := boss_system.request_boss(
		GameConstants.MODE_SURVIVAL,
		&"final_visual_qa",
		Vector2(-150.0, -40.0)
	) as BasicBoss
	_expect(boss != null, "Wave Warden is available for final QA")
	if boss == null:
		_finish()
		return
	boss.set_physics_process(false)
	boss.aimed_telegraph_duration = 4.0
	boss.radial_telegraph_duration = 4.0
	var player_one := player_manager.players.get(1) as PlayerController
	boss.target = player_one
	_expect(
		boss.start_attack_telegraph(&"aimed_volley"),
		"phase one aimed telegraph starts"
	)
	for _frame in range(12):
		await process_frame
	_expect(
		boss.pending_pattern_id == &"aimed_volley"
		and boss.telegraph_timer > 0.0,
		"phase one marker shows the aimed telegraph"
	)
	_expect(
		await _capture("milestone_14_boss_phase_one.png"),
		"phase one boss presentation is captured"
	)

	boss.cancel_attack_telegraph()
	var boss_health := boss.get_node("HealthComponent") as HealthComponent
	health_system.apply_damage(
		boss,
		boss_health.current_health - boss_health.max_health / 2
	)
	_expect(
		boss.start_attack_telegraph(&"radial_burst"),
		"phase two radial telegraph starts"
	)
	for _frame in range(12):
		await process_frame
	_expect(
		boss.pending_pattern_id == &"radial_burst"
		and boss.telegraph_timer > 0.0
		and boss.phase_index == 2,
		"phase two marker shows the radial telegraph"
	)
	_expect(
		await _capture("milestone_14_boss_phase_two.png"),
		"phase two boss presentation is captured"
	)

	boss.cancel_attack_telegraph()
	health_system.apply_damage(boss, 99999)
	for _frame in range(12):
		await process_frame
	_expect(
		not is_instance_valid(boss)
		or boss.is_queued_for_deletion()
		or boss.is_dead,
		"boss defeat marker is active"
	)
	_expect(
		await _capture("milestone_14_boss_defeat.png"),
		"boss defeat presentation is captured"
	)
	_finish()

func _capture(file_name: String) -> bool:
	await process_frame
	if VISUAL_QA_RUNTIME.has_loading_overlay(self):
		return false
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		return false
	var output_path := "%s/%s" % [OUTPUT_DIRECTORY, file_name]
	return image.save_png(ProjectSettings.globalize_path(output_path)) == OK

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	var exit_code := 0
	if failures.is_empty():
		print("FINAL_SURVIVAL_VISUAL_QA: PASS")
	else:
		exit_code = 1
		print("FINAL_SURVIVAL_VISUAL_QA: FAIL (%d)" % failures.size())
	await VISUAL_QA_RUNTIME.cleanup_scene(self)
	quit(exit_code)
