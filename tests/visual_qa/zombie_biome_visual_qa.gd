extends SceneTree

const OUTPUT_DIRECTORY: String = "res://build/qa"

var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main_scene := load("res://game/main/main.tscn") as PackedScene
	_expect(main_scene != null, "main scene can be loaded for biome QA")
	if main_scene == null:
		_finish()
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame

	var game_mode_manager := get_first_node_in_group(
		"game_mode_manager"
	) as GameModeManager
	var wave_manager := get_first_node_in_group(
		"wave_manager"
	) as WaveManager
	var biome_manager := get_first_node_in_group(
		"biome_manager"
	) as BiomeManager
	var transition_system := get_first_node_in_group(
		"biome_transition_system"
	) as BiomeTransitionSystem
	var enemy_system := get_first_node_in_group(
		"enemy_system"
	) as EnemySystem
	var player := get_first_node_in_group("players") as PlayerController
	_expect(game_mode_manager != null, "game mode manager is available")
	_expect(wave_manager != null, "wave manager is available")
	_expect(biome_manager != null, "biome manager is available")
	_expect(transition_system != null, "transition system is available")
	_expect(enemy_system != null, "enemy system is available")
	_expect(player != null, "player one is available")
	if (
		game_mode_manager == null
		or wave_manager == null
		or biome_manager == null
		or transition_system == null
		or enemy_system == null
		or player == null
	):
		_finish()
		return

	wave_manager.initial_delay = 100.0
	transition_system.transition_cooldown = 0.01
	game_mode_manager.set_mode(GameConstants.MODE_SURVIVAL)
	await process_frame
	await process_frame
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(OUTPUT_DIRECTORY)
	)

	var biome_ids: Array[StringName] = [
		&"infected_plains",
		&"toxic_wastes",
		&"burning_fields",
		&"frozen_outskirts",
		&"drowned_marsh"
	]
	for biome_id in biome_ids:
		if biome_manager.get_current_biome_id() != biome_id:
			transition_system.cooldown_timer = 0.0
			transition_system.transition_to(biome_id, &"east")
			await process_frame
			await physics_frame
		player.global_position = Vector2.ZERO
		_clear_qa_enemies()
		_spawn_biome_roster(enemy_system, biome_id)
		await process_frame
		await process_frame
		_expect(
			await _capture("zombie_biome_%s.png" % String(biome_id)),
			"%s screenshot is captured" % String(biome_id)
		)

	_finish()

func _spawn_biome_roster(
	enemy_system: EnemySystem,
	biome_id: StringName
) -> void:
	var roster: Array[StringName] = [&"survival_zombie", &"survival_runner"]
	match biome_id:
		&"toxic_wastes":
			roster = [&"toxic_zombie", &"toxic_exploder"]
		&"burning_fields":
			roster = [&"burned_zombie", &"fire_runner", &"fire_exploder"]
		&"frozen_outskirts":
			roster = [&"frozen_zombie", &"ice_armored_zombie"]
		&"drowned_marsh":
			roster = [&"drowned_zombie", &"marsh_zombie", &"water_emerging_zombie"]
	for index in range(roster.size()):
		var enemy := enemy_system.spawn_enemy(
			roster[index],
			Vector2(-170.0 + float(index) * 170.0, -85.0)
		)
		if enemy == null:
			continue
		enemy.add_to_group("biome_qa_enemies")
		enemy.set_physics_process(false)
		var visual := enemy.get_node_or_null("Visual") as ZombieVisual
		if visual != null:
			visual.modulate = Color.WHITE
			visual.set_state(&"chase")
			visual.set_facing(Vector2.DOWN)

func _clear_qa_enemies() -> void:
	for enemy in get_nodes_in_group("biome_qa_enemies"):
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
		print("ZOMBIE_BIOME_VISUAL_QA: PASS")
		quit(0)
		return
	print("ZOMBIE_BIOME_VISUAL_QA: FAIL (%d)" % failures.size())
	quit(1)
