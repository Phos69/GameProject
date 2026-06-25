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
	_expect(main_scene != null, "main scene can be loaded for accessibility QA")
	if main_scene == null:
		_finish()
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	await process_frame

	var main_menu := get_first_node_in_group("main_menu") as MainMenu
	var visual_settings := get_first_node_in_group(
		"visual_settings_manager"
	) as VisualSettingsManager
	var game_mode_manager := get_first_node_in_group(
		"game_mode_manager"
	) as GameModeManager
	var local_multiplayer := get_first_node_in_group(
		"local_multiplayer_manager"
	) as LocalMultiplayerManager
	var player_manager := get_first_node_in_group(
		"player_manager"
	) as PlayerManager
	var wave_manager := get_first_node_in_group(
		"wave_manager"
	) as WaveManager
	var enemy_system := get_first_node_in_group(
		"enemy_system"
	) as EnemySystem
	var boss_system := get_first_node_in_group(
		"boss_system"
	) as BossSystem
	var projectile_system := get_first_node_in_group(
		"projectile_system"
	) as ProjectileSystem
	_expect(main_menu != null, "main menu is available")
	_expect(visual_settings != null, "visual settings manager is available")
	_expect(game_mode_manager != null, "game mode manager is available")
	_expect(local_multiplayer != null, "local multiplayer manager is available")
	_expect(player_manager != null, "player manager is available")
	_expect(wave_manager != null, "wave manager is available")
	_expect(enemy_system != null, "enemy system is available")
	_expect(boss_system != null, "boss system is available")
	_expect(projectile_system != null, "projectile system is available")
	if (
		main_menu == null
		or visual_settings == null
		or game_mode_manager == null
		or local_multiplayer == null
		or player_manager == null
		or wave_manager == null
		or enemy_system == null
		or boss_system == null
		or projectile_system == null
	):
		_finish()
		return

	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(OUTPUT_DIRECTORY)
	)
	main_menu._open_visual_settings()
	await process_frame
	_expect(
		await _capture("milestone_21_visual_settings_menu.png"),
		"visual settings menu screenshot is captured"
	)
	main_menu._close_visual_settings()

	for player_slot in range(2, 5):
		local_multiplayer.activate_slot(player_slot)
	wave_manager.initial_delay = 100.0
	game_mode_manager.set_mode(GameConstants.MODE_SURVIVAL, {})
	await process_frame
	await process_frame
	for index in range(ENEMY_IDS.size()):
		var spawn_position := Vector2.RIGHT.rotated(
			TAU * float(index) / float(ENEMY_IDS.size())
		) * 360.0
		var enemy := enemy_system.spawn_enemy(
			ENEMY_IDS[index],
			spawn_position.move_toward(Vector2.ZERO, 155.0)
		)
		if enemy != null:
			enemy.set_physics_process(false)
			var visual := enemy.get_node_or_null("Visual") as ZombieVisual
			if visual != null:
				visual.set_state(&"chase")
				visual.set_facing(
					(enemy as Node2D).global_position.direction_to(Vector2.ZERO)
				)
	var boss := boss_system.request_boss_by_id(
		&"rift_architect",
		GameConstants.MODE_SURVIVAL,
		&"accessibility_qa",
		Vector2(0.0, -190.0)
	) as RiftArchitect
	if boss != null:
		boss.set_physics_process(false)
		boss.target = player_manager.players.get(1) as Node2D
		boss.lane_telegraph_duration = 20.0
		boss.start_attack_telegraph(&"lane_sweep")
	_spawn_pickup_samples(main)
	_spawn_projectile_samples(projectile_system)

	for profile_spec in [
		[&"default", "milestone_21_profile_default.png"],
		[&"reduced_motion", "milestone_21_profile_reduced_motion.png"],
		[&"high_contrast", "milestone_21_profile_high_contrast.png"]
	]:
		visual_settings.apply_profile(profile_spec[0])
		await process_frame
		await process_frame
		_expect(
			await _capture(profile_spec[1]),
			"%s profile screenshot is captured" % profile_spec[0]
		)
	_finish()

func _spawn_pickup_samples(main: Node) -> void:
	var pickup_scene := load(
		"res://game/drops/drop_pickup.tscn"
	) as PackedScene
	var parent := main.get_node("World/Pickups")
	var types: Array[StringName] = [
		GameConstants.DROP_EXPERIENCE,
		GameConstants.DROP_MONEY,
		GameConstants.DROP_AMMO,
		GameConstants.DROP_HEALTH,
		GameConstants.DROP_WEAPON
	]
	for index in range(types.size()):
		var pickup := pickup_scene.instantiate() as DropPickup
		pickup.setup({
			"type": types[index],
			"amount": 1
		})
		pickup.position = Vector2(
			-190.0 + float(index) * 95.0,
			175.0
		)
		parent.add_child(pickup)

func _spawn_projectile_samples(projectile_system: ProjectileSystem) -> void:
	var weapon_resources := [
		"res://game/weapons/starter_pistol.tres",
		"res://game/weapons/prototype_blaster.tres",
		"res://game/weapons/wave_cannon.tres",
		"res://game/weapons/rift_repeater.tres"
	]
	for index in range(weapon_resources.size()):
		var weapon := load(weapon_resources[index]) as WeaponData
		var projectile := projectile_system.spawn_projectile(
			Vector2(-210.0 + float(index) * 140.0, -40.0),
			Vector2.RIGHT,
			0.0,
			null,
			null,
			1,
			StringName("accessibility_%d" % index),
			weapon.visual_data
		) as Projectile
		if projectile != null:
			projectile.lifetime = 30.0

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
		print("VISUAL_ACCESSIBILITY_QA: PASS")
		quit(0)
		return
	print("VISUAL_ACCESSIBILITY_QA: FAIL (%d)" % failures.size())
	quit(1)

