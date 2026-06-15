extends SceneTree

var failures: PackedStringArray = []

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

	var biome_manager = get_first_node_in_group("biome_manager")
	var wave_director = get_first_node_in_group("wave_director")
	var wave_manager := get_first_node_in_group("wave_manager") as WaveManager
	_expect(biome_manager != null, "biome manager is available")
	_expect(wave_director != null, "wave director is available")
	_expect(wave_manager != null, "wave manager is available")
	if biome_manager == null or wave_director == null or wave_manager == null:
		_finish()
		return

	var expected_ids: Array = [
		&"infected_plains",
		&"toxic_wastes",
		&"burning_fields",
		&"frozen_outskirts",
		&"drowned_marsh"
	]
	for biome_id in expected_ids:
		var definition = biome_manager.get_biome_definition(StringName(biome_id))
		_expect(definition != null, "%s biome definition exists" % String(biome_id))
		if definition == null:
			continue
		_expect(
			not String(definition.get("display_name")).is_empty(),
			"%s biome has a display name" % String(biome_id)
		)
		_expect(
			(definition.get("palette") as Resource) != null,
			"%s biome has a palette" % String(biome_id)
		)
		_expect(
			(definition.get("terrain_tags") as Array).size() > 0,
			"%s biome defines terrain tags" % String(biome_id)
		)
		_expect(
			(definition.get("obstacle_ids") as Array).size() > 0,
			"%s biome defines obstacles" % String(biome_id)
		)
		_expect(
			(definition.get("crate_ids") as Array).size() > 0,
			"%s biome defines crate types" % String(biome_id)
		)
		_expect(
			(definition.get("allowed_zombie_types") as Array).size() > 0,
			"%s biome defines allowed zombies" % String(biome_id)
		)
		_expect(
			(definition.get("resource_tags") as Array).size() > 0,
			"%s biome defines resources" % String(biome_id)
		)
		_expect(
			float(definition.get("difficulty_rating")) > 0.0,
			"%s biome defines difficulty" % String(biome_id)
		)

	_expect(
		biome_manager.get_current_biome_id() == &"infected_plains",
		"run defaults to the starting biome"
	)
	_expect(
		wave_director.get_enemy_id_for_spawn(1, 0, 3) == &"survival_zombie",
		"starting biome first wave keeps base zombies"
	)

	_expect(
		biome_manager.set_current_biome(&"toxic_wastes"),
		"biome manager can switch to the toxic biome"
	)
	var toxic_config: Dictionary = wave_director.configure_wave(2, false, 10)
	_expect(
		int(toxic_config.get("regular_total", 0)) > 10,
		"toxic biome increases regular wave size"
	)
	_expect(
		float(toxic_config.get("spawn_rate_multiplier", 1.0)) > 1.0,
		"toxic biome changes spawn cadence"
	)
	var toxic_scaling: Dictionary = wave_director.get_wave_scaling_multipliers()
	_expect(
		float(toxic_scaling.get("health", 1.0)) > 1.0
		and float(toxic_scaling.get("damage", 1.0)) > 1.0,
		"toxic biome changes enemy scaling"
	)
	var toxic_enemy_id: StringName = wave_director.get_enemy_id_for_spawn(2, 0, 10)
	_expect(
		toxic_enemy_id == &"toxic_zombie",
		"toxic biome can resolve a thematic zombie id"
	)

	wave_manager.stop_run(true)
	wave_manager.initial_delay = 100.0
	wave_manager.base_enemy_count = 10
	wave_manager.enemy_count_growth = 0
	wave_manager.boss_wave_interval = 99
	wave_manager.start_run()
	wave_manager.start_next_wave()
	_expect(
		wave_manager.current_wave_biome_id == &"toxic_wastes",
		"wave manager records the current toxic biome"
	)
	_expect(
		wave_manager.current_wave_regular_total > 10,
		"wave manager applies biome wave size"
	)
	_expect(
		wave_manager.get_enemy_id_for_spawn(2, 0, 10) == &"toxic_zombie",
		"wave manager delegates roster to the biome director"
	)
	wave_manager.stop_run(true)

	_finish()

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("ZOMBIE_BIOME_WAVE_DIRECTOR_SMOKE_TEST: PASS")
		quit(0)
		return

	print("ZOMBIE_BIOME_WAVE_DIRECTOR_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
