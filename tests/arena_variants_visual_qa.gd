extends SceneTree

const OUTPUT_DIRECTORY: String = "res://build/qa"
const ENEMY_IDS: Array[StringName] = [
	&"survival_zombie",
	&"survival_runner",
	&"survival_tank",
	&"survival_shooter"
]

var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main_scene := load("res://game/main/main.tscn") as PackedScene
	_expect(main_scene != null, "main scene can be loaded for arena QA")
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
	var arena_manager := get_first_node_in_group(
		"survival_arena_manager"
	) as SurvivalArenaManager
	var local_multiplayer := get_first_node_in_group(
		"local_multiplayer_manager"
	) as LocalMultiplayerManager
	var wave_manager := get_first_node_in_group(
		"wave_manager"
	) as WaveManager
	var enemy_system := get_first_node_in_group(
		"enemy_system"
	) as EnemySystem
	var player_manager := get_first_node_in_group(
		"player_manager"
	) as PlayerManager
	_expect(game_mode_manager != null, "game mode manager is available")
	_expect(arena_manager != null, "arena manager is available")
	_expect(local_multiplayer != null, "local multiplayer manager is available")
	_expect(wave_manager != null, "wave manager is available")
	_expect(enemy_system != null, "enemy system is available")
	_expect(player_manager != null, "player manager is available")
	if (
		game_mode_manager == null
		or arena_manager == null
		or local_multiplayer == null
		or wave_manager == null
		or enemy_system == null
		or player_manager == null
	):
		_finish()
		return

	for player_slot in range(2, 5):
		local_multiplayer.activate_slot(player_slot)
	wave_manager.initial_delay = 100.0
	game_mode_manager.set_mode(
		GameConstants.MODE_SURVIVAL,
		{"arena_id": &"industrial_crossroads"}
	)
	await process_frame
	await process_frame
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(OUTPUT_DIRECTORY)
	)

	await _prepare_roster(enemy_system, player_manager, arena_manager)
	_expect(
		await _capture("milestone_20_industrial_crossroads.png"),
		"industrial arena screenshot is captured"
	)
	_clear_qa_enemies()
	arena_manager.activate_arena(&"rift_foundry")
	await process_frame
	await process_frame
	await _prepare_roster(enemy_system, player_manager, arena_manager)
	_expect(
		await _capture("milestone_20_rift_foundry.png"),
		"rift arena screenshot is captured"
	)
	_finish()

func _prepare_roster(
	enemy_system: EnemySystem,
	player_manager: PlayerManager,
	arena_manager: SurvivalArenaManager
) -> void:
	var profile := arena_manager.active_profile
	for slot in range(1, 5):
		var player := player_manager.players.get(slot) as PlayerController
		if player != null:
			player.global_position = profile.player_spawn_points[slot - 1]
	for index in range(ENEMY_IDS.size()):
		var spawn_position := profile.enemy_spawn_points[
			index % profile.enemy_spawn_points.size()
		]
		var enemy := enemy_system.spawn_enemy(
			ENEMY_IDS[index],
			spawn_position.move_toward(Vector2.ZERO, 145.0)
		)
		if enemy != null:
			enemy.add_to_group("arena_qa_enemies")
			enemy.set_physics_process(false)
			var visual := enemy.get_node_or_null("Visual") as ZombieVisual
			if visual != null:
				visual.set_state(&"chase")
				visual.set_facing(
					(enemy as Node2D).global_position.direction_to(Vector2.ZERO)
				)
	var props := arena_manager.get_interactive_props()
	if not props.is_empty():
		var barrel := props[0] as ExplosiveBarrel
		if barrel != null:
			barrel.warning_duration = 8.0
			barrel.arm_explosion()
	await process_frame
	await process_frame

func _clear_qa_enemies() -> void:
	for enemy in get_nodes_in_group("arena_qa_enemies"):
		if is_instance_valid(enemy):
			enemy.queue_free()

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
		print("ARENA_VARIANTS_VISUAL_QA: PASS")
		quit(0)
		return
	print("ARENA_VARIANTS_VISUAL_QA: FAIL (%d)" % failures.size())
	quit(1)

