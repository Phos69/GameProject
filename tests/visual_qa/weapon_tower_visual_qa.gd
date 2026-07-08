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
	_expect(main_scene != null, "main scene can be loaded for weapon QA")
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
	var local_multiplayer := get_first_node_in_group(
		"local_multiplayer_manager"
	) as LocalMultiplayerManager
	var player_manager := get_first_node_in_group(
		"player_manager"
	) as PlayerManager
	var projectile_system := get_first_node_in_group(
		"projectile_system"
	) as ProjectileSystem
	var tower_defense_mode := get_first_node_in_group(
		"tower_defense_mode"
	) as TowerDefenseMode
	_expect(game_mode_manager != null, "game mode manager is available")
	_expect(wave_manager != null, "wave manager is available")
	_expect(local_multiplayer != null, "local multiplayer manager is available")
	_expect(player_manager != null, "player manager is available")
	_expect(projectile_system != null, "projectile system is available")
	_expect(tower_defense_mode != null, "tower defense mode is available")
	if (
		game_mode_manager == null
		or wave_manager == null
		or local_multiplayer == null
		or player_manager == null
		or projectile_system == null
		or tower_defense_mode == null
	):
		_finish()
		return

	wave_manager.initial_delay = 100.0
	for player_slot in range(2, 5):
		local_multiplayer.activate_slot(player_slot)
	game_mode_manager.set_mode(GameConstants.MODE_SURVIVAL)
	var survival_ready: Dictionary = await VISUAL_QA_RUNTIME.wait_for_capture_ready(
		self,
		func() -> bool:
			return (
				game_mode_manager.active_mode_id == GameConstants.MODE_SURVIVAL
				and player_manager.players.size() == 4
			)
	)
	_expect(
		bool(survival_ready.get("ready", false)),
		"weapon scenario world is capture-ready: %s"
		% VISUAL_QA_RUNTIME.describe_failure(survival_ready)
	)

	var blaster := load(
		"res://game/weapons/prototype_blaster.tres"
	) as WeaponData
	var cannon := load(
		"res://game/weapons/wave_cannon.tres"
	) as WeaponData
	var player_positions: Array[Vector2] = [
		Vector2(-250.0, 40.0),
		Vector2(-80.0, 40.0),
		Vector2(90.0, 40.0),
		Vector2(260.0, 40.0)
	]
	var directions: Array[Vector2] = [
		Vector2(0.8, -0.35).normalized(),
		Vector2(0.55, -0.62).normalized(),
		Vector2(-0.55, -0.62).normalized(),
		Vector2(-0.8, -0.35).normalized()
	]
	for player_slot in range(1, 5):
		var player := player_manager.players.get(player_slot) as PlayerController
		if player == null:
			continue
		player.global_position = player_positions[player_slot - 1]
		player.set_physics_process(false)
		player.facing_direction = directions[player_slot - 1]
		player.visual.set_facing(player.facing_direction)
		if player_slot == 2:
			(player.weapon_system as WeaponSystem).equip_weapon(blaster)
		elif player_slot >= 3:
			(player.weapon_system as WeaponSystem).equip_weapon(cannon)
		player.visual.play_fire()

	var starter_visual := load(
		"res://game/weapons/starter_pistol_visual.tres"
	) as WeaponVisualData
	var projectile_positions: Array[Vector2] = [
		Vector2(-205.0, -5.0),
		Vector2(-30.0, -20.0),
		Vector2(35.0, -20.0)
	]
	var projectile_directions: Array[Vector2] = [
		directions[0],
		directions[1],
		directions[2]
	]
	var projectile_visuals: Array[WeaponVisualData] = [
		starter_visual,
		blaster.visual_data,
		cannon.visual_data
	]
	var qa_projectiles: Array[Projectile] = []
	for index in range(projectile_positions.size()):
		var visual_data := projectile_visuals[index]
		var projectile := projectile_system.spawn_projectile(
			projectile_positions[index],
			projectile_directions[index],
			400.0,
			null,
			null,
			1,
			visual_data.profile_id,
			visual_data
		) as Projectile
		if projectile != null:
			projectile.set_physics_process(false)
			qa_projectiles.append(projectile)

	await process_frame
	await process_frame
	_expect(
		qa_projectiles.size() == projectile_positions.size(),
		"player weapon scenario marker contains three projectiles"
	)
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(OUTPUT_DIRECTORY)
	)
	_expect(
		await _capture("milestone_13_player_weapons.png"),
		"player weapon identity screenshot is captured"
	)
	for projectile in qa_projectiles:
		if is_instance_valid(projectile):
			projectile.queue_free()
	for player_slot in range(1, 5):
		var player := player_manager.players.get(player_slot) as PlayerController
		if player != null:
			player.visible = false
	await process_frame

	game_mode_manager.set_mode(
		GameConstants.MODE_TOWER_DEFENSE,
		{"initial_delay": 100.0, "starting_credits": 75}
	)
	var tower_mode_ready: Dictionary = await VISUAL_QA_RUNTIME.wait_for_capture_ready(
		self,
		func() -> bool:
			return (
				game_mode_manager.active_mode_id
				== GameConstants.MODE_TOWER_DEFENSE
			),
		false,
		false
	)
	_expect(
		bool(tower_mode_ready.get("ready", false)),
		"tower defense scenario is capture-ready: %s"
		% VISUAL_QA_RUNTIME.describe_failure(tower_mode_ready)
	)
	var tower_a := tower_defense_mode.try_build_at_slot(&"slot_a") as DefenseTower
	var tower_b := tower_defense_mode.try_build_at_slot(&"slot_b") as DefenseTower
	var tower_c := tower_defense_mode.try_build_at_slot(&"slot_c") as DefenseTower
	var towers: Array[DefenseTower] = [tower_a, tower_b, tower_c]
	var tower_directions: Array[Vector2] = [
		Vector2(0.7, -0.5),
		Vector2.RIGHT,
		Vector2(-0.7, -0.5)
	]
	for index in range(3):
		var tower := towers[index]
		if tower == null:
			continue
		tower.set_process(false)
		var direction: Vector2 = tower_directions[index].normalized()
		tower.visual.set_aim_direction(direction)
		if index == 1:
			tower.visual.play_fire()
	# TD-001: gli upgrade passano dal flusso crediti reale, cosi' i prompt
	# degli slot restano coerenti; la board mostra L1 / L3 / L2 fianco a
	# fianco con i pip di livello sulla base.
	var tower_defense_manager := get_first_node_in_group(
		"tower_defense_manager"
	) as TowerDefenseManager
	if tower_defense_manager != null:
		tower_defense_manager.add_credits(200)
		tower_defense_mode.try_upgrade_at_slot(&"slot_b")
		tower_defense_mode.try_upgrade_at_slot(&"slot_b")
		tower_defense_mode.try_upgrade_at_slot(&"slot_c")
	await process_frame
	await process_frame
	_expect(
		tower_b != null and tower_b.tower_level == 3
			and tower_c != null and tower_c.tower_level == 2,
		"upgraded towers reach their display levels through the credit flow"
	)
	_expect(
		towers.all(func(tower: DefenseTower) -> bool: return tower != null),
		"tower scenario marker contains all three defense towers"
	)
	_expect(
		await _capture("milestone_13_defense_towers.png"),
		"defense tower identity screenshot is captured"
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
		print("WEAPON_TOWER_VISUAL_QA: PASS")
	else:
		exit_code = 1
		print("WEAPON_TOWER_VISUAL_QA: FAIL (%d)" % failures.size())
	await VISUAL_QA_RUNTIME.cleanup_scene(self)
	quit(exit_code)
