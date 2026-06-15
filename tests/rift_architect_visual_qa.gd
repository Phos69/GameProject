extends SceneTree

const OUTPUT_DIRECTORY: String = "res://build/qa"

var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main_scene := load("res://game/main/main.tscn") as PackedScene
	_expect(main_scene != null, "main scene can be loaded for boss QA")
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
	var wave_manager := get_first_node_in_group("wave_manager") as WaveManager
	var boss_system := get_first_node_in_group("boss_system") as BossSystem
	var player_manager := get_first_node_in_group(
		"player_manager"
	) as PlayerManager
	var health_system := get_first_node_in_group(
		"health_system"
	) as HealthSystem
	_expect(game_mode_manager != null, "game mode manager is available")
	_expect(wave_manager != null, "wave manager is available")
	_expect(boss_system != null, "boss system is available")
	_expect(player_manager != null, "player manager is available")
	_expect(health_system != null, "health system is available")
	if (
		game_mode_manager == null
		or wave_manager == null
		or boss_system == null
		or player_manager == null
		or health_system == null
	):
		_finish()
		return
	wave_manager.initial_delay = 100.0
	game_mode_manager.set_mode(GameConstants.MODE_SURVIVAL)
	await process_frame
	await process_frame
	var player := player_manager.players.get(1) as PlayerController
	if player == null:
		_finish()
		return
	player.global_position = Vector2(300.0, 80.0)
	var boss := boss_system.request_boss_by_id(
		&"rift_architect",
		GameConstants.MODE_DUNGEON,
		&"visual_qa",
		Vector2(-120.0, -20.0)
	) as RiftArchitect
	_expect(boss != null, "Rift Architect is available for QA")
	if boss == null:
		_finish()
		return
	boss.set_physics_process(false)
	boss.target = player
	boss.lane_telegraph_duration = 6.0
	boss.cross_telegraph_duration = 6.0
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(OUTPUT_DIRECTORY)
	)
	_expect(
		boss.start_attack_telegraph(&"lane_sweep"),
		"lane telegraph starts"
	)
	await process_frame
	await process_frame
	_expect(
		await _capture("milestone_19_rift_lane.png"),
		"lane telegraph screenshot is captured"
	)
	boss.cancel_attack_telegraph()
	health_system.apply_damage(
		boss,
		boss.health_component.current_health
		- boss.health_component.max_health / 2
	)
	_expect(
		boss.start_attack_telegraph(&"cross_burst"),
		"cross telegraph starts"
	)
	await process_frame
	await process_frame
	_expect(
		await _capture("milestone_19_rift_cross.png"),
		"cross telegraph screenshot is captured"
	)
	_finish()

func _capture(file_name: String) -> bool:
	await process_frame
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		return false
	return image.save_png(ProjectSettings.globalize_path(
		"%s/%s" % [OUTPUT_DIRECTORY, file_name]
	)) == OK

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("RIFT_ARCHITECT_VISUAL_QA: PASS")
		quit(0)
		return
	print("RIFT_ARCHITECT_VISUAL_QA: FAIL (%d)" % failures.size())
	quit(1)
