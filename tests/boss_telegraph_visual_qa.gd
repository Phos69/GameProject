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
	var player_manager := get_first_node_in_group(
		"player_manager"
	) as PlayerManager
	var boss_system := get_first_node_in_group("boss_system") as BossSystem
	_expect(game_mode_manager != null, "game mode manager is available")
	_expect(wave_manager != null, "wave manager is available")
	_expect(player_manager != null, "player manager is available")
	_expect(boss_system != null, "boss system is available")
	if (
		game_mode_manager == null
		or wave_manager == null
		or player_manager == null
		or boss_system == null
	):
		_finish()
		return

	wave_manager.initial_delay = 100.0
	game_mode_manager.set_mode(GameConstants.MODE_SURVIVAL)
	var player := player_manager.players.get(1) as PlayerController
	_expect(player != null, "player one is available")
	if player == null:
		_finish()
		return

	player.global_position = Vector2(250.0, 90.0)
	var boss := boss_system.request_boss(
		GameConstants.MODE_SURVIVAL,
		&"visual_qa",
		Vector2(-120.0, -20.0)
	) as BasicBoss
	_expect(boss != null, "Wave Warden is available for visual QA")
	if boss == null:
		_finish()
		return

	boss.move_speed = 0.0
	boss.attack_cooldown = 100.0
	boss.attack_timer = 100.0
	boss.aimed_telegraph_duration = 4.0
	boss.radial_telegraph_duration = 4.0
	boss.target = player

	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(OUTPUT_DIRECTORY)
	)
	_expect(
		boss.start_attack_telegraph(&"aimed_volley"),
		"aimed telegraph starts for visual QA"
	)
	await process_frame
	await process_frame
	_expect(
		await _capture("milestone_11_boss_aimed.png"),
		"aimed telegraph screenshot is captured"
	)

	boss.cancel_attack_telegraph()
	_expect(
		boss.start_attack_telegraph(&"radial_burst"),
		"radial telegraph starts for visual QA"
	)
	await process_frame
	await process_frame
	_expect(
		await _capture("milestone_11_boss_radial.png"),
		"radial telegraph screenshot is captured"
	)
	_finish()

func _capture(file_name: String) -> bool:
	await process_frame
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
	if failures.is_empty():
		print("BOSS_TELEGRAPH_VISUAL_QA: PASS")
		quit(0)
		return
	print("BOSS_TELEGRAPH_VISUAL_QA: FAIL (%d)" % failures.size())
	quit(1)
